begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id,email,phone,email_confirmed_at,phone_confirmed_at,raw_user_meta_data) values
 ('65000000-0000-4000-8000-000000000001','seal-person@example.test','528100010101',now(),null,
  '{"display_name":"Prueba","verified_phone":true,"terms_version":"development-2026-09-13","terms_accepted":true}'),
 ('65000000-0000-4000-8000-000000000002','seal-reviewer@example.test',null,now(),null,
  '{"display_name":"Revisión","terms_version":"development-2026-09-13","terms_accepted":true}'),
 ('65000000-0000-4000-8000-000000000003','seal-old@example.test','528100010103',now(),now(),
  '{"display_name":"Anterior","terms_version":"development-2026-09-13","terms_accepted":true}');
insert into private.admin_memberships(user_id) values
 ('65000000-0000-4000-8000-000000000001'),('65000000-0000-4000-8000-000000000002');

set local role anon;
select throws_ok('select dopmi_rescuer_seal_status()','42501',null,'anonymous cannot see the seal checklist');
select throws_ok('select dopmi_submit_rescuer_seal()','42501',null,'anonymous cannot request a seal');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','65000000-0000-4000-8000-000000000001',true);
select is(dopmi_rescuer_seal_status()->>'status','not_started','no existing record');
select is(dopmi_rescuer_seal_status()->'missing','["name","photo","phone","social"]'::jsonb,'requires profile and actual Auth phone confirmation');
select is(dopmi_submit_rescuer_seal()->>'record_id',null,'checklist not met creates no request');
reset role;

insert into public.dopmi_rescuer_profiles(owner_id,display_name,avatar_path,instagram_url,facebook_url,public_phone,public_email,contact_consent) values
 ('65000000-0000-4000-8000-000000000001','Refugio Prueba',
  '65000000-0000-4000-8000-000000000003/65000000-0000-4000-8000-000000000003/65000000-0000-4000-8000-000000000004.jpg',
  'https://instagram.com.ejemplo.test/falso','', '+528100010101','public-example@example.test',false),
 ('65000000-0000-4000-8000-000000000003','Refugio Anterior',
  '65000000-0000-4000-8000-000000000003/65000000-0000-4000-8000-000000000003/65000000-0000-4000-8000-000000000004.jpg',
  '','https://www.facebook.com/refugio.test','', '',false);
insert into storage.objects(bucket_id,name) select 'dopmi-rescuer-profile-media',avatar_path from public.dopmi_rescuer_profiles
 where owner_id='65000000-0000-4000-8000-000000000003';
set local role authenticated;
select is(dopmi_rescuer_seal_status()->'missing','["photo","phone","social"]'::jsonb,'foreign photo, unconfirmed phone and deceptive link do not pass');
reset role;
update public.dopmi_rescuer_profiles set
  avatar_path='65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000004.jpg',
  instagram_url='https://www.instagram.com/refugio.test'
where owner_id='65000000-0000-4000-8000-000000000001';
insert into storage.objects(bucket_id,name) select 'dopmi-rescuer-profile-media',avatar_path from public.dopmi_rescuer_profiles
 where owner_id='65000000-0000-4000-8000-000000000001';
set local role authenticated;
select is(dopmi_rescuer_seal_status()->'missing','["phone"]'::jsonb,'private or public profile phone cannot substitute SMS confirmation');
reset role;
update auth.users set phone_confirmed_at=now() where id='65000000-0000-4000-8000-000000000001';

set local role authenticated;
select is(dopmi_rescuer_seal_status()->'missing','[]'::jsonb,'only the five profile items are required');
select set_config('test.seal_submission',dopmi_submit_rescuer_seal()::text,true);
select is(current_setting('test.seal_submission')::jsonb->>'status','submitted','complete profile goes to manual review');
select is(dopmi_submit_rescuer_seal(),current_setting('test.seal_submission')::jsonb,'repeat uses the same pending request');
select set_config('test.seal_id',current_setting('test.seal_submission')::jsonb->>'record_id',true);
select is(dopmi_rescuer_seal_status()->>'verification_method','profile','new path is identifiable without sharing private fields');
select is(dopmi_rescuer_dashboard()->>'verification_status','submitted','existing dashboard sees the new request');
select is((select version from dopmi_rescue_records where id=current_setting('test.seal_id')::uuid),2,'only one submission transition was saved');
select is(dopmi_rescuer_profile_file_access(
  '65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000004.jpg',true),
  false,'the exact photo remains immutable while staff reviews it');
