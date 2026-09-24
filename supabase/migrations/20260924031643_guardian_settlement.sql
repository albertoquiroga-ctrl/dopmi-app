begin;
alter table private.dopmi_guardian_cycles drop constraint dopmi_guardian_cycles_status_check;
alter table private.dopmi_guardian_cycles add constraint dopmi_guardian_cycles_status_check check(status in ('reserved','skipped','released','expired','allocated','refund_pending','refunded'));
alter table private.dopmi_guardian_allocations
 add column allocated_cents bigint not null default 0 check(allocated_cents>=0 and allocated_cents<=amount_cents),
 add column destination text, add column stripe_transfer_id text unique, add column transferred_at timestamptz;
alter table private.dopmi_guardian_invoice_cycles add column checked_at timestamptz not null default '-infinity';
create table private.dopmi_guardian_settlements (
 cycle_id uuid primary key references private.dopmi_guardian_cycles(id), invoice_id text not null unique check(invoice_id ~ '^in_[A-Za-z0-9]+$'),
 payment_intent_id text not null unique check(payment_intent_id ~ '^pi_[A-Za-z0-9]+$'),
 charge_id text not null unique check(charge_id ~ '^ch_[A-Za-z0-9]+$'),
 invoice_payment_id text not null unique check(invoice_payment_id ~ '^inpay_[A-Za-z0-9]+$'),
 gross_cents bigint not null check(gross_cents between 1000 and 1000000), stripe_fee_cents bigint not null check(stripe_fee_cents>=0),
 platform_fee_cents bigint not null check(platform_fee_cents>=0), allocated_cents bigint not null check(allocated_cents>=0),
 refund_cents bigint not null check(refund_cents>=0), platform_loss_cents bigint not null default 0 check(platform_loss_cents>=0),
 stripe_refund_id text unique, refunded_at timestamptz, evidence jsonb not null, created_at timestamptz not null default now(),
 check(gross_cents+platform_loss_cents=stripe_fee_cents+platform_fee_cents+allocated_cents+refund_cents),
 check((allocated_cents>0 and refund_cents=0) or (allocated_cents=0 and refund_cents=gross_cents))
);
create table private.dopmi_guardian_jobs (
 id uuid primary key default gen_random_uuid(), job_key text not null unique,
 cycle_id uuid not null references private.dopmi_guardian_settlements(cycle_id), expense_id uuid references public.dopmi_rescue_records(id),
 kind text not null check(kind in ('transfer','refund')), status text not null default 'ready' check(status in ('ready','running','done','attention')),
 attempts integer not null default 0, first_attempt_at timestamptz, available_at timestamptz not null default now(), lease uuid, lease_until timestamptz, error_code text,
 check((kind='transfer' and expense_id is not null) or (kind='refund' and expense_id is null))
);
create index dopmi_guardian_jobs_ready on private.dopmi_guardian_jobs(status,available_at);
create index dopmi_guardian_jobs_cycle on private.dopmi_guardian_jobs(cycle_id);
create index dopmi_guardian_jobs_expense on private.dopmi_guardian_jobs(expense_id);
alter table private.dopmi_guardian_settlements enable row level security;
alter table private.dopmi_guardian_jobs enable row level security;
revoke all on private.dopmi_guardian_settlements,private.dopmi_guardian_jobs from public,anon,authenticated;

-- Capacity stays occupied by confirmed allocations after their hold expires.
-- All existing capacity readers already subtract this helper, including H4.
create or replace function private.dopmi_guardian_reserved(target_expense uuid) returns bigint
language sql stable security definer set search_path='' as $$
 select coalesce(sum(case when c.status='reserved' and c.expires_at>now() then a.amount_cents else a.allocated_cents end),0)
 from private.dopmi_guardian_allocations a join private.dopmi_guardian_cycles c on c.id=a.cycle_id where a.expense_id=target_expense;
