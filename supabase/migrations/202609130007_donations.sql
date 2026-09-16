begin;
-- Test-mode individual contributions. Only the service role may write processor state.
create table private.dopmi_connect_accounts (
 owner_id uuid primary key references public.profiles(id) on delete restrict,
 account_id text unique, transfers_enabled boolean not null default false,
 payouts_enabled boolean not null default false, details_submitted boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), create_started_at timestamptz
);
create table public.dopmi_donations (
 id uuid primary key default gen_random_uuid(), donor_id uuid not null references public.profiles(id) on delete restrict,
 rescuer_id uuid not null references public.profiles(id) on delete restrict,
 expense_id uuid not null references public.dopmi_rescue_records(id) on delete restrict,
 expense_title text not null, destination text not null,
 idempotency_key uuid not null, processor text not null default 'stripe' check(processor='stripe'),
 currency text not null default 'mxn' check(currency='mxn'),
 gross_cents bigint not null check(gross_cents between 1000 and 1000000),
 platform_fee_cents bigint not null check(platform_fee_cents>=0),
 stripe_fee_cents bigint check(stripe_fee_cents>=0), net_cents bigint check(net_cents>=0),
 allocated_cents bigint not null default 0 check(allocated_cents>=0),
 refund_cents bigint not null default 0 check(refund_cents>=0),
 platform_loss_cents bigint not null default 0 check(platform_loss_cents>=0),
 reserved_cents bigint not null check(reserved_cents>=0),
 status text not null default 'pending' check(status in ('pending','allocated','partial','unassigned','canceled','refunded')),
 payment_status text not null default 'pending' check(payment_status in ('pending','confirmed','canceled','refunded')),
 transfer_status text not null default 'not_started' check(transfer_status in ('not_started','pending','transferred','attention','reversed')),
 refund_status text not null default 'none' check(refund_status in ('none','pending','refunded','attention')),
 stripe_charge_id text unique, stripe_payment_intent_id text unique, stripe_transfer_id text unique, stripe_refund_id text unique,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), processed_at timestamptz,
 unique(donor_id,idempotency_key),
 check(processed_at is null or gross_cents+platform_loss_cents=platform_fee_cents+stripe_fee_cents+allocated_cents+refund_cents),
 check(processed_at is null or net_cents=allocated_cents+refund_cents)
);
create index dopmi_donations_expense on public.dopmi_donations(expense_id);
create index dopmi_donations_donor on public.dopmi_donations(donor_id,created_at desc,id);
create index dopmi_donations_rescuer on public.dopmi_donations(rescuer_id,created_at desc,id);
create index dopmi_donations_status on public.dopmi_donations(status,created_at desc,id);
create table private.dopmi_checkouts (
 donation_id uuid primary key references public.dopmi_donations(id), session_id text unique, url text
);
create table private.dopmi_payment_jobs (
 id uuid primary key default gen_random_uuid(), job_key text not null unique,
 kind text not null check(kind in ('event','transfer','refund')),
 donation_id uuid references public.dopmi_donations(id), payload jsonb not null default '{}',
 status text not null default 'ready' check(status in ('ready','running','done','attention')),
 attempts integer not null default 0, lease uuid, lease_until timestamptz,
 available_at timestamptz not null default now(), first_attempt_at timestamptz,
 created_at timestamptz not null default now(), error_code text
);
create index dopmi_payment_jobs_ready on private.dopmi_payment_jobs(status,available_at);
alter table public.dopmi_donations enable row level security;
alter table private.dopmi_connect_accounts enable row level security;
alter table private.dopmi_checkouts enable row level security;
alter table private.dopmi_payment_jobs enable row level security;
revoke all on public.dopmi_donations,private.dopmi_connect_accounts,private.dopmi_checkouts,private.dopmi_payment_jobs from public,anon,authenticated;
grant select on public.dopmi_donations to authenticated;
create policy dopmi_payment_participant on public.dopmi_donations for select to authenticated
 using(public.dopmi_actor_active() and (donor_id=(select auth.uid()) or rescuer_id=(select auth.uid())));

