begin;

-- A durable send marker is irreversible without processor reconciliation.
-- No external payment consumer is enabled by this migration.
alter table private.dopmi_guardian_registration_attempts
  add column pay_requested_at timestamptz;

create function public.dopmi_guardian_registration_authorize_payment(target_attempt uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a private.dopmi_guardian_registration_attempts; fresh jsonb;
begin
  select * into a from private.dopmi_guardian_registration_attempts where id=target_attempt;
  if not found then raise exception 'Intento no disponible' using errcode='42501'; end if;
  -- Match the setup/cancellation lock order before re-reading the marker.
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||a.owner_id,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||a.owner_id,0));
  select * into a from private.dopmi_guardian_registration_attempts where id=target_attempt for update;
  if a.pay_requested_at is not null or a.status<>'prepared' then return null; end if;
  -- Reuse the entire fresh account, consent, binding, cycle, capacity and
  -- rescuer-lock validation. A caller cannot supply an amount or method.
  fresh:=public.dopmi_guardian_registration_attempt_server('prepare',
    jsonb_build_object('id',a.registration_id));
  if fresh is null or (fresh->>'id')::uuid<>a.id or fresh->>'status'<>'prepared'
    or (fresh->>'expires_at')::timestamptz<=clock_timestamp()+interval '2 minutes'
    or not exists(select 1 from private.dopmi_guardian_cycles c where c.id=a.reservation_id
      and c.status='reserved' and c.expires_at>clock_timestamp()+interval '2 minutes') then return null; end if;
  update private.dopmi_guardian_registration_attempts set pay_requested_at=clock_timestamp()
    where id=a.id and pay_requested_at is null returning * into a;
  if not found then return null; end if;
  return to_jsonb(a)||jsonb_build_object('payment_key','guardian-registration:'||a.id);
end $$;
revoke all on function public.dopmi_guardian_registration_authorize_payment(uuid) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_authorize_payment(uuid) to service_role;

-- A response lost after the marker must reconcile the original operation.
-- Preparation must not expire/cancel it or silently authorize another send.
do $patch$
declare definition text; anchor text;
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_registration_attempt_server(text,jsonb)'::regprocedure);
  anchor:='if r.status<>''registered'' then return null; end if;';
  if position(anchor in definition)=0 then raise exception 'Review attempt marker anchor'; end if;
  execute replace(definition,anchor,$replacement$select * into a from private.dopmi_guardian_registration_attempts
    where registration_id=r.id and pay_requested_at is not null order by created_at desc,id desc limit 1;
  if found then return to_jsonb(a); end if;
  if r.status<>'registered' then return null; end if;$replacement$);

  definition:=pg_get_functiondef('public.dopmi_guardian_registration_server(text,jsonb)'::regprocedure);
  anchor:='if operation=''cancel'' then';
  if position(anchor in definition)=0 then raise exception 'Review cancellation marker anchor'; end if;
  -- Cancellation remains possible, but a possibly sent payment keeps its
  -- reservation/evaluation until processor evidence resolves it.
  definition:=replace(definition,'where registration_id=r.id and status=''prepared'';',
    'where registration_id=r.id and status=''prepared'' and pay_requested_at is null;');
  definition:=replace(definition,'where e.registration_id=r.id and e.status=''reserved'';',
    'where e.registration_id=r.id and e.status=''reserved'' and not exists(select 1 from private.dopmi_guardian_registration_attempts a where a.evaluation_id=e.id and a.pay_requested_at is not null);');
  definition:=replace(definition,'where registration_id=r.id and status=''reserved'';',
    'where registration_id=r.id and status=''reserved'' and not exists(select 1 from private.dopmi_guardian_registration_attempts a where a.evaluation_id=private.dopmi_guardian_registration_evaluations.id and a.pay_requested_at is not null);');
  anchor:='if exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=actor)';
  if position(anchor in definition)=0 then raise exception 'Review enrollment marker anchor'; end if;
  definition:=replace(definition,anchor,$replacement$if exists(select 1 from private.dopmi_guardian_registration_attempts where owner_id=actor and pay_requested_at is not null)
        or exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=actor)$replacement$);
  execute definition;

  definition:=pg_get_functiondef('public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure);
  anchor:='held:=public.dopmi_guardian_reserve(donor,requested_key,gross);';
  if position(anchor in definition)=0 then raise exception 'Review legacy activation marker anchor'; end if;
  execute replace(definition,anchor,$replacement$if exists(select 1 from private.dopmi_guardian_registration_attempts
    where owner_id=donor and pay_requested_at is not null) then
    raise exception 'Cobro requiere conciliación' using errcode='55000'; end if;
  held:=public.dopmi_guardian_reserve(donor,requested_key,gross);$replacement$);
end $patch$;
commit;
