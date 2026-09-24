begin;
alter table private.dopmi_guardian_subscriptions
 add column payment_method_id text check(payment_method_id ~ '^pm_[A-Za-z0-9]+$'),
 add column payment_method_updated_at timestamptz;

create table private.dopmi_guardian_method_jobs (
 id uuid primary key default gen_random_uuid(),
 donor_id uuid not null references public.profiles(id),
 subscription_id text not null references private.dopmi_guardian_subscriptions(stripe_subscription_id),
 request_key uuid not null, revision bigint not null, consent_version text not null check(consent_version='guardian-2026-09-24'),
 status text not null default 'pending' check(status in ('pending','attention','applied','expired','superseded')),
 created_at timestamptz not null default now(), expires_at timestamptz not null,
 return_url text not null check(return_url ~ '^https://'),
 session_id text unique check(session_id ~ '^cs_(test_)?[A-Za-z0-9]+$'),
 setup_intent_id text unique check(setup_intent_id ~ '^seti_[A-Za-z0-9]+$'),
 payment_method_id text check(payment_method_id ~ '^pm_[A-Za-z0-9]+$'),
 billing_anchor bigint check(billing_anchor between 1 and 4102444800),
 checkout_attempts int not null default 0, checkout_first_at timestamptz,
 update_attempts int not null default 0, update_first_at timestamptz,
 mutation_requested_at timestamptz, applied_at timestamptz,
 checked_at timestamptz not null default '-infinity', error_code text,
 unique(donor_id,request_key)
);
create unique index dopmi_guardian_one_method_job on private.dopmi_guardian_method_jobs(subscription_id) where status in ('pending','attention');
create index dopmi_guardian_method_queue on private.dopmi_guardian_method_jobs(checked_at,id) where status in ('pending','attention');
alter table private.dopmi_guardian_method_jobs enable row level security;
revoke all on private.dopmi_guardian_method_jobs from public,anon,authenticated;

