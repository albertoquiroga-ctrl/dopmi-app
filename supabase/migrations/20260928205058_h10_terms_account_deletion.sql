begin;

-- H10 public consent. The profile row becomes the durable accounting subject:
-- Auth can be removed while legally required payment evidence keeps an opaque id.
alter table public.profiles drop constraint profiles_id_fkey;
alter table public.profiles drop constraint profiles_account_status_check;
alter table public.profiles add constraint profiles_account_status_check
  check (account_status in ('active','suspended','deletion_requested','deleted'));
alter table public.profiles
  add column adult_confirmed_at timestamptz,
  add column privacy_version text,
  add column privacy_accepted_at timestamptz;

create table private.dopmi_consents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  terms_version text not null,
  privacy_version text not null,
  adult_confirmed boolean not null,
  accepted_at timestamptz not null default now(),
  unique(owner_id,terms_version,privacy_version)
);
alter table private.dopmi_consents enable row level security;
revoke all on private.dopmi_consents from public,anon,authenticated;

create table private.dopmi_account_deletions (
  owner_id uuid primary key references public.profiles(id) on delete restrict,
  request_key uuid not null,
  status text not null default 'solicitado'
    check(status in ('solicitado','procesando','requiere_atencion','completado')),
  requested_at timestamptz not null default now(),
  processing_at timestamptz,
  completed_at timestamptz,
  attention_code text,
  updated_at timestamptz not null default now(),
  unique(request_key),
  check((status='completado')=(completed_at is not null))
);
alter table private.dopmi_account_deletions enable row level security;
revoke all on private.dopmi_account_deletions from public,anon,authenticated;

create function public.dopmi_accept_legal(
  accepted_terms text,
  accepted_privacy text,
  confirms_adult boolean
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); accepted timestamptz:=now();
begin
  if actor is null or accepted_terms is distinct from 'terms-2026-09-28'
    or accepted_privacy is distinct from 'privacy-2026-09-28'
    or confirms_adult is distinct from true then
    raise exception 'Aceptación legal inválida' using errcode='22023';
  end if;
  update public.profiles set terms_version=accepted_terms,terms_accepted_at=accepted,
    privacy_version=accepted_privacy,privacy_accepted_at=accepted,
    adult_confirmed_at=accepted
  where id=actor and account_status='active';
  if not found then raise exception 'Cuenta no disponible' using errcode='42501'; end if;
  insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed,accepted_at)
  values(actor,accepted_terms,accepted_privacy,true,accepted)
  on conflict(owner_id,terms_version,privacy_version) do nothing;
  return jsonb_build_object('terms_version',accepted_terms,'privacy_version',accepted_privacy,
    'adult_confirmed',true,'accepted_at',accepted);
