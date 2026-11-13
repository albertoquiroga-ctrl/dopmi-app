begin;
set local search_path = public, extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id, email, raw_user_meta_data, email_confirmed_at)
select ('98000000-0000-4000-8000-00000000000' || n)::uuid,
       'match-favorites-' || n || '@example.test',
       '{"display_name":"Prueba de favoritos","terms_version":"development-2026-09-13","terms_accepted":true}',
       now()
from generate_series(1, 4) n;

insert into public.dopmi_adoptions(id, owner_id, pet_name, status, review_feedback)
select ('98100000-0000-4000-8000-00000000000' || n)::uuid,
       case when n = 5 then '98000000-0000-4000-8000-000000000004'::uuid
            else '98000000-0000-4000-8000-000000000001'::uuid end,
       'Mascota ' || n,
       case when n = 4 then 'draft' else 'published' end,
       'Comentario privado'
from generate_series(1, 5) n;
update public.profiles set account_status = 'suspended'
where id = '98000000-0000-4000-8000-000000000004';

insert into public.dopmi_favorites(user_id, post_id, created_at)
select '98000000-0000-4000-8000-000000000002',
       ('98100000-0000-4000-8000-00000000000' || n)::uuid,
       now() + n * interval '1 second'
from generate_series(1, 5) n;
insert into public.dopmi_favorites(user_id, post_id)
values ('98000000-0000-4000-8000-000000000003', '98100000-0000-4000-8000-000000000001');

-- An older client could start an empty thread before a first message.
insert into public.dopmi_threads(id, post_id, owner_id, adopter_id, pet_name, status)
values
  ('98200000-0000-4000-8000-000000000002', '98100000-0000-4000-8000-000000000002',
   '98000000-0000-4000-8000-000000000001', '98000000-0000-4000-8000-000000000002', 'Mascota 2', 'active'),
  ('98200000-0000-4000-8000-000000000003', '98100000-0000-4000-8000-000000000003',
   '98000000-0000-4000-8000-000000000001', '98000000-0000-4000-8000-000000000002', 'Mascota 3', 'closed');
-- A previously sent photo can have an empty text body.
insert into public.dopmi_messages(id, thread_id, sender_id, body, attachment_path)
values ('98300000-0000-4000-8000-000000000003', '98200000-0000-4000-8000-000000000003',
        '98000000-0000-4000-8000-000000000002', '',
        '98000000-0000-4000-8000-000000000002/98200000-0000-4000-8000-000000000003/98300000-0000-4000-8000-000000000003.jpg');

set local role anon;
select throws_ok($$select public.dopmi_match_favorites()$$, '42501', null, 'anonymous cannot read match favorites');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok($$select public.dopmi_match_favorites()$$, '42501', null, 'a role without a current account is insufficient');
select set_config('request.jwt.claim.sub', '98000000-0000-4000-8000-000000000002', true);
select throws_ok($$select public.dopmi_match_favorites(0)$$, '22023', null, 'invalid page is rejected');
select is((public.dopmi_match_favorites()->>'total')::integer, 2, 'excludes private, suspended and contacted pets before counting');
select is(public.dopmi_match_favorites(1, 1)->'items'->0->>'id',
  '98100000-0000-4000-8000-000000000002', 'an empty thread keeps the recent favorite visible');
select is(public.dopmi_match_favorites(2, 1)->'items'->0->>'id',
  '98100000-0000-4000-8000-000000000001', 'pagination still reaches the next eligible favorite');
select ok(not (public.dopmi_match_favorites()->'items'->0 ?| array['review_feedback','approximate_latitude','attachment_path']),
  'public pet data excludes private coordinates, moderation and messages');

select set_config('request.jwt.claim.sub', '98000000-0000-4000-8000-000000000001', true);
select public.dopmi_send_message('98200000-0000-4000-8000-000000000002',
  '98300000-0000-4000-8000-000000000002', 'Hola');
select set_config('request.jwt.claim.sub', '98000000-0000-4000-8000-000000000002', true);
select is((public.dopmi_match_favorites()->>'total')::integer, 2, 'a message sent only by the rescuer does not hide the favorite');
select throws_ok($$select public.dopmi_send_message('98200000-0000-4000-8000-000000000002',
  '98300000-0000-4000-8000-000000000012', '')$$, '22023', null, 'empty adopter send is rejected');
select is((public.dopmi_match_favorites()->>'total')::integer, 2, 'failed sends preserve the favorite');
select public.dopmi_start_adoption_contact('98100000-0000-4000-8000-000000000001');
select is((public.dopmi_match_favorites()->>'total')::integer, 1, 'the saved automatic greeting hides that favorite');
select public.dopmi_send_message('98200000-0000-4000-8000-000000000002',
  '98300000-0000-4000-8000-000000000012', 'Me interesa');
select is(public.dopmi_match_favorites(), '{"items":[],"total":0}'::jsonb, 'first saved message also hides the legacy favorite');
select is((public.dopmi_saved_adoptions()->>'total')::integer, 5, 'likes remain saved for Profile and rediscovery');
select set_config('request.jwt.claim.sub', '98000000-0000-4000-8000-000000000003', true);
select is(public.dopmi_match_favorites()->'items'->0->>'id',
  '98100000-0000-4000-8000-000000000001', 'another adopter still sees their favorite for the same pet');
select set_config('request.jwt.claim.sub', '98000000-0000-4000-8000-000000000004', true);
select throws_ok($$select public.dopmi_match_favorites()$$, '42501', null, 'suspended accounts cannot query favorites');

select * from finish();
rollback;
