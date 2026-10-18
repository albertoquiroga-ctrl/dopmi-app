begin;

-- Rollout compatibility: 318 may still send the complete September pair.
-- This records explicit consent only; it never activates a payment or Guardian.
create or replace function public.dopmi_accept_legal(
  accepted_terms text,
  accepted_privacy text,
  confirms_adult boolean
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid:=auth.uid();
  subject public.profiles;
  accepted timestamptz;
begin
  if actor is null or confirms_adult is distinct from true
    or not coalesce((accepted_terms='terms-2026-09-28' and accepted_privacy='privacy-2026-09-28')
      or (accepted_terms='terms-2026-10-17' and accepted_privacy='privacy-2026-10-17'),false) then
    raise exception 'Aceptación legal inválida' using errcode='22023';
  end if;
  -- Serializes duplicate acceptance and competing legacy/current requests.
  select * into subject from public.profiles where id=actor for update;
  if not found or subject.account_status<>'active' then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  if accepted_terms='terms-2026-09-28' and
    (subject.terms_version='terms-2026-10-17' or subject.privacy_version='privacy-2026-10-17') then
    raise exception 'La cuenta ya aceptó una versión más reciente' using errcode='22023';
  end if;
  insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed)
    values(actor,accepted_terms,accepted_privacy,true)
    on conflict(owner_id,terms_version,privacy_version) do nothing;
  select accepted_at into accepted from private.dopmi_consents
    where owner_id=actor and terms_version=accepted_terms and privacy_version=accepted_privacy;
  update public.profiles set terms_version=accepted_terms,terms_accepted_at=accepted,
    privacy_version=accepted_privacy,privacy_accepted_at=accepted,
    adult_confirmed_at=coalesce(subject.adult_confirmed_at,accepted)
    where id=actor and (terms_version is distinct from accepted_terms
      or privacy_version is distinct from accepted_privacy
      or terms_accepted_at is distinct from accepted
      or privacy_accepted_at is distinct from accepted or adult_confirmed_at is null);
  return jsonb_build_object('terms_version',accepted_terms,'privacy_version',accepted_privacy,
    'adult_confirmed',true,'accepted_at',accepted);
end $$;
revoke all on function public.dopmi_accept_legal(text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_accept_legal(text,text,boolean) to authenticated;

-- The original development RPC must not overwrite either public legal version.
create or replace function public.accept_current_terms() returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); subject public.profiles;
begin
  select * into subject from public.profiles where id=actor for update;
  if not found or subject.account_status<>'active' then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  if (subject.terms_version is not null and subject.terms_version<>'development-2026-09-13')
    or subject.privacy_version is not null then
    raise exception 'La cuenta ya aceptó una versión más reciente' using errcode='22023';
  end if;
  update public.profiles set terms_version='development-2026-09-13',
    terms_accepted_at=coalesce(subject.terms_accepted_at,now()) where id=actor;
end $$;
revoke all on function public.accept_current_terms() from public,anon,authenticated,service_role;
grant execute on function public.accept_current_terms() to authenticated;

-- Signup metadata records only an exact accepted pair, not authority or roles.
-- Historic development/September registration remains compatible during rollout.
create or replace function private.create_profile() returns trigger
language plpgsql security definer set search_path='' as $$
declare
  meta jsonb:=coalesce(new.raw_user_meta_data,'{}'::jsonb);
  chosen_intent text:=coalesce(meta->>'intent','adopt');
  accepted boolean:=coalesce(((meta->>'terms_version'='terms-2026-09-28'
    and meta->>'privacy_version'='privacy-2026-09-28')
    or (meta->>'terms_version'='terms-2026-10-17'
    and meta->>'privacy_version'='privacy-2026-10-17'))
    and meta->>'adult_confirmed'='true',false);
  legacy_accepted boolean:=meta->>'terms_version'='development-2026-09-13'
    and meta->>'terms_accepted'='true';
begin
  if chosen_intent not in ('adopt','donate','rescue') then chosen_intent:='adopt'; end if;
  insert into public.profiles(id,display_name,phone,intent,active_mode,terms_version,
    terms_accepted_at,privacy_version,privacy_accepted_at,adult_confirmed_at)
  values(new.id,left(coalesce(nullif(btrim(meta->>'display_name'),''),nullif(btrim(meta->>'full_name'),''),'Mi perfil'),80),
    left(coalesce(meta->>'phone',''),24),chosen_intent,
    case when chosen_intent='rescue' then 'rescuer' else 'donor' end,
    case when accepted then meta->>'terms_version' when legacy_accepted then 'development-2026-09-13' end,
    case when accepted or legacy_accepted then now() end,
    case when accepted then meta->>'privacy_version' end,case when accepted then now() end,
    case when accepted then now() end);
  if accepted then
    insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed)
      values(new.id,meta->>'terms_version',meta->>'privacy_version',true);
  end if;
  return new;
end $$;
revoke all on function private.create_profile() from public,anon,authenticated,service_role;

-- Legal acceptance must not block an authenticated owner from inspecting the
-- registration needed to cancel. This projection never reconciles a method,
-- evaluates capacity, reserves money or opens enrollment. The normal active /
-- confirmed-account registration RPC and all write guards remain unchanged.
create function public.dopmi_guardian_registration_cancellation_state()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid(); r private.dopmi_guardian_registrations;
  e private.dopmi_guardian_registration_evaluations; a private.dopmi_guardian_registration_attempts;
  settlement jsonb; payment_state text; cycle integer; due timestamptz; next_date timestamptz;
begin
  if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=actor) then
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
revoke all on function public.dopmi_guardian_registration_cancellation_state() from public,anon,service_role;
grant execute on function public.dopmi_guardian_registration_cancellation_state() to authenticated;

commit;