select throws_ok($$select dopmi_review_rescuer_seal(current_setting('test.seal_id')::uuid,2,'approved','Aprobado',true)$$,
 '42501','Otra persona del equipo debe revisar tu solicitud','a reviewer cannot approve their own seal');
select set_config('request.jwt.claim.sub','65000000-0000-4000-8000-000000000003',true);
select throws_ok($$select dopmi_review_rescuer_seal(current_setting('test.seal_id')::uuid,2,'approved','Aprobado',true)$$,
 '42501','Acceso administrativo requerido','a regular account cannot approve anyone else');

reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is(dopmi_rescuer_public('65000000-0000-4000-8000-000000000001'),null,'no public badge before approval');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','65000000-0000-4000-8000-000000000002',true);
select is(dopmi_rescue_detail(current_setting('test.seal_id')::uuid)->'record'->'public_data',
 '{"public_name":"Refugio Prueba"}'::jsonb,'only the declared name is public data');
select is(dopmi_rescue_detail(current_setting('test.seal_id')::uuid)->'record'->'private_data'->>'email',
 'seal-person@example.test','staff review uses confirmed Auth email');
select is(dopmi_rescue_detail(current_setting('test.seal_id')::uuid)->'record'->'files','[]'::jsonb,'staff do not see ID or address requirements on a new seal');
select ok(dopmi_rescuer_profile_file_access(
  '65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000004.jpg'), 'staff can open the exact photo');
select throws_ok($$select dopmi_review_rescuer_seal(current_setting('test.seal_id')::uuid,2,'approved','Reviewed',false)$$,
 '22023',null,'approval requires affirmative review');
select throws_ok($$select dopmi_review_rescue(current_setting('test.seal_id')::uuid,2,'approved','Reviewed',0,false,'',true)$$,
 '22023',null,'older client cannot bypass the profile review acknowledgement');
reset role;
update auth.users set phone='528100010199',phone_confirmed_at=now()
 where id='65000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select dopmi_review_rescuer_seal(current_setting('test.seal_id')::uuid,2,'approved','Reviewed',true)$$,
 '22023',null,'current verified phone must match the reviewed snapshot');
select is(dopmi_review_rescuer_seal(current_setting('test.seal_id')::uuid,2,'changes_requested','Actualiza el contacto',false)->>'status',
 'changes_requested','a reviewer can return stale evidence');
select set_config('request.jwt.claim.sub','65000000-0000-4000-8000-000000000001',true);
select throws_ok($$select dopmi_transition_rescue(current_setting('test.seal_id')::uuid,3,'submit')$$,
 '22023',null,'legacy transition cannot resubmit stale profile data');
select throws_ok($$select dopmi_save_rescue('verification','{}','{}','[]',current_setting('test.seal_id')::uuid,3)$$,
 '22023',null,'legacy editor cannot remove the trusted method');
select is(dopmi_submit_rescuer_seal()->>'status','submitted','new endpoint refreshes the private snapshot');
reset role;
select set_config('storage.allow_delete_query','true',true);
delete from storage.objects where bucket_id='dopmi-rescuer-profile-media' and name=
  '65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000004.jpg';
set local role authenticated;
select set_config('request.jwt.claim.sub','65000000-0000-4000-8000-000000000002',true);
select throws_ok($$select dopmi_review_rescuer_seal(current_setting('test.seal_id')::uuid,4,'approved','Reviewed',true)$$,
 '22023',null,'staff cannot approve a missing profile photo even after acknowledgement');
