begin;

create or replace function public.dopmi_rescuer_dashboard() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
  guardian_assigned bigint;
  guardian_transferred bigint;
begin
  -- Count settled net once per owned expense, including recorded reversals.
  -- Reservation amounts never enter dopmi_guardian_funded.
  select coalesce(sum(private.dopmi_guardian_funded(e.id)),0),
    coalesce(sum(private.dopmi_guardian_funded(e.id,true)),0)
  into guardian_assigned,guardian_transferred
  from public.dopmi_rescue_records e
  where e.owner_id=actor and e.kind='expense';
  return jsonb_build_object(
    'verification_status',coalesce((select status from public.dopmi_rescue_records
      where owner_id=actor and kind='verification'),'not_started'),
    'case_counts',jsonb_build_object(
      'active',(select count(*) from public.dopmi_rescue_records where owner_id=actor and kind='case' and status='approved'),
      'draft',(select count(*) from public.dopmi_rescue_records where owner_id=actor and kind='case' and status='draft'),
      'review',(select count(*) from public.dopmi_rescue_records where owner_id=actor and kind='case' and status='submitted'),
      'corrections',(select count(*) from public.dopmi_rescue_records where owner_id=actor and kind='case' and status in ('changes_requested','rejected'))
    ),
    'unread_messages',(select count(*) from public.dopmi_notifications where user_id=actor and kind='message' and read_at is null),
    'financial',jsonb_build_object(
      'assigned_cents',(select coalesce(sum(allocated_cents),0) from public.dopmi_donations where rescuer_id=actor and payment_status='confirmed')+guardian_assigned,
      'transferred_cents',(select coalesce(sum(allocated_cents),0) from public.dopmi_donations where rescuer_id=actor and transfer_status='transferred' and stripe_transfer_id is not null)+guardian_transferred,
      'in_review_cents',(select coalesce(sum(allocated_cents),0) from public.dopmi_donations where rescuer_id=actor and payment_status='confirmed' and transfer_status in ('not_started','pending','attention'))+greatest(0,guardian_assigned-guardian_transferred)
    ),
    'pending',coalesce((select jsonb_agg(to_jsonb(x)) from (
      select r.id,r.kind,r.parent_id,r.status,r.feedback,
        coalesce(r.public_data->>'pet_name',r.public_data->>'title',r.public_data->>'public_name','Borrador') as title,
        r.updated_at
      from public.dopmi_rescue_records r
      where r.owner_id=actor and r.status in ('draft','changes_requested','rejected')
      order by r.updated_at desc,r.id limit 6
    ) x),'[]'::jsonb),
    'recent_activity',coalesce((select jsonb_agg(to_jsonb(x)) from (
      select q.expense_id,q.expense_title,q.allocated_cents,q.transfer_status,q.created_at,q.source
      from (
        select d.expense_id,d.expense_title,d.allocated_cents,d.transfer_status,d.created_at,
          'individual'::text as source,d.id::text as sort_key
        from public.dopmi_donations d
        where d.rescuer_id=actor and d.payment_status='confirmed' and d.allocated_cents>0
        union all
        select a.expense_id,coalesce(e.approved_snapshot->>'title','Gasto'),
          a.allocated_cents-a.reversed_cents,
          case when a.stripe_transfer_id is not null then 'transferred'
            when exists(select 1 from private.dopmi_guardian_jobs j where j.cycle_id=a.cycle_id
              and j.expense_id=a.expense_id and j.kind='transfer' and j.status='attention') then 'attention'
            else 'pending' end,
          settlement.created_at,'guardian'::text,a.cycle_id::text||':'||a.expense_id::text
        from private.dopmi_guardian_allocations a
        join private.dopmi_guardian_settlements settlement on settlement.cycle_id=a.cycle_id
        join public.dopmi_rescue_records e on e.id=a.expense_id
        where e.owner_id=actor and e.kind='expense' and a.allocated_cents>a.reversed_cents
      ) q order by q.created_at desc,q.source,q.sort_key limit 6
    ) x),'[]'::jsonb)
  );
end;
$$;

revoke all on function public.dopmi_rescuer_dashboard() from public,anon;
grant execute on function public.dopmi_rescuer_dashboard() to authenticated;

commit;
