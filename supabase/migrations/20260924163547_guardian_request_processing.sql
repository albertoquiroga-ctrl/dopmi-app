begin;
alter table private.dopmi_guardian_subscriptions
 add column change_request_id uuid,
 add column change_lease uuid,
 add column change_lease_until timestamptz;
alter table private.dopmi_guardian_requests
 add column old_price_id text,
 add column price_id text unique check(price_id ~ '^price_[A-Za-z0-9]+$'),
 add column item_id text check(item_id ~ '^si_[A-Za-z0-9]+$'),
 add column period_start bigint,
 add column effective_from bigint,
 add column billing_anchor bigint,
 add column latest_invoice_id text,
 add column mutation_requested_at timestamptz,
 add column write_lease uuid,
 add column attempts integer not null default 0 check(attempts>=0),
 add column first_attempt_at timestamptz,
 add column checked_at timestamptz not null default '-infinity',
 add column available_at timestamptz not null default now(),
 add column error_code text,
 add constraint dopmi_guardian_change_period check(period_start is null or
 (period_start between 1 and 4102444800 and effective_from>period_start and effective_from<=4102444800 and billing_anchor between 1 and 4102444800));
create index dopmi_guardian_request_queue on private.dopmi_guardian_requests(checked_at,available_at) where status='pending';

create table private.dopmi_guardian_prices (
 subscription_id text not null references private.dopmi_guardian_subscriptions(stripe_subscription_id),
 revision bigint not null check(revision>=0),
 effective_from bigint not null check(effective_from between 1 and 4102444800),
 price_id text not null check(price_id ~ '^price_[A-Za-z0-9]+$'),
 gross_cents bigint not null check(gross_cents between 1000 and 1000000),
 request_id uuid unique references private.dopmi_guardian_requests(id),
 primary key(subscription_id,revision)
);
create index dopmi_guardian_prices_period on private.dopmi_guardian_prices(subscription_id,effective_from desc,revision desc);
alter table private.dopmi_guardian_prices enable row level security;
revoke all on private.dopmi_guardian_prices from public,anon,authenticated;
insert into private.dopmi_guardian_prices(subscription_id,revision,effective_from,price_id,gross_cents)
 select stripe_subscription_id,0,1,stripe_price_id,gross_cents from private.dopmi_guardian_subscriptions;
create function private.dopmi_guardian_first_price() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into private.dopmi_guardian_prices(subscription_id,revision,effective_from,price_id,gross_cents)
 values(new.stripe_subscription_id,0,1,new.stripe_price_id,new.gross_cents);
 return new;
end; $$;
revoke all on function private.dopmi_guardian_first_price() from public,anon,authenticated;
create trigger dopmi_guardian_first_price after insert on private.dopmi_guardian_subscriptions
 for each row execute function private.dopmi_guardian_first_price();
create function private.dopmi_guardian_price_at(subscription text,starts bigint) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('stripe_price_id',price_id,'gross_cents',gross_cents)
 from private.dopmi_guardian_prices where subscription_id=subscription and effective_from<=starts
 order by effective_from desc,revision desc limit 1;
$$;
revoke all on function private.dopmi_guardian_price_at(text,bigint) from public,anon,authenticated;

-- Paid evidence uses the immutable invoice snapshot, never the latest plan.
alter table private.dopmi_guardian_invoice_cycles
 add column price_id text,
 add column gross_cents bigint,
 add column period_start bigint;
update private.dopmi_guardian_invoice_cycles b set price_id=p.stripe_price_id,gross_cents=c.gross_cents
 from private.dopmi_guardian_subscriptions p,private.dopmi_guardian_cycles c
 where p.stripe_subscription_id=b.stripe_subscription_id and c.id=b.cycle_id;
alter table private.dopmi_guardian_invoice_cycles alter column price_id set not null,alter column gross_cents set not null;
alter table private.dopmi_guardian_invoice_cycles
 add constraint dopmi_guardian_invoice_price check(price_id ~ '^price_[A-Za-z0-9]+$'),
 add constraint dopmi_guardian_invoice_gross check(gross_cents between 1000 and 1000000),
 add constraint dopmi_guardian_invoice_period check(period_start between 1 and 4102444800);

