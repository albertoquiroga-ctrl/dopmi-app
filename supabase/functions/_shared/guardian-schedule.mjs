import { GuardianBillingError } from './guardian-billing.mjs';
import { paymentLog } from './payments.mjs';

const fail = code => { throw new GuardianBillingError(code); };
const id = value => typeof value === 'string' ? value : value?.id;
export function guardianMonthlyAnchor(created) {
  if (!Number.isSafeInteger(created) || created < 1 || created > 4102444800) fail('guardian_charge_date_invalid');
  const date = new Date(created * 1000);
  const config = { day_of_month: date.getUTCDate(), hour: date.getUTCHours(), minute: date.getUTCMinutes(), second: date.getUTCSeconds() };
  const last = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 2, 0)).getUTCDate();
  const next = Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, Math.min(config.day_of_month, last), config.hour, config.minute, config.second) / 1000;
  return { config, next };
}

function checkPrice(price, a, expectedId) {
  if (!/^price_[A-Za-z0-9]+$/.test(price?.id ?? '') || (expectedId && price.id !== expectedId)
    || price.livemode !== false || price.active !== true || price.currency !== 'mxn' || price.unit_amount !== a.gross_cents
    || price.recurring?.interval !== 'month' || price.recurring?.interval_count !== 1 || price.recurring?.usage_type !== 'licensed'
    || price.billing_scheme !== 'per_unit' || price.transform_quantity != null) fail('guardian_schedule_price_mismatch');
}
function checkSubscription(sub, job, setup = true) {
  const a = job.activation, item = sub?.items?.data?.[0];
  if (!/^sub_[A-Za-z0-9]+$/.test(sub?.id ?? '') || (job.subscription_id && sub.id !== job.subscription_id)
    || sub.livemode !== false || id(sub.customer) !== a.customer_id || sub.status !== 'active'
    || sub.collection_method !== 'send_invoice' || sub.days_until_due !== 1
    || id(sub.default_payment_method) !== a.payment_method_id || sub.automatic_tax?.enabled !== false
    || sub.items?.has_more !== false || sub.items?.data?.length !== 1 || item.quantity !== 1
    || id(item.price) !== job.price_id || !Array.isArray(sub.discounts) || sub.discounts.length !== 0
    || !Array.isArray(sub.default_tax_rates) || sub.default_tax_rates.length !== 0 || sub.pending_update != null)
    fail('guardian_schedule_subscription_mismatch');
  if (setup && (item.current_period_end !== Date.parse(job.next_billing_at) / 1000 || sub.latest_invoice != null))
    fail('guardian_schedule_calendar_mismatch');
}
const isPaused = sub => sub.pause_collection?.behavior === 'keep_as_draft' && sub.pause_collection.resumes_at == null
  && sub.cancel_at_period_end === false && sub.cancel_at == null;

