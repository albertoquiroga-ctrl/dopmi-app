begin;

-- Registration is private authorization, not a subscription or a contribution.
create table private.dopmi_guardian_registrations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  request_key uuid not null,
  initial_gross_cents integer not null check (initial_gross_cents between 2000 and 1000000),
  gross_cents integer not null check (gross_cents between 2000 and 1000000),
  consent_version text not null check (consent_version='guardian-registration-2026-10-14'),
  consent_at timestamptz not null default now(),
  registered_at timestamptz not null default date_trunc('second',now()),
  status text not null default 'method_pending' check (status in ('method_pending','registered','canceled')),
  method_job_id uuid references private.dopmi_saved_card_jobs(id),
  revision integer not null default 0 check (revision>=0),
  canceled_at timestamptz,
  unique(owner_id,request_key),
  check ((status='canceled')=(canceled_at is not null)),
  check (status<>'registered' or method_job_id is not null)
);
create unique index dopmi_guardian_registration_open on private.dopmi_guardian_registrations(owner_id)
  where status<>'canceled';
alter table private.dopmi_guardian_registrations enable row level security;
revoke all on private.dopmi_guardian_registrations from public,anon,authenticated,service_role;

-- Server owns the original anniversary. Never advance from a clamped date.
create function private.dopmi_guardian_registration_date(origin timestamptz, cycle integer)
returns timestamptz language plpgsql immutable set search_path='' as $$
declare local_origin timestamp:=origin at time zone 'UTC'; target timestamp; day_number integer;
begin
  if origin is null or cycle is null or cycle<1 or cycle>1200 then
    raise exception 'Calendario inválido' using errcode='22023';
  end if;
  target:=date_trunc('month',local_origin)+make_interval(months=>cycle);
  day_number:=least(extract(day from local_origin)::integer,
    extract(day from target+interval '1 month'-interval '1 day')::integer);
  return (target+make_interval(days=>day_number-1)+(local_origin-date_trunc('day',local_origin))) at time zone 'UTC';
end $$;
revoke all on function private.dopmi_guardian_registration_date(timestamptz,integer) from public,anon,authenticated,service_role;