reset role;
insert into storage.objects(bucket_id,name) values('dopmi-rescuer-profile-media',
  '65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000001/65000000-0000-4000-8000-000000000004.jpg');
set local role authenticated;
select is(dopmi_review_rescuer_seal(current_setting('test.seal_id')::uuid,4,'approved','Perfil comprobado',true)->>'status',
 'approved','a different admin can manually approve without ID or address');
reset role;
select ok(exists(select 1 from private.dopmi_rescue_history
  where record_id=current_setting('test.seal_id')::uuid and action='approved' and actor_id='65000000-0000-4000-8000-000000000002')
 and not exists(select 1 from private.dopmi_rescue_history
  where record_id=current_setting('test.seal_id')::uuid and snapshot->'private_data' is distinct from '{"verification_method":"profile"}'::jsonb),
  'decisions remain audited without duplicating the private profile evidence into history');
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is(dopmi_rescuer_public('65000000-0000-4000-8000-000000000001')->>'verified','true','approval gives the public badge');
select ok(dopmi_rescuer_public('65000000-0000-4000-8000-000000000001')::text !~ 'seal-person@example|528100010199|instagram.com|65000000-0000-4000-8000-000000000004',
 'approval never publishes the private review contact, photo or social link');
reset role;

insert into public.dopmi_rescue_records(id,owner_id,kind,status,public_data,private_data,files) values
 ('65000000-0000-4000-8000-000000000005','65000000-0000-4000-8000-000000000003','verification','submitted',
  '{"public_name":"Nombre anterior"}','{"identity_type":"ine","legal_name":"Documento anterior"}',
  '[{"role":"identity","path":"65000000-0000-4000-8000-000000000003/65000000-0000-4000-8000-000000000005/65000000-0000-4000-8000-000000000006.pdf"}]');
insert into storage.objects(bucket_id,name) values
 ('dopmi-rescue-evidence','65000000-0000-4000-8000-000000000003/65000000-0000-4000-8000-000000000005/65000000-0000-4000-8000-000000000006.pdf');
set local role authenticated;
select set_config('request.jwt.claim.sub','65000000-0000-4000-8000-000000000003',true);
select is(dopmi_rescuer_seal_status()->>'verification_method','documents','existing legacy record is identifiable');
select is(dopmi_submit_rescuer_seal()->>'verification_method','documents','a legacy request already in review is not replaced');
select set_config('request.jwt.claim.sub','65000000-0000-4000-8000-000000000002',true);
select is(dopmi_rescue_detail('65000000-0000-4000-8000-000000000005')->'record'->'files'->0->>'role','identity',
 'still-queued legacy evidence remains visible to staff');
select is(dopmi_review_rescue('65000000-0000-4000-8000-000000000005',1,'changes_requested','Revisar con perfil')->>'status',
 'changes_requested','legacy reviewer can return a previously submitted documentary request');
select set_config('request.jwt.claim.sub','65000000-0000-4000-8000-000000000003',true);
select is(dopmi_submit_rescuer_seal()->>'record_id','65000000-0000-4000-8000-000000000005','old editable record converts in place');
select is(dopmi_rescue_detail('65000000-0000-4000-8000-000000000005')->'record'->'files','[]'::jsonb,'former documents are not attached to the new checklist');
reset role;
select ok(exists(select 1 from private.dopmi_rescue_history
 where record_id='65000000-0000-4000-8000-000000000005' and action='seal_profile_conversion'
   and snapshot->'private_data'->>'legal_name'='Documento anterior'
   and jsonb_array_length(snapshot->'files')=1),'conversion preserves historical documents in private audit history');
select ok(exists(select 1 from storage.objects where bucket_id='dopmi-rescue-evidence' and
 name='65000000-0000-4000-8000-000000000003/65000000-0000-4000-8000-000000000005/65000000-0000-4000-8000-000000000006.pdf'),
 'historical evidence object is not deleted by the conversion');
select * from finish();
rollback;
