import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const migration = '20261028232540_production_payment_environment.sql';
const donor = 'e8000000-0000-4000-8000-000000000001';
const rescuer = 'e8000000-0000-4000-8000-000000000002';
const other = 'e8000000-0000-4000-8000-000000000003';
const caseId = 'e8100000-0000-4000-8000-000000000002';
const expense = 'e8100000-0000-4000-8000-000000000003';
const historicalKey = 'e8200000-0000-4000-8000-000000000001';
const key = 'e8200000-0000-4000-8000-000000000002';
const testVersion = 'oneoff-test-2026-10-15';
const liveVersion = 'oneoff-live-2026-10-28';
const returnUrl = 'https://example.test/functions/v1/payment-return';
const consentTargets = ['dopmi_oneoff_native_server', 'dopmi_oneoff_case_server'];
const checkoutTargets = ['dopmi_guardian_activation_server', 'dopmi_guardian_method_server', 'dopmi_saved_card_server'];
let db, history, definitions;

const rpc = async (name, operation, fields = {}) => (await db.query(
  `select public.${name}($1,$2::jsonb) value`, [operation, JSON.stringify(fields)])).rows[0].value;
const prepare = (name, fields = {}) => rpc(name, 'prepare', {
  actor: donor, key, gross_cents: 1000, consent: true, consent_version: testVersion,
  ...(name === 'dopmi_oneoff_case_server' ? { case_id: caseId } : { expense_id: expense }), ...fields,
});
const environment = async () => (await db.query('select public.dopmi_payment_environment_server() value')).rows[0].value;
const snapshot = async () => (await db.query(`select to_jsonb(d) donation,to_jsonb(c) checkout
  from public.dopmi_donations d join private.dopmi_checkouts c on c.donation_id=d.id
  where d.idempotency_key=$1`, [historicalKey])).rows[0];
async function rejected(action, expected) {
  await db.exec('savepoint expected_failure');
  await assert.rejects(action(), expected);
  await db.exec('rollback to savepoint expected_failure');
}

