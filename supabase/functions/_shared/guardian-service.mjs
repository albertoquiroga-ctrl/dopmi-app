import { GuardianBillingError } from './guardian-billing.mjs';
import { readGuardianPaidEvidence } from './guardian-reconciliation.mjs';
import { paymentLog } from './payments.mjs';

const attentionCodes = new Set(['guardian_destination_mismatch', 'guardian_charge_mismatch',
  'guardian_transfer_mismatch', 'guardian_refund_mismatch', 'guardian_charge_needs_review']);
const fail = code => { throw new GuardianBillingError(code); };
const objectId = object => typeof object === 'string' ? object : object?.id;

// All mutable processor operations use persisted jobs and a bounded retry
// window shorter than Stripe's minimum idempotency retention (24 hours).
export function guardianService({ stripe, rpc, lookupSubscription, logger = console }) {
  async function reconcileInvoice(invoiceId) {
    if (!/^in_[A-Za-z0-9]+$/.test(invoiceId ?? '')) fail('invalid_invoice_identity');
    const binding = await rpc('lookup_invoice', { invoice_id: invoiceId });
    if (!binding) fail('guardian_invoice_not_bound');
    if (binding.settlement) return binding.settlement;
    try {
      const evidence = await readGuardianPaidEvidence({ stripe, lookupSubscription }, invoiceId);
      return await rpc('settle', evidence);
    } finally { await rpc('checked', { invoice_id: invoiceId }); }
  }
  function validateCharge(charge, settled) {
    if (charge?.id !== settled.charge_id || charge.livemode !== false
      || objectId(charge.payment_intent) !== settled.payment_intent_id || charge.currency !== 'mxn'
      || charge.amount !== settled.gross_cents || charge.paid !== true || charge.captured !== true)
      fail('guardian_charge_mismatch');
    if (charge.disputed !== false) fail('guardian_charge_needs_review');
  }
  async function execute(job) {
    try {
      const settled = await rpc('get', { cycle_id: job.cycle_id });
      if (!settled) fail('guardian_settlement_missing');
      const charge = await stripe.charges.retrieve(settled.charge_id);
      validateCharge(charge, settled);
      let result;
      if (job.kind === 'transfer') {
        if (charge.amount_refunded !== 0) fail('guardian_charge_needs_review');
        const allocation = settled.allocations.find(a => a.expense_id === job.expense_id);
        if (!allocation || allocation.amount_cents <= 0 || settled.refund_cents !== 0) fail('guardian_transfer_mismatch');
        const destination = await rpc('destination', { expense_id: job.expense_id });
        if (destination?.owner_id !== allocation.rescuer_id || destination.account_id !== allocation.destination)
          fail('guardian_destination_mismatch');
        if (!destination.payable) fail('guardian_destination_unavailable');
        const account = await stripe.accounts.retrieve(allocation.destination);
        if (account.id !== allocation.destination || account.capabilities?.transfers !== 'active'
          || account.payouts_enabled !== true) fail('guardian_destination_unavailable');
        const fields = { amount: allocation.amount_cents, currency: 'mxn', destination: allocation.destination,
          source_transaction: settled.charge_id, transfer_group: `dopmi_guardian_${job.cycle_id}`,
          metadata: { dopmi_guardian_cycle: job.cycle_id, dopmi_guardian_expense: job.expense_id } };
        result = await stripe.transfers.create(fields, { idempotencyKey: job.job_key });
        if (!/^tr_[A-Za-z0-9]+$/.test(result?.id ?? '') || result.livemode !== false
          || result.amount !== fields.amount || result.currency !== fields.currency
          || objectId(result.destination) !== fields.destination || objectId(result.source_transaction) !== fields.source_transaction
          || result.transfer_group !== fields.transfer_group || result.reversed !== false || result.amount_reversed !== 0)
          fail('guardian_transfer_mismatch');
      } else if (job.kind === 'refund') {
        if (settled.allocated_cents !== 0 || settled.refund_cents !== settled.gross_cents) fail('guardian_refund_mismatch');
        // Read before creating: recover a lost Stripe response or a refund
        // already initiated from the Dashboard without issuing another refund.
        const list = await stripe.refunds.list({ charge: settled.charge_id, limit: 100 });
        if (list.has_more !== false || !Array.isArray(list.data)) fail('guardian_refund_mismatch');
        const refunds = list.data.filter(r => r.status !== 'failed' && r.status !== 'canceled');
        if (refunds.length > 1) fail('guardian_refund_mismatch');
        result = refunds[0];
        if (!result) {
          if (charge.amount_refunded !== 0) fail('guardian_refund_mismatch');
          result = await stripe.refunds.create({ charge: settled.charge_id, amount: settled.refund_cents,
            metadata: { dopmi_guardian_cycle: job.cycle_id } }, { idempotencyKey: job.job_key });
        }
        if (!/^re_[A-Za-z0-9]+$/.test(result?.id ?? '') || objectId(result.charge) !== settled.charge_id
          || result.amount !== settled.refund_cents || result.currency !== 'mxn') fail('guardian_refund_mismatch');
        if (result.status !== 'succeeded') fail('guardian_refund_pending');
      } else fail('guardian_job_invalid');
      await rpc('finish', { job_id: job.id, lease: job.lease, result_id: result.id });
      return true;
    } catch (error) {
      const code = error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable';
      await rpc('finish', { job_id: job.id, lease: job.lease, error_code: code, attention: attentionCodes.has(code) });
      paymentLog(logger, 'guardian_job_failed', { job_id: job.id, cycle_id: job.cycle_id, code });
      return false;
    }
  }
  async function work(limit = 10, cycleId) {
    let processed = 0, failed = 0;
    for (let i = 0; i < limit; i++) {
      const job = await rpc('claim', cycleId ? { cycle_id: cycleId } : {});
      if (!job) break;
      if (job.skipped || !await execute(job)) failed++; else processed++;
    }
    return { processed, failed };
  }
  async function reconcile() {
    const candidates = await rpc('candidates', {});
    let failed = 0, reconciled = 0;
    for (const candidate of candidates) {
      try { await reconcileInvoice(candidate.invoice_id); reconciled++; }
      catch (error) {
        // A draft/open invoice is expected while collection remains paused.
        // Every other error remains visible and the persisted binding is retried.
        if (error?.code !== 'invoice_not_confirmed') {
          failed++;
          paymentLog(logger, 'guardian_reconciliation_failed', { invoice_id: candidate.invoice_id,
            code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
        }
      }
    }
    const result = await work();
    return { reconciled, processed: result.processed, failed: failed + result.failed };
  }
  return { reconcileInvoice, work, reconcile };
}
