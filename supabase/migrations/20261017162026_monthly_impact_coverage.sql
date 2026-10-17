begin;
-- Block financial/need writers before establishing the real measurement
-- baseline. Otherwise a concurrent payment between baseline and trigger
-- installation could silently become unmeasured. Fail atomically if busy.
set local lock_timeout='2s';
set local statement_timeout='30s';
lock table public.dopmi_rescue_records,public.dopmi_donations,
 private.dopmi_guardian_cycles,private.dopmi_guardian_settlements,
 private.dopmi_guardian_allocations,private.dopmi_case_allocations
 in share row exclusive mode;
-- Financial support is an internal projection: one row per real allocation,
-- anchored to the original settlement time, never the last update time.
create view private.dopmi_impact_support as
 select 'expense'::text source,d.id source_id,d.donor_id,e.parent_id case_id,e.id expense_id,
 d.allocated_cents amount_cents,d.processed_at supported_at
 from public.dopmi_donations d join public.dopmi_rescue_records e on e.id=d.expense_id
 where d.contribution_scope='expense' and d.payment_status='confirmed' and d.allocated_cents>0 and d.processed_at is not null
 union all
 select 'case',d.id,d.donor_id,d.case_id,a.expense_id,a.allocated_cents-a.reversed_cents,d.processed_at
 from private.dopmi_case_allocations a join public.dopmi_donations d on d.id=a.donation_id
 where d.contribution_scope='case' and d.payment_status='confirmed' and a.allocated_cents>a.reversed_cents and d.processed_at is not null
 union all
 select 'guardian',a.cycle_id,c.donor_id,e.parent_id,a.expense_id,a.allocated_cents-a.reversed_cents,s.created_at
 from private.dopmi_guardian_allocations a join private.dopmi_guardian_cycles c on c.id=a.cycle_id
 join private.dopmi_guardian_settlements s on s.cycle_id=a.cycle_id
 join public.dopmi_rescue_records e on e.id=a.expense_id
 where a.allocated_cents>a.reversed_cents;
revoke all on private.dopmi_impact_support from public,anon,authenticated;
create table private.dopmi_impact_tracking (
 singleton boolean primary key default true check(singleton), started_at timestamptz not null
);
insert into private.dopmi_impact_tracking values(true,clock_timestamp());
create table private.dopmi_urgent_coverage_state (
 case_id uuid primary key references public.dopmi_rescue_records(id) on delete restrict,
 complete boolean not null, observed_at timestamptz not null default clock_timestamp()
);
create table private.dopmi_urgent_coverage_events (
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references public.dopmi_rescue_records(id) on delete restrict,
 covered_at timestamptz not null default clock_timestamp(),
 urgent_snapshot jsonb not null check(jsonb_typeof(urgent_snapshot)='array' and jsonb_array_length(urgent_snapshot)>0),
 funding_snapshot jsonb not null check(jsonb_typeof(funding_snapshot)='array' and jsonb_array_length(funding_snapshot)>0),
 invalidated_at timestamptz
);
create index dopmi_urgent_coverage_events_month on private.dopmi_urgent_coverage_events(covered_at,case_id) where invalidated_at is null;
alter table private.dopmi_impact_tracking enable row level security;
alter table private.dopmi_urgent_coverage_state enable row level security;
alter table private.dopmi_urgent_coverage_events enable row level security;
revoke all on private.dopmi_impact_tracking,private.dopmi_urgent_coverage_state,private.dopmi_urgent_coverage_events from public,anon,authenticated;

create function private.dopmi_urgent_case_complete(target uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.dopmi_rescue_records e where e.parent_id=target and e.kind='expense' and e.status='approved' and e.urgent and e.approved_snapshot is not null)
 and not exists(select 1 from public.dopmi_rescue_records e where e.parent_id=target and e.kind='expense' and e.status='approved' and e.urgent and e.approved_snapshot is not null
 and e.reimbursable_cents>coalesce((select sum(s.amount_cents) from private.dopmi_impact_support s where s.expense_id=e.id),0));
$$;
-- Existing complete cases form a baseline only. No coverage event is backdated
-- or invented for funding that preceded actual instrumentation.
insert into private.dopmi_urgent_coverage_state(case_id,complete)
 select id,private.dopmi_urgent_case_complete(id) from public.dopmi_rescue_records where kind='case';

