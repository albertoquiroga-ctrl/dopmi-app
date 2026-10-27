import { PaymentError } from './payments.mjs';
import { savedCardConsentVersion } from './saved-card.mjs';

const id = value => typeof value === 'string' ? value : value?.id;
const uuid = value => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value ?? '');
const actionable = ['requires_payment_method', 'requires_confirmation', 'requires_action'];
const fail = code => { throw new PaymentError(code, 503); };

// A card SetupIntent saves authorization only. Registration, payment collection,
// and allocation remain distinct durable operations. Checkout jobs created by
// earlier releases resume through their original service and idempotency keys.
export function nativeSavedCardService({ stripe, rpc, hosted, returnUrl }) {
  function matches(setup, job) {
    if (setup?.id !== job.setup_intent_id || setup.livemode !== false ||
        id(setup.customer) !== job.customer_id || setup.usage !== 'off_session' ||
        setup.metadata?.dopmi_saved_card_job !== job.id || setup.metadata?.wallet_type !== 'card' ||
        setup.metadata?.consent_version !== savedCardConsentVersion ||
        !Array.isArray(setup.payment_method_types) || setup.payment_method_types.length !== 1 ||
        setup.payment_method_types[0] !== 'card') fail('saved_card_setup_mismatch');
    if (job.purpose === 'add_card' &&
        (setup.metadata?.dopmi_purpose !== 'add_card' || setup.metadata?.request_key !== job.request_key))
      fail('saved_card_setup_mismatch');
  }
  function customerMatches(customer, expected) {
    if (customer?.id !== expected || customer.deleted || customer.livemode !== false)
      fail('saved_card_customer_mismatch');
  }
  async function run(jobId) {
    let job = await rpc('get', { id: jobId });
    if (!job || job.wallet_type !== 'card') fail('saved_card_native_job_invalid');
    if (job.status !== 'pending') return job;
    const claimed = await rpc('claim', { id: jobId });
    if (!claimed) return rpc('get', { id: jobId });
    job = claimed;
    const checkpoint = async (operation, data = {}) => {
      const result = await rpc(operation, { id: jobId, lease: claimed.lease, ...data });
      if (result) job = result;
      return result;
    };
    try {
      if (job.id !== jobId || job.wallet_type !== 'card' || !uuid(job.wallet_id) ||
          job.session_id != null || job.consent_version !== savedCardConsentVersion || !job.consent_at ||
          !Number.isFinite(Date.parse(job.expires_at)) ||
          (job.customer_id != null && !/^cus_[A-Za-z0-9]+$/.test(job.customer_id)))
        fail('saved_card_native_job_invalid');
      if (!job.setup_intent_id && Date.parse(job.expires_at) <= Date.now()) return await checkpoint('expired');
      if (!job.customer_id) {
        const customer = await stripe.customers.create({},
          { idempotencyKey: `dopmi-saved-card-customer:${job.wallet_id}` });
        if (!/^cus_[A-Za-z0-9]+$/.test(customer?.id ?? '')) fail('saved_card_customer_mismatch');
        customerMatches(customer, customer.id);
        if (!await checkpoint('customer', { customer_id: customer.id })) return rpc('get', { id: jobId });
      }
      customerMatches(await stripe.customers.retrieve(job.customer_id), job.customer_id);
      if (!job.setup_intent_id) {
        if (Date.parse(job.expires_at) <= Date.now()) return await checkpoint('expired');
        const setup = await stripe.setupIntents.create({ customer: job.customer_id, usage: 'off_session',
          allowed_payment_method_types: ['card'],
          metadata: { dopmi_saved_card_job: job.id, wallet_type: 'card', consent_version: savedCardConsentVersion,
            ...(job.purpose === 'add_card' ? { dopmi_purpose: 'add_card', request_key: job.request_key } : {}) } },
        { idempotencyKey: `dopmi-native-card-setup:${jobId}` });
        if (!/^seti_[A-Za-z0-9]+$/.test(setup?.id ?? '')) fail('saved_card_setup_mismatch');
        matches(setup, { ...job, setup_intent_id: setup.id });
        if (!await checkpoint('native_setup', { setup_intent_id: setup.id })) return rpc('get', { id: jobId });
      }
      let setup = await stripe.setupIntents.retrieve(job.setup_intent_id);
      matches(setup, job);
      if (setup.status !== 'succeeded' && Date.parse(job.expires_at) <= Date.now()) {
        if (setup.status !== 'canceled') {
          try {
            await stripe.setupIntents.cancel(setup.id, {},
              { idempotencyKey: `dopmi-native-card-expire:${jobId}` });
          } catch {
            // Confirmation can win. A fresh provider read decides the outcome.
          }
          setup = await stripe.setupIntents.retrieve(job.setup_intent_id);
          matches(setup, job);
        }
      }
      if (setup.status === 'canceled') return await checkpoint('expired');
      if (setup.status !== 'succeeded') {
        if (![...actionable, 'processing'].includes(setup.status)) fail('saved_card_setup_unconfirmed');
        return job;
      }
      const methodId = id(setup.payment_method);
      if (!/^pm_[A-Za-z0-9]+$/.test(methodId ?? '')) fail('saved_card_method_mismatch');
      const method = await stripe.paymentMethods.retrieve(methodId);
      if (method?.id !== methodId || method.livemode !== false || id(method.customer) !== job.customer_id ||
          method.type !== 'card' || method.card?.wallet != null) fail('saved_card_method_mismatch');
      return await checkpoint('native_saved', { setup_intent_id: setup.id, payment_method_id: methodId });
    } finally {
      await rpc('release', { id: jobId, lease: claimed.lease });
    }
  }
  async function receipt(jobId) {
    const job = await run(jobId);
    let secret = null, methodStatus = job.status;
    const ready = job.status === 'pending' && job.setup_intent_id && Date.parse(job.expires_at) > Date.now()
      ? await rpc('native_ready', { id: jobId, setup_intent_id: job.setup_intent_id }) : null;
    if (ready) {
      if (ready.id !== job.id || ready.status !== 'pending' || ready.request_key !== job.request_key ||
          ready.customer_id !== job.customer_id || ready.wallet_type !== 'card' ||
          ready.setup_intent_id !== job.setup_intent_id || Date.parse(ready.expires_at) <= Date.now())
        fail('saved_card_native_job_invalid');
      const setup = await stripe.setupIntents.retrieve(job.setup_intent_id);
      matches(setup, job);
      methodStatus = setup.status;
      if (actionable.includes(setup.status)) {
        if (typeof setup.client_secret !== 'string' || !setup.client_secret.startsWith(`${setup.id}_secret_`))
          fail('saved_card_setup_mismatch');
        secret = setup.client_secret;
      }
    }
    return { key: job.request_key, status: job.status, method_status: methodStatus,
      setup_client_secret: secret, checkout_url: null,
      ...(job.purpose === 'add_card' ? { card_id: job.status === 'saved' ? job.payment_method_id : null } : {}) };
  }
  async function methodReceipt(actor, job) {
    if (job?.owner_id !== actor || job.purpose != null) fail('saved_card_native_job_invalid');
    if (job.wallet_type == null) return hosted.checkout(actor, { key: job.request_key,
      consent: true, consent_version: savedCardConsentVersion });
    if (job.wallet_type !== 'card') fail('saved_card_native_job_invalid');
    return receipt(job.id);
  }
  async function submit(actor, input) {
    if (!uuid(input.key) || input.consent !== true || input.consent_version !== savedCardConsentVersion)
      throw new PaymentError('saved_card_consent_required', 400);
    const prepared = await rpc('prepare_registration', { owner_id: actor, key: input.key,
      consent: true, consent_version: savedCardConsentVersion, return_url: returnUrl });
    if (prepared?.request_key !== input.key) fail('saved_card_native_job_invalid');
    return methodReceipt(actor, prepared);
  }
  async function status(actor, input) {
    const job = await rpc('registration_job', { owner_id: actor, key: input.key });
    if (!job) return null;
    if (job.request_key !== input.key) fail('saved_card_native_job_invalid');
    return methodReceipt(actor, job);
  }
  async function addReceipt(actor, job, key) {
    if (job?.owner_id !== actor || job.request_key !== key ||
        job.consent_version !== savedCardConsentVersion || !job.consent_at)
      fail('saved_card_native_job_invalid');
    let result, presentation;
    if (job.wallet_type == null && job.purpose == null) {
      // A retry of a pre-upgrade add-only request keeps its original channel.
      result = await hosted.checkout(actor, { key, consent: true, consent_version: savedCardConsentVersion });
      presentation = 'hosted_checkout';
    } else {
      if (job.wallet_type !== 'card' || job.purpose !== 'add_card') fail('saved_card_native_job_invalid');
      result = await receipt(job.id);
      presentation = 'native_card';
    }
    return { ...result, method_status: result.method_status ?? result.status,
      setup_client_secret: result.setup_client_secret ?? null, card_id: result.card_id ?? null,
      presentation, add_only: true, default_unchanged: true };
  }
  async function addSubmit(actor, input) {
    if (!uuid(input.key) || input.consent !== true || input.consent_version !== savedCardConsentVersion)
      throw new PaymentError('saved_card_consent_required', 400);
    const job = await rpc('prepare_add', { owner_id: actor, key: input.key,
      consent: true, consent_version: savedCardConsentVersion, return_url: returnUrl });
    return addReceipt(actor, job, input.key);
  }
  async function addStatus(actor, input) {
    if (!uuid(input.key)) throw new PaymentError('saved_card_request_invalid', 400);
    const job = await rpc('add_job', { owner_id: actor, key: input.key });
    return job == null ? null : addReceipt(actor, job, input.key);
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
    if (!['setup_intent.succeeded', 'setup_intent.canceled', 'setup_intent.setup_failed'].includes(event.type)) return null;
    const job = await rpc('lookup_setup', { setup_intent_id: event.data?.object?.id });
    if (!job) return null;
    await run(job.id);
    return { received: true, saved_native_card: true };
  }
  return { run, receipt, submit, status, addSubmit, addStatus, reconcile, handleWebhook };
}
