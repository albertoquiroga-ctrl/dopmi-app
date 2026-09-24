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

// Recovery may close an attempted but unpaid invoice; it never authorizes a
// payment. Retain all ownership/amount/line checks and allow a canceled plan.
export function guardianUnpaidInvoiceForRecovery(invoice, subscription, expected) {
  if (invoice?.id !== expected?.invoice_id) throw new GuardianBillingError('invoice_identity_mismatch');
  checkGuardianInvoiceIdentity(invoice, subscription, expected, 'recovery');
  if (invoice.status !== 'open' || invoice.auto_advance !== false || invoice.collection_method !== 'send_invoice'
    || invoice.currency !== 'mxn' || invoice.total !== expected.gross_cents || invoice.amount_due !== expected.gross_cents
    || invoice.amount_remaining !== expected.gross_cents || invoice.amount_paid !== 0 || invoice.starting_balance !== 0
    || invoice.automatic_tax?.enabled !== false || !Number.isSafeInteger(invoice.attempt_count) || invoice.attempt_count < 0
    || invoice.attempt_count > 1 || typeof invoice.attempted !== 'boolean')
    throw new GuardianBillingError('guardian_recovery_invoice_unsafe');
  checkInvoiceLine(invoice, expected);
}

// Only a fully paid, undisputed Stripe charge with an expanded balance
// transaction supplies a trustworthy processor fee. This calculation never
// creates an allocation, marks a cycle paid, or moves funds by itself.
export function guardianPaidInvoice(invoice, subscription, expected, invoicePayments, paymentIntent) {
  if (!/^in_[A-Za-z0-9]+$/.test(expected?.invoice_id ?? '') || invoice?.id !== expected.invoice_id)
    throw new GuardianBillingError('invoice_identity_mismatch');
  checkGuardianInvoiceIdentity(invoice, subscription, expected, true);
  if (invoice.status !== 'paid' || invoice.currency !== 'mxn' || invoice.auto_advance !== false
    || invoice.collection_method !== 'send_invoice' || invoice.amount_paid !== expected.gross_cents
    || invoice.amount_remaining !== 0 || invoice.total !== expected.gross_cents
    || invoice.amount_due !== expected.gross_cents
    || !Number.isSafeInteger(invoice.attempt_count) || invoice.attempt_count < 1
    || invoice.attempted !== true || invoice.starting_balance !== 0)
    throw new GuardianBillingError('invoice_not_confirmed');
  checkInvoiceLine(invoice, expected);
  const payments = invoicePayments?.data;
  const successful = payments?.filter(entry => entry.status === 'paid');
  const payment = successful?.[0];
  if (invoicePayments?.has_more !== false || !Array.isArray(payments)
    || payments.length === 0 || successful?.length !== 1
    || payments.some(entry => !/^inpay_[A-Za-z0-9]+$/.test(entry?.id ?? '')
      || entry.invoice !== invoice.id || (entry !== payment && entry.amount_paid !== 0))
    || !/^inpay_[A-Za-z0-9]+$/.test(payment?.id ?? '')
    || payment.invoice !== invoice.id || payment.status !== 'paid'
    || payment.amount_requested !== expected.gross_cents
    || payment.amount_paid !== expected.gross_cents
    || payment.payment?.type !== 'payment_intent'
    || payment.payment.payment_intent !== paymentIntent?.id)
    throw new GuardianBillingError('invoice_payment_mismatch');
  const charge = paymentIntent?.latest_charge;
  if (!/^pi_[A-Za-z0-9]+$/.test(paymentIntent?.id ?? '') || paymentIntent?.livemode !== false
    || paymentIntent.status !== 'succeeded' || paymentIntent.customer !== expected.customer_id
    || paymentIntent.currency !== 'mxn' || paymentIntent.amount_received !== expected.gross_cents
    || !charge || typeof charge === 'string' || !/^ch_[A-Za-z0-9]+$/.test(charge.id ?? '')
    || charge.livemode !== false || charge.payment_intent !== paymentIntent.id
    || charge.currency !== 'mxn' || charge.amount !== expected.gross_cents
    || charge.paid !== true || charge.captured !== true || charge.disputed !== false
    || charge.amount_refunded !== 0)
    throw new GuardianBillingError('charge_not_confirmed');
  const balance = charge.balance_transaction;
  if (!balance || typeof balance === 'string' || balance.currency !== 'mxn'
    || balance.amount !== expected.gross_cents || !Number.isSafeInteger(balance.fee)
    || balance.fee < 0)
    throw new GuardianBillingError('processor_fee_not_ready');
  const platformFee = Math.floor((expected.gross_cents * 2 + 50) / 100);
  const net = expected.gross_cents - platformFee - balance.fee;
  if (net <= 0) throw new GuardianBillingError('processor_fee_exceeds_payment');
  return { invoice_id: invoice.id, subscription_id: subscription.id,
    invoice_payment_id: payment.id,
    payment_intent_id: paymentIntent.id, charge_id: charge.id,
    gross_cents: expected.gross_cents, platform_fee_cents: platformFee,
    stripe_fee_cents: balance.fee, net_cents: net };
}