$$;
create function private.dopmi_guardian_funded(target_expense uuid, transferred_only boolean default false) returns bigint
language sql stable security definer set search_path='' as $$
 select coalesce(sum(a.allocated_cents),0) from private.dopmi_guardian_allocations a where a.expense_id=target_expense and (not transferred_only or a.stripe_transfer_id is not null);
$$;
revoke all on function private.dopmi_guardian_funded(uuid,boolean) from public,anon,authenticated;
create or replace function private.dopmi_guard_funded_expense() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.kind='expense' and (new.reimbursable_cents<>old.reimbursable_cents or new.status<>old.status or new.owner_id<>old.owner_id or new.parent_id<>old.parent_id)
 and (exists(select 1 from public.dopmi_donations where expense_id=old.id and allocated_cents>0) or private.dopmi_guardian_funded(old.id)>0) then
 raise exception 'Este gasto ya tiene aportaciones asignadas. Conserva su aprobación e historial' using errcode='22023'; end if;
 return new;
end; $$;
create function private.dopmi_guardian_settlement_view(target_cycle uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select (to_jsonb(s)-'evidence') || jsonb_build_object('donor_id',c.donor_id,'status',c.status,
 'allocations',coalesce((select jsonb_agg(jsonb_build_object('expense_id',a.expense_id,'rescuer_id',r.owner_id,
 'amount_cents',a.allocated_cents,'destination',a.destination,'stripe_transfer_id',a.stripe_transfer_id) order by a.expense_id)
 from private.dopmi_guardian_allocations a join public.dopmi_rescue_records r on r.id=a.expense_id where a.cycle_id=c.id and a.allocated_cents>0),'[]'::jsonb))
 from private.dopmi_guardian_settlements s join private.dopmi_guardian_cycles c on c.id=s.cycle_id where s.cycle_id=target_cycle;
$$;
revoke all on function private.dopmi_guardian_settlement_view(uuid) from public,anon,authenticated;

-- Only service_role submits independently verified Stripe evidence.
create function public.dopmi_guardian_settlement_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 c private.dopmi_guardian_cycles; s private.dopmi_guardian_settlements; b private.dopmi_guardian_invoice_cycles;
 p private.dopmi_guardian_subscriptions; j private.dopmi_guardian_jobs; r record; owner uuid;
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
 elsif operation='settle' then
 select * into b from private.dopmi_guardian_invoice_cycles where stripe_invoice_id=data->>'invoice_id';
 if not found then raise exception 'Factura sin reserva Guardián vinculada' using errcode='22023'; end if;
 select * into c from private.dopmi_guardian_cycles where id=b.cycle_id for update;
 select * into p from private.dopmi_guardian_subscriptions where stripe_subscription_id=b.stripe_subscription_id;
 if (data->>'donor_id')::uuid is distinct from c.donor_id or data->>'subscription_id' is distinct from b.stripe_subscription_id
 or p.donor_id is distinct from c.donor_id or (data->>'gross_cents')::bigint is distinct from c.gross_cents
 or coalesce(data->>'payment_intent_id','') !~ '^pi_[A-Za-z0-9]+$' or coalesce(data->>'charge_id','') !~ '^ch_[A-Za-z0-9]+$'
 or coalesce(data->>'invoice_payment_id','') !~ '^inpay_[A-Za-z0-9]+$' then
 raise exception 'Evidencia de pago Guardián no coincide' using errcode='22023'; end if;
 fee:=(data->>'stripe_fee_cents')::bigint; platform:=(c.gross_cents*2+50)/100; net:=c.gross_cents-platform-fee;
 if fee is null or fee<0 or net<=0 or net>c.gross_cents or (data->>'platform_fee_cents')::bigint is distinct from platform
 or (data->>'net_cents')::bigint is distinct from net then raise exception 'Comisiones o neto Guardián inválidos' using errcode='22023'; end if;
 select * into s from private.dopmi_guardian_settlements where cycle_id=c.id;
 if found then
 if s.evidence is distinct from data then raise exception 'Liquidación Guardián ya registrada con otra evidencia' using errcode='22023'; end if;
 return private.dopmi_guardian_settlement_view(c.id); end if;
 if exists(select 1 from public.dopmi_donations where stripe_payment_intent_id=data->>'payment_intent_id' or stripe_charge_id=data->>'charge_id')
 or p.initial_payment_intent_id=data->>'payment_intent_id' or p.initial_charge_id=data->>'charge_id' then
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
 platform_fee_cents,allocated_cents,refund_cents,platform_loss_cents,evidence)
 values(c.id,b.stripe_invoice_id,data->>'payment_intent_id',data->>'charge_id',data->>'invoice_payment_id',c.gross_cents,fee,
 case when valid then platform else 0 end,case when valid then net else 0 end,case when valid then 0 else c.gross_cents end,case when valid then 0 else fee end,data);
 if valid then
 for entry in select value from jsonb_array_elements(planned) loop
 update private.dopmi_guardian_allocations set allocated_cents=(entry->>'amount_cents')::bigint,destination=entry->>'destination'
 where cycle_id=c.id and expense_id=(entry->>'expense_id')::uuid;
 insert into private.dopmi_guardian_jobs(job_key,cycle_id,expense_id,kind) values('guardian-transfer:'||c.id||':'||(entry->>'expense_id'),c.id,(entry->>'expense_id')::uuid,'transfer');
 end loop;
 else insert into private.dopmi_guardian_jobs(job_key,cycle_id,kind) values('guardian-refund:'||c.id,c.id,'refund'); end if;
 update private.dopmi_guardian_cycles set status=case when valid then 'allocated' else 'refund_pending' end,reserved_cents=0 where id=c.id;
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
 if j.kind='refund' then update private.dopmi_guardian_cycles set status='refunded' where id=j.cycle_id; end if;
 update private.dopmi_guardian_jobs set status='done',lease_until=null,error_code=null where id=j.id;
 end if; return '{}';
 else raise exception 'Operación Guardián inválida' using errcode='22023'; end if;
