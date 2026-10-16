import { test } from 'node:test';
import assert from 'node:assert/strict';
import { oneoffNativeService, oneoffConsentVersion } from '../../supabase/functions/_shared/oneoff-native.mjs';
import { paymentService } from '../../supabase/functions/_shared/payments.mjs';

const actor = '90000000-0000-4000-8000-000000000001';
const input = { expense_id: '91000000-0000-4000-8000-000000000001',
  key: '92000000-0000-4000-8000-000000000001', gross_cents: 10000,
  consent: true, consent_version: oneoffConsentVersion };
function fixture() {
  const donation = { id: '93000000-0000-4000-8000-000000000001', donor_id: actor,
    expense_id: input.expense_id, idempotency_key: input.key, gross_cents: input.gross_cents,
    payment_status: 'pending', payment_flow: 'native', created_at: new Date().toISOString() };
  const state = { loseCreate: false, loseBind: false, status: 'requires_payment_method',
    mutate: value => value, creates: [], reads: [], cancels: [], rpc: [], intents: new Map(), hosted: [],
    cancel: () => { state.status = 'canceled'; } };
  const rpc = async (operation, data) => {
    state.rpc.push({ operation, data });
    if (operation === 'bind') {
      if (state.loseBind) { state.loseBind = false; throw Error('lost bind response'); }
      if (donation.stripe_payment_intent_id && donation.stripe_payment_intent_id !== data.payment_intent_id) throw Error('different intent');
      donation.stripe_payment_intent_id = data.payment_intent_id;
    } else if (operation === 'canceled') donation.payment_status = 'canceled';
    return structuredClone(donation);
  };
  const service = oneoffNativeService({ rpc,
    stripe: { paymentIntents: {
      create: async (body, options) => {
        state.creates.push({ body, options });
        if (!state.intents.has(options.idempotencyKey)) state.intents.set(options.idempotencyKey,
          { body: structuredClone(body), intent: { ...body, id: 'pi_synthetic', livemode: false,
            status: state.status, client_secret: 'pi_synthetic_secret_synthetic' } });
        const saved = state.intents.get(options.idempotencyKey);
        assert.deepEqual(body, saved.body);
        if (state.loseCreate) { state.loseCreate = false; throw Error('lost create response'); }
        return state.mutate(structuredClone(saved.intent));
      },
      retrieve: async id => {
        state.reads.push(id);
        const saved = [...state.intents.values()].find(v => v.intent.id === id);
        return state.mutate({ ...structuredClone(saved.intent), status: state.status });
      },
      cancel: async (id, body, options) => {
        state.cancels.push({ id, body, options });
        state.cancel();
        return {};
      },
    } },
    hosted: {
      checkout: async (owner, payload) => { state.hosted.push({ owner, payload }); return { url: 'https://checkout.stripe.com/synthetic' }; },
      reprocessDonation: async id => { assert.equal(id, donation.id); donation.payment_status = 'confirmed'; },
    },
  });
  return { donation, state, service };
}

test('native card intent is unconfirmed, consent-bound and exactly one stable request', async () => {
  const f = fixture();
  const value = await f.service.submit(actor, input);
  assert.equal(value.payment_client_secret, 'pi_synthetic_secret_synthetic');
  assert.equal(value.status, 'pending');
  const request = f.state.creates[0];
  assert.equal(request.options.idempotencyKey, `dopmi-native-oneoff-${f.donation.id}`);
  assert.deepEqual(request.body.allowed_payment_method_types, ['card']);
  assert.equal(request.body.payment_method_types, undefined);
  assert.equal(request.body.confirm, undefined);
  assert.equal(request.body.customer, undefined);
  assert.equal(request.body.setup_future_usage, undefined);
  assert.equal(request.body.metadata.consent_version, oneoffConsentVersion);
  await f.service.submit(actor, input);
  assert.equal(f.state.creates.length, 1);
  assert.equal(f.donation.payment_status, 'pending');
});

