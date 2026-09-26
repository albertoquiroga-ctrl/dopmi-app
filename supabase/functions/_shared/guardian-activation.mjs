import { GuardianBillingError } from './guardian-billing.mjs';
import { paymentLog } from './payments.mjs';

export const guardianConsentVersion = 'guardian-2026-09-24';
const fail = code => { throw new GuardianBillingError(code); };
const id = value => typeof value === 'string' ? value : value?.id;
const sessionId = value => /^cs_(test_)?[A-Za-z0-9]+$/.test(value ?? '');

function checkSession(session, activation) {
  if (!sessionId(session?.id) || (activation.session_id && activation.session_id !== session.id)
    || session.livemode !== false || session.mode !== 'payment'
    || session.client_reference_id !== activation.cycle_id || session.currency !== 'mxn'
    || session.amount_total !== activation.gross_cents || session.amount_subtotal !== activation.gross_cents
    || !(session.expires_at === Math.floor(Date.parse(activation.checkout_expires_at) / 1000)
      || (session.status === 'expired' && Number.isSafeInteger(session.expires_at) && session.expires_at > 0
        && session.expires_at < Math.floor(Date.parse(activation.checkout_expires_at) / 1000)))
    || session.customer_creation !== 'always' || session.subscription != null || session.invoice != null
    || session.automatic_tax?.enabled !== false || session.total_details?.amount_tax !== 0
    || session.total_details?.amount_discount !== 0 || session.total_details?.amount_shipping !== 0)
    fail('guardian_checkout_mismatch');
}

// The persisted Checkout ID is the ownership boundary. Neither redirect
// parameters nor metadata supplied by a browser may establish a payment.
function initialCharge(session, intent, activation) {
  checkSession(session, activation);
  if (session.status !== 'complete' || session.payment_status !== 'paid') fail('guardian_initial_unpaid');
  const customer = id(session.customer), method = id(intent?.payment_method);
  const charge = intent?.latest_charge;
  if (!/^cus_[A-Za-z0-9]+$/.test(customer ?? '') || !/^pm_[A-Za-z0-9]+$/.test(method ?? '')
    || !/^pi_[A-Za-z0-9]+$/.test(intent?.id ?? '') || id(session.payment_intent) !== intent.id
    || intent.livemode !== false || intent.status !== 'succeeded' || id(intent.customer) !== customer
    || intent.amount !== activation.gross_cents || intent.amount_received !== activation.gross_cents
    || intent.currency !== 'mxn' || intent.setup_future_usage !== 'off_session'
    || intent.application_fee_amount != null || intent.transfer_data != null
    || !charge || typeof charge === 'string' || !/^ch_[A-Za-z0-9]+$/.test(charge.id ?? '')
    || charge.livemode !== false || id(charge.payment_intent) !== intent.id || id(charge.customer) !== customer
    || charge.amount !== activation.gross_cents || charge.currency !== 'mxn'
    || charge.paid !== true || charge.captured !== true || typeof charge.disputed !== 'boolean' || charge.amount_refunded !== 0)
    fail('guardian_initial_charge_mismatch');
  return { customer, method, charge };
}

export function guardianInitialEvidence(session, intent, activation) {
  const { customer, method, charge } = initialCharge(session, intent, activation);
  if (charge.disputed) fail('guardian_initial_disputed');
  const balance = charge.balance_transaction;
  if (!balance || typeof balance === 'string' || id(balance.source) !== charge.id
    || balance.currency !== 'mxn' || balance.amount !== activation.gross_cents
    || !Number.isSafeInteger(balance.fee) || balance.fee < 0 || balance.net !== balance.amount - balance.fee)
    fail('processor_fee_not_ready');
  const platform = Math.floor((activation.gross_cents * 2 + 50) / 100);
  const net = activation.gross_cents - platform - balance.fee;
  if (net <= 0) fail('processor_fee_exceeds_payment');
  return { donor_id: activation.donor_id, checkout_session_id: session.id,
    customer_id: customer, payment_method_id: method, payment_intent_id: intent.id, charge_id: charge.id,
    gross_cents: activation.gross_cents, platform_fee_cents: platform, stripe_fee_cents: balance.fee, net_cents: net };
}