end $$;
revoke all on function public.dopmi_accept_legal(text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_accept_legal(text,text,boolean) to authenticated;

create function private.dopmi_account_deletion_view(owner uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('status',d.status,'requested_at',d.requested_at,
    'completed_at',d.completed_at,'attention_code',d.attention_code)
  from private.dopmi_account_deletions d where d.owner_id=owner;
$$;
revoke all on function private.dopmi_account_deletion_view(uuid) from public,anon,authenticated;

create function public.dopmi_account_deletion_status() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
  if actor is null then raise exception 'Inicia sesión' using errcode='42501'; end if;
  return private.dopmi_account_deletion_view(actor);
end $$;
revoke all on function public.dopmi_account_deletion_status() from public,anon,authenticated,service_role;
grant execute on function public.dopmi_account_deletion_status() to authenticated;

-- Service-only. The Edge Function first verifies the fresh user token and a
-- recent sign-in, then calls this idempotent transition with the token owner.
create function public.dopmi_account_deletion_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  owner uuid;
  request_id uuid;
  plan private.dopmi_guardian_subscriptions;
  deletion private.dopmi_account_deletions;
  pending_money boolean;
begin
  owner:=(data->>'owner_id')::uuid;
  if owner is null then raise exception 'Solicitud inválida' using errcode='22023'; end if;

  if operation='request' then
    request_id:=(data->>'request_key')::uuid;
    if request_id is null then raise exception 'Solicitud inválida' using errcode='22023'; end if;
    perform 1 from public.profiles where id=owner for update;
    if not found then return jsonb_build_object('status','completado'); end if;
    insert into private.dopmi_account_deletions(owner_id,request_key)
      values(owner,request_id) on conflict(owner_id) do nothing;
    select * into deletion from private.dopmi_account_deletions where owner_id=owner for update;
    if deletion.request_key<>request_id and deletion.status<>'completado' then
      raise exception 'La solicitud ya existe' using errcode='22023';
    end if;
    if deletion.status='completado' then return private.dopmi_account_deletion_view(owner); end if;
    update public.profiles set account_status='deletion_requested' where id=owner and account_status<>'deleted';
    update public.dopmi_adoptions set status='archived',updated_at=now()
      where owner_id=owner and status in ('draft','submitted','changes_requested','published');
    update public.dopmi_rescue_records set status='closed',updated_at=now()
      where owner_id=owner and kind='case' and status in ('draft','submitted','changes_requested','approved');
    update public.dopmi_threads set status='closed',updated_at=now()
      where owner in(owner_id,adopter_id) and status='active';
    select * into plan from private.dopmi_guardian_subscriptions where donor_id=owner for update;
    if found and plan.status='active' and plan.cancellation_requested_at is null then
      update private.dopmi_guardian_requests set status='superseded'
        where subscription_id=plan.stripe_subscription_id and kind='amount' and status='pending';
      insert into private.dopmi_guardian_requests(donor_id,subscription_id,request_key,kind,
        expected_revision,revision,previous_gross_cents)
      values(owner,plan.stripe_subscription_id,request_id,'cancel',plan.management_revision,
        plan.management_revision+1,plan.gross_cents)
      on conflict(donor_id,request_key) do nothing;
      update private.dopmi_guardian_subscriptions set management_revision=management_revision+1,
        cancellation_requested_at=coalesce(cancellation_requested_at,now()) where donor_id=owner;
    end if;
    update private.dopmi_account_deletions set status='procesando',processing_at=coalesce(processing_at,now()),
      attention_code=null,updated_at=now() where owner_id=owner;
    return private.dopmi_account_deletion_view(owner);
  elsif operation='finalize' then
    select * into deletion from private.dopmi_account_deletions where owner_id=owner for update;
    if not found then raise exception 'Solicitud inexistente' using errcode='22023'; end if;
    if deletion.status='completado' then return private.dopmi_account_deletion_view(owner); end if;
    pending_money:=exists(select 1 from private.dopmi_guardian_subscriptions
      where donor_id=owner and status='active')
      or exists(select 1 from public.dopmi_donations where (donor_id=owner or rescuer_id=owner)
        and (payment_status='pending' or transfer_status in ('pending','attention') or refund_status in ('pending','attention')));
    if pending_money then
      update private.dopmi_account_deletions set status='requiere_atencion',
        attention_code='operacion_financiera_pendiente',updated_at=now() where owner_id=owner;
      return private.dopmi_account_deletion_view(owner);
    end if;

    -- Remove private/product state; retain only payment and moderation evidence.
    delete from public.dopmi_favorites where user_id=owner;
    delete from public.dopmi_saved_cases where user_id=owner;
    delete from public.dopmi_saved_rescuers where user_id=owner or rescuer_id=owner;
    delete from public.dopmi_notifications where user_id=owner;
    update public.dopmi_messages set body='[Mensaje retirado por eliminación de cuenta]'
      where sender_id=owner;
    delete from public.dopmi_content_reports where reporter_id=owner;
    delete from public.dopmi_case_updates where owner_id=owner;
    delete from public.dopmi_rescuer_profiles where owner_id=owner;
    delete from public.dopmi_adoptions where owner_id=owner;
    delete from public.dopmi_rescue_records r where r.owner_id=owner
      and not exists(select 1 from public.dopmi_donations d where d.expense_id=r.id);
    delete from private.admin_memberships where user_id=owner;
    update public.profiles set display_name='Cuenta eliminada',phone='',city='',active_mode='donor',
      intent='adopt',account_status='deleted',updated_at=now() where id=owner;
    update private.dopmi_account_deletions set status='completado',completed_at=now(),
      attention_code=null,updated_at=now() where owner_id=owner;
    return private.dopmi_account_deletion_view(owner);
  elsif operation='get' then
    return private.dopmi_account_deletion_view(owner);
  elsif operation='attention' then
    update private.dopmi_account_deletions set status='requiere_atencion',
      attention_code=left(coalesce(nullif(data->>'attention_code',''),'procesamiento_incompleto'),80),
      updated_at=now() where owner_id=owner and status<>'completado';
    return private.dopmi_account_deletion_view(owner);
  end if;
  raise exception 'Operación inválida' using errcode='22023';
end $$;
revoke all on function public.dopmi_account_deletion_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_account_deletion_server(text,jsonb) to service_role;

-- New accounts record current public legal acceptance only when all three
-- values are present. Existing accounts must accept explicitly in the app.
create or replace function private.create_profile() returns trigger
language plpgsql security definer set search_path='' as $$
declare
  meta jsonb:=coalesce(new.raw_user_meta_data,'{}'::jsonb);
  chosen_intent text:=coalesce(meta->>'intent','adopt');
  accepted boolean:=meta->>'terms_version'='terms-2026-09-28'
    and meta->>'privacy_version'='privacy-2026-09-28'
    and meta->>'adult_confirmed'='true';
  legacy_accepted boolean:=meta->>'terms_version'='development-2026-09-13'
    and meta->>'terms_accepted'='true';
begin
  if chosen_intent not in ('adopt','donate','rescue') then chosen_intent:='adopt'; end if;
  insert into public.profiles(id,display_name,phone,intent,active_mode,terms_version,
    terms_accepted_at,privacy_version,privacy_accepted_at,adult_confirmed_at)
  values(new.id,left(coalesce(nullif(btrim(meta->>'display_name'),''),nullif(btrim(meta->>'full_name'),''),'Mi perfil'),80),
    left(coalesce(meta->>'phone',''),24),chosen_intent,
    case when chosen_intent='rescue' then 'rescuer' else 'donor' end,
    case when accepted then 'terms-2026-09-28' when legacy_accepted then 'development-2026-09-13' end,
    case when accepted or legacy_accepted then now() end,
    case when accepted then 'privacy-2026-09-28' end,case when accepted then now() end,
    case when accepted then now() end);
  if accepted then
    insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed)
      values(new.id,'terms-2026-09-28','privacy-2026-09-28',true);
  end if;
  return new;
end $$;

commit;