create function public.dopmi_guardian_registration_server(operation text,data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.dopmi_guardian_registrations; actor uuid:=(data->>'owner_id')::uuid;
  requested uuid; gross integer; j private.dopmi_saved_card_jobs;
begin
  if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  -- Shared lock order with saved-card setup and initial activation.
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||actor,0));
  if operation='prepare' then
    requested:=(data->>'key')::uuid; gross:=(data->>'gross_cents')::integer;
    if requested is null or gross is null or gross<2000 or gross>1000000
      or data->>'consent' is distinct from 'true'
      or data->>'consent_version' is distinct from 'guardian-registration-2026-10-14' then
      raise exception 'Autorización requerida' using errcode='22023';
    end if;
    select * into r from private.dopmi_guardian_registrations where owner_id=actor and request_key=requested for update;
    if found then
      if r.initial_gross_cents<>gross then raise exception 'La solicitud cambió' using errcode='22023'; end if;
    else
      if exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=actor)
        or exists(select 1 from private.dopmi_guardian_activations where donor_id=actor and status in ('pending','settled','attention'))
        or exists(select 1 from private.dopmi_guardian_registrations where owner_id=actor and status<>'canceled') then
        raise exception 'Registro Guardián existente' using errcode='55000';
      end if;
      insert into private.dopmi_guardian_registrations(owner_id,request_key,initial_gross_cents,gross_cents,consent_version)
        values(actor,requested,gross,gross,'guardian-registration-2026-10-14') returning * into r;
    end if;
  else
    select * into r from private.dopmi_guardian_registrations where id=(data->>'id')::uuid and owner_id=actor for update;
    if not found then raise exception 'Registro no disponible' using errcode='42501'; end if;
    if operation='cancel' then
      if r.status<>'canceled' then
        update private.dopmi_guardian_registrations set status='canceled',canceled_at=now(),revision=revision+1
          where id=r.id returning * into r;
      end if;
    elsif operation='reconcile_method' then
      if r.status='method_pending' then
        -- Only the saved-card job deterministically belonging to this
        -- registration may complete it. No caller-supplied method/job IDs.
        select * into j from private.dopmi_saved_card_jobs where owner_id=actor
          and request_key=r.id and status='saved';
        if found and j.payment_method_id is not null and j.setup_intent_id is not null
          and j.customer_id is not null then
          update private.dopmi_guardian_registrations set status='registered',method_job_id=j.id,revision=revision+1
            where id=r.id returning * into r;
        end if;
      end if;
    elsif operation='confirm_method' then
      if r.status='canceled' then return to_jsonb(r); end if;
      select * into j from private.dopmi_saved_card_jobs where id=(data->>'method_job_id')::uuid
        and owner_id=actor and request_key=r.id and status='saved';
      if not found or j.payment_method_id is null or j.setup_intent_id is null or j.customer_id is null then
        raise exception 'Método no confirmado' using errcode='22023';
      end if;
      if r.method_job_id is not null and r.method_job_id<>j.id then
        raise exception 'El registro cambió' using errcode='40001';
      end if;
      if r.status='method_pending' then
        update private.dopmi_guardian_registrations set status='registered',method_job_id=j.id,revision=revision+1
          where id=r.id returning * into r;
      end if;
    elsif operation='change_amount' then
      gross:=(data->>'gross_cents')::integer;
      if r.status='canceled' or (data->>'revision')::integer is distinct from r.revision then
        raise exception 'El registro cambió' using errcode='40001';
      end if;
      if gross is null or gross<2000 or gross>1000000 or data->>'consent' is distinct from 'true'
        or data->>'consent_version' is distinct from r.consent_version then
        raise exception 'Autorización requerida' using errcode='22023';
      end if;
      update private.dopmi_guardian_registrations set gross_cents=gross,consent_at=now(),revision=revision+1
        where id=r.id returning * into r;
    elsif operation<>'get' then raise exception 'Operación inválida' using errcode='22023';
    end if;
  end if;
  return to_jsonb(r)||jsonb_build_object('next_evaluation_at',private.dopmi_guardian_registration_date(r.registered_at,1));
end $$;
revoke all on function public.dopmi_guardian_registration_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_server(text,jsonb) to service_role;

create function public.dopmi_guardian_registration_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); r private.dopmi_guardian_registrations;
begin
  if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  select * into r from private.dopmi_guardian_registrations where owner_id=actor order by (status<>'canceled') desc,registered_at desc,id desc limit 1;
  if not found then return null; end if;
  return jsonb_build_object('id',r.id,'key',r.request_key,'status',r.status,'gross_cents',r.gross_cents,
    'revision',r.revision,'registered_at',r.registered_at,'consent_version',r.consent_version,
    'next_evaluation_at',case when r.status<>'canceled' then private.dopmi_guardian_registration_date(r.registered_at,1) end);
end $$;
revoke all on function public.dopmi_guardian_registration_state() from public,anon;
grant execute on function public.dopmi_guardian_registration_state() to authenticated;

-- The old activation path cannot create a second enrollment while registration
-- exists. Keep historical activation retries before this new-operation guard.
do $guard$
declare definition text; anchor text:='held:=public.dopmi_guardian_reserve(donor,requested_key,gross);';
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure);
  if position(anchor in definition)=0 then raise exception 'Review registration activation guard anchor'; end if;
  execute replace(definition,anchor,$replacement$if exists(select 1 from private.dopmi_guardian_registrations
    where owner_id=donor and status<>'canceled') then
    raise exception 'Registro Guardián existente' using errcode='55000'; end if;
  held:=public.dopmi_guardian_reserve(donor,requested_key,gross);$replacement$);
end $guard$;
commit;
