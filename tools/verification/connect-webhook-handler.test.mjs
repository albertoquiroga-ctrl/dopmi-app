import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { PaymentError } from '../../supabase/functions/_shared/payments.mjs';
import { connectWebhookRequestHandler } from '../../supabase/functions/_shared/connect-webhook-handler.mjs';

const secret = 'whsec_connect_fixture';
const platformSecret = 'whsec_platform_fixture';
const event = { id: 'evt_connect1', object: 'event', type: 'account.updated', livemode: true,
  account: 'acct_fixture', data: { object: { id: 'acct_fixture', object: 'account', email: 'private@example.invalid' } } };
const json = (body, status = 200) => Response.json(body, { status });
const failure = error => json({ error: error instanceof PaymentError ? error.code : 'payment_unavailable' },
  error instanceof PaymentError ? error.status : 503);

function signed(payload = event, signingSecret = secret, options = {}) {
  const body = options.body ?? JSON.stringify(payload);
  const stamp = options.stamp ?? Math.floor(Date.now() / 1000);
  const signature = createHmac('sha256', signingSecret).update(`${stamp}.${body}`).digest('hex');
  return new Request('https://example.invalid/stripe-connect-webhook', { method: 'POST', body,
    headers: { 'Stripe-Signature': `t=${stamp},v1=${signature}`, ...options.headers } });
}

function fixture({ expectedLivemode = true, connectWebhookSecret = secret, handle } = {}) {
  const calls = { environment: 0, runtime: 0, handled: [], logs: [] };
  const handler = connectWebhookRequestHandler({ json, failure,
    logger: { info: value => calls.logs.push(value) },
    loadEnvironment: () => { calls.environment++; return { expectedLivemode, webhookSecret: platformSecret, connectWebhookSecret }; },
    createRuntime: async () => {
      calls.runtime++;
      return { service: { handleConnectWebhook: async (...args) => {
        calls.handled.push(args);
        return handle ? handle(...args) : { received: true };
      } } };
    },
  });
  return { handler, calls };
}

test('only the correctly signed account.updated envelope enters the server queue in each explicit mode', async () => {
  for (const expectedLivemode of [false, true]) {
    const f = fixture({ expectedLivemode });
    const response = await f.handler(signed({ ...event, livemode: expectedLivemode }));
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { received: true });
    assert.deepEqual(f.calls.handled, [[event.id, event.account]]);
    assert.equal(f.calls.runtime, 1);
    assert.equal(JSON.stringify(f.calls).includes('private@example.invalid'), false);
  }
});

test('platform signature, bad signature, expired delivery and crossed mode cannot construct the financial runtime', async () => {
  const f = fixture();
  for (const request of [signed(event, platformSecret), signed(event, 'whsec_wrong_fixture'),
    signed(event, secret, { stamp: Math.floor(Date.now() / 1000) - 601 }),
    signed({ ...event, livemode: false }), signed({ ...event, livemode: 'true' })]) {
    assert.equal((await f.handler(request)).status, 400);
  }
  assert.equal(f.calls.runtime, 0);
  assert.deepEqual(f.calls.handled, []);
});

test('signed financial events and crossed account identities are rejected before runtime access', async () => {
  const f = fixture();
  for (const patch of [{ type: 'payment_intent.succeeded' }, { account: undefined },
    { account: 'acct_other' }, { account: 'acct_bad/path' }, { id: 'evt_bad/path' },
    { data: { object: { object: 'customer', id: event.account } } }, { data: null }]) {
    assert.equal((await f.handler(signed({ ...event, ...patch }))).status, 400);
  }
  assert.equal(f.calls.runtime, 0);
});

test('missing or reused signing secret cannot silently substitute the platform credential', async () => {
  for (const connectWebhookSecret of [null, '', 'not-a-secret', platformSecret]) {
    const f = fixture({ connectWebhookSecret });
    assert.equal((await f.handler(signed())).status, 503);
    assert.equal(f.calls.runtime, 0);
  }
});

test('method and both declared or actual byte limits fail before loading server credentials', async () => {
  const f = fixture();
  assert.equal((await f.handler(new Request('https://example.invalid/connect'))).status, 405);
  assert.equal((await f.handler(signed(event, secret, { headers: { 'Content-Length': '262145' } }))).status, 413);
  assert.equal((await f.handler(signed(event, secret, { body: 'é'.repeat(131073), headers: { 'Content-Length': '1' } }))).status, 413);
  assert.equal(f.calls.environment, 0);
  assert.equal(f.calls.runtime, 0);
});

test('durable processing failures remain retryable without copying the event body, secrets or arbitrary diagnostics', async () => {
  for (const error of [new Error('private@example.invalid'),
    new PaymentError('processor_busy', 503, { body: event, secret })]) {
    const f = fixture({ handle: () => { throw error; } });
    const response = await f.handler(signed());
    assert.equal(response.status, 503);
    assert.equal((await response.json()).received, false);
    const diagnostics = JSON.stringify(f.calls.logs);
    for (const value of [secret, platformSecret, 'private@example.invalid', 'acct_fixture']) assert.equal(diagnostics.includes(value), false);
    assert.ok(diagnostics.includes(event.id));
  }
});
