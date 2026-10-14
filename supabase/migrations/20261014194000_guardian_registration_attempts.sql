begin;

-- Preparation is durable identity, NOT permission to invoke a payment API.
-- The payment consumer must obtain a fresh authorization before confirmation.
create table private.dopmi_guardian_registration_attempts (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null unique references private.dopmi_guardian_registration_evaluations(id),
  registration_id uuid not null references private.dopmi_guardian_registrations(id),
  reservation_id uuid not null unique references private.dopmi_guardian_cycles(id),
  owner_id uuid not null references public.profiles(id),
  gross_cents integer not null check(gross_cents between 2000 and 1000000),
  customer_id text not null,
  payment_method_id text not null,
  expires_at timestamptz not null,
  status text not null default 'prepared' check(status in ('prepared','expired','canceled')),
  created_at timestamptz not null default now()
);
alter table private.dopmi_guardian_registration_attempts enable row level security;
revoke all on private.dopmi_guardian_registration_attempts from public,anon,authenticated,service_role;

create function public.dopmi_guardian_registration_attempt_server(operation text,data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.dopmi_guardian_registrations; e private.dopmi_guardian_registration_evaluations;
  a private.dopmi_guardian_registration_attempts; c private.dopmi_guardian_cycles;
  j private.dopmi_saved_card_jobs; actor uuid; rescuer uuid; held jsonb; upper_net bigint;
begin
  if operation='candidates' then
    return coalesce((select jsonb_agg(jsonb_build_object('id',candidate.id)) from (
      select reg.id from private.dopmi_guardian_registrations reg
      join public.profiles p on p.id=reg.owner_id and p.account_status='active'
      join auth.users u on u.id=reg.owner_id and u.email_confirmed_at is not null
      where reg.status='registered' and reg.registered_at<=now()
        and not exists(select 1 from private.dopmi_guardian_registration_evaluations ev
          where ev.registration_id=reg.id and ev.next_evaluation_at>now())
      order by reg.registered_at,reg.id limit 20
    ) candidate),'[]'::jsonb);
  end if;
  if operation<>'prepare' then raise exception 'Operación inválida' using errcode='22023'; end if;
  select owner_id into actor from private.dopmi_guardian_registrations where id=(data->>'id')::uuid;
  if actor is null then raise exception 'Registro no disponible' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||actor,0));
  select * into r from private.dopmi_guardian_registrations where id=(data->>'id')::uuid for update;
  if r.status<>'registered' then return null; end if;
  if r.consent_version<>'guardian-registration-2026-10-14' or r.consent_at is null then
    raise exception 'Autorización requerida' using errcode='22023'; end if;
  held:=public.dopmi_guardian_registration_evaluate(r.id);
  if held is null then return null; end if;
  select * into e from private.dopmi_guardian_registration_evaluations where id=(held->>'id')::uuid for update;
  select * into a from private.dopmi_guardian_registration_attempts where evaluation_id=e.id for update;
  if e.status<>'reserved' then
    if a.id is not null and a.status='prepared' then
      update private.dopmi_guardian_registration_attempts set status='expired' where id=a.id returning * into a;
    end if;
    return case when a.id is null then null else to_jsonb(a) end;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-cycle:'||actor::text||':'||e.id::text,0));
  select * into c from private.dopmi_guardian_cycles where id=e.reservation_id for update;
  for rescuer in select distinct expense.owner_id from private.dopmi_guardian_allocations allocation
    join public.dopmi_rescue_records expense on expense.id=allocation.expense_id
    where allocation.cycle_id=c.id order by expense.owner_id
  loop perform private.dopmi_rescue_lock(rescuer); end loop;
  upper_net:=e.gross_cents-(e.gross_cents*2+50)/100;
  -- Recheck approved expenses under the same owner locks as settlement. The
  -- persisted reservation alone does not establish present payable capacity.
  if c.donor_id is distinct from actor or c.cycle_key is distinct from e.id
    or c.gross_cents is distinct from e.gross_cents or c.status is distinct from 'reserved'
    or c.expires_at<=now() or c.reserved_cents is distinct from upper_net
    or (select coalesce(sum(amount_cents),0) from private.dopmi_guardian_allocations where cycle_id=c.id)<>upper_net
    or exists(select 1 from private.dopmi_guardian_allocations allocation
      join public.dopmi_rescue_records expense on expense.id=allocation.expense_id
      where allocation.cycle_id=c.id and (expense.owner_id=actor or not private.dopmi_expense_payable(expense)
        or expense.reimbursable_cents-coalesce((select sum(d.allocated_cents+d.reserved_cents)
          from public.dopmi_donations d where d.expense_id=expense.id),0)
          -private.dopmi_guardian_reserved(expense.id)<0)) then
    perform public.dopmi_guardian_release(actor,e.id);
    update private.dopmi_guardian_registration_evaluations set status='expired' where id=e.id;
    if a.id is not null then
      update private.dopmi_guardian_registration_attempts set status='expired' where id=a.id returning * into a;
    end if;
    return case when a.id is null then null else to_jsonb(a) end;
  end if;
  select * into j from private.dopmi_saved_card_jobs where id=r.method_job_id
    and owner_id=actor and request_key=r.id and status='saved';
  if not found or j.customer_id is null or j.payment_method_id is null or j.setup_intent_id is null then
    raise exception 'Método no confirmado' using errcode='22023'; end if;
  if a.id is null then
    insert into private.dopmi_guardian_registration_attempts(evaluation_id,registration_id,reservation_id,
      owner_id,gross_cents,customer_id,payment_method_id,expires_at)
      values(e.id,r.id,c.id,actor,e.gross_cents,j.customer_id,j.payment_method_id,c.expires_at) returning * into a;
  elsif a.customer_id<>j.customer_id or a.payment_method_id<>j.payment_method_id then
    raise exception 'El método cambió' using errcode='22023';
  end if;
  return to_jsonb(a);
end $$;
revoke all on function public.dopmi_guardian_registration_attempt_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_attempt_server(text,jsonb) to service_role;

do $patch$
declare definition text; anchor text:='if operation=''cancel'' then';
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_registration_server(text,jsonb)'::regprocedure);
  if position(anchor in definition)=0 then raise exception 'Review registration attempt cancellation anchor'; end if;
  execute replace(definition,anchor,$replacement$if operation='cancel' then
      update private.dopmi_guardian_registration_attempts set status='canceled'
        where registration_id=r.id and status='prepared';$replacement$);
end $patch$;
commit;
