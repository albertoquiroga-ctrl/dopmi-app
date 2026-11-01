import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

const migration = '20261101201331_generic_legal_consent.sql';
const pairs = {
  test: ['terms-2026-11-01', 'privacy-2026-11-01'],
  production: ['terms-live-2026-11-01', 'privacy-live-2026-11-01'],
};
const oldPairs = {
  test: ['terms-2026-10-17', 'privacy-2026-10-17'],
  production: ['terms-live-2026-10-28', 'privacy-live-2026-10-28'],
};
const owner = randomUUID(), other = randomUUID();
const retained = [
  'public.accept_current_terms()', 'public.dopmi_accept_legal(text,text,boolean)',
  'private.dopmi_legal_pair_allowed(text,text)', 'private.dopmi_require_actor()',
  'public.dopmi_payment_server(text,jsonb)', 'public.dopmi_oneoff_native_server(text,jsonb)',
  'public.dopmi_guardian_registration_server(text,jsonb)',
  'public.dopmi_guardian_registration_cancellation_state()',
  'public.dopmi_account_deletion_server(text,jsonb)',
];
let db, historical, definitions, environmentBefore;
const profile = async (id = owner) => (await db.query('select * from public.profiles where id=$1', [id])).rows[0];
const proofs = async (id = owner) => (await db.query('select * from private.dopmi_consents where owner_id=$1 order by terms_version', [id])).rows;
const definition = async name => (await db.query('select pg_get_functiondef($1::regprocedure) value', [name])).rows[0].value;
const accept = async pair => (await db.query('select public.accept_current_legal($1,$2) value', pair)).rows[0].value;
const generalMetadata = pair => ({ terms_version: pair[0], privacy_version: pair[1], terms_accepted: true, privacy_accepted: true });
async function signup(id = randomUUID(), meta = {}, confirmed = true) {
  await db.query('insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values($1,$2,$3,$4)',
    [id, `${id}@example.test`, JSON.stringify(meta), confirmed ? new Date() : null]);
  return id;
}
async function actor(id = owner, role = 'authenticated') {
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id]);
  await db.exec(`set local role ${role}`);
}
async function reset() { await db.exec('reset role'); }
async function configure(environment) {
  await reset(); await db.query('update private.dopmi_payment_environment set environment=$1', [environment]);
}
async function rejected(action, expected = { code: '42501' }) {
  await db.exec('savepoint expected_failure');
  await assert.rejects(action(), expected);
  await db.exec('rollback to savepoint expected_failure');
}
async function admit(id) {
  return (await db.query("select public.dopmi_payment_server('connect_admit',$1::jsonb) value", [JSON.stringify({ actor: id })])).rows[0].value;
}

