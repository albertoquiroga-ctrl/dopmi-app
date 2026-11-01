begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok(private.dopmi_general_legal_pair_allowed('terms-2026-11-01','privacy-2026-11-01'),'TEST admits new exact generic pair');
select ok(not private.dopmi_general_legal_pair_allowed('terms-live-2026-11-01','privacy-live-2026-11-01'),'TEST rejects new LIVE pair');
select ok(not private.dopmi_legal_pair_allowed('terms-2026-11-01','privacy-2026-11-01'),'legacy adult RPC validator cannot admit generic documents');
select is(to_regprocedure('public.accept_current_legal()'),null::regprocedure,'new acceptance requires explicit displayed document versions');

insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 ('ec000000-0000-4000-8000-000000000001','generic-owner@example.test',now(),'{}'),
 ('ec000000-0000-4000-8000-000000000002','generic-other@example.test',now(),'{}'),
 ('ec000000-0000-4000-8000-000000000003','generic-pending@example.test',null,'{}'),
 ('ec000000-0000-4000-8000-000000000004','generic-history@example.test',now(),
  '{"terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}'),
 ('ec000000-0000-4000-8000-000000000005','generic-signup@example.test',now(),
  '{"terms_version":"terms-2026-11-01","privacy_version":"privacy-2026-11-01","terms_accepted":true,"privacy_accepted":true,"adult_confirmed":true,"role":"admin"}'),
 ('ec000000-0000-4000-8000-000000000006','generic-missing@example.test',now(),
  '{"terms_version":"terms-2026-11-01","privacy_version":"privacy-2026-11-01","adult_confirmed":true}');
create temporary table generic_legal_history as select to_jsonb(c) value from private.dopmi_consents c
 where c.owner_id='ec000000-0000-4000-8000-000000000004';
create temporary table generic_adult_history as select adult_confirmed_at value from public.profiles
 where id='ec000000-0000-4000-8000-000000000004';

select is((select adult_confirmed_at from public.profiles where id='ec000000-0000-4000-8000-000000000005'),null::timestamptz,'generic signup never invents adult declaration from editable metadata');
select is((select adult_confirmed from private.dopmi_consents where owner_id='ec000000-0000-4000-8000-000000000005'),false,'generic signup proof is explicitly non-adult');
select is((select terms_version from public.profiles where id='ec000000-0000-4000-8000-000000000006'),null::text,'adult metadata does not replace both generic acceptance booleans');

set local role authenticated;
select set_config('request.jwt.claim.sub','ec000000-0000-4000-8000-000000000001',true);
select set_config('test.generic_legal_acceptance',accept_current_legal('terms-2026-11-01','privacy-2026-11-01')::text,true);
select is(accept_current_legal('terms-2026-11-01','privacy-2026-11-01'),current_setting('test.generic_legal_acceptance')::jsonb,'duplicate acceptance reuses immutable proof');
select is((current_setting('test.generic_legal_acceptance')::jsonb->>'adult_confirmed')::boolean,false,'RPC response describes no adult declaration');
select throws_ok($$select dopmi_accept_legal('terms-2026-11-01','privacy-2026-11-01',true)$$,'22023',null,'legacy RPC cannot fabricate adult proof for general documents');
select throws_ok($$select accept_current_legal('terms-live-2026-11-01','privacy-live-2026-11-01')$$,'22023',null,'TEST user cannot accept crossed LIVE pair');
select throws_ok($$select accept_current_legal('terms-2026-11-01','privacy-live-2026-11-01')$$,'22023',null,'mixed pair denied');
select throws_ok($$select accept_current_legal('terms-2099-01-01','privacy-2099-01-01')$$,'22023',null,'client cannot implicitly accept future documents');
select throws_ok($$update profiles set adult_confirmed_at=now()$$,'42501',null,'client cannot write an adult projection');
select throws_ok($$select * from private.dopmi_consents$$,'42501',null,'client cannot read private evidence');
select set_config('request.jwt.claim.sub','ec000000-0000-4000-8000-000000000003',true);
select throws_ok($$select accept_current_legal('terms-2026-11-01','privacy-2026-11-01')$$,'42501',null,'unconfirmed email cannot call new acceptance');
select set_config('request.jwt.claim.sub','ec000000-0000-4000-8000-000000000005',true);
select is(dopmi_is_admin(),false,'generic signup metadata grants no admin role');
reset role;
select is((select adult_confirmed_at from public.profiles where id='ec000000-0000-4000-8000-000000000001'),null::timestamptz,'new acceptance leaves adult timestamp absent');
select is((select terms_version from public.profiles where id='ec000000-0000-4000-8000-000000000002'),null::text,'acceptance cannot write another owner');
select ok(exists(select 1 from public.profiles p join private.dopmi_consents c on c.owner_id=p.id
 where p.id='ec000000-0000-4000-8000-000000000001' and not c.adult_confirmed
 and c.accepted_at=p.terms_accepted_at and c.accepted_at=p.privacy_accepted_at),'generic profile timestamps match actor-owned evidence');

