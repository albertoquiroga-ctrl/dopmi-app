begin;

-- Three independently reviewed entities share versioning, evidence and audit rules.
-- JSON fields are whitelisted by kind; no JSON key grants permissions or financial state.
create table public.dopmi_rescue_records (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check(kind in ('verification','case','expense')),
  parent_id uuid references public.dopmi_rescue_records(id),
  public_data jsonb not null default '{}', private_data jsonb not null default '{}',
  files jsonb not null default '[]',
  status text not null default 'draft' check(status in ('draft','submitted','changes_requested','approved','rejected','closed')),
  version integer not null default 1,
  feedback text not null default '', approved_snapshot jsonb,
  reimbursable_cents bigint not null default 0 check(reimbursable_cents between 0 and 100000000),
  urgent boolean not null default false, priority_reason text not null default '',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  submitted_at timestamptz, approved_at timestamptz,
  check ((kind='expense')=(parent_id is not null)),
  check(kind='expense' or (reimbursable_cents=0 and not urgent)),
  check(jsonb_typeof(public_data)='object' and jsonb_typeof(private_data)='object' and jsonb_typeof(files)='array'),
  check(octet_length(public_data::text)<=20000 and octet_length(private_data::text)<=20000 and jsonb_array_length(files)<=12)
);
create unique index dopmi_one_verification on public.dopmi_rescue_records(owner_id) where kind='verification';
create index dopmi_rescue_owner on public.dopmi_rescue_records(owner_id,kind,updated_at desc,id);
create index dopmi_rescue_parent on public.dopmi_rescue_records(parent_id);
create index dopmi_rescue_queue on public.dopmi_rescue_records(kind,status,submitted_at,id);
create index dopmi_rescue_priority on public.dopmi_rescue_records(urgent desc,approved_at,id) where kind='expense' and status='approved';

create table private.dopmi_rescue_history (
  id uuid primary key default gen_random_uuid(), record_id uuid not null references public.dopmi_rescue_records(id) on delete cascade,
  actor_id uuid not null, action text not null, feedback text not null default '',
  version integer not null, snapshot jsonb not null, created_at timestamptz not null default now()
);
create index dopmi_rescue_history_record on private.dopmi_rescue_history(record_id,created_at,id);
alter table private.dopmi_rescue_history enable row level security;
alter table public.dopmi_rescue_records enable row level security;
revoke all on public.dopmi_rescue_records,private.dopmi_rescue_history from public,anon,authenticated;
grant select on public.dopmi_rescue_records to authenticated;
create policy dopmi_rescue_owner on public.dopmi_rescue_records for select to authenticated
  using(public.dopmi_actor_active() and owner_id=(select auth.uid()));

alter table public.dopmi_notifications drop constraint dopmi_notifications_kind_check;
alter table public.dopmi_notifications add constraint dopmi_notifications_kind_check check(kind in ('review','message','rescue'));
alter table public.dopmi_notifications add column rescue_id uuid references public.dopmi_rescue_records(id) on delete cascade;

create function private.dopmi_rescuer_verified(person uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.dopmi_rescue_records r join public.profiles p on p.id=r.owner_id
    join auth.users u on u.id=p.id where r.owner_id=person and r.kind='verification' and r.status='approved'
    and p.account_status='active' and u.email_confirmed_at is not null);
$$;

create function private.dopmi_rescue_lock(person uuid) returns void
language sql set search_path='' as $$ select pg_advisory_xact_lock(hashtextextended('dopmi-rescue:'||person::text,0)); $$;

