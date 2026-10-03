begin;

-- Only the authenticated Edge boundary can call this server lookup.
-- Browser callers cannot obtain processor identities or nominate another owner.
create function public.dopmi_guardian_method_owner_server(target_actor uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if target_actor is null or not exists (
    select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=target_actor and p.account_status='active'
      and u.email_confirmed_at is not null
  ) then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  return (select jsonb_build_object('customer_id',s.stripe_customer_id,
    'subscription_id',s.stripe_subscription_id)
    from private.dopmi_guardian_subscriptions s where s.donor_id=target_actor);
end;
$$;
revoke all on function public.dopmi_guardian_method_owner_server(uuid)
  from public,anon,authenticated;
grant execute on function public.dopmi_guardian_method_owner_server(uuid) to service_role;

commit;
