import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const legacyMigration = '20261017235000_legal_document_versions.sql';
const directory = new URL('../../supabase/migrations/', import.meta.url);
const sql = await readFile(new URL('../../supabase/dev-compatibility/20261112_legal_acceptance_build_382.sql', import.meta.url), 'utf8');
const shim = sql.replace(/^begin;\s*/i, '').replace(/commit;\s*$/i, '');
const current = ['terms-2026-11-01', 'privacy-2026-11-01-ubicacion'];
const older = ['terms-2026-10-17', 'privacy-2026-10-17'];
const live = ['terms-live-2026-11-01', 'privacy-live-2026-11-01-ubicacion-precisa'];
const owner = randomUUID(), other = randomUUID(), unconfirmed = randomUUID();
let db;

async function value(statement, args = []) {
  return (await db.query(statement, args)).rows[0]?.value;
}
const accept = (pair = current) => value('select public.accept_current_legal($1,$2) value', pair);
const profile = id => value('select to_jsonb(p) value from public.profiles p where id=$1', [id]);
const proofs = id => value('select coalesce(jsonb_agg(to_jsonb(c) order by privacy_version),$2::jsonb) value from private.dopmi_consents c where owner_id=$1', [id, '[]']);
const definition = name => value('select pg_get_functiondef($1::regprocedure) value', [name]);
const runtimeIsolated = async id => {
  await db.exec('reset role');
  return { profile: await profile(id), proofs: await proofs(id) };
};

async function asActor(id = owner, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
  await db.exec('set local role ' + role);
}
async function rejects(operation, code, message) {
  await db.exec('savepoint blocked');
  await assert.rejects(operation, { code, ...(message ? { message } : {}) });
  await db.exec('rollback to savepoint blocked; release savepoint blocked');
}

before(async () => {
  db = new PGlite();
  await db.exec([
    'create role anon; create role authenticated; create role service_role',
    'create schema auth; create schema storage',
    "create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz)",
    'create table auth.identities(user_id uuid,provider text,provider_id text)',
    'create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz)',
    "create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$",
    "create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('role',current_setting('role',true))$$",
    'grant usage on schema auth,public to anon,authenticated,service_role',
    'create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[])',
    'create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb)',
    'alter table storage.objects enable row level security',
    'grant usage on schema storage to anon,authenticated',
    'grant select on storage.objects to anon',
    'grant select,insert,update,delete on storage.objects to authenticated',
  ].join(';'));
  for (const file of (await readdir(directory)).filter(file => file.endsWith('.sql') && file <= legacyMigration).sort()) {
    try {
      await db.exec(await readFile(new URL(file, directory), 'utf8'));
    } catch (error) {
      throw new Error('Migration ' + file + ': ' + error.code + ' ' + error.message, { cause: error });
    }
  }
  for (const id of [owner, other, unconfirmed]) {
    const metadata = id === owner
      ? { terms_version: older[0], privacy_version: older[1], adult_confirmed: true }
      : { terms_version: current[0], privacy_version: current[1], terms_accepted: true, privacy_accepted: true };
    await db.query(
      'insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,$3,$4)',
      [id, id + '@example.invalid', id === unconfirmed ? null : new Date(), metadata],
    );
  }
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('legacy DEV patch adds only the authenticated exact-pair RPC and accepts retries without changing older proof', async () => {
  const kept = ['private.create_profile()', 'public.accept_current_terms()', 'public.dopmi_accept_legal(text,text,boolean)'];
  const before = await Promise.all(kept.map(definition));
  const historical = await runtimeIsolated(owner);
  const untouched = await runtimeIsolated(other);
  assert.equal(untouched.profile.privacy_version, null);
  await db.exec(shim);
  assert.deepEqual(await Promise.all(kept.map(definition)), before);
  assert.equal(await value("select to_regclass('private.dopmi_payment_environment') value"), null);
  assert.equal(await value("select to_regprocedure('private.dopmi_general_legal_pair_allowed(text,text)') value"), null);
  for (const role of ['anon', 'authenticated', 'service_role']) {
    assert.equal(await value("select has_function_privilege($1,'public.accept_current_legal(text,text)','execute') value", [role]), role === 'authenticated');
  }
  await asActor();
  const accepted = await accept();
  assert.equal(accepted.adult_confirmed, false);
  assert.equal(accepted.terms_accepted, true);
  assert.equal(accepted.privacy_accepted, true);
  assert.deepEqual(await accept(), accepted);
  const result = await runtimeIsolated(owner);
  assert.equal(result.profile.adult_confirmed_at, historical.profile.adult_confirmed_at);
  assert.equal(result.profile.terms_accepted_at, accepted.accepted_at);
  assert.equal(result.profile.privacy_accepted_at, accepted.accepted_at);
  assert.deepEqual(result.proofs.filter(p => p.adult_confirmed), historical.proofs);
  assert.equal(result.proofs.length, historical.proofs.length + 1);
  assert.deepEqual(await runtimeIsolated(other), untouched);

  await asActor(other);
  await accept();
  assert.equal((await runtimeIsolated(other)).profile.adult_confirmed_at, null);
});

test('the RPC rejects other pairs, no actor, unconfirmed or suspended accounts and incompatible existing adult proof', async () => {
  await db.exec(shim);
  await asActor(null, 'anon');
  await rejects(accept, '42501');
  await asActor(null);
  await rejects(accept, '22023');
  await asActor();
  for (const pair of [older, live, [null, current[1]], [current[0], 'privacy-2026-11-01']]) {
    await rejects(() => accept(pair), '22023');
  }
  await asActor(unconfirmed);
  await rejects(accept, '42501');
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [other]);
  await asActor(other);
  await rejects(accept, '42501');
  await db.exec('reset role');
  await db.query('insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed) values($1,$2,$3,true)', [owner, ...current]);
  await asActor();
  await rejects(accept, '42501');
});

test('LIVE profile and independent ledger evidence cannot be downgraded to TEST', async () => {
  await db.exec(shim);
  await db.query('update public.profiles set terms_version=$2, privacy_version=$3 where id=$1', [owner, ...live]);
  await db.query('insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed) values($1,$2,$3,false)', [other, ...live]);
  const snapshots = new Map();
  for (const id of [owner, other]) {
    snapshots.set(id, await runtimeIsolated(id));
    await asActor(id);
    await rejects(accept, '22023');
    assert.deepEqual(await runtimeIsolated(id), snapshots.get(id));
  }
});

test('preflight rejects binding, conflicting contract and trigger body drift; installed shim stops if binding appears', async () => {
  await db.exec('create table private.dopmi_payment_environment(environment text)');
  await rejects(() => db.exec(shim), 'P0001', /catálogo/);
  await db.exec('drop table private.dopmi_payment_environment');
  await db.exec("create function public.accept_current_legal(text,text) returns jsonb language sql as $$select '{}'::jsonb$$");
  await rejects(() => db.exec(shim), 'P0001', /catálogo/);
  await db.exec('drop function public.accept_current_legal(text,text)');
  await db.exec('savepoint trigger_drift');
  await db.exec('create or replace function private.create_profile() returns trigger language plpgsql security definer as $$begin return new; end;$$');
  await rejects(() => db.exec(shim), 'P0001', /registro Auth/);
  await db.exec('rollback to savepoint trigger_drift; release savepoint trigger_drift');
  await db.exec(shim);
  await rejects(() => db.exec(shim), 'P0001', /catálogo/);
  await db.exec('create table private.dopmi_payment_environment(environment text)');
  await asActor();
  await rejects(accept, '42501', /contrato legal vigente/);
});
