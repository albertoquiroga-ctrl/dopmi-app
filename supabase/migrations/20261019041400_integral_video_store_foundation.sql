begin;

-- BEGIN DOPMI VIDEO MEDIA
-- PREPARED ONLY. No provider enabled; no historical record is resubmitted.
-- Migration generator/integrator must preserve this body and validate against actual remote history.
alter table public.dopmi_rescue_records add column video_thanks_required boolean not null default false;
alter table public.dopmi_rescue_records alter column video_thanks_required set default true;
create table private.dopmi_video_settings(singleton boolean primary key default true check(singleton), enabled boolean not null default false);
insert into private.dopmi_video_settings values(true,false);
alter table private.dopmi_video_settings enable row level security;
revoke all on private.dopmi_video_settings from public,anon,authenticated,service_role;
create table private.dopmi_video_assets (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade,
 parent_id uuid not null references public.dopmi_rescue_records(id) on delete cascade, parent_version integer not null,
 purpose text not null check(purpose in ('thanks','urgency','expense_evidence','public_update','farewell')),
 file_fingerprint text check(file_fingerprint is null or file_fingerprint ~ '^[a-f0-9]{64}$'),
 request_key uuid not null, bytes bigint not null check(bytes between 1 and 209715200),
 content_snapshot jsonb not null,
 technical_state text not null default 'reserved' check(technical_state in ('reserved','provisioning_unknown','uploading','processing','ready','failed','canceled','deleted')),
 moderation_state text not null default 'pending' check(moderation_state in ('pending','approved','rejected','stale')),
 provider_id text unique check(provider_id ~ '^[a-f0-9]{32}$'), upload_url text,
 duration numeric, approved_parent_snapshot jsonb, review_note text not null default '',
 reviewer_id uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(owner_id,request_key),check(duration is null or duration>=0)
);
alter table private.dopmi_video_assets enable row level security;
revoke all on private.dopmi_video_assets from public,anon,authenticated,service_role;
create table private.dopmi_video_reviews (
 id uuid primary key default gen_random_uuid(),asset_id uuid not null references private.dopmi_video_assets(id) on delete cascade,
 reviewer_id uuid references public.profiles(id) on delete set null,parent_version integer not null,
 decision text not null check(decision in ('approved','rejected')),note text not null,snapshot jsonb not null,created_at timestamptz not null default now()
);
alter table private.dopmi_video_reviews enable row level security;
revoke all on private.dopmi_video_reviews from public,anon,authenticated,service_role;
create index dopmi_video_parent on private.dopmi_video_assets(parent_id,created_at,id);

-- Durable provider deletion queue survives local parent/account deletion. Service-only drain is
-- part of the provider operation package; no scheduler or remote deletion is activated here.
create table private.dopmi_video_deletion_queue(provider_id text primary key,created_at timestamptz not null default now());
alter table private.dopmi_video_deletion_queue enable row level security;
revoke all on private.dopmi_video_deletion_queue from public,anon,authenticated,service_role;
create function private.dopmi_video_delete_enqueue() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.provider_id is not null and old.technical_state<>'deleted' then
  insert into private.dopmi_video_deletion_queue(provider_id) values(old.provider_id) on conflict do nothing;
 end if;
 return old;
end;
$$;
revoke all on function private.dopmi_video_delete_enqueue() from public,anon,authenticated,service_role;
create trigger dopmi_video_delete_enqueue after delete on private.dopmi_video_assets for each row execute function private.dopmi_video_delete_enqueue();

create function private.dopmi_video_content(r public.dopmi_rescue_records) returns jsonb
language sql immutable set search_path='' as $$ select jsonb_build_object('public',r.public_data,'private',r.private_data,'files',r.files,'parent',r.parent_id,'kind',r.kind); $$;

create function private.dopmi_video_urgency_allowed(r public.dopmi_rescue_records) returns boolean
language sql stable security definer set search_path='' as $$
 select r.kind='case' and (
  exists(select 1 from jsonb_array_elements(case when jsonb_typeof(r.public_data->'need_items')='array' then r.public_data->'need_items' else '[]'::jsonb end) item
   where item->>'type' in ('veterinary','medicine') and item->'urgent'='true'::jsonb)
  or exists(select 1 from public.dopmi_rescue_records expense where expense.kind='expense' and expense.parent_id=r.id and expense.owner_id=r.owner_id
   and expense.public_data->>'category' in ('veterinary','medicine') and btrim(coalesce(expense.private_data->>'urgency_reason',''))<>''));
$$;
revoke all on function private.dopmi_video_urgency_allowed(public.dopmi_rescue_records) from public,anon,authenticated,service_role;

create function private.dopmi_video_public(a private.dopmi_video_assets,r public.dopmi_rescue_records) returns boolean
language sql stable security definer set search_path='' as $$
 select a.purpose<>'expense_evidence' and (a.purpose<>'urgency' or private.dopmi_video_urgency_allowed(r)) and a.moderation_state='approved' and a.technical_state='ready'
 and a.approved_parent_snapshot is not null and a.approved_parent_snapshot=r.approved_snapshot
 and private.dopmi_rescue_public_visible(r);
$$;

