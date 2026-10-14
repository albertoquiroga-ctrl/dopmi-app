begin;
-- Only new authorizations change. Existing intents/retries, ACLs, ownership,
-- test-only payments and the assignment of the complete net remain unchanged.
do $migration$
declare signature text; definition text; old_guard text; new_guard text;
begin
  for signature, old_guard, new_guard in
    select * from (values
      ('public.dopmi_guardian_activation_server(text,jsonb)',
       ' if gross<5000 then raise exception ''El mínimo Guardián es $50 MXN'' using errcode=''22023''; end if;',
       ' if gross<2000 then raise exception ''El mínimo Guardián es $20 MXN'' using errcode=''22023''; end if;'),
      ('public.dopmi_guardian_request(text,uuid,bigint,bigint,text)',
       ' if request_kind=''amount'' and new_gross_cents<5000 then raise exception ''El mínimo Guardián es $50 MXN'' using errcode=''22023''; end if;',
       ' if request_kind=''amount'' and new_gross_cents<2000 then raise exception ''El mínimo Guardián es $20 MXN'' using errcode=''22023''; end if;')
    ) as guards(signature, old_guard, new_guard)
  loop
    definition := pg_get_functiondef(signature::regprocedure);
    if length(definition)-length(replace(definition,old_guard,'')) <> length(old_guard) then
      raise exception 'Guardian minimum guard drift: inspect % before migration', signature;
    end if;
    execute replace(definition,old_guard,new_guard);
  end loop;
end $migration$;
commit;
