begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at)
select ('70000000-0000-4000-8000-00000000000'||n)::uuid,'payment-'||n||'@example.test',
 '{"display_name":"Prueba de pagos","terms_version":"development-2026-09-13","terms_accepted":true}',now() from generate_series(1,4)n;
insert into private.admin_memberships(user_id) values('70000000-0000-4000-8000-000000000003');
insert into dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
 ('71000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002','verification','approved','{"public_name":"Refugio"}',null,0),
 ('71000000-0000-4000-8000-000000000002','70000000-0000-4000-8000-000000000002','case','approved','{"pet_name":"Luna"}',null,0),
 ('71000000-0000-4000-8000-000000000003','70000000-0000-4000-8000-000000000002','expense','approved','{"title":"Medicamentos"}','71000000-0000-4000-8000-000000000002',12000);
insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
 values('70000000-0000-4000-8000-000000000002','acct_payment_test',true,true);

set local role anon;
select throws_ok('select * from dopmi_donations','42501',null,'anonymous financial records denied');
select throws_ok($$select dopmi_payment_server('settle','{}')$$,'42501',null,'anonymous settlement denied');
select is((dopmi_expense_funding('71000000-0000-4000-8000-000000000003')->>'funded_cents')::int,0,'approved public progress starts at zero');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-4000-8000-000000000001',true);
select throws_ok($$select dopmi_payment_server('settle','{}')$$,'42501',null,'a donor cannot fabricate a confirmation');
select throws_ok($$update dopmi_donations set payment_status='confirmed'$$,'42501',null,'direct financial writes denied');
select throws_ok('select * from private.dopmi_payment_jobs','42501',null,'payment jobs remain private');
select throws_ok('select dopmi_admin_donations()','42501',null,'non-admin listing denied');
select set_config('request.jwt.claim.sub','70000000-0000-4000-8000-000000000003',true);
select throws_ok($$select dopmi_payment_server('settle','{}')$$,'42501',null,'even an admin client cannot confirm a payment');
reset role;

create temporary table payment_fixture(id uuid);
insert into payment_fixture select (dopmi_payment_server('prepare','{"actor":"70000000-0000-4000-8000-000000000001","expense_id":"71000000-0000-4000-8000-000000000003","key":"72000000-0000-4000-8000-000000000001","gross_cents":10000}')->>'id')::uuid;
select is((select payment_status from dopmi_donations where id=(select id from payment_fixture)),'pending','preparing checkout never confirms payment');
select is((select reserved_cents from dopmi_donations where id=(select id from payment_fixture)),9800::bigint,'reserve upper bound before actual fees');
select is((dopmi_payment_server('prepare','{"actor":"70000000-0000-4000-8000-000000000001","expense_id":"71000000-0000-4000-8000-000000000003","key":"72000000-0000-4000-8000-000000000001","gross_cents":10000}')->>'id')::uuid,(select id from payment_fixture),'checkout retry returns original');
select throws_ok($$select dopmi_payment_server('prepare','{"actor":"70000000-0000-4000-8000-000000000001","expense_id":"71000000-0000-4000-8000-000000000003","key":"72000000-0000-4000-8000-000000000001","gross_cents":11000}')$$,'22023',null,'idempotency does not allow changing the amount');
select dopmi_payment_server('settle',jsonb_build_object('donation_id',(select id from payment_fixture),'currency','mxn','gross_cents',10000,'charge_id','ch_fixture','payment_intent_id','pi_fixture','stripe_fee_cents',600));
select is((select platform_fee_cents from dopmi_donations where id=(select id from payment_fixture)),200::bigint,'platform fee is 2 percent of gross');
select is((select allocated_cents from dopmi_donations where id=(select id from payment_fixture)),9200::bigint,'actual processor fee also deducted');
select is((select transfer_status from dopmi_donations where id=(select id from payment_fixture)),'pending','confirmed is distinct from transferred');
select dopmi_payment_server('settle',jsonb_build_object('donation_id',(select id from payment_fixture),'currency','mxn','gross_cents',10000,'charge_id','ch_fixture','payment_intent_id','pi_fixture','stripe_fee_cents',600));
select is((select count(*) from private.dopmi_payment_jobs where donation_id=(select id from payment_fixture)),1::bigint,'duplicate confirmation creates one transfer job');
select throws_ok($$update dopmi_rescue_records set reimbursable_cents=0 where id='71000000-0000-4000-8000-000000000003'$$,'22023',null,'funded expense cannot lose its approval amount');
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-4000-8000-000000000004',true);
select is((select count(*) from dopmi_donations),0::bigint,'unrelated user sees no payments');
select set_config('request.jwt.claim.sub','70000000-0000-4000-8000-000000000001',true);
select is((select count(*) from dopmi_donations),1::bigint,'donor can read own payment');
select set_config('request.jwt.claim.sub','70000000-0000-4000-8000-000000000003',true);
select is((dopmi_admin_donations()->>'total')::int,1,'server-authorized admin can inspect history');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','70000000-0000-4000-8000-000000000003',true);
select throws_ok($$select dopmi_guardian_reserve('70000000-0000-4000-8000-000000000001','73000000-0000-4000-8000-000000000001',2000)$$,
  '42501',null,'even staff cannot reserve Guardian funds');
select throws_ok('select * from private.dopmi_guardian_allocations','42501',null,'Guardian allocations are private');
reset role;
select is((dopmi_guardian_reserve('70000000-0000-4000-8000-000000000001',
  '73000000-0000-4000-8000-000000000001',2000)->>'reserved_cents')::bigint,1960::bigint,
  'Guardian holds the upper net against the remaining approved expense');
select is((dopmi_expense_funding('71000000-0000-4000-8000-000000000003')->>'available_cents')::bigint,840::bigint,
  'funding availability subtracts a pending Guardian hold');
select is(dopmi_guardian_release('70000000-0000-4000-8000-000000000001',
  '73000000-0000-4000-8000-000000000001')->>'status','released','releasing a hold restores capacity');
select is((dopmi_expense_funding('71000000-0000-4000-8000-000000000003')->>'available_cents')::bigint,2800::bigint,
  'released hold is not counted as paid or reserved');
select * from finish();
rollback;
