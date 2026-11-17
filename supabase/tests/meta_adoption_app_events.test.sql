begin;
set local search_path=public,extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at)
select ('81280000-0000-4000-8000-00000000000'||n)::uuid,'meta-ads-'||n||'@example.test',
  '{"display_name":"Cuenta de prueba","terms_version":"development-2026-09-13","terms_accepted":true}',now()
from generate_series(1,4) n;

insert into public.dopmi_adoptions(id,owner_id,pet_name,status,published_at)
values('81281000-0000-4000-8000-000000000001','81280000-0000-4000-8000-000000000001','Luna','published',now());

insert into public.dopmi_adoptions(
  id,owner_id,pet_name,city,region,story,publisher_name,photos,personality,approximate_latitude,approximate_longitude
) values(
  '81281000-0000-4000-8000-000000000002','81280000-0000-4000-8000-000000000003','Sol','Monterrey',
  'Nuevo León','Sol busca una familia que le dedique tiempo.','Cuenta de prueba',
  array['81280000-0000-4000-8000-000000000003/81281000-0000-4000-8000-000000000002/81284000-0000-4000-8000-000000000002.jpg'],
  array['affectionate','calm'],25.69,-100.32
);
insert into storage.objects(bucket_id,name)
values('dopmi-adoption-photos','81280000-0000-4000-8000-000000000003/81281000-0000-4000-8000-000000000002/81284000-0000-4000-8000-000000000002.jpg');

insert into public.dopmi_adoptions(id,owner_id,pet_name) values
  ('81281000-0000-4000-8000-000000000005','81280000-0000-4000-8000-000000000003','Borrador incompleto');

select set_config('test.meta_context',
  '{"advertising_id":"81285000-0000-4000-8000-000000000001","os_version":"16","app_version":"2.3.5","app_build":398}',true);

select ok(not has_function_privilege('anon','public.dopmi_meta_ads_preference()','execute'),'anonymous cannot read preference');
select ok(not has_function_privilege('anon','public.dopmi_meta_ads_action_eligible(text,uuid)','execute'),'anonymous cannot preflight an action');
select ok(not has_function_privilege('authenticated','public.dopmi_set_meta_ads_gate(boolean)','execute'),'account cannot open global gate');
select ok(not has_function_privilege('authenticated','public.dopmi_claim_meta_ads_events(integer)','execute'),'account cannot claim events');
select ok(not has_function_privilege('authenticated','public.dopmi_purge_expired_meta_ads_events()','execute'),'account cannot run the retention janitor');
select ok(not has_function_privilege('authenticated','public.dopmi_complete_meta_ads_event(uuid,boolean,uuid)','execute'),'account cannot complete an event');

set local role authenticated;
select set_config('request.jwt.claim.sub','81280000-0000-4000-8000-000000000002',true);
select is(dopmi_meta_ads_preference(),false,'measurement is off by default');
select is(dopmi_set_meta_ads_preference(true),false,'closed gate refuses opt-in');
select is(dopmi_set_meta_ads_preference(false),false,'closed gate still accepts revoke');
select set_config('test.meta_thread',dopmi_start_adoption_contact('81281000-0000-4000-8000-000000000001')::text,true);
select is(dopmi_meta_ads_action_eligible('first_adoption_message',current_setting('test.meta_thread')::uuid),false,'gate off prevents native advertising preflight');
select is(dopmi_send_message_meta(current_setting('test.meta_thread')::uuid,'81282000-0000-4000-8000-000000000001',
  'Envío con el permiso apagado',null,current_setting('test.meta_context')::jsonb)->>'body','Envío con el permiso apagado',
  'message continues when gate is off');

set local role service_role;
select is(dopmi_claim_meta_ads_events(10),'[]'::jsonb,'automatic greeting and gate-off message enqueue nothing');
select is(dopmi_set_meta_ads_gate(true),true,'operations can enable the gate');

