-- Milestone 1 only. No money, automatic grants of staff access, or public profiles.
begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 80),
  phone text not null default '' check (char_length(phone) <= 24),
  city text not null default '' check (char_length(city) <= 100),
  active_mode text not null default 'donor' check (active_mode in ('donor', 'rescuer')),
  intent text not null default 'adopt' check (intent in ('adopt', 'donate', 'rescue')),
  account_status text not null default 'active' check (account_status in ('active', 'suspended')),
  terms_version text,
  terms_accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table private.admin_memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table private.admin_access_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null,
  action text not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table private.admin_memberships enable row level security;
alter table private.admin_access_log enable row level security;

revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update(display_name, phone, city, active_mode, intent) on public.profiles to authenticated;

create policy "Read own profile" on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy "Update own active profile" on public.profiles for update to authenticated
  using ((select auth.uid()) = id and account_status = 'active')
  with check ((select auth.uid()) = id and account_status = 'active');

create function private.touch_profile() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger profile_updated before update on public.profiles
  for each row execute function private.touch_profile();

create function private.create_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  chosen_intent text := coalesce(new.raw_user_meta_data->>'intent', 'adopt');
begin
  if chosen_intent not in ('adopt', 'donate', 'rescue') then chosen_intent := 'adopt'; end if;
  insert into public.profiles(id, display_name, phone, intent, active_mode, terms_version, terms_accepted_at)
  values (
    new.id,
    left(coalesce(nullif(btrim(meta->>'display_name'), ''), nullif(btrim(meta->>'full_name'), ''), 'Mi perfil'), 80),
    left(coalesce(meta->>'phone', ''), 24),
    chosen_intent,
    case when chosen_intent = 'rescue' then 'rescuer' else 'donor' end,
    case when meta->>'terms_version' = 'development-2026-09-13' and meta->>'terms_accepted' = 'true'
      then 'development-2026-09-13' end,
    case when meta->>'terms_version' = 'development-2026-09-13' and meta->>'terms_accepted' = 'true'
      then now() end
  );
  return new;
end;
$$;
create trigger dopmi_create_profile after insert on auth.users
  for each row execute function private.create_profile();

-- Backfill identities created before this migration without inventing legal consent.
insert into public.profiles(id, display_name)
select id, left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'), ''), 'Mi perfil'), 80)
from auth.users on conflict (id) do nothing;

create function public.dopmi_is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from private.admin_memberships m
    join public.profiles p on p.id = m.user_id
    join auth.users u on u.id = m.user_id
    where m.user_id = (select auth.uid()) and m.active
      and p.account_status = 'active' and u.email_confirmed_at is not null
  );
$$;
revoke all on function public.dopmi_is_admin() from public, anon;
grant execute on function public.dopmi_is_admin() to authenticated;

create function public.accept_current_terms() returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set terms_version = 'development-2026-09-13', terms_accepted_at = now()
  where id = (select auth.uid()) and account_status = 'active';
  if not found then raise exception 'Cuenta no disponible' using errcode = '42501'; end if;
end;
$$;
revoke all on function public.accept_current_terms() from public, anon;
grant execute on function public.accept_current_terms() to authenticated;

create function public.admin_list_users(search_text text default '', page_number integer default 1, page_size integer default 20)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb; safe_search text := btrim(coalesce(search_text, ''));
begin
  if not public.dopmi_is_admin() then
    raise exception 'Acceso administrativo requerido' using errcode = '42501';
  end if;
  if page_number < 1 or page_number is null or page_size < 1 or page_size > 50 or page_size is null or char_length(safe_search) > 100 then
    raise exception 'Paginación o búsqueda inválida' using errcode = '22023';
  end if;
  -- Treat search as a literal substring, not user-controlled LIKE wildcards.
  with matched as (
    select p.id, p.display_name, p.phone, p.city, p.active_mode, p.account_status,
      p.created_at, u.email, u.email_confirmed_at, u.last_sign_in_at
    from public.profiles p join auth.users u on u.id = p.id
    where safe_search = '' or strpos(lower(p.display_name), lower(safe_search)) > 0
      or strpos(lower(coalesce(u.email, '')), lower(safe_search)) > 0
  ), paged as (
    select * from matched order by created_at desc, id
    limit page_size offset (page_number::bigint - 1) * page_size
  )
  select jsonb_build_object('total', (select count(*) from matched), 'users',
    coalesce((select jsonb_agg(to_jsonb(paged) order by created_at desc, id) from paged), '[]'::jsonb)) into result;
  insert into private.admin_access_log(actor_id, action) values ((select auth.uid()), 'users.list');
  return result;
end;
$$;
revoke all on function public.admin_list_users(text, integer, integer) from public, anon;
grant execute on function public.admin_list_users(text, integer, integer) to authenticated;
revoke all on function private.touch_profile(), private.create_profile() from public, anon, authenticated;

commit;
