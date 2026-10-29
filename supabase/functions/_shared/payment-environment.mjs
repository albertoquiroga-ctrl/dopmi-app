import { PaymentError, requireStripeKey } from './payments.mjs';

const profiles = Object.freeze({
  test: Object.freeze({
    projectRef: 'ohqxranynackjignryep',
    expectedLivemode: false,
    accountId: null,
    keyName: 'STRIPE_SECRET_KEY_H4_TEST',
    webhookName: 'STRIPE_WEBHOOK_SECRET_H4_TEST',
  }),
  production: Object.freeze({
    projectRef: 'ysaoeuidcvgtlmphmeyb',
    expectedLivemode: true,
    accountId: null,
    keyName: 'STRIPE_SECRET_KEY_LIVE',
    webhookName: 'STRIPE_WEBHOOK_SECRET_LIVE',
  }),
});

// Local Supabase acceptance remains TEST only; none is a production endpoint.
const localTestUrls = new Set([
  'http://127.0.0.1:54321',
  'http://localhost:54321',
  'http://kong:8000',
]);

function invalid() {
  // Never include configuration values in errors, logs or HTTP replies.
  throw new PaymentError('payments_environment_invalid', 503);
}

// This input comes exclusively from the server environment, never HTTP data.
// Historical DEV defaults to TEST; selecting production requires all bindings
// and a separate activation gate. A key prefix cannot select the environment.
export function resolvePaymentEnvironment(env) {
  if (!env || typeof env !== 'object' || Array.isArray(env)) invalid();
  const environment = env.DOPMI_ENVIRONMENT ?? 'test';
  if (!Object.hasOwn(profiles, environment)) invalid();
  const profile = profiles[environment];
  const url = typeof env.SUPABASE_URL === 'string'
    ? env.SUPABASE_URL.replace(/\/$/, '') : '';
  const local = environment === 'test' && localTestUrls.has(url);
  if (!local && url !== `https://${profile.projectRef}.supabase.co`) invalid();
  if (profile.expectedLivemode) {
    if (env.DOPMI_PAYMENTS_LIVE_ENABLED !== 'true') invalid();
  } else if (env.DOPMI_PAYMENTS_LIVE_ENABLED != null
      && env.DOPMI_PAYMENTS_LIVE_ENABLED !== 'false') {
    invalid();
  }
  const other = profiles[environment === 'test' ? 'production' : 'test'];
  if (env[other.keyName] || env[other.webhookName]) invalid();
  const secretKey = env[profile.keyName];
  requireStripeKey(secretKey, profile.expectedLivemode);
  const accountId = profile.expectedLivemode ? env.STRIPE_PLATFORM_ACCOUNT_ID_LIVE : null;
  if (profile.expectedLivemode
      && (typeof accountId !== 'string' || !/^acct_[A-Za-z0-9]+$/.test(accountId))) invalid();
  const webhookSecret = env[profile.webhookName];
  if (typeof webhookSecret !== 'string' || !/^whsec_[A-Za-z0-9_]+$/.test(webhookSecret)) invalid();
  return Object.freeze({
    environment,
    projectRef: local ? 'local' : profile.projectRef,
    expectedLivemode: profile.expectedLivemode,
    accountId,
    secretKey,
    webhookSecret,
    returnUrl: `${url}/functions/v1/payment-return`,
  });
}

// A key for the correct processor mode must not operate against a database
// still commissioned for the other mode. The read-only RPC is service-only.
export async function assertPaymentDatabaseEnvironment(context, load) {
  let result;
  try { result = await load(); } catch { invalid(); }
  const data = result?.data;
  const consentVersion = context.expectedLivemode
    ? 'oneoff-live-2026-10-28' : 'oneoff-test-2026-10-15';
  if (result?.error || !data || Array.isArray(data)
      || data.environment !== context.environment
      || data.expected_livemode !== context.expectedLivemode
      || data.oneoff_consent_version !== consentVersion) invalid();
  return context;
}

// Account has no required livemode field. Bind the LIVE credential to Dopmi's
// registered platform before any service can write provider objects. Do not
// return or log the PII-bearing account response.
export async function assertStripeAccountBinding(context, fetcher = fetch) {
  if (!context.expectedLivemode) return context;
  requireStripeKey(context.secretKey, true);
  if (context.environment !== 'production' || !/^acct_[A-Za-z0-9]+$/.test(context.accountId ?? '')) invalid();
  try {
    const response = await fetcher('https://api.stripe.com/v1/account', {
      method: 'GET',
      redirect: 'error',
      headers: { Authorization: `Bearer ${context.secretKey}`, 'Stripe-Version': '2026-08-26.dahlia' },
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) {
      await response.body?.cancel();
      invalid();
    }
    const account = await response.json();
    if (account?.object !== 'account' || account.id !== context.accountId
        || ('livemode' in account && account.livemode !== true)) invalid();
  } catch { invalid(); }
  return context;
}
