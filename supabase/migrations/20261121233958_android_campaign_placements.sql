begin;

-- Public marketing context only. The operator's social-placement ledger stays
-- outside this registry; a token does not prove an install or Facebook author.
create table private.dopmi_campaign_placements (
  token text primary key check (token ~ '^[0-9a-f]{32}$'),
  experiment_id text not null check (experiment_id ~ '^[a-z][a-z0-9_]{0,79}$'),
  arm_id text not null,
  variant text not null,
  is_qa boolean not null default false,
  enabled boolean not null default false,
  constraint dopmi_campaign_placement_assignment check (
    (arm_id = 'R1' and variant = 'personal-a')
    or (arm_id = 'R2' and variant = 'personal-b')
    or (arm_id = 'R3' and variant = 'pagina-a')
    or (arm_id = 'R4' and variant = 'pagina-b')
  )
);
alter table private.dopmi_campaign_placements enable row level security;
revoke all on private.dopmi_campaign_placements from public, anon, authenticated, service_role;

-- Generated from the frozen public-context manifest; all real placements start
-- disabled. Enabling the pilot requires a compatible public Android release.
insert into private.dopmi_campaign_placements(token, experiment_id, arm_id, variant, is_qa, enabled) values
  ('f15b37bdbc1f372944a2fafce56ec77e', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('cf192652a83dac14b388f57605b6edd7', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('31edffccfb0471711ff0669dd5abeeef', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('33f8999e4f89f788e38b5ab99057c005', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('4c420bcb774ee98b928c54ba061e4915', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('b8bcacd286e22eab92ea8a996268a664', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('55098f1e806807416535bc1baf551b9b', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('0f7ddbd087d2902ba87e658e27f65c7f', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('ca80efc3d47722d5b14786d8b30f412f', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('7f162c280758764645d9fb89373bd192', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('ba0e1116a3b4129c275984dcd4b617c1', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('df149001d95633b71a377df96f00d0f5', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('81e6d462fa3a6ffbb021a16521ff22a6', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('71c597f90020153521379a236d9ff82b', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('be08a9d82a13c3d5c63fdddf84bac3fb', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('f058962d068d9995722a984c788089d7', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('89dd1e6b74e2bb6019bfe88842d1e58d', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('c5351c7e3cda320413aba671fcafa6c7', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('1f95602ad4b026d09fb377bde90df0b1', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('9a43331a110ba673e199d1e46b4ed2e3', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('b747848317c0c2d6ae12a034880136a0', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('0ff6e03019b49638b6d8205b6762b3df', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('8024dd5ab198a3a4b94369369551c658', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('cc2dc74465960f222a11ea75bbec0102', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('180e29e7022d2af50fd98269822132e7', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('b46527e49445186f71c52eb98bbb88be', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('812c4f37831c3ebcb4244a3aff591d09', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('13267e0a3030785f297c403ada98e656', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('79ba060e14359b8469a474b6e5336461', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('2967cb1f193bc8936e295ff1b1caa2f9', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('90a64b85e032779a38eaddf9ba5af3b8', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('3aeafcdfaf908ebfb9dcfb72f3eddc71', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('a67974e2b44921ed1b74217f80407cbb', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('e3c85f9153a56d387a0ba4effeb8c545', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('4f013ca7980070f4994a926bd503ef71', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('954da3a6111f19f41f8ea206dfe6cfb9', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('9b8c9db04a92158381636f14a4bba42b', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('d6cbf7c182bd612b13328a70b0ed3812', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('7e2796c59d25acad91531098978f9336', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('f7efa9739158f1c014d64eeb418087d7', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('0dddf388247e6d15caecd244a65d55db', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('ed41e8923112c77b9be98e528444c988', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('b658632fd184c9d25e5fd258ebb494f8', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('e05514e830061efa455c408450080f99', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('e03c3b4d08b43d07e85fea1c581fdbd5', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('9f5d00548f93dbb8257dcc0756e2792c', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('8c3a739aec3bf9cb60a8a8de3120f169', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('64a9f96b66f8e2139b193a1bb5214830', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('e344a2964a6794fb762d4d67043af5bc', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('e99d0da56e7ee04f89f07f612072de9f', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('581e7b22a49cca2c925dee805f637c62', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('7b3fdae245b347978b0636878989548d', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('c3678a684ee7fa489c3fdd52e1afce87', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('91527a1a63e004a73974b6cfab5f4d7b', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('9906b8cea24fb3e59f7d07567b261746', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('d515036060220f69060cb3a935fa06e3', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('2650109ded232d11c4089e2849086c20', 'resc_mty_20261121_p60_v1', 'R4', 'pagina-b', false, false),
  ('b73ecfcd351e04e6f6b7e651c8291aa8', 'resc_mty_20261121_p60_v1', 'R3', 'pagina-a', false, false),
  ('a3745ed5c93664f2969b68da3e96afa4', 'resc_mty_20261121_p60_v1', 'R2', 'personal-b', false, false),
  ('17db9f15f8e1c3da9206be0873da50a7', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', false, false),
  ('43481c7670b31d9d640884ba57bf3b2f', 'resc_mty_20261121_p60_v1', 'R1', 'personal-a', true, true);

alter table private.dopmi_android_rescuer_acquisition
  add column placement_token text references private.dopmi_campaign_placements(token);
create index dopmi_android_acquisition_placement
  on private.dopmi_android_rescuer_acquisition(placement_token)
  where placement_token is not null;

-- The existing source remains the only Android first-source authority. These
-- per-publication receipts preserve original submission time through mutable
-- drafts/corrections. They do not create another source or backfill history.
create table private.dopmi_campaign_adoption_submissions (
  post_id uuid primary key references public.dopmi_adoptions(id) on delete cascade,
  actor_id uuid not null references private.dopmi_android_rescuer_acquisition(actor_id) on delete cascade,
  placement_token text not null references private.dopmi_campaign_placements(token),
  first_submitted_at timestamptz not null
);
create index dopmi_campaign_submissions_actor
  on private.dopmi_campaign_adoption_submissions(actor_id);
alter table private.dopmi_campaign_adoption_submissions enable row level security;
revoke all on private.dopmi_campaign_adoption_submissions from public, anon, authenticated, service_role;

create function public.dopmi_record_android_experiment_acquisition(
  p_placement_token text, p_clicked_at timestamptz, p_expected_consent_revision bigint
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := private.dopmi_require_actor();
  received_at timestamptz := clock_timestamp();
  consent_state private.dopmi_adoption_measurement;
  placement private.dopmi_campaign_placements;
begin
  if p_expected_consent_revision is null or p_expected_consent_revision < 0 then
    raise exception 'Revisión de consentimiento no válida' using errcode = '22023';
  end if;
  if p_clicked_at is null or p_clicked_at > received_at
    or p_clicked_at <= received_at - interval '336 hours' then
    raise exception 'Fecha de referencia fuera del periodo de medición' using errcode = '22023';
  end if;
  if p_placement_token is null or p_placement_token !~ '^[0-9a-f]{32}$' then
    return jsonb_build_object('status', 'invalid_placement');
  end if;

  -- Preserve the existing profile -> consent -> source order. No adoption or
  -- thread row is locked by enrollment. Registry assignment is operator-owned.
  perform 1 from public.profiles p where p.id = actor and p.account_status = 'active'
    for no key update;
  if not found then return jsonb_build_object('status', 'ineligible'); end if;
  select * into consent_state from private.dopmi_adoption_measurement m
    where m.actor_id = actor for update;
  if not found or not consent_state.consent or consent_state.revision <> p_expected_consent_revision then
    return jsonb_build_object('status', 'consent_changed');
  end if;
  select * into placement from private.dopmi_campaign_placements p
    where p.token = p_placement_token and p.enabled for share;
  if not found then return jsonb_build_object('status', 'invalid_placement'); end if;
  if exists (select 1 from private.dopmi_android_rescuer_acquisition s where s.actor_id = actor) then
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
  received_at := clock_timestamp();
  if p_clicked_at > received_at or p_clicked_at <= received_at - interval '336 hours' then
    return jsonb_build_object('status', 'ineligible');
  end if;
  insert into private.dopmi_android_rescuer_acquisition(
    actor_id, variant, clicked_at, attributed_at, placement_token
  ) values (actor, placement.variant, p_clicked_at, received_at, placement.token)
    on conflict(actor_id) do nothing;
  return jsonb_build_object('status', case when found then 'recorded' else 'already_recorded' end);
end;
$$;

create function private.dopmi_observe_campaign_adoption_submission() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  source private.dopmi_android_rescuer_acquisition;
  observed_at timestamptz;
begin
  perform 1 from private.dopmi_adoption_measurement m
    where m.actor_id = new.owner_id and m.consent for update;
  if not found then return null; end if;
  -- Profile deletion may purge a source without taking the consent lock.
  -- Key-share lets its cascade remove this receipt even when capture wins.
  select * into source from private.dopmi_android_rescuer_acquisition s
    where s.actor_id = new.owner_id for key share;
  if not found or source.placement_token is null then return null; end if;
  observed_at := clock_timestamp();
  if observed_at < source.attributed_at or observed_at >= source.clicked_at + interval '336 hours' then
    return null;
  end if;
  insert into private.dopmi_campaign_adoption_submissions(
    post_id, actor_id, placement_token, first_submitted_at
  ) values (new.id, new.owner_id, source.placement_token, observed_at)
    on conflict(post_id) do nothing;
  return null;
end;
$$;
create trigger dopmi_observe_campaign_adoption_submission
after update of submitted_at on public.dopmi_adoptions
for each row when (new.status = 'submitted' and old.submitted_at is null and new.submitted_at is not null)
execute function private.dopmi_observe_campaign_adoption_submission();

revoke all on function public.dopmi_record_android_experiment_acquisition(text,timestamptz,bigint),
  private.dopmi_observe_campaign_adoption_submission()
  from public, anon, authenticated, service_role;
grant execute on function public.dopmi_record_android_experiment_acquisition(text,timestamptz,bigint) to authenticated;

commit;
