begin;
-- Binding precedes the one-way marker; never authorize an unknown processor identity.
create or replace function public.dopmi_guardian_registration_authorize_payment(target_attempt uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a private.dopmi_guardian_registration_attempts; fresh jsonb;
begin
  select * into a from private.dopmi_guardian_registration_attempts where id=target_attempt;
  if not found then raise exception 'Intento no disponible' using errcode='42501'; end if;
  -- Match the setup/cancellation lock order before re-reading the marker.
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||a.owner_id,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||a.owner_id,0));
  select * into a from private.dopmi_guardian_registration_attempts where id=target_attempt for update;
  if a.pay_requested_at is not null or a.status<>'prepared' or a.stripe_payment_intent_id is null then return null; end if;
  -- Reuse the entire fresh account, consent, binding, cycle, capacity and
  -- rescuer-lock validation. A caller cannot supply an amount or method.
  fresh:=public.dopmi_guardian_registration_attempt_server('prepare',
    jsonb_build_object('id',a.registration_id));
  if fresh is null or (fresh->>'id')::uuid<>a.id or fresh->>'status'<>'prepared'
    or (fresh->>'expires_at')::timestamptz<=clock_timestamp()+interval '2 minutes'
    or not exists(select 1 from private.dopmi_guardian_cycles c where c.id=a.reservation_id
      and c.status='reserved' and c.expires_at>clock_timestamp()+interval '2 minutes') then return null; end if;
  update private.dopmi_guardian_registration_attempts set pay_requested_at=clock_timestamp()
    where id=a.id and pay_requested_at is null returning * into a;
  if not found then return null; end if;
  return to_jsonb(a)||jsonb_build_object('payment_key','guardian-registration:'||a.id);
end $$;
revoke all on function public.dopmi_guardian_registration_authorize_payment(uuid) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_authorize_payment(uuid) to service_role;

commit;
