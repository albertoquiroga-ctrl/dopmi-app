begin;

-- Persist the unconfirmed processor identity before the irreversible send
-- marker. Binding is not payment authorization and cannot complete a cycle.
alter table private.dopmi_guardian_registration_attempts
  add column stripe_payment_intent_id text unique
    check(stripe_payment_intent_id ~ '^pi_[A-Za-z0-9]+$');

create function public.dopmi_guardian_registration_bind_payment(target_attempt uuid, processor_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a private.dopmi_guardian_registration_attempts;
begin
  if processor_id is null or processor_id !~ '^pi_[A-Za-z0-9]+$' then
    raise exception 'Identidad de pago inválida' using errcode='22023';
  end if;
  select * into a from private.dopmi_guardian_registration_attempts where id=target_attempt;
  if not found then raise exception 'Intento no disponible' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||a.owner_id,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||a.owner_id,0));
  select * into a from private.dopmi_guardian_registration_attempts where id=target_attempt for update;
  if a.stripe_payment_intent_id is not null then
    if a.stripe_payment_intent_id<>processor_id then
      raise exception 'Identidad de pago inmutable' using errcode='22023';
    end if;
    return to_jsonb(a);
  end if;
  if a.status<>'prepared' or a.pay_requested_at is not null
    or a.expires_at<=clock_timestamp()
    or not exists(select 1 from private.dopmi_guardian_registrations r
      where r.id=a.registration_id and r.status='registered') then
    raise exception 'Intento no disponible' using errcode='55000';
  end if;
  update private.dopmi_guardian_registration_attempts set stripe_payment_intent_id=processor_id
    where id=a.id returning * into a;
  return to_jsonb(a);
end $$;
revoke all on function public.dopmi_guardian_registration_bind_payment(uuid,text) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_bind_payment(uuid,text) to service_role;

commit;
