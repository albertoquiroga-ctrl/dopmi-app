begin;

-- Owner-only case pagination with actual financial totals. No mutation or payment
-- authority is added; existing expense funding includes settled Guardian net.
create function public.dopmi_my_cases(page_number integer default 1) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := auth.uid();
begin
  if actor is null or not public.dopmi_actor_active() then
    raise exception 'Sesión activa requerida' using errcode='42501';
  end if;
  if page_number is null or page_number<1 then
    raise exception 'Página inválida' using errcode='22023';
  end if;
  return jsonb_build_object(
    'total',(select count(*) from public.dopmi_rescue_records r where r.owner_id=actor and r.kind='case'),
    'items',coalesce((select jsonb_agg(x.record order by x.updated_at desc,x.id) from (
      select r.id,r.updated_at,to_jsonb(r)||jsonb_build_object(
        'target_cents',coalesce(f.target_cents,0),
        'funded_cents',coalesce(f.funded_cents,0),
        'transferred_cents',coalesce(f.transferred_cents,0)
      ) as record
      from (
        select c.* from public.dopmi_rescue_records c
        where c.owner_id=actor and c.kind='case'
        order by c.updated_at desc,c.id limit 20 offset (page_number::bigint-1)*20
      ) r
      left join lateral (
        select coalesce(sum(e.reimbursable_cents) filter(where e.status in ('approved','closed') and e.approved_snapshot is not null),0) as target_cents,
          coalesce(sum((funding.value->>'funded_cents')::bigint),0) as funded_cents,
          coalesce(sum((funding.value->>'transferred_cents')::bigint),0) as transferred_cents
        from public.dopmi_rescue_records e
        cross join lateral public.dopmi_expense_funding(e.id) as funding(value)
        where e.parent_id=r.id and e.kind='expense' and e.owner_id=actor
      ) f on true
    ) x),'[]')
  );
end;
$$;

revoke all on function public.dopmi_my_cases(integer) from public,anon,authenticated;
grant execute on function public.dopmi_my_cases(integer) to authenticated;

commit;
