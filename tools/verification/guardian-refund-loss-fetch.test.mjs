import test from 'node:test';
import assert from 'node:assert/strict';
import Stripe from 'stripe';
import { refundLossFetch } from './guardian-refund-loss-fetch.mjs';
const cycle = '11111111-1111-4111-8111-111111111111';
const expense = '22222222-2222-4222-8222-222222222222';
const target = { cycle, expense, transfer: 'tr_fixture', amount: 4314, expiresAt: 100000 };
const key = `guardian-reversal:${cycle}:${expense}`;
const body = { amount: 4314, metadata: { dopmi_guardian_cycle: cycle, dopmi_guardian_expense: expense } };
const response = () => new Response(JSON.stringify({ id: 'trr_fixture', amount: 4314, transfer: 'tr_fixture', currency: 'mxn' }),
  { status: 200, headers: { 'request-id': 'req_fixture' } });
test('real SDK Fetch boundary loses exactly one matching success and preserves GET recovery', async () => {
  let calls = 0;
  const evidence = [];
  const wrapped = refundLossFetch({ testKey: 'sk_test_fixture', target, now: () => 1, record: x => evidence.push(x),
    fetchImpl: async () => { calls++; return response(); } });
  const stripe = new Stripe('sk_test_fixture', { maxNetworkRetries: 0,
    httpClient: Stripe.createFetchHttpClient(wrapped) });
  await assert.rejects(stripe.transfers.createReversal('tr_fixture', body, { idempotencyKey: key }),
    error => error.type === 'StripeConnectionError');
  assert.equal(calls, 1);
  assert.equal(evidence.length, 1);
  assert.equal(evidence[0].reversal, 'trr_fixture');
  const recovered = await stripe.transfers.retrieveReversal('tr_fixture', 'trr_fixture');
  assert.equal(recovered.id, 'trr_fixture');
  assert.equal(evidence.length, 1);
});
test('expired or mismatched request is passed through without consuming response', async () => {
  let time = 1;
  const evidence = [];
  const wrapped = refundLossFetch({ testKey: 'sk_test_fixture', target, now: () => time, record: x => evidence.push(x), fetchImpl: async () => response() });
  for (const auth of ['Bearer sk_live_fixture', 'Bearer sk_test_fixture']) {
    const result = await wrapped('https://api.stripe.com/v1/transfers/tr_other/reversals',
      { method: 'POST', headers: { authorization: auth, 'idempotency-key': key }, body: '' });
    assert.equal(result.status, 200);
  }
  time = target.expiresAt;
  assert.equal((await wrapped('https://api.stripe.com/v1/transfers/tr_fixture/reversals', { method: 'POST' })).status, 200);
  assert.deepEqual(evidence, []);
  assert.throws(() => refundLossFetch({ testKey: 'sk_test_fixture', target: { ...target, expiresAt: 2000000 }, now: () => 1 }), /invalid_refund_loss_target/);
});

test('exact route still excludes other keys, accounts, bodies, methods and upstream errors', async () => {
  const headers = { authorization: 'Bearer sk_test_fixture', 'idempotency-key': key };
  const encoded = new URLSearchParams({ amount: '4314',
    'metadata[dopmi_guardian_cycle]': cycle, 'metadata[dopmi_guardian_expense]': expense }).toString();
  for (const change of [
    { headers: { ...headers, authorization: 'Bearer sk_live_fixture' } },
    { headers: { ...headers, authorization: 'Bearer sk_test_other' } },
    { headers: { ...headers, 'stripe-account': 'acct_other' } },
    { headers: { ...headers, 'idempotency-key': 'other' } },
    { body: `${encoded}&extra=1` }, { body: encoded.replace('4314', '4313') }, { method: 'GET' },
  ]) {
    const wrapped = refundLossFetch({ target, testKey: 'sk_test_fixture', now: () => 1,
      record: () => assert.fail('must not intercept'), fetchImpl: async () => response() });
    assert.equal((await wrapped('https://api.stripe.com/v1/transfers/tr_fixture/reversals',
      { method: 'POST', headers, body: encoded, ...change })).status, 200);
  }
  for (const upstream of [new Response('declined', { status: 400 }),
    new Response(JSON.stringify({ id: 'trr_other', transfer: 'tr_other', amount: 4314, currency: 'mxn' })),
    new Response('x'.repeat(33000))]) {
    const wrapped = refundLossFetch({ target, testKey: 'sk_test_fixture', now: () => 1,
      record: () => assert.fail('must not intercept'), fetchImpl: async () => upstream });
    assert.equal(await wrapped('https://api.stripe.com/v1/transfers/tr_fixture/reversals',
      { method: 'POST', headers, body: encoded }), upstream);
  }
});
