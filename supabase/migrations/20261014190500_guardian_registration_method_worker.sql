begin;

-- Add server-only discovery without changing the reviewed registration RPC.
-- No new timer: payment-worker uses its existing reconciliation invocation.
do $worker$
declare definition text;
  anchor text:='if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id';
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_registration_server(text,jsonb)'::regprocedure);
  if position(anchor in definition)=0 then raise exception 'Review registration worker anchor'; end if;
  execute replace(definition,anchor,$replacement$if operation='method_candidates' then
    return coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'owner_id',c.owner_id))
      from (select reg.id,reg.owner_id from private.dopmi_guardian_registrations reg
        join public.profiles p on p.id=reg.owner_id and p.account_status='active'
        join auth.users u on u.id=reg.owner_id and u.email_confirmed_at is not null
        join private.dopmi_saved_card_jobs job on job.owner_id=reg.owner_id and job.request_key=reg.id
        where reg.status='method_pending' and job.owner_id=reg.owner_id and job.request_key=reg.id
          and job.status='saved' and job.customer_id is not null
          and job.setup_intent_id is not null and job.payment_method_id is not null
        order by reg.registered_at,reg.id limit 20) c),'[]'::jsonb);
  end if;
  if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id$replacement$);
end $worker$;

-- CREATE OR REPLACE preserves the original server-only ACL; assert it here.
do $$ begin
  if has_function_privilege('authenticated','public.dopmi_guardian_registration_server(text,jsonb)','EXECUTE')
    or has_function_privilege('anon','public.dopmi_guardian_registration_server(text,jsonb)','EXECUTE')
    or not has_function_privilege('service_role','public.dopmi_guardian_registration_server(text,jsonb)','EXECUTE') then
    raise exception 'Registration worker ACL changed';
  end if;
end $$;
commit;
