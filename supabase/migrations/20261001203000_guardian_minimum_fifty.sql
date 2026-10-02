begin;
-- Change new authorizations only. Historical amounts, pending intents and stable-key retries retain their original contract.
do $migration$
declare definition text; source_hash text; anchor text;
begin
  select md5(prosrc) into source_hash from pg_proc where oid='public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure;
  if source_hash<>'ef90c36f59c749419ffe8dbe6d24930c' then raise exception 'Guardian activation definition drift; inspect before migration'; end if;
  definition:=pg_get_functiondef('public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure);
  anchor:=' if exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=donor)';
  if length(definition)-length(replace(definition,anchor,''))<>length(anchor) then raise exception 'Guardian activation anchor mismatch'; end if;
  execute replace(definition,anchor,' if gross<5000 then raise exception ''El mínimo Guardián es $50 MXN'' using errcode=''22023''; end if;'||chr(10)||anchor);
  select md5(prosrc) into source_hash from pg_proc where oid='public.dopmi_guardian_request(text,uuid,bigint,bigint,text)'::regprocedure;
  if source_hash<>'e4f6b6f18b6ee503b9aba8f72c2e6f98' then raise exception 'Guardian request definition drift; inspect before migration'; end if;
  definition:=pg_get_functiondef('public.dopmi_guardian_request(text,uuid,bigint,bigint,text)'::regprocedure);
  anchor:=' if p.management_revision<>expected_revision';
  if length(definition)-length(replace(definition,anchor,''))<>length(anchor) then raise exception 'Guardian request anchor mismatch'; end if;
  execute replace(definition,anchor,' if request_kind=''amount'' and new_gross_cents<5000 then raise exception ''El mínimo Guardián es $50 MXN'' using errcode=''22023''; end if;'||chr(10)||anchor);
end $migration$;
commit;
