import test from 'node:test';
import assert from 'node:assert/strict';
import { PaymentError } from '../../supabase/functions/_shared/payments.mjs';
import { paymentRequestHandler } from '../../supabase/functions/_shared/payment-handler.mjs';

const json = (data, status = 200) => Response.json(data, { status });
const failure = error => json({ error: error instanceof PaymentError ? error.code : 'payment_unavailable' },
  error instanceof PaymentError ? error.status : 503);
const request = (action, authorized = true, extra = {}) => new Request('https://example.invalid/payments', {
  method: 'POST', headers: { ...(authorized ? { Authorization: 'Bearer synthetic-token' } : {}), 'Content-Type': 'application/json' },
  body: JSON.stringify({ action, ...extra }),
});
function fixture(overrides = {}) {
  const events = [], logs = [];
  const route = name => async (actor, input) => { events.push({ name, actor, input }); return { ok: true }; };
  const handler = paymentRequestHandler({
    json, failure, cors: { 'Access-Control-Allow-Origin': '*' }, logger: { info: value => logs.push(value) },
    authenticate: async req => {
      events.push('authenticate');
      if (req.headers.get('Authorization') !== 'Bearer synthetic-token') throw new PaymentError('sign_in_required', 401);
      return 'authenticated-owner';
    },
    createRuntime: async () => {
      events.push('financial-runtime');
      return { service: { checkout: route('checkout'), connect: route('connect') },
        native: { submit: route('native-submit'), status: route('native-status') },
        nativeCase: { submit: route('case-submit') } };
    }, ...overrides,
  });
  return { handler, events, logs };
}

test('anonymous POST is rejected before financial runtime or provider access', async () => {
  const f = fixture();
  const response = await f.handler(request('native_checkout', false));
  assert.equal(response.status, 401);
  assert.deepEqual(f.events, ['authenticate']);
  assert.deepEqual(await response.json(), { error: 'sign_in_required' });
  assert.ok(!f.logs.join('').includes('synthetic-token'));
});

test('an unauthenticated result also cannot construct the financial runtime', async () => {
  let calls = 0;
  const f = fixture({ authenticate: async () => null, createRuntime: async () => { calls++; assert.fail('runtime'); } });
  assert.equal((await f.handler(request('checkout'))).status, 401);
  assert.equal(calls, 0);
});

test('OPTIONS and disallowed methods do not authenticate or access finances', async () => {
  const f = fixture();
  assert.equal((await f.handler(new Request('https://example.invalid', { method: 'OPTIONS' }))).status, 200);
  assert.equal((await f.handler(new Request('https://example.invalid'))).status, 405);
  assert.deepEqual(f.events, []);
});

test('invalid action cannot spend privileged runtime reads', async () => {
  const f = fixture();
  assert.equal((await f.handler(request('unknown'))).status, 400);
  assert.deepEqual(f.events, ['authenticate']);
});

test('all payment and Connect routes use the authenticated actor, never input actor', async () => {
  for (const [action, method] of [['checkout', 'checkout'], ['native_checkout', 'native-submit'],
    ['native_status', 'native-status'], ['native_case_checkout', 'case-submit'],
    ['connect_status', 'connect'], ['connect_onboard', 'connect'], ['connect_session', 'connect']]) {
    const f = fixture();
    const response = await f.handler(request(action, true, { actor: 'forged-owner' }));
    assert.equal(response.status, 200);
    assert.deepEqual(f.events.slice(0, 2), ['authenticate', 'financial-runtime']);
    assert.equal(f.events[2].name, method);
    assert.equal(f.events[2].actor, 'authenticated-owner');
  }
});

test('disabled native services fail without falling back to hosted checkout', async () => {
  for (const action of ['native_checkout', 'native_status', 'native_case_checkout']) {
    const f = fixture({ createRuntime: async () => ({ service: { checkout: () => assert.fail('hosted fallback') } }) });
    assert.equal((await f.handler(request(action))).status, 503);
  }
});

test('unavailable authenticated financial context fails closed without returning secrets', async () => {
  const f = fixture({ createRuntime: async () => { throw new Error('synthetic-private-configuration'); } });
  const response = await f.handler(request('connect_session'));
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'payment_unavailable' });
  assert.ok(!f.logs.join('').includes('synthetic-private-configuration'));
});
