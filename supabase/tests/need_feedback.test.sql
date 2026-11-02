begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Synthetic transaction only. Cases and expense states are installed directly
-- to exercise authorization without publishing content or running any payment.
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
select ('b7000000-0000-4000-8000-00000000000'||n)::uuid,'need-feedback-'||n||'@example.test',now(),
  '{"display_name":"Nombre privado del equipo","is_admin":true}'::jsonb from generate_series(1,4)n;
insert into private.admin_memberships(user_id) values
  ('b7000000-0000-4000-8000-000000000002'),('b7000000-0000-4000-8000-000000000003');
insert into dopmi_rescue_records(id,owner_id,kind,status,version,public_data,video_thanks_required) values
  ('b7100000-0000-4000-8000-000000000001','b7000000-0000-4000-8000-000000000001','case','submitted',4,
    '{"pet_name":"Caso sintético","need_items":[{"id":"b7200000-0000-4000-8000-000000000001","type":"veterinary","title":"Consulta prevista","amount_cents":30000,"detail":"","urgent":false}]}',false),
  ('b7100000-0000-4000-8000-000000000002','b7000000-0000-4000-8000-000000000001','case','draft',1,'{"pet_name":"CASO PRIVADO"}',false),
  ('b7100000-0000-4000-8000-000000000003','b7000000-0000-4000-8000-000000000001','case','pending_stripe',1,'{"pet_name":"PENDING PRIVADO"}',false);
insert into dopmi_rescue_records(id,owner_id,kind,parent_id,status,version,public_data,private_data) values
  ('b7300000-0000-4000-8000-000000000001','b7000000-0000-4000-8000-000000000001','expense','b7100000-0000-4000-8000-000000000001','submitted',2,
    '{"title":"Consulta pagada"}','{"vendor":"Proveedor sintético","amount_cents":"30000"}'),
  ('b7300000-0000-4000-8000-000000000002','b7000000-0000-4000-8000-000000000001','expense','b7100000-0000-4000-8000-000000000001','draft',2,
    '{"title":"GASTO PRIVADO"}','{"vendor":"PRIVADO"}'),
  ('b7300000-0000-4000-8000-000000000003','b7000000-0000-4000-8000-000000000004','expense','b7100000-0000-4000-8000-000000000001','submitted',2,
    '{"title":"OTRO PROPIETARIO"}','{}');
select set_config('dopmi.test.need_comments',
  '[{"target_kind":"planned","target_id":"b7200000-0000-4000-8000-000000000001","target_version":4,"body":"Aclara el tratamiento"},
    {"target_kind":"expense","target_id":"b7300000-0000-4000-8000-000000000001","target_version":2,"body":"Adjunta el desglose"}]',true);
create temporary table need_feedback_baseline as
select (select jsonb_agg(to_jsonb(r) order by r.id) from dopmi_rescue_records r) records,
  (select jsonb_agg(to_jsonb(d) order by d.id) from dopmi_donations d) donations,
  (select to_jsonb(e) from private.dopmi_payment_environment e) environment;
create temporary table need_feedback_response(result jsonb);
grant select,insert on need_feedback_response to authenticated;

select ok(not has_function_privilege('anon','public.dopmi_admin_rescue_packet(uuid,integer)','execute'),'packet denies anon');
select ok(not has_function_privilege('service_role','public.dopmi_admin_rescue_packet(uuid,integer)','execute'),'packet denies service role');
select ok(not has_function_privilege('anon','public.dopmi_comment_case_needs(uuid,integer,jsonb,uuid)','execute'),'comment denies anon');
select ok(not has_function_privilege('service_role','public.dopmi_comment_case_needs(uuid,integer,jsonb,uuid)','execute'),'comment denies service role');
select ok(not has_function_privilege('authenticated','private.dopmi_need_comment_dto(uuid,uuid,integer,timestamptz,jsonb)','execute'),'DTO helper remains private');
select ok(not has_table_privilege('authenticated','private.dopmi_rescue_history','select'),'history table remains private');

