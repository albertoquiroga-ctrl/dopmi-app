begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Exact synthetic fixtures in a rolled-back local PostgreSQL transaction.
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 ('b8000000-0000-4000-8000-000000000001','initial-packet-owner@example.test',now(),'{"display_name":"Sintético","terms_accepted":true,"terms_version":"development-2026-09-13"}'),
 ('b8000000-0000-4000-8000-000000000002','initial-packet-staff@example.test',now(),'{"display_name":"Sintético","terms_accepted":true,"terms_version":"development-2026-09-13"}');
insert into private.admin_memberships(user_id) values('b8000000-0000-4000-8000-000000000002');
insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled) values
 ('b8000000-0000-4000-8000-000000000001','acct_initial_packet_pgtap_synthetic',true,true);
insert into dopmi_rescue_records(id,owner_id,kind,public_data,files,video_thanks_required) values
 ('b8100000-0000-4000-8000-000000000001','b8000000-0000-4000-8000-000000000001','case',
 '{"pet_name":"Luna sintética","species":"dog","sex":"unknown","age":"Dos años","story":"Historia sintética para revisión","city":"Monterrey","state":"Nuevo León"}',
 '[{"role":"public","path":"b8000000-0000-4000-8000-000000000001/b8100000-0000-4000-8000-000000000001/b8300000-0000-4000-8000-000000000001.jpg"}]',false);
insert into dopmi_rescue_records(id,owner_id,kind,parent_id,public_data,private_data,files) values
 ('b8200000-0000-4000-8000-000000000001','b8000000-0000-4000-8000-000000000001','expense','b8100000-0000-4000-8000-000000000001',
 '{"title":"Consulta pagada sintética","description":"Descripción sintética de gasto pagado","category":"veterinary"}',
 '{"paid_on":"2026-09-01","vendor":"Proveedor sintético","amount_cents":"10000","receipt_reference":"packet-pgtap-1"}',
 '[{"role":"receipt","path":"b8000000-0000-4000-8000-000000000001/b8200000-0000-4000-8000-000000000001/b8300000-0000-4000-8000-000000000002.pdf"},{"role":"proof","path":"b8000000-0000-4000-8000-000000000001/b8200000-0000-4000-8000-000000000001/b8300000-0000-4000-8000-000000000003.jpg"}]');
insert into storage.objects(bucket_id,name)
 select 'dopmi-rescue-evidence',f->>'path' from dopmi_rescue_records r cross join lateral jsonb_array_elements(r.files) f
 where r.id in ('b8100000-0000-4000-8000-000000000001','b8200000-0000-4000-8000-000000000001');

