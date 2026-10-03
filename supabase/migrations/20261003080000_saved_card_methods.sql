begin;

create table private.dopmi_saved_card_method_jobs (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete restrict,
 wallet_id uuid not null references private.dopmi_saved_card_customers(id),
 request_key uuid not null,
 action text not null check(action in ('default','remove')),
 selected_method_id text not null check(selected_method_id ~ '^pm_[A-Za-z0-9]+$'),
 customer_id text not null check(customer_id ~ '^cus_[A-Za-z0-9]+$'),
 consent_version text not null check(consent_version='saved-card-methods-2026-10-03'),
 status text not null default 'pending' check(status in ('pending','applied','removed','refused','expired','attention')),
 default_method_id text check(default_method_id ~ '^pm_[A-Za-z0-9]+$'),
 snapshot_at timestamptz,
 mutation_requested_at timestamptz,
 payment_method_id text check(payment_method_id ~ '^pm_[A-Za-z0-9]+$'),
 expires_at timestamptz not null default now()+interval '35 minutes',
 lease uuid, lease_until timestamptz,
 attempts integer not null default 0,
 checked_at timestamptz not null default now(),
 created_at timestamptz not null default now(),
 unique(owner_id,request_key),
 check(status not in ('applied','removed') or (payment_method_id is not null and payment_method_id=selected_method_id))
);
create index dopmi_saved_card_method_pending on private.dopmi_saved_card_method_jobs(checked_at,id) where status='pending';
alter table private.dopmi_saved_card_method_jobs enable row level security;
revoke all on private.dopmi_saved_card_method_jobs from public,anon,authenticated;

create function public.dopmi_saved_card_method_server(operation text,data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare j private.dopmi_saved_card_method_jobs; w private.dopmi_saved_card_customers;
 actor uuid; requested uuid;
begin
 if operation='prepare' then
  actor:=(data->>'owner_id')::uuid; requested:=(data->>'key')::uuid;
  if actor is null or requested is null or data->>'consent' is distinct from 'true'
   or data->>'consent_version' is distinct from 'saved-card-methods-2026-10-03'
   or coalesce(data->>'action','') not in ('default','remove')
   or coalesce(data->>'selected_method_id','') !~ '^pm_[A-Za-z0-9]+$' then
   raise exception 'Autorización de tarjeta requerida' using errcode='22023'; end if;
  if not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
   where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
   raise exception 'Cuenta no disponible' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
  select * into j from private.dopmi_saved_card_method_jobs where owner_id=actor and request_key=requested;
  if found then
   if j.action is distinct from data->>'action' or j.selected_method_id is distinct from data->>'selected_method_id' then
    raise exception 'La solicitud cambió' using errcode='22023'; end if;
   return to_jsonb(j);
  end if;
  if exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=actor)
   or exists(select 1 from private.dopmi_guardian_activations where donor_id=actor and status in ('pending','settled','attention')) then
   raise exception 'Consulta tu medio de Guardián' using errcode='55000'; end if;
  if exists(select 1 from private.dopmi_saved_card_jobs where owner_id=actor and status in ('pending','attention'))
   or exists(select 1 from private.dopmi_saved_card_method_jobs where owner_id=actor and status in ('pending','attention')) then
   raise exception 'Solicitud de tarjeta pendiente' using errcode='55000'; end if;
  if (select count(*) from private.dopmi_saved_card_method_jobs where owner_id=actor and created_at>now()-interval '1 hour')>=10 then
   raise exception 'Espera antes de cambiar otra tarjeta' using errcode='55000'; end if;
  select * into w from private.dopmi_saved_card_customers where owner_id=actor;
  if not found or w.stripe_customer_id is null then
   raise exception 'Tarjeta no disponible' using errcode='22023'; end if;
  insert into private.dopmi_saved_card_method_jobs(owner_id,wallet_id,request_key,action,selected_method_id,customer_id,consent_version)
   values(actor,w.id,requested,data->>'action',data->>'selected_method_id',w.stripe_customer_id,'saved-card-methods-2026-10-03') returning * into j;
 elsif operation='candidates' then
  return coalesce((select jsonb_agg(x) from (select id from private.dopmi_saved_card_method_jobs
   where status='pending' and coalesce(lease_until,now())<=now() order by checked_at,id limit 25)x),'[]');
 else
  select owner_id into actor from private.dopmi_saved_card_method_jobs where id=(data->>'id')::uuid;
  if actor is null then raise exception 'Solicitud no disponible' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
  select * into j from private.dopmi_saved_card_method_jobs where id=(data->>'id')::uuid for update;
  if operation='claim' then
   if j.status<>'pending' or j.lease_until>now() then return null; end if;
   if not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then return null; end if;
   if j.mutation_requested_at<now()-interval '23 hours' or (j.mutation_requested_at is null and j.attempts>=8) then
    update private.dopmi_saved_card_method_jobs set status='attention' where id=j.id; return null; end if;
   if j.mutation_requested_at is null and j.expires_at<=now() then
    update private.dopmi_saved_card_method_jobs set status='expired' where id=j.id; return null; end if;
   update private.dopmi_saved_card_method_jobs set lease=gen_random_uuid(),lease_until=now()+interval '2 minutes',
    attempts=attempts+1 where id=j.id returning * into j;
  elsif operation='release' then
   update private.dopmi_saved_card_method_jobs set lease_until=null,checked_at=now()
    where id=j.id and lease=(data->>'lease')::uuid returning * into j;
   if not found then select * into j from private.dopmi_saved_card_method_jobs where id=(data->>'id')::uuid; end if;
  elsif operation<>'get' then
   if j.status<>'pending' or j.lease is distinct from (data->>'lease')::uuid or j.lease_until is null or j.lease_until<=now() then
    raise exception 'Intento de tarjeta vencido' using errcode='40001'; end if;
   if operation='snapshot' then
    if j.mutation_requested_at is not null or (j.snapshot_at is not null and j.default_method_id is distinct from data->>'default_method_id') then
     raise exception 'Estado de tarjeta cambió' using errcode='22023'; end if;
    update private.dopmi_saved_card_method_jobs set default_method_id=data->>'default_method_id',snapshot_at=coalesce(snapshot_at,now()) where id=j.id;
   elsif operation='write_mutation' then
    if j.snapshot_at is null then raise exception 'Tarjeta no verificada' using errcode='22023'; end if;
    if j.mutation_requested_at is null and j.expires_at<=now() then
     update private.dopmi_saved_card_method_jobs set status='expired' where id=j.id; return null; end if;
    if not exists(select 1 from public.profiles p join auth.users u on u.id=p.id where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null)
     or exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=actor)
     or exists(select 1 from private.dopmi_guardian_activations where donor_id=actor and status in ('pending','settled','attention')) then return null; end if;
    update private.dopmi_saved_card_method_jobs set mutation_requested_at=coalesce(mutation_requested_at,now()) where id=j.id;
   elsif operation in ('applied','removed') then
    if j.snapshot_at is null or data->>'payment_method_id' is distinct from j.selected_method_id
     or (operation='removed' and (j.action<>'remove' or j.mutation_requested_at is null))
     or (operation='applied' and (j.action<>'default' or (j.mutation_requested_at is null and j.default_method_id is distinct from j.selected_method_id))) then
     raise exception 'Tarjeta no confirmada' using errcode='22023'; end if;
    update private.dopmi_saved_card_method_jobs set status=operation,payment_method_id=j.selected_method_id,lease_until=null where id=j.id;
   elsif operation in ('refused','expired') then
    if j.mutation_requested_at is not null then raise exception 'Cambio de tarjeta en revisión' using errcode='55000'; end if;
    update private.dopmi_saved_card_method_jobs set status=operation,lease_until=null where id=j.id;
   else raise exception 'Operación de tarjeta inválida' using errcode='22023'; end if;
   select * into j from private.dopmi_saved_card_method_jobs where id=j.id;
  end if;
 end if;
 return to_jsonb(j);
