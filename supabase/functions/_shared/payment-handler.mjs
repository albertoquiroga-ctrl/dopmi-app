import { PaymentError, paymentLog } from './payments.mjs';

const actions = new Set(['checkout', 'native_checkout', 'native_case_checkout',
  'native_status', 'connect_status', 'connect_onboard', 'connect_session']);

// Authentication is deliberately outside the financial runtime: unauthenticated
// requests must never reach privileged database or Stripe account-binding reads.
export function paymentRequestHandler({ authenticate, createRuntime, json, failure, cors, logger = console }) {
  return async (req) => {
    if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
    let action = 'authenticate';
    const requestId = crypto.randomUUID();
    try {
      const actor = await authenticate(req);
      if (!actor) throw new PaymentError('sign_in_required', 401);
      const input = await req.json();
      action = actions.has(input?.action) ? input.action : 'invalid_action';
      if (action === 'invalid_action') return json({ error: 'invalid_action' }, 400);
      const { service, native, nativeCase } = await createRuntime();
      if (action === 'native_case_checkout') {
        if (!nativeCase) throw new PaymentError('payments_not_configured', 503);
        return json(await nativeCase.submit(actor, input));
      }
      if (action === 'native_checkout' || action === 'native_status') {
        if (!native) throw new PaymentError('payments_not_configured', 503);
        return json(await (action === 'native_checkout' ? native.submit(actor, input) : native.status(actor, input)));
      }
      if (action === 'checkout') return json(await service.checkout(actor, input));
      if (action === 'connect_status') return json(await service.connect(actor, 'status'));
      if (action === 'connect_onboard') return json(await service.connect(actor, 'onboard'));
      return json(await service.connect(actor, 'session'));
    } catch (error) {
      paymentLog(logger, 'payments_request_failed', { request_id: requestId, action,
        code: error instanceof PaymentError ? error.code : 'payment_unavailable',
        ...(error instanceof PaymentError ? error.context : {}) });
      return failure(error);
    }
  };
}
