begin;

-- Admission follows the owner-controlled database binding, never request or
-- signup metadata. September compatibility belongs only to the TEST rollout.
create function private.dopmi_legal_pair_allowed(terms text,privacy text) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.dopmi_payment_environment e where e.singleton and (
    (e.environment='production' and terms='terms-live-2026-10-28' and privacy='privacy-live-2026-10-28') or
    (e.environment='test' and (
      (terms='terms-2026-10-17' and privacy='privacy-2026-10-17') or
      (terms='terms-2026-09-28' and privacy='privacy-2026-09-28')))));
$$;
revoke all on function private.dopmi_legal_pair_allowed(text,text) from public,anon,authenticated,service_role;

create or replace function public.dopmi_accept_legal(
  accepted_terms text,accepted_privacy text,confirms_adult boolean
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid:=auth.uid();
  subject public.profiles;
  accepted timestamptz;
begin
  if actor is null or confirms_adult is distinct from true or
    not private.dopmi_legal_pair_allowed(accepted_terms,accepted_privacy) then
    raise exception 'Aceptación legal inválida' using errcode='22023';
  end if;
  -- Preserve the existing serialization and immutable per-pair evidence.
  select * into subject from public.profiles where id=actor for update;
  if not found or subject.account_status<>'active' then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  -- Even an owner changing configuration back to TEST cannot make a client
  -- overwrite LIVE acceptance. Existing LIVE evidence is never relabeled TEST.
  if (accepted_terms<>'terms-live-2026-10-28' and (
      subject.terms_version='terms-live-2026-10-28' or subject.privacy_version='privacy-live-2026-10-28' or
      exists(select 1 from private.dopmi_consents c where c.owner_id=actor and
        (c.terms_version='terms-live-2026-10-28' or c.privacy_version='privacy-live-2026-10-28')))) or
    (accepted_terms='terms-2026-09-28' and
      (subject.terms_version='terms-2026-10-17' or subject.privacy_version='privacy-2026-10-17')) then
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

-- Preserve development compatibility only in TEST; this RPC cannot bypass the
-- environment-specific legal pair or downgrade an accepted public version.
create or replace function public.accept_current_terms() returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); subject public.profiles;
begin
  if not exists(select 1 from private.dopmi_payment_environment where singleton and environment='test') then
    raise exception 'Aceptación legal inválida' using errcode='22023';
  end if;
  select * into subject from public.profiles where id=actor for update;
  if not found or subject.account_status<>'active' then
    raise exception 'Cuenta no disponible' using errcode='42501';
  end if;
  if (subject.terms_version is not null and subject.terms_version<>'development-2026-09-13')
    or subject.privacy_version is not null or exists(select 1 from private.dopmi_consents c where c.owner_id=actor and
      (c.terms_version='terms-live-2026-10-28' or c.privacy_version='privacy-live-2026-10-28')) then
    raise exception 'La cuenta ya aceptó una versión más reciente' using errcode='22023';
  end if;
  update public.profiles set terms_version='development-2026-09-13',
    terms_accepted_at=coalesce(subject.terms_accepted_at,now()) where id=actor;
end $$;
revoke all on function public.accept_current_terms() from public,anon,authenticated,service_role;
grant execute on function public.accept_current_terms() to authenticated;

-- OAuth may create an unaccepted profile. Cross-environment, missing or mixed
-- metadata records no consent; it never aborts Auth or grants an admin role.
create or replace function private.create_profile() returns trigger
language plpgsql security definer set search_path='' as $$
declare
  meta jsonb:=coalesce(new.raw_user_meta_data,'{}'::jsonb);
  chosen_intent text:=coalesce(meta->>'intent','adopt');
  accepted boolean:=private.dopmi_legal_pair_allowed(meta->>'terms_version',meta->>'privacy_version')
    and coalesce(meta->>'adult_confirmed'='true',false);
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
    case when accepted then now() end);
  if accepted then
    insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed)
      values(new.id,meta->>'terms_version',meta->>'privacy_version',true);
  end if;
  return new;
end $$;
revoke all on function private.create_profile() from public,anon,authenticated,service_role;

commit;
