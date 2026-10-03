begin;

-- Keep the canceled registry and financial evidence. A canceled plan may use
-- the independent wallet only after every Guardian mutation has stopped.
create function private.dopmi_guardian_blocks_saved_method(actor uuid)
returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from private.dopmi_guardian_subscriptions s
  where s.donor_id=actor and (
   s.status<>'canceled' or s.canceled_at is null or s.change_lease_until>now()
   or exists(select 1 from private.dopmi_saved_card_customers w
    where w.owner_id=actor and w.stripe_customer_id is distinct from s.stripe_customer_id)
   or exists(select 1 from private.dopmi_guardian_schedule_jobs j
    where j.subscription_id=s.stripe_subscription_id and j.status<>'canceled')))
 or exists(select 1 from private.dopmi_guardian_requests where donor_id=actor and status='pending')
 or exists(select 1 from private.dopmi_guardian_method_jobs where donor_id=actor and status in ('pending','attention'));
$$;
revoke all on function private.dopmi_guardian_blocks_saved_method(uuid) from public,anon,authenticated;

-- Patch the deployed continuation without replaying the original migration.
-- Both prepare and the checkpoint immediately before a provider write must
-- use the same rule under the existing per-owner advisory lock.
do $$
declare definition text; previous text; replacement text;
begin
 definition:=pg_get_functiondef('public.dopmi_saved_card_method_server(text,jsonb)'::regprocedure);
 previous:='exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=actor)';
 replacement:='private.dopmi_guardian_blocks_saved_method(actor)';
 if (length(definition)-length(replace(definition,previous,'')))/length(previous)<>2 then
  raise exception 'Saved method Guardian guard differs; inspect before applying';
 end if;
 execute replace(definition,previous,replacement);
end $$;

commit;