// Server-only, test-key runtime. No invoice is paid here. Creation is guarded
// by end-of-period cancellation; only an atomic pause+uncancel update removes
// that guard. Fixed request keys and persisted checkpoints recover lost replies.
export function guardianScheduleService({ stripe, rpc, logger = console, now = () => Date.now() }) {
  async function stopSetup(job) {
    const owned = sub => {
      if (sub?.id !== job.subscription_id || sub.livemode !== false || id(sub.customer) !== job.activation.customer_id)
        fail('guardian_schedule_subscription_mismatch');
    };
    let sub = await stripe.subscriptions.retrieve(job.subscription_id);
    owned(sub);
    if (sub.status !== 'canceled') {
      await stripe.subscriptions.cancel(sub.id, { invoice_now: false, prorate: false },
        { idempotencyKey: `guardian-stop-setup:${job.cycle_id}` });
      sub = await stripe.subscriptions.retrieve(job.subscription_id);
      owned(sub);
    }
    if (sub.status !== 'canceled') fail('guardian_cancel_unconfirmed');
    return rpc('canceled', { cycle_id: job.cycle_id, subscription_id: job.subscription_id });
  }
  async function source(cycleId) {
    const a = await rpc('source', { cycle_id: cycleId });
    const s = a.settlement;
    const charge = await stripe.charges.retrieve(s.charge_id);
    if (charge?.id !== s.charge_id || charge.livemode !== false || id(charge.payment_intent) !== s.payment_intent_id
      || id(charge.customer) !== a.customer_id || charge.amount !== a.gross_cents || charge.currency !== 'mxn'
      || charge.paid !== true || charge.captured !== true || charge.disputed !== false || charge.amount_refunded !== 0)
      fail('guardian_schedule_charge_mismatch');
    const customer = await stripe.customers.retrieve(a.customer_id);
    const method = await stripe.paymentMethods.retrieve(a.payment_method_id);
    if (customer?.id !== a.customer_id || customer.deleted === true || customer.livemode !== false || customer.balance !== 0
      || method?.id !== a.payment_method_id || method.livemode !== false || id(method.customer) !== a.customer_id)
      fail('guardian_schedule_customer_mismatch');
    let stripeNow = Math.floor(now() / 1000);
    if (customer.test_clock) {
      const clock = await stripe.testHelpers.testClocks.retrieve(id(customer.test_clock));
      if (clock.id !== id(customer.test_clock) || clock.status !== 'ready' || !Number.isSafeInteger(clock.frozen_time))
        fail('guardian_schedule_clock_unavailable');
      stripeNow = clock.frozen_time;
    }
    return { a, charge, stripeNow };
  }
  async function run(cycleId) {
    let job = await rpc('get', { cycle_id: cycleId });
    if (job && job.status !== 'pending') return job;
    if (job?.activation.cancellation_requested_at && job.subscription_id) return stopSetup(job);
    const verified = await source(cycleId);
    job = await rpc('prepare', { cycle_id: cycleId, charge_created: verified.charge.created });
    if (job.status !== 'pending') return job;
    const claimed = await rpc('claim', { cycle_id: cycleId });
    if (!claimed) return rpc('get', { cycle_id: cycleId });
    job = claimed;
    const checkpoint = async (operation, data = {}) => {
      job = await rpc(operation, { cycle_id: cycleId, lease: claimed.lease, ...data });
      return job;
    };
    try {
      const anchor = guardianMonthlyAnchor(job.charge_created);
      if (anchor.next <= verified.stripeNow + 48 * 3600) fail('guardian_schedule_too_late');
      const a = job.activation;
      const price = job.price_id ? await stripe.prices.retrieve(job.price_id) : await stripe.prices.create({
        currency: 'mxn', unit_amount: a.gross_cents, recurring: { interval: 'month', interval_count: 1 },
        product_data: { name: `Guardián mensual ${a.gross_cents / 100} MXN` },
      }, { idempotencyKey: `guardian-price:${cycleId}` });
      checkPrice(price, a, job.price_id);
      if (!job.price_id) await checkpoint('price', { price_id: price.id });
      let sub = job.subscription_id ? await stripe.subscriptions.retrieve(job.subscription_id)
        : await stripe.subscriptions.create({ customer: a.customer_id, default_payment_method: a.payment_method_id,
          items: [{ price: job.price_id, quantity: 1 }], collection_method: 'send_invoice', days_until_due: 1,
          billing_cycle_anchor_config: anchor.config, proration_behavior: 'none', cancel_at_period_end: true,
          automatic_tax: { enabled: false }, metadata: { dopmi_guardian_cycle: cycleId },
        }, { idempotencyKey: `guardian-subscription:${cycleId}` });
      // A previous cancellation may have succeeded with its response lost.
      if (job.activation.cancellation_requested_at && job.subscription_id) return await stopSetup(job);
      checkSubscription(sub, job);
      if (!isPaused(sub) && sub.cancel_at_period_end !== true) fail('guardian_schedule_missing_guard');
      if (!job.subscription_id) await checkpoint('subscription', { subscription_id: sub.id });
      job = await rpc('get', { cycle_id: cycleId });
      if (job.activation.cancellation_requested_at) return await stopSetup(job);
      if (!isPaused(sub)) {
        if (sub.pause_collection != null) fail('guardian_schedule_pause_changed');
        await stripe.subscriptions.update(sub.id, { pause_collection: { behavior: 'keep_as_draft' },
          cancel_at_period_end: false, proration_behavior: 'none' }, { idempotencyKey: `guardian-pause:${cycleId}` });
      }
      sub = await stripe.subscriptions.retrieve(job.subscription_id);
      checkSubscription(sub, job);
      if (!isPaused(sub)) fail('guardian_schedule_pause_unconfirmed');
      return await checkpoint('ready');
    } catch (error) {
      await checkpoint('failed', { error_code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
      throw error;
    }
  }
  async function reconcile() {
    let ready = 0, failed = 0;
    for (const candidate of await rpc('candidates', {})) {
      try { const job = await run(candidate.cycle_id); if (job?.status === 'ready') ready++; else if (job?.status === 'attention') failed++; }
      catch (error) {
        failed++;
        paymentLog(logger, 'guardian_schedule_failed', { cycle_id: candidate.cycle_id,
          code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
      } finally { await rpc('source_checked', candidate); }
    }
    for (const candidate of await rpc('monitor', {})) {
      try { await syncSubscription(candidate.subscription_id); }
      catch (error) {
        failed++;
        paymentLog(logger, 'guardian_schedule_sync_failed', { subscription_id: candidate.subscription_id,
          code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
      }
    }
    return { ready, failed };
  }
  async function handleWebhook(eventId) {
    if (!/^evt_[A-Za-z0-9]+$/.test(eventId ?? '')) fail('guardian_event_invalid');
    const event = await stripe.events.retrieve(eventId);
    if (event.livemode !== false) fail('guardian_event_invalid');
    if (!['customer.subscription.updated', 'customer.subscription.deleted'].includes(event.type)) return null;
    return syncSubscription(event.data?.object?.id);
  }
  async function syncSubscription(subscriptionId) {
    const job = await rpc('lookup_subscription', { subscription_id: subscriptionId });
    if (!job) return null;
    try {
      if (job.activation.cancellation_requested_at && job.status !== 'canceled') {
        await stopSetup(job);
        return { received: true, guardian_schedule: true };
      }
      if (job.lifecycle_pending) return { received: true, guardian_schedule: true };
      const sub = await stripe.subscriptions.retrieve(job.subscription_id);
      if (sub.id !== job.subscription_id || sub.livemode !== false || id(sub.customer) !== job.activation.customer_id)
        fail('guardian_schedule_subscription_mismatch');
      if (sub.status === 'canceled') await rpc('canceled', { cycle_id: job.cycle_id, subscription_id: sub.id });
      else if (job.status === 'ready') {
        try { checkSubscription(sub, job, false); if (!isPaused(sub)) fail('guardian_schedule_pause_unconfirmed'); }
        catch (error) { await rpc('attention', { cycle_id: job.cycle_id, subscription_id: sub.id, expected_price_id: job.price_id }); throw error; }
      }
      return { received: true, guardian_schedule: true };
    } finally { await rpc('observed', { cycle_id: job.cycle_id }); }
  }
  return { run, reconcile, handleWebhook };
}