set local role authenticated;
select is(dopmi_set_meta_ads_preference(true),true,'adopter explicitly opts in');
select is(dopmi_meta_ads_preference(),true,'adopter reads own active permission');
select is(dopmi_meta_ads_action_eligible('first_adoption_message',current_setting('test.meta_thread')::uuid),true,'opted-in adopter can preflight a first message');
select is(dopmi_meta_ads_action_eligible('unsupported',current_setting('test.meta_thread')::uuid),false,'invalid kinds fail closed');
select is(dopmi_send_message_meta(current_setting('test.meta_thread')::uuid,'81282000-0000-4000-8000-000000000001',
  'Envío con el permiso apagado',null,current_setting('test.meta_context')::jsonb)->>'body','Envío con el permiso apagado',
  'retry of previously stored message preserves canonical response');
select is(dopmi_send_message_meta(current_setting('test.meta_thread')::uuid,'81282000-0000-4000-8000-000000000002',
  'Envío con metadatos inválidos',null,current_setting('test.meta_context')::jsonb||'{"extra":"never store"}'::jsonb)->>'body',
  'Envío con metadatos inválidos','unknown advertising fields do not block message');
set local role service_role;
select is(dopmi_claim_meta_ads_events(10),'[]'::jsonb,'replayed pre-consent message and invalid context enqueue nothing');
reset role;
create function private.dopmi_test_reject_meta_enqueue() returns trigger
language plpgsql as $$begin raise exception 'synthetic failure, never copied to telemetry logs'; end;$$;
create trigger dopmi_test_reject_meta_enqueue before insert on private.dopmi_meta_ads_outbox
  for each row execute function private.dopmi_test_reject_meta_enqueue();
set local role authenticated;
select is(dopmi_send_message_meta(current_setting('test.meta_thread')::uuid,'81282000-0000-4000-8000-000000000010',
  'El mensaje se conserva',null,current_setting('test.meta_context')::jsonb)->>'body','El mensaje se conserva',
  'an unexpected enqueue failure preserves the valid product send');
reset role;
select ok(exists(select 1 from public.dopmi_messages where id='81282000-0000-4000-8000-000000000010'),
  'the persisted message survives the telemetry exception');
drop trigger dopmi_test_reject_meta_enqueue on private.dopmi_meta_ads_outbox;
drop function private.dopmi_test_reject_meta_enqueue();
set local role service_role;
select is(dopmi_claim_meta_ads_events(10),'[]'::jsonb,'the failed enqueue does not fabricate a conversion');

set local role authenticated;
select is(dopmi_send_message_meta(current_setting('test.meta_thread')::uuid,'81282000-0000-4000-8000-000000000003',
  'Primer envío apto',null,current_setting('test.meta_context')::jsonb)->>'body','Primer envío apto',
  'first explicit eligible adopter message succeeds');
select is(dopmi_send_message_meta(current_setting('test.meta_thread')::uuid,'81282000-0000-4000-8000-000000000004',
  'Segundo envío apto',null,current_setting('test.meta_context')::jsonb)->>'body','Segundo envío apto',
  'second eligible message also succeeds');
select set_config('request.jwt.claim.sub','81280000-0000-4000-8000-000000000001',true);
select is(dopmi_meta_ads_preference(),false,'another account cannot inherit permission');
select is(dopmi_set_meta_ads_preference(true),true,'rescuer can opt in for own actions');
select is(dopmi_meta_ads_action_eligible('first_adoption_message',current_setting('test.meta_thread')::uuid),false,'owner reply is ineligible before native identifier lookup');
select is(dopmi_meta_ads_action_eligible('first_adoption_submission','81281000-0000-4000-8000-000000000001'),false,'a published adoption revision is ineligible');
select is(dopmi_meta_ads_action_eligible('first_adoption_submission','81281000-0000-4000-8000-000000000002'),false,'another owner cannot preflight a draft');
select is(dopmi_send_message_meta(current_setting('test.meta_thread')::uuid,'81282000-0000-4000-8000-000000000005',
  'Respuesta del rescatista',null,current_setting('test.meta_context')::jsonb)->>'body','Respuesta del rescatista',
  'rescuer reply succeeds without counting as adopter outreach');