create function private.dopmi_expense_payable(r public.dopmi_rescue_records) returns boolean
language sql stable security definer set search_path='' as $$
 select r.kind='expense' and r.status='approved' and r.reimbursable_cents>0 and r.approved_snapshot is not null
 and private.dopmi_rescuer_verified(r.owner_id)
 and exists(select 1 from public.dopmi_rescue_records c where c.id=r.parent_id and c.status='approved' and c.approved_snapshot is not null)
 and exists(select 1 from private.dopmi_connect_accounts a where a.owner_id=r.owner_id and a.transfers_enabled and a.payouts_enabled);
$$;
create function public.dopmi_expense_funding(record_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.dopmi_rescue_records; assigned bigint; reserved bigint;
begin
 select * into r from public.dopmi_rescue_records where id=record_id;
 if not found or r.kind<>'expense' or not private.dopmi_rescue_public_visible(r) then
   raise exception 'Gasto no disponible' using errcode='42501'; end if;
 select coalesce(sum(allocated_cents),0),coalesce(sum(reserved_cents),0) into assigned,reserved from public.dopmi_donations where expense_id=r.id;
 return jsonb_build_object('expense_id',r.id,'title',r.approved_snapshot->>'title','reimbursable_cents',r.reimbursable_cents,
 'funded_cents',assigned,'available_cents',greatest(0,r.reimbursable_cents-assigned-reserved),'payable',private.dopmi_expense_payable(r));
end;
$$;

-- H3 moderation uses the same rescuer-wide advisory lock as settlement.
create function private.dopmi_guard_funded_expense() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.kind='expense' and (new.reimbursable_cents<>old.reimbursable_cents or new.status<>old.status
   or new.owner_id<>old.owner_id or new.parent_id<>old.parent_id) and
   exists(select 1 from public.dopmi_donations where expense_id=old.id and allocated_cents>0) then
   raise exception 'Este gasto ya tiene aportaciones asignadas. Conserva su aprobación e historial' using errcode='22023';
 end if;
 return new;
end;
$$;
create trigger dopmi_guard_funded_expense before update on public.dopmi_rescue_records
 for each row execute function private.dopmi_guard_funded_expense();

-- Edge Functions authenticate Auth users or signed Stripe events before invoking
-- this gateway. There is deliberately no authenticated-client settlement RPC.
create function public.dopmi_payment_server(operation text, data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d public.dopmi_donations; r public.dopmi_rescue_records; a private.dopmi_connect_accounts;
 j private.dopmi_payment_jobs; actor uuid; available bigint; gross bigint; fee bigint; platform bigint; net bigint; assigned bigint; refund bigint;
begin
 if operation in ('prepare','connect_get','connect_begin') then
   actor:=(data->>'actor')::uuid;
   if not exists(select 1 from public.profiles p join auth.users u on u.id=p.id where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
     raise exception 'Cuenta activa y confirmada requerida' using errcode='42501'; end if;
 end if;
 if operation in ('connect_get','connect_begin') then
   if not private.dopmi_rescuer_verified(actor) then raise exception 'Completa la verificación de rescatista' using errcode='42501'; end if;
   perform private.dopmi_rescue_lock(actor);
   insert into private.dopmi_connect_accounts(owner_id) values(actor) on conflict do nothing;
   if operation='connect_begin' then update private.dopmi_connect_accounts set create_started_at=coalesce(create_started_at,now()) where owner_id=actor; end if;
     select * into a from private.dopmi_connect_accounts where owner_id=actor;
   return to_jsonb(a);
 elsif operation='connect_save' then
   update private.dopmi_connect_accounts set account_id=data->>'account_id',
     transfers_enabled=(data->>'transfers_enabled')::boolean,payouts_enabled=(data->>'payouts_enabled')::boolean,
     details_submitted=(data->>'details_submitted')::boolean,updated_at=now()
     where owner_id=(data->>'actor')::uuid and (account_id is null or account_id=data->>'account_id') returning * into a;
   if not found then raise exception 'Cuenta Connect no vinculada' using errcode='22023'; end if;
   return to_jsonb(a);
 elsif operation='prepare' then
   perform pg_advisory_xact_lock(hashtextextended('dopmi-checkout:'||actor::text,0));
   select * into d from public.dopmi_donations where donor_id=actor and idempotency_key=(data->>'key')::uuid;
   if found then
     if d.expense_id<>(data->>'expense_id')::uuid or d.gross_cents<>(data->>'gross_cents')::bigint then
       raise exception 'La aportación ya existe con otros datos' using errcode='22023'; end if;
     return to_jsonb(d)||(select to_jsonb(c) from private.dopmi_checkouts c where donation_id=d.id);
   end if;
   select * into r from public.dopmi_rescue_records where id=(data->>'expense_id')::uuid;
   if not found then raise exception 'Gasto no disponible' using errcode='22023'; end if;
   perform private.dopmi_rescue_lock(r.owner_id);
   select * into r from public.dopmi_rescue_records where id=r.id for update;
   if not private.dopmi_expense_payable(r) or actor=r.owner_id then raise exception 'Gasto no disponible para esta aportación' using errcode='22023'; end if;
   gross:=(data->>'gross_cents')::bigint;
   if gross is null or gross not between 1000 and 1000000 then raise exception 'Elige de $10 a $10,000 MXN' using errcode='22023'; end if;
   platform:=(gross*2+50)/100;
   select r.reimbursable_cents-coalesce(sum(allocated_cents+reserved_cents),0) into available from public.dopmi_donations where expense_id=r.id;
   if available<=0 then raise exception 'Este gasto ya está cubierto o tiene pagos en proceso' using errcode='22023'; end if;
   if (select count(*) from public.dopmi_donations where donor_id=actor and payment_status='pending')>=5 then
     raise exception 'Termina tus aportaciones pendientes antes de iniciar otra' using errcode='22023'; end if;
   select * into a from private.dopmi_connect_accounts where owner_id=r.owner_id;
   insert into public.dopmi_donations(donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,reserved_cents)
     values(actor,r.owner_id,r.id,coalesce(r.approved_snapshot->>'title','Gasto aprobado'),a.account_id,(data->>'key')::uuid,gross,platform,least(available,gross-platform)) returning * into d;
   insert into private.dopmi_checkouts(donation_id) values(d.id);
   return to_jsonb(d);
 elsif operation='checkout_save' then
   update private.dopmi_checkouts set session_id=data->>'session_id',url=data->>'url'
     where donation_id=(data->>'donation_id')::uuid and (session_id is null or session_id=data->>'session_id');
   if not found then raise exception 'Sesión distinta para la misma aportación' using errcode='22023'; end if;
   return '{}';
 elsif operation='get' then
   select * into d from public.dopmi_donations where id=(data->>'donation_id')::uuid;
   return to_jsonb(d);
 elsif operation='hold' then
   update public.dopmi_donations set transfer_status='attention',updated_at=now() where stripe_payment_intent_id=data->>'payment_intent_id' returning * into d;
   if found then
     update private.dopmi_payment_jobs set status='attention',error_code='external_adjustment_review' where donation_id=d.id and kind='transfer' and status<>'done';
   end if;
   return '{}';
 elsif operation='lookup_account' then
   select * into a from private.dopmi_connect_accounts where account_id=data->>'account_id';
   return to_jsonb(a);
 elsif operation='enqueue' then
   insert into private.dopmi_payment_jobs(job_key,kind,payload) values(data->>'event_id','event',data) on conflict(job_key) do nothing;
   return '{}';
 elsif operation='claim' then
   select * into j from private.dopmi_payment_jobs where (status='ready' and available_at<=now()) or (status='running' and lease_until<now())
     order by available_at,id for update skip locked limit 1;
   if not found then return null; end if;
   -- Stripe only guarantees idempotency retention for at least 24 hours.
   if j.attempts>=8 or (j.kind<>'event' and j.first_attempt_at<now()-interval '23 hours') then
     update private.dopmi_payment_jobs set status='attention',error_code='retry_limit' where id=j.id;
     update public.dopmi_donations set transfer_status=case when j.kind='transfer' then 'attention' else transfer_status end,
       refund_status=case when j.kind='refund' then 'attention' else refund_status end where id=j.donation_id;
     return jsonb_build_object('skipped',true);
   end if;
   update private.dopmi_payment_jobs set status='running',attempts=attempts+1,lease=gen_random_uuid(),lease_until=now()+interval '2 minutes',
     first_attempt_at=coalesce(first_attempt_at,now()) where id=j.id returning * into j;
   return to_jsonb(j);
 elsif operation='finish_job' then
   select * into j from private.dopmi_payment_jobs where id=(data->>'job_id')::uuid and lease=(data->>'lease')::uuid and status='running' for update;
   if not found then raise exception 'Intento de procesamiento vencido' using errcode='40001'; end if;
   if data->>'error_code' is not null then
     update private.dopmi_payment_jobs set status=case when data->>'attention'='true' then 'attention' else 'ready' end,
       error_code=left(data->>'error_code',80),available_at=now()+make_interval(secs=>least(3600,30*power(2,j.attempts)::integer)),lease_until=null where id=j.id;
     update public.dopmi_donations set transfer_status=case when j.kind='transfer' then 'attention' else transfer_status end,
       refund_status=case when j.kind='refund' then 'attention' else refund_status end where id=j.donation_id;
   else
     if j.kind='transfer' then
       update public.dopmi_donations set stripe_transfer_id=data->>'result_id',transfer_status='transferred',updated_at=now() where id=j.donation_id;
     elsif j.kind='refund' then
       update public.dopmi_donations set stripe_refund_id=data->>'result_id',refund_status='refunded',updated_at=now(),
         payment_status=case when allocated_cents=0 then 'refunded' else payment_status end,
         status=case when allocated_cents=0 then 'refunded' else status end where id=j.donation_id;
     end if;
     update private.dopmi_payment_jobs set status='done',lease_until=null,error_code=null where id=j.id;
   end if;
   return '{}';
 elsif operation in ('settle','cancel') then
   select * into d from public.dopmi_donations where id=(data->>'donation_id')::uuid;
   if not found then raise exception 'Aportación no disponible' using errcode='22023'; end if;
   perform private.dopmi_rescue_lock(d.rescuer_id);
   select * into d from public.dopmi_donations where id=d.id for update;
   if operation='cancel' then
     update public.dopmi_donations set status='canceled',payment_status='canceled',reserved_cents=0,updated_at=now()
       where id=d.id and payment_status='pending';
     return '{}';
   end if;
   if (data->>'currency') is distinct from 'mxn' or (data->>'gross_cents')::bigint is distinct from d.gross_cents
     or data->>'charge_id' is null or data->>'payment_intent_id' is null then raise exception 'Cobro no coincide con la aportación' using errcode='22023'; end if;
   if d.processed_at is not null then
     if d.stripe_charge_id<>data->>'charge_id' or d.stripe_payment_intent_id<>data->>'payment_intent_id' then raise exception 'Cobro duplicado distinto' using errcode='22023'; end if;
     return to_jsonb(d);
   end if;
   fee:=(data->>'stripe_fee_cents')::bigint;
   if fee is null or fee<0 or fee>d.gross_cents then raise exception 'Comisión de Stripe pendiente o inválida' using errcode='22023'; end if;
   select * into r from public.dopmi_rescue_records where id=d.expense_id for update;
   select greatest(0,r.reimbursable_cents-coalesce(sum(allocated_cents),0)) into available from public.dopmi_donations where expense_id=r.id;
   platform:=(d.gross_cents*2+50)/100;
   net:=greatest(0,d.gross_cents-platform-fee);
   assigned:=case when private.dopmi_expense_payable(r) then least(available,net) else 0 end;
   refund:=net-assigned;
   -- A wholly unassignable charge is refunded in full; Dopmi absorbs Stripe's fee.
   if assigned=0 then platform:=0; refund:=d.gross_cents; end if;
   update public.dopmi_donations set stripe_charge_id=data->>'charge_id',stripe_payment_intent_id=data->>'payment_intent_id',
     stripe_fee_cents=fee,platform_fee_cents=platform,platform_loss_cents=case when assigned=0 then fee else 0 end,
     net_cents=assigned+refund,allocated_cents=assigned,refund_cents=refund,reserved_cents=0,payment_status='confirmed',
     status=case when assigned=0 then 'unassigned' when refund>0 then 'partial' else 'allocated' end,
     transfer_status=case when assigned>0 then 'pending' else 'not_started' end,
     refund_status=case when refund>0 then 'pending' else 'none' end,processed_at=now(),updated_at=now() where id=d.id returning * into d;
   if assigned>0 then insert into private.dopmi_payment_jobs(job_key,kind,donation_id) values('transfer:'||d.id,'transfer',d.id) on conflict do nothing; end if;
   if refund>0 then insert into private.dopmi_payment_jobs(job_key,kind,donation_id) values('refund:'||d.id,'refund',d.id) on conflict do nothing; end if;
   return to_jsonb(d);
 elsif operation='reconcile_candidates' then
   return coalesce((select jsonb_agg(x) from (select d.id,c.session_id from public.dopmi_donations d join private.dopmi_checkouts c on c.donation_id=d.id
     where d.payment_status='pending' and c.session_id is not null order by d.updated_at,d.id limit 50)x),'[]');
 end if;
 raise exception 'Operación de pago inválida' using errcode='22023';
end;
$$;

create function public.dopmi_admin_donations(status_filter text default 'all',page_number integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if not public.dopmi_is_admin() then raise exception 'Acceso administrativo requerido' using errcode='42501'; end if;
 if page_number is null or page_number<1 or status_filter is null or status_filter not in ('all','pending','allocated','partial','unassigned','canceled','refunded','attention') then
   raise exception 'Filtros inválidos' using errcode='22023'; end if;
 insert into private.admin_access_log(actor_id,action) values(auth.uid(),'donations.list');
 return jsonb_build_object('total',(select count(*) from public.dopmi_donations d where status_filter='all' or d.status=status_filter or
     (status_filter='attention' and (d.transfer_status='attention' or d.refund_status='attention'))),
   'items',coalesce((select jsonb_agg(x) from (select d.*,p.display_name as donor_name,u.email as donor_email,
     (select count(*) from private.dopmi_payment_jobs j where j.donation_id=d.id and j.status='attention') as attention_count
     from public.dopmi_donations d join public.profiles p on p.id=d.donor_id join auth.users u on u.id=p.id
     where status_filter='all' or d.status=status_filter or (status_filter='attention' and (d.transfer_status='attention' or d.refund_status='attention'))
     order by d.created_at desc,d.id limit 20 offset (page_number::bigint-1)*20)x),'[]'));
end;
$$;
revoke all on function private.dopmi_expense_payable(public.dopmi_rescue_records),private.dopmi_guard_funded_expense(),
 public.dopmi_payment_server(text,jsonb),public.dopmi_expense_funding(uuid),public.dopmi_admin_donations(text,integer) from public,anon,authenticated;
grant execute on function public.dopmi_payment_server(text,jsonb) to service_role;
grant execute on function public.dopmi_expense_funding(uuid) to anon,authenticated;
grant execute on function public.dopmi_admin_donations(text,integer) to authenticated;
commit;
