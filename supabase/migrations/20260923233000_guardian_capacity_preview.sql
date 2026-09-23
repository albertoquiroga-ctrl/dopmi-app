begin;

-- A read-only hint for the authorization screen. The checkout path must still
-- call dopmi_guardian_reserve under rescuer locks; this snapshot is not a hold.
create function public.dopmi_guardian_capacity_preview(target_gross bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare
  donor uuid;
  upper_net bigint;
  eligible_capacity bigint;
begin
  if target_gross is null or target_gross not between 1000 and 1000000 then
    raise exception 'Importe de Guardián inválido' using errcode='22023';
  end if;
  donor := private.dopmi_require_actor();
  upper_net := target_gross - (target_gross*2+50)/100;
  select coalesce(sum(greatest(0,r.reimbursable_cents
    -coalesce((select sum(d.allocated_cents+d.reserved_cents)
      from public.dopmi_donations d where d.expense_id=r.id),0)
    -private.dopmi_guardian_reserved(r.id))),0)
    into eligible_capacity
    from public.dopmi_rescue_records r
    where r.kind='expense' and r.status='approved' and r.owner_id<>donor
      and private.dopmi_expense_payable(r);
  return jsonb_build_object('gross_cents',target_gross,'required_cents',upper_net,
    'can_activate',eligible_capacity>=upper_net);
end;
$$;
revoke all on function public.dopmi_guardian_capacity_preview(bigint) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_capacity_preview(bigint) to authenticated;

commit;
