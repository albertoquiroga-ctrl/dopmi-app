begin;

-- A published case is one fixed set. Mutable approval timestamps are not proof
-- that a case has never been published (moderators may withdraw unsafe content).
create function private.dopmi_case_ever_approved(case_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.dopmi_rescue_history h where h.record_id=$1 and h.action='approved')
    or exists(select 1 from private.dopmi_case_need_submissions s where s.case_id=$1 and s.decision_input->>'decision'='approved');
$$;
create function private.dopmi_case_expense_locked(expense_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.dopmi_donations where expense_id=$1)
    or exists(select 1 from private.dopmi_case_allocations where expense_id=$1)
    or exists(select 1 from private.dopmi_guardian_allocations where expense_id=$1);
$$;
create function private.dopmi_case_unit(r public.dopmi_rescue_records) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare c public.dopmi_rescue_records; s private.dopmi_case_need_submissions; approved boolean; editable boolean;
begin
  if r.kind='verification' then return null; end if;
  if r.kind='case' then c:=r; else select * into c from public.dopmi_rescue_records where id=r.parent_id; end if;
  approved:=private.dopmi_case_ever_approved(c.id);
  editable:=c.status in ('draft','changes_requested','rejected') and not approved;
  s:=private.dopmi_initial_case_submission(c);
  return jsonb_build_object('case_id',c.id,'case_version',c.version,'case_status',c.status,
    'public_version_visible',c.status='approved' and c.approved_snapshot is not null,
    'can_start_revision',approved and c.status in ('approved','changes_requested') and not exists(select 1 from private.dopmi_support_archives ar where ar.record_id=c.id),
    'revision_recovery',approved and c.status='changes_requested',
    'case_archived',exists(select 1 from private.dopmi_support_archives ar where ar.record_id=c.id),'ever_approved',approved,
    'needs_frozen',not editable,'case_editable',editable,'needs_editable',editable and (r.kind='case' or r.status in ('draft','changes_requested','rejected')),
    'can_add_needs',editable,'pending_submission_id',s.id,
    'expense_ids',case when s.id is not null then (select coalesce(jsonb_agg(e.expense_id order by e.expense_id),'[]') from private.dopmi_case_need_submission_expenses e where e.submission_id=s.id) end,
    'expense_versions',case when s.id is not null then (select coalesce(jsonb_object_agg(e.expense_id::text,e.expense_version),'{}') from private.dopmi_case_need_submission_expenses e where e.submission_id=s.id) end);
end;
$$;

-- Copied delegates are private implementation details. Replacing entry points
-- preserves their OIDs and every effective pre-existing ACL, including SQL61.
do $copy$ declare signature text; definition text; name text;
begin
  foreach signature in array array[
    'public.dopmi_save_rescue(text,jsonb,jsonb,jsonb,uuid,integer,uuid)',
    'public.dopmi_transition_rescue(uuid,integer,text)',
    'public.dopmi_remove_draft_expense(uuid,integer)',
    'public.dopmi_rescue_detail(uuid)',
    'public.dopmi_rescue_file_access(text,boolean)',
    'public.dopmi_admin_rescue(text,text,integer)'] loop
    name:=split_part(split_part(signature,'.',2),'(',1);
    definition:=replace(pg_get_functiondef(signature::regprocedure),'FUNCTION public.'||name||'(', 'FUNCTION public.'||name||'_before_fixed_case(');
    execute definition;
    execute 'revoke all on function '||replace(signature,name||'(',name||'_before_fixed_case(')||' from public,anon,authenticated,service_role';
  end loop;
end $copy$;

create or replace function public.dopmi_save_rescue(record_kind text,public_fields jsonb,private_fields jsonb,attachments jsonb,
  target_id uuid default null,expected_version integer default null,case_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); c public.dopmi_rescue_records;
begin
  perform private.dopmi_rescue_lock(actor);
  if record_kind='expense' then
    select * into c from public.dopmi_rescue_records where id=case_id and owner_id=actor and kind='case';
    if found and (c.status in ('submitted','pending_stripe','closed') or private.dopmi_case_ever_approved(c.id)) then
      raise exception 'Las necesidades se corrigen junto con su caso. Para otra necesidad crea un caso nuevo' using errcode='22023';
    end if;
  elsif record_kind='case' and target_id is not null and exists(select 1 from public.dopmi_rescue_records where id=target_id and owner_id=actor)
    and private.dopmi_case_ever_approved(target_id) then
    raise exception 'Prepara una edición del caso con su motivo' using errcode='22023';
  end if;
  return public.dopmi_save_rescue_before_fixed_case(record_kind,public_fields,private_fields,attachments,target_id,expected_version,case_id);
end;
$$;
create or replace function public.dopmi_transition_rescue(record_id uuid,expected_version integer,action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); r public.dopmi_rescue_records; c public.dopmi_rescue_records;
begin
  perform private.dopmi_rescue_lock(actor);
  select * into r from public.dopmi_rescue_records where id=record_id;
  if r.owner_id=actor and r.kind='expense' then
    select * into c from public.dopmi_rescue_records where id=r.parent_id;
    if action is distinct from 'withdraw' or r.status<>'submitted' or private.dopmi_case_expense_locked(r.id)
      or exists(select 1 from private.dopmi_case_need_submission_expenses e where e.expense_id=r.id and e.submission_id=(private.dopmi_initial_case_submission(c)).id) then
      raise exception 'Esta necesidad se envía y revisa junto con su caso' using errcode='22023';
    end if;
  elsif r.owner_id=actor and r.kind='case' and action='submit' and private.dopmi_case_ever_approved(r.id) then
    raise exception 'Envía una edición completa del caso con su motivo' using errcode='22023';
  end if;
  return public.dopmi_transition_rescue_before_fixed_case(record_id,expected_version,action);
end;
$$;
create or replace function public.dopmi_remove_draft_expense(record_id uuid,expected_version integer) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); r public.dopmi_rescue_records; c public.dopmi_rescue_records;
begin
  perform private.dopmi_rescue_lock(actor);
  select * into r from public.dopmi_rescue_records where id=record_id and owner_id=actor;
  select * into c from public.dopmi_rescue_records where id=r.parent_id;
  if c.status in ('submitted','pending_stripe') or private.dopmi_case_ever_approved(c.id) then
    raise exception 'Las necesidades forman parte de un caso fijo' using errcode='22023'; end if;
  perform public.dopmi_remove_draft_expense_before_fixed_case(record_id,expected_version);
end;
$$;
create function private.dopmi_fixed_case_membership_guard() returns trigger
language plpgsql set search_path='' as $$
begin
  if tg_op='UPDATE' and old.kind='expense' and (new.parent_id is distinct from old.parent_id or new.owner_id is distinct from old.owner_id or new.kind is distinct from old.kind)
    and private.dopmi_case_ever_approved(old.parent_id) then
    raise exception 'Una necesidad publicada conserva su caso y propietario' using errcode='22023'; end if;
  if new.kind='expense' and (tg_op='INSERT' or new.parent_id is distinct from old.parent_id or new.owner_id is distinct from old.owner_id or old.kind<>'expense')
    and exists(select 1 from public.dopmi_rescue_records c where c.id=new.parent_id and private.dopmi_case_ever_approved(c.id)) then
    raise exception 'Un caso publicado conserva sus necesidades. Crea otro caso para una nueva' using errcode='22023'; end if;
  return new;
end;
$$;
create trigger dopmi_fixed_case_membership_guard before insert or update on public.dopmi_rescue_records
  for each row execute function private.dopmi_fixed_case_membership_guard();

