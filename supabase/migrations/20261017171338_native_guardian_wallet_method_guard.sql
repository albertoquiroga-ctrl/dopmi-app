begin;
-- Native registration uses a saved SetupIntent method rather than Stripe
-- subscription/customer defaults. Keep that authorization and any sent attempt
-- protected by the same owner lock as independent wallet mutations.
create function private.dopmi_native_guardian_uses_method(actor uuid,target_method text default null)
returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from private.dopmi_guardian_registrations r
  where r.owner_id=actor and r.status<>'canceled' and (target_method is null or exists(
   select 1 from private.dopmi_saved_card_jobs j where j.owner_id=actor and j.payment_method_id=target_method
    and ((j.id=r.method_job_id and private.dopmi_registration_method_valid(r.id,actor,j.id))
      or (r.status='method_pending' and j.request_key=r.id and j.status='saved')))))
 or exists(select 1 from private.dopmi_guardian_registration_method_changes m
  join private.dopmi_guardian_registrations r on r.id=m.registration_id and r.owner_id=m.owner_id
  join private.dopmi_saved_card_jobs j on j.request_key=m.id and j.owner_id=m.owner_id
  where m.owner_id=actor and m.status='pending' and r.status='registered'
   and r.revision=m.registration_revision and j.status='saved'
   and (target_method is null or j.payment_method_id=target_method))
 or exists(select 1 from private.dopmi_guardian_registration_attempts a
  where a.owner_id=actor and a.pay_requested_at is not null and a.resolved_at is null
   and (target_method is null or a.payment_method_id=target_method));
$$;
revoke all on function private.dopmi_native_guardian_uses_method(uuid,text) from public,anon,authenticated,service_role;

do $patch$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('public.dopmi_saved_card_method_server(text,jsonb)'::regprocedure);
 anchor:='if private.dopmi_guardian_blocks_saved_method(actor)';
 if position(anchor in definition)=0 then raise exception 'Review native wallet prepare target guard'; end if;
 definition:=replace(definition,anchor,anchor||'
   or (data->>''action''=''remove'' and private.dopmi_native_guardian_uses_method(actor,data->>''selected_method_id''))');
 anchor:='or private.dopmi_guardian_blocks_saved_method(actor)';
 -- The prepare expression above contains "if", so this anchor is only prewrite.
 if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 then
  raise exception 'Review native wallet prewrite target guard'; end if;
 definition:=replace(definition,anchor,anchor||'
     or (j.action=''remove'' and private.dopmi_native_guardian_uses_method(actor,j.selected_method_id))');
 anchor:='if operation=''claim'' then';
 if position(anchor in definition)=0 then raise exception 'Review native wallet usage lease anchor'; end if;
 execute replace(definition,anchor,$replacement$if operation='native_usage' then
   if j.status<>'pending' or j.lease is distinct from (data->>'lease')::uuid
    or j.lease_until is null or j.lease_until<=now() then
    raise exception 'Intento de tarjeta vencido' using errcode='40001'; end if;
   return jsonb_build_object('in_use',j.action='remove' and private.dopmi_native_guardian_uses_method(actor,j.selected_method_id));
  elsif operation='claim' then$replacement$);

 -- A saved method must not be adopted after an independently authorized
 -- detach has started. Both paths acquire the same owner lock. A merely
 -- prepared wallet job is allowed to reconcile/refuse before adoption; a sent
 -- removal permanently cancels this change so stale saved proof cannot return.
 definition:=pg_get_functiondef('public.dopmi_guardian_registration_method_server(text,jsonb)'::regprocedure);
 anchor:='elsif j.status=''saved'' and j.setup_intent_id is not null and j.payment_method_id is not null and j.customer_id is not null and j.wallet_type=''card'' then';
 if position(anchor in definition)=0 then raise exception 'Review native method adoption removal guard'; end if;
 execute replace(definition,anchor,anchor||$adoption$
   if exists(select 1 from private.dopmi_saved_card_method_jobs w
    where w.owner_id=actor and w.action='remove' and w.selected_method_id=j.payment_method_id
     and ((w.status in ('pending','attention') and w.mutation_requested_at is not null)
       or (w.status='removed' and w.mutation_requested_at>=j.created_at))) then
    update private.dopmi_guardian_registration_method_changes set status='canceled' where id=m.id returning * into m;
    return to_jsonb(m);
   elsif exists(select 1 from private.dopmi_saved_card_method_jobs w
    where w.owner_id=actor and w.action='remove' and w.selected_method_id=j.payment_method_id
      and w.status in ('pending','attention')) then
    return to_jsonb(m);
   end if;$adoption$);

 definition:=pg_get_functiondef('public.dopmi_saved_card_owner_server(uuid)'::regprocedure);
 anchor:='return jsonb_build_object(''customer_id'',customer,''subscription_id'',subscription);';
 if position(anchor in definition)=0 then raise exception 'Review native method owner list anchor'; end if;
 -- Coherence is checked before returning the internal method ID. Only the
 -- trusted service receives it; public clients see minimized provider fields.
 execute replace(definition,anchor,$replacement$if exists(select 1 from private.dopmi_guardian_registrations r
    join private.dopmi_saved_card_jobs j on j.id=r.method_job_id
    where r.owner_id=target_actor and r.status='registered'
      and (not private.dopmi_registration_method_valid(r.id,target_actor,j.id)
        or j.customer_id is distinct from customer)) then
    raise exception 'Método del registro en revisión' using errcode='55000'; end if;
  return jsonb_build_object('customer_id',customer,'subscription_id',subscription,
   'registration_method_id',(select j.payment_method_id from private.dopmi_guardian_registrations r
    join private.dopmi_saved_card_jobs j on j.id=r.method_job_id
    where r.owner_id=target_actor and r.status='registered'
      and private.dopmi_registration_method_valid(r.id,target_actor,j.id)));$replacement$);
end $patch$;
commit;