before(async () => {
  db = new PGlite();
  // Real isolated PostgreSQL, using the same Auth/Storage boundary as the
  // existing integrated legal suites; no network, remote URL or existing data.
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.identities(user_id uuid,provider text,provider_id text);
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
  for (const file of (await readdir(directory)).filter(v => v.endsWith('.sql') && v < migration).sort()) {
    try { await db.exec(await readFile(new URL(file, directory), 'utf8')); }
    catch (error) { throw new Error(`Migration ${file}: ${error.code}: ${error.message}`); }
  }
  await signup(owner, { terms_version: oldPairs.test[0], privacy_version: oldPairs.test[1], adult_confirmed: true });
  await signup(other);
  await db.query("update public.profiles set adult_confirmed_at='2026-08-01T00:00:00Z' where id=$1", [owner]);
  historical = { profile: await profile(), proofs: await proofs() };
  environmentBefore = (await db.query('select to_jsonb(e) value from private.dopmi_payment_environment e')).rows;
  definitions = new Map();
  for (const name of retained) definitions.set(name, await definition(name));
  await db.exec(await readFile(new URL(migration, directory), 'utf8'));
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('additive migration preserves old RPCs, adult history, financial functions and environment without data rewrites', async () => {
  assert.deepEqual({ profile: await profile(), proofs: await proofs() }, historical);
  assert.deepEqual((await db.query('select to_jsonb(e) value from private.dopmi_payment_environment e')).rows, environmentBefore);
  for (const name of retained) assert.equal(await definition(name), definitions.get(name), name);
  assert.equal((await db.query('select count(*)::int n from public.dopmi_donations')).rows[0].n, 0);
  assert.equal((await db.query("select to_regprocedure('public.accept_current_legal()') value")).rows[0].value, null);
});

for (const environment of ['test', 'production']) {
  test(`general ${environment} acceptance records exact self-owned proof without an adult declaration and is idempotent`, async () => {
    await configure(environment);
    const id = await signup(); await actor(id);
    const accepted = await accept(pairs[environment]); await reset();
    assert.deepEqual(Object.keys(accepted).sort(), ['accepted_at', 'adult_confirmed', 'privacy_accepted', 'privacy_version', 'terms_accepted', 'terms_version']);
    assert.equal(accepted.terms_version, pairs[environment][0]);
    assert.equal(accepted.privacy_version, pairs[environment][1]);
    assert.equal(accepted.terms_accepted, true); assert.equal(accepted.privacy_accepted, true);
    assert.equal(accepted.adult_confirmed, false);
    const row = await profile(id), evidence = await proofs(id);
    assert.equal(row.adult_confirmed_at, null); assert.equal(evidence.length, 1);
    assert.equal(evidence[0].adult_confirmed, false);
    assert.equal(row.terms_accepted_at.getTime(), evidence[0].accepted_at.getTime());
    assert.equal(row.privacy_accepted_at.getTime(), evidence[0].accepted_at.getTime());
    await actor(id); assert.deepEqual(await accept(pairs[environment]), accepted); await reset();
    assert.deepEqual(await profile(id), row); assert.deepEqual(await proofs(id), evidence);
    assert.equal((await profile(other)).terms_version, null);
  });

  test(`new ${environment} signup requires both actual booleans; adult metadata and roles cannot replace generic consent`, async () => {
    await configure(environment);
    const allowed = pairs[environment], crossed = pairs[environment === 'test' ? 'production' : 'test'];
    for (const [metadata, expected] of [
      [generalMetadata(allowed), true],
      [{ ...generalMetadata(allowed), adult_confirmed: true, role: 'admin', is_admin: true, intent: 'rescue' }, true],
      [{ ...generalMetadata(allowed), terms_accepted: false }, false],
      [{ ...generalMetadata(allowed), privacy_accepted: false }, false],
      [{ ...generalMetadata(allowed), terms_accepted: 'true' }, false],
      [{ terms_version: allowed[0], privacy_version: allowed[1], adult_confirmed: true }, false],
      [{ ...generalMetadata(allowed), privacy_version: crossed[1] }, false],
      [generalMetadata(crossed), false],
      [{ role: 'admin', is_admin: true }, false],
    ]) {
      const id = await signup(undefined, metadata), row = await profile(id), evidence = await proofs(id);
      assert.equal(row.terms_version, expected ? allowed[0] : null);
      assert.equal(row.privacy_version, expected ? allowed[1] : null);
      assert.equal(row.adult_confirmed_at, null); assert.equal(evidence.length, expected ? 1 : 0);
      if (expected) assert.equal(evidence[0].adult_confirmed, false);
      await actor(id);
      assert.equal((await db.query('select public.dopmi_is_admin() value')).rows[0].value, false);
      await reset();
    }
  });

  test(`old ${environment} clients retain their explicit adult acceptance and cannot label generic documents as adult proof`, async () => {
    await configure(environment);
    const id = await signup(); await actor(id);
    await db.query('select public.dopmi_accept_legal($1,$2,true)', oldPairs[environment]); await reset();
    assert.equal((await profile(id)).terms_version, oldPairs[environment][0]);
    assert.notEqual((await profile(id)).adult_confirmed_at, null);
    assert.equal((await proofs(id))[0].adult_confirmed, true);
    await actor(id);
    await rejected(() => db.query('select public.dopmi_accept_legal($1,$2,false)', oldPairs[environment]), { code: '22023' });
    await rejected(() => db.query('select public.dopmi_accept_legal($1,$2,true)', pairs[environment]), { code: '22023' });
    await reset();
    const noAdult = await signup(undefined, { ...generalMetadata(oldPairs[environment]), adult_confirmed: false });
    assert.equal((await profile(noAdult)).terms_version, null); assert.deepEqual(await proofs(noAdult), []);
  });
}

test('new RPC rejects mixed, old, crossed, unknown and future documents without choosing a pair for the client', async () => {
  for (const environment of ['test', 'production']) {
    await configure(environment); await actor(other);
    for (const pair of [oldPairs.test, oldPairs.production, pairs[environment === 'test' ? 'production' : 'test'],
      [pairs.test[0], pairs.production[1]], [pairs.production[0], pairs.test[1]],
      ['terms-live-2099-01-01', 'privacy-live-2099-01-01'], [null, pairs[environment][1]], [pairs[environment][0], null]]) {
      await rejected(() => accept(pair), { code: '22023' });
    }
    await reset(); assert.equal((await profile(other)).terms_version, null); assert.deepEqual(await proofs(other), []);
  }
});

test('new RPC requires actual authenticated self, active profile and confirmed email; metadata and grants cannot forge consent', async () => {
  const unconfirmed = await signup(undefined, {}, false);
  for (const id of [unconfirmed, randomUUID()]) {
    await actor(id); await rejected(() => accept(pairs.test)); await reset();
  }
  for (const status of ['suspended', 'deletion_requested', 'deleted']) {
    await db.query('update public.profiles set account_status=$2 where id=$1', [other, status]);
    await actor(other); await rejected(() => accept(pairs.test)); await reset();
  }
  await db.query("update public.profiles set account_status='active' where id=$1", [other]);
  for (const role of ['anon', 'service_role']) {
    await actor(other, role); await rejected(() => accept(pairs.test)); await reset();
  }
  await actor(''); await rejected(() => accept(pairs.test), { code: '22023' }); await reset();
  for (const role of ['anon', 'authenticated', 'service_role']) {
    await actor(other, role);
    await rejected(() => db.query('select private.dopmi_general_legal_pair_allowed($1,$2)', pairs.test));
    await rejected(() => db.query('select private.dopmi_require_current_legal($1)', [other]));
    await reset();
  }
  await actor(other);
  await rejected(() => db.query('update public.profiles set adult_confirmed_at=now(),terms_version=$1 where id=$2', [pairs.test[0], other]));
  await rejected(() => db.query('insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed) values($1,$2,$3,false)', [other, ...pairs.test]));
  await rejected(() => db.query("update private.dopmi_payment_environment set environment='production'"));
  await reset(); assert.deepEqual(await proofs(other), []);
});

test('generic upgrade preserves every historical adult timestamp and consent; replay keeps the original generic proof', async () => {
  await configure('production'); await actor(); await accept(pairs.production); await reset();
  const upgraded = await profile(), evidence = await proofs();
  assert.equal(upgraded.adult_confirmed_at.getTime(), historical.profile.adult_confirmed_at.getTime());
  assert.deepEqual(evidence.find(c => c.terms_version === oldPairs.test[0]), historical.proofs[0]);
  assert.equal(evidence.find(c => c.terms_version === pairs.production[0]).adult_confirmed, false);
  await db.query('update private.dopmi_consents set accepted_at=$2 where owner_id=$1 and terms_version=$3', [owner, '2026-09-01T00:00:00Z', pairs.production[0]]);
  await actor(); const replay = await accept(pairs.production); await reset();
  assert.equal(new Date(replay.accepted_at).toISOString(), '2026-09-01T00:00:00.000Z');
  assert.equal((await profile()).adult_confirmed_at.getTime(), historical.profile.adult_confirmed_at.getTime());
  await configure('test'); await actor();
  await rejected(() => accept(pairs.test), { code: '22023' }); await reset();
  await db.query('update public.profiles set terms_version=null,privacy_version=null where id=$1', [owner]);
  await actor(); await rejected(() => accept(pairs.test), { code: '22023' });
});

test('PROD finance admits genuine general evidence with no adulthood and rejects forged, foreign or stale projection', async () => {
  await configure('production'); const id = await signup(); await actor(id); await accept(pairs.production); await reset();
  assert.equal((await profile(id)).adult_confirmed_at, null);
  await actor(id, 'service_role'); assert.deepEqual(await admit(id), { allowed: true }); await reset();
  for (const mutation of [
    "update public.profiles set account_status='suspended' where id=$1",
    'update auth.users set email_confirmed_at=null where id=$1',
    "update public.profiles set privacy_version='privacy-live-2026-10-28' where id=$1",
    "update public.profiles set terms_accepted_at=terms_accepted_at-interval '1 second' where id=$1",
    "update public.profiles set privacy_accepted_at=privacy_accepted_at-interval '1 second' where id=$1",
    'update private.dopmi_consents set adult_confirmed=true where owner_id=$1',
    `update private.dopmi_consents set owner_id='${other}' where owner_id=$1`,
    'delete from private.dopmi_consents where owner_id=$1',
  ]) {
    await db.exec('savepoint forged_proof'); await db.query(mutation, [id]);
    await actor(id, 'service_role'); await rejected(() => admit(id)); await reset();
    await db.exec('rollback to savepoint forged_proof');
  }
  await actor(id, 'service_role'); await rejected(() => admit(other)); await reset();
  assert.equal((await db.query('select count(*)::int n from public.dopmi_donations')).rows[0].n, 0);
});

test('TEST generic consent cannot satisfy PROD finance, while exact LIVE upgrade needs no fabricated adult evidence', async () => {
  await actor(other); await accept(pairs.test); await reset();
  const testProof = (await proofs(other))[0]; await configure('production');
  await actor(other, 'service_role'); await rejected(() => admit(other)); await reset();
  await actor(other); await accept(pairs.production); await reset();
  await actor(other, 'service_role'); assert.deepEqual(await admit(other), { allowed: true }); await reset();
  assert.equal((await profile(other)).adult_confirmed_at, null);
  assert.deepEqual((await proofs(other)).find(c => c.terms_version === pairs.test[0]), testProof);
  assert.ok((await proofs(other)).every(c => c.adult_confirmed === false));
});

test('new RPC does not overwrite malformed pre-existing general proof or manufacture a matching adult declaration', async () => {
  await db.query('insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed) values($1,$2,$3,true)', [other, ...pairs.test]);
  const beforeProof = await proofs(other);
  await actor(other); await rejected(() => accept(pairs.test)); await reset();
  assert.deepEqual(await proofs(other), beforeProof);
  assert.equal((await profile(other)).terms_version, null);
  assert.equal((await profile(other)).adult_confirmed_at, null);
});
