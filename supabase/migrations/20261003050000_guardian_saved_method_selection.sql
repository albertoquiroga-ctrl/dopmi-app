begin;
alter table private.dopmi_guardian_method_jobs add column selected_method_id text check(selected_method_id ~ '^pm_[A-Za-z0-9]+$');

-- Preserve the existing lock, ownership, revision, collection and retry guards.
do $patch$
declare definition text:=pg_get_functiondef('public.dopmi_guardian_method_server(text,jsonb)'::regprocedure); old_text text; new_text text;
begin
 old_text:=$old$if j.revision-1 is distinct from (data->>'revision')::bigint then$old$;
 new_text:=$new$if j.revision-1 is distinct from (data->>'revision')::bigint or (data ? 'selected_method_id' and j.selected_method_id is distinct from data->>'selected_method_id') then$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian method patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$old$insert into private.dopmi_guardian_method_jobs(donor_id,subscription_id,request_key,revision,consent_version,expires_at,return_url)$old$;
 new_text:=$new$insert into private.dopmi_guardian_method_jobs(donor_id,subscription_id,request_key,revision,consent_version,expires_at,return_url,selected_method_id)$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian method patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$old$date_trunc('second',now())+interval '35 minutes',data->>'return_url') returning * into j;$old$;
 new_text:=$new$date_trunc('second',now())+interval '35 minutes',data->>'return_url',data->>'selected_method_id') returning * into j;$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian method patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$old$elsif operation='verified' then$old$;
 new_text:=$new$elsif operation='expire_saved' then
 if j.selected_method_id is null or j.expires_at>now() or j.mutation_requested_at is not null then raise exception 'Vencimiento no confirmado' using errcode='22023'; end if;
 update private.dopmi_guardian_method_jobs set status='expired' where id=j.id;
 elsif operation='verified_saved' then
 if j.selected_method_id is null or j.selected_method_id is distinct from data->>'payment_method_id' or j.session_id is not null or j.setup_intent_id is not null then
 raise exception 'Medio guardado no verificado' using errcode='22023'; end if;
 update private.dopmi_guardian_method_jobs set payment_method_id=j.selected_method_id where id=j.id;
 elsif operation='verified' then$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian method patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$old$if j.setup_intent_id is null or j.payment_method_id is null or j.mutation_requested_at is null$old$;
 new_text:=$new$if (j.setup_intent_id is null and j.selected_method_id is null) or j.payment_method_id is null or j.mutation_requested_at is null$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian method patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$old$if j.payment_method_id is null or j.billing_anchor is null then raise exception 'Medio no verificado' using errcode='22023'; end if;$old$;
 new_text:=$new$if j.selected_method_id is not null and j.mutation_requested_at is null and j.expires_at<=now() then
 update private.dopmi_guardian_method_jobs set status='expired' where id=j.id; return null; end if;
 if j.payment_method_id is null or j.billing_anchor is null then raise exception 'Medio no verificado' using errcode='22023'; end if;$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian method patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 execute definition;
end; $patch$;
commit;
