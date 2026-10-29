import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

let db, preserved;
const rescuer = randomUUID(), caseId = randomUUID(), expense = randomUUID();
const returnUrl = 'https://example.test/functions/v1/payment-return';
const livePair = ['terms-live-2026-10-28', 'privacy-live-2026-10-28', true];
const unchangedFunctions = ['private.dopmi_require_actor()', 'public.dopmi_oneoff_native_server(text,jsonb)',
  'public.dopmi_guardian_registration_cancellation_state()', 'public.dopmi_account_deletion_server(text,jsonb)',
  'public.dopmi_guardian_registration_authorize_payment(uuid)', 'public.dopmi_guardian_collection_server(text,jsonb)'];
const rpc = async (name, operation, fields = {}) => (await db.query(
  `select public.${name}($1,$2::jsonb) value`, [operation, JSON.stringify(fields)])).rows[0].value;
async function actor(id, role = 'authenticated') {
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id]); await db.exec(`set local role ${role}`);
}
async function reset() { await db.exec('reset role'); }
async function configure(environment) { await reset(); await db.query('update private.dopmi_payment_environment set environment=$1', [environment]); }
async function newActor() {
  const id = randomUUID();
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),
    '{"display_name":"Prueba financiera","terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}')`, [id, `${id}@example.test`]);
  return id;
}
async function acceptLive(id) {
  await actor(id); await db.query('select public.dopmi_accept_legal($1,$2,$3)', livePair); await reset();
}
async function rejected(action, expected = /términos y el aviso de privacidad vigentes/) {
  await db.exec('savepoint expected_failure'); await assert.rejects(action(), expected); await db.exec('rollback to savepoint expected_failure');
}
async function inventory() {
  const result = {};
  for (const table of ['public.dopmi_donations', 'private.dopmi_checkouts', 'private.dopmi_case_allocations',
    'private.dopmi_guardian_registrations', 'private.dopmi_guardian_cycles', 'private.dopmi_guardian_activations',
    'private.dopmi_saved_card_jobs', 'private.dopmi_saved_card_customers', 'private.dopmi_guardian_method_jobs',
    'private.dopmi_guardian_registration_method_changes', 'private.dopmi_guardian_requests', 'private.dopmi_connect_accounts']) {
    result[table] = (await db.query(`select to_jsonb(t) value from ${table} t order by to_jsonb(t)::text`)).rows;
  }
  return result;
}

before(async () => {
  db = new PGlite();
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
  // This suite exercises ALL migrations together, unlike the isolated B2/B4
  // migration-contract suites. No remote URL, Docker or existing database.
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(directory)).filter(v => v.endsWith('.sql')).sort()) {
    if (file === '20261029002921_production_financial_legal_admission.sql') {
      preserved = new Map();
      for (const name of unchangedFunctions) preserved.set(name,
        (await db.query('select pg_get_functiondef($1::regprocedure) value', [name])).rows[0].value);
    }
    try { await db.exec(await readFile(new URL(file, directory), 'utf8')); }
    catch (error) { throw new Error(`Migration ${file}: ${error.code}: ${error.message}`); }
  }
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,'financial-rescuer@example.test',now(),
    '{"display_name":"Refugio","terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}')`, [rescuer]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
    ($1,$4,'verification','approved','{"public_name":"Refugio"}',null,0),
    ($2,$4,'case','approved','{"pet_name":"Luna"}',null,0),
    ($3,$4,'expense','approved','{"title":"Medicamentos"}',$2,1000000)`, [randomUUID(), caseId, expense, rescuer]);
  await db.query("insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled) values($1,'acct_financial',true,true)", [rescuer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('integrated finance patch retains shared identity, native receipt, cancellation, deletion and recurring collection definitions', async () => {
  assert.ok(preserved);
  for (const [name, before] of preserved) assert.equal(
    (await db.query('select pg_get_functiondef($1::regprocedure) value', [name])).rows[0].value, before, name);
});

async function seedPlan(id, gross = 2000) {
  const cycle = randomUUID(), suffix = id.replaceAll('-', '');
  await db.query(`insert into private.dopmi_guardian_cycles(id,donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at)
    values($1,$2,$1,$3,0,'released',now()+interval '40 minutes')`, [cycle, id, gross]);
  await db.query(`insert into private.dopmi_guardian_activations(cycle_id,donor_id,consent_version,status,checkout_expires_at,return_url)
    values($1,$2,'guardian-2026-09-24','settled',now()+interval '35 minutes',$3)`, [cycle, id, returnUrl]);
  await db.query(`insert into private.dopmi_guardian_subscriptions(donor_id,stripe_customer_id,stripe_subscription_id,stripe_price_id,
    gross_cents,initial_payment_intent_id,initial_charge_id)
    values($1,$2,$3,$4,$5,$6,$7)`, [id, `cus_${suffix}`, `sub_${suffix}`, `price_${suffix}`, gross, `pi_${suffix}`, `ch_${suffix}`]);
  await db.query(`insert into private.dopmi_guardian_schedule_jobs(cycle_id,status,charge_created,next_billing_at,price_id,subscription_id)
    values($1,'ready',1700000000,now()+interval '1 month',$2,$3)`, [cycle, `price_${suffix}`, `sub_${suffix}`]);
}
async function seedRegistration(id, gross = 2000) {
  const registration = randomUUID(), suffix = id.replaceAll('-', '');
  const wallet = (await db.query('insert into private.dopmi_saved_card_customers(owner_id,stripe_customer_id) values($1,$2) returning id', [id, `cus_${suffix}`])).rows[0].id;
  const method = (await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,
    setup_intent_id,payment_method_id,status,return_url,wallet_type) values($1,$2,$3,'saved-cards-2026-10-03',$4,$5,$6,'saved',$7,'card') returning id`,
  [id, registration, wallet, `cus_${suffix}`, `seti_${suffix}`, `pm_${suffix}`, returnUrl])).rows[0].id;
  await db.query(`insert into private.dopmi_guardian_registrations(id,owner_id,request_key,initial_gross_cents,gross_cents,consent_version,status,method_job_id)
    values($1,$2,$1,$3,$3,'guardian-registration-2026-10-14','registered',$4)`, [registration, id, gross, method]);
  return registration;
}

