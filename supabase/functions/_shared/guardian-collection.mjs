import { guardianRecoveryService } from './guardian-recovery.mjs';
import { GuardianBillingError, guardianInvoiceCycleKey, guardianRenewalCandidate,
  guardianFinalizedInvoiceForCollection } from './guardian-billing.mjs';
import { paymentLog } from './payments.mjs';

const fail = code => { throw new GuardianBillingError(code); };
const id = value => typeof value === 'string' ? value : value?.id;
const expected = job => ({ invoice_id: job.invoice_id, subscription_id: job.subscription_id,
  customer_id: job.customer_id, price_id: job.price_id, gross_cents: job.gross_cents });
const canceled = sub => sub.status === 'canceled' || sub.cancel_at_period_end === true || sub.cancel_at != null;

// One invoice, one persisted reservation and at most one pay invocation. A lost
// pay response is recovered through fresh evidence and, for a confirmed unpaid
// attempt, invoice voiding. Recovery never repeats payment authorization.
export function guardianCollectionService({ stripe, rpc, recoveryRpc, reconcileInvoice, logger = console, now = () => Date.now() }) {
  function period(invoice) {
    const p = invoice.lines?.data?.[0]?.period;
    if (!Number.isSafeInteger(p?.start) || !Number.isSafeInteger(p?.end) || p.start < 1 || p.end <= p.start)
      fail('guardian_invoice_period_invalid');
    return p;
  }
  function identity(invoice, job) {
    if (invoice?.id !== job.invoice_id || invoice.livemode !== false || invoice.customer !== job.customer_id
      || id(invoice.parent?.subscription_details?.subscription) !== job.subscription_id
      || invoice.billing_reason !== 'subscription_cycle' || invoice.currency !== 'mxn') fail('invoice_identity_mismatch');
    const p = period(invoice);
    if (p.start !== job.period_start || p.end !== job.period_end) fail('guardian_invoice_period_changed');
  }
  function unpaid(invoice, sub, job) {
    identity(invoice, job);
    if (invoice.automatic_tax?.enabled !== false || sub.automatic_tax?.enabled !== false) fail('guardian_collection_tax_changed');
    // A canceled subscription can still have a known unpaid invoice to void.
    // This relaxation never permits collection; cancellation is checked again.
    const checking = sub.status === 'canceled' ? { ...sub, status: 'active' } : sub;
    if (invoice.status === 'draft') guardianRenewalCandidate(invoice, checking, expected(job));
    else guardianFinalizedInvoiceForCollection(invoice, checking, expected(job));
  }
  async function prepare(invoice) {
    const subscriptionId = id(invoice.parent?.subscription_details?.subscription);
    if (!/^sub_[A-Za-z0-9]+$/.test(subscriptionId ?? '')) return null;
    const p = period(invoice);
    const plan = await rpc('source', { subscription_id: subscriptionId, period_start: p.start });
    if (!plan) return null;
    const sub = await stripe.subscriptions.retrieve(subscriptionId);
    const snapshot = { invoice_id: invoice.id, subscription_id: plan.stripe_subscription_id,
      customer_id: plan.stripe_customer_id, price_id: plan.stripe_price_id, gross_cents: plan.gross_cents };
    guardianRenewalCandidate(invoice, sub, expected(snapshot));
    if (invoice.automatic_tax?.enabled !== false || sub.automatic_tax?.enabled !== false) fail('guardian_collection_tax_changed');
    const customer = await stripe.customers.retrieve(plan.stripe_customer_id);
    if (customer.id !== plan.stripe_customer_id || customer.livemode !== false || customer.deleted === true || customer.balance !== 0)
      fail('guardian_collection_customer_mismatch');
    let stripeNow = Math.floor(now() / 1000);
    if (customer.test_clock) {
      const clock = await stripe.testHelpers.testClocks.retrieve(id(customer.test_clock));
      if (clock.id !== id(customer.test_clock) || clock.status !== 'ready' || !Number.isSafeInteger(clock.frozen_time))
        fail('guardian_collection_clock_unavailable');
      stripeNow = clock.frozen_time;
    }
    if (!Number.isSafeInteger(invoice.created) || invoice.created > stripeNow || p.start > stripeNow)
      fail('guardian_invoice_date_invalid');
    return rpc('prepare', { invoice_id: invoice.id, subscription_id: subscriptionId,
      cycle_key: await guardianInvoiceCycleKey(subscriptionId, invoice.id), period_start: p.start, period_end: p.end,
      fresh: !canceled(sub) && stripeNow - invoice.created < 48 * 3600 && stripeNow - p.start < 48 * 3600 && p.end > stripeNow });
  }
  async function paid(job) {
    await reconcileInvoice(job.invoice_id);
    return rpc('paid', { invoice_id: job.invoice_id });
  }
  const recovery = guardianRecoveryService({ stripe, rpc: recoveryRpc, paid });
  async function run(invoiceId) {
    if (!/^in_[A-Za-z0-9]+$/.test(invoiceId ?? '')) fail('invalid_invoice_identity');
    let job = await rpc('get', { invoice_id: invoiceId });
    if (job?.status === 'paid' || job?.status === 'skipped') return job;
    let invoice = await stripe.invoices.retrieve(invoiceId);
    if (invoice?.id !== invoiceId || invoice.livemode !== false) fail('invoice_identity_mismatch');
    if (!job) job = await prepare(invoice);
    if (!job) return null;
    try {
      identity(invoice, job);
      if (invoice.status === 'paid') return await paid(job);
      if (job.pay_requested_at) return await recovery.run(job);
      if (job.status === 'attention') return job;
      const claimed = await rpc('claim', { invoice_id: invoiceId });
      if (!claimed) return await rpc('get', { invoice_id: invoiceId });
      job = claimed;
      const checkpoint = async (operation, data = {}) => {
        const value = await rpc(operation, { invoice_id: invoiceId, lease: claimed.lease, ...data });
        if (value) job = value;
        return value;
      };
      try {
        // Re-read after acquiring the lease, not from a webhook payload or an
        // earlier worker's read. No Stripe write after a persisted pay marker.
        invoice = await stripe.invoices.retrieve(invoiceId);
        identity(invoice, job);
        if (invoice.status === 'paid') return await paid(job);
        if (job.pay_requested_at) fail('guardian_payment_uncertain');
        if (invoice.status === 'void') {
          if (invoice.amount_paid !== 0 || ![0, job.gross_cents].includes(invoice.amount_remaining) || invoice.auto_advance !== false)
            fail('guardian_void_unconfirmed');
          await recovery.verifyVoided(job);
          return await checkpoint('voided');
        }
        let sub = await stripe.subscriptions.retrieve(job.subscription_id);
        unpaid(invoice, sub, job);
        if (canceled(sub)) await checkpoint('skip');
        if (invoice.status === 'draft') {
          const customer = await stripe.customers.retrieve(job.customer_id);
          if (customer.id !== job.customer_id || customer.livemode !== false || customer.deleted === true || customer.balance !== 0)
            fail('guardian_collection_customer_mismatch');
          await stripe.invoices.finalizeInvoice(invoiceId, { auto_advance: false },
            { idempotencyKey: `guardian-finalize:${invoiceId}` });
        }
        invoice = await stripe.invoices.retrieve(invoiceId);
        sub = await stripe.subscriptions.retrieve(job.subscription_id);
        unpaid(invoice, sub, job);
        if (canceled(sub)) await checkpoint('skip');
        if (job.decision === 'collect') {
          const customer = await stripe.customers.retrieve(job.customer_id);
          const method = await stripe.paymentMethods.retrieve(job.payment_method_id);
          if (customer.id !== job.customer_id || customer.deleted === true || customer.livemode !== false || customer.balance !== 0
            || method.id !== job.payment_method_id || method.livemode !== false || id(method.customer) !== job.customer_id
            || id(sub.default_payment_method) !== job.payment_method_id || sub.automatic_tax?.enabled !== false)
            fail('guardian_collection_customer_mismatch');
          const authorization = await checkpoint('authorize_pay');
          if (!authorization) fail('guardian_payment_uncertain');
          if (job.decision === 'collect') {
            if (!job.pay_requested_at || Date.parse(job.expires_at) <= now() + 60000) fail('guardian_payment_not_authorized');
            await stripe.invoices.pay(invoiceId, { payment_method: job.payment_method_id, off_session: true },
              { idempotencyKey: `guardian-pay:${invoiceId}` });
            return await paid(job);
          }
        }
        // No capacity/expired hold/cancellation: finalize with auto_advance
        // disabled, then void. Never delete a subscription invoice draft.
        await stripe.invoices.voidInvoice(invoiceId, {}, { idempotencyKey: `guardian-void:${invoiceId}` });
        invoice = await stripe.invoices.retrieve(invoiceId);
        identity(invoice, job);
        if (invoice.status !== 'void' || invoice.amount_paid !== 0 || ![0, job.gross_cents].includes(invoice.amount_remaining) || invoice.auto_advance !== false)
          fail('guardian_void_unconfirmed');
        await recovery.verifyVoided(job);
        return await checkpoint('voided');
      } catch (error) {
        await checkpoint('failed', { error_code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable',
          attention: error instanceof GuardianBillingError });
        throw error;
      }
    } finally { await rpc('checked', { invoice_id: invoiceId }); }
  }
  async function reconcile() {
    let processed = 0, failed = 0;
    const visit = async invoiceId => {
      try { const job = await run(invoiceId); if (job?.status === 'attention' && !['processing', 'succeeded'].includes(job.recovery_state)) failed++; else if (job) processed++; }
      catch (error) {
        failed++;
        paymentLog(logger, 'guardian_collection_failed', { invoice_id: invoiceId,
          code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
      }
    };
    for (const candidate of await rpc('candidates', {})) await visit(candidate.invoice_id);
    for (const source of await rpc('sources', {})) {
      let cursor = source.cursor;
      try {
        const list = await stripe.invoices.list({ subscription: source.subscription_id, limit: 20,
          ...(cursor ? { starting_after: cursor } : {}) });
        if (!Array.isArray(list.data) || typeof list.has_more !== 'boolean' || (list.has_more && list.data.length === 0))
          fail('guardian_invoice_list_invalid');
        for (const invoice of list.data) {
          if (id(invoice.parent?.subscription_details?.subscription) !== source.subscription_id || invoice.livemode !== false)
            fail('invoice_identity_mismatch');
          if (['draft', 'open', 'paid'].includes(invoice.status)) await visit(invoice.id);
        }
        cursor = list.has_more ? list.data.at(-1).id : null;
      } catch (error) {
        failed++;
        paymentLog(logger, 'guardian_invoice_discovery_failed', { subscription_id: source.subscription_id,
          code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
      } finally { await rpc('source_checked', { subscription_id: source.subscription_id, cursor }); }
    }
    return { processed, failed };
  }
  async function handleWebhook(eventId) {
    if (!/^evt_[A-Za-z0-9]+$/.test(eventId ?? '')) fail('guardian_event_invalid');
    const event = await stripe.events.retrieve(eventId);
    if (event.livemode !== false) fail('guardian_event_invalid');
    if (!['invoice.created', 'invoice.finalized', 'invoice.paid', 'invoice.payment_failed', 'invoice.payment_action_required', 'invoice.voided', 'invoice_payment.paid'].includes(event.type)) return null;
    const invoiceId = event.type === 'invoice_payment.paid' ? id(event.data?.object?.invoice) : event.data?.object?.id;
    const result = await run(invoiceId);
    if (result?.status === 'attention' && !['processing', 'succeeded'].includes(result.recovery_state)) fail('guardian_payment_attention');
    return result ? { received: true, guardian_collection: true } : null;
  }
  return { run, reconcile, handleWebhook };
}
