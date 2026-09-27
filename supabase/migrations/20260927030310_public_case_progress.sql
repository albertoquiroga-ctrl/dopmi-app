begin;

-- Preserve the established response and add aggregate progress needed by the
-- public case cards. Only approved, public expenses contribute to the goal.
create or replace function public.dopmi_rescue_public(case_id uuid default null, page_number integer default 1) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if page_number is null or page_number<1 then
    raise exception 'Página inválida' using errcode='22023';
  end if;
  return jsonb_build_object(
    'total',(select count(*) from public.dopmi_rescue_records r
      where (case when case_id is null then r.kind='case' else r.id=case_id or r.parent_id=case_id end)
        and private.dopmi_rescue_public_visible(r)),
    'items',coalesce((select jsonb_agg(x) from (
      select r.id,r.owner_id,r.kind,r.parent_id,r.status,r.approved_snapshot as public_data,
        r.reimbursable_cents,r.urgent,r.approved_at,
        case when r.kind='case' then coalesce((
          select sum(e.reimbursable_cents) from public.dopmi_rescue_records e
          where e.parent_id=r.id and e.kind='expense' and private.dopmi_rescue_public_visible(e)
        ),0) else r.reimbursable_cents end as target_cents,
        (select coalesce(sum(d.allocated_cents),0)
          from public.dopmi_donations d
          join public.dopmi_rescue_records e on e.id=d.expense_id
          where e.id=r.id or (r.kind='case' and e.parent_id=r.id)) as funded_cents,
        (select coalesce(sum(d.allocated_cents),0)
          from public.dopmi_donations d
          join public.dopmi_rescue_records e on e.id=d.expense_id
          where (e.id=r.id or (r.kind='case' and e.parent_id=r.id))
            and d.transfer_status='transferred' and d.stripe_transfer_id is not null) as transferred_cents,
        (r.kind='case' and exists(select 1 from public.dopmi_saved_cases s
          where s.user_id=auth.uid() and s.case_id=r.id and public.dopmi_actor_active())) as saved,
        (select approved_snapshot->>'public_name' from public.dopmi_rescue_records
          where owner_id=r.owner_id and kind='verification') as rescuer_name
      from public.dopmi_rescue_records r
      where (case when case_id is null then r.kind='case' else r.id=case_id or r.parent_id=case_id end)
        and private.dopmi_rescue_public_visible(r)
      order by r.kind,r.approved_at desc,r.id limit 20 offset (page_number::bigint-1)*20
    ) x),'[]')
  );
end;
$$;

revoke all on function public.dopmi_rescue_public(uuid,integer) from public;
grant execute on function public.dopmi_rescue_public(uuid,integer) to anon,authenticated;

commit;