select set_config('request.jwt.claim.sub','81280000-0000-4000-8000-000000000004',true);
select throws_ok($$select dopmi_send_message_meta(current_setting('test.meta_thread')::uuid,
  '81282000-0000-4000-8000-000000000006','Sin autorización',null,current_setting('test.meta_context')::jsonb)$$,
  '42501',null,'meta wrapper preserves participant authorization');
select throws_ok($$select dopmi_transition_adoption_meta('81281000-0000-4000-8000-000000000002',1,'submit',
  current_setting('test.meta_context')::jsonb)$$,'42501',null,'meta wrapper preserves adoption ownership authorization');

set local role service_role;
select set_config('test.meta_claim',dopmi_claim_meta_ads_events(10)::text,true);
select is(jsonb_array_length(current_setting('test.meta_claim')::jsonb),1,'only one event for first intentional eligible adopter message');
select is(current_setting('test.meta_claim')::jsonb->0->>'event_name','Contact','server chooses the Meta standard Contact name');
select is((current_setting('test.meta_claim')::jsonb->0) - array['event_id','lease_token','event_name','event_time',
  'advertising_id','os_version','app_version','app_build'],'{}'::jsonb,'worker receives only the allowlisted payload');
select is(dopmi_claim_meta_ads_events(10),'[]'::jsonb,'pending lease excludes concurrent claim');
select is(dopmi_meta_ads_event_allowed(
  (current_setting('test.meta_claim')::jsonb->0->>'event_id')::uuid,
  (current_setting('test.meta_claim')::jsonb->0->>'lease_token')::uuid
),true,'current lease authorizes dispatch');
select is(dopmi_complete_meta_ads_event(
  (current_setting('test.meta_claim')::jsonb->0->>'event_id')::uuid,true,gen_random_uuid()
),false,'stale token cannot acknowledge a current lease');

set local role authenticated;
select set_config('request.jwt.claim.sub','81280000-0000-4000-8000-000000000002',true);
select is(dopmi_set_meta_ads_preference(false),false,'adopter revokes permission');
set local role service_role;
select is(dopmi_meta_ads_event_allowed(
  (current_setting('test.meta_claim')::jsonb->0->>'event_id')::uuid,
  (current_setting('test.meta_claim')::jsonb->0->>'lease_token')::uuid
),false,'revocation invalidates outstanding lease');
reset role;
select ok((select advertising_id is null from private.dopmi_meta_ads_outbox
  where event_id=(current_setting('test.meta_claim')::jsonb->0->>'event_id')::uuid),
  'revocation purges the ad identifier while preserving deduplication');

set local role authenticated;
select is(dopmi_set_meta_ads_preference(true),true,'adopter may explicitly re-enable');
select is(dopmi_meta_ads_action_eligible('first_adoption_message',current_setting('test.meta_thread')::uuid),false,'revoked and scrubbed conversion still exhausts eligibility');
select is(dopmi_send_message_meta(current_setting('test.meta_thread')::uuid,'81282000-0000-4000-8000-000000000007',
  'Después de reactivar',null,current_setting('test.meta_context')::jsonb)->>'body','Después de reactivar',
  'message continues after re-enabling');
set local role service_role;
select is(dopmi_claim_meta_ads_events(10),'[]'::jsonb,'re-enabling cannot duplicate a previously captured conversion');

set local role authenticated;
select set_config('request.jwt.claim.sub','81280000-0000-4000-8000-000000000003',true);
select is(dopmi_set_meta_ads_preference(true),true,'publication author opts in');
select is(dopmi_meta_ads_action_eligible('first_adoption_submission','81281000-0000-4000-8000-000000000005'),false,
  'canonical validation failure blocks preflight before an AAID read');
select is(dopmi_meta_ads_action_eligible('first_adoption_submission','81281000-0000-4000-8000-000000000002'),true,'valid initial adoption draft can preflight');
select throws_ok($$select dopmi_transition_adoption_meta('81281000-0000-4000-8000-000000000002',999,'submit',
  current_setting('test.meta_context')::jsonb)$$,'40001',null,'optimistic version conflict remains unchanged');
