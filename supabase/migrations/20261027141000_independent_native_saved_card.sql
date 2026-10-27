begin;

-- Null preserves all existing hosted, wallet and Guardian registration jobs.
-- Only a newly reserved independent native add receives this purpose.
alter table private.dopmi_saved_card_jobs add column purpose text
  check(purpose is null or (purpose='add_card' and wallet_type is not distinct from 'card'));

create or replace function public.dopmi_saved_native_card_server(operation text,data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; requested uuid; j private.dopmi_saved_card_jobs;
begin
  if operation in ('prepare_add','add_job','prepare_registration','registration_job') then
    actor:=(data->>'owner_id')::uuid; requested:=(data->>'key')::uuid;
    if actor is null or requested is null or not exists(
      select 1 from public.profiles p join auth.users u on u.id=p.id
      where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
      raise exception 'Cuenta no disponible' using errcode='42501'; end if;
    perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
    if operation in ('prepare_add','add_job') then
      -- A registration or its method-change UUID is never an independent add.
      if exists(select 1 from private.dopmi_guardian_registrations where id=requested)
        or exists(select 1 from private.dopmi_guardian_registration_method_changes where id=requested) then
        raise exception 'La solicitud corresponde a otro propósito' using errcode='42501'; end if;
    elsif not private.dopmi_registration_setup_allowed(actor,requested) then
      raise exception 'Registro no disponible' using errcode='42501';
    end if;
    select * into j from private.dopmi_saved_card_jobs where owner_id=actor and request_key=requested;
    if found then
      if (operation in ('prepare_add','add_job') and not
          ((j.purpose is not distinct from 'add_card' and j.wallet_type='card') or (j.purpose is null and j.wallet_type is null)))
        or (operation in ('prepare_registration','registration_job') and
          (j.purpose is not null or (j.wallet_type is not null and j.wallet_type<>'card'))) then
        raise exception 'El propósito del método cambió' using errcode='42501'; end if;
      if operation in ('prepare_add','prepare_registration') and
        (data->>'consent' is distinct from 'true' or data->>'consent_version' is distinct from j.consent_version
          or data->>'return_url' is distinct from j.return_url) then
        raise exception 'La solicitud cambió' using errcode='22023'; end if;
      return to_jsonb(j);
    end if;
    if operation in ('add_job','registration_job') then return null; end if;
    if exists(select 1 from private.dopmi_guardian_method_jobs
      where donor_id=actor and status in ('pending','attention')) then
      raise exception 'Cambio de medio Guardián pendiente' using errcode='55000'; end if;
    -- Reuse consent, limits, owner/customer lock, activation and method guards.
    j:=jsonb_populate_record(null::private.dopmi_saved_card_jobs,
      public.dopmi_saved_card_server('prepare',data||jsonb_build_object('wallet_type','card')));
    if operation='prepare_add' then
      update private.dopmi_saved_card_jobs set purpose='add_card' where id=j.id returning * into j;
    end if;
    return to_jsonb(j);
  elsif operation='candidates' then
    return coalesce((select jsonb_agg(x) from (select id from private.dopmi_saved_card_jobs
      where wallet_type='card' and status='pending' and coalesce(lease_until,now())<=now()
      order by checked_at,id limit 25)x),'[]');
  elsif operation='lookup_setup' then
    return (select to_jsonb(x) from private.dopmi_saved_card_jobs x
      where wallet_type='card' and setup_intent_id=data->>'setup_intent_id');
  end if;
  select owner_id into actor from private.dopmi_saved_card_jobs where id=(data->>'id')::uuid and wallet_type='card';
  if actor is null then raise exception 'Método nativo no disponible' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
  select * into j from private.dopmi_saved_card_jobs where id=(data->>'id')::uuid and wallet_type='card' for update;
  -- Independent adds use the active actor/customer/lease gate below, rather
  -- than borrowing a pending Guardian registration. Existing jobs keep theirs.
  if operation='native_ready' and j.purpose is null
    and not private.dopmi_registration_setup_allowed(actor,j.request_key) then return null; end if;
  if operation='claim' and j.setup_intent_id is null and j.purpose is null
    and not private.dopmi_registration_setup_allowed(actor,j.request_key) then return null; end if;
  if operation not in ('get','claim','release','customer','native_ready','native_setup','native_saved','expired') then
    raise exception 'Operación nativa inválida' using errcode='22023'; end if;
  return public.dopmi_saved_wallet_server(operation,data);
end $$;

-- Purpose isolation applies in both directions. Historical null-purpose jobs
-- retain their exact registration behavior; an independent add is not evidence
-- of Guardian authorization even if a UUID is deliberately made to collide.
do $isolate$
declare definition text; anchor text;
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_registration_server(text,jsonb)'::regprocedure);
  anchor:='join private.dopmi_saved_card_jobs job on job.owner_id=reg.owner_id';
  if position(anchor in definition)=0 then raise exception 'Review registration worker purpose'; end if;
  definition:=replace(definition,anchor,'join private.dopmi_saved_card_jobs job on job.purpose is null and job.owner_id=reg.owner_id');
  anchor:='select * into j from private.dopmi_saved_card_jobs where owner_id=actor';
  if position(anchor in definition)=0 then raise exception 'Review registration receipt purpose'; end if;
  definition:=replace(definition,anchor,'select * into j from private.dopmi_saved_card_jobs where purpose is null and owner_id=actor');
  anchor:=$code$select * into j from private.dopmi_saved_card_jobs where id=(data->>'method_job_id')::uuid$code$;
  if position(anchor in definition)=0 then raise exception 'Review registration confirmation purpose'; end if;
  definition:=replace(definition,anchor,$code$select * into j from private.dopmi_saved_card_jobs where purpose is null and id=(data->>'method_job_id')::uuid$code$);
  execute definition;

  definition:=pg_get_functiondef('public.dopmi_guardian_registration_method_server(text,jsonb)'::regprocedure);
  anchor:='select * into j from private.dopmi_saved_card_jobs where owner_id=actor and request_key=m.id';
  if position(anchor in definition)=0 then raise exception 'Review registration method purpose'; end if;
  execute replace(definition,anchor,'select * into j from private.dopmi_saved_card_jobs where purpose is null and owner_id=actor and request_key=m.id');

  definition:=pg_get_functiondef('private.dopmi_registration_method_valid(uuid,uuid,uuid)'::regprocedure);
  anchor:='from private.dopmi_saved_card_jobs j where j.id=job';
  if position(anchor in definition)=0 then raise exception 'Review registration snapshot purpose'; end if;
  execute replace(definition,anchor,'from private.dopmi_saved_card_jobs j where j.purpose is null and j.id=job');
end $isolate$;

-- CREATE OR REPLACE preserves the service-only ACL of the existing adapter.
-- An opaque public receipt allows restart recovery without customer or secret.
create or replace function public.dopmi_saved_card_state() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
  if actor is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
    where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
    raise exception 'Cuenta no disponible' using errcode='42501'; end if;
  return (select jsonb_build_object('key',request_key,'status',status,
    'card_id',case when status='saved' then payment_method_id end,
    'presentation',case when purpose='add_card' then 'native_card' else 'hosted_checkout' end,
    'add_only',true,'default_unchanged',true)
    from private.dopmi_saved_card_jobs j where owner_id=actor
      and (wallet_type is null or (wallet_type='card' and purpose='add_card'))
      and not exists(select 1 from private.dopmi_guardian_registrations where id=j.request_key)
      and not exists(select 1 from private.dopmi_guardian_registration_method_changes where id=j.request_key)
    order by created_at desc,id desc limit 1);
end $$;

commit;
