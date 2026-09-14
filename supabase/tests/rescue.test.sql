begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
delete from private.dopmi_rescue_history;
delete from public.dopmi_rescue_records;
select set_config('storage.allow_delete_query','true',true);
delete from storage.objects where bucket_id='dopmi-rescue-evidence';
delete from auth.users where id::text like '60000000-0000-4000-8000-00000000000%';
select no_plan();
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at)
select ('60000000-0000-4000-8000-00000000000'||n)::uuid,'rescue-'||n||'@example.test',
  '{"display_name":"Privado","terms_version":"development-2026-09-13","terms_accepted":true}',now() from generate_series(1,4)n;
insert into private.admin_memberships(user_id) values('60000000-0000-4000-8000-000000000004');
insert into dopmi_rescue_records(id,owner_id,kind,public_data,private_data) values
 ('61000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','verification',
 '{"public_name":"Refugio Uno","bio":"Ayudamos animales","city":"Monterrey","state":"Nuevo León"}',
 '{"legal_name":"Nombre legal privado","phone":"8188888888","experience":"Tres años de rescate","social_url":"https://instagram.com/refugio","identity_type":"ine"}'),
 ('61000000-0000-4000-8000-000000000002','60000000-0000-4000-8000-000000000001','case',
 '{"pet_name":"Luna","species":"dog","sex":"female","age":"2 meses","story":"Rescatada con lesión","city":"Monterrey","state":"Nuevo León","need":"Atención veterinaria"}','{}');
insert into dopmi_rescue_records(id,owner_id,kind,parent_id,public_data,private_data) values
 ('61000000-0000-4000-8000-000000000003','60000000-0000-4000-8000-000000000001','expense','61000000-0000-4000-8000-000000000002',
 '{"title":"Comida primera ronda","description":"Alimento comprado para Luna","category":"food","round_label":"Septiembre ronda 1"}',
 '{"paid_on":"2026-09-01","vendor":"Veterinaria","amount_cents":"25050","receipt_reference":"F-123","urgency_reason":"Atención urgente"}');
update dopmi_rescue_records r set files=case kind
  when 'verification' then jsonb_build_array(jsonb_build_object('role','identity','path',owner_id||'/'||id||'/62000000-0000-4000-8000-000000000001.jpg'),jsonb_build_object('role','address','path',owner_id||'/'||id||'/62000000-0000-4000-8000-000000000002.pdf'))
  when 'case' then jsonb_build_array(jsonb_build_object('role','public','path',owner_id||'/'||id||'/62000000-0000-4000-8000-000000000003.jpg'))
  else jsonb_build_array(jsonb_build_object('role','receipt','path',owner_id||'/'||id||'/62000000-0000-4000-8000-000000000004.pdf'),jsonb_build_object('role','proof','path',owner_id||'/'||id||'/62000000-0000-4000-8000-000000000005.jpg')) end
  where owner_id='60000000-0000-4000-8000-000000000001';

set local role anon;
select set_config('request.jwt.claim.sub','',true);
select throws_ok('select * from dopmi_rescue_records','42501',null,'anonymous cannot read private records');
select is((dopmi_rescue_public()->>'total')::int,0,'drafts never appear publicly');
select is(dopmi_rescue_file_access('60000000-0000-4000-8000-000000000001/61000000-0000-4000-8000-000000000001/62000000-0000-4000-8000-000000000001.jpg'),false,'identity file is private');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000002',true);
select is((select count(*) from dopmi_rescue_records),0::bigint,'another user cannot read drafts');
select throws_ok($$select dopmi_rescue_detail('61000000-0000-4000-8000-000000000001')$$,'42501',null,'another user cannot query private detail');
select throws_ok($$select dopmi_transition_rescue('61000000-0000-4000-8000-000000000001',1,'submit')$$,'42501',null,'another user cannot submit');
select throws_ok($$select dopmi_review_rescue('61000000-0000-4000-8000-000000000001',1,'approved','Aprobada',0,false,'',true)$$,'42501',null,'non-admin cannot approve');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
select throws_ok($$update dopmi_rescue_records set status='approved',reimbursable_cents=99999$$,'42501',null,'direct state and money updates blocked');
select throws_ok($$select dopmi_save_rescue('case','{"is_admin":"true"}','{}','[]','61000000-0000-4000-8000-000000000002',1)$$,'22023',null,'unknown client fields rejected');
select throws_ok($$select dopmi_save_rescue('case','{}','{}','[{"path":"forged/path.jpg","role":"public"}]','61000000-0000-4000-8000-000000000002',1)$$,'22023',null,'foreign attachment paths rejected');
select throws_ok($$select dopmi_transition_rescue('61000000-0000-4000-8000-000000000002',1,'submit')$$,'22023',null,'verification required to submit a case');
select throws_ok($$select dopmi_transition_rescue('61000000-0000-4000-8000-000000000001',1,'submit')$$,'22023',null,'missing Storage object blocks submission');
reset role;
insert into storage.objects(bucket_id,name) select 'dopmi-rescue-evidence',f->>'path' from dopmi_rescue_records r,jsonb_array_elements(r.files) f
  where owner_id='60000000-0000-4000-8000-000000000001';