create function public.dopmi_video_action(data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a private.dopmi_video_assets; r public.dopmi_rescue_records; op text:=data->>'action'; actor uuid:=auth.uid(); staff boolean; active boolean:=coalesce(public.dopmi_actor_active(),false);
begin
 if not active and op not in ('public_list','playback') then raise exception 'Authentication required' using errcode='42501'; end if;
 staff:=case when active then public.dopmi_is_admin() else false end;
 if op='public_list' then
  return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(x)) from
   (select media_row.id,media_row.parent_id,media_row.purpose,media_row.duration,media_row.created_at from private.dopmi_video_assets media_row join public.dopmi_rescue_records parent_row on parent_row.id=media_row.parent_id
    where media_row.parent_id=(data->>'parent_id')::uuid and private.dopmi_video_public(media_row,parent_row) order by media_row.created_at,media_row.id limit 100) x),'[]'::jsonb));
 end if;
 if op='list' then
  if not staff then raise exception 'Reviewer required' using errcode='42501'; end if;
  return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(x)) from
   (select media_row.id,media_row.parent_id,media_row.parent_version,parent_row.version as current_parent_version,media_row.purpose,media_row.technical_state,media_row.moderation_state,media_row.duration,media_row.created_at from private.dopmi_video_assets media_row join public.dopmi_rescue_records parent_row on parent_row.id=media_row.parent_id where media_row.technical_state not in ('canceled','deleted') and parent_row.status<>'draft' order by media_row.created_at,media_row.id limit 100) x),'[]'::jsonb));
 end if;
 if op='begin' then
  if not (select enabled from private.dopmi_video_settings where singleton) then raise exception 'Video unavailable' using errcode='55000'; end if;
  select * into r from public.dopmi_rescue_records where id=(data->>'parent_id')::uuid for update;
  if not found or r.owner_id<>actor or r.kind not in ('case','expense') then raise exception 'Invalid owner or parent' using errcode='42501'; end if;
  if data->>'purpose'='urgency' and (not private.dopmi_video_urgency_allowed(r) or coalesce(r.public_data->>'urgency_photo_path','')<>'') then raise exception 'El complemento de urgencia requiere un caso urgente y admite una foto o un video' using errcode='22023';end if;
  select * into a from private.dopmi_video_assets where owner_id=actor and request_key=(data->>'request_key')::uuid for update;
  if found then
   if a.parent_id<>r.id or a.parent_version<>(data->>'parent_version')::integer or a.purpose<>data->>'purpose' or a.bytes<>(data->>'bytes')::bigint or a.content_snapshot<>private.dopmi_video_content(r) or a.file_fingerprint is distinct from (data->>'file_fingerprint') or a.technical_state in ('canceled','deleted') then raise exception 'Idempotency conflict' using errcode='40001';end if;
   return jsonb_build_object('id',a.id,'parent_id',a.parent_id,'parent_version',a.parent_version,'purpose',a.purpose,'technical_state',a.technical_state,'moderation_state',a.moderation_state,'duration',a.duration,'upload_url',case when a.technical_state='uploading' then a.upload_url else null end);
  end if;
  if r.version is distinct from (data->>'parent_version')::integer then raise exception 'Stale parent' using errcode='40001'; end if;
  if data->>'purpose' not in ('thanks','urgency','expense_evidence','public_update','farewell')
   or (data->>'purpose'='expense_evidence' and r.kind<>'expense')
   or (data->>'purpose' in ('thanks','public_update','farewell') and r.kind<>'case')
   or (r.status='closed' and data->>'purpose'<>'farewell') then raise exception 'Invalid purpose' using errcode='22023'; end if;
  if r.status not in ('draft','changes_requested','rejected','approved','closed') then raise exception 'Parent not editable' using errcode='55000'; end if;
  insert into private.dopmi_video_assets(owner_id,parent_id,parent_version,purpose,request_key,bytes,content_snapshot,file_fingerprint)
   values(actor,r.id,r.version,data->>'purpose',(data->>'request_key')::uuid,(data->>'bytes')::bigint,private.dopmi_video_content(r),data->>'file_fingerprint')
   on conflict(owner_id,request_key) do nothing;
  select * into a from private.dopmi_video_assets where owner_id=actor and request_key=(data->>'request_key')::uuid for update;
  if a.parent_id<>r.id or a.parent_version<>r.version or a.purpose<>data->>'purpose' or a.bytes<>(data->>'bytes')::bigint
   or a.content_snapshot<>private.dopmi_video_content(r) or a.file_fingerprint is distinct from (data->>'file_fingerprint') or a.technical_state in ('canceled','deleted') then raise exception 'Idempotency conflict' using errcode='40001'; end if;
 else
  select * into a from private.dopmi_video_assets where id=(data->>'id')::uuid for update;
  if not found then raise exception 'Unavailable' using errcode='42501'; end if;
  select * into r from public.dopmi_rescue_records where id=a.parent_id;
  if op='playback' then
   if not ((active and a.owner_id=actor) or (staff and r.status<>'draft') or private.dopmi_video_public(a,r)) then raise exception 'Unavailable' using errcode='42501'; end if;
  elsif op='review' then
   if not staff or r.status='draft' then raise exception 'Reviewer required' using errcode='42501'; end if;
   if r.version is distinct from (data->>'parent_version')::integer or a.content_snapshot<>private.dopmi_video_content(r) then raise exception 'Stale parent' using errcode='40001'; end if;
   if data->>'decision' not in ('approved','rejected') or a.technical_state<>'ready' then raise exception 'Invalid review' using errcode='22023'; end if;
   insert into private.dopmi_video_reviews(asset_id,reviewer_id,parent_version,decision,note,snapshot) values(a.id,actor,r.version,data->>'decision',left(coalesce(data->>'note',''),1000),jsonb_build_object('content',a.content_snapshot,'purpose',a.purpose,'duration',a.duration));
   update private.dopmi_video_assets set moderation_state=data->>'decision',reviewer_id=actor,review_note=left(coalesce(data->>'note',''),1000),
    approved_parent_snapshot=case when data->>'decision'='approved' and private.dopmi_rescue_public_visible(r) then r.approved_snapshot else null end,updated_at=now() where id=a.id returning * into a;
  elsif op in ('status','cancel') then
   if a.owner_id<>actor and not (staff and op='status' and r.status<>'draft') then raise exception 'Owner required' using errcode='42501'; end if;
   if op='cancel' and a.purpose='expense_evidence' and (exists(select 1 from public.dopmi_donations d where d.expense_id=a.parent_id) or exists(select 1 from private.dopmi_case_allocations c where c.expense_id=a.parent_id) or exists(select 1 from private.dopmi_guardian_allocations g where g.expense_id=a.parent_id)) then raise exception 'Financial evidence retained' using errcode='42501';end if;
   if op='cancel' and a.provider_id is not null then insert into private.dopmi_video_deletion_queue(provider_id) values(a.provider_id) on conflict do nothing;end if;
   if op='cancel' then update private.dopmi_video_assets set technical_state='canceled',upload_url=null,approved_parent_snapshot=null,updated_at=now() where id=a.id returning * into a; end if;
  else raise exception 'Invalid operation' using errcode='22023'; end if;
 end if;
 return jsonb_build_object('id',a.id,'parent_id',a.parent_id,'parent_version',a.parent_version,'purpose',a.purpose,'technical_state',a.technical_state,'moderation_state',a.moderation_state,'duration',a.duration,
  'provider_id',case when op in ('status','playback','cancel') then a.provider_id else null end,
  'upload_url',case when a.owner_id=actor and op in ('begin','status') and a.technical_state='uploading' then a.upload_url else null end);
