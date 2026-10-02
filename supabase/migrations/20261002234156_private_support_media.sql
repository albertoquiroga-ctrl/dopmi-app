begin;
alter table private.dopmi_support_requests add column attachment_path text;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('dopmi-support-media','dopmi-support-media',false,5242880,array['image/jpeg']);
create function public.dopmi_support_file_access(object_name text,writing boolean default false) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare actor uuid; request_key uuid;
begin
  if not public.dopmi_actor_active() or object_name is null or object_name !~
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$' then return false; end if;
  actor:=auth.uid(); request_key:=split_part(object_name,'/',2)::uuid;
  if writing then
    return split_part(object_name,'/',1)=actor::text and not exists(
      select 1 from private.dopmi_support_requests where owner_id=actor and request_id=request_key);
  end if;
  return split_part(object_name,'/',1)=actor::text or (
    public.dopmi_is_admin() and exists(select 1 from private.dopmi_support_requests
      where attachment_path=object_name and owner_id::text=split_part(object_name,'/',1) and request_id=request_key));
end;
$$;
revoke all on function public.dopmi_support_file_access(text,boolean) from public,anon,authenticated;
grant execute on function public.dopmi_support_file_access(text,boolean) to anon,authenticated;
create policy dopmi_support_media_read on storage.objects for select to authenticated
using(bucket_id='dopmi-support-media' and public.dopmi_support_file_access(name));
create policy dopmi_support_media_insert on storage.objects for insert to authenticated
with check(bucket_id='dopmi-support-media' and public.dopmi_support_file_access(name,true));
create policy dopmi_support_media_delete on storage.objects for delete to authenticated
using(bucket_id='dopmi-support-media' and public.dopmi_support_file_access(name,true));
create policy dopmi_support_media_read_boundary on storage.objects as restrictive for select to anon,authenticated
using(bucket_id<>'dopmi-support-media' or public.dopmi_support_file_access(name));
create policy dopmi_support_media_insert_boundary on storage.objects as restrictive for insert to anon,authenticated
with check(bucket_id<>'dopmi-support-media' or public.dopmi_support_file_access(name,true));
create policy dopmi_support_media_delete_boundary on storage.objects as restrictive for delete to anon,authenticated
using(bucket_id<>'dopmi-support-media' or public.dopmi_support_file_access(name,true));
create policy dopmi_support_media_update_boundary on storage.objects as restrictive for update to anon,authenticated
using(bucket_id<>'dopmi-support-media') with check(bucket_id<>'dopmi-support-media');
commit;
