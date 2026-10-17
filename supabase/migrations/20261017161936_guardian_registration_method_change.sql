begin;
create table private.dopmi_guardian_registration_method_changes (
 id uuid primary key default gen_random_uuid(),
 registration_id uuid not null references private.dopmi_guardian_registrations(id),
 owner_id uuid not null references public.profiles(id), request_key uuid not null,
 registration_revision integer not null check(registration_revision>=0),
 consent_version text not null check(consent_version='saved-cards-2026-10-03'),
 consent_at timestamptz not null default now(),
 status text not null default 'pending' check(status in ('pending','applied','expired','canceled')),
 applied_revision integer, created_at timestamptz not null default now(),
 unique(owner_id,request_key));
create unique index dopmi_registration_method_pending on private.dopmi_guardian_registration_method_changes(registration_id) where status='pending';
alter table private.dopmi_guardian_registration_method_changes enable row level security;
revoke all on private.dopmi_guardian_registration_method_changes from public,anon,authenticated,service_role;

create function private.dopmi_registration_setup_allowed(actor uuid,requested uuid)
returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from private.dopmi_guardian_registrations
  where owner_id=actor and id=requested and status='method_pending')
 or exists(select 1 from private.dopmi_guardian_registration_method_changes m
  join private.dopmi_guardian_registrations r on r.id=m.registration_id and r.owner_id=m.owner_id
  where m.owner_id=actor and m.id=requested and m.status='pending'
   and r.status='registered' and r.revision=m.registration_revision)
$$;
revoke all on function private.dopmi_registration_setup_allowed(uuid,uuid) from public,anon,authenticated,service_role;

create function private.dopmi_registration_method_valid(registration uuid,owner uuid,job uuid)
returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from private.dopmi_saved_card_jobs j where j.id=job
  and j.owner_id=owner and j.status='saved' and j.setup_intent_id is not null
  and j.customer_id is not null and j.payment_method_id is not null
  and (j.request_key=registration or exists(
   select 1 from private.dopmi_guardian_registration_method_changes m
   where m.id=j.request_key and m.registration_id=registration and m.owner_id=owner and m.status='applied')))
$$;
revoke all on function private.dopmi_registration_method_valid(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function public.dopmi_guardian_registration_method_server(operation text,data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=(data->>'owner_id')::uuid; r private.dopmi_guardian_registrations;
 m private.dopmi_guardian_registration_method_changes; j private.dopmi_saved_card_jobs;
begin
 if operation='candidates' then
  return coalesce((select jsonb_agg(to_jsonb(x)) from (select owner_id,registration_id,request_key
   from private.dopmi_guardian_registration_method_changes where status='pending' order by created_at,id limit 25)x),'[]');
 end if;
 if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
  where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
  raise exception 'Cuenta no disponible' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
 perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||actor,0));
 select * into r from private.dopmi_guardian_registrations where id=(data->>'id')::uuid and owner_id=actor for update;
 if not found then raise exception 'Registro no disponible' using errcode='42501'; end if;
 select * into m from private.dopmi_guardian_registration_method_changes
  where owner_id=actor and request_key=(data->>'key')::uuid for update;
 if found and m.registration_id<>r.id then raise exception 'La solicitud cambió' using errcode='22023'; end if;
 if operation='prepare' then
  if data->>'consent' is distinct from 'true' or data->>'consent_version' is distinct from 'saved-cards-2026-10-03'
   or data->>'key' is null or data->>'revision' is null then
   raise exception 'Autorización requerida' using errcode='22023'; end if;
  if m.id is not null then
   if m.registration_revision is distinct from (data->>'revision')::integer then
    raise exception 'La solicitud cambió' using errcode='22023'; end if;
  else
   if r.status<>'registered' or r.revision is distinct from (data->>'revision')::integer then
    raise exception 'El registro cambió' using errcode='40001'; end if;
   if exists(select 1 from private.dopmi_guardian_registration_method_changes where registration_id=r.id and status='pending') then
    raise exception 'Cambio de tarjeta pendiente' using errcode='55000'; end if;
   insert into private.dopmi_guardian_registration_method_changes(registration_id,owner_id,request_key,registration_revision,consent_version)
    values(r.id,actor,(data->>'key')::uuid,r.revision,'saved-cards-2026-10-03') returning * into m;
  end if;
 elsif operation<>'reconcile' then raise exception 'Operación inválida' using errcode='22023'; end if;
 if m.id is null then raise exception 'Cambio no disponible' using errcode='42501'; end if;
 if m.status='pending' then
  select * into j from private.dopmi_saved_card_jobs where owner_id=actor and request_key=m.id for update;
  if r.status<>'registered' or r.revision<>m.registration_revision then
   update private.dopmi_guardian_registration_method_changes set status='canceled' where id=m.id returning * into m;
  elsif j.status='saved' and j.setup_intent_id is not null and j.payment_method_id is not null and j.customer_id is not null and j.wallet_type='card' then
   update private.dopmi_guardian_registrations set method_job_id=j.id,revision=revision+1 where id=r.id returning * into r;
   update private.dopmi_guardian_registration_method_changes set status='applied',applied_revision=r.revision where id=m.id returning * into m;
  elsif j.status='expired' or (j.id is null and m.created_at<now()-interval '35 minutes') then
   update private.dopmi_guardian_registration_method_changes set status='expired' where id=m.id returning * into m;
  end if;
 end if;
 return to_jsonb(m);
