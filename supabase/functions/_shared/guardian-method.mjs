import { GuardianBillingError } from './guardian-billing.mjs';
import { paymentLog } from './payments.mjs';

const id = value => typeof value === 'string' ? value : value?.id;
const fail = code => { throw new GuardianBillingError(code); };
const pending = job => ['pending', 'attention'].includes(job?.status);
const timestamp = n => Number.isSafeInteger(n) && n > 0 && n <= 4102444800;
function sessionMatches(s, j) {
  if (!/^cs_(test_)?[A-Za-z0-9]+$/.test(s?.id ?? '') || (j.session_id && s.id !== j.session_id)
    || s.livemode !== false || s.mode !== 'setup' || id(s.customer) !== j.customer_id
    || s.client_reference_id !== j.id || s.payment_intent != null || s.subscription != null || s.invoice != null
    || (s.currency != null && s.currency !== 'mxn')) fail('guardian_method_session_mismatch');
}
function subscriptionMatches(s, j) {
  if (s?.id !== j.subscription_id || s.livemode !== false || id(s.customer) !== j.customer_id
    || s.status !== 'active' || s.collection_method !== 'send_invoice' || s.days_until_due !== 1
    || s.pause_collection?.behavior !== 'keep_as_draft' || s.pause_collection.resumes_at != null
    || s.cancel_at_period_end !== false || s.cancel_at != null || s.automatic_tax?.enabled !== false
    || s.items?.has_more !== false || s.items.data.length !== 1 || s.items.data[0].quantity !== 1
    || !timestamp(s.billing_cycle_anchor) || !timestamp(s.items.data[0].current_period_start)
    || !timestamp(s.items.data[0].current_period_end) || s.items.data[0].current_period_end <= s.items.data[0].current_period_start
    || id(s.items.data[0].price) !== j.price_id || s.pending_update != null
    || !Array.isArray(s.discounts) || s.discounts.length || !Array.isArray(s.default_tax_rates) || s.default_tax_rates.length)
    fail('guardian_method_subscription_mismatch');
}
const calendar = s => JSON.stringify([s.billing_cycle_anchor, s.items.data[0].current_period_start,
  s.items.data[0].current_period_end, id(s.latest_invoice)]);

