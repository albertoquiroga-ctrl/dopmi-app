import { PaymentError, paymentLog, verifySignature } from '../_shared/payments.mjs';
import { failure, json, runtime } from '../_shared/runtime.ts';

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  let eventId: string | undefined;
  try {
    if (Number(req.headers.get('Content-Length') ?? 0) > 262144) return json({ error: 'body_too_large' }, 413);
    const body = await req.text();
    if (body.length > 262144) return json({ error: 'body_too_large' }, 413);
    // H4 uses an isolated sandbox destination without replacing the
    // programmer's pre-existing webhook configuration.
    const webhookSecret =
      Deno.env.get('STRIPE_WEBHOOK_SECRET_H4_TEST') ??
      Deno.env.get('STRIPE_WEBHOOK_SECRET');
    const event = await verifySignature(
      body,
      req.headers.get('Stripe-Signature'),
      webhookSecret,
    );
    eventId = event.id;
    if (Deno.env.get('DOPMI_GUARDIAN_WORKER_ENABLED') === 'true') {
      const { guardianRuntime } = await import('../_shared/guardian-runtime.ts');
      const guardian = guardianRuntime();
      const handled = await guardian.initial.handleWebhook(event.id);
      if (handled) {
        const result = await guardian.work();
        return json({ ...handled, ...result }, result.failed > 0 ? 503 : 200);
      }
    }
    const { service } = runtime();
    // The event is durably queued and claimed before processing. Required
    // transfers/refunds finish before the event is marked done; failures return
    // a retryable non-2xx response to Stripe.
    return json(await service.handleWebhook(event.id));
  } catch (error) {
    paymentLog(console, 'stripe_webhook_failed', { event_id: eventId, code: error instanceof PaymentError ? error.code : 'payment_unavailable', ...(error instanceof PaymentError ? error.context : {}) });
    if (eventId) return json({ error: error instanceof PaymentError ? error.code : 'payment_unavailable', received: false }, 503);
    return failure(error);
  }
});
