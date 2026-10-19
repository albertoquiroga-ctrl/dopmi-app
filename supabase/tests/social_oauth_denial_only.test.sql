begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok(not has_function_privilege('anon','public.social_verification_denial_available(uuid,uuid)','execute'),'anonymous cannot inspect a permission');
select ok(not has_function_privilege('authenticated','public.social_verification_denial_available(uuid,uuid)','execute'),'client cannot supply an arbitrary owner to inspect permission');
select ok(not has_function_privilege('anon','public.social_verification_denial_start(uuid,uuid,text,text)','execute'),'anonymous cannot consume a permission');
select ok(not has_function_privilege('authenticated','public.social_verification_denial_start(uuid,uuid,text,text)','execute'),'client cannot create rehearsal attempts directly');
select ok(has_function_privilege('service_role','public.social_verification_denial_start(uuid,uuid,text,text)','execute'),'existing server credential can use verified actor/session entrypoint');
select ok(not has_table_privilege('service_role','private.social_oauth_denial_grants','select'),'server cannot read raw grants directly');
select ok(not has_table_privilege('service_role','private.social_oauth_denial_grants','insert'),'server cannot create new grants');
select ok(not has_table_privilege('service_role','private.social_oauth_denial_grants','update'),'server cannot renew quota directly');
select ok(not has_table_privilege('service_role','private.social_oauth_denial_grants','delete'),'server cannot erase consumed quota');
select ok((select relrowsecurity from pg_class where oid='private.social_oauth_denial_grants'::regclass),'private grants retain RLS');

insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at)
 values('e1000000-0000-4000-8000-000000000001','social-denial-synthetic@example.test','{"admin":true,"social_denial_allowed":true}',now());
insert into auth.sessions(id,user_id)
 values('e1000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000001');
select is(public.social_verification_denial_available('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002'),false,'editable metadata does not create permission');
insert into private.social_oauth_denial_grants(owner_id,session_id,starts_at,expires_at)
 values('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002',clock_timestamp()-interval '1 second',clock_timestamp()+interval '14 minutes');
select is(public.social_verification_denial_available('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002'),true,'exact live actor/session can see scoped availability');
select is(public.social_verification_denial_available('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000003'),false,'another session stays closed');
select throws_ok($$select public.social_verification_denial_start('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','instagram',repeat('a',64))$$,'22023','denial_unavailable','Instagram cannot use Facebook permission');
select throws_ok($$select public.social_verification_start('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','facebook',repeat('a',64))$$,'22023','denial_only_required','global flag drift cannot switch the rehearsal to normal verification');
create temporary table denial_attempt(id uuid);
insert into denial_attempt select public.social_verification_denial_start('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','facebook',repeat('b',64));
select is(public.social_verification_denial_available('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002'),false,'one committed start consumes availability');
select throws_ok($$select public.social_verification_denial_start('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','facebook',repeat('c',64))$$,'22023','denial_unavailable','a lost response cannot justify a second attempt');
select is((select count(*) from public.social_verification_consume(repeat('b',64))),1::bigint,'legitimate local state consumes once');
select throws_ok($$select public.social_verification_finish((select id from denial_attempt),'42','Synthetic')$$,'22023','invalid_attempt','even server finish cannot create a proof for denial-only state');
select is((select count(*) from public.social_verification_proofs where owner_id='e1000000-0000-4000-8000-000000000001'),0::bigint,'no social proof was created');
delete from public.social_verification_attempts where id=(select id from denial_attempt);
select is(public.social_verification_denial_available('e1000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002'),false,'attempt retention cannot restore consumed grant');
select * from finish();
rollback;
