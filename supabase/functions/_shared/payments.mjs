// Portable core: the same code runs in Supabase Edge and Node acceptance tests.
export class PaymentError extends Error {
  constructor(code, status = 409) { super(code); this.code = code; this.status = status; }
}
export function requireTestKey(key) {
  if (!/^(sk|rk)_test_/.test(key ?? '')) throw new PaymentError('payments_not_configured', 503);
}
export function stripeApi(key, fetcher = fetch) {
  requireTestKey(key);
  return async (path, fields, idempotencyKey, account) => {
    const headers = { Authorization: `Bearer ${key}`, 'Stripe-Version': '2025-02-24.acacia' };
    if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey;
    if (account) headers['Stripe-Account'] = account;
    const response = await fetcher(`https://api.stripe.com/v1/${path}`, {
      method: fields ? 'POST' : 'GET', headers,
      body: fields ? new URLSearchParams(Object.entries(fields).map(([k,v]) => [k,String(v)])) : undefined,
      signal: AbortSignal.timeout(20000),
    });
    const result = await response.json();
    if (!response.ok) throw new PaymentError(result.error?.code ?? 'stripe_unavailable', response.status);
    if (result.livemode === true) throw new PaymentError('live_mode_rejected');
    return result;
  };
}
export async function verifySignature(body, header, secret, now = Date.now()) {
  if (!secret || !header) throw new PaymentError('invalid_signature', 400);
  const parts = header.split(',').map(v => v.split('='));
  const timestamps = parts.filter(([k]) => k === 't');
  const stamp = Number(timestamps[0]?.[1]);
  if (timestamps.length !== 1 || !Number.isSafeInteger(stamp) || Math.abs(now / 1000 - stamp) > 300) throw new PaymentError('invalid_signature', 400);
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const signature = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${stamp}.${body}`)));
  const valid = parts.filter(([k,v]) => k === 'v1' && /^[a-f0-9]{64}$/.test(v)).some(([,v]) => {
    const bytes = v.match(/../g).map(n => parseInt(n,16));
    return signature.reduce((diff,byte,i) => diff | (byte ^ bytes[i]),0) === 0;
  });
  if (!valid) throw new PaymentError('invalid_signature', 400);
  const event = JSON.parse(body);
  if (event.livemode !== false || !event.id?.startsWith('evt_')) throw new PaymentError('invalid_test_event', 400);
  return event;
}
function withinRetryWindow(created) {
  if (Date.now() - Date.parse(created) > 23 * 3600000) throw new PaymentError('manual_reconciliation_required');
}
export function paymentService({ rpc, stripe, returnUrl }) {
  async function refreshAccount(account) {
    const current = await stripe(`accounts/${account.account_id}`);
    await rpc('connect_save', { actor: account.owner_id, account_id: current.id,
      transfers_enabled: current.capabilities?.transfers === 'active', payouts_enabled: current.payouts_enabled === true,
      details_submitted: current.details_submitted === true });
    return current;
  }
  async function connect(actor, action) {
    let account = await rpc('connect_get', { actor });
    if (!account.account_id) {
      if (action === 'status') return { ready: false, transfers_enabled: false, payouts_enabled: false, payouts: [] };
      account = await rpc('connect_begin', { actor });
      withinRetryWindow(account.create_started_at);
      const created = await stripe('accounts', { type: 'express', country: 'MX',
        'capabilities[transfers][requested]': true, 'metadata[dopmi_owner]': actor,
        'business_profile[product_description]': 'Reembolso de gastos de rescate animal revisados por Dopmi' }, `dopmi-account-${actor}`);
      account = await rpc('connect_save', { actor, account_id: created.id, transfers_enabled: false, payouts_enabled: false, details_submitted: false });
    }
    const current = await refreshAccount(account);
    if (action === 'onboard') {
      const link = await stripe('account_links', { account: account.account_id, type: 'account_onboarding',
        refresh_url: `${returnUrl}?flow=connect`, return_url: `${returnUrl}?flow=connect` });
      return { url: link.url };
    }
    const payouts = await stripe('payouts?limit=10', undefined, undefined, account.account_id);
    return { ready: current.capabilities?.transfers === 'active' && current.payouts_enabled === true,
      transfers_enabled: current.capabilities?.transfers === 'active', payouts_enabled: current.payouts_enabled === true,
      details_submitted: current.details_submitted === true,
      payouts: payouts.data.map(p => ({ id: p.id, amount: p.amount, currency: p.currency, status: p.status, arrival_date: p.arrival_date })) };
  }
  async function checkout(actor, input) {
    if (!Number.isSafeInteger(input.gross_cents) || !/^[0-9a-f-]{36}$/i.test(input.key ?? '') || !/^[0-9a-f-]{36}$/i.test(input.expense_id ?? '')) throw new PaymentError('invalid_input', 400);
    const d = await rpc('prepare', { actor, expense_id: input.expense_id, gross_cents: input.gross_cents, key: input.key });
    if (d.payment_status !== 'pending') return { donation_id: d.id, status: d.payment_status };
    if (d.session_id) {
      const session = await stripe(`checkout/sessions/${d.session_id}`);
      await reconcileSession(session);
      return { donation_id: d.id, url: session.status === 'open' ? session.url : null, status: session.status };
    }
    withinRetryWindow(d.created_at);
    const session = await stripe('checkout/sessions', {
      mode: 'payment', 'payment_method_types[0]': 'card', client_reference_id: d.id,
      'metadata[dopmi_donation]': d.id, 'payment_intent_data[metadata][dopmi_donation]': d.id,
      'payment_intent_data[transfer_group]': `dopmi_${d.id}`,
      'line_items[0][price_data][currency]': 'mxn', 'line_items[0][price_data][unit_amount]': d.gross_cents,
      'line_items[0][price_data][product_data][name]': `Aportación Dopmi: ${d.expense_title}`,
      'line_items[0][quantity]': 1,
      expires_at: Math.floor(Date.parse(d.created_at) / 1000) + 3600,
      success_url: `${returnUrl}?flow=payment`, cancel_url: `${returnUrl}?flow=payment`,
    }, `dopmi-checkout-${d.id}`);
    await rpc('checkout_save', { donation_id: d.id, session_id: session.id, url: session.url });
    return { donation_id: d.id, url: session.url, status: 'pending' };
  }
  async function settleIntent(id) {
    const pi = await stripe(`payment_intents/${id}?expand[]=latest_charge.balance_transaction`);
    if (pi.status !== 'succeeded' || !pi.metadata?.dopmi_donation) return;
    const charge = pi.latest_charge;
    if (!charge || typeof charge === 'string' || !charge.paid || !charge.captured || charge.disputed) throw new PaymentError('charge_needs_review');
    const d = await rpc('get', { donation_id: pi.metadata.dopmi_donation });
    if (!d || d.gross_cents !== pi.amount_received || charge.currency !== 'mxn' || charge.amount !== d.gross_cents || pi.currency !== 'mxn') throw new PaymentError('charge_mismatch');
    if (d.processed_at) {
      if (d.stripe_charge_id !== charge.id) throw new PaymentError('charge_mismatch');
      return;
    }
    if (charge.amount_refunded > 0) throw new PaymentError('external_refund_review');
    const balance = charge.balance_transaction;
    if (!balance || typeof balance === 'string') throw new PaymentError('fee_not_ready', 503);
    if (balance.currency !== 'mxn' || balance.amount !== d.gross_cents || !Number.isSafeInteger(balance.fee)) throw new PaymentError('settlement_currency_mismatch');
    const account = await rpc('lookup_account', { account_id: d.destination });
    if (!account) throw new PaymentError('destination_mismatch');
    await refreshAccount(account);
    await rpc('settle', { donation_id: d.id, currency: pi.currency, gross_cents: pi.amount_received,
      charge_id: charge.id, payment_intent_id: pi.id, stripe_fee_cents: balance.fee });
  }
  async function reconcileSession(session) {
    if (!session.metadata?.dopmi_donation) return;
    if (session.payment_status === 'paid') await settleIntent(typeof session.payment_intent === 'string' ? session.payment_intent : session.payment_intent.id);
    else if (session.status === 'expired') await rpc('cancel', { donation_id: session.metadata.dopmi_donation });
  }
  async function processEvent(payload) {
    // Read current processor state; delivery order and duplicates are irrelevant.
    const event = await stripe(`events/${payload.event_id}`);
    if (event.livemode !== false) throw new PaymentError('live_mode_rejected');
    const object = event.data.object;
    if (event.type === 'account.updated') {
      const account = await rpc('lookup_account', { account_id: object.id });
      if (account) await refreshAccount(account);
    } else if (event.account) {
      // Connected-account payouts are fetched independently for their owner.
      return;
    } else if (event.type.startsWith('checkout.session.')) {
      await reconcileSession(await stripe(`checkout/sessions/${object.id}`));
    } else if (event.type === 'payment_intent.succeeded') await settleIntent(object.id);
    else if (event.type === 'charge.dispute.created') {
      const charge = await stripe(`charges/${object.charge}`);
      if (charge.payment_intent) await rpc('hold', { payment_intent_id: charge.payment_intent });
    } else if (event.type === 'charge.refunded' && object.metadata?.dopmi_donation) {
      const d = await rpc('get', { donation_id: object.metadata.dopmi_donation });
      const charge = await stripe(`charges/${object.id}`);
      if (d && charge.amount_refunded > d.refund_cents) await rpc('hold', { payment_intent_id: charge.payment_intent });
    }
  }
  async function work(limit = 10) {
    let processed = 0;
    for (let i=0; i<limit; i++) {
      const job = await rpc('claim', {});
      if (!job) break;
      if (job.skipped) continue;
      try {
        let result;
        if (job.kind === 'event') await processEvent(job.payload);
        else {
          const d = await rpc('get', { donation_id: job.donation_id });
          if (!d?.processed_at || d.payment_status !== 'confirmed') throw new PaymentError('unconfirmed_payment');
          if (job.kind === 'transfer') {
            if (d.transfer_status === 'reversed') throw new PaymentError('charge_needs_review');
            const charge = await stripe(`charges/${d.stripe_charge_id}`);
            if (charge.disputed || charge.amount_refunded > d.refund_cents) throw new PaymentError('charge_needs_review');
            result = await stripe('transfers', { amount: d.allocated_cents, currency: 'mxn', destination: d.destination,
              source_transaction: d.stripe_charge_id, transfer_group: `dopmi_${d.id}`, 'metadata[dopmi_donation]': d.id }, `dopmi-transfer-${d.id}`);
            if (result.amount !== d.allocated_cents || result.destination !== d.destination) throw new PaymentError('transfer_mismatch');
          } else {
            result = await stripe('refunds', { charge: d.stripe_charge_id, amount: d.refund_cents, 'metadata[dopmi_donation]': d.id }, `dopmi-refund-${d.id}`);
            if (result.status !== 'succeeded') result = await stripe(`refunds/${result.id}`);
            if (result.status !== 'succeeded') throw new PaymentError('refund_not_complete', 503);
          }
        }
        await rpc('finish_job', { job_id: job.id, lease: job.lease, result_id: result?.id });
        processed++;
      } catch (error) {
        const code = error instanceof PaymentError ? error.code : 'processor_unavailable';
        const attention = ['charge_needs_review','charge_mismatch','external_refund_review','destination_mismatch','settlement_currency_mismatch','transfer_mismatch','unconfirmed_payment'].includes(code);
        await rpc('finish_job', { job_id: job.id, lease: job.lease, error_code: code, attention });
      }
    }
    return { processed };
  }
  async function reconcile() {
    const candidates = await rpc('reconcile_candidates', {});
    for (const d of candidates) {
      try { await reconcileSession(await stripe(`checkout/sessions/${d.session_id}`)); } catch { /* Next scheduled attempt re-reads processor state. */ }
    }
    return work();
  }
  return { connect, checkout, work, reconcile, processEvent, settleIntent };
}