const scenarios = [
  ['expense native contribution', async id => {
    const fields = { actor: id, key: randomUUID(), expense_id: expense, gross_cents: 1000, consent: true, consent_version: 'oneoff-live-2026-10-28' };
    return () => rpc('dopmi_oneoff_native_server', 'prepare', fields);
  }],
  ['case native contribution', async id => {
    const fields = { actor: id, key: randomUUID(), case_id: caseId, gross_cents: 1000, consent: true, consent_version: 'oneoff-live-2026-10-28' };
    return () => rpc('dopmi_oneoff_case_server', 'prepare', fields);
  }],
  ['historical hosted contribution entry', async id => {
    const fields = { actor: id, key: randomUUID(), expense_id: expense, gross_cents: 1000 };
    return () => rpc('dopmi_payment_server', 'prepare', fields);
  }],
  ['new Guardian registration', async id => {
    const fields = { owner_id: id, key: randomUUID(), gross_cents: 2000, consent: true, consent_version: 'guardian-registration-2026-10-14' };
    return () => rpc('dopmi_guardian_registration_server', 'prepare', fields);
  }],
  ['new Guardian activation', async id => {
    const fields = { donor_id: id, key: randomUUID(), gross_cents: 2000, consent: true, consent_version: 'guardian-2026-09-24', return_url: returnUrl };
    return () => rpc('dopmi_guardian_activation_server', 'prepare', fields);
  }],
  ['hosted saved card', async id => {
    const fields = { owner_id: id, key: randomUUID(), consent: true, consent_version: 'saved-cards-2026-10-03', return_url: returnUrl };
    return () => rpc('dopmi_saved_card_server', 'prepare', fields);
  }],
  ['independent native saved card', async id => {
    const fields = { owner_id: id, key: randomUUID(), consent: true, consent_version: 'saved-cards-2026-10-03', return_url: returnUrl };
    return () => rpc('dopmi_saved_native_card_server', 'prepare_add', fields);
  }],
  ['native wallet saving', async id => {
    const fields = { owner_id: id, key: randomUUID(), consent: true, consent_version: 'saved-cards-2026-10-03', return_url: returnUrl, wallet_type: 'google_pay' };
    return () => rpc('dopmi_saved_card_server', 'prepare', fields);
  }],
  ['Guardian hosted method change', async id => {
    await seedPlan(id);
    const fields = { donor_id: id, key: randomUUID(), revision: 0, consent: true, consent_version: 'guardian-2026-09-24', return_url: returnUrl };
    return () => rpc('dopmi_guardian_method_server', 'prepare', fields);
  }],
  ['Guardian registration method change', async id => {
    const registration = await seedRegistration(id);
    const fields = { owner_id: id, id: registration, key: randomUUID(), revision: 0, consent: true, consent_version: 'saved-cards-2026-10-03' };
    return () => rpc('dopmi_guardian_registration_method_server', 'prepare', fields);
  }],
  ['Guardian subscription amount increase', async id => {
    await seedPlan(id); const key = randomUUID();
    return async () => { await actor(id); const result = (await db.query('select public.dopmi_guardian_request($1,$2,$3,$4,$5) value',
      ['amount', key, 0, 3000, 'guardian-2026-09-24'])).rows[0].value; await reset(); return result; };
  }],
  ['Connect admission', async id => () => rpc('dopmi_payment_server', 'connect_admit', { actor: id })],
];

