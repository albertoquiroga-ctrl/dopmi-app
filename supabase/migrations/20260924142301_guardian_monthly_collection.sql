begin;
alter table private.dopmi_guardian_subscriptions
 add column collection_checked_at timestamptz not null default '-infinity',
 add column collection_cursor text;
create index dopmi_guardian_collection_scan on private.dopmi_guardian_subscriptions(collection_checked_at) where status='active';
create table private.dopmi_guardian_collection_jobs (
 invoice_id text primary key check(invoice_id ~ '^in_[A-Za-z0-9]+$'),
 cycle_id uuid not null unique references private.dopmi_guardian_invoice_cycles(cycle_id),
 subscription_id text not null references private.dopmi_guardian_subscriptions(stripe_subscription_id),
 customer_id text not null, price_id text not null, payment_method_id text not null,
 gross_cents bigint not null check(gross_cents between 1000 and 1000000),
 period_start bigint not null check(period_start between 1 and 4102444800),
 period_end bigint not null check(period_end>period_start and period_end<=4102444800),
 decision text not null check(decision in ('collect','skip')),
 status text not null default 'pending' check(status in ('pending','attention','paid','skipped')),
 pay_requested_at timestamptz, attempts integer not null default 0,
 first_attempt_at timestamptz, available_at timestamptz not null default now(),
 checked_at timestamptz not null default '-infinity', lease uuid, lease_until timestamptz, error_code text,
 unique(subscription_id,period_start)
);
create index dopmi_guardian_collection_queue on private.dopmi_guardian_collection_jobs(checked_at,available_at) where status in ('pending','attention');
alter table private.dopmi_guardian_collection_jobs enable row level security;
revoke all on private.dopmi_guardian_collection_jobs from public,anon,authenticated;
create function private.dopmi_guardian_collection_view(target_invoice text) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(j)||jsonb_build_object('cycle_status',c.status,'expires_at',c.expires_at)
 from private.dopmi_guardian_collection_jobs j join private.dopmi_guardian_cycles c on c.id=j.cycle_id where j.invoice_id=target_invoice;
$$;
revoke all on function private.dopmi_guardian_collection_view(text) from public,anon,authenticated;

-- Only a verified Stripe draft may enter prepare. The caller supplies its
-- immutable identity, never donor/amount authority. Reservation and binding
-- commit together. A pay marker is one-shot: uncertain delivery is read-only
-- reconciliation, never a new payment request after lease/idempotency expiry.
create function public.dopmi_guardian_collection_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 j private.dopmi_guardian_collection_jobs; p private.dopmi_guardian_subscriptions;
 a private.dopmi_guardian_activations; c private.dopmi_guardian_cycles;
 hold jsonb; target text:=data->>'invoice_id'; owner uuid; r record; available bigint; valid boolean;