end $$;
revoke all on function public.dopmi_guardian_registration_method_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_method_server(text,jsonb) to service_role;

do $patch$
declare definition text; anchor text; replacement text; target text;
begin
 definition:=pg_get_functiondef('public.dopmi_saved_native_card_server(text,jsonb)'::regprocedure);
 anchor:='not exists(select 1 from private.dopmi_guardian_registrations
      where id=requested and owner_id=actor and status=''method_pending'')';
 if position(anchor in definition)=0 then raise exception 'Review native method prepare anchor'; end if;
 definition:=replace(definition,anchor,'not private.dopmi_registration_setup_allowed(actor,requested)');
 anchor:='not exists(select 1 from private.dopmi_guardian_registrations
    where owner_id=actor and id=j.request_key and status=''method_pending'')';
 if position(anchor in definition)=0 then raise exception 'Review native method readiness anchor'; end if;
 definition:=replace(definition,anchor,'not private.dopmi_registration_setup_allowed(actor,j.request_key)');
 execute definition;

 foreach target in array array['public.dopmi_guardian_registration_evaluate(uuid)', 'public.dopmi_guardian_registration_attempt_server(text,jsonb)'] loop
  definition:=pg_get_functiondef(target::regprocedure);
  anchor:='j.request_key=r.id';
  if target like '%attempt_server%' then anchor:='request_key=r.id'; end if;
  if position(anchor in definition)=0 then raise exception 'Review registered method binding: %',target; end if;
  definition:=replace(definition,anchor,'private.dopmi_registration_method_valid(r.id,actor,r.method_job_id)');
  if target like '%attempt_server%' then
   anchor:='elsif a.customer_id<>j.customer_id or a.payment_method_id<>j.payment_method_id then';
   replacement:='elsif not exists(select 1 from private.dopmi_saved_card_jobs snapshot where snapshot.owner_id=actor
    and snapshot.customer_id=a.customer_id and snapshot.payment_method_id=a.payment_method_id
    and private.dopmi_registration_method_valid(r.id,actor,snapshot.id)) then';
   if position(anchor in definition)=0 then raise exception 'Review existing attempt method snapshot'; end if;
   definition:=replace(definition,anchor,replacement);
  end if;
  execute definition;
 end loop;
 definition:=pg_get_functiondef('public.dopmi_guardian_registration_bank_action(uuid,uuid,uuid)'::regprocedure);
 anchor:='id=r.method_job_id and owner_id=target_owner
    and request_key=r.id and status=''saved''';
 if position(anchor in definition)=0 then raise exception 'Review bank action method snapshot'; end if;
 definition:=replace(definition,anchor,'owner_id=target_owner and customer_id=a.customer_id and payment_method_id=a.payment_method_id
    and private.dopmi_registration_method_valid(r.id,target_owner,id) and status=''saved''');
 execute definition;
 -- A canceled or revised registration cannot apply an outstanding method setup.
 definition:=pg_get_functiondef('public.dopmi_guardian_registration_server(text,jsonb)'::regprocedure);
 anchor:='if operation=''cancel'' then';
 if position(anchor in definition)=0 then raise exception 'Review method cancellation anchor'; end if;
 definition:=replace(definition,anchor,anchor||'
 update private.dopmi_guardian_registration_method_changes set status=''canceled'' where registration_id=r.id and status=''pending'';');
 anchor:='update private.dopmi_guardian_registrations set gross_cents=gross,consent_at=now(),revision=revision+1';
 if position(anchor in definition)=0 then raise exception 'Review method amount revision anchor'; end if;
 definition:=replace(definition,anchor,'update private.dopmi_guardian_registration_method_changes set status=''canceled'' where registration_id=r.id and status=''pending'';
 '||anchor);
 execute definition;
 definition:=pg_get_functiondef('public.dopmi_guardian_registration_state()'::regprocedure);
 anchor:='return jsonb_build_object(''id'',r.id';
 if position(anchor in definition)=0 then raise exception 'Review method status projection anchor'; end if;
 definition:=replace(definition,anchor,'return jsonb_build_object(''method_status'',case when private.dopmi_registration_method_valid(r.id,actor,r.method_job_id) then ''saved'' else ''unavailable'' end,
 ''method_change'',(select jsonb_build_object(''key'',m.request_key,''status'',m.status,''revision'',coalesce(m.applied_revision,m.registration_revision))
 from private.dopmi_guardian_registration_method_changes m where m.owner_id=actor and m.registration_id=r.id order by m.created_at desc,m.id desc limit 1),''id'',r.id');
 execute definition;
end $patch$;
commit;
