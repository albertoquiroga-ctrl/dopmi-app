import { verifySignature } from '../_shared/payments.mjs';
import { failure, json, runtime } from '../_shared/runtime.ts';
Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  try {
    if (Number(req.headers.get('Content-Length') ?? 0) > 262144) return json({ error: 'body_too_large' }, 413);
    const body = await req.text();
    if (body.length > 262144) return json({ error: 'body_too_large' }, 413);
    const event = await verifySignature(body, req.headers.get('Stripe-Signature'), Deno.env.get('STRIPE_WEBHOOK_SECRET'));
    const { rpc } = runtime();
    await rpc('enqueue', { event_id: event.id });
    // Durable queue first. Cron processes it even if this request ends immediately.
    return json({ received: true });
  } catch (error) { return failure(error); }
});
