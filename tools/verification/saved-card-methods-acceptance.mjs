import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import Stripe from 'stripe';

// Explicit DEV-only acceptance against Auth, deployed SQL/Edge and Stripe test.
// Fixture preparation uses real test cards; it is not hosted-Checkout acceptance.
// Credentials and the cleanup journal must remain outside the repository.
const [mode, path] = process.argv.slice(2);
assert.ok(['prepare-stripe', 'verify', 'cleanup-stripe'].includes(mode));
const config = JSON.parse((await readFile(path, 'utf8')).replace(/^\uFEFF/, ''));
assert.equal(config.url, 'https://ohqxranynackjignryep.supabase.co');
assert.equal(config.email, `parity-methods-382-${config.id}@example.invalid`);
assert.match(config.id, /^[0-9a-f-]{36}$/);
assert.equal(config.cleaned, false);
const save = () => writeFile(path, JSON.stringify(config, null, 2));
const env = (await readFile(join(process.env.LOCALAPPDATA, 'Dopmi', 'acceptance', 'stripe-test.env'), 'utf8')).trim();
const match = /^STRIPE_SECRET_KEY_H4_TEST=((?:rk|sk)_test_[A-Za-z0-9]+)$/.exec(env);
assert.ok(match);
const stripe = new Stripe(match[1], { apiVersion: '2026-08-26.dahlia', maxNetworkRetries: 0,
  timeout: 20000, httpClient: Stripe.createFetchHttpClient() });
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
const input = (action, key, payment_method_id) => ({ action, key, payment_method_id,
  consent: true, consent_version: 'saved-card-methods-2026-10-03' });
async function noMoney() {
  for (const resource of [stripe.charges, stripe.paymentIntents, stripe.invoices, stripe.subscriptions]) {
    const list = await resource.list({ customer: config.customer, limit: 100 });
    assert.equal(list.has_more, false);
    assert.equal(list.data.length, 0);
  }
  config.noMoney = true;
  await save();
}
try {
  const session = await json('/auth/v1/token?grant_type=password', { email: config.email, password: config.password });
  assert.equal(session.user.id, config.id);
  assert.ok(session.user.email_confirmed_at);
  token = session.access_token;
  if (mode === 'prepare-stripe') {
    stage = 'prepare-test-customer';
    const customer = await stripe.customers.create({ metadata: { dopmi_acceptance: 'saved-card-methods-382', fixture_owner: config.id } },
      { idempotencyKey: `dopmi-methods-382-customer:${config.id}` });
    config.customer = customer.id;
    await save();
    assert.equal(customer.livemode, false);
    const methods = [];
    for (const [name, cardToken] of [['old', 'tok_visa'], ['target', 'tok_mastercard']]) {
      const method = await stripe.paymentMethods.create({ type: 'card', card: { token: cardToken } },
        { idempotencyKey: `dopmi-methods-382-${name}:${config.id}` });
      await stripe.paymentMethods.attach(method.id, { customer: customer.id },
        { idempotencyKey: `dopmi-methods-382-attach-${name}:${config.id}` });
      config[name] = method.id;
      await save();
      methods.push(method.id);
    }
    await stripe.customers.update(customer.id, { invoice_settings: { default_payment_method: methods[0] } },
      { idempotencyKey: `dopmi-methods-382-baseline:${config.id}` });
    config.prepared = true;
    await noMoney();
    console.log(JSON.stringify({ prepared: true, authenticated: true, actualTestCards: 2, noMoney: true }));
  } else {
    assert.equal(config.prepared, true);
    const customer = await stripe.customers.retrieve(config.customer);
    assert.equal(customer.livemode, false);
    assert.equal(customer.metadata.dopmi_acceptance, 'saved-card-methods-382');
    assert.equal(customer.metadata.fixture_owner, config.id);
    if (mode === 'verify') {
      stage = 'initial-owned-list';
      const initial = await json('/functions/v1/guardian-client', { action: 'methods' });
      assert.equal(initial.items.length, 2);
      assert.equal(initial.items.find(c => c.id === config.old).default, true);
      assert.equal(initial.items.find(c => c.id === config.target).default, false);
      stage = 'authorization-boundaries';
      const change = input('saved_card_default', config.default_key, config.target);
      for (const patch of [{ consent: false }, { consent_version: 'guardian-2026-09-24' },
        { owner_id: config.id }, { customer_id: config.customer }, { revision: 0 }]) {
        const response = await call('/functions/v1/guardian-client', { ...change, ...patch });
        assert.equal(response.status, 400);
      }
      assert.equal((await call('/functions/v1/guardian-client', change, false)).status, 401);
      const denied = await call('/rest/v1/rpc/dopmi_saved_card_method_server', { operation: 'get', data: {} });
      assert.equal(denied.status, 403);
      assert.equal((await denied.json()).code, '42501');
      assert.equal(await json('/rest/v1/rpc/dopmi_saved_card_method_state', {}), null);
      stage = 'default-real';
      const expectedDefault = { key: config.default_key, action: 'default', status: 'applied', card_id: config.target };
      assert.deepEqual(await json('/functions/v1/guardian-client', change), expectedDefault);
      assert.deepEqual(await json('/rest/v1/rpc/dopmi_saved_card_method_state', {}), expectedDefault);
      assert.deepEqual(await json('/functions/v1/guardian-client', change), expectedDefault);
      assert.equal((await call('/functions/v1/guardian-client', { ...change, payment_method_id: config.old })).status, 409);
      assert.equal((await stripe.customers.retrieve(config.customer)).invoice_settings.default_payment_method, config.target);
      const changed = await json('/functions/v1/guardian-client', { action: 'methods' });
      assert.equal(changed.items.find(c => c.id === config.target).default, true);
      config.defaultVerified = true;
      await save();
      stage = 'remove-real';
      const remove = input('saved_card_remove', config.remove_key, config.old);
      const expectedRemoval = { key: config.remove_key, action: 'remove', status: 'removed', card_id: config.old };
      assert.deepEqual(await json('/functions/v1/guardian-client', remove), expectedRemoval);
      assert.deepEqual(await json('/rest/v1/rpc/dopmi_saved_card_method_state', {}), expectedRemoval);
      assert.deepEqual(await json('/functions/v1/guardian-client', remove), expectedRemoval);
      assert.equal((await stripe.paymentMethods.retrieve(config.old)).customer, null);
      assert.equal((await stripe.customers.retrieve(config.customer)).invoice_settings.default_payment_method, config.target);
      const final = await json('/functions/v1/guardian-client', { action: 'methods' });
      assert.equal(final.items.length, 1);
      assert.equal(final.items[0].id, config.target);
      assert.equal(final.items[0].default, true);
      config.removeVerified = true;
      await save();
      await noMoney();
      console.log(JSON.stringify({ authenticated: true, defaultVerified: true, removeVerified: true,
        stableReplay: true, privateRpcDenied: true, noMoney: true }));
    } else {
      stage = 'cleanup-stripe';
      await noMoney();
      assert.equal((await stripe.customers.del(config.customer)).deleted, true);
      assert.equal((await stripe.customers.retrieve(config.customer)).deleted, true);
      config.stripeCleaned = true;
      await save();
      console.log(JSON.stringify({ stripeCleaned: true, noMoney: true }));
    }
  }
} catch (error) {
  config.failure = { stage, name: error.name };
  await save();
  console.error(JSON.stringify({ failed: true, stage, type: error.name }));
  process.exitCode = 1;
} finally {
  if (token) {
    await call('/auth/v1/logout', {});
    token = undefined;
  }
}
