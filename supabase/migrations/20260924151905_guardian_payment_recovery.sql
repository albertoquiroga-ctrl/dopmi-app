begin;
alter table private.dopmi_guardian_collection_jobs
 add column recovery_state text check(recovery_state in ('requires_payment_method','requires_action','requires_confirmation','canceled','processing','succeeded','unknown','void_pending','voided')),
 add column recovery_reason text check(recovery_reason in ('payment_failed','authentication_required','not_attempted','payment_canceled')),
 add column recovery_intent_id text unique check(recovery_intent_id ~ '^pi_[A-Za-z0-9]+$'),
 add column recovery_invoice_payment_id text unique check(recovery_invoice_payment_id ~ '^inpay_[A-Za-z0-9]+$'),
 add column recovery_attempts integer not null default 0 check(recovery_attempts>=0),
 add column recovery_first_attempt_at timestamptz;

-- Shares the collection lease, so invoice finalization/payment and recovery
-- cannot run concurrently. Recovery can only observe or cancel a failed
-- attempt; it never resets the one-shot payment authorization.
create function public.dopmi_guardian_recovery_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.dopmi_guardian_collection_jobs; target text:=data->>'invoice_id'; reason text;
begin
 select * into j from private.dopmi_guardian_collection_jobs where invoice_id=target for update;
 if not found then raise exception 'Factura de recuperación no vinculada' using errcode='22023'; end if;
 if operation='get' then return private.dopmi_guardian_collection_view(target); end if;
 if j.status in ('paid','skipped') then
 if operation='claim' then return null; end if;
 return private.dopmi_guardian_collection_view(target); end if;
 if j.pay_requested_at is null then raise exception 'Factura sin intento autorizado' using errcode='22023'; end if;
 if operation='claim' then
 if j.lease_until>now() or j.available_at>now() then return null; end if;
 update private.dopmi_guardian_collection_jobs set lease=gen_random_uuid(),lease_until=now()+interval '5 minutes',checked_at=now()
 where invoice_id=target;
 else
 if j.lease is null or j.lease_until is null or j.lease is distinct from (data->>'lease')::uuid or j.lease_until<=now() then
 raise exception 'Turno de recuperación vencido' using errcode='55000'; end if;
 if operation='observe' then
 if coalesce(data->>'state','') not in ('requires_payment_method','requires_action','requires_confirmation','canceled','processing','succeeded','unknown')
 or coalesce(data->>'intent_id','') !~ '^pi_[A-Za-z0-9]+$' or coalesce(data->>'invoice_payment_id','') !~ '^inpay_[A-Za-z0-9]+$'
 or (j.recovery_intent_id is not null and j.recovery_intent_id is distinct from data->>'intent_id')
 or (j.recovery_invoice_payment_id is not null and j.recovery_invoice_payment_id is distinct from data->>'invoice_payment_id') then
 raise exception 'Evidencia de recuperación no coincide' using errcode='22023'; end if;
 update private.dopmi_guardian_collection_jobs set status='attention',recovery_state=data->>'state',
 recovery_intent_id=data->>'intent_id',recovery_invoice_payment_id=data->>'invoice_payment_id',checked_at=now() where invoice_id=target;
 elsif operation='authorize_void' then
 if j.recovery_state not in ('requires_payment_method','requires_action','requires_confirmation','canceled') or j.recovery_state is null
 or j.recovery_intent_id is null or j.recovery_invoice_payment_id is null then
 raise exception 'Pago no cancelable confirmado' using errcode='22023'; end if;
 if j.recovery_attempts>=8 or j.recovery_first_attempt_at<now()-interval '23 hours' then
 update private.dopmi_guardian_collection_jobs set status='attention',lease_until=null,error_code='recovery_retry_limit',available_at=now()+interval '1 hour' where invoice_id=target;
 return null; end if;
 reason:=case j.recovery_state when 'requires_action' then 'authentication_required' when 'requires_payment_method' then 'payment_failed'
 when 'requires_confirmation' then 'not_attempted' else 'payment_canceled' end;
 update private.dopmi_guardian_collection_jobs set recovery_state='void_pending',recovery_reason=coalesce(recovery_reason,reason),
 recovery_attempts=recovery_attempts+1,recovery_first_attempt_at=coalesce(recovery_first_attempt_at,now()) where invoice_id=target;
 elsif operation='voided' then
 -- The service independently reads invoice void + default InvoicePayment
 -- canceled + PaymentIntent canceled with zero received/capturable amount.
 if coalesce(data->>'intent_status','')<>'canceled' or coalesce(data->>'invoice_status','')<>'void'
 or coalesce(data->>'invoice_payment_status','')<>'canceled'
 or (data->>'amount_received')::bigint is distinct from 0 or (data->>'amount_paid')::bigint is distinct from 0
 or coalesce((data->>'amount_remaining')::bigint,-1) not in (0,j.gross_cents) or (data->>'amount_capturable')::bigint is distinct from 0
 or j.recovery_intent_id is null or j.recovery_intent_id is distinct from data->>'intent_id'
 or j.recovery_invoice_payment_id is null or j.recovery_invoice_payment_id is distinct from data->>'invoice_payment_id' then
 raise exception 'Cancelación de pago no confirmada' using errcode='22023'; end if;
 perform 1 from private.dopmi_guardian_cycles where id=j.cycle_id for update;
 if exists(select 1 from private.dopmi_guardian_settlements where cycle_id=j.cycle_id) then
 raise exception 'Pago ya liquidado' using errcode='22023'; end if;
 update private.dopmi_guardian_collection_jobs set status='skipped',decision='skip',recovery_state='voided',
 recovery_reason=coalesce(recovery_reason,'payment_canceled'),lease_until=null,error_code=null where invoice_id=target;
 update private.dopmi_guardian_cycles set status=case when expires_at<=now() then 'expired' else 'released' end,reserved_cents=0
 where id=j.cycle_id and status='reserved';
 elsif operation in ('wait','failed') then
 update private.dopmi_guardian_collection_jobs set status='attention',lease_until=null,
 available_at=now()+case when operation='wait' then interval '1 minute' else interval '5 minutes' end,
 error_code=case when operation='wait' then 'guardian_payment_pending' else left(data->>'error_code',80) end where invoice_id=target;
 else raise exception 'Operación de recuperación inválida' using errcode='22023'; end if;
 end if;
 return private.dopmi_guardian_collection_view(target);
end; $$;
revoke all on function public.dopmi_guardian_recovery_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_recovery_server(text,jsonb) to service_role;

do $patch$
declare definition text:=pg_get_functiondef('public.dopmi_guardian_collection_server(text,jsonb)'::regprocedure);
 old_text text:='update private.dopmi_guardian_collection_jobs set status=''paid'',lease_until=null,error_code=null where invoice_id=target;';
begin
 if position(old_text in definition)=0 then raise exception 'Review collection paid transition before migration'; end if;
 execute replace(definition,old_text,'update private.dopmi_guardian_collection_jobs set status=''paid'',recovery_state=''succeeded'',lease_until=null,error_code=null where invoice_id=target;');
end $patch$;
commit;