end;
$$;
revoke all on function public.dopmi_video_action(jsonb) from public;
grant execute on function public.dopmi_video_action(jsonb) to anon,authenticated;

create function public.dopmi_video_service(data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a private.dopmi_video_assets; op text:=data->>'action';
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'Service required' using errcode='42501'; end if;
 if op='cleanup_list' then return jsonb_build_object('items',coalesce((select jsonb_agg(provider_id) from (select provider_id from private.dopmi_video_deletion_queue order by created_at,provider_id limit 20) q),'[]'::jsonb));
 elsif op='orphan_enqueue' then
  if data->>'provider_id' !~ '^[a-f0-9]{32}$' then raise exception 'Invalid provider';end if;
  if exists(select 1 from private.dopmi_video_assets v where v.provider_id=data->>'provider_id' and v.technical_state not in ('canceled','deleted','provisioning_unknown')) then return jsonb_build_object('retained',true);end if;
  update private.dopmi_video_assets set technical_state='canceled',upload_url=null,approved_parent_snapshot=null,updated_at=now() where provider_id=data->>'provider_id' and technical_state='provisioning_unknown';
  insert into private.dopmi_video_deletion_queue(provider_id) values(data->>'provider_id') on conflict do nothing;return jsonb_build_object('queued',true);
 elsif op='cleanup_done' then delete from private.dopmi_video_deletion_queue where provider_id=data->>'provider_id';return jsonb_build_object('ok',true);end if;
 if op='refresh' then select * into a from private.dopmi_video_assets where provider_id=data->>'provider_id' for update;
 else select * into a from private.dopmi_video_assets where id=(data->>'id')::uuid for update; end if;
 if not found and op='created' then
  insert into private.dopmi_video_deletion_queue(provider_id) values(data->>'provider_id') on conflict do nothing;return jsonb_build_object('technical_state','canceled');
 elsif not found and op='binding' then return jsonb_build_object('bound',false);
 elsif not found then raise exception 'Unavailable' using errcode='22023'; end if;
 if op='created' then
  if a.provider_id is not null and a.provider_id<>data->>'provider_id' then raise exception 'Provider conflict';end if;
  update private.dopmi_video_assets set provider_id=data->>'provider_id',updated_at=now() where id=a.id returning * into a;
  if a.technical_state in ('canceled','deleted') then insert into private.dopmi_video_deletion_queue(provider_id) values(a.provider_id) on conflict do nothing;end if;
  return jsonb_build_object('id',a.id,'technical_state',a.technical_state);
 elsif op='binding' then
  return jsonb_build_object('bound',a.provider_id=data->>'provider_id' and a.technical_state in ('uploading','processing','ready','failed'),'technical_state',a.technical_state,'id',a.id,'moderation_state',a.moderation_state,'upload_url',a.upload_url);
 elsif op='claim' then
  if a.technical_state<>'reserved' then return jsonb_build_object('claimed',false); end if;
  update private.dopmi_video_assets set technical_state='provisioning_unknown',updated_at=now() where id=a.id;
  return jsonb_build_object('claimed',true);
 elsif op='bind' then
  if a.provider_id=data->>'provider_id' and a.upload_url is not null and a.technical_state not in ('canceled','deleted') then return jsonb_build_object('id',a.id,'technical_state',a.technical_state,'moderation_state',a.moderation_state,'upload_url',a.upload_url);end if;
  if a.technical_state<>'provisioning_unknown' or (a.provider_id is not null and a.provider_id<>data->>'provider_id') then raise exception 'Invalid bind' using errcode='40001'; end if;
  if data->>'upload_url' !~ '^https://(upload\.videodelivery\.net|upload\.cloudflarestream\.com)/' then raise exception 'Invalid provider URL'; end if;
  update private.dopmi_video_assets set provider_id=data->>'provider_id',upload_url=data->>'upload_url',technical_state='uploading',updated_at=now() where id=a.id returning * into a;
 elsif op='refresh' then
  -- Repeated, delayed and replayed hooks never resurrect canceled/deleted or undo ready.
  if a.technical_state not in ('canceled','deleted','failed') and not (a.technical_state='ready' and data->>'state'='processing') then
   if data->>'state' not in ('uploading','processing','ready','failed') or (data->>'state'='ready' and ((data->>'duration') is null or (data->>'duration')::numeric<=0 or (data->>'duration')::numeric>60)) then raise exception 'Invalid processing result'; end if;
   update private.dopmi_video_assets set technical_state=case when a.technical_state='uploading' and data->>'state'='uploading' then 'uploading' else data->>'state' end,duration=(data->>'duration')::numeric,upload_url=case when data->>'state'='uploading' then upload_url else null end,updated_at=now() where id=a.id returning * into a;
  end if;
 elsif op='deleted' then
  if a.technical_state<>'canceled' then raise exception 'Cancel first'; end if;
  update private.dopmi_video_assets set technical_state='deleted',updated_at=now() where id=a.id returning * into a;
 else raise exception 'Invalid service operation'; end if;
 return jsonb_build_object('id',a.id,'technical_state',a.technical_state,'moderation_state',a.moderation_state,'upload_url',a.upload_url);
end;
$$;
revoke all on function public.dopmi_video_service(jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_video_service(jsonb) to service_role;

create function private.dopmi_video_submission_guard() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not (select enabled from private.dopmi_video_settings where singleton) and new.kind='case' and new.status in ('submitted','approved') then new.video_thanks_required:=false;end if;
 if (select enabled from private.dopmi_video_settings where singleton) and new.kind='case' and new.video_thanks_required and new.status in ('submitted','approved') and old.status is distinct from new.status then
  if not exists(select 1 from private.dopmi_video_assets a where a.parent_id=new.id and a.purpose='thanks' and a.technical_state='ready'
   and a.content_snapshot=private.dopmi_video_content(new) and a.moderation_state in ('pending','approved')
   and (new.status<>'approved' or a.moderation_state='approved')) then
   raise exception 'Agradecimiento requerido: carga un video listo y aprobado antes de publicar' using errcode='23514';
  end if;
 end if;
 return new;
end;
$$;
create trigger dopmi_video_submission_guard before update on public.dopmi_rescue_records for each row execute function private.dopmi_video_submission_guard();
revoke all on function private.dopmi_video_submission_guard() from public,anon,authenticated,service_role;

create function private.dopmi_video_parent_transition() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 -- Content edits invalidate pending media; published snapshots remain immutable until new review.
 if private.dopmi_video_content(old) is distinct from private.dopmi_video_content(new) then
  update private.dopmi_video_assets set moderation_state='stale',approved_parent_snapshot=null,updated_at=now() where parent_id=new.id and technical_state not in ('canceled','deleted');
 elsif new.status='approved' and old.status is distinct from 'approved' then
  update private.dopmi_video_assets set approved_parent_snapshot=new.approved_snapshot,updated_at=now()
   where parent_id=new.id and moderation_state='approved' and purpose<>'expense_evidence' and content_snapshot=private.dopmi_video_content(new);
 end if;
 return new;
end;
$$;
create trigger dopmi_video_parent_transition after update on public.dopmi_rescue_records for each row execute function private.dopmi_video_parent_transition();
revoke all on function private.dopmi_video_content(public.dopmi_rescue_records),private.dopmi_video_public(private.dopmi_video_assets,public.dopmi_rescue_records),private.dopmi_video_parent_transition() from public,anon,authenticated,service_role;

create function public.dopmi_video_policy(target_parent uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.dopmi_rescue_records;
begin
 if not public.dopmi_actor_active() then raise exception 'Owner required' using errcode='42501';end if;
 select * into r from public.dopmi_rescue_records where id=target_parent and owner_id=auth.uid();
 if not found then raise exception 'Owner required' using errcode='42501';end if;
 return jsonb_build_object('enabled',(select enabled from private.dopmi_video_settings where singleton),'thanks_required',r.kind='case' and r.video_thanks_required,'urgency_allowed',private.dopmi_video_urgency_allowed(r),'assets',coalesce((select jsonb_agg(to_jsonb(v)) from
 (select id,parent_id,parent_version,purpose,technical_state,moderation_state,duration,request_key,bytes,file_fingerprint,(content_snapshot=private.dopmi_video_content(r) and moderation_state<>'stale' and (purpose<>'urgency' or private.dopmi_video_urgency_allowed(r))) as matches_current_content from private.dopmi_video_assets where parent_id=r.id and owner_id=auth.uid() and technical_state not in ('canceled','deleted') order by created_at desc,id) v),'[]'::jsonb));
end;
$$;
revoke all on function public.dopmi_video_policy(uuid) from public,anon;
grant execute on function public.dopmi_video_policy(uuid) to authenticated;

create function private.dopmi_video_account_transition() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.account_status in ('deletion_requested','deleted') and old.account_status is distinct from new.account_status then
  -- The existing financial purge policy retains linked expense parents. Their originals
  -- stay private; public/product videos are queued even when a financial case remains.
  delete from private.dopmi_video_assets where owner_id=new.id and purpose<>'expense_evidence';
 end if;
 return new;
end;
$$;
revoke all on function private.dopmi_video_account_transition() from public,anon,authenticated,service_role;
create trigger dopmi_video_account_transition after update on public.profiles for each row execute function private.dopmi_video_account_transition();


-- One optional urgency attachment belongs to the CASE, never a financial receipt.
create unique index dopmi_one_active_urgency_video on private.dopmi_video_assets(parent_id)
 where purpose='urgency' and technical_state not in ('canceled','deleted');

-- Extend the existing normalized case contract without admitting extra attachment keys.
do $urgency_fields$
declare definition text:=pg_get_functiondef('private.dopmi_case_fields(jsonb)'::regprocedure);
 normalization text:='data-''need_items''-''size''';
 anchor text:='if not data ? ''need_items'' then return normalized; end if;';
 insertion text:=$body$if data ? 'urgency_photo_path' and coalesce(data->>'urgency_photo_path','')<>'' then
    if jsonb_typeof(data->'urgency_photo_path') is distinct from 'string' or char_length(data->>'urgency_photo_path')>180 then
      raise exception 'Foto de urgencia inválida' using errcode='22023';end if;
    normalized:=normalized||jsonb_build_object('urgency_photo_path',data->>'urgency_photo_path');
  end if;
  $body$;
begin
 if position(normalization in definition)=0 or position(anchor in definition)=0 then raise exception 'Review current case field normalizer before extending urgency media';end if;
 execute replace(replace(definition,normalization,normalization||'-''urgency_photo_path'''),anchor,insertion||anchor);
end;
$urgency_fields$;

create function private.dopmi_video_urgency_photo_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare photo text:=coalesce(new.public_data->>'urgency_photo_path','');
begin
 if photo='' then return new;end if;
 if new.kind<>'case' or not private.dopmi_video_urgency_allowed(new)
  or jsonb_typeof(new.public_data->'urgency_photo_path') is distinct from 'string'
  or photo !~ ('^'||new.owner_id::text||'/'||new.id::text||'/[0-9a-f-]{36}\.(jpg|png|webp)$')
  or not exists(select 1 from jsonb_array_elements(new.files) attachment where attachment->>'role'='public' and attachment->>'path'=photo and attachment-'path'-'role'='{}'::jsonb)
  or not exists(select 1 from storage.objects where bucket_id='dopmi-rescue-evidence' and name=photo)
  or exists(select 1 from private.dopmi_video_assets where parent_id=new.id and purpose='urgency' and technical_state not in ('canceled','deleted')) then
   raise exception 'Elige una foto pública propia o un video de urgencia, no ambos' using errcode='22023';
 end if;
 return new;
end;
$$;
revoke all on function private.dopmi_video_urgency_photo_guard() from public,anon,authenticated,service_role;
create trigger dopmi_video_urgency_photo_guard before insert or update on public.dopmi_rescue_records
 for each row execute function private.dopmi_video_urgency_photo_guard();
-- END DOPMI VIDEO MEDIA

-- BEGIN DOPMI STORE CATALOG
-- Additive Tienda package. Integrator creates the migration via CLI.
-- No public activation, seed catalog, real commerce, or deployment is included.
create table private.dopmi_store_settings (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false,
  activation_reference text not null default '',
  check(not enabled or length(trim(activation_reference)) >= 10)
);
insert into private.dopmi_store_settings(singleton) values(true);
create table private.dopmi_store_merchants (
  id uuid primary key default gen_random_uuid(), version integer not null default 1,
  data jsonb not null, updated_at timestamptz not null default now(), updated_by uuid not null references auth.users(id)
);
create table private.dopmi_store_products (
  id uuid primary key default gen_random_uuid(), version integer not null default 1,
  merchant_id uuid not null references private.dopmi_store_merchants(id),
  data jsonb not null, updated_at timestamptz not null default now(), updated_by uuid not null references auth.users(id)
);
alter table private.dopmi_store_settings enable row level security;
alter table private.dopmi_store_merchants enable row level security;
alter table private.dopmi_store_products enable row level security;
revoke all on private.dopmi_store_settings, private.dopmi_store_merchants, private.dopmi_store_products from public, anon, authenticated;

create function private.dopmi_store_url_ok(link text, domain text) returns boolean
language sql immutable set search_path='' as $$
  select coalesce(domain ~ '^[a-z0-9]+([.-][a-z0-9]+)*\.[a-z]{2,}$'
    and link ~ ('^https://' || replace(domain,'.','\.') || '(/[^[:space:]\\#]*)?$')
    and link !~* '(redirect|return_url|returnurl|destination|[?&](url|next|target)=)', false);
$$;
revoke all on function private.dopmi_store_url_ok(text,text) from public, anon, authenticated;

create function private.dopmi_store_merchant_ready(d jsonb) returns boolean
language sql immutable set search_path='' as $$
  select coalesce(d->>'enabled'='true' and d->>'permission_reviewed'='true'
    and d->>'rights_reviewed'='true' and d->>'links_reviewed'='true'
    and length(trim(d->>'approval_reference'))>=10,false);
$$;
revoke all on function private.dopmi_store_merchant_ready(jsonb) from public, anon, authenticated;

create function public.dopmi_admin_store_catalog() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  return jsonb_build_object('enabled',(select enabled from private.dopmi_store_settings),
    'merchants',coalesce((select jsonb_agg(jsonb_build_object('id',id,'version',version,'data',data) order by updated_at,id) from private.dopmi_store_merchants),'[]'::jsonb),
    'products',coalesce((select jsonb_agg(jsonb_build_object('id',id,'version',version,'merchant_id',merchant_id,'data',data) order by updated_at,id) from private.dopmi_store_products),'[]'::jsonb));
end $$;

create function public.dopmi_admin_save_store(entity text, item_id uuid, expected_version integer, payload jsonb, merchant uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare next_id uuid; next_version integer; m jsonb; key text;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if jsonb_typeof(payload) <> 'object' or octet_length(payload::text)>20000 then raise exception 'Datos de catálogo inválidos'; end if;
  if coalesce(length(trim(payload->>'name')),0) not between 1 and 160 then raise exception 'Escribe un nombre de hasta 160 caracteres'; end if;
  if entity='merchant' then
    for key in select jsonb_object_keys(payload) loop
      if key not in ('name','domain','image_domain','enabled','permission_reviewed','rights_reviewed','links_reviewed','approval_reference') then raise exception 'Campo de comercio desconocido'; end if;
    end loop;
    if not private.dopmi_store_url_ok('https://' || coalesce(payload->>'domain','') || '/',payload->>'domain') then raise exception 'Dominio inválido'; end if;
    if coalesce(payload->>'image_domain','')<>'' and not private.dopmi_store_url_ok('https://' || (payload->>'image_domain') || '/',payload->>'image_domain') then raise exception 'Dominio de imágenes inválido'; end if;
    foreach key in array array['enabled','permission_reviewed','rights_reviewed','links_reviewed'] loop
      if coalesce(jsonb_typeof(payload->key),'')<>'boolean' then raise exception 'Indicador inválido'; end if;
    end loop;
    if payload->>'enabled'='true' and not private.dopmi_store_merchant_ready(payload) then raise exception 'Falta revisión comercial, derechos o enlaces'; end if;
    if item_id is null or expected_version=0 then
      insert into private.dopmi_store_merchants(id,data,updated_by) values(coalesce(item_id,gen_random_uuid()),payload,auth.uid()) on conflict(id) do nothing returning id,version into next_id,next_version;
      if next_id is null and item_id is not null then
        select id,version into next_id,next_version from private.dopmi_store_merchants where id=item_id and version=1 and updated_by=auth.uid() and data=payload;
      end if;
    else
      update private.dopmi_store_merchants set data=payload,version=version+1,updated_by=auth.uid(),updated_at=now() where id=item_id and version=expected_version returning id,version into next_id,next_version;
    end if;
  elsif entity='product' then
    for key in select jsonb_object_keys(payload) loop
      if key not in ('name','brand','species','age','size','weight_kg','image_url','image_rights_reference','external_url','published','position') then raise exception 'Campo de producto desconocido'; end if;
    end loop;
    select data into m from private.dopmi_store_merchants where id=merchant for share;
    if m is null then raise exception 'Comercio inexistente'; end if;
    if coalesce(length(trim(payload->>'brand')),0) not between 1 and 100
      or coalesce(payload->>'species','') not in ('dog','cat')
      or coalesce(payload->>'age','') not in ('puppy','adult','senior')
      or coalesce(payload->>'size','') not in ('small','medium','large')
      or coalesce(jsonb_typeof(payload->'weight_kg'),'')<>'number'
      or (payload->>'weight_kg')::numeric<=0 or (payload->>'weight_kg')::numeric>1000
      or coalesce(jsonb_typeof(payload->'position'),'')<>'number'
      or (payload->>'position')::numeric not between 0 and 100000
      or coalesce(jsonb_typeof(payload->'published'),'')<>'boolean' then raise exception 'Ficha de producto inválida'; end if;
    if not private.dopmi_store_url_ok(payload->>'external_url',m->>'domain') then raise exception 'El enlace debe ser HTTPS del dominio autorizado, sin redirección'; end if;
    if payload->>'published'='true' and (not private.dopmi_store_merchant_ready(m)
      or not private.dopmi_store_url_ok(payload->>'image_url',coalesce(nullif(m->>'image_domain',''),m->>'domain'))
      or coalesce(length(trim(payload->>'image_rights_reference')),0)<10) then raise exception 'Faltan derechos de imagen o autorización comercial'; end if;
    if item_id is null or expected_version=0 then
      insert into private.dopmi_store_products(id,merchant_id,data,updated_by) values(coalesce(item_id,gen_random_uuid()),merchant,payload,auth.uid()) on conflict(id) do nothing returning id,version into next_id,next_version;
      if next_id is null and item_id is not null then
        select id,version into next_id,next_version from private.dopmi_store_products where id=item_id and version=1 and updated_by=auth.uid() and data=payload and merchant_id=merchant;
      end if;
    else
      update private.dopmi_store_products set merchant_id=merchant,data=payload,version=version+1,updated_by=auth.uid(),updated_at=now() where id=item_id and version=expected_version returning id,version into next_id,next_version;
    end if;
  else raise exception 'Tipo de catálogo inválido'; end if;
  if next_id is null then raise exception 'El registro cambió. Actualiza antes de guardar' using errcode='40001'; end if;
  return jsonb_build_object('id',next_id,'version',next_version);
end $$;

create function public.dopmi_admin_delete_store(entity text, item_id uuid, expected_version integer) returns void
language plpgsql security definer set search_path='' as $$
declare removed uuid;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if entity='product' then delete from private.dopmi_store_products where id=item_id and version=expected_version returning id into removed;
  elsif entity='merchant' then delete from private.dopmi_store_merchants where id=item_id and version=expected_version returning id into removed;
  else raise exception 'Tipo de catálogo inválido'; end if;
  if removed is null then raise exception 'El registro cambió. Actualiza antes de eliminar' using errcode='40001'; end if;
end $$;

create function public.dopmi_store_catalog(filters jsonb default '{}'::jsonb) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('enabled',coalesce((select enabled from private.dopmi_store_settings),false),'items',coalesce((
    select jsonb_agg(item order by sort_weight,position,id) from (
      select p.id,(p.data->>'position')::numeric position,
        case filters->>'sort' when 'weight_asc' then (p.data->>'weight_kg')::numeric when 'weight_desc' then -(p.data->>'weight_kg')::numeric else 0 end sort_weight,
        jsonb_build_object('id',p.id,'name',p.data->>'name','brand',p.data->>'brand','species',p.data->>'species','age',p.data->>'age','size',p.data->>'size','weight_kg',p.data->'weight_kg','image_url',p.data->>'image_url','merchant_name',m.data->>'name') item
      from private.dopmi_store_products p join private.dopmi_store_merchants m on m.id=p.merchant_id
      where (select enabled from private.dopmi_store_settings) and p.data->>'published'='true'
        and private.dopmi_store_merchant_ready(m.data)
        and private.dopmi_store_url_ok(p.data->>'external_url',m.data->>'domain')
        and private.dopmi_store_url_ok(p.data->>'image_url',coalesce(nullif(m.data->>'image_domain',''),m.data->>'domain'))
        and not exists(select 1 from unnest(array['species','age','size','brand']) k where coalesce(filters->>k,'')<>'' and p.data->>k <> filters->>k)
    ) visible),'[]'::jsonb));
$$;

create function public.dopmi_store_product_link(product_id uuid) returns text
language sql stable security definer set search_path='' as $$
  select p.data->>'external_url' from private.dopmi_store_products p join private.dopmi_store_merchants m on m.id=p.merchant_id
  where p.id=product_id and (select enabled from private.dopmi_store_settings)
    and p.data->>'published'='true' and private.dopmi_store_merchant_ready(m.data)
    and private.dopmi_store_url_ok(p.data->>'external_url',m.data->>'domain')
    and private.dopmi_store_url_ok(p.data->>'image_url',coalesce(nullif(m.data->>'image_domain',''),m.data->>'domain'));
$$;
revoke all on function public.dopmi_admin_store_catalog(),public.dopmi_admin_save_store(text,uuid,integer,jsonb,uuid), public.dopmi_store_catalog(jsonb),public.dopmi_store_product_link(uuid) from public,anon,authenticated;
grant execute on function public.dopmi_admin_store_catalog(),public.dopmi_admin_save_store(text,uuid,integer,jsonb,uuid) to authenticated;
grant execute on function public.dopmi_store_catalog(jsonb),public.dopmi_store_product_link(uuid) to anon,authenticated;
revoke all on function public.dopmi_admin_delete_store(text,uuid,integer) from public,anon,authenticated;
grant execute on function public.dopmi_admin_delete_store(text,uuid,integer) to authenticated;
-- END DOPMI STORE CATALOG

-- BEGIN DOPMI PUBLIC PROFILE ELIGIBILITY
-- Prepared integral20d21 public support eligibility; not applied remotely.
create or replace function public.dopmi_rescuer_public(person_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare verification public.dopmi_rescue_records; edited public.dopmi_rescuer_profiles; profile jsonb; source jsonb;
begin
  select * into verification from public.dopmi_rescue_records where owner_id=person_id and kind='verification' and status='approved' and approved_snapshot is not null order by approved_at desc,id limit 1;
  if not found or not private.dopmi_public_rescuer(person_id) then return null; end if;
  select * into edited from public.dopmi_rescuer_profiles where owner_id=person_id and approved_snapshot is not null;
  source:=case when found then edited.approved_snapshot else verification.approved_snapshot end;
  profile:=jsonb_build_object(
    'id',person_id,'name',coalesce(source->>'display_name',source->>'public_name','Rescatista Dopmi'),'bio',coalesce(source->>'bio',''),
    'city',coalesce(source->>'city',''),'region',coalesce(source->>'region',source->>'state',''),'avatar_path',source->>'avatar_path',
    'instagram_url',coalesce(source->>'instagram_url',''),'facebook_url',coalesce(source->>'facebook_url',''),'verified',true,
    'saved',exists(select 1 from public.dopmi_saved_rescuers s where s.user_id=auth.uid() and s.rescuer_id=person_id and public.dopmi_actor_active()),
    'adopted_count',(select count(*) from public.dopmi_adoptions where owner_id=person_id and status='adopted'),
    'adoptions',coalesce((select jsonb_agg(private.dopmi_public_post(a) order by a.published_at desc,a.id) from public.dopmi_adoptions a where a.owner_id=person_id and a.status='published'),'[]'::jsonb),
    'cases',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'status',r.status,'public_data',r.approved_snapshot,
      'accepts_support',r.status='approved' and exists(
        select 1 from public.dopmi_rescue_records e
        where e.parent_id=r.id and e.kind='expense' and e.status='approved'
          and private.dopmi_rescue_public_visible(e)
          and e.reimbursable_cents>(public.dopmi_expense_funding(e.id)->>'funded_cents')::bigint)) order by r.approved_at desc,r.id) from public.dopmi_rescue_records r where r.owner_id=person_id and r.kind='case' and private.dopmi_rescue_public_visible(r)),'[]'::jsonb),
    'activity',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'case_id',u.case_id,'body',u.approved_snapshot->>'body','photos',u.approved_snapshot->'photos','published_at',u.published_at) order by u.published_at desc,u.id) from public.dopmi_case_updates u where u.owner_id=person_id and u.status='published' and u.approved_snapshot is not null and exists(select 1 from public.dopmi_rescue_records c where c.id=u.case_id and private.dopmi_rescue_public_visible(c))),'[]'::jsonb));
  profile:=profile || jsonb_build_object(
    'member_since',(select created_at from public.profiles where id=person_id),
    'active_adoptions',(select count(*) from public.dopmi_adoptions where owner_id=person_id and status='published'),
    'website_url',case when edited.contact_consent and edited.contact_publication_enabled and coalesce((source->>'contact_consent')::boolean,false) then coalesce(source->>'website_url','') else '' end,
    'public_email',case when edited.contact_consent and edited.contact_publication_enabled and coalesce((source->>'contact_consent')::boolean,false) then coalesce(source->>'public_email','') else '' end,
    'public_address',case when edited.contact_consent and edited.contact_publication_enabled and coalesce((source->>'contact_consent')::boolean,false) then coalesce(source->>'public_address','') else '' end,
    'public_phone',case when edited.contact_consent and edited.contact_publication_enabled and coalesce((source->>'contact_consent')::boolean,false)
      and exists(select 1 from auth.users u where u.id=person_id and ltrim(u.phone,'+')=ltrim(source->>'public_phone','+') and u.phone_confirmed_at is not null)
      then coalesce(source->>'public_phone','') else '' end);
  return profile;