set local role authenticated;
select set_config('request.jwt.claim.sub','b7000000-0000-4000-8000-000000000004',true);
select throws_ok($$select dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')$$,'42501',null,'editable admin metadata grants no packet access');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000001')$$,'42501',null,'editable metadata grants no comment privilege');
select set_config('request.jwt.claim.sub','b7000000-0000-4000-8000-000000000001',true);
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000001')$$,'42501',null,'owner cannot comment as staff');
reset role;
insert into private.admin_memberships(user_id) values('b7000000-0000-4000-8000-000000000001');
set local role authenticated;
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000001')$$,'42501',null,'real staff cannot review their own case');

select set_config('request.jwt.claim.sub','b7000000-0000-4000-8000-000000000002',true);
select throws_ok($$select dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000002')$$,'42501',null,'packet hides draft parent');
select throws_ok($$select dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000003')$$,'42501',null,'packet hides pending Stripe parent');
select throws_ok($$select dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001',0)$$,'22023',null,'packet rejects invalid page');
select throws_ok($$select dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001',1001)$$,'22023',null,'packet bounds page');
select is((dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')->'expenses'->>'total')::integer,1,'total excludes draft and mixed-owner expenses');
select is(dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')->'expenses'->'items'->0->>'id','b7300000-0000-4000-8000-000000000001','packet returns the accessible child');
select is(dopmi_admin_rescue_packet('b7300000-0000-4000-8000-000000000001')->'expenses','{"total":0,"page":1,"items":[]}'::jsonb,'non-case retains legacy and empty expenses');
select is(dopmi_admin_rescue_packet('b7300000-0000-4000-8000-000000000001')->'need_comments','[]'::jsonb,'non-case has no need comments');
reset role;
select ok(exists(select 1 from private.dopmi_rescue_history where record_id='b7300000-0000-4000-8000-000000000001' and action='read'),'visible child read is audited');
select is((select count(*) from private.dopmi_rescue_history where record_id in ('b7300000-0000-4000-8000-000000000002','b7300000-0000-4000-8000-000000000003')),0::bigint,'hidden children are not read/audited');

set local role authenticated;
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',3,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000002')$$,'40001',null,'stale case rejected');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,jsonb_set(current_setting('dopmi.test.need_comments')::jsonb,'{1,target_version}','1'),'b7400000-0000-4000-8000-000000000002')$$,'40001',null,'stale second child rejects whole batch');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,jsonb_set(current_setting('dopmi.test.need_comments')::jsonb,'{1,target_id}','"b7300000-0000-4000-8000-000000000002"'),'b7400000-0000-4000-8000-000000000002')$$,'40001',null,'draft second child rejects whole batch');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,jsonb_set(current_setting('dopmi.test.need_comments')::jsonb,'{1,target_id}','"b7300000-0000-4000-8000-000000000003"'),'b7400000-0000-4000-8000-000000000002')$$,'40001',null,'mixed owner second child rejects whole batch');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,'[]','b7400000-0000-4000-8000-000000000002')$$,'22023',null,'empty batch rejected');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,jsonb_set(current_setting('dopmi.test.need_comments')::jsonb,'{0,body}','" "'),'b7400000-0000-4000-8000-000000000002')$$,'22023',null,'empty trimmed body rejected');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,jsonb_build_array((current_setting('dopmi.test.need_comments')::jsonb)->0,(current_setting('dopmi.test.need_comments')::jsonb)->0),'b7400000-0000-4000-8000-000000000002')$$,'22023',null,'duplicate targets rejected');
reset role;
select is((select count(*) from private.dopmi_rescue_history where action='need_comments' and record_id='b7100000-0000-4000-8000-000000000001'),0::bigint,'invalid batches leave no event');

