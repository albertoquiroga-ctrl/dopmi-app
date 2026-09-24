begin;

-- Server-owned linkage for the subscription created only after the first
-- Guardian payment has been independently verified. The registry does not
-- create a subscription or authorize a charge.
create table private.dopmi_guardian_subscriptions (
  donor_id uuid primary key references public.profiles(id) on delete restrict,
  stripe_customer_id text not null check (stripe_customer_id ~ '^cus_[A-Za-z0-9]+$'),
  stripe_subscription_id text not null unique check (stripe_subscription_id ~ '^sub_[A-Za-z0-9]+$'),
  stripe_price_id text not null check (stripe_price_id ~ '^price_[A-Za-z0-9]+$'),
  gross_cents bigint not null check (gross_cents between 1000 and 1000000),
  initial_payment_intent_id text not null unique check (initial_payment_intent_id ~ '^pi_[A-Za-z0-9]+$'),
  initial_charge_id text not null unique check (initial_charge_id ~ '^ch_[A-Za-z0-9]+$'),
  status text not null default 'active' check (status in ('active','canceled')),
  created_at timestamptz not null default now(),
  canceled_at timestamptz,
  check ((status='active' and canceled_at is null) or (status='canceled' and canceled_at is not null))
);

create table private.dopmi_guardian_invoice_cycles (
  cycle_id uuid primary key references private.dopmi_guardian_cycles(id) on delete restrict,
  stripe_subscription_id text not null references private.dopmi_guardian_subscriptions(stripe_subscription_id) on delete restrict,
  stripe_invoice_id text not null unique check (stripe_invoice_id ~ '^in_[A-Za-z0-9]+$'),
  created_at timestamptz not null default now()
);

create index dopmi_guardian_invoice_subscription on private.dopmi_guardian_invoice_cycles(stripe_subscription_id);
alter table private.dopmi_guardian_subscriptions enable row level security;
alter table private.dopmi_guardian_invoice_cycles enable row level security;
revoke all on private.dopmi_guardian_subscriptions,private.dopmi_guardian_invoice_cycles from public,anon,authenticated;

-- Only the backend service role can register a verified initial charge,
-- resolve an invoice's owner and bind an invoice to the atomic hold. A Stripe
-- signature or browser metadata is never an authorization substitute for the
-- persisted subscription ID. Stripe objects must be verified by the caller.
create function public.dopmi_guardian_subscription_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  plan private.dopmi_guardian_subscriptions;
  cycle private.dopmi_guardian_cycles;
  binding private.dopmi_guardian_invoice_cycles;
  donor uuid;
  customer text;
  subscription text;
  price text;
  initial_intent text;
  initial_charge text;
  invoice text;
  target_cycle_id uuid;
  gross bigint;
begin
  if operation='register' then
    donor := (data->>'donor_id')::uuid;
    customer := data->>'stripe_customer_id';
    subscription := data->>'stripe_subscription_id';
    price := data->>'stripe_price_id';
    gross := (data->>'gross_cents')::bigint;
    initial_intent := data->>'initial_payment_intent_id';
    initial_charge := data->>'initial_charge_id';
    if donor is null or customer !~ '^cus_[A-Za-z0-9]+$'
      or subscription !~ '^sub_[A-Za-z0-9]+$' or price !~ '^price_[A-Za-z0-9]+$'
      or initial_intent !~ '^pi_[A-Za-z0-9]+$' or initial_charge !~ '^ch_[A-Za-z0-9]+$'
      or gross not between 1000 and 1000000 then
      raise exception 'Registro Guardián inválido' using errcode='22023';
    end if;
    if not exists (select 1 from public.profiles p join auth.users u on u.id=p.id
      where p.id=donor and p.account_status='active' and u.email_confirmed_at is not null) then
      raise exception 'Cuenta Guardián no disponible' using errcode='42501';
    end if;
    insert into private.dopmi_guardian_subscriptions(donor_id,stripe_customer_id,
      stripe_subscription_id,stripe_price_id,gross_cents,initial_payment_intent_id,initial_charge_id)
    values(donor,customer,subscription,price,gross,initial_intent,initial_charge)
    on conflict(donor_id) do nothing;
    select * into plan from private.dopmi_guardian_subscriptions p where p.donor_id=donor for update;
    if plan.status<>'active' or plan.stripe_customer_id<>customer
      or plan.stripe_subscription_id<>subscription or plan.stripe_price_id<>price
      or plan.gross_cents<>gross or plan.initial_payment_intent_id<>initial_intent
      or plan.initial_charge_id<>initial_charge then
      raise exception 'Registro Guardián ya vinculado a otros datos' using errcode='22023';
    end if;
  elsif operation='lookup' then
    subscription := data->>'stripe_subscription_id';
    if subscription !~ '^sub_[A-Za-z0-9]+$' then
      raise exception 'Suscripción Guardián inválida' using errcode='22023';
    end if;
    select * into plan from private.dopmi_guardian_subscriptions p where p.stripe_subscription_id=subscription;
    if not found then return null; end if;
  elsif operation='bind_invoice' then
    subscription := data->>'stripe_subscription_id';
    invoice := data->>'stripe_invoice_id';
    target_cycle_id := (data->>'cycle_id')::uuid;
    if subscription !~ '^sub_[A-Za-z0-9]+$' or invoice !~ '^in_[A-Za-z0-9]+$' or target_cycle_id is null then
      raise exception 'Factura Guardián inválida' using errcode='22023';
    end if;
    select * into plan from private.dopmi_guardian_subscriptions p
      where p.stripe_subscription_id=subscription and p.status='active' for update;
    if not found then raise exception 'Suscripción Guardián no disponible' using errcode='42501'; end if;
    select * into cycle from private.dopmi_guardian_cycles c where c.id=target_cycle_id for update;
    if not found or cycle.donor_id<>plan.donor_id or cycle.gross_cents<>plan.gross_cents
      or cycle.status not in ('reserved','skipped')
      or (cycle.status='reserved' and cycle.expires_at<=now()) then
      raise exception 'Reserva Guardián no coincide' using errcode='22023';
    end if;
    insert into private.dopmi_guardian_invoice_cycles(cycle_id,stripe_subscription_id,stripe_invoice_id)
    values(target_cycle_id,subscription,invoice) on conflict(cycle_id) do nothing;
    select * into binding from private.dopmi_guardian_invoice_cycles b where b.cycle_id=target_cycle_id;
    if binding.stripe_subscription_id<>subscription or binding.stripe_invoice_id<>invoice then
      raise exception 'Ciclo Guardián ya vinculado a otra factura' using errcode='22023';
    end if;
  else
    raise exception 'Operación Guardián inválida' using errcode='22023';
  end if;
  return jsonb_build_object('donor_id',plan.donor_id,
    'stripe_customer_id',plan.stripe_customer_id,
    'stripe_subscription_id',plan.stripe_subscription_id,
    'stripe_price_id',plan.stripe_price_id,'gross_cents',plan.gross_cents,
    'status',plan.status,'cycle_id',binding.cycle_id,'stripe_invoice_id',binding.stripe_invoice_id);
end;
$$;

revoke all on function public.dopmi_guardian_subscription_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_subscription_server(text,jsonb) to service_role;

commit;
