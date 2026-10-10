begin;

alter table private.dopmi_saved_card_jobs add column wallet_type text
  check(wallet_type in ('apple_pay','google_pay'));
create unique index dopmi_saved_card_setup_unique on private.dopmi_saved_card_jobs(setup_intent_id)
  where setup_intent_id is not null;

-- Preserve the normal Checkout completion constraint, while a native wallet
-- completes against its durably reserved SetupIntent without a Checkout Session.
do $constraints$
declare name text;
begin
 select conname into name from pg_constraint
 where conrelid='private.dopmi_saved_card_jobs'::regclass and contype='c'
   and pg_get_constraintdef(oid) like '%status%session_id%setup_intent_id%payment_method_id%';
 if name is null then raise exception 'Review saved-card completion constraint'; end if;
 execute format('alter table private.dopmi_saved_card_jobs drop constraint %I',name);
end $constraints$;
alter table private.dopmi_saved_card_jobs add constraint dopmi_saved_card_flow_check
  check(wallet_type is null or session_id is null);
alter table private.dopmi_saved_card_jobs add constraint dopmi_saved_card_completion_check
  check(status<>'saved' or (setup_intent_id is not null and payment_method_id is not null
    and (wallet_type is not null or session_id is not null)));

do $patch$
declare definition text; old_text text; new_text text;
begin
 definition:=pg_get_functiondef('public.dopmi_saved_card_server(text,jsonb)'::regprocedure);
 old_text:=$code$or coalesce(data->>'return_url','') !~ '^https://[A-Za-z0-9.-]+/functions/v1/payment-return$' then$code$;
 new_text:=$code$or (data->>'wallet_type' is not null and data->>'wallet_type' not in ('apple_pay','google_pay'))
      or coalesce(data->>'return_url','') !~ '^https://[A-Za-z0-9.-]+/functions/v1/payment-return$' then$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet provider input'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$if j.return_url is distinct from data->>'return_url' then$code$;
 new_text:=$code$if j.return_url is distinct from data->>'return_url' or j.wallet_type is distinct from data->>'wallet_type' then$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet replay'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,return_url)
      values(actor,requested,w.id,'saved-cards-2026-10-03',customer,data->>'return_url')$code$;
 new_text:=$code$insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,return_url,wallet_type)
      values(actor,requested,w.id,'saved-cards-2026-10-03',customer,data->>'return_url',data->>'wallet_type')$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet reservation'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$where status='pending' and coalesce(lease_until,now())<=now() order by checked_at,id limit 25$code$;
 new_text:=$code$where wallet_type is null and status='pending' and coalesce(lease_until,now())<=now() order by checked_at,id limit 25$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet queue separation'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$select * into j from private.dopmi_saved_card_jobs where id=(data->>'id')::uuid for update;$code$;
 new_text:=$code$select owner_id into actor from private.dopmi_saved_card_jobs where id=(data->>'id')::uuid;
    if actor is null then raise exception 'Alta de tarjeta no disponible' using errcode='22023'; end if;
    perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
    select * into j from private.dopmi_saved_card_jobs where id=(data->>'id')::uuid for update;$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet transition lock'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$if j.session_id is null and (j.attempts>=8$code$;
 new_text:=$code$if j.session_id is null and j.setup_intent_id is null and (j.attempts>=8$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet retry window'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$if j.session_id is null and j.attempts=0 and j.expires_at<now()+interval '30 minutes' then$code$;
 new_text:=$code$if j.wallet_type is null and j.session_id is null and j.attempts=0 and j.expires_at<now()+interval '30 minutes' then$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet reconciliation deadline'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$attempts=attempts+case when session_id is null then 1 else 0 end$code$;
 new_text:=$code$attempts=attempts+case when session_id is null and setup_intent_id is null then 1 else 0 end$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet attempt counting'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$or j.lease_until<=now() then$code$;
 new_text:=$code$or j.lease_until is null or j.lease_until<=now() then$code$;
 if position(old_text in definition)=0 then raise exception 'Review released wallet lease'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$if operation='customer' then$code$;
 new_text:=$code$if j.wallet_type is not null and operation in ('session','saved','expired') then
        raise exception 'Usa el comprobante nativo de billetera' using errcode='22023'; end if;
      if operation='customer' then$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet flow boundary'; end if;
 execute replace(definition,old_text,new_text);

 -- Normal device recovery must never adopt a native wallet intent as Checkout.
 definition:=pg_get_functiondef('public.dopmi_saved_card_state()'::regprocedure);
 old_text:=$code$where owner_id=actor order by created_at desc,id desc limit 1$code$;
 new_text:=$code$where owner_id=actor and wallet_type is null order by created_at desc,id desc limit 1$code$;
 if position(old_text in definition)=0 then raise exception 'Review wallet receipt separation'; end if;
 execute replace(definition,old_text,new_text);

 -- A native wallet and a Guardian method change reserve the same owner lock.
 definition:=pg_get_functiondef('public.dopmi_guardian_method_server(text,jsonb)'::regprocedure);
 old_text:=$code$select * into p from private.dopmi_guardian_subscriptions where donor_id=actor for update;$code$;
 new_text:=$code$perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
 select * into p from private.dopmi_guardian_subscriptions where donor_id=actor for update;$code$;
 if position(old_text in definition)=0 then raise exception 'Review Guardian wallet lock'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:=$code$if private.dopmi_guardian_method_pending(p.stripe_subscription_id)$code$;
 new_text:=$code$if exists(select 1 from private.dopmi_saved_card_jobs where owner_id=actor
   and wallet_type is not null and status in ('pending','attention'))
 or private.dopmi_guardian_method_pending(p.stripe_subscription_id)$code$;
 if position(old_text in definition)=0 then raise exception 'Review Guardian wallet guard'; end if;
 execute replace(definition,old_text,new_text);
end $patch$;

create function public.dopmi_saved_wallet_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.dopmi_saved_card_jobs; actor uuid; requested_setup text;
begin
 if operation='candidates' then
  return coalesce((select jsonb_agg(x) from (select id from private.dopmi_saved_card_jobs
   where wallet_type is not null and status='pending' and coalesce(lease_until,now())<=now()
   order by checked_at,id limit 25)x),'[]');
 elsif operation='lookup_setup' then
  return (select to_jsonb(x) from private.dopmi_saved_card_jobs x
   where wallet_type is not null and setup_intent_id=data->>'setup_intent_id');
 elsif operation='prepare' then
  actor:=(data->>'owner_id')::uuid;
  if coalesce(data->>'wallet_type','') not in ('apple_pay','google_pay') then
   raise exception 'Billetera no disponible' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
  if exists(select 1 from private.dopmi_guardian_method_jobs where donor_id=actor and status in ('pending','attention')) then
   raise exception 'Cambio de medio Guardián pendiente' using errcode='55000'; end if;
  return public.dopmi_saved_card_server('prepare',data);
 end if;
 select owner_id into actor from private.dopmi_saved_card_jobs where id=(data->>'id')::uuid;
 if actor is null then raise exception 'Billetera no disponible' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
 select * into j from private.dopmi_saved_card_jobs where id=(data->>'id')::uuid for update;
 if j.wallet_type is null then raise exception 'Usa el comprobante Checkout de tarjeta' using errcode='22023'; end if;
 if operation='native_ready' then
  if j.status<>'pending' or j.setup_intent_id is null or j.setup_intent_id is distinct from data->>'setup_intent_id'
    or j.expires_at<=now() or j.lease_until>now() or j.customer_id is null
    or not exists(select 1 from private.dopmi_saved_card_customers w where w.id=j.wallet_id and w.owner_id=actor
     and (w.stripe_customer_id is null or w.stripe_customer_id=j.customer_id))
    or exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=actor and stripe_customer_id<>j.customer_id)
    or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
     where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null)
    or exists(select 1 from private.dopmi_saved_card_method_jobs where owner_id=actor and status in ('pending','attention'))
    or exists(select 1 from private.dopmi_guardian_method_jobs where donor_id=actor and status in ('pending','attention'))
    or (not exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=actor)
     and exists(select 1 from private.dopmi_guardian_activations where donor_id=actor and status in ('pending','settled','attention'))) then
   return null;
  end if;
  return to_jsonb(j);
 elsif operation in ('get','claim','release','customer') then
  if operation='claim' and exists(select 1 from private.dopmi_guardian_method_jobs
    where donor_id=actor and status in ('pending','attention')) then return null; end if;
  return public.dopmi_saved_card_server(operation,data);
 elsif operation in ('native_setup','native_saved','expired') then
  if j.status<>'pending' or j.lease is distinct from (data->>'lease')::uuid or j.lease_until is null or j.lease_until<=now() then
   raise exception 'Intento de billetera vencido' using errcode='40001'; end if;
  if operation='native_setup' then
   requested_setup:=data->>'setup_intent_id';
   if j.customer_id is null or coalesce(requested_setup,'') !~ '^seti_[A-Za-z0-9]+$'
    or (j.setup_intent_id is not null and j.setup_intent_id<>requested_setup)
    or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
     where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Autorización de billetera no coincide' using errcode='22023'; end if;
   update private.dopmi_saved_card_jobs set setup_intent_id=requested_setup where id=j.id;
  elsif operation='native_saved' then
   if j.setup_intent_id is null or j.setup_intent_id is distinct from data->>'setup_intent_id'
     or coalesce(data->>'payment_method_id','') !~ '^pm_[A-Za-z0-9]+$' then
    raise exception 'Billetera no confirmada' using errcode='22023'; end if;
   update private.dopmi_saved_card_jobs set status='saved',payment_method_id=data->>'payment_method_id',lease_until=null where id=j.id;
  else
   update private.dopmi_saved_card_jobs set status='expired',lease_until=null where id=j.id;
  end if;
  select * into j from private.dopmi_saved_card_jobs where id=j.id;
  return to_jsonb(j);
 end if;
 raise exception 'Operación de billetera inválida' using errcode='22023';
end;
$$;
revoke all on function public.dopmi_saved_wallet_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_saved_wallet_server(text,jsonb) to service_role;

create function public.dopmi_saved_wallet_state() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
  where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
  raise exception 'Cuenta no disponible' using errcode='42501'; end if;
 return (select jsonb_build_object('key',request_key,'status',status,'wallet_type',wallet_type,
  'card_id',case when status='saved' then payment_method_id end)
  from private.dopmi_saved_card_jobs where owner_id=actor and wallet_type is not null
  order by created_at desc,id desc limit 1);
end;
$$;
revoke all on function public.dopmi_saved_wallet_state() from public,anon;
grant execute on function public.dopmi_saved_wallet_state() to authenticated;

commit;
