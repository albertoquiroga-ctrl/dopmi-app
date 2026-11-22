begin;

create table private.dopmi_meta_ads_gate (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false
);
insert into private.dopmi_meta_ads_gate default values;

create table private.dopmi_meta_ads_preferences (
  actor_id uuid primary key references auth.users(id) on delete cascade,
  notice_version text not null default 'meta-ads-2026-11-22'
    check(notice_version='meta-ads-2026-11-22'),
  granted_at timestamptz not null default clock_timestamp()
);

create table private.dopmi_meta_ads_outbox (
  event_id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id) on delete cascade,
  event_name text not null check(event_name in ('first_adoption_message','first_adoption_submission')),
  event_at timestamptz not null default clock_timestamp(),
  advertising_id uuid,
  os_version text,
  app_version text,
  app_build integer,
  available_at timestamptz not null default clock_timestamp(),
  lease_token uuid,
  lease_until timestamptz,
  attempts integer not null default 0 check(attempts between 0 and 5),
  delivered_at timestamptz,
  unique(actor_id,event_name),
  check(
    (advertising_id is not null and os_version is not null and app_version is not null and app_build is not null)
    or (advertising_id is null and os_version is null and app_version is null and app_build is null)
  ),
  check((lease_token is null)=(lease_until is null)),
  check(advertising_id is not null or lease_token is null)
);
create index dopmi_meta_ads_outbox_due on private.dopmi_meta_ads_outbox(available_at,event_id)
  where advertising_id is not null;
create index dopmi_meta_ads_outbox_expiry on private.dopmi_meta_ads_outbox(event_at)
  where advertising_id is not null;

alter table private.dopmi_meta_ads_gate enable row level security;
alter table private.dopmi_meta_ads_preferences enable row level security;
alter table private.dopmi_meta_ads_outbox enable row level security;
revoke all on private.dopmi_meta_ads_gate,private.dopmi_meta_ads_preferences,private.dopmi_meta_ads_outbox
  from public,anon,authenticated,service_role;

create function public.dopmi_meta_ads_preference() returns boolean
language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from private.dopmi_meta_ads_gate g
    join private.dopmi_meta_ads_preferences p on p.actor_id=(select auth.uid())
    join public.profiles profile on profile.id=p.actor_id and profile.account_status='active'
    join auth.users u on u.id=p.actor_id and u.deleted_at is null
    where g.enabled
  );
$$;

create function public.dopmi_set_meta_ads_preference(enabled boolean) returns boolean
language plpgsql security definer set search_path='' as $$
declare
  actor uuid := auth.uid();
  gate_enabled boolean;
begin
  if actor is null then
    raise exception 'Inicia sesión para controlar la medición publicitaria' using errcode='42501';
  end if;
  if enabled is null then
    raise exception 'Confirma tu preferencia de medición publicitaria' using errcode='22023';
  end if;
  select g.enabled into gate_enabled from private.dopmi_meta_ads_gate g where g.singleton for share;
  if enabled then
    if gate_enabled is distinct from true then return false; end if;
    perform private.dopmi_require_actor();
    if not exists(select 1 from auth.users u where u.id=actor and u.deleted_at is null) then return false; end if;
    insert into private.dopmi_meta_ads_preferences(actor_id,notice_version)
      values(actor,'meta-ads-2026-11-22') on conflict do nothing;
    return true;
  end if;
  delete from private.dopmi_meta_ads_preferences p where p.actor_id=actor;
  update private.dopmi_meta_ads_outbox o
    set advertising_id=null,os_version=null,app_version=null,app_build=null,lease_token=null,lease_until=null
    where o.actor_id=actor and o.advertising_id is not null;
  return false;
end;
$$;

-- Closing the gate immediately disables grants and cancels pending or claimed
-- events. Reopening needs a fresh opt-in. Empty outbox rows retain deduplication.
create function public.dopmi_set_meta_ads_gate(enabled boolean) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  if enabled is null then
    raise exception 'Especifica el estado de la medición publicitaria' using errcode='22023';
  end if;
  update private.dopmi_meta_ads_gate g set enabled=$1 where g.singleton;
  if not enabled then
    delete from private.dopmi_meta_ads_preferences;
    update private.dopmi_meta_ads_outbox o
      set advertising_id=null,os_version=null,app_version=null,app_build=null,lease_token=null,lease_until=null
      where o.advertising_id is not null;
  end if;
  return enabled;
end;
$$;

