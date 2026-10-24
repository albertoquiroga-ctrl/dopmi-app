begin;

-- Display-only facts from the exact settled Charge. No current-wallet lookup,
-- full card data, or backfill guesses. Existing movements remain nullable.
create table private.dopmi_payment_method_snapshots (
  kind text not null check (kind in ('contribution','guardian')),
  payment_id uuid not null,
  owner_id uuid not null references public.profiles(id),
  payment_intent_id text not null check (payment_intent_id ~ '^pi_[A-Za-z0-9]{1,128}$'),
  charge_id text not null check (charge_id ~ '^ch_[A-Za-z0-9]{1,128}$'),
  brand text not null check (brand in ('amex','cartes_bancaires','diners','discover','eftpos_au',
    'jcb','link','mastercard','unionpay','visa','unknown')),
  last4 text not null check (last4 ~ '^[0-9]{4}$'),
  recorded_at timestamptz not null default now(),
  primary key (kind,payment_id)
);
alter table private.dopmi_payment_method_snapshots enable row level security;
revoke all on table private.dopmi_payment_method_snapshots from public,anon,authenticated,service_role;

create function private.dopmi_payment_method_snapshot_immutable() returns trigger
language plpgsql set search_path='' as $$
begin
  raise exception 'El método histórico de un pago no se modifica' using errcode='22023';
end; $$;
revoke all on function private.dopmi_payment_method_snapshot_immutable() from public,anon,authenticated,service_role;
create trigger dopmi_payment_method_snapshot_immutable
before update or delete on private.dopmi_payment_method_snapshots
for each row execute function private.dopmi_payment_method_snapshot_immutable();

