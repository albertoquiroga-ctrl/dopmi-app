import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { paymentService } from '../../supabase/functions/_shared/payments.mjs';

let db;
const donor = '94000000-0000-4000-8000-000000000001';
const rescuer = '94000000-0000-4000-8000-000000000002';
const other = '94000000-0000-4000-8000-000000000003';
const expense = '95000000-0000-4000-8000-000000000003';
const key = '96000000-0000-4000-8000-000000000001';
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
  const migrations = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(migrations)).filter(v => v.endsWith('.sql')).sort())
    await db.exec(await readFile(new URL(file, migrations), 'utf8'));
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    select id::uuid,id||'@example.test',now(),$2::jsonb from unnest($1::text[]) id`,
  [[donor, rescuer, other], JSON.stringify({ display_name: 'Prueba', terms_accepted: true, terms_version: 'development-2026-09-13' })]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
    ('95000000-0000-4000-8000-000000000001',$1,'verification','approved','{"public_name":"Refugio"}',null,0),
    ('95000000-0000-4000-8000-000000000002',$1,'case','approved','{"pet_name":"Luna"}',null,0),
    ($2,$1,'expense','approved','{"title":"Medicamentos"}','95000000-0000-4000-8000-000000000002',12000)`, [rescuer, expense]);
  await db.query(`insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
    values($1,'acct_synthetic',true,true)`, [rescuer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));
const call = async (operation, fields = {}) => (await db.query(
  'select public.dopmi_oneoff_native_server($1,$2::jsonb) value',
  [operation, JSON.stringify({ actor: donor, key, ...fields })])).rows[0].value;
const payload = { expense_id: expense, gross_cents: 10000, consent: true, consent_version: 'oneoff-test-2026-10-15' };
async function rejected(fn, match) {
  await db.exec('savepoint expected_failure');
  await assert.rejects(fn(), match);
  await db.exec('rollback to savepoint expected_failure');
}

test('native donation is atomic, consent-bound, fully reserved and owner-filtered', async () => {
  await rejected(() => call('prepare', { ...payload, consent: false }), /Confirma el importe/);
  const d = await call('prepare', payload);
  assert.equal(d.payment_flow, 'native');
  assert.equal(d.consent_version, payload.consent_version);
  assert.ok(d.consent_at);
  assert.equal(d.reserved_cents, 9800);
  assert.deepEqual(await call('prepare', payload), d);
  assert.equal(await call('get', { actor: other }), null);
  await rejected(() => call('prepare', { ...payload, gross_cents: 10001 }), /otros datos/);
  assert.equal((await db.query('select count(*)::int n from public.dopmi_donations')).rows[0].n, 1);
});

test('provider identity binds once, legacy channel cannot save, canceled is durable', async () => {
  const d = await call('prepare', payload);
  const requests = [];
  const historicalApi = paymentService({ returnUrl: 'https://example.test/return',
    rpc: async (operation, fields) => (await db.query('select public.dopmi_payment_server($1,$2::jsonb) value',
      [operation, JSON.stringify(fields)])).rows[0].value,
    stripe: async (...args) => { requests.push(args); throw Error('Unexpected hosted call'); },
  });
  await assert.rejects(historicalApi.checkout(donor, { expense_id: expense, key, gross_cents: payload.gross_cents }),
    { code: 'payment_channel_mismatch' });
  assert.equal(requests.length, 0);
  const bound = await call('bind', { payment_intent_id: 'pi_synthetic' });
  assert.equal(bound.stripe_payment_intent_id, 'pi_synthetic');
  await call('bind', { payment_intent_id: 'pi_synthetic' });
  await rejected(() => call('bind', { payment_intent_id: 'pi_other' }), /Cobro distinto/);
  await rejected(() => db.query('select public.dopmi_payment_server($1,$2::jsonb)', ['checkout_save',
    JSON.stringify({ donation_id: d.id, session_id: 'cs_synthetic', url: 'https://checkout.stripe.com/synthetic' })]), /Sesión distinta/);
  const canceled = await call('canceled', { payment_intent_id: 'pi_synthetic' });
  assert.equal(canceled.payment_status, 'canceled');
  assert.equal(canceled.reserved_cents, 0);
  assert.equal((await call('prepare', payload)).payment_status, 'canceled');
});

test('native reservation rejects partial capacity without leaving a donation, while old hosted channel is preserved', async () => {
  await rejected(() => call('prepare', { ...payload, gross_cents: 20000 }), /asignarse completo/);
  assert.equal((await db.query('select count(*)::int n from public.dopmi_donations')).rows[0].n, 0);
  const historical = (await db.query('select public.dopmi_payment_server($1,$2::jsonb) value', ['prepare',
    JSON.stringify({ actor: donor, key, expense_id: expense, gross_cents: 10000 })])).rows[0].value;
  const preserved = await call('prepare', payload);
  assert.equal(preserved.id, historical.id);
  assert.equal(preserved.payment_flow, 'hosted');
  await rejected(() => call('bind', { payment_intent_id: 'pi_synthetic' }), /Cobro distinto/);
});

test('native ids participate in worker reconciliation and settlement rejects an alien intent', async () => {
  const d = await call('prepare', payload);
  await call('bind', { payment_intent_id: 'pi_synthetic' });
  const candidates = (await db.query("select public.dopmi_payment_server('reconcile_candidates','{}') value")).rows[0].value;
  assert.equal(candidates[0].stripe_payment_intent_id, 'pi_synthetic');
  await rejected(() => db.query('select public.dopmi_payment_server($1,$2::jsonb)', ['settle',
    JSON.stringify({ donation_id: d.id, currency: 'mxn', gross_cents: 10000, charge_id: 'ch_synthetic',
      payment_intent_id: 'pi_other', stripe_fee_cents: 600 })]), /Cobro distinto/);
  const settled = (await db.query('select public.dopmi_payment_server($1,$2::jsonb) value', ['settle',
    JSON.stringify({ donation_id: d.id, currency: 'mxn', gross_cents: 10000, charge_id: 'ch_synthetic',
      payment_intent_id: 'pi_synthetic', stripe_fee_cents: 600 })])).rows[0].value;
  assert.equal(settled.payment_status, 'confirmed');
  assert.equal(settled.allocated_cents, 9200);
  assert.equal(settled.platform_fee_cents, 200);
});

test('clients cannot invoke service-only native RPC or access consent/channel storage', async () => {
  await call('prepare', payload);
  for (const role of ['anon', 'authenticated']) {
    await db.exec(`set local role ${role}`);
    await rejected(() => call('get'), /permission denied/);
    await rejected(() => db.query('select * from private.dopmi_checkouts'), /permission denied/);
    await db.exec('reset role');
  }
});
