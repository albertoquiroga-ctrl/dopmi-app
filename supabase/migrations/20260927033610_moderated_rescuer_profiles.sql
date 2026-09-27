begin;

create table public.dopmi_rescuer_profiles (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  display_name text not null default '' check(char_length(display_name)<=80),
  bio text not null default '' check(char_length(bio)<=1000),
  city text not null default '' check(char_length(city)<=100),
  region text not null default '' check(char_length(region)<=100),
  instagram_url text not null default '' check(char_length(instagram_url)<=500),
  facebook_url text not null default '' check(char_length(facebook_url)<=500),
  avatar_path text,
  status text not null default 'draft' check(status in ('draft','submitted','changes_requested','rejected','published')),
  version integer not null default 1,
  approved_snapshot jsonb,
  review_feedback text not null default '' check(char_length(review_feedback)<=1000),
  submitted_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index dopmi_rescuer_profiles_review on public.dopmi_rescuer_profiles(status,submitted_at,owner_id);

create table private.dopmi_rescuer_profile_reviews (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  reviewer_id uuid references auth.users(id),
  decision text not null,
  feedback text not null default '',
  version integer not null,
  snapshot jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.dopmi_rescuer_profiles enable row level security;
alter table private.dopmi_rescuer_profile_reviews enable row level security;
revoke all on public.dopmi_rescuer_profiles,private.dopmi_rescuer_profile_reviews from public,anon,authenticated;
create policy dopmi_rescuer_profiles_rpc_only on public.dopmi_rescuer_profiles as restrictive for all to authenticated using(false) with check(false);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('dopmi-rescuer-profile-media','dopmi-rescuer-profile-media',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create function public.dopmi_rescuer_profile_file_access(object_name text,writing boolean default false) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare item public.dopmi_rescuer_profiles;
begin
  if object_name is null or object_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then return false; end if;
  select * into item from public.dopmi_rescuer_profiles where owner_id::text=split_part(object_name,'/',2);
  if not found or item.owner_id::text<>split_part(object_name,'/',1) then return false; end if;
  if writing then return public.dopmi_actor_active() and item.owner_id=auth.uid() and item.status in ('draft','changes_requested','rejected','published'); end if;
  return (public.dopmi_actor_active() and item.owner_id=auth.uid()) or public.dopmi_is_admin()
    or (item.approved_snapshot is not null and item.approved_snapshot->>'avatar_path'=object_name);
end;
$$;

create policy dopmi_rescuer_profile_files_read on storage.objects for select to anon,authenticated
  using(bucket_id='dopmi-rescuer-profile-media' and public.dopmi_rescuer_profile_file_access(name));
create policy dopmi_rescuer_profile_files_insert on storage.objects for insert to authenticated
  with check(bucket_id='dopmi-rescuer-profile-media' and public.dopmi_rescuer_profile_file_access(name,true));
create policy dopmi_rescuer_profile_files_delete on storage.objects for delete to authenticated
  using(bucket_id='dopmi-rescuer-profile-media' and public.dopmi_rescuer_profile_file_access(name,true));
create policy dopmi_rescuer_profile_read_boundary on storage.objects as restrictive for select to anon,authenticated
  using(bucket_id<>'dopmi-rescuer-profile-media' or public.dopmi_rescuer_profile_file_access(name));
create policy dopmi_rescuer_profile_insert_boundary on storage.objects as restrictive for insert to anon,authenticated
  with check(bucket_id<>'dopmi-rescuer-profile-media' or public.dopmi_rescuer_profile_file_access(name,true));
create policy dopmi_rescuer_profile_delete_boundary on storage.objects as restrictive for delete to anon,authenticated
  using(bucket_id<>'dopmi-rescuer-profile-media' or public.dopmi_rescuer_profile_file_access(name,true));
create policy dopmi_rescuer_profile_update_boundary on storage.objects as restrictive for update to anon,authenticated
  using(bucket_id<>'dopmi-rescuer-profile-media') with check(bucket_id<>'dopmi-rescuer-profile-media');

create function public.dopmi_my_rescuer_profile() returns jsonb
language sql stable security definer set search_path='' as $$
  select case when public.dopmi_actor_active() then to_jsonb(p) else null end
  from public.dopmi_rescuer_profiles p where p.owner_id=auth.uid();
$$;

create function public.dopmi_save_rescuer_profile(payload jsonb,expected_version integer default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); item public.dopmi_rescuer_profiles; avatar text; ig text; fb text;
begin
  if jsonb_typeof(payload) is distinct from 'object' or char_length(payload::text)>5000
    or payload - array['display_name','bio','city','region','instagram_url','facebook_url','avatar_path']::text[] <> '{}'::jsonb then
    raise exception 'Perfil inválido' using errcode='22023'; end if;
  select * into item from public.dopmi_rescuer_profiles where owner_id=actor for update;
  if not found then
    if expected_version is not null then raise exception 'El perfil cambió. Vuelve a cargarlo.' using errcode='40001'; end if;
    insert into public.dopmi_rescuer_profiles(owner_id) values(actor) returning * into item;
  elsif expected_version is distinct from item.version then raise exception 'El perfil cambió. Vuelve a cargarlo.' using errcode='40001';
  elsif item.status='submitted' then raise exception 'Retira el perfil de revisión antes de editar.' using errcode='22023'; end if;
  avatar:=nullif(payload->>'avatar_path',''); ig:=btrim(coalesce(payload->>'instagram_url','')); fb:=btrim(coalesce(payload->>'facebook_url',''));
  if avatar is not null and avatar !~ ('^'||actor::text||'/'||actor::text||'/[0-9a-f-]{36}\.(jpg|png|webp)$') then raise exception 'Avatar inválido' using errcode='22023'; end if;
  if (ig<>'' and ig !~ '^https://(www\.)?instagram\.com/') or (fb<>'' and fb !~ '^https://(www\.)?facebook\.com/') then raise exception 'Usa enlaces https válidos de Instagram o Facebook' using errcode='22023'; end if;
  update public.dopmi_rescuer_profiles set
    display_name=btrim(coalesce(payload->>'display_name','')),bio=btrim(coalesce(payload->>'bio','')),
    city=btrim(coalesce(payload->>'city','')),region=btrim(coalesce(payload->>'region','')),
    instagram_url=ig,facebook_url=fb,avatar_path=avatar,
    status='draft',review_feedback='',submitted_at=null,version=item.version+1,updated_at=now()
  where owner_id=actor returning * into item;
  return to_jsonb(item);
end;
$$;

create function public.dopmi_transition_rescuer_profile(expected_version integer,action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); item public.dopmi_rescuer_profiles;
begin
  select * into item from public.dopmi_rescuer_profiles where owner_id=actor for update;
  if not found then raise exception 'Perfil no disponible' using errcode='22023'; end if;
  if expected_version is distinct from item.version then raise exception 'El perfil cambió. Vuelve a cargarlo.' using errcode='40001'; end if;
  if action='submit' then
    if item.status not in ('draft','changes_requested','rejected') or char_length(item.display_name)<1 or char_length(item.bio)<20 or char_length(item.city)<1 or char_length(item.region)<1
      or not private.dopmi_rescuer_verified(actor) then raise exception 'Completa tu perfil y verificación antes de enviarlo' using errcode='22023'; end if;
    if item.avatar_path is not null and not exists(select 1 from storage.objects where bucket_id='dopmi-rescuer-profile-media' and name=item.avatar_path) then raise exception 'El avatar no terminó de subir' using errcode='22023'; end if;
    update public.dopmi_rescuer_profiles set status='submitted',submitted_at=now(),version=version+1,updated_at=now() where owner_id=actor returning * into item;
  elsif action='withdraw' and item.status='submitted' then
    update public.dopmi_rescuer_profiles set status='draft',version=version+1,updated_at=now() where owner_id=actor returning * into item;
  else raise exception 'Transición no disponible' using errcode='22023'; end if;
  return to_jsonb(item);
end;
$$;

create function public.dopmi_admin_rescuer_profiles(status_filter text default 'submitted',page_number integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  if status_filter not in ('submitted','changes_requested','rejected','published') or page_number<1 then raise exception 'Filtros inválidos' using errcode='22023'; end if;
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'rescuer_profiles.list');
  return jsonb_build_object('total',(select count(*) from public.dopmi_rescuer_profiles where status=status_filter),
    'items',coalesce((select jsonb_agg(to_jsonb(x)) from (select * from public.dopmi_rescuer_profiles where status=status_filter order by submitted_at,owner_id limit 20 offset (page_number::bigint-1)*20)x),'[]'::jsonb));
end;
$$;

create function public.dopmi_review_rescuer_profile(profile_owner uuid,expected_version integer,decision text,feedback text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare item public.dopmi_rescuer_profiles;
begin
  if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
  select * into item from public.dopmi_rescuer_profiles where owner_id=profile_owner for update;
  if not found or item.status<>'submitted' then raise exception 'Perfil no disponible' using errcode='22023'; end if;
  if item.version is distinct from expected_version then raise exception 'El perfil cambió' using errcode='40001'; end if;
  if decision not in ('published','changes_requested','rejected') or (decision<>'published' and char_length(btrim(coalesce(feedback,'')))<5) then raise exception 'Decisión inválida' using errcode='22023'; end if;
  update public.dopmi_rescuer_profiles set status=decision,review_feedback=btrim(coalesce(feedback,'')),
    approved_snapshot=case when decision='published' then jsonb_build_object('display_name',display_name,'bio',bio,'city',city,'region',region,'instagram_url',instagram_url,'facebook_url',facebook_url,'avatar_path',avatar_path) else approved_snapshot end,
    published_at=case when decision='published' then now() else published_at end,version=version+1,updated_at=now()
    where owner_id=profile_owner returning * into item;
  insert into private.dopmi_rescuer_profile_reviews(owner_id,reviewer_id,decision,feedback,version,snapshot)
    values(item.owner_id,auth.uid(),decision,btrim(coalesce(feedback,'')),item.version,to_jsonb(item));
  insert into public.dopmi_notifications(user_id,kind,source_id,title) values(item.owner_id,'review',item.owner_id,case when decision='published' then 'Tu perfil público fue aprobado' else 'Tu perfil público necesita atención' end)
    on conflict(user_id,kind,source_id) do update set title=excluded.title,read_at=null,created_at=now();
  insert into private.admin_access_log(actor_id,action) values(auth.uid(),'rescuer_profiles.review');
  return to_jsonb(item);
end;
$$;

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
    'cases',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'status',r.status,'public_data',r.approved_snapshot) order by r.approved_at desc,r.id) from public.dopmi_rescue_records r where r.owner_id=person_id and r.kind='case' and private.dopmi_rescue_public_visible(r)),'[]'::jsonb),
    'activity',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'case_id',u.case_id,'body',u.approved_snapshot->>'body','photos',u.approved_snapshot->'photos','published_at',u.published_at) order by u.published_at desc,u.id) from public.dopmi_case_updates u where u.owner_id=person_id and u.status='published' and u.approved_snapshot is not null),'[]'::jsonb));
  return profile;
end;
$$;

revoke all on function public.dopmi_rescuer_profile_file_access(text,boolean),public.dopmi_my_rescuer_profile(),public.dopmi_save_rescuer_profile(jsonb,integer),public.dopmi_transition_rescuer_profile(integer,text),public.dopmi_admin_rescuer_profiles(text,integer),public.dopmi_review_rescuer_profile(uuid,integer,text,text) from public,anon,authenticated;
grant execute on function public.dopmi_rescuer_profile_file_access(text,boolean) to anon,authenticated;
grant execute on function public.dopmi_my_rescuer_profile(),public.dopmi_save_rescuer_profile(jsonb,integer),public.dopmi_transition_rescuer_profile(integer,text),public.dopmi_admin_rescuer_profiles(text,integer),public.dopmi_review_rescuer_profile(uuid,integer,text,text) to authenticated;

do $$ begin if exists(select 1 from pg_publication where pubname='supabase_realtime') then alter publication supabase_realtime add table public.dopmi_rescuer_profiles; end if; end $$;

commit;
