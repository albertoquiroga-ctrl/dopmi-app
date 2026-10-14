begin;
alter table private.dopmi_guardian_registration_attempts add column resolved_at timestamptz;

create function public.dopmi_guardian_registration_resolve_payment(target_attempt uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a private.dopmi_guardian_registration_attempts; e private.dopmi_guardian_registration_evaluations;
begin
  select * into a from private.dopmi_guardian_registration_attempts where id=target_attempt;
  if not found then raise exception 'Intento no disponible' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||a.owner_id,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||a.owner_id,0));
  select * into a from private.dopmi_guardian_registration_attempts where id=target_attempt for update;
  if a.resolved_at is not null then return to_jsonb(a); end if;
  if a.pay_requested_at is null then raise exception 'Intento sin envío' using errcode='55000'; end if;
  if a.processor_state='processor_succeeded' then
    if not exists(select 1 from private.dopmi_guardian_settlements s
      where s.registration_attempt_id=a.id and s.cycle_id=a.reservation_id
        and s.payment_intent_id=a.stripe_payment_intent_id) then
      raise exception 'Liquidación pendiente' using errcode='55000'; end if;
  elsif a.processor_state='processor_canceled' then
    if exists(select 1 from private.dopmi_guardian_settlements where registration_attempt_id=a.id) then
      raise exception 'Evidencia contradictoria' using errcode='22023'; end if;
    select * into e from private.dopmi_guardian_registration_evaluations where id=a.evaluation_id for update;
    perform public.dopmi_guardian_release(a.owner_id,e.id);
    update private.dopmi_guardian_registration_evaluations set status='canceled' where id=e.id;
    update private.dopmi_guardian_registration_attempts set status='canceled' where id=a.id;
  else raise exception 'Confirmación pendiente' using errcode='55000'; end if;
  update private.dopmi_guardian_registration_attempts set resolved_at=clock_timestamp()
    where id=a.id returning * into a;
  return to_jsonb(a);
end $$;
revoke all on function public.dopmi_guardian_registration_resolve_payment(uuid) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_resolve_payment(uuid) to service_role;

do $patch$
declare definition text; anchor text;
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_registration_payment_server(text,jsonb)'::regprocedure);
  anchor:='if operation=''candidates'' then';
  if position(anchor in definition)=0 then raise exception 'Review resolution discovery anchor'; end if;
  definition:=replace(definition,anchor,$code$if operation='finalization_candidates' then
    return coalesce((select jsonb_agg(jsonb_build_object('id',candidate.id)) from (
      select id from private.dopmi_guardian_registration_attempts
      where resolved_at is null and pay_requested_at is not null
        and processor_state in ('processor_succeeded','processor_canceled')
      order by processor_checked_at,id limit 20
    ) candidate),'[]'::jsonb);
  end if;
  if operation='candidates' then$code$);
  anchor:='if operation=''get'' then return to_jsonb(a); end if;';
  if position(anchor in definition)=0 then raise exception 'Review resolution get anchor'; end if;
  definition:=replace(definition,anchor,$code$if operation='get' then return to_jsonb(a)||jsonb_build_object('settlement',
    private.dopmi_guardian_settlement_view(a.reservation_id)); end if;$code$);
  execute definition;

  definition:=pg_get_functiondef('public.dopmi_guardian_registration_attempt_server(text,jsonb)'::regprocedure);
  anchor:='where registration_id=r.id and pay_requested_at is not null order by created_at desc,id desc limit 1;';
  if position(anchor in definition)=0 then raise exception 'Review resolved attempt anchor'; end if;
  definition:=replace(definition,anchor,'where registration_id=r.id and pay_requested_at is not null and resolved_at is null order by created_at desc,id desc limit 1;');
  anchor:='if found then return to_jsonb(a); end if;';
  if position(anchor in definition)=0 then raise exception 'Review resolved cycle anchor'; end if;
  definition:=replace(definition,anchor,anchor||$code$
  -- A resolved cycle never authorizes another attempt within its interval.
  select att.* into a from private.dopmi_guardian_registration_attempts att
    join private.dopmi_guardian_registration_evaluations ev on ev.id=att.evaluation_id
    where att.registration_id=r.id and att.resolved_at is not null and ev.next_evaluation_at>now()
    order by ev.due_at desc,att.id desc limit 1;
  if found then return to_jsonb(a); end if;$code$);
  execute definition;

  definition:=pg_get_functiondef('public.dopmi_guardian_registration_server(text,jsonb)'::regprocedure);
  anchor:='where owner_id=actor and pay_requested_at is not null)';
  if position(anchor in definition)=0 then raise exception 'Review resolved enrollment anchor'; end if;
  execute replace(definition,anchor,'where owner_id=actor and pay_requested_at is not null and resolved_at is null)');
  definition:=pg_get_functiondef('public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure);
  anchor:='where owner_id=donor and pay_requested_at is not null)';
  if position(anchor in definition)=0 then raise exception 'Review resolved legacy anchor'; end if;
  execute replace(definition,anchor,'where owner_id=donor and pay_requested_at is not null and resolved_at is null)');
end $patch$;
commit;
