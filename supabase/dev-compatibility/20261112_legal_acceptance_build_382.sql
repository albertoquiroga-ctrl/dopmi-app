begin;

-- Standalone repair for verified legacy DopMi DEV (ohqxranynackjignryep).
-- The canonical migration chain already contains a different legal contract.
-- The operator must independently verify the project reference before applying.
do $guard$
declare
  profile_trigger regprocedure := to_regprocedure('private.create_profile()');
  trigger_body_md5 text;
begin
  if to_regprocedure('public.accept_current_legal(text,text)') is not null
    or to_regprocedure('private.dopmi_general_legal_pair_allowed(text,text)') is not null
    or to_regclass('private.dopmi_payment_environment') is not null
    or to_regprocedure('public.dopmi_accept_legal(text,text,boolean)') is null
    or to_regprocedure('public.accept_current_terms()') is null
    or to_regclass('private.dopmi_consents') is null then
    raise exception 'El catálogo no coincide con el DEV legado esperado';
  end if;

  select md5(regexp_replace(p.prosrc, '[[:space:]]', '', 'g')) into trigger_body_md5
    from pg_proc p
    join pg_trigger t on t.tgfoid = p.oid
    where p.oid = profile_trigger and p.prosecdef
      and t.tgrelid = 'auth.users'::regclass and t.tgname = 'dopmi_create_profile'
      and t.tgtype = 5 and t.tgenabled in ('O', 'A') and not t.tgisinternal;
  -- This is the normalized October source hash verified on DEV.
  if trigger_body_md5 is distinct from '1c9098b59591db88a25f2edc0452dc50' then
    raise exception 'El registro Auth no coincide con el contrato de octubre esperado';
  end if;

  if not exists (
    select 1 from pg_constraint c
    where c.conrelid = 'private.dopmi_consents'::regclass and c.contype = 'u'
      and c.conkey = array[
        (select attnum from pg_attribute where attrelid = c.conrelid and attname = 'owner_id'),
        (select attnum from pg_attribute where attrelid = c.conrelid and attname = 'terms_version'),
        (select attnum from pg_attribute where attrelid = c.conrelid and attname = 'privacy_version')
      ]
  ) then
    raise exception 'El registro de aceptación legal no coincide con el contrato esperado';
  end if;
end
$guard$;

-- Adapted from the general-legal RPC in 20261102032910. This legacy DEV
-- endpoint cannot assert adulthood or accept a production document pair.
create function public.accept_current_legal(accepted_terms text, accepted_privacy text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  subject public.profiles;
  accepted timestamptz;
begin
  if to_regclass('private.dopmi_payment_environment') is not null
    or to_regprocedure('private.dopmi_general_legal_pair_allowed(text,text)') is not null then
    raise exception 'Se requiere el contrato legal vigente' using errcode = '42501';
  end if;
  if actor is null
    or accepted_terms is distinct from 'terms-2026-11-01'
    or accepted_privacy is distinct from 'privacy-2026-11-01-ubicacion' then
    raise exception 'Aceptación legal inválida' using errcode = '22023';
  end if;

  select * into subject from public.profiles where id = actor for update;
  if not found or subject.account_status <> 'active' or not exists (
    select 1 from auth.users u where u.id = actor and u.email_confirmed_at is not null
  ) then
    raise exception 'Cuenta activa y confirmada requerida' using errcode = '42501';
  end if;
  if subject.terms_version like 'terms-live-%' or subject.privacy_version like 'privacy-live-%'
    or exists (
      select 1 from private.dopmi_consents c where c.owner_id = actor
        and (c.terms_version like 'terms-live-%' or c.privacy_version like 'privacy-live-%')
    ) then
    raise exception 'La cuenta ya aceptó una versión más reciente' using errcode = '22023';
  end if;

  insert into private.dopmi_consents(owner_id, terms_version, privacy_version, adult_confirmed)
    values (actor, accepted_terms, accepted_privacy, false)
    on conflict (owner_id, terms_version, privacy_version) do nothing;
  select c.accepted_at into accepted from private.dopmi_consents c
    where c.owner_id = actor and c.terms_version = accepted_terms
      and c.privacy_version = accepted_privacy and not c.adult_confirmed;
  if accepted is null then
    raise exception 'Evidencia de aceptación legal inválida' using errcode = '42501';
  end if;

  update public.profiles set terms_version = accepted_terms, terms_accepted_at = accepted,
    privacy_version = accepted_privacy, privacy_accepted_at = accepted
    where id = actor and (terms_version is distinct from accepted_terms
      or privacy_version is distinct from accepted_privacy
      or terms_accepted_at is distinct from accepted or privacy_accepted_at is distinct from accepted);
  return jsonb_build_object('terms_version', accepted_terms, 'privacy_version', accepted_privacy,
    'terms_accepted', true, 'privacy_accepted', true, 'adult_confirmed', false, 'accepted_at', accepted);
end
$$;

revoke all on function public.accept_current_legal(text,text) from public, anon, authenticated, service_role;
grant execute on function public.accept_current_legal(text,text) to authenticated;

commit;
