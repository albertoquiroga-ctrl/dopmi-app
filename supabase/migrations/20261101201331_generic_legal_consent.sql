begin;

-- General consent is separate from the adult declaration in older clients.
-- Keep both old acceptance RPCs and their pair validator unchanged for rollout.
create function private.dopmi_general_legal_pair_allowed(terms text,privacy text) returns boolean
language sql stable set search_path='' as $$
  select exists(select 1 from private.dopmi_payment_environment e where e.singleton and (
    (e.environment='production' and terms='terms-live-2026-11-01' and privacy='privacy-live-2026-11-01') or
    (e.environment='test' and terms='terms-2026-11-01' and privacy='privacy-2026-11-01')));
$$;
revoke all on function private.dopmi_general_legal_pair_allowed(text,text) from public,anon,authenticated,service_role;

-- The client names the documents it displayed; the owner-controlled environment
-- selects which exact pair is admissible. No adult assertion is accepted here.
create function public.accept_current_legal(accepted_terms text,accepted_privacy text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid:=auth.uid();
  subject public.profiles;
  accepted timestamptz;
begin
  if actor is null or not private.dopmi_general_legal_pair_allowed(accepted_terms,accepted_privacy) then
    raise exception 'Aceptación legal inválida' using errcode='22023';
  end if;
  select * into subject from public.profiles where id=actor for update;
  if not found or subject.account_status<>'active' or not exists(
    select 1 from auth.users u where u.id=actor and u.email_confirmed_at is not null
  ) then
    raise exception 'Cuenta activa y confirmada requerida' using errcode='42501';
  end if;
  -- A configuration rollback must not relabel accepted production evidence TEST.
  if accepted_terms='terms-2026-11-01' and (
    subject.terms_version in ('terms-live-2026-10-28','terms-live-2026-11-01') or
    subject.privacy_version in ('privacy-live-2026-10-28','privacy-live-2026-11-01') or
    exists(select 1 from private.dopmi_consents c where c.owner_id=actor and (
      c.terms_version in ('terms-live-2026-10-28','terms-live-2026-11-01') or
      c.privacy_version in ('privacy-live-2026-10-28','privacy-live-2026-11-01')))
  ) then
    raise exception 'La cuenta ya aceptó una versión más reciente' using errcode='22023';
  end if;
  insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed)
    values(actor,accepted_terms,accepted_privacy,false)
    on conflict(owner_id,terms_version,privacy_version) do nothing;
  select c.accepted_at into accepted from private.dopmi_consents c
    where c.owner_id=actor and c.terms_version=accepted_terms and c.privacy_version=accepted_privacy
      and not c.adult_confirmed;
  if accepted is null then
    raise exception 'Evidencia de aceptación legal inválida' using errcode='42501';
  end if;
  update public.profiles set terms_version=accepted_terms,terms_accepted_at=accepted,
    privacy_version=accepted_privacy,privacy_accepted_at=accepted
    where id=actor and (terms_version is distinct from accepted_terms
      or privacy_version is distinct from accepted_privacy
      or terms_accepted_at is distinct from accepted or privacy_accepted_at is distinct from accepted);
  return jsonb_build_object('terms_version',accepted_terms,'privacy_version',accepted_privacy,
    'terms_accepted',true,'privacy_accepted',true,'adult_confirmed',false,'accepted_at',accepted);
end $$;
revoke all on function public.accept_current_legal(text,text) from public,anon,authenticated,service_role;
grant execute on function public.accept_current_legal(text,text) to authenticated;

-- Signup records consent to the exact displayed pair. Editable metadata still
-- grants no staff authority, identity verification or financial capabilities.
create or replace function private.create_profile() returns trigger
language plpgsql security definer set search_path='' as $$
declare
  meta jsonb:=coalesce(new.raw_user_meta_data,'{}'::jsonb);
  chosen_intent text:=coalesce(meta->>'intent','adopt');
  general_accepted boolean:=private.dopmi_general_legal_pair_allowed(meta->>'terms_version',meta->>'privacy_version')
    and coalesce(meta->'terms_accepted'='true'::jsonb,false)
    and coalesce(meta->'privacy_accepted'='true'::jsonb,false);
  adult_accepted boolean:=private.dopmi_legal_pair_allowed(meta->>'terms_version',meta->>'privacy_version')
    and coalesce(meta->>'adult_confirmed'='true',false);
  accepted boolean:=general_accepted or adult_accepted;
  legacy_accepted boolean:=coalesce(meta->>'terms_version'='development-2026-09-13'
    and meta->>'terms_accepted'='true',false) and exists(
      select 1 from private.dopmi_payment_environment where singleton and environment='test');
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
    case when adult_accepted then now() end);
  if accepted then
    insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed)
      values(new.id,meta->>'terms_version',meta->>'privacy_version',adult_accepted);
  end if;
  return new;
end $$;
revoke all on function private.create_profile() from public,anon,authenticated,service_role;

-- Preserve financial instructions, flags, KYC, stable attempts and the existing
-- TEST contract. In production, either complete historical adult proof or exact
-- general consent is required; a profile projection alone is never evidence.
create or replace function private.dopmi_require_current_legal(target_actor uuid) returns void
language plpgsql stable security definer set search_path='' as $$
declare environment text;
begin
  select e.environment into environment from private.dopmi_payment_environment e where e.singleton;
  if environment='test' then return; end if;
  if environment is distinct from 'production' or target_actor is null or not exists(
    select 1 from public.profiles p join auth.users u on u.id=p.id
    join private.dopmi_consents c on c.owner_id=p.id
    where p.id=target_actor and p.account_status='active' and u.email_confirmed_at is not null
      and p.terms_accepted_at is not null and p.privacy_accepted_at is not null
      and c.terms_version=p.terms_version and c.privacy_version=p.privacy_version
      and c.accepted_at=p.terms_accepted_at and c.accepted_at=p.privacy_accepted_at
      and (
        (p.terms_version='terms-live-2026-10-28' and p.privacy_version='privacy-live-2026-10-28'
          and p.adult_confirmed_at is not null and c.adult_confirmed) or
        (p.terms_version='terms-live-2026-11-01' and p.privacy_version='privacy-live-2026-11-01'
          and not c.adult_confirmed)
      )
  ) then
    raise exception 'Acepta los términos y el aviso de privacidad vigentes' using errcode='42501';
  end if;
end $$;
revoke all on function private.dopmi_require_current_legal(uuid) from public,anon,authenticated,service_role;

commit;
