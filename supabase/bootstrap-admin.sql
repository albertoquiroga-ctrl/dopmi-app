-- Run only from an authenticated operator connection, after the account verifies its email.
-- psql "$DATABASE_URL" -v admin_email='you@example.com' -f supabase/bootstrap-admin.sql
-- Does not create an auth identity or accept a password.
\set ON_ERROR_STOP on
begin;
insert into private.admin_memberships(user_id)
select id from auth.users where lower(email) = lower(:'admin_email') and email_confirmed_at is not null
on conflict (user_id) do update set active = true;
-- Grant receipt: no row means the account does not exist or is not confirmed yet.
select u.email, m.active from private.admin_memberships m join auth.users u on u.id = m.user_id
where lower(u.email) = lower(:'admin_email');
commit;
