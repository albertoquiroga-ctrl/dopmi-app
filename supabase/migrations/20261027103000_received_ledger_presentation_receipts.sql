-- Additive local preparation. Compare remote migration history and current SQL
-- before applying. Financial rows, badge definitions and ACK semantics remain.
begin;
create function private.dopmi_payment_activity_before_received_receipts(
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
revoke all on function private.dopmi_payment_activity_before_received_receipts(
  boolean,timestamptz,text,uuid,integer) from public,anon,authenticated,service_role;

-- A row acknowledges only the existing badge events present in the same
-- statement snapshot as that ledger row. The keyset cursor is never an ACK.
create or replace function public.dopmi_payment_activity(
  received boolean default false,before_created_at timestamptz default null,
  before_kind text default null,before_id uuid default null,page_size integer default 20
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); result jsonb;
begin
  -- Preserve the sent-history projection, including historical card snapshots.
  if received is false then
    return private.dopmi_payment_activity_before_received_receipts(
      received,before_created_at,before_kind,before_id,page_size);
  end if;
  -- Same owner mutex as the existing activity reader; reuse exact receipts.
  if received is true then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('activity:'||actor::text,0));
  end if;
  with ledger as materialized (
    select private.dopmi_payment_activity_before_received_receipts(
      received,before_created_at,before_kind,before_id,page_size) value
  ), badge_events as materialized (
    select id,source from private.dopmi_rescuer_activity_rows(actor)
    where received is true
  ), presented as materialized (
    select entry.item,entry.position,
      coalesce((
        select array_agg(event.id order by event.id)
        from badge_events event
        where (entry.item->>'kind'='contribution'
            and event.source='individual'
            and event.id='individual:'||(entry.item->>'id'))
          or (entry.item->>'kind'='guardian'
            and event.source='guardian'
            and split_part(event.id,':',2)=entry.item->>'id')
      ),'{}'::text[]) event_ids
    from ledger
    cross join lateral jsonb_array_elements(ledger.value->'items')
      with ordinality entry(item,position)
  ), recorded as (
    insert into private.dopmi_rescuer_activity_receipts(owner_id,event_ids)
    select distinct actor,presented.event_ids from presented
    where cardinality(presented.event_ids)>0 and not exists(
      select 1 from private.dopmi_rescuer_activity_receipts old
      where old.owner_id=actor and old.event_ids=presented.event_ids
    )
    returning id,event_ids
  ), rows_with_receipts as (
    select presented.item||jsonb_build_object('presented_cursor',coalesce(
      (select recorded.id from recorded
        where recorded.event_ids=presented.event_ids limit 1),
      (select old.id from private.dopmi_rescuer_activity_receipts old
        where old.owner_id=actor and old.event_ids=presented.event_ids
          and cardinality(presented.event_ids)>0
        order by old.id limit 1)
    )) item,presented.position
    from presented
  )
  select jsonb_set(ledger.value,'{items}',coalesce((
    select jsonb_agg(entry.item order by entry.position) from rows_with_receipts entry
  ),'[]'::jsonb)) into result from ledger;
  return result;
end; $$;
-- CREATE OR REPLACE keeps the public entry's owner and execution ACL.
-- The existing ACK validates receipt ownership and consumes only event_ids;
-- it is deliberately unchanged and never re-queries financial state.
commit;