create function private.dopmi_guardian_change_view(target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(r)||jsonb_build_object('lease',p.change_lease,'lease_until',p.change_lease_until,
 'customer_id',p.stripe_customer_id,'registered_price_id',p.stripe_price_id,'registered_gross_cents',p.gross_cents,
 'plan_status',p.status,'cancellation_requested_at',p.cancellation_requested_at,
 'payment_method_id',a.payment_method_id,'schedule_status',s.status)
 from private.dopmi_guardian_requests r join private.dopmi_guardian_subscriptions p on p.stripe_subscription_id=r.subscription_id
 join private.dopmi_guardian_schedule_jobs s on s.subscription_id=p.stripe_subscription_id
 join private.dopmi_guardian_activations a on a.cycle_id=s.cycle_id where r.id=target;
$$;
revoke all on function private.dopmi_guardian_change_view(uuid) from public,anon,authenticated;

create function public.dopmi_guardian_change_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r private.dopmi_guardian_requests; p private.dopmi_guardian_subscriptions;
 target uuid:=(data->>'request_id')::uuid; subscription text;
begin
 if operation in ('candidates','lookup_subscription') then
 return coalesce((select jsonb_agg(x) from (select id as request_id from private.dopmi_guardian_requests
 where status='pending' and available_at<=now() and (operation='candidates' or subscription_id=data->>'subscription_id')
 order by (kind='cancel') desc,checked_at,id limit 20)x),'[]');
 elsif operation='get' then return private.dopmi_guardian_change_view(target); end if;
 select subscription_id into subscription from private.dopmi_guardian_requests where id=target;
 select * into p from private.dopmi_guardian_subscriptions where stripe_subscription_id=subscription for update;
 if not found then raise exception 'Solicitud Guardián no disponible' using errcode='22023'; end if;
 select * into r from private.dopmi_guardian_requests where id=target for update;
 if r.status<>'pending' then
 if p.change_request_id=r.id and p.change_lease=(data->>'lease')::uuid then
 update private.dopmi_guardian_subscriptions set change_lease_until=null where donor_id=p.donor_id; end if;
 if operation='claim' then return null; end if;
 return private.dopmi_guardian_change_view(target);
 end if;
 if operation='claim' then
 if r.available_at>now() or p.change_lease_until>now() then return null; end if;
 update private.dopmi_guardian_subscriptions set change_request_id=r.id,change_lease=gen_random_uuid(),change_lease_until=now()+interval '5 minutes' where donor_id=p.donor_id;
 update private.dopmi_guardian_requests set checked_at=now() where id=r.id;
 else
 if p.change_request_id is distinct from r.id or p.change_lease is null or p.change_lease_until is null
 or p.change_lease is distinct from (data->>'lease')::uuid or p.change_lease_until<=now() then
 raise exception 'Turno de cambio Guardián vencido' using errcode='55000'; end if;
 if operation in ('snapshot','write','price','mutation','applied') and r.kind='amount'
 and (p.status<>'active' or p.cancellation_requested_at is not null or p.management_revision<>r.revision) then
 raise exception 'Cambio Guardián sustituido por cancelación' using errcode='55000'; end if;
 if operation='snapshot' then
 if r.kind<>'amount' or coalesce(data->>'item_id','') !~ '^si_[A-Za-z0-9]+$'
 or coalesce((data->>'period_start')::bigint,0) not between 1 and 4102444800
 or coalesce((data->>'effective_from')::bigint,0)<=(data->>'period_start')::bigint
 or (data->>'effective_from')::bigint>4102444800 or coalesce((data->>'billing_anchor')::bigint,0) not between 1 and 4102444800
 or (data->>'latest_invoice_id' is not null and data->>'latest_invoice_id' !~ '^in_[A-Za-z0-9]+$') then
 raise exception 'Calendario de cambio inválido' using errcode='22023'; end if;
 if r.item_id is not null then
 if r.item_id is distinct from data->>'item_id' or r.period_start is distinct from (data->>'period_start')::bigint
 or r.effective_from is distinct from (data->>'effective_from')::bigint or r.billing_anchor is distinct from (data->>'billing_anchor')::bigint
 or r.latest_invoice_id is distinct from data->>'latest_invoice_id' then raise exception 'Calendario de cambio ya fijado' using errcode='22023'; end if;
 else
 if exists(select 1 from private.dopmi_guardian_collection_jobs where subscription_id=r.subscription_id and period_start>=(data->>'effective_from')::bigint) then
 raise exception 'Período de cambio ya preparado' using errcode='55000'; end if;
 update private.dopmi_guardian_requests set old_price_id=p.stripe_price_id,item_id=data->>'item_id',period_start=(data->>'period_start')::bigint,
 effective_from=(data->>'effective_from')::bigint,billing_anchor=(data->>'billing_anchor')::bigint,latest_invoice_id=data->>'latest_invoice_id' where id=r.id;
 end if;
 elsif operation='write' then
 if r.write_lease=p.change_lease then return private.dopmi_guardian_change_view(target); end if;
 if r.attempts>=8 or r.first_attempt_at<now()-interval '23 hours' then
 update private.dopmi_guardian_requests set error_code='change_retry_limit',available_at=now()+interval '1 hour' where id=r.id;
 update private.dopmi_guardian_subscriptions set change_lease_until=null where donor_id=p.donor_id; return null; end if;
 update private.dopmi_guardian_requests set attempts=attempts+1,first_attempt_at=coalesce(first_attempt_at,now()),write_lease=p.change_lease where id=r.id;
 elsif operation='price' then
 if r.kind<>'amount' or r.item_id is null or r.write_lease is distinct from p.change_lease or coalesce(data->>'price_id','') !~ '^price_[A-Za-z0-9]+$'
 or (r.price_id is not null and r.price_id is distinct from data->>'price_id') then raise exception 'Precio de cambio inválido' using errcode='22023'; end if;
 update private.dopmi_guardian_requests set price_id=data->>'price_id' where id=r.id;
 elsif operation='mutation' then
 if r.write_lease is distinct from p.change_lease or (r.kind='amount' and (r.price_id is null or r.item_id is null)) then raise exception 'Cambio sin autorización' using errcode='22023'; end if;
 update private.dopmi_guardian_requests set mutation_requested_at=coalesce(mutation_requested_at,now()) where id=r.id;
 elsif operation='applied' then
 if r.kind<>'amount' or r.price_id is null or r.mutation_requested_at is null or r.item_id is null
 or data->>'subscription_id' is distinct from r.subscription_id or data->>'customer_id' is distinct from p.stripe_customer_id
 or data->>'price_id' is distinct from r.price_id or data->>'item_id' is distinct from r.item_id
 or (data->>'effective_from')::bigint is distinct from r.effective_from or (data->>'gross_cents')::bigint is distinct from r.new_gross_cents then
 raise exception 'Cambio de precio no confirmado' using errcode='22023'; end if;
 insert into private.dopmi_guardian_prices(subscription_id,revision,effective_from,price_id,gross_cents,request_id)
 values(r.subscription_id,r.revision,r.effective_from,r.price_id,r.new_gross_cents,r.id);
 update private.dopmi_guardian_subscriptions set stripe_price_id=r.price_id,gross_cents=r.new_gross_cents,change_lease_until=null where donor_id=p.donor_id;
 update private.dopmi_guardian_schedule_jobs set price_id=r.price_id,status='ready',error_code=null where subscription_id=r.subscription_id and status<>'canceled';
 update private.dopmi_guardian_requests set status='applied',applied_at=now(),error_code=null where id=r.id;
 elsif operation='canceled' then
 if data->>'subscription_id' is distinct from r.subscription_id or data->>'customer_id' is distinct from p.stripe_customer_id
 or data->>'status' is distinct from 'canceled' then raise exception 'Cancelación Stripe no confirmada' using errcode='22023'; end if;
 update private.dopmi_guardian_subscriptions set status='canceled',canceled_at=coalesce(canceled_at,now()),change_lease_until=null where donor_id=p.donor_id;
 update private.dopmi_guardian_schedule_jobs set status='canceled',lease_until=null where subscription_id=r.subscription_id;
 update private.dopmi_guardian_requests set status='superseded',error_code=null where subscription_id=r.subscription_id and kind='amount' and status='pending';
 if r.kind='cancel' then update private.dopmi_guardian_requests set status='applied',applied_at=now(),error_code=null where id=r.id; end if;
 elsif operation='failed' then
 update private.dopmi_guardian_requests set error_code=left(data->>'error_code',80),available_at=now()+interval '5 minutes' where id=r.id;
 update private.dopmi_guardian_subscriptions set change_lease_until=null where donor_id=p.donor_id;
 else raise exception 'Operación de cambio inválida' using errcode='22023'; end if;
 end if;
 return private.dopmi_guardian_change_view(target);
end; $$;
revoke all on function public.dopmi_guardian_change_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_change_server(text,jsonb) to service_role;

create or replace function private.dopmi_guardian_request_view(target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',r.id,'kind',r.kind,'revision',r.revision,'status',r.status,
 'previous_gross_cents',r.previous_gross_cents,'new_gross_cents',r.new_gross_cents,
 'created_at',r.created_at,'applied_at',r.applied_at,'effective_at',case when r.status='applied' and r.kind='amount' then to_timestamp(r.effective_from) else null end)
 from private.dopmi_guardian_requests r where r.id=target;
$$;

-- Patch only known definitions, fail atomically if their contracts changed.
do $patch$
declare definition text; old_text text; new_text text;
begin
 definition:=pg_get_functiondef('public.dopmi_guardian_subscription_server(text,jsonb)'::regprocedure);
 old_text:='cycle.gross_cents<>plan.gross_cents';
 if position(old_text in definition)=0 then raise exception 'Review invoice binding'; end if;
 definition:=replace(definition,'cycle.gross_cents<>plan.gross_cents',
 'cycle.gross_cents<>coalesce((private.dopmi_guardian_price_at(subscription,(data->>''period_start'')::bigint)->>''gross_cents'')::bigint,plan.gross_cents)');
 old_text:='insert into private.dopmi_guardian_invoice_cycles(cycle_id,stripe_subscription_id,stripe_invoice_id)
    values(target_cycle_id,subscription,invoice)';
 new_text:='insert into private.dopmi_guardian_invoice_cycles(cycle_id,stripe_subscription_id,stripe_invoice_id,price_id,gross_cents,period_start)
    values(target_cycle_id,subscription,invoice,coalesce(private.dopmi_guardian_price_at(subscription,(data->>''period_start'')::bigint)->>''stripe_price_id'',plan.stripe_price_id),cycle.gross_cents,(data->>''period_start'')::bigint)';
 if position(old_text in definition)=0 then raise exception 'Review invoice snapshot insertion'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:='if binding.stripe_subscription_id<>subscription or binding.stripe_invoice_id<>invoice then';
 new_text:='if binding.stripe_subscription_id<>subscription or binding.stripe_invoice_id<>invoice or binding.gross_cents is distinct from cycle.gross_cents or binding.period_start is distinct from (data->>''period_start'')::bigint then';
 if position(old_text in definition)=0 then raise exception 'Review immutable invoice snapshot'; end if;
 execute replace(definition,old_text,new_text);

 definition:=pg_get_functiondef('public.dopmi_guardian_collection_server(text,jsonb)'::regprocedure);
 old_text:='return (select to_jsonb(p1)||jsonb_build_object(''payment_method_id'',a1.payment_method_id)';
 new_text:='return (select to_jsonb(p1)||case when data->>''period_start'' is null then ''{}''::jsonb else private.dopmi_guardian_price_at(p1.stripe_subscription_id,(data->>''period_start'')::bigint) end||jsonb_build_object(''payment_method_id'',a1.payment_method_id)';
 if position(old_text in definition)=0 then raise exception 'Review historical invoice source'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:='hold:=public.dopmi_guardian_reserve(p.donor_id,(data->>''cycle_key'')::uuid,p.gross_cents);';
 new_text:='p.gross_cents:=(private.dopmi_guardian_price_at(p.stripe_subscription_id,(data->>''period_start'')::bigint)->>''gross_cents'')::bigint;
 p.stripe_price_id:=private.dopmi_guardian_price_at(p.stripe_subscription_id,(data->>''period_start'')::bigint)->>''stripe_price_id'';
 if p.gross_cents is null or p.stripe_price_id is null then raise exception ''Período Guardián desconocido'' using errcode=''22023''; end if; '||old_text;
 if position(old_text in definition)=0 then raise exception 'Review historical reservation'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:='''stripe_invoice_id'',target,''cycle_id'',hold->>''id''));';
 new_text:='''stripe_invoice_id'',target,''cycle_id'',hold->>''id'',''period_start'',data->>''period_start''));';
 if position(old_text in definition)=0 then raise exception 'Review historical invoice binding'; end if;
 execute replace(definition,old_text,new_text);

 -- Monitoring and owner changes acquire the subscription before the schedule.
 -- A stale monitor must not flag a replacement price that was just confirmed.
 definition:=pg_get_functiondef('public.dopmi_guardian_schedule_server(text,jsonb)'::regprocedure);
 old_text:='select * into j from private.dopmi_guardian_schedule_jobs where cycle_id=target for update;';
 new_text:='if operation in (''canceled'',''attention'') then perform 1 from private.dopmi_guardian_subscriptions where stripe_subscription_id=(select subscription_id from private.dopmi_guardian_schedule_jobs where cycle_id=target) for update; end if; '||old_text;
 if position(old_text in definition)=0 then raise exception 'Review monitor lock order'; end if;
 definition:=replace(definition,old_text,new_text);
 old_text:='elsif j.status<>''canceled'' then update private.dopmi_guardian_schedule_jobs';
 new_text:='elsif j.status<>''canceled'' and j.price_id is not distinct from data->>''expected_price_id'' and not exists(select 1 from private.dopmi_guardian_requests where subscription_id=j.subscription_id and status=''pending'') then update private.dopmi_guardian_schedule_jobs';
 if position(old_text in definition)=0 then raise exception 'Review stale monitor protection'; end if;
 execute replace(definition,old_text,new_text);
end $patch$;

create or replace function private.dopmi_guardian_schedule_view(target_cycle uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(j)||jsonb_build_object('activation',private.dopmi_guardian_activation_view(j.cycle_id),
 'lifecycle_pending',exists(select 1 from private.dopmi_guardian_requests r where r.subscription_id=j.subscription_id and r.status='pending'))
 from private.dopmi_guardian_schedule_jobs j where j.cycle_id=target_cycle;
$$;
commit;