create function private.dopmi_guardian_method_pending(subscription text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.dopmi_guardian_method_jobs where subscription_id=subscription and status in ('pending','attention'));
$$;
revoke all on function private.dopmi_guardian_method_pending(text) from public,anon,authenticated;
create function private.dopmi_guardian_method_view(target uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(j)||jsonb_build_object('customer_id',p.stripe_customer_id,'price_id',p.stripe_price_id,
 'gross_cents',p.gross_cents,'current_method_id',coalesce(p.payment_method_id,a.payment_method_id),
 'lease',p.change_lease,'lease_until',p.change_lease_until,'plan_status',p.status,
 'cancellation_requested_at',p.cancellation_requested_at)
 from private.dopmi_guardian_method_jobs j join private.dopmi_guardian_subscriptions p on p.stripe_subscription_id=j.subscription_id
 join private.dopmi_guardian_schedule_jobs s on s.subscription_id=p.stripe_subscription_id
 join private.dopmi_guardian_activations a on a.cycle_id=s.cycle_id where j.id=target;
$$;
revoke all on function private.dopmi_guardian_method_view(uuid) from public,anon,authenticated;

-- Server boundary authenticates the owner; only this service RPC may handle
-- Stripe identities. A method change and a collection cannot start together.
create function public.dopmi_guardian_method_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p private.dopmi_guardian_subscriptions; j private.dopmi_guardian_method_jobs;
 target uuid:=(data->>'job_id')::uuid; actor uuid; subscription text;
begin
 if operation='candidates' then
 return coalesce((select jsonb_agg(x) from (select id as job_id from private.dopmi_guardian_method_jobs
 where status in ('pending','attention') order by checked_at,id limit 20)x),'[]');
 elsif operation='lookup_session' then
 return (select private.dopmi_guardian_method_view(id) from private.dopmi_guardian_method_jobs where session_id=data->>'session_id');
 elsif operation='get' then return private.dopmi_guardian_method_view(target);
 elsif operation='prepare' then
 actor:=(data->>'donor_id')::uuid;
 if actor is null or data->>'key' is null or data->>'consent' is distinct from 'true'
 or data->>'consent_version' is distinct from 'guardian-2026-09-24' then raise exception 'Autorización de medio requerida' using errcode='22023'; end if;
 select * into p from private.dopmi_guardian_subscriptions where donor_id=actor for update;
 if not found then raise exception 'Plan no disponible' using errcode='42501'; end if;
 select * into j from private.dopmi_guardian_method_jobs where donor_id=actor and request_key=(data->>'key')::uuid;
 if found then
 if j.revision-1 is distinct from (data->>'revision')::bigint then raise exception 'Clave ya utilizada' using errcode='22023'; end if;
 return private.dopmi_guardian_method_view(j.id); end if;
 if p.status<>'active' or p.cancellation_requested_at is not null
 or not exists(select 1 from public.profiles a join auth.users u on u.id=a.id where a.id=actor and a.account_status='active' and u.email_confirmed_at is not null)
 or not exists(select 1 from private.dopmi_guardian_schedule_jobs where subscription_id=p.stripe_subscription_id and status='ready') then
 raise exception 'Plan no disponible' using errcode='42501'; end if;
 if p.management_revision is distinct from (data->>'revision')::bigint then raise exception 'Actualiza tu plan' using errcode='40001'; end if;
 if private.dopmi_guardian_method_pending(p.stripe_subscription_id)
 or exists(select 1 from private.dopmi_guardian_requests where subscription_id=p.stripe_subscription_id and status='pending')
 or exists(select 1 from private.dopmi_guardian_collection_jobs where subscription_id=p.stripe_subscription_id and status not in ('paid','skipped')) then
 raise exception 'Espera la conciliación pendiente' using errcode='55000'; end if;
 insert into private.dopmi_guardian_method_jobs(donor_id,subscription_id,request_key,revision,consent_version,expires_at,return_url)
 values(actor,p.stripe_subscription_id,(data->>'key')::uuid,p.management_revision+1,'guardian-2026-09-24',date_trunc('second',now())+interval '35 minutes',data->>'return_url') returning * into j;
 update private.dopmi_guardian_subscriptions set management_revision=j.revision where donor_id=actor;
 return private.dopmi_guardian_method_view(j.id);
 end if;
 select subscription_id into subscription from private.dopmi_guardian_method_jobs where id=target;
 select * into p from private.dopmi_guardian_subscriptions where stripe_subscription_id=subscription for update;
 if not found then raise exception 'Cambio de medio no disponible' using errcode='22023'; end if;
 select * into j from private.dopmi_guardian_method_jobs where id=target for update;
 if operation='release' then
 if p.change_request_id=j.id and p.change_lease=(data->>'lease')::uuid then
 update private.dopmi_guardian_subscriptions set change_lease_until=null where donor_id=p.donor_id; end if;
 update private.dopmi_guardian_method_jobs set checked_at=now() where id=j.id;
 return private.dopmi_guardian_method_view(j.id); end if;
 if j.status not in ('pending','attention') then
 if operation='claim' then return null; end if; return private.dopmi_guardian_method_view(j.id); end if;
 if p.status<>'active' or p.cancellation_requested_at is not null or p.management_revision<>j.revision
 or not exists(select 1 from public.profiles a join auth.users u on u.id=a.id where a.id=p.donor_id and a.account_status='active' and u.email_confirmed_at is not null) then
 update private.dopmi_guardian_method_jobs set status='superseded' where id=j.id;
 if operation='claim' then return null; end if; return private.dopmi_guardian_method_view(j.id); end if;
 if operation='claim' then
 if p.change_lease_until>now() then return null; end if;
 update private.dopmi_guardian_subscriptions set change_request_id=j.id,change_lease=gen_random_uuid(),change_lease_until=now()+interval '5 minutes' where donor_id=p.donor_id;
 update private.dopmi_guardian_method_jobs set checked_at=now() where id=j.id;
 else
 if p.change_request_id is distinct from j.id or p.change_lease is distinct from (data->>'lease')::uuid or p.change_lease_until is null or p.change_lease_until<=now() then
 raise exception 'Turno de medio vencido' using errcode='55000'; end if;
 if operation='write_checkout' then
 if j.session_id is not null then return null; end if;
 if j.checkout_attempts=0 and j.expires_at<now()+interval '30 minutes' then
 update private.dopmi_guardian_method_jobs set status='expired' where id=j.id; return null; end if;
 if j.checkout_attempts>=8 or j.checkout_first_at<now()-interval '23 hours' then
 update private.dopmi_guardian_method_jobs set status='attention',error_code='setup_retry_limit' where id=j.id; return null; end if;
 update private.dopmi_guardian_method_jobs set checkout_attempts=checkout_attempts+1,checkout_first_at=coalesce(checkout_first_at,now()) where id=j.id;
 elsif operation='session' then
 if j.checkout_attempts=0 or coalesce(data->>'session_id','') !~ '^cs_(test_)?[A-Za-z0-9]+$'
 or (j.session_id is not null and j.session_id<>data->>'session_id') then raise exception 'Sesión no coincide' using errcode='22023'; end if;
 update private.dopmi_guardian_method_jobs set session_id=data->>'session_id' where id=j.id;
 elsif operation='verified' then
 if j.session_id is null or data->>'session_id' is distinct from j.session_id
 or coalesce(data->>'setup_intent_id','') !~ '^seti_[A-Za-z0-9]+$' or coalesce(data->>'payment_method_id','') !~ '^pm_[A-Za-z0-9]+$'
 or (j.setup_intent_id is not null and (j.setup_intent_id<>data->>'setup_intent_id' or j.payment_method_id<>data->>'payment_method_id')) then
 raise exception 'Medio no verificado' using errcode='22023'; end if;
 update private.dopmi_guardian_method_jobs set setup_intent_id=data->>'setup_intent_id',payment_method_id=data->>'payment_method_id' where id=j.id;
 elsif operation='snapshot' then
 if coalesce((data->>'billing_anchor')::bigint,0) not between 1 and 4102444800
 or (j.billing_anchor is not null and j.billing_anchor<>(data->>'billing_anchor')::bigint) then
 raise exception 'Aniversario del plan cambió' using errcode='22023'; end if;
 update private.dopmi_guardian_method_jobs set billing_anchor=(data->>'billing_anchor')::bigint where id=j.id;
 elsif operation='write_update' then
 if j.payment_method_id is null or j.billing_anchor is null then raise exception 'Medio no verificado' using errcode='22023'; end if;
 if j.update_attempts>=8 or j.update_first_at<now()-interval '23 hours' then
 update private.dopmi_guardian_method_jobs set status='attention',error_code='method_retry_limit' where id=j.id; return null; end if;
 update private.dopmi_guardian_method_jobs set update_attempts=update_attempts+1,update_first_at=coalesce(update_first_at,now()),mutation_requested_at=coalesce(mutation_requested_at,now()) where id=j.id;
 elsif operation='applied' then
 if j.setup_intent_id is null or j.payment_method_id is null or j.mutation_requested_at is null
 or data->>'payment_method_id' is distinct from j.payment_method_id then raise exception 'Cambio no confirmado' using errcode='22023'; end if;
 update private.dopmi_guardian_subscriptions set payment_method_id=j.payment_method_id,payment_method_updated_at=now() where donor_id=p.donor_id;
 update private.dopmi_guardian_method_jobs set status='applied',applied_at=now(),error_code=null where id=j.id;
 elsif operation='expired' then
 if j.session_id is null or data->>'session_id' is distinct from j.session_id or j.mutation_requested_at is not null then
 raise exception 'Vencimiento no confirmado' using errcode='22023'; end if;
 update private.dopmi_guardian_method_jobs set status='expired' where id=j.id;
 elsif operation='failed' then update private.dopmi_guardian_method_jobs set error_code=left(data->>'error_code',80) where id=j.id;
 else raise exception 'Operación de medio inválida' using errcode='22023'; end if;
 end if;
 return private.dopmi_guardian_method_view(j.id);
end; $$;
revoke all on function public.dopmi_guardian_method_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_guardian_method_server(text,jsonb) to service_role;

-- Existing invoice jobs keep their payment-method snapshot. Only a future
-- preparation sees the new method; the initial payment evidence is immutable.
do $patch$
declare definition text; old_text text;
begin
 definition:=pg_get_functiondef('private.dopmi_guardian_collection_allowed(text)'::regprocedure);
 old_text:='and p.cancellation_requested_at is null';
 if position(old_text in definition)=0 then raise exception 'Review collection gate'; end if;
 execute replace(definition,old_text,old_text||' and not private.dopmi_guardian_method_pending(p.stripe_subscription_id)');
 definition:=pg_get_functiondef('public.dopmi_guardian_request(text,uuid,bigint,bigint,text)'::regprocedure);
 old_text:='if request_kind=''amount'' then'||chr(10)||' if p.gross_cents=new_gross_cents';
 if position(old_text in definition)=0 then raise exception 'Review owner request gate'; end if;
 execute replace(definition,old_text,'if request_kind=''amount'' then if private.dopmi_guardian_method_pending(p.stripe_subscription_id) then raise exception ''Cambio de medio pendiente'' using errcode=''55000''; end if;'||chr(10)||' if p.gross_cents=new_gross_cents');
 definition:=pg_get_functiondef('public.dopmi_guardian_collection_server(text,jsonb)'::regprocedure);
 if position('a1.payment_method_id' in definition)=0 or position('a.payment_method_id,p.gross_cents' in definition)=0 then raise exception 'Review method snapshots'; end if;
 definition:=replace(definition,'a1.payment_method_id','coalesce(p1.payment_method_id,a1.payment_method_id)');
 execute replace(definition,'a.payment_method_id,p.gross_cents','coalesce(p.payment_method_id,a.payment_method_id),p.gross_cents');
 definition:=pg_get_functiondef('private.dopmi_guardian_change_view(uuid)'::regprocedure);
 if position('a.payment_method_id' in definition)=0 then raise exception 'Review change method'; end if;
 execute replace(definition,'a.payment_method_id','coalesce(p.payment_method_id,a.payment_method_id)');
 -- Ignore old monitor reads across either kind of pending change. Compare the
 -- expected method again after locking the plan, as already done for prices.
 definition:=pg_get_functiondef('public.dopmi_guardian_schedule_server(text,jsonb)'::regprocedure);
 old_text:='elsif j.status<>''canceled'' and j.price_id is not distinct from data->>''expected_price_id''';
 if position(old_text in definition)=0 then raise exception 'Review method monitor'; end if;
 execute replace(definition,old_text,old_text||' and not private.dopmi_guardian_method_pending(j.subscription_id)
 and (data->>''expected_method_id'' is null or data->>''expected_method_id'' is not distinct from
 (select coalesce(p.payment_method_id,a.payment_method_id) from private.dopmi_guardian_subscriptions p join private.dopmi_guardian_activations a on a.cycle_id=j.cycle_id where p.stripe_subscription_id=j.subscription_id))');
end $patch$;

create or replace function private.dopmi_guardian_schedule_view(target_cycle uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(j)||jsonb_build_object('activation',private.dopmi_guardian_activation_view(j.cycle_id)||
 case when p.payment_method_id is null then '{}'::jsonb else jsonb_build_object('payment_method_id',p.payment_method_id) end,
 'lifecycle_pending',private.dopmi_guardian_method_pending(j.subscription_id) or exists(select 1 from private.dopmi_guardian_requests r where r.subscription_id=j.subscription_id and r.status='pending'))
 from private.dopmi_guardian_schedule_jobs j left join private.dopmi_guardian_subscriptions p on p.stripe_subscription_id=j.subscription_id where j.cycle_id=target_cycle;
$$;

-- Owner projection deliberately excludes Stripe IDs, URLs and client secrets.
do $patch$
declare definition text:=pg_get_functiondef('public.dopmi_guardian_state()'::regprocedure); old_text text;
begin
 old_text:='''activation'',activation)';
 if position(old_text in definition)=0 then raise exception 'Review method projection'; end if;
 execute replace(definition,old_text,old_text||'||jsonb_build_object(''method_setup'',(select jsonb_build_object(''key'',j.request_key,''revision'',j.revision-1,''status'',j.status,''created_at'',j.created_at,''applied_at'',j.applied_at)
 from private.dopmi_guardian_method_jobs j where j.donor_id=actor order by j.created_at desc,j.id desc limit 1),
 ''payment_issue'',(select jsonb_build_object(''reason'',j.recovery_reason,''status'',j.status,''period_start'',to_timestamp(j.period_start))
 from private.dopmi_guardian_collection_jobs j join private.dopmi_guardian_subscriptions p on p.stripe_subscription_id=j.subscription_id
 where p.donor_id=actor order by j.period_start desc limit 1),
 ''method_change_available'',exists(select 1 from private.dopmi_guardian_subscriptions p where p.donor_id=actor and p.status=''active'' and p.cancellation_requested_at is null
 and not private.dopmi_guardian_method_pending(p.stripe_subscription_id)
 and not exists(select 1 from private.dopmi_guardian_requests r where r.subscription_id=p.stripe_subscription_id and r.status=''pending'')
 and not exists(select 1 from private.dopmi_guardian_collection_jobs j where j.subscription_id=p.stripe_subscription_id and j.status not in (''paid'',''skipped''))))');
end $patch$;
commit;
