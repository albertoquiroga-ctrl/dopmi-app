begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok(not has_function_privilege('anon','public.dopmi_apple_credential_server(text,uuid,text,text,jsonb)','execute'),'anon cannot attest Apple revocation');
select ok(not has_function_privilege('authenticated','public.dopmi_apple_credential_server(text,uuid,text,text,jsonb)','execute'),'clients cannot attest Apple revocation for any owner');
select ok(not has_function_privilege('service_role','private.dopmi_apple_deletion_ready(uuid)','execute'),'private guard is not a service API');

insert into auth.users(id,email,email_confirmed_at) values
 ('a9000000-0000-4000-8000-000000000001','apple-delete-orphan@example.test',now()),
 ('a9000000-0000-4000-8000-000000000002','apple-delete-legacy@example.test',now()),
 ('a9000000-0000-4000-8000-000000000003','google-delete@example.test',now()),
 ('a9000000-0000-4000-8000-000000000004','email-delete@example.test',now());
insert into auth.identities(provider_id,user_id,identity_data,provider) values
 ('apple-delete-orphan','a9000000-0000-4000-8000-000000000001','{"sub":"apple-delete-orphan"}','apple'),
 ('apple-delete-legacy','a9000000-0000-4000-8000-000000000002','{"sub":"apple-delete-legacy"}','apple'),
 ('google-delete','a9000000-0000-4000-8000-000000000003','{"sub":"google-delete"}','google');

select throws_ok($$select dopmi_account_deletion_server('request','{"owner_id":"a9000000-0000-4000-8000-000000000001","request_key":"a9000000-0000-4000-8000-000000000001"}')$$,
 '55000','apple_reauthentication_required','orphaned Apple identity stops deletion before profile withdrawal');
select is((select account_status from profiles where id='a9000000-0000-4000-8000-000000000001'),'active','failed request preserves active profile');
select throws_ok($$delete from auth.users where id='a9000000-0000-4000-8000-000000000001'$$,
 '55000','apple_revocation_required','direct Auth deletion cannot skip revocation');
select throws_ok($$select dopmi_apple_credential_server('save','a9000000-0000-4000-8000-000000000001','apple-delete-legacy',repeat('a',64),'{"key_id":"v1","iv":"iv","ciphertext":"synthetic-encrypted-credential"}')$$,
 '42501','apple_identity_required','another owner subject is rejected');
select lives_ok($$select dopmi_apple_credential_server('require_active','a9000000-0000-4000-8000-000000000001','apple-delete-orphan',repeat('a',64))$$,'server records intent before exchanging code');
select throws_ok($$select dopmi_account_deletion_server('request','{"owner_id":"a9000000-0000-4000-8000-000000000001","request_key":"a9000000-0000-4000-8000-000000000001"}')$$,
 '55000','apple_registration_pending','unresolved exchange intent blocks deletion');
select is(dopmi_apple_credential_server('require_active','a9000000-0000-4000-8000-000000000001','apple-delete-orphan',repeat('a',64))->>'pending','true','same intent cannot repeat exchange blindly');
select throws_ok($$select dopmi_apple_credential_server('require_active','a9000000-0000-4000-8000-000000000001','apple-delete-orphan',repeat('b',64))$$,
 '55000','apple_registration_pending','different intent cannot overwrite the unresolved exchange');
select lives_ok($$select dopmi_apple_credential_server('save','a9000000-0000-4000-8000-000000000001','apple-delete-orphan',repeat('a',64),'{"key_id":"v1","iv":"iv","ciphertext":"synthetic-encrypted-credential"}')$$,'server can persist verified grant and consume intent');
select is(dopmi_account_deletion_server('request','{"owner_id":"a9000000-0000-4000-8000-000000000001","request_key":"a9000000-0000-4000-8000-000000000001"}')->>'status','procesando','request with grant starts processing');
select is(dopmi_account_deletion_server('finalize','{"owner_id":"a9000000-0000-4000-8000-000000000001"}')->>'attention_code','revocacion_apple_pendiente','failed or skipped provider revoke prevents finalize');
select throws_ok($$select dopmi_apple_credential_server('remove','a9000000-0000-4000-8000-000000000001',null,repeat('b',64))$$,
 '40001','credential_changed','compare-and-delete rejects a different grant');
select lives_ok($$select dopmi_apple_credential_server('remove','a9000000-0000-4000-8000-000000000001',null,repeat('a',64))$$,'successful revoke can be attested by service');
select ok((select apple_revoked_request_key=request_key and apple_revoked_request_hash=repeat('a',64)
 and apple_revoked_subject_hash=encode(sha256(convert_to('apple-delete-orphan','UTF8')),'hex') and apple_revoked_at is not null
 from private.dopmi_account_deletions where owner_id='a9000000-0000-4000-8000-000000000001'),'proof binds owner, operation and revoked grant');

