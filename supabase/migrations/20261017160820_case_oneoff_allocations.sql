begin;
-- Preserve the historic expense contract; case payments have one financial
-- parent and private per-expense accounting, never an arbitrary anchor expense.
alter table public.dopmi_donations alter column expense_id drop not null;
alter table public.dopmi_donations add column contribution_scope text not null default 'expense'
 check(contribution_scope in ('expense','case'));
alter table public.dopmi_donations add column case_id uuid references public.dopmi_rescue_records(id) on delete restrict;
update public.dopmi_donations d set case_id=e.parent_id from public.dopmi_rescue_records e where e.id=d.expense_id;
alter table public.dopmi_donations add constraint dopmi_donation_scope check(
 (contribution_scope='expense' and expense_id is not null) or
 (contribution_scope='case' and expense_id is null and case_id is not null));
create table private.dopmi_case_allocations (
 donation_id uuid not null references public.dopmi_donations(id) on delete restrict,
 expense_id uuid not null references public.dopmi_rescue_records(id) on delete restrict,
 expense_title text not null, reserved_cents bigint not null default 0 check(reserved_cents>=0),
 allocated_cents bigint not null default 0 check(allocated_cents>=0),
 reversed_cents bigint not null default 0 check(reversed_cents>=0 and reversed_cents<=allocated_cents),
 allocated_at timestamptz, reversed_at timestamptz,
 primary key(donation_id,expense_id)
);
create index dopmi_case_allocations_expense on private.dopmi_case_allocations(expense_id);
alter table private.dopmi_case_allocations enable row level security;
revoke all on private.dopmi_case_allocations from public,anon,authenticated;
create function private.dopmi_case_occupied(target_expense uuid, excluding uuid default null) returns bigint
language sql stable security definer set search_path='' as $$
 select coalesce(sum(reserved_cents+allocated_cents-reversed_cents),0)
 from private.dopmi_case_allocations where expense_id=target_expense and (excluding is null or donation_id<>excluding);
$$;
create function private.dopmi_case_funded(target_expense uuid, transferred_only boolean default false) returns bigint
language sql stable security definer set search_path='' as $$
 select coalesce(sum(a.allocated_cents-a.reversed_cents),0) from private.dopmi_case_allocations a
 join public.dopmi_donations d on d.id=a.donation_id
 where a.expense_id=target_expense and (not transferred_only or d.transfer_status='transferred');
$$;
create function private.dopmi_shared_occupied(target_expense uuid) returns bigint
language sql stable security definer set search_path='' as $$
 select private.dopmi_guardian_reserved(target_expense)+private.dopmi_case_occupied(target_expense);
$$;
revoke all on function private.dopmi_case_occupied(uuid,uuid),private.dopmi_case_funded(uuid,boolean),private.dopmi_shared_occupied(uuid) from public,anon,authenticated;
-- Every existing capacity consumer already shares guardian_reserved. Patch only
-- callers, retaining Guardian-only projections and ledger semantics.
do $patch$
declare f record; definition text;
begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in ('public','private') and p.prokind='f'
 and p.proname not in ('dopmi_shared_occupied','dopmi_guardian_reserved')
 and position('private.dopmi_guardian_reserved(' in p.prosrc)>0 loop
 definition:=pg_get_functiondef(f.oid);
 execute replace(definition,'private.dopmi_guardian_reserved(','private.dopmi_shared_occupied(');
 end loop;
 definition:=pg_get_functiondef('public.dopmi_payment_server(text,jsonb)'::regprocedure);
 if position('if d.expense_id<>' in definition)=0 then raise exception 'Review expense idempotency guard'; end if;
 execute replace(definition,'if d.expense_id<>','if d.contribution_scope<>''expense'' or d.expense_id<>');
 definition:=pg_get_functiondef('public.dopmi_rescue_public(uuid,integer)'::regprocedure);
 definition:=replace(definition,'private.dopmi_guardian_funded(e.id,true)','(private.dopmi_guardian_funded(e.id,true)+private.dopmi_case_funded(e.id,true))');
 definition:=replace(definition,'private.dopmi_guardian_funded(e.id)','(private.dopmi_guardian_funded(e.id)+private.dopmi_case_funded(e.id))');
 execute definition;
 -- Public funding must separate confirmed child allocations from reservations.
 definition:=pg_get_functiondef('public.dopmi_expense_funding(uuid)'::regprocedure);
 definition:=replace(definition,'private.dopmi_guardian_funded(r.id,true)','(private.dopmi_guardian_funded(r.id,true)+private.dopmi_case_funded(r.id,true))');
 definition:=replace(definition,'private.dopmi_guardian_funded(r.id)','(private.dopmi_guardian_funded(r.id)+private.dopmi_case_funded(r.id))');
 execute definition;
 definition:=pg_get_functiondef('private.dopmi_guard_funded_expense()'::regprocedure);
 definition:=replace(definition,'private.dopmi_guardian_funded(old.id)>0','(private.dopmi_guardian_funded(old.id)+private.dopmi_case_funded(old.id))>0');
 execute definition;
