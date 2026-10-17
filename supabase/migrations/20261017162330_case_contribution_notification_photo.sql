begin;
-- Keep event identities, cohort gates, history destinations and read semantics.
-- Case donations intentionally have no anchor expense; resolve their own case.
do $patch$
declare definition text;
  anchor text := 'select parent_id into case_id from public.dopmi_rescue_records where id=new.expense_id;';
begin
  definition := pg_get_functiondef('private.dopmi_contribution_notification()'::regprocedure);
  if position(anchor in definition)=0 then
    raise exception 'Review case contribution notification anchor';
  end if;
  execute replace(definition, anchor,
    'select coalesce(new.case_id,parent_id) into case_id from public.dopmi_rescue_records where id=coalesce(new.expense_id,new.case_id);');
end $patch$;
commit;
