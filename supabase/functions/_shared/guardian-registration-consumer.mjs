import { PaymentError } from './payments.mjs';
import { assertRegistrationPaymentIdentity, registrationPaymentEvidence } from './guardian-registration-payment.mjs';

// Server-only ports. Deliberately not wired to a worker until evidence can be
// persisted and settled transactionally. No client-supplied amount or method.
export function guardianRegistrationConsumer({ stripe, load, bind, authorize, observe }) {
  async function record(attempt, intent) {
    const evidence = registrationPaymentEvidence(attempt, intent);
    const saved = await observe(attempt.id, evidence);
    // The locked database may already hold later terminal evidence. Never
    // return the stale processor snapshot after that authoritative merge.
    if (!saved || saved.id !== attempt.id || !saved.pay_requested_at ||
        saved.stripe_payment_intent_id !== attempt.stripe_payment_intent_id ||
        saved.gross_cents !== attempt.gross_cents || saved.customer_id !== attempt.customer_id ||
        saved.payment_method_id !== attempt.payment_method_id ||
        !['unresolved', 'requires_action', 'processor_succeeded', 'processor_canceled'].includes(saved.processor_state))
      throw new PaymentError('guardian_registration_observation_mismatch', 409);
    return { state: saved.processor_state, paymentIntentId: saved.stripe_payment_intent_id };
  }
  async function consume(id) {
    let attempt = await load(id);
    if (!attempt || attempt.id !== id) throw new PaymentError('guardian_registration_attempt_unavailable', 409);
    if (attempt.pay_requested_at) return reconcile(attempt);
    if (attempt.status !== 'prepared') return { state: 'not_authorized' };

    let intent;
    if (attempt.stripe_payment_intent_id) {
      intent = await stripe.paymentIntents.retrieve(attempt.stripe_payment_intent_id);
    } else {
      // Creation has no confirmation side effect. A lost create response uses
      // the same immutable attempt identity and exact same creation parameters.
      intent = await stripe.paymentIntents.create({
        amount: attempt.gross_cents, currency: 'mxn', customer: attempt.customer_id,
        payment_method: attempt.payment_method_id, payment_method_types: ['card'],
        confirm: false, metadata: { guardian_registration_attempt_id: attempt.id },
      }, { idempotencyKey: `guardian-registration-create:${attempt.id}` });
      const candidate = { ...attempt, stripe_payment_intent_id: intent.id };
      assertRegistrationPaymentIdentity(candidate, intent);
      attempt = await bind(attempt.id, intent.id);
    }
    assertRegistrationPaymentIdentity(attempt, intent);
    if (attempt.pay_requested_at) return reconcile(attempt);
    if (intent.status !== 'requires_confirmation') return { state: 'unresolved' };
    const authorized = await authorize(attempt.id);
    // Only the transaction that obtains the one-way marker may send. A race,
    // expired reservation or cancellation must never become another confirm.
    if (!authorized) return { state: 'not_authorized' };
    assertRegistrationPaymentIdentity(authorized, intent);
    if (!authorized.pay_requested_at || authorized.id !== attempt.id ||
        authorized.payment_key !== `guardian-registration:${attempt.id}`)
      throw new PaymentError('guardian_registration_authorization_mismatch', 409);
    try {
      intent = await stripe.paymentIntents.confirm(authorized.stripe_payment_intent_id,
        { off_session: true }, { idempotencyKey: authorized.payment_key });
    } catch {
      // Timeout/SDK error is not payment failure. Keep the marker and identity;
      // subsequent consumption retrieves this intent and never sends again.
      return { state: 'unresolved' };
    }
    return record(authorized, intent);
  }
  async function reconcile(attempt) {
    const intent = await stripe.paymentIntents.retrieve(attempt.stripe_payment_intent_id);
    return record(attempt, intent);
  }
  return { consume };
}
