import test from 'node:test';
import assert from 'node:assert/strict';
import { assertPaymentDatabaseEnvironment, assertStripeAccountBinding, resolvePaymentEnvironment } from '../../supabase/functions/_shared/payment-environment.mjs';

const dev = {
  SUPABASE_URL: 'https://ohqxranynackjignryep.supabase.co',
  STRIPE_SECRET_KEY_H4_TEST: 'rk_test_fixture',
  STRIPE_WEBHOOK_SECRET_H4_TEST: 'whsec_test_fixture',
};
const live = {
  DOPMI_ENVIRONMENT: 'production',
  SUPABASE_URL: 'https://ysaoeuidcvgtlmphmeyb.supabase.co',
  DOPMI_PAYMENTS_LIVE_ENABLED: 'true',
  STRIPE_SECRET_KEY_LIVE: 'rk_live_fixture',
  STRIPE_WEBHOOK_SECRET_LIVE: 'whsec_live_fixture',
  STRIPE_CONNECT_WEBHOOK_SECRET_LIVE: 'whsec_connect_live_fixture',
  STRIPE_PLATFORM_ACCOUNT_ID_LIVE: 'acct_ProductionFixture',
};

function denied(env) {
  assert.throws(() => resolvePaymentEnvironment(env), error => {
    assert.equal(error.status, 503);
    for (const name of Object.keys(env ?? {}).filter(n => /KEY|SECRET/.test(n))) {
      const value = env[name];
      if (value) assert.ok(!error.message.includes(value));
    }
    return true;
  });
}

test('legacy DEV resolves TEST and keeps the registered callback', () => {
  const resolved = resolvePaymentEnvironment(dev);
  assert.equal(resolved.environment, 'test');
  assert.equal(resolved.expectedLivemode, false);
  assert.equal(resolved.projectRef, 'ohqxranynackjignryep');
  assert.equal(resolved.returnUrl, `${dev.SUPABASE_URL}/functions/v1/payment-return`);
  assert.ok(Object.isFrozen(resolved));
});

test('production binds LIVE activation, project, account and separate secrets', () => {
  const resolved = resolvePaymentEnvironment(live);
  assert.equal(resolved.environment, 'production');
  assert.equal(resolved.expectedLivemode, true);
  assert.equal(resolved.accountId, live.STRIPE_PLATFORM_ACCOUNT_ID_LIVE);
  assert.equal(resolved.secretKey, live.STRIPE_SECRET_KEY_LIVE);
  assert.equal(resolved.webhookSecret, live.STRIPE_WEBHOOK_SECRET_LIVE);
  assert.equal(resolved.connectWebhookSecret, live.STRIPE_CONNECT_WEBHOOK_SECRET_LIVE);
  assert.equal(resolved.returnUrl, `${live.SUPABASE_URL}/functions/v1/payment-return`);
  assert.ok(Object.isFrozen(resolved));
});

test('local Supabase acceptance stays TEST and cannot select LIVE', () => {
  for (const url of ['http://127.0.0.1:54321', 'http://localhost:54321', 'http://kong:8000']) {
    const resolved = resolvePaymentEnvironment({ ...dev, SUPABASE_URL: url });
    assert.equal(resolved.projectRef, 'local');
    assert.equal(resolved.expectedLivemode, false);
    denied({ ...live, SUPABASE_URL: url });
  }
});

test('production never activates from a key prefix or truthy flag', () => {
  for (const flag of [undefined, '', 'false', 'TRUE', '1', true]) {
    denied({ ...live, DOPMI_PAYMENTS_LIVE_ENABLED: flag });
  }
  denied({ ...live, DOPMI_ENVIRONMENT: undefined });
});

test('registered environments reject crossed or unregistered backends', () => {
  denied({ ...live, SUPABASE_URL: dev.SUPABASE_URL });
  denied({ ...dev, SUPABASE_URL: live.SUPABASE_URL });
  for (const url of ['https://foreign.supabase.co', 'http://ysaoeuidcvgtlmphmeyb.supabase.co',
    `${live.SUPABASE_URL}/functions`, `${live.SUPABASE_URL}?other=1`]) {
    denied({ ...live, SUPABASE_URL: url });
  }
});

test('unknown environments and invalid inputs fail closed', () => {
  for (const value of ['', 'live', 'staging', 'PRODUCTION', 'toString', true]) {
    denied({ ...live, DOPMI_ENVIRONMENT: value });
  }
  for (const value of [undefined, null, [], 'production']) denied(value);
});

test('opposite mode credentials and LIVE flags cannot be carried across', () => {
  denied({ ...dev, STRIPE_CONNECT_WEBHOOK_SECRET_LIVE: live.STRIPE_CONNECT_WEBHOOK_SECRET_LIVE });
  denied({ ...live, STRIPE_CONNECT_WEBHOOK_SECRET_H4_TEST: 'whsec_connect_test_fixture' });
  denied({ ...dev, DOPMI_PAYMENTS_LIVE_ENABLED: 'true' });
  denied({ ...dev, STRIPE_SECRET_KEY_LIVE: live.STRIPE_SECRET_KEY_LIVE });
  denied({ ...dev, STRIPE_WEBHOOK_SECRET_LIVE: live.STRIPE_WEBHOOK_SECRET_LIVE });
  denied({ ...live, STRIPE_SECRET_KEY_H4_TEST: dev.STRIPE_SECRET_KEY_H4_TEST });
  denied({ ...live, STRIPE_WEBHOOK_SECRET_H4_TEST: dev.STRIPE_WEBHOOK_SECRET_H4_TEST });
  denied({ ...dev, STRIPE_SECRET_KEY_H4_TEST: live.STRIPE_SECRET_KEY_LIVE });
  denied({ ...live, STRIPE_SECRET_KEY_LIVE: dev.STRIPE_SECRET_KEY_H4_TEST });
});

