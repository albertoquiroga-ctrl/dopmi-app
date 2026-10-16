begin;

-- Keep historical Checkout and native wallet jobs immutable. Ordinary native
-- cards are explicit; null continues to mean the earlier hosted setup flow.
do $constraint$
declare constraint_name text;
begin
  select conname into constraint_name from pg_constraint
    where conrelid='private.dopmi_saved_card_jobs'::regclass and contype='c'
      and conkey=array[(select attnum from pg_attribute
        where attrelid='private.dopmi_saved_card_jobs'::regclass and attname='wallet_type')]::smallint[];
  if constraint_name is null then raise exception 'Review native card provider constraint'; end if;
  execute format('alter table private.dopmi_saved_card_jobs drop constraint %I',constraint_name);
end $constraint$;
alter table private.dopmi_saved_card_jobs add constraint dopmi_saved_card_provider_check
  check(wallet_type in ('apple_pay','google_pay','card'));

do $patch$
declare definition text; old_text text; new_text text;
begin
  definition:=pg_get_functiondef('public.dopmi_saved_card_server(text,jsonb)'::regprocedure);
  old_text:=$code$data->>'wallet_type' not in ('apple_pay','google_pay')$code$;
  new_text:=$code$data->>'wallet_type' not in ('apple_pay','google_pay','card')$code$;
  if position(old_text in definition)=0 then raise exception 'Review native card reservation anchor'; end if;
  execute replace(definition,old_text,new_text);

  -- The wallet endpoints continue to return Apple Pay / Google Pay only. A
  -- regular card cannot enter their queue or satisfy their provider proof.
  definition:=pg_get_functiondef('public.dopmi_saved_wallet_server(text,jsonb)'::regprocedure);
  old_text:='where wallet_type is not null';
  new_text:=$code$where wallet_type in ('apple_pay','google_pay')$code$;
  if position(old_text in definition)=0 then raise exception 'Review native wallet queue separation'; end if;
  execute replace(definition,old_text,new_text);
  definition:=pg_get_functiondef('public.dopmi_saved_wallet_state()'::regprocedure);
  old_text:='where owner_id=actor and wallet_type is not null';
  new_text:=$code$where owner_id=actor and wallet_type in ('apple_pay','google_pay')$code$;
  if position(old_text in definition)=0 then raise exception 'Review native wallet receipt separation'; end if;
  execute replace(definition,old_text,new_text);
end $patch$;

-- Server-only adapter shares the existing owner/customer lock and native lease
-- transitions. The registration UUID is the saved-method request key; callers
-- cannot select a different owner's job or replace a hosted SetupIntent.
create function public.dopmi_saved_native_card_server(operation text,data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; requested uuid; j private.dopmi_saved_card_jobs;
begin
  if operation in ('prepare_registration','registration_job') then
    actor:=(data->>'owner_id')::uuid; requested:=(data->>'key')::uuid;
    if actor is null or requested is null or not exists(
      select 1 from public.profiles p join auth.users u on u.id=p.id
      where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
      raise exception 'Cuenta no disponible' using errcode='42501'; end if;
    perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||actor,0));
    if not exists(select 1 from private.dopmi_guardian_registrations
      where id=requested and owner_id=actor and status='method_pending') then
      raise exception 'Registro no disponible' using errcode='42501'; end if;
    select * into j from private.dopmi_saved_card_jobs
      where owner_id=actor and request_key=requested;
    if found then
      if j.wallet_type is not null and j.wallet_type<>'card' then
        raise exception 'El método del registro cambió' using errcode='40001'; end if;
      if operation='prepare_registration' and
        (data->>'consent' is distinct from 'true' or data->>'consent_version' is distinct from j.consent_version
          or data->>'return_url' is distinct from j.return_url) then
        raise exception 'La solicitud cambió' using errcode='22023'; end if;
      return to_jsonb(j);
    end if;
    if operation='registration_job' then return null; end if;
    if exists(select 1 from private.dopmi_guardian_method_jobs
      where donor_id=actor and status in ('pending','attention')) then
      raise exception 'Cambio de medio Guardián pendiente' using errcode='55000'; end if;
    return public.dopmi_saved_card_server('prepare',data||jsonb_build_object('wallet_type','card'));
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
  if operation='native_ready' and not exists(select 1 from private.dopmi_guardian_registrations
    where owner_id=actor and id=j.request_key and status='method_pending') then return null; end if;
  if operation='claim' and j.setup_intent_id is null and not exists(select 1 from private.dopmi_guardian_registrations
    where owner_id=actor and id=j.request_key and status='method_pending') then return null; end if;
  if operation not in ('get','claim','release','customer','native_ready','native_setup','native_saved','expired') then
    raise exception 'Operación nativa inválida' using errcode='22023'; end if;
  return public.dopmi_saved_wallet_server(operation,data);
end $$;
revoke all on function public.dopmi_saved_native_card_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_saved_native_card_server(text,jsonb) to service_role;

commit;
