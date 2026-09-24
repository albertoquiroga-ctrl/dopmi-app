begin;

-- Seek pagination is scoped to the authenticated donor. These projections
-- expose confirmed accounting only, never reservation estimates or Stripe IDs.
create index dopmi_guardian_cycles_history on private.dopmi_guardian_cycles(donor_id,created_at desc,id desc);
create function public.dopmi_guardian_history(
 before_created_at timestamptz default null, before_id uuid default null, page_size integer default 20
) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare owner uuid:=auth.uid(); result jsonb; more boolean;
begin
 if owner is null then raise exception 'Sesión requerida' using errcode='42501'; end if;
 if page_size is null or page_size not between 1 and 50
 or (before_created_at is null)<>(before_id is null)
 or (before_created_at is not null and not isfinite(before_created_at)) then
 raise exception 'Página inválida' using errcode='22023'; end if;
 with candidates as materialized (
   select c.* from private.dopmi_guardian_cycles c where c.donor_id=owner
   and (before_created_at is null or (c.created_at,c.id)<(before_created_at,before_id))
   order by c.created_at desc,c.id desc limit page_size+1
 ), page as (select * from candidates order by created_at desc,id desc limit page_size)
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',c.id,'created_at',c.created_at,
   'kind',case when a.cycle_id is not null then 'initial' when j.cycle_id is not null then 'monthly' else 'cycle' end,
   'period_start',to_timestamp(j.period_start),'period_end',to_timestamp(j.period_end),
   'authorized_cents',c.gross_cents,
   'status',case
     when s.refunded_at is not null and s.stripe_refund_id is not null then 'refunded'
     when s.refund_cents>0 then 'refund_pending'
     when s.allocated_cents>0 and totals.transferred_cents=s.allocated_cents then 'transferred'
     when s.allocated_cents>0 then 'assigned'
     when j.status='skipped' or a.status='no_capacity' then 'skipped'
     when a.status in ('expired','failed') then 'not_paid'
     when j.status='attention' or a.status='attention' then 'review'
     else 'processing' end,
   'skip_reason',case when j.status='skipped' then
       case when j.recovery_reason in ('payment_failed','authentication_required') then j.recovery_reason
       when c.status='skipped' then 'no_capacity' else 'not_collected' end
     when a.status='no_capacity' then 'no_capacity' else null end,
   'needs_review',exists(select 1 from private.dopmi_guardian_jobs work where work.cycle_id=c.id and work.status='attention'),
   'paid_cents',s.gross_cents,'stripe_fee_cents',s.stripe_fee_cents,'platform_fee_cents',s.platform_fee_cents,
   'assigned_cents',s.allocated_cents,'transferred_cents',totals.transferred_cents,
   'refund_cents',coalesce(s.refund_cents,0),
   'refunded_cents',case when s.refunded_at is not null and s.stripe_refund_id is not null then s.refund_cents else 0 end,
   'allocation_count',totals.allocation_count
 ) order by c.created_at desc,c.id desc),'[]'),(select count(*)>page_size from candidates)
 into result,more
 from page c
 left join private.dopmi_guardian_activations a on a.cycle_id=c.id
 left join private.dopmi_guardian_collection_jobs j on j.cycle_id=c.id
 left join private.dopmi_guardian_settlements s on s.cycle_id=c.id
 cross join lateral (
   select count(*) as allocation_count,
   coalesce(sum(x.allocated_cents) filter(where x.stripe_transfer_id is not null and x.transferred_at is not null),0) as transferred_cents
   from private.dopmi_guardian_allocations x where x.cycle_id=c.id and x.allocated_cents>0
 ) totals;
 return jsonb_build_object('items',result,'next_cursor',case when more then
   jsonb_build_object('created_at',result->-1->'created_at','id',result->-1->'id') else null end);
end;
$$;

-- Allocation pages never expose private drafts, evidence, destinations or
-- rescuer identities. If publication is withdrawn, keep the amount and use a
-- neutral title. Even staff cannot use this endpoint for another donor.
create function public.dopmi_guardian_history_allocations(
 target_cycle uuid, after_expense uuid default null, page_size integer default 20
) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare owner uuid:=auth.uid(); result jsonb; more boolean;
begin
 if owner is null or not exists(select 1 from private.dopmi_guardian_cycles c where c.id=target_cycle and c.donor_id=owner) then
 raise exception 'Ciclo no disponible' using errcode='42501'; end if;
 if page_size is null or page_size not between 1 and 50 then raise exception 'Página inválida' using errcode='22023'; end if;
 with candidates as materialized (
   select a.* from private.dopmi_guardian_allocations a
   where a.cycle_id=target_cycle and a.allocated_cents>0 and (after_expense is null or a.expense_id>after_expense)
   order by a.expense_id limit page_size+1
 ), page as (select * from candidates order by expense_id limit page_size)
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',a.expense_id,
   'title',case when private.dopmi_rescue_public_visible(r) then coalesce(nullif(r.approved_snapshot->>'title',''),'Gasto aprobado') else 'Gasto aprobado' end,
   'amount_cents',a.allocated_cents,
   'status',case when a.stripe_transfer_id is not null and a.transferred_at is not null then 'transferred' else 'assigned' end
 ) order by a.expense_id),'[]'),(select count(*)>page_size from candidates)
 into result,more from page a join public.dopmi_rescue_records r on r.id=a.expense_id;
 return jsonb_build_object('items',result,'next_cursor',case when more then result->-1->'id' else null end);
end;
$$;

revoke all on function public.dopmi_guardian_history(timestamptz,uuid,integer),public.dopmi_guardian_history_allocations(uuid,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_guardian_history(timestamptz,uuid,integer),public.dopmi_guardian_history_allocations(uuid,uuid,integer) to authenticated;
commit;
