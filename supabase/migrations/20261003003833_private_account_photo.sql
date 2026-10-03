begin;
create table private.dopmi_account_photos (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  photo_path text not null,
  updated_at timestamptz not null default now()
);
alter table private.dopmi_account_photos enable row level security;
revoke all on private.dopmi_account_photos from public,anon,authenticated,service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('dopmi-account-profile-media','dopmi-account-profile-media',false,5242880,array['image/jpeg']);

create function public.dopmi_account_photo_file_access(object_name text,writing boolean default false) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
  if not public.dopmi_actor_active() or object_name is null or object_name !~
    ('^'||actor::text||'/'||actor::text||'/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.jpg$') then return false; end if;
  if writing then
    return not exists(select 1 from private.dopmi_account_photos where owner_id=actor and photo_path=object_name);
  end if;
  return true;
end;
$$;
revoke all on function public.dopmi_account_photo_file_access(text,boolean) from public,anon,authenticated;
grant execute on function public.dopmi_account_photo_file_access(text,boolean) to anon,authenticated;
create policy dopmi_account_photo_read on storage.objects for select to authenticated
using(bucket_id='dopmi-account-profile-media' and public.dopmi_account_photo_file_access(name));
create policy dopmi_account_photo_insert on storage.objects for insert to authenticated
with check(bucket_id='dopmi-account-profile-media' and public.dopmi_account_photo_file_access(name,true));
create policy dopmi_account_photo_delete on storage.objects for delete to authenticated
using(bucket_id='dopmi-account-profile-media' and public.dopmi_account_photo_file_access(name,true));
create policy dopmi_account_photo_read_boundary on storage.objects as restrictive for select to anon,authenticated
using(bucket_id<>'dopmi-account-profile-media' or public.dopmi_account_photo_file_access(name));
create policy dopmi_account_photo_insert_boundary on storage.objects as restrictive for insert to anon,authenticated
with check(bucket_id<>'dopmi-account-profile-media' or public.dopmi_account_photo_file_access(name,true));
create policy dopmi_account_photo_delete_boundary on storage.objects as restrictive for delete to anon,authenticated
using(bucket_id<>'dopmi-account-profile-media' or public.dopmi_account_photo_file_access(name,true));
create policy dopmi_account_photo_update_boundary on storage.objects as restrictive for update to anon,authenticated
using(bucket_id<>'dopmi-account-profile-media') with check(bucket_id<>'dopmi-account-profile-media');

create function public.dopmi_my_account_photo() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  select jsonb_build_object('photo_path',photo_path,'updated_at',updated_at) into result
    from private.dopmi_account_photos where owner_id=actor;
  return result;
end;
$$;
revoke all on function public.dopmi_my_account_photo() from public,anon,authenticated;
grant execute on function public.dopmi_my_account_photo() to authenticated;

create function public.dopmi_save_account_photo(photo_path text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  -- Serialize account mutations and recheck availability after acquiring the lock.
  perform 1 from public.profiles where id=actor for update;
  perform private.dopmi_require_actor();
  if photo_path is null then
    delete from private.dopmi_account_photos where owner_id=actor;
    return null;
  end if;
  if not public.dopmi_account_photo_file_access(photo_path) or not exists(
    select 1 from storage.objects o where o.bucket_id='dopmi-account-profile-media' and o.name=photo_path
      and o.metadata->>'mimetype'='image/jpeg'
      and case when o.metadata->>'size' ~ '^[0-9]{1,8}$' then (o.metadata->>'size')::bigint else 0 end between 1 and 5242880) then
    raise exception 'Foto de cuenta inválida' using errcode='22023';
  end if;
  insert into private.dopmi_account_photos(owner_id,photo_path) values(actor,photo_path)
    on conflict(owner_id) do update set photo_path=excluded.photo_path,updated_at=now();
  select jsonb_build_object('photo_path',p.photo_path,'updated_at',p.updated_at) into result
    from private.dopmi_account_photos p where owner_id=actor;
  return result;
end;
$$;
revoke all on function public.dopmi_save_account_photo(text) from public,anon,authenticated;
grant execute on function public.dopmi_save_account_photo(text) to authenticated;
commit;