create function private.dopmi_rescue_fields(data jsonb, allowed text[]) returns jsonb
language plpgsql immutable set search_path='' as $$
begin
  if jsonb_typeof(data) is distinct from 'object' or octet_length(data::text)>20000
    or exists(select 1 from jsonb_each(data) e where not e.key=any(allowed) or jsonb_typeof(e.value)<>'string'
      or char_length(e.value #>> '{}')>4000) then
    raise exception 'Campos inválidos o demasiado largos' using errcode='22023';
  end if;
  return coalesce((select jsonb_object_agg(key,btrim(value #>> '{}')) from jsonb_each(data)),'{}');
end;
$$;

create function private.dopmi_rescue_validate(r public.dopmi_rescue_records) returns void
language plpgsql security definer set search_path='' as $$
declare required_public text[]; required_private text[]; roles text[]; field text;
begin
  if r.kind='verification' then
    required_public:=array['public_name','bio','city','state'];
    required_private:=array['legal_name','phone','experience','social_url','identity_type'];
    roles:=array['identity','address'];
    if coalesce(r.private_data->>'identity_type','') not in ('ine','passport','license')
      or coalesce(r.private_data->>'social_url','') !~ '^https://[^ /]+/.+'
      or coalesce(r.private_data->>'phone','') !~ '^\+?[0-9 ()-]{10,20}$' then
      raise exception 'Revisa identificación, teléfono y enlace social HTTPS' using errcode='22023'; end if;
  elsif r.kind='case' then
    required_public:=array['pet_name','species','sex','age','story','city','state','need']; required_private:='{}'; roles:=array['public'];
    if coalesce(r.public_data->>'species','') not in ('dog','cat') or coalesce(r.public_data->>'sex','') not in ('male','female','unknown') then
      raise exception 'Revisa especie y sexo' using errcode='22023'; end if;
  else
    required_public:=array['title','description','category'];
    required_private:=array['paid_on','vendor','amount_cents','receipt_reference']; roles:=array['receipt','proof'];
    if coalesce(r.public_data->>'category','') not in ('food','veterinary','medicine','other') then
      raise exception 'Selecciona la necesidad que cubrió el gasto' using errcode='22023'; end if;
    if r.public_data->>'category'='food' then required_public:=required_public||'round_label'::text; end if;
    if coalesce(r.private_data->>'amount_cents','') !~ '^[0-9]{1,9}$' then
      raise exception 'Escribe el gasto en centavos enteros' using errcode='22023'; end if;
    if (r.private_data->>'amount_cents')::bigint not between 1 and 100000000 then
      raise exception 'El gasto debe ser mayor a cero y hasta $1,000,000' using errcode='22023'; end if;
    begin
      if coalesce(r.private_data->>'paid_on','') !~ '^\d{4}-\d{2}-\d{2}$'
        or (r.private_data->>'paid_on')::date > (now() at time zone 'America/Mexico_City')::date then
        raise exception 'Fecha de pago inválida'; end if;
    exception when others then raise exception 'Indica una fecha válida de un gasto ya pagado' using errcode='22023'; end;
    -- Catch the same receipt submitted twice, including separate food rounds.
    if exists(select 1 from public.dopmi_rescue_records x where x.kind='expense' and x.owner_id=r.owner_id and x.id<>r.id
      and x.status in ('submitted','approved') and lower(x.private_data->>'vendor')=lower(r.private_data->>'vendor')
      and lower(x.private_data->>'receipt_reference')=lower(r.private_data->>'receipt_reference')
      and x.private_data->>'paid_on'=r.private_data->>'paid_on') then
      raise exception 'Este comprobante ya tiene una solicitud en revisión o aprobada' using errcode='22023'; end if;
  end if;
  foreach field in array required_public loop
    if coalesce(char_length(btrim(r.public_data->>field)),0)<2 then
      raise exception 'Completa la información para publicación' using errcode='22023'; end if;
  end loop;
  foreach field in array required_private loop
    if coalesce(char_length(btrim(r.private_data->>field)),0)<1 then
      raise exception 'Completa los datos privados de revisión' using errcode='22023'; end if;
  end loop;
  foreach field in array roles loop
    if not exists(select 1 from jsonb_array_elements(r.files) f where f->>'role'=field) then
      raise exception 'Falta adjuntar evidencia: %',field using errcode='22023'; end if;
  end loop;
  if exists(select 1 from jsonb_array_elements(r.files) f where not exists(select 1 from storage.objects o
    where o.bucket_id='dopmi-rescue-evidence' and o.name=f->>'path')) then
    raise exception 'Hay un archivo que no terminó de subir. Vuelve a adjuntarlo' using errcode='22023'; end if;
end;
$$;

create function public.dopmi_save_rescue(record_kind text, public_fields jsonb, private_fields jsonb, attachments jsonb,
  target_id uuid default null, expected_version integer default null, case_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; r public.dopmi_rescue_records; c public.dopmi_rescue_records; pub text[]; priv text[]; roles text[];
begin
  actor:=private.dopmi_require_actor(); perform private.dopmi_rescue_lock(actor);
  if record_kind is null or record_kind not in ('verification','case','expense') then raise exception 'Tipo inválido' using errcode='22023'; end if;
  if target_id is null then
    if record_kind='verification' and exists(select 1 from public.dopmi_rescue_records where owner_id=actor and kind='verification') then
      raise exception 'Ya tienes una verificación. Abre la solicitud existente' using errcode='40001'; end if;
    insert into public.dopmi_rescue_records(owner_id,kind,parent_id) values(actor,record_kind,case_id) returning * into r;
  else
    select * into r from public.dopmi_rescue_records where id=target_id for update;
    if not found or r.owner_id<>actor then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
    if r.version is distinct from expected_version then raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='40001'; end if;
    if r.kind<>record_kind or r.parent_id is distinct from case_id or r.status not in ('draft','changes_requested','rejected') then
      raise exception 'Esta solicitud no se puede editar en su estado actual' using errcode='22023'; end if;
  end if;
  if r.kind='expense' then
    select * into c from public.dopmi_rescue_records where id=r.parent_id;
    if not found or c.kind<>'case' or c.owner_id<>actor or c.status='closed' then
      raise exception 'Selecciona uno de tus casos abiertos' using errcode='22023'; end if;
  end if;
  if record_kind='verification' then
    pub:=array['public_name','bio','city','state']; priv:=array['legal_name','phone','experience','social_url','identity_type']; roles:=array['identity','address'];
  elsif record_kind='case' then
    pub:=array['pet_name','species','sex','age','story','city','state','need']; priv:='{}'; roles:=array['public'];
  else
    pub:=array['title','description','category','round_label']; priv:=array['paid_on','vendor','amount_cents','receipt_reference','urgency_reason']; roles:=array['receipt','proof','public'];
  end if;
  public_fields:=private.dopmi_rescue_fields(public_fields,pub); private_fields:=private.dopmi_rescue_fields(private_fields,priv);
  if jsonb_typeof(attachments) is distinct from 'array' or jsonb_array_length(attachments)>12
    or exists(select 1 from jsonb_array_elements(attachments) f where jsonb_typeof(f)<>'object'
      or (f-'path'-'role')<>'{}'::jsonb or not coalesce(f->>'role','')=any(roles)
      or coalesce(f->>'path','') !~ ('^'||actor::text||'/'||r.id::text||'/[0-9a-f-]{36}\.(jpg|png|webp|pdf)$')
      or (f->>'role'='public' and f->>'path' !~ '\.(jpg|png|webp)$'))
    or (select count(*) from jsonb_array_elements(attachments))<>(select count(distinct f->>'path') from jsonb_array_elements(attachments) f) then
    raise exception 'Archivos o permisos de publicación inválidos' using errcode='22023'; end if;
  update public.dopmi_rescue_records set public_data=public_fields,private_data=private_fields,files=attachments,
    version=version+1,updated_at=now(),status='draft' where id=r.id returning * into r;
  return to_jsonb(r);
end;
$$;

create function private.dopmi_rescue_audit(r public.dopmi_rescue_records, event text, note text) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
  insert into private.dopmi_rescue_history(record_id,actor_id,action,feedback,version,snapshot)
    values(r.id,auth.uid(),event,note,r.version,to_jsonb(r)) returning id into result;
  return result;
end;
$$;

create function public.dopmi_transition_rescue(record_id uuid, expected_version integer, action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; r public.dopmi_rescue_records;
begin
  actor:=private.dopmi_require_actor(); perform private.dopmi_rescue_lock(actor);
  select * into r from public.dopmi_rescue_records where id=record_id for update;
  if not found or r.owner_id<>actor then raise exception 'Solicitud no disponible' using errcode='42501'; end if;
  if r.version is distinct from expected_version then raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='40001'; end if;
  if action='submit' and r.status in ('draft','changes_requested','rejected') then
    if r.kind<>'verification' and not private.dopmi_rescuer_verified(actor) then
      raise exception 'Primero completa la verificación de rescatista' using errcode='22023'; end if;
    if r.kind='expense' and not exists(select 1 from public.dopmi_rescue_records where id=r.parent_id and status='approved') then
      raise exception 'El caso debe estar aprobado y abierto' using errcode='22023'; end if;
    perform private.dopmi_rescue_validate(r);
    update public.dopmi_rescue_records set status='submitted',submitted_at=now() where id=r.id;
  elsif action='withdraw' and r.status='submitted' then
    update public.dopmi_rescue_records set status='draft' where id=r.id;
  elsif action='close' and r.kind='case' and r.status='approved' then
    if exists(select 1 from public.dopmi_rescue_records where parent_id=r.id and status='submitted') then
      raise exception 'Resuelve o retira los gastos en revisión antes de cerrar el caso' using errcode='22023'; end if;
    update public.dopmi_rescue_records set status='closed' where id=r.id;
  else raise exception 'Acción no disponible para este estado' using errcode='22023'; end if;
  update public.dopmi_rescue_records set version=version+1,updated_at=now() where id=r.id returning * into r;
  perform private.dopmi_rescue_audit(r,action,'');
  return to_jsonb(r);
end;
$$;

create function public.dopmi_review_rescue(record_id uuid, expected_version integer, decision text, note text,
  amount_cents bigint default 0, is_urgent boolean default false, urgency_note text default '', publish_content boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; person uuid; audit_id uuid;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select owner_id into person from public.dopmi_rescue_records where id=record_id;
  if person is null then raise exception 'Solicitud no disponible' using errcode='22023'; end if;
  perform private.dopmi_rescue_lock(person);
  select * into r from public.dopmi_rescue_records where id=record_id for update;
  if r.owner_id=auth.uid() then raise exception 'Otra persona del equipo debe revisar tu solicitud' using errcode='42501'; end if;
  if r.version is distinct from expected_version then raise exception 'La solicitud cambió. Recarga antes de continuar' using errcode='40001'; end if;
  if decision is null or decision not in ('approved','changes_requested','rejected')
    or not (r.status='submitted' or (r.status='approved' and decision='changes_requested'))
    or note is null or char_length(btrim(note)) not between 5 and 2000 then
    raise exception 'Revisa el estado y escribe un motivo de 5 a 2000 caracteres' using errcode='22023'; end if;
  if decision='approved' then
    if not exists(select 1 from public.profiles where id=person and account_status='active') then
      raise exception 'La cuenta está suspendida' using errcode='22023'; end if;
    perform private.dopmi_rescue_validate(r);
    if r.kind<>'verification' and not private.dopmi_rescuer_verified(person) then
      raise exception 'El rescatista no tiene verificación vigente' using errcode='22023'; end if;
    if publish_content is distinct from true then
      raise exception 'Revisa y autoriza expresamente los textos y fotos públicos' using errcode='22023'; end if;
    if r.kind='expense' then
      if not exists(select 1 from public.dopmi_rescue_records where id=r.parent_id and status='approved') then
        raise exception 'El caso debe estar aprobado y abierto' using errcode='22023'; end if;
      if amount_cents is null or amount_cents<1 or amount_cents>(r.private_data->>'amount_cents')::bigint
        or is_urgent is null or (is_urgent and (urgency_note is null or char_length(btrim(urgency_note)) not between 5 and 1000)) then
        raise exception 'Revisa el monto reembolsable y el motivo de urgencia' using errcode='22023'; end if;
    end if;
  end if;
  update public.dopmi_rescue_records set status=decision,feedback=btrim(note),version=version+1,updated_at=now(),
    reimbursable_cents=case when decision='approved' and kind='expense' then amount_cents else 0 end,
    urgent=decision='approved' and kind='expense' and coalesce(is_urgent,false),
    priority_reason=case when decision='approved' and kind='expense' and is_urgent then btrim(urgency_note) else '' end,
    approved_at=case when decision='approved' then clock_timestamp() else null end,
    approved_snapshot=case when decision='approved' then public_data||jsonb_build_object('photos',
      coalesce((select jsonb_agg(f->>'path') from jsonb_array_elements(files) f where f->>'role'='public'),'[]')) else null end
    where id=r.id returning * into r;
  audit_id:=private.dopmi_rescue_audit(r,decision,btrim(note));
  insert into public.dopmi_notifications(user_id,kind,rescue_id,source_id,title)
    values(person,'rescue',r.id,audit_id,case r.kind when 'verification' then 'Tu verificación' when 'case' then 'Tu caso' else 'Tu gasto' end||
      case decision when 'approved' then ' fue aprobado por el equipo' when 'changes_requested' then ' necesita correcciones' else ' no fue aprobado' end);
  return to_jsonb(r);
end;
$$;

create function public.dopmi_admin_rescue(kind_filter text, status_filter text default 'submitted', page_number integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if kind_filter is null or kind_filter not in ('verification','case','expense') or status_filter is null
    or status_filter not in ('submitted','changes_requested','approved','rejected','closed') or page_number is null or page_number<1 then
    raise exception 'Filtros inválidos' using errcode='22023'; end if;
  return jsonb_build_object('total',(select count(*) from public.dopmi_rescue_records where kind=kind_filter and status=status_filter),
    'items',coalesce((select jsonb_agg(x) from (select id,owner_id,kind,parent_id,public_data,status,version,submitted_at,updated_at
      from public.dopmi_rescue_records where kind=kind_filter and status=status_filter
      order by submitted_at,id limit 20 offset (page_number::bigint-1)*20)x),'[]'));
end;
$$;

create function public.dopmi_rescue_detail(record_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; a boolean:=public.dopmi_is_admin();
begin
  select * into r from public.dopmi_rescue_records where id=record_id;
  if not found or not ((public.dopmi_actor_active() and r.owner_id=auth.uid()) or (a and r.status<>'draft')) then
    raise exception 'Solicitud no disponible' using errcode='42501'; end if;
  if a and r.owner_id<>auth.uid() then perform private.dopmi_rescue_audit(r,'read','Consulta de expediente'); end if;
  return jsonb_build_object('record',to_jsonb(r),
    'verified',private.dopmi_rescuer_verified(r.owner_id),
    'case_status',(select status from public.dopmi_rescue_records where id=r.parent_id),
    'history',coalesce((select jsonb_agg(x) from (select id,action,feedback,version,created_at,
        snapshot->'reimbursable_cents' as reimbursable_cents,snapshot->'urgent' as urgent
      from private.dopmi_rescue_history h where h.record_id=r.id and action<>'read' order by created_at desc,id limit 100)x),'[]'));
end;
$$;

create function private.dopmi_rescue_public_visible(r public.dopmi_rescue_records) returns boolean
language sql stable security definer set search_path='' as $$
  select r.kind in ('case','expense') and r.status in ('approved','closed') and r.approved_snapshot is not null
    and private.dopmi_rescuer_verified(r.owner_id) and (r.kind='case' or exists(select 1 from public.dopmi_rescue_records
      where id=r.parent_id and status in ('approved','closed') and approved_snapshot is not null));
$$;
create function public.dopmi_rescue_public(case_id uuid default null, page_number integer default 1) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if page_number is null or page_number<1 then raise exception 'Página inválida' using errcode='22023'; end if;
  return jsonb_build_object('total',(select count(*) from public.dopmi_rescue_records r
      where (case when case_id is null then r.kind='case' else r.id=case_id or r.parent_id=case_id end) and private.dopmi_rescue_public_visible(r)),
    'items',coalesce((select jsonb_agg(x) from (select r.id,r.owner_id,r.kind,r.parent_id,r.status,r.approved_snapshot as public_data,
      r.reimbursable_cents,r.urgent,r.approved_at,
      (select approved_snapshot->>'public_name' from public.dopmi_rescue_records where owner_id=r.owner_id and kind='verification') as rescuer_name
      from public.dopmi_rescue_records r where (case when case_id is null then r.kind='case' else r.id=case_id or r.parent_id=case_id end)
      and private.dopmi_rescue_public_visible(r) order by r.kind,r.approved_at desc,r.id limit 20 offset (page_number::bigint-1)*20)x),'[]'));
end;
$$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
  values('dopmi-rescue-evidence','dopmi-rescue-evidence',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf']);
create function public.dopmi_rescue_file_access(object_name text, writing boolean default false) returns boolean
language plpgsql security definer set search_path='' as $$
declare r public.dopmi_rescue_records; person uuid;
begin
  if object_name is null or object_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp|pdf)$' then return false; end if;
  select owner_id into person from public.dopmi_rescue_records where id::text=split_part(object_name,'/',2);
  if writing then perform private.dopmi_rescue_lock(person); end if;
  select * into r from public.dopmi_rescue_records where id::text=split_part(object_name,'/',2);
  if not found or r.owner_id::text<>split_part(object_name,'/',1) then return false; end if;
  if writing then return public.dopmi_actor_active() and r.owner_id=auth.uid() and r.status in ('draft','changes_requested','rejected')
    and not exists(select 1 from public.dopmi_rescue_records where id=r.parent_id and status='closed'); end if;
  return (public.dopmi_actor_active() and r.owner_id=auth.uid()) or (public.dopmi_is_admin() and r.status<>'draft')
    or (private.dopmi_rescue_public_visible(r) and coalesce(r.approved_snapshot->'photos','[]') ? object_name);
end;
$$;
create policy dopmi_rescue_files_read on storage.objects for select to anon,authenticated
  using(bucket_id='dopmi-rescue-evidence' and public.dopmi_rescue_file_access(name));
create policy dopmi_rescue_files_insert on storage.objects for insert to authenticated
  with check(bucket_id='dopmi-rescue-evidence' and public.dopmi_rescue_file_access(name,true));
create policy dopmi_rescue_files_delete on storage.objects for delete to authenticated
  using(bucket_id='dopmi-rescue-evidence' and public.dopmi_rescue_file_access(name,true));
create policy dopmi_rescue_read_boundary on storage.objects as restrictive for select to anon,authenticated
  using(bucket_id<>'dopmi-rescue-evidence' or public.dopmi_rescue_file_access(name));
create policy dopmi_rescue_insert_boundary on storage.objects as restrictive for insert to anon,authenticated
  with check(bucket_id<>'dopmi-rescue-evidence' or public.dopmi_rescue_file_access(name,true));
create policy dopmi_rescue_delete_boundary on storage.objects as restrictive for delete to anon,authenticated
  using(bucket_id<>'dopmi-rescue-evidence' or public.dopmi_rescue_file_access(name,true));
create policy dopmi_rescue_update_boundary on storage.objects as restrictive for update to anon,authenticated
  using(bucket_id<>'dopmi-rescue-evidence') with check(bucket_id<>'dopmi-rescue-evidence');

revoke all on function private.dopmi_rescuer_verified(uuid),private.dopmi_rescue_lock(uuid),private.dopmi_rescue_fields(jsonb,text[]),
  private.dopmi_rescue_validate(public.dopmi_rescue_records),private.dopmi_rescue_audit(public.dopmi_rescue_records,text,text),
  private.dopmi_rescue_public_visible(public.dopmi_rescue_records) from public,anon,authenticated;
revoke all on function public.dopmi_save_rescue(text,jsonb,jsonb,jsonb,uuid,integer,uuid),public.dopmi_transition_rescue(uuid,integer,text),
  public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean),public.dopmi_admin_rescue(text,text,integer),
  public.dopmi_rescue_detail(uuid),public.dopmi_rescue_public(uuid,integer),public.dopmi_rescue_file_access(text,boolean) from public,anon,authenticated;
grant execute on function public.dopmi_save_rescue(text,jsonb,jsonb,jsonb,uuid,integer,uuid),public.dopmi_transition_rescue(uuid,integer,text),
  public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean),public.dopmi_admin_rescue(text,text,integer),public.dopmi_rescue_detail(uuid) to authenticated;
grant execute on function public.dopmi_rescue_public(uuid,integer),public.dopmi_rescue_file_access(text,boolean) to anon,authenticated;
do $$ begin if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.dopmi_rescue_records;
end if; end $$;
commit;