end $patch$;

create function public.dopmi_oneoff_case_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=(data->>'actor')::uuid; key uuid:=(data->>'key')::uuid;
 c public.dopmi_rescue_records; e public.dopmi_rescue_records; d public.dopmi_donations;
 remaining bigint; available bigint; portion bigint; gross bigint; platform bigint;
begin
 if operation<>'prepare' then return public.dopmi_oneoff_native_server(operation,data); end if;
 if actor is null or key is null or not exists(select 1 from public.profiles p join auth.users u on u.id=p.id
 where p.id=actor and p.account_status='active' and u.email_confirmed_at is not null) then
 raise exception 'Cuenta activa y confirmada requerida' using errcode='42501'; end if;
 if data->>'consent_version' is distinct from 'oneoff-test-2026-10-15' or data->>'consent' is distinct from 'true' then
 raise exception 'Confirma el importe y las condiciones de la aportación' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('dopmi-checkout:'||actor::text,0));
 select * into d from public.dopmi_donations where donor_id=actor and idempotency_key=key;
 if found then
 if d.contribution_scope<>'case' or d.case_id is distinct from (data->>'case_id')::uuid or d.gross_cents is distinct from (data->>'gross_cents')::bigint then
 raise exception 'La aportación ya existe con otros datos' using errcode='22023'; end if;
 return public.dopmi_oneoff_native_server('get',data); end if;
 gross:=(data->>'gross_cents')::bigint;
 if gross is null or gross not between 1000 and 1000000 then raise exception 'Elige de $10 a $10,000 MXN' using errcode='22023'; end if;
 select * into c from public.dopmi_rescue_records where id=(data->>'case_id')::uuid;
 if not found then raise exception 'Caso no disponible' using errcode='22023'; end if;
 perform private.dopmi_rescue_lock(c.owner_id);
 select * into c from public.dopmi_rescue_records where id=c.id for update;
 if c.kind<>'case' or c.status<>'approved' or c.approved_snapshot is null or c.owner_id=actor then
 raise exception 'Caso no disponible' using errcode='22023'; end if;
 if (select count(*) from public.dopmi_donations where donor_id=actor and payment_status='pending')>=5 then
 raise exception 'Termina tus aportaciones pendientes antes de iniciar otra' using errcode='22023'; end if;
 platform:=(gross*2+50)/100; remaining:=gross-platform;
 insert into public.dopmi_donations(donor_id,rescuer_id,expense_id,case_id,contribution_scope,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,reserved_cents)
 values(actor,c.owner_id,null,c.id,'case','Apoyar al caso',
 (select account_id from private.dopmi_connect_accounts where owner_id=c.owner_id),key,gross,platform,remaining) returning * into d;
 for e in select * from public.dopmi_rescue_records where parent_id=c.id and owner_id=c.owner_id and kind='expense'
 order by urgent desc,approved_at,id loop
 if not private.dopmi_expense_payable(e) then continue; end if;
 select greatest(0,e.reimbursable_cents-coalesce(sum(x.allocated_cents+x.reserved_cents),0)-private.dopmi_shared_occupied(e.id))
 into available from public.dopmi_donations x where x.expense_id=e.id;
 portion:=least(remaining,available);
 if portion>0 then insert into private.dopmi_case_allocations(donation_id,expense_id,expense_title,reserved_cents)
 values(d.id,e.id,coalesce(e.approved_snapshot->>'title','Gasto aprobado'),portion); remaining:=remaining-portion; end if;
 exit when remaining=0;
 end loop;
 if remaining<>0 then raise exception 'Elige un importe que pueda asignarse completo a este caso' using errcode='22023'; end if;
 insert into private.dopmi_checkouts(donation_id,payment_flow,consent_version,consent_at) values(d.id,'native',data->>'consent_version',now());
 return public.dopmi_oneoff_native_server('get',data);
