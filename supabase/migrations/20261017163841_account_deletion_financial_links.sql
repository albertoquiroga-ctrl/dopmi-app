begin;
-- Account deletion withdraws public access but retains financial evidence. A
-- case payment has no expense anchor: its private allocations, and Guardian's,
-- are historic links even after a confirmed full reversal. Never infer retention
-- from the currently funded amount or change the funded-expense safety trigger.
do $patch$
declare
 definition text:=pg_get_functiondef('public.dopmi_account_deletion_server(text,jsonb)'::regprocedure);
 anchor text:='not exists(select 1 from public.dopmi_donations d where d.expense_id=dopmi_rescue_records.id)';
 replacement text:='not (exists(select 1 from public.dopmi_donations d where d.expense_id=dopmi_rescue_records.id)
          or exists(select 1 from private.dopmi_case_allocations a where a.expense_id=dopmi_rescue_records.id)
          or exists(select 1 from private.dopmi_guardian_allocations a where a.expense_id=dopmi_rescue_records.id))';
 occurrences integer;
begin
 occurrences:=(length(definition)-length(replace(definition,anchor,'')))/length(anchor);
 if occurrences<>4 then raise exception 'Review four account deletion financial retention conditions'; end if;
 execute replace(definition,anchor,replacement);
end $patch$;
commit;
