begin;

-- Intent is persisted before exchanging a one-use code. A timeout is not proof
-- that no provider grant was issued, so unresolved intent never expires itself.
alter table private.dopmi_apple_credentials
  alter column request_hash drop not null,
  alter column envelope drop not null,
  add column pending_request_hash text check (pending_request_hash ~ '^[0-9a-f]{64}$'),
  add constraint dopmi_apple_credential_or_intent check (
    (request_hash is not null and envelope is not null)
    or (request_hash is null and envelope is null and pending_request_hash is not null)
  );

-- The deletion job is the durable evidence for this exact owner, request and
-- Apple grant. A missing credential alone never proves provider revocation.
alter table private.dopmi_account_deletions
  add column apple_revoked_subject_hash text,
  add column apple_revoked_request_hash text,
  add column apple_revoked_request_key uuid,
  add column apple_revoked_at timestamptz,
  add constraint dopmi_account_deletion_apple_proof check (
    (apple_revoked_subject_hash is null and apple_revoked_request_hash is null
      and apple_revoked_request_key is null and apple_revoked_at is null)
    or (apple_revoked_subject_hash is not null and apple_revoked_request_hash is not null
      and apple_revoked_subject_hash ~ '^[0-9a-f]{64}$'
      and apple_revoked_request_hash ~ '^[0-9a-f]{64}$'
      and apple_revoked_request_key is not null and apple_revoked_at is not null)
  );

