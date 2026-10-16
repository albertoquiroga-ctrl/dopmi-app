import { PaymentError } from './payments.mjs';

const identifier = value => typeof value === 'string' ? value : value?.id;

// Server-side reconciliation only. This function cannot authorize, create,
// confirm, retry or allocate a payment. Unknown evidence stays unresolved.
export function assertRegistrationPaymentIdentity(attempt, intent) {
  const mismatch = () => { throw new PaymentError('guardian_registration_payment_mismatch', 409); };
  // Stripe can clear a declined/canceled intent's method. That cannot prove a
  // charge or a bank action; it may only reconcile the already bound resource
  // toward cancellation. Any method still supplied by Stripe must match.
  const method = identifier(intent?.payment_method);
  const failedMethod = identifier(intent?.last_payment_error?.payment_method);
  const clearedNonpayableMethod = intent?.payment_method === null &&
    Boolean(attempt?.pay_requested_at) &&
    ['requires_payment_method', 'canceled'].includes(intent?.status) &&
    (!failedMethod || failedMethod === attempt?.payment_method_id);
  if (!attempt?.stripe_payment_intent_id ||
      !Number.isSafeInteger(attempt.gross_cents) || attempt.gross_cents < 2000 ||
      intent?.id !== attempt.stripe_payment_intent_id || intent.livemode !== false ||
      intent.currency !== 'mxn' || intent.amount !== attempt.gross_cents ||
      identifier(intent.customer) !== attempt.customer_id ||
      (method !== attempt.payment_method_id && !clearedNonpayableMethod) ||
      intent.metadata?.guardian_registration_attempt_id !== attempt.id) mismatch();
}

export function registrationPaymentEvidence(attempt, intent) {
  assertRegistrationPaymentIdentity(attempt, intent);
  const mismatch = () => { throw new PaymentError('guardian_registration_payment_mismatch', 409); };
  if (!attempt.pay_requested_at) mismatch();
  if (intent.status === 'succeeded') {
    if (intent.amount_received !== attempt.gross_cents || !identifier(intent.latest_charge)) mismatch();
    // Processor success is not proof of allocation or confirmed impact.
    return { state: 'processor_succeeded', paymentIntentId: intent.id };
  }
  if (intent.status === 'canceled') return { state: 'processor_canceled', paymentIntentId: intent.id };
  if (intent.status === 'requires_action') return { state: 'requires_action', paymentIntentId: intent.id };
  // requires_payment_method and errors alone do not release a reservation:
  // finality and permission for a bank action belong to the durable consumer.
  return { state: 'unresolved', paymentIntentId: intent.id };
}
