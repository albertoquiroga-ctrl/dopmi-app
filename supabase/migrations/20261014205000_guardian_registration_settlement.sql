begin;
alter table private.dopmi_guardian_settlements
  add column registration_attempt_id uuid unique references private.dopmi_guardian_registration_attempts(id),
  drop constraint dopmi_guardian_settlement_source,
  add constraint dopmi_guardian_settlement_source check(
    (registration_attempt_id is null and checkout_session_id is null and invoice_id is not null and invoice_payment_id is not null) or
    (registration_attempt_id is null and checkout_session_id is not null and invoice_id is null and invoice_payment_id is null) or
    (registration_attempt_id is not null and checkout_session_id is null and invoice_id is null and invoice_payment_id is null));

-- Extend only the source binding. Reuse the existing locked full-net planner,
-- actual-fee accounting, refund fallback and durable transfer/refund jobs.
do $patch$
declare definition text; anchor text;
begin
  definition:=pg_get_functiondef('public.dopmi_guardian_settlement_server(text,jsonb)'::regprocedure);
  anchor:='initial_activation private.dopmi_guardian_activations;';
  if position(anchor in definition)=0 then raise exception 'Review registration settlement declaration'; end if;
  definition:=replace(definition,anchor,anchor||' registration_attempt private.dopmi_guardian_registration_attempts;');
  anchor:='elsif operation in (''settle'',''settle_initial'') then';
  if position(anchor in definition)=0 then raise exception 'Review registration settlement operation'; end if;
  definition:=replace(definition,anchor,'elsif operation in (''settle'',''settle_initial'',''settle_registration'') then');
  anchor:='if operation=''settle_initial'' then'||chr(10)||' select * into initial_activation';
  if position(anchor in definition)=0 then raise exception 'Review registration settlement source'; end if;
  definition:=replace(definition,anchor,$code$if operation='settle_registration' then
 select * into registration_attempt from private.dopmi_guardian_registration_attempts
   where id=(data->>'registration_attempt_id')::uuid;
 if not found then raise exception 'Intento no disponible' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||registration_attempt.owner_id,0));
 perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||registration_attempt.owner_id,0));
 select * into registration_attempt from private.dopmi_guardian_registration_attempts
   where id=registration_attempt.id for update;
 if registration_attempt.pay_requested_at is null or registration_attempt.processor_state is distinct from 'processor_succeeded'
   or registration_attempt.stripe_payment_intent_id is distinct from data->>'payment_intent_id'
   or registration_attempt.owner_id is distinct from (data->>'donor_id')::uuid
   or registration_attempt.gross_cents is distinct from (data->>'gross_cents')::bigint
   or registration_attempt.customer_id is distinct from data->>'customer_id'
   or registration_attempt.payment_method_id is distinct from data->>'payment_method_id'
   or data->>'invoice_id' is not null or data->>'invoice_payment_id' is not null
   or data->>'subscription_id' is not null or data->>'checkout_session_id' is not null then
   raise exception 'Evidencia de registro no coincide' using errcode='22023'; end if;
 b.cycle_id:=registration_attempt.reservation_id;
 elsif operation='settle_initial' then
 select * into initial_activation$code$);
  anchor:='evidence,checkout_session_id)';
  if position(anchor in definition)=0 then raise exception 'Review registration settlement columns'; end if;
  definition:=replace(definition,anchor,'evidence,checkout_session_id,registration_attempt_id)');
  anchor:='case when operation=''settle_initial'' then initial_activation.session_id else null end);';
  if position(anchor in definition)=0 then raise exception 'Review registration settlement values'; end if;
  definition:=replace(definition,anchor,'case when operation=''settle_initial'' then initial_activation.session_id else null end,'||
    'case when operation=''settle_registration'' then registration_attempt.id else null end);');
  execute definition;
end $patch$;
commit;