create function private.dopmi_refresh_urgent_coverage(target uuid,financial boolean) returns void
language plpgsql security definer set search_path='' as $$
declare owner uuid; was_complete boolean; is_complete boolean; urgent jsonb; funding jsonb;
begin
 select owner_id into owner from public.dopmi_rescue_records where id=target and kind='case';
 if owner is null then return; end if;
 perform private.dopmi_rescue_lock(owner);
 insert into private.dopmi_urgent_coverage_state(case_id,complete) values(target,false) on conflict do nothing;
 select complete into was_complete from private.dopmi_urgent_coverage_state where case_id=target for update;
 is_complete:=private.dopmi_urgent_case_complete(target);
 if financial then
 -- Historical achievements depend on their original supporting funds. A new
 -- need cannot erase one, and replacement money cannot resurrect an invalid one.
 update private.dopmi_urgent_coverage_events event set invalidated_at=clock_timestamp()
 where event.case_id=target and event.invalidated_at is null and exists(
  select 1 from jsonb_array_elements(event.urgent_snapshot) need
  where (need->>'required_cents')::bigint>coalesce((
   select sum(least((ref->>'amount_cents')::bigint,coalesce(current_support.amount_cents,0)))
   from jsonb_array_elements(event.funding_snapshot) ref
   left join private.dopmi_impact_support current_support
    on current_support.source=ref->>'source' and current_support.source_id=(ref->>'source_id')::uuid
    and current_support.expense_id=(ref->>'expense_id')::uuid
   where ref->>'expense_id'=need->>'expense_id'
  ),0)
 );
 if is_complete and not was_complete then
 select jsonb_agg(jsonb_build_object('expense_id',e.id,'required_cents',e.reimbursable_cents,'approved_at',e.approved_at) order by e.id)
 into urgent from public.dopmi_rescue_records e where e.parent_id=target and e.kind='expense' and e.status='approved' and e.urgent and e.approved_snapshot is not null;
 select jsonb_agg(jsonb_build_object('source',s.source,'source_id',s.source_id,'expense_id',s.expense_id,'amount_cents',s.amount_cents) order by s.source,s.source_id,s.expense_id)
 into funding from private.dopmi_impact_support s where s.case_id=target and exists(
 select 1 from jsonb_array_elements(urgent) need where (need->>'expense_id')::uuid=s.expense_id);
 if urgent is not null and funding is not null then
 insert into private.dopmi_urgent_coverage_events(case_id,urgent_snapshot,funding_snapshot) values(target,urgent,funding);
 end if;
 end if;
 end if;
 update private.dopmi_urgent_coverage_state set complete=is_complete,observed_at=clock_timestamp() where case_id=target;
end; $$;
revoke all on function private.dopmi_urgent_case_complete(uuid),private.dopmi_refresh_urgent_coverage(uuid,boolean) from public,anon,authenticated;

-- Run in the same financial transaction. Reservations, cards and processor
-- pending states never enter the support view or produce coverage events.
create function private.dopmi_impact_donation_transition() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 -- A never-allocated refund/cancellation cannot affect support. Avoid taking
 -- owner locks after job_finish already owns this zero-allocation donation row.
 if (new.allocated_cents>0 or old.allocated_cents>0) and (
 new.allocated_cents is distinct from old.allocated_cents or new.payment_status is distinct from old.payment_status
 or new.processed_at is distinct from old.processed_at) then
 perform private.dopmi_refresh_urgent_coverage(coalesce(new.case_id,(select parent_id from public.dopmi_rescue_records where id=new.expense_id)),true);
 end if;return new;
end; $$;
create trigger dopmi_impact_donation_transition after update on public.dopmi_donations
 for each row execute function private.dopmi_impact_donation_transition();
create function private.dopmi_impact_guardian_transition() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.allocated_cents is distinct from old.allocated_cents or new.reversed_cents is distinct from old.reversed_cents then
 perform private.dopmi_refresh_urgent_coverage((select parent_id from public.dopmi_rescue_records where id=new.expense_id),true);
 end if;return new;
end; $$;
create trigger dopmi_impact_guardian_transition after update on private.dopmi_guardian_allocations
 for each row execute function private.dopmi_impact_guardian_transition();
create function private.dopmi_impact_case_ledger_transition() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.reversed_cents is distinct from old.reversed_cents then
 perform private.dopmi_refresh_urgent_coverage((select case_id from public.dopmi_donations where id=new.donation_id),true);
 end if;return new;
end; $$;
create trigger dopmi_impact_case_ledger_transition after update on private.dopmi_case_allocations
 for each row execute function private.dopmi_impact_case_ledger_transition();
create function private.dopmi_impact_need_transition() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.kind='case' then
 if TG_OP='INSERT' then perform private.dopmi_refresh_urgent_coverage(new.id,false);end if;
 elsif new.kind='expense' then
 perform private.dopmi_refresh_urgent_coverage(new.parent_id,false);
 if TG_OP='UPDATE' and old.parent_id is distinct from new.parent_id then perform private.dopmi_refresh_urgent_coverage(old.parent_id,false);end if;
 end if;return new;
end; $$;
create trigger dopmi_impact_need_transition after insert or update on public.dopmi_rescue_records
 for each row execute function private.dopmi_impact_need_transition();
