import { PaymentError } from './payments.mjs';
import { registrationPaymentEvidence } from './guardian-registration-payment.mjs';

const id = value => typeof value === 'string' ? value : value?.id;

// Read-only evidence. Settlement separately rechecks capacity under rescuer
// locks and assigns all actual net or prepares a full refund, never a part.
export function registrationSettlementEvidence(attempt, intent) {
  const fail = () => { throw new PaymentError('guardian_registration_charge_unconfirmed', 409); };
  if (registrationPaymentEvidence(attempt, intent).state !== 'processor_succeeded') fail();
  if (intent.application_fee_amount != null || intent.transfer_data != null ||
      intent.capture_method !== 'automatic') fail();
  const charge = intent.latest_charge;
  if (!charge || typeof charge === 'string' || !/^ch_[A-Za-z0-9]+$/.test(charge.id ?? '') ||
      charge.livemode !== false || id(charge.payment_intent) !== intent.id ||
      id(charge.customer) !== attempt.customer_id || charge.currency !== 'mxn' ||
      charge.amount !== attempt.gross_cents || charge.paid !== true || charge.captured !== true ||
      charge.disputed !== false || charge.amount_refunded !== 0 || charge.refunded !== false ||
      charge.application_fee != null || charge.transfer != null || charge.destination != null) fail();
  const balance = charge.balance_transaction;
  if (!balance || typeof balance === 'string' || !/^txn_[A-Za-z0-9]+$/.test(balance.id ?? '') ||
      id(balance.source) !== charge.id || balance.currency !== 'mxn' || balance.amount !== attempt.gross_cents ||
      !Number.isSafeInteger(balance.fee) || balance.fee < 0 || balance.net !== balance.amount - balance.fee) fail();
  const platform = Math.floor((attempt.gross_cents * 2 + 50) / 100);
  const net = attempt.gross_cents - platform - balance.fee;
  if (net <= 0) fail();
  return { registration_attempt_id: attempt.id, donor_id: attempt.owner_id,
    customer_id: attempt.customer_id, payment_method_id: attempt.payment_method_id,
    payment_intent_id: intent.id, charge_id: charge.id, gross_cents: attempt.gross_cents,
    platform_fee_cents: platform, stripe_fee_cents: balance.fee, net_cents: net };
}

export async function readRegistrationSettlementEvidence(stripe, attempt) {
  const intent = await stripe.paymentIntents.retrieve(attempt.stripe_payment_intent_id,
    { expand: ['latest_charge.balance_transaction'] });
  return registrationSettlementEvidence(attempt, intent);
}