end; $$;
revoke all on function public.dopmi_oneoff_case_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_oneoff_case_server(text,jsonb) to service_role;

-- Keep the historical gateway intact behind a service-only dispatcher.
alter function public.dopmi_payment_server(text,jsonb) rename to dopmi_payment_server_expense_v1;
revoke all on function public.dopmi_payment_server_expense_v1(text,jsonb) from public,anon,authenticated,service_role;
create function public.dopmi_payment_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d public.dopmi_donations; e public.dopmi_rescue_records; fee bigint; platform bigint; net bigint;
 remaining bigint; available bigint; portion bigint; planned jsonb:='[]'; entry jsonb;
begin
 if operation not in ('settle','cancel') then return public.dopmi_payment_server_expense_v1(operation,data); end if;
 select * into d from public.dopmi_donations where id=(data->>'donation_id')::uuid;
 if d.contribution_scope is distinct from 'case' then return public.dopmi_payment_server_expense_v1(operation,data); end if;
 perform private.dopmi_rescue_lock(d.rescuer_id);
 select * into d from public.dopmi_donations where id=d.id for update;
 if operation='cancel' then
 if d.payment_status='pending' then
 update private.dopmi_case_allocations set reserved_cents=0 where donation_id=d.id;
 update public.dopmi_donations set reserved_cents=0,status='canceled',payment_status='canceled',updated_at=now() where id=d.id;
 end if; return '{}'; end if;
 if data->>'currency' is distinct from 'mxn' or (data->>'gross_cents')::bigint is distinct from d.gross_cents
 or data->>'charge_id' is null or data->>'payment_intent_id' is distinct from d.stripe_payment_intent_id then
 raise exception 'Cobro distinto para la misma aportación' using errcode='22023'; end if;
 if d.processed_at is not null then
 if data->>'charge_id' is distinct from d.stripe_charge_id then raise exception 'Cobro duplicado distinto' using errcode='22023'; end if;
 return to_jsonb(d); end if;
 if d.payment_status<>'pending' then raise exception 'Cobro requiere conciliación' using errcode='40001'; end if;
 fee:=(data->>'stripe_fee_cents')::bigint;
 if fee is null or fee<0 or fee>d.gross_cents then raise exception 'Comisión de Stripe pendiente o inválida' using errcode='22023'; end if;
 platform:=(d.gross_cents*2+50)/100; net:=greatest(0,d.gross_cents-platform-fee); remaining:=net;
 for e in select * from public.dopmi_rescue_records where parent_id=d.case_id and owner_id=d.rescuer_id and kind='expense'
 order by urgent desc,approved_at,id loop
 if not private.dopmi_expense_payable(e) then continue; end if;
 select greatest(0,e.reimbursable_cents-coalesce(sum(x.allocated_cents+x.reserved_cents),0)
 -private.dopmi_guardian_reserved(e.id)-private.dopmi_case_occupied(e.id,d.id)) into available
 from public.dopmi_donations x where x.expense_id=e.id;
 portion:=least(remaining,available);
 if portion>0 then planned:=planned||jsonb_build_array(jsonb_build_object('expense_id',e.id,'title',coalesce(e.approved_snapshot->>'title','Gasto aprobado'),'amount',portion)); remaining:=remaining-portion; end if;
 exit when remaining=0;
 end loop;
 if remaining<>0 or net=0 then
 -- No partial allocation. Holds remain until the full refund is confirmed.
 update public.dopmi_donations set stripe_charge_id=data->>'charge_id',stripe_fee_cents=fee,
 platform_fee_cents=0,platform_loss_cents=fee,net_cents=gross_cents,refund_cents=gross_cents,
 payment_status='confirmed',status='unassigned',refund_status='pending',processed_at=now(),updated_at=now() where id=d.id returning * into d;
 insert into private.dopmi_payment_jobs(job_key,kind,donation_id) values('refund:'||d.id,'refund',d.id) on conflict do nothing;
 else
 update private.dopmi_case_allocations set reserved_cents=0 where donation_id=d.id;
 for entry in select * from jsonb_array_elements(planned) loop
 insert into private.dopmi_case_allocations(donation_id,expense_id,expense_title,allocated_cents,allocated_at)
 values(d.id,(entry->>'expense_id')::uuid,entry->>'title',(entry->>'amount')::bigint,now())
 on conflict(donation_id,expense_id) do update set allocated_cents=excluded.allocated_cents,allocated_at=excluded.allocated_at;
 end loop;
 update public.dopmi_donations set stripe_charge_id=data->>'charge_id',stripe_fee_cents=fee,
 net_cents=net,allocated_cents=net,reserved_cents=0,payment_status='confirmed',status='allocated',transfer_status='pending',processed_at=now(),updated_at=now() where id=d.id returning * into d;
 insert into private.dopmi_payment_jobs(job_key,kind,donation_id) values('transfer:'||d.id,'transfer',d.id) on conflict do nothing;
 end if;
 return to_jsonb(d);
