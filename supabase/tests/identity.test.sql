begin;
set local search_path = public, extensions;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users(id, email, raw_user_meta_data, email_confirmed_at)
values ('10000000-0000-4000-8000-000000000001', 'identity-a@example.test', '{"display_name":"Ana","role":"admin"}', now()),
       ('10000000-0000-4000-8000-000000000002', 'identity-b@example.test', '{"display_name":"Beto"}', now());
select is((select count(*) from public.profiles where id in ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002')), 2::bigint, 'signup trigger creates profiles');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is((select count(*) from public.profiles), 1::bigint, 'RLS only exposes own profile');
select is(public.dopmi_is_admin(), false, 'editable metadata does not grant staff access');
select throws_ok('select public.admin_list_users()', '42501', 'Acceso administrativo requerido', 'non-admin RPC blocked');
select throws_ok($$update public.profiles set account_status='suspended'$$, '42501', 'permission denied for table profiles', 'status is not client-editable');
select throws_ok($$insert into private.admin_memberships(user_id) values ('10000000-0000-4000-8000-000000000001')$$, '42501', 'permission denied for schema private', 'membership cannot be self-granted');
select lives_ok($$update public.profiles set active_mode='rescuer',city='Monterrey'$$, 'own profile can be updated');
select is((select active_mode from public.profiles), 'rescuer', 'experience persisted');

reset role;
insert into private.admin_memberships(user_id) values ('10000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is(public.dopmi_is_admin(), true, 'server membership grants verified staff access');
select is((public.admin_list_users('identity-a@',1,20)->>'total')::integer, 1, 'admin can search identities');
reset role;
set local role anon;
select throws_ok('select * from public.profiles', '42501', 'permission denied for table profiles', 'anonymous profile access blocked');
reset role;
select * from finish();
rollback;