for (const [name, setup] of scenarios) test(`integrated PROD ${name}: TEST legal cannot admit; exact LIVE proof admits one stable instruction`, async () => {
  const id = await newActor(), run = await setup(id);
  await configure('production');
  const before = await inventory(); await rejected(run); assert.deepEqual(await inventory(), before);
  await acceptLive(id);
  const first = await run(); assert.ok(first);
  const created = await inventory(), replay = await run();
  // The legacy hosted gateway adds Checkout projection fields only on replay.
  // Every original field and the full persisted instruction must stay stable.
  assert.deepEqual(Object.fromEntries(Object.keys(first).map(key => [key, replay[key]])), first);
  assert.deepEqual(await inventory(), created);
  const evidence = (await db.query('select terms_version,privacy_version,adult_confirmed from private.dopmi_consents where owner_id=$1 order by terms_version', [id])).rows;
  assert.equal(evidence.length, 2); assert.equal(evidence[1].terms_version, livePair[0]);
});

test('integrated PROD helper requires actor-owned active/confirmed profile and genuine exact LIVE audit; ACLs stay private', async () => {
  const id = await newActor(), other = await newActor(); await configure('production'); await acceptLive(other);
  await rejected(() => rpc('dopmi_payment_server', 'connect_admit', { actor: id }));
  await acceptLive(id);
  assert.deepEqual(await rpc('dopmi_payment_server', 'connect_admit', { actor: id }), { allowed: true });
  for (const mutation of [
    "update public.profiles set account_status='suspended' where id=$1",
    'update auth.users set email_confirmed_at=null where id=$1',
    "update public.profiles set privacy_version='privacy-2026-10-17' where id=$1",
    'update public.profiles set adult_confirmed_at=null where id=$1',
    'update public.profiles set terms_accepted_at=terms_accepted_at-interval \'1 second\' where id=$1',
    "update private.dopmi_consents set adult_confirmed=false where owner_id=$1 and terms_version='terms-live-2026-10-28'",
    "delete from private.dopmi_consents where owner_id=$1 and terms_version='terms-live-2026-10-28'",
  ]) {
    await db.exec('savepoint malformed_proof'); await db.query(mutation, [id]);
    await rejected(() => rpc('dopmi_payment_server', 'connect_admit', { actor: id }));
    await db.exec('rollback to savepoint malformed_proof');
  }
  await rejected(() => rpc('dopmi_payment_server', 'connect_admit', { actor: randomUUID() }));
  for (const role of ['anon', 'authenticated', 'service_role']) {
    await actor(id, role); await rejected(() => db.query('select private.dopmi_require_current_legal($1)', [id]), { code: '42501' }); await reset();
  }
  for (const role of ['anon', 'authenticated']) {
    await actor(id, role); await rejected(() => rpc('dopmi_payment_server', 'connect_admit', { actor: id }), { code: '42501' }); await reset();
  }
  await actor(id, 'service_role'); assert.deepEqual(await rpc('dopmi_payment_server', 'connect_admit', { actor: id }), { allowed: true }); await reset();
  await db.exec('delete from private.dopmi_payment_environment');
  await rejected(() => rpc('dopmi_payment_server', 'connect_admit', { actor: id }));
});

