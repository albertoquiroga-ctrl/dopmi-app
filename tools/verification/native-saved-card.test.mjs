import test from 'node:test';
import assert from 'node:assert/strict';
import { nativeSavedCardService } from '../../supabase/functions/_shared/native-saved-card.mjs';
import { guardianRegistrationService } from '../../supabase/functions/_shared/guardian-registration.mjs';
import { savedCardConsentVersion } from '../../supabase/functions/_shared/saved-card.mjs';

const key = '72000000-0000-4000-8000-000000000002';
function fixture() {
  const job = { id: 'job', owner_id: 'owner', request_key: key, status: 'pending', wallet_type: 'card',
    wallet_id: 'a52540a5-e18d-40a7-9e43-748510ebbe3e', customer_id: 'cus_owner',
    consent_version: savedCardConsentVersion, consent_at: '2026-10-15T00:00:00Z',
    expires_at: new Date(Date.now() + 60000).toISOString(), lease: 'lease' };
  const setup = { id: 'seti_card', customer: 'cus_owner', livemode: false, usage: 'off_session',
    payment_method_types: ['card'], status: 'requires_payment_method', client_secret: 'seti_card_secret_fixture',
    payment_method: 'pm_card', metadata: { dopmi_saved_card_job: 'job', wallet_type: 'card', consent_version: savedCardConsentVersion } };
  const method = { id: 'pm_card', customer: 'cus_owner', livemode: false, type: 'card', card: {} };
  const f = { job, setup, method, calls: [], operations: [], lease: true, ready: true, exists: true,
    customer: { id: 'cus_owner', livemode: false } };
  f.rpc = async (op, data) => {
    f.operations.push({ op, data: structuredClone(data) });
    if (op === 'prepare_registration' || op === 'registration_job') return f.exists ? structuredClone(job) : null;
    if (op === 'candidates') return f.queue ?? [];
    if (op === 'lookup_setup') return data.setup_intent_id === setup.id ? structuredClone(job) : null;
    if (op === 'get' && data.id === 'failed') throw Error('fixture unavailable');
    if (op === 'get') return structuredClone(job);
    if (op === 'claim') return f.lease ? structuredClone(job) : null;
    if (op === 'native_ready') return f.ready ? structuredClone(job) : null;
    assert.equal(data.lease, 'lease');
    if (op === 'native_saved' && f.slowSave) {
      await new Promise(resolve => setTimeout(resolve, 10));
      assert.equal(f.released, undefined, 'lease released before durable saved checkpoint completed');
    }
    if (op === 'release') f.released = true;
    if (op === 'customer') job.customer_id = data.customer_id;
    if (op === 'native_setup') job.setup_intent_id = data.setup_intent_id;
    if (op === 'native_saved') { job.status = 'saved'; job.payment_method_id = data.payment_method_id; }
    if (op === 'expired') job.status = 'expired';
    return structuredClone(job);
  };
  const stripe = {
    customers: {
      create: async (data, options) => { f.calls.push({ op: 'customer', data, options }); return structuredClone(f.customer); },
      retrieve: async () => structuredClone(f.customer),
    },
    setupIntents: {
      create: async (data, options) => {
        f.calls.push({ op: 'setup', data, options });
        if (f.lost) { f.lost = false; throw Error('lost setup response'); }
        return structuredClone(setup);
      },
      retrieve: async () => structuredClone(setup),
      cancel: async (id, data, options) => {
        f.calls.push({ op: 'cancel', id, data, options });
        if (f.race) { setup.status = 'succeeded'; throw Error('confirmation won'); }
        setup.status = 'canceled'; return structuredClone(setup);
      },
    },
    paymentMethods: { retrieve: async () => structuredClone(method) },
    events: { retrieve: async () => structuredClone(f.event) },
  };
  const hosted = { checkout: async (actor, input) => {
    f.calls.push({ op: 'hosted', actor, input });
    return { key: input.key, status: 'pending', checkout_url: 'https://checkout.stripe.com/c/fixture' };
  } };
  f.service = nativeSavedCardService({ stripe, rpc: f.rpc, hosted,
    returnUrl: 'https://fixture.supabase.co/functions/v1/payment-return' });
  return f;
}
const consent = { key, consent: true, consent_version: savedCardConsentVersion };

