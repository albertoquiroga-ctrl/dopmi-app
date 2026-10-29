import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

const migration = '20261029002336_legal_environment_versions.sql';
const september = ['terms-2026-09-28', 'privacy-2026-09-28', true];
const current = ['terms-2026-10-17', 'privacy-2026-10-17', true];
const live = ['terms-live-2026-10-28', 'privacy-live-2026-10-28', true];
const owner = randomUUID(), other = randomUUID();
let db, historical, untouched;
const retained = ['public.dopmi_guardian_registration_cancellation_state()', 'public.dopmi_account_deletion_status()',
  'public.dopmi_account_deletion_server(text,jsonb)', 'public.dopmi_guardian_registration_server(text,jsonb)',
  'public.dopmi_payment_activity(boolean,timestamptz,text,uuid,integer)', 'private.dopmi_require_actor()'];
const profile = async (id = owner) => (await db.query('select * from public.profiles where id=$1', [id])).rows[0];
const proofs = async (id = owner) => (await db.query('select * from private.dopmi_consents where owner_id=$1 order by terms_version', [id])).rows;
const accept = async (pair = current) => (await db.query('select public.dopmi_accept_legal($1,$2,$3) value', pair)).rows[0].value;
async function signup(id, meta = {}) {
  await db.query('insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values($1,$2,$3,now())', [id, `${id}@example.test`, JSON.stringify(meta)]);
}
async function actor(id = owner, role = 'authenticated') {
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id]);
  await db.exec(`set local role ${role}`);
}
async function reset() { await db.exec('reset role'); }
async function configure(environment) {
  await reset();
  await db.query('update private.dopmi_payment_environment set environment=$1', [environment]);
}
async function rejected(action, expected = { code: '22023' }) {
  await db.exec('savepoint expected_failure');
  await assert.rejects(action(), expected);
  await db.exec('rollback to savepoint expected_failure');
}
const definition = async name => (await db.query('select pg_get_functiondef($1::regprocedure) value', [name])).rows[0].value;

