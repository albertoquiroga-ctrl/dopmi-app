import { failure, json, runtime } from '../_shared/runtime.ts';
Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  const secret = Deno.env.get('DOPMI_WORKER_SECRET');
  if (!secret || req.headers.get('Authorization') !== `Bearer ${secret}`) return json({ error: 'access_denied' }, 401);
  try {
    const input = await req.json().catch(() => ({}));
    if (input.action === 'reprocess_donation') {
      const d = await runtime().service.reprocessDonation(input.donation_id);
      return json({ donation_id: d.id, payment_status: d.payment_status, transfer_status: d.transfer_status,
        transfer_id: d.stripe_transfer_id, allocated_cents: d.allocated_cents, refund_status: d.refund_status });
    }
    if (input.action === 'reprocess_guardian_invoice') {
      const { guardianRuntime } = await import('../_shared/guardian-runtime.ts');
      const guardian = guardianRuntime();
      const settled = await guardian.reconcileInvoice(input.invoice_id);
      const result = await guardian.work(10, settled.cycle_id);
      return json({ cycle_id: settled.cycle_id, ...result }, result.failed > 0 ? 503 : 200);
    }
    if (input.action && input.action !== 'reconcile') return json({ error: 'invalid_action' }, 400);
    const result = await runtime().service.reconcile();
    if (Deno.env.get('DOPMI_GUARDIAN_WORKER_ENABLED') === 'true') {
      const { guardianRuntime } = await import('../_shared/guardian-runtime.ts');
      const guardian = await guardianRuntime().reconcile();
      return json({ ...result, guardian }, result.failed + guardian.failed > 0 ? 503 : 200);
    }
    return json(result, result.failed > 0 ? 503 : 200);
  } catch (error) { return failure(error); }
});
