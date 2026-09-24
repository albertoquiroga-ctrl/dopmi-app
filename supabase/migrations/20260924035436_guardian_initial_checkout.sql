begin;

-- A server-owned activation attempt records consent and a fixed Checkout
-- request before any Stripe write. One unresolved attempt per donor.
create table private.dopmi_guardian_activations (
 cycle_id uuid primary key references private.dopmi_guardian_cycles(id),
 donor_id uuid not null references public.profiles(id),
 consent_version text not null check(consent_version='guardian-2026-09-24'),
 consent_at timestamptz not null default now(),
 status text not null check(status in ('pending','no_capacity','expired','failed','settled','refund_pending','refunded','attention')),
 checkout_expires_at timestamptz not null,
 return_url text not null check(return_url ~ '^https://'),
 session_id text unique check(session_id ~ '^cs_(test_)?[A-Za-z0-9]+$'),
 customer_id text check(customer_id ~ '^cus_[A-Za-z0-9]+$'),
 payment_method_id text check(payment_method_id ~ '^pm_[A-Za-z0-9]+$'),
 attempts integer not null default 0, first_attempt_at timestamptz,
 lease uuid, lease_until timestamptz, checked_at timestamptz not null default '-infinity'
);
create unique index dopmi_guardian_one_activation on private.dopmi_guardian_activations(donor_id)
 where status in ('pending','settled','attention');
create index dopmi_guardian_activation_candidates on private.dopmi_guardian_activations(checked_at,cycle_id) where status='pending';
create index dopmi_guardian_activation_donor on private.dopmi_guardian_activations(donor_id);
alter table private.dopmi_guardian_activations enable row level security;
revoke all on private.dopmi_guardian_activations from public,anon,authenticated;

