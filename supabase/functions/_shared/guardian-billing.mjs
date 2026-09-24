// Guardián renewals are never collected from a webhook alone. The server must
// find the persisted owner/subscription pair, verify this fail-closed Stripe
// configuration, reserve the whole net in PostgreSQL, and only then decide
// whether to pay or void one invoice. Nothing in this module calls Stripe.
export class GuardianBillingError extends Error {
  constructor(code) { super(code); this.code = code; }
}

export async function guardianInvoiceCycleKey(subscriptionId, invoiceId) {
  if (!/^sub_[A-Za-z0-9]+$/.test(subscriptionId ?? '') || !/^in_[A-Za-z0-9]+$/.test(invoiceId ?? ''))
    throw new GuardianBillingError('invalid_invoice_identity');
  const bytes = new Uint8Array(await crypto.subtle.digest('SHA-256',
    new TextEncoder().encode(`dopmi:guardian:invoice:v1:${subscriptionId}:${invoiceId}`))).slice(0, 16);
  // RFC 9562 UUIDv8: deterministic application-defined bits, UUID variant.
  bytes[6] = (bytes[6] & 0x0f) | 0x80;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
}

export function guardianRenewalCandidate(invoice, subscription, expected) {
  return checkGuardianInvoice(invoice, subscription, expected, 'draft');
}

// Re-read both objects after finalization. The caller must compare the invoice
// with the identity persisted at reservation time, not an ID supplied by a
// browser or an untrusted webhook. This check does not authorize a Stripe pay.
export function guardianFinalizedInvoiceForCollection(invoice, subscription, expected) {
  if (!/^in_[A-Za-z0-9]+$/.test(expected?.invoice_id ?? '') || invoice?.id !== expected.invoice_id)
    throw new GuardianBillingError('invoice_identity_mismatch');
  return checkGuardianInvoice(invoice, subscription, expected, 'open');
}

function checkGuardianInvoice(invoice, subscription, expected, requiredStatus) {
  const subId = invoice?.parent?.subscription_details?.subscription ?? invoice?.subscription;
  const id = typeof subId === 'string' ? subId : subId?.id;
  if (!expected || !/^sub_[A-Za-z0-9]+$/.test(expected.subscription_id ?? '')
    || !/^cus_[A-Za-z0-9]+$/.test(expected.customer_id ?? '')
    || !Number.isSafeInteger(expected.gross_cents) || expected.gross_cents < 1000 || expected.gross_cents > 1000000)
    throw new GuardianBillingError('invalid_guardian_subscription');
  if (!/^in_[A-Za-z0-9]+$/.test(invoice?.id ?? '') || invoice?.livemode !== false
    || subscription?.livemode !== false || id !== expected.subscription_id
    || subscription?.id !== expected.subscription_id || invoice?.customer !== expected.customer_id
    || subscription?.customer !== expected.customer_id || invoice?.billing_reason !== 'subscription_cycle')
    throw new GuardianBillingError('invoice_identity_mismatch');
  if (subscription.status !== 'active' || subscription.collection_method !== 'send_invoice'
    || subscription.pause_collection?.behavior !== 'keep_as_draft'
    || subscription.pause_collection?.resumes_at != null)
    throw new GuardianBillingError('billing_not_fail_closed');
  if (invoice.status !== requiredStatus || invoice.auto_advance !== false
    || invoice.collection_method !== 'send_invoice')
    throw new GuardianBillingError('invoice_not_safe_to_collect');
  if (invoice.currency !== 'mxn' || invoice.total !== expected.gross_cents
    || invoice.amount_due !== expected.gross_cents || invoice.amount_paid !== 0
    || invoice.attempted !== false || invoice.starting_balance !== 0)
    throw new GuardianBillingError('invoice_amount_mismatch');
  return { invoice_id: invoice.id, subscription_id: subscription.id, gross_cents: expected.gross_cents };
}
