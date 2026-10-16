import { PaymentError } from './payments.mjs';
import { savedCardConsentVersion } from './saved-card.mjs';

export const guardianRegistrationConsentVersion = 'guardian-registration-2026-10-14';

// Registration and method setup are separate durable operations. A lost
// response must resume the same saved-card job, never create a charge.
export function guardianRegistrationService({ rpc, savedCard, savedNativeCard, attemptRpc }) {
  function consent(input) {
    if (input.consent !== true || input.consent_version !== guardianRegistrationConsentVersion ||
        input.method_consent !== true || input.method_consent_version !== savedCardConsentVersion)
      throw new PaymentError('guardian_registration_consent_required', 400);
  }
  function receipt(registration, method = null) {
    return { id: registration.id, key: registration.request_key, status: registration.status,
      gross_cents: registration.gross_cents, revision: registration.revision,
      registered_at: registration.registered_at, next_evaluation_at: registration.status === 'canceled'
        ? null : registration.next_evaluation_at,
      method_status: method?.method_status ?? method?.status ?? null,
      setup_client_secret: registration.status === 'method_pending' ? method?.setup_client_secret ?? null : null,
      checkout_url: registration.status === 'method_pending' ? method?.checkout_url ?? null : null };
  }
  async function status(actor, input) {
    let registration = await rpc('reconcile_method', { owner_id: actor, id: input.id });
    if (registration.status !== 'method_pending' || !savedNativeCard) return receipt(registration);
    // Reconcile only the existing owner-bound job; status never reserves a new
    // setup and the SDK return never becomes server proof of a saved method.
    const method = await savedNativeCard.status(actor, { key: registration.id });
    registration = await rpc('reconcile_method', { owner_id: actor, id: registration.id });
    return receipt(registration, method);
  }
  async function register(actor, input) {
    consent(input);
    let registration = await rpc('prepare', { owner_id: actor, key: input.key,
      gross_cents: input.gross_cents, consent: true, consent_version: guardianRegistrationConsentVersion });
    if (registration.status !== 'method_pending') return receipt(registration);
    const setup = savedNativeCard?.submit ?? savedCard.checkout;
    const method = await setup(actor, { key: registration.id, consent: true,
      consent_version: savedCardConsentVersion });
    // Re-read cancellation and saved-method evidence after external work.
    // Browser return, success URL, and the method callback do not prove success.
    registration = await rpc('reconcile_method', { owner_id: actor, id: registration.id });
    return receipt(registration, method);
  }
  async function cancel(actor, input) {
    return receipt(await rpc('cancel', { owner_id: actor, id: input.id }));
  }
  async function changeAmount(actor, input) {
    return receipt(await rpc('change_amount', { owner_id: actor, id: input.id,
      revision: input.revision, gross_cents: input.gross_cents,
      consent: input.consent, consent_version: input.consent_version }));
  }
  async function reconcile() {
    let registered = 0, failed = 0;
    // Candidate identities come only from the server. Reconcile under the
    // existing owner locks: cancellation can win after this snapshot.
    for (const candidate of await rpc('method_candidates', {})) {
      try {
        const result = await rpc('reconcile_method', {
          owner_id: candidate.owner_id, id: candidate.id,
        });
        if (result.status === 'registered') registered++;
      } catch {
        // Do not strand later owners or log private setup/payment identifiers.
        failed++;
      }
    }
    return { registered, failed };
  }
  async function prepareAttempts() {
    let prepared = 0, skipped = 0, failed = 0;
    for (const candidate of await attemptRpc('candidates', {})) {
      try {
        const attempt = await attemptRpc('prepare', { id: candidate.id });
        if (attempt?.status === 'prepared') prepared++;
        else skipped++;
      } catch {
        // Preparation failures are not confirmed payment failures. Do not
        // expose private method references or strand other owners.
        failed++;
      }
    }
    return { prepared, skipped, failed };
  }
  return { register, status, cancel, changeAmount, reconcile, prepareAttempts };
}
