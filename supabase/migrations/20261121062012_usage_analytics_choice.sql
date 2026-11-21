begin;

-- Receipts describe an explicit choice made with the displayed notice, never a
-- default or a historical legal acceptance. No existing preference is rewritten.
-- The FK also removes receipts when the account's measurement state is erased.
create table private.dopmi_usage_analytics_choices (
  actor_id uuid not null references private.dopmi_adoption_measurement(actor_id) on delete cascade,
  revision bigint not null check (revision > 0),
  consent boolean not null,
  notice_version text not null check (notice_version = 'usage-analytics-2026-11-21'),
  decision_source text not null default 'explicit_in_app_choice'
    check (decision_source = 'explicit_in_app_choice'),
  decided_at timestamptz not null default clock_timestamp(),
  primary key (actor_id, revision)
);
alter table private.dopmi_usage_analytics_choices enable row level security;
revoke all on private.dopmi_usage_analytics_choices from public, anon, authenticated, service_role;

-- A row at legacy revision zero is still a choice. Only actual absence allows
-- the new client to offer an initially selected option without enabling it.
-- A later legacy write cannot inherit the notice of an earlier explicit choice.
create or replace function public.dopmi_adoption_measurement_state() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  current_state private.dopmi_adoption_measurement;
  displayed_notice text;
  has_choice boolean;
begin
  select * into current_state from private.dopmi_adoption_measurement where actor_id = actor;
  has_choice := found;
  if has_choice then
    select c.notice_version into displayed_notice from private.dopmi_usage_analytics_choices c
      where c.actor_id = actor and c.revision = current_state.revision;
  end if;
  return jsonb_build_object('consent', coalesce(current_state.consent, false),
    'revision', coalesce(current_state.revision, 0::bigint),
    'has_choice', has_choice, 'notice_version', displayed_notice);
end;
$$;

create function public.dopmi_choose_usage_analytics(
  consent boolean, expected_revision bigint, notice_version text
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  current_state private.dopmi_adoption_measurement;
  displayed_notice text;
begin
  if consent is null or expected_revision is null or expected_revision < 0
    or notice_version is distinct from 'usage-analytics-2026-11-21' then
    raise exception 'Elección, revisión y aviso válidos requeridos' using errcode = '22023';
  end if;

  select * into current_state from private.dopmi_adoption_measurement
    where actor_id = actor for update;
  if not found then
    if expected_revision <> 0 then
      return jsonb_build_object('applied', false, 'consent', false, 'revision', 0,
        'has_choice', false, 'notice_version', null);
    end if;
    -- A concurrent first choice or legacy INSERT owns the same unique actor.
    insert into private.dopmi_adoption_measurement(actor_id, consent, revision)
      values(actor, false, 0) on conflict(actor_id) do nothing;
    select * into current_state from private.dopmi_adoption_measurement
      where actor_id = actor for update;
  end if;
  if current_state.revision <> expected_revision then
    select c.notice_version into displayed_notice from private.dopmi_usage_analytics_choices c
      where c.actor_id = actor and c.revision = current_state.revision;
    return jsonb_build_object('applied', false, 'consent', current_state.consent,
      'revision', current_state.revision, 'has_choice', true, 'notice_version', displayed_notice);
  end if;

  -- Use the same state UPDATE as v2: the existing trigger owns revisions and
  -- existing opt-out triggers remove acquisition data before this tx commits.
  update private.dopmi_adoption_measurement set consent = $1, updated_at = now()
    where actor_id = actor returning * into current_state;
  insert into private.dopmi_usage_analytics_choices(actor_id, revision, consent, notice_version)
    values(actor, current_state.revision, current_state.consent, $3);
  return jsonb_build_object('applied', true, 'consent', current_state.consent,
    'revision', current_state.revision, 'has_choice', true, 'notice_version', $3);
end;
$$;

revoke all on function public.dopmi_adoption_measurement_state(),
  public.dopmi_choose_usage_analytics(boolean, bigint, text)
  from public, anon, authenticated, service_role;
grant execute on function public.dopmi_adoption_measurement_state(),
  public.dopmi_choose_usage_analytics(boolean, bigint, text) to authenticated;

commit;
