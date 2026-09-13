import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

// PostgreSQL-in-WASM tests exercise the production migration and RLS. The auth schema
// below only stands in for Supabase-owned objects; it is never deployed.
let db;
const alice = '00000000-0000-4000-8000-000000000001';
const bob = '00000000-0000-4000-8000-000000000002';
const staff = '00000000-0000-4000-8000-000000000003';
before(async () => {
  db = new PGlite();
  await db.exec(`
    create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb default '{}',
      email_confirmed_at timestamptz, last_sign_in_at timestamptz);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth, public to authenticated, anon;
    grant execute on function auth.uid() to authenticated, anon;
    -- Reproduce the existing legacy table, including a separate column grant.
    create table public.users(id uuid primary key references auth.users(id), email text, role text default 'user');
    alter table public.users enable row level security;
    create policy legacy_self on public.users to authenticated using (id = auth.uid());
    grant all privileges on public.users to anon, authenticated;
    grant update(role) on public.users to authenticated;
    create function public.legacy_signup() returns trigger language plpgsql security definer as $$
      begin insert into public.users(id,email) values(new.id,new.email); return new; end; $$;
    create trigger legacy_signup after insert on auth.users for each row execute function public.legacy_signup();
  `);
  await db.exec(await readFile(new URL('../../supabase/migrations/202609130001_identity.sql', import.meta.url), 'utf8'));
  await db.exec(await readFile(new URL('../../supabase/migrations/202609130002_legacy_identity_boundary.sql', import.meta.url), 'utf8'));
  await db.query(`insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
    ($1,'alice@dopmi.test','{"display_name":"Ana","is_admin":true,"dopmi_is_admin":true,"role":"admin","terms_version":"development-2026-09-13","terms_accepted":true}',now()),
    ($2,'bob@dopmi.test','{"display_name":"Beto"}',now()),
    ($3,'staff@dopmi.test','{"display_name":"Equipo"}',now())`, [alice,bob,staff]);
  await db.query('insert into private.admin_memberships(user_id) values ($1)', [staff]);
});
after(async () => { await db?.close(); });
async function asUser(id, fn, role = 'authenticated') {
  await db.exec('begin');
  try {
    await db.query(`select set_config('request.jwt.claim.sub',$1,true)`, [id]);
    await db.exec(`set local role ${role}`);
    return await fn();
  } finally { await db.exec('rollback'); }
}
test('signup creates a profile and records only the accepted development terms', async () => {
  const {rows} = await db.query('select * from public.profiles order by id');
  assert.equal(rows.length, 3);
  assert.equal(rows[0].display_name, 'Ana');
  assert.equal(rows[0].terms_version, 'development-2026-09-13');
  assert.equal(rows[1].terms_accepted_at, null);
});
test('each person reads only their own profile and can change their account experience', async () => {
  await asUser(alice, async () => {
    assert.equal((await db.query('select * from public.profiles')).rows.length, 1);
    assert.equal((await db.query(`update public.profiles set active_mode='rescuer',city='Monterrey' returning city`)).rows[0].city, 'Monterrey');
    assert.equal((await db.query(`update public.profiles set display_name='Changed' where id=$1 returning id`, [bob])).rows.length, 0);
  });
});
test('a client cannot set staff membership, account status, identity, or consent timestamps', async () => {
  for (const sql of [
    `insert into private.admin_memberships(user_id) values ('${alice}')`,
    `update public.profiles set account_status='suspended'`,
    `update public.profiles set id='${bob}'`,
    `update public.profiles set terms_accepted_at=now()`,
    `insert into public.profiles(id,display_name) values ('00000000-0000-4000-8000-000000000004','x')`,
  ]) await assert.rejects(asUser(alice, () => db.exec(sql)), /permission denied/i);
});
test('editable auth metadata never makes someone an administrator', async () => {
  await asUser(alice, async () => assert.equal((await db.query('select public.dopmi_is_admin() as allowed')).rows[0].allowed, false));
  await assert.rejects(asUser(alice, () => db.query('select public.admin_list_users()')), /Acceso administrativo/);
});
test('admin listing is authorized, paginated, literal-searchable and audited', async () => {
  await asUser(staff, async () => {
    const page = (await db.query(`select public.admin_list_users('',1,2) as data`)).rows[0].data;
    assert.equal(page.total, 3); assert.equal(page.users.length, 2);
    const search = (await db.query(`select public.admin_list_users('alice@',1,20) as data`)).rows[0].data;
    assert.equal(search.total, 1); assert.equal(search.users[0].id, alice);
    assert.equal((await db.query(`select public.admin_list_users('%',1,20) as data`)).rows[0].data.total, 0);
    await db.exec('reset role');
    assert.equal((await db.query('select count(*)::int as n from private.admin_access_log')).rows[0].n, 3);
  });
  await assert.rejects(asUser(staff, () => db.query(`select public.admin_list_users('',0,1000)`)), /inválida/);
});
test('suspension and revoked staff access take effect on the server', async () => {
  await db.query(`update public.profiles set account_status='suspended' where id=$1`, [staff]);
  await assert.rejects(asUser(staff, () => db.query('select public.admin_list_users()')), /Acceso administrativo/);
  await asUser(staff, async () => assert.equal((await db.query(`update public.profiles set city='x' returning id`)).rows.length, 0));
  await db.query(`update public.profiles set account_status='active' where id=$1`, [staff]);
  await db.query('update private.admin_memberships set active=false where user_id=$1', [staff]);
  await assert.rejects(asUser(staff, () => db.query('select public.admin_list_users()')), /Acceso administrativo/);
});
test('anonymous users cannot inspect identities or administrative data', async () => {
  for (const sql of ['select * from public.profiles', 'select public.admin_list_users()', 'select public.dopmi_is_admin()']) {
    await assert.rejects(asUser('', () => db.query(sql), 'anon'), /permission denied/i);
  }
});
test('profile validation and server-controlled consent are enforced', async () => {
  await assert.rejects(asUser(alice, () => db.exec(`update public.profiles set display_name='  '`)), /check constraint/);
  await asUser(bob, async () => {
    await db.exec('select public.accept_current_terms()');
    assert.equal((await db.query('select terms_version from public.profiles')).rows[0].terms_version, 'development-2026-09-13');
  });
});

test('legacy identity records remain but no client can read or promote a legacy role', async () => {
  assert.equal((await db.query('select count(*)::int as n from public.users')).rows[0].n, 3);
  for (const sql of ['select * from public.users', `update public.users set role='admin' where id='${alice}'`]) {
    await assert.rejects(asUser(alice, () => db.exec(sql)), /permission denied/i);
    await assert.rejects(asUser('', () => db.exec(sql), 'anon'), /permission denied/i);
  }
});

test('the legacy boundary migration also works on an empty Supabase project', async () => {
  const clean = new PGlite();
  try {
    await clean.exec('create role anon; create role authenticated;');
    await clean.exec(await readFile(new URL('../../supabase/migrations/202609130002_legacy_identity_boundary.sql', import.meta.url), 'utf8'));
  } finally { await clean.close(); }
});