-- Trusted server evidence only. Ownership and Charge/Intent binding are read
-- from the already-settled ledger, never accepted from a client. This also
-- permits a separately reviewed historical recovery using that exact Charge.
create function public.dopmi_payment_method_snapshot_server(data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  target_kind text:=data->>'kind';
  target_id uuid;
  target_owner uuid;
  method jsonb:=data->'payment_method';
  snapshot private.dopmi_payment_method_snapshots;
begin
  if jsonb_typeof(data) is distinct from 'object'
    or not (data ?& array['kind','payment_id','payment_intent_id','charge_id','payment_method'])
    or data - array['kind','payment_id','payment_intent_id','charge_id','payment_method'] <> '{}'::jsonb
    or jsonb_typeof(data->'kind') is distinct from 'string'
    or target_kind not in ('contribution','guardian')
    or jsonb_typeof(data->'payment_id') is distinct from 'string'
    or jsonb_typeof(data->'payment_intent_id') is distinct from 'string'
    or (data->>'payment_intent_id') !~ '^pi_[A-Za-z0-9]{1,128}$'
    or jsonb_typeof(data->'charge_id') is distinct from 'string'
    or (data->>'charge_id') !~ '^ch_[A-Za-z0-9]{1,128}$'
    or jsonb_typeof(method) is distinct from 'object'
    or not (method ?& array['type','brand','last4'])
    or method - array['type','brand','last4'] <> '{}'::jsonb
    or method->>'type' is distinct from 'card'
    or jsonb_typeof(method->'brand') is distinct from 'string'
    or (method->>'brand') not in ('amex','cartes_bancaires','diners','discover','eftpos_au',
      'jcb','link','mastercard','unionpay','visa','unknown')
    or jsonb_typeof(method->'last4') is distinct from 'string'
    or (method->>'last4') !~ '^[0-9]{4}$' then
    raise exception 'Método histórico inválido' using errcode='22023';
  end if;
  target_id:=(data->>'payment_id')::uuid;
  if target_kind='contribution' then
    select d.donor_id into target_owner from public.dopmi_donations d
    where d.id=target_id and d.processed_at is not null
      and d.stripe_payment_intent_id=data->>'payment_intent_id'
      and d.stripe_charge_id=data->>'charge_id'
    for share of d;
  else
    select c.donor_id into target_owner
    from private.dopmi_guardian_settlements s
    join private.dopmi_guardian_cycles c on c.id=s.cycle_id
    where s.cycle_id=target_id and s.payment_intent_id=data->>'payment_intent_id'
      and s.charge_id=data->>'charge_id'
    for share of s,c;
  end if;
  if target_owner is null then
    raise exception 'El método no corresponde a un pago conciliado' using errcode='22023';
  end if;
  insert into private.dopmi_payment_method_snapshots
    (kind,payment_id,owner_id,payment_intent_id,charge_id,brand,last4)
  values(target_kind,target_id,target_owner,data->>'payment_intent_id',data->>'charge_id',
    method->>'brand',method->>'last4')
  on conflict (kind,payment_id) do nothing;
  select * into strict snapshot from private.dopmi_payment_method_snapshots
    where kind=target_kind and payment_id=target_id;
  if snapshot.owner_id is distinct from target_owner
    or snapshot.payment_intent_id is distinct from data->>'payment_intent_id'
    or snapshot.charge_id is distinct from data->>'charge_id'
    or snapshot.brand is distinct from method->>'brand'
    or snapshot.last4 is distinct from method->>'last4' then
    raise exception 'El pago ya conserva otro método histórico' using errcode='22023';
  end if;
  return jsonb_build_object('type','card','brand',snapshot.brand,'last4',snapshot.last4);
end; $$;
revoke all on function public.dopmi_payment_method_snapshot_server(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_payment_method_snapshot_server(jsonb) to service_role;

-- Keep every existing financial path and evidence comparison intact. The
-- optional snapshot is captured atomically after the original settlement.
alter function public.dopmi_payment_server(text,jsonb) rename to dopmi_payment_server_before_method_snapshot;
revoke all on function public.dopmi_payment_server_before_method_snapshot(text,jsonb) from public,anon,authenticated,service_role;
create function public.dopmi_payment_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=public.dopmi_payment_server_before_method_snapshot(operation,data-'payment_method');
  if operation='settle' and data ? 'payment_method' then
    perform public.dopmi_payment_method_snapshot_server(jsonb_build_object(
      'kind','contribution','payment_id',result->>'id',
      'payment_intent_id',data->>'payment_intent_id','charge_id',data->>'charge_id',
      'payment_method',data->'payment_method'));
  end if;
  return result;
end; $$;
revoke all on function public.dopmi_payment_server(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_payment_server(text,jsonb) to service_role;

alter function public.dopmi_guardian_settlement_server(text,jsonb) rename to dopmi_guardian_settlement_server_before_method_snapshot;
revoke all on function public.dopmi_guardian_settlement_server_before_method_snapshot(text,jsonb) from public,anon,authenticated,service_role;
create function public.dopmi_guardian_settlement_server(operation text,data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=public.dopmi_guardian_settlement_server_before_method_snapshot(operation,data-'payment_method');
  if operation in ('settle','settle_initial','settle_registration') and data ? 'payment_method' then
    perform public.dopmi_payment_method_snapshot_server(jsonb_build_object(
      'kind','guardian','payment_id',result->>'cycle_id',
      'payment_intent_id',data->>'payment_intent_id','charge_id',data->>'charge_id',
      'payment_method',data->'payment_method'));
  end if;
  return result;
end; $$;
revoke all on function public.dopmi_guardian_settlement_server(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.dopmi_guardian_settlement_server(text,jsonb) to service_role;

-- Preserve the current merged keyset page, statuses, amounts and all case
-- allocation patches. The rescuer's received history gets no donor card data.
alter function public.dopmi_payment_activity(boolean,timestamptz,text,uuid,integer)
  rename to dopmi_payment_activity_before_method_snapshot;
revoke all on function public.dopmi_payment_activity_before_method_snapshot(boolean,timestamptz,text,uuid,integer)
  from public,anon,authenticated,service_role;
create function public.dopmi_payment_activity(
  received boolean default false,before_created_at timestamptz default null,
  before_kind text default null,before_id uuid default null,page_size integer default 20
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  actor uuid:=private.dopmi_require_actor();
  result jsonb;
begin
  result:=public.dopmi_payment_activity_before_method_snapshot(received,before_created_at,before_kind,before_id,page_size);
  return jsonb_set(result,'{items}',coalesce((
    select jsonb_agg(entry.item || jsonb_build_object('payment_method',
      case when snapshot.payment_id is not null then
        jsonb_build_object('type','card','brand',snapshot.brand,'last4',snapshot.last4)
      else null end) order by entry.position)
    from jsonb_array_elements(result->'items') with ordinality entry(item,position)
    left join private.dopmi_payment_method_snapshots snapshot
      on received is false and snapshot.owner_id=actor
      and snapshot.kind=entry.item->>'kind' and snapshot.payment_id=(entry.item->>'id')::uuid
  ),'[]'::jsonb));
end; $$;
revoke all on function public.dopmi_payment_activity(boolean,timestamptz,text,uuid,integer)
  from public,anon,authenticated,service_role;
grant execute on function public.dopmi_payment_activity(boolean,timestamptz,text,uuid,integer) to authenticated;

commit;
