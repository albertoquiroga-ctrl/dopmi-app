begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
select id,id::text||'@example.test',now(),'{"display_name":"Caso local","terms_accepted":true,"terms_version":"development-2026-09-13"}'::jsonb
from unnest(array['b9000000-0000-4000-8000-000000000001'::uuid,'b9000000-0000-4000-8000-000000000002'::uuid]) id;
insert into auth.sessions(id,user_id) values
 ('b9900000-0000-4000-8000-000000000001','b9000000-0000-4000-8000-000000000001'),
 ('b9900000-0000-4000-8000-000000000002','b9000000-0000-4000-8000-000000000002');
insert into private.admin_memberships(user_id) values('b9000000-0000-4000-8000-000000000002');
insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
 values('b9000000-0000-4000-8000-000000000001','acct_fixed_case_pgtap',true,true);
insert into dopmi_rescue_records(id,owner_id,kind,public_data,files,video_thanks_required)
 values('b9100000-0000-4000-8000-000000000001','b9000000-0000-4000-8000-000000000001','case',
 '{"pet_name":"Caso local","species":"dog","sex":"female","age":"2 años","story":"Historia publicada original","city":"Monterrey","state":"Nuevo León"}',
 '[{"role":"public","path":"b9000000-0000-4000-8000-000000000001/b9100000-0000-4000-8000-000000000001/b9800000-0000-4000-8000-000000000001.jpg"}]',false);
insert into dopmi_rescue_records(id,owner_id,kind,parent_id,public_data,private_data,files)
 values('b9200000-0000-4000-8000-000000000001','b9000000-0000-4000-8000-000000000001','expense','b9100000-0000-4000-8000-000000000001',
 '{"title":"Consulta pagada","description":"Consulta pagada sintética","category":"veterinary"}',
 '{"paid_on":"2026-09-01","vendor":"Proveedor local","amount_cents":"10000","receipt_reference":"FIXED-UNIT-1"}',
 '[{"role":"receipt","path":"b9000000-0000-4000-8000-000000000001/b9200000-0000-4000-8000-000000000001/b9800000-0000-4000-8000-000000000002.pdf"},
 {"role":"proof","path":"b9000000-0000-4000-8000-000000000001/b9200000-0000-4000-8000-000000000001/b9800000-0000-4000-8000-000000000003.jpg"}]');
insert into storage.objects(bucket_id,name) select 'dopmi-rescue-evidence',f->>'path' from dopmi_rescue_records r,
 lateral jsonb_array_elements(r.files) f where r.owner_id='b9000000-0000-4000-8000-000000000001';
create temporary table fixed_revision_packet(packet jsonb);
grant select,insert,update on fixed_revision_packet to authenticated;
select ok(not has_table_privilege('authenticated','private.dopmi_case_revisions','select'),'private proposals have no direct client read');
select ok(not has_function_privilege('service_role','public.dopmi_review_case_revision(uuid,integer,text,text,boolean,jsonb,uuid)','execute'),'service role cannot review case revisions');
select ok(has_function_privilege('service_role','public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean)','execute'),'SQL61 legacy service ACL is preserved');
set local role authenticated;
select set_config('request.jwt.claim.sub','b9000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.session_id','b9900000-0000-4000-8000-000000000001',true);
select is(dopmi_transition_rescue('b9100000-0000-4000-8000-000000000001',1,'submit')->>'status','submitted','owner sends whole initial case');
select is((dopmi_rescue_detail('b9200000-0000-4000-8000-000000000001')->'case_unit'->>'needs_editable')::boolean,false,'captured draft cannot be edited');
select set_config('request.jwt.claim.sub','b9000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claim.session_id','b9900000-0000-4000-8000-000000000002',true);
select is(dopmi_review_initial_case_packet('b9100000-0000-4000-8000-000000000001',2,
 (dopmi_admin_rescue_packet('b9100000-0000-4000-8000-000000000001')->'initial_packet'->>'id')::uuid,'approved','Expediente completo revisado',true,
 '[{"expense_id":"b9200000-0000-4000-8000-000000000001","expense_version":1,"amount_cents":10000,"is_urgent":false,"urgency_note":"","publish_content":true}]',
 'b9400000-0000-4000-8000-000000000001')->'record'->>'status','approved','one decision publishes all initial needs');