set local role authenticated;
select is(dopmi_transition_rescue('61000000-0000-4000-8000-000000000001',1,'submit')->>'status','submitted','complete verification submitted');
select is(dopmi_rescue_file_access('60000000-0000-4000-8000-000000000001/61000000-0000-4000-8000-000000000001/62000000-0000-4000-8000-000000000001.jpg',true),false,'submission locks file mutations');
select throws_ok($$select dopmi_save_rescue('verification','{}','{}','[]','61000000-0000-4000-8000-000000000001',2)$$,'22023',null,'submitted data cannot change behind reviewer');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select is((select count(*) from dopmi_rescue_records),0::bigint,'admin raw access denied; audited detail required');
select is((dopmi_admin_rescue('verification')->>'total')::int,1,'admin queue includes submitted verification');
select throws_ok($$select dopmi_rescue_detail('61000000-0000-4000-8000-000000000002')$$,'42501',null,'admin cannot inspect never-submitted draft');
select is(dopmi_rescue_detail('61000000-0000-4000-8000-000000000001')->'record'->'private_data'->>'legal_name','Nombre legal privado','admin can inspect submitted identity');
select throws_ok($$select dopmi_review_rescue('61000000-0000-4000-8000-000000000001',1,'approved','Comprobada',0,false,'',true)$$,'40001',null,'stale admin version rejected');
select throws_ok($$select dopmi_review_rescue('61000000-0000-4000-8000-000000000001',2,'approved','Comprobada')$$,'22023',null,'public content requires explicit approval');
select is(dopmi_review_rescue('61000000-0000-4000-8000-000000000001',2,'changes_requested','Aclara tu experiencia')->'private_data'->>'legal_name','Nombre legal privado','corrections conserve private data');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
select is((select count(*) from dopmi_notifications where kind='rescue'),1::bigint,'owner receives persistent review notification');
select is(dopmi_transition_rescue('61000000-0000-4000-8000-000000000001',3,'submit')->>'status','submitted','correction resubmitted with existing evidence');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select is(dopmi_review_rescue('61000000-0000-4000-8000-000000000001',4,'approved','Identidad comprobada',0,false,'',true)->>'status','approved','admin verifies identity');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
select throws_ok($$select dopmi_save_rescue('verification','{}','{}','[]','61000000-0000-4000-8000-000000000001',5)$$,'22023',null,'approved identity immutable to owner');
select is(dopmi_transition_rescue('61000000-0000-4000-8000-000000000002',1,'submit')->>'status','submitted','verified rescuer submits case');
select throws_ok($$select dopmi_transition_rescue('61000000-0000-4000-8000-000000000003',1,'submit')$$,'22023',null,'expense requires approved case');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select is(dopmi_review_rescue('61000000-0000-4000-8000-000000000002',2,'approved','Caso comprobado',0,false,'',true)->>'status','approved','case approved separately');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
select is(dopmi_transition_rescue('61000000-0000-4000-8000-000000000003',1,'submit')->>'status','submitted','paid food expense submitted');
select throws_ok($$select dopmi_transition_rescue('61000000-0000-4000-8000-000000000002',3,'close')$$,'22023',null,'pending expense blocks case closure');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select throws_ok($$select dopmi_review_rescue('61000000-0000-4000-8000-000000000003',2,'approved','Gasto comprobado',25051,false,'',true)$$,'22023',null,'cannot approve beyond paid amount');
select throws_ok($$select dopmi_review_rescue('61000000-0000-4000-8000-000000000003',2,'approved','Gasto comprobado',25050,true,'',true)$$,'22023',null,'urgency requires reason');
select is((dopmi_review_rescue('61000000-0000-4000-8000-000000000003',2,'approved','Gasto comprobado',24000,true,'Continuidad del cuidado',true)->>'reimbursable_cents')::bigint,24000::bigint,'server sets reimbursable cents');
select throws_ok($$select dopmi_review_rescue('61000000-0000-4000-8000-000000000003',2,'approved','Gasto comprobado',24000,true,'Continuidad del cuidado',true)$$,'40001',null,'duplicate review cannot generate another approval');
reset role;
select ok(exists(select 1 from private.dopmi_rescue_history where action='read'),'private reads audited');
select ok(exists(select 1 from dopmi_rescue_records where kind='expense' and urgent and approved_at is not null),'priority and approval timestamp recorded');
-- A second round starts from a fresh draft and must supply its own proof.
insert into dopmi_rescue_records(id,owner_id,kind,parent_id,public_data,private_data,files)
select '61000000-0000-4000-8000-000000000004',owner_id,kind,parent_id,public_data||'{"round_label":"Ronda 2"}',private_data,'[]'
from dopmi_rescue_records where id='61000000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
select throws_ok($$select dopmi_transition_rescue('61000000-0000-4000-8000-000000000004',1,'submit')$$,'22023',null,'same receipt cannot fund another food round');
reset role;
update dopmi_rescue_records set private_data=private_data||'{"receipt_reference":"F-124"}' where id='61000000-0000-4000-8000-000000000004';
set local role authenticated;
select throws_ok($$select dopmi_transition_rescue('61000000-0000-4000-8000-000000000004',1,'submit')$$,'22023',null,'new food round still requires new evidence');
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is((dopmi_rescue_public()->>'total')::int,1,'only approved case in public catalog');
select is((dopmi_rescue_public('61000000-0000-4000-8000-000000000002')->>'total')::int,2,'case detail includes approved expense');
select ok(dopmi_rescue_public('61000000-0000-4000-8000-000000000002')::text !~ 'Nombre legal|8188888888|F-123|receipt_reference|private_data|62000000-0000-4000-8000-000000000004','public response omits PII and receipts');
select is(dopmi_rescue_file_access('60000000-0000-4000-8000-000000000001/61000000-0000-4000-8000-000000000002/62000000-0000-4000-8000-000000000003.jpg'),true,'approved case photo publicly readable');
select is(dopmi_rescue_file_access('60000000-0000-4000-8000-000000000001/61000000-0000-4000-8000-000000000003/62000000-0000-4000-8000-000000000004.pdf'),false,'approved expense receipt remains private');
select is((select count(*) from storage.objects where bucket_id='dopmi-rescue-evidence'),1::bigint,'Storage RLS exposes only approved public photo');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
select is(dopmi_transition_rescue('61000000-0000-4000-8000-000000000002',3,'close')->>'status','closed','case can close after review resolved');
select throws_ok($$select dopmi_save_rescue('expense','{}','{}','[]',null,null,'61000000-0000-4000-8000-000000000002')$$,'22023',null,'closed case rejects new expense');
select throws_ok($$select dopmi_transition_rescue('61000000-0000-4000-8000-000000000004',1,'submit')$$,'22023',null,'existing draft cannot submit after closure');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select is(dopmi_review_rescue('61000000-0000-4000-8000-000000000001',5,'changes_requested','Revisar documento vigente')->>'status','changes_requested','admin can revoke verification for corrections');
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is((dopmi_rescue_public()->>'total')::int,0,'revoked identity hides public case');
select is(dopmi_rescue_file_access('60000000-0000-4000-8000-000000000001/61000000-0000-4000-8000-000000000002/62000000-0000-4000-8000-000000000003.jpg'),false,'revocation removes fresh public file access');
reset role;
select * from finish();
rollback;
