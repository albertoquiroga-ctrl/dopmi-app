begin;

-- A manifest is created by an explicit, initial case submission, never by a
-- migration, a timestamp heuristic, or Stripe readiness. Drafts remain drafts.
create table private.dopmi_case_need_submissions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.dopmi_rescue_records(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  source_case_version integer not null check(source_case_version>0),
  review_case_version integer not null check(review_case_version>0),
  case_snapshot jsonb not null check(jsonb_typeof(case_snapshot)='object'),
  created_at timestamptz not null default now(),
  decision_request_id uuid unique, decision_actor_id uuid,
  decision_input jsonb, decision_result jsonb,
  unique(case_id,source_case_version),
  unique(case_id,review_case_version),
  check((decision_request_id is null and decision_actor_id is null and decision_input is null and decision_result is null)
    or (decision_request_id is not null and decision_actor_id is not null and decision_input is not null and decision_result is not null))
);
create table private.dopmi_case_need_submission_expenses (
  submission_id uuid not null references private.dopmi_case_need_submissions(id) on delete cascade,
  -- Keep the historical JSON if an inactive draft is legitimately removed.
  -- The case/owner cascade still follows the established account retention.
  expense_id uuid not null,
  expense_version integer not null check(expense_version>0),
  snapshot jsonb not null check(jsonb_typeof(snapshot)='object'),
  primary key(submission_id,expense_id)
);
create index dopmi_case_need_expense on private.dopmi_case_need_submission_expenses(expense_id,submission_id);
alter table private.dopmi_case_need_submissions enable row level security;
alter table private.dopmi_case_need_submission_expenses enable row level security;
revoke all on private.dopmi_case_need_submissions,private.dopmi_case_need_submission_expenses
  from public,anon,authenticated,service_role;

create function private.dopmi_initial_case_submission(r public.dopmi_rescue_records)
returns private.dopmi_case_need_submissions
language sql stable set search_path='' as $$
  select s from private.dopmi_case_need_submissions s
    where r.kind='case' and r.status in ('pending_stripe','submitted')
      and s.case_id=r.id and s.owner_id=r.owner_id and s.review_case_version=r.version
      and s.decision_request_id is null;
$$;

create function private.dopmi_initial_case_capture(r public.dopmi_rescue_records) returns void
language plpgsql set search_path='' as $$
declare packet uuid; expense public.dopmi_rescue_records;
begin
  if r.kind<>'case' or r.status not in ('submitted','pending_stripe')
    or r.approved_snapshot is not null or r.approved_at is not null
    or exists(select 1 from private.dopmi_rescue_history h where h.record_id=r.id and h.action='approved') then
    return;
  end if;
  insert into private.dopmi_case_need_submissions(case_id,owner_id,source_case_version,review_case_version,case_snapshot)
    values(r.id,r.owner_id,r.version,r.version,to_jsonb(r)) returning id into packet;
  -- Save and submission both hold this owner's advisory lock. Exact membership
  -- and versions are frozen together with the paths the owner actually shared.
  perform 1 from public.dopmi_rescue_records e
    where e.parent_id=r.id and e.owner_id=r.owner_id and e.kind='expense' order by e.id for update;
  for expense in select e.* from public.dopmi_rescue_records e
    where e.parent_id=r.id and e.owner_id=r.owner_id and e.kind='expense' order by e.id loop
    begin
      perform private.dopmi_rescue_validate(expense);
    exception when invalid_parameter_value then
      raise exception 'Revisa la necesidad «%»: %',coalesce(nullif(expense.public_data->>'title',''),'Gasto'),sqlerrm
        using errcode='22023';
    end;
  end loop;
  insert into private.dopmi_case_need_submission_expenses(submission_id,expense_id,expense_version,snapshot)
    select packet,e.id,e.version,to_jsonb(e) from public.dopmi_rescue_records e
      where e.parent_id=r.id and e.owner_id=r.owner_id and e.kind='expense';
end;
$$;

do $copy$ begin
  execute replace(pg_get_functiondef('public.dopmi_transition_rescue(uuid,integer,text)'::regprocedure),
    'FUNCTION public.dopmi_transition_rescue(', 'FUNCTION public.dopmi_transition_rescue_before_initial_packet(');
end; $copy$;
revoke all on function public.dopmi_transition_rescue_before_initial_packet(uuid,integer,text)
  from public,anon,authenticated,service_role;
