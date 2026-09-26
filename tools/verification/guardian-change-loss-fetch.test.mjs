import test from 'node:test';
import assert from 'node:assert/strict';
import Stripe from 'stripe';
import { changeLossFetch } from './guardian-change-loss-fetch.mjs';

const now = 1000000;
const target = { subscription: 'sub_acceptance', customer: 'cus_acceptance', item: 'si_acceptance', amount: 20000, expiresAt: now + 60000 };
const path = `https://api.stripe.com/v1/subscriptions/${target.subscription}`;
const headers = { authorization: 'Bearer sk_test_acceptance', 'idempotency-key': 'guardian-change-amount:12345678-1234-1234-1234-123456789012' };
const body = new URLSearchParams({ 'items[0][id]': target.item, 'items[0][price]': 'price_new', 'items[0][quantity]': '1', billing_cycle_anchor: 'unchanged', proration_behavior: 'none' }).toString();
const subscription = (amount = 20000) => ({ id: target.subscription, customer: target.customer, status: 'active', livemode: false, items: { has_more: false, data: [{ id: target.item, quantity: 1, price: { id: 'price_new', currency: 'mxn', unit_amount: amount } }] } });
const options = { target, testKey: 'sk_test_acceptance', now: () => now };

test('Stripe SDK Fetch transport serializes the targeted write and recovers without a second POST', async () => {
  let amount = 5000; const requests = [], evidence = [];
  const upstream = async (url, init) => {
    assert.equal(String(url), path);
    requests.push(init.method);
    if (init.method === 'POST') {
      assert.equal(new URLSearchParams(init.body).get('proration_behavior'), 'none');
      amount = 20000;
    }
    return new Response(JSON.stringify(subscription(amount)), { headers: { 'content-type': 'application/json', 'request-id': 'req_sdk' } });
  };
  const create = fetchImpl => new Stripe(options.testKey, { apiVersion: '2026-08-26.dahlia', maxNetworkRetries: 0, httpClient: Stripe.createFetchHttpClient(fetchImpl) });
  const instrumented = create(changeLossFetch({ ...options, fetchImpl: upstream, record: event => evidence.push(event) }));
  assert.equal((await instrumented.subscriptions.retrieve(target.subscription)).items.data[0].price.unit_amount, 5000);
  await assert.rejects(instrumented.subscriptions.update(target.subscription, {
    items: [{ id: target.item, price: 'price_new', quantity: 1 }], billing_cycle_anchor: 'unchanged', proration_behavior: 'none',
  }, { idempotencyKey: headers['idempotency-key'] }), error => error.type === 'StripeConnectionError');
  await assert.rejects(instrumented.subscriptions.retrieve(target.subscription), error => error.type === 'StripeConnectionError');
  const recovered = await create(upstream).subscriptions.retrieve(target.subscription);
  assert.equal(recovered.items.data[0].price.unit_amount, 20000);
  assert.deepEqual(requests, ['GET', 'POST', 'GET', 'GET']);
  assert.deepEqual(evidence.map(event => event.method), ['POST', 'GET']);
  assert.equal(evidence[0].guardianRequest, '12345678-1234-1234-1234-123456789012');
});

test('real write is applied before loss; separate instances hide new state, expiry recovers same state', async () => {
  let amount = 5000, writes = 0, time = now; const evidence = [];
  const fetchImpl = async (_url, init) => {
    if (init.method === 'POST') { amount = 20000; writes++; }
    return new Response(JSON.stringify(subscription(amount)), { headers: { 'request-id': 'req_test' } });
  };
  const create = () => changeLossFetch({ ...options, now: () => time, fetchImpl, record: event => evidence.push(event) });
  assert.equal((await (await create()(path, { method: 'GET', headers })).json()).items.data[0].price.unit_amount, 5000);
  await assert.rejects(create()(path, { method: 'POST', headers, body }), /response_lost/);
  assert.equal(writes, 1); assert.equal(amount, 20000);
  await assert.rejects(create()(path, { method: 'GET', headers }), /response_lost/);
  const existing = create(); time = target.expiresAt;
  assert.equal((await (await existing(path, { method: 'GET', headers })).json()).items.data[0].price.unit_amount, 20000);
  assert.deepEqual(evidence.map(e => e.method), ['POST', 'GET']); assert.equal(writes, 1);
  assert.equal(evidence[0].guardianRequest, '12345678-1234-1234-1234-123456789012');
  assert.equal(evidence[0].price, 'price_new'); assert.equal(evidence[1].price, 'price_new');
  assert.equal(evidence[1].guardianRequest, null);
});

test('POST response with a different price at same amount passes without false evidence', async () => {
  const different = subscription(); different.items.data[0].price.id = 'price_other';
  const response = new Response(JSON.stringify(different));
  const wrapper = changeLossFetch({ ...options, fetchImpl: async () => response, record: () => assert.fail('wrong price attributed') });
  assert.equal(await wrapper(path, { method: 'POST', headers, body }), response);
});

test('unrelated origin, auth, account, body, method, or request key passes untouched', async () => {
  const cases = [
    [path + '/other', { method: 'POST', headers, body }],
    [path, { method: 'DELETE', headers }],
    [path, { method: 'POST', headers: { ...headers, authorization: 'Bearer sk_live_other' }, body }],
    [path, { method: 'POST', headers: { ...headers, 'stripe-account': 'acct_other' }, body }],
    [path, { method: 'POST', headers: { ...headers, 'idempotency-key': 'other' }, body }],
    [path, { method: 'POST', headers, body: body + '&unexpected=true' }],
    [path, { method: 'POST', headers, body: body.replace('unchanged', 'now') }],
  ];
  for (const [url, init] of cases) {
    const response = new Response(JSON.stringify(subscription()));
    const wrapper = changeLossFetch({ ...options, fetchImpl: async () => response, record: () => assert.fail('unexpected interception') });
    assert.equal(await wrapper(url, init), response);
  }
});

test('invalid, foreign, live and oversized responses are not hidden', async () => {
  const wrong = subscription(); wrong.customer = 'cus_other';
  const live = subscription(); live.livemode = true;
  const canceled = subscription(); canceled.status = 'canceled';
  for (const response of [new Response('error', { status: 400 }), new Response('not json'), new Response(JSON.stringify(wrong)), new Response(JSON.stringify(live)), new Response(JSON.stringify(canceled)), new Response(JSON.stringify(subscription(5000))), new Response('x'.repeat(262145))]) {
    const wrapper = changeLossFetch({ ...options, fetchImpl: async () => response, record: () => assert.fail('unexpected interception') });
    assert.equal(await wrapper(path, { method: 'GET', headers }), response);
    assert.ok((await response.text()).length);
  }
  assert.throws(() => changeLossFetch({ ...options, target: { ...target, expiresAt: now } }), /invalid_change_loss_target/);
  assert.throws(() => changeLossFetch({ ...options, testKey: 'sk_live_other' }), /invalid_change_loss_target/);
});
