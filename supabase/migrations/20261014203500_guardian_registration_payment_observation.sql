begin;

-- Processor evidence is private and separate from allocation/confirmed impact.
alter table private.dopmi_guardian_registration_attempts
  add column processor_state text check(processor_state in
    ('unresolved','requires_action','processor_succeeded','processor_canceled')),
  add column processor_checked_at timestamptz;

create function public.dopmi_guardian_registration_payment_server(operation text,data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a private.dopmi_guardian_registration_attempts; incoming text;
begin
  if operation='candidates' then
    return coalesce((select jsonb_agg(jsonb_build_object('id',candidate.id)) from (
      select att.id from private.dopmi_guardian_registration_attempts att
      join private.dopmi_guardian_registrations reg on reg.id=att.registration_id
      where (att.pay_requested_at is not null
          and att.processor_state is distinct from 'processor_succeeded'
          and att.processor_state is distinct from 'processor_canceled')
        or (att.pay_requested_at is null and att.status='prepared'
          and reg.status='registered' and att.expires_at>clock_timestamp())
      order by att.processor_checked_at nulls first,att.created_at,att.id limit 20
    ) candidate),'[]'::jsonb);
  end if;
  select * into a from private.dopmi_guardian_registration_attempts where id=(data->>'id')::uuid;
  if not found then raise exception 'Intento no disponible' using errcode='42501'; end if;
  if operation='get' then return to_jsonb(a); end if;
  if operation<>'observe' then raise exception 'Operación inválida' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||a.owner_id,0));
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||a.owner_id,0));
  select * into a from private.dopmi_guardian_registration_attempts where id=a.id for update;
  incoming:=data->>'state';
  if a.pay_requested_at is null or a.stripe_payment_intent_id is null
    or a.stripe_payment_intent_id is distinct from data->>'payment_intent_id'
    or incoming is null or incoming not in
      ('unresolved','requires_action','processor_succeeded','processor_canceled') then
    raise exception 'Evidencia no vinculada' using errcode='22023';
  end if;
  -- Reordered observations cannot erase terminal evidence. Conflicting
  -- terminal results require investigation, never a silent overwrite.
  if a.processor_state in ('processor_succeeded','processor_canceled') then
    if incoming in ('processor_succeeded','processor_canceled') and incoming<>a.processor_state then
      raise exception 'Evidencia contradictoria' using errcode='22023';
    end if;
    return to_jsonb(a);
  end if;
  update private.dopmi_guardian_registration_attempts
    set processor_state=incoming,processor_checked_at=clock_timestamp()
    where id=a.id returning * into a;
  return to_jsonb(a);
end $$;
revoke all on function public.dopmi_guardian_registration_payment_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_registration_payment_server(text,jsonb) to service_role;

commit;