for (const failure of ['loseCreate', 'loseBind']) test(`lost ${failure} retries same intent and payload`, async () => {
  const f = fixture(); f.state[failure] = true;
  await assert.rejects(f.service.submit(actor, input), /lost/);
  const recovered = await f.service.submit(actor, input);
  assert.equal(recovered.status, 'pending');
  assert.equal(f.state.intents.size, 1);
  assert.deepEqual(f.state.creates[0], f.state.creates[1]);
});

test('concurrent preparation cannot produce a second processor identity', async () => {
  const f = fixture();
  const values = await Promise.all([f.service.submit(actor, input), f.service.submit(actor, input)]);
  assert.equal(f.state.intents.size, 1);
  assert.equal(new Set(values.map(v => v.donation_id)).size, 1);
});

test('only confirmed server settlement produces success; processing never exposes authorization', async () => {
  const f = fixture(); await f.service.submit(actor, input);
  f.state.status = 'processing';
  const pending = await f.service.status(actor, input);
  assert.equal(pending.status, 'pending');
  assert.equal(pending.payment_client_secret, null);
  f.state.status = 'succeeded';
  assert.equal((await f.service.status(actor, input)).status, 'confirmed');
  assert.equal(f.state.creates.length, 1);
});

test('processor cancellation releases only the bound attempt; SDK closure alone does not', async () => {
  const f = fixture(); await f.service.submit(actor, input);
  assert.equal(f.donation.payment_status, 'pending');
  f.state.status = 'canceled';
  assert.equal((await f.service.status(actor, input)).status, 'canceled');
  assert.equal(f.state.rpc.filter(v => v.operation === 'canceled').length, 1);
});

for (const mutation of [
  { livemode: true }, { amount: 1 }, { currency: 'usd' }, { transfer_group: 'other' },
  { metadata: { dopmi_donation: 'other', consent_version: oneoffConsentVersion } },
  { metadata: { dopmi_donation: '93000000-0000-4000-8000-000000000001', consent_version: 'wrong' } },
]) test(`mismatched processor evidence rejected: ${Object.keys(mutation)}`, async () => {
  const f = fixture(); f.state.mutate = value => ({ ...value, ...mutation });
  await assert.rejects(f.service.submit(actor, input), { code: 'charge_mismatch' });
  assert.equal(f.donation.stripe_payment_intent_id, undefined);
});

test('missing consent and changed response ownership stop before provider work', async () => {
  const f = fixture();
  await assert.rejects(f.service.submit(actor, { ...input, consent: false }), { code: 'payment_consent_required' });
  assert.equal(f.state.rpc.length, 0);
  f.donation.donor_id = '90000000-0000-4000-8000-000000000002';
  await assert.rejects(f.service.submit(actor, input), { code: 'access_denied' });
  assert.equal(f.state.creates.length, 0);
});

test('historical hosted attempt resumes original channel and never creates native intent', async () => {
  const f = fixture(); f.donation.payment_flow = 'hosted';
  assert.equal((await f.service.submit(actor, input)).url, 'https://checkout.stripe.com/synthetic');
  assert.equal(f.state.creates.length, 0);
  assert.deepEqual(f.state.hosted[0].payload, { expense_id: input.expense_id, gross_cents: input.gross_cents, key: input.key });
});

test('unbound unknown creation after idempotency window stops without a new request', async () => {
  const f = fixture(); f.donation.created_at = new Date(Date.now() - 24 * 3600000).toISOString();
  await assert.rejects(f.service.submit(actor, input), { code: 'manual_reconciliation_required' });
  assert.equal(f.state.creates.length, 0);
});

for (const finalStatus of ['canceled', 'succeeded', 'processing', 'requires_action'])
  test(`expiry reconciles a racing ${finalStatus} without another intent`, async () => {
    const f = fixture(); await f.service.submit(actor, input);
    f.donation.created_at = new Date(Date.now() - 3600001).toISOString();
    f.state.cancel = () => { f.state.status = finalStatus; throw Error('synthetic lost cancellation'); };
    const result = await f.service.status(actor, input);
    assert.equal(result.status, finalStatus === 'canceled' ? 'canceled' : finalStatus === 'succeeded' ? 'confirmed' : 'pending');
    assert.equal(result.payment_client_secret, finalStatus === 'processing' || finalStatus === 'requires_action' ? null : undefined);
    if (finalStatus === 'processing' || finalStatus === 'requires_action') assert.equal(result.payment_state, 'processing');
    assert.equal(f.state.cancels[0].options.idempotencyKey, `dopmi-native-oneoff-expire-${f.donation.id}`);
    assert.equal(f.state.rpc.filter(v => v.operation === 'canceled').length, finalStatus === 'canceled' ? 1 : 0);
    assert.equal(f.state.creates.length, 1);
  });