before(async () => {
  db = new PGlite();
  // Reuse the isolated Auth/Storage bootstrap of the existing legal SQL suite.
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  const files = (await readdir(directory)).filter(v => v.endsWith('.sql')).sort();
  for (const file of files.filter(v => v < migration)) await db.exec(await readFile(new URL(file, directory), 'utf8'));
  await signup(owner, { terms_version: current[0], privacy_version: current[1], adult_confirmed: true });
  await signup(other);
  historical = { profile: await profile(), proofs: await proofs() };
  untouched = new Map();
  for (const name of retained) untouched.set(name, await definition(name));
  await db.exec(await readFile(new URL(migration, directory), 'utf8'));
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('legal migration preserves existing proofs, owner configuration and all exit/read/financial functions', async () => {
  assert.deepEqual({ profile: await profile(), proofs: await proofs() }, historical);
  for (const name of retained) assert.equal(await definition(name), untouched.get(name), name);
  assert.equal((await db.query('select public.dopmi_payment_environment_server() value')).rows[0].value.environment, 'test');
});

test('exact pairs are admitted only in their DB environment; mixed/unknown/minor accepts fail without writes', async () => {
  for (const environment of ['test', 'production']) {
    await configure(environment);
    const allowed = environment === 'test' ? [september, current] : [live];
    const denied = environment === 'test' ? [live] : [september, current];
    const mixed = [
      [live[0], current[1], true], [current[0], live[1], true], [live[0], september[1], true],
      [september[0], live[1], true], [current[0], september[1], true], [september[0], current[1], true],
      ['terms-2099-01-01', 'privacy-2099-01-01', true], [null, live[1], true], [live[0], null, true],
      [...allowed[0].slice(0, 2), false], [...allowed[0].slice(0, 2), null],
    ];
    for (const pair of [...denied, ...mixed]) {
      await actor(other);
      await rejected(() => accept(pair), /Aceptación legal inválida/);
      await reset();
      assert.equal((await profile(other)).terms_version, null);
      assert.equal((await proofs(other)).length, 0);
    }
    for (const pair of allowed) {
      const id = randomUUID(); await signup(id); await actor(id);
      const accepted = await accept(pair); assert.equal(accepted.terms_version, pair[0]);
      assert.equal(accepted.privacy_version, pair[1]);
      await reset(); assert.equal((await proofs(id)).length, 1);
    }
  }
});

test('TEST-to-LIVE upgrade retains historical proof and adult timestamp; replay uses immutable evidence', async () => {
  await configure('production'); await actor();
  const first = await accept(live); await reset();
  assert.deepEqual((await proofs()).find(p => p.terms_version === current[0]), historical.proofs[0]);
  const upgraded = await profile();
  assert.equal(upgraded.terms_version, live[0]); assert.equal(upgraded.privacy_version, live[1]);
  assert.equal(upgraded.adult_confirmed_at.getTime(), historical.profile.adult_confirmed_at.getTime());
  const originalProof = (await proofs()).find(p => p.terms_version === live[0]);
  // A pre-existing timestamp makes overwriting it with now() observable even
  // inside one test transaction, without sleeps or remote clocks.
  await db.query('update private.dopmi_consents set accepted_at=$2 where id=$1', [originalProof.id, '2026-09-01T00:00:00Z']);
  await actor(); const replay = await accept(live); await reset();
  assert.notEqual(replay.accepted_at, first.accepted_at);
  assert.equal(new Date(replay.accepted_at).toISOString(), '2026-09-01T00:00:00.000Z');
  await actor(); assert.deepEqual(await accept(live), replay); await reset();
  assert.equal((await proofs()).length, 2);
  assert.equal((await profile(other)).terms_version, null);
});

test('LIVE cannot downgrade after owner changes DB back to TEST, including retained audit evidence', async () => {
  await configure('production'); await actor(); await accept(live); await reset();
  const accepted = await profile(), evidence = await proofs();
  await configure('test'); await actor();
  for (const pair of [current, september]) await rejected(() => accept(pair), /versión más reciente/);
  await rejected(() => db.query('select public.accept_current_terms()'), /versión más reciente/);
  await reset(); assert.deepEqual(await profile(), accepted); assert.deepEqual(await proofs(), evidence);
  // A retained audit remains authoritative if maintenance clears a projection.
  await db.query('update public.profiles set terms_version=null,privacy_version=null where id=$1', [owner]);
  await actor(); await rejected(() => accept(current), /versión más reciente/);
  await rejected(() => db.query('select public.accept_current_terms()'), /versión más reciente/);
});

test('development RPC stays TEST-only; public acceptance still requires active auth.uid and has exact ACLs', async () => {
  await actor(other); await db.query('select public.accept_current_terms()'); await reset();
  assert.equal((await profile(other)).terms_version, 'development-2026-09-13');
  await configure('production'); await actor(other);
  await rejected(() => db.query('select public.accept_current_terms()'), /Aceptación legal inválida/);
  await reset();
  for (const status of ['suspended', 'deletion_requested', 'deleted']) {
    await db.query('update public.profiles set account_status=$2 where id=$1', [other, status]);
    await actor(other); await rejected(() => accept(live), /Cuenta no disponible/); await reset();
  }
  for (const role of ['anon', 'service_role']) {
    await actor(other, role); await rejected(() => accept(live), { code: '42501' }); await reset();
  }
  await actor(''); await rejected(() => accept(live), /Aceptación legal inválida/); await reset();
  for (const role of ['anon', 'authenticated', 'service_role']) {
    await actor(other, role);
    await rejected(() => db.query('select private.dopmi_legal_pair_allowed($1,$2)', live.slice(0, 2)), { code: '42501' });
    await rejected(() => db.query("update private.dopmi_payment_environment set environment='test'"), { code: '42501' });
    await reset();
  }
  await actor(other);
  await rejected(() => db.query('update public.profiles set terms_version=$1', [live[0]]), { code: '42501' });
  await rejected(() => db.query('select * from private.dopmi_consents'), { code: '42501' });
});

test('signup metadata admits same-environment pairs only; OAuth/mixed/crossed metadata remains unaccepted and never admin', async () => {
  for (const environment of ['test', 'production']) {
    await configure(environment);
    for (const pair of [september, current, live]) {
      const id = randomUUID();
      await signup(id, { terms_version: pair[0], privacy_version: pair[1], adult_confirmed: true,
        intent: 'rescue', role: 'admin', is_admin: true, environment: environment === 'test' ? 'production' : 'test' });
      const admitted = environment === 'test' ? pair !== live : pair === live;
      assert.equal((await profile(id)).terms_version, admitted ? pair[0] : null);
      assert.equal((await profile(id)).privacy_version, admitted ? pair[1] : null);
      assert.equal((await proofs(id)).length, admitted ? 1 : 0);
      await actor(id); assert.equal((await db.query('select public.dopmi_is_admin() value')).rows[0].value, false); await reset();
    }
    for (const metadata of [{}, { terms_version: live[0], privacy_version: current[1], adult_confirmed: true },
      { terms_version: current[0], privacy_version: live[1], adult_confirmed: true },
      { terms_version: live[0], privacy_version: live[1], adult_confirmed: false }]) {
      const id = randomUUID(); await signup(id, metadata);
      assert.equal((await profile(id)).terms_version, null); assert.equal((await proofs(id)).length, 0);
      await db.query('update auth.users set raw_user_meta_data=$2 where id=$1', [id, JSON.stringify({ terms_version: live[0], privacy_version: live[1], adult_confirmed: true, role: 'admin' })]);
      assert.equal((await profile(id)).terms_version, null);
    }
    const development = randomUUID(); await signup(development, { terms_version: 'development-2026-09-13', terms_accepted: true });
    assert.equal((await profile(development)).terms_version, environment === 'test' ? 'development-2026-09-13' : null);
    assert.equal((await proofs(development)).length, 0);
  }
});

test('historical TEST owners keep cancellation/history/deletion access in production without accepting again', async () => {
  await actor(other); await accept(); await reset();
  const evidence = await proofs(other);
  await configure('production');
  const id = randomUUID();
  await db.query(`insert into private.dopmi_guardian_registrations
    (id,owner_id,request_key,initial_gross_cents,gross_cents,consent_version)
    values($1,$2,$1,2000,2000,'guardian-registration-2026-10-14')`, [id, other]);
  await actor(other);
  assert.equal((await db.query('select public.dopmi_guardian_registration_cancellation_state() value')).rows[0].value.id, id);
  assert.deepEqual((await db.query('select public.dopmi_payment_activity() value')).rows[0].value, { items: [], next_cursor: null });
  assert.equal((await db.query('select public.dopmi_account_deletion_status() value')).rows[0].value, null);
  await reset();
  const canceled = (await db.query("select public.dopmi_guardian_registration_server('cancel',$1::jsonb) value", [JSON.stringify({ owner_id: other, id })])).rows[0].value;
  assert.equal(canceled.status, 'canceled');
  await db.query("select public.dopmi_account_deletion_server('request',$1::jsonb)", [JSON.stringify({ owner_id: other, request_key: randomUUID() })]);
  await actor(other);
  assert.equal((await db.query('select public.dopmi_account_deletion_status() value')).rows[0].value.status, 'procesando');
  await reset(); assert.deepEqual(await proofs(other), evidence);
  await actor(owner);
  assert.equal((await db.query('select public.dopmi_guardian_registration_cancellation_state() value')).rows[0].value, null);
  assert.equal((await db.query('select public.dopmi_account_deletion_status() value')).rows[0].value, null);
});
