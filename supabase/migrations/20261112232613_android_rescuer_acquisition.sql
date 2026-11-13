begin;

-- First-touch acquisition is a private measurement record. Neither the
-- referrer string nor a device, Facebook, or visitor identifier is retained.
create table private.dopmi_android_rescuer_acquisition (
  actor_id uuid primary key references private.dopmi_adoption_measurement(actor_id) on delete cascade,
  variant text not null check (variant in ('personal-a', 'personal-b', 'pagina-a', 'pagina-b')),
  clicked_at timestamptz not null,
  attributed_at timestamptz not null,
  first_adoption_id uuid,
  first_submitted_at timestamptz,
  first_approved_at timestamptz,
  check (clicked_at <= attributed_at),
  check ((first_adoption_id is null) = (first_submitted_at is null)),
  check (first_approved_at is null or first_submitted_at is not null)
);

alter table private.dopmi_android_rescuer_acquisition enable row level security;
revoke all on private.dopmi_android_rescuer_acquisition from public, anon, authenticated, service_role;

create function public.dopmi_record_android_rescuer_acquisition(p_variant text, p_clicked_at timestamptz) returns void
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  received_at timestamptz := clock_timestamp();
begin
  if p_variant is null or p_variant not in ('personal-a', 'personal-b', 'pagina-a', 'pagina-b') then
    raise exception 'Variante de medición no válida' using errcode = '22023';
  end if;

  if p_clicked_at is null or p_clicked_at > received_at
    or p_clicked_at <= received_at - interval '336 hours' then
    raise exception 'Fecha de referencia fuera del periodo de medición' using errcode = '22023';
  end if;

  -- Serialize enrollment with profile deletion, consent changes, and first
  -- original submission. Do not lock the adoption rows from enrollment.
  perform 1 from public.profiles p where p.id = actor and p.account_status = 'active'
    for no key update;
  if not found then return; end if;

  perform 1 from private.dopmi_adoption_measurement m where m.actor_id = actor and m.consent
    for update;
  if not found then return; end if;

  if exists (
    select 1 from public.dopmi_adoptions a
    where a.owner_id = actor and (
      a.submitted_at is not null or a.published_at is not null
      or a.status in ('submitted', 'changes_requested', 'published', 'rejected', 'adopted')
      or exists (select 1 from private.dopmi_adoption_reviews r where r.post_id = a.id)
    )
  ) then
    return;
  end if;

  received_at := clock_timestamp();
  if p_clicked_at > received_at or p_clicked_at <= received_at - interval '336 hours' then return; end if;

  insert into private.dopmi_android_rescuer_acquisition(actor_id, variant, clicked_at, attributed_at)
    values (actor, p_variant, p_clicked_at, received_at) on conflict (actor_id) do nothing;
end;
$$;

create function private.dopmi_observe_android_rescuer_acquisition() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  observed_at timestamptz;
begin
  if new.status = 'submitted' then
    -- The consent row is also locked by enrollment and opt-out. If the first
    -- submission wins that race, enrollment sees the prior submission.
    perform 1 from private.dopmi_adoption_measurement m
      where m.actor_id = new.owner_id and m.consent for update;
    if not found then return null; end if;

    observed_at := clock_timestamp();
    update private.dopmi_android_rescuer_acquisition s
      set first_adoption_id = new.id, first_submitted_at = observed_at
      where s.actor_id = new.owner_id and s.first_submitted_at is null
        and s.attributed_at <= observed_at and observed_at < s.clicked_at + interval '336 hours';
  else
    update private.dopmi_android_rescuer_acquisition s
      set first_approved_at = greatest(clock_timestamp(), s.first_submitted_at)
      where s.actor_id = new.owner_id and s.first_adoption_id = new.id
        and s.first_submitted_at is not null and s.first_approved_at is null;
  end if;
  return null;
end;
$$;

-- Capture the first original submission before subsequent edits can replace
-- submitted_at. Approvals refer to that same original, including after corrections.
create trigger dopmi_observe_android_rescuer_acquisition
after update of submitted_at, published_at on public.dopmi_adoptions
for each row when (
  (new.status = 'submitted' and old.submitted_at is null and new.submitted_at is not null)
  or (new.status = 'published' and old.published_at is null and new.published_at is not null)
)
execute function private.dopmi_observe_android_rescuer_acquisition();

create function private.dopmi_clear_android_rescuer_acquisition_on_opt_out() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from private.dopmi_android_rescuer_acquisition where actor_id = new.actor_id;
  return null;
end;
$$;

create trigger dopmi_clear_android_rescuer_acquisition_on_opt_out
after update of consent on private.dopmi_adoption_measurement
for each row when (not new.consent)
execute function private.dopmi_clear_android_rescuer_acquisition_on_opt_out();

create function private.dopmi_clear_android_rescuer_acquisition_on_delete() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from private.dopmi_android_rescuer_acquisition where actor_id = new.id;
  return null;
end;
$$;

-- Some account deletions retain an anonymized profile before Auth cleanup.
create trigger dopmi_clear_android_rescuer_acquisition_on_delete
after update of account_status on public.profiles
for each row when (old.account_status is distinct from new.account_status and new.account_status = 'deleted')
execute function private.dopmi_clear_android_rescuer_acquisition_on_delete();

revoke all on function public.dopmi_record_android_rescuer_acquisition(text,timestamptz),
  private.dopmi_observe_android_rescuer_acquisition(),
  private.dopmi_clear_android_rescuer_acquisition_on_opt_out(),
  private.dopmi_clear_android_rescuer_acquisition_on_delete()
from public, anon, authenticated, service_role;
grant execute on function public.dopmi_record_android_rescuer_acquisition(text,timestamptz) to authenticated;

commit;