select is(dopmi_transition_adoption_meta('81281000-0000-4000-8000-000000000002',1,'submit',
  current_setting('test.meta_context')::jsonb)->>'status','submitted','server accepts a valid initial submission');
select is(dopmi_transition_adoption_meta('81281000-0000-4000-8000-000000000002',2,'withdraw',
  current_setting('test.meta_context')::jsonb)->>'status','draft','withdraw remains available');
select is(dopmi_transition_adoption_meta('81281000-0000-4000-8000-000000000002',3,'submit',
  current_setting('test.meta_context')::jsonb)->>'status','submitted','resubmission remains available');

set local role service_role;
select set_config('test.meta_claim',dopmi_claim_meta_ads_events(10)::text,true);
select is(jsonb_array_length(current_setting('test.meta_claim')::jsonb),1,'only one first submission event');
select is(current_setting('test.meta_claim')::jsonb->0->>'event_name','SubmitApplication','server chooses the Meta standard SubmitApplication name');
select is(dopmi_complete_meta_ads_event(
  (current_setting('test.meta_claim')::jsonb->0->>'event_id')::uuid,false,
  (current_setting('test.meta_claim')::jsonb->0->>'lease_token')::uuid
),true,'current lease can schedule a retry');
select is(dopmi_claim_meta_ads_events(10),'[]'::jsonb,'retry has a delay');
reset role;
update private.dopmi_meta_ads_outbox set available_at=clock_timestamp()-interval '1 second'
where event_id=(current_setting('test.meta_claim')::jsonb->0->>'event_id')::uuid;

set local role service_role;
select set_config('test.meta_retry',dopmi_claim_meta_ads_events(10)::text,true);
select is(current_setting('test.meta_retry')::jsonb->0->>'event_id',
  current_setting('test.meta_claim')::jsonb->0->>'event_id','retry reuses the stable Meta event ID');
select isnt(current_setting('test.meta_retry')::jsonb->0->>'lease_token',
  current_setting('test.meta_claim')::jsonb->0->>'lease_token','retry generates a new lease token');
select is(dopmi_complete_meta_ads_event(
  (current_setting('test.meta_retry')::jsonb->0->>'event_id')::uuid,true,
  (current_setting('test.meta_retry')::jsonb->0->>'lease_token')::uuid
),true,'current lease acknowledges successful delivery');
reset role;
select ok((select advertising_id is null from private.dopmi_meta_ads_outbox
  where event_id=(current_setting('test.meta_retry')::jsonb->0->>'event_id')::uuid),
  'completed event retains no ad identifier');
set local role authenticated;
select set_config('request.jwt.claim.sub','81280000-0000-4000-8000-000000000004',true);
select is(dopmi_set_meta_ads_preference(true),true,'photo sender opts in');
select set_config('test.meta_photo_thread',dopmi_start_adoption_contact('81281000-0000-4000-8000-000000000001')::text,true);
select set_config('test.meta_chat_photo',
  '81280000-0000-4000-8000-000000000004/'||current_setting('test.meta_photo_thread')||
  '/81282000-0000-4000-8000-000000000008.jpg',true);
reset role;
insert into storage.objects(bucket_id,name) values('dopmi-chat-photos',current_setting('test.meta_chat_photo'));
set local role authenticated;
select is(dopmi_send_message_meta(current_setting('test.meta_photo_thread')::uuid,'81282000-0000-4000-8000-000000000008',
  '',current_setting('test.meta_chat_photo'),current_setting('test.meta_context')::jsonb)->>'attachment_path',
  current_setting('test.meta_chat_photo'),'explicit photo without text counts as a sent message');
