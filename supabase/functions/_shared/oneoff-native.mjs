import { PaymentError, requireExpectedLivemode } from './payments.mjs';

export const oneoffConsentVersion = 'oneoff-test-2026-10-15';
export const oneoffLiveConsentVersion = 'oneoff-live-2026-10-28';
const uuid = value => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value ?? '');
const actionable = ['requires_payment_method', 'requires_confirmation', 'requires_action'];

// The database owns the donation, consent, immutable channel and reservation.
// A native sheet is only payment authorization, never a donation receipt.
export function oneoffNativeService({ rpc, stripe, hosted, expectedLivemode = false }) {
  requireExpectedLivemode(expectedLivemode);
  const consentVersion = expectedLivemode ? oneoffLiveConsentVersion : oneoffConsentVersion;
  function validate(intent, donation) {
    if (intent?.id !== donation.stripe_payment_intent_id || intent.livemode !== expectedLivemode ||
        intent.amount !== donation.gross_cents || intent.currency !== 'mxn' ||
        intent.metadata?.dopmi_donation !== donation.id ||
        intent.metadata?.consent_version !== consentVersion ||
        intent.transfer_group !== `dopmi_${donation.id}` ||
        intent.capture_method !== 'automatic' || intent.confirmation_method !== 'automatic')
      throw new PaymentError('charge_mismatch', 409);
  }
  async function receipt(actor, donation) {
    if (!donation || donation.donor_id !== actor) throw new PaymentError('access_denied', 403);
    // A historical receipt remains readable. A pending attempt cannot acquire
    // a different consent or financial mode by retrying its existing key.
    if (donation.payment_status !== 'pending') return { donation_id: donation.id, status: donation.payment_status };
    if (donation.consent_version !== consentVersion) throw new PaymentError('payment_consent_required', 409);
    if (donation.payment_flow !== 'native') {
      // Historical attempts keep their original hosted session/key. Never
      // convert an unknown hosted outcome into a second PaymentIntent.
      return hosted.checkout(actor, { expense_id: donation.expense_id,
        gross_cents: donation.gross_cents, key: donation.idempotency_key });
    }
    if (!donation.stripe_payment_intent_id) {
      // Stripe may forget idempotency keys after 24 hours. Unknown creation
      // older than this window requires operator reconciliation, not recreation.
      if (!Number.isFinite(Date.parse(donation.created_at)) ||
          Date.now() - Date.parse(donation.created_at) > 23 * 3600000)
        throw new PaymentError('manual_reconciliation_required');
      const created = await stripe.paymentIntents.create({ amount: donation.gross_cents, currency: 'mxn',
        allowed_payment_method_types: ['card'], capture_method: 'automatic', confirmation_method: 'automatic',
        transfer_group: `dopmi_${donation.id}`,
        metadata: { dopmi_donation: donation.id, consent_version: consentVersion } },
      { idempotencyKey: `dopmi-native-oneoff-${donation.id}` });
      if (!/^pi_[A-Za-z0-9]+$/.test(created?.id ?? '')) throw new PaymentError('charge_mismatch');
      validate(created, { ...donation, stripe_payment_intent_id: created.id });
      donation = await rpc('bind', { actor, key: donation.idempotency_key, payment_intent_id: created.id });
      if (donation?.donor_id !== actor || donation.stripe_payment_intent_id !== created.id)
        throw new PaymentError('charge_mismatch');
      if (donation.consent_version !== consentVersion) throw new PaymentError('payment_consent_required', 409);
    }
    let intent = await stripe.paymentIntents.retrieve(donation.stripe_payment_intent_id);
    validate(intent, donation);
    const expired = Date.now() - Date.parse(donation.created_at) >= 3600000;
    if (expired && actionable.includes(intent.status)) {
      try {
        await stripe.paymentIntents.cancel(intent.id, {},
          { idempotencyKey: `dopmi-native-oneoff-expire-${donation.id}` });
      } catch {
        // Confirmation can win or the response can be lost. Only a fresh
        // provider read decides whether the reservation can be released.
      }
      intent = await stripe.paymentIntents.retrieve(donation.stripe_payment_intent_id);
      validate(intent, donation);
    }
    if (intent.status === 'succeeded') {
      await hosted.reprocessDonation(donation.id);
      const current = await rpc('get', { actor, key: donation.idempotency_key });
      return { donation_id: donation.id, status: current.payment_status };
    }
    if (intent.status === 'canceled') {
      await rpc('canceled', { actor, key: donation.idempotency_key, payment_intent_id: intent.id });
      return { donation_id: donation.id, status: 'canceled' };
    }
    if (![...actionable, 'processing'].includes(intent.status)) throw new PaymentError('charge_needs_review');
    const canAuthorize = !expired && actionable.includes(intent.status);
    const secret = canAuthorize ? intent.client_secret : null;
    if (canAuthorize && (typeof secret !== 'string' || !secret.startsWith(`${intent.id}_secret_`)))
      throw new PaymentError('charge_mismatch');
    // Secret is ephemeral, owner-only, and absent while processor result is
    // unknown/processing. Neither the database nor draft preferences store it.
    return { donation_id: donation.id, status: 'pending', payment_state: expired ? 'processing' : intent.status,
      payment_client_secret: secret };
  }
  async function submit(actor, input) {
    if (!uuid(actor) || !uuid(input.key) || !uuid(input.expense_id) ||
        !Number.isSafeInteger(input.gross_cents) || input.gross_cents < 1000 || input.gross_cents > 1000000)
      throw new PaymentError('invalid_input', 400);
    if (input.consent !== true || input.consent_version !== consentVersion)
      throw new PaymentError('payment_consent_required', 400);
    const donation = await rpc('prepare', { actor, key: input.key, expense_id: input.expense_id,
      gross_cents: input.gross_cents, consent: true, consent_version: consentVersion });
    if (donation?.idempotency_key !== input.key || donation.expense_id !== input.expense_id ||
        donation.gross_cents !== input.gross_cents) throw new PaymentError('charge_mismatch');
    return receipt(actor, donation);
  }
  async function status(actor, input) {
    if (!uuid(actor) || !uuid(input.key)) throw new PaymentError('invalid_input', 400);
    const donation = await rpc('get', { actor, key: input.key });
    if (!donation) return null;
    return receipt(actor, donation);
  }
  return { submit, status };
}
