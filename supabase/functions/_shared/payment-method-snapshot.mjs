import { requireExpectedLivemode } from './payments.mjs';
// Stripe Charge.payment_method_details.card.brand values. Unknown future
// brands remain absent until reviewed instead of accepting arbitrary text.
const cardBrands = new Set(['amex','cartes_bancaires','diners','discover','eftpos_au',
  'jcb','link','mastercard','unionpay','visa','unknown']);

// Historical display comes only from the exact, reconciled Charge. A saved
// PaymentMethod or a customer's current default can change or disappear.
// Keep this optional: unavailable/unsupported display data never invents a
// card and never changes the financial evidence required for settlement.
export function chargePaymentMethodSnapshot(charge, { expectedLivemode = false } = {}) {
  requireExpectedLivemode(expectedLivemode);
  const details = charge?.payment_method_details;
  const card = details?.card;
  if (charge?.livemode !== expectedLivemode || details?.type !== 'card' ||
      !cardBrands.has(card?.brand) ||
      typeof card?.last4 !== 'string' || !/^[0-9]{4}$/.test(card.last4)) return {};
  // Never retain the processor object, expiry, fingerprint, full number,
  // wallet details, billing identity, or any client secret.
  return { payment_method: { type: 'card', brand: card.brand, last4: card.last4 } };
}