// Checkout owns authentication and collection of payment details. This service
// never confirms/pays an invoice and never exposes a SetupIntent client secret.
export function guardianMethodService({ stripe, rpc, returnUrl, logger = console }) {
  const address = new URL(returnUrl);
  if (address.protocol !== 'https:' || address.username || address.password || address.search || address.hash)
    fail('guardian_return_url_invalid');
  async function run(jobId) {
    let job = await rpc('get', { job_id: jobId });
    if (!pending(job)) return job;
    const claimed = await rpc('claim', { job_id: jobId });
    if (!claimed) return rpc('get', { job_id: jobId });
    job = claimed;
    const checkpoint = async (op, data = {}) => {
      const value = await rpc(op, { job_id: jobId, lease: claimed.lease, ...data });
      if (value) job = value;
      if (value && !pending(value) && !['applied', 'expired', 'failed'].includes(op)) fail('guardian_method_superseded');
      return value;
    };
    try {
      if (!job.session_id) {
        if (!await checkpoint('write_checkout')) return rpc('get', { job_id: jobId });
        const suffix = job.id.replaceAll('-', '').slice(0, 8).replace(/[0-9]/g, n => 'ghijklmnop'[Number(n)]);
        const created = await stripe.checkout.sessions.create({ mode: 'setup', currency: 'mxn', customer: job.customer_id,
          client_reference_id: job.id, integration_identifier: `dopmi_method_${suffix}`,
          expires_at: Math.floor(Date.parse(job.expires_at) / 1000), success_url: job.return_url, cancel_url: job.return_url,
        }, { idempotencyKey: `guardian-method-session:${jobId}` });
        sessionMatches(created, job);
        await checkpoint('session', { session_id: created.id });
      }
      const session = await stripe.checkout.sessions.retrieve(job.session_id);
      sessionMatches(session, job);
      if (session.status === 'expired') return await checkpoint('expired', { session_id: session.id });
      if (session.status !== 'complete') return job;
      const setupId = id(session.setup_intent);
      if (!/^seti_[A-Za-z0-9]+$/.test(setupId ?? '')) fail('guardian_method_setup_mismatch');
      const setup = await stripe.setupIntents.retrieve(setupId);
      if (setup?.id !== setupId || setup.livemode !== false || id(setup.customer) !== job.customer_id || setup.usage !== 'off_session')
        fail('guardian_method_setup_mismatch');
      if (setup.status !== 'succeeded') return job;
      const methodId = id(setup.payment_method);
      if (!/^pm_[A-Za-z0-9]+$/.test(methodId ?? '')) fail('guardian_method_setup_mismatch');
      const method = await stripe.paymentMethods.retrieve(methodId);
      if (method?.id !== methodId || method.livemode !== false || id(method.customer) !== job.customer_id)
        fail('guardian_method_owner_mismatch');
      await checkpoint('verified', { session_id: session.id, setup_intent_id: setup.id, payment_method_id: methodId });
      let sub = await stripe.subscriptions.retrieve(job.subscription_id);
      subscriptionMatches(sub, job);
      await checkpoint('snapshot', { billing_anchor: sub.billing_cycle_anchor });
      const before = calendar(sub);
      if (id(sub.default_payment_method) !== methodId || !job.mutation_requested_at) {
        if (!await checkpoint('write_update')) return rpc('get', { job_id: jobId });
        if (id(sub.default_payment_method) !== methodId) {
          if (id(sub.default_payment_method) !== job.current_method_id) fail('guardian_method_changed_elsewhere');
          await stripe.subscriptions.update(sub.id, { default_payment_method: methodId, proration_behavior: 'none' },
            { idempotencyKey: `guardian-method-apply:${jobId}` });
        }
      }
      sub = await stripe.subscriptions.retrieve(job.subscription_id);
      subscriptionMatches(sub, job);
      if (id(sub.default_payment_method) !== methodId || calendar(sub) !== before) fail('guardian_method_unconfirmed');
      return await checkpoint('applied', { payment_method_id: methodId });
    } catch (error) {
      await checkpoint('failed', { error_code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
      throw error;
    } finally { await rpc('release', { job_id: jobId, lease: claimed.lease }); }
  }
  async function checkout(donor, input) {
    const prepared = await rpc('prepare', { donor_id: donor, key: input.key, revision: input.revision,
      consent: input.consent, consent_version: input.consent_version, return_url: returnUrl });
    const job = await run(prepared.id);
    let url = null;
    if (pending(job) && job.session_id && job.plan_status === 'active' && !job.cancellation_requested_at) {
      const session = await stripe.checkout.sessions.retrieve(job.session_id);
      sessionMatches(session, job);
      if (session.status === 'open') {
        const parsed = new URL(session.url);
        if (parsed.protocol !== 'https:' || parsed.hostname !== 'checkout.stripe.com' || parsed.username || parsed.password)
          fail('guardian_checkout_url_invalid');
        url = parsed.href;
      }
    }
    return { status: job.status, checkout_url: url };
  }
  async function reconcile() {
    let applied = 0, failed = 0;
    for (const candidate of await rpc('candidates', {})) {
      try { if ((await run(candidate.job_id))?.status === 'applied') applied++; }
      catch (error) {
        failed++;
        paymentLog(logger, 'guardian_method_failed', { job_id: candidate.job_id,
          code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
      }
    }
    return { applied, failed };
  }
  async function handleWebhook(eventId) {
    if (!/^evt_[A-Za-z0-9]+$/.test(eventId ?? '')) fail('guardian_event_invalid');
    const event = await stripe.events.retrieve(eventId);
    if (event.livemode !== false) fail('guardian_event_invalid');
    if (!['checkout.session.completed', 'checkout.session.expired', 'checkout.session.async_payment_succeeded',
      'checkout.session.async_payment_failed'].includes(event.type)) return null;
    const job = await rpc('lookup_session', { session_id: event.data?.object?.id });
    if (!job) return null;
    await run(job.id);
    return { received: true, guardian_method: true };
  }
  return { checkout, run, reconcile, handleWebhook };
}
