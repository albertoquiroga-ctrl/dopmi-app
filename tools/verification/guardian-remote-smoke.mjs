import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

// Read-only probes: no user/session token, worker secret or Stripe key.
// --expect-enabled changes the assertion, never the server configuration.
const args = process.argv.slice(2);
assert.ok(args.every(arg => arg === '--expect-enabled'), 'Only --expect-enabled is supported');
const enabled = args.includes('--expect-enabled');
const config = JSON.parse(await readFile(new URL('../../apps/mobile/config.local.json', import.meta.url), 'utf8'));
assert.equal(config.SUPABASE_URL, 'https://ohqxranynackjignryep.supabase.co', 'Use the agreed Dopmi test project');
assert.match(config.SUPABASE_PUBLISHABLE_KEY ?? '', /^sb_publishable_[A-Za-z0-9_-]+$/, 'Use only a publishable key');
const headers = { apikey: config.SUPABASE_PUBLISHABLE_KEY, 'Content-Type': 'application/json' };
let passed = 0;
async function probe(path, { method = 'POST', body = {}, status, error, inspect } = {}) {
  const response = await fetch(config.SUPABASE_URL + path, {
    method, headers, redirect: 'error', signal: AbortSignal.timeout(25000),
    ...(method === 'POST' ? { body: JSON.stringify(body) } : {}),
  });
  assert.equal(response.status, status, `${method} ${path}: expected HTTP ${status}, got ${response.status}`);
  if (error) assert.equal((await response.json()).error, error, `${path}: error code`);
  if (inspect) await inspect(response);
  passed++;
  console.log(`PASS ${passed}: ${method} ${path} -> ${status}`);
}

await probe('/functions/v1/guardian-client', { status: enabled ? 401 : 503, error: enabled ? 'sign_in_required' : 'guardian_disabled' });
await probe('/functions/v1/guardian-client', { method: 'GET', status: 405, error: 'method_not_allowed' });
await probe('/functions/v1/guardian-client', { method: 'OPTIONS', status: 200, inspect: async response => {
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.ok(response.headers.get('access-control-allow-methods')?.includes('POST'));
} });
await probe('/functions/v1/payment-worker', { status: 401, error: 'access_denied' });
await probe('/functions/v1/stripe-webhook', { status: 400, error: 'invalid_signature' });
await probe('/functions/v1/payment-return', { method: 'GET', status: 200, inspect: async response => {
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.ok(response.headers.get('content-security-policy')?.includes("default-src 'none'"));
  assert.match(response.headers.get('content-type') ?? '', /^text\/plain\b/);
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  const text = await response.text();
  assert.ok(text.includes('Cuenta > Mi plan Guardián'));
  assert.ok(text.includes('Esta pantalla no confirma un pago'));
  assert.ok(text.includes('No inicies otro pago'));
  assert.ok(!/<[a-z!]/i.test(text), 'Return instructions must be readable without HTML rendering');
} });

// An anonymous caller must get an explicit privilege denial, not a missing-RPC
// response. This also catches unapplied migrations or a stale API schema cache.
for (const rpc of ['activation', 'subscription', 'settlement', 'schedule', 'collection', 'recovery', 'change', 'method', 'refund']) {
  await probe(`/rest/v1/rpc/dopmi_guardian_${rpc}_server`, {
    body: { operation: 'get', data: {} }, status: 401,
    inspect: async response => assert.equal((await response.json()).code, '42501'),
  });
}
for (const rpc of ['state', 'plan', 'history']) {
  await probe(`/rest/v1/rpc/dopmi_guardian_${rpc}`, {
    status: 401, inspect: async response => assert.equal((await response.json()).code, '42501'),
  });
}
console.log(`${passed} remote checks passed; checkout gate ${enabled ? 'enabled, requires sign-in' : 'closed'}.`);
console.log('This does not verify Stripe key permissions, a signed webhook, payment, Cron or a device journey.');
