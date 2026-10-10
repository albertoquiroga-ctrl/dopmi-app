begin;
-- Read-only, owner-scoped ledger projection. Never updates financial evidence.
create function public.dopmi_payment_activity(
 received boolean default false, before_created_at timestamptz default null,
 before_kind text default null, before_id uuid default null, page_size integer default 20
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb; more boolean;
begin
 if received is null or page_size is null or page_size not between 1 and 50
 or (before_created_at is null)<>(before_kind is null) or (before_kind is null)<>(before_id is null)
 or (before_created_at is not null and not isfinite(before_created_at))
 or (before_kind is not null and before_kind not in ('contribution','guardian')) then
 raise exception 'Página inválida' using errcode='22023'; end if;
 with entries as (
  select d.created_at,'contribution'::text kind,d.id,
   jsonb_build_object('id',d.id,'created_at',d.created_at,'kind','contribution',
    'title',d.expense_title,'amount_cents',case when received then d.allocated_cents else d.gross_cents end,
    'gross_cents',case when not received then d.gross_cents end,
    'idempotency_key',case when not received and d.payment_status='pending' then d.idempotency_key end,
    'processed_at',d.processed_at,'platform_fee_cents',case when not received then d.platform_fee_cents end,
    'stripe_fee_cents',case when not received then d.stripe_fee_cents end,'net_cents',case when received then d.allocated_cents else d.net_cents end,
    'assigned_cents',d.allocated_cents,'transferred_cents',case when d.transfer_status='transferred' then d.allocated_cents else 0 end,
    'reversed_cents',case when d.transfer_status='reversed' then d.allocated_cents else 0 end,'payment_status',d.payment_status,
    'transfer_status',d.transfer_status,'refund_status',d.refund_status,
    'refund_cents',case when not received and d.refund_status in ('pending','attention') then d.refund_cents else 0 end,
    'refunded_cents',case when not received and (d.refund_status='refunded' or d.payment_status='refunded') then d.refund_cents else 0 end,
    'status',case when d.refund_status='attention' then 'refund_review'
      when d.refund_status='refunded' and d.refund_cents>0 and d.refund_cents<d.gross_cents then 'partial_refund'
      when d.refund_status='refunded' or d.payment_status='refunded' then 'refunded'
      when d.transfer_status='reversed' then 'reversed'
      when d.refund_status='pending' then 'refund_pending'
      when d.transfer_status='attention' then 'review'
      when d.transfer_status='transferred' then 'transferred'
      when d.payment_status='confirmed' and d.allocated_cents>0 then 'assigned'
      when d.payment_status='confirmed' then 'confirmed'
      when d.payment_status='canceled' then 'not_paid' else 'processing' end,
    'expense_id',d.expense_id,'allocation_count',1,
    'case_id',case when private.dopmi_rescue_public_visible(p) then p.id end,
    'case_name',case when private.dopmi_rescue_public_visible(p) then p.approved_snapshot->>'pet_name' end,
    'photo',case when private.dopmi_rescue_public_visible(p) then p.approved_snapshot->'photos'->>0 end
   ) item
  from public.dopmi_donations d
  join public.dopmi_rescue_records e on e.id=d.expense_id
  left join public.dopmi_rescue_records p on p.id=e.parent_id
  where (received and d.rescuer_id=actor) or (not received and d.donor_id=actor)
  union all
  select c.created_at,'guardian',c.id,
   jsonb_build_object('id',c.id,'created_at',c.created_at,'kind','guardian',
    'title',case when received then 'Guardián recibido' else 'Suscripción Guardián' end,
    'amount_cents',case when received then totals.assigned_cents else coalesce(s.gross_cents,0) end,
    'authorized_cents',case when not received then c.gross_cents end,
    'processed_at',s.created_at,'platform_fee_cents',case when not received then s.platform_fee_cents end,
    'stripe_fee_cents',case when not received then s.stripe_fee_cents end,
    'net_cents',case when received then totals.assigned_cents else s.allocated_cents+s.refund_cents end,
    'assigned_cents',totals.assigned_cents,'transferred_cents',totals.transferred_cents,
    'reversed_cents',totals.reversed_cents,'refund_cents',case when not received and s.refunded_at is null and s.stripe_refund_id is null then coalesce(s.refund_cents,0) else 0 end,
    'refunded_cents',case when not received then case when s.refunded_at is not null and s.stripe_refund_id is not null then s.refund_cents else coalesce(ra.confirmed_refund_cents,0) end end,
    'allocation_count',totals.allocation_count,
    'status',case
     when received and totals.assigned_cents>0 and totals.reversed_cents=totals.assigned_cents then 'reversed'
     when not received and s.refunded_at is not null and s.stripe_refund_id is not null then 'refunded'
     when not received and ra.status='review' then 'refund_review' when not received and ra.status='pending' then 'refund_reconciling'
     when not received and ra.status='completed' and ra.confirmed_refund_cents>=s.gross_cents then 'refunded'
     when not received and ra.status='completed' and ra.confirmed_refund_cents>0 then 'partial_refund'
     when not received and s.refund_cents>0 then 'refund_pending'
     when received and totals.reversed_cents>0 then 'partial_reversal'
     when received and totals.needs_review then 'review'
     when totals.assigned_cents>0 and totals.transferred_cents=totals.assigned_cents-totals.reversed_cents then 'transferred'
     when totals.assigned_cents>0 then 'assigned'
     when j.status='skipped' or a.status='no_capacity' or c.status='skipped' then 'skipped'
     when a.status in ('expired','failed') then 'not_paid'
     when j.status='attention' or a.status='attention' then 'review' else 'processing' end
   ) item
  from private.dopmi_guardian_cycles c
  left join private.dopmi_guardian_settlements s on s.cycle_id=c.id
  left join private.dopmi_guardian_activations a on a.cycle_id=c.id
  left join private.dopmi_guardian_collection_jobs j on j.cycle_id=c.id
  left join private.dopmi_guardian_refund_adjustments ra on ra.cycle_id=c.id
  cross join lateral (
   select count(*) allocation_count,coalesce(sum(x.allocated_cents),0) assigned_cents,
    coalesce(bool_or(exists(select 1 from private.dopmi_guardian_jobs work where work.cycle_id=x.cycle_id and work.expense_id=x.expense_id and work.status='attention')),false) needs_review,
    coalesce(sum(x.reversed_cents),0) reversed_cents,
    coalesce(sum(x.allocated_cents-x.reversed_cents) filter(where x.stripe_transfer_id is not null and x.transferred_at is not null),0) transferred_cents
   from private.dopmi_guardian_allocations x join public.dopmi_rescue_records e on e.id=x.expense_id
   where x.cycle_id=c.id and x.allocated_cents>0 and (not received or e.owner_id=actor)
  ) totals
  where (not received and c.donor_id=actor) or (received and exists(
   select 1 from private.dopmi_guardian_allocations own join public.dopmi_rescue_records own_expense on own_expense.id=own.expense_id
   where own.cycle_id=c.id and own.allocated_cents>0 and own_expense.owner_id=actor
  ))
 ), candidates as materialized (
  select * from entries where before_created_at is null or (created_at,kind,id)<(before_created_at,before_kind,before_id)
  order by created_at desc,kind desc,id desc limit page_size+1
 ), page as (select * from candidates order by created_at desc,kind desc,id desc limit page_size)
 select coalesce(jsonb_agg(item order by created_at desc,kind desc,id desc),'[]'::jsonb),
  (select count(*)>page_size from candidates) into result,more from page;
 return jsonb_build_object('items',result,'next_cursor',case when more then jsonb_build_object(
  'created_at',result->-1->'created_at','kind',result->-1->'kind','id',result->-1->'id') else null end);
end;
$$;

create function public.dopmi_payment_activity_allocations(target_cycle uuid,received boolean default false,after_expense uuid default null,page_size integer default 20)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb; more boolean;
begin
 if received is null or page_size is null or page_size not between 1 and 50 then raise exception 'Página inválida' using errcode='22023'; end if;
 if not exists(select 1 from private.dopmi_guardian_cycles c where c.id=target_cycle and (
  (not received and c.donor_id=actor) or (received and exists(select 1 from private.dopmi_guardian_allocations a join public.dopmi_rescue_records e on e.id=a.expense_id where a.cycle_id=c.id and e.owner_id=actor and a.allocated_cents>0)))) then
  raise exception 'Ciclo no disponible' using errcode='42501'; end if;
 with candidates as materialized (
  select a.expense_id,a.allocated_cents,a.reversed_cents,a.allocated_cents-a.reversed_cents remaining_cents,
   case when a.stripe_transfer_id is not null and a.transferred_at is not null then a.allocated_cents-a.reversed_cents else 0 end transferred_cents,
   case when a.reversed_cents=a.allocated_cents then 'reversed' when a.reversed_cents>0 then 'partial_reversal' when a.stripe_transfer_id is not null and a.transferred_at is not null then 'transferred' else 'assigned' end status,
   case when private.dopmi_rescue_public_visible(e) then coalesce(e.approved_snapshot->>'title','Gasto aprobado') else 'Gasto aprobado' end title,
   case when private.dopmi_rescue_public_visible(p) then p.id end case_id,
   case when private.dopmi_rescue_public_visible(p) then p.approved_snapshot->>'pet_name' end case_name,
   case when private.dopmi_rescue_public_visible(p) then p.approved_snapshot->'photos'->>0 end photo
  from private.dopmi_guardian_allocations a join public.dopmi_rescue_records e on e.id=a.expense_id
  left join public.dopmi_rescue_records p on p.id=e.parent_id
  where a.cycle_id=target_cycle and a.allocated_cents>0 and (not received or e.owner_id=actor)
   and (after_expense is null or a.expense_id>after_expense)
  order by a.expense_id limit page_size+1
 ), page as (select * from candidates order by expense_id limit page_size)
 select coalesce(jsonb_agg(to_jsonb(page) order by expense_id),'[]'::jsonb),(select count(*)>page_size from candidates) into result,more from page;
 return jsonb_build_object('items',result,'next_cursor',case when more then result->-1->'expense_id' else null end);
end;
$$;
revoke all on function public.dopmi_payment_activity(boolean,timestamptz,text,uuid,integer),public.dopmi_payment_activity_allocations(uuid,boolean,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_payment_activity(boolean,timestamptz,text,uuid,integer),public.dopmi_payment_activity_allocations(uuid,boolean,uuid,integer) to authenticated;
commit;
