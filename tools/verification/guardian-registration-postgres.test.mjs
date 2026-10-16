import { before, after, beforeEach, afterEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import pg from 'pg';
import { registerGuardianRegistrationSqlCases } from './guardian-registration-sql-cases.mjs';

// Dedicated, disposable PostgreSQL only. Never discovers a Supabase container,
// accepts a remote URL or touches the two existing local Supabase databases.
assert.equal(process.env.DOPMI_RELEASE_POSTGRES_TEST, 'true', 'Explicit local test opt-in required');
const config = { host: '127.0.0.1', port: 55432, user: 'postgres',
  database: 'dopmi_release_20261015', connectionTimeoutMillis: 5000 };
const admin = new pg.Client(config);
const database = `dopmi_registration_test_${randomUUID().replaceAll('-', '')}`;
const client = new pg.Client({ ...config, database });
assert.equal(client.connectionParameters.host, config.host);
assert.equal(client.connectionParameters.port, config.port);
assert.equal(client.connectionParameters.database, database);
const db = { query: (sql, values) => client.query(sql, values), exec: sql => client.query(sql) };
const donor = randomUUID(), other = randomUUID(), staff = randomUUID(), rescuer = randomUUID();
const expense = '71000000-0000-4000-8000-000000000003';
const key = '72000000-0000-4000-8000-000000000001';
let created = false, connected = false, transaction = false;
const sources = [];

before(async () => {
  await admin.connect();
  assert.equal((await admin.query('select current_database() as name')).rows[0].name, config.database);
  await admin.query(`create database "${database}" template template0`);
  created = true;
  await client.connect(); connected = true;
  await db.exec(`set statement_timeout=20000; set lock_timeout=5000;
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
  const path = new URL('../../supabase/migrations/', import.meta.url);
  for (const name of (await readdir(path)).filter(x => x.endsWith('.sql')).sort()) {
    const bytes = await readFile(new URL(name, path));
    await db.exec(bytes.toString('utf8'));
    sources.push({ name, sha256: createHash('sha256').update(bytes).digest('hex') });
  }
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    select id::uuid,id||'@example.test',now(),'{"display_name":"Prueba","terms_accepted":true,"terms_version":"development-2026-09-13"}'
    from unnest($1::text[]) id`, [[donor, other, staff, rescuer]]);
  await db.query('insert into private.admin_memberships(user_id) values($1)', [staff]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
    ('71000000-0000-4000-8000-000000000001',$1,'verification','approved','{"public_name":"Refugio"}',null,0),
    ('71000000-0000-4000-8000-000000000002',$1,'case','approved','{"pet_name":"Luna"}',null,0),
    ($2,$1,'expense','approved','{"title":"Medicamentos"}','71000000-0000-4000-8000-000000000002',12000)`, [rescuer, expense]);
  await db.query(`insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
    values($1,'acct_test',true,true)`, [rescuer]);
  console.log(`PostgreSQL real: ${sources.length} migration bodies applied to a new disposable database; no provider or Auth HTTP calls`);
});
beforeEach(async () => { await db.exec('begin'); transaction = true; });
afterEach(async () => { if (transaction) { await db.exec('rollback'); transaction = false; } });
after(async () => {
  if (connected) { if (transaction) await db.exec('rollback'); await client.end(); }
  if (created) await admin.query(`drop database "${database}"`);
  await admin.end();
});
registerGuardianRegistrationSqlCases(() => db, { donor, other, staff, key });

test('native donation PostgreSQL: consent, full net reservation, ownership and bound intent survive replay', async () => {
  const requestKey = randomUUID();
  const call = async (op, fields = {}) => (await db.query(
    'select public.dopmi_oneoff_native_server($1,$2::jsonb) as value',
    [op, JSON.stringify({ actor: donor, key: requestKey, ...fields })])).rows[0].value;
  const payload = { expense_id: expense, gross_cents: 10000, consent: true,
    consent_version: 'oneoff-test-2026-10-15' };
  const prepared = await call('prepare', payload);
  assert.equal(prepared.reserved_cents, 9800);
  assert.equal(prepared.payment_flow, 'native');
  assert.deepEqual(await call('prepare', payload), prepared);
  assert.equal(await call('get', { actor: other }), null);
  const bound = await call('bind', { payment_intent_id: 'pi_SyntheticNative' });
  assert.equal(bound.stripe_payment_intent_id, 'pi_SyntheticNative');
  assert.equal((await call('get')).stripe_payment_intent_id, 'pi_SyntheticNative');
});

test('native donation PostgreSQL: concurrent same-key submissions share one reservation and provider slot', async () => {
  const a = new pg.Client({ ...config, database }), b = new pg.Client({ ...config, database });
  await a.connect(); await b.connect();
  try {
    for (const c of [a, b]) await c.query('set statement_timeout=10000; set lock_timeout=5000');
    const requestKey = randomUUID();
    const data = JSON.stringify({ actor: donor, key: requestKey, expense_id: expense,
      gross_cents: 2000, consent: true, consent_version: 'oneoff-test-2026-10-15' });
    await a.query('begin');
    const first = await a.query("select public.dopmi_oneoff_native_server('prepare',$1::jsonb) as value", [data]);
    let done = false;
    const waiting = b.query("select public.dopmi_oneoff_native_server('prepare',$1::jsonb) as value", [data])
      .then(r => { done = true; return r; });
    await a.query('select pg_sleep(0.15)');
    assert.equal(done, false);
    await a.query('commit');
    assert.equal((await waiting).rows[0].value.id, first.rows[0].value.id);
    assert.equal((await b.query(`select count(*)::int as n from private.dopmi_checkouts c
      join public.dopmi_donations d on d.id=c.donation_id where d.idempotency_key=$1`, [requestKey])).rows[0].n, 1);
  } finally { await a.query('rollback').catch(() => {}); await a.end(); await b.end(); }
});

test('registration PostgreSQL: two concurrent same-key prepares retain a single owner registration', async () => {
  const a = new pg.Client({ ...config, database }), b = new pg.Client({ ...config, database });
  await a.connect(); await b.connect();
  try {
    await a.query('set statement_timeout=10000; set lock_timeout=5000');
    await b.query('set statement_timeout=10000; set lock_timeout=5000');
    const owner = randomUUID(), requestKey = randomUUID();
    await a.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      values($1,'concurrency@example.test',now(),'{"display_name":"Concurrent","terms_accepted":true,"terms_version":"development-2026-09-13"}')`, [owner]);
    const data = JSON.stringify({ owner_id: owner, key: requestKey, gross_cents: 2000,
      consent: true, consent_version: 'guardian-registration-2026-10-14' });
    await a.query('begin');
    const first = await a.query("select public.dopmi_guardian_registration_server('prepare',$1::jsonb) as value", [data]);
    let secondFinished = false;
    const second = b.query("select public.dopmi_guardian_registration_server('prepare',$1::jsonb) as value", [data])
      .then(r => { secondFinished = true; return r; });
    await a.query('select pg_sleep(0.15)');
    assert.equal(secondFinished, false, 'second connection must wait for the owner transaction');
    await a.query('commit');
    assert.equal((await second).rows[0].value.id, first.rows[0].value.id);
    assert.equal((await b.query('select count(*)::int as n from private.dopmi_guardian_registrations where owner_id=$1', [owner])).rows[0].n, 1);
  } finally { await a.query('rollback').catch(() => {}); await a.end(); await b.end(); }
});

