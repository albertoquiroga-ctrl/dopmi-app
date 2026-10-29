import { PaymentError, requireStripeKey } from './payments.mjs';

const resources = ['events', 'customers', 'checkout/sessions', 'setup_intents',
  'payment_methods', 'products', 'prices', 'subscriptions', 'invoices',
  'invoice_payments', 'payment_intents', 'charges', 'balance_transactions',
  'accounts', 'transfers', 'refunds'];

// Called only behind payment-worker's existing secret. No Stripe objects,
// credential values or request/response bodies are returned or logged.
// GET checks do not prove writes with a restricted key or an integrated payment.
/**
 * @param {string} key
 * @param {typeof fetch} fetcher
 * @param {{ expectedLivemode?: boolean, expectedAccountId?: string }} options
 */
export async function guardianPreflight(key, fetcher = fetch, { expectedLivemode = false, expectedAccountId } = {}) {
  requireStripeKey(key, expectedLivemode);
  if (expectedAccountId !== undefined && (typeof expectedAccountId !== 'string' || !/^acct_[A-Za-z0-9]+$/.test(expectedAccountId)))
    throw new PaymentError('payments_not_configured', 503);
  const checks = [];
  if (expectedAccountId !== undefined) {
    // Account has no livemode. Its exact server-configured identity and the
    // key's mode bind this read; never expose its PII-bearing payload.
    let status = null, ok = false;
    try {
      const response = await fetcher('https://api.stripe.com/v1/account', {
        method: 'GET', redirect: 'error',
        headers: { Authorization: `Bearer ${key}`, 'Stripe-Version': '2026-08-26.dahlia' },
        signal: AbortSignal.timeout(15000),
      });
      status = response.status;
      if (response.ok) {
        const account = await response.json();
        ok = account?.object === 'account' && account.id === expectedAccountId &&
          (!('livemode' in account) || account.livemode === expectedLivemode);
      } else await response.body?.cancel();
    } catch { /* Only the safe status below leaves this boundary. */ }
    checks.push({ resource: 'account', status, ok });
  }
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
  const restricted = key.startsWith('rk_');
  return { test_mode: !expectedLivemode, key_type: restricted ? 'restricted' : 'standard',
    reads_ready: checks.every((check) => check.ok),
    write_permissions: restricted ? 'not_verified' : 'standard_key', checks };
}
