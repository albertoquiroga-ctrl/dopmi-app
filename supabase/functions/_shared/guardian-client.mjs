import { PaymentError } from './payments.mjs';
import { GuardianBillingError } from './guardian-billing.mjs';

export const guardianClientFlags = ['DOPMI_GUARDIAN_CHECKOUT_ENABLED', 'DOPMI_GUARDIAN_WORKER_ENABLED',
  'DOPMI_GUARDIAN_SCHEDULE_ENABLED', 'DOPMI_GUARDIAN_COLLECTION_ENABLED', 'DOPMI_GUARDIAN_CHANGES_ENABLED', 'DOPMI_GUARDIAN_REFUNDS_ENABLED'];
export const guardianClientEnabled = env => guardianClientFlags.every(flag => env(flag) === 'true');
const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store',
  'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const reply = (body, status = 200) => new Response(JSON.stringify(body), { status, headers });

// Authenticate on the server and pass an explicit allowlist. Caller-supplied
// donor IDs, return URLs and status fields never reach checkout. A saved-method
// selection accepts only its opaque ID; the service verifies its customer ownership.
export function guardianClientHandler({ enabled, authenticate, checkout, method, methods, defaultMethod, removeMethod, addCard }) {
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
      if (input?.action === 'add_card') {
        if (Object.keys(input).some(key => !['action','key','consent','consent_version'].includes(key)) ||
            typeof addCard !== 'function' || input.consent !== true || input.consent_version !== 'saved-cards-2026-10-03' ||
            !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.key ?? ''))
          return reply({ error: 'invalid_request' }, 400);
        return reply(await addCard(actor.id, { key: input.key, consent: true, consent_version: input.consent_version }));
      }
      if (input?.action === 'methods') {
        if (Object.keys(input).some(key => key !== 'action') || typeof methods !== 'function')
          return reply({ error: 'invalid_request' }, 400);
        return reply(await methods(actor.id));
      }
      if (['default_method', 'remove_method'].includes(input?.action)) {
        const operation = input.action === 'remove_method' ? removeMethod : defaultMethod;
        const allowed = ['action', 'key', 'revision', 'consent', 'consent_version', 'payment_method_id'];
        if (Object.keys(input).some(key => !allowed.includes(key)) || typeof operation !== 'function' ||
            !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.key ?? '') ||
            !Number.isSafeInteger(input.revision) || input.revision < 0 || input.consent !== true ||
            input.consent_version !== 'guardian-2026-09-24' || !/^pm_[A-Za-z0-9]+$/.test(input.payment_method_id ?? ''))
          return reply({ error: 'invalid_request' }, 400);
        return reply(await operation(actor.id, { key: input.key, revision: input.revision,
          consent: true, consent_version: input.consent_version, selected_method_id: input.payment_method_id, remove_saved: input.action === 'remove_method' }));
      }
      if (!input || !['checkout', 'method'].includes(input.action) || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.key ?? '')
        || (input.action === 'checkout' && (!Number.isSafeInteger(input.gross_cents) || input.gross_cents < 1000 || input.gross_cents > 1000000))
        || (input.action === 'method' && (!Number.isSafeInteger(input.revision) || input.revision < 0))
        || input.consent !== true || input.consent_version !== 'guardian-2026-09-24') return reply({ error: 'invalid_request' }, 400);
      if (input.action === 'method') return reply(await method(actor.id, { key: input.key, revision: input.revision,
        consent: true, consent_version: 'guardian-2026-09-24' }));
      return reply(await checkout(actor.id, { key: input.key, gross_cents: input.gross_cents,
        consent: true, consent_version: 'guardian-2026-09-24' }));
    } catch (error) {
      const code = error instanceof PaymentError || error instanceof GuardianBillingError ? error.code : 'guardian_unavailable';
      return reply({ error: code }, error instanceof PaymentError ? Math.min(error.status, 503) : 503);
    }
  };
}
