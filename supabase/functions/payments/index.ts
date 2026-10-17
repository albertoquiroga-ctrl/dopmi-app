import { cors, failure, json, runtime } from '../_shared/runtime.ts';
import { PaymentError, paymentLog } from '../_shared/payments.mjs';
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  let action = 'authenticate';
  const requestId = crypto.randomUUID();
  try {
    const { service, native, nativeCase, actor } = runtime();
    const id = await actor(req);
    const input = await req.json();
    action = ['checkout','native_checkout','native_case_checkout','native_status','connect_status','connect_onboard','connect_session'].includes(input.action) ? input.action : 'invalid_action';
    if (input.action === 'native_case_checkout') {
      if (!nativeCase) throw new PaymentError('payments_not_configured', 503);
      return json(await nativeCase.submit(id, input));
    }
    if (['native_checkout', 'native_status'].includes(input.action)) {
      if (!native) throw new PaymentError('payments_not_configured', 503);
      return json(await (input.action === 'native_checkout' ? native.submit(id, input) : native.status(id, input)));
    }
    if (input.action === 'checkout') return json(await service.checkout(id, input));
    if (input.action === 'connect_status') return json(await service.connect(id, 'status'));
    if (input.action === 'connect_onboard') return json(await service.connect(id, 'onboard'));
    if (input.action === 'connect_session') return json(await service.connect(id, 'session'));
    return json({ error: 'invalid_action' }, 400);
  } catch (error) {
    paymentLog(console, 'payments_request_failed', { request_id: requestId, action, code: error instanceof PaymentError ? error.code : 'payment_unavailable', ...(error instanceof PaymentError ? error.context : {}) });
    return failure(error);
  }
});