end; $$;
revoke all on function public.dopmi_payment_server(text,jsonb) from public,anon,authenticated;
grant execute on function public.dopmi_payment_server(text,jsonb) to service_role;

-- Reuse verified refund/reversal job semantics. No navigation or timeout can
-- release a hold or reverse an allocation.
create function private.dopmi_case_financial_transition() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.contribution_scope='case' then
 if new.refund_status='refunded' and new.allocated_cents=0 then
 update private.dopmi_case_allocations set reserved_cents=0 where donation_id=new.id;
 new.reserved_cents:=0;
 end if;
 if new.transfer_status='reversed' and new.payment_status='refunded' and new.stripe_reversal_id is not null then
 update private.dopmi_case_allocations set reversed_cents=allocated_cents,reversed_at=coalesce(reversed_at,now()),reserved_cents=0 where donation_id=new.id;
 end if;
 end if;
 return new;
end; $$;
revoke all on function private.dopmi_case_financial_transition() from public,anon,authenticated;
create trigger dopmi_case_financial_transition before update on public.dopmi_donations
for each row execute function private.dopmi_case_financial_transition();

-- Receipt access survives withdrawn public snapshots. Expense titles were
-- snapshotted privately when reserved; no mutable/public-only join is required.
create function public.dopmi_case_payment_allocations(target_donation uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor();
begin
 if not exists(select 1 from public.dopmi_donations where id=target_donation and donor_id=actor and contribution_scope='case') then
 raise exception 'Aportación no disponible' using errcode='42501'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('expense_id',expense_id,'title',expense_title,
 'reserved_cents',reserved_cents,'allocated_cents',allocated_cents,'reversed_cents',reversed_cents) order by expense_id)
 from private.dopmi_case_allocations where donation_id=target_donation),'[]');
end; $$;
revoke all on function public.dopmi_case_payment_allocations(uuid) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_case_payment_allocations(uuid) to authenticated;
do $patch$
declare definition text;
begin
 definition:=pg_get_functiondef('public.dopmi_payment_activity(boolean,timestamptz,text,uuid,integer)'::regprocedure);
 if position('join public.dopmi_rescue_records e on e.id=d.expense_id' in definition)=0 then raise exception 'Review payment activity case patch'; end if;
 definition:=replace(definition,'join public.dopmi_rescue_records e on e.id=d.expense_id','left join public.dopmi_rescue_records e on e.id=d.expense_id');
 definition:=replace(definition,'p.id=e.parent_id','p.id=coalesce(d.case_id,e.parent_id)');
 definition:=replace(definition,'''expense_id'',d.expense_id,''allocation_count'',1,','''contribution_scope'',d.contribution_scope,''expense_id'',d.expense_id,''allocation_count'',case when d.contribution_scope=''case'' then (select count(*) from private.dopmi_case_allocations ca where ca.donation_id=d.id and ca.allocated_cents>0) else 1 end,');
 execute definition;
end $patch$;
commit;
