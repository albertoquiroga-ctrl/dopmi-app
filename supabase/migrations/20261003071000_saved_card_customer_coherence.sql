begin;

-- Snapshot the saved-card customer before the original activation Checkout.
-- A retry must never change the customer attached to its idempotent request.
alter table private.dopmi_guardian_activations add column saved_customer_id text
  check(saved_customer_id ~ '^cus_[A-Za-z0-9]+$');

do $patch$
declare definition text; old_text text; new_text text;
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure);
  old_text:=$code$perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||donor,0));$code$;
  new_text:=$code$perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||donor,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||donor,0));$code$;
  if position(old_text in definition)=0 then raise exception 'Review activation customer lock'; end if;
  definition:=replace(definition,old_text,new_text);
  old_text:=$code$held:=public.dopmi_guardian_reserve(donor,requested_key,gross);$code$;
  new_text:=$code$if exists(select 1 from private.dopmi_saved_card_jobs where owner_id=donor and status in ('pending','attention')) then
  raise exception 'Termina el alta de tarjeta antes de activar Guardián' using errcode='55000'; end if;
  held:=public.dopmi_guardian_reserve(donor,requested_key,gross);$code$;
  if position(old_text in definition)=0 then raise exception 'Review activation card setup guard'; end if;
  definition:=replace(definition,old_text,new_text);
  old_text:=$code$insert into private.dopmi_guardian_activations(cycle_id,donor_id,consent_version,status,checkout_expires_at,return_url)$code$;
  new_text:=$code$insert into private.dopmi_guardian_activations(cycle_id,donor_id,consent_version,status,checkout_expires_at,return_url,saved_customer_id)$code$;
  if position(old_text in definition)=0 then raise exception 'Review activation card customer column'; end if;
  definition:=replace(definition,old_text,new_text);
  old_text:=$code$date_trunc('second',now())+interval '35 minutes',data->>'return_url') returning * into a;$code$;
  new_text:=$code$date_trunc('second',now())+interval '35 minutes',data->>'return_url',
  (select stripe_customer_id from private.dopmi_saved_card_customers where owner_id=donor)) returning * into a;$code$;
  if position(old_text in definition)=0 then raise exception 'Review activation card customer snapshot'; end if;
  execute replace(definition,old_text,new_text);

  definition:=pg_get_functiondef('public.dopmi_saved_card_server(text,jsonb)'::regprocedure);
  old_text:=$code$if exists(select 1 from private.dopmi_saved_card_jobs where owner_id=actor and status in ('pending','attention')) then$code$;
  new_text:=$code$if not exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=actor)
    and exists(select 1 from private.dopmi_guardian_activations where donor_id=actor and status in ('pending','settled','attention')) then
    raise exception 'Alta Guardián pendiente' using errcode='55000'; end if;
  if exists(select 1 from private.dopmi_saved_card_jobs where owner_id=actor and status in ('pending','attention')) then$code$;
  if position(old_text in definition)=0 then raise exception 'Review saved card activation guard'; end if;
  execute replace(definition,old_text,new_text);
end $patch$;

create function public.dopmi_saved_card_owner_server(target_actor uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare customer text; saved_customer text; subscription text;
begin
  if target_actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=target_actor and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  select stripe_customer_id,stripe_subscription_id into customer,subscription
    from private.dopmi_guardian_subscriptions where donor_id=target_actor;
  select stripe_customer_id into saved_customer from private.dopmi_saved_card_customers where owner_id=target_actor;
  if customer is not null and saved_customer is not null and customer<>saved_customer then
    raise exception 'Clientes de tarjeta en revisión' using errcode='55000';
  end if;
  customer:=coalesce(customer,saved_customer);
  if customer is null then return null; end if;
  return jsonb_build_object('customer_id',customer,'subscription_id',subscription);
end;
$$;
revoke all on function public.dopmi_saved_card_owner_server(uuid) from public,anon,authenticated;
grant execute on function public.dopmi_saved_card_owner_server(uuid) to service_role;

commit;
