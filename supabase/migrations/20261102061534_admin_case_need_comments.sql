begin;

-- Additive administrative comments. The existing private history retains its
-- lifecycle; this migration changes no approval, publication or financial row.
create function private.dopmi_need_comment_dto(event_id uuid, case_id uuid, case_version integer,
  occurred_at timestamptz, item jsonb) returns jsonb
language sql stable set search_path='' as $$
  select jsonb_build_object(
    'id',event_id::text||':'||(item->>'target_kind')||':'||(item->>'target_id'),
    'request_id',event_id,'case_id',case_id,'case_version',case_version,
    'target_kind',item->>'target_kind','target_id',item->>'target_id',
    'target_version',(item->>'target_version')::integer,'target_title',item->>'target_title',
    'body',item->>'body','created_at',occurred_at);
$$;
revoke all on function private.dopmi_need_comment_dto(uuid,uuid,integer,timestamptz,jsonb)
  from public,anon,authenticated,service_role;

create function public.dopmi_admin_rescue_packet(record_id uuid, expense_page integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  person uuid; r public.dopmi_rescue_records; child public.dopmi_rescue_records;
  legacy jsonb; expenses jsonb:='[]'; need_comments jsonb:='[]'; child_ids uuid[]:='{}'; total bigint:=0;
begin
  if not public.dopmi_is_admin() then
    raise exception 'Acceso administrativo requerido' using errcode='42501';
  end if;
  if expense_page is null or expense_page not between 1 and 1000 then
    raise exception 'Página inválida' using errcode='22023';
  end if;
  select owner_id into person from public.dopmi_rescue_records where id=record_id;
  if person is null then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
  -- Save, transition and review use this owner lock too. A child cannot become
  -- private between the access predicate, count, returned rows and read audit.
  perform private.dopmi_rescue_lock(person);
  if not public.dopmi_is_admin() then
    raise exception 'Acceso administrativo requerido' using errcode='42501';
  end if;
  select * into r from public.dopmi_rescue_records where id=record_id;
  if not found or r.status in ('draft','pending_stripe') then
    raise exception 'Solicitud no disponible' using errcode='42501';
  end if;
  legacy:=public.dopmi_rescue_detail(record_id);
  if r.kind='case' then
    select count(*) into total from public.dopmi_rescue_records e
      where e.kind='expense' and e.parent_id=r.id and e.owner_id=r.owner_id
        and e.status not in ('draft','pending_stripe');
    select coalesce(jsonb_agg(to_jsonb(e) order by e.submitted_at desc nulls last,e.id),'[]'),
      coalesce(array_agg(e.id),'{}') into expenses,child_ids
      from (select * from public.dopmi_rescue_records x
        where x.kind='expense' and x.parent_id=r.id and x.owner_id=r.owner_id
          and x.status not in ('draft','pending_stripe')
        order by x.submitted_at desc nulls last,x.id limit 20 offset (expense_page-1)*20) e;
    -- Limit flattened comments, not batches. Structured expense comments remain
    -- hidden while that expense is currently private or outside this case/owner.
    -- Legacy history still retains feedback shared on the previously reviewed
    -- version; it contains no new fields or evidence from a current draft.
    select coalesce(jsonb_agg(x.dto order by x.created_at desc,x.event_id desc,x.ordinality desc),'[]')
      into need_comments from (
        select private.dopmi_need_comment_dto(h.id,h.record_id,h.version,h.created_at,c.item) dto,
          h.created_at,h.id event_id,c.ordinality
        from private.dopmi_rescue_history h
        cross join lateral jsonb_array_elements(case when jsonb_typeof(h.snapshot->'_need_comments')='array'
          then h.snapshot->'_need_comments' else '[]'::jsonb end) with ordinality c(item,ordinality)
        where h.record_id=r.id and h.action='need_comments'
          and (c.item->>'target_kind'='planned' or (c.item->>'target_kind'='expense' and exists(
            select 1 from public.dopmi_rescue_records e where e.id::text=c.item->>'target_id'
              and e.kind='expense' and e.parent_id=r.id and e.owner_id=r.owner_id
              and e.status not in ('draft','pending_stripe'))))
        order by h.created_at desc,h.id desc,c.ordinality desc limit 100
      ) x;
    -- Audit every returned child's data, including the minimal title in a
    -- comment whose child lies on a different page. Never audit hidden drafts.
    for child in select e.* from public.dopmi_rescue_records e
      where e.kind='expense' and e.parent_id=r.id and e.owner_id=r.owner_id
        and e.status not in ('draft','pending_stripe')
        and (e.id=any(child_ids) or exists(select 1 from jsonb_array_elements(need_comments) c
          where c->>'target_kind'='expense' and c->>'target_id'=e.id::text))
    loop
      if child.owner_id<>auth.uid() then
        perform private.dopmi_rescue_audit(child,'read','Consulta de expediente de necesidades');
      end if;
    end loop;
  end if;
  return legacy||jsonb_build_object('expenses',jsonb_build_object('total',total,'page',expense_page,'items',expenses),
    'need_comments',need_comments);
end;
$$;

create function public.dopmi_comment_case_needs(record_id uuid, expected_version integer,
  comments jsonb, request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid:=auth.uid(); person uuid; r public.dopmi_rescue_records; expense public.dopmi_rescue_records;
  saved private.dopmi_rescue_history; item jsonb; normalized jsonb:='[]'; enriched jsonb:='[]';
  target uuid; target_kind text; target_version integer; title text; body text; feedback text:='';
  seen text[]:='{}'; body_size integer:=0;
begin
  if actor is null or not public.dopmi_is_admin() then
    raise exception 'Acceso administrativo requerido' using errcode='42501';
  end if;
  select owner_id into person from public.dopmi_rescue_records where id=record_id;
  if person is null then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
  perform private.dopmi_rescue_lock(person);
  if not public.dopmi_is_admin() then
    raise exception 'Acceso administrativo requerido' using errcode='42501';
  end if;
  select * into r from public.dopmi_rescue_records where id=record_id for update;
  -- Check current access before considering any previous request. A revoked
  -- reviewer, a withdrawn case and self review never acquire replay access.
  if not found or r.kind<>'case' or r.status in ('draft','pending_stripe') then
    raise exception 'Solicitud no disponible' using errcode='42501';
  end if;
  if r.owner_id=actor then
    raise exception 'Otra persona del equipo debe revisar tu solicitud' using errcode='42501';
  end if;
  if request_id is null or jsonb_typeof(comments) is distinct from 'array'
    or octet_length(comments::text)>100000 then
    raise exception 'Comentarios inválidos' using errcode='22023';
  end if;
  if jsonb_array_length(comments) not between 1 and 40 then
    raise exception 'Comentarios inválidos' using errcode='22023';
  end if;
  for item in select value from jsonb_array_elements(comments) loop
    if jsonb_typeof(item) is distinct from 'object'
      or not (item ?& array['target_kind','target_id','target_version','body'])
      or (item-'target_kind'-'target_id'-'target_version'-'body')<>'{}'::jsonb
      or jsonb_typeof(item->'target_kind') is distinct from 'string'
      or coalesce(item->>'target_kind','') not in ('planned','expense')
      or jsonb_typeof(item->'target_id') is distinct from 'string'
      or coalesce(item->>'target_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or jsonb_typeof(item->'target_version') is distinct from 'number'
      or coalesce(item->>'target_version','') !~ '^[0-9]{1,10}$'
      or jsonb_typeof(item->'body') is distinct from 'string' then
      raise exception 'Comentarios inválidos' using errcode='22023';
    end if;
    if (item->>'target_version')::bigint not between 1 and 2147483647 then
      raise exception 'Comentarios inválidos' using errcode='22023';
    end if;
    target:=(item->>'target_id')::uuid; target_kind:=item->>'target_kind';
    target_version:=(item->>'target_version')::integer;
    body:=btrim(item->>'body',E' \t\n\r\f\v');
    body_size:=body_size+char_length(body);
    if char_length(body) not between 1 and 1000 or body_size>20000
      or (target_kind||':'||target::text)=any(seen) then
      raise exception 'Comentarios inválidos' using errcode='22023';
    end if;
    seen:=array_append(seen,target_kind||':'||target::text);
    normalized:=normalized||jsonb_build_array(jsonb_build_object('target_kind',target_kind,
      'target_id',target,'target_version',target_version,'body',body));
  end loop;
  -- Entry order is immaterial; the same normalized intent reuses the request.
  select jsonb_agg(value order by value->>'target_kind',value->>'target_id') into normalized
    from jsonb_array_elements(normalized);
  select * into saved from private.dopmi_rescue_history where id=request_id;
  if found then
    if saved.action<>'need_comments' or saved.actor_type<>'user' or saved.source<>'user'
      or saved.actor_id is distinct from actor or saved.record_id is distinct from r.id
      or saved.version is distinct from expected_version
      or saved.snapshot->'_need_comments_input' is distinct from normalized then
      raise exception 'Identificador de solicitud no disponible' using errcode='22023';
    end if;
  else
    if r.version is distinct from expected_version then
      raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='40001';
    end if;
    if r.status<>'submitted' then
      raise exception 'El caso debe estar en revisión para comentar' using errcode='22023';
    end if;
    -- Validate every target before the single history insert. No partial batch,
    -- decision, version bump, new publication or financial state is possible.
    for item in select value from jsonb_array_elements(normalized) loop
      target:=(item->>'target_id')::uuid; target_kind:=item->>'target_kind';
      target_version:=(item->>'target_version')::integer;
      if target_kind='planned' then
        select p->>'title' into title from jsonb_array_elements(case when jsonb_typeof(r.public_data->'need_items')='array'
          then r.public_data->'need_items' else '[]'::jsonb end) p where p->>'id'=target::text;
        if not found or target_version<>r.version then
          raise exception 'La necesidad cambió. Recarga antes de continuar' using errcode='40001';
        end if;
      else
        select * into expense from public.dopmi_rescue_records e
          where e.id=target and e.kind='expense' and e.parent_id=r.id and e.owner_id=r.owner_id
            and e.status not in ('draft','pending_stripe') for update;
        if not found or expense.version<>target_version then
          raise exception 'La necesidad cambió. Recarga antes de continuar' using errcode='40001';
        end if;
        title:=coalesce(nullif(btrim(expense.public_data->>'title'),''),'Gasto');
      end if;
      enriched:=enriched||jsonb_build_array(item||jsonb_build_object('target_title',title));
      feedback:=feedback||case when feedback='' then '' else E'\n\n' end||title||E':\n'||(item->>'body');
    end loop;
    insert into private.dopmi_rescue_history(id,record_id,actor_id,actor_type,source,action,feedback,version,snapshot)
      values(request_id,r.id,actor,'user','user','need_comments',feedback,r.version,
        to_jsonb(r)||jsonb_build_object('_need_comments',enriched,'_need_comments_input',normalized))
      on conflict(id) do nothing returning * into saved;
    if not found then
      -- A concurrent request for a different owner may share the UUID. Compare
      -- the winning event without leaking its actor, record or private payload.
      select * into saved from private.dopmi_rescue_history where id=request_id;
      if not found or saved.action<>'need_comments' or saved.actor_type<>'user' or saved.source<>'user'
        or saved.actor_id is distinct from actor or saved.record_id is distinct from r.id
        or saved.version is distinct from expected_version
        or saved.snapshot->'_need_comments_input' is distinct from normalized then
        raise exception 'Identificador de solicitud no disponible' using errcode='22023';
      end if;
    end if;
  end if;
  return jsonb_build_object('request_id',saved.id,'record_id',saved.record_id,'case_version',saved.version,
    'comments',(select jsonb_agg(private.dopmi_need_comment_dto(saved.id,saved.record_id,saved.version,saved.created_at,c.item)
      order by c.ordinality) from jsonb_array_elements(saved.snapshot->'_need_comments') with ordinality c(item,ordinality)));
end;
$$;

revoke all on function public.dopmi_admin_rescue_packet(uuid,integer) from public,anon,authenticated,service_role;
revoke all on function public.dopmi_comment_case_needs(uuid,integer,jsonb,uuid) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_admin_rescue_packet(uuid,integer) to authenticated;
grant execute on function public.dopmi_comment_case_needs(uuid,integer,jsonb,uuid) to authenticated;

commit;
