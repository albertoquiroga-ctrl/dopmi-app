begin;

-- Public aggregate only: never expose donor, processor, private drafts or evidence.
create function public.dopmi_rescuer_public_metrics(person_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  if public.dopmi_rescuer_public(person_id) is null then return null; end if;
  with cases as materialized (
    select r.id,r.status from public.dopmi_rescue_records r
    where r.owner_id=person_id and r.kind='case' and private.dopmi_rescue_public_visible(r)
  ), expenses as materialized (
    select e.parent_id,e.reimbursable_cents as target,
      (public.dopmi_expense_funding(e.id)->>'funded_cents')::bigint as funded
    from public.dopmi_rescue_records e join cases c on c.id=e.parent_id
    where e.kind='expense' and private.dopmi_rescue_public_visible(e)
  ), adoptions as materialized (
    -- Historical counts reveal no retired listing identity or unpublished edits.
    select a.id,a.rescue_case_id,a.status from public.dopmi_adoptions a
    where a.owner_id=person_id and a.published_at is not null
  )
  select jsonb_build_object(
    'published_cases',(select count(*) from cases),
    'active_donation_cases',(select count(*) from cases c where c.status='approved'
      and exists(select 1 from expenses e where e.parent_id=c.id and e.target>e.funded)),
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

revoke all on function public.dopmi_rescuer_public_metrics(uuid) from public;
grant execute on function public.dopmi_rescuer_public_metrics(uuid) to anon,authenticated;

commit;