select set_config('request.jwt.claim.sub','b9000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.session_id','b9900000-0000-4000-8000-000000000001',true);
select throws_ok($$select dopmi_save_rescue('expense','{}','{}','[]',null,null,'b9100000-0000-4000-8000-000000000001')$$,'22023',null,'published case cannot acquire new needs');
insert into fixed_revision_packet select dopmi_start_case_revision('b9100000-0000-4000-8000-000000000001',3,'b9400000-0000-4000-8000-000000000002');
select is((select packet->'revision'->>'status' from fixed_revision_packet),'draft','edit starts privately');
update fixed_revision_packet set packet=dopmi_save_case_revision((packet->'revision'->>'id')::uuid,1,'Corrijo la historia del rescate',
 jsonb_build_object('public_data',packet->'record'->'public_data'||'{"story":"Historia nueva propuesta"}'::jsonb,'private_data',packet->'record'->'private_data','files',packet->'record'->'files'),
 (select jsonb_agg(jsonb_build_object('id',e->'id','public_data',e->'public_data','private_data',e->'private_data','files',e->'files')) from jsonb_array_elements(packet->'expenses'->'items') e),
 'b9400000-0000-4000-8000-000000000003');
select is(dopmi_rescue_public('b9100000-0000-4000-8000-000000000001')->'items'->0->'public_data'->>'story','Historia publicada original','saving edit preserves old public story');
update fixed_revision_packet set packet=dopmi_transition_case_revision((packet->'revision'->>'id')::uuid,2,'submit','b9400000-0000-4000-8000-000000000004');
select is(dopmi_rescue_public('b9100000-0000-4000-8000-000000000001')->'items'->0->'public_data'->>'story','Historia publicada original','review keeps old public story');
select throws_ok($$select dopmi_save_case_revision((select (packet->'revision'->>'id')::uuid from fixed_revision_packet),3,'Cambio fuera de revisión','{}','[]',gen_random_uuid())$$,'40001',null,'submitted edit is frozen before payload processing');
select set_config('request.jwt.claim.sub','b9000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claim.session_id','b9900000-0000-4000-8000-000000000002',true);
select is(dopmi_admin_rescue('case','submitted')->'items'->0->>'review_kind','revision','revision appears in the existing case queue');
update fixed_revision_packet set packet=dopmi_review_case_revision((packet->'revision'->>'id')::uuid,3,'approved','Edición completa aprobada',true,
 '[{"expense_id":"b9200000-0000-4000-8000-000000000001","expense_version":3,"amount_cents":10000,"is_urgent":false,"urgency_note":"","publish_content":true}]',
 'b9400000-0000-4000-8000-000000000005');
select is((select packet->'revision'->>'status' from fixed_revision_packet),'approved','one decision approves the entire edit');
select is((select (packet->'record'->>'version')::integer from fixed_revision_packet),4,'receipt identifies the effective published version');
select is(dopmi_rescue_public('b9100000-0000-4000-8000-000000000001')->'items'->0->'public_data'->>'story','Historia nueva propuesta','only approved edit replaces public story');
reset role;
select is((select count(*) from private.dopmi_rescue_history where record_id='b9100000-0000-4000-8000-000000000001' and action='case_revision_approved'),1::bigint,'one decision creates one case audit');
select is((select reimbursable_cents from dopmi_rescue_records where id='b9200000-0000-4000-8000-000000000001'),10000::bigint,'text edit preserves financial authorization');
select * from finish();
rollback;
