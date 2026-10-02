begin;

-- Keep the other participant's messages and moderation/payment evidence. The
-- deleted owner's authored text is replaced and every retained object stays
-- unavailable because the profile is no longer active.
do $patch$
declare
  definition text:=pg_get_functiondef('public.dopmi_account_deletion_server(text,jsonb)'::regprocedure);
  old_text text;
  new_text text;
begin
  old_text:=$old$
    delete from public.dopmi_rescuer_profiles where owner_id=owner;
    delete from public.dopmi_adoptions where owner_id=owner;
    delete from public.dopmi_rescue_records r where r.owner_id=owner
      and not exists(select 1 from public.dopmi_donations d where d.expense_id=r.id);$old$;
  new_text:=$new$
    delete from public.dopmi_rescuer_profiles where owner_id=owner;
    update public.dopmi_adoptions set pet_name='Publicación retirada',breed='',city='',region='',
      story='',special_care='',publisher_name='Cuenta eliminada',publisher_bio='',photos='{}',
      status='archived',review_feedback='',updated_at=now() where owner_id=owner;
    update public.dopmi_rescue_records set status=case
        when kind<>'expense' or not exists(select 1 from public.dopmi_donations d where d.expense_id=dopmi_rescue_records.id)
          then 'closed' else status end,
      public_data=case when kind<>'expense' or not exists(select 1 from public.dopmi_donations d where d.expense_id=dopmi_rescue_records.id)
          then '{}'::jsonb else public_data end,
      private_data=case when kind<>'expense' or not exists(select 1 from public.dopmi_donations d where d.expense_id=dopmi_rescue_records.id)
          then '{}'::jsonb else private_data end,
      files=case when kind<>'expense' or not exists(select 1 from public.dopmi_donations d where d.expense_id=dopmi_rescue_records.id)
          then '[]'::jsonb else files end,
      feedback='',updated_at=now()
      where owner_id=owner;$new$;
  if position(old_text in definition)=0 then raise exception 'Review account deletion content cleanup before migration'; end if;
  execute replace(definition,old_text,new_text);
end $patch$;

commit;
