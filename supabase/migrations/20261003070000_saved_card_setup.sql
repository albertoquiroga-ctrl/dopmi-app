begin;

-- Independent saving consent never activates Guardian or changes its default.
-- Existing Guardian customers are reused; an owner without one can save a card.
create table private.dopmi_saved_card_customers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete restrict,
  stripe_customer_id text unique check (stripe_customer_id ~ '^cus_[A-Za-z0-9]+$'),
  created_at timestamptz not null default now()
);
create table private.dopmi_saved_card_jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  request_key uuid not null,
  wallet_id uuid not null references private.dopmi_saved_card_customers(id),
  consent_version text not null check (consent_version='saved-cards-2026-10-03'),
  consent_at timestamptz not null default now(),
  customer_id text check (customer_id ~ '^cus_[A-Za-z0-9]+$'),
  session_id text unique check (session_id ~ '^cs_(test_)?[A-Za-z0-9]+$'),
  setup_intent_id text unique check (setup_intent_id ~ '^seti_[A-Za-z0-9]+$'),
  payment_method_id text check (payment_method_id ~ '^pm_[A-Za-z0-9]+$'),
  status text not null default 'pending' check (status in ('pending','saved','expired','attention')),
  return_url text not null,
  expires_at timestamptz not null default date_trunc('second',now())+interval '35 minutes',
  lease uuid, lease_until timestamptz,
  attempts integer not null default 0,
  first_attempt_at timestamptz,
  checked_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(owner_id,request_key),
  check (status<>'saved' or (session_id is not null and setup_intent_id is not null and payment_method_id is not null))
);
create index dopmi_saved_card_pending on private.dopmi_saved_card_jobs(checked_at,id) where status='pending';
alter table private.dopmi_saved_card_customers enable row level security;
alter table private.dopmi_saved_card_jobs enable row level security;
revoke all on private.dopmi_saved_card_customers,private.dopmi_saved_card_jobs from public,anon,authenticated;