before(async () => {
  db = new PGlite();
  // Same isolated PostgreSQL bootstrap used by oneoff-native-sql.test.mjs.
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
  assert.equal(files.filter(v => v.endsWith('_production_payment_environment.sql')).length, 1);
  for (const file of files.filter(v => v < migration)) await db.exec(await readFile(new URL(file, directory), 'utf8'));
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    select id::uuid,id||'@example.test',now(),$2::jsonb from unnest($1::text[]) id`,
  [[donor, rescuer, other], JSON.stringify({ display_name: 'Prueba SQL', terms_accepted: true, terms_version: 'development-2026-09-13' })]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
    ('e8100000-0000-4000-8000-000000000001',$1,'verification','approved','{"public_name":"Refugio"}',null,0),
    ($2,$1,'case','approved','{"pet_name":"Luna"}',null,0),
    ($3,$1,'expense','approved','{"title":"Medicamentos"}',$2,100000)`, [rescuer, caseId, expense]);
  await db.query(`insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
    values($1,'acct_environment',true,true)`, [rescuer]);
  await prepare('dopmi_oneoff_native_server', { key: historicalKey });
  history = await snapshot();
  definitions = new Map();
  for (const name of [...consentTargets, ...checkoutTargets]) definitions.set(name,
    (await db.query('select pg_get_functiondef($1::regprocedure) definition', [`public.${name}(text,jsonb)`])).rows[0].definition);
  await db.exec(await readFile(new URL(migration, directory), 'utf8'));
  for (const file of files.filter(v => v > migration)) await db.exec(await readFile(new URL(file, directory), 'utf8'));
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('SQL environment starts TEST, has one owner-controlled row, and exposes no setter', async () => {
  assert.deepEqual(await environment(), { environment: 'test', expected_livemode: false, oneoff_consent_version: testVersion });
  assert.equal((await db.query('select count(*)::int n from private.dopmi_payment_environment')).rows[0].n, 1);
  assert.equal((await db.query("select relrowsecurity from pg_class where oid='private.dopmi_payment_environment'::regclass")).rows[0].relrowsecurity, true);
  assert.deepEqual((await db.query("select proname,prosecdef,proconfig from pg_proc where proname like 'dopmi_payment_environment%' order by proname")).rows,
    [{ proname: 'dopmi_payment_environment_server', prosecdef: true, proconfig: ['search_path=""'] }]);
  await rejected(() => db.query("update private.dopmi_payment_environment set environment='live'"), { code: '23514' });
  await rejected(() => db.query("insert into private.dopmi_payment_environment values(false,'test')"), { code: '23514' });
  await rejected(() => db.query("insert into private.dopmi_payment_environment values(true,'test')"), { code: '23505' });
  await db.exec("update private.dopmi_payment_environment set environment='production'");
  assert.deepEqual(await environment(), { environment: 'production', expected_livemode: true, oneoff_consent_version: liveVersion });
});

test('SQL service reads binding only; anon/auth cannot execute, read or change it', async () => {
  for (const role of ['anon', 'authenticated', 'service_role']) {
    await db.exec(`set local role ${role}`);
    if (role === 'service_role') assert.equal((await environment()).environment, 'test');
    else await rejected(environment, { code: '42501' });
    await rejected(() => db.query('select * from private.dopmi_payment_environment'), { code: '42501' });
    await rejected(() => db.query("update private.dopmi_payment_environment set environment='production'"), { code: '42501' });
    await rejected(() => db.query("insert into private.dopmi_payment_environment values(true,'production')"), { code: '42501' });
    await rejected(() => db.query('delete from private.dopmi_payment_environment'), { code: '42501' });
    await db.exec('reset role');
  }
});

test('SQL additive patch preserves historical evidence and every unrelated function guard exactly', async () => {
  assert.deepEqual(await snapshot(), history);
  for (const name of [...consentTargets, ...checkoutTargets]) {
    const actual = (await db.query('select pg_get_functiondef($1::regprocedure) definition', [`public.${name}(text,jsonb)`])).rows[0].definition;
    const expected = consentTargets.includes(name)
      ? definitions.get(name).replace("data->>'consent_version' is distinct from 'oneoff-test-2026-10-15'", "data->>'consent_version' is distinct from (public.dopmi_payment_environment_server()->>'oneoff_consent_version')")
      : definitions.get(name).replace('^cs_(test_)?[A-Za-z0-9]+$', '^cs_(test_|live_)?[A-Za-z0-9]+$');
    assert.equal(actual, expected, name);
    assert.equal((await db.query('select has_function_privilege($1,$2,\'EXECUTE\') allowed', ['service_role', `public.${name}(text,jsonb)`])).rows[0].allowed, true);
    for (const role of ['anon', 'authenticated']) assert.equal((await db.query(
      'select has_function_privilege($1,$2,\'EXECUTE\') allowed', [role, `public.${name}(text,jsonb)`])).rows[0].allowed, false);
  }
});

for (const name of consentTargets) {
  test(`SQL ${name} binds new consent to TEST/production and keeps stable retries`, async () => {
    await rejected(() => prepare(name, { consent_version: liveVersion }), /Confirma el importe/);
    const first = await prepare(name);
    assert.equal(first.consent_version, testVersion);
    assert.equal(first.platform_fee_cents, 20);
    assert.equal(first.reserved_cents, 980);
    assert.deepEqual(await prepare(name), first);
    await db.exec("update private.dopmi_payment_environment set environment='production'");
    await rejected(() => prepare(name), /Confirma el importe/);
    const productionKey = 'e8200000-0000-4000-8000-000000000003';
    await rejected(() => prepare(name, { key: productionKey, consent_version: liveVersion, consent: false }), /Confirma el importe/);
    const live = await prepare(name, { key: productionKey, consent_version: liveVersion });
    assert.equal(live.consent_version, liveVersion);
    assert.equal(live.payment_status, 'pending');
    assert.deepEqual(await prepare(name, { key: productionKey, consent_version: liveVersion }), live);
    assert.equal(await rpc(name, 'get', { actor: other, key: productionKey }), null);
    await rejected(() => prepare(name, { key: productionKey, consent_version: liveVersion, gross_cents: 2000 }), /otros datos/);
    await rejected(() => prepare(name, { key: other, consent_version: liveVersion, gross_cents: 1000000 }), /asignarse completo/);
    assert.deepEqual(await snapshot(), history);
    assert.equal((await rpc('dopmi_oneoff_native_server', 'get', { actor: donor, key: historicalKey })).consent_version, testVersion);
    await db.exec("update private.dopmi_payment_environment set environment='test'");
    await rejected(() => prepare(name, { key: productionKey, consent_version: liveVersion }), /Confirma el importe/);
    assert.equal((await rpc(name, 'get', { actor: donor, key: productionKey })).consent_version, liveVersion);
  });
}

async function checkoutFixtures() {
  const activation = await rpc('dopmi_guardian_activation_server', 'prepare', {
    donor_id: donor, key, gross_cents: 2000, consent: true, consent_version: 'guardian-2026-09-24', return_url: returnUrl,
  });
  const a = await rpc('dopmi_guardian_activation_server', 'claim_checkout', { cycle_id: activation.cycle_id });
  const otherActivation = await rpc('dopmi_guardian_activation_server', 'prepare', {
    donor_id: other, key, gross_cents: 2000, consent: true, consent_version: 'guardian-2026-09-24', return_url: returnUrl,
  });
  await db.query(`insert into private.dopmi_guardian_subscriptions(donor_id,stripe_customer_id,stripe_subscription_id,stripe_price_id,
    gross_cents,initial_payment_intent_id,initial_charge_id,management_revision)
    values($1,'cus_environment','sub_environment','price_environment',1000,'pi_environment','ch_environment',1)`, [other]);
  await db.query(`insert into private.dopmi_guardian_schedule_jobs(cycle_id,status,charge_created,next_billing_at,price_id,subscription_id)
    values($1,'ready',1700000000,now()+interval '1 month','price_environment','sub_environment')`, [otherActivation.cycle_id]);
  const job = (await db.query(`insert into private.dopmi_guardian_method_jobs(donor_id,subscription_id,request_key,revision,
    consent_version,expires_at,return_url,checkout_attempts) values($1,'sub_environment',$2,1,'guardian-2026-09-24',
    now()+interval '35 minutes',$3,1) returning id`, [other, key, returnUrl])).rows[0];
  const m = await rpc('dopmi_guardian_method_server', 'claim', { job_id: job.id });
  const saved = await rpc('dopmi_saved_card_server', 'prepare', {
    owner_id: other, key, consent: true, consent_version: 'saved-cards-2026-10-03', return_url: returnUrl,
  });
  const s = await rpc('dopmi_saved_card_server', 'claim', { id: saved.id });
  return [
    { table: 'dopmi_guardian_activations', column: 'cycle_id', id: a.cycle_id, name: checkoutTargets[0], operation: 'save_checkout', fields: { cycle_id: a.cycle_id, lease: a.lease } },
    { table: 'dopmi_guardian_method_jobs', column: 'id', id: job.id, name: checkoutTargets[1], operation: 'session', fields: { job_id: job.id, lease: m.lease } },
    { table: 'dopmi_saved_card_jobs', column: 'id', id: s.id, name: checkoutTargets[2], operation: 'session', fields: { id: s.id, lease: s.lease } },
  ];
}

test('SQL all three Checkout RPCs and constraints accept LIVE and historical ids, reject malformed ids, preserve bindings', async () => {
  const fixtures = await checkoutFixtures();
  for (const [index, fixture] of fixtures.entries()) {
    const { table, column, id, name, operation, fields } = fixture;
    for (const session of ['cs_old123', 'cs_test_old123', 'cs_live_new123']) {
      await db.exec('savepoint format_case');
      const sessionId = session + index;
      const data = { ...fields, session_id: sessionId };
      const value = await rpc(name, operation, data);
      assert.equal(value.session_id, sessionId);
      assert.equal((await rpc(name, operation, data)).session_id, sessionId);
      await rejected(() => rpc(name, operation, { ...data, session_id: 'cs_live_Alien123' }), /vinculado|coincide/);
      await db.exec('rollback to savepoint format_case');
    }
    for (const sessionId of ['cs_live_', 'cs_test_', 'cs_bad_id', 'cs_live_x/y', 'pi_live_123', 'cs_live_x\n']) {
      await rejected(() => rpc(name, operation, { ...fields, session_id: sessionId }), /Checkout inválido|no coincide|Sesión no coincide/);
      await rejected(() => db.query(`update private.${table} set session_id=$1 where ${column}=$2`, [sessionId, id]), { code: '23514' });
    }
    await rejected(() => rpc(name, operation, { ...fields, lease: historicalKey, session_id: 'cs_live_Lease123' }), /vencido/);
  }
});
