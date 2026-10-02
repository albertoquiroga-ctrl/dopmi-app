begin;

create table public.dopmi_case_updates (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.dopmi_rescue_records(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 2000),
  photos text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft','submitted','changes_requested','rejected','published','archived')),
  version integer not null default 1,
  approved_snapshot jsonb,
  review_feedback text not null default '' check (char_length(review_feedback) <= 1000),
  submitted_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index dopmi_case_updates_case_public on public.dopmi_case_updates(case_id,published_at,id) where status='published';
create index dopmi_case_updates_owner on public.dopmi_case_updates(owner_id,updated_at desc,id);

create table private.dopmi_case_update_reviews (
  id uuid primary key default gen_random_uuid(),
  update_id uuid not null references public.dopmi_case_updates(id) on delete cascade,
  reviewer_id uuid references auth.users(id),
  decision text not null,
  feedback text not null default '',
  version integer not null,
  snapshot jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.dopmi_case_updates enable row level security;
alter table private.dopmi_case_update_reviews enable row level security;
revoke all on public.dopmi_case_updates from public,anon,authenticated;
revoke all on private.dopmi_case_update_reviews from public,anon,authenticated;
create policy dopmi_case_updates_rpc_only on public.dopmi_case_updates as restrictive for all to authenticated using(false) with check(false);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('dopmi-case-update-media','dopmi-case-update-media',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create function public.dopmi_case_update_file_access(object_name text,writing boolean default false) returns boolean
language plpgsql security definer set search_path='' as $$
declare item public.dopmi_case_updates;
begin
  if object_name is null or object_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then return false; end if;
  select * into item from public.dopmi_case_updates where id::text=split_part(object_name,'/',2);
  if not found or item.owner_id::text<>split_part(object_name,'/',1) then return false; end if;
  if writing then return public.dopmi_actor_active() and item.owner_id=auth.uid() and item.status in ('draft','changes_requested','rejected'); end if;
  return (public.dopmi_actor_active() and item.owner_id=auth.uid()) or public.dopmi_is_admin()
    or (item.status='published' and item.approved_snapshot is not null and coalesce(item.approved_snapshot->'photos','[]'::jsonb) ? object_name);
end;
$$;

create policy dopmi_case_update_files_read on storage.objects for select to anon,authenticated
  using(bucket_id='dopmi-case-update-media' and public.dopmi_case_update_file_access(name));
create policy dopmi_case_update_files_insert on storage.objects for insert to authenticated
  with check(bucket_id='dopmi-case-update-media' and public.dopmi_case_update_file_access(name,true));
create policy dopmi_case_update_files_delete on storage.objects for delete to authenticated
  using(bucket_id='dopmi-case-update-media' and public.dopmi_case_update_file_access(name,true));
create policy dopmi_case_update_read_boundary on storage.objects as restrictive for select to anon,authenticated
  using(bucket_id<>'dopmi-case-update-media' or public.dopmi_case_update_file_access(name));
create policy dopmi_case_update_insert_boundary on storage.objects as restrictive for insert to anon,authenticated
  with check(bucket_id<>'dopmi-case-update-media' or public.dopmi_case_update_file_access(name,true));
create policy dopmi_case_update_delete_boundary on storage.objects as restrictive for delete to anon,authenticated
  using(bucket_id<>'dopmi-case-update-media' or public.dopmi_case_update_file_access(name,true));
create policy dopmi_case_update_update_boundary on storage.objects as restrictive for update to anon,authenticated
  using(bucket_id<>'dopmi-case-update-media') with check(bucket_id<>'dopmi-case-update-media');

create function public.dopmi_save_case_update(target_case uuid,update_id uuid default null,expected_version integer default null,update_body text default '',update_photos text[] default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); item public.dopmi_case_updates; target public.dopmi_rescue_records; photo text;
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  select * into target from public.dopmi_rescue_records where id=target_case and kind='case' and owner_id=actor and status in ('approved','closed');
  if not found then raise exception 'Caso no disponible para avances' using errcode='42501'; end if;
  if char_length(btrim(coalesce(update_body,'')))>2000 or cardinality(coalesce(update_photos,'{}'))>6 then raise exception 'Avance inválido' using errcode='22023'; end if;
  if update_id is null then
    insert into public.dopmi_case_updates(case_id,owner_id) values(target_case,actor) returning * into item;
  else
    select * into item from public.dopmi_case_updates where id=update_id for update;
    if not found or item.owner_id<>actor or item.case_id<>target_case then raise exception 'Avance no disponible' using errcode='42501'; end if;
    if item.version is distinct from expected_version then raise exception 'El avance cambió. Vuelve a cargarlo.' using errcode='40001'; end if;
    if item.status not in ('draft','changes_requested','rejected') then raise exception 'Este avance no se puede editar' using errcode='22023'; end if;
  end if;
  foreach photo in array coalesce(update_photos,'{}') loop
    if photo !~ ('^'||actor::text||'/'||item.id::text||'/[0-9a-f-]{36}\.(jpg|png|webp)$') then raise exception 'Ruta de foto inválida' using errcode='22023'; end if;
  end loop;
  update public.dopmi_case_updates set body=btrim(coalesce(update_body,'')),photos=coalesce(update_photos,'{}'),
    status=case when status in ('changes_requested','rejected') then 'draft' else status end,
    review_feedback='',version=version+1,updated_at=now() where id=item.id returning * into item;
  return to_jsonb(item);
end;
$$;

create function public.dopmi_transition_case_update(update_id uuid,expected_version integer,action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); item public.dopmi_case_updates; photo text;
begin
  select * into item from public.dopmi_case_updates where id=update_id for update;
  if not public.dopmi_actor_active() or not found or item.owner_id<>actor then raise exception 'Avance no disponible' using errcode='42501'; end if;
  if item.version is distinct from expected_version then raise exception 'El avance cambió. Vuelve a cargarlo.' using errcode='40001'; end if;
  if action='submit' then
    if item.status not in ('draft','changes_requested','rejected') or char_length(item.body) not between 10 and 2000 then raise exception 'Completa la historia antes de enviarla' using errcode='22023'; end if;
    foreach photo in array item.photos loop
      if not exists(select 1 from storage.objects where bucket_id='dopmi-case-update-media' and name=photo) then raise exception 'Termina de subir las fotos' using errcode='22023'; end if;
    end loop;
    update public.dopmi_case_updates set status='submitted',submitted_at=now(),version=version+1,updated_at=now() where id=item.id returning * into item;
  elsif action='withdraw' and item.status='submitted' then
    update public.dopmi_case_updates set status='draft',version=version+1,updated_at=now() where id=item.id returning * into item;
  elsif action='archive' and item.status='published' then
    update public.dopmi_case_updates set status='archived',version=version+1,updated_at=now() where id=item.id returning * into item;
  else raise exception 'Transición no disponible' using errcode='22023'; end if;
  return to_jsonb(item);
end;
$$;

create function public.dopmi_my_case_updates(target_case uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc,x.id) from (
    select id,case_id,owner_id,body,photos,status,version,review_feedback,submitted_at,published_at,created_at,updated_at
    from public.dopmi_case_updates where case_id=target_case and owner_id=auth.uid()
  ) x),'[]'::jsonb);
end;
$$;

create function public.dopmi_public_case_updates(target_case uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'case_id',case_id,'body',approved_snapshot->>'body','photos',approved_snapshot->'photos','published_at',published_at) order by published_at,id),'[]'::jsonb)
  from public.dopmi_case_updates where case_id=target_case and status='published' and approved_snapshot is not null
    and exists(select 1 from public.dopmi_rescue_records r where r.id=target_case and private.dopmi_rescue_public_visible(r));
