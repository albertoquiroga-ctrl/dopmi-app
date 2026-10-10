-- Public media and profile activity must follow current parent visibility.
begin;
create or replace function public.dopmi_case_update_file_access(object_name text,writing boolean default false) returns boolean
language plpgsql security definer set search_path='' as $$
declare item public.dopmi_case_updates;
begin
  if object_name is null or object_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then return false; end if;
  select * into item from public.dopmi_case_updates where id::text=split_part(object_name,'/',2);
  if not found or item.owner_id::text<>split_part(object_name,'/',1) then return false; end if;
  if writing then return public.dopmi_actor_active() and item.owner_id=auth.uid() and item.status in ('draft','changes_requested','rejected'); end if;
  return (public.dopmi_actor_active() and item.owner_id=auth.uid()) or public.dopmi_is_admin()
    or (exists(select 1 from public.dopmi_rescue_records r where r.id=item.case_id and private.dopmi_rescue_public_visible(r)) and item.status='published' and item.approved_snapshot is not null and coalesce(item.approved_snapshot->'photos','[]'::jsonb) ? object_name);
end;
$$;
create or replace function public.dopmi_rescuer_profile_file_access(object_name text,writing boolean default false) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare item public.dopmi_rescuer_profiles;
begin
  if object_name is null or object_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then return false; end if;
  select * into item from public.dopmi_rescuer_profiles where owner_id::text=split_part(object_name,'/',2);
  if not found or item.owner_id::text<>split_part(object_name,'/',1) then return false; end if;
  if writing then return public.dopmi_actor_active() and item.owner_id=auth.uid() and item.status in ('draft','changes_requested','rejected','published'); end if;
  return (public.dopmi_actor_active() and item.owner_id=auth.uid()) or public.dopmi_is_admin()
    or (private.dopmi_rescuer_verified(item.owner_id) and item.approved_snapshot is not null and item.approved_snapshot->>'avatar_path'=object_name);
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
    'activity',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'case_id',u.case_id,'body',u.approved_snapshot->>'body','photos',u.approved_snapshot->'photos','published_at',u.published_at) order by u.published_at desc,u.id) from public.dopmi_case_updates u where u.owner_id=person_id and u.status='published' and u.approved_snapshot is not null and exists(select 1 from public.dopmi_rescue_records c where c.id=u.case_id and private.dopmi_rescue_public_visible(c))),'[]'::jsonb));
  return profile;
end;
$$;
commit;
