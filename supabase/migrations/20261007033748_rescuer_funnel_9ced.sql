begin;

-- Daily observations add temporal coverage without rewriting lifetime evidence.
create table private.dopmi_adoption_view_days (
  post_id uuid not null references public.dopmi_adoptions(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete cascade,
  viewed_on date not null,
  primary key(post_id,actor_id,viewed_on)
);
create table private.dopmi_adoption_view_day_start (
  singleton boolean primary key default true check(singleton),
  started_at timestamptz not null default now()
);
insert into private.dopmi_adoption_view_day_start(singleton) values(true);
alter table private.dopmi_adoption_view_days enable row level security;
alter table private.dopmi_adoption_view_day_start enable row level security;
revoke all on private.dopmi_adoption_view_days,private.dopmi_adoption_view_day_start
  from public,anon,authenticated;

create or replace function public.dopmi_record_adoption_view(post_id uuid,consent boolean) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  if consent is distinct from true or not exists(select 1 from private.dopmi_adoption_measurement m where m.actor_id=actor and m.consent) then return; end if;
  if not exists(select 1 from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
    where a.id=post_id and a.status='published' and p.account_status='active' and a.owner_id<>actor) then return; end if;
  insert into private.dopmi_adoption_views(post_id,actor_id) values(post_id,actor) on conflict do nothing;
  insert into private.dopmi_adoption_view_days(post_id,actor_id,viewed_on)
    values(post_id,actor,timezone('America/Mexico_City',now())::date) on conflict do nothing;
end; $$;
revoke all on function public.dopmi_record_adoption_view(uuid,boolean) from public,anon;
grant execute on function public.dopmi_record_adoption_view(uuid,boolean) to authenticated;

create function private.dopmi_funnel_period(period text,instant timestamptz)
returns table(period_start timestamptz,period_end timestamptz)
language plpgsql immutable set search_path='' as $$
declare local_now timestamp:=timezone('America/Mexico_City',instant);
begin
  if period is null or period not in('yesterday','week','month') or instant is null then
    raise exception 'Período inválido' using errcode='22023';
  end if;
  period_start:=(case period when 'yesterday' then date_trunc('day',local_now)-interval '1 day'
    when 'week' then date_trunc('week',local_now) else date_trunc('month',local_now) end) at time zone 'America/Mexico_City';
  period_end:=case when period='yesterday' then date_trunc('day',local_now) at time zone 'America/Mexico_City' else instant end;
  return next;
end; $$;
revoke all on function private.dopmi_funnel_period(text,timestamptz) from public,anon,authenticated;

create function public.dopmi_rescuer_funnel(period text default 'month') returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); bounds record; instant timestamptz:=now(); result jsonb;
begin
  select * into bounds from private.dopmi_funnel_period(period,instant);
  with owned_adoptions as (
    select id,status from public.dopmi_adoptions where owner_id=actor
  ), views as (
    select distinct v.post_id,v.actor_id from private.dopmi_adoption_view_days v
    join owned_adoptions a on a.id=v.post_id
    where v.viewed_on>=timezone('America/Mexico_City',bounds.period_start)::date
      and v.viewed_on<=timezone('America/Mexico_City',bounds.period_end)::date
      and (period<>'yesterday' or v.viewed_on<timezone('America/Mexico_City',bounds.period_end)::date)
  ), contacts as (
    select distinct t.post_id,t.adopter_id from public.dopmi_threads t
    join owned_adoptions a on a.id=t.post_id join public.dopmi_messages m on m.thread_id=t.id
    where t.owner_id=actor and m.sender_id=t.adopter_id
      and m.created_at>=bounds.period_start and m.created_at<bounds.period_end
  ), adopted as (
    select a.id from owned_adoptions a join lateral (
      select reason,created_at from private.dopmi_adoption_closures c
      where c.post_id=a.id order by version desc limit 1
    ) closure on true where a.status='adopted' and closure.reason='adopted'
      and closure.created_at>=bounds.period_start and closure.created_at<bounds.period_end
  ), support_events as (
    select d.donor_id,d.allocated_cents as net_cents,d.processed_at as occurred_at
    from public.dopmi_donations d join public.dopmi_rescue_records e on e.id=d.expense_id
    where d.rescuer_id=actor and e.owner_id=actor and d.payment_status='confirmed' and d.allocated_cents>0
    union all
    select cycle.donor_id,a.allocated_cents-a.reversed_cents,s.created_at
    from private.dopmi_guardian_allocations a
    join private.dopmi_guardian_cycles cycle on cycle.id=a.cycle_id
    join private.dopmi_guardian_settlements s on s.cycle_id=a.cycle_id
    join public.dopmi_rescue_records e on e.id=a.expense_id
    where e.owner_id=actor and a.allocated_cents>a.reversed_cents
  ), period_support as (
    select * from support_events where occurred_at>=bounds.period_start and occurred_at<bounds.period_end
  ), support_cases as (
    select item,status,archived from private.dopmi_owned_case_rows(actor) where program='support'
  )
  select jsonb_build_object(
    'period',period,'period_start',bounds.period_start,'period_end',bounds.period_end,'as_of',instant,
    'view_tracking_started_at',(select started_at from private.dopmi_adoption_view_day_start),
    'adoption',jsonb_build_object(
      'views',(select count(*) from views),
      'favorites',(select count(*) from public.dopmi_favorites f join owned_adoptions a on a.id=f.post_id
        where f.user_id<>actor and f.created_at>=bounds.period_start and f.created_at<bounds.period_end),
      'messages',(select count(*) from contacts),'adoptions',(select count(*) from adopted)),
    'support',jsonb_build_object(
      'donors',(select count(distinct donor_id) from period_support),
      'raised_cents',(select coalesce(sum(net_cents),0) from period_support),
      'active',(select count(*) from support_cases where status='approved' and not archived),
      'completed',(select count(*) from support_cases where status in('approved','closed')
        and (item->>'target_cents')::bigint>0 and (item->>'funded_cents')::bigint>=(item->>'target_cents')::bigint)
    )
  ) into result;
  return result;
end; $$;
revoke all on function public.dopmi_rescuer_funnel(text) from public,anon,authenticated;
grant execute on function public.dopmi_rescuer_funnel(text) to authenticated;

commit;
