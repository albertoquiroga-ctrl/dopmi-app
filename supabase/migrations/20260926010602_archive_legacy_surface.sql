-- H7: reversible retirement of pre-pivot test surfaces.
-- Keep rows, constraints, blobs and original source backups; never reset Auth/modern Dopmi.
create schema if not exists dopmi_legacy;
revoke all on schema dopmi_legacy from public, anon, authenticated, service_role;
comment on schema dopmi_legacy is 'Retired pre-pivot test data. Not exposed by PostgREST. Restore only through reviewed recovery.';

do $archive$
declare
  object_name text;
  item record;
  legacy_tables text[] := array['achievements','adoption_applications','community_goals','conversations','device_tokens','donations','error_reports','fund_pool_contributions','fund_pool_disbursements','fund_pool_settings','fund_pool_subscriptions','messages','needs','notifications','partner_products','payment_methods','pets','posts','reimbursement_requests','reports','rescuer_profiles','saved_pets','saved_rescuers','sponsorship_charges','sponsorships','transactions','user_achievements','user_feedback','users'];
begin
  -- No modern relation may depend on a legacy table.
  if exists (
    select 1 from pg_constraint c
    join pg_class target on target.oid=c.confrelid
    join pg_namespace tn on tn.oid=target.relnamespace
    join pg_class source on source.oid=c.conrelid
    join pg_namespace sn on sn.oid=source.relnamespace
    where c.contype='f' and tn.nspname='public' and target.relname=any(legacy_tables)
      and not (sn.nspname='public' and source.relname=any(legacy_tables))
  ) then raise exception 'External foreign key to legacy table; inspect before archival'; end if;

  -- Auth owns its table; do not alter platform-owned auth.users. Retire only
  -- the legacy trigger routine as a no-op; private.create_profile stays active.
  if to_regprocedure('public.handle_new_auth_user()') is not null then
    execute $routine$create or replace function public.handle_new_auth_user()
      returns trigger language plpgsql security definer set search_path=pg_catalog
      as $body$ begin return new; end $body$$routine$;
  end if;

  -- Drop only the 16 legacy Storage policies. Modern private evidence stays intact.
  foreach object_name in array array[
    'avatars_delete','avatars_modify','avatars_read','avatars_write',
    'kyc_docs_delete','kyc_docs_modify','kyc_docs_read','kyc_docs_write',
    'pet_photos_delete','pet_photos_modify','pet_photos_read','pet_photos_write',
    'posts_delete','posts_modify','posts_read','posts_write'
  ] loop
    execute format('drop policy if exists %I on storage.objects',object_name);
  end loop;
  update storage.buckets set public=false where id in ('avatars','kyc-docs','pet-photos','posts');

  -- Jobs remain recoverable by name; the current payment worker is untouched.
  if to_regclass('cron.job') is not null then
    for item in execute $cron$select jobid from cron.job where jobname in
      ('cleanup-expired-spei','close-expired-sponsor-windows','sponsorship-cycle-warnings')$cron$
    loop
      perform cron.alter_job(item.jobid, active := false);
    end loop;
  end if;

  foreach object_name in array legacy_tables loop
    if to_regclass(format('public.%I',object_name)) is not null then
      execute format('alter table public.%I set schema dopmi_legacy',object_name);
    end if;
  end loop;
  if to_regclass('public.v_deprecated_sponsorships') is not null then
    alter view public.v_deprecated_sponsorships set schema dopmi_legacy;
  end if;
  if to_regclass('public.v_fund_pool_balance') is not null then
    alter materialized view public.v_fund_pool_balance set schema dopmi_legacy;
  end if;

  for item in select p.oid::regprocedure as identity from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=any(array['bump_conversation_last_message','fn_support_notify_admins','handle_new_auth_user','release_claims_on_sponsorship_end','messages_read_only_update','posts_verified_guard','fn_need_urgent_check','fn_need_urgent_blocks_donation','write_ledger_on_confirmed_sponsorship_charge','claim_for_everything_sponsor','raise_immutable','fn_pool_balance_refresh','is_admin','rescuer_profile_owner_guard','has_active_sponsorship_on','users_self_update_guard','reimbursement_owner_guard','notifications_read_only_update','recompute_need_raised','is_pet_rescuer'])
  loop
    execute format('alter function %s set schema dopmi_legacy',item.identity);
  end loop;
end $archive$;

-- Explicit grants survive SET SCHEMA; revoke all, including column grants.
revoke all on all tables in schema dopmi_legacy from public, anon, authenticated, service_role;
revoke all on all sequences in schema dopmi_legacy from public, anon, authenticated, service_role;
revoke all on all functions in schema dopmi_legacy from public, anon, authenticated, service_role;
do $permissions$
declare item record;
begin
  for item in select c.relname,a.attname from pg_attribute a
    join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='dopmi_legacy' and a.attnum>0 and not a.attisdropped and a.attacl is not null
  loop
    execute format('revoke all (%I) on dopmi_legacy.%I from public, anon, authenticated, service_role',item.attname,item.relname);
  end loop;
  -- Archived routines cannot be used by clients; pin lookup so security linters
  -- do not leave an unsafe definer routine available if grants change later.
  for item in select p.oid::regprocedure as identity from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace where n.nspname='dopmi_legacy'
  loop
    execute format('alter function %s set search_path = pg_catalog, dopmi_legacy',item.identity);
  end loop;
end $permissions$;
notify pgrst, 'reload schema';