test('native card reserves before creating a no-charge off-session setup with stable resource key', async () => {
  const f = fixture();
  const r = await f.service.submit('owner', consent);
  assert.deepEqual(r, { key, status: 'pending', method_status: 'requires_payment_method',
    setup_client_secret: 'seti_card_secret_fixture', checkout_url: null });
  assert.deepEqual(f.calls, [{ op: 'setup', data: { customer: 'cus_owner', usage: 'off_session',
    allowed_payment_method_types: ['card'], metadata: { dopmi_saved_card_job: 'job', wallet_type: 'card',
      consent_version: savedCardConsentVersion } }, options: { idempotencyKey: 'dopmi-native-card-setup:job' } }]);
  assert.ok(f.operations.findIndex(c => c.op === 'claim') < f.operations.findIndex(c => c.op === 'native_setup'));
  for (const field of ['customer_id', 'owner_id', 'setup_intent_id', 'payment_method_id', 'wallet_id'])
    assert.equal(Object.hasOwn(r, field), false);
});

test('native card consent and owner binding reject before provider work', async () => {
  for (const patch of [{ consent: false }, { consent_version: 'old' }, { key: 'foreign' }]) {
    const f = fixture(); await assert.rejects(f.service.submit('owner', { ...consent, ...patch }), /consent_required/);
    assert.equal(f.operations.length, 0); assert.equal(f.calls.length, 0);
  }
  for (const patch of [{ owner_id: 'other' }, { request_key: 'other' }, { wallet_type: 'google_pay' }]) {
    const f = fixture(); Object.assign(f.job, patch);
    await assert.rejects(f.service.submit('owner', consent), /job_invalid/);
    assert.equal(f.calls.length, 0);
  }
});

test('lost native setup response retries exactly the same key, never a new payment or method', async () => {
  const f = fixture(); f.lost = true;
  await assert.rejects(f.service.submit('owner', consent), /lost setup response/);
  await f.service.submit('owner', consent);
  assert.deepEqual(f.calls[0], f.calls[1]); assert.equal(f.job.status, 'pending');
  assert.equal(f.operations.filter(c => c.op === 'native_saved').length, 0);
});

test('historical hosted job remains hosted even when session response was lost', async () => {
  for (const session_id of [null, 'cs_test_original']) {
    const f = fixture(); Object.assign(f.job, { wallet_type: null, session_id });
    const result = await f.service.submit('owner', consent);
    assert.equal(result.checkout_url, 'https://checkout.stripe.com/c/fixture');
    assert.deepEqual(f.calls, [{ op: 'hosted', actor: 'owner', input: consent }]);
    assert.equal(f.operations.some(c => c.op === 'claim'), false);
  }
});

test('status never reserves a missing job and uses the same existing owner-bound setup', async () => {
  const f = fixture(); f.exists = false;
  assert.equal(await f.service.status('owner', { key }), null); assert.equal(f.calls.length, 0);
  f.exists = true; await f.service.status('owner', { key });
  assert.equal(f.operations.some(c => c.op === 'prepare_registration'), false);
  assert.equal(f.calls[0].options.idempotencyKey, 'dopmi-native-card-setup:job');
});

test('only fresh successful SetupIntent and matching non-wallet card can become saved', async () => {
  const f = fixture(); await f.service.submit('owner', consent);
  f.setup.status = 'processing';
  const pending = await f.service.status('owner', { key });
  assert.equal(pending.method_status, 'processing'); assert.equal(pending.setup_client_secret, null);
  assert.equal(f.job.status, 'pending');
  f.setup.status = 'succeeded';
  const saved = await f.service.status('owner', { key });
  assert.equal(saved.status, 'saved'); assert.equal(saved.setup_client_secret, null);
  await f.service.status('owner', { key });
  assert.equal(f.operations.filter(c => c.op === 'native_saved').length, 1);
  assert.equal(f.calls.length, 1);
});

test('native saved checkpoint finishes before releasing the lease', async () => {
  const f = fixture(); f.job.setup_intent_id = f.setup.id; f.setup.status = 'succeeded'; f.slowSave = true;
  assert.equal((await f.service.status('owner', { key })).status, 'saved');
  assert.equal(f.released, true);
});