test('registration PostgreSQL: competing keys cannot create two open registrations', async () => {
  const a = new pg.Client({ ...config, database }), b = new pg.Client({ ...config, database });
  await a.connect(); await b.connect();
  try {
    await a.query('set statement_timeout=10000; set lock_timeout=5000');
    await b.query('set statement_timeout=10000; set lock_timeout=5000');
    const owner = randomUUID();
    await a.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      values($1,'competing@example.test',now(),'{"display_name":"Concurrent","terms_accepted":true,"terms_version":"development-2026-09-13"}')`, [owner]);
    const data = key => JSON.stringify({ owner_id: owner, key, gross_cents: 2000,
      consent: true, consent_version: 'guardian-registration-2026-10-14' });
    const outcomes = await Promise.allSettled([a, b].map(c => c.query(
      "select public.dopmi_guardian_registration_server('prepare',$1::jsonb) as value", [data(randomUUID())])));
    assert.equal(outcomes.filter(x => x.status === 'fulfilled').length, 1);
    assert.equal(outcomes.filter(x => x.status === 'rejected').length, 1);
    assert.equal((await a.query('select count(*)::int as n from private.dopmi_guardian_registrations where owner_id=$1', [owner])).rows[0].n, 1);
  } finally { await a.end(); await b.end(); }
});
