begin;

-- Server-owned revision, shared by new compare-and-set writers and legacy v1.
-- An UPDATE advances the revision even when the consent value is unchanged.
alter table private.dopmi_adoption_measurement
  add column revision bigint not null default 0 check(revision >= 0);
-- Existing rows start at zero. A future v1 INSERT is already a consent write,
-- so it must invalidate any previously read absent/zero state as well.
alter table private.dopmi_adoption_measurement alter column revision set default 1;

create function private.dopmi_increment_adoption_measurement_revision() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.revision := old.revision + 1;
  return new;
end;
$$;
create trigger dopmi_increment_adoption_measurement_revision
before update on private.dopmi_adoption_measurement
for each row execute function private.dopmi_increment_adoption_measurement_revision();

create function public.dopmi_adoption_measurement_state() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  current_state private.dopmi_adoption_measurement;
begin
  select * into current_state from private.dopmi_adoption_measurement where actor_id = actor;
  return jsonb_build_object('consent', coalesce(current_state.consent, false),
    'revision', coalesce(current_state.revision, 0::bigint));
end;
$$;

create function public.dopmi_set_adoption_measurement_v2(consent boolean, expected_revision bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  current_state private.dopmi_adoption_measurement;
begin
  if consent is null or expected_revision is null or expected_revision < 0 then
    raise exception 'Consentimiento y revisión válidos requeridos' using errcode = '22023';
  end if;

  insert into private.dopmi_adoption_measurement(actor_id, consent, revision)
    values(actor, false, 0) on conflict(actor_id) do nothing;
  select * into current_state from private.dopmi_adoption_measurement
    where actor_id = actor for update;
  if current_state.revision <> expected_revision then
    return jsonb_build_object('applied', false, 'consent', current_state.consent,
      'revision', current_state.revision);
  end if;

  -- Keep v1's update and opt-out cascade semantics. The BEFORE UPDATE trigger
  -- owns the counter; a delayed request cannot choose a replacement revision.
  update private.dopmi_adoption_measurement set consent = $1, updated_at = now()
    where actor_id = actor returning * into current_state;
  return jsonb_build_object('applied', true, 'consent', current_state.consent,
    'revision', current_state.revision);
end;
$$;

revoke all on function private.dopmi_increment_adoption_measurement_revision(),
  public.dopmi_adoption_measurement_state(), public.dopmi_set_adoption_measurement_v2(boolean, bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.dopmi_adoption_measurement_state(),
  public.dopmi_set_adoption_measurement_v2(boolean, bigint) to authenticated;

commit;