create or replace function public.dopmi_review_rescue(record_id uuid,expected_version integer,decision text,note text,
  amount_cents bigint default 0,is_urgent boolean default false,urgency_note text default '',publish_content boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; person uuid;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select owner_id into person from public.dopmi_rescue_records where id=record_id;
  if person is not null then perform private.dopmi_rescue_lock(person); end if;
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into r from public.dopmi_rescue_records where id=record_id;
  if r.owner_id=auth.uid() then raise exception 'Otra persona del equipo debe revisar tu solicitud' using errcode='42501'; end if;
  if r.kind='expense' then raise exception 'Esta necesidad se revisa junto con su caso' using errcode='22023'; end if;
  if r.kind='case' and (exists(select 1 from private.dopmi_case_need_submission_expenses e where e.submission_id=(private.dopmi_initial_case_submission(r)).id)
    or (decision='approved' and exists(select 1 from public.dopmi_rescue_records where parent_id=r.id))) then
    raise exception 'Reenvía y revisa el caso con todas sus necesidades' using errcode='22023'; end if;
  return public.dopmi_review_rescue_before_initial_packet(record_id,expected_version,decision,note,amount_cents,is_urgent,urgency_note,publish_content);
end;
$$;
-- Keep exact historical replays valid, while every NEW decision must approve
-- the entire paid amount. The delegated financial validations remain in force.
do $patch$ declare definition text; anchor text:='    -- Lock the exact rows in UUID order and reject any changed source before a';
begin
  definition:=replace(pg_get_functiondef('public.dopmi_review_initial_case_packet(uuid,integer,uuid,text,text,boolean,jsonb,uuid)'::regprocedure),E'\r\n',E'\n');
  if position(anchor in definition)=0 then raise exception 'Fixed case: unexpected initial packet review'; end if;
  execute replace(definition,anchor,$new$    if exists(select 1 from private.dopmi_case_need_submission_expenses e
      join jsonb_array_elements(normalized) i on (i->>'expense_id')::uuid=e.expense_id
      where e.submission_id=s.id and (i->>'amount_cents')::bigint is distinct from (e.snapshot->'private_data'->>'amount_cents')::bigint) then
      raise exception 'Aprueba los importes completos respaldados o devuelve todo el caso' using errcode='22023';
    end if;
$new$||anchor);
end $patch$;

create table private.dopmi_case_revisions (
  id uuid primary key default gen_random_uuid(),case_id uuid not null references public.dopmi_rescue_records(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  base_case_version integer not null,version integer not null default 1 check(version>0),
  status text not null default 'draft' check(status in ('draft','submitted','changes_requested','rejected','approved','invalidated')),
  reason text not null default '',feedback text not null default '',
  source_case jsonb not null,proposed_case jsonb not null,source_expenses jsonb not null,proposed_expenses jsonb not null,
  source_media jsonb not null default '[]',file_objects jsonb not null default '[]',
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),submitted_at timestamptz,
  check(jsonb_typeof(source_expenses)='array' and jsonb_typeof(proposed_expenses)='array'),
  check(octet_length(proposed_case::text)+octet_length(proposed_expenses::text)<=1000000)
);
create unique index dopmi_case_one_open_revision on private.dopmi_case_revisions(case_id)
  where status in ('draft','submitted','changes_requested','rejected');
create table private.dopmi_case_revision_files (
  path text primary key,revision_id uuid not null references private.dopmi_case_revisions(id) on delete cascade,
  record_id uuid not null references public.dopmi_rescue_records(id) on delete cascade,role text not null
);
create table private.dopmi_case_revision_requests (
  request_id uuid primary key,revision_id uuid not null references private.dopmi_case_revisions(id) on delete cascade,
  actor_id uuid not null,input jsonb not null,result jsonb not null
);
alter table private.dopmi_case_revisions enable row level security;
alter table private.dopmi_case_revision_files enable row level security;
alter table private.dopmi_case_revision_requests enable row level security;
revoke all on private.dopmi_case_revisions,private.dopmi_case_revision_files,private.dopmi_case_revision_requests from public,anon,authenticated,service_role;

create function private.dopmi_case_revision_actor(staff boolean default false) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); session_value text;
begin
  perform private.dopmi_require_current_legal(actor);
  session_value:=coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'session_id',nullif(current_setting('request.jwt.claim.session_id',true),''));
  if session_value is null or session_value !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    or not exists(select 1 from auth.sessions s where s.id=session_value::uuid and s.user_id=actor and (s.not_after is null or s.not_after>now()))
    or (staff and not public.dopmi_is_admin()) then
    raise exception 'Sesión vigente y permisos requeridos' using errcode='42501'; end if;
  return actor;
end;
$$;
create function private.dopmi_case_revision_authorize(revision_id uuid,staff boolean default false) returns private.dopmi_case_revisions
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_case_revision_actor(staff); v private.dopmi_case_revisions; c public.dopmi_rescue_records;
begin
  select * into v from private.dopmi_case_revisions where id=$1;
  if not found or (not staff and v.owner_id<>actor) or (staff and v.owner_id=actor) then
    raise exception 'Edición no disponible' using errcode='42501'; end if;
  perform private.dopmi_rescue_lock(v.owner_id);
  perform private.dopmi_case_revision_actor(staff);
  select * into v from private.dopmi_case_revisions where id=$1 for update;
  select * into c from public.dopmi_rescue_records where id=v.case_id for update;
  if not public.dopmi_actor_active() or not private.dopmi_support_owner_active(v.owner_id) then
    raise exception 'El rescatista debe conservar su cuenta activa y correo confirmado' using errcode='42501'; end if;
  perform private.dopmi_require_current_legal(v.owner_id);
  if c.owner_id<>v.owner_id or exists(select 1 from private.dopmi_support_archives ar where ar.record_id=c.id)
    or (v.status='approved' and c.status<>'approved')
    or (v.status<>'approved' and (c.status not in ('approved','changes_requested') or c.status is distinct from v.source_case->>'status'
      or c.version<>v.base_case_version or not private.dopmi_case_ever_approved(c.id))) then
    -- No unsafe old snapshot can be republished by an outstanding edit.
    raise exception 'El caso cambió o fue retirado. Esta edición ya no está disponible' using errcode='40001'; end if;
  return v;
end;
$$;
create function private.dopmi_case_revision_replay(revision_id uuid,request_id uuid,intent jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare saved private.dopmi_case_revision_requests;
begin
  if request_id is null then raise exception 'Identificador de solicitud requerido' using errcode='22023'; end if;
  select * into saved from private.dopmi_case_revision_requests q where q.request_id=$2;
  if not found then return null; end if;
  if saved.revision_id<>$1 or saved.actor_id<>auth.uid() or saved.input is distinct from intent then
    raise exception 'Identificador de solicitud no disponible' using errcode='22023'; end if;
  return saved.result;
end;
$$;
create function private.dopmi_case_revision_remember(revision_id uuid,request_id uuid,intent jsonb,result jsonb) returns void
language plpgsql set search_path='' as $$
begin
  insert into private.dopmi_case_revision_requests values(request_id,revision_id,auth.uid(),intent,result);
exception when unique_violation then raise exception 'Identificador de solicitud no disponible' using errcode='22023';
end;
$$;
create function private.dopmi_case_revision_media(v private.dopmi_case_revisions) returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('asset',to_jsonb(a),'cleanup_queued',exists(
    select 1 from private.dopmi_video_deletion_queue q where q.provider_id=a.provider_id)) order by a.id),'[]')
  from private.dopmi_video_assets a where a.owner_id=v.owner_id and (a.parent_id=v.case_id or exists(
    select 1 from jsonb_array_elements(v.source_expenses) e where e->>'id'=a.parent_id::text));
