begin;
alter table private.dopmi_guardian_method_jobs add column remove_saved boolean not null default false,
 add constraint guardian_remove_saved_target check(not remove_saved or selected_method_id is not null);

-- Removal shares the existing owner/revision/lease and collection exclusion.
do $patch$
declare definition text:=pg_get_functiondef('public.dopmi_guardian_method_server(text,jsonb)'::regprocedure); old_text text; new_text text;
begin
 old_text:=$old$or (data ? 'selected_method_id' and j.selected_method_id is distinct from data->>'selected_method_id') then$old$;
 new_text:=$new$or (data ? 'selected_method_id' and j.selected_method_id is distinct from data->>'selected_method_id')
 or (data ? 'remove_saved' and j.remove_saved is distinct from (data->>'remove_saved')::boolean) then$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian removal patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$old$insert into private.dopmi_guardian_method_jobs(donor_id,subscription_id,request_key,revision,consent_version,expires_at,return_url,selected_method_id)$old$;
 new_text:=$new$if coalesce((data->>'remove_saved')::boolean,false) and (data->>'selected_method_id') is not distinct from
 (select coalesce(p.payment_method_id,a.payment_method_id) from private.dopmi_guardian_schedule_jobs s
 join private.dopmi_guardian_activations a on a.cycle_id=s.cycle_id where s.subscription_id=p.stripe_subscription_id) then
 raise exception 'La tarjeta activa no se puede eliminar' using errcode='22023'; end if;
 insert into private.dopmi_guardian_method_jobs(donor_id,subscription_id,request_key,revision,consent_version,expires_at,return_url,selected_method_id,remove_saved)$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian removal patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$old$data->>'return_url',data->>'selected_method_id') returning * into j;$old$;
 new_text:=$new$data->>'return_url',data->>'selected_method_id',coalesce((data->>'remove_saved')::boolean,false)) returning * into j;$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian removal patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$old$elsif operation='applied' then$old$;
 new_text:=$new$elsif operation='refused_removal' then
 if not j.remove_saved or j.mutation_requested_at is not null then raise exception 'Rechazo no confirmado' using errcode='22023'; end if;
 update private.dopmi_guardian_method_jobs set status='superseded',error_code='guardian_method_in_use' where id=j.id;
 elsif operation='removed' then
 if not j.remove_saved or j.payment_method_id is null or j.mutation_requested_at is null
 or j.payment_method_id is distinct from data->>'payment_method_id' then raise exception 'Eliminación no confirmada' using errcode='22023'; end if;
 if j.payment_method_id is not distinct from (select coalesce(p.payment_method_id,a.payment_method_id)
 from private.dopmi_guardian_schedule_jobs s join private.dopmi_guardian_activations a on a.cycle_id=s.cycle_id
 where s.subscription_id=p.stripe_subscription_id) then raise exception 'Tarjeta activa' using errcode='22023'; end if;
 update private.dopmi_guardian_method_jobs set status='applied',applied_at=now(),error_code=null where id=j.id;
 elsif operation='applied' then
 if j.remove_saved then raise exception 'Operación incompatible' using errcode='22023'; end if;$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian removal patch mismatch'; end if;
 definition:=replace(definition,old_text,new_text);
 execute definition;
 definition:=pg_get_functiondef('public.dopmi_guardian_state()'::regprocedure);
 old_text:=$old$'key',j.request_key,'revision',j.revision-1,'status',j.status$old$;
 new_text:=$new$'key',j.request_key,'revision',j.revision-1,'status',j.status,
 'action',case when j.remove_saved then 'remove' when j.selected_method_id is not null then 'default' else 'setup' end,
 'reason',case when j.error_code='guardian_method_in_use' then 'in_use' else null end$new$;
 if strpos(definition,old_text)=0 then raise exception 'Guardian removal projection mismatch'; end if;
 execute replace(definition,old_text,new_text);
end; $patch$;
commit;