update private.dopmi_payment_environment set environment='production';
select ok(private.dopmi_general_legal_pair_allowed('terms-live-2026-11-01','privacy-live-2026-11-01'),'PROD admits exact new LIVE pair');
select ok(not private.dopmi_general_legal_pair_allowed('terms-2026-11-01','privacy-2026-11-01'),'PROD rejects TEST pair');
select throws_ok($$select private.dopmi_require_current_legal('ec000000-0000-4000-8000-000000000001')$$,'42501',null,'TEST generic evidence cannot satisfy PROD finance');
set local role authenticated;
select set_config('request.jwt.claim.sub','ec000000-0000-4000-8000-000000000001',true);
select lives_ok($$select accept_current_legal('terms-live-2026-11-01','privacy-live-2026-11-01')$$,'owner can upgrade to generic LIVE without declaring adulthood');
select set_config('request.jwt.claim.sub','ec000000-0000-4000-8000-000000000004',true);
select lives_ok($$select accept_current_legal('terms-live-2026-11-01','privacy-live-2026-11-01')$$,'historical adult owner can accept generic LIVE');
reset role;
select lives_ok($$select private.dopmi_require_current_legal('ec000000-0000-4000-8000-000000000001')$$,'genuine generic LIVE proof admits existing financial guard without adulthood');
select ok(exists(select 1 from private.dopmi_consents c join generic_legal_history h on to_jsonb(c)=h.value),'historical consent row remains byte-equivalent');
select is((select adult_confirmed_at from public.profiles where id='ec000000-0000-4000-8000-000000000004'),(select value from generic_adult_history),'historical adult timestamp is preserved');
update private.dopmi_consents set adult_confirmed=true where owner_id='ec000000-0000-4000-8000-000000000001' and terms_version='terms-live-2026-11-01';
select throws_ok($$select private.dopmi_require_current_legal('ec000000-0000-4000-8000-000000000001')$$,'42501',null,'wrong declaration semantics cannot satisfy generic financial proof');
set local role authenticated;
select set_config('request.jwt.claim.sub','ec000000-0000-4000-8000-000000000001',true);
select throws_ok($$select accept_current_legal('terms-live-2026-11-01','privacy-live-2026-11-01')$$,'42501',null,'new RPC refuses to overwrite malformed evidence');
reset role;

set local role anon;
select throws_ok($$select accept_current_legal('terms-live-2026-11-01','privacy-live-2026-11-01')$$,'42501',null,'anonymous acceptance denied');
reset role;
set local role service_role;
select throws_ok($$select accept_current_legal('terms-live-2026-11-01','privacy-live-2026-11-01')$$,'42501',null,'service cannot impersonate general consent');
select throws_ok($$select private.dopmi_general_legal_pair_allowed('terms-live-2026-11-01','privacy-live-2026-11-01')$$,'42501',null,'private helper is not exposed to service callers');
reset role;

select * from finish();
rollback;
