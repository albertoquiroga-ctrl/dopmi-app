begin;

create function public.dopmi_rescuer_dashboard() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
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
      'assigned_cents',(select coalesce(sum(allocated_cents),0) from public.dopmi_donations where rescuer_id=actor and payment_status='confirmed'),
      'transferred_cents',(select coalesce(sum(allocated_cents),0) from public.dopmi_donations where rescuer_id=actor and transfer_status='transferred' and stripe_transfer_id is not null),
      'in_review_cents',(select coalesce(sum(allocated_cents),0) from public.dopmi_donations where rescuer_id=actor and payment_status='confirmed' and transfer_status in ('not_started','pending','attention'))
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
      select d.expense_id,d.expense_title,d.allocated_cents,d.transfer_status,d.created_at
      from public.dopmi_donations d
      where d.rescuer_id=actor and d.payment_status='confirmed' and d.allocated_cents>0
      order by d.created_at desc,d.id limit 6
    ) x),'[]'::jsonb)
  );
end;
$$;

revoke all on function public.dopmi_rescuer_dashboard() from public,anon;
grant execute on function public.dopmi_rescuer_dashboard() to authenticated;

commit;