create or replace function public.dopmi_transition_rescue(record_id uuid, expected_version integer, action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; r public.dopmi_rescue_records;
begin
  -- The delegated operation preserves every current owner, lifecycle, legal,
  -- Stripe and video gate and acquires ownerlock before the row lock.
  result:=public.dopmi_transition_rescue_before_initial_packet(record_id,expected_version,action);
  if action='submit' then
    select * into r from public.dopmi_rescue_records where id=record_id;
    perform private.dopmi_initial_case_capture(r);
  end if;
  return result;
end;
$$;

create function private.dopmi_initial_case_stripe_promoted() returns trigger
language plpgsql set search_path='' as $$
begin
  -- Promote the already consented manifest, including the original versions.
  -- A legacy waiting case without a manifest remains legacy.
  update private.dopmi_case_need_submissions set review_case_version=new.version
    where case_id=new.id and owner_id=new.owner_id and review_case_version=old.version
      and decision_request_id is null;
  return new;
end;
$$;
create trigger dopmi_initial_case_stripe_promoted after update of status on public.dopmi_rescue_records
  for each row when(old.kind='case' and old.status='pending_stripe' and new.status='submitted')
  execute function private.dopmi_initial_case_stripe_promoted();

create function private.dopmi_initial_case_freeze_expense() returns trigger
language plpgsql set search_path='' as $$
declare parent public.dopmi_rescue_records;
begin
  if old.kind='expense' and (new.public_data is distinct from old.public_data
    or new.private_data is distinct from old.private_data or new.files is distinct from old.files
    or new.parent_id is distinct from old.parent_id or new.owner_id is distinct from old.owner_id
    or new.kind is distinct from old.kind or new.version is distinct from old.version or new.status is distinct from old.status) then
    select * into parent from public.dopmi_rescue_records where id=old.parent_id;
    if exists(select 1 from private.dopmi_case_need_submission_expenses e
      join private.dopmi_case_need_submissions s on s.id=e.submission_id
      where e.expense_id=old.id and s.id=(private.dopmi_initial_case_submission(parent)).id) then
      raise exception 'Retira el caso de revisión antes de corregir esta necesidad' using errcode='22023';
    end if;
  end if;
  return new;
end;
$$;
create trigger dopmi_initial_case_freeze_expense before update on public.dopmi_rescue_records
  for each row execute function private.dopmi_initial_case_freeze_expense();

-- Draft removal previously took the child row lock first. Serialize the public
-- owner operation before that row lock, matching submission and review order.
do $patch$
declare definition text; anchor text:='  select * into r from public.dopmi_rescue_records where id=$1 for update;';
begin
  definition:=replace(pg_get_functiondef('public.dopmi_remove_draft_expense(uuid,integer)'::regprocedure),E'\r\n',E'\n');
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 then
    raise exception 'Initial packet: unexpected draft removal function';
  end if;
  execute replace(definition,anchor,'  perform private.dopmi_rescue_lock(actor);'||E'\n'||anchor);
end;
$patch$;
create function private.dopmi_initial_case_prevent_expense_delete() returns trigger
language plpgsql set search_path='' as $$
declare parent public.dopmi_rescue_records;
begin
  -- Preserve service/administrative deletion and retention powers. Clients have
  -- no direct DELETE grant; the owner RPC above acquires ownerlock before DELETE.
  if old.kind='expense' and current_setting('role',true) in ('anon','authenticated') then
    select * into parent from public.dopmi_rescue_records where id=old.parent_id;
    if exists(select 1 from private.dopmi_case_need_submission_expenses e
      where e.expense_id=old.id and e.submission_id=(private.dopmi_initial_case_submission(parent)).id) then
      raise exception 'Retira el caso de revisión antes de eliminar esta necesidad' using errcode='22023';
    end if;
  end if;
  return old;
end;
$$;
create trigger dopmi_initial_case_prevent_expense_delete before delete on public.dopmi_rescue_records
  for each row execute function private.dopmi_initial_case_prevent_expense_delete();

-- Historical manifests are not a new indefinite blob-retention policy. Pins and
-- snapshot read grants exist only while the case is pending/submitted. Withdrawal
-- or a decision revokes them in that transaction; baseline retention still runs.
do $copy$ begin
  execute replace(pg_get_functiondef('public.dopmi_rescue_file_access(text,boolean)'::regprocedure),
    'FUNCTION public.dopmi_rescue_file_access(', 'FUNCTION public.dopmi_rescue_file_access_before_initial_packet(');
end; $copy$;
revoke all on function public.dopmi_rescue_file_access_before_initial_packet(text,boolean)
  from public,anon,authenticated,service_role;
create or replace function public.dopmi_rescue_file_access(object_name text, writing boolean default false) returns boolean
language plpgsql security definer set search_path='' as $$
declare person uuid; pinned boolean; shared boolean;
begin
  select owner_id into person from public.dopmi_rescue_records where id::text=split_part(object_name,'/',2);
  -- Serialize the newly shared read grant too. A withdrawal cannot release the
  -- path pin between evaluating membership and authorizing a new signed read.
  if person is not null then perform private.dopmi_rescue_lock(person); end if;
  select coalesce(bool_or(true),false),coalesce(bool_or(c.status='submitted'),false) into pinned,shared
    from private.dopmi_case_need_submission_expenses e
    join private.dopmi_case_need_submissions s on s.id=e.submission_id
    join public.dopmi_rescue_records c on c.id=s.case_id and c.owner_id=s.owner_id
    cross join lateral jsonb_array_elements(e.snapshot->'files') f
    where c.status in ('pending_stripe','submitted') and c.version=s.review_case_version
      and s.decision_request_id is null and f->>'path'=object_name;
  if writing and pinned then return false; end if;
  return public.dopmi_rescue_file_access_before_initial_packet(object_name,writing)
    or (not writing and shared and public.dopmi_is_admin());
end;
$$;

do $copy$ begin
  execute replace(pg_get_functiondef('public.dopmi_admin_rescue_packet(uuid,integer)'::regprocedure),
    'FUNCTION public.dopmi_admin_rescue_packet(', 'FUNCTION public.dopmi_admin_rescue_packet_before_initial_packet(');
end; $copy$;
revoke all on function public.dopmi_admin_rescue_packet_before_initial_packet(uuid,integer)
  from public,anon,authenticated,service_role;
create or replace function public.dopmi_admin_rescue_packet(record_id uuid, expense_page integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; r public.dopmi_rescue_records; s private.dopmi_case_need_submissions;
  children jsonb; ids jsonb; total bigint; comments jsonb; child public.dopmi_rescue_records;
begin
  -- The legacy RPC owns authorization, validation, the ownerlock and read audit.
  result:=public.dopmi_admin_rescue_packet_before_initial_packet(record_id,expense_page);
  select * into r from public.dopmi_rescue_records where id=record_id;
  s:=private.dopmi_initial_case_submission(r);
  if s.id is null or r.status<>'submitted' then return result||jsonb_build_object('initial_packet',null); end if;
  select count(*),coalesce(jsonb_agg(e.expense_id order by e.expense_id),'[]') into total,ids
    from private.dopmi_case_need_submission_expenses e where e.submission_id=s.id;
  select coalesce(jsonb_agg(e.snapshot||jsonb_build_object('submission_id',s.id) order by e.expense_id),'[]') into children
    from (select * from private.dopmi_case_need_submission_expenses where submission_id=s.id
      order by expense_id limit 20 offset (expense_page-1)*20) e;
  select coalesce(jsonb_agg(x.dto order by x.created_at desc,x.event_id desc,x.ordinality desc),'[]') into comments
    from (select private.dopmi_need_comment_dto(h.id,h.record_id,h.version,h.created_at,c.item) dto,
      h.created_at,h.id event_id,c.ordinality from private.dopmi_rescue_history h
      cross join lateral jsonb_array_elements(case when jsonb_typeof(h.snapshot->'_need_comments')='array'
        then h.snapshot->'_need_comments' else '[]'::jsonb end) with ordinality c(item,ordinality)
      where h.record_id=r.id and h.action='need_comments' and (c.item->>'target_kind'='planned' or exists(
        select 1 from private.dopmi_case_need_submission_expenses e where e.submission_id=s.id
          and e.expense_id::text=c.item->>'target_id' and e.expense_version=(c.item->>'target_version')::integer
          and c.item->>'target_kind'='expense'))
      order by h.created_at desc,h.id desc,c.ordinality desc limit 100) x;
  for child in select (jsonb_populate_record(null::public.dopmi_rescue_records,e.snapshot)).* 
    from private.dopmi_case_need_submission_expenses e where e.submission_id=s.id
      and (children @> jsonb_build_array(jsonb_build_object('id',e.expense_id)) or exists(
        select 1 from jsonb_array_elements(comments) c where c->>'target_kind'='expense' and c->>'target_id'=e.expense_id::text))
  loop
    if child.owner_id<>auth.uid() then perform private.dopmi_rescue_audit(child,'read','Consulta de paquete inicial de necesidades'); end if;
  end loop;
  return result||jsonb_build_object('initial_packet',jsonb_build_object('id',s.id,'case_version',r.version,
      'source_case_version',s.source_case_version,'expense_ids',ids),
    'expenses',jsonb_build_object('total',total,'page',expense_page,'items',children),'need_comments',comments);
end;
$$;

-- Extend only target resolution of the established, idempotent comments RPC.
-- The current manifest is the authority; a later DRAFT is never a target.
do $patch$
declare definition text; old_fragment text:=$old$        select * into expense from public.dopmi_rescue_records e
          where e.id=target and e.kind='expense' and e.parent_id=r.id and e.owner_id=r.owner_id
            and e.status not in ('draft','pending_stripe') for update;$old$;
begin
  definition:=replace(pg_get_functiondef('public.dopmi_comment_case_needs(uuid,integer,jsonb,uuid)'::regprocedure),E'\r\n',E'\n');
  old_fragment:=replace(old_fragment,E'\r\n',E'\n');
  if (length(definition)-length(replace(definition,old_fragment,'')))/length(old_fragment)<>1 then
    raise exception 'Initial packet: unexpected comments function';
  end if;
  execute replace(definition,old_fragment,$new$        if (private.dopmi_initial_case_submission(r)).id is not null then
          select (jsonb_populate_record(null::public.dopmi_rescue_records,e.snapshot)).* into expense
            from private.dopmi_case_need_submission_expenses e
            where e.submission_id=(private.dopmi_initial_case_submission(r)).id and e.expense_id=target;
        else
          select * into expense from public.dopmi_rescue_records e
            where e.id=target and e.kind='expense' and e.parent_id=r.id and e.owner_id=r.owner_id
              and e.status not in ('draft','pending_stripe') for update;
        end if;$new$);
end;
$patch$;

do $copy$ begin
  execute replace(pg_get_functiondef('public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean)'::regprocedure),
    'FUNCTION public.dopmi_review_rescue(', 'FUNCTION public.dopmi_review_rescue_before_initial_packet(');
end; $copy$;
revoke all on function public.dopmi_review_rescue_before_initial_packet(uuid,integer,text,text,bigint,boolean,text,boolean)
  from public,anon,authenticated,service_role;
create or replace function public.dopmi_review_rescue(record_id uuid, expected_version integer, decision text, note text,
  amount_cents bigint default 0,is_urgent boolean default false,urgency_note text default '',publish_content boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; parent public.dopmi_rescue_records; person uuid;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select owner_id into person from public.dopmi_rescue_records where id=record_id;
  if person is not null then perform private.dopmi_rescue_lock(person); end if;
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into r from public.dopmi_rescue_records where id=record_id;
  if r.owner_id=auth.uid() then raise exception 'Otra persona del equipo debe revisar tu solicitud' using errcode='42501'; end if;
  if r.kind='case' and exists(select 1 from private.dopmi_case_need_submission_expenses e
    where e.submission_id=(private.dopmi_initial_case_submission(r)).id) then
    raise exception 'Revisa el caso y todas sus necesidades en el paquete inicial' using errcode='22023';
  elsif r.kind='expense' then
    select * into parent from public.dopmi_rescue_records where id=r.parent_id;
    if exists(select 1 from private.dopmi_case_need_submission_expenses e
      where e.submission_id=(private.dopmi_initial_case_submission(parent)).id and e.expense_id=r.id) then
      raise exception 'Esta necesidad se revisa junto con su caso' using errcode='22023';
    end if;
  end if;
  return public.dopmi_review_rescue_before_initial_packet(record_id,expected_version,decision,note,
    amount_cents,is_urgent,urgency_note,publish_content);
end;
$$;

create function public.dopmi_review_initial_case_packet(record_id uuid,expected_version integer,submission_id uuid,
  decision text,note text,publish_content boolean,expense_reviews jsonb,request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); person uuid; r public.dopmi_rescue_records; expense public.dopmi_rescue_records;
  s private.dopmi_case_need_submissions; item jsonb; intent jsonb; normalized jsonb; result jsonb;
  reviewed jsonb:='[]'; record_result jsonb; total integer; seen uuid[]:='{}'; expense_id uuid;
begin
  if actor is null or not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select owner_id into person from public.dopmi_rescue_records where id=record_id;
  if person is null then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
  perform private.dopmi_rescue_lock(person);
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into r from public.dopmi_rescue_records where id=record_id for update;
  if not found or r.kind<>'case' or r.owner_id=actor or r.status in ('draft','pending_stripe') then
    raise exception 'Solicitud no disponible' using errcode='42501';
  end if;
  if request_id is null or submission_id is null or expected_version is null
    or decision is null or decision not in ('approved','changes_requested','rejected')
    or note is null or char_length(btrim(note)) not between 5 and 2000 or publish_content is null
    or jsonb_typeof(expense_reviews) is distinct from 'array' or octet_length(expense_reviews::text)>1000000 then
    raise exception 'Revisa la decisión y sus necesidades' using errcode='22023';
  end if;
  for item in select value from jsonb_array_elements(expense_reviews) loop
    if jsonb_typeof(item) is distinct from 'object'
      or not(item ?& array['expense_id','expense_version','amount_cents','is_urgent','urgency_note','publish_content'])
      or (item-'expense_id'-'expense_version'-'amount_cents'-'is_urgent'-'urgency_note'-'publish_content')<>'{}'::jsonb
      or jsonb_typeof(item->'expense_id') is distinct from 'string'
      or coalesce(item->>'expense_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or jsonb_typeof(item->'expense_version') is distinct from 'number'
      or coalesce(item->>'expense_version','') !~ '^[0-9]{1,10}$'
      or (item->>'expense_version')::bigint not between 1 and 2147483647
      or jsonb_typeof(item->'amount_cents') is distinct from 'number'
      or coalesce(item->>'amount_cents','') !~ '^[0-9]{1,9}$'
      or (item->>'amount_cents')::bigint<1
      or jsonb_typeof(item->'is_urgent') is distinct from 'boolean'
      or jsonb_typeof(item->'publish_content') is distinct from 'boolean'
      or jsonb_typeof(item->'urgency_note') is distinct from 'string'
      or char_length(item->>'urgency_note')>1000 then
      raise exception 'Indica explícitamente monto, urgencia y publicación por necesidad' using errcode='22023';
    end if;
    expense_id:=(item->>'expense_id')::uuid;
    if expense_id=any(seen) then raise exception 'Necesidad repetida' using errcode='22023'; end if;
    seen:=array_append(seen,expense_id);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('expense_id',(i->>'expense_id')::uuid,
      'expense_version',(i->>'expense_version')::integer,'amount_cents',(i->>'amount_cents')::bigint,
      'is_urgent',(i->>'is_urgent')::boolean,'urgency_note',btrim(i->>'urgency_note'),
      'publish_content',(i->>'publish_content')::boolean) order by (i->>'expense_id')::uuid),'[]') into normalized
    from jsonb_array_elements(expense_reviews) i;
  intent:=jsonb_build_object('record_id',record_id,'expected_version',expected_version,'submission_id',submission_id,
    'decision',decision,'note',btrim(note),'publish_content',publish_content,'expense_reviews',normalized);
  select * into s from private.dopmi_case_need_submissions p where p.decision_request_id=request_id;
  if found then
    if s.case_id<>record_id or s.id<>submission_id or s.decision_actor_id<>actor or s.decision_input is distinct from intent then
      raise exception 'Identificador de solicitud no disponible' using errcode='22023';
    end if;
    return s.decision_result;
  end if;
  select * into s from private.dopmi_case_need_submissions p where p.id=submission_id and p.case_id=r.id and p.owner_id=r.owner_id for update;
  if not found or r.version<>expected_version or s.review_case_version<>r.version
    or s.decision_request_id is not null or (private.dopmi_initial_case_submission(r)).id is distinct from s.id then
    raise exception 'El paquete cambió. Recarga antes de continuar' using errcode='40001';
  end if;
  if r.public_data is distinct from s.case_snapshot->'public_data'
    or r.private_data is distinct from s.case_snapshot->'private_data'
    or r.files is distinct from s.case_snapshot->'files' then
    raise exception 'El caso cambió. Recarga antes de continuar' using errcode='40001';
  end if;
  if decision<>'approved' then
    if jsonb_array_length(normalized)<>0 then raise exception 'La corrección o rechazo no aprueba gastos' using errcode='22023'; end if;
  else
    select count(*) into total from private.dopmi_case_need_submission_expenses e where e.submission_id=s.id;
    if total<>jsonb_array_length(normalized) or exists(select 1 from private.dopmi_case_need_submission_expenses e
      where e.submission_id=s.id and not exists(select 1 from jsonb_array_elements(normalized) i
        where (i->>'expense_id')::uuid=e.expense_id and (i->>'expense_version')::integer=e.expense_version)) then
      raise exception 'Revisa todas las necesidades del paquete exacto' using errcode='40001';
    end if;
    -- Lock the exact rows in UUID order and reject any changed source before a
    -- single approval. Current drafts outside this manifest are left private.
    for expense in select e.* from public.dopmi_rescue_records e
      join private.dopmi_case_need_submission_expenses p on p.expense_id=e.id
      where p.submission_id=s.id order by e.id for update of e loop
      if expense.owner_id<>r.owner_id or expense.parent_id<>r.id or expense.kind<>'expense'
        or expense.status not in ('draft','changes_requested','rejected') or not exists(
          select 1 from private.dopmi_case_need_submission_expenses p where p.submission_id=s.id
            and p.expense_id=expense.id and p.expense_version=expense.version and p.snapshot=to_jsonb(expense)) then
        raise exception 'Una necesidad cambió. Recarga antes de continuar' using errcode='40001';
      end if;
      perform private.dopmi_rescue_validate(expense);
    end loop;
  end if;
  record_result:=public.dopmi_review_rescue_before_initial_packet(r.id,r.version,decision,btrim(note),0,false,'',publish_content);
  if decision='approved' then
    -- All are promoted before validation/review so duplicate receipts among
    -- siblings are caught by the existing validator. Audit names the real staff
    -- actor; it never impersonates the owner or a Stripe system event.
    for expense in select e.* from public.dopmi_rescue_records e
      join private.dopmi_case_need_submission_expenses p on p.expense_id=e.id
      where p.submission_id=s.id order by e.id loop
      update public.dopmi_rescue_records set status='submitted',submitted_at=now(),version=version+1,updated_at=now()
        where id=expense.id returning * into expense;
      perform private.dopmi_rescue_audit(expense,'initial_packet_submit','Envío compartido en el paquete inicial del caso');
    end loop;
    for item in select value from jsonb_array_elements(normalized) loop
      select * into expense from public.dopmi_rescue_records where id=(item->>'expense_id')::uuid;
      reviewed:=reviewed||jsonb_build_array(public.dopmi_review_rescue_before_initial_packet(expense.id,expense.version,
        'approved',btrim(note),(item->>'amount_cents')::bigint,(item->>'is_urgent')::boolean,
        item->>'urgency_note',(item->>'publish_content')::boolean));
    end loop;
  end if;
  result:=jsonb_build_object('request_id',request_id,'submission_id',s.id,'record_id',r.id,
    'case_version',expected_version,'decision',decision,'record',record_result,'expenses',reviewed);
  begin
    update private.dopmi_case_need_submissions set decision_request_id=request_id,decision_actor_id=actor,
      decision_input=intent,decision_result=result where id=s.id;
  exception when unique_violation then
    raise exception 'Identificador de solicitud no disponible' using errcode='22023';
  end;
  return result;
end;
$$;

revoke all on function private.dopmi_initial_case_submission(public.dopmi_rescue_records),
  private.dopmi_initial_case_capture(public.dopmi_rescue_records),private.dopmi_initial_case_stripe_promoted(),
  private.dopmi_initial_case_freeze_expense(),private.dopmi_initial_case_prevent_expense_delete()
  from public,anon,authenticated,service_role;
revoke all on function public.dopmi_transition_rescue(uuid,integer,text),public.dopmi_admin_rescue_packet(uuid,integer),
  public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean),
  public.dopmi_review_initial_case_packet(uuid,integer,uuid,text,text,boolean,jsonb,uuid),
  public.dopmi_rescue_file_access(text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_transition_rescue(uuid,integer,text),public.dopmi_admin_rescue_packet(uuid,integer),
  public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean),
  public.dopmi_review_initial_case_packet(uuid,integer,uuid,text,text,boolean,jsonb,uuid) to authenticated;
grant execute on function public.dopmi_rescue_file_access(text,boolean) to anon,authenticated;

commit;
