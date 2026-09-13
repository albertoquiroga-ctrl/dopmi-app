begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
  values('dopmi-adoption-photos','dopmi-adoption-photos',false,5242880,array['image/jpeg','image/png','image/webp']);

create function public.dopmi_can_read_photo(object_name text) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
    where split_part(object_name,'/',1)=a.owner_id::text and split_part(object_name,'/',2)=a.id::text
      and ((public.dopmi_actor_active() and a.owner_id=auth.uid()) or public.dopmi_is_admin()
        or (a.status in ('published','adopted') and p.account_status='active' and object_name=any(a.photos))));
$$;
create function public.dopmi_can_write_photo(object_name text) returns boolean
language plpgsql security definer set search_path='' as $$
declare a public.dopmi_adoptions;
begin
  if not public.dopmi_actor_active() or object_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then return false; end if;
  -- Serialize object writes/deletes with submission and review. Approved content cannot be overwritten.
  select * into a from public.dopmi_adoptions where id::text=split_part(object_name,'/',2) for update;
  return found and a.owner_id=auth.uid() and a.owner_id::text=split_part(object_name,'/',1)
    and a.status in ('draft','changes_requested','rejected','archived');
end;
$$;
revoke all on function public.dopmi_can_read_photo(text),public.dopmi_can_write_photo(text) from public;
grant execute on function public.dopmi_can_read_photo(text) to anon,authenticated;
grant execute on function public.dopmi_can_write_photo(text) to authenticated;
create policy dopmi_photos_read on storage.objects for select to anon,authenticated
  using(bucket_id='dopmi-adoption-photos' and public.dopmi_can_read_photo(name));
create policy dopmi_photos_insert on storage.objects for insert to authenticated
  with check(bucket_id='dopmi-adoption-photos' and public.dopmi_can_write_photo(name));
create policy dopmi_photos_delete on storage.objects for delete to authenticated
  using(bucket_id='dopmi-adoption-photos' and public.dopmi_can_write_photo(name));

-- Existing policies are permissive (OR). A restrictive boundary protects this bucket
-- even if legacy policies grant broader access to other buckets in this development project.
create policy dopmi_photos_read_boundary on storage.objects as restrictive for select to anon,authenticated
  using(bucket_id<>'dopmi-adoption-photos' or public.dopmi_can_read_photo(name));
create policy dopmi_photos_insert_boundary on storage.objects as restrictive for insert to anon,authenticated
  with check(bucket_id<>'dopmi-adoption-photos' or public.dopmi_can_write_photo(name));
create policy dopmi_photos_delete_boundary on storage.objects as restrictive for delete to anon,authenticated
  using(bucket_id<>'dopmi-adoption-photos' or public.dopmi_can_write_photo(name));
create policy dopmi_photos_update_boundary on storage.objects as restrictive for update to anon,authenticated
  using(bucket_id<>'dopmi-adoption-photos') with check(bucket_id<>'dopmi-adoption-photos');

do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    alter publication supabase_realtime add table public.dopmi_threads,public.dopmi_messages,public.dopmi_notifications,public.dopmi_adoptions;
  end if;
end $$;
commit;