set local role service_role;
select set_config('test.meta_photo_claim',dopmi_claim_meta_ads_events(10)::text,true);
select is(current_setting('test.meta_photo_claim')::jsonb->0->>'event_name','Contact','photo sends the same first contact event');
reset role;
update private.dopmi_meta_ads_outbox set attempts=5,event_at=statement_timestamp()-interval '24 hours 1 second'
where event_id=(current_setting('test.meta_photo_claim')::jsonb->0->>'event_id')::uuid;
set local role service_role;
select is(dopmi_meta_ads_event_allowed(
  (current_setting('test.meta_photo_claim')::jsonb->0->>'event_id')::uuid,
  (current_setting('test.meta_photo_claim')::jsonb->0->>'lease_token')::uuid
),false,'expired event may not dispatch even under a valid lease');
select is(dopmi_purge_expired_meta_ads_events(),1::bigint,'the independent janitor clears expired context');
select is(dopmi_claim_meta_ads_events(10),'[]'::jsonb,'expired event cannot be reclaimed');
reset role;
select ok((select advertising_id is null from private.dopmi_meta_ads_outbox
  where event_id=(current_setting('test.meta_photo_claim')::jsonb->0->>'event_id')::uuid),
  'queue sweep purges expired advertising context');
set local role authenticated;
select is(dopmi_meta_ads_action_eligible('first_adoption_message',current_setting('test.meta_photo_thread')::uuid),false,
  'expired and exhausted event still prevents subsequent device ID reads');

set local role authenticated;
select set_config('request.jwt.claim.sub','81280000-0000-4000-8000-000000000003',true);
select set_config('test.meta_gate_thread',dopmi_start_adoption_contact('81281000-0000-4000-8000-000000000001')::text,true);
select is(dopmi_send_message_meta(current_setting('test.meta_gate_thread')::uuid,'81282000-0000-4000-8000-000000000009',
  'Mensaje antes de cerrar',null,current_setting('test.meta_context')::jsonb)->>'body','Mensaje antes de cerrar',
  'one account may have one event per distinct conversion');
set local role service_role;
select set_config('test.meta_gate_claim',dopmi_claim_meta_ads_events(10)::text,true);
select is(jsonb_array_length(current_setting('test.meta_gate_claim')::jsonb),1,'gate closure fixture is in flight');
select is(dopmi_set_meta_ads_gate(false),false,'operations can close the gate');
select is(dopmi_complete_meta_ads_event(
  (current_setting('test.meta_gate_claim')::jsonb->0->>'event_id')::uuid,true,
  (current_setting('test.meta_gate_claim')::jsonb->0->>'lease_token')::uuid
),false,'gate closure invalidates outstanding lease');
reset role;
select ok((select advertising_id is null from private.dopmi_meta_ads_outbox
  where event_id=(current_setting('test.meta_gate_claim')::jsonb->0->>'event_id')::uuid),
  'gate closure purges all claimed advertising context');
set local role service_role;
select is(dopmi_set_meta_ads_gate(true),true,'operations can reopen the gate');
set local role authenticated;
select is(dopmi_meta_ads_preference(),false,'reopening requires fresh opt-in');

-- Reproduce a deployment whose canonical transition predates private revisions.
reset role;
alter table private.dopmi_adoption_edits rename to dopmi_adoption_edits_later_schema;
alter function private.dopmi_adoption_validate(public.dopmi_adoptions) rename to dopmi_adoption_validate_later_schema;
select is(to_regclass('private.dopmi_adoption_edits'),null::regclass,'legacy deployment has no private revisions table');

