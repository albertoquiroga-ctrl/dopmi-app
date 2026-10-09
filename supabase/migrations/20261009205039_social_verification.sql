-- Private evidence only: never updates Auth identities, public snapshots or moderation.
create table public.social_verification_attempts (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 session_id uuid not null,
 provider text not null check(provider in ('facebook','instagram')),
 state_hash text not null unique check(length(state_hash)=64),
 status text not null default 'pending' check(status in ('pending','processing','verified','denied','expired','failed')),
 label text,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '10 minutes'
);
create index social_verification_attempts_owner on public.social_verification_attempts(owner_id);
create table public.social_verification_proofs (
 owner_id uuid not null references auth.users(id) on delete cascade,
 provider text not null check(provider in ('facebook','instagram')),
 subject text not null check(length(subject) between 1 and 255),
 label text not null check(length(label) between 1 and 200),
 verified_at timestamptz not null default now(),
 primary key(owner_id,provider), unique(provider,subject)
);
alter table public.social_verification_attempts enable row level security;
alter table public.social_verification_proofs enable row level security;
revoke all on public.social_verification_attempts, public.social_verification_proofs from public,anon,authenticated;
grant select,insert,update,delete on public.social_verification_attempts,public.social_verification_proofs to service_role;

-- Ten-minute hashed tombstones serialize revocation against the first in-flight proof.
create table public.social_verification_revocations(
 provider text not null check(provider in ('facebook','instagram')),
 subject_hash text not null check(length(subject_hash)=64),
 revoked_at timestamptz not null,expires_at timestamptz not null,
 primary key(provider,subject_hash)
);
alter table public.social_verification_revocations enable row level security;
revoke all on public.social_verification_revocations from public,anon,authenticated,service_role;

create function public.social_verification_consume(p_hash text)
returns setof public.social_verification_attempts language sql security definer set search_path='' as $$
 update public.social_verification_attempts a set status='processing'
 where a.state_hash=p_hash and a.status='pending' and a.expires_at>now()
 and exists(select 1 from auth.sessions s where s.id=a.session_id and s.user_id=a.owner_id and (s.not_after is null or s.not_after>now()))
 returning a.*;
$$;
create function public.social_verification_finish(p_attempt uuid,p_subject text,p_label text)
returns void language plpgsql security definer set search_path='' as $$
declare a public.social_verification_attempts;
begin
 select * into a from public.social_verification_attempts where id=p_attempt;
 if not found then raise exception 'invalid_attempt' using errcode='22023';end if;
 -- Acquire provider/subject lock before attempt locks, matching removal's lock order.
 perform pg_advisory_xact_lock(hashtextextended(a.provider||':'||p_subject,0));
 select * into a from public.social_verification_attempts where id=p_attempt for update;
 if not found or a.status<>'processing' or a.expires_at<=now() or not exists(
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
revoke all on function public.social_verification_consume(text),public.social_verification_finish(uuid,text,text) from public,anon,authenticated;
grant execute on function public.social_verification_consume(text),public.social_verification_finish(uuid,text,text) to service_role;

create function public.social_verification_start(p_owner uuid,p_session uuid,p_provider text,p_hash text)
returns uuid language plpgsql security definer set search_path='' as $$
declare attempt uuid;
begin
 perform 1 from auth.users where id=p_owner for update;
 if not exists(select 1 from auth.sessions where id=p_session and user_id=p_owner and (not_after is null or not_after>now())) then raise exception 'invalid_session'; end if;
 if (select count(*) from public.social_verification_attempts where owner_id=p_owner and created_at>now()-interval '10 minutes')>=5 then raise exception 'too_many_attempts';end if;
 update public.social_verification_attempts set status='denied' where owner_id=p_owner and session_id=p_session and provider=p_provider and status in ('pending','processing');
 insert into public.social_verification_attempts(owner_id,session_id,provider,state_hash) values(p_owner,p_session,p_provider,p_hash) returning id into attempt;
 return attempt;
end;
$$;
create function public.social_verification_disconnect(p_owner uuid,p_provider text)
returns void language plpgsql security definer set search_path='' as $$
begin
 -- Lock attempts before proofs, matching finish, so callback cannot restore removed proof.
 perform 1 from public.social_verification_attempts where owner_id=p_owner and provider=p_provider for update;
 update public.social_verification_attempts set status='denied' where owner_id=p_owner and provider=p_provider and status in ('pending','processing');
 update public.social_verification_attempts set status='denied',label=null where owner_id=p_owner and provider=p_provider;
 delete from public.social_verification_proofs where owner_id=p_owner and provider=p_provider;
end;
$$;
revoke all on function public.social_verification_start(uuid,uuid,text,text),public.social_verification_disconnect(uuid,text) from public,anon,authenticated;
grant execute on function public.social_verification_start(uuid,uuid,text,text),public.social_verification_disconnect(uuid,text) to service_role;

create table public.social_verification_deletions(id uuid primary key default gen_random_uuid(),provider text not null check(provider in ('facebook','instagram')),operation text not null check(operation in ('delete','deauthorize')),request_hash text not null check(length(request_hash)=64),created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '7 days',unique(provider,operation,request_hash));
alter table public.social_verification_deletions enable row level security;
revoke all on public.social_verification_deletions from public,anon,authenticated;
grant select on public.social_verification_deletions to service_role;
create function public.social_verification_provider_remove(p_provider text,p_subject text,p_deletion boolean,p_request_hash text)
returns uuid language plpgsql security definer set search_path='' as $$
declare owner uuid; receipt uuid; op text; hashed text; removed_at timestamptz;
begin
 if p_provider not in ('facebook','instagram') or p_subject !~ '^[0-9]{1,255}$' then raise exception 'invalid_provider_subject';end if;
 op:=case when p_deletion then 'delete' else 'deauthorize' end;
 -- Reserve replay receipt before mutations, including deauthorization. A replay
 -- must not remove a new proof created after the original request completed.
 insert into public.social_verification_deletions(provider,operation,request_hash)
 values(p_provider,op,p_request_hash) on conflict(provider,operation,request_hash) do nothing returning id into receipt;
 if receipt is null then
 select id into receipt from public.social_verification_deletions where provider=p_provider and operation=op and request_hash=p_request_hash;
 return receipt;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_provider||':'||p_subject,0));
 removed_at:=clock_timestamp();
 hashed:=encode(sha256(convert_to(p_provider||':'||p_subject,'UTF8')),'hex');
 delete from public.social_verification_revocations where expires_at<=removed_at;
 insert into public.social_verification_revocations(provider,subject_hash,revoked_at,expires_at)
 values(p_provider,hashed,removed_at,removed_at+interval '10 minutes')
 on conflict(provider,subject_hash) do update set revoked_at=excluded.revoked_at,expires_at=excluded.expires_at;
 select owner_id into owner from public.social_verification_proofs where provider=p_provider and subject=p_subject;
 if owner is not null then
  perform public.social_verification_disconnect(owner,p_provider);
  delete from public.social_verification_attempts where owner_id=owner and provider=p_provider;
 end if;
 return receipt;
end;
$$;
revoke all on function public.social_verification_provider_remove(text,text,boolean,text) from public,anon,authenticated;
grant execute on function public.social_verification_provider_remove(text,text,boolean,text) to service_role;
