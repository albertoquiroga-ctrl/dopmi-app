begin;
set local search_path = public, extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok(not has_function_privilege('anon', 'public.dopmi_rescuer_funnel(text)', 'execute'), 'anonymous cannot read an owner funnel');
select ok(has_function_privilege('authenticated', 'public.dopmi_rescuer_funnel(text)', 'execute'), 'authenticated can request their own funnel');
select ok(not has_function_privilege('anon', 'public.dopmi_record_adoption_view(uuid,boolean)', 'execute'), 'anonymous cannot register a view');
select ok(has_function_privilege('authenticated', 'public.dopmi_record_adoption_view(uuid,boolean)', 'execute'), 'authenticated can register a consented view');
select ok(not has_function_privilege('authenticated', 'private.dopmi_funnel_period(text,timestamptz)', 'execute'), 'client cannot call the private period helper');
select ok(not has_function_privilege('anon', 'private.dopmi_funnel_period(text,timestamptz)', 'execute'), 'anonymous cannot call the private period helper');
select ok(not has_table_privilege('anon', 'private.dopmi_adoption_view_days', 'select'), 'anonymous cannot inspect daily actors');
select ok(not has_table_privilege('authenticated', 'private.dopmi_adoption_view_days', 'select'), 'client cannot inspect daily actors');
select ok(not has_table_privilege('authenticated', 'private.dopmi_adoption_view_days', 'insert'), 'client cannot forge daily observations');
select ok(not has_table_privilege('authenticated', 'private.dopmi_adoption_view_day_start', 'select'), 'measurement start remains private');
select ok((select relrowsecurity from pg_class where oid = 'private.dopmi_adoption_view_days'::regclass), 'daily observations retain RLS');
select ok((select relrowsecurity from pg_class where oid = 'private.dopmi_adoption_view_day_start'::regclass), 'measurement singleton retains RLS');

select is((select period_start from private.dopmi_funnel_period('yesterday', '2026-10-07T03:33:46Z')), '2026-10-05T06:00:00Z'::timestamptz, 'yesterday starts on the previous Mexico calendar day');
select is((select period_end from private.dopmi_funnel_period('yesterday', '2026-10-07T03:33:46Z')), '2026-10-06T06:00:00Z'::timestamptz, 'yesterday excludes the current Mexico calendar day');
select is((select period_start from private.dopmi_funnel_period('week', '2026-10-07T03:33:46Z')), '2026-10-05T06:00:00Z'::timestamptz, 'week starts on Monday in Mexico');
select is((select period_start from private.dopmi_funnel_period('month', '2026-10-07T03:33:46Z')), '2026-10-01T06:00:00Z'::timestamptz, 'month starts in Mexico rather than UTC');
select is((select period_start from private.dopmi_funnel_period('week', '2026-10-05T05:15:00Z')), '2026-09-28T06:00:00Z'::timestamptz, 'UTC Monday still belongs to the previous week before Mexico midnight');
select is((select period_end from private.dopmi_funnel_period('month', '2026-10-07T03:33:46Z')), '2026-10-07T03:33:46Z'::timestamptz, 'current month ends at the observation instant');
select throws_ok($$select * from private.dopmi_funnel_period('all', now())$$, '22023', 'Período inválido', 'unknown period rejected');
select throws_ok($$select * from private.dopmi_funnel_period(null, now())$$, '22023', 'Período inválido', 'null period rejected');

insert into auth.users(id, email, raw_user_meta_data, email_confirmed_at)
values
  ('93000000-0000-4000-8000-000000000001', 'funnel-owner-a@example.test', '{"display_name":"Owner A","terms_accepted":true,"terms_version":"development-2026-09-13","role":"admin"}', now()),
  ('93000000-0000-4000-8000-000000000002', 'funnel-owner-b@example.test', '{"display_name":"Owner B","terms_accepted":true,"terms_version":"development-2026-09-13"}', now()),
  ('93000000-0000-4000-8000-000000000003', 'funnel-viewer@example.test', '{"display_name":"Viewer","terms_accepted":true,"terms_version":"development-2026-09-13"}', now());
insert into public.dopmi_adoptions(id, owner_id, pet_name, status)
values
  ('93100000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', 'Luna', 'published'),
  ('93100000-0000-4000-8000-000000000002', '93000000-0000-4000-8000-000000000002', 'Toby', 'published'),
  ('93100000-0000-4000-8000-000000000003', '93000000-0000-4000-8000-000000000001', 'Rocky', 'published');
-- Lifetime evidence is intentionally not copied into the new daily journal.
insert into private.dopmi_adoption_views(post_id, actor_id)
values ('93100000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000003');

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok($$select public.dopmi_rescuer_funnel('month')$$, '42501', null, 'anonymous invocation rejected');
reset role;
set local role authenticated;
select throws_ok($$select public.dopmi_rescuer_funnel('month')$$, '42501', 'Cuenta activa y confirmada requerida', 'authenticated role without an actor is insufficient');
select set_config('request.jwt.claim.sub', '93000000-0000-4000-8000-000000000001', true);
select throws_ok($$select public.dopmi_rescuer_funnel('all')$$, '22023', 'Período inválido', 'public RPC rejects an unknown period');
select is((public.dopmi_rescuer_funnel('month')->'adoption'->>'views')::bigint, 0::bigint, 'lifetime evidence does not invent period views');
select is(public.dopmi_rescuer_funnel()->>'period', 'month', 'default public period is month');

