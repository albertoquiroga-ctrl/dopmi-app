import { PaymentError } from './payments.mjs';
import { savedCardConsentVersion } from './saved-card.mjs';

const id = value => typeof value === 'string' ? value : value?.id;
const providers = ['apple_pay', 'google_pay'];
const fail = code => { throw new PaymentError(code, 503); };

// Native wallet saving is a SetupIntent, never a payment or Guardian activation.
// The SQL adapter must reserve the owner/customer/provider under the existing
// saved-card lock, retain an immutable SetupIntent, and enforce the lease.
// Client calls must reserve the authenticated owner; a caller cannot supply a job ID.
export function nativeSavedWalletService({ stripe, rpc, returnUrl }) {
  function matches(setup, job) {
    if (setup?.id !== job.setup_intent_id || setup.livemode !== false ||
        id(setup.customer) !== job.customer_id || setup.usage !== 'off_session' ||
        setup.metadata?.dopmi_saved_card_job !== job.id ||
        setup.metadata?.wallet_type !== job.wallet_type ||
        setup.metadata?.consent_version !== savedCardConsentVersion ||
        !Array.isArray(setup.payment_method_types) ||
        setup.payment_method_types.length !== 1 || setup.payment_method_types[0] !== 'card') {
      fail('saved_wallet_setup_mismatch');
    }
  }

  async function run(jobId) {
    let job = await rpc('get', { id: jobId });
    if (job?.status !== 'pending') return job;
    const claimed = await rpc('claim', { id: jobId });
    if (!claimed) return rpc('get', { id: jobId });
    job = claimed;
    const checkpoint = async (operation, data = {}) => {
      const result = await rpc(operation, { id: jobId, lease: claimed.lease, ...data });
      if (result) job = result;
      return result;
    };
    try {
      if (job.id !== jobId || !providers.includes(job.wallet_type) ||
          !/^[0-9a-f-]{36}$/.test(job.wallet_id ?? '') ||
          (job.customer_id != null && !/^cus_[A-Za-z0-9]+$/.test(job.customer_id)) ||
          job.consent_version !== savedCardConsentVersion || job.session_id != null ||
          !Number.isFinite(Date.parse(job.expires_at))) fail('saved_wallet_job_invalid');
      if (!job.setup_intent_id && Date.parse(job.expires_at) <= Date.now()) return checkpoint('expired');
      if (!job.customer_id) {
        // Share the same stable customer identity as ordinary saved cards.
        const created = await stripe.customers.create({},
          { idempotencyKey: `dopmi-saved-card-customer:${job.wallet_id}` });
        if (!/^cus_[A-Za-z0-9]+$/.test(created?.id ?? '') || created.deleted || created.livemode !== false)
          fail('saved_wallet_customer_mismatch');
        if (!await checkpoint('customer', { customer_id: created.id })) return rpc('get', { id: jobId });
      }
      const customer = await stripe.customers.retrieve(job.customer_id);
      if (customer?.id !== job.customer_id || customer.deleted || customer.livemode !== false)
        fail('saved_wallet_customer_mismatch');
      if (!job.setup_intent_id) {
        if (Date.parse(job.expires_at) <= Date.now()) return checkpoint('expired');
        const setup = await stripe.setupIntents.create({ customer: job.customer_id,
          usage: 'off_session', payment_method_types: ['card'],
          metadata: { dopmi_saved_card_job: job.id, wallet_type: job.wallet_type,
            consent_version: savedCardConsentVersion } },
        { idempotencyKey: `dopmi-saved-wallet-setup:${jobId}` });
        if (!/^seti_[A-Za-z0-9]+$/.test(setup?.id ?? '')) fail('saved_wallet_setup_mismatch');
        matches(setup, { ...job, setup_intent_id: setup.id });
        if (!await checkpoint('native_setup', { setup_intent_id: setup.id }))
          return rpc('get', { id: jobId });
      }
      let setup = await stripe.setupIntents.retrieve(job.setup_intent_id);
      matches(setup, job);
      if (setup.status !== 'succeeded' && Date.parse(job.expires_at) <= Date.now()) {
        // A SetupIntent has no automatic expiry. Resolve a cancellation racing
        // confirmation from Stripe's fresh state before choosing a terminal state.
        if (setup.status !== 'canceled') {
          try {
            await stripe.setupIntents.cancel(setup.id, {},
              { idempotencyKey: `dopmi-saved-wallet-expire:${jobId}` });
          } catch {
            // A successful confirmation may have won; never infer cancellation.
          }
          setup = await stripe.setupIntents.retrieve(job.setup_intent_id);
          matches(setup, job);
        }
      }
      if (setup.status === 'canceled') return checkpoint('expired');
      if (setup.status !== 'succeeded') {
        if (!['requires_payment_method', 'requires_confirmation', 'requires_action', 'processing'].includes(setup.status))
          fail('saved_wallet_setup_unconfirmed');
        return job;
      }
      const methodId = id(setup.payment_method);
      if (!/^pm_[A-Za-z0-9]+$/.test(methodId ?? '')) fail('saved_wallet_method_mismatch');
      const method = await stripe.paymentMethods.retrieve(methodId);
      if (method?.id !== methodId || method.livemode !== false || method.type !== 'card' ||
          id(method.customer) !== job.customer_id || method.card?.wallet?.type !== job.wallet_type)
        fail('saved_wallet_method_mismatch');
      return checkpoint('native_saved', { setup_intent_id: setup.id, payment_method_id: methodId });
    } finally {
      await rpc('release', { id: jobId, lease: claimed.lease });
    }
  }

  async function receipt(jobId) {
    const job = await run(jobId);
    if (!job || !providers.includes(job.wallet_type)) fail('saved_wallet_job_invalid');
    let secret = null;
    const ready = job.status === 'pending' && job.setup_intent_id && Date.parse(job.expires_at) > Date.now()
      ? await rpc('native_ready', { id: jobId, setup_intent_id: job.setup_intent_id }) : null;
    if (ready) {
      if (ready.id !== job.id || ready.status !== 'pending' || ready.request_key !== job.request_key ||
          ready.customer_id !== job.customer_id || ready.wallet_type !== job.wallet_type ||
          ready.setup_intent_id !== job.setup_intent_id || Date.parse(ready.expires_at) <= Date.now())
        fail('saved_wallet_job_invalid');
      const setup = await stripe.setupIntents.retrieve(job.setup_intent_id);
      matches(setup, job);
      if (['requires_payment_method', 'requires_confirmation', 'requires_action'].includes(setup.status)) {
        if (typeof setup.client_secret !== 'string' || !setup.client_secret.startsWith(`${setup.id}_secret_`))
          fail('saved_wallet_setup_mismatch');
        secret = setup.client_secret;
      }
    }
    return { key: job.request_key, status: job.status, wallet_type: job.wallet_type,
      card_id: job.status === 'saved' ? job.payment_method_id : null,
      setup_client_secret: secret };
  }
  async function submit(actor, input) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.key ?? '') ||
        input.consent !== true || input.consent_version !== savedCardConsentVersion || !providers.includes(input.wallet_type))
      throw new PaymentError('saved_wallet_consent_required', 400);
    const prepared = await rpc('prepare', { owner_id: actor, key: input.key, wallet_type: input.wallet_type,
      consent: true, consent_version: savedCardConsentVersion, return_url: returnUrl });
    if (prepared?.owner_id !== actor || prepared.request_key !== input.key || prepared.wallet_type !== input.wallet_type)
      fail('saved_wallet_job_invalid');
    return receipt(prepared.id);
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
    if (!/^evt_[A-Za-z0-9]+$/.test(eventId ?? '')) fail('saved_wallet_event_invalid');
    const event = await stripe.events.retrieve(eventId);
    if (event.livemode !== false) fail('saved_wallet_event_invalid');
    if (!['setup_intent.succeeded', 'setup_intent.canceled', 'setup_intent.setup_failed'].includes(event.type)) return null;
    const job = await rpc('lookup_setup', { setup_intent_id: event.data?.object?.id });
    if (!job) return null;
    await run(job.id);
    return { received: true, saved_wallet: true };
  }
  return { run, receipt, submit, reconcile, handleWebhook };
}
