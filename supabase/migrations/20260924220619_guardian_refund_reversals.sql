begin;

alter table private.dopmi_guardian_settlements add column refund_checked_at timestamptz not null default '-infinity';
create index dopmi_guardian_refund_scan on private.dopmi_guardian_settlements(refund_checked_at,cycle_id) where allocated_cents>0;
alter table private.dopmi_guardian_allocations add column reversed_cents bigint not null default 0 check(reversed_cents>=0 and reversed_cents<=allocated_cents);
create table private.dopmi_guardian_refund_adjustments (
 cycle_id uuid primary key references private.dopmi_guardian_settlements(cycle_id),
 before_state jsonb not null, status text not null default 'review' check(status in ('pending','review','completed')),
 confirmed_refund_cents bigint not null default 0 check(confirmed_refund_cents>=0),
 refunds jsonb not null default '[]' check(jsonb_typeof(refunds)='array'),
 has_pending boolean not null default false, disputed boolean not null default false,
 lease uuid, lease_until timestamptz, available_at timestamptz not null default now(), error_code text,
 created_at timestamptz not null default now(), confirmed_at timestamptz, completed_at timestamptz
);
create table private.dopmi_guardian_reversals (
 cycle_id uuid not null, expense_id uuid not null, transfer_id text not null unique check(transfer_id ~ '^tr_[A-Za-z0-9]+$'),
 amount_cents bigint not null check(amount_cents>0), destination text not null,
 attempts integer not null default 0 check(attempts between 0 and 8), first_attempt_at timestamptz, write_lease uuid,
 reversal_id text unique check(reversal_id ~ '^trr_[A-Za-z0-9]+$'), confirmed_at timestamptz,
 primary key(cycle_id,expense_id), foreign key(cycle_id,expense_id) references private.dopmi_guardian_allocations(cycle_id,expense_id),
 check((reversal_id is null)=(confirmed_at is null))
);
create index dopmi_guardian_reversals_expense on private.dopmi_guardian_reversals(expense_id);
alter table private.dopmi_guardian_refund_adjustments enable row level security;
alter table private.dopmi_guardian_reversals enable row level security;
revoke all on private.dopmi_guardian_refund_adjustments,private.dopmi_guardian_reversals from public,anon,authenticated;