set local role authenticated;
insert into need_feedback_response select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000001');
select is((select result->>'case_version' from need_feedback_response),'4','comment pins reviewed case version');
select is((select jsonb_array_length(result->'comments') from need_feedback_response),2,'one response contains both targets');
select is((select result->'comments'->0->>'id' from need_feedback_response),'b7400000-0000-4000-8000-000000000001:expense:b7300000-0000-4000-8000-000000000001','comment identity includes event, kind and target');
select is(dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000001'),(select result from need_feedback_response),'identical replay returns original response');
select is(dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,jsonb_build_array((current_setting('dopmi.test.need_comments')::jsonb)->1,jsonb_set((current_setting('dopmi.test.need_comments')::jsonb)->0,'{body}','"  Aclara el tratamiento  "')),'b7400000-0000-4000-8000-000000000001'),(select result from need_feedback_response),'reordered trimmed intent is idempotent');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,jsonb_set(current_setting('dopmi.test.need_comments')::jsonb,'{0,body}','"Otro mensaje"'),'b7400000-0000-4000-8000-000000000001')$$,'22023',null,'request collision cannot replace payload');
select set_config('request.jwt.claim.sub','b7000000-0000-4000-8000-000000000003',true);
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000001')$$,'22023',null,'request collision cannot replace actor');
select set_config('request.jwt.claim.sub','b7000000-0000-4000-8000-000000000002',true);
select is(jsonb_array_length(dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')->'need_comments'),2,'packet flattens comments');
select ok((dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')->'need_comments')::text not like '%snapshot%','comment DTO omits snapshots');
select ok((dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')->'need_comments')::text not like '%Nombre privado%','comment DTO omits staff PII');
reset role;
select is((select count(*) from private.dopmi_rescue_history where id='b7400000-0000-4000-8000-000000000001'),1::bigint,'replay writes one history event');
select ok((select actor_type='user' and source='user' and actor_id='b7000000-0000-4000-8000-000000000002' from private.dopmi_rescue_history where id='b7400000-0000-4000-8000-000000000001'),'event records real reviewer under existing constraints');
select ok((select feedback like '%Consulta prevista:%Aclara el tratamiento%' and feedback like '%Consulta pagada:%Adjunta el desglose%' from private.dopmi_rescue_history where id='b7400000-0000-4000-8000-000000000001'),'legacy history feedback supplies target context');
select is((select jsonb_agg(to_jsonb(r) order by r.id) from dopmi_rescue_records r),(select records from need_feedback_baseline),'comments change no status, version, fields, files, approval or amounts');
select is((select jsonb_agg(to_jsonb(d) order by d.id) from dopmi_donations d),(select donations from need_feedback_baseline),'comments change no donations');
select is((select to_jsonb(e) from private.dopmi_payment_environment e),(select environment from need_feedback_baseline),'comments do not change financial flags');

-- Current access is mandatory even for an existing replay.
update private.admin_memberships set active=false where user_id='b7000000-0000-4000-8000-000000000002';
set local role authenticated;
select throws_ok($$select dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')$$,'42501',null,'revoked staff cannot read packet');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000001')$$,'42501',null,'revoked staff cannot replay');
reset role;
update private.admin_memberships set active=true where user_id='b7000000-0000-4000-8000-000000000002';
update dopmi_rescue_records set status='changes_requested',version=5 where id='b7100000-0000-4000-8000-000000000001';
set local role authenticated;
select is(dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000001'),(select result from need_feedback_response),'replay reconciles after later review without another write');
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',5,jsonb_set(current_setting('dopmi.test.need_comments')::jsonb,'{0,target_version}','5'),'b7400000-0000-4000-8000-000000000002')$$,'22023',null,'new comments require submitted case');
reset role;
update dopmi_rescue_records set status='submitted',public_data=jsonb_set(public_data,'{need_items,0,title}','"Nueva consulta"') where id='b7100000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',5,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000002')$$,'40001',null,'reused planned ID still requires current source version');
select is(dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')->'need_comments'->0->>'case_version','4','historical comment retains its reviewed version');
reset role;
update dopmi_rescue_records set status='draft',public_data='{"title":"NUEVO BORRADOR"}' where id='b7300000-0000-4000-8000-000000000001';
set local role authenticated;
select is(jsonb_array_length(dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')->'need_comments'),1,'withdrawn expense is hidden from structured comments');
select ok(dopmi_admin_rescue_packet('b7100000-0000-4000-8000-000000000001')::text not like '%NUEVO BORRADOR%','new draft content is never exposed');
reset role;
update dopmi_rescue_records set status='draft' where id='b7100000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select dopmi_comment_case_needs('b7100000-0000-4000-8000-000000000001',4,current_setting('dopmi.test.need_comments')::jsonb,'b7400000-0000-4000-8000-000000000001')$$,'42501',null,'withdrawn case denies stored replay');

select * from finish();
rollback;
