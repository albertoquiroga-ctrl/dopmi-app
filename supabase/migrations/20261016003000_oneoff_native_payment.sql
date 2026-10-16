begin;

-- Existing attempts remain hosted. New native attempts choose their channel in
-- the same transaction as the original donation reservation, before any Stripe
-- request. Channels and provider identity cannot change on retries.
alter table private.dopmi_checkouts
  add column payment_flow text not null default 'hosted' check (payment_flow in ('hosted','native')),
  add column consent_version text,
  add column consent_at timestamptz,
  add constraint dopmi_native_checkout_consent check (payment_flow<>'native' or
    (session_id is null and url is null and consent_version='oneoff-test-2026-10-15' and consent_at is not null));

do $patch$
declare
  definition text := pg_get_functiondef('public.dopmi_payment_server(text,jsonb)'::regprocedure);
  old_insert constant text := 'insert into private.dopmi_checkouts(donation_id) values(d.id);';
  new_insert constant text := 'insert into private.dopmi_checkouts(donation_id,payment_flow,consent_version,consent_at)
    values(d.id,case when data->>''payment_flow''=''native'' then ''native'' else ''hosted'' end,
      case when data->>''payment_flow''=''native'' then data->>''consent_version'' end,
      case when data->>''payment_flow''=''native'' then now() end);';
  old_save constant text := 'where donation_id=(data->>''donation_id'')::uuid and (session_id is null or session_id=data->>''session_id'');';
  new_save constant text := 'where donation_id=(data->>''donation_id'')::uuid and payment_flow=''hosted'' and (session_id is null or session_id=data->>''session_id'');';
  old_reconcile constant text := 'select donation.id,c.session_id from public.dopmi_donations donation join private.dopmi_checkouts c on c.donation_id=donation.id';
  new_reconcile constant text := 'select donation.id,c.session_id,donation.stripe_payment_intent_id from public.dopmi_donations donation join private.dopmi_checkouts c on c.donation_id=donation.id';
  old_filter constant text := 'where donation.payment_status=''pending'' and c.session_id is not null order by donation.updated_at,donation.id limit 50';
  new_filter constant text := 'where donation.payment_status=''pending'' and (c.session_id is not null or donation.stripe_payment_intent_id is not null) order by donation.updated_at,donation.id limit 50';
  old_fee constant text := 'fee:=(data->>''stripe_fee_cents'')::bigint;';
  new_fee constant text := 'if d.stripe_payment_intent_id is not null and d.stripe_payment_intent_id is distinct from data->>''payment_intent_id'' then
    raise exception ''Cobro distinto para la misma aportación'' using errcode=''22023''; end if;
    fee:=(data->>''stripe_fee_cents'')::bigint;';
begin
  if position(old_insert in definition)=0 or position(old_save in definition)=0 or
     position(old_reconcile in definition)=0 or position(old_filter in definition)=0 or position(old_fee in definition)=0 then
    raise exception 'Payment gateway changed: review native channel patch before applying';
  end if;
  execute replace(replace(replace(replace(replace(definition,old_insert,new_insert),old_save,new_save),
    old_reconcile,new_reconcile),old_filter,new_filter),old_fee,new_fee);
end
$patch$;

create function public.dopmi_oneoff_native_server(operation text, data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  target_actor uuid := (data->>'actor')::uuid;
  target_key uuid := (data->>'key')::uuid;
  d public.dopmi_donations;
  c private.dopmi_checkouts;
begin
  if target_actor is null or target_key is null or not exists(
    select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=target_actor and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Cuenta activa y confirmada requerida' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-checkout:'||target_actor::text,0));
  if operation='prepare' then
    if data->>'consent_version' is distinct from 'oneoff-test-2026-10-15' or
       (data->>'consent') is distinct from 'true' then
      raise exception 'Confirma el importe y las condiciones de la aportación' using errcode='22023';
    end if;
    perform public.dopmi_payment_server('prepare',data||jsonb_build_object('payment_flow','native'));
  end if;
  select * into d from public.dopmi_donations donation
    where donation.donor_id=target_actor and donation.idempotency_key=target_key;
  if not found then return null; end if;
  -- Match prepare/settle lock order. Cancellation must not hold a donation row
  -- while waiting on a settlement that already owns the rescuer lock.
  perform private.dopmi_rescue_lock(d.rescuer_id);
  select * into d from public.dopmi_donations donation
    where donation.donor_id=target_actor and donation.idempotency_key=target_key for update;
  select * into c from private.dopmi_checkouts checkout where checkout.donation_id=d.id for update;
  if operation='prepare' and c.payment_flow='native' and d.payment_status='pending' and d.stripe_payment_intent_id is null and
     d.reserved_cents<d.gross_cents-d.platform_fee_cents then
    raise exception 'Elige un importe que pueda asignarse completo a este gasto' using errcode='22023';
  end if;
  if operation in ('bind','canceled') then
    if c.payment_flow<>'native' or c.session_id is not null or d.payment_status<>'pending' or
       coalesce(data->>'payment_intent_id','')!~'^pi_[A-Za-z0-9]+$' or
       (d.stripe_payment_intent_id is not null and d.stripe_payment_intent_id is distinct from data->>'payment_intent_id') then
      raise exception 'Cobro distinto para la misma aportación' using errcode='22023';
    end if;
    if operation='bind' then
      update public.dopmi_donations set stripe_payment_intent_id=data->>'payment_intent_id',updated_at=now()
        where id=d.id returning * into d;
    else
      if d.stripe_payment_intent_id is null then raise exception 'Cobro no vinculado' using errcode='22023'; end if;
      perform public.dopmi_payment_server('cancel',jsonb_build_object('donation_id',d.id));
      select * into d from public.dopmi_donations donation where donation.id=d.id;
    end if;
  elsif operation not in ('prepare','get') then
    raise exception 'Operación de aportación inválida' using errcode='22023';
  end if;
  return to_jsonb(d)||jsonb_build_object('payment_flow',c.payment_flow,
    'consent_version',c.consent_version,'consent_at',c.consent_at);
end;
$$;
revoke all on function public.dopmi_oneoff_native_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_oneoff_native_server(text,jsonb) to service_role;
commit;
