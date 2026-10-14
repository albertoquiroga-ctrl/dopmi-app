begin;

-- An evaluation is not a payment authorization. Keep the cycle identity and
-- amount immutable even when a response is lost or capacity later changes.
create table private.dopmi_guardian_registration_evaluations (
  id uuid primary key default gen_random_uuid(),
  registration_id uuid not null references private.dopmi_guardian_registrations(id),
  cycle_number integer not null check(cycle_number between 0 and 1199),
  due_at timestamptz not null,
  next_evaluation_at timestamptz not null,
  gross_cents integer not null check(gross_cents between 2000 and 1000000),
  registration_revision integer not null,
  reservation_id uuid unique references private.dopmi_guardian_cycles(id),
  status text not null check(status in ('reserved','skipped','expired','canceled')),
  created_at timestamptz not null default now(),
  unique(registration_id,cycle_number)
);
alter table private.dopmi_guardian_registration_evaluations enable row level security;
revoke all on private.dopmi_guardian_registration_evaluations from public,anon,authenticated,service_role;

create function public.dopmi_guardian_registration_evaluate(target_registration uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.dopmi_guardian_registrations; e private.dopmi_guardian_registration_evaluations;
  actor uuid; cycle integer; due timestamptz; next_date timestamptz; held jsonb;
begin
  select owner_id into actor from private.dopmi_guardian_registrations where id=target_registration;
  if actor is null then raise exception 'Registro no disponible' using errcode='42501'; end if;
  -- Same order as registration setup/cancel/amount. Reservation then takes the
  -- existing cycle and rescuer locks, shared with individual contributions.
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||actor,0));
  select * into r from private.dopmi_guardian_registrations where id=target_registration for update;
  if r.status<>'registered' then return null; end if;
  if not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  if not exists(select 1 from private.dopmi_saved_card_jobs j where j.id=r.method_job_id
    and j.owner_id=actor and j.request_key=r.id and j.status='saved'
    and j.customer_id is not null and j.setup_intent_id is not null and j.payment_method_id is not null) then
    raise exception 'Método no confirmado' using errcode='22023';
  end if;
  if now()<r.registered_at then return null; end if;
  cycle:=(extract(year from now() at time zone 'UTC')::integer-extract(year from r.registered_at at time zone 'UTC')::integer)*12
    +extract(month from now() at time zone 'UTC')::integer-extract(month from r.registered_at at time zone 'UTC')::integer;
  if cycle>1199 then raise exception 'Calendario inválido' using errcode='22023'; end if;
  if cycle>0 and private.dopmi_guardian_registration_date(r.registered_at,cycle)>now() then cycle:=cycle-1; end if;
  due:=case when cycle=0 then r.registered_at else private.dopmi_guardian_registration_date(r.registered_at,cycle) end;
  next_date:=private.dopmi_guardian_registration_date(r.registered_at,cycle+1);
  -- Do not collect missed months. Only the current anniversary interval can
  -- be evaluated; a skipped interval stays skipped even if capacity returns.
  select * into e from private.dopmi_guardian_registration_evaluations
    where registration_id=r.id and cycle_number=cycle for update;
  if not found then
    insert into private.dopmi_guardian_registration_evaluations(registration_id,cycle_number,due_at,next_evaluation_at,
      gross_cents,registration_revision,status)
      values(r.id,cycle,due,next_date,r.gross_cents,r.revision,'skipped') returning * into e;
    held:=public.dopmi_guardian_reserve(actor,e.id,r.gross_cents);
    update private.dopmi_guardian_registration_evaluations set reservation_id=(held->>'id')::uuid,
      status=held->>'status' where id=e.id returning * into e;
  elsif e.status='reserved' then
    -- This is a read/reconciliation, never a new reservation or renewed TTL.
    update private.dopmi_guardian_registration_evaluations set status='expired'
      where id=e.id and exists(select 1 from private.dopmi_guardian_cycles c where c.id=e.reservation_id
        and (c.status<>'reserved' or c.expires_at<=now())) returning * into e;
    if not found then select * into e from private.dopmi_guardian_registration_evaluations
      where registration_id=r.id and cycle_number=cycle; end if;
  end if;
  return to_jsonb(e);
end $$;
revoke all on function public.dopmi_guardian_registration_evaluate(uuid) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_evaluate(uuid) to service_role;

-- Cancellation releases an uncharged hold atomically. Amount changes remain
-- available for the next evaluation; they never mutate the persisted cycle.
do $patch$
declare definition text; cancel_anchor text:='if operation=''cancel'' then';
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_registration_server(text,jsonb)'::regprocedure);
  if position(cancel_anchor in definition)=0 then
    raise exception 'Review registration evaluation lifecycle anchors'; end if;
  definition:=replace(definition,cancel_anchor,$replacement$if operation='cancel' then
      perform public.dopmi_guardian_release(actor,e.id) from private.dopmi_guardian_registration_evaluations e
        where e.registration_id=r.id and e.status='reserved';
      update private.dopmi_guardian_registration_evaluations set status='canceled'
        where registration_id=r.id and status='reserved';$replacement$);
  execute definition;
end $patch$;
commit;