test('generic keys and webhook secrets never substitute for isolated credentials', () => {
  denied({ ...live, STRIPE_SECRET_KEY_LIVE: undefined, STRIPE_SECRET_KEY: live.STRIPE_SECRET_KEY_LIVE });
  denied({ ...dev, STRIPE_SECRET_KEY_H4_TEST: undefined, STRIPE_SECRET_KEY: dev.STRIPE_SECRET_KEY_H4_TEST });
  denied({ ...live, STRIPE_WEBHOOK_SECRET_LIVE: undefined, STRIPE_WEBHOOK_SECRET: live.STRIPE_WEBHOOK_SECRET_LIVE });
  denied({ ...dev, STRIPE_WEBHOOK_SECRET_H4_TEST: undefined, STRIPE_WEBHOOK_SECRET: dev.STRIPE_WEBHOOK_SECRET_H4_TEST });
});

test('public keys and absent or malformed webhook bindings cannot start a server', () => {
  for (const secret of [undefined, '', 'not_a_webhook_secret', live.STRIPE_WEBHOOK_SECRET_LIVE]) {
    denied({ ...live, STRIPE_CONNECT_WEBHOOK_SECRET_LIVE: secret });
  }
  for (const key of [undefined, '', 'pk_live_fixture', 'rk_test_fixture']) {
    denied({ ...live, STRIPE_SECRET_KEY_LIVE: key });
  }
  for (const secret of [undefined, '', 'not_a_webhook_secret']) {
    denied({ ...live, STRIPE_WEBHOOK_SECRET_LIVE: secret });
  }
  for (const accountId of [undefined, '', 'cus_NotAnAccount']) {
    denied({ ...live, STRIPE_PLATFORM_ACCOUNT_ID_LIVE: accountId });
  }
});

test('server and database agree on mode and consent before processing', async () => {
  for (const env of [dev, live]) {
    const context = resolvePaymentEnvironment(env);
    const result = await assertPaymentDatabaseEnvironment(context, async () => ({ data: {
      environment: context.environment,
      expected_livemode: context.expectedLivemode,
      oneoff_consent_version: context.expectedLivemode ? 'oneoff-live-2026-10-28' : 'oneoff-test-2026-10-15',
    }, error: null }));
    assert.equal(result, context);
  }
});

test('missing, unavailable or crossed database binding cannot commission LIVE', async () => {
  const context = resolvePaymentEnvironment(live);
  const valid = { environment: 'production', expected_livemode: true, oneoff_consent_version: 'oneoff-live-2026-10-28' };
  for (const result of [{ data: null }, { data: [] }, { error: { message: 'unavailable' } },
    { data: { ...valid, environment: 'test' } },
    { data: { ...valid, expected_livemode: false } },
    { data: { ...valid, expected_livemode: 'true' } },
    { data: { ...valid, oneoff_consent_version: 'oneoff-test-2026-10-15' } }]) {
    await assert.rejects(() => assertPaymentDatabaseEnvironment(context, async () => result), { code: 'payments_environment_invalid' });
  }
  await assert.rejects(() => assertPaymentDatabaseEnvironment(context, async () => { throw new Error('private failure'); }),
    error => error.code === 'payments_environment_invalid' && !error.message.includes('private failure'));
});

test('LIVE account binding reads the configured account without returning its payload', async () => {
  const context = resolvePaymentEnvironment(live);
  let calls = 0;
  const result = await assertStripeAccountBinding(context, async (url, options) => {
    calls++;
    assert.equal(url, 'https://api.stripe.com/v1/account');
    assert.equal(options.method, 'GET');
    assert.equal(options.redirect, 'error');
    return Response.json({ object: 'account', id: context.accountId, private_contact: 'synthetic-private-value' });
  });
  assert.equal(calls, 1);
  assert.equal(result, context);
  assert.equal(result.private_contact, undefined);
});

test('a wrong LIVE account or provider failure prevents service construction', async () => {
  const context = resolvePaymentEnvironment(live);
  for (const account of [{ object: 'account', id: 'acct_foreign' },
    { object: 'account', id: context.accountId, livemode: false },
    { object: 'account', id: context.accountId, livemode: 'true' }]) {
    await assert.rejects(() => assertStripeAccountBinding(context, async () => Response.json(account)),
      { code: 'payments_environment_invalid' });
  }
  await assert.rejects(() => assertStripeAccountBinding(context, async () => new Response('', { status: 403 })),
    { code: 'payments_environment_invalid' });
  await assert.rejects(() => assertStripeAccountBinding(context, async () => { throw new Error('synthetic-private-value'); }),
    error => error.code === 'payments_environment_invalid' && !error.message.includes('synthetic-private-value'));
});

test('legacy TEST does not invent a new LIVE account-read requirement', async () => {
  const context = resolvePaymentEnvironment(dev);
  const result = await assertStripeAccountBinding(context, async () => { assert.fail('unexpected provider call'); });
  assert.equal(result, context);
});
