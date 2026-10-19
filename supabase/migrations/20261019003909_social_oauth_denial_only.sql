-- Inert by default: no permission is inserted by this migration. Any DEV
-- configuration is a separate, exact, privileged operation approved by owner.
alter table public.social_verification_attempts
 add column purpose text not null default 'verification'
 check(purpose in ('verification','denial_only'));

create table private.social_oauth_denial_grants (
 id uuid primary key default gen_random_uuid(),
 project_ref text not null default 'ohqxranynackjignryep' check(project_ref='ohqxranynackjignryep'),
 owner_id uuid not null references auth.users(id) on delete cascade,
 session_id uuid not null references auth.sessions(id) on delete cascade,
 provider text not null default 'facebook' check(provider='facebook'),
 purpose text not null default 'denial_only' check(purpose='denial_only'),
 max_starts integer not null default 1 check(max_starts=1),
 starts_at timestamptz not null,
 expires_at timestamptz not null,
 consumed_at timestamptz,
 -- Deliberately no FK to attempts: operational retention cannot restore quota.
 consumed_attempt_id uuid unique,
 revoked_at timestamptz,
 unique(owner_id,provider),
 check(expires_at>starts_at and expires_at<=starts_at+interval '15 minutes'),
 check((consumed_at is null)=(consumed_attempt_id is null))
);
alter table private.social_oauth_denial_grants enable row level security;
revoke all on private.social_oauth_denial_grants from public,anon,authenticated,service_role;

create function public.social_verification_denial_available(p_owner uuid,p_session uuid)
returns boolean language sql security definer set search_path='' as $$
 select exists(
  select 1 from private.social_oauth_denial_grants g
  join auth.sessions s on s.id=g.session_id and s.user_id=g.owner_id
  where g.owner_id=p_owner and g.session_id=p_session
  and g.project_ref='ohqxranynackjignryep' and g.provider='facebook' and g.purpose='denial_only'
  and g.revoked_at is null and g.consumed_at is null
  and g.starts_at<=clock_timestamp() and g.expires_at>clock_timestamp()
  and (s.not_after is null or s.not_after>clock_timestamp())
 );
$$;

create function public.social_verification_denial_start(p_owner uuid,p_session uuid,p_provider text,p_hash text)
returns uuid language plpgsql security definer set search_path='' as $$
declare g private.social_oauth_denial_grants; attempt uuid; at_time timestamptz;
begin
 if p_provider is distinct from 'facebook' or p_hash is null or p_hash!~'^[0-9a-f]{64}$' then
  raise exception 'denial_unavailable' using errcode='22023';
 end if;
 -- Same owner lock as ordinary social start, followed by the single grant lock.
 perform 1 from auth.users where id=p_owner for update;
 select * into g from private.social_oauth_denial_grants
 where owner_id=p_owner and session_id=p_session and provider=p_provider for update;
 -- Read the clock after any lock wait. A transaction that began before expiry
 -- must not start an attempt after expiry or recover already consumed quota.
 at_time:=clock_timestamp();
 if not found or g.project_ref<>'ohqxranynackjignryep' or g.purpose<>'denial_only'
 or g.revoked_at is not null or g.consumed_at is not null
 or g.starts_at>at_time or g.expires_at<=at_time or not exists(
  select 1 from auth.sessions where id=p_session and user_id=p_owner
  and (not_after is null or not_after>at_time)
 ) then raise exception 'denial_unavailable' using errcode='22023'; end if;
 insert into public.social_verification_attempts(owner_id,session_id,provider,state_hash,purpose,created_at,expires_at)
 values(p_owner,p_session,p_provider,p_hash,'denial_only',at_time,least(at_time+interval '10 minutes',g.expires_at))
 returning id into attempt;
 update private.social_oauth_denial_grants set consumed_at=at_time,consumed_attempt_id=attempt where id=g.id;
 return attempt;
end;
$$;

