begin;

-- Canceled does not mean a previously requested collection is reconciled.
-- Preserve the existing rule for a confirmed paid or skipped cycle.
create or replace function private.dopmi_guardian_blocks_saved_method(actor uuid)
returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from private.dopmi_guardian_subscriptions s
  where s.donor_id=actor and (
   s.status<>'canceled' or s.canceled_at is null or s.change_lease_until>now()
   or exists(select 1 from private.dopmi_saved_card_customers w
    where w.owner_id=actor and w.stripe_customer_id is distinct from s.stripe_customer_id)
   or exists(select 1 from private.dopmi_guardian_schedule_jobs j
    where j.subscription_id=s.stripe_subscription_id and j.status<>'canceled')
   or exists(select 1 from private.dopmi_guardian_collection_jobs j
    where j.subscription_id=s.stripe_subscription_id and j.pay_requested_at is not null
     and j.status not in ('paid','skipped'))))
 or exists(select 1 from private.dopmi_guardian_requests where donor_id=actor and status='pending')
 or exists(select 1 from private.dopmi_guardian_method_jobs where donor_id=actor and status in ('pending','attention'));
$$;
revoke all on function private.dopmi_guardian_blocks_saved_method(uuid) from public,anon,authenticated;

-- The initial settled activation is immutable evidence, not a new enrollment.
-- Exempt only the activation linked to the canceled registered subscription.
create function private.dopmi_guardian_activation_blocks_saved_method(actor uuid)
returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from private.dopmi_guardian_activations a where a.donor_id=actor
  and (a.status in ('pending','attention') or (a.status='settled' and not exists(
   select 1 from private.dopmi_guardian_schedule_jobs j
   join private.dopmi_guardian_subscriptions s on s.stripe_subscription_id=j.subscription_id
   join private.dopmi_guardian_settlements e on e.cycle_id=a.cycle_id
   where j.cycle_id=a.cycle_id and j.status='canceled' and s.donor_id=actor
    and s.status='canceled' and s.canceled_at is not null
    and e.payment_intent_id=s.initial_payment_intent_id and e.charge_id=s.initial_charge_id))));
$$;
revoke all on function private.dopmi_guardian_activation_blocks_saved_method(uuid) from public,anon,authenticated;

do $$
declare definition text; previous text;
begin
 definition:=pg_get_functiondef('public.dopmi_saved_card_method_server(text,jsonb)'::regprocedure);
 previous:='exists(select 1 from private.dopmi_guardian_activations where donor_id=actor and status in (''pending'',''settled'',''attention''))';
 if (length(definition)-length(replace(definition,previous,'')))/length(previous)<>2 then
  raise exception 'Saved method activation guard differs; inspect before applying';
 end if;
 execute replace(definition,previous,'private.dopmi_guardian_activation_blocks_saved_method(actor)');
end $$;

commit;
