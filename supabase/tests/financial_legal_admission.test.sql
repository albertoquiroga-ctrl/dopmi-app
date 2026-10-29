begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
select ('eb000000-0000-4000-8000-00000000000'||n)::uuid,'financial-legal-'||n||'@example.test',now(),
 '{"display_name":"Prueba financiera","terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}' from generate_series(1,3)n;
insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
 ('eb100000-0000-4000-8000-000000000001','eb000000-0000-4000-8000-000000000003','verification','approved','{"public_name":"Refugio"}',null,0),
 ('eb100000-0000-4000-8000-000000000002','eb000000-0000-4000-8000-000000000003','case','approved','{"pet_name":"Luna"}',null,0),
 ('eb100000-0000-4000-8000-000000000003','eb000000-0000-4000-8000-000000000003','expense','approved','{"title":"Medicamentos"}','eb100000-0000-4000-8000-000000000002',100000);
insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
 values('eb000000-0000-4000-8000-000000000003','acct_financial_legal',true,true);
set local role service_role;
select is(dopmi_payment_server('connect_admit','{"actor":"eb000000-0000-4000-8000-000000000001"}'),'{"allowed":true}'::jsonb,'TEST keeps previous admission contract');
select throws_ok($$select private.dopmi_require_current_legal('eb000000-0000-4000-8000-000000000001')$$,'42501',null,'service cannot execute private legal helper directly');
reset role;
update private.dopmi_payment_environment set environment='production';
set local role service_role;
select throws_ok($$select dopmi_payment_server('connect_admit','{"actor":"eb000000-0000-4000-8000-000000000001"}')$$,'42501',null,'TEST consent never authorizes new LIVE sharing');
select throws_ok($$select dopmi_oneoff_native_server('prepare','{"actor":"eb000000-0000-4000-8000-000000000001","key":"eb200000-0000-4000-8000-000000000001","expense_id":"eb100000-0000-4000-8000-000000000003","gross_cents":1000,"consent":true,"consent_version":"oneoff-live-2026-10-28"}')$$,
 '42501',null,'one-off payment consent cannot substitute LIVE legal consent');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','eb000000-0000-4000-8000-000000000001',true);
select lives_ok($$select dopmi_accept_legal('terms-live-2026-10-28','privacy-live-2026-10-28',true)$$,'owner records exact LIVE legal pair');
select throws_ok($$select dopmi_payment_server('connect_admit','{"actor":"eb000000-0000-4000-8000-000000000001"}')$$,'42501',null,'client cannot call server dispatcher');
reset role;
set local role service_role;
select is(dopmi_payment_server('connect_admit','{"actor":"eb000000-0000-4000-8000-000000000001"}'),'{"allowed":true}'::jsonb,'genuine owner LIVE proof permits sharing');
select throws_ok($$select dopmi_payment_server('connect_admit','{"actor":"eb000000-0000-4000-8000-000000000002"}')$$,'42501',null,'another actor cannot borrow LIVE evidence');
select lives_ok($$select dopmi_oneoff_native_server('prepare','{"actor":"eb000000-0000-4000-8000-000000000001","key":"eb200000-0000-4000-8000-000000000001","expense_id":"eb100000-0000-4000-8000-000000000003","gross_cents":1000,"consent":true,"consent_version":"oneoff-live-2026-10-28"}')$$,
 'exact LIVE legal and one-off consents permit a new reservation');
reset role;
select is((select count(*) from public.dopmi_donations where donor_id='eb000000-0000-4000-8000-000000000001'),1::bigint,'one stable financial instruction');
update private.dopmi_consents set adult_confirmed=false where owner_id='eb000000-0000-4000-8000-000000000001' and terms_version='terms-live-2026-10-28';
set local role service_role;
select throws_ok($$select dopmi_payment_server('connect_admit','{"actor":"eb000000-0000-4000-8000-000000000001"}')$$,'42501',null,'false audit cannot authorize a new operation');
select lives_ok($$select dopmi_oneoff_native_server('bind','{"actor":"eb000000-0000-4000-8000-000000000001","key":"eb200000-0000-4000-8000-000000000001","payment_intent_id":"pi_financiallegal"}')$$,
 'existing provider identity reconciliation remains available');
select lives_ok($$select dopmi_oneoff_native_server('canceled','{"actor":"eb000000-0000-4000-8000-000000000001","key":"eb200000-0000-4000-8000-000000000001","payment_intent_id":"pi_financiallegal"}')$$,
 'cancellation remains available without new legal acceptance');
reset role;

select * from finish();
rollback;
