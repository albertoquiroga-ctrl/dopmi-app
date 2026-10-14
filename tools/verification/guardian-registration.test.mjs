import { test } from 'node:test';
import assert from 'node:assert/strict';
import { guardianRegistrationService } from '../../supabase/functions/_shared/guardian-registration.mjs';
import { guardianClientHandler } from '../../supabase/functions/_shared/guardian-client.mjs';

const key = '72000000-0000-4000-8000-000000000001';
const id = '72000000-0000-4000-8000-000000000002';
const input = { key, gross_cents: 2000, consent: true, consent_version: 'guardian-registration-2026-10-14',
  method_consent: true, method_consent_version: 'saved-cards-2026-10-03' };
function fixture() {
  const state = { id, request_key: key, owner_id: 'owner', status: 'method_pending', gross_cents: 2000,
    revision: 0, registered_at: '2026-10-14T00:00:00Z', next_evaluation_at: '2026-11-14T00:00:00Z' };
  const calls = [];
  let confirmed = false, lose = false, cancelDuringSetup = false;
  const service = guardianRegistrationService({
    rpc: async (op, data) => {
      assert.equal(data.owner_id, 'owner');
      calls.push({ op, ...data });
      if (op === 'cancel') state.status = 'canceled';
      if (op === 'reconcile_method' && confirmed && state.status === 'method_pending') {
        state.status = 'registered'; state.revision++;
      }
      return { ...state };
    },
    savedCard: { checkout: async (actor, data) => {
      assert.equal(actor, 'owner');
      assert.deepEqual(data, { key: id, consent: true, consent_version: 'saved-cards-2026-10-03' });
      calls.push({ op: 'setup', key: data.key });
      if (cancelDuringSetup) state.status = 'canceled';
      if (lose) { lose = false; throw new Error('response lost after setup'); }
      return { status: confirmed ? 'saved' : 'pending', checkout_url: 'https://checkout.stripe.com/c/test' };
    } },
  });
  return { service, state, calls, confirm: () => { confirmed = true; },
    lose: () => { lose = true; }, cancelDuringSetup: () => { cancelDuringSetup = true; } };
}
test('registration method: separate consents before persistence or provider work', async () => {
  const f = fixture();
  for (const delta of [{ consent: false }, { method_consent: false }, { method_consent_version: 'old' }])
    await assert.rejects(f.service.register('owner', { ...input, ...delta }), /consent_required/);
  assert.equal(f.calls.length, 0);
});
test('registration method: pending is not registered and private evidence never leaks', async () => {
  const f = fixture();
  const result = await f.service.register('owner', input);
  assert.equal(result.status, 'method_pending');
  assert.equal(result.method_status, 'pending');
  assert.equal(result.next_evaluation_at, '2026-11-14T00:00:00Z');
  for (const privateKey of ['owner_id', 'customer_id', 'method_job_id', 'payment_method_id'])
    assert.equal(Object.hasOwn(result, privateKey), false);
  assert.deepEqual(f.calls.map(c => c.op), ['prepare', 'setup', 'reconcile_method']);
});
test('registration method: lost response retries same setup key, server evidence decides completion', async () => {
  const f = fixture(); f.lose();
  await assert.rejects(f.service.register('owner', input), /response lost/);
  const pending = await f.service.register('owner', input);
  assert.equal(pending.status, 'method_pending');
  assert.deepEqual(f.calls.filter(c => c.op === 'setup').map(c => c.key), [id, id]);
  f.confirm();
  assert.equal((await f.service.status('owner', { id })).status, 'registered');
  const complete = await f.service.register('owner', input);
  assert.equal(complete.checkout_url, null);
  assert.equal(f.calls.filter(c => c.op === 'setup').length, 2);
});
test('registration method: cancel before or during setup cannot complete registration', async () => {
  const f = fixture();
  await f.service.cancel('owner', { id });
  assert.equal((await f.service.register('owner', input)).status, 'canceled');
  assert.equal(f.calls.some(c => c.op === 'setup'), false);
  const race = fixture(); race.confirm(); race.cancelDuringSetup();
  const result = await race.service.register('owner', input);
  assert.equal(result.status, 'canceled');
  assert.equal(result.checkout_url, null);
  assert.equal(result.next_evaluation_at, null);
});
test('registration endpoint: authenticated owner only, strict fields, minimum and independent consent', async () => {
  const calls = [];
  const handler = guardianClientHandler({ enabled: () => true,
    authenticate: async () => ({ id: 'server-owner', email_confirmed_at: 'today' }),
    registration: async (actor, data) => { calls.push({ actor, data }); return { status: 'method_pending' }; } });
  const request = data => handler(new Request('https://example.test/guardian-client', {
    method: 'POST', headers: { Authorization: 'Bearer synthetic' }, body: JSON.stringify(data),
  }));
  for (const delta of [{ owner_id: 'other' }, { method_job_id: id }, { gross_cents: 1999 }, { method_consent: false }])
    assert.equal((await request({ action: 'register', ...input, ...delta })).status, 400);
  assert.equal(calls.length, 0);
  assert.equal((await request({ action: 'register', ...input })).status, 200);
  assert.equal(calls[0].actor, 'server-owner');
  for (const action of ['registration_status', 'registration_cancel'])
    assert.equal((await request({ action, id })).status, 200);
  assert.equal((await request({ action: 'registration_amount', id, gross_cents: 2000, revision: 0,
    consent: true, consent_version: input.consent_version })).status, 200);
  assert.equal((await handler(new Request('https://example.test', { method: 'POST', body: '{}' }))).status, 401);
});