select ok(not has_table_privilege('authenticated','private.dopmi_case_need_submissions','select'),'manifest stays private');
select ok(not has_table_privilege('service_role','private.dopmi_case_need_submission_expenses','update'),'no new service table privilege');
select ok(not has_function_privilege('authenticated','public.dopmi_review_rescue_before_initial_packet(uuid,integer,text,text,bigint,boolean,text,boolean)','execute'),'legacy delegation cannot bypass joint API');
set local role authenticated;
select set_config('request.jwt.claim.sub','b8000000-0000-4000-8000-000000000001',true);
select is(dopmi_transition_rescue('b8100000-0000-4000-8000-000000000001',1,'submit')->>'status','submitted','one case submission shares initial draft');
select throws_ok($$select dopmi_remove_draft_expense('b8200000-0000-4000-8000-000000000001',1)$$,'22023',null,'owner cannot erase unread initial membership through draft-removal RPC');
with deleted as(delete from storage.objects where name='b8000000-0000-4000-8000-000000000001/b8200000-0000-4000-8000-000000000001/b8300000-0000-4000-8000-000000000002.pdf' returning id)
select is(count(*),0::bigint,'Storage RLS prevents deletion of captured receipt') from deleted;
select throws_ok($$insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence','b8000000-0000-4000-8000-000000000001/b8200000-0000-4000-8000-000000000001/b8300000-0000-4000-8000-000000000002.pdf')$$,'42501',null,'Storage RLS prevents reinsertion of captured path');
reset role;
select is((select count(*) from private.dopmi_case_need_submissions where case_id='b8100000-0000-4000-8000-000000000001'),1::bigint,'exactly one new explicit manifest');
select set_config('dopmi.test.initial_submission',(select id::text from private.dopmi_case_need_submissions where case_id='b8100000-0000-4000-8000-000000000001'),true);
select set_config('dopmi.test.initial_choices','[{"expense_id":"b8200000-0000-4000-8000-000000000001","expense_version":1,"amount_cents":7000,"is_urgent":false,"urgency_note":"","publish_content":true}]',true);
select is((select status from dopmi_rescue_records where id='b8200000-0000-4000-8000-000000000001'),'draft','sharing does not grant financial submission or approval');

-- A newly created draft has never been shared by this case submission.
insert into dopmi_rescue_records(id,owner_id,kind,parent_id,public_data) values
 ('b8200000-0000-4000-8000-000000000002','b8000000-0000-4000-8000-000000000001','expense','b8100000-0000-4000-8000-000000000001','{"title":"DRAFT posterior privado"}');
set local role authenticated;
select set_config('request.jwt.claim.sub','b8000000-0000-4000-8000-000000000002',true);
select is((dopmi_admin_rescue_packet('b8100000-0000-4000-8000-000000000001')->'expenses'->>'total')::integer,1,'only manifest membership contributes to packet total');
select is(dopmi_admin_rescue_packet('b8100000-0000-4000-8000-000000000001')->'expenses'->'items'->0->>'status','draft','staff sees frozen initial draft snapshot');
select ok(dopmi_admin_rescue_packet('b8100000-0000-4000-8000-000000000001')::text not like '%DRAFT posterior privado%','later private draft is never included');
select throws_ok($$select dopmi_review_rescue('b8100000-0000-4000-8000-000000000001',2,'approved','Revisión sintética',0,false,'',true)$$,'22023',null,'legacy case decision cannot bypass exact initial package');
select throws_ok($$select dopmi_review_rescue('b8200000-0000-4000-8000-000000000001',1,'approved','Revisión sintética',7000,false,'',true)$$,'22023',null,'included expense cannot be approved individually');
select is(jsonb_array_length(dopmi_comment_case_needs('b8100000-0000-4000-8000-000000000001',2,
 '[{"target_kind":"expense","target_id":"b8200000-0000-4000-8000-000000000001","target_version":1,"body":"Aclara este comprobante"}]',
 'b8400000-0000-4000-8000-000000000001')->'comments'),1,'comments resolve frozen draft identity and version');
select throws_ok($$select dopmi_review_initial_case_packet('b8100000-0000-4000-8000-000000000001',2,current_setting('dopmi.test.initial_submission')::uuid,
 'approved','Revisión sintética',true,'[]','b8400000-0000-4000-8000-000000000002')$$,'40001',null,'missing choice cannot partially approve case');
select throws_ok($$select dopmi_review_initial_case_packet('b8100000-0000-4000-8000-000000000001',2,current_setting('dopmi.test.initial_submission')::uuid,
 'approved','Revisión sintética',true,jsonb_set(current_setting('dopmi.test.initial_choices')::jsonb,'{0,amount_cents}','10001'),
 'b8400000-0000-4000-8000-000000000002')$$,'22023',null,'paid-amount ceiling rolls back the entire case decision');
reset role;
select is((select status from dopmi_rescue_records where id='b8100000-0000-4000-8000-000000000001'),'submitted','failed last financial review left parent submitted');
select is((select status from dopmi_rescue_records where id='b8200000-0000-4000-8000-000000000001'),'draft','failed last financial review left child draft');
create temporary table initial_packet_response(result jsonb);
grant select,insert on initial_packet_response to authenticated;
set local role authenticated;
insert into initial_packet_response select dopmi_review_initial_case_packet('b8100000-0000-4000-8000-000000000001',2,
 current_setting('dopmi.test.initial_submission')::uuid,'approved','Revisión sintética',true,current_setting('dopmi.test.initial_choices')::jsonb,
 'b8400000-0000-4000-8000-000000000002');
select is((select result->'record'->>'status' from initial_packet_response),'approved','one review approves case');
select is((select result->'expenses'->0->>'status' from initial_packet_response),'approved','same transaction approves expense');
select is((select (result->'expenses'->0->>'reimbursable_cents')::bigint from initial_packet_response),7000::bigint,'only explicitly entered reimbursement is approved');
select is(dopmi_review_initial_case_packet('b8100000-0000-4000-8000-000000000001',2,current_setting('dopmi.test.initial_submission')::uuid,
 'approved','Revisión sintética',true,current_setting('dopmi.test.initial_choices')::jsonb,'b8400000-0000-4000-8000-000000000002'),
 (select result from initial_packet_response),'lost response retries return the original exact response');
reset role;
select is((select count(*) from private.dopmi_rescue_history where record_id='b8100000-0000-4000-8000-000000000001' and action='approved'),1::bigint,'replay adds no approval event');
update private.admin_memberships set active=false where user_id='b8000000-0000-4000-8000-000000000002';
set local role authenticated;
select throws_ok($$select dopmi_review_initial_case_packet('b8100000-0000-4000-8000-000000000001',2,current_setting('dopmi.test.initial_submission')::uuid,
 'approved','Revisión sintética',true,current_setting('dopmi.test.initial_choices')::jsonb,'b8400000-0000-4000-8000-000000000002')$$,'42501',null,'revoked reviewer cannot replay stored response');
reset role;
select * from finish();
rollback;
