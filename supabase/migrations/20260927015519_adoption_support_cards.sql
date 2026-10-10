begin;

create function public.dopmi_discovery_support(page_size integer default 12)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if page_size is null or page_size not between 1 and 30 then
    raise exception 'Límite inválido' using errcode = '22023';
  end if;
  return coalesce((
    select jsonb_agg(card order by approved_at desc, case_id)
    from (
      select
        c.id as case_id,
        c.approved_at,
        c.approved_snapshot->>'pet_name' as pet_name,
        c.approved_snapshot->>'story' as story,
        c.approved_snapshot->>'city' as city,
        c.approved_snapshot->>'state' as region,
        coalesce(c.approved_snapshot->'photos','[]'::jsonb)->>0 as photo,
        e.id as expense_id,
        funding->>'title' as expense_title,
        (funding->>'reimbursable_cents')::bigint as reimbursable_cents,
        (funding->>'funded_cents')::bigint as funded_cents,
        (funding->>'available_cents')::bigint as available_cents
      from public.dopmi_rescue_records c
      join lateral (
        select expense.* from public.dopmi_rescue_records expense
        cross join lateral public.dopmi_expense_funding(expense.id) amount
        where expense.parent_id = c.id and expense.kind = 'expense'
          and expense.status = 'approved'
          and (amount->>'payable')::boolean
          and (amount->>'available_cents')::bigint > 0
        order by expense.urgent desc, expense.approved_at, expense.id
        limit 1
      ) e on true
      cross join lateral public.dopmi_expense_funding(e.id) funding
      where c.kind = 'case' and c.status = 'approved'
        and private.dopmi_rescue_public_visible(c)
      order by c.approved_at desc, c.id
      limit page_size
    ) card
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.dopmi_discovery_support(integer) from public, anon, authenticated;
grant execute on function public.dopmi_discovery_support(integer) to anon, authenticated;

commit;
