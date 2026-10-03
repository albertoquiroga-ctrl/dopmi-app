import { PaymentError } from './payments.mjs';

export const savedCardConsentVersion = 'saved-cards-2026-10-03';
const id = value => typeof value === 'string' ? value : value?.id;
const fail = code => { throw new PaymentError(code, 503); };
function customerMatches(customer, expected) {
  if (customer?.id !== expected || customer.deleted === true || customer.livemode !== false)
    fail('saved_card_customer_mismatch');
}
function sessionMatches(session, job) {
  if (!/^cs_(test_)?[A-Za-z0-9]+$/.test(session?.id ?? '') ||
      (job.session_id && session.id !== job.session_id) || session.livemode !== false ||
      session.mode !== 'setup' || id(session.customer) !== job.customer_id ||
      session.client_reference_id !== job.id || session.metadata?.dopmi_saved_card_job !== job.id ||
      session.metadata?.consent_version !== savedCardConsentVersion ||
      (session.currency != null && session.currency !== 'mxn') || session.payment_intent != null || session.subscription != null)
    fail('saved_card_session_mismatch');
}

// Add-only: no subscription/customer default update, no PaymentIntent/charge.
// Durable SQL ownership and leases precede provider writes. No success is inferred
// from the browser redirect or webhook payload; all three objects are re-read.
export function savedCardService({ stripe, rpc, returnUrl }) {
  const address = new URL(returnUrl);
  if (address.protocol !== 'https:' || address.username || address.password || address.search || address.hash)
    fail('saved_card_return_url_invalid');

  async function run(jobId) {
    let job = await rpc('get', { id: jobId });
    if (job.status !== 'pending') return job;
    job = await rpc('claim', { id: jobId });
    if (!job) return rpc('get', { id: jobId });
    const lease = job.lease;
    const checkpoint = async (operation, data = {}) => {
      job = await rpc(operation, { id: jobId, lease, ...data });
      return job;
    };
    try {
      if (!job.customer_id) {
        const customer = await stripe.customers.create({},
          { idempotencyKey: `dopmi-saved-card-customer:${job.wallet_id}` });
        if (!/^cus_[A-Za-z0-9]+$/.test(customer?.id ?? '')) fail('saved_card_customer_mismatch');
        customerMatches(customer, customer.id);
        await checkpoint('customer', { customer_id: customer.id });
      }
      customerMatches(await stripe.customers.retrieve(job.customer_id), job.customer_id);
      if (!job.session_id) {
        const suffix = job.id.replaceAll('-', '').slice(0, 8).replace(/[0-9]/g, n => 'abcdefghij'[Number(n)]);
        const created = await stripe.checkout.sessions.create({ mode: 'setup', currency: 'mxn',
          customer: job.customer_id, client_reference_id: job.id,
          integration_identifier: `dopmi_save_card_${suffix}`,
          metadata: { dopmi_saved_card_job: job.id, consent_version: savedCardConsentVersion },
          setup_intent_data: { metadata: { dopmi_saved_card_job: job.id, consent_version: savedCardConsentVersion } },
          expires_at: Math.floor(Date.parse(job.expires_at) / 1000),
          success_url: job.return_url, cancel_url: job.return_url,
        }, { idempotencyKey: `dopmi-saved-card-session:${job.id}` });
        sessionMatches(created, job);
        await checkpoint('session', { session_id: created.id });
      }
      const session = await stripe.checkout.sessions.retrieve(job.session_id);
      sessionMatches(session, job);
      if (session.status === 'expired') return await checkpoint('expired', { session_id: session.id });
      if (session.status !== 'complete') return job;
      const setupId = id(session.setup_intent);
      if (!/^seti_[A-Za-z0-9]+$/.test(setupId ?? '')) fail('saved_card_setup_mismatch');
      const setup = await stripe.setupIntents.retrieve(setupId);
      if (setup?.id !== setupId || setup.livemode !== false || id(setup.customer) !== job.customer_id ||
          setup.usage !== 'off_session' || setup.metadata?.dopmi_saved_card_job !== job.id ||
          setup.metadata?.consent_version !== savedCardConsentVersion) fail('saved_card_setup_mismatch');
      if (setup.status !== 'succeeded') return job;
      const methodId = id(setup.payment_method);
      if (!/^pm_[A-Za-z0-9]+$/.test(methodId ?? '')) fail('saved_card_method_mismatch');
      const method = await stripe.paymentMethods.retrieve(methodId);
      if (method?.id !== methodId || method.livemode !== false || id(method.customer) !== job.customer_id ||
          method.type !== 'card') fail('saved_card_method_mismatch');
      return await checkpoint('saved', { session_id: session.id, setup_intent_id: setupId, payment_method_id: methodId });
    } finally {
      await rpc('release', { id: jobId, lease });
    }
  }

  async function checkout(actor, input) {
    if (input.consent !== true || input.consent_version !== savedCardConsentVersion)
      throw new PaymentError('saved_card_consent_required', 400);
    const prepared = await rpc('prepare', { owner_id: actor, key: input.key, consent: true,
      consent_version: savedCardConsentVersion, return_url: returnUrl });
    const job = await run(prepared.id);
    let url = null;
    if (job.status === 'pending' && job.session_id) {
      const session = await stripe.checkout.sessions.retrieve(job.session_id);
      sessionMatches(session, job);
      if (session.status === 'open') {
        const parsed = new URL(session.url);
        if (parsed.protocol !== 'https:' || parsed.hostname !== 'checkout.stripe.com' || parsed.username || parsed.password)
          fail('saved_card_checkout_url_invalid');
        url = parsed.href;
      }
    }
    return { key: job.request_key, status: job.status, checkout_url: url,
      card_id: job.status === 'saved' ? job.payment_method_id : null };
  }
  async function reconcile() {
    let saved = 0, failed = 0;
    for (const candidate of await rpc('candidates', {})) {
      try { if ((await run(candidate.id)).status === 'saved') saved++; }
      catch { failed++; }
    }
    return { saved, failed };
  }
  async function handleWebhook(eventId) {
    if (!/^evt_[A-Za-z0-9]+$/.test(eventId ?? '')) fail('saved_card_event_invalid');
    const event = await stripe.events.retrieve(eventId);
    if (event.livemode !== false) fail('saved_card_event_invalid');
    if (!['checkout.session.completed', 'checkout.session.expired'].includes(event.type)) return null;
    const job = await rpc('lookup_session', { session_id: event.data?.object?.id });
    if (!job) return null;
    await run(job.id);
    return { received: true, saved_card: true };
  }
  return { checkout, run, reconcile, handleWebhook };
}