create function private.dopmi_guardian_refund_view(target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select private.dopmi_guardian_settlement_view(s.cycle_id)||jsonb_build_object(
 'adjustment',(select to_jsonb(a)-'before_state' from private.dopmi_guardian_refund_adjustments a where a.cycle_id=s.cycle_id),
 'reversals',coalesce((select jsonb_agg(to_jsonb(r) order by r.expense_id) from private.dopmi_guardian_reversals r where r.cycle_id=s.cycle_id),'[]'))
 from private.dopmi_guardian_settlements s where s.cycle_id=target;
$$;
revoke all on function private.dopmi_guardian_refund_view(uuid) from public,anon,authenticated;

-- Cycle -> adjustment -> rescuer locks, in the same order as settlement and
-- reservation. Transfer results may still be recorded while a refund is under
-- review, but reversals start only after every transfer job is durably done.
create function public.dopmi_guardian_refund_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c private.dopmi_guardian_cycles; s private.dopmi_guardian_settlements;
 a private.dopmi_guardian_refund_adjustments; r private.dopmi_guardian_reversals;
 target uuid:=(data->>'cycle_id')::uuid; total bigint; owner uuid; ready boolean;
begin
 if operation='lookup' then
 return (select jsonb_build_object('cycle_id',x.cycle_id) from private.dopmi_guardian_settlements x
 where (data->>'charge_id' is not null and x.charge_id=data->>'charge_id')
 or (data->>'transfer_id' is not null and exists(select 1 from private.dopmi_guardian_allocations al where al.cycle_id=x.cycle_id and al.stripe_transfer_id=data->>'transfer_id')));
 elsif operation='candidates' then
 return coalesce((select jsonb_agg(x) from (select cycle_id from private.dopmi_guardian_settlements where allocated_cents>0
 order by refund_checked_at,cycle_id limit 25)x),'[]');
 elsif operation='checked' then
 update private.dopmi_guardian_settlements set refund_checked_at=now() where cycle_id=target; return '{}';
 elsif operation='get' then return private.dopmi_guardian_refund_view(target);
 end if;
 select * into c from private.dopmi_guardian_cycles where id=target for update;
 select * into s from private.dopmi_guardian_settlements where cycle_id=target;
 if c.id is null or s.cycle_id is null then raise exception 'Ciclo no liquidado' using errcode='22023'; end if;
 select * into a from private.dopmi_guardian_refund_adjustments where cycle_id=target for update;
 if a.status='completed' then return private.dopmi_guardian_refund_view(target); end if;
 if operation='observe' then
 if s.allocated_cents<=0 or data->>'charge_id' is distinct from s.charge_id
 or data->>'payment_intent_id' is distinct from s.payment_intent_id
 or (data->>'gross_cents')::bigint is distinct from s.gross_cents
 or coalesce(jsonb_typeof(data->'refunds'),'')<>'array'
 or jsonb_array_length(data->'refunds')>100
 or coalesce(jsonb_typeof(data->'has_pending'),'')<>'boolean'
 or coalesce(jsonb_typeof(data->'disputed'),'')<>'boolean' then
 raise exception 'Evidencia de devolución inválida' using errcode='22023'; end if;
 if exists(select 1 from jsonb_array_elements(data->'refunds') x where coalesce(x->>'id','') !~ '^re_[A-Za-z0-9]+$'
 or coalesce((x->>'amount')::bigint,0)<=0)
 or (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(data->'refunds') x) then
 raise exception 'Devoluciones repetidas o inválidas' using errcode='22023'; end if;
 select coalesce(sum((x->>'amount')::bigint),0) into total from jsonb_array_elements(data->'refunds') x;
 if total>s.gross_cents or total is distinct from (data->>'confirmed_refund_cents')::bigint then
 raise exception 'Importe devuelto no coincide' using errcode='22023'; end if;
 if a.cycle_id is not null and total<a.confirmed_refund_cents then raise exception 'Lectura antigua de devolución' using errcode='40001'; end if;
 insert into private.dopmi_guardian_refund_adjustments(cycle_id,before_state) values(target,private.dopmi_guardian_settlement_view(target)) on conflict do nothing;
 ready:=total=s.gross_cents and not (data->>'has_pending')::boolean and not (data->>'disputed')::boolean;
 update private.dopmi_guardian_refund_adjustments set confirmed_refund_cents=total,refunds=data->'refunds',
 has_pending=(data->>'has_pending')::boolean,disputed=(data->>'disputed')::boolean,
 status=case when ready then 'pending' else 'review' end,
 confirmed_at=case when total=s.gross_cents then coalesce(confirmed_at,now()) else confirmed_at end,
 error_code=case when ready then error_code else 'guardian_refund_review' end where cycle_id=target;
 return private.dopmi_guardian_refund_view(target);
 elsif operation='claim' then
 if a.cycle_id is null or a.confirmed_refund_cents<>s.gross_cents or a.has_pending or a.disputed
 or a.lease_until>now() or a.available_at>now() then return null; end if;
 if not exists(select 1 from private.dopmi_guardian_allocations where cycle_id=target and allocated_cents>0)
 or exists(select 1 from private.dopmi_guardian_allocations al where al.cycle_id=target and al.allocated_cents>0
 and (al.stripe_transfer_id is null or al.transferred_at is null or not exists(select 1 from private.dopmi_guardian_jobs j
 where j.cycle_id=target and j.expense_id=al.expense_id and j.kind='transfer' and j.status='done')))
 or (select sum(allocated_cents) from private.dopmi_guardian_allocations where cycle_id=target)<>s.allocated_cents then
 update private.dopmi_guardian_refund_adjustments set status='review',error_code='guardian_transfer_unconfirmed' where cycle_id=target;
 return null; end if;
 insert into private.dopmi_guardian_reversals(cycle_id,expense_id,transfer_id,amount_cents,destination)
 select cycle_id,expense_id,stripe_transfer_id,allocated_cents,destination from private.dopmi_guardian_allocations where cycle_id=target and allocated_cents>0 on conflict do nothing;
 update private.dopmi_guardian_refund_adjustments set status='pending',lease=gen_random_uuid(),lease_until=now()+interval '5 minutes' where cycle_id=target;
 return private.dopmi_guardian_refund_view(target);
 end if;
 if a.cycle_id is null or a.lease is distinct from (data->>'lease')::uuid or a.lease_until is null or a.lease_until<=now() then
 raise exception 'Conciliación vencida' using errcode='40001'; end if;
 if operation='fail' then
 update private.dopmi_guardian_refund_adjustments set status='review',error_code=left(data->>'error_code',80),
 lease_until=null,available_at=now()+interval '1 minute' where cycle_id=target;
 return private.dopmi_guardian_refund_view(target);
 end if;
 if a.status<>'pending' or a.disputed or a.has_pending or a.confirmed_refund_cents<>s.gross_cents then
 raise exception 'Devolución requiere revisión' using errcode='40001'; end if;
 if operation in ('authorize','confirmed') then
 select * into r from private.dopmi_guardian_reversals where cycle_id=target and expense_id=(data->>'expense_id')::uuid for update;
 if not found then raise exception 'Asignación no disponible' using errcode='22023'; end if;
 if operation='authorize' then
 if r.reversal_id is not null or r.attempts>=8 or r.first_attempt_at<now()-interval '23 hours' then return jsonb_build_object('allowed',false); end if;
 if r.write_lease is distinct from a.lease then
 update private.dopmi_guardian_reversals set attempts=attempts+1,first_attempt_at=coalesce(first_attempt_at,now()),write_lease=a.lease
 where cycle_id=target and expense_id=r.expense_id; end if;
 return jsonb_build_object('allowed',true,'key','guardian-reversal:'||target||':'||r.expense_id);
 end if;
 if data->>'transfer_id' is distinct from r.transfer_id or (data->>'amount_cents')::bigint is distinct from r.amount_cents
 or coalesce(data->>'reversal_id','') !~ '^trr_[A-Za-z0-9]+$' or (r.reversal_id is not null and r.reversal_id<>data->>'reversal_id') then
 raise exception 'Reversión no coincide' using errcode='22023'; end if;
 update private.dopmi_guardian_reversals set reversal_id=data->>'reversal_id',confirmed_at=coalesce(confirmed_at,now()) where cycle_id=target and expense_id=r.expense_id;
 return private.dopmi_guardian_refund_view(target);
 elsif operation='complete' then
 if not exists(select 1 from private.dopmi_guardian_reversals where cycle_id=target)
 or exists(select 1 from private.dopmi_guardian_reversals where cycle_id=target and reversal_id is null) then
 update private.dopmi_guardian_refund_adjustments set lease_until=null where cycle_id=target;
 return private.dopmi_guardian_refund_view(target); end if;
 if (select sum(amount_cents) from private.dopmi_guardian_reversals where cycle_id=target)<>s.allocated_cents then
 raise exception 'Reversión incompleta' using errcode='22023'; end if;
 for owner in select distinct expense.owner_id from private.dopmi_guardian_allocations al join public.dopmi_rescue_records expense on expense.id=al.expense_id
 where al.cycle_id=target order by expense.owner_id loop perform private.dopmi_rescue_lock(owner); end loop;
 update private.dopmi_guardian_allocations set reversed_cents=allocated_cents where cycle_id=target;
 update private.dopmi_guardian_settlements set allocated_cents=0,platform_fee_cents=0,refund_cents=gross_cents,platform_loss_cents=stripe_fee_cents,
 stripe_refund_id=a.refunds->0->>'id',refunded_at=a.confirmed_at where cycle_id=target;
 update private.dopmi_guardian_cycles set status='refunded' where id=target;
 update private.dopmi_guardian_refund_adjustments set status='completed',completed_at=now(),lease_until=null,error_code=null where cycle_id=target;
 return private.dopmi_guardian_refund_view(target);
 end if;
 raise exception 'Operación inválida' using errcode='22023';
end; $$;
revoke all on function public.dopmi_guardian_refund_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_refund_server(text,jsonb) to service_role;

create or replace function private.dopmi_guardian_reserved(target_expense uuid) returns bigint
language sql stable security definer set search_path='' as $$
 select coalesce(sum(case when c.status='reserved' and c.expires_at>now() then a.amount_cents else a.allocated_cents-a.reversed_cents end),0)
 from private.dopmi_guardian_allocations a join private.dopmi_guardian_cycles c on c.id=a.cycle_id where a.expense_id=target_expense;
$$;
create or replace function private.dopmi_guardian_funded(target_expense uuid, transferred_only boolean default false) returns bigint
language sql stable security definer set search_path='' as $$
 select coalesce(sum(a.allocated_cents-a.reversed_cents),0) from private.dopmi_guardian_allocations a
 where a.expense_id=target_expense and (not transferred_only or a.stripe_transfer_id is not null);
$$;

-- Preserve original allocations in history; describe the confirmed refund
-- separately from the recovery of transfers. Processor identifiers stay private.
do $patch$
declare definition text;
begin
 definition:=pg_get_functiondef('private.dopmi_guardian_settlement_view(uuid)'::regprocedure);
 definition:=replace(definition,'''status'',c.status,','''status'',c.status,''external_refund_pending'',exists(select 1 from private.dopmi_guardian_refund_adjustments ra where ra.cycle_id=c.id and ra.status<>''completed''),');
 if position('external_refund_pending' in definition)=0 then raise exception 'Review settlement projection patch'; end if;
 execute definition;
 definition:=pg_get_functiondef('public.dopmi_guardian_history(timestamptz,uuid,integer)'::regprocedure);
 definition:=replace(definition,'left join private.dopmi_guardian_settlements s on s.cycle_id=c.id','left join private.dopmi_guardian_settlements s on s.cycle_id=c.id left join private.dopmi_guardian_refund_adjustments ra on ra.cycle_id=c.id');
 definition:=replace(definition,'when s.refund_cents>0 then', 'when ra.status=''review'' then ''refund_review'' when ra.status=''pending'' then ''refund_reconciling'' when s.refund_cents>0 then');
 definition:=replace(definition,'''needs_review'',exists(','''needs_review'',coalesce(ra.status=''review'',false) or exists(');
 definition:=replace(definition,'''refund_cents'',coalesce(s.refund_cents,0),','''refund_cents'',coalesce(s.refund_cents,0),''reversed_cents'',totals.reversed_cents,');
 definition:=replace(definition,'then s.refund_cents else 0 end','then s.refund_cents else coalesce(ra.confirmed_refund_cents,0) end');
 definition:=replace(definition,'sum(x.allocated_cents) filter','sum(x.allocated_cents-x.reversed_cents) filter');
 definition:=replace(definition,'select count(*) as allocation_count,','select count(*) as allocation_count,coalesce(sum(x.reversed_cents),0) as reversed_cents,');
 if position('refund_reconciling' in definition)=0 or position('sum(x.allocated_cents-x.reversed_cents)' in definition)=0
 or position('sum(x.reversed_cents)' in definition)=0 then raise exception 'Review refund history patch'; end if;
 execute definition;
 definition:=pg_get_functiondef('public.dopmi_guardian_history_allocations(uuid,uuid,integer)'::regprocedure);
 definition:=replace(definition,'''status'',case when a.stripe_transfer_id','''status'',case when a.reversed_cents=a.allocated_cents then ''reversed'' when a.stripe_transfer_id');
 if position('a.reversed_cents=a.allocated_cents' in definition)=0 then raise exception 'Review allocation history patch'; end if;
 execute definition;
end $patch$;
commit;
