import test from 'node:test';
import assert from 'node:assert/strict';
import { guardianPreflight } from '../../supabase/functions/_shared/guardian-preflight.mjs';

test('preflight rejects live and missing keys before any network request', async () => {
  for (const key of [undefined, '', 'sk_live_placeholder', 'rk_live_placeholder']) {
    await assert.rejects(() => guardianPreflight(key, () => assert.fail('Network call')), /payments_not_configured/);
  }
});

test('preflight only reads fixed Stripe endpoints and returns no credentials or objects', async () => {
  const key = 'sk_test_unit_placeholder';
  const result = await guardianPreflight(key, async (url, options) => {
    assert.equal(new URL(url).origin, 'https://api.stripe.com');
    assert.equal(new URL(url).search, '?limit=1');
    assert.equal(options.method, 'GET');
    assert.equal(options.redirect, 'error');
    assert.equal(options.body, undefined);
    assert.equal(options.headers.Authorization, `Bearer ${key}`);
    return new Response('private_stripe_object', { status: 200 });
  });
  assert.equal(result.checks.length, 16);
  assert.equal(result.reads_ready, true);
  assert.equal(result.write_permissions, 'standard_key');
  assert.ok(!JSON.stringify(result).includes(key));
  assert.ok(!JSON.stringify(result).includes('private_stripe_object'));
});

test('successful GETs do not claim restricted-key write permissions', async () => {
  const result = await guardianPreflight('rk_test_unit_placeholder', async () => new Response('{}'));
  assert.equal(result.reads_ready, true);
  assert.equal(result.key_type, 'restricted');
  assert.equal(result.write_permissions, 'not_verified');
});

test('denials and network failures fail the check without exposing errors', async () => {
  const result = await guardianPreflight('rk_test_unit_placeholder', async (url) => {
    if (url.includes('/customers?')) throw new Error('private_error');
    return new Response('private_denial', { status: url.includes('/invoices?') ? 403 : 200 });
  });
  assert.equal(result.reads_ready, false);
  assert.equal(result.checks.find((check) => check.resource === 'customers').status, null);
  assert.equal(result.checks.find((check) => check.resource === 'invoices').status, 403);
  assert.ok(!JSON.stringify(result).includes('private_'));
});
