begin;
create function public.dopmi_guardian_registration_bank_action(target_owner uuid,target_registration uuid,target_attempt uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.dopmi_guardian_registrations; a private.dopmi_guardian_registration_attempts;
  c private.dopmi_guardian_cycles; j private.dopmi_saved_card_jobs; rescuer uuid; upper_net bigint;
begin
  if target_owner is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=target_owner and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Cuenta no disponible' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||target_owner,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||target_owner,0));
  select * into r from private.dopmi_guardian_registrations where id=target_registration and owner_id=target_owner for update;
  if not found or r.status<>'registered' or r.consent_at is null
    or r.consent_version<>'guardian-registration-2026-10-14' then
    raise exception 'Registro no disponible' using errcode='42501'; end if;
  select * into a from private.dopmi_guardian_registration_attempts
    where id=target_attempt and registration_id=r.id and owner_id=target_owner for update;
  if not found or a.pay_requested_at is null or a.stripe_payment_intent_id is null
    or a.resolved_at is not null or a.processor_state is distinct from 'requires_action'
    or a.expires_at<=clock_timestamp()+interval '2 minutes'
    or exists(select 1 from private.dopmi_guardian_settlements where registration_attempt_id=a.id) then
    raise exception 'Acción bancaria no disponible' using errcode='55000'; end if;
  select * into j from private.dopmi_saved_card_jobs where id=r.method_job_id and owner_id=target_owner
    and request_key=r.id and status='saved';
  if not found or j.setup_intent_id is null or j.customer_id is distinct from a.customer_id
    or j.payment_method_id is distinct from a.payment_method_id then
    raise exception 'Método no confirmado' using errcode='55000'; end if;
  select * into c from private.dopmi_guardian_cycles where id=a.reservation_id for update;
  for rescuer in select distinct expense.owner_id from private.dopmi_guardian_allocations allocation
    join public.dopmi_rescue_records expense on expense.id=allocation.expense_id
    where allocation.cycle_id=c.id order by expense.owner_id
  loop perform private.dopmi_rescue_lock(rescuer); end loop;
  upper_net:=a.gross_cents-(a.gross_cents*2+50)/100;
  if c.donor_id is distinct from target_owner or c.cycle_key is distinct from a.evaluation_id
    or c.gross_cents is distinct from a.gross_cents or c.status is distinct from 'reserved'
    or c.expires_at<=clock_timestamp()+interval '2 minutes' or c.reserved_cents is distinct from upper_net
    or (select coalesce(sum(amount_cents),0) from private.dopmi_guardian_allocations where cycle_id=c.id)<>upper_net
    or exists(select 1 from private.dopmi_guardian_allocations allocation
      join public.dopmi_rescue_records expense on expense.id=allocation.expense_id
      where allocation.cycle_id=c.id and (expense.owner_id=target_owner or not private.dopmi_expense_payable(expense)
        or expense.reimbursable_cents-coalesce((select sum(d.allocated_cents+d.reserved_cents)
          from public.dopmi_donations d where d.expense_id=expense.id),0)
          -private.dopmi_guardian_reserved(expense.id)<0)) then
    raise exception 'Reserva no vigente' using errcode='55000'; end if;
  -- No new marker, renewal, reservation, payment or grace period.
  return to_jsonb(a);
end $$;
revoke all on function public.dopmi_guardian_registration_bank_action(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_bank_action(uuid,uuid,uuid) to service_role;
commit;
