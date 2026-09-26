import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { join } from 'node:path';
import Stripe from 'stripe';
import { startGuardianResponseLossProxy } from './guardian-response-loss-proxy.mjs';

// Explicitly invoked technical acceptance. Creates only an unused test price;
// never creates a payment, customer, subscription, transfer or refund.
assert.deepEqual(process.argv.slice(2), ['--execute-test-write']);
const stateDirectory = new URL('../../.tools/', import.meta.url);
const statePath = new URL('guardian-stripe-transport.json', stateDirectory);
await mkdir(stateDirectory, { recursive: true });
let proxy;
let stage = 'account-check';
try {
  const credentials = (await readFile(join(process.env.LOCALAPPDATA,
    'Dopmi', 'acceptance', 'stripe-test.env'), 'utf8')).trim();
  const match = /^STRIPE_SECRET_KEY_H4_TEST=((?:rk|sk)_test_[A-Za-z0-9]+)$/.exec(credentials);
  assert.ok(match, 'A locally stored Stripe test key is required');
  const testKey = match[1];
  const options = { apiVersion: '2026-08-26.dahlia', maxNetworkRetries: 0,
    timeout: 20000, httpClient: Stripe.createFetchHttpClient() };
  const stripe = new Stripe(testKey, options);
  const knownSession = 'cs_test_a1qfHlwmhBMH2VIXpcf9sUmt78LEQwY4XKzDJns4d653y7fUluM3dDXXi1';
  const session = await stripe.checkout.sessions.retrieve(knownSession);
  assert.equal(session.id, knownSession);
  assert.equal(session.livemode, false);
  let state;
  try { state = JSON.parse(await readFile(statePath, 'utf8')); }
  catch (error) {
    if (error.code !== 'ENOENT') throw error;
    const runId = randomUUID();
    state = { runId, createdAt: new Date().toISOString(),
      idempotencyKey: `guardian-transport-price:${runId}`,
      fields: { currency: 'mxn', unit_amount: 5000, recurring: { interval: 'month' },
        product_data: { name: `Dopmi H5 transporte aislado ${runId}` },
        metadata: { dopmi_transport_acceptance: runId } } };
    await writeFile(statePath, JSON.stringify(state, null, 2), { flag: 'wx' });
  }
  assert.match(state.runId, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(state.idempotencyKey, `guardian-transport-price:${state.runId}`);
  const productName = `Dopmi H5 transporte aislado ${state.runId}`;
  assert.deepEqual(state.fields, { currency: 'mxn', unit_amount: 5000,
    recurring: { interval: 'month' }, product_data: { name: productName },
    metadata: { dopmi_transport_acceptance: state.runId } });
  for (const field of ['createdAt', 'attemptStartedAt', 'recoveredAt', 'completedAt']) {
    if (field !== 'createdAt' && state[field] === undefined) continue;
    const timestamp = Date.parse(state[field]);
    assert.ok(Number.isFinite(timestamp) && timestamp <= Date.now());
    assert.equal(new Date(timestamp).toISOString(), state[field]);
  }
  const save = () => writeFile(statePath, JSON.stringify(state, null, 2));
  if (state.completedAt) {
    const price = await stripe.prices.retrieve(state.priceId);
    assert.equal(price.livemode, false);
    assert.equal(price.metadata.dopmi_transport_acceptance, state.runId);
    assert.equal(price.active, false);
    const product = await stripe.products.retrieve(price.product);
    assert.equal(product.livemode, false);
    assert.equal(product.name, productName);
    assert.equal(product.active, false);
    console.log(JSON.stringify({ alreadyComplete: true, priceId: price.id }));
  } else {
    assert.ok(Date.now() - Date.parse(state.createdAt) < 23 * 3600000,
      'Idempotency recovery window exceeded; manual evidence review required');
    if (!state.attemptStartedAt) {
      state.attemptStartedAt = new Date().toISOString();
      await save();
      proxy = await startGuardianResponseLossProxy({ testKey, path: '/v1/prices',
        idempotencyKey: state.idempotencyKey });
      const interrupted = new Stripe(testKey, { ...options,
        host: '127.0.0.1', port: proxy.port, protocol: 'http' });
      await assert.rejects(interrupted.prices.create(state.fields,
        { idempotencyKey: state.idempotencyKey }), error => error.type === 'StripeConnectionError');
      state.transportEvidence = proxy.evidence();
      await save();
      assert.equal(state.transportEvidence.length, 1, 'No accepted upstream write was observed');
      await proxy.close();
      proxy = null;
    }
    // Same immutable body/key; a process interruption never causes a new key.
    stage = 'recover';
    const recovered = await stripe.prices.create(state.fields, { idempotencyKey: state.idempotencyKey });
    assert.equal(recovered.livemode, false);
    assert.equal(recovered.metadata.dopmi_transport_acceptance, state.runId);
    state.priceId = recovered.id;
    state.productId = typeof recovered.product === 'string' ? recovered.product : recovered.product.id;
    state.recoveredAt = new Date().toISOString();
    await save();
    stage = 'retrieve-price';
    const independent = await stripe.prices.retrieve(state.priceId);
    assert.equal(independent.unit_amount, 5000);
    assert.equal(independent.currency, 'mxn');
    assert.equal(independent.livemode, false);
    const matches = [];
    stage = 'list-prices';
    for await (const price of stripe.prices.list({ limit: 100, product: state.productId })) {
      if (price.metadata.dopmi_transport_acceptance === state.runId) matches.push(price.id);
    }
    assert.deepEqual(matches, [state.priceId]);
    // Archive only the exact unused objects created by this technical run.
    stage = 'retrieve-product';
    const product = await stripe.products.retrieve(state.productId);
    assert.equal(product.livemode, false);
    assert.equal(product.name, productName);
    stage = 'archive';
    await stripe.products.update(state.productId, { default_price: '' });
    await stripe.prices.update(state.priceId, { active: false });
    await stripe.products.update(state.productId, { active: false });
    assert.equal((await stripe.prices.retrieve(state.priceId)).active, false);
    assert.equal((await stripe.products.retrieve(state.productId)).active, false);
    state.archived = true;
    await save();
    assert.equal(state.transportEvidence?.[0]?.objectId, state.priceId,
      'Recovery succeeded, but original lost-response evidence is incomplete');
    assert.equal(state.transportEvidence[0].responseDropped, true);
    state.completedAt = new Date().toISOString();
    await save();
    console.log(JSON.stringify({ completed: true, priceId: state.priceId,
      productId: state.productId, requestId: state.transportEvidence[0].requestId,
      observedPrices: matches.length, archived: state.archived }));
  }
} catch (error) {
  // SDK errors may contain request headers. Never print the raw error object.
  console.log(JSON.stringify({ completed: false, type: error.type ?? error.name,
    status: error.statusCode ?? null, code: error.code ?? null, param: error.param ?? null, stage }));
  process.exitCode = 1;
} finally { await proxy?.close(); }
