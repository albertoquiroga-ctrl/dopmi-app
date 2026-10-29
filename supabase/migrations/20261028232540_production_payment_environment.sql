begin;

-- Configuration, never a demo fixture or an activation of production payments.
-- The database owner is the only writer; neither clients nor service_role may
-- change the binding that Edge reads before contacting the payment provider.
create table private.dopmi_payment_environment (
  singleton boolean primary key default true check (singleton),
  environment text not null check (environment in ('test','production'))
);
alter table private.dopmi_payment_environment enable row level security;
revoke all on private.dopmi_payment_environment from public,anon,authenticated,service_role;
insert into private.dopmi_payment_environment(singleton,environment) values(true,'test');

create function public.dopmi_payment_environment_server() returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'environment',e.environment,
    'expected_livemode',e.environment='production',
    'oneoff_consent_version',case e.environment
      when 'production' then 'oneoff-live-2026-10-28'
      else 'oneoff-test-2026-10-15' end)
  from private.dopmi_payment_environment e where e.singleton;
$$;
revoke all on function public.dopmi_payment_environment_server() from public,anon,authenticated;
grant execute on function public.dopmi_payment_environment_server() to service_role;

-- Preserve earlier TEST evidence. The version accepted for a new prepare is
-- narrower than this historical storage constraint and comes only from the DB.
alter table private.dopmi_checkouts drop constraint dopmi_native_checkout_consent;
alter table private.dopmi_checkouts add constraint dopmi_native_checkout_consent
  check (payment_flow<>'native' or (session_id is null and url is null and
    consent_version in ('oneoff-test-2026-10-15','oneoff-live-2026-10-28') and consent_at is not null));

-- Patch the final installed definitions, not historical migration text. Fail
-- closed on drift or a non-unique anchor; all other consent, owner, fee,
-- reservation and idempotency checks remain byte-for-byte in each definition.
do $patch$
declare
  target regprocedure;
  definition text;
  old_check constant text := 'data->>''consent_version'' is distinct from ''oneoff-test-2026-10-15''';
  new_check constant text := 'data->>''consent_version'' is distinct from (public.dopmi_payment_environment_server()->>''oneoff_consent_version'')';
begin
  foreach target in array array[
    'public.dopmi_oneoff_native_server(text,jsonb)'::regprocedure,
    'public.dopmi_oneoff_case_server(text,jsonb)'::regprocedure
  ] loop
    definition:=pg_get_functiondef(target);
    if (length(definition)-length(replace(definition,old_check,'')))/length(old_check)<>1 then
      raise exception 'One-off consent contract changed for %: review environment patch',target;
    end if;
    execute replace(definition,old_check,new_check);
  end loop;
end $patch$;

-- A Checkout identifier does not establish provider mode. These three channels
-- retain historical cs_/cs_test_ identifiers and add the explicit cs_live_
-- representation; backend resource/environment binding still verifies mode.
do $patch$
declare
  target regprocedure;
  definition text;
  old_pattern constant text := '^cs_(test_)?[A-Za-z0-9]+$';
  new_pattern constant text := '^cs_(test_|live_)?[A-Za-z0-9]+$';
  target_table regclass;
  target_constraint text;
begin
  foreach target in array array[
    'public.dopmi_guardian_activation_server(text,jsonb)'::regprocedure,
    'public.dopmi_guardian_method_server(text,jsonb)'::regprocedure,
    'public.dopmi_saved_card_server(text,jsonb)'::regprocedure
  ] loop
    definition:=pg_get_functiondef(target);
    if (length(definition)-length(replace(definition,old_pattern,'')))/length(old_pattern)<>1 then
      raise exception 'Checkout contract changed for %: review environment patch',target;
    end if;
    execute replace(definition,old_pattern,new_pattern);
  end loop;

  for target_table,target_constraint in values
    ('private.dopmi_guardian_activations'::regclass,'dopmi_guardian_activations_session_id_check'),
    ('private.dopmi_guardian_method_jobs'::regclass,'dopmi_guardian_method_jobs_session_id_check'),
    ('private.dopmi_saved_card_jobs'::regclass,'dopmi_saved_card_jobs_session_id_check')
  loop
    select pg_get_constraintdef(c.oid) into definition from pg_constraint c
      where c.conrelid=target_table and c.conname=target_constraint and c.contype='c';
    if definition is null or
      (length(definition)-length(replace(definition,old_pattern,'')))/length(old_pattern)<>1 then
      raise exception 'Checkout constraint changed for %: review environment patch',target_table;
    end if;
    execute format('alter table %s drop constraint %I',target_table,target_constraint);
    execute format('alter table %s add constraint %I %s',target_table,target_constraint,
      replace(definition,old_pattern,new_pattern));
  end loop;
end $patch$;

commit;
