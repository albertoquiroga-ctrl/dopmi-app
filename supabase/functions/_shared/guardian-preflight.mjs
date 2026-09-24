import { requireTestKey } from './payments.mjs';

const resources = ['events', 'customers', 'checkout/sessions', 'setup_intents',
  'payment_methods', 'products', 'prices', 'subscriptions', 'invoices',
  'invoice_payments', 'payment_intents', 'charges', 'balance_transactions',
  'accounts', 'transfers', 'refunds'];

// Called only behind payment-worker's existing secret. No Stripe objects,
// credential values or request/response bodies are returned or logged.
// GET checks do not prove writes with a restricted key or an integrated payment.
export async function guardianPreflight(key, fetcher = fetch) {
  requireTestKey(key);
  const checks = [];
  for (let offset = 0; offset < resources.length; offset += 4) {
    checks.push(...await Promise.all(resources.slice(offset, offset + 4).map(async (resource) => {
      try {
        const response = await fetcher(`https://api.stripe.com/v1/${resource}?limit=1`, {
          method: 'GET', redirect: 'error',
          headers: { Authorization: `Bearer ${key}`, 'Stripe-Version': '2026-08-26.dahlia' },
          signal: AbortSignal.timeout(15000),
        });
        await response.body?.cancel();
        return { resource, status: response.status, ok: response.status === 200 };
      } catch {
        return { resource, status: null, ok: false };
      }
    })));
  }
  const restricted = key.startsWith('rk_test_');
  return { test_mode: true, key_type: restricted ? 'restricted' : 'standard',
    reads_ready: checks.every((check) => check.ok),
    write_permissions: restricted ? 'not_verified' : 'standard_key', checks };
}