create function private.dopmi_guardian_activation_view(target_cycle uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(a)||jsonb_build_object('gross_cents',c.gross_cents,'cycle_key',c.cycle_key,
 'hold_expires_at',c.expires_at,'settlement',private.dopmi_guardian_settlement_view(c.id))
 from private.dopmi_guardian_activations a join private.dopmi_guardian_cycles c on c.id=a.cycle_id where a.cycle_id=target_cycle;
$$;
revoke all on function private.dopmi_guardian_activation_view(uuid) from public,anon,authenticated;

create function public.dopmi_guardian_activation_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a private.dopmi_guardian_activations; c private.dopmi_guardian_cycles; held jsonb; donor uuid; requested_key uuid; gross bigint;
begin
 if operation='prepare' then
 donor:=(data->>'donor_id')::uuid; requested_key:=(data->>'key')::uuid; gross:=(data->>'gross_cents')::bigint;
 if donor is null or requested_key is null or gross is null or gross not between 1000 and 1000000
 or data->>'consent_version' is distinct from 'guardian-2026-09-24' or data->>'consent' is distinct from 'true' then
 raise exception 'Autorización Guardián requerida' using errcode='22023'; end if;
 if not exists(select 1 from public.profiles p join auth.users u on u.id=p.id where p.id=donor and p.account_status='active' and u.email_confirmed_at is not null) then
 raise exception 'Cuenta Guardián no disponible' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-activation:'||donor,0));
 select * into c from private.dopmi_guardian_cycles where donor_id=donor and private.dopmi_guardian_cycles.cycle_key=requested_key;
 if found then
 select * into a from private.dopmi_guardian_activations where cycle_id=c.id;
 if not found or c.gross_cents<>gross then raise exception 'Intento Guardián ya utilizado' using errcode='22023'; end if;
 return private.dopmi_guardian_activation_view(c.id); end if;
 if exists(select 1 from private.dopmi_guardian_subscriptions where donor_id=donor)
 or exists(select 1 from private.dopmi_guardian_activations where donor_id=donor and status in ('pending','settled','attention')) then
 raise exception 'Guardián ya tiene un alta o suscripción' using errcode='22023'; end if;
 held:=public.dopmi_guardian_reserve(donor,requested_key,gross);
 -- Checkout requires at least 30 minutes. The persisted request expires in
 -- 35 minutes; its upper-net reservation includes a five-minute safety margin.
 update private.dopmi_guardian_cycles set expires_at=date_trunc('second',now())+interval '40 minutes' where id=(held->>'id')::uuid;
 insert into private.dopmi_guardian_activations(cycle_id,donor_id,consent_version,status,checkout_expires_at,return_url)
 values((held->>'id')::uuid,donor,'guardian-2026-09-24',case when held->>'status'='reserved' then 'pending' else 'no_capacity' end,date_trunc('second',now())+interval '35 minutes',data->>'return_url') returning * into a;
 elsif operation='lookup_session' then
 select * into a from private.dopmi_guardian_activations where session_id=data->>'session_id';
 if not found then return null; end if;
 elsif operation='candidates' then
 return coalesce((select jsonb_agg(x) from (select cycle_id from private.dopmi_guardian_activations
 where status='pending' order by checked_at,cycle_id limit 25)x),'[]');
 else
 select * into a from private.dopmi_guardian_activations where cycle_id=(data->>'cycle_id')::uuid for update;
 if not found then raise exception 'Alta Guardián no disponible' using errcode='22023'; end if;
 if operation='claim_checkout' then
 if a.status<>'pending' or a.session_id is not null then return null; end if;
 if a.lease_until>now() then return null; end if;
 if a.attempts=0 and a.checkout_expires_at<now()+interval '30 minutes' then
 update private.dopmi_guardian_activations set status='expired' where cycle_id=a.cycle_id;
 update private.dopmi_guardian_cycles set status='expired',reserved_cents=0 where id=a.cycle_id and status='reserved'; return null; end if;
 if a.attempts>=8 or a.first_attempt_at<now()-interval '23 hours' then
 update private.dopmi_guardian_activations set status='attention' where cycle_id=a.cycle_id; return null; end if;
 update private.dopmi_guardian_activations set lease=gen_random_uuid(),lease_until=now()+interval '2 minutes',
 attempts=attempts+1,first_attempt_at=coalesce(first_attempt_at,now()) where cycle_id=a.cycle_id returning * into a;
 elsif operation='save_checkout' then
 if coalesce(data->>'session_id','') !~ '^cs_(test_)?[A-Za-z0-9]+$' then raise exception 'Checkout inválido' using errcode='22023'; end if;
 if a.session_id is not null then
 if a.session_id<>data->>'session_id' then raise exception 'Checkout ya vinculado' using errcode='22023'; end if;
 elsif a.status<>'pending' or a.lease is distinct from (data->>'lease')::uuid or a.lease_until<=now() then
 raise exception 'Intento Guardián vencido' using errcode='40001';
 else update private.dopmi_guardian_activations set session_id=data->>'session_id',lease_until=null where cycle_id=a.cycle_id; end if;
 elsif operation='checkout_failed' then
 update private.dopmi_guardian_activations set lease_until=null where cycle_id=a.cycle_id and lease=(data->>'lease')::uuid and session_id is null;
 elsif operation in ('expire','fail_checkout') then
 -- Caller has freshly verified Stripe reports this persisted session expired
 -- and unpaid, or its completed payment failed. A later paid event must refund.
 if a.session_id is distinct from data->>'session_id' or a.session_id is null then raise exception 'Checkout no coincide' using errcode='22023'; end if;
 if a.status='pending' then
 update private.dopmi_guardian_activations set status=case when operation='fail_checkout' then 'failed' else 'expired' end where cycle_id=a.cycle_id;
 update private.dopmi_guardian_cycles set status='expired',reserved_cents=0 where id=a.cycle_id and status='reserved'; end if;
 elsif operation='checked' then update private.dopmi_guardian_activations set checked_at=now() where cycle_id=a.cycle_id;
 elsif operation<>'get' then raise exception 'Operación Guardián inválida' using errcode='22023'; end if;
 end if;
 return private.dopmi_guardian_activation_view(a.cycle_id);
end; $$;
revoke all on function public.dopmi_guardian_activation_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_activation_server(text,jsonb) to service_role;

-- Initial payments have a first-class Checkout identity instead of inventing
-- a subscription/invoice that does not exist yet. The allocation engine,
-- private transfer/refund jobs and immutable evidence stay shared.
alter table private.dopmi_guardian_settlements
 alter column invoice_id drop not null, alter column invoice_payment_id drop not null,
 add column checkout_session_id text unique references private.dopmi_guardian_activations(session_id),
 add constraint dopmi_guardian_settlement_source check(
 (checkout_session_id is null and invoice_id is not null and invoice_payment_id is not null) or
 (checkout_session_id is not null and invoice_id is null and invoice_payment_id is null));

create or replace function public.dopmi_guardian_settlement_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 c private.dopmi_guardian_cycles; s private.dopmi_guardian_settlements; b private.dopmi_guardian_invoice_cycles;
 initial_activation private.dopmi_guardian_activations; p private.dopmi_guardian_subscriptions; j private.dopmi_guardian_jobs; r record; owner uuid;
 fee bigint; platform bigint; net bigint; remaining bigint; available bigint; portion bigint;
 valid boolean; planned jsonb := '[]'; entry jsonb;
begin
 if operation='candidates' then
 return coalesce((select jsonb_agg(x) from (select binding.stripe_invoice_id as invoice_id from private.dopmi_guardian_invoice_cycles binding
 left join private.dopmi_guardian_settlements settled on settled.cycle_id=binding.cycle_id where settled.cycle_id is null order by binding.checked_at,binding.cycle_id limit 50)x),'[]');
 elsif operation='checked' then
 update private.dopmi_guardian_invoice_cycles set checked_at=now() where stripe_invoice_id=data->>'invoice_id'; return '{}';
 elsif operation='destination' then
 return (select jsonb_build_object('owner_id',target.owner_id,'account_id',a.account_id,'payable',private.dopmi_expense_payable(target))
 from public.dopmi_rescue_records target join private.dopmi_connect_accounts a on a.owner_id=target.owner_id where target.id=(data->>'expense_id')::uuid);
 elsif operation='get' then return private.dopmi_guardian_settlement_view((data->>'cycle_id')::uuid);
 elsif operation='lookup_invoice' then
 select * into b from private.dopmi_guardian_invoice_cycles where stripe_invoice_id=data->>'invoice_id';
 if not found then return null; end if;
 return to_jsonb(b)||jsonb_build_object('settlement',private.dopmi_guardian_settlement_view(b.cycle_id));
 elsif operation in ('settle','settle_initial') then
 if operation='settle_initial' then
 select * into initial_activation from private.dopmi_guardian_activations where session_id=data->>'checkout_session_id' for update;
 if not found or data->>'invoice_id' is not null or data->>'invoice_payment_id' is not null or data->>'subscription_id' is not null
 or coalesce(data->>'customer_id','') !~ '^cus_[A-Za-z0-9]+$' or coalesce(data->>'payment_method_id','') !~ '^pm_[A-Za-z0-9]+$' then
 raise exception 'Checkout Guardián sin vínculo válido' using errcode='22023'; end if;
 b.cycle_id:=initial_activation.cycle_id;
 else
 select * into b from private.dopmi_guardian_invoice_cycles where stripe_invoice_id=data->>'invoice_id';
 if not found then raise exception 'Factura sin reserva Guardián vinculada' using errcode='22023'; end if;
 end if;
 select * into c from private.dopmi_guardian_cycles where id=b.cycle_id for update;
 select * into p from private.dopmi_guardian_subscriptions where stripe_subscription_id=b.stripe_subscription_id;
 if (data->>'donor_id')::uuid is distinct from c.donor_id or data->>'subscription_id' is distinct from b.stripe_subscription_id
 or (operation='settle' and p.donor_id is distinct from c.donor_id) or (data->>'gross_cents')::bigint is distinct from c.gross_cents
 or coalesce(data->>'payment_intent_id','') !~ '^pi_[A-Za-z0-9]+$' or coalesce(data->>'charge_id','') !~ '^ch_[A-Za-z0-9]+$'
 or (operation='settle' and coalesce(data->>'invoice_payment_id','') !~ '^inpay_[A-Za-z0-9]+$') then
 raise exception 'Evidencia de pago Guardián no coincide' using errcode='22023'; end if;
 fee:=(data->>'stripe_fee_cents')::bigint; platform:=(c.gross_cents*2+50)/100; net:=c.gross_cents-platform-fee;
 if fee is null or fee<0 or net<=0 or net>c.gross_cents or (data->>'platform_fee_cents')::bigint is distinct from platform
 or (data->>'net_cents')::bigint is distinct from net then raise exception 'Comisiones o neto Guardián inválidos' using errcode='22023'; end if;
 select * into s from private.dopmi_guardian_settlements where cycle_id=c.id;
 if found then
 if s.evidence is distinct from data then raise exception 'Liquidación Guardián ya registrada con otra evidencia' using errcode='22023'; end if;
 return private.dopmi_guardian_settlement_view(c.id); end if;
 if exists(select 1 from public.dopmi_donations where stripe_payment_intent_id=data->>'payment_intent_id' or stripe_charge_id=data->>'charge_id')
 or exists(select 1 from private.dopmi_guardian_subscriptions where initial_payment_intent_id=data->>'payment_intent_id' or initial_charge_id=data->>'charge_id') then
 raise exception 'Cobro ya utilizado en otra aportación' using errcode='22023'; end if;
 for owner in select distinct expense.owner_id from private.dopmi_guardian_allocations a join public.dopmi_rescue_records expense on expense.id=a.expense_id
 where a.cycle_id=c.id order by expense.owner_id loop perform private.dopmi_rescue_lock(owner); end loop;
 valid:=c.status='reserved' and c.expires_at>now() and c.reserved_cents=c.gross_cents-platform
 and c.reserved_cents=(select coalesce(sum(amount_cents),0) from private.dopmi_guardian_allocations where cycle_id=c.id);
 remaining:=net;
 if valid then
 for r in select expense.*,a.amount_cents from private.dopmi_guardian_allocations a join public.dopmi_rescue_records expense on expense.id=a.expense_id
 where a.cycle_id=c.id order by expense.urgent desc,expense.approved_at,expense.id for update of expense loop
 portion:=least(remaining,r.amount_cents); exit when portion=0;
 select r.reimbursable_cents-coalesce(sum(d.allocated_cents+d.reserved_cents),0)-private.dopmi_guardian_reserved(r.id)+r.amount_cents into available
 from public.dopmi_donations d where d.expense_id=r.id;
 if r.owner_id=c.donor_id or not private.dopmi_expense_payable((select expense from public.dopmi_rescue_records expense where expense.id=r.id)) or available<portion then
 valid:=false; exit; end if;
 planned:=planned||jsonb_build_array(jsonb_build_object('expense_id',r.id,'amount_cents',portion,
 'destination',(select account_id from private.dopmi_connect_accounts where owner_id=r.owner_id)));
 remaining:=remaining-portion;
 end loop; end if;
 valid:=valid and remaining=0;
 insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,charge_id,invoice_payment_id,gross_cents,stripe_fee_cents,
 platform_fee_cents,allocated_cents,refund_cents,platform_loss_cents,evidence,checkout_session_id)
 values(c.id,b.stripe_invoice_id,data->>'payment_intent_id',data->>'charge_id',data->>'invoice_payment_id',c.gross_cents,fee,
 case when valid then platform else 0 end,case when valid then net else 0 end,case when valid then 0 else c.gross_cents end,case when valid then 0 else fee end,data,case when operation='settle_initial' then initial_activation.session_id else null end);
 if valid then
 for entry in select value from jsonb_array_elements(planned) loop
 update private.dopmi_guardian_allocations set allocated_cents=(entry->>'amount_cents')::bigint,destination=entry->>'destination'
 where cycle_id=c.id and expense_id=(entry->>'expense_id')::uuid;
 insert into private.dopmi_guardian_jobs(job_key,cycle_id,expense_id,kind) values('guardian-transfer:'||c.id||':'||(entry->>'expense_id'),c.id,(entry->>'expense_id')::uuid,'transfer');
 end loop;
 else insert into private.dopmi_guardian_jobs(job_key,cycle_id,kind) values('guardian-refund:'||c.id,c.id,'refund'); end if;
 update private.dopmi_guardian_cycles set status=case when valid then 'allocated' else 'refund_pending' end,reserved_cents=0 where id=c.id;
 if operation='settle_initial' then
 update private.dopmi_guardian_activations set status=case when valid then 'settled' else 'refund_pending' end,customer_id=data->>'customer_id',payment_method_id=data->>'payment_method_id' where cycle_id=c.id;
 end if;
 return private.dopmi_guardian_settlement_view(c.id);
 elsif operation='claim' then
 select * into j from private.dopmi_guardian_jobs job where ((job.status='ready' and job.available_at<=now()) or (job.status='running' and job.lease_until<now()))
 and (data->>'cycle_id' is null or job.cycle_id=(data->>'cycle_id')::uuid) order by job.available_at,job.id for update skip locked limit 1;
 if not found then return null; end if;
 if j.attempts>=8 or j.first_attempt_at<now()-interval '23 hours' then
 update private.dopmi_guardian_jobs set status='attention',error_code='retry_limit' where id=j.id;
 return jsonb_build_object('skipped',true,'status','attention'); end if;
 update private.dopmi_guardian_jobs set status='running',attempts=attempts+1,lease=gen_random_uuid(),lease_until=now()+interval '5 minutes',
 first_attempt_at=coalesce(first_attempt_at,now()) where id=j.id returning * into j; return to_jsonb(j);
 elsif operation='finish' then
 select * into j from private.dopmi_guardian_jobs where id=(data->>'job_id')::uuid and lease=(data->>'lease')::uuid for update;
 if not found then raise exception 'Intento Guardián vencido' using errcode='40001'; end if;
 if j.status='done' then return '{}'; end if;
 if j.status<>'running' or j.lease_until<=now() then raise exception 'Intento Guardián vencido' using errcode='40001'; end if;
 if data->>'error_code' is not null then
 update private.dopmi_guardian_jobs set status=case when coalesce((data->>'attention')::boolean,false) then 'attention' else 'ready' end,
 error_code=left(data->>'error_code',80),lease_until=null,available_at=now()+make_interval(secs=>least(3600,30*power(2,j.attempts)::integer)) where id=j.id;
 else
 if j.kind='transfer' then
 if coalesce(data->>'result_id','') !~ '^tr_[A-Za-z0-9]+$' then raise exception 'Transferencia Guardián inválida' using errcode='22023'; end if;
 update private.dopmi_guardian_allocations set stripe_transfer_id=data->>'result_id',transferred_at=now()
 where cycle_id=j.cycle_id and expense_id=j.expense_id and allocated_cents>0 and (stripe_transfer_id is null or stripe_transfer_id=data->>'result_id');
 else
 if coalesce(data->>'result_id','') !~ '^re_[A-Za-z0-9]+$' then raise exception 'Devolución Guardián inválida' using errcode='22023'; end if;
 update private.dopmi_guardian_settlements set stripe_refund_id=data->>'result_id',refunded_at=now()
 where cycle_id=j.cycle_id and refund_cents=gross_cents and allocated_cents=0 and (stripe_refund_id is null or stripe_refund_id=data->>'result_id'); end if;
 if not found then raise exception 'Resultado Guardián no coincide' using errcode='22023'; end if;
 if j.kind='refund' then
 perform 1 from private.dopmi_guardian_activations where cycle_id=j.cycle_id for update;
 update private.dopmi_guardian_cycles set status='refunded' where id=j.cycle_id;
 update private.dopmi_guardian_activations set status='refunded' where cycle_id=j.cycle_id;
 end if;
 update private.dopmi_guardian_jobs set status='done',lease_until=null,error_code=null where id=j.id;
 end if; return '{}';
 else raise exception 'Operación Guardián inválida' using errcode='22023'; end if;
end; $$;
revoke all on function public.dopmi_guardian_settlement_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_settlement_server(text,jsonb) to service_role;


commit;
