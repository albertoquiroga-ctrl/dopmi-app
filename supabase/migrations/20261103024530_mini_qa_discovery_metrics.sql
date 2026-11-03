begin;

-- Per-account discovery progress is a product preference, independent of optional
-- audience measurement. It stores no origin, coordinates, contacts or payloads.
create table private.dopmi_adoption_seen (
  actor_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.dopmi_adoptions(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key(actor_id,post_id)
);
alter table private.dopmi_adoption_seen enable row level security;
revoke all on private.dopmi_adoption_seen from public,anon,authenticated,service_role;

-- Finalization retains an anonymized profile before Auth cleanup. Remove the
-- functional history immediately, even if the later Auth operation is delayed.
create function private.dopmi_clear_adoption_seen_for_deleted_account() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  delete from private.dopmi_adoption_seen s where s.actor_id=new.id;
  return new;
end;
$$;
revoke all on function private.dopmi_clear_adoption_seen_for_deleted_account()
  from public,anon,authenticated,service_role;
create trigger dopmi_clear_adoption_seen_for_deleted_account
  after update of account_status on public.profiles
  for each row when (new.account_status='deleted' and old.account_status is distinct from 'deleted')
  execute function private.dopmi_clear_adoption_seen_for_deleted_account();

create function public.dopmi_seen_adoptions() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  return coalesce((select jsonb_agg(s.post_id order by s.seen_at,s.post_id)
    from private.dopmi_adoption_seen s where s.actor_id=actor),'[]'::jsonb);
end;
$$;

create function public.dopmi_mark_adoption_seen(post_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  perform pg_advisory_xact_lock(hashtextextended('dopmi-discovery-history:'||actor::text,0));
  if not exists(select 1 from public.dopmi_adoptions a join public.profiles p on p.id=a.owner_id
    where a.id=post_id and a.status='published' and p.account_status='active') then return; end if;
  insert into private.dopmi_adoption_seen(actor_id,post_id) values(actor,post_id)
    on conflict on constraint dopmi_adoption_seen_pkey do nothing;
end;
$$;

create function public.dopmi_reset_seen_adoptions() returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
  perform pg_advisory_xact_lock(hashtextextended('dopmi-discovery-history:'||actor::text,0));
  delete from private.dopmi_adoption_seen s where s.actor_id=actor;
end;
$$;
revoke all on function public.dopmi_seen_adoptions(),public.dopmi_mark_adoption_seen(uuid),
  public.dopmi_reset_seen_adoptions() from public,anon,authenticated,service_role;
grant execute on function public.dopmi_seen_adoptions(),public.dopmi_mark_adoption_seen(uuid),
  public.dopmi_reset_seen_adoptions() to authenticated;

-- Public counters describe public outcomes, not the optional shelter badge.
create or replace function public.dopmi_rescuer_public_metrics(person_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  if public.dopmi_rescuer_public(person_id) is null and public.dopmi_public_profile(person_id) is null then return null; end if;
  with cases as materialized (
    select r.id,r.status from public.dopmi_rescue_records r
    where r.owner_id=person_id and r.kind='case' and private.dopmi_rescue_public_visible(r)
  ), expenses as materialized (
    select e.parent_id,e.status,e.reimbursable_cents as target,
      (public.dopmi_expense_funding(e.id)->>'funded_cents')::bigint as funded
    from public.dopmi_rescue_records e join cases c on c.id=e.parent_id
    where e.kind='expense' and private.dopmi_rescue_public_visible(e)
  ), adoptions as materialized (
    -- Historical counts reveal no retired listing identity or unpublished edits.
    select a.id,a.rescue_case_id,a.status from public.dopmi_adoptions a
    where a.owner_id=person_id and a.published_at is not null
  )
  select jsonb_build_object(
    'received_support_pets',(select count(distinct parent_id) from expenses where funded>0),
    'published_cases',(select count(*) from cases),
    'active_donation_cases',(select count(*) from cases c where c.status='approved'
      and exists(select 1 from expenses e where e.parent_id=c.id and e.status='approved' and e.target>e.funded)),
    'active_adoptions',(select count(*) from adoptions where status='published'),
    'published_donation_cases',(select count(*) from cases c where exists(select 1 from expenses e where e.parent_id=c.id)),
    'published_adoptions',(select count(*) from adoptions),
    'funded_cents',(select coalesce(sum(funded),0) from expenses),
    'completed_needs',(select count(*) from expenses where target>0 and funded>=target),
    'helped_pets',(select count(*) from (
      select id from cases union select coalesce(rescue_case_id,id) from adoptions
    ) pets),
    'closed_cases',(select count(*) from cases where status='closed')
  ) into result;
  return result;
end;
$$;

-- Owner lists use the private proposal; public readers keep the approved row.
create or replace function private.dopmi_owned_case_rows(actor uuid) returns table(id uuid,program text,status text,
  archived boolean,pet_name text,updated_at timestamptz,item jsonb)
language sql stable set search_path='' as $$
  select a.id,'adoption',o.value->>'status',a.status in('adopted','archived'),o.value->>'pet_name',a.updated_at,
    o.value||jsonb_build_object('program','adoption','record',o.value,'cover_path',o.value->'photos'->>0,
      'archived',a.status in('adopted','archived'),'unique_view_count',(select count(*) from private.dopmi_adoption_views v where v.post_id=a.id),
      'tracking_started_at',(select started_at from private.dopmi_adoption_measurement_start),
      'thread_count',(select count(*) from public.dopmi_threads t where t.post_id=a.id),
      'close_reason',c.reason,'adopted_with_dopmi_support',c.dopmi_support,'close_reason_description',c.description)
    from public.dopmi_adoptions a cross join lateral(select private.dopmi_adoption_owner_row(a) value)o left join lateral(select * from private.dopmi_adoption_closures x where x.post_id=a.id order by x.version desc limit 1)c on true
    where a.owner_id=actor and actor=auth.uid()
  union all
  select r.id,'support',r.status,r.status='closed' or exists(select 1 from private.dopmi_support_archives ar where ar.record_id=r.id),
    coalesce(r.public_data->>'pet_name',r.public_data->>'title','Sin nombre'),r.updated_at,
    to_jsonb(r)||jsonb_build_object('program','support','record',to_jsonb(r),'pet_name',coalesce(r.public_data->>'pet_name',r.public_data->>'title','Sin nombre'),
      'cover_path',(select f->>'path' from jsonb_array_elements(r.files)f where f->>'role'='public' limit 1),
      'archived',r.status='closed' or exists(select 1 from private.dopmi_support_archives ar where ar.record_id=r.id),
      'target_cents',coalesce(f.target_cents,0),'funded_cents',coalesce(f.funded_cents,0),'transferred_cents',coalesce(f.transferred_cents,0),
      'need_types',coalesce(f.need_types,'[]'::jsonb))
    from public.dopmi_rescue_records r left join lateral(
      select sum(e.reimbursable_cents)filter(where e.status in('approved','closed') and e.approved_snapshot is not null)target_cents,
        sum((funding.value->>'funded_cents')::bigint)funded_cents,sum((funding.value->>'transferred_cents')::bigint)transferred_cents,
        jsonb_agg(distinct coalesce(e.public_data->>'category','other'))filter(where e.status in('approved','closed') and e.approved_snapshot is not null)need_types
      from public.dopmi_rescue_records e cross join lateral public.dopmi_expense_funding(e.id)funding(value)
      where e.owner_id=actor and e.parent_id=r.id and e.kind='expense'
    )f on true where r.owner_id=actor and r.kind='case' and actor=auth.uid();
$$;

commit;
