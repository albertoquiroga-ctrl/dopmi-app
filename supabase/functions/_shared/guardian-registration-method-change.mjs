import { PaymentError } from './payments.mjs';
import { savedCardConsentVersion } from './saved-card.mjs';

// Only the existing native SetupIntent service contacts Stripe. This adapter
// never invokes a payment consumer, creates enrollment, or changes its amount.
export function guardianRegistrationMethodChange({ rpc, savedNativeCard }) {
  function receipt(job, method = null) {
    return { id: job.registration_id, key: job.request_key, status: job.status,
      registration_revision: job.applied_revision ?? job.registration_revision,
      method_status: method?.method_status ?? method?.status ?? null,
      setup_client_secret: job.status === 'pending' ? method?.setup_client_secret ?? null : null,
      checkout_url: null };
  }
  async function observe(actor, job) {
    if (!job || job.owner_id !== actor) throw new PaymentError('guardian_method_unavailable', 409);
    if (job.status !== 'pending') return receipt(job);
    const method = await savedNativeCard.status(actor, { key: job.id });
    return receipt(await rpc('reconcile', { owner_id: actor, id: job.registration_id, key: job.request_key }), method);
  }
  async function submit(actor, input) {
    if (input.consent !== true || input.consent_version !== savedCardConsentVersion)
      throw new PaymentError('guardian_method_consent_required', 400);
    const job = await rpc('prepare', { owner_id: actor, id: input.id, key: input.key,
      revision: input.revision, consent: true, consent_version: savedCardConsentVersion });
    if (job.status !== 'pending') return receipt(job);
    await savedNativeCard.submit(actor, { key: job.id, consent: true, consent_version: savedCardConsentVersion });
    return observe(actor, job);
  }
  async function status(actor, input) {
    const job = await rpc('reconcile', { owner_id: actor, id: input.id, key: input.key });
    return observe(actor, job);
  }
  async function reconcile() {
    let applied = 0, failed = 0;
    for (const candidate of await rpc('candidates', {})) {
      try {
        const job = await rpc('reconcile', { owner_id: candidate.owner_id,
          id: candidate.registration_id, key: candidate.request_key });
        if (job.status === 'applied') applied++;
      } catch { failed++; }
    }
    return { applied, failed };
  }
  return { submit, status, reconcile };
}
