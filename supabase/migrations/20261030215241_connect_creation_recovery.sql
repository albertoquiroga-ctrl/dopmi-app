begin;

-- Inert until an operator explicitly reconciles a known non-creation and
-- authorizes one actor-bound recovery. NULL retains every legacy key.
alter table private.dopmi_connect_accounts
  add column create_idempotency_key text unique,
  add constraint dopmi_connect_recovery_key_shape check (
    create_idempotency_key is null or create_idempotency_key ~
      ('^dopmi-account-' || owner_id::text || '-retry-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
  );

create table private.dopmi_connect_creation_recoveries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references private.dopmi_connect_accounts(owner_id) on delete restrict,
  previous_key text not null,
  previous_started_at timestamptz not null,
  retry_key text not null unique,
  retry_started_at timestamptz not null,
  failed_request_id text not null check (failed_request_id ~ '^req_[A-Za-z0-9]+$'),
  failure_code text not null check (failure_code = 'platform_profile_incomplete'),
  non_creation_verified_at timestamptz not null,
  evidence_sha256 text not null check (evidence_sha256 ~ '^[0-9a-f]{64}$'),
  authorization_reference text not null check (length(authorization_reference) between 16 and 256),
  created_at timestamptz not null default now(),
  unique(owner_id, previous_key),
  check (retry_key ~ ('^dopmi-account-' || owner_id::text || '-retry-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')),
  check (retry_key <> previous_key),
  check (non_creation_verified_at <= retry_started_at and
    non_creation_verified_at > retry_started_at - interval '5 minutes')
);
alter table private.dopmi_connect_creation_recoveries enable row level security;
revoke all on private.dopmi_connect_creation_recoveries from public, anon, authenticated, service_role;

create function private.dopmi_guard_connect_creation_recovery() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.create_idempotency_key is not null then
      raise exception 'Inicia Connect con su clave original' using errcode = '22023';
    end if;
    return new;
  end if;
  if new.create_idempotency_key is not distinct from old.create_idempotency_key then
    if old.create_started_at is not null and new.create_started_at is distinct from old.create_started_at then
      raise exception 'No reinicies un intento Connect sin recuperación auditada' using errcode = '22023';
    end if;
    return new;
  end if;
  -- Operator must acquire dopmi_rescue_lock before row lock, like connect_begin.
  -- No app/Edge RPC can rotate keys or authorize a recovery.
  if old.account_id is not null or new.account_id is not null or
      old.transfers_enabled or old.payouts_enabled or old.details_submitted or
      (to_jsonb(new) - 'create_idempotency_key' - 'create_started_at') is distinct from
        (to_jsonb(old) - 'create_idempotency_key' - 'create_started_at') or
      not exists (
        select 1 from private.dopmi_connect_creation_recoveries h
        where h.owner_id = old.owner_id
          and h.previous_key = coalesce(old.create_idempotency_key, 'dopmi-account-' || old.owner_id::text)
          and h.previous_started_at = old.create_started_at
          and h.retry_key = new.create_idempotency_key
          and h.retry_started_at = new.create_started_at
      ) then
    raise exception 'Recuperación Connect no autorizada o sin conciliar' using errcode = '22023';
  end if;
  return new;
end $$;
revoke all on function private.dopmi_guard_connect_creation_recovery() from public, anon, authenticated, service_role;
create trigger dopmi_guard_connect_creation_recovery before insert or update of create_idempotency_key, create_started_at
  on private.dopmi_connect_accounts for each row execute function private.dopmi_guard_connect_creation_recovery();

create function private.dopmi_connect_recovery_history_immutable() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  raise exception 'Conserva el historial de recuperación Connect' using errcode = '22023';
end $$;
revoke all on function private.dopmi_connect_recovery_history_immutable() from public, anon, authenticated, service_role;
create trigger dopmi_connect_recovery_history_immutable before update or delete
  on private.dopmi_connect_creation_recoveries for each row execute function private.dopmi_connect_recovery_history_immutable();

commit;