create function private.dopmi_enqueue_meta_ads_event(actor uuid,event_name text,occurred_at timestamptz,context jsonb) returns void
language plpgsql set search_path='' as $$
declare
  gate_enabled boolean;
  ad_id text := context->>'advertising_id';
  os_version text := context->>'os_version';
  app_version text := context->>'app_version';
  app_build text := context->>'app_build';
begin
  if jsonb_typeof(context) is distinct from 'object' then return; end if;
  if not (context ?& array['advertising_id','os_version','app_version','app_build'])
    or context - array['advertising_id','os_version','app_version','app_build'] <> '{}'::jsonb
    or jsonb_typeof(context->'advertising_id') <> 'string'
    or jsonb_typeof(context->'os_version') <> 'string'
    or jsonb_typeof(context->'app_version') <> 'string'
    or jsonb_typeof(context->'app_build') not in ('string','number')
    or ad_id is null
    or ad_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    or ad_id='00000000-0000-0000-0000-000000000000'
    or os_version is null or os_version !~ '^[0-9][0-9A-Za-z._+-]{0,23}$'
    or app_version is null or char_length(app_version)>24
    or app_version !~ '^[0-9]+(\.[0-9]+){1,3}([+-][0-9A-Za-z.-]+)?$'
    or app_build is null or app_build !~ '^[1-9][0-9]{0,9}$'
  then return; end if;
  if app_build::bigint>2100000000 then return; end if;

  select g.enabled into gate_enabled from private.dopmi_meta_ads_gate g where g.singleton for share;
  if gate_enabled is distinct from true then return; end if;
  perform 1 from private.dopmi_meta_ads_preferences p
    join public.profiles profile on profile.id=p.actor_id and profile.account_status='active'
    join auth.users u on u.id=p.actor_id and u.deleted_at is null
    where p.actor_id=actor and p.granted_at<=occurred_at for share of p;
  if not found then return; end if;

  insert into private.dopmi_meta_ads_outbox(actor_id,event_name,event_at,advertising_id,os_version,app_version,app_build)
  values(actor,event_name,occurred_at,ad_id::uuid,os_version,app_version,app_build::integer)
  on conflict on constraint dopmi_meta_ads_outbox_actor_id_event_name_key do nothing;
exception when others then
  -- A telemetry write failure must not roll back the enclosing product action.
  raise warning 'Dopmi Meta event enqueue failed (SQLSTATE %)',sqlstate;
end;
$$;

