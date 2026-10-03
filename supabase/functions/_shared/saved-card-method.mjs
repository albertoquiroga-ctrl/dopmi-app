import { PaymentError } from './payments.mjs';

const id = value => typeof value === 'string' ? value : value?.id;
const fail = code => { throw new PaymentError(code, 503); };
const active = job => job?.status === 'pending';

// Independent wallet actions. PostgreSQL must reserve the owner/customer/target
// under the shared wallet lock and deny these jobs while Guardian is changing.
// This module cannot select an owner or create a financial obligation.
export function savedCardMethodService({ stripe, rpc }) {
  function customerMatches(customer, job) {
    if (customer?.id !== job.customer_id || customer.deleted || customer.livemode !== false)
      fail('saved_card_customer_mismatch');
  }
  function methodMatches(method, job, detached = false) {
    if (method?.id !== job.selected_method_id || method.livemode !== false || method.type !== 'card' ||
        (detached ? method.customer != null : id(method.customer) !== job.customer_id))
      fail('saved_card_method_owner_mismatch');
  }
  function completePage(page, customer, prefix) {
    if (!Array.isArray(page?.data) || page.has_more !== false) fail('saved_card_usage_unconfirmed');
    for (const value of page.data) {
      if (!new RegExp(`^${prefix}_[A-Za-z0-9]+$`).test(value?.id ?? '') ||
          value.livemode !== false || id(value.customer) !== customer)
        fail('saved_card_usage_unconfirmed');
    }
    return page.data;
  }
  async function usage(job, customer) {
    let inUse = job.action === 'remove' && id(customer.invoice_settings?.default_payment_method) === job.selected_method_id;
    const subscriptions = completePage(await stripe.subscriptions.list({ customer: job.customer_id, status: 'all', limit: 100 }), job.customer_id, 'sub');
    for (const sub of subscriptions) {
      if (!['incomplete', 'incomplete_expired', 'trialing', 'active', 'past_due', 'canceled', 'unpaid', 'paused'].includes(sub.status))
        fail('saved_card_usage_unconfirmed');
      if (!['canceled', 'incomplete_expired'].includes(sub.status)) {
        // A customer-level default must never silently change a subscription.
        if (job.action === 'default' || id(sub.default_payment_method) === job.selected_method_id ||
            (sub.default_payment_method == null && id(customer.invoice_settings?.default_payment_method) === job.selected_method_id)) inUse = true;
      }
    }
    for (const status of ['draft', 'open']) {
      const invoices = completePage(await stripe.invoices.list({ customer: job.customer_id, status, limit: 100 }), job.customer_id, 'in');
      for (const invoice of invoices) {
        if (invoice.status !== status) fail('saved_card_usage_unconfirmed');
        // An unset invoice method may inherit from its subscription/customer.
        // Do not detach while that selection remains unresolved.
        if (job.action === 'default' || invoice.default_payment_method == null ||
            id(invoice.default_payment_method) === job.selected_method_id) inUse = true;
      }
    }
    const intents = completePage(await stripe.paymentIntents.list({ customer: job.customer_id, limit: 100 }), job.customer_id, 'pi');
    for (const intent of intents) {
      if (!['requires_payment_method', 'requires_confirmation', 'requires_action', 'processing', 'requires_capture', 'canceled', 'succeeded'].includes(intent.status))
        fail('saved_card_usage_unconfirmed');
      if (!['canceled', 'succeeded'].includes(intent.status) &&
          (job.action === 'default' || id(intent.payment_method) === job.selected_method_id)) inUse = true;
    }
    return inUse;
  }
  async function run(jobId) {
    let job = await rpc('get', { id: jobId });
    if (!active(job)) return job;
    const claimed = await rpc('claim', { id: jobId });
    if (!claimed) return rpc('get', { id: jobId });
    job = claimed;
    const checkpoint = async (operation, data = {}) => {
      const result = await rpc(operation, { id: jobId, lease: claimed.lease, ...data });
      if (result) job = result;
      return result;
    };
    try {
      if (job.id !== jobId || !/^cus_[A-Za-z0-9]+$/.test(job.customer_id ?? '') ||
          !/^pm_[A-Za-z0-9]+$/.test(job.selected_method_id ?? '') ||
          !['default', 'remove'].includes(job.action) || job.subscription_id != null)
        fail('saved_card_method_job_invalid');
      if (!job.mutation_requested_at && (!Number.isFinite(Date.parse(job.expires_at)) || Date.parse(job.expires_at) <= Date.now()))
        return await checkpoint('expired');
      const customer = await stripe.customers.retrieve(job.customer_id);
      customerMatches(customer, job);
      const method = await stripe.paymentMethods.retrieve(job.selected_method_id);
      const detached = job.action === 'remove' && job.mutation_requested_at && method?.customer == null;
      methodMatches(method, job, Boolean(detached));
      if (await usage(job, customer)) {
        if (job.mutation_requested_at) fail('saved_card_method_in_use');
        return await checkpoint('refused');
      }
      if (!job.mutation_requested_at) {
        if (!await checkpoint('snapshot', { default_method_id: id(customer.invoice_settings?.default_payment_method) ?? null }))
          return rpc('get', { id: jobId });
      }
      const target = job.selected_method_id;
      const alreadyDefault = job.action === 'default' && id(customer.invoice_settings?.default_payment_method) === target;
      if (!detached && !alreadyDefault) {
        if (!await checkpoint('write_mutation')) return rpc('get', { id: jobId });
        if (job.action === 'default') {
          await stripe.customers.update(job.customer_id, { invoice_settings: { default_payment_method: target } },
            { idempotencyKey: `dopmi-saved-card-default:${jobId}` });
        } else {
          await stripe.paymentMethods.detach(target, {}, { idempotencyKey: `dopmi-saved-card-remove:${jobId}` });
        }
      }
      const afterCustomer = await stripe.customers.retrieve(job.customer_id);
      const afterMethod = await stripe.paymentMethods.retrieve(target);
      customerMatches(afterCustomer, job);
      methodMatches(afterMethod, job, job.action === 'remove');
      const expected = job.action === 'default' ? target : job.default_method_id;
      if ((id(afterCustomer.invoice_settings?.default_payment_method) ?? null) !== expected)
        fail('saved_card_method_unconfirmed');
      return await checkpoint(job.action === 'default' ? 'applied' : 'removed', { payment_method_id: target });
    } finally {
      await rpc('release', { id: jobId, lease: claimed.lease });
    }
  }
  return { run };
}