test('registration worker: server candidates recover after app closes without setup or charge', async () => {
  const calls = [];
  const service = guardianRegistrationService({
    savedCard: { checkout: () => { throw new Error('worker must not create setup'); } },
    rpc: async (op, data) => {
      calls.push({ op, data });
      if (op === 'method_candidates') return [{ id, owner_id: 'owner' }];
      assert.deepEqual(data, { id, owner_id: 'owner' });
      return { status: 'registered' };
    },
  });
  assert.deepEqual(await service.reconcile(), { registered: 1, failed: 0 });
  assert.deepEqual(calls.map(c => c.op), ['method_candidates', 'reconcile_method']);
});

test('registration worker: cancellation race and one unavailable owner do not complete or strand others', async () => {
  const seen = [];
  const service = guardianRegistrationService({ rpc: async (op, data) => {
    if (op === 'method_candidates') return ['canceled', 'unavailable', 'ready'].map(owner_id => ({ id, owner_id }));
    seen.push(data.owner_id);
    if (data.owner_id === 'unavailable') throw new Error('account changed');
    return { status: data.owner_id === 'ready' ? 'registered' : 'canceled' };
  } });
  assert.deepEqual(await service.reconcile(), { registered: 1, failed: 1 });
  assert.deepEqual(seen, ['canceled', 'unavailable', 'ready']);
});

test('registration attempt worker: server identities, cancellation and failures never invoke setup or payment', async () => {
  const seen = [];
  const service = guardianRegistrationService({
    savedCard: { checkout: () => { throw new Error('must not setup'); } },
    rpc: () => { throw new Error('must use attempt boundary'); },
    attemptRpc: async (op, data) => {
      if (op === 'candidates') return ['ready', 'canceled', 'unavailable', 'skipped', 'later'].map(id => ({ id }));
      seen.push(data);
      if (data.id === 'unavailable') throw new Error('private provider reference');
      return ['ready', 'later'].includes(data.id) ? { id: data.id, status: 'prepared' } : null;
    },
  });
  assert.deepEqual(await service.prepareAttempts(), { prepared: 2, skipped: 2, failed: 1 });
  assert.deepEqual(seen, ['ready', 'canceled', 'unavailable', 'skipped', 'later'].map(id => ({ id })));
});

test('registration attempt worker: discovery failure cannot be reported as successful empty work', async () => {
  const service = guardianRegistrationService({ attemptRpc: async () => { throw new Error('database unavailable'); } });
  await assert.rejects(service.prepareAttempts(), /database unavailable/);
});