$$;
create function private.dopmi_case_revision_objects(v private.dopmi_case_revisions) returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'bucket_id',o.bucket_id,'name',o.name,'metadata',o.metadata,
    'version',to_jsonb(o)->'version','updated_at',to_jsonb(o)->'updated_at') order by o.name),'[]')
  from storage.objects o where o.bucket_id='dopmi-rescue-evidence' and o.name in (
    select f->>'path' from jsonb_array_elements(v.proposed_case->'files') f
    union select f->>'path' from jsonb_array_elements(v.proposed_expenses) e cross join lateral jsonb_array_elements(e->'files') f);
$$;
create function private.dopmi_case_revision_packet(v private.dopmi_case_revisions,expense_page integer default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare expenses jsonb; comments jsonb;
begin
  select coalesce(jsonb_agg(e||jsonb_build_object('financial_locked',private.dopmi_case_expense_locked((e->>'id')::uuid),'financial_inactive',s->>'status'<>'approved',
    'locked_fields',case when private.dopmi_case_expense_locked((e->>'id')::uuid) then '["amount_cents","paid_on","vendor","receipt_reference","files"]'::jsonb else '[]'::jsonb end,
    'review_amount_cents',case when s->>'status'<>'approved' then 0 when (e->'private_data'->>'amount_cents')::bigint=(s->'private_data'->>'amount_cents')::bigint
      then (s->>'reimbursable_cents')::bigint else (e->'private_data'->>'amount_cents')::bigint end) order by e->>'id'),'[]') into expenses
    from (select value e from jsonb_array_elements(v.proposed_expenses) order by value->>'id'
      limit case when expense_page is null then null else 20 end offset case when expense_page is null then 0 else (expense_page-1)*20 end) p
    join jsonb_array_elements(v.source_expenses) s on s->>'id'=e->>'id';
  select coalesce(jsonb_agg(private.dopmi_need_comment_dto(h.id,h.record_id,h.version,h.created_at,c.item) order by h.created_at desc,h.id desc),'[]') into comments
    from private.dopmi_rescue_history h cross join lateral jsonb_array_elements(coalesce(h.snapshot->'_need_comments','[]')) c(item)
    where h.record_id=v.case_id and h.snapshot->>'_case_revision_id'=v.id::text;
  return jsonb_build_object('revision',to_jsonb(v)-'source_case'-'proposed_case'-'source_expenses'-'proposed_expenses'-'source_media'-'file_objects',
    'record',v.proposed_case,'base_record',v.source_case,
    'expenses',jsonb_build_object('total',jsonb_array_length(v.proposed_expenses),'page',coalesce(expense_page,1),'items',expenses),
    'expense_ids',(select coalesce(jsonb_agg(e->'id' order by e->>'id'),'[]') from jsonb_array_elements(v.source_expenses) e),
    'expense_versions',(select coalesce(jsonb_object_agg(e->>'id',e->'version'),'{}') from jsonb_array_elements(v.source_expenses) e),
    'case_unit',(select private.dopmi_case_unit(r) from public.dopmi_rescue_records r where r.id=v.case_id),
    'public_version_visible',(select r.status='approved' and r.approved_snapshot is not null from public.dopmi_rescue_records r where r.id=v.case_id),
    'publication_blockers',case when v.source_case->>'status'='changes_requested' and (v.proposed_case->>'video_thanks_required')::boolean
      and (select enabled from private.dopmi_video_settings where singleton) and not exists(
        select 1 from private.dopmi_video_assets a where a.parent_id=v.case_id and a.purpose='thanks' and a.technical_state='ready'
          and a.moderation_state='approved' and a.content_snapshot=private.dopmi_video_content((jsonb_populate_record(null::public.dopmi_rescue_records,v.source_case)))
          and not exists(select 1 from private.dopmi_video_deletion_queue q where q.provider_id=a.provider_id))
      then '["approved_thanks_required"]'::jsonb else '[]'::jsonb end,
    'need_comments',comments,'preserved_media',(select coalesce(jsonb_agg(jsonb_build_object('id',a->'asset'->'id',
      'parent_id',a->'asset'->'parent_id','purpose',a->'asset'->'purpose')),'[]')
      from jsonb_array_elements(private.dopmi_case_revision_media(v)) a
      where a->'asset'->>'technical_state'='ready' and a->'asset'->>'moderation_state'='approved'
        and a->'cleanup_queued'='false'::jsonb));
end;
$$;

create function public.dopmi_case_revision(record_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_case_revision_actor(); v private.dopmi_case_revisions;
begin
  if not exists(select 1 from public.dopmi_rescue_records where id=record_id and owner_id=actor and kind='case') then
    raise exception 'Caso no disponible' using errcode='42501'; end if;
  select * into v from private.dopmi_case_revisions where case_id=record_id and owner_id=actor order by created_at desc,id desc limit 1;
  if not found then return null; end if;
  return private.dopmi_case_revision_packet(v);
end;
$$;
create function public.dopmi_start_case_revision(record_id uuid,expected_version integer,request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_case_revision_actor(); c public.dopmi_rescue_records; v private.dopmi_case_revisions;
  expenses jsonb; intent jsonb; replay jsonb; saved private.dopmi_case_revision_requests;
begin
  perform private.dopmi_rescue_lock(actor);
  perform private.dopmi_case_revision_actor();
  select * into c from public.dopmi_rescue_records where id=record_id and owner_id=actor and kind='case' for update;
  if not found or c.status not in ('approved','changes_requested') or not private.dopmi_case_ever_approved(c.id) or not private.dopmi_support_owner_active(actor)
    or exists(select 1 from private.dopmi_support_archives ar where ar.record_id=c.id) then raise exception 'Caso aprobado y cuenta activa requeridos' using errcode='42501'; end if;
  if request_id is null then raise exception 'Identificador de solicitud requerido' using errcode='22023'; end if;
  intent:=jsonb_build_object('operation','start','record_id',record_id,'expected_version',expected_version);
  select * into saved from private.dopmi_case_revision_requests q where q.request_id=$3;
  if found then
    perform private.dopmi_case_revision_authorize(saved.revision_id);
    return private.dopmi_case_revision_replay(saved.revision_id,request_id,intent);
  end if;
  if c.version is distinct from expected_version then raise exception 'El caso cambió. Recarga antes de editar' using errcode='40001'; end if;
  select * into v from private.dopmi_case_revisions where case_id=c.id and status in ('draft','submitted','changes_requested','rejected');
  if found then raise exception 'Este caso ya tiene una edición. Abre la edición existente' using errcode='40001'; end if;
  perform 1 from public.dopmi_rescue_records where parent_id=c.id and owner_id=actor and kind='expense' order by id for update;
  -- Freeze the union of exact approved manifests and unequivocally approved
  -- legacy children. Never infer membership from a title/date or a late draft.
  select coalesce(jsonb_agg(to_jsonb(e) order by e.id),'[]') into expenses from public.dopmi_rescue_records e
    where e.parent_id=c.id and e.owner_id=actor and e.kind='expense' and (
      e.approved_snapshot is not null or exists(select 1 from private.dopmi_rescue_history h where h.record_id=e.id and h.action='approved'
        and h.snapshot->>'parent_id'=c.id::text and h.snapshot->>'owner_id'=actor::text)
      or exists(select 1 from private.dopmi_case_need_submission_expenses se join private.dopmi_case_need_submissions cs on cs.id=se.submission_id
        where se.expense_id=e.id and cs.case_id=c.id and cs.owner_id=actor and cs.decision_input->>'decision'='approved'));
  insert into private.dopmi_case_revisions(case_id,owner_id,base_case_version,source_case,proposed_case,source_expenses,proposed_expenses)
    values(c.id,actor,c.version,to_jsonb(c),to_jsonb(c),expenses,expenses) returning * into v;
  replay:=private.dopmi_case_revision_packet(v);
  perform private.dopmi_case_revision_remember(v.id,request_id,intent,replay);
  return replay;
end;
$$;

create function private.dopmi_case_revision_normalize(source jsonb,fields jsonb,v private.dopmi_case_revisions) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; pub jsonb; roles text[]; coarse numeric[]; field text;
begin
  r:=jsonb_populate_record(null::public.dopmi_rescue_records,source);
  if jsonb_typeof(fields) is distinct from 'object' or not(fields ?& array['public_data','private_data','files'])
    or fields-'id'-'public_data'-'private_data'-'files'<>'{}'::jsonb then
    raise exception 'Envía todos los datos de cada necesidad y del caso' using errcode='22023'; end if;
  pub:=fields->'public_data';
  if r.kind='case' then
    coarse:=private.dopmi_coarse_pet_location(pub);
    coarse:=private.dopmi_preserve_fine_pet_location(coarse,r.approximate_latitude,r.approximate_longitude,(pub->'location_precision_version'='1'::jsonb) is true);
    if coarse is not null then r.approximate_latitude:=coarse[1]; r.approximate_longitude:=coarse[2]; end if;
    pub:=pub-'approximate_latitude'-'approximate_longitude'-'location_precision_version';
    if not pub ? 'size' and r.public_data ? 'size' then pub:=pub||jsonb_build_object('size',r.public_data->'size'); end if;
    pub:=private.dopmi_case_fields(pub);
    -- Planned needs are fixed IDs too; an edit cannot smuggle in a new need.
    if (select coalesce(jsonb_agg(x->>'id' order by x->>'id'),'[]') from jsonb_array_elements(coalesce(pub->'need_items','[]')) x)
      is distinct from (select coalesce(jsonb_agg(x->>'id' order by x->>'id'),'[]') from jsonb_array_elements(coalesce(r.public_data->'need_items','[]')) x) then
      raise exception 'Una necesidad nueva requiere un caso nuevo' using errcode='22023'; end if;
    r.private_data:=private.dopmi_rescue_fields(fields->'private_data',array[]::text[]); roles:=array['public'];
  else
    pub:=private.dopmi_rescue_fields(pub,array['title','description','category','round_label']);
    r.private_data:=private.dopmi_rescue_fields(fields->'private_data',array['paid_on','vendor','amount_cents','receipt_reference','urgency_reason']);
    if coalesce(r.private_data->>'amount_cents','') !~ '^[0-9]{1,9}$' or (r.private_data->>'amount_cents')::bigint not between 1 and 100000000 then
      raise exception 'Indica un importe positivo en centavos enteros' using errcode='22023'; end if;
    roles:=array['receipt','proof','public'];
    if private.dopmi_case_expense_locked(r.id) then
      foreach field in array array['amount_cents','paid_on','vendor','receipt_reference'] loop
        if r.private_data->field is distinct from source->'private_data'->field then
          raise exception 'Esta necesidad tiene vínculos financieros. Conserva importe y comprobante' using errcode='22023'; end if;
      end loop;
      if fields->'files' is distinct from r.files then raise exception 'Conserva los archivos de esta necesidad con vínculos financieros' using errcode='22023'; end if;
    end if;
  end if;
  if jsonb_typeof(fields->'files') is distinct from 'array' or jsonb_array_length(fields->'files')>12
    or exists(select 1 from jsonb_array_elements(fields->'files') f where jsonb_typeof(f) is distinct from 'object'
      or f-'path'-'role'<>'{}'::jsonb or not coalesce(f->>'role','')=any(roles)
      or not ((source->'files') @> jsonb_build_array(f) or exists(select 1 from private.dopmi_case_revision_files rf
        where rf.revision_id=v.id and rf.record_id=r.id and rf.path=f->>'path' and rf.role=f->>'role')))
    or (select count(*) from jsonb_array_elements(fields->'files'))<>(select count(distinct f->>'path') from jsonb_array_elements(fields->'files') f) then
    raise exception 'Usa sólo archivos originales o registrados para esta edición' using errcode='22023'; end if;
  r.public_data:=pub; r.files:=fields->'files';
  return to_jsonb(r);
end;
$$;
create function private.dopmi_case_revision_validate(v private.dopmi_case_revisions) returns void
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; e jsonb; s jsonb;
begin
  if char_length(btrim(v.reason)) not between 5 and 2000 then raise exception 'Explica el motivo de la edición con 5 a 2000 caracteres' using errcode='22023'; end if;
  r:=jsonb_populate_record(null::public.dopmi_rescue_records,v.proposed_case); perform private.dopmi_rescue_validate(r);
  if (select coalesce(jsonb_agg(x->>'id' order by x->>'id'),'[]') from jsonb_array_elements(v.source_expenses) x)
    is distinct from (select coalesce(jsonb_agg(x->>'id' order by x->>'id'),'[]') from jsonb_array_elements(v.proposed_expenses) x) then
    raise exception 'Revisa el conjunto exacto de necesidades del caso' using errcode='40001'; end if;
  for e in select value from jsonb_array_elements(v.proposed_expenses) loop
    select value into s from jsonb_array_elements(v.source_expenses) where value->>'id'=e->>'id';
    perform private.dopmi_case_revision_normalize(s,jsonb_build_object('public_data',e->'public_data','private_data',e->'private_data','files',e->'files'),v);
    r:=jsonb_populate_record(null::public.dopmi_rescue_records,e); perform private.dopmi_rescue_validate(r);
    if exists(select 1 from jsonb_array_elements(v.proposed_expenses) sibling where sibling->>'id'<>e->>'id'
      and lower(sibling->'private_data'->>'vendor')=lower(e->'private_data'->>'vendor')
      and lower(sibling->'private_data'->>'receipt_reference')=lower(e->'private_data'->>'receipt_reference')
      and sibling->'private_data'->>'paid_on'=e->'private_data'->>'paid_on') then
      raise exception 'Este comprobante aparece en más de una necesidad' using errcode='22023'; end if;
  end loop;
end;
$$;
create function public.dopmi_save_case_revision(revision_id uuid,expected_version integer,reason text,case_fields jsonb,expense_fields jsonb,request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v private.dopmi_case_revisions; intent jsonb; result jsonb; proposed jsonb:='[]'; e jsonb; source jsonb; ids jsonb;
begin
  v:=private.dopmi_case_revision_authorize(revision_id);
  if jsonb_typeof(expense_fields) is distinct from 'array' or octet_length(expense_fields::text)+octet_length(case_fields::text)>1000000
    or reason is null or char_length(btrim(reason)) not between 5 and 2000 then
    raise exception 'Revisa el motivo y el caso completo' using errcode='22023'; end if;
  select coalesce(jsonb_agg(x order by x->>'id'),'[]') into expense_fields from jsonb_array_elements(expense_fields) x;
  intent:=jsonb_build_object('operation','save','revision_id',revision_id,'expected_version',expected_version,'reason',btrim(reason),'case_fields',case_fields,'expense_fields',expense_fields);
  result:=private.dopmi_case_revision_replay(revision_id,request_id,intent); if result is not null then return result; end if;
  if v.version is distinct from expected_version or v.status not in ('draft','changes_requested','rejected') then
    raise exception 'La edición cambió. Recarga antes de continuar' using errcode='40001'; end if;
  if jsonb_array_length(expense_fields)<>jsonb_array_length(v.source_expenses)
    or (select count(*) from jsonb_array_elements(expense_fields))<>(select count(distinct x->>'id') from jsonb_array_elements(expense_fields) x) then
    raise exception 'Envía todas las mismas necesidades del caso' using errcode='22023'; end if;
  v.proposed_case:=private.dopmi_case_revision_normalize(v.source_case,case_fields,v);
  for e in select value from jsonb_array_elements(expense_fields) loop
    select value into source from jsonb_array_elements(v.source_expenses) where value->>'id'=e->>'id';
    if source is null then raise exception 'Una necesidad nueva requiere un caso nuevo' using errcode='22023'; end if;
    proposed:=proposed||jsonb_build_array(private.dopmi_case_revision_normalize(source,e,v));
  end loop;
  update private.dopmi_case_revisions set reason=btrim($3),proposed_case=v.proposed_case,proposed_expenses=proposed,
    status='draft',version=version+1,updated_at=now() where id=v.id returning * into v;
  result:=private.dopmi_case_revision_packet(v); perform private.dopmi_case_revision_remember(v.id,request_id,intent,result); return result;
end;
$$;
create function public.dopmi_transition_case_revision(revision_id uuid,expected_version integer,action text,request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v private.dopmi_case_revisions; intent jsonb; result jsonb;
begin
  v:=private.dopmi_case_revision_authorize(revision_id);
  intent:=jsonb_build_object('operation','transition','revision_id',revision_id,'expected_version',expected_version,'action',action);
  result:=private.dopmi_case_revision_replay(revision_id,request_id,intent); if result is not null then return result; end if;
  if v.version is distinct from expected_version or action is null
    or not ((action='submit' and v.status in ('draft','changes_requested','rejected')) or (action='withdraw' and v.status='submitted')) then
    raise exception 'Acción no disponible para esta edición' using errcode='40001'; end if;
  if action='submit' then perform private.dopmi_case_revision_validate(v); end if;
  update private.dopmi_case_revisions set status=case when action='submit' then 'submitted' else 'draft' end,
    source_media=case when action='submit' then private.dopmi_case_revision_media(v) else source_media end,
    file_objects=case when action='submit' then private.dopmi_case_revision_objects(v) else file_objects end,
    submitted_at=case when action='submit' then now() else null end,version=version+1,updated_at=now()
    where id=v.id returning * into v;
  perform private.dopmi_rescue_audit((jsonb_populate_record(null::public.dopmi_rescue_records,v.source_case)),
    'case_revision_'||action,v.reason);
  result:=private.dopmi_case_revision_packet(v); perform private.dopmi_case_revision_remember(v.id,request_id,intent,result); return result;
end;
$$;
create function public.dopmi_case_revision_file(revision_id uuid,expected_version integer,record_id uuid,file_role text,extension text,request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v private.dopmi_case_revisions; intent jsonb; result jsonb; path text; source jsonb;
begin
  v:=private.dopmi_case_revision_authorize(revision_id);
  intent:=jsonb_build_object('operation','file','revision_id',revision_id,'expected_version',expected_version,'record_id',record_id,'file_role',file_role,'extension',extension);
  result:=private.dopmi_case_revision_replay(revision_id,request_id,intent); if result is not null then return result; end if;
  if v.status not in ('draft','changes_requested','rejected') or v.version is distinct from expected_version then
    raise exception 'Retira la edición antes de cambiar sus archivos' using errcode='40001'; end if;
  if record_id=v.case_id then source:=v.source_case;
  else select value into source from jsonb_array_elements(v.source_expenses) where value->>'id'=record_id::text; end if;
  if source is null or (source->>'kind'='case' and file_role is distinct from 'public')
    or (source->>'kind'='expense' and (file_role is null or file_role not in ('receipt','proof','public')))
    or extension is null or extension not in ('jpg','png','webp','pdf') or (file_role='public' and extension='pdf')
    or (source->>'kind'='expense' and private.dopmi_case_expense_locked(record_id)) then
    raise exception 'Archivo o necesidad no editable en esta edición' using errcode='22023'; end if;
  path:=v.owner_id::text||'/'||record_id::text||'/'||gen_random_uuid()::text||'.'||extension;
  insert into private.dopmi_case_revision_files values(path,v.id,record_id,file_role);
  result:=jsonb_build_object('path',path,'revision_id',v.id,'record_id',record_id,'role',file_role);
  perform private.dopmi_case_revision_remember(v.id,request_id,intent,result); return result;
end;
$$;
create or replace function public.dopmi_rescue_file_access(object_name text,writing boolean default false) returns boolean
language plpgsql security definer set search_path='' as $$
declare v private.dopmi_case_revisions; r public.dopmi_rescue_records; c public.dopmi_rescue_records; registered boolean;
begin
  select x.* into v from private.dopmi_case_revision_files f join private.dopmi_case_revisions x on x.id=f.revision_id where f.path=object_name;
  registered:=found;
  if registered then
    perform private.dopmi_rescue_lock(v.owner_id);
    select * into v from private.dopmi_case_revisions where id=v.id;
    select * into c from public.dopmi_rescue_records where id=v.case_id;
    -- Registered paths never fall through to the broad legacy approved-folder
    -- read rule. A guessed draft path does not grant staff a private preview.
    if writing then
      if auth.uid()<>v.owner_id or v.status not in ('draft','changes_requested','rejected') or c.status is distinct from v.source_case->>'status'
        or c.status not in ('approved','changes_requested') or c.version<>v.base_case_version then return false; end if;
      begin perform private.dopmi_case_revision_actor(); exception when insufficient_privilege or invalid_parameter_value then return false; end;
      return true;
    end if;
    if public.dopmi_actor_active() and auth.uid()=v.owner_id then
      begin perform private.dopmi_case_revision_actor(); exception when insufficient_privilege or invalid_parameter_value then return false; end;
      return true;
    end if;
    if v.status='submitted' and c.status=v.source_case->>'status' and c.status in ('approved','changes_requested') and c.version=v.base_case_version and public.dopmi_is_admin()
      and (exists(select 1 from jsonb_array_elements(v.proposed_case->'files') f where f->>'path'=object_name)
        or exists(select 1 from jsonb_array_elements(v.proposed_expenses) e cross join lateral jsonb_array_elements(e->'files') f where f->>'path'=object_name)) then
      begin
        perform private.dopmi_case_revision_actor(true); perform private.dopmi_require_current_legal(v.owner_id);
        if not private.dopmi_support_owner_active(v.owner_id) then return false; end if;
      exception when insufficient_privilege or invalid_parameter_value then return false; end;
      return true;
    end if;
    -- After approval only the ordinary approved snapshot can authorize a read.
    if v.status<>'approved' then return false; end if;
    select * into r from public.dopmi_rescue_records where id::text=split_part(object_name,'/',2) and owner_id=v.owner_id;
    if not found or not (exists(select 1 from jsonb_array_elements(r.files) f where f->>'path'=object_name)
      or coalesce(r.approved_snapshot->'photos','[]') ? object_name) then return false; end if;
  end if;
  if writing then
    select * into r from public.dopmi_rescue_records where id::text=split_part(object_name,'/',2);
    if r.kind='expense' then
      select * into c from public.dopmi_rescue_records where id=r.parent_id;
      if c.status in ('submitted','pending_stripe') or private.dopmi_case_ever_approved(c.id) then return false; end if;
    elsif r.kind='case' and private.dopmi_case_ever_approved(r.id) then return false; end if;
  end if;
  return public.dopmi_rescue_file_access_before_fixed_case(object_name,writing);
end;
$$;

create function private.dopmi_case_revision_invalidate() returns trigger
language plpgsql set search_path='' as $$
begin
  if old.kind='case' and (new.status is distinct from old.status or new.version<>old.version) then
    update private.dopmi_case_revisions set status='invalidated',version=version+1,updated_at=now(),feedback='El caso cambió o fue retirado'
      where case_id=old.id and status in ('draft','submitted','changes_requested','rejected');
  end if;
  return new;
end;
$$;
create trigger dopmi_case_revision_invalidate after update on public.dopmi_rescue_records
  for each row execute function private.dopmi_case_revision_invalidate();

create or replace function public.dopmi_rescue_detail(record_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; r public.dopmi_rescue_records; unit jsonb; revision jsonb;
begin
  result:=public.dopmi_rescue_detail_before_fixed_case(record_id);
  r:=jsonb_populate_record(null::public.dopmi_rescue_records,result->'record'); unit:=private.dopmi_case_unit(r);
  if unit is not null then
    select jsonb_build_object('id',v.id,'version',v.version,'status',v.status,'reason',v.reason) into revision
      from private.dopmi_case_revisions v where v.case_id=(unit->>'case_id')::uuid
        and v.status in ('draft','submitted','changes_requested','rejected') order by v.created_at desc limit 1;
    -- Staff packets never reveal a private edit before explicit submission.
    if r.owner_id<>auth.uid() and revision->>'status'<>'submitted' then revision:=null; end if;
    unit:=unit||jsonb_build_object('revision',revision);
  end if;
  return result||jsonb_build_object('case_unit',unit);
end;
$$;
create or replace function public.dopmi_admin_rescue(kind_filter text,status_filter text default 'submitted',page_number integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=public.dopmi_admin_rescue_before_fixed_case(kind_filter,status_filter,page_number);
  if kind_filter<>'case' or status_filter<>'submitted' then return result; end if;
  with queue as (
    select r.id,r.owner_id,r.kind,r.parent_id,r.public_data,r.status,r.version,r.submitted_at,r.updated_at,
      'initial'::text review_kind,null::uuid revision_id,null::integer revision_version,null::text reason
      from public.dopmi_rescue_records r where r.kind='case' and r.status='submitted'
    union all
    select r.id,r.owner_id,r.kind,r.parent_id,v.proposed_case->'public_data','submitted',r.version,v.submitted_at,v.updated_at,
      'revision',v.id,v.version,v.reason from private.dopmi_case_revisions v join public.dopmi_rescue_records r on r.id=v.case_id
      where v.status='submitted' and r.status=v.source_case->>'status' and r.status in ('approved','changes_requested') and r.version=v.base_case_version
  ) select jsonb_build_object('total',(select count(*) from queue),'items',coalesce((select jsonb_agg(x) from
    (select * from queue order by submitted_at,id limit 20 offset (page_number::bigint-1)*20) x),'[]')) into result;
  return result;
end;
$$;
create function public.dopmi_admin_case_revision_packet(revision_id uuid,expense_page integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v private.dopmi_case_revisions;
begin
  v:=private.dopmi_case_revision_authorize(revision_id,true);
  if expense_page is null or expense_page not between 1 and 1000 then raise exception 'Página inválida' using errcode='22023'; end if;
  if v.status<>'submitted' then raise exception 'Edición no disponible para revisión' using errcode='42501'; end if;
  perform private.dopmi_rescue_audit((jsonb_populate_record(null::public.dopmi_rescue_records,v.source_case)),'read','Consulta de edición completa de caso');
  return private.dopmi_case_revision_packet(v,expense_page);
end;
$$;

create function public.dopmi_comment_case_revision_needs(revision_id uuid,expected_version integer,comments jsonb,request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v private.dopmi_case_revisions; intent jsonb; result jsonb; item jsonb; source jsonb; target uuid; kind text;
  normalized jsonb; enriched jsonb:='[]'; seen text[]:='{}'; title text; event_id uuid:=gen_random_uuid(); feedback text:='';
begin
  v:=private.dopmi_case_revision_authorize(revision_id,true);
  if jsonb_typeof(comments) is distinct from 'array' or jsonb_array_length(comments) not between 1 and 50 or octet_length(comments::text)>100000 then
    raise exception 'Revisa los comentarios del caso' using errcode='22023'; end if;
  select jsonb_agg(i order by i->>'target_kind',i->>'target_id') into normalized from jsonb_array_elements(comments) i;
  intent:=jsonb_build_object('operation','comment','revision_id',revision_id,'expected_version',expected_version,'comments',normalized);
  result:=private.dopmi_case_revision_replay(revision_id,request_id,intent); if result is not null then return result; end if;
  if v.status<>'submitted' or v.version is distinct from expected_version then raise exception 'La edición cambió. Recarga antes de comentar' using errcode='40001'; end if;
  for item in select value from jsonb_array_elements(normalized) loop
    kind:=item->>'target_kind';
    if jsonb_typeof(item) is distinct from 'object' or item-'target_kind'-'target_id'-'target_version'-'body'<>'{}'::jsonb
      or kind is null or kind not in ('expense','planned') or jsonb_typeof(item->'body') is distinct from 'string'
      or char_length(btrim(item->>'body')) not between 5 and 2000
      or coalesce(item->>'target_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or coalesce(item->>'target_version','') !~ '^[0-9]{1,9}$' then raise exception 'Comentario o necesidad inválidos' using errcode='22023'; end if;
    target:=(item->>'target_id')::uuid;
    if (kind||':'||target::text)=any(seen) then raise exception 'Necesidad repetida' using errcode='22023'; end if;
    seen:=array_append(seen,kind||':'||target::text);
    if kind='expense' then
      select value into source from jsonb_array_elements(v.proposed_expenses) where value->>'id'=target::text;
      if source is null or (source->>'version')::integer<>(item->>'target_version')::integer then raise exception 'La necesidad cambió' using errcode='40001'; end if;
      title:=source->'public_data'->>'title';
    else
      select value into source from jsonb_array_elements(coalesce(v.proposed_case->'public_data'->'need_items','[]')) where value->>'id'=target::text;
      if source is null or (item->>'target_version')::integer<>v.base_case_version then raise exception 'La necesidad cambió' using errcode='40001'; end if;
      title:=source->>'title';
    end if;
    enriched:=enriched||jsonb_build_array(item||jsonb_build_object('target_title',title));
    feedback:=feedback||case when feedback='' then '' else E'\n\n' end||coalesce(title,'Necesidad')||E':\n'||btrim(item->>'body');
  end loop;
  insert into private.dopmi_rescue_history(id,record_id,actor_id,action,feedback,version,snapshot)
    values(event_id,v.case_id,auth.uid(),'need_comments',feedback,v.base_case_version,
      v.source_case||jsonb_build_object('_case_revision_id',v.id,'_need_comments',enriched));
  result:=jsonb_build_object('request_id',request_id,'revision_id',v.id,'revision_version',v.version,'record_id',v.case_id,'case_version',v.base_case_version,'comments',
    (select jsonb_agg(private.dopmi_need_comment_dto(event_id,v.case_id,v.base_case_version,now(),i)) from jsonb_array_elements(enriched) i));
  perform private.dopmi_case_revision_remember(v.id,request_id,intent,result); return result;
end;
$$;
create function private.dopmi_case_revision_preserve_media(v private.dopmi_case_revisions,prepare boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare item jsonb; old_asset private.dopmi_video_assets; current_asset private.dopmi_video_assets;
  old_parent public.dopmi_rescue_records; new_parent public.dopmi_rescue_records;
begin
  for item in select value from jsonb_array_elements(v.source_media) loop
    old_asset:=jsonb_populate_record(null::private.dopmi_video_assets,item->'asset');
    if old_asset.technical_state<>'ready' or old_asset.moderation_state<>'approved' or item->'cleanup_queued'<>'false'::jsonb then continue; end if;
    if old_asset.parent_id=v.case_id then old_parent:=jsonb_populate_record(null::public.dopmi_rescue_records,v.source_case);
    else select (jsonb_populate_record(null::public.dopmi_rescue_records,e)).* into old_parent from jsonb_array_elements(v.source_expenses) e where e->>'id'=old_asset.parent_id::text; end if;
    if old_parent.status<>'approved' and not (old_parent.kind='case' and private.dopmi_case_ever_approved(old_parent.id)) then continue; end if;
    if prepare and old_parent.kind<>'case' then continue; end if;
    -- A previously stale context is never promoted by editing another field.
    if old_asset.content_snapshot is distinct from private.dopmi_video_content(old_parent) then continue; end if;
    select * into current_asset from private.dopmi_video_assets where id=old_asset.id;
    if prepare then
      new_parent:=jsonb_populate_record(null::public.dopmi_rescue_records,v.proposed_case);
      new_parent.status:='approved'; new_parent.version:=v.base_case_version+1;
      new_parent.approved_snapshot:=new_parent.public_data||jsonb_build_object('photos',coalesce((select jsonb_agg(f->>'path') from jsonb_array_elements(new_parent.files) f where f->>'role'='public'),'[]'));
    else select * into new_parent from public.dopmi_rescue_records where id=old_asset.parent_id; end if;
    if current_asset.bytes is distinct from old_asset.bytes or current_asset.provider_id is distinct from old_asset.provider_id
      or current_asset.file_fingerprint is distinct from old_asset.file_fingerprint or current_asset.technical_state<>'ready'
      or current_asset.moderation_state not in ('stale','approved') or exists(
        select 1 from private.dopmi_video_deletion_queue where provider_id=old_asset.provider_id) then
      raise exception 'Un medio cambió. Recarga y revisa la edición completa' using errcode='40001'; end if;
    update private.dopmi_video_assets set parent_version=new_parent.version,content_snapshot=private.dopmi_video_content(new_parent),
      approved_parent_snapshot=case when purpose<>'expense_evidence' then new_parent.approved_snapshot else null end,
      moderation_state='approved',updated_at=now() where id=old_asset.id;
    if not prepare then insert into private.dopmi_video_reviews(asset_id,reviewer_id,parent_version,decision,note,snapshot)
      values(old_asset.id,auth.uid(),new_parent.version,'approved','Medio ya aprobado conservado en la revisión conjunta; sin nueva reproducción atribuida',
        jsonb_build_object('case_revision_id',v.id,'previous_parent_version',old_asset.parent_version,'parent_version',new_parent.version,
          'old_content',old_asset.content_snapshot,'content',private.dopmi_video_content(new_parent),'bytes',old_asset.bytes,
          'provider_id',old_asset.provider_id,'file_fingerprint',old_asset.file_fingerprint,'preserved_approved_asset',true)); end if;
  end loop;
end;
$$;
create function public.dopmi_review_case_revision(revision_id uuid,expected_version integer,decision text,note text,
  publish_content boolean,expense_reviews jsonb,request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v private.dopmi_case_revisions; c public.dopmi_rescue_records; current_expense public.dopmi_rescue_records;
  p public.dopmi_rescue_records; item jsonb; source jsonb; proposed jsonb; normalized jsonb; intent jsonb; result jsonb;
  amount bigint; urgent boolean; urgent_note text; audit_id uuid;
begin
  v:=private.dopmi_case_revision_authorize(revision_id,true);
  if decision is null or decision not in ('approved','changes_requested','rejected') or note is null or char_length(btrim(note)) not between 5 and 2000
    or publish_content is null or jsonb_typeof(expense_reviews) is distinct from 'array' or octet_length(expense_reviews::text)>1000000 then
    raise exception 'Revisa la decisión completa y su motivo' using errcode='22023'; end if;
  select coalesce(jsonb_agg(i order by i->>'expense_id'),'[]') into normalized from jsonb_array_elements(expense_reviews) i;
  intent:=jsonb_build_object('operation','review','revision_id',revision_id,'expected_version',expected_version,'decision',decision,
    'note',btrim(note),'publish_content',publish_content,'expense_reviews',normalized);
  result:=private.dopmi_case_revision_replay(revision_id,request_id,intent); if result is not null then return result; end if;
  if v.status<>'submitted' or v.version is distinct from expected_version then raise exception 'La edición cambió. Recarga antes de decidir' using errcode='40001'; end if;
  if decision<>'approved' then
    if jsonb_array_length(normalized)<>0 then raise exception 'Devolver el caso no aprueba necesidades' using errcode='22023'; end if;
    update private.dopmi_case_revisions set status=decision,feedback=btrim(note),version=version+1,updated_at=now() where id=v.id returning * into v;
  else
    if publish_content is distinct from true then raise exception 'Autoriza expresamente los textos y fotos de la edición' using errcode='22023'; end if;
    select * into c from public.dopmi_rescue_records where id=v.case_id for update;
    if to_jsonb(c) is distinct from v.source_case then raise exception 'El caso cambió. Recarga antes de decidir' using errcode='40001'; end if;
    perform 1 from public.dopmi_rescue_records where id in (select (e->>'id')::uuid from jsonb_array_elements(v.source_expenses) e) order by id for update;
    if exists(select 1 from jsonb_array_elements(v.source_expenses) e left join public.dopmi_rescue_records r on r.id=(e->>'id')::uuid
      where r.id is null or to_jsonb(r) is distinct from e or r.parent_id<>v.case_id or r.owner_id<>v.owner_id or r.kind<>'expense') then
      raise exception 'Una necesidad cambió. Recarga antes de decidir' using errcode='40001'; end if;
    -- Serialize provider queue inserts/deletes for the short publication
    -- transaction. Already queued assets are never revived or dequeued.
    perform 1 from private.dopmi_video_assets a where a.owner_id=v.owner_id and (a.parent_id=v.case_id or exists(
      select 1 from jsonb_array_elements(v.source_expenses) e where e->>'id'=a.parent_id::text)) order by a.id for update;
    lock table private.dopmi_video_deletion_queue in share row exclusive mode;
    if private.dopmi_case_revision_media(v) is distinct from v.source_media then
      raise exception 'Los medios cambiaron. Retira y vuelve a enviar la edición completa' using errcode='40001'; end if;
    if private.dopmi_case_revision_objects(v) is distinct from v.file_objects then
      raise exception 'Un archivo cambió. Retira y vuelve a enviar la edición completa' using errcode='40001'; end if;
    perform private.dopmi_case_revision_validate(v);
    if jsonb_array_length(normalized)<>jsonb_array_length(v.source_expenses)
      or (select count(distinct i->>'expense_id') from jsonb_array_elements(normalized) i)<>jsonb_array_length(normalized) then
      raise exception 'Revisa todas las mismas necesidades de la edición' using errcode='40001'; end if;
    for item in select value from jsonb_array_elements(normalized) loop
      if jsonb_typeof(item) is distinct from 'object'
        or not(item ?& array['expense_id','expense_version','amount_cents','is_urgent','urgency_note','publish_content'])
        or item-'expense_id'-'expense_version'-'amount_cents'-'is_urgent'-'urgency_note'-'publish_content'<>'{}'::jsonb
        or jsonb_typeof(item->'expense_id') is distinct from 'string'
        or jsonb_typeof(item->'expense_version') is distinct from 'number' or coalesce(item->>'expense_version','') !~ '^[0-9]{1,9}$'
        or jsonb_typeof(item->'amount_cents') is distinct from 'number' or coalesce(item->>'amount_cents','') !~ '^[0-9]{1,9}$'
        or jsonb_typeof(item->'is_urgent') is distinct from 'boolean' or jsonb_typeof(item->'publish_content') is distinct from 'boolean'
        or jsonb_typeof(item->'urgency_note') is distinct from 'string' or char_length(item->>'urgency_note')>1000 then
        raise exception 'Confirma importe, prioridad y publicación de cada necesidad' using errcode='22023'; end if;
      select value into source from jsonb_array_elements(v.source_expenses) where value->>'id'=item->>'expense_id';
      select value into proposed from jsonb_array_elements(v.proposed_expenses) where value->>'id'=item->>'expense_id';
      if source is null or proposed is null or (source->>'version')::integer<>(item->>'expense_version')::integer then
        raise exception 'Una necesidad cambió' using errcode='40001'; end if;
      amount:=case when source->>'status'<>'approved' then 0 when (proposed->'private_data'->>'amount_cents')::bigint=(source->'private_data'->>'amount_cents')::bigint
        then (source->>'reimbursable_cents')::bigint else (proposed->'private_data'->>'amount_cents')::bigint end;
      urgent:=(item->>'is_urgent')::boolean; urgent_note:=btrim(item->>'urgency_note');
      if (item->>'amount_cents')::bigint<>amount or (item->>'publish_content')::boolean is distinct from true
        or (urgent and char_length(urgent_note) not between 5 and 1000) then
        raise exception 'Conserva el importe autorizado o aprueba el importe completo respaldado' using errcode='22023'; end if;
      if source->>'status'<>'approved' and (urgent is distinct from (source->>'urgent')::boolean
        or urgent_note is distinct from btrim(source->>'priority_reason')) then
        raise exception 'Conserva la prioridad histórica de la necesidad retirada' using errcode='22023'; end if;
      if private.dopmi_case_expense_locked((source->>'id')::uuid)
        and source->>'status'='approved' and amount<>(source->>'reimbursable_cents')::bigint then
        raise exception 'Conserva la aprobación y el importe de la necesidad con vínculos financieros' using errcode='22023'; end if;
    end loop;
    -- Mark the proposal terminal before bumping the published case version, so
    -- the normal close/moderation invalidation trigger cannot invalidate itself.
    update private.dopmi_case_revisions set status='approved',feedback=btrim(note),version=version+1,updated_at=now() where id=v.id returning * into v;
    if c.status='changes_requested' then perform private.dopmi_case_revision_preserve_media(v,true); end if;
    p:=jsonb_populate_record(null::public.dopmi_rescue_records,v.proposed_case);
    update public.dopmi_rescue_records set public_data=p.public_data,private_data=p.private_data,files=p.files,status='approved',feedback=btrim(note),
      approved_at=case when status='approved' then approved_at else clock_timestamp() end,
      approximate_latitude=p.approximate_latitude,approximate_longitude=p.approximate_longitude,
      approved_snapshot=p.public_data||jsonb_build_object('photos',coalesce((select jsonb_agg(f->>'path') from jsonb_array_elements(p.files) f where f->>'role'='public'),'[]')),
      version=version+1,updated_at=now() where id=v.case_id returning * into c;
    for item in select value from jsonb_array_elements(normalized) loop
      select value into source from jsonb_array_elements(v.source_expenses) where value->>'id'=item->>'expense_id';
      select value into proposed from jsonb_array_elements(v.proposed_expenses) where value->>'id'=item->>'expense_id';
      p:=jsonb_populate_record(null::public.dopmi_rescue_records,proposed);
      amount:=(item->>'amount_cents')::bigint;
      update public.dopmi_rescue_records r set public_data=p.public_data,private_data=p.private_data,files=p.files,
        reimbursable_cents=case when r.status='approved' then amount else r.reimbursable_cents end,
        urgent=case when r.status='approved' then (item->>'is_urgent')::boolean else r.urgent end,
        priority_reason=case when r.status<>'approved' then r.priority_reason when (item->>'is_urgent')::boolean then btrim(item->>'urgency_note') else '' end,
        approved_snapshot=case when r.status='approved' then p.public_data||jsonb_build_object('photos',coalesce((select jsonb_agg(f->>'path') from jsonb_array_elements(p.files) f where f->>'role'='public'),'[]')) else r.approved_snapshot end,
        version=r.version+1,updated_at=now() where r.id=p.id returning r.* into current_expense;
      perform private.dopmi_rescue_audit(current_expense,'case_revision_approved',v.reason||E'\n\n'||btrim(note));
    end loop;
    perform private.dopmi_case_revision_preserve_media(v);
  end if;
  audit_id:=private.dopmi_rescue_audit(case when decision='approved' then c else jsonb_populate_record(null::public.dopmi_rescue_records,v.source_case) end,
    'case_revision_'||decision,v.reason||E'\n\n'||btrim(note));
  insert into public.dopmi_notifications(user_id,kind,rescue_id,source_id,title) values(v.owner_id,'rescue',v.case_id,audit_id,
    case decision when 'approved' then 'La edición de tu caso fue aprobada' when 'changes_requested' then 'La edición de tu caso necesita correcciones' else 'La edición de tu caso no fue aprobada' end);
  result:=private.dopmi_case_revision_packet(v)||jsonb_build_object('request_id',request_id,'revision_id',v.id,'revision_version',v.version,'decision',decision);
  if decision='approved' then
    result:=result||jsonb_build_object('record',to_jsonb(c),'case_unit',private.dopmi_case_unit(c),
      'expenses',jsonb_build_object('total',jsonb_array_length(v.source_expenses),'page',1,'items',
        (select coalesce(jsonb_agg(to_jsonb(r)||jsonb_build_object('financial_locked',private.dopmi_case_expense_locked(r.id),'financial_inactive',r.status<>'approved',
          'locked_fields',case when private.dopmi_case_expense_locked(r.id) then '["amount_cents","paid_on","vendor","receipt_reference","files"]'::jsonb else '[]'::jsonb end,
          'review_amount_cents',case when r.status='approved' then r.reimbursable_cents else 0 end) order by r.id),'[]') from public.dopmi_rescue_records r
          where exists(select 1 from jsonb_array_elements(v.source_expenses) e where e->>'id'=r.id::text))));
  end if;
  perform private.dopmi_case_revision_remember(v.id,request_id,intent,result); return result;
end;
$$;

-- New helpers/delegates stay closed even to service_role. Existing entry-point
-- privileges above are deliberately not revoked/regranted.
do $acl$ declare f record;
begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname in ('dopmi_case_ever_approved','dopmi_case_expense_locked','dopmi_case_unit',
      'dopmi_fixed_case_membership_guard','dopmi_case_revision_actor','dopmi_case_revision_authorize','dopmi_case_revision_replay',
      'dopmi_case_revision_remember','dopmi_case_revision_media','dopmi_case_revision_objects','dopmi_case_revision_preserve_media','dopmi_case_revision_packet','dopmi_case_revision_normalize','dopmi_case_revision_validate','dopmi_case_revision_invalidate'))
      or (n.nspname='public' and p.proname in ('dopmi_case_revision','dopmi_start_case_revision','dopmi_save_case_revision','dopmi_transition_case_revision',
        'dopmi_case_revision_file','dopmi_admin_case_revision_packet','dopmi_comment_case_revision_needs','dopmi_review_case_revision')) loop
    execute 'revoke all on function '||f.signature||' from public,anon,authenticated,service_role';
  end loop;
end $acl$;
grant execute on function public.dopmi_case_revision(uuid),public.dopmi_start_case_revision(uuid,integer,uuid),
  public.dopmi_save_case_revision(uuid,integer,text,jsonb,jsonb,uuid),public.dopmi_transition_case_revision(uuid,integer,text,uuid),
  public.dopmi_case_revision_file(uuid,integer,uuid,text,text,uuid),public.dopmi_admin_case_revision_packet(uuid,integer),
  public.dopmi_comment_case_revision_needs(uuid,integer,jsonb,uuid),public.dopmi_review_case_revision(uuid,integer,text,text,boolean,jsonb,uuid) to authenticated;

commit;