-- If the global Edge setting drifts on during the rehearsed window, the
-- ordinary RPC must not turn this exact denial rehearsal into verification.
-- Other actors/providers retain the established ordinary-start contract.
create or replace function public.social_verification_start(p_owner uuid,p_session uuid,p_provider text,p_hash text)
returns uuid language plpgsql security definer set search_path='' as $$
declare attempt uuid;
begin
 perform 1 from auth.users where id=p_owner for update;
 if not exists(select 1 from auth.sessions where id=p_session and user_id=p_owner and (not_after is null or not_after>now())) then raise exception 'invalid_session'; end if;
 if exists(select 1 from private.social_oauth_denial_grants g
  where g.owner_id=p_owner and g.session_id=p_session and g.provider=p_provider
  and g.project_ref='ohqxranynackjignryep' and g.purpose='denial_only'
  and g.revoked_at is null and g.starts_at<=clock_timestamp() and g.expires_at>clock_timestamp()) then
  raise exception 'denial_only_required' using errcode='22023';
 end if;
 if (select count(*) from public.social_verification_attempts where owner_id=p_owner and created_at>now()-interval '10 minutes')>=5 then raise exception 'too_many_attempts';end if;
 update public.social_verification_attempts set status='denied' where owner_id=p_owner and session_id=p_session and provider=p_provider and status in ('pending','processing');
 insert into public.social_verification_attempts(owner_id,session_id,provider,state_hash) values(p_owner,p_session,p_provider,p_hash) returning id into attempt;
 return attempt;
end;
$$;

-- Existing ordinary attempts keep their original session/state behavior.
create or replace function public.social_verification_consume(p_hash text)
returns setof public.social_verification_attempts language sql security definer set search_path='' as $$
 update public.social_verification_attempts a set status='processing'
 where a.state_hash=p_hash and a.status='pending'
 and a.expires_at>case when a.purpose='denial_only' then clock_timestamp() else now() end
 and exists(select 1 from auth.sessions s where s.id=a.session_id and s.user_id=a.owner_id
  and (s.not_after is null or s.not_after>case when a.purpose='denial_only' then clock_timestamp() else now() end))
 and (a.purpose='verification' or exists(
  select 1 from private.social_oauth_denial_grants g where g.consumed_attempt_id=a.id
  and g.owner_id=a.owner_id and g.session_id=a.session_id and g.provider=a.provider
  and g.project_ref='ohqxranynackjignryep' and g.purpose='denial_only'
  and g.consumed_at is not null and g.revoked_at is null
  and g.starts_at<=clock_timestamp() and g.expires_at>clock_timestamp()
 ))
 returning a.*;
$$;

create or replace function public.social_verification_finish(p_attempt uuid,p_subject text,p_label text)
returns void language plpgsql security definer set search_path='' as $$
declare a public.social_verification_attempts;
begin
 select * into a from public.social_verification_attempts where id=p_attempt;
 if not found or a.purpose<>'verification' then raise exception 'invalid_attempt' using errcode='22023';end if;
 -- Preserve removal's existing provider/subject -> attempt lock order.
 perform pg_advisory_xact_lock(hashtextextended(a.provider||':'||p_subject,0));
 select * into a from public.social_verification_attempts where id=p_attempt for update;
 if not found or a.purpose<>'verification' or a.status<>'processing' or a.expires_at<=now() or not exists(
 select 1 from auth.sessions s where s.id=a.session_id and s.user_id=a.owner_id and (s.not_after is null or s.not_after>now())) then
 raise exception 'invalid_attempt' using errcode='22023'; end if;
 if exists(select 1 from public.social_verification_revocations r
 where r.provider=a.provider and r.subject_hash=encode(sha256(convert_to(a.provider||':'||p_subject,'UTF8')),'hex')
 and r.expires_at>clock_timestamp() and a.created_at<=r.revoked_at) then
 raise exception 'revoked_attempt' using errcode='22023';end if;
 insert into public.social_verification_proofs(owner_id,provider,subject,label)
 values(a.owner_id,a.provider,p_subject,p_label)
 on conflict(owner_id,provider) do update set subject=excluded.subject,label=excluded.label,verified_at=now();
 update public.social_verification_attempts set status='verified',label=p_label where id=a.id;
end;
$$;
revoke all on function public.social_verification_denial_available(uuid,uuid),
 public.social_verification_denial_start(uuid,uuid,text,text),
 public.social_verification_start(uuid,uuid,text,text),
 public.social_verification_consume(text),public.social_verification_finish(uuid,text,text)
 from public,anon,authenticated;
grant execute on function public.social_verification_denial_available(uuid,uuid),
 public.social_verification_denial_start(uuid,uuid,text,text),
 public.social_verification_start(uuid,uuid,text,text),
 public.social_verification_consume(text),public.social_verification_finish(uuid,text,text) to service_role;