end;
$$;
revoke all on function public.dopmi_saved_card_method_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_saved_card_method_server(text,jsonb) to service_role;

create function public.dopmi_saved_card_method_state() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
  where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
  raise exception 'Cuenta no disponible' using errcode='42501'; end if;
 return (select jsonb_build_object('key',request_key,'action',action,'status',status,'card_id',selected_method_id)
  from private.dopmi_saved_card_method_jobs where owner_id=actor order by created_at desc,id desc limit 1);
end;
$$;
revoke all on function public.dopmi_saved_card_method_state() from public,anon;
grant execute on function public.dopmi_saved_card_method_state() to authenticated;

do $patch$
declare definition text; old_text text; new_text text;
begin
 definition:=pg_get_functiondef('public.dopmi_saved_card_server(text,jsonb)'::regprocedure);
 old_text:=$code$if exists(select 1 from private.dopmi_saved_card_jobs where owner_id=actor and status in ('pending','attention')) then$code$;
 new_text:=$code$if exists(select 1 from private.dopmi_saved_card_method_jobs where owner_id=actor and status in ('pending','attention')) then
 raise exception 'Cambio de tarjeta pendiente' using errcode='55000'; end if;
 if exists(select 1 from private.dopmi_saved_card_jobs where owner_id=actor and status in ('pending','attention')) then$code$;
 if position(old_text in definition)=0 then raise exception 'Review setup method guard'; end if;
 execute replace(definition,old_text,new_text);
 definition:=pg_get_functiondef('public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure);
 old_text:=$code$held:=public.dopmi_guardian_reserve(donor,requested_key,gross);$code$;
 new_text:=$code$if exists(select 1 from private.dopmi_saved_card_method_jobs where owner_id=donor and status in ('pending','attention')) then
 raise exception 'Termina el cambio de tarjeta antes de activar Guardián' using errcode='55000'; end if;
 held:=public.dopmi_guardian_reserve(donor,requested_key,gross);$code$;
 if position(old_text in definition)=0 then raise exception 'Review activation method guard'; end if;
 execute replace(definition,old_text,new_text);
end $patch$;
commit;
