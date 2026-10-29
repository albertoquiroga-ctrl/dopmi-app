begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is(public.dopmi_payment_environment_server(),
  '{"environment":"test","expected_livemode":false,"oneoff_consent_version":"oneoff-test-2026-10-15"}'::jsonb,
  'migration defaults to TEST without activating real payments');
select is((select count(*) from private.dopmi_payment_environment),1::bigint,'one configuration row');
select ok((select relrowsecurity from pg_class where oid='private.dopmi_payment_environment'::regclass),'configuration has RLS');
select is((select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','private') and p.proname like 'dopmi_payment_environment%'),1::bigint,'read RPC has no setter companion');
select throws_ok($$update private.dopmi_payment_environment set environment='live'$$,'23514',null,'unknown environment rejected');
select throws_ok($$insert into private.dopmi_payment_environment values(false,'test')$$,'23514',null,'second singleton identity rejected');
select throws_ok($$insert into private.dopmi_payment_environment values(true,'test')$$,'23505',null,'second configuration row rejected');

set local role anon;
select throws_ok('select public.dopmi_payment_environment_server()','42501',null,'anonymous cannot call environment RPC');
select throws_ok('select * from private.dopmi_payment_environment','42501',null,'anonymous cannot read configuration');
select throws_ok($$update private.dopmi_payment_environment set environment='production'$$,'42501',null,'anonymous cannot activate production');
reset role;
set local role authenticated;
select throws_ok('select public.dopmi_payment_environment_server()','42501',null,'authenticated cannot call environment RPC');
select throws_ok('select * from private.dopmi_payment_environment','42501',null,'authenticated cannot read configuration');
select throws_ok($$update private.dopmi_payment_environment set environment='production'$$,'42501',null,'authenticated cannot activate production');
reset role;
set local role service_role;
select is(public.dopmi_payment_environment_server()->>'environment','test','service reads configured environment');
select throws_ok('select * from private.dopmi_payment_environment','42501',null,'service cannot read raw configuration');
select throws_ok($$update private.dopmi_payment_environment set environment='production'$$,'42501',null,'service cannot activate production');
select throws_ok($$insert into private.dopmi_payment_environment values(true,'production')$$,'42501',null,'service cannot insert configuration');
select throws_ok('delete from private.dopmi_payment_environment','42501',null,'service cannot delete configuration');
reset role;

insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at)
select ('e9000000-0000-4000-8000-00000000000'||n)::uuid,'payment-env-'||n||'@example.test',
 '{"display_name":"Prueba SQL","terms_version":"development-2026-09-13","terms_accepted":true}',now() from generate_series(1,3)n;
insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
 ('e9100000-0000-4000-8000-000000000001','e9000000-0000-4000-8000-000000000002','verification','approved','{"public_name":"Refugio"}',null,0),
 ('e9100000-0000-4000-8000-000000000002','e9000000-0000-4000-8000-000000000002','case','approved','{"pet_name":"Luna"}',null,0),
 ('e9100000-0000-4000-8000-000000000003','e9000000-0000-4000-8000-000000000002','expense','approved','{"title":"Medicamentos"}','e9100000-0000-4000-8000-000000000002',100000);
insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
 values('e9000000-0000-4000-8000-000000000002','acct_environment',true,true);

-- Temporary helper keeps both production RPCs under the same acceptance cases.
create function pg_temp.environment_rpc(name text,operation text,data jsonb) returns jsonb
language plpgsql as $$declare result jsonb; begin
 execute format('select public.%I($1,$2)',name) into result using operation,data;
 return result;
end; $$;
create temporary table environment_attempts(name text primary key,data jsonb,value jsonb);
insert into environment_attempts(name,data) values
 ('dopmi_oneoff_native_server','{"actor":"e9000000-0000-4000-8000-000000000001","key":"e9200000-0000-4000-8000-000000000001","expense_id":"e9100000-0000-4000-8000-000000000003","gross_cents":1000,"consent":true,"consent_version":"oneoff-test-2026-10-15"}'),
 ('dopmi_oneoff_case_server','{"actor":"e9000000-0000-4000-8000-000000000001","key":"e9200000-0000-4000-8000-000000000002","case_id":"e9100000-0000-4000-8000-000000000002","gross_cents":1000,"consent":true,"consent_version":"oneoff-test-2026-10-15"}');
select throws_ok(format('select pg_temp.environment_rpc(%L,%L,%L::jsonb)',name,'prepare',data||'{"consent_version":"oneoff-live-2026-10-28"}'::jsonb),
 '22023',null,name||' rejects LIVE consent in TEST') from environment_attempts;
update environment_attempts set value=pg_temp.environment_rpc(name,'prepare',data);
select is(pg_temp.environment_rpc(name,'prepare',data),value,name||' retries stable TEST key') from environment_attempts;
create temporary table historical_environment_evidence as
 select d.id,to_jsonb(d) donation,to_jsonb(c) checkout from public.dopmi_donations d
 join private.dopmi_checkouts c on c.donation_id=d.id;

select lives_ok($$update private.dopmi_payment_environment set environment='production'$$,'database owner may configure production');
select is(public.dopmi_payment_environment_server(),
 '{"environment":"production","expected_livemode":true,"oneoff_consent_version":"oneoff-live-2026-10-28"}'::jsonb,'production binding is explicit');
select throws_ok(format('select pg_temp.environment_rpc(%L,%L,%L::jsonb)',name,'prepare',data),
 '22023',null,name||' rejects TEST consent in production') from environment_attempts;
select ok(not exists(select 1 from historical_environment_evidence h
 join public.dopmi_donations d on d.id=h.id join private.dopmi_checkouts c on c.donation_id=d.id
 where to_jsonb(d)<>h.donation or to_jsonb(c)<>h.checkout),'historical TEST consent and reservation remain intact');
select is(public.dopmi_oneoff_native_server('get',
 '{"actor":"e9000000-0000-4000-8000-000000000001","key":"e9200000-0000-4000-8000-000000000001"}')->>'consent_version',
 'oneoff-test-2026-10-15','historical TEST receipt stays TEST after configuration changes');
-- This PgTAP suite runs against the complete current schema. New financial
-- instructions additionally require B4 LIVE legal evidence, unlike the isolated
-- B2 PGlite migration-contract suite.
set local role authenticated;
select set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000001',true);
select lives_ok($$select dopmi_accept_legal('terms-live-2026-10-28','privacy-live-2026-10-28',true)$$,'current donor accepts LIVE legal pair');
select set_config('request.jwt.claim.sub','e9000000-0000-4000-8000-000000000003',true);
select lives_ok($$select dopmi_accept_legal('terms-live-2026-10-28','privacy-live-2026-10-28',true)$$,'current Checkout owner accepts LIVE legal pair');
reset role;
update environment_attempts set data=data||jsonb_build_object('consent_version','oneoff-live-2026-10-28','key',gen_random_uuid());
select throws_ok(format('select pg_temp.environment_rpc(%L,%L,%L::jsonb)',name,'prepare',data||'{"consent":false}'::jsonb),
 '22023',null,name||' still requires affirmative consent') from environment_attempts;
update environment_attempts set value=pg_temp.environment_rpc(name,'prepare',data);
select is(value->>'consent_version','oneoff-live-2026-10-28',name||' stores LIVE consent') from environment_attempts;
select is(pg_temp.environment_rpc(name,'prepare',data),value,name||' retries stable LIVE key') from environment_attempts;
select is((value->>'reserved_cents')::bigint,980::bigint,name||' preserves complete net reservation') from environment_attempts;
select is(pg_temp.environment_rpc(name,'get',data||'{"actor":"e9000000-0000-4000-8000-000000000003"}'::jsonb),null::jsonb,
 name||' keeps owner filtering') from environment_attempts;

-- Checkout is still a provider-bound identity. Mode comes from the binding above,
-- never from the textual prefix or a client-provided parameter.
create temporary table environment_checkouts(name text,operation text,fields jsonb,table_name text,column_name text,row_id uuid);
create temporary table environment_activation as select public.dopmi_guardian_activation_server('prepare',
 '{"donor_id":"e9000000-0000-4000-8000-000000000003","key":"e9200000-0000-4000-8000-000000000003","gross_cents":2000,"consent":true,"consent_version":"guardian-2026-09-24","return_url":"https://example.test/functions/v1/payment-return"}') value;
update environment_activation set value=public.dopmi_guardian_activation_server('claim_checkout',jsonb_build_object('cycle_id',value->>'cycle_id'));
insert into environment_checkouts select 'dopmi_guardian_activation_server','save_checkout',
 jsonb_build_object('cycle_id',value->>'cycle_id','lease',value->>'lease'),'dopmi_guardian_activations','cycle_id',(value->>'cycle_id')::uuid from environment_activation;
insert into private.dopmi_guardian_subscriptions(donor_id,stripe_customer_id,stripe_subscription_id,stripe_price_id,gross_cents,initial_payment_intent_id,initial_charge_id,management_revision)
 values('e9000000-0000-4000-8000-000000000003','cus_environment','sub_environment','price_environment',2000,'pi_environment','ch_environment',1);
insert into private.dopmi_guardian_schedule_jobs(cycle_id,status,charge_created,next_billing_at,price_id,subscription_id)
 select (value->>'cycle_id')::uuid,'ready',1700000000,now()+interval '1 month','price_environment','sub_environment' from environment_activation;
with job as (insert into private.dopmi_guardian_method_jobs(donor_id,subscription_id,request_key,revision,consent_version,expires_at,return_url,checkout_attempts)
 values('e9000000-0000-4000-8000-000000000003','sub_environment',gen_random_uuid(),1,'guardian-2026-09-24',now()+interval '35 minutes','https://example.test/functions/v1/payment-return',1) returning id)
insert into environment_checkouts select 'dopmi_guardian_method_server','session',jsonb_build_object('job_id',id),'dopmi_guardian_method_jobs','id',id from job;
update environment_checkouts set fields=fields||jsonb_build_object('lease',public.dopmi_guardian_method_server('claim',fields)->>'lease') where name='dopmi_guardian_method_server';
with saved as (select public.dopmi_saved_card_server('prepare',
 '{"owner_id":"e9000000-0000-4000-8000-000000000003","key":"e9200000-0000-4000-8000-000000000004","consent":true,"consent_version":"saved-cards-2026-10-03","return_url":"https://example.test/functions/v1/payment-return"}') value)
insert into environment_checkouts select 'dopmi_saved_card_server','session',jsonb_build_object('id',value->>'id'),'dopmi_saved_card_jobs','id',(value->>'id')::uuid from saved;
update environment_checkouts set fields=fields||jsonb_build_object('lease',public.dopmi_saved_card_server('claim',fields)->>'lease') where name='dopmi_saved_card_server';

select lives_ok(format('select pg_temp.environment_rpc(%L,%L,%L::jsonb)',name,operation,
 fields||jsonb_build_object('session_id','cs_live_'||replace(row_id::text,'-',''))),name||' accepts LIVE Checkout') from environment_checkouts;
select throws_ok(format('select pg_temp.environment_rpc(%L,%L,%L::jsonb)',name,operation,
 fields||'{"session_id":"cs_live_Alien123"}'::jsonb),'22023',null,name||' cannot replace a bound Checkout') from environment_checkouts;
select lives_ok(format('update private.%I set session_id=%L where %I=%L',table_name,
 prefix||replace(row_id::text,'-',''),column_name,row_id),table_name||' preserves format '||prefix)
 from environment_checkouts cross join (values('cs_'),('cs_test_'),('cs_live_')) formats(prefix);
select throws_ok(format('update private.%I set session_id=%L where %I=%L',table_name,bad,column_name,row_id),
 '23514',null,table_name||' rejects malformed Checkout '||bad)
 from environment_checkouts cross join (values('cs_live_'),('cs_bad_id'),('pi_live_123'),('cs_live_x/y')) invalid(bad);

select * from finish();
rollback;
