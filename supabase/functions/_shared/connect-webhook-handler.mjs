import { PaymentError, paymentLog, verifySignature } from './payments.mjs';

const maxBytes = 262144;

async function boundedBody(req) {
  if (Number(req.headers.get('Content-Length') ?? 0) > maxBytes) {
    await req.body?.cancel();
    throw new PaymentError('body_too_large', 413);
  }
  if (!req.body) return '';
  const reader = req.body.getReader();
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > maxBytes) {
        await reader.cancel();
        throw new PaymentError('body_too_large', 413);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return new TextDecoder().decode(bytes);
}

// This destination receives no payment or customer events. After validating its
// own signature, only event/account identifiers enter the durable server queue.
export function connectWebhookRequestHandler({ loadEnvironment, createRuntime, json, failure, logger = console }) {
  return async req => {
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
    let eventId;
    try {
      const body = await boundedBody(req);
      const context = loadEnvironment();
      if (typeof context.connectWebhookSecret !== 'string'
          || !/^whsec_[A-Za-z0-9_]+$/.test(context.connectWebhookSecret)
          || context.connectWebhookSecret === context.webhookSecret) {
        throw new PaymentError('connect_webhook_not_configured', 503);
      }
      const event = await verifySignature(body, req.headers.get('Stripe-Signature'),
        context.connectWebhookSecret, Date.now(), { expectedLivemode: context.expectedLivemode });
      if (!/^evt_[A-Za-z0-9]+$/.test(event.id) || event.type !== 'account.updated'
          || typeof event.account !== 'string' || !/^acct_[A-Za-z0-9]+$/.test(event.account)
          || event.data?.object?.object !== 'account' || event.data.object.id !== event.account) {
        throw new PaymentError('invalid_connect_event', 400);
      }
      eventId = event.id;
      const { service } = await createRuntime();
      return json(await service.handleConnectWebhook(event.id, event.account));
    } catch (error) {
      const code = error instanceof PaymentError ? error.code : 'payment_unavailable';
      paymentLog(logger, 'stripe_connect_webhook_failed', { event_id: eventId, code });
      if (eventId) return json({ error: code, received: false }, 503);
      return failure(error);
    }
  };
}
