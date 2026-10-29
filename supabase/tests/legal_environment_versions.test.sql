begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is(public.dopmi_payment_environment_server()->>'environment','test','legal migration leaves environment TEST');
select ok(private.dopmi_legal_pair_allowed('terms-2026-10-17','privacy-2026-10-17'),'TEST admits current pair');
select ok(private.dopmi_legal_pair_allowed('terms-2026-09-28','privacy-2026-09-28'),'TEST retains September compatibility');
select ok(not private.dopmi_legal_pair_allowed('terms-live-2026-10-28','privacy-live-2026-10-28'),'TEST rejects LIVE pair');
select ok(not private.dopmi_legal_pair_allowed('terms-live-2026-10-28','privacy-2026-10-17'),'mixed LIVE/TEST pair rejected');

insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 ('ea000000-0000-4000-8000-000000000001','legal-env-owner@example.test',now(),
 '{"terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}'),
 ('ea000000-0000-4000-8000-000000000002','legal-env-other@example.test',now(),'{}');
create temporary table legal_environment_history as select to_jsonb(c) value from private.dopmi_consents c
 where c.owner_id='ea000000-0000-4000-8000-000000000001';

update private.dopmi_payment_environment set environment='production';
select ok(private.dopmi_legal_pair_allowed('terms-live-2026-10-28','privacy-live-2026-10-28'),'PROD admits complete LIVE pair');
select ok(not private.dopmi_legal_pair_allowed('terms-2026-10-17','privacy-2026-10-17'),'PROD rejects TEST pair');
select ok(not private.dopmi_legal_pair_allowed('terms-2026-09-28','privacy-2026-09-28'),'PROD rejects September pair');
select ok(not private.dopmi_legal_pair_allowed('terms-2026-10-17','privacy-live-2026-10-28'),'mixed TEST/LIVE pair rejected');
set local role authenticated;
select set_config('request.jwt.claim.sub','ea000000-0000-4000-8000-000000000001',true);
select throws_ok($$select dopmi_accept_legal('terms-2026-10-17','privacy-2026-10-17',true)$$,'22023',null,'PROD cannot newly accept TEST');
select throws_ok($$select dopmi_accept_legal('terms-live-2026-10-28','privacy-2026-10-17',true)$$,'22023',null,'PROD cannot accept mixed pair');
select throws_ok($$select dopmi_accept_legal('terms-live-2026-10-28','privacy-live-2026-10-28',false)$$,'22023',null,'adult confirmation remains required');
select throws_ok('select accept_current_terms()','22023',null,'development RPC cannot bypass production consent');
select throws_ok($$select private.dopmi_legal_pair_allowed('terms-live-2026-10-28','privacy-live-2026-10-28')$$,'42501',null,'private helper cannot be called by clients');
select throws_ok($$update private.dopmi_payment_environment set environment='test'$$,'42501',null,'clients cannot change environment');
select lives_ok('select dopmi_payment_activity()','historical TEST owner can read own history without reaccepting');
select is(dopmi_guardian_registration_cancellation_state(),null::jsonb,'owner can inspect cancellation without reaccepting');
select is(dopmi_account_deletion_status(),null::jsonb,'owner can read deletion state without reaccepting');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','ea000000-0000-4000-8000-000000000001',true);
select set_config('test.legal_live_acceptance',dopmi_accept_legal('terms-live-2026-10-28','privacy-live-2026-10-28',true)::text,true);
select is(dopmi_accept_legal('terms-live-2026-10-28','privacy-live-2026-10-28',true),
 current_setting('test.legal_live_acceptance')::jsonb,'duplicate LIVE acceptance reuses original evidence');
reset role;
select is((select count(*) from private.dopmi_consents where owner_id='ea000000-0000-4000-8000-000000000001'),2::bigint,'TEST and LIVE proofs coexist');
select ok(exists(select 1 from private.dopmi_consents c join legal_environment_history h on to_jsonb(c)=h.value),
 'historical TEST proof remains identical');
select is((select terms_version from public.profiles where id='ea000000-0000-4000-8000-000000000002'),null::text,'another owner stays unchanged');

update private.dopmi_payment_environment set environment='test';
set local role authenticated;
select set_config('request.jwt.claim.sub','ea000000-0000-4000-8000-000000000001',true);
select throws_ok($$select dopmi_accept_legal('terms-2026-10-17','privacy-2026-10-17',true)$$,'22023',null,'LIVE profile cannot downgrade when owner switches DB to TEST');
select throws_ok('select accept_current_terms()','22023',null,'development RPC cannot downgrade LIVE');
reset role;

update private.dopmi_payment_environment set environment='production';
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 ('ea000000-0000-4000-8000-000000000003','legal-env-crossed@example.test',now(),
 '{"terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true,"role":"admin","is_admin":true}'),
 ('ea000000-0000-4000-8000-000000000004','legal-env-live@example.test',now(),
 '{"terms_version":"terms-live-2026-10-28","privacy_version":"privacy-live-2026-10-28","adult_confirmed":true,"role":"admin","is_admin":true}');
select is((select terms_version from public.profiles where id='ea000000-0000-4000-8000-000000000003'),null::text,'crossed signup remains unaccepted without aborting Auth');
select is((select count(*) from private.dopmi_consents where owner_id='ea000000-0000-4000-8000-000000000003'),0::bigint,'crossed signup produces no consent proof');
select is((select terms_version from public.profiles where id='ea000000-0000-4000-8000-000000000004'),'terms-live-2026-10-28','valid production signup records LIVE terms');
set local role authenticated;
select set_config('request.jwt.claim.sub','ea000000-0000-4000-8000-000000000004',true);
select is(dopmi_is_admin(),false,'signup metadata cannot grant administrator authority');
reset role;
set local role anon;
select throws_ok($$select dopmi_accept_legal('terms-live-2026-10-28','privacy-live-2026-10-28',true)$$,'42501',null,'anonymous acceptance denied');
reset role;
set local role service_role;
select throws_ok($$select dopmi_accept_legal('terms-live-2026-10-28','privacy-live-2026-10-28',true)$$,'42501',null,'service cannot impersonate user legal acceptance');
select throws_ok($$update private.dopmi_payment_environment set environment='test'$$,'42501',null,'service cannot change environment');
reset role;

select * from finish();
rollback;
