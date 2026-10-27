begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Entirely synthetic local records; the transaction rolls back all changes.
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 ('a7000000-0000-4000-8000-000000000001','pending-stripe-owner@example.test',now(),'{"display_name":"Prueba","terms_accepted":true,"terms_version":"development-2026-09-13"}'),
 ('a7000000-0000-4000-8000-000000000002','pending-stripe-staff@example.test',now(),'{"display_name":"Prueba","terms_accepted":true,"terms_version":"development-2026-09-13"}');
insert into private.admin_memberships(user_id) values('a7000000-0000-4000-8000-000000000002');
insert into dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot) values
 ('a7100000-0000-4000-8000-000000000001','a7000000-0000-4000-8000-000000000001','verification','approved','{}');
insert into private.dopmi_connect_accounts(owner_id,account_id,details_submitted) values
 ('a7000000-0000-4000-8000-000000000001','acct_pending_stripe_pgtap_synthetic',true);
insert into dopmi_rescue_records(id,owner_id,kind,public_data,files,video_thanks_required) values
 ('a7100000-0000-4000-8000-000000000002','a7000000-0000-4000-8000-000000000001','case',
 '{"pet_name":"Luna sintética","species":"dog","sex":"unknown","age":"Dos años","story":"Historia sintética para revisión","city":"Monterrey","state":"Nuevo León"}',
 '[{"role":"public","path":"a7000000-0000-4000-8000-000000000001/a7100000-0000-4000-8000-000000000002/a7200000-0000-4000-8000-000000000001.jpg"}]',false);
insert into storage.objects(bucket_id,name) values
 ('dopmi-rescue-evidence','a7000000-0000-4000-8000-000000000001/a7100000-0000-4000-8000-000000000002/a7200000-0000-4000-8000-000000000001.jpg');

set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-4000-8000-000000000001',true);
select is(dopmi_transition_rescue('a7100000-0000-4000-8000-000000000002',1,'submit')->>'status','pending_stripe','details submitted alone does not qualify for Dopmi review');
select is((dopmi_rescue_detail('a7100000-0000-4000-8000-000000000002')->'record'->>'version')::integer,2,'owner reads pending with one version increment');
select is((dopmi_rescuer_dashboard_v2()->'support_counts'->>'pendingStripe')::integer,1,'dashboard counts waiting for Stripe explicitly');
select is((dopmi_rescuer_dashboard_v2()->'support_counts'->>'review')::integer,0,'waiting is not review');
select is((dopmi_owned_cases('support',array['pending_stripe'])->'items'->0->>'phase'),'pending_stripe','owned list uses the dedicated phase');
select is((select count(*) from storage.objects where bucket_id='dopmi-rescue-evidence' and name like 'a7000000%'),1::bigint,'owner reads their pending photo');
select is(dopmi_rescue_file_access('a7000000-0000-4000-8000-000000000001/a7100000-0000-4000-8000-000000000002/a7200000-0000-4000-8000-000000000001.jpg',true),false,'owner cannot replace pending photo');
select throws_ok($$select dopmi_save_rescue('case','{}','{}','[]','a7100000-0000-4000-8000-000000000002',2)$$,'22023',null,'pending content must be withdrawn before editing');
select set_config('request.jwt.claim.sub','a7000000-0000-4000-8000-000000000002',true);
select throws_ok($$select dopmi_rescue_detail('a7100000-0000-4000-8000-000000000002')$$,'42501',null,'staff cannot read pending case detail');
select is((select count(*) from storage.objects where bucket_id='dopmi-rescue-evidence' and name like 'a7000000%'),0::bigint,'staff cannot read pending evidence through actual Storage RLS');
select throws_ok($$select dopmi_review_rescue('a7100000-0000-4000-8000-000000000002',2,'approved','Revisión sintética',0,false,'',true)$$,'22023',null,'staff cannot approve a pending case');
select throws_ok($$select dopmi_payment_server('connect_save','{}')$$,'42501',null,'staff cannot forge Stripe readiness');

set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is((dopmi_rescue_public('a7100000-0000-4000-8000-000000000002')->>'total')::integer,0,'pending has no public snapshot');
reset role;
select is((select submitted_at from dopmi_rescue_records where id='a7100000-0000-4000-8000-000000000002'),null::timestamptz,'review clock starts only after Stripe readiness');

set local role service_role;
select dopmi_payment_server('connect_save','{"actor":"a7000000-0000-4000-8000-000000000001","account_id":"acct_pending_stripe_pgtap_synthetic","transfers_enabled":true,"payouts_enabled":false,"details_submitted":true}');
reset role;
select is((select status from dopmi_rescue_records where id='a7100000-0000-4000-8000-000000000002'),'pending_stripe','both transfer and payout readiness are required');
set local role service_role;
select dopmi_payment_server('connect_save','{"actor":"a7000000-0000-4000-8000-000000000001","account_id":"acct_pending_stripe_pgtap_synthetic","transfers_enabled":true,"payouts_enabled":true,"details_submitted":false}');
reset role;
select is((select status from dopmi_rescue_records where id='a7100000-0000-4000-8000-000000000002'),'submitted','service-ready promotes to review only');
select is((select version from dopmi_rescue_records where id='a7100000-0000-4000-8000-000000000002'),3,'promotion increments once');
select ok((select submitted_at is not null and approved_at is null and approved_snapshot is null and reimbursable_cents=0 from dopmi_rescue_records where id='a7100000-0000-4000-8000-000000000002'),'promotion creates neither approval nor money');
select is((select count(*) from private.dopmi_rescue_history where record_id='a7100000-0000-4000-8000-000000000002' and actor_type='system' and source='stripe_connect_ready' and actor_id is null and previous_status='pending_stripe'),1::bigint,'system promotion has explicit source and no impersonated owner');
select is((select actor_id from private.dopmi_rescue_history where record_id='a7100000-0000-4000-8000-000000000002' and action='submit'),'a7000000-0000-4000-8000-000000000001'::uuid,'original submit remains attributed to its human');
set local role service_role;
select dopmi_payment_server('connect_save','{"actor":"a7000000-0000-4000-8000-000000000001","account_id":"acct_pending_stripe_pgtap_synthetic","transfers_enabled":true,"payouts_enabled":true,"details_submitted":true}');
reset role;
select is((select version from dopmi_rescue_records where id='a7100000-0000-4000-8000-000000000002'),3,'duplicate ready does not resubmit');
select is((select count(*) from private.dopmi_rescue_history where record_id='a7100000-0000-4000-8000-000000000002' and actor_type='system'),1::bigint,'duplicate ready does not append history');
select ok(not has_table_privilege('authenticated','private.dopmi_rescue_history','select'),'history table remains private');
select ok(not has_function_privilege('service_role','public.dopmi_payment_server_before_pending_stripe(text,jsonb)','execute'),'service cannot bypass the wrapper');
select * from finish();
rollback;
