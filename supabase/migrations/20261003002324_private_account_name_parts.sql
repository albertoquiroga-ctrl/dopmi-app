begin;
create table private.dopmi_account_name_parts (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  first_name text not null check(char_length(btrim(first_name)) between 1 and 80),
  last_name text not null check(char_length(last_name)<=80),
  updated_at timestamptz not null default now()
);
alter table private.dopmi_account_name_parts enable row level security;
revoke all on private.dopmi_account_name_parts from public,anon,authenticated,service_role;

-- An older client can still edit display_name. Never preserve stale name parts.
create function private.dopmi_sync_account_name_parts() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.display_name is distinct from old.display_name then
    delete from private.dopmi_account_name_parts
      where owner_id=new.id and
        btrim(first_name||' '||last_name) is distinct from new.display_name;
  end if;
  return new;
end;
$$;
revoke all on function private.dopmi_sync_account_name_parts() from public,anon,authenticated,service_role;
create trigger dopmi_account_name_parts_sync after update of display_name on public.profiles
  for each row execute function private.dopmi_sync_account_name_parts();

create function public.dopmi_my_account_names() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  select jsonb_build_object('first_name',coalesce(n.first_name,p.display_name),
    'last_name',coalesce(n.last_name,''),'name_parts_saved',n.owner_id is not null)
  into result from public.profiles p left join private.dopmi_account_name_parts n on n.owner_id=p.id
  where p.id=actor;
  return result;
end;
$$;
revoke all on function public.dopmi_my_account_names() from public,anon,authenticated;
grant execute on function public.dopmi_my_account_names() to authenticated;

create function public.dopmi_save_account_names(payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); first_value text; last_value text;
  phone_value text; city_value text; full_value text; result jsonb;
begin
  if jsonb_typeof(payload) is distinct from 'object' or octet_length(payload::text)>3000
    or payload-array['first_name','last_name','phone','city']::text[]<>'{}'::jsonb
    or jsonb_typeof(payload->'first_name') is distinct from 'string'
    or jsonb_typeof(payload->'last_name') is distinct from 'string'
    or jsonb_typeof(payload->'phone') is distinct from 'string'
    or jsonb_typeof(payload->'city') is distinct from 'string' then
    raise exception 'Datos de perfil inválidos' using errcode='22023';
  end if;
  first_value:=btrim(payload->>'first_name'); last_value:=btrim(payload->>'last_name');
  phone_value:=btrim(payload->>'phone'); city_value:=btrim(payload->>'city');
  full_value:=btrim(first_value||' '||last_value);
  if char_length(first_value) not between 1 and 80 or first_value ~ '^[[:space:]]*$'
    or char_length(last_value)>80 or char_length(full_value)>80
    or char_length(phone_value)>24 or char_length(city_value)>100 then
    raise exception 'Datos de perfil inválidos' using errcode='22023';
  end if;
  perform 1 from public.profiles where id=actor for update;
  update public.profiles set display_name=full_value,phone=phone_value,city=city_value where id=actor;
  insert into private.dopmi_account_name_parts(owner_id,first_name,last_name)
    values(actor,first_value,last_value) on conflict(owner_id) do update
    set first_name=excluded.first_name,last_name=excluded.last_name,updated_at=now();
  select to_jsonb(p) into result from public.profiles p where id=actor;
  return result;
end;
$$;
revoke all on function public.dopmi_save_account_names(jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_save_account_names(jsonb) to authenticated;
commit;
