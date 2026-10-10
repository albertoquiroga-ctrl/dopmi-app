begin;

-- No plaintext provider tokens. Only the Edge runtime has the encryption key.
create table private.dopmi_apple_credentials (
  owner_id uuid primary key references auth.users(id) on delete restrict,
  subject text not null check (length(subject) between 1 and 255),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  envelope jsonb not null check (
    jsonb_typeof(envelope) = 'object'
    and envelope ?& array['key_id', 'iv', 'ciphertext']
    and length(envelope->>'ciphertext') between 24 and 16384
  ),
  updated_at timestamptz not null default now()
);
alter table private.dopmi_apple_credentials enable row level security;
revoke all on private.dopmi_apple_credentials from public, anon, authenticated;

create function public.dopmi_apple_credential_server(operation text, owner uuid,
  apple_subject text default null, request_hash text default null, envelope jsonb default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  if operation = 'get' then
    select jsonb_build_object('subject', c.subject, 'request_hash', c.request_hash,
      'envelope', c.envelope) into result
      from private.dopmi_apple_credentials c where c.owner_id = owner;
    return result;
  elsif operation in ('require_active', 'save') then
    perform 1 from public.profiles p join auth.identities i on i.user_id = p.id
      where p.id = owner and p.account_status = 'active' and i.provider = 'apple'
      and i.provider_id = apple_subject for update of p;
    if not found then raise exception 'apple_identity_required' using errcode = '42501'; end if;
    if operation = 'save' then
      insert into private.dopmi_apple_credentials(owner_id, subject, request_hash, envelope)
      values (owner, apple_subject, request_hash, envelope)
      on conflict (owner_id) do update set subject = excluded.subject,
        request_hash = excluded.request_hash, envelope = excluded.envelope, updated_at = now();
    end if;
    return jsonb_build_object('ok', true);
  elsif operation = 'remove' then
    delete from private.dopmi_apple_credentials c
      where c.owner_id = owner and c.request_hash = dopmi_apple_credential_server.request_hash;
    if not found and exists(select 1 from private.dopmi_apple_credentials c where c.owner_id = owner) then
      raise exception 'credential_changed' using errcode = '40001';
    end if;
    return jsonb_build_object('ok', true);
  end if;
  raise exception 'invalid_operation' using errcode = '22023';
end;
$$;
revoke all on function public.dopmi_apple_credential_server(text,uuid,text,text,jsonb) from public, anon, authenticated;
grant execute on function public.dopmi_apple_credential_server(text,uuid,text,text,jsonb) to service_role;

commit;
