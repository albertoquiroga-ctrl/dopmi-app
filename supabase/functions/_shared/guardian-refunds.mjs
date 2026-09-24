import { GuardianBillingError } from './guardian-billing.mjs';
import { paymentLog } from './payments.mjs';

const fail = code => { throw new GuardianBillingError(code); };
const id = value => typeof value === 'string' ? value : value?.id;

// Reconcile existing full refunds only. This service never creates a refund,
// charge, transfer, partial reversal, or a replacement for a failed reversal.
export function guardianRefundService({ stripe, rpc, logger = console }) {
  async function refundEvidence(s) {
    const charge = await stripe.charges.retrieve(s.charge_id);
    if (charge?.id !== s.charge_id || charge.livemode !== false || id(charge.payment_intent) !== s.payment_intent_id
      || charge.amount !== s.gross_cents || charge.currency !== 'mxn' || charge.paid !== true || charge.captured !== true
      || typeof charge.disputed !== 'boolean' || !Number.isSafeInteger(charge.amount_refunded)
      || charge.amount_refunded < 0 || charge.amount_refunded > s.gross_cents) fail('guardian_refund_charge_mismatch');
    let cursor, complete = false, pending = false, activeAmount = 0;
    const seen = new Set(), refunds = [];
    for (let page = 0; page < 5; page++) {
      const list = await stripe.refunds.list({ charge: s.charge_id, limit: 20, ...(cursor ? { starting_after: cursor } : {}) });
      if (!Array.isArray(list?.data) || typeof list.has_more !== 'boolean' || list.data.length > 20
        || (list.has_more && list.data.length === 0)) fail('guardian_refund_list_invalid');
      for (const r of list.data) {
        if (!/^re_[A-Za-z0-9]+$/.test(r?.id ?? '') || seen.has(r.id) || id(r.charge) !== s.charge_id
          || (r.payment_intent != null && id(r.payment_intent) !== s.payment_intent_id) || r.livemode === true
          || r.currency !== 'mxn' || !Number.isSafeInteger(r.amount) || r.amount <= 0 || r.amount > s.gross_cents
          || !['succeeded', 'pending', 'requires_action', 'failed', 'canceled'].includes(r.status)) fail('guardian_refund_list_invalid');
        seen.add(r.id);
        if (r.status === 'succeeded') refunds.push({ id: r.id, amount: r.amount });
        if (!['failed', 'canceled'].includes(r.status)) activeAmount += r.amount;
        if (['pending', 'requires_action'].includes(r.status)) pending = true;
      }
      if (!list.has_more) { complete = true; break; }
      cursor = list.data.at(-1).id;
    }
    const total = refunds.reduce((sum, r) => sum + r.amount, 0);
    if (!complete || activeAmount > s.gross_cents || total > charge.amount_refunded
      || (!pending && total !== charge.amount_refunded)) fail('guardian_refund_evidence_mismatch');
    return { cycle_id: s.cycle_id, charge_id: s.charge_id, payment_intent_id: s.payment_intent_id,
      gross_cents: s.gross_cents, refunds, confirmed_refund_cents: total, has_pending: pending, disputed: charge.disputed };
  }
  async function reversalEvidence(s, r) {
    const transfer = await stripe.transfers.retrieve(r.transfer_id);
    if (transfer?.id !== r.transfer_id || transfer.livemode !== false || transfer.amount !== r.amount_cents
      || transfer.currency !== 'mxn' || id(transfer.destination) !== r.destination || id(transfer.source_transaction) !== s.charge_id
      || transfer.transfer_group !== `dopmi_guardian_${s.cycle_id}` || typeof transfer.reversed !== 'boolean'
      || !Number.isSafeInteger(transfer.amount_reversed)) fail('guardian_reversal_transfer_mismatch');
    // Manual partial reversals need explicit review; do not guess a remainder.
    if (![0, r.amount_cents].includes(transfer.amount_reversed)) fail('guardian_partial_reversal_review');
    const list = await stripe.transfers.listReversals(r.transfer_id, { limit: 100 });
    if (list?.has_more !== false || !Array.isArray(list.data)) fail('guardian_reversal_list_invalid');
    if (transfer.amount_reversed === 0) {
      if (transfer.reversed || list.data.length !== 0) fail('guardian_reversal_evidence_mismatch');
      return null;
    }
    const reversal = list.data[0];
    if (!transfer.reversed || list.data.length !== 1 || !/^trr_[A-Za-z0-9]+$/.test(reversal?.id ?? '')
      || id(reversal.transfer) !== r.transfer_id || reversal.amount !== r.amount_cents
      || reversal.currency !== 'mxn') fail('guardian_reversal_evidence_mismatch');
    return reversal.id;
  }
  async function reconcileCycle(cycleId, forceReview = false) {
    let lease;
    try {
      let s = await rpc('get', { cycle_id: cycleId });
      if (!s) fail('guardian_refund_cycle_missing');
      if (s.adjustment?.status === 'completed' || s.allocated_cents === 0) return s;
      const evidence = await refundEvidence(s);
      if (evidence.confirmed_refund_cents === 0 && !evidence.has_pending && !evidence.disputed && !s.adjustment && !forceReview) return null;
      s = await rpc('observe', evidence);
      if (evidence.confirmed_refund_cents !== s.gross_cents || evidence.has_pending || evidence.disputed) return s;
      const claim = await rpc('claim', { cycle_id: cycleId });
      if (!claim) return await rpc('get', { cycle_id: cycleId });
      s = claim; lease = s.adjustment.lease;
      const again = await refundEvidence(s);
      if (again.confirmed_refund_cents !== s.gross_cents || again.has_pending || again.disputed) fail('guardian_refund_review');
      for (const r of s.reversals.filter(x => !x.reversal_id).slice(0, 10)) {
        let reversalId = await reversalEvidence(s, r);
        if (!reversalId) {
          const permit = await rpc('authorize', { cycle_id: cycleId, lease, expense_id: r.expense_id });
          if (permit?.allowed !== true) fail('guardian_reversal_retry_limit');
          await stripe.transfers.createReversal(r.transfer_id, { amount: r.amount_cents,
            metadata: { dopmi_guardian_cycle: cycleId, dopmi_guardian_expense: r.expense_id } }, { idempotencyKey: permit.key });
          reversalId = await reversalEvidence(s, r);
          if (!reversalId) fail('guardian_reversal_unconfirmed');
        }
        await rpc('confirmed', { cycle_id: cycleId, lease, expense_id: r.expense_id,
          transfer_id: r.transfer_id, amount_cents: r.amount_cents, reversal_id: reversalId });
      }
      // The adjustment keeps the original assignment until every destination
      // is reconciled. A multi-destination batch releases capacity atomically.
      return await rpc('complete', { cycle_id: cycleId, lease });
    } catch (error) {
      const code = error instanceof GuardianBillingError ? error.code : 'guardian_refund_processor_unavailable';
      if (lease) await rpc('fail', { cycle_id: cycleId, lease, error_code: code });
      paymentLog(logger, 'guardian_refund_failed', { cycle_id: cycleId, code });
      throw error;
    } finally { await rpc('checked', { cycle_id: cycleId }); }
  }
  async function reconcile() {
    let reconciled = 0, failed = 0;
    for (const row of await rpc('candidates', {})) {
      try {
        const result = await reconcileCycle(row.cycle_id);
        if (result && result.adjustment?.status !== 'completed') failed++; else reconciled++;
      } catch { failed++; }
    }
    return { reconciled, failed };
  }
  async function handleWebhook(eventId) {
    if (!/^evt_[A-Za-z0-9]+$/.test(eventId ?? '')) fail('invalid_event_identity');
    const event = await stripe.events.retrieve(eventId);
    if (event?.id !== eventId || event.livemode !== false) fail('guardian_refund_event_mismatch');
    if (event.account) return null;
    const object = event.data?.object;
    let lookup;
    if (event.type === 'charge.refunded') lookup = { charge_id: object?.id };
    else if (event.type === 'charge.dispute.created' || ['refund.created', 'refund.updated', 'refund.failed'].includes(event.type)) lookup = { charge_id: id(object?.charge) };
    else if (event.type === 'transfer.reversed') lookup = { transfer_id: object?.id };
    else return null;
    if (!/^(ch|tr)_[A-Za-z0-9]+$/.test(lookup.charge_id ?? lookup.transfer_id ?? '')) fail('guardian_refund_event_mismatch');
    const binding = await rpc('lookup', lookup);
    if (!binding) return null;
    const result = await reconcileCycle(binding.cycle_id, event.type === 'transfer.reversed');
    if (result?.adjustment && result.adjustment.status !== 'completed') fail('guardian_refund_review');
    return { received: true, cycle_id: binding.cycle_id };
  }
  return { reconcileCycle, reconcile, handleWebhook };
}
