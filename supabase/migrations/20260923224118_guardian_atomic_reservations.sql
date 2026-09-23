begin;

-- A cycle holds an upper bound on the transferable net (gross less Dopmi's
-- 2%). Actual Stripe fees are unknown until the payment settles. No cycle
-- here creates a Checkout or authorizes a charge.
create table private.dopmi_guardian_cycles (
  id uuid primary key default gen_random_uuid(),
  donor_id uuid not null references public.profiles(id) on delete restrict,
  cycle_key uuid not null,
  gross_cents bigint not null check (gross_cents between 1000 and 1000000),
  reserved_cents bigint not null check (reserved_cents >= 0),
  status text not null check (status in ('reserved','skipped','released','expired')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (donor_id,cycle_key)
);
create table private.dopmi_guardian_allocations (
  cycle_id uuid not null references private.dopmi_guardian_cycles(id) on delete restrict,
  expense_id uuid not null references public.dopmi_rescue_records(id) on delete restrict,
  amount_cents bigint not null check (amount_cents > 0),
  primary key (cycle_id,expense_id)
);
create index dopmi_guardian_allocations_expense on private.dopmi_guardian_allocations(expense_id);
alter table private.dopmi_guardian_cycles enable row level security;
alter table private.dopmi_guardian_allocations enable row level security;
revoke all on private.dopmi_guardian_cycles,private.dopmi_guardian_allocations from public,anon,authenticated;

create function private.dopmi_guardian_reserved(target_expense uuid) returns bigint
language sql stable security definer set search_path='' as $$
  select coalesce(sum(allocation.amount_cents),0)
  from private.dopmi_guardian_allocations allocation
  join private.dopmi_guardian_cycles cycle on cycle.id=allocation.cycle_id
  where allocation.expense_id=target_expense and cycle.status='reserved' and cycle.expires_at>now();
$$;
revoke all on function private.dopmi_guardian_reserved(uuid) from public,anon,authenticated;

-- Reuse the same per-rescuer transaction lock as single-payment prepare and
-- settlement. A second Guardian cycle waits and then sees the first one's
-- holds; individual Checkout reservations see these holds as well.
create function public.dopmi_guardian_reserve(target_donor uuid,target_key uuid,target_gross bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  cycle private.dopmi_guardian_cycles;
  record public.dopmi_rescue_records;
  rescuer uuid;
  owners uuid[];
  upper_net bigint;
  remaining bigint;
  available bigint;
  portion bigint;
  planned jsonb := '[]'::jsonb;
begin
  if target_donor is null or target_key is null or target_gross is null or target_gross not between 1000 and 1000000 then
    raise exception 'Ciclo o importe de Guardián inválido' using errcode='22023';
  end if;
  if not exists (
    select 1 from public.profiles profile join auth.users usr on usr.id=profile.id
    where profile.id=target_donor and profile.account_status='active' and usr.email_confirmed_at is not null
  ) then raise exception 'Cuenta activa y confirmada requerida' using errcode='42501'; end if;

  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-cycle:'||target_donor::text||':'||target_key::text,0));
  select * into cycle from private.dopmi_guardian_cycles
    where donor_id=target_donor and cycle_key=target_key for update;
  if found then
    if cycle.gross_cents<>target_gross then raise exception 'El ciclo ya existe con otro importe' using errcode='22023'; end if;
    if cycle.status='reserved' and cycle.expires_at<=now() then
      update private.dopmi_guardian_cycles set status='expired' where id=cycle.id returning * into cycle;
    end if;
    return jsonb_build_object('id',cycle.id,'status',cycle.status,'gross_cents',cycle.gross_cents,
      'reserved_cents',cycle.reserved_cents,'expires_at',cycle.expires_at,
      'allocations',coalesce((select jsonb_agg(jsonb_build_object('expense_id',allocation.expense_id,
        'amount_cents',allocation.amount_cents) order by ordered_expense.urgent desc,ordered_expense.approved_at,ordered_expense.id)
        from private.dopmi_guardian_allocations allocation
        join public.dopmi_rescue_records ordered_expense on ordered_expense.id=allocation.expense_id
        where allocation.cycle_id=cycle.id),'[]'::jsonb));
  end if;

  upper_net := target_gross - (target_gross*2+50)/100;
  remaining := upper_net;
  select array_agg(owner_id order by owner_id) into owners from (
    select distinct candidate.owner_id from public.dopmi_rescue_records candidate
    where candidate.kind='expense' and candidate.status='approved' and candidate.owner_id<>target_donor
  ) distinct_owners;
  if coalesce(array_length(owners,1),0)>500 then
    raise exception 'Demasiados rescatistas para reservar en un ciclo' using errcode='54000';
  end if;
  foreach rescuer in array coalesce(owners,'{}'::uuid[]) loop
    perform private.dopmi_rescue_lock(rescuer);
  end loop;

  -- Read after acquiring all owner locks. All participating payment writers
  -- acquire these locks before changing their reserved/allocated balances.
  for record in
    select * from public.dopmi_rescue_records candidate
    where candidate.kind='expense' and candidate.status='approved' and candidate.owner_id<>target_donor
    order by candidate.urgent desc,candidate.approved_at,candidate.id
  loop
    if not private.dopmi_expense_payable(record) then continue; end if;
    select greatest(0,record.reimbursable_cents-coalesce(sum(donation.allocated_cents+donation.reserved_cents),0)
      -private.dopmi_guardian_reserved(record.id)) into available
      from public.dopmi_donations donation where donation.expense_id=record.id;
    if available=0 then continue; end if;
    portion := least(remaining,available);
    planned := planned || jsonb_build_array(jsonb_build_object('expense_id',record.id,'amount_cents',portion));
    remaining := remaining-portion;
    exit when remaining=0;
  end loop;

  insert into private.dopmi_guardian_cycles(donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at)
  values(target_donor,target_key,target_gross,case when remaining=0 then upper_net else 0 end,
    case when remaining=0 then 'reserved' else 'skipped' end,now()+interval '30 minutes') returning * into cycle;
  if remaining=0 then
    insert into private.dopmi_guardian_allocations(cycle_id,expense_id,amount_cents)
      select cycle.id,(entry->>'expense_id')::uuid,(entry->>'amount_cents')::bigint
      from jsonb_array_elements(planned) entry;
  else planned := '[]'::jsonb; end if;
  return jsonb_build_object('id',cycle.id,'status',cycle.status,'gross_cents',cycle.gross_cents,
    'reserved_cents',cycle.reserved_cents,'expires_at',cycle.expires_at,'allocations',planned);
end;
$$;

create function public.dopmi_guardian_release(target_donor uuid,target_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare cycle private.dopmi_guardian_cycles;
begin
  if target_donor is null or target_key is null then raise exception 'Ciclo inválido' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('dopmi-guardian-cycle:'||target_donor::text||':'||target_key::text,0));
  select * into cycle from private.dopmi_guardian_cycles where donor_id=target_donor and cycle_key=target_key for update;
  if not found then return jsonb_build_object('status','missing'); end if;
  if cycle.status='reserved' then
    update private.dopmi_guardian_cycles set status=case when expires_at<=now() then 'expired' else 'released' end
      where id=cycle.id returning * into cycle;
  end if;
  return jsonb_build_object('id',cycle.id,'status',cycle.status);
end;
$$;
revoke all on function public.dopmi_guardian_reserve(uuid,uuid,bigint),public.dopmi_guardian_release(uuid,uuid)
  from public,anon,authenticated;
grant execute on function public.dopmi_guardian_reserve(uuid,uuid,bigint),public.dopmi_guardian_release(uuid,uuid)
  to service_role;

-- Patch the existing service-only payment gateway without resetting later
-- fixes to event handling, job leases, refunds, or transfers.
do $patch$
declare
  definition text := pg_get_functiondef('public.dopmi_payment_server(text,jsonb)'::regprocedure);
  original_prepare constant text := 'select r.reimbursable_cents-coalesce(sum(allocated_cents+reserved_cents),0) into available from public.dopmi_donations where expense_id=r.id;';
  guarded_prepare constant text := 'select r.reimbursable_cents-coalesce(sum(allocated_cents+reserved_cents),0)-private.dopmi_guardian_reserved(r.id) into available from public.dopmi_donations where expense_id=r.id;';
  original_settle constant text := 'select greatest(0,r.reimbursable_cents-coalesce(sum(allocated_cents),0)) into available from public.dopmi_donations where expense_id=r.id;';
  guarded_settle constant text := 'select greatest(0,r.reimbursable_cents-coalesce(sum(allocated_cents),0)-private.dopmi_guardian_reserved(r.id)) into available from public.dopmi_donations where expense_id=r.id;';
begin
  if position(original_prepare in definition)=0 or position(original_settle in definition)=0 then
    raise exception 'Payment gateway changed: review Guardian capacity patch before applying';
  end if;
  execute replace(replace(definition,original_prepare,guarded_prepare),original_settle,guarded_settle);
end
$patch$;

-- The public available amount includes pending Guardian holds; funded and
-- transferred amounts continue to mean actual confirmed processor effects.
create or replace function public.dopmi_expense_funding(record_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.dopmi_rescue_records; assigned bigint; reserved bigint; transferred bigint;
begin
  select * into r from public.dopmi_rescue_records where id=record_id;
  if not found or r.kind<>'expense' or not (private.dopmi_rescue_public_visible(r)
    or (r.owner_id=auth.uid() and public.dopmi_actor_active())) then
    raise exception 'Gasto no disponible' using errcode='42501';
  end if;
  select coalesce(sum(allocated_cents),0),coalesce(sum(reserved_cents),0),
    coalesce(sum(allocated_cents) filter(where transfer_status='transferred' and stripe_transfer_id is not null),0)
    into assigned,reserved,transferred from public.dopmi_donations where expense_id=r.id;
  reserved := reserved+private.dopmi_guardian_reserved(r.id);
  return jsonb_build_object('expense_id',r.id,'title',r.approved_snapshot->>'title','reimbursable_cents',r.reimbursable_cents,
    'funded_cents',assigned,'transferred_cents',transferred,
    'available_cents',greatest(0,r.reimbursable_cents-assigned-reserved),'payable',private.dopmi_expense_payable(r));
end;
$$;

commit;
