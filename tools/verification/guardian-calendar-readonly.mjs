// Real Stripe reads + production validation/RPCs in an ephemeral database.
// The local registry/schedule seed is synthetic, NOT evidence of initial payment.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import Stripe from 'stripe';
import { PGlite } from '@electric-sql/pglite';
import { guardianRenewalCandidate, guardianInvoiceCycleKey } from '../../supabase/functions/_shared/guardian-billing.mjs';

const [keyFile, fixtureFile] = process.argv.slice(2);
if (!keyFile || !fixtureFile) throw Error('Usage: node guardian-calendar-readonly.mjs <test-key-file> <fixture-json>');
const key = (await readFile(keyFile, 'utf8')).match(/^STRIPE_SECRET_KEY_H4_TEST=((?:rk|sk)_test_[A-Za-z0-9]+)$/m)?.[1];
assert.ok(key, 'A test key is required');
const fixture = JSON.parse(await readFile(fixtureFile, 'utf8'));
// Transport guard makes every remote mutation impossible in this harness.
const readonlyFetch = (url, options = {}) => {
  assert.equal(options.method ?? 'GET', 'GET', 'Stripe writes forbidden');
  assert.equal(new URL(url).origin, 'https://api.stripe.com');
  return fetch(url, options);
};
const stripe = new Stripe(key, { apiVersion: '2026-08-26.dahlia', maxNetworkRetries: 0,
  httpClient: Stripe.createFetchHttpClient(readonlyFetch) });
const sub = await stripe.subscriptions.retrieve(fixture.subscription);
assert.equal(sub.livemode, false);
assert.equal(sub.customer, fixture.customer);
assert.equal(sub.pause_collection?.behavior, 'keep_as_draft');
assert.equal(sub.collection_method, 'send_invoice');
assert.equal(sub.billing_cycle_anchor_config?.day_of_month, 31);
const invoices = await stripe.invoices.list({ subscription: sub.id, limit: 100 });
assert.equal(invoices.has_more, false, 'Incomplete invoice evidence');
const renewals = invoices.data.filter(i => i.billing_reason === 'subscription_cycle');
assert.ok(renewals.length >= 2);
for (const [start, end] of [[1803823200, 1806501600], [1806501600, 1809093600]]) {
  assert.equal(renewals.filter(i => i.lines?.data?.[0]?.period?.start === start
    && i.lines.data[0].period.end === end).length, 1,
  'Expected exactly one February→March / March→April 2027 renewal');
}
const db = new PGlite();
const donor = '70000000-0000-4000-8000-000000000031';
const seedKey = '72000000-0000-4000-8000-000000000031';
const rpc = async (name, operation, data) => (await db.query(
  `select public.${name}($1,$2::jsonb) as value`, [operation, JSON.stringify(data)])).rows[0].value;
try {
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;`);
  const migrations = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(migrations)).filter(f => f.endsWith('.sql')).sort())
    await db.exec(await readFile(new URL(file, migrations), 'utf8'));
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    values($1,'calendar@example.invalid',now(),'{"display_name":"Calendar fixture","terms_accepted":true,"terms_version":"development-2026-09-13"}')`, [donor]);
  // No settlement, charge, transfer or financial result is fabricated.
  // These unmistakable placeholder references satisfy the local registry schema only.
  await rpc('dopmi_guardian_subscription_server', 'register', { donor_id: donor,
    stripe_customer_id: fixture.customer, stripe_subscription_id: sub.id,
    stripe_price_id: fixture.price, gross_cents: 5000,
    initial_payment_intent_id: 'pi_SYNTHETICCalendarSeed', initial_charge_id: 'ch_SYNTHETICCalendarSeed' });
  const seed = (await db.query('select public.dopmi_guardian_reserve($1,$2,5000) as value', [donor, seedKey])).rows[0].value;
  await db.query(`insert into private.dopmi_guardian_activations(cycle_id,donor_id,consent_version,status,checkout_expires_at,return_url,payment_method_id)
    values($1,$2,'guardian-2026-09-24','no_capacity',now(),'https://example.invalid','pm_SYNTHETICCalendarSeed')`, [seed.id, donor]);
  await db.query(`insert into private.dopmi_guardian_schedule_jobs(cycle_id,status,charge_created,next_billing_at,price_id,subscription_id)
    values($1,'ready',1801404000,to_timestamp(1803823200),$2,$3)`, [seed.id, fixture.price, sub.id]);
  const evidence = [];
  for (const invoice of renewals) {
    guardianRenewalCandidate(invoice, sub, { invoice_id: invoice.id, subscription_id: sub.id,
      customer_id: fixture.customer, price_id: fixture.price, gross_cents: 5000 });
    assert.equal(invoice.amount_paid, 0);
    const period = invoice.lines.data[0].period;
    const data = { invoice_id: invoice.id, subscription_id: sub.id,
      cycle_key: await guardianInvoiceCycleKey(sub.id, invoice.id),
      period_start: period.start, period_end: period.end,
      verified_price_id: fixture.price, verified_gross_cents: 5000, fresh: false };
    const prepared = await rpc('dopmi_guardian_collection_server', 'prepare', data);
    const replay = await rpc('dopmi_guardian_collection_server', 'prepare', data);
    assert.equal(prepared.cycle_id, replay.cycle_id);
    assert.equal(prepared.decision, 'skip');
    evidence.push({ invoice: invoice.id, cycle: prepared.cycle_id, start: new Date(period.start * 1000).toISOString(), end: new Date(period.end * 1000).toISOString() });
  }
  await db.exec('set role authenticated');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [donor]);
  const history = (await db.query('select public.dopmi_guardian_history(null,null,20) as value')).rows[0].value;
  for (const entry of evidence) {
    const item = history.items.find(i => i.id === entry.cycle);
    assert.ok(item);
    assert.equal(new Date(item.period_start).toISOString(), entry.start);
    assert.equal(new Date(item.period_end).toISOString(), entry.end);
    assert.equal(item.authorized_cents, 5000);
    assert.equal(item.paid_cents, null);
  }
  console.log(JSON.stringify({ scope: 'real Stripe reads + isolated seeded database; no initial-payment or mobile acceptance',
    remoteWrites: 0, checkedRenewals: evidence, ownerHistoryDatesPreserved: true }, null, 2));
} finally { await db.close(); }
