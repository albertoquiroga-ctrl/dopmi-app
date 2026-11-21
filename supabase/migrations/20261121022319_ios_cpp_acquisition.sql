begin;

-- An App Store custom-product-page URL is static context, not a verified
-- install referrer. Its measurement window begins at server enrollment.
create table private.dopmi_ios_cpp_acquisition (
  actor_id uuid primary key references private.dopmi_adoption_measurement(actor_id) on delete cascade,
  variant text not null check (variant = 'personal-a'),
  source_method text not null default 'ios_cpp_open' check (source_method = 'ios_cpp_open'),
  attributed_at timestamptz not null,
  first_adoption_id uuid,
  first_submitted_at timestamptz,
  first_approved_at timestamptz,
  check ((first_adoption_id is null) = (first_submitted_at is null)),
  check (first_submitted_at is null or first_submitted_at >= attributed_at),
  check (first_approved_at is null or (first_submitted_at is not null and first_approved_at >= first_submitted_at))
);
create table private.dopmi_ios_cpp_acquisition_events (
  actor_id uuid not null references private.dopmi_ios_cpp_acquisition(actor_id) on delete cascade,
  event_type text not null check (event_type in ('automatic_greeting', 'first_user_message', 'first_rescuer_reply')),
  observed_at timestamptz not null,
  primary key (actor_id, event_type)
);
alter table private.dopmi_ios_cpp_acquisition enable row level security;
alter table private.dopmi_ios_cpp_acquisition_events enable row level security;
revoke all on private.dopmi_ios_cpp_acquisition, private.dopmi_ios_cpp_acquisition_events
  from public, anon, authenticated, service_role;

