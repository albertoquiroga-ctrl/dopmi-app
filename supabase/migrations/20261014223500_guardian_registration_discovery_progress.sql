begin;

-- Unresolved sends belong to payment reconciliation, never preparation.
-- Filter before LIMIT so uncertain owners cannot starve eligible registrations.
do $patch$
declare definition text; anchor text := 'where reg.status=''registered'' and reg.registered_at<=now()';
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_registration_attempt_server(text,jsonb)'::regprocedure);
  if position(anchor in definition)=0 then raise exception 'Review preparation discovery anchor'; end if;
  execute replace(definition,anchor,anchor||$code$
        and not exists(select 1 from private.dopmi_guardian_registration_attempts att
          where att.registration_id=reg.id and att.pay_requested_at is not null
            and att.resolved_at is null)$code$);
end $patch$;

commit;
