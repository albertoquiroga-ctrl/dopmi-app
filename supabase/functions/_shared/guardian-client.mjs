import { PaymentError } from './payments.mjs';
import { GuardianBillingError } from './guardian-billing.mjs';

export const guardianClientFlags = ['DOPMI_GUARDIAN_CHECKOUT_ENABLED', 'DOPMI_GUARDIAN_WORKER_ENABLED',
  'DOPMI_GUARDIAN_SCHEDULE_ENABLED', 'DOPMI_GUARDIAN_COLLECTION_ENABLED', 'DOPMI_GUARDIAN_CHANGES_ENABLED'];
export const guardianClientEnabled = env => guardianClientFlags.every(flag => env(flag) === 'true');
const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store',
  'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const reply = (body, status = 200) => new Response(JSON.stringify(body), { status, headers });

// Authenticate on the server and pass an explicit allowlist. Caller-supplied
// donor IDs, return URLs, processor IDs and status fields never reach checkout.
export function guardianClientHandler({ enabled, authenticate, checkout }) {
  return async req => {
    if (req.method === 'OPTIONS') return new Response(null, { headers });
    if (req.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405);
    if (!enabled()) return reply({ error: 'guardian_disabled' }, 503);
    try {
      const token = req.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
      if (!token) return reply({ error: 'sign_in_required' }, 401);
      const actor = await authenticate(token);
      if (!actor?.id || !actor.email_confirmed_at) return reply({ error: 'sign_in_required' }, 401);
      const text = await req.text();
      if (text.length > 4096) return reply({ error: 'invalid_request' }, 400);
      let input; try { input = JSON.parse(text); } catch { return reply({ error: 'invalid_request' }, 400); }
      if (!input || input.action !== 'checkout' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.key ?? '')
        || !Number.isSafeInteger(input.gross_cents) || input.gross_cents < 1000 || input.gross_cents > 1000000
        || input.consent !== true || input.consent_version !== 'guardian-2026-09-24') return reply({ error: 'invalid_request' }, 400);
      return reply(await checkout(actor.id, { key: input.key, gross_cents: input.gross_cents,
        consent: true, consent_version: 'guardian-2026-09-24' }));
    } catch (error) {
      const code = error instanceof PaymentError || error instanceof GuardianBillingError ? error.code : 'guardian_unavailable';
      return reply({ error: code }, error instanceof PaymentError ? Math.min(error.status, 503) : 503);
    }
  };
}