-- A new verified grant invalidates earlier proof, including during recovery.
select dopmi_apple_credential_server('require_active','a9000000-0000-4000-8000-000000000001','apple-delete-orphan',repeat('b',64));
select lives_ok($$select dopmi_apple_credential_server('save','a9000000-0000-4000-8000-000000000001','apple-delete-orphan',repeat('b',64),'{"key_id":"v1","iv":"iv","ciphertext":"synthetic-encrypted-credential"}')$$,'Apple reauthentication can recover while deletion is pending');
select is((select account_status from profiles where id='a9000000-0000-4000-8000-000000000001'),'deletion_requested','recovery does not reactivate profile');
create temporary table apple_resume_before as select to_jsonb(d) value from private.dopmi_account_deletions d
 where owner_id='a9000000-0000-4000-8000-000000000001';
select is(dopmi_account_deletion_server('request','{"owner_id":"a9000000-0000-4000-8000-000000000001","request_key":"a9100000-0000-4000-8000-000000000001"}')->>'status','requiere_atencion','new button key resumes the same owner job after reauthentication');
select is((select to_jsonb(d) from private.dopmi_account_deletions d where owner_id='a9000000-0000-4000-8000-000000000001'),
 (select value from apple_resume_before),'resume preserves canonical key, proof, timestamps and attention state');
select is(dopmi_account_deletion_server('finalize','{"owner_id":"a9000000-0000-4000-8000-000000000001"}')->>'attention_code','revocacion_apple_pendiente','new grant invalidates earlier proof');
select dopmi_apple_credential_server('remove','a9000000-0000-4000-8000-000000000001',null,repeat('b',64));
select is(dopmi_account_deletion_server('finalize','{"owner_id":"a9000000-0000-4000-8000-000000000001"}')->>'status','completado','retry finishes only after durable revoke proof');
select throws_ok($$select dopmi_apple_credential_server('save','a9000000-0000-4000-8000-000000000001','apple-delete-orphan',repeat('c',64),'{"key_id":"v1","iv":"iv","ciphertext":"synthetic-encrypted-credential"}')$$,
 '42501','apple_identity_required','no new credential may be saved after finalization');
create temporary table apple_completed_resume_before as select to_jsonb(d) value from private.dopmi_account_deletions d
 where owner_id='a9000000-0000-4000-8000-000000000001';
select is(dopmi_account_deletion_server('request','{"owner_id":"a9000000-0000-4000-8000-000000000001","request_key":"a9200000-0000-4000-8000-000000000001"}')->>'status','completado','new key can resume pending Auth cleanup after finalize');
select is((select to_jsonb(d) from private.dopmi_account_deletions d where owner_id='a9000000-0000-4000-8000-000000000001'),
 (select value from apple_completed_resume_before),'completed cleanup retry retains the original revocation evidence');
select lives_ok($$delete from auth.users where id='a9000000-0000-4000-8000-000000000001'$$,'attested account may be removed from Auth');

-- Legacy jobs may already have withdrawn a profile without storing any grant.
insert into private.dopmi_account_deletions(owner_id,request_key,status)
 values('a9000000-0000-4000-8000-000000000002','a9000000-0000-4000-8000-000000000002','procesando');
update profiles set account_status='deletion_requested' where id='a9000000-0000-4000-8000-000000000002';
select dopmi_apple_credential_server('remove','a9000000-0000-4000-8000-000000000002',null,repeat('a',64));
select is(dopmi_account_deletion_server('finalize','{"owner_id":"a9000000-0000-4000-8000-000000000002"}')->>'attention_code','revocacion_apple_pendiente','missing credential cannot manufacture legacy revocation proof');
select throws_ok($$select dopmi_account_deletion_server('auth_cleanup','{"owner_id":"a9000000-0000-4000-8000-000000000002"}')$$,
 '55000','apple_revocation_required','legacy cleanup requires the same durable proof');

select is(dopmi_account_deletion_server('request','{"owner_id":"a9000000-0000-4000-8000-000000000003","request_key":"a9000000-0000-4000-8000-000000000003"}')->>'status','procesando','Google-only request remains available');
select is(dopmi_account_deletion_server('finalize','{"owner_id":"a9000000-0000-4000-8000-000000000003"}')->>'status','completado','Google-only account still finalizes');
select lives_ok($$delete from auth.users where id='a9000000-0000-4000-8000-000000000003'$$,'Google-only Auth cleanup remains available');
select is(dopmi_account_deletion_server('request','{"owner_id":"a9000000-0000-4000-8000-000000000004","request_key":"a9000000-0000-4000-8000-000000000004"}')->>'status','procesando','email request remains available');
select is(dopmi_account_deletion_server('finalize','{"owner_id":"a9000000-0000-4000-8000-000000000004"}')->>'status','completado','email account still finalizes');
select lives_ok($$delete from auth.users where id='a9000000-0000-4000-8000-000000000004'$$,'email Auth cleanup remains available');

select * from finish();
rollback;