create function private.dopmi_apple_deletion_ready(owner uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
  return not exists(select 1 from private.dopmi_apple_credentials c where c.owner_id=owner)
    and (not exists(select 1 from auth.identities i where i.user_id=owner and i.provider='apple')
      or exists(select 1 from private.dopmi_account_deletions d
        where d.owner_id=owner and d.apple_revoked_at is not null
          and d.apple_revoked_request_key=d.request_key
          and not exists(select 1 from auth.identities i where i.user_id=owner
            and i.provider='apple' and encode(sha256(convert_to(i.provider_id,'UTF8')),'hex')
              is distinct from d.apple_revoked_subject_hash)));
end;
$$;
revoke all on function private.dopmi_apple_deletion_ready(uuid) from public,anon,authenticated,service_role;

create or replace function public.dopmi_apple_credential_server(operation text, owner uuid,
  apple_subject text default null, request_hash text default null, envelope jsonb default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  result jsonb;
  removed private.dopmi_apple_credentials;
  current_credential private.dopmi_apple_credentials;
begin
  -- The user row also serializes against DELETE Auth; every mutation then locks
  -- the profile before the job. A save can never slip in after finalization.
  perform 1 from auth.users u where u.id=owner for update;
  perform 1 from public.profiles p where p.id=owner for update;
  if operation='get' then
    select jsonb_build_object('subject',c.subject,'request_hash',c.request_hash,'envelope',c.envelope,
      'pending_request_hash',c.pending_request_hash)
      into result from private.dopmi_apple_credentials c where c.owner_id=owner;
    return result;
  elsif operation in ('require_active','save') then
    perform 1 from public.profiles p join auth.identities i on i.user_id=p.id
      where p.id=owner and (p.account_status in ('active','deletion_requested')
        or (p.account_status='deleted' and exists(select 1 from private.dopmi_account_deletions d
          where d.owner_id=owner and d.status<>'completado')))
        and i.provider='apple' and i.provider_id=apple_subject
        and not exists(select 1 from private.dopmi_account_deletions d
          where d.owner_id=owner and d.status='completado');
    if not found then raise exception 'apple_identity_required' using errcode='42501'; end if;
    if request_hash is null or request_hash !~ '^[0-9a-f]{64}$' then
      raise exception 'invalid_request' using errcode='22023';
    end if;
    select * into current_credential from private.dopmi_apple_credentials c where c.owner_id=owner;
    if operation='require_active' then
      if current_credential.pending_request_hash is not null then
        if current_credential.pending_request_hash=request_hash then
          return jsonb_build_object('pending',true);
        end if;
        raise exception 'apple_registration_pending' using errcode='55000';
      end if;
      if current_credential.request_hash=request_hash and current_credential.subject=apple_subject then
        return jsonb_build_object('registered',true);
      end if;
      insert into private.dopmi_apple_credentials(owner_id,subject,pending_request_hash)
        values(owner,apple_subject,request_hash)
        on conflict(owner_id) do update set pending_request_hash=excluded.pending_request_hash,updated_at=now();
      update private.dopmi_account_deletions set apple_revoked_subject_hash=null,
        apple_revoked_request_hash=null,apple_revoked_request_key=null,apple_revoked_at=null
        where owner_id=owner;
      return jsonb_build_object('started',true);
    else
      if current_credential.pending_request_hash is distinct from request_hash then
        raise exception 'apple_registration_pending' using errcode='55000';
      end if;
      insert into private.dopmi_apple_credentials(owner_id,subject,request_hash,envelope)
        values(owner,apple_subject,request_hash,envelope)
        on conflict(owner_id) do update set subject=excluded.subject,
          request_hash=excluded.request_hash,envelope=excluded.envelope,pending_request_hash=null,updated_at=now();
      update private.dopmi_account_deletions set apple_revoked_subject_hash=null,
        apple_revoked_request_hash=null,apple_revoked_request_key=null,apple_revoked_at=null
        where owner_id=owner;
    end if;
    return jsonb_build_object('ok',true);
  elsif operation='cancel_registration' then
    -- Only call after a definitive no-grant response or confirmed provider revoke.
    -- Clear exactly this intent; a different attempt can never be overwritten.
    select * into current_credential from private.dopmi_apple_credentials c where c.owner_id=owner;
    if current_credential.pending_request_hash is distinct from request_hash then
      if current_credential.pending_request_hash is not null then
        raise exception 'credential_changed' using errcode='40001';
      end if;
    elsif current_credential.envelope is null then
      delete from private.dopmi_apple_credentials c where c.owner_id=owner;
    else
      update private.dopmi_apple_credentials c set pending_request_hash=null where c.owner_id=owner;
    end if;
    return jsonb_build_object('ok',true);
  elsif operation='remove' then
    if exists(select 1 from private.dopmi_apple_credentials c where c.owner_id=owner and c.pending_request_hash is not null) then
      raise exception 'apple_registration_pending' using errcode='55000';
    end if;
    delete from private.dopmi_apple_credentials c
      where c.owner_id=owner and c.request_hash=dopmi_apple_credential_server.request_hash
      returning c.* into removed;
    if found then
      -- Only the server calls remove, after provider revoke succeeded. Comparing
      -- the grant hash protects a concurrently replaced credential and proof.
      update private.dopmi_account_deletions d set apple_revoked_subject_hash=encode(sha256(convert_to(removed.subject,'UTF8')),'hex'),
        apple_revoked_request_hash=removed.request_hash,apple_revoked_request_key=d.request_key,
        apple_revoked_at=clock_timestamp() where d.owner_id=owner;
    elsif exists(select 1 from private.dopmi_apple_credentials c where c.owner_id=owner) then
      raise exception 'credential_changed' using errcode='40001';
    end if;
    return jsonb_build_object('ok',true);
  end if;
  raise exception 'invalid_operation' using errcode='22023';
end $$;
revoke all on function public.dopmi_apple_credential_server(text,uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_apple_credential_server(text,uuid,text,text,jsonb) to service_role;

-- Add the guard to the current function without rewriting its existing content
-- and financial retention rules. Fail migration if those reviewed seams moved.
do $patch$
declare
  definition text:=pg_get_functiondef('public.dopmi_account_deletion_server(text,jsonb)'::regprocedure);
  anchor text;
  replacement text;
begin
  anchor:=$old$  if operation='request' then$old$;
  replacement:=$new$  -- Lock order shared with credential save/remove and the Auth delete trigger.
  perform 1 from auth.users u where u.id=owner for update;
  perform 1 from public.profiles p where p.id=owner for update;
  if operation='auth_cleanup' then
    if not private.dopmi_apple_deletion_ready(owner) then
      raise exception 'apple_revocation_required' using errcode='55000';
    end if;
    if exists(select 1 from public.profiles p where p.id=owner and p.account_status<>'deleted') then
      raise exception 'deletion_not_completed' using errcode='55000';
    end if;
    return private.dopmi_account_deletion_view(owner);
  end if;
  if operation='request' then
    if exists(select 1 from private.dopmi_apple_credentials c where c.owner_id=owner and c.pending_request_hash is not null) then
      raise exception 'apple_registration_pending' using errcode='55000';
    end if;
    if exists(select 1 from auth.identities i where i.user_id=owner and i.provider='apple')
      and not exists(select 1 from private.dopmi_apple_credentials c where c.owner_id=owner)
      and not private.dopmi_apple_deletion_ready(owner) then
      raise exception 'apple_reauthentication_required' using errcode='55000';
    end if;$new$;
  if position(anchor in definition)=0 then raise exception 'Review account deletion request guard seam'; end if;
  definition:=replace(definition,anchor,replacement);
  anchor:=$old$    insert into private.dopmi_account_deletions(owner_id,request_key)
      values(owner,request_id) on conflict(owner_id) do nothing;
    select * into deletion from private.dopmi_account_deletions where owner_id=owner for update;
    if deletion.request_key<>request_id and deletion.status<>'completado' then
      raise exception 'La solicitud ya existe' using errcode='22023';
    end if;
    if deletion.status='completado' then return private.dopmi_account_deletion_view(owner); end if;$old$;
  replacement:=$new$    -- The owner has one canonical deletion job. A fresh button press may
    -- supply another valid key; resume that owner's job without replacing its
    -- key/proof or replaying withdrawal and financial cancellation side effects.
    select * into deletion from private.dopmi_account_deletions where owner_id=owner for update;
    if found then return private.dopmi_account_deletion_view(owner); end if;
    insert into private.dopmi_account_deletions(owner_id,request_key)
      values(owner,request_id);
    select * into deletion from private.dopmi_account_deletions where owner_id=owner for update;$new$;
  if position(anchor in definition)=0 then raise exception 'Review account deletion canonical resume seam'; end if;
  definition:=replace(definition,anchor,replacement);
  anchor:=$old$  elsif operation='finalize' then$old$;
  replacement:=$new$  elsif operation='finalize' then
    if not private.dopmi_apple_deletion_ready(owner) then
      update private.dopmi_account_deletions set status='requiere_atencion',
        attention_code='revocacion_apple_pendiente',updated_at=now()
        where owner_id=owner and status<>'completado';
      if found then return private.dopmi_account_deletion_view(owner); end if;
      raise exception 'apple_revocation_required' using errcode='55000';
    end if;$new$;
  if position(anchor in definition)=0 then raise exception 'Review account deletion finalize guard seam'; end if;
  execute replace(definition,anchor,replacement);
end $patch$;

-- Defense for legacy completed jobs and direct Admin Auth deletion, which does
-- not pass through the Edge function or the public finalization RPC.
create function private.dopmi_guard_apple_auth_deletion() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.profiles p where p.id=old.id for update;
  if not private.dopmi_apple_deletion_ready(old.id) then
    raise exception 'apple_revocation_required' using errcode='55000';
  end if;
  return old;
end $$;
revoke all on function private.dopmi_guard_apple_auth_deletion() from public,anon,authenticated,service_role;
create trigger dopmi_guard_apple_auth_deletion before delete on auth.users
  for each row execute function private.dopmi_guard_apple_auth_deletion();

commit;
