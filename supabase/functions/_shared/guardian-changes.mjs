import { GuardianBillingError } from './guardian-billing.mjs';
import { paymentLog } from './payments.mjs';

const fail = code => { throw new GuardianBillingError(code); };
const id = value => typeof value === 'string' ? value : value?.id;
const empty = value => Array.isArray(value) && value.length === 0;
const timestamp = value => Number.isSafeInteger(value) && value > 0 && value <= 4102444800;

function identity(sub, job) {
  if (sub?.id !== job.subscription_id || sub.livemode !== false || id(sub.customer) !== job.customer_id)
    fail('guardian_change_subscription_mismatch');
}
function priceMatches(price, expectedId, amount) {
  if (!/^price_[A-Za-z0-9]+$/.test(price?.id ?? '') || (expectedId && price.id !== expectedId)
    || price.livemode !== false || price.active !== true || price.currency !== 'mxn' || price.unit_amount !== amount
    || price.billing_scheme !== 'per_unit' || price.transform_quantity != null || price.custom_unit_amount != null
    || price.recurring?.interval !== 'month' || price.recurring?.interval_count !== 1 || price.recurring?.usage_type !== 'licensed')
    fail('guardian_change_price_mismatch');
}
function safeSubscription(sub, job) {
  identity(sub, job);
  const item = sub.items?.data?.[0];
  if (sub.status !== 'active' || sub.collection_method !== 'send_invoice' || sub.days_until_due !== 1
    || sub.pause_collection?.behavior !== 'keep_as_draft' || sub.pause_collection.resumes_at != null
    || sub.cancel_at_period_end !== false || sub.cancel_at != null || sub.automatic_tax?.enabled !== false
    || id(sub.default_payment_method) !== job.payment_method_id || !empty(sub.discounts) || !empty(sub.default_tax_rates)
    || sub.pending_update != null || sub.schedule != null || sub.pending_invoice_item_interval != null
    || sub.billing_thresholds != null || sub.application_fee_percent != null || sub.transfer_data != null || sub.on_behalf_of != null
    || sub.items?.has_more !== false || sub.items?.data?.length !== 1 || item?.quantity !== 1
    || !/^si_[A-Za-z0-9]+$/.test(item?.id ?? '') || !empty(item.tax_rates) || !empty(item.discounts)
    || !timestamp(item.current_period_start) || !timestamp(item.current_period_end) || item.current_period_end <= item.current_period_start
    || !timestamp(sub.billing_cycle_anchor)) fail('guardian_change_subscription_unsafe');
  return item;
}