create function public.dopmi_saved_card_server(operation text,data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  j private.dopmi_saved_card_jobs;
  w private.dopmi_saved_card_customers;
  actor uuid;
  requested uuid;
  customer text;
begin
  if operation='prepare' then
    actor:=(data->>'owner_id')::uuid; requested:=(data->>'key')::uuid;
    if actor is null or requested is null or data->>'consent' is distinct from 'true'
      or data->>'consent_version' is distinct from 'saved-cards-2026-10-03'
      or coalesce(data->>'return_url','') !~ '^https://[A-Za-z0-9.-]+/functions/v1/payment-return$' then
      raise exception 'Autorización para guardar tarjeta requerida' using errcode='22023';
    end if;
    if not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
      where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
      raise exception 'Cuenta no disponible' using errcode='42501';
    end if;
    perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
    select * into j from private.dopmi_saved_card_jobs where owner_id=actor and request_key=requested;
    if found then
      if j.return_url is distinct from data->>'return_url' then
        raise exception 'La solicitud cambió' using errcode='22023';
      end if;
      return to_jsonb(j);
    end if;
    if exists(select 1 from private.dopmi_saved_card_jobs where owner_id=actor and status in ('pending','attention')) then
      raise exception 'Alta de tarjeta pendiente' using errcode='55000';
    end if;
    if (select count(*) from private.dopmi_saved_card_jobs where owner_id=actor and created_at>now()-interval '1 hour')>=5 then
      raise exception 'Espera antes de agregar otra tarjeta' using errcode='55000';
    end if;
    insert into private.dopmi_saved_card_customers(owner_id) values(actor) on conflict(owner_id) do nothing;
    select * into w from private.dopmi_saved_card_customers where owner_id=actor for update;
    select stripe_customer_id into customer from private.dopmi_guardian_subscriptions where donor_id=actor;
    customer:=coalesce(customer,w.stripe_customer_id);
    insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,return_url)
      values(actor,requested,w.id,'saved-cards-2026-10-03',customer,data->>'return_url') returning * into j;
  elsif operation='lookup_session' then
    select * into j from private.dopmi_saved_card_jobs where session_id=data->>'session_id';
    if not found then return null; end if;
  elsif operation='candidates' then
    return coalesce((select jsonb_agg(x) from (select id from private.dopmi_saved_card_jobs
      where status='pending' and coalesce(lease_until,now())<=now() order by checked_at,id limit 25)x),'[]');
  else
    select * into j from private.dopmi_saved_card_jobs where id=(data->>'id')::uuid for update;
    if not found then raise exception 'Alta de tarjeta no disponible' using errcode='22023'; end if;
    if operation='claim' then
      if j.status<>'pending' or j.lease_until>now() then return null; end if;
      if not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
        where p.id=j.owner_id and p.account_status='active' and u.email_confirmed_at is not null) then
        return null;
      end if;
      if j.session_id is null and (j.attempts>=8 or j.first_attempt_at<now()-interval '23 hours') then
        update private.dopmi_saved_card_jobs set status='attention' where id=j.id; return null;
      end if;
      if j.session_id is null and j.attempts=0 and j.expires_at<now()+interval '30 minutes' then
        update private.dopmi_saved_card_jobs set status='expired' where id=j.id; return null;
      end if;
      update private.dopmi_saved_card_jobs set lease=gen_random_uuid(),lease_until=now()+interval '2 minutes',
        attempts=attempts+case when session_id is null then 1 else 0 end,
        first_attempt_at=coalesce(first_attempt_at,now()) where id=j.id returning * into j;
    elsif operation in ('customer','session','saved','expired') then
      if j.status<>'pending' or j.lease is distinct from (data->>'lease')::uuid or j.lease_until<=now() then
        raise exception 'Intento de tarjeta vencido' using errcode='40001';
      end if;
      if operation='customer' then
        customer:=data->>'customer_id';
        if coalesce(customer,'') !~ '^cus_[A-Za-z0-9]+$' or j.customer_id is not null then
          raise exception 'Cliente de tarjeta inválido' using errcode='22023';
        end if;
        select * into w from private.dopmi_saved_card_customers where id=j.wallet_id for update;
        if w.owner_id<>j.owner_id or (w.stripe_customer_id is not null and w.stripe_customer_id<>customer)
          or exists(select 1 from private.dopmi_guardian_subscriptions where stripe_customer_id=customer and donor_id<>j.owner_id) then
          raise exception 'Cliente de tarjeta no coincide' using errcode='22023';
        end if;
        update private.dopmi_saved_card_customers set stripe_customer_id=customer where id=w.id;
        update private.dopmi_saved_card_jobs set customer_id=customer where id=j.id;
      elsif operation='session' then
        if j.customer_id is null or coalesce(data->>'session_id','') !~ '^cs_(test_)?[A-Za-z0-9]+$'
          or (j.session_id is not null and j.session_id<>data->>'session_id') then
          raise exception 'Checkout de tarjeta no coincide' using errcode='22023';
        end if;
        update private.dopmi_saved_card_jobs set session_id=data->>'session_id' where id=j.id;
      else
        if j.session_id is null or j.session_id is distinct from data->>'session_id' then
          raise exception 'Checkout de tarjeta no coincide' using errcode='22023';
        end if;
        if operation='saved' then
          if coalesce(data->>'setup_intent_id','') !~ '^seti_[A-Za-z0-9]+$'
            or coalesce(data->>'payment_method_id','') !~ '^pm_[A-Za-z0-9]+$' then
            raise exception 'Tarjeta no confirmada' using errcode='22023';
          end if;
          update private.dopmi_saved_card_jobs set status='saved',setup_intent_id=data->>'setup_intent_id',
            payment_method_id=data->>'payment_method_id',lease_until=null where id=j.id;
        else
          update private.dopmi_saved_card_jobs set status='expired',lease_until=null where id=j.id;
        end if;
      end if;
    elsif operation='release' then
      update private.dopmi_saved_card_jobs set lease_until=null,checked_at=now()
        where id=j.id and lease=(data->>'lease')::uuid;
    elsif operation<>'get' then
      raise exception 'Operación de tarjeta inválida' using errcode='22023';
    end if;
    select * into j from private.dopmi_saved_card_jobs where id=j.id;
  end if;
  return to_jsonb(j);
end;
$$;
revoke all on function public.dopmi_saved_card_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_saved_card_server(text,jsonb) to service_role;

-- A device can resume its own receipt without receiving a customer/session/secret.
create function public.dopmi_saved_card_state() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
  if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  return (select jsonb_build_object('key',request_key,'status',status,
    'card_id',case when status='saved' then payment_method_id end)
    from private.dopmi_saved_card_jobs where owner_id=actor order by created_at desc,id desc limit 1);
end;
$$;
revoke all on function public.dopmi_saved_card_state() from public,anon;
grant execute on function public.dopmi_saved_card_state() to authenticated;

commit;
