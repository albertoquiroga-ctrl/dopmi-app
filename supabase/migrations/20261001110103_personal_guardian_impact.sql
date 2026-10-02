begin;

-- Keep the authenticated/public projection; add settled Guardian allocations,
-- never reservations, processor evidence, private drafts or another donor.
create or replace function public.dopmi_personal_impact() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
  if not public.dopmi_actor_active() then raise exception 'Sesión activa requerida' using errcode='42501'; end if;
  return coalesce((
    with support as (
      select e.parent_id as case_id,d.allocated_cents,d.processed_at as supported_at
      from public.dopmi_donations d
      join public.dopmi_rescue_records e on e.id=d.expense_id
      where d.donor_id=actor and d.payment_status='confirmed' and d.allocated_cents>0
      union all
      select e.parent_id,a.allocated_cents-a.reversed_cents,s.created_at
      from private.dopmi_guardian_allocations a
      join private.dopmi_guardian_cycles g on g.id=a.cycle_id
      join private.dopmi_guardian_settlements s on s.cycle_id=g.id
      join public.dopmi_rescue_records e on e.id=a.expense_id
      where g.donor_id=actor and a.allocated_cents>a.reversed_cents
    )
    select jsonb_agg(to_jsonb(result) order by result.last_supported_at desc,result.case_id)
    from (
      select c.id as case_id,c.approved_snapshot as public_data,
        sum(s.allocated_cents)::bigint as allocated_cents,max(s.supported_at) as last_supported_at,
        coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'body',u.approved_snapshot->>'body','photos',u.approved_snapshot->'photos','published_at',u.published_at) order by u.published_at,u.id)
          from public.dopmi_case_updates u where u.case_id=c.id and u.status='published' and u.approved_snapshot is not null),'[]'::jsonb) as updates
      from support s
      join public.dopmi_rescue_records c on c.id=s.case_id
      where private.dopmi_rescue_public_visible(c)
      group by c.id,c.approved_snapshot
    ) result
  ),'[]'::jsonb);
end;
$$;

-- CREATE OR REPLACE preserves the existing authenticated-only ACL.
commit;