create or replace function public.dopmi_transition_adoption(post_id uuid,expected_version integer,action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.dopmi_require_actor(); a public.dopmi_adoptions; next_status text;
begin
  select * into a from public.dopmi_adoptions where id=post_id for update;
  if not found or a.owner_id<>actor then raise exception 'Publicación no disponible' using errcode='42501'; end if;
  if expected_version is distinct from a.version then raise exception 'La publicación cambió. Vuelve a cargarla.' using errcode='40001'; end if;
  if action='submit' and a.status in ('draft','changes_requested') then
    if a.species is null or a.sex is null or a.size is null then
      raise exception 'Selecciona especie, sexo y tamaño antes de enviar.' using errcode='22023';
    end if;
    if char_length(a.pet_name)<1 or char_length(a.city)<1 or char_length(a.region)<1 or char_length(a.story)<20
      or char_length(a.publisher_name)<1 or cardinality(a.photos)<1 then
      raise exception 'Completa nombre, ubicación, historia, nombre público y al menos una foto.' using errcode='22023'; end if;
    if exists(select 1 from unnest(a.photos) photo where not exists(
      select 1 from storage.objects o where o.bucket_id='dopmi-adoption-photos' and o.name=photo)) then
      raise exception 'Una foto no terminó de subir. Vuelve a adjuntarla.' using errcode='22023'; end if;
    next_status:='submitted';
  elsif action='withdraw' and a.status='submitted' then next_status:='draft';
  elsif action='adopted' and a.status='published' then next_status:='adopted';
  elsif action='archive' and a.status<>'archived' then next_status:='archived';
  else raise exception 'Esta transición no está disponible' using errcode='22023'; end if;
  update public.dopmi_adoptions set status=next_status,version=version+1,updated_at=now(),
    submitted_at=case when next_status='submitted' then now() else submitted_at end
    where id=post_id returning * into a;
  return to_jsonb(a);
end;
$$;

insert into public.dopmi_adoptions(
  id,owner_id,pet_name,city,region,story,publisher_name,photos
) values(
  '81281000-0000-4000-8000-000000000003','81280000-0000-4000-8000-000000000004','Nube','Monterrey',
  'Nuevo León','Nube busca una familia que le dedique tiempo.','Cuenta de prueba',
  array['81280000-0000-4000-8000-000000000004/81281000-0000-4000-8000-000000000003/81284000-0000-4000-8000-000000000003.jpg']
);
insert into storage.objects(bucket_id,name)
values('dopmi-adoption-photos','81280000-0000-4000-8000-000000000004/81281000-0000-4000-8000-000000000003/81284000-0000-4000-8000-000000000003.jpg');
insert into public.dopmi_adoptions(id,owner_id,pet_name,city,region,story,publisher_name,photos)
select '81281000-0000-4000-8000-000000000004',owner_id,pet_name,city,region,story,publisher_name,
  array['81280000-0000-4000-8000-000000000004/81281000-0000-4000-8000-000000000004/81284000-0000-4000-8000-000000000004.jpg']
from public.dopmi_adoptions where id='81281000-0000-4000-8000-000000000003';
insert into storage.objects(bucket_id,name)
values('dopmi-adoption-photos','81280000-0000-4000-8000-000000000004/81281000-0000-4000-8000-000000000004/81284000-0000-4000-8000-000000000004.jpg');

set local role authenticated;
select set_config('request.jwt.claim.sub','81280000-0000-4000-8000-000000000004',true);
select is(dopmi_set_meta_ads_preference(true),true,'legacy-schema author explicitly opts in again');
select is(dopmi_transition_adoption_meta('81281000-0000-4000-8000-000000000004',1,'submit',null)->>'status','submitted',
  'a prior submit without advertising context still succeeds');
select is(dopmi_transition_adoption_meta('81281000-0000-4000-8000-000000000004',2,'withdraw',
  current_setting('test.meta_context')::jsonb)->>'status','draft','withdrawal keeps the canonical transition');
select is(dopmi_meta_ads_action_eligible('first_adoption_submission','81281000-0000-4000-8000-000000000004'),false,
  'a withdrawn draft cannot preflight even without an earlier captured submission');
select is(dopmi_meta_ads_action_eligible('first_adoption_submission','81281000-0000-4000-8000-000000000003'),true,'legacy draft passes eligibility without private revisions');
select is(dopmi_transition_adoption_meta('81281000-0000-4000-8000-000000000003',1,'submit',
  current_setting('test.meta_context')::jsonb)->>'status','submitted',
  'valid draft submits without a private revisions table');
set local role service_role;
select set_config('test.meta_legacy_claim',dopmi_claim_meta_ads_events(10)::text,true);
select is(jsonb_array_length(current_setting('test.meta_legacy_claim')::jsonb),1,'legacy schema queues one conversion');
select is(current_setting('test.meta_legacy_claim')::jsonb->0->>'event_name','SubmitApplication',
  'legacy schema keeps the standard submission event');

reset role;
select * from finish();
rollback;