test('a processing intent is not canceled on expiry, and missing actionable secret is rejected', async () => {
  const f = fixture(); await f.service.submit(actor, input);
  f.donation.created_at = new Date(Date.now() - 3600001).toISOString();
  f.state.status = 'processing';
  assert.equal((await f.service.status(actor, input)).payment_client_secret, null);
  assert.equal(f.state.cancels.length, 0);
  f.donation.created_at = new Date().toISOString();
  f.state.status = 'requires_payment_method';
  f.state.mutate = value => ({ ...value, client_secret: null });
  await assert.rejects(f.service.status(actor, input), { code: 'charge_mismatch' });
});

for (const finalStatus of ['canceled', 'succeeded', 'processing'])
  test(`background worker preserves expiry race ${finalStatus} without creating payments`, async () => {
    const f = fixture();
    f.donation.created_at = new Date(Date.now() - 3600001).toISOString();
    Object.assign(f.donation, { stripe_payment_intent_id: 'pi_synthetic', currency: 'mxn',
      destination: 'acct_synthetic', rescuer_id: actor, allocated_cents: 0, refund_cents: 0 });
    let processorStatus = 'requires_action', cancelRequests = 0, canceledRows = 0;
    const paths = [];
    const pi = () => ({ id: 'pi_synthetic', livemode: false, amount: 10000, amount_received: 10000,
      currency: 'mxn', status: processorStatus, metadata: { dopmi_donation: f.donation.id, consent_version: oneoffConsentVersion },
      latest_charge: { id: 'ch_synthetic', paid: true, captured: true, disputed: false, amount: 10000,
        currency: 'mxn', amount_refunded: 0, balance_transaction: { currency: 'mxn', amount: 10000, fee: 600 } } });
    const worker = paymentService({ logger: {},
      rpc: async (operation, data) => {
        if (operation === 'reconcile_candidates') return [{ id: f.donation.id, stripe_payment_intent_id: 'pi_synthetic' }];
        if (operation === 'get') return structuredClone(f.donation);
        if (operation === 'cancel') { canceledRows++; f.donation.payment_status = 'canceled'; return {}; }
        if (operation === 'claim') return null;
        if (operation === 'lookup_account') return { owner_id: actor, account_id: 'acct_synthetic' };
        if (operation === 'connect_save') return {};
        if (operation === 'settle') { f.donation.payment_status = 'confirmed'; f.donation.processed_at = new Date().toISOString(); return structuredClone(f.donation); }
        throw Error(operation);
      },
      stripe: async (path, body, key) => {
        paths.push(path);
        if (path === 'payment_intents/pi_synthetic/cancel') {
          cancelRequests++;
          assert.equal(key, `dopmi-native-oneoff-expire-${f.donation.id}`);
          processorStatus = finalStatus;
          throw Error('synthetic cancellation response lost');
        }
        if (path.startsWith('payment_intents/pi_synthetic')) return pi();
        if (path === 'accounts/acct_synthetic') return { id: 'acct_synthetic', capabilities: { transfers: 'active' }, payouts_enabled: true };
        throw Error(path);
      },
    });
    const result = await worker.reconcile();
    assert.equal(result.failed, 0);
    assert.equal(cancelRequests, 1);
    assert.equal(canceledRows, finalStatus === 'canceled' ? 1 : 0);
    assert.equal(f.donation.payment_status, finalStatus === 'succeeded' ? 'confirmed' : finalStatus === 'canceled' ? 'canceled' : 'pending');
    assert.equal(paths.some(path => path === 'payment_intents' || path === 'checkout/sessions'), false);
  });