test('wrong setup metadata, live mode, owner or wallet cannot complete or leak secrets', async () => {
  for (const patch of [{ livemode: true }, { customer: 'cus_other' }, { usage: 'on_session' },
    { metadata: {} }, { payment_method_types: ['card', 'link'] }]) {
    const f = fixture(); f.job.setup_intent_id = f.setup.id; Object.assign(f.setup, patch);
    await assert.rejects(f.service.status('owner', { key }), /setup_mismatch/);
    assert.equal(f.job.status, 'pending');
  }
  for (const patch of [{ livemode: true }, { customer: 'cus_other' }, { type: 'bank_account' },
    { card: { wallet: { type: 'apple_pay' } } }]) {
    const f = fixture(); f.job.setup_intent_id = f.setup.id; f.setup.status = 'succeeded'; Object.assign(f.method, patch);
    await assert.rejects(f.service.status('owner', { key }), /method_mismatch/);
    assert.equal(f.job.status, 'pending');
  }
});

test('missing lease or native-ready evidence cannot expose secret or create provider work', async () => {
  const f = fixture(); f.lease = false; f.ready = false;
  assert.equal((await f.service.submit('owner', consent)).setup_client_secret, null);
  assert.equal(f.calls.length, 0);
  f.job.setup_intent_id = f.setup.id;
  assert.equal((await f.service.submit('owner', consent)).setup_client_secret, null);
  assert.equal(f.calls.length, 0);
});

test('expiration cancels setup; concurrent confirmation must still prove card ownership', async () => {
  const f = fixture(); f.job.setup_intent_id = f.setup.id; f.job.expires_at = '2020-01-01T00:00:00Z';
  const expired = await f.service.status('owner', { key });
  assert.equal(expired.status, 'expired'); assert.equal(expired.setup_client_secret, null);
  assert.equal(f.calls[0].options.idempotencyKey, 'dopmi-native-card-expire:job');
  const race = fixture(); race.job.setup_intent_id = race.setup.id; race.job.expires_at = '2020-01-01T00:00:00Z'; race.race = true;
  assert.equal((await race.service.status('owner', { key })).status, 'saved');
});

test('native webhook re-reads provider outcome and worker isolates failed candidates', async () => {
  const f = fixture(); await f.service.submit('owner', consent);
  f.event = { livemode: false, type: 'setup_intent.succeeded', data: { object: { id: f.setup.id } } };
  assert.deepEqual(await f.service.handleWebhook('evt_fixture'), { received: true, saved_native_card: true });
  assert.equal(f.job.status, 'pending');
  f.setup.status = 'succeeded';
  await f.service.handleWebhook('evt_fixture'); assert.equal(f.job.status, 'saved');
  f.queue = [{ id: 'failed' }, { id: 'job' }];
  assert.deepEqual(await f.service.reconcile(), { saved: 1, failed: 1 });
});

test('registration reconciles native method on status and suppresses secret if cancellation wins', async () => {
  let status = 'method_pending', confirmed = false;
  const calls = [];
  const service = guardianRegistrationService({
    rpc: async op => {
      calls.push(op); if (confirmed && status === 'method_pending') status = 'registered';
      return { id: key, request_key: key, status };
    },
    savedNativeCard: {
      status: async (actor, input) => { assert.equal(actor, 'owner'); assert.equal(input.key, key); confirmed = true; return { status: 'saved' }; },
      submit: async () => { status = 'canceled'; return { method_status: 'requires_payment_method', setup_client_secret: 'seti_card_secret_fixture' }; },
    },
  });
  assert.equal((await service.status('owner', { id: key })).status, 'registered');
  assert.deepEqual(calls, ['reconcile_method', 'reconcile_method']);
  status = 'method_pending'; confirmed = false;
  const result = await service.register('owner', { key, gross_cents: 2000, consent: true,
    consent_version: 'guardian-registration-2026-10-14', method_consent: true, method_consent_version: savedCardConsentVersion });
  assert.equal(result.status, 'canceled'); assert.equal(result.setup_client_secret, null);
});
