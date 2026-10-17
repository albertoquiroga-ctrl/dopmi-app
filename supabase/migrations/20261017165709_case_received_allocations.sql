begin;
-- Recipient history is independent from public case visibility. This read is
-- separate from the donor receipt: no reservations or donor identifiers enter it.
create function public.dopmi_case_received_allocations(target_donation uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); parent public.dopmi_donations;
begin
 select * into parent from public.dopmi_donations where id=target_donation
  and contribution_scope='case' and rescuer_id=actor and payment_status in ('confirmed','refunded');
 if not found or not exists(select 1 from private.dopmi_case_allocations a
  join public.dopmi_rescue_records e on e.id=a.expense_id
  where a.donation_id=target_donation and a.allocated_cents>0
   and e.kind='expense' and e.owner_id=actor and e.parent_id=parent.case_id) then
  raise exception 'Aportación no disponible' using errcode='42501'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
  'expense_id',a.expense_id,
  'title',case when private.dopmi_rescue_public_visible(e)
    then coalesce(e.approved_snapshot->>'title','Gasto aprobado') else 'Gasto aprobado' end,
  'allocated_cents',a.allocated_cents,'reversed_cents',a.reversed_cents,
  'remaining_cents',a.allocated_cents-a.reversed_cents) order by a.expense_id)
 from private.dopmi_case_allocations a
 join public.dopmi_rescue_records e on e.id=a.expense_id
 where a.donation_id=parent.id and a.allocated_cents>0
  and e.kind='expense' and e.owner_id=actor and e.parent_id=parent.case_id),'[]'::jsonb);
end $$;
revoke all on function public.dopmi_case_received_allocations(uuid) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_case_received_allocations(uuid) to authenticated;
commit;