end; $$;
revoke all on function public.dopmi_guardian_settlement_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_settlement_server(text,jsonb) to service_role;

-- Keep public aggregate fields accurate without exposing payment identities.
do $patch$
declare definition text;
begin
 definition:=pg_get_functiondef('public.dopmi_expense_funding(uuid)'::regprocedure);
 if position('reserved := reserved+private.dopmi_guardian_reserved(r.id);' in definition)=0 then raise exception 'Review funding patch'; end if;
 execute replace(definition,'reserved := reserved+private.dopmi_guardian_reserved(r.id);',
 'reserved := reserved+private.dopmi_guardian_reserved(r.id)-private.dopmi_guardian_funded(r.id);
 assigned := assigned+private.dopmi_guardian_funded(r.id); transferred := transferred+private.dopmi_guardian_funded(r.id,true);');
 definition:=pg_get_functiondef('public.dopmi_rescue_public(uuid,integer)'::regprocedure);
 if position(') as funded_cents,' in definition)=0 or position(') as transferred_cents,' in definition)=0 then raise exception 'Review public totals patch'; end if;
 definition:=replace(definition,') as funded_cents,',') + (select coalesce(sum(private.dopmi_guardian_funded(e.id)),0) from public.dopmi_rescue_records e where e.id=r.id or (r.kind=''case'' and e.parent_id=r.id)) as funded_cents,');
 definition:=replace(definition,') as transferred_cents,',') + (select coalesce(sum(private.dopmi_guardian_funded(e.id,true)),0) from public.dopmi_rescue_records e where e.id=r.id or (r.kind=''case'' and e.parent_id=r.id)) as transferred_cents,');
 execute definition;
end $patch$;
commit;