begin
 if operation='sources' then
 return coalesce((select jsonb_agg(x) from (select p1.stripe_subscription_id as subscription_id,p1.collection_cursor as cursor
 from private.dopmi_guardian_subscriptions p1 join private.dopmi_guardian_schedule_jobs s on s.subscription_id=p1.stripe_subscription_id
 where p1.status='active' and s.status='ready' order by p1.collection_checked_at,p1.donor_id limit 10)x),'[]');
 elsif operation='source_checked' then
 update private.dopmi_guardian_subscriptions set collection_checked_at=now(),collection_cursor=data->>'cursor'
 where stripe_subscription_id=data->>'subscription_id'; return '{}';
 elsif operation='source' then
 return (select to_jsonb(p1)||jsonb_build_object('payment_method_id',a1.payment_method_id)
 from private.dopmi_guardian_subscriptions p1 join private.dopmi_guardian_schedule_jobs s on s.subscription_id=p1.stripe_subscription_id
 join private.dopmi_guardian_activations a1 on a1.cycle_id=s.cycle_id
 where p1.stripe_subscription_id=data->>'subscription_id' and p1.status='active' and s.status='ready');
 elsif operation='candidates' then
 return coalesce((select jsonb_agg(x) from (select invoice_id from private.dopmi_guardian_collection_jobs
 where status in ('pending','attention') and available_at<=now() order by checked_at,invoice_id limit 20)x),'[]');
 elsif operation='get' then return private.dopmi_guardian_collection_view(target);
 elsif operation='checked' then
 update private.dopmi_guardian_collection_jobs set checked_at=now() where invoice_id=target; return '{}';
 elsif operation='prepare' then
 if coalesce(target,'') !~ '^in_[A-Za-z0-9]+$' or (data->>'cycle_key') is null then
 raise exception 'Factura de renovación inválida' using errcode='22023'; end if;
 select * into p from private.dopmi_guardian_subscriptions where stripe_subscription_id=data->>'subscription_id' for update;
 if not found then raise exception 'Suscripción no registrada' using errcode='42501'; end if;
 select * into j from private.dopmi_guardian_collection_jobs where invoice_id=target;
 if found then
 if j.subscription_id<>p.stripe_subscription_id or j.period_start is distinct from (data->>'period_start')::bigint
 or j.period_end is distinct from (data->>'period_end')::bigint then raise exception 'Factura ya vinculada' using errcode='22023'; end if;
 return private.dopmi_guardian_collection_view(target); end if;
 select act.* into a from private.dopmi_guardian_schedule_jobs s join private.dopmi_guardian_activations act on act.cycle_id=s.cycle_id
 where s.subscription_id=p.stripe_subscription_id and s.status='ready';
 if not found or p.status<>'active' then raise exception 'Calendario no disponible' using errcode='42501'; end if;
 if exists(select 1 from private.dopmi_guardian_collection_jobs where subscription_id=p.stripe_subscription_id
 and pay_requested_at is not null and status not in ('paid','skipped')) then
 raise exception 'Cobro anterior pendiente de conciliación' using errcode='55000'; end if;
 hold:=public.dopmi_guardian_reserve(p.donor_id,(data->>'cycle_key')::uuid,p.gross_cents);
 perform public.dopmi_guardian_subscription_server('bind_invoice',jsonb_build_object('stripe_subscription_id',p.stripe_subscription_id,
 'stripe_invoice_id',target,'cycle_id',hold->>'id'));
 insert into private.dopmi_guardian_collection_jobs(invoice_id,cycle_id,subscription_id,customer_id,price_id,payment_method_id,gross_cents,
 period_start,period_end,decision)
 values(target,(hold->>'id')::uuid,p.stripe_subscription_id,p.stripe_customer_id,p.stripe_price_id,a.payment_method_id,p.gross_cents,
 (data->>'period_start')::bigint,(data->>'period_end')::bigint,
 case when hold->>'status'='reserved' and coalesce((data->>'fresh')::boolean,false) then 'collect' else 'skip' end);
 if not coalesce((data->>'fresh')::boolean,false) then
 update private.dopmi_guardian_cycles set status='released',reserved_cents=0 where id=(hold->>'id')::uuid and status='reserved'; end if;
 else
 select * into j from private.dopmi_guardian_collection_jobs where invoice_id=target for update;
 if not found then raise exception 'Factura de renovación no vinculada' using errcode='22023'; end if;
 if operation='paid' then
 if not exists(select 1 from private.dopmi_guardian_settlements where cycle_id=j.cycle_id and invoice_id=target) then
 raise exception 'Pago sin liquidación verificada' using errcode='22023'; end if;
 update private.dopmi_guardian_collection_jobs set status='paid',lease_until=null,error_code=null where invoice_id=target;
 elsif j.status in ('paid','skipped') then return private.dopmi_guardian_collection_view(target);
 elsif operation='claim' then
 if j.status<>'pending' or j.available_at>now() or j.lease_until>now() then return null; end if;
 if j.attempts>=8 or j.first_attempt_at<now()-interval '23 hours' then
 update private.dopmi_guardian_collection_jobs set status='attention',error_code='retry_limit' where invoice_id=target;
 return null; end if;
 update private.dopmi_guardian_collection_jobs set attempts=attempts+1,first_attempt_at=coalesce(first_attempt_at,now()),
 lease=gen_random_uuid(),lease_until=now()+interval '5 minutes' where invoice_id=target;
 else
 if j.lease is null or j.lease_until is null or j.lease is distinct from (data->>'lease')::uuid or j.lease_until<=now() then
 raise exception 'Turno de cobro vencido' using errcode='55000'; end if;
 if operation='authorize_pay' then
 if j.pay_requested_at is not null or j.decision<>'collect' then return null; end if;
 select * into c from private.dopmi_guardian_cycles where id=j.cycle_id for update;
 for owner in select distinct expense.owner_id from private.dopmi_guardian_allocations al join public.dopmi_rescue_records expense on expense.id=al.expense_id
 where al.cycle_id=c.id order by expense.owner_id loop perform private.dopmi_rescue_lock(owner); end loop;
 valid:=c.status='reserved' and c.expires_at>now()+interval '2 minutes'
 and c.reserved_cents=c.gross_cents-(c.gross_cents*2+50)/100
 and c.reserved_cents=(select coalesce(sum(amount_cents),0) from private.dopmi_guardian_allocations where cycle_id=c.id)
 and exists(select 1 from private.dopmi_guardian_subscriptions where stripe_subscription_id=j.subscription_id and status='active')
 and exists(select 1 from private.dopmi_guardian_schedule_jobs where subscription_id=j.subscription_id and status='ready')
 and exists(select 1 from public.profiles pr join auth.users u on u.id=pr.id where pr.id=c.donor_id and pr.account_status='active' and u.email_confirmed_at is not null);
 for r in select expense.*,al.amount_cents from private.dopmi_guardian_allocations al join public.dopmi_rescue_records expense on expense.id=al.expense_id where al.cycle_id=c.id loop
 select r.reimbursable_cents-coalesce(sum(d.allocated_cents+d.reserved_cents),0)-private.dopmi_guardian_reserved(r.id)+r.amount_cents into available
 from public.dopmi_donations d where d.expense_id=r.id;
 if r.owner_id=c.donor_id or not private.dopmi_expense_payable((select expense from public.dopmi_rescue_records expense where expense.id=r.id)) or available<r.amount_cents then valid:=false; end if;
 end loop;
 if valid then update private.dopmi_guardian_collection_jobs set pay_requested_at=now() where invoice_id=target;
 else
 update private.dopmi_guardian_collection_jobs set decision='skip',error_code='reservation_unavailable' where invoice_id=target;
 update private.dopmi_guardian_cycles set status='released',reserved_cents=0 where id=c.id and status='reserved'; end if;
 elsif operation='skip' then
 if j.pay_requested_at is not null then raise exception 'Cobro requiere conciliación' using errcode='55000'; end if;
 update private.dopmi_guardian_collection_jobs set decision='skip' where invoice_id=target;
 update private.dopmi_guardian_cycles set status='released',reserved_cents=0 where id=j.cycle_id and status='reserved';
 elsif operation='voided' then
 if j.pay_requested_at is not null then raise exception 'Cobro requiere conciliación' using errcode='55000'; end if;
 update private.dopmi_guardian_collection_jobs set status='skipped',decision='skip',lease_until=null,error_code=null where invoice_id=target;
 update private.dopmi_guardian_cycles set status='released',reserved_cents=0 where id=j.cycle_id and status='reserved';
 elsif operation='failed' then
 update private.dopmi_guardian_collection_jobs set status=case when pay_requested_at is not null or coalesce((data->>'attention')::boolean,false) then 'attention' else 'pending' end,
 lease_until=null,error_code=left(data->>'error_code',80),available_at=now()+make_interval(secs=>least(3600,30*power(2,j.attempts)::integer)) where invoice_id=target;
 else raise exception 'Operación de cobro inválida' using errcode='22023'; end if;
 end if;
 end if;
 return private.dopmi_guardian_collection_view(target);
end; $$;
revoke all on function public.dopmi_guardian_collection_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_collection_server(text,jsonb) to service_role;
commit;