revoke all on function private.dopmi_impact_donation_transition(),private.dopmi_impact_guardian_transition(),private.dopmi_impact_case_ledger_transition(),private.dopmi_impact_need_transition() from public,anon,authenticated;

-- External refund reconciliation must take the shared owner lock before the
-- donation row, matching settlement/reservation and the coverage transaction.
do $patch$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('public.dopmi_refund_adjustment(text,jsonb)'::regprocedure);
 anchor:='select * into d from public.dopmi_donations where id=(data->>''donation_id'')::uuid for update;';
 if position(anchor in definition)=0 then raise exception 'Review impact refund begin lock';end if;
 definition:=replace(definition,anchor,'perform private.dopmi_rescue_lock((select rescuer_id from public.dopmi_donations where id=(data->>''donation_id'')::uuid));'||chr(10)||anchor);
 anchor:='select * into d from public.dopmi_donations where id=j.donation_id for update;';
 if position(anchor in definition)=0 then raise exception 'Review impact refund finish lock';end if;
 definition:=replace(definition,anchor,'perform private.dopmi_rescue_lock((select rescuer_id from public.dopmi_donations where id=j.donation_id));'||chr(10)||anchor);
 execute definition;
end $patch$;

create function private.dopmi_impact_month(target_month date) returns date
language plpgsql stable security definer set search_path='' as $$
declare current_month date:=date_trunc('month',timezone('America/Mexico_City',now()))::date;
begin
 if target_month is null then return current_month;end if;
 if not isfinite(target_month) or target_month<>date_trunc('month',target_month)::date or target_month>current_month then
 raise exception 'Mes inválido' using errcode='22023';end if;
 return target_month;
end; $$;
revoke all on function private.dopmi_impact_month(date) from public,anon,authenticated;
create function public.dopmi_monthly_personal_impact(target_month date default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid(); month date:=private.dopmi_impact_month(target_month);
 start_at timestamptz:=month::timestamp at time zone 'America/Mexico_City';
 end_at timestamptz:=(month+interval '1 month')::timestamp at time zone 'America/Mexico_City';result jsonb;
begin
 if actor is null or not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501';end if;
 select jsonb_build_object('month',month,'current_month',private.dopmi_impact_month(null),'timezone','America/Mexico_City','period_start',start_at,'period_end',end_at,
 'allocated_cents',coalesce(sum(amount_cents),0),'cases_supported',count(distinct case_id),
 'case_ids',coalesce(jsonb_agg(distinct case_id) filter(where case_id is not null),'[]')) into result
 from private.dopmi_impact_support where donor_id=actor and supported_at>=start_at and supported_at<end_at;
 return result;
end; $$;
create function public.dopmi_monthly_community_impact(target_month date default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare month date:=private.dopmi_impact_month(target_month);
 start_at timestamptz:=month::timestamp at time zone 'America/Mexico_City';
 end_at timestamptz:=(month+interval '1 month')::timestamp at time zone 'America/Mexico_City'; started timestamptz;
begin
 select started_at into started from private.dopmi_impact_tracking where singleton;
 return jsonb_build_object('month',month,'timezone','America/Mexico_City','period_start',start_at,'period_end',end_at,
 'cases_supported',(select count(distinct case_id) from private.dopmi_impact_support where supported_at>=start_at and supported_at<end_at),
 'urgent_cases_covered',case when end_at<=started then null else (select count(distinct case_id) from private.dopmi_urgent_coverage_events where covered_at>=start_at and covered_at<end_at and invalidated_at is null) end,
 'measurement_started_at',started,'measurement_started_on',timezone('America/Mexico_City',started)::date,'measurement_status',case when end_at<=started then 'not_measured' when start_at<started then 'partial' else 'complete' end);
end; $$;
revoke all on function public.dopmi_monthly_personal_impact(date),public.dopmi_monthly_community_impact(date) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_monthly_personal_impact(date) to authenticated;
grant execute on function public.dopmi_monthly_community_impact(date) to anon,authenticated;
-- Preserve the existing approved-case collage contract while including the new
-- case ledger. The monthly metrics above remain separate and owner-scoped.
do $patch$
declare definition text; start_at integer; end_at integer;
begin
 definition:=pg_get_functiondef('public.dopmi_personal_impact()'::regprocedure);
 start_at:=position('with support as (' in definition);
 end_at:=position('    select jsonb_agg(to_jsonb(result)' in definition);
 if start_at=0 or end_at<=start_at then raise exception 'Review personal impact source projection';end if;
 definition:=substring(definition from 1 for start_at-1)||'with support as (
 select case_id,amount_cents as allocated_cents,supported_at from private.dopmi_impact_support where donor_id=actor
 )
'||substring(definition from end_at);
 execute definition;
end $patch$;
commit;
