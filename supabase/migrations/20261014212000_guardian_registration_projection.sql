begin;
create or replace function public.dopmi_guardian_registration_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); r private.dopmi_guardian_registrations;
  e private.dopmi_guardian_registration_evaluations; a private.dopmi_guardian_registration_attempts;
  settlement jsonb; payment_state text; cycle integer; due timestamptz; next_date timestamptz;
begin
  if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Cuenta no disponible' using errcode='42501'; end if;
  select * into r from private.dopmi_guardian_registrations where owner_id=actor
    order by (status<>'canceled') desc,registered_at desc,id desc limit 1;
  if not found then return null; end if;
  cycle:=greatest(0,(extract(year from now() at time zone 'UTC')::integer-extract(year from r.registered_at at time zone 'UTC')::integer)*12
    +extract(month from now() at time zone 'UTC')::integer-extract(month from r.registered_at at time zone 'UTC')::integer);
  cycle:=least(cycle,1199);
  due:=case when cycle=0 then r.registered_at else private.dopmi_guardian_registration_date(r.registered_at,cycle) end;
  if cycle>0 and now()<due then cycle:=cycle-1; end if;
  next_date:=private.dopmi_guardian_registration_date(r.registered_at,cycle+1);
  select * into e from private.dopmi_guardian_registration_evaluations
    where registration_id=r.id order by cycle_number desc,id desc limit 1;
  select att.* into a from private.dopmi_guardian_registration_attempts att
    join private.dopmi_guardian_registration_evaluations ev on ev.id=att.evaluation_id
    where att.registration_id=r.id
    order by (att.resolved_at is null and att.pay_requested_at is not null) desc,ev.cycle_number desc,att.id desc limit 1;
  if a.id is not null then settlement:=private.dopmi_guardian_settlement_view(a.reservation_id); end if;
  payment_state:=case
    when settlement->>'external_refund_pending'='true' then 'refund_pending'
    when settlement->>'status'='allocated' then 'allocated'
    when settlement->>'status'='refunded' then 'refunded'
    when settlement->>'status'='refund_pending' then 'refund_pending'
    when a.pay_requested_at is not null and a.processor_state='processor_succeeded' then 'processor_confirmed'
    when a.pay_requested_at is not null and a.processor_state='processor_canceled' then 'canceled'
    when a.pay_requested_at is not null and a.processor_state='requires_action' then 'requires_action'
    when a.pay_requested_at is not null then 'processing'
    when e.status='skipped' then 'skipped'
    when e.status='expired' then 'expired'
    when e.status='canceled' or a.status='canceled' then 'canceled'
    when a.status='prepared' then 'prepared'
    else 'not_evaluated' end;
  return jsonb_build_object('id',r.id,'key',r.request_key,'status',r.status,'gross_cents',r.gross_cents,
    'revision',r.revision,'registered_at',r.registered_at,'consent_version',r.consent_version,
    'next_evaluation_at',case when r.status<>'canceled' then next_date end,
    'evaluation',case when e.id is not null then jsonb_build_object('cycle_number',e.cycle_number,
      'status',e.status,'due_at',e.due_at) end,
    'payment',jsonb_build_object('state',payment_state,'attempt_id',a.id,
      'cycle_number',coalesce((select ev.cycle_number from private.dopmi_guardian_registration_evaluations ev where ev.id=a.evaluation_id),e.cycle_number),
      'gross_cents',a.gross_cents,'allocated_cents',coalesce((settlement->>'allocated_cents')::bigint,0),
      'refund_cents',coalesce((settlement->>'refund_cents')::bigint,0)));
end $$;
revoke all on function public.dopmi_guardian_registration_state() from public,anon,service_role;
grant execute on function public.dopmi_guardian_registration_state() to authenticated;
commit;
