begin;
create table private.dopmi_guardian_schedule_jobs (
 cycle_id uuid primary key references private.dopmi_guardian_activations(cycle_id),
 status text not null default 'pending' check(status in ('pending','ready','attention','canceled')),
 charge_created bigint not null check(charge_created between 1 and 4102444800),
 next_billing_at timestamptz not null,
 price_id text unique check(price_id ~ '^price_[A-Za-z0-9]+$'),
 subscription_id text unique check(subscription_id ~ '^sub_[A-Za-z0-9]+$'),
 attempts integer not null default 0, first_attempt_at timestamptz,
 checked_at timestamptz not null default '-infinity',
 lease uuid, lease_until timestamptz, available_at timestamptz not null default now(), error_code text,
 check(status<>'ready' or (price_id is not null and subscription_id is not null))
);
create index dopmi_guardian_schedule_pending on private.dopmi_guardian_schedule_jobs(available_at,cycle_id) where status='pending';
create index dopmi_guardian_schedule_monitor on private.dopmi_guardian_schedule_jobs(checked_at,cycle_id) where subscription_id is not null and status<>'canceled';
create index dopmi_guardian_activation_scheduling on private.dopmi_guardian_activations(checked_at,cycle_id) where status='settled';
alter table private.dopmi_guardian_schedule_jobs enable row level security;
revoke all on private.dopmi_guardian_schedule_jobs from public,anon,authenticated;

create function private.dopmi_guardian_schedule_eligible(target_cycle uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.dopmi_guardian_activations a
 join private.dopmi_guardian_settlements s on s.cycle_id=a.cycle_id
 join public.profiles p on p.id=a.donor_id join auth.users u on u.id=p.id
 where a.cycle_id=target_cycle and a.status='settled' and s.allocated_cents>0 and s.refund_cents=0
 and p.account_status='active' and u.email_confirmed_at is not null
 and exists(select 1 from private.dopmi_guardian_jobs j where j.cycle_id=a.cycle_id and j.kind='transfer')
 and not exists(select 1 from private.dopmi_guardian_jobs j where j.cycle_id=a.cycle_id and (j.kind<>'transfer' or j.status<>'done')));