create function public.dopmi_send_message_meta_v2(
  thread_id uuid,message_id uuid,message_body text,attachment_path text,advertising_context jsonb
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid;
  adopter uuid;
  already_stored boolean;
  result jsonb;
  occurred_at timestamptz;
begin
  if advertising_context is null then
    return public.dopmi_send_message_v3(thread_id,message_id,message_body,attachment_path);
  end if;
  actor := private.dopmi_require_actor();
  -- Use the same thread lock as message V3 to distinguish a new send
  -- from an idempotent retry, including sends made on a previous app version.
  select t.adopter_id into adopter from public.dopmi_threads t
    where t.id=thread_id and actor in (t.adopter_id,t.owner_id) for update;
  select exists(select 1 from public.dopmi_messages m where m.id=message_id) into already_stored;
  occurred_at := clock_timestamp();
  result := public.dopmi_send_message_v3(thread_id,message_id,message_body,attachment_path);
  if adopter=actor and not already_stored then
    perform private.dopmi_enqueue_meta_ads_event(actor,'first_adoption_message',occurred_at,advertising_context);
  end if;
  return result;
end;
$$;

create function private.dopmi_meta_ads_initial_adoption(a public.dopmi_adoptions) returns boolean
language plpgsql stable set search_path='' as $$
begin
  if a.id is null or a.status<>'draft' or a.submitted_at is not null or a.published_at is not null then
    return false;
  end if;
  -- Older deployments have the canonical transition but no private revisions.
  if to_regclass('private.dopmi_adoption_edits') is not null then
    return not exists(select 1 from private.dopmi_adoption_edits e where e.id=a.id);
  end if;
  return true;
end;
$$;

-- The client checks eligibility before reading the device advertising ID.
-- The mutation wrappers still enforce eligibility and consent transactionally.
create function public.dopmi_meta_ads_action_eligible(p_event_kind text,p_target_id uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare
  actor uuid;
  draft public.dopmi_adoptions;
begin
  if p_target_id is null or p_event_kind is null
    or p_event_kind not in ('first_adoption_message','first_adoption_submission')
    or not public.dopmi_meta_ads_preference() then
    return false;
  end if;

  actor := private.dopmi_require_actor();
  if exists(select 1 from private.dopmi_meta_ads_outbox o where o.actor_id=actor and o.event_name=p_event_kind) then
    return false;
  end if;

  if p_event_kind='first_adoption_message' then
    return exists(
      select 1 from public.dopmi_threads t
      join public.profiles recipient on recipient.id=t.owner_id and recipient.account_status='active'
      where t.id=p_target_id and t.adopter_id=actor and t.status='active'
    );
  end if;

  select a.* into draft from public.dopmi_adoptions a where a.id=p_target_id and a.owner_id=actor;
  if not found or not private.dopmi_meta_ads_initial_adoption(draft) then return false; end if;

  if to_regprocedure('private.dopmi_adoption_validate(public.dopmi_adoptions)') is not null then
    perform private.dopmi_adoption_validate(draft);
    return true;
  end if;
  -- Legacy canonical transitions inline the submission checks.
  return draft.species is not null and draft.sex is not null and draft.size is not null
    and char_length(draft.pet_name)>0 and char_length(draft.city)>0 and char_length(draft.region)>0
    and char_length(draft.story)>=20 and char_length(draft.publisher_name)>0 and cardinality(draft.photos)>0
    and not exists(
      select 1 from unnest(draft.photos) photo where not exists(
        select 1 from storage.objects o where o.bucket_id='dopmi-adoption-photos' and o.name=photo
      )
    );
exception when insufficient_privilege or invalid_parameter_value then
  return false;
end;
$$;

create function public.dopmi_transition_adoption_meta(
  post_id uuid,expected_version integer,action text,advertising_context jsonb
) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  actor uuid;
  initial_draft boolean;
  draft public.dopmi_adoptions;
  result jsonb;
  occurred_at timestamptz;
begin
  if action is distinct from 'submit' or advertising_context is null then
    return public.dopmi_transition_adoption(post_id,expected_version,action);
  end if;
  actor := private.dopmi_require_actor();
  select a.* into draft from public.dopmi_adoptions a where a.id=post_id and a.owner_id=actor for update;
  initial_draft := found and private.dopmi_meta_ads_initial_adoption(draft);
  occurred_at := clock_timestamp();
  result := public.dopmi_transition_adoption(post_id,expected_version,action);
  if initial_draft and result->>'status'='submitted' then
    perform private.dopmi_enqueue_meta_ads_event(actor,'first_adoption_submission',occurred_at,advertising_context);
  end if;
  return result;
end;
$$;

-- Safe to schedule independently of HTTP delivery. Only expired payloads,
-- exhausted leases, closed-gate work and ineligible accounts are purged.
create function public.dopmi_purge_expired_meta_ads_events() returns bigint
language plpgsql security definer set search_path='' as $$
declare
  gate_enabled boolean;
  checked_at timestamptz;
  cleared bigint;
begin
  select g.enabled into gate_enabled from private.dopmi_meta_ads_gate g where g.singleton for share;
  checked_at := clock_timestamp();
  update private.dopmi_meta_ads_outbox o
    set advertising_id=null,os_version=null,app_version=null,app_build=null,lease_token=null,lease_until=null
    where o.advertising_id is not null
    and (
      gate_enabled is distinct from true
      or o.event_at<=checked_at-interval '24 hours'
      or (o.attempts>=5 and (o.lease_until is null or o.lease_until<=checked_at))
      or not exists(
        select 1 from private.dopmi_meta_ads_preferences p
        join public.profiles profile on profile.id=p.actor_id and profile.account_status='active'
        join auth.users u on u.id=p.actor_id and u.deleted_at is null
        where p.actor_id=o.actor_id
      )
    );
  get diagnostics cleared = row_count;
  return cleared;
end;
$$;

create function public.dopmi_claim_meta_ads_events(batch_size integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  gate_enabled boolean;
  claim_at timestamptz := clock_timestamp();
  result jsonb;
begin
  if batch_size is null or batch_size not between 1 and 50 then
    raise exception 'El lote debe contener de 1 a 50 eventos' using errcode='22023';
  end if;
  select g.enabled into gate_enabled from private.dopmi_meta_ads_gate g where g.singleton for share;
  if gate_enabled is distinct from true then return '[]'::jsonb; end if;

  perform public.dopmi_purge_expired_meta_ads_events();

  with due as (
    select o.event_id from private.dopmi_meta_ads_outbox o
    join private.dopmi_meta_ads_preferences p on p.actor_id=o.actor_id
    join public.profiles profile on profile.id=o.actor_id and profile.account_status='active'
    join auth.users u on u.id=o.actor_id and u.deleted_at is null
    where o.advertising_id is not null and o.available_at<=claim_at
      and o.event_at>claim_at-interval '24 hours' and o.attempts<5
      and (o.lease_until is null or o.lease_until<=claim_at)
    order by o.available_at,o.event_id for update of o skip locked limit batch_size
  ), claimed as (
    update private.dopmi_meta_ads_outbox o
      set lease_token=gen_random_uuid(),lease_until=claim_at+interval '5 minutes',attempts=o.attempts+1
    from due where o.event_id=due.event_id
    returning o.event_id,o.lease_token,o.event_name,o.event_at,o.advertising_id,o.os_version,o.app_version,o.app_build
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'event_id',c.event_id,'lease_token',c.lease_token,
    'event_name',case c.event_name when 'first_adoption_message' then 'Contact' else 'SubmitApplication' end,
    'event_time',floor(extract(epoch from c.event_at))::bigint,'advertising_id',c.advertising_id,
    'os_version',c.os_version,'app_version',c.app_version,'app_build',c.app_build
  ) order by c.event_at,c.event_id),'[]'::jsonb) into result from claimed c;
  return result;
end;
$$;

create function public.dopmi_meta_ads_event_allowed(event_id uuid,lease_token uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from private.dopmi_meta_ads_outbox o
    join private.dopmi_meta_ads_preferences p on p.actor_id=o.actor_id
    join public.profiles profile on profile.id=o.actor_id and profile.account_status='active'
    join auth.users u on u.id=o.actor_id and u.deleted_at is null
    join private.dopmi_meta_ads_gate g on g.enabled
    where o.event_id=$1 and o.lease_token=$2 and o.advertising_id is not null
      and o.lease_until>statement_timestamp() and o.event_at>statement_timestamp()-interval '24 hours'
  );
$$;

create function public.dopmi_complete_meta_ads_event(event_id uuid,delivered boolean,lease_token uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare
  completed_at timestamptz := clock_timestamp();
begin
  if delivered is null then return false; end if;
  if not public.dopmi_meta_ads_event_allowed(event_id,lease_token) then return false; end if;
  update private.dopmi_meta_ads_outbox o
    set delivered_at=case when delivered then completed_at else null end,
      advertising_id=case when delivered or o.attempts>=5 then null else o.advertising_id end,
      os_version=case when delivered or o.attempts>=5 then null else o.os_version end,
      app_version=case when delivered or o.attempts>=5 then null else o.app_version end,
      app_build=case when delivered or o.attempts>=5 then null else o.app_build end,
      available_at=completed_at+make_interval(secs=>60*(1<<(o.attempts-1))),
      lease_token=null,
      lease_until=null
    where o.event_id=$1 and o.lease_token=$3 and o.lease_until>completed_at
      and o.event_at>completed_at-interval '24 hours' and o.advertising_id is not null;
  return found;
end;
$$;

revoke all on function private.dopmi_enqueue_meta_ads_event(uuid,text,timestamptz,jsonb),
  private.dopmi_meta_ads_initial_adoption(public.dopmi_adoptions)
  from public,anon,authenticated,service_role;
revoke all on function public.dopmi_meta_ads_preference(),public.dopmi_set_meta_ads_preference(boolean),
  public.dopmi_meta_ads_action_eligible(text,uuid),
  public.dopmi_send_message_meta_v2(uuid,uuid,text,text,jsonb),public.dopmi_transition_adoption_meta(uuid,integer,text,jsonb),
  public.dopmi_set_meta_ads_gate(boolean),public.dopmi_claim_meta_ads_events(integer),public.dopmi_purge_expired_meta_ads_events(),
  public.dopmi_meta_ads_event_allowed(uuid,uuid),public.dopmi_complete_meta_ads_event(uuid,boolean,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.dopmi_meta_ads_preference(),public.dopmi_set_meta_ads_preference(boolean),
  public.dopmi_meta_ads_action_eligible(text,uuid),
  public.dopmi_send_message_meta_v2(uuid,uuid,text,text,jsonb),public.dopmi_transition_adoption_meta(uuid,integer,text,jsonb)
  to authenticated;
grant execute on function public.dopmi_set_meta_ads_gate(boolean),public.dopmi_claim_meta_ads_events(integer),public.dopmi_purge_expired_meta_ads_events(),
  public.dopmi_meta_ads_event_allowed(uuid,uuid),public.dopmi_complete_meta_ads_event(uuid,boolean,uuid)
  to service_role;

commit;
