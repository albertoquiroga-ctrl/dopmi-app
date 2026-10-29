import { PaymentError, requireExpectedLivemode } from './payments.mjs';
import { assertRegistrationPaymentIdentity } from './guardian-registration-payment.mjs';

// Secret is transient and owner-scoped; no create/confirm/retry API is called.
export function guardianRegistrationBankAction({ stripe, authorizeAction, expectedLivemode = false }) {
  requireExpectedLivemode(expectedLivemode);
  return async (owner, input) => {
    const validate = attempt => {
      if (!attempt || attempt.id !== input.attempt_id || attempt.registration_id !== input.id ||
          attempt.owner_id !== owner || !attempt.pay_requested_at || attempt.resolved_at ||
          attempt.processor_state !== 'requires_action')
        throw new PaymentError('guardian_registration_action_unavailable', 409);
    };
    const attempt = await authorizeAction(owner, input.id, input.attempt_id);
    validate(attempt);
    const intent = await stripe.paymentIntents.retrieve(attempt.stripe_payment_intent_id);
    assertRegistrationPaymentIdentity(attempt, intent, { expectedLivemode });
    // Cancellation, method changes, capacity loss and TTL can win during I/O.
    const current = await authorizeAction(owner, input.id, input.attempt_id);
    validate(current);
    assertRegistrationPaymentIdentity(current, intent, { expectedLivemode });
    if (current.id !== attempt.id || !current.pay_requested_at || current.resolved_at ||
        current.registration_id !== input.id || current.owner_id !== owner)
      throw new PaymentError('guardian_registration_action_unavailable', 409);
    const receipt = { id: input.id, attempt_id: current.id, state: 'processing' };
    if (intent.status !== 'requires_action') return receipt;
    if (!['use_stripe_sdk', 'redirect_to_url'].includes(intent.next_action?.type) ||
        typeof intent.client_secret !== 'string' ||
        !intent.client_secret.startsWith(`${intent.id}_secret_`) ||
        !/^pi_[A-Za-z0-9]+_secret_[A-Za-z0-9]+$/.test(intent.client_secret))
      throw new PaymentError('guardian_registration_action_unavailable', 409);
    return { ...receipt, state: 'requires_action', client_secret: intent.client_secret };
  };
}