end;
$$;

create or replace function public.dopmi_rescuer_public_metrics(person_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  if public.dopmi_rescuer_public(person_id) is null then return null; end if;
  with cases as materialized (
    select r.id,r.status from public.dopmi_rescue_records r
    where r.owner_id=person_id and r.kind='case' and private.dopmi_rescue_public_visible(r)
  ), expenses as materialized (
    select e.parent_id,e.status,e.reimbursable_cents as target,
      (public.dopmi_expense_funding(e.id)->>'funded_cents')::bigint as funded
    from public.dopmi_rescue_records e join cases c on c.id=e.parent_id
    where e.kind='expense' and private.dopmi_rescue_public_visible(e)
  ), adoptions as materialized (
    -- Historical counts reveal no retired listing identity or unpublished edits.
    select a.id,a.rescue_case_id,a.status from public.dopmi_adoptions a
    where a.owner_id=person_id and a.published_at is not null
  )
  select jsonb_build_object(
    'received_support_pets',(select count(distinct parent_id) from expenses where funded>0),
    'published_cases',(select count(*) from cases),
    'active_donation_cases',(select count(*) from cases c where c.status='approved'
      and exists(select 1 from expenses e where e.parent_id=c.id and e.status='approved' and e.target>e.funded)),
    'active_adoptions',(select count(*) from adoptions where status='published'),
    'published_donation_cases',(select count(*) from cases c where exists(select 1 from expenses e where e.parent_id=c.id)),
    'published_adoptions',(select count(*) from adoptions),
    'funded_cents',(select coalesce(sum(funded),0) from expenses),
    'completed_needs',(select count(*) from expenses where target>0 and funded>=target),
    'helped_pets',(select count(*) from (
      select id from cases union select coalesce(rescue_case_id,id) from adoptions
    ) pets),
    'closed_cases',(select count(*) from cases where status='closed')
  ) into result;
  return result;
end;
$$;
-- END DOPMI PUBLIC PROFILE ELIGIBILITY

commit;
