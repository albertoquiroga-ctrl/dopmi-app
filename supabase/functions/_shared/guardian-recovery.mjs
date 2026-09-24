import { GuardianBillingError, guardianUnpaidInvoiceForRecovery } from './guardian-billing.mjs';

const fail = code => { throw new GuardianBillingError(code); };
const id = object => typeof object === 'string' ? object : object?.id;
const cancelable = new Set(['requires_payment_method', 'requires_action', 'requires_confirmation', 'canceled']);
const knownStates = new Set([...cancelable, 'processing', 'succeeded']);

// Invoice default PaymentIntents must be canceled through invoice voiding.
// Never call pay, confirm, capture or PaymentIntent.cancel from recovery.
// Unknown/multiple/partly paid objects remain attention without any write.
export function guardianRecoveryService({ stripe, rpc, paid }) {
  function identity(invoice, job) {
    const period = invoice?.lines?.data?.[0]?.period;
    if (invoice?.id !== job.invoice_id || invoice.livemode !== false || invoice.customer !== job.customer_id
      || id(invoice.parent?.subscription_details?.subscription) !== job.subscription_id
      || invoice.billing_reason !== 'subscription_cycle' || invoice.currency !== 'mxn'
      || period?.start !== job.period_start || period?.end !== job.period_end)
      fail('guardian_recovery_invoice_mismatch');
  }
  async function evidence(job) {
    const invoice = await stripe.invoices.retrieve(job.invoice_id);
    identity(invoice, job);
    if (invoice.status === 'paid') return { invoice, paid: true };
    if (!['open', 'void'].includes(invoice.status) || invoice.auto_advance !== false
      || invoice.collection_method !== 'send_invoice' || invoice.amount_paid !== 0)
      fail('guardian_recovery_invoice_unsafe');
    if (invoice.status === 'open') {
      const sub = await stripe.subscriptions.retrieve(job.subscription_id);
      guardianUnpaidInvoiceForRecovery(invoice, sub, { invoice_id: job.invoice_id, subscription_id: job.subscription_id,
        customer_id: job.customer_id, price_id: job.price_id, gross_cents: job.gross_cents });
    } else if (![0, job.gross_cents].includes(invoice.amount_remaining)) fail('guardian_recovery_void_unconfirmed');
    const list = await stripe.invoicePayments.list({ invoice: job.invoice_id, limit: 100 });
    const payment = list?.data?.[0];
    if (list?.has_more !== false || !Array.isArray(list.data) || list.data.length !== 1
      || !/^inpay_[A-Za-z0-9]+$/.test(payment?.id ?? '') || id(payment.invoice) !== job.invoice_id
      || payment.livemode !== false || payment.currency !== 'mxn' || payment.is_default !== true
      || !['open', 'canceled'].includes(payment.status) || ![null, 0].includes(payment.amount_paid)
      || (payment.amount_requested !== job.gross_cents && !(invoice.status === 'void' && payment.amount_requested === 0))
      || payment.payment?.type !== 'payment_intent' || !/^pi_[A-Za-z0-9]+$/.test(id(payment.payment.payment_intent) ?? '')
      || (job.recovery_invoice_payment_id && job.recovery_invoice_payment_id !== payment.id))
      fail('guardian_recovery_payment_mismatch');
    const intent = await stripe.paymentIntents.retrieve(id(payment.payment.payment_intent), { expand: ['latest_charge'] });
    if (intent?.id !== id(payment.payment.payment_intent) || intent.livemode !== false || id(intent.customer) !== job.customer_id
      || intent.currency !== 'mxn' || intent.amount !== job.gross_cents
      || !Number.isSafeInteger(intent.amount_received) || intent.amount_received < 0 || intent.amount_received > job.gross_cents
      || !Number.isSafeInteger(intent.amount_capturable) || intent.amount_capturable < 0
      || intent.application_fee_amount != null || intent.transfer_data != null
      || (id(intent.payment_method) != null && id(intent.payment_method) !== job.payment_method_id)
      || (job.recovery_intent_id && job.recovery_intent_id !== intent.id))
      fail('guardian_recovery_intent_mismatch');
    let state = knownStates.has(intent.status) ? intent.status : 'unknown';
    if (cancelable.has(state)) {
      if (intent.amount_received !== 0 || intent.amount_capturable !== 0) fail('guardian_recovery_funds_unconfirmed');
      const charge = intent.latest_charge;
      if (charge != null && (typeof charge !== 'object' || !/^ch_[A-Za-z0-9]+$/.test(charge.id ?? '')
        || charge.livemode !== false || id(charge.payment_intent) !== intent.id || id(charge.customer) !== job.customer_id
        || charge.currency !== 'mxn' || charge.amount !== job.gross_cents || charge.paid !== false || charge.status !== 'failed'))
        fail('guardian_recovery_charge_unconfirmed');
    }
    if (invoice.status === 'void' && (state !== 'canceled' || payment.status !== 'canceled'))
      fail('guardian_recovery_void_unconfirmed');
    if (invoice.status === 'open' && payment.status === 'canceled' && state !== 'canceled')
      fail('guardian_recovery_payment_mismatch');
    return { invoice, payment, intent, state };
  }
  async function run(original) {
    let job = await rpc('claim', { invoice_id: original.invoice_id });
    if (!job) return original;
    const lease = job.lease;
    const checkpoint = async (operation, data = {}) => {
      const value = await rpc(operation, { invoice_id: job.invoice_id, lease, ...data });
      if (value) job = value;
      return value;
    };
    const observe = e => checkpoint('observe', { state: e.state, intent_id: e.intent.id, invoice_payment_id: e.payment.id });
    const finish = e => checkpoint('voided', { intent_id: e.intent.id, invoice_payment_id: e.payment.id,
      invoice_status: e.invoice.status, intent_status: e.intent.status, invoice_payment_status: e.payment.status,
      amount_received: e.intent.amount_received, amount_capturable: e.intent.amount_capturable,
      amount_paid: e.invoice.amount_paid, amount_remaining: e.invoice.amount_remaining });
    try {
      let e = await evidence(job);
      if (e.paid) return await paid(job);
      await observe(e);
      if (e.invoice.status === 'void') return await finish(e);
      if (!cancelable.has(e.state)) return await checkpoint('wait');
      if (!await checkpoint('authorize_void')) return rpc('get', { invoice_id: job.invoice_id });
      // Re-read after authorization. A processor transition may have raced the
      // first read; processing/success never takes the cancellation path.
      e = await evidence(job);
      if (e.paid) return await paid(job);
      if (e.invoice.status === 'void') return await finish(e);
      if (!cancelable.has(e.state)) { await observe(e); return await checkpoint('wait'); }
      await stripe.invoices.voidInvoice(job.invoice_id, {}, { idempotencyKey: `guardian-recovery-void:${job.invoice_id}` });
      e = await evidence(job);
      if (e.paid) return await paid(job);
      if (e.invoice.status !== 'void') fail('guardian_recovery_void_unconfirmed');
      return await finish(e);
    } catch (error) {
      await checkpoint('failed', { error_code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
      throw error;
    }
  }
  async function verifyVoided(job) {
    const e = await evidence(job);
    if (e.paid || e.invoice.status !== 'void') fail('guardian_recovery_void_unconfirmed');
    return e;
  }
  return { run, verifyVoided };
}
