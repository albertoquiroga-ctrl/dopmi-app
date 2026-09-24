import { GuardianBillingError, guardianPaidInvoice } from './guardian-billing.mjs';

// Server-only evidence reader. Inject a StripeClient using the Billing API
// version (2026-08-26.dahlia) and a service-role registry lookup. Never pass
// subscription amounts/ownership from a browser or webhook into this function.
// This does not authorize allocation: settlement must separately lock and
// validate the persisted invoice/cycle binding and reservation in PostgreSQL.
export async function readGuardianPaidEvidence({ stripe, lookupSubscription, invoiceSnapshot }, invoiceId) {
  if (!/^in_[A-Za-z0-9]+$/.test(invoiceId ?? ''))
    throw new GuardianBillingError('invalid_invoice_identity');
  const invoice = await stripe.invoices.retrieve(invoiceId, { expand: ['payments'] });
  if (invoice?.id !== invoiceId || invoice.livemode !== false || invoice.status !== 'paid')
    throw new GuardianBillingError('invoice_not_confirmed');
  const subscriptionId = invoice.parent?.subscription_details?.subscription;
  if (!/^sub_[A-Za-z0-9]+$/.test(subscriptionId ?? ''))
    throw new GuardianBillingError('invoice_identity_mismatch');
  const plan = await lookupSubscription(subscriptionId);
  if (!plan || plan.stripe_subscription_id !== subscriptionId
    || !['active', 'canceled'].includes(plan.status)
    || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(plan.donor_id ?? ''))
    throw new GuardianBillingError('guardian_subscription_not_registered');
  const payments = invoice.payments;
  if (!Array.isArray(payments?.data) || payments.has_more !== false)
    throw new GuardianBillingError('invoice_payment_mismatch');
  const successful = payments.data.filter(payment => payment?.status === 'paid');
  const intentId = successful[0]?.payment?.payment_intent;
  if (successful.length !== 1 || !/^pi_[A-Za-z0-9]+$/.test(intentId ?? ''))
    throw new GuardianBillingError('invoice_payment_mismatch');
  const subscription = await stripe.subscriptions.retrieve(subscriptionId);
  if (invoiceSnapshot && (invoiceSnapshot.stripe_invoice_id !== invoiceId || invoiceSnapshot.stripe_subscription_id !== subscriptionId
    || !/^price_[A-Za-z0-9]+$/.test(invoiceSnapshot.price_id ?? '') || !Number.isSafeInteger(invoiceSnapshot.gross_cents)
    || (invoiceSnapshot.period_start != null && invoice.lines?.data?.[0]?.period?.start !== invoiceSnapshot.period_start)))
    throw new GuardianBillingError('guardian_invoice_snapshot_mismatch');
  const intent = await stripe.paymentIntents.retrieve(intentId, {
    expand: ['latest_charge.balance_transaction'],
  });
  const evidence = guardianPaidInvoice(invoice, subscription, {
    invoice_id: invoiceId, subscription_id: plan.stripe_subscription_id,
    customer_id: plan.stripe_customer_id, price_id: invoiceSnapshot?.price_id ?? plan.stripe_price_id,
    gross_cents: invoiceSnapshot?.gross_cents ?? plan.gross_cents,
  }, payments, intent);
  return { donor_id: plan.donor_id, ...evidence };
}
