begin;

-- Signed Connect account.updated notifications share the existing durable
-- worker queue. Only these immutable identifiers are retained; Stripe's body
-- and its private Account data never enter the job payload.
create function private.dopmi_connect_account_event_enqueue(data jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare event_id text; account_id text; event_payload jsonb; job private.dopmi_payment_jobs;
begin
  if jsonb_typeof(data) is distinct from 'object' then
    raise exception 'Contexto de evento Connect inválido' using errcode='22023';
  end if;
  if jsonb_typeof(data->'event_id') is distinct from 'string' or
      jsonb_typeof(data->'event_account') is distinct from 'string' or
      data-'event_id'-'event_account'<>'{}'::jsonb then
    raise exception 'Contexto de evento Connect inválido' using errcode='22023';
  end if;
  event_id:=data->>'event_id'; account_id:=data->>'event_account';
  if length(event_id)>160 or event_id!~'^evt_[A-Za-z0-9]+$' or
      length(account_id)>160 or account_id!~'^acct_[A-Za-z0-9]+$' then
    raise exception 'Contexto de evento Connect inválido' using errcode='22023';
  end if;
  -- The same lock also covers the legacy enqueue route below. A competing
  -- receiver cannot silently reuse one event ID under a different scope.
  perform pg_advisory_xact_lock(hashtextextended('dopmi-payment-event:'||event_id,0));
  event_payload:=jsonb_build_object('event_id',event_id,'event_account',account_id,
    'event_scope','connect_account_updated');
  insert into private.dopmi_payment_jobs(job_key,kind,payload)
    values(event_id,'event',event_payload) on conflict(job_key) do nothing;
  select * into job from private.dopmi_payment_jobs where job_key=event_id for update;
  if job.kind is distinct from 'event' or job.donation_id is not null or
      job.payload is distinct from event_payload then
    raise exception 'Contexto de evento Connect distinto' using errcode='22023';
  end if;
  return '{}'::jsonb;
end $$;
revoke all on function private.dopmi_connect_account_event_enqueue(jsonb) from public,anon,authenticated,service_role;

-- Patch the current dispatcher in place. Preserve its PendingStripe lock and
-- promotion logic, legal admission, wrapper identity, ownership and ACLs.
do $patch$
declare
  definition text:=pg_get_functiondef('public.dopmi_payment_server(text,jsonb)'::regprocedure);
  anchor constant text:='result:=public.dopmi_payment_server_before_pending_stripe(operation,data);';
  admission constant text:=$block$
  if operation='connect_event_enqueue' then
    return private.dopmi_connect_account_event_enqueue(data);
  end if;
  if operation='enqueue' then
    if data ? 'event_scope' or data ? 'event_account' then
      raise exception 'Contexto de evento Connect inválido' using errcode='22023';
    end if;
    perform pg_advisory_xact_lock(hashtextextended('dopmi-payment-event:'||(data->>'event_id'),0));
    if exists(select 1 from private.dopmi_payment_jobs j where j.job_key=data->>'event_id'
      and (j.payload ? 'event_scope' or j.payload ? 'event_account')) then
      raise exception 'Contexto de evento Connect distinto' using errcode='22023';
    end if;
  end if;
  $block$;
begin
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 or
      position($marker$operation='connect_event_enqueue'$marker$ in definition)>0 then
    raise exception 'Connect event dispatcher anchor changed: review patch';
  end if;
  execute replace(definition,anchor,admission||anchor);
end $patch$;

-- CREATE OR REPLACE retains the service-only public gate. The helper remains
-- callable only under the dispatcher's owner, never directly by API roles.
do $$ begin
  if has_function_privilege('anon','public.dopmi_payment_server(text,jsonb)','EXECUTE') or
      has_function_privilege('authenticated','public.dopmi_payment_server(text,jsonb)','EXECUTE') or
      not has_function_privilege('service_role','public.dopmi_payment_server(text,jsonb)','EXECUTE') or
      has_function_privilege('anon','private.dopmi_connect_account_event_enqueue(jsonb)','EXECUTE') or
      has_function_privilege('authenticated','private.dopmi_connect_account_event_enqueue(jsonb)','EXECUTE') or
      has_function_privilege('service_role','private.dopmi_connect_account_event_enqueue(jsonb)','EXECUTE') then
    raise exception 'Connect event dispatcher ACL changed: review patch';
  end if;
end $$;

commit;
