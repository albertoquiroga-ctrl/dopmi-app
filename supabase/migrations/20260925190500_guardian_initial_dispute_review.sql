begin;

-- Verified charge references are private evidence, not a settlement or refund.
alter table private.dopmi_guardian_activations
 add column payment_review jsonb,
 add column payment_review_at timestamptz;

do $patch$
declare definition text; old_text text; new_text text;
begin
 definition:=pg_get_functiondef('public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure);
 old_text:='elsif operation=''checked'' then';
 new_text:=$code$elsif operation='review_payment' then
 select * into c from private.dopmi_guardian_cycles where id=a.cycle_id for update;
 if a.session_id is null or a.session_id is distinct from data->>'session_id'
 or data->>'reason' is distinct from 'disputed' or data->'disputed' is distinct from 'true'::jsonb
 or coalesce(data->>'payment_intent_id','') !~ '^pi_[A-Za-z0-9]+$'
 or coalesce(data->>'charge_id','') !~ '^ch_[A-Za-z0-9]+$'
 or (data->>'gross_cents')::bigint is distinct from c.gross_cents then
 raise exception 'Evidencia de revisión no coincide' using errcode='22023'; end if;
 -- Same activation→cycle lock order as settlement: never overwrite a winner.
 if exists(select 1 from private.dopmi_guardian_settlements where cycle_id=c.id) then
 return private.dopmi_guardian_activation_view(c.id); end if;
 if a.payment_review is not null and a.payment_review is distinct from data then
 raise exception 'Revisión ya vinculada a otra evidencia' using errcode='22023'; end if;
 update private.dopmi_guardian_activations set status='attention',
 payment_review=coalesce(payment_review,data),payment_review_at=coalesce(payment_review_at,now())
 where cycle_id=c.id;
 elsif operation='checked' then$code$;
 if position(old_text in definition)=0 then raise exception 'Review activation operation patch'; end if;
 execute replace(definition,old_text,new_text);

 definition:=pg_get_functiondef('public.dopmi_guardian_settlement_server(text,jsonb)'::regprocedure);
 old_text:='b.cycle_id:=initial_activation.cycle_id;';
 new_text:=$code$if initial_activation.payment_review is not null then
 raise exception 'Pago inicial en revisión' using errcode='22023'; end if;
 b.cycle_id:=initial_activation.cycle_id;$code$;
 if position(old_text in definition)=0 then raise exception 'Review initial settlement guard'; end if;
 execute replace(definition,old_text,new_text);
end $patch$;

-- Existing service-only grants and owner-filtered projections are unchanged.
-- Reservation expiry and cancellation retain their existing policies; this
-- operation itself never releases capacity or fabricates financial accounting.
commit;