create function public.dopmi_record_ios_cpp_acquisition(p_variant text, p_expected_consent_revision bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  consent_state private.dopmi_adoption_measurement;
begin
  if p_variant is null or p_variant <> 'personal-a' then
    raise exception 'Variante de medición no válida' using errcode = '22023';
  end if;
  if p_expected_consent_revision is null or p_expected_consent_revision < 0 then
    raise exception 'Revisión de consentimiento no válida' using errcode = '22023';
  end if;

  -- Same lock order as Android: profile, consent, then source. Enrollment
  -- never takes an adoption or conversation lock.
  perform 1 from public.profiles p where p.id = actor and p.account_status = 'active'
    for no key update;
  if not found then return jsonb_build_object('status', 'ineligible'); end if;
  select * into consent_state from private.dopmi_adoption_measurement m
    where m.actor_id = actor for update;
  if not found or not consent_state.consent or consent_state.revision <> p_expected_consent_revision then
    return jsonb_build_object('status', 'consent_changed');
  end if;
  if exists (select 1 from private.dopmi_ios_cpp_acquisition s where s.actor_id = actor) then
    return jsonb_build_object('status', 'already_recorded');
  end if;

  if exists (
    select 1 from public.dopmi_adoptions a where a.owner_id = actor and (
      a.submitted_at is not null or a.published_at is not null
      or a.status in ('submitted', 'changes_requested', 'published', 'rejected', 'adopted')
      or exists (select 1 from private.dopmi_adoption_reviews r where r.post_id = a.id)
    )
  ) then
    return jsonb_build_object('status', 'ineligible');
  end if;

  insert into private.dopmi_ios_cpp_acquisition(actor_id, variant, attributed_at)
    values(actor, p_variant, clock_timestamp()) on conflict(actor_id) do nothing;
  return jsonb_build_object('status', case when found then 'recorded' else 'already_recorded' end);
end;
$$;

create function private.dopmi_observe_ios_cpp_acquisition() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  observed_at timestamptz;
begin
  if new.status = 'submitted' then
    perform 1 from private.dopmi_adoption_measurement m
      where m.actor_id = new.owner_id and m.consent for update;
    if not found then return null; end if;
    observed_at := clock_timestamp();
    update private.dopmi_ios_cpp_acquisition s
      set first_adoption_id = new.id, first_submitted_at = observed_at
      where s.actor_id = new.owner_id and s.first_submitted_at is null
        and s.attributed_at <= observed_at and observed_at < s.attributed_at + interval '336 hours';
  else
    -- Approval follows this same first original through corrections, even
    -- after its submission window. Opt-out/deletion remove the source itself.
    update private.dopmi_ios_cpp_acquisition s
      set first_approved_at = greatest(clock_timestamp(), s.first_submitted_at)
      where s.actor_id = new.owner_id and s.first_adoption_id = new.id
        and s.first_submitted_at is not null and s.first_approved_at is null;
  end if;
  return null;
end;
$$;
create trigger dopmi_observe_ios_cpp_acquisition
after update of submitted_at, published_at on public.dopmi_adoptions
for each row when (
  (new.status = 'submitted' and old.submitted_at is null and new.submitted_at is not null)
  or (new.status = 'published' and old.published_at is null and new.published_at is not null)
)
execute function private.dopmi_observe_ios_cpp_acquisition();

create function private.dopmi_observe_ios_cpp_message_acquisition() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  thread public.dopmi_threads;
  source private.dopmi_ios_cpp_acquisition;
  milestone text;
  consented boolean;
  observed timestamptz;
begin
  if new.origin = 'unknown' then return null; end if;
  select * into thread from public.dopmi_threads where id = new.thread_id;
  if new.sender_id = thread.adopter_id then
    milestone := case new.origin when 'automatic_greeting' then 'automatic_greeting'
      when 'user' then 'first_user_message' end;
  elsif new.sender_id = thread.owner_id and new.origin = 'user' and exists (
    select 1 from public.dopmi_messages m where m.thread_id = thread.id
      and m.sender_id = thread.adopter_id and m.id <> new.id
  ) then
    milestone := 'first_rescuer_reply';
  end if;
  if milestone is null then return null; end if;

  -- The sender RPC holds the thread lock. Enrollment and opt-out do not take
  -- thread locks, and both platforms take consent before their source rows.
  select m.consent into consented from private.dopmi_adoption_measurement m
    where m.actor_id = new.sender_id for update;
  if not found or not consented then return null; end if;
  select * into source from private.dopmi_ios_cpp_acquisition s
    where s.actor_id = new.sender_id for key share;
  if not found then return null; end if;
  observed := clock_timestamp();
  if observed < source.attributed_at or observed >= source.attributed_at + interval '336 hours' then
    return null;
  end if;
  insert into private.dopmi_ios_cpp_acquisition_events(actor_id, event_type, observed_at)
    values(new.sender_id, milestone, observed) on conflict(actor_id, event_type) do nothing;
  return null;
end;
$$;
create trigger dopmi_observe_ios_cpp_message_acquisition
after insert on public.dopmi_messages
for each row execute function private.dopmi_observe_ios_cpp_message_acquisition();

create function private.dopmi_clear_ios_cpp_acquisition_on_opt_out() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from private.dopmi_ios_cpp_acquisition where actor_id = new.actor_id;
  return null;
end;
$$;
create trigger dopmi_clear_ios_cpp_acquisition_on_opt_out
after update of consent on private.dopmi_adoption_measurement
for each row when (not new.consent)
execute function private.dopmi_clear_ios_cpp_acquisition_on_opt_out();

create function private.dopmi_clear_ios_cpp_acquisition_on_delete() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from private.dopmi_ios_cpp_acquisition where actor_id = new.id;
  return null;
end;
$$;
create trigger dopmi_clear_ios_cpp_acquisition_on_delete
after update of account_status on public.profiles
for each row when (old.account_status is distinct from new.account_status and new.account_status = 'deleted')
execute function private.dopmi_clear_ios_cpp_acquisition_on_delete();

revoke all on function public.dopmi_record_ios_cpp_acquisition(text,bigint),
  private.dopmi_observe_ios_cpp_acquisition(), private.dopmi_observe_ios_cpp_message_acquisition(),
  private.dopmi_clear_ios_cpp_acquisition_on_opt_out(), private.dopmi_clear_ios_cpp_acquisition_on_delete()
  from public, anon, authenticated, service_role;
grant execute on function public.dopmi_record_ios_cpp_acquisition(text,bigint) to authenticated;

commit;