// Price evidence after a billing boundary is not evidence of payment. Inspect
// the exact renewal line without finalizing, paying, editing or voiding it.
export function guardianInvoicePriceEvidence(invoice, subscription, expected, periodStart) {
  checkGuardianInvoiceIdentity(invoice, subscription, expected);
  checkInvoiceLine(invoice, expected);
  const period = invoice.lines.data[0].period;
  if (!['draft', 'open', 'paid', 'void'].includes(invoice.status) || invoice.auto_advance !== false
    || invoice.collection_method !== 'send_invoice' || invoice.currency !== 'mxn'
    || invoice.total !== expected.gross_cents || invoice.amount_due !== expected.gross_cents
    || invoice.starting_balance !== 0 || invoice.automatic_tax?.enabled !== false
    || period?.start !== periodStart || !Number.isSafeInteger(period.end)
    || period.end <= periodStart || period.end > 4102444800)
    throw new GuardianBillingError('guardian_change_boundary_invoice_mismatch');
  return { boundary_invoice_id: invoice.id, boundary_period_start: periodStart,
    boundary_price_id: expected.price_id, boundary_gross_cents: expected.gross_cents };
}

function checkInvoiceLine(invoice, expected) {
  const lines = invoice.lines;
  const line = lines?.data?.[0];
  if (lines?.has_more !== false || lines?.data?.length !== 1 || lines.total_count !== 1
    || line?.amount !== expected.gross_cents || line?.currency !== 'mxn'
    || line?.quantity !== 1 || line?.pricing?.price_details?.price !== expected.price_id
    || line?.parent?.subscription_item_details?.subscription !== expected.subscription_id
    || !Array.isArray(line.taxes) || line.taxes.length !== 0
    || !Array.isArray(line.discount_amounts) || line.discount_amounts.length !== 0
    || !Array.isArray(invoice.total_taxes) || invoice.total_taxes.length !== 0
    || !Array.isArray(invoice.total_discount_amounts) || invoice.total_discount_amounts.length !== 0)
    throw new GuardianBillingError('invoice_line_mismatch');
}

function checkGuardianInvoiceIdentity(invoice, subscription, expected, reconcilingPaid = false) {
  const subId = invoice?.parent?.subscription_details?.subscription ?? invoice?.subscription;
  const id = typeof subId === 'string' ? subId : subId?.id;
  if (!expected || !/^sub_[A-Za-z0-9]+$/.test(expected.subscription_id ?? '')
    || !/^cus_[A-Za-z0-9]+$/.test(expected.customer_id ?? '')
    || !/^price_[A-Za-z0-9]+$/.test(expected.price_id ?? '')
    || !Number.isSafeInteger(expected.gross_cents) || expected.gross_cents < 1000 || expected.gross_cents > 1000000)
    throw new GuardianBillingError('invalid_guardian_subscription');
  if (!/^in_[A-Za-z0-9]+$/.test(invoice?.id ?? '') || invoice?.livemode !== false
    || subscription?.livemode !== false || id !== expected.subscription_id
    || subscription?.id !== expected.subscription_id || invoice?.customer !== expected.customer_id
    || subscription?.customer !== expected.customer_id || invoice?.billing_reason !== 'subscription_cycle')
    throw new GuardianBillingError('invoice_identity_mismatch');
  // Cancellation stops future collection; it must not hide an already paid invoice.
  // This exception is only for evidence reconciliation, never permission to pay.
  const allowedStatus = subscription.status === 'active'
    || (reconcilingPaid && subscription.status === 'canceled')
    || (reconcilingPaid === 'recovery' && ['past_due', 'unpaid', 'paused'].includes(subscription.status));
  if (!allowedStatus || subscription.collection_method !== 'send_invoice'
    || subscription.pause_collection?.behavior !== 'keep_as_draft'
    || subscription.pause_collection?.resumes_at != null)
    throw new GuardianBillingError('billing_not_fail_closed');
}

function checkGuardianInvoice(invoice, subscription, expected, requiredStatus) {
  checkGuardianInvoiceIdentity(invoice, subscription, expected);
  if (invoice.status !== requiredStatus || invoice.auto_advance !== false
    || invoice.collection_method !== 'send_invoice' || invoice.attempt_count !== 0)
    throw new GuardianBillingError('invoice_not_safe_to_collect');
  if (invoice.currency !== 'mxn' || invoice.total !== expected.gross_cents
    || invoice.amount_due !== expected.gross_cents || invoice.amount_remaining !== expected.gross_cents
    || invoice.amount_paid !== 0
    || invoice.attempted !== false || invoice.starting_balance !== 0)
    throw new GuardianBillingError('invoice_amount_mismatch');
  checkInvoiceLine(invoice, expected);
  return { invoice_id: invoice.id, subscription_id: subscription.id, gross_cents: expected.gross_cents };
}