test('integrated TEST keeps old fixtures; switching to PROD preserves old stable attempts, receipts, cancellation and deletion', async () => {
  const id = await newActor(), key = randomUUID(), regKey = randomUUID(), cardKey = randomUUID();
  const fields = { actor: id, key, expense_id: expense, gross_cents: 1000, consent: true, consent_version: 'oneoff-test-2026-10-15' };
  const donation = await rpc('dopmi_oneoff_native_server', 'prepare', fields);
  const registration = await rpc('dopmi_guardian_registration_server', 'prepare', { owner_id: id, key: regKey, gross_cents: 2000, consent: true, consent_version: 'guardian-registration-2026-10-14' });
  const cardFields = { owner_id: id, key: cardKey, consent: true, consent_version: 'saved-cards-2026-10-03', return_url: returnUrl };
  const card = await rpc('dopmi_saved_card_server', 'prepare', cardFields);
  await configure('production');
  assert.equal((await rpc('dopmi_oneoff_native_server', 'prepare', { ...fields, consent_version: 'oneoff-live-2026-10-28' })).id, donation.id);
  assert.deepEqual(await rpc('dopmi_oneoff_native_server', 'get', { actor: id, key }), donation);
  assert.equal((await rpc('dopmi_guardian_registration_server', 'prepare', { owner_id: id, key: regKey, gross_cents: 2000, consent: true, consent_version: 'guardian-registration-2026-10-14' })).id, registration.id);
  assert.deepEqual(await rpc('dopmi_saved_card_server', 'prepare', cardFields), card);
  await actor(id);
  assert.equal((await db.query('select public.dopmi_guardian_registration_cancellation_state() value')).rows[0].value.id, registration.id);
  assert.equal((await db.query('select public.dopmi_payment_activity() value')).rows[0].value.items.length, 1);
  await reset();
  assert.equal((await rpc('dopmi_guardian_registration_server', 'cancel', { owner_id: id, id: registration.id })).status, 'canceled');
  await rpc('dopmi_oneoff_native_server', 'bind', { actor: id, key, payment_intent_id: 'pi_historical' });
  assert.equal((await rpc('dopmi_oneoff_native_server', 'canceled', { actor: id, key, payment_intent_id: 'pi_historical' })).payment_status, 'canceled');
  const deletion = await rpc('dopmi_account_deletion_server', 'request', { owner_id: id, request_key: randomUUID() });
  assert.equal(deletion.status, 'procesando');
});

test('integrated Guardian registration amount increase requires LIVE; decrease and cancel remain available', async () => {
  const id = await newActor(), registration = await seedRegistration(id, 3000); await configure('production');
  const fields = { owner_id: id, id: registration, revision: 0, gross_cents: 4000, consent: true, consent_version: 'guardian-registration-2026-10-14' };
  const before = await inventory(); await rejected(() => rpc('dopmi_guardian_registration_server', 'change_amount', fields));
  assert.deepEqual(await inventory(), before);
  const lowered = await rpc('dopmi_guardian_registration_server', 'change_amount', { ...fields, gross_cents: 2000 });
  assert.equal(lowered.gross_cents, 2000);
  await acceptLive(id);
  assert.equal((await rpc('dopmi_guardian_registration_server', 'change_amount', { ...fields, revision: lowered.revision })).gross_cents, 4000);
  assert.equal((await rpc('dopmi_guardian_registration_server', 'cancel', { owner_id: id, id: registration })).status, 'canceled');
});

test('integrated existing Guardian can reduce amount, cancel and request removal of an unused saved card without accepting LIVE', async () => {
  const id = await newActor(); await seedPlan(id, 3000); await configure('production');
  await actor(id);
  const reduction = (await db.query('select public.dopmi_guardian_request($1,$2,$3,$4,$5) value',
    ['amount', randomUUID(), 0, 2000, 'guardian-2026-09-24'])).rows[0].value;
  assert.equal(reduction.request.new_gross_cents, 2000);
  const cancellation = (await db.query('select public.dopmi_guardian_request($1,$2,$3) value',
    ['cancel', randomUUID(), 1])).rows[0].value;
  assert.equal(cancellation.request.kind, 'cancel'); await reset();
  const cardOwner = await newActor(); await seedPlan(cardOwner);
  const removal = await rpc('dopmi_guardian_method_server', 'prepare', { donor_id: cardOwner, key: randomUUID(), revision: 0,
    consent: true, consent_version: 'guardian-2026-09-24', return_url: returnUrl, selected_method_id: 'pm_unused', remove_saved: true });
  assert.equal(removal.remove_saved, true);
});