$$;
revoke all on function private.dopmi_guardian_schedule_eligible(uuid) from public,anon,authenticated;
create function private.dopmi_guardian_schedule_view(target_cycle uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(j)||jsonb_build_object('activation',private.dopmi_guardian_activation_view(j.cycle_id))
 from private.dopmi_guardian_schedule_jobs j where j.cycle_id=target_cycle;
$$;
revoke all on function private.dopmi_guardian_schedule_view(uuid) from public,anon,authenticated;

create function public.dopmi_guardian_schedule_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.dopmi_guardian_schedule_jobs; activation_record private.dopmi_guardian_activations; s private.dopmi_guardian_settlements;
 target uuid; charged bigint; next_date timestamptz;
begin
 if operation='candidates' then
 return coalesce((select jsonb_agg(x) from (select a.cycle_id from private.dopmi_guardian_activations a
 left join private.dopmi_guardian_schedule_jobs job on job.cycle_id=a.cycle_id
 where a.status='settled' and private.dopmi_guardian_schedule_eligible(a.cycle_id)
 and (job.cycle_id is null or (job.status='pending' and job.available_at<=now()))
 order by greatest(coalesce(job.available_at,'-infinity'),a.checked_at),a.cycle_id limit 20)x),'[]');
 elsif operation='monitor' then
 return coalesce((select jsonb_agg(x) from (select subscription_id from private.dopmi_guardian_schedule_jobs
 where subscription_id is not null and status<>'canceled' order by checked_at,cycle_id limit 20)x),'[]');
 elsif operation='lookup_subscription' then
 select * into j from private.dopmi_guardian_schedule_jobs where subscription_id=data->>'subscription_id';
 if not found then return null; end if; return private.dopmi_guardian_schedule_view(j.cycle_id);
 end if;
 target:=(data->>'cycle_id')::uuid;
 if operation='source' then
 if not private.dopmi_guardian_schedule_eligible(target) then raise exception 'Primer pago Guardián no entregado' using errcode='22023'; end if;
 return private.dopmi_guardian_activation_view(target);
 elsif operation='source_checked' then
 update private.dopmi_guardian_activations set checked_at=now() where cycle_id=target and status='settled'; return '{}';
 elsif operation='prepare' then
 if not private.dopmi_guardian_schedule_eligible(target) then raise exception 'Primer pago Guardián no entregado' using errcode='22023'; end if;
 charged:=(data->>'charge_created')::bigint;
 next_date:=((to_timestamp(charged) at time zone 'UTC')+interval '1 month') at time zone 'UTC';
 insert into private.dopmi_guardian_schedule_jobs(cycle_id,charge_created,next_billing_at,status,error_code)
 values(target,charged,next_date,case when next_date>now()+interval '48 hours' then 'pending' else 'attention' end,
 case when next_date>now()+interval '48 hours' then null else 'schedule_too_late' end) on conflict(cycle_id) do nothing;
 select * into j from private.dopmi_guardian_schedule_jobs where cycle_id=target for update;
 if j.charge_created is distinct from charged then raise exception 'Fecha de pago Guardián no coincide' using errcode='22023'; end if;
 return private.dopmi_guardian_schedule_view(target);
 end if;
 select * into j from private.dopmi_guardian_schedule_jobs where cycle_id=target for update;
 if not found then return null; end if;
 if operation='get' then return private.dopmi_guardian_schedule_view(target);
 elsif operation='observed' then update private.dopmi_guardian_schedule_jobs set checked_at=now() where cycle_id=target;
 elsif operation in ('canceled','attention') then
 if j.subscription_id is distinct from data->>'subscription_id' or j.subscription_id is null then raise exception 'Suscripción no coincide' using errcode='22023'; end if;
 if operation='canceled' then
 update private.dopmi_guardian_schedule_jobs set status='canceled',lease_until=null where cycle_id=target;
 update private.dopmi_guardian_subscriptions set status='canceled',canceled_at=coalesce(canceled_at,now()) where stripe_subscription_id=j.subscription_id;
 elsif j.status<>'canceled' then update private.dopmi_guardian_schedule_jobs set status='attention',error_code='subscription_changed',lease_until=null where cycle_id=target; end if;
 elsif operation='claim' then
 if j.status<>'pending' or j.available_at>now() or j.lease_until>now() then return null; end if;
 if j.attempts>=8 or j.first_attempt_at<now()-interval '23 hours' or j.next_billing_at<=now()+interval '24 hours'
 or not private.dopmi_guardian_schedule_eligible(target) then
 update private.dopmi_guardian_schedule_jobs set status='attention',error_code='schedule_retry_limit' where cycle_id=target; return null; end if;
 update private.dopmi_guardian_schedule_jobs set lease=gen_random_uuid(),lease_until=now()+interval '5 minutes',attempts=attempts+1,
 first_attempt_at=coalesce(first_attempt_at,now()) where cycle_id=target;
 else
 if j.status='ready' and operation='failed' then return private.dopmi_guardian_schedule_view(target); end if;
 if j.status<>'pending' or j.lease is distinct from (data->>'lease')::uuid or j.lease_until<=now() then raise exception 'Intento de calendario vencido' using errcode='40001'; end if;
 if operation='price' then
 if coalesce(data->>'price_id','') !~ '^price_[A-Za-z0-9]+$' or (j.price_id is not null and j.price_id<>data->>'price_id') then raise exception 'Precio no coincide' using errcode='22023'; end if;
 update private.dopmi_guardian_schedule_jobs set price_id=data->>'price_id' where cycle_id=target;
 elsif operation='subscription' then
 if j.price_id is null or coalesce(data->>'subscription_id','') !~ '^sub_[A-Za-z0-9]+$'
 or (j.subscription_id is not null and j.subscription_id<>data->>'subscription_id') then raise exception 'Suscripción no coincide' using errcode='22023'; end if;
 update private.dopmi_guardian_schedule_jobs set subscription_id=data->>'subscription_id' where cycle_id=target;
 elsif operation='ready' then
 if j.price_id is null or j.subscription_id is null or not private.dopmi_guardian_schedule_eligible(target) then raise exception 'Calendario incompleto' using errcode='22023'; end if;
 select * into activation_record from private.dopmi_guardian_activations where cycle_id=target;
 select * into s from private.dopmi_guardian_settlements where cycle_id=target;
 perform public.dopmi_guardian_subscription_server('register',jsonb_build_object('donor_id',activation_record.donor_id,
 'stripe_customer_id',activation_record.customer_id,'stripe_subscription_id',j.subscription_id,'stripe_price_id',j.price_id,
 'gross_cents',s.gross_cents,'initial_payment_intent_id',s.payment_intent_id,'initial_charge_id',s.charge_id));
 update private.dopmi_guardian_schedule_jobs set status='ready',lease_until=null,error_code=null where cycle_id=target;
 elsif operation='failed' then
 update private.dopmi_guardian_schedule_jobs set lease_until=null,error_code=left(data->>'error_code',80),
 available_at=now()+make_interval(secs=>least(3600,30*power(2,j.attempts)::integer)) where cycle_id=target;
 else raise exception 'Operación de calendario inválida' using errcode='22023'; end if;
 end if;
 return private.dopmi_guardian_schedule_view(target);
end; $$;
revoke all on function public.dopmi_guardian_schedule_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_schedule_server(text,jsonb) to service_role;
create or replace function private.dopmi_guardian_activation_view(target_cycle uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(a)||jsonb_build_object('gross_cents',c.gross_cents,'cycle_key',c.cycle_key,
 'hold_expires_at',c.expires_at,'settlement',private.dopmi_guardian_settlement_view(c.id),
 'schedule_status',j.status,'next_billing_at',j.next_billing_at)
 from private.dopmi_guardian_activations a join private.dopmi_guardian_cycles c on c.id=a.cycle_id
 left join private.dopmi_guardian_schedule_jobs j on j.cycle_id=a.cycle_id where a.cycle_id=target_cycle;
$$;
commit;
