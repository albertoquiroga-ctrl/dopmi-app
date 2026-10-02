-- A new draft cannot delete the photo still used by its approved snapshot.
begin;
create or replace function public.dopmi_rescuer_profile_file_access(object_name text,writing boolean default false) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare item public.dopmi_rescuer_profiles;
begin
  if object_name is null or object_name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then return false; end if;
  select * into item from public.dopmi_rescuer_profiles where owner_id::text=split_part(object_name,'/',2);
  if not found or item.owner_id::text<>split_part(object_name,'/',1) then return false; end if;
  if writing then return public.dopmi_actor_active() and item.owner_id=auth.uid() and item.status in ('draft','changes_requested','rejected','published') and (item.approved_snapshot->>'avatar_path') is distinct from object_name; end if;
  return (public.dopmi_actor_active() and item.owner_id=auth.uid()) or public.dopmi_is_admin()
    or (private.dopmi_rescuer_verified(item.owner_id) and item.approved_snapshot is not null and item.approved_snapshot->>'avatar_path'=object_name);
end;
$$;
commit;