$$;

create function public.dopmi_admin_case_updates(status_filter text default 'submitted',page_number integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if status_filter not in ('submitted','changes_requested','rejected','published') or page_number<1 then raise exception 'Filtros inválidos' using errcode='22023'; end if;
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'case_updates.list');
  return jsonb_build_object('total',(select count(*) from public.dopmi_case_updates where status=status_filter),
    'items',coalesce((select jsonb_agg(to_jsonb(x)) from (select * from public.dopmi_case_updates where status=status_filter order by submitted_at,id limit 20 offset (page_number::bigint-1)*20)x),'[]'::jsonb));
end;
$$;

create function public.dopmi_review_case_update(update_id uuid,expected_version integer,decision text,feedback text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare item public.dopmi_case_updates;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into item from public.dopmi_case_updates where id=update_id for update;
  if not found or item.status<>'submitted' then raise exception 'Avance no disponible' using errcode='22023'; end if;
  if item.version is distinct from expected_version then raise exception 'El avance cambió' using errcode='40001'; end if;
  if decision not in ('published','changes_requested','rejected') or (decision<>'published' and char_length(btrim(coalesce(feedback,'')))<5) then raise exception 'Decisión inválida' using errcode='22023'; end if;
  update public.dopmi_case_updates set status=decision,review_feedback=btrim(coalesce(feedback,'')),
    approved_snapshot=case when decision='published' then jsonb_build_object('body',body,'photos',to_jsonb(photos)) else approved_snapshot end,
    published_at=case when decision='published' then now() else published_at end,version=version+1,updated_at=now()
    where id=item.id returning * into item;
  insert into private.dopmi_case_update_reviews(update_id,reviewer_id,decision,feedback,version,snapshot)
    values(item.id,auth.uid(),decision,btrim(coalesce(feedback,'')),item.version,to_jsonb(item));
  insert into public.dopmi_notifications(user_id,kind,rescue_id,source_id,title)
    values(item.owner_id,'review',item.case_id,item.id,case when decision='published' then 'Tu avance ya está publicado' else 'Tu avance necesita atención' end);
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'case_updates.review');
  return to_jsonb(item);
end;
$$;

revoke all on function public.dopmi_case_update_file_access(text,boolean),public.dopmi_save_case_update(uuid,uuid,integer,text,text[]),public.dopmi_transition_case_update(uuid,integer,text),public.dopmi_my_case_updates(uuid),public.dopmi_public_case_updates(uuid),public.dopmi_admin_case_updates(text,integer),public.dopmi_review_case_update(uuid,integer,text,text) from public,anon,authenticated;
grant execute on function public.dopmi_case_update_file_access(text,boolean),public.dopmi_public_case_updates(uuid) to anon,authenticated;
grant execute on function public.dopmi_save_case_update(uuid,uuid,integer,text,text[]),public.dopmi_transition_case_update(uuid,integer,text),public.dopmi_my_case_updates(uuid),public.dopmi_admin_case_updates(text,integer),public.dopmi_review_case_update(uuid,integer,text,text) to authenticated;

do $$ begin if exists(select 1 from pg_publication where pubname='supabase_realtime') then alter publication supabase_realtime add table public.dopmi_case_updates; end if; end $$;

commit;
