import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import Stripe from 'stripe';

// Explicit opt-in. Uses only a disposable Auth fixture and its Stripe test customer.
// Preparation pauses for the real hosted Checkout UI; verification never fabricates
// completion or writes a saved receipt directly. Journals/credentials stay outside Git.
const [mode, path] = process.argv.slice(2);
assert.ok(['prepare', 'verify', 'cleanup-stripe'].includes(mode));
const config = JSON.parse(await readFile(path, 'utf8'));
assert.equal(config.url, 'https://ohqxranynackjignryep.supabase.co');
assert.equal(config.email, `parity-card-371-${config.id}@example.invalid`);
assert.match(config.id, /^[0-9a-f-]{36}$/);
assert.match(config.key, /^[0-9a-f-]{36}$/);
assert.match(config.publishable, /^sb_publishable_/);
assert.equal(config.cleaned, false);
const save = () => writeFile(path, JSON.stringify(config, null, 2));
let token;
let stage = 'login';
async function call(endpoint, body, authenticated = true) {
  return fetch(config.url + endpoint, {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(25000),
    headers: { apikey: config.publishable, 'Content-Type': 'application/json',
      ...(authenticated && token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });
}
async function json(endpoint, body) {
  const response = await call(endpoint, body);
  assert.equal(response.status, 200, `${stage}: HTTP ${response.status}`);
  return response.json();
}
const input = { action: 'add_card', key: config.key, consent: true, consent_version: 'saved-cards-2026-10-03' };
try {
  const session = await json('/auth/v1/token?grant_type=password', { email: config.email, password: config.password });
  assert.equal(session.user.id, config.id);
  assert.ok(session.user.email_confirmed_at);
  token = session.access_token;
  config.created = true;
  await save();
  if (mode === 'prepare') {
    stage = 'initial-empty';
    assert.deepEqual(await json('/functions/v1/guardian-client', { action: 'methods' }), { items: [] });
    assert.equal(await json('/rest/v1/rpc/dopmi_saved_card_state', {}), null);
    stage = 'explicit-consent';
    for (const patch of [{ consent: false }, { consent_version: 'guardian-2026-09-24' },
      { owner_id: config.id }, { customer_id: 'cus_foreign' }, { return_url: 'https://example.invalid' }]) {
      const response = await call('/functions/v1/guardian-client', { ...input, ...patch });
      assert.equal(response.status, 400);
      assert.deepEqual(await response.json(), { error: 'invalid_request' });
    }
    stage = 'private-boundary';
    for (const [name, body] of [['dopmi_saved_card_server', { operation: 'get', data: {} }],
      ['dopmi_saved_card_owner_server', { target_actor: config.id }]]) {
      const response = await call(`/rest/v1/rpc/${name}`, body);
      assert.equal(response.status, 403);
      assert.equal((await response.json()).code, '42501');
    }
    stage = 'setup';
    const first = await json('/functions/v1/guardian-client', input);
    assert.equal(first.key, config.key);
    assert.equal(first.status, 'pending');
    assert.equal(first.card_id, null);
    assert.match(first.checkout_url, /^https:\/\/checkout.stripe.com\//);
    config.checkoutUrl = first.checkout_url;
    await save();
    stage = 'stable-replay';
    assert.deepEqual(await json('/functions/v1/guardian-client', input), first);
    assert.deepEqual(await json('/rest/v1/rpc/dopmi_saved_card_state', {}), { key: config.key, status: 'pending', card_id: null });
    assert.deepEqual(await json('/functions/v1/guardian-client', { action: 'methods' }), { items: [] });
    config.prepared = true;
    await save();
    console.log(JSON.stringify({ prepared: true, authenticated: true, replayConfirmed: true, privateRpcDenied: true, cardNotInvented: true }));
  } else {
    stage = 'test-key';
    assert.ok(config.prepared && config.customer && config.session);
    const env = (await readFile(join(process.env.LOCALAPPDATA, 'Dopmi', 'acceptance', 'stripe-test.env'), 'utf8')).trim();
    const match = /^STRIPE_SECRET_KEY_H4_TEST=((?:rk|sk)_test_[A-Za-z0-9]+)$/.exec(env);
    assert.ok(match);
    const stripe = new Stripe(match[1], { apiVersion: '2026-08-26.dahlia', maxNetworkRetries: 0,
      timeout: 20000, httpClient: Stripe.createFetchHttpClient() });
    stage = 'owned-test-session';
    const checkout = await stripe.checkout.sessions.retrieve(config.session);
    assert.equal(checkout.customer, config.customer);
    assert.equal(checkout.livemode, false);
    assert.equal(checkout.mode, 'setup');
    assert.equal(checkout.metadata.dopmi_saved_card_job, config.job);
    assert.equal(checkout.payment_intent, null);
    assert.equal(checkout.subscription, null);
    if (mode === 'verify') {
      assert.equal(checkout.status, 'complete');
      const setup = await stripe.setupIntents.retrieve(checkout.setup_intent);
      assert.equal(setup.livemode, false);
      assert.equal(setup.customer, config.customer);
      assert.equal(setup.status, 'succeeded');
      assert.equal(setup.usage, 'off_session');
      const method = await stripe.paymentMethods.retrieve(setup.payment_method);
      assert.equal(method.customer, config.customer);
      assert.equal(method.type, 'card');
      assert.equal(method.livemode, false);
      stage = 'server-confirmed';
      const confirmed = await json('/functions/v1/guardian-client', input);
      assert.deepEqual(confirmed, { key: config.key, status: 'saved', card_id: method.id, checkout_url: null });
      assert.deepEqual(await json('/rest/v1/rpc/dopmi_saved_card_state', {}), { key: config.key, status: 'saved', card_id: method.id });
      const list = await json('/functions/v1/guardian-client', { action: 'methods' });
      assert.equal(list.items.length, 1);
      assert.equal(list.items[0].id, method.id);
      assert.equal(list.items[0].last4, '4242');
      assert.equal(list.items[0].default, false);
      assert.deepEqual(Object.keys(list.items[0]).sort(), ['brand','default','exp_month','exp_year','id','last4','wallet']);
      assert.deepEqual(await json('/functions/v1/guardian-client', input), confirmed);
      config.method = method.id;
      config.verified = true;
      await save();
    }
    stage = 'no-money';
    for (const resource of [stripe.charges, stripe.paymentIntents, stripe.invoices, stripe.subscriptions]) {
      const result = await resource.list({ customer: config.customer, limit: 100 });
      assert.equal(result.has_more, false);
      assert.equal(result.data.length, 0);
    }
    config.noMoney = true;
    if (mode === 'cleanup-stripe') {
      stage = 'cleanup';
      if (checkout.status === 'open') await stripe.checkout.sessions.expire(checkout.id, {}, { idempotencyKey: `dopmi-saved-card-cleanup:${config.key}` });
      const result = await stripe.customers.del(config.customer);
      assert.equal(result.deleted, true);
      assert.equal((await stripe.customers.retrieve(config.customer)).deleted, true);
      config.stripeCleaned = true;
    }
    await save();
    console.log(JSON.stringify({ verified: config.verified === true, noMoney: true, stripeCleaned: config.stripeCleaned === true }));
  }
} catch (error) {
  config.failure = { stage, name: error.name };
  await save();
  console.error(JSON.stringify({ failed: true, stage, type: error.name }));
  process.exitCode = 1;
} finally {
  if (token) {
    config.logout = (await call('/auth/v1/logout?scope=global', {})).ok;
    await save();
  }
}
