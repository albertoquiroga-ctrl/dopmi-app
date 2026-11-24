begin;

-- Pre-login operational preflight only. Consent and advertising identifiers
-- remain local to the client; this function exposes no actor or event data.
create function public.dopmi_meta_lifecycle_enabled() returns boolean
language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from private.dopmi_meta_ads_gate g
    where g.singleton and g.enabled
  );
$$;
revoke all on function public.dopmi_meta_lifecycle_enabled() from public;
grant execute on function public.dopmi_meta_lifecycle_enabled()
  to anon,authenticated,service_role;

commit;