// Changes are scheduled by changing a same-interval price with no proration;
// the current invoice retains its snapshot. No invoice is paid by this service.
export function guardianChangeService({ stripe, rpc, logger = console, now = () => Date.now() }) {
  async function stripeTime(job) {
    const customer = await stripe.customers.retrieve(job.customer_id);
    if (customer?.id !== job.customer_id || customer.deleted === true || customer.livemode !== false || customer.balance !== 0)
      fail('guardian_change_customer_mismatch');
    if (!customer.test_clock) return Math.floor(now() / 1000);
    const clock = await stripe.testHelpers.testClocks.retrieve(id(customer.test_clock));
    if (clock.id !== id(customer.test_clock) || clock.status !== 'ready' || !timestamp(clock.frozen_time))
      fail('guardian_change_clock_unavailable');
    return clock.frozen_time;
  }
  async function run(requestId) {
    let job = await rpc('get', { request_id: requestId });
    if (!job || job.status !== 'pending') return job;
    const claimed = await rpc('claim', { request_id: requestId });
    if (!claimed) return rpc('get', { request_id: requestId });
    job = claimed;
    const checkpoint = async (operation, fields = {}) => {
      const result = await rpc(operation, { request_id: requestId, lease: claimed.lease, ...fields });
      if (result) job = result;
      return result;
    };
    const stillPending = () => job.status === 'pending';
    const finishCanceled = sub => checkpoint('canceled', { subscription_id: sub.id, customer_id: id(sub.customer), status: sub.status });
    async function finishAmount(sub) {
      const item = safeSubscription(sub, job);
      if (!job.mutation_requested_at || !job.price_id || id(item.price) !== job.price_id || item.id !== job.item_id
        || sub.billing_cycle_anchor !== job.billing_anchor || item.current_period_start < job.period_start
        || item.current_period_end < job.effective_from
        || (item.current_period_start === job.period_start && (item.current_period_end !== job.effective_from
          || (id(sub.latest_invoice) ?? null) !== job.latest_invoice_id))) fail('guardian_change_unconfirmed');
      priceMatches(await stripe.prices.retrieve(job.price_id), job.price_id, job.new_gross_cents);
      return checkpoint('applied', { subscription_id: sub.id, customer_id: id(sub.customer), price_id: job.price_id,
        item_id: item.id, effective_from: job.effective_from, gross_cents: job.new_gross_cents });
    }
    function unchanged(sub) {
      const item = safeSubscription(sub, job);
      if (id(item.price) !== job.old_price_id || item.id !== job.item_id || item.current_period_start !== job.period_start
        || item.current_period_end !== job.effective_from || sub.billing_cycle_anchor !== job.billing_anchor
        || (id(sub.latest_invoice) ?? null) !== job.latest_invoice_id) fail('guardian_change_calendar_changed');
      return item;
    }
    try {
      let sub = await stripe.subscriptions.retrieve(job.subscription_id);
      identity(sub, job);
      if (sub.status === 'canceled') return await finishCanceled(sub);
      if (job.kind === 'cancel') {
        if (!await checkpoint('write')) return await rpc('get', { request_id: requestId });
        if (!stillPending()) return job;
        await checkpoint('mutation');
        if (!stillPending()) return job;
        await stripe.subscriptions.cancel(job.subscription_id, { invoice_now: false, prorate: false },
          { idempotencyKey: `guardian-change-cancel:${job.subscription_id}` });
        sub = await stripe.subscriptions.retrieve(job.subscription_id);
        identity(sub, job);
        if (sub.status !== 'canceled') fail('guardian_change_cancel_unconfirmed');
        return await finishCanceled(sub);
      }
      if (job.kind !== 'amount') fail('guardian_change_kind_invalid');
      let item = safeSubscription(sub, job);
      if (job.price_id && id(item.price) === job.price_id && job.mutation_requested_at) return await finishAmount(sub);
      if (!job.item_id) {
        if (id(item.price) !== job.registered_price_id) fail('guardian_change_price_mismatch');
        priceMatches(await stripe.prices.retrieve(job.registered_price_id), job.registered_price_id, job.previous_gross_cents);
        await checkpoint('snapshot', { item_id: item.id, period_start: item.current_period_start,
          effective_from: item.current_period_end, billing_anchor: sub.billing_cycle_anchor,
          latest_invoice_id: id(sub.latest_invoice) ?? null });
        if (!stillPending()) return job;
      }
      unchanged(sub);
      if (await stripeTime(job) >= job.effective_from - 120) fail('guardian_change_too_late');
      if (!await checkpoint('write')) return await rpc('get', { request_id: requestId });
      if (!stillPending()) return job;
      const price = job.price_id ? await stripe.prices.retrieve(job.price_id) : await stripe.prices.create({
        currency: 'mxn', unit_amount: job.new_gross_cents, recurring: { interval: 'month', interval_count: 1 },
        product_data: { name: `Guardián mensual ${job.new_gross_cents / 100} MXN` },
      }, { idempotencyKey: `guardian-change-price:${requestId}` });
      priceMatches(price, job.price_id, job.new_gross_cents);
      if (!job.price_id) await checkpoint('price', { price_id: price.id });
      if (!stillPending()) return job;
      sub = await stripe.subscriptions.retrieve(job.subscription_id);
      item = safeSubscription(sub, job);
      if (id(item.price) === job.price_id && job.mutation_requested_at) return await finishAmount(sub);
      unchanged(sub);
      if (await stripeTime(job) >= job.effective_from - 120) fail('guardian_change_too_late');
      await checkpoint('mutation');
      if (!stillPending()) return job;
      sub = await stripe.subscriptions.retrieve(job.subscription_id);
      unchanged(sub);
      if (await stripeTime(job) >= job.effective_from - 120) fail('guardian_change_too_late');
      await stripe.subscriptions.update(job.subscription_id, { items: [{ id: job.item_id, price: job.price_id, quantity: 1 }],
        billing_cycle_anchor: 'unchanged', proration_behavior: 'none' }, { idempotencyKey: `guardian-change-amount:${requestId}` });
      sub = await stripe.subscriptions.retrieve(job.subscription_id);
      identity(sub, job);
      if (sub.status === 'canceled') return await finishCanceled(sub);
      return await finishAmount(sub);
    } catch (error) {
      const code = error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable';
      try { await checkpoint('failed', { error_code: code }); } catch { /* An expired lease cannot overwrite its successor. */ }
      throw error;
    }
  }
  async function reconcile() {
    let applied = 0, failed = 0;
    for (const candidate of await rpc('candidates', {})) {
      try { const result = await run(candidate.request_id); if (result?.status === 'applied') applied++;
        else if (result?.error_code) failed++; }
      catch (error) { failed++; paymentLog(logger, 'guardian_change_failed', { request_id: candidate.request_id,
        code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' }); }
    }
    return { applied, failed };
  }
  async function handleWebhook(eventId) {
    if (!/^evt_[A-Za-z0-9]+$/.test(eventId ?? '')) fail('guardian_event_invalid');
    const event = await stripe.events.retrieve(eventId);
    if (event.livemode !== false) fail('guardian_event_invalid');
    if (!['customer.subscription.updated', 'customer.subscription.deleted'].includes(event.type)) return null;
    const candidates = await rpc('lookup_subscription', { subscription_id: event.data?.object?.id });
    if (!candidates.length) return null;
    for (const candidate of candidates) {
      const result = await run(candidate.request_id);
      if (result?.status === 'pending' && result.error_code) fail('guardian_change_pending_review');
    }
    return { received: true, guardian_change: true };
  }
  return { run, reconcile, handleWebhook };
}