select set_config('request.jwt.claim.sub', '93000000-0000-4000-8000-000000000003', true);
select public.dopmi_record_adoption_view('93100000-0000-4000-8000-000000000001', true);
reset role;
select is((select count(*) from private.dopmi_adoption_view_days), 0::bigint, 'per-call consent does not replace saved consent');
set local role authenticated;
select public.dopmi_set_adoption_measurement(true);
select public.dopmi_record_adoption_view('93100000-0000-4000-8000-000000000001', false);
reset role;
select is((select count(*) from private.dopmi_adoption_view_days), 0::bigint, 'saved consent does not replace per-call consent');
set local role authenticated;
select public.dopmi_record_adoption_view('93100000-0000-4000-8000-000000000001', true);
select public.dopmi_record_adoption_view('93100000-0000-4000-8000-000000000001', true);
select public.dopmi_record_adoption_view('93100000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claim.sub', '93000000-0000-4000-8000-000000000001', true);
select public.dopmi_set_adoption_measurement(true);
select public.dopmi_record_adoption_view('93100000-0000-4000-8000-000000000001', true);
reset role;
select is((select count(*) from private.dopmi_adoption_view_days where post_id = '93100000-0000-4000-8000-000000000001'), 1::bigint, 'retries deduplicate and owner views are ignored');

-- Expired observations and favorites must not inflate the current month.
insert into private.dopmi_adoption_view_days(post_id, actor_id, viewed_on)
select '93100000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000002', timezone('America/Mexico_City', period_start)::date - 1
from private.dopmi_funnel_period('month', now());
insert into public.dopmi_favorites(user_id, post_id, created_at)
select actor_id, post_id, case when expired then period_start - interval '1 day' else period_start + (period_end - period_start) / 2 end
from (values
  ('93000000-0000-4000-8000-000000000003'::uuid, '93100000-0000-4000-8000-000000000001'::uuid, false),
  ('93000000-0000-4000-8000-000000000003'::uuid, '93100000-0000-4000-8000-000000000002'::uuid, false),
  ('93000000-0000-4000-8000-000000000001'::uuid, '93100000-0000-4000-8000-000000000001'::uuid, false),
  ('93000000-0000-4000-8000-000000000002'::uuid, '93100000-0000-4000-8000-000000000001'::uuid, true)
) fixture(actor_id, post_id, expired)
cross join private.dopmi_funnel_period('month', now());
insert into public.dopmi_threads(id, post_id, owner_id, adopter_id, pet_name)
values
  ('93200000-0000-4000-8000-000000000001', '93100000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000003', 'Luna'),
  ('93200000-0000-4000-8000-000000000002', '93100000-0000-4000-8000-000000000002', '93000000-0000-4000-8000-000000000002', '93000000-0000-4000-8000-000000000003', 'Toby'),
  ('93200000-0000-4000-8000-000000000003', '93100000-0000-4000-8000-000000000003', '93000000-0000-4000-8000-000000000001', '93000000-0000-4000-8000-000000000002', 'Rocky');
insert into public.dopmi_messages(id, thread_id, sender_id, body, created_at)
select id, thread_id, sender_id, 'Mensaje sintético local', period_start + (period_end - period_start) / 2
from (values
  ('93300000-0000-4000-8000-000000000001'::uuid, '93200000-0000-4000-8000-000000000001'::uuid, '93000000-0000-4000-8000-000000000003'::uuid),
  ('93300000-0000-4000-8000-000000000002'::uuid, '93200000-0000-4000-8000-000000000001'::uuid, '93000000-0000-4000-8000-000000000003'::uuid),
  ('93300000-0000-4000-8000-000000000003'::uuid, '93200000-0000-4000-8000-000000000002'::uuid, '93000000-0000-4000-8000-000000000003'::uuid),
  ('93300000-0000-4000-8000-000000000004'::uuid, '93200000-0000-4000-8000-000000000003'::uuid, '93000000-0000-4000-8000-000000000001'::uuid)
) fixture(id, thread_id, sender_id)
cross join private.dopmi_funnel_period('month', now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '93000000-0000-4000-8000-000000000001', true);
select is((public.dopmi_rescuer_funnel('month')->'adoption'->>'views')::bigint, 1::bigint, 'owner A sees only current consented views of own posts');
select is((public.dopmi_rescuer_funnel('month')->'adoption'->>'favorites')::bigint, 1::bigint, 'owner A excludes old and self favorites and other owners');
select is((public.dopmi_rescuer_funnel('month')->'adoption'->>'messages')::bigint, 1::bigint, 'owner A counts unique adopter contacts rather than replies or messages');
select is(public.dopmi_is_admin(), false, 'editable admin metadata does not grant staff privileges');
select set_config('request.jwt.claim.sub', '93000000-0000-4000-8000-000000000002', true);
select is((public.dopmi_rescuer_funnel('month')->'adoption'->>'views')::bigint, 1::bigint, 'owner B cannot see owner A observations');
select is((public.dopmi_rescuer_funnel('month')->'adoption'->>'favorites')::bigint, 1::bigint, 'owner B cannot see owner A favorites');
select is((public.dopmi_rescuer_funnel('month')->'adoption'->>'messages')::bigint, 1::bigint, 'owner B cannot see owner A contacts');
select set_config('request.jwt.claim.sub', '93000000-0000-4000-8000-000000000003', true);
select is(public.dopmi_rescuer_funnel('month')->'adoption', '{"views":0,"favorites":0,"messages":0,"adoptions":0}'::jsonb, 'participating viewer cannot request another owner funnel');
select is(public.dopmi_rescuer_funnel('month')->'support', '{"donors":0,"raised_cents":0,"active":0,"completed":0}'::jsonb, 'unrelated viewer has no support metrics');
reset role;

select * from finish();
rollback;