export function guardianActivationService({ stripe, rpc, settle, returnUrl, logger = console }) {
  const returnAddress = new URL(returnUrl);
  if (returnAddress.protocol !== 'https:' || returnAddress.username || returnAddress.password
    || returnAddress.search || returnAddress.hash) fail('guardian_return_url_invalid');

  function fields(a) {
    const suffix = a.cycle_id.replaceAll('-', '').slice(0, 8).replace(/[0-9]/g, n => 'ghijklmnop'[Number(n)]);
    return { mode: 'payment', customer_creation: 'always', client_reference_id: a.cycle_id,
      integration_identifier: `dopmi_guardian_${suffix}`, expires_at: Math.floor(Date.parse(a.checkout_expires_at) / 1000),
      success_url: a.return_url, cancel_url: a.return_url, adaptive_pricing: { enabled: false },
      automatic_tax: { enabled: false },
      line_items: [{ quantity: 1, price_data: { currency: 'mxn', unit_amount: a.gross_cents,
        product_data: { name: 'Primera aportación Guardián' } } }],
      payment_intent_data: { setup_future_usage: 'off_session', transfer_group: `dopmi_guardian_${a.cycle_id}` },
      metadata: { dopmi_guardian_cycle: a.cycle_id, consent_version: a.consent_version } };
  }
  async function ensureCheckout(a) {
    if (a.session_id || a.status !== 'pending') return a;
    const claimed = await rpc('claim_checkout', { cycle_id: a.cycle_id });
    if (!claimed) return rpc('get', { cycle_id: a.cycle_id });
    try {
      const session = await stripe.checkout.sessions.create(fields(claimed),
        { idempotencyKey: `guardian-checkout:${claimed.cycle_id}` });
      checkSession(session, claimed);
      return await rpc('save_checkout', { cycle_id: claimed.cycle_id, lease: claimed.lease, session_id: session.id });
    } catch (error) {
      await rpc('checkout_failed', { cycle_id: claimed.cycle_id, lease: claimed.lease });
      throw error;
    }
  }
  async function reconcileSession(session) {
    if (!sessionId(session)) fail('guardian_checkout_mismatch');
    const a = await rpc('lookup_session', { session_id: session });
    if (!a) return null;
    if (a.settlement) return a.settlement;
    // A verified disputed payment needs an explicit operational decision.
    // Later webhooks must not turn it into a settlement automatically.
    if (a.payment_review) return null;
    try {
      let checkout = await stripe.checkout.sessions.retrieve(a.session_id);
      checkSession(checkout, a);
      if (a.cancellation_requested_at && checkout.status === 'open' && checkout.payment_status === 'unpaid') {
        // Expiration may race a completed payment or lose its response. Only
        // the independent read below decides what actually happened.
        try { await stripe.checkout.sessions.expire(a.session_id, {},
          { idempotencyKey: `guardian-expire:${a.cycle_id}` }); }
        catch { /* reconcile the persisted session before retrying */ }
        checkout = await stripe.checkout.sessions.retrieve(a.session_id);
        checkSession(checkout, a);
        if (checkout.status === 'open') fail('guardian_cancel_unconfirmed');
      }
      if (checkout.status === 'expired' && checkout.payment_status === 'unpaid') {
        await rpc('expire', { cycle_id: a.cycle_id, session_id: a.session_id });
        return null;
      }
      const paymentIntentId = id(checkout.payment_intent);
      if (checkout.payment_status !== 'paid') {
        if (checkout.status === 'complete' && /^pi_[A-Za-z0-9]+$/.test(paymentIntentId ?? '')) {
          const intent = await stripe.paymentIntents.retrieve(paymentIntentId);
          if (intent?.id !== paymentIntentId || intent.livemode !== false
            || id(intent.customer) !== id(checkout.customer) || intent.amount !== a.gross_cents || intent.currency !== 'mxn')
            fail('guardian_initial_charge_mismatch');
          if (['canceled', 'requires_payment_method'].includes(intent.status) && intent.amount_received === 0)
            await rpc('fail_checkout', { cycle_id: a.cycle_id, session_id: a.session_id });
        }
        return null;
      }
      if (!/^pi_[A-Za-z0-9]+$/.test(paymentIntentId ?? '')) fail('guardian_initial_charge_mismatch');
      const intent = await stripe.paymentIntents.retrieve(paymentIntentId, { expand: ['latest_charge.balance_transaction'] });
      const { charge } = initialCharge(checkout, intent, a);
      if (charge.disputed) {
        await rpc('review_payment', { cycle_id: a.cycle_id, session_id: a.session_id,
          reason: 'disputed', payment_intent_id: intent.id, charge_id: charge.id,
          gross_cents: a.gross_cents, disputed: true });
        return null;
      }
      return await settle('settle_initial', guardianInitialEvidence(checkout, intent, a));
    } finally { await rpc('checked', { cycle_id: a.cycle_id }); }
  }
  async function checkout(donor, input) {
    if (input.consent !== true || input.consent_version !== guardianConsentVersion) fail('guardian_consent_required');
    const a = await ensureCheckout(await rpc('prepare', { donor_id: donor, key: input.key,
      gross_cents: input.gross_cents, consent: true, consent_version: guardianConsentVersion, return_url: returnUrl }));
    if (!a.session_id) return { cycle_id: a.cycle_id, status: a.status, checkout_url: null };
    const session = await stripe.checkout.sessions.retrieve(a.session_id);
    checkSession(session, a);
    // The return URL never confirms anything; webhooks and reconciliation do.
    let url = null;
    if (!a.cancellation_requested_at && a.status === 'pending' && session.status === 'open' && session.payment_status === 'unpaid') {
      const parsed = new URL(session.url);
      if (parsed.protocol !== 'https:' || parsed.hostname !== 'checkout.stripe.com' || parsed.username || parsed.password)
        fail('guardian_checkout_url_invalid');
      url = parsed.href;
    }
    const scheduled = { ready: 'active', canceled: 'canceled', attention: 'attention' }[a.schedule_status];
    return { cycle_id: a.cycle_id, status: a.status === 'settled' ? scheduled ?? 'funded_pending_schedule' : a.status,
      next_billing_at: a.next_billing_at ?? null, checkout_url: url };
  }
  async function reconcile() {
    let reconciled = 0, failed = 0;
    for (const candidate of await rpc('candidates', {})) {
      try {
        const a = await ensureCheckout(await rpc('get', candidate));
        if (a.status === 'attention') failed++;
        if (a.session_id && await reconcileSession(a.session_id)) reconciled++;
      } catch (error) {
        failed++;
        paymentLog(logger, 'guardian_initial_failed', { cycle_id: candidate.cycle_id,
          code: error instanceof GuardianBillingError ? error.code : 'guardian_processor_unavailable' });
      } finally { await rpc('checked', candidate); }
    }
    return { reconciled, failed };
  }
  // Called only after the HTTP boundary verifies the signature. Re-read Stripe
  // and use a persisted Session ID; event metadata never grants ownership.
  async function handleWebhook(eventId) {
    if (!/^evt_[A-Za-z0-9]+$/.test(eventId ?? '')) fail('guardian_event_invalid');
    const event = await stripe.events.retrieve(eventId);
    if (event.livemode !== false) fail('guardian_event_invalid');
    if (!['checkout.session.completed', 'checkout.session.async_payment_succeeded',
      'checkout.session.async_payment_failed', 'checkout.session.expired'].includes(event.type)) return null;
    if (!await rpc('lookup_session', { session_id: event.data?.object?.id })) return null;
    await reconcileSession(event.data.object.id);
    return { received: true, guardian: true };
  }
  return { checkout, reconcileSession, reconcile, handleWebhook };
}
