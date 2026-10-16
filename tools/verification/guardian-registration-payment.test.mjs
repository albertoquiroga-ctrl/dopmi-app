import { test } from 'node:test';
import assert from 'node:assert/strict';
import { registrationPaymentEvidence } from '../../supabase/functions/_shared/guardian-registration-payment.mjs';
import { guardianRegistrationConsumer } from '../../supabase/functions/_shared/guardian-registration-consumer.mjs';
import { registrationSettlementEvidence, readRegistrationSettlementEvidence } from '../../supabase/functions/_shared/guardian-registration-settlement.mjs';
import { guardianRegistrationWorker } from '../../supabase/functions/_shared/guardian-registration-worker.mjs';
import { guardianRegistrationBankAction } from '../../supabase/functions/_shared/guardian-registration-bank-action.mjs';
import { guardianClientHandler } from '../../supabase/functions/_shared/guardian-client.mjs';

const attempt = { id: 'synthetic-attempt', stripe_payment_intent_id: 'pi_synthetic',
  pay_requested_at: '2026-10-14T19:45:00Z', gross_cents: 2000,
  customer_id: 'cus_synthetic', payment_method_id: 'pm_synthetic' };
const intent = { id: 'pi_synthetic', livemode: false, currency: 'mxn', amount: 2000,
  customer: 'cus_synthetic', payment_method: 'pm_synthetic',
  metadata: { guardian_registration_attempt_id: attempt.id }, status: 'processing' };
test('registration bank action returns a transient secret only after two owner gates without any payment write', async () => {
  const owned = { ...attempt, owner_id: 'owner', registration_id: 'registration', processor_state: 'requires_action' };
  let gates = 0, reads = 0;
  const action = guardianRegistrationBankAction({ authorizeAction: async (owner, registration, id) => {
    gates++; assert.equal(owner, 'owner'); assert.equal(registration, 'registration'); assert.equal(id, attempt.id); return owned;
  }, stripe: { paymentIntents: { retrieve: async id => { reads++; assert.equal(id, intent.id);
    return { ...intent, status: 'requires_action', next_action: { type: 'use_stripe_sdk' }, client_secret: 'pi_synthetic_secret_synthetic' }; } } } });
  const result = await action('owner', { id: 'registration', attempt_id: attempt.id });
  assert.equal(result.state, 'requires_action'); assert.equal(result.client_secret, 'pi_synthetic_secret_synthetic');
  assert.equal(gates, 2); assert.equal(reads, 1); assert.equal(Object.hasOwn(result, 'customer_id'), false);
});
test('registration bank action cancellation during processor read prevents secret release', async () => {
  let gates = 0;
  const action = guardianRegistrationBankAction({ authorizeAction: async () => {
    if (++gates === 2) throw new Error('synthetic cancellation won');
    return { ...attempt, owner_id: 'owner', registration_id: 'registration', processor_state: 'requires_action' };
  }, stripe: { paymentIntents: { retrieve: async () => ({ ...intent, status: 'requires_action',
    next_action: { type: 'use_stripe_sdk' }, client_secret: 'pi_synthetic_secret_synthetic' }) } } });
  await assert.rejects(action('owner', { id: 'registration', attempt_id: attempt.id }), /cancellation won/);
});
test('registration bank action rejects mismatched owner before I/O and stale non-action state has no secret', async () => {
  const owned = { ...attempt, owner_id: 'owner', registration_id: 'registration', processor_state: 'requires_action' };
  const bad = guardianRegistrationBankAction({ authorizeAction: async () => ({ ...owned, owner_id: 'other' }),
    stripe: { paymentIntents: { retrieve: () => assert.fail('foreign read') } } });
  await assert.rejects(bad('owner', { id: 'registration', attempt_id: attempt.id }), /action_unavailable/);
  const stale = guardianRegistrationBankAction({ authorizeAction: async () => owned,
    stripe: { paymentIntents: { retrieve: async () => intent } } });
  assert.deepEqual(await stale('owner', { id: 'registration', attempt_id: attempt.id }),
    { id: 'registration', attempt_id: attempt.id, state: 'processing' });
});
test('registration bank action endpoint authenticates owner and rejects secret or processor injection', async () => {
  const id = '72000000-0000-4000-8000-000000000001';
  const attemptId = '72000000-0000-4000-8000-000000000002';
  let calls = 0;
  const handler = guardianClientHandler({ enabled: () => true,
    authenticate: async () => ({ id: 'server-owner', email_confirmed_at: 'synthetic' }),
    registrationAction: async (owner, data) => { calls++; assert.equal(owner, 'server-owner');
      assert.deepEqual(data, { id, attempt_id: attemptId }); return { state: 'processing' }; },
  });
  const request = body => new Request('https://example.test', { method: 'POST',
    headers: { Authorization: 'Bearer synthetic' }, body: JSON.stringify(body) });
  const body = { action: 'registration_action', id, attempt_id: attemptId };
  for (const extra of [{ owner_id: 'other' }, { client_secret: 'foreign' }, { payment_intent_id: intent.id }, { gross_cents: 2000 }])
    assert.equal((await handler(request({ ...body, ...extra }))).status, 400);
  assert.equal(calls, 0); assert.equal((await handler(request(body))).status, 200); assert.equal(calls, 1);
  assert.equal((await handler(new Request('https://example.test', { method: 'POST', body: JSON.stringify(body) }))).status, 401);
});

function paidFixture() {
  return { ...intent, status: 'succeeded', amount_received: 2000, capture_method: 'automatic',
    latest_charge: { id: 'ch_synthetic', livemode: false, payment_intent: intent.id,
      customer: attempt.customer_id, currency: 'mxn', amount: 2000, paid: true, captured: true,
      disputed: false, amount_refunded: 0, refunded: false,
      balance_transaction: { id: 'txn_synthetic', source: 'ch_synthetic', currency: 'mxn',
        amount: 2000, fee: 100, net: 1900 } } };
}
test('registration settlement evidence uses actual processor fee and original owner/method', async () => {
  const paid = paidFixture(); const owned = { ...attempt, owner_id: 'synthetic-owner' };
  const evidence = registrationSettlementEvidence(owned, paid);
  assert.equal(evidence.net_cents, 1860); assert.equal(evidence.platform_fee_cents, 40);
  assert.equal(evidence.stripe_fee_cents, 100); assert.equal(evidence.donor_id, owned.owner_id);
  assert.equal(evidence.registration_attempt_id, owned.id);
  const read = await readRegistrationSettlementEvidence({ paymentIntents: { retrieve: async (id, params) => {
    assert.equal(id, attempt.stripe_payment_intent_id);
    assert.deepEqual(params.expand, ['latest_charge.balance_transaction']); return paid;
  } } }, owned);
  assert.deepEqual(read, evidence);
});
test('registration settlement evidence rejects disputed, refunded, foreign and destination charges', () => {
  const paid = paidFixture();
  for (const delta of [{ livemode: true }, { payment_intent: 'pi_other' }, { customer: 'cus_other' },
    { currency: 'usd' }, { amount: 1999 }, { paid: false }, { captured: false }, { disputed: true },
    { amount_refunded: 1 }, { refunded: true }, { transfer: 'tr_foreign' }, { destination: 'acct_other' }])
    assert.throws(() => registrationSettlementEvidence(attempt, { ...paid, latest_charge: { ...paid.latest_charge, ...delta } }), /unconfirmed/);
  for (const delta of [{ capture_method: 'manual' }, { transfer_data: {} }, { application_fee_amount: 1 }])
    assert.throws(() => registrationSettlementEvidence(attempt, { ...paid, ...delta }), /unconfirmed/);
});
test('registration settlement evidence rejects absent, foreign and inconsistent balance transactions', () => {
  const paid = paidFixture();
  for (const balance of [null, 'txn_synthetic', { ...paid.latest_charge.balance_transaction, source: 'ch_foreign' },
    { ...paid.latest_charge.balance_transaction, currency: 'usd' },
    { ...paid.latest_charge.balance_transaction, fee: -1 },
    { ...paid.latest_charge.balance_transaction, net: 2000 },
    { ...paid.latest_charge.balance_transaction, amount: 1999 },
    { ...paid.latest_charge.balance_transaction, fee: 1960, net: 40 }])
    assert.throws(() => registrationSettlementEvidence(attempt, { ...paid,
      latest_charge: { ...paid.latest_charge, balance_transaction: balance } }), /unconfirmed/);
});
test('registration worker disabled new sends still finalizes a known canceled attempt without Stripe', async () => {
  const pending = { ...attempt, id: 'pending', pay_requested_at: null, status: 'prepared' };
  const canceled = { ...attempt, processor_state: 'processor_canceled' };
  const resolved = [];
  const worker = guardianRegistrationWorker({ stripe: {},
    paymentRpc: async (op, data) => op === 'candidates' ? [{ id: pending.id }] :
      op === 'finalization_candidates' ? [{ id: canceled.id }] : data.id === pending.id ? pending : canceled,
    bind: () => assert.fail('no bind'), authorize: () => assert.fail('no authorize'),
    settle: () => assert.fail('no settlement for canceled'), resolve: async id => resolved.push(id),
  });
  assert.deepEqual(await worker.reconcile(), { observed: 0, finalized: 1, failed: 0 });
  assert.deepEqual(resolved, [attempt.id]);
});
test('registration worker restart after settlement only resolves, never recreates or settles again', async () => {
  const row = { ...attempt, owner_id: 'synthetic-owner', processor_state: 'processor_succeeded' };
  let reads = 0, settlements = 0, lost = true;
  const worker = guardianRegistrationWorker({
    stripe: { paymentIntents: { retrieve: async () => { reads++; return paidFixture(); } } },
    paymentRpc: async op => op === 'candidates' ? [] : op === 'finalization_candidates' ? [{ id: row.id }] : { ...row },
    settle: async evidence => { settlements++; assert.equal(evidence.net_cents, 1860);
      row.settlement = { registration_attempt_id: row.id }; },
    resolve: async () => { if (lost) { lost = false; throw new Error('synthetic interruption'); }
      row.resolved_at = '2026-10-14T20:00:00Z'; },
  });
  assert.deepEqual(await worker.reconcile(), { observed: 0, finalized: 0, failed: 1 });
  assert.deepEqual(await worker.reconcile(), { observed: 0, finalized: 1, failed: 0 });
  assert.equal(reads, 1); assert.equal(settlements, 1);
});
test('registration worker keeps bank action uncertain and never resends an existing marker', async () => {
  const row = { ...attempt, processor_state: 'requires_action' };
  let reads = 0, observations = 0;
  const worker = guardianRegistrationWorker({
    stripe: { paymentIntents: { retrieve: async () => { reads++; return { ...intent, status: 'requires_action' }; } } },
    paymentRpc: async (op, data) => { if (op === 'candidates') return [{ id: row.id }];
      if (op === 'finalization_candidates') return [];
      if (op === 'observe') { observations++; assert.equal(data.payment_intent_id, intent.id); }
      return { ...row }; },
    authorize: () => assert.fail('no authorize'), bind: () => assert.fail('no bind'),
    settle: () => assert.fail('no settle'), resolve: () => assert.fail('no resolve'),
  });
  assert.deepEqual(await worker.reconcile(), { observed: 1, finalized: 0, failed: 0 });
  assert.equal(reads, 1); assert.equal(observations, 1);
});
test('registration worker isolates candidate errors and preserves later finalization', async () => {
  const row = { ...attempt, processor_state: 'processor_canceled' };
  let resolved = false;
  const worker = guardianRegistrationWorker({ stripe: {},
    paymentRpc: async (op, data) => op === 'candidates' ? [{ id: 'broken' }] :
      op === 'finalization_candidates' ? [{ id: row.id }] : data.id === 'broken' ? null : row,
    resolve: async () => { resolved = true; },
  });
  assert.deepEqual(await worker.reconcile(), { observed: 0, finalized: 1, failed: 1 });
  assert.equal(resolved, true);
});

function harness({ denied = false, lost = false, mismatch = false, marked = false,
  lostCreate = false, lostBind = false, lostObserve = false,
  clearMethodOnCancel = false, cancelWinsConfirmation = false, lostCancel = false } = {}) {
  const calls = [];
  let row = { ...attempt, status: 'prepared', stripe_payment_intent_id: marked ? intent.id : null,
    pay_requested_at: marked ? attempt.pay_requested_at : null };
  const processor = { ...intent, status: marked ? 'processing' : 'requires_confirmation' };
  const observations = [];
  const consumer = guardianRegistrationConsumer({ load: async () => ({ ...row }),
    observe: async (id, evidence) => { observations.push({ id, ...evidence });
      if (!['processor_succeeded', 'processor_canceled'].includes(row.processor_state)) row.processor_state = evidence.state;
      if (lostObserve) { lostObserve = false; throw new Error('synthetic observation response lost'); }
      return { ...row }; },
    bind: async (id, pi) => { calls.push('bind'); row.stripe_payment_intent_id = pi;
      if (lostBind) { lostBind = false; throw new Error('synthetic bind response lost'); }
      return { ...row }; },
    authorize: async () => { calls.push('authorize'); if (denied || row.pay_requested_at) return null;
      row.pay_requested_at = attempt.pay_requested_at;
      return { ...row, payment_key: `guardian-registration:${row.id}` }; },
    stripe: { paymentIntents: {
      create: async (params, options) => { calls.push('create'); assert.equal(params.confirm, false);
        assert.equal(params.amount, 2000); assert.equal(params.payment_method, attempt.payment_method_id);
        assert.deepEqual(params.allowed_payment_method_types, ['card']);
        assert.equal(Object.hasOwn(params, 'payment_method_types'), false);
        assert.equal(options.idempotencyKey, `guardian-registration-create:${attempt.id}`);
        if (lostCreate) { lostCreate = false; throw new Error('synthetic create response lost'); }
        return { ...processor, livemode: mismatch }; },
      retrieve: async id => { calls.push('retrieve'); assert.equal(id, intent.id); return { ...processor }; },
      cancel: async (id, params, options) => { calls.push('cancel'); assert.equal(id, intent.id);
        assert.deepEqual(params, {});
        assert.equal(options.idempotencyKey, `guardian-registration-abandon:${attempt.id}`);
        if (cancelWinsConfirmation) { processor.status = 'succeeded';
          processor.amount_received = row.gross_cents; processor.latest_charge = 'ch_synthetic_race';
          throw new Error('synthetic confirmation won'); }
        if (lostCancel) throw new Error('synthetic cancellation unavailable');
        processor.status = 'canceled';
        if (clearMethodOnCancel) processor.payment_method = null;
        return { ...processor }; },
      confirm: async (id, params, options) => { calls.push('confirm'); assert.equal(id, row.stripe_payment_intent_id);
        assert.ok(row.pay_requested_at); assert.equal(params.off_session, true);
        assert.equal(options.idempotencyKey, `guardian-registration:${row.id}`);
        processor.status = 'processing'; if (lost) throw new Error('synthetic response loss');
        return { ...processor }; },
    } },
  });
  return { consumer, calls, row, processor, observations };
}

test('registration consumer binds before authorization and confirms only the same identity once', async () => {
  const h = harness();
  assert.equal((await h.consumer.consume(attempt.id)).state, 'unresolved');
  assert.deepEqual(h.calls, ['create', 'bind', 'authorize', 'confirm']);
  await h.consumer.consume(attempt.id);
  assert.deepEqual(h.calls, ['create', 'bind', 'authorize', 'confirm', 'retrieve']);
});
test('registration consumer denied fresh authorization never confirms', async () => {
  const h = harness({ denied: true });
  assert.equal((await h.consumer.consume(attempt.id)).state, 'not_authorized');
  assert.deepEqual(h.calls, ['create', 'bind', 'authorize']);
  assert.equal(h.row.pay_requested_at, null);
});
test('registration consumer response loss reconciles without another confirmation', async () => {
  const h = harness({ lost: true });
  assert.equal((await h.consumer.consume(attempt.id)).state, 'unresolved');
  h.processor.status = 'requires_action';
  assert.equal((await h.consumer.consume(attempt.id)).state, 'requires_action');
  assert.equal(h.calls.filter(x => x === 'confirm').length, 1);
  assert.equal(h.calls.filter(x => x === 'create').length, 1);
});
test('registration consumer rejects live evidence before binding or authorizing', async () => {
  const h = harness({ mismatch: true });
  await assert.rejects(h.consumer.consume(attempt.id), /payment_mismatch/);
  assert.deepEqual(h.calls, ['create']);
});
test('registration consumer prior marker only retrieves even after cancellation', async () => {
  const h = harness({ marked: true }); h.row.status = 'canceled';
  assert.equal((await h.consumer.consume(attempt.id)).state, 'unresolved');
  assert.deepEqual(h.calls, ['retrieve']);
});

for (const status of ['requires_confirmation', 'requires_payment_method']) {
  test(`registration marked ${status} is canceled on the same intent instead of blocking future cycles`, async () => {
    const h = harness({ marked: true }); h.processor.status = status;
    assert.equal((await h.consumer.consume(attempt.id)).state, 'processor_canceled');
    assert.equal((await h.consumer.consume(attempt.id)).state, 'processor_canceled');
    assert.deepEqual(h.calls, ['retrieve', 'cancel', 'retrieve', 'retrieve']);
    assert.ok(!h.calls.includes('confirm'));
    assert.ok(!h.calls.includes('create'));
  });
}

test('registration reconciles a declined cleared method and a canceled cleared method without another charge', async () => {
  for (const initiallyCleared of [true, false]) {
    const h = harness({ marked: true, clearMethodOnCancel: true });
    h.processor.status = 'requires_payment_method';
    if (initiallyCleared) h.processor.payment_method = null;
    h.processor.last_payment_error = { payment_method: { id: attempt.payment_method_id } };
    assert.equal((await h.consumer.consume(attempt.id)).state, 'processor_canceled');
    assert.equal((await h.consumer.consume(attempt.id)).state, 'processor_canceled');
    assert.deepEqual(h.calls, ['retrieve', 'cancel', 'retrieve', 'retrieve']);
  }
});

test('registration cancellation observes confirmation race as success without sending again', async () => {
  const h = harness({ marked: true, cancelWinsConfirmation: true });
  h.processor.status = 'requires_confirmation';
  assert.equal((await h.consumer.consume(attempt.id)).state, 'processor_succeeded');
  assert.deepEqual(h.calls, ['retrieve', 'cancel', 'retrieve']);
});

test('registration fresh marker leaves the in-flight sender time to confirm without cancellation', async () => {
  const h = harness({ marked: true });
  h.row.pay_requested_at = new Date().toISOString();
  h.processor.status = 'requires_confirmation';
  assert.equal((await h.consumer.consume(attempt.id)).state, 'unresolved');
  assert.deepEqual(h.calls, ['retrieve']);
});

test('registration failed cancellation keeps reservation unresolved', async () => {
  const h = harness({ marked: true, lostCancel: true });
  h.processor.status = 'requires_payment_method'; h.processor.payment_method = null;
  assert.equal((await h.consumer.consume(attempt.id)).state, 'unresolved');
  assert.deepEqual(h.calls, ['retrieve', 'cancel', 'retrieve']);
});

test('registration cleared methods cannot prove payment, bank action, foreign method or unmarked preparation', () => {
  for (const status of ['succeeded', 'requires_action', 'processing', 'requires_confirmation'])
    assert.throws(() => registrationPaymentEvidence(attempt,
      { ...intent, payment_method: null, status }), /payment_mismatch/);
  for (const status of ['requires_payment_method', 'canceled']) {
    assert.throws(() => registrationPaymentEvidence(attempt,
      { ...intent, payment_method: null, status, last_payment_error: { payment_method: 'pm_foreign' } }), /payment_mismatch/);
    assert.throws(() => registrationPaymentEvidence({ ...attempt, pay_requested_at: null },
      { ...intent, payment_method: null, status }), /payment_mismatch/);
    assert.throws(() => registrationPaymentEvidence(attempt,
      { ...intent, payment_method: 'pm_foreign', status }), /payment_mismatch/);
  }
});
test('registration consumer cannot create an intent for canceled preparation', async () => {
  const h = harness(); h.row.status = 'canceled';
  assert.equal((await h.consumer.consume(attempt.id)).state, 'not_authorized');
  assert.deepEqual(h.calls, []);
});
test('registration consumer lost creation restarts with same key and immutable processor identity', async () => {
  const h = harness({ lostCreate: true });
  await assert.rejects(h.consumer.consume(attempt.id), /create response lost/);
  assert.equal(h.row.pay_requested_at, null);
  assert.equal(h.row.stripe_payment_intent_id, null);
  await h.consumer.consume(attempt.id);
  assert.equal(h.row.stripe_payment_intent_id, intent.id);
  assert.equal(h.calls.filter(x => x === 'confirm').length, 1);
  assert.equal(h.calls.filter(x => x === 'create').length, 2);
});
test('registration consumer lost binding reloads durable identity without another create', async () => {
  const h = harness({ lostBind: true });
  await assert.rejects(h.consumer.consume(attempt.id), /bind response lost/);
  assert.equal(h.row.stripe_payment_intent_id, intent.id);
  assert.equal(h.row.pay_requested_at, null);
  await h.consumer.consume(attempt.id);
  assert.deepEqual(h.calls, ['create', 'bind', 'retrieve', 'authorize', 'confirm']);
});
test('registration consumer racing consumers only the marker winner confirms', async () => {
  const h = harness();
  await Promise.all([h.consumer.consume(attempt.id), h.consumer.consume(attempt.id)]);
  assert.equal(h.calls.filter(x => x === 'confirm').length, 1);
  assert.ok(h.row.pay_requested_at);
});
test('registration consumer lost observation retries evidence read without resending payment', async () => {
  const h = harness({ lostObserve: true });
  await assert.rejects(h.consumer.consume(attempt.id), /observation response lost/);
  await h.consumer.consume(attempt.id);
  assert.equal(h.calls.filter(x => x === 'confirm').length, 1);
  assert.equal(h.observations.length, 2);
  assert.equal(h.observations[1].paymentIntentId, intent.id);
});
test('registration consumer Q38-22 returns authoritative terminal evidence despite an older processor snapshot', async () => {
  for (const terminal of ['processor_succeeded', 'processor_canceled']) {
    for (const stale of ['processing', 'requires_action']) {
      const h = harness({ marked: true }); h.row.processor_state = terminal; h.processor.status = stale;
      const result = await h.consumer.consume(attempt.id);
      assert.equal(result.state, terminal); assert.equal(result.paymentIntentId, intent.id);
      assert.deepEqual(h.calls, ['retrieve']); assert.equal(Object.hasOwn(result, 'allocated_cents'), false);
    }
  }
});

test('registration payment evidence rejects foreign, live and incomplete identities', () => {
  for (const delta of [{ id: 'pi_other' }, { livemode: true }, { currency: 'usd' },
    { amount: 1999 }, { customer: 'cus_other' }, { payment_method: 'pm_other' }, { metadata: {} }])
    assert.throws(() => registrationPaymentEvidence(attempt, { ...intent, ...delta }), /payment_mismatch/);
  for (const delta of [{ stripe_payment_intent_id: null }, { pay_requested_at: null }, { gross_cents: 1999 }])
    assert.throws(() => registrationPaymentEvidence({ ...attempt, ...delta }, intent), /payment_mismatch/);
});
test('registration payment evidence keeps nonfinal and unknown processor states unresolved', () => {
  for (const status of ['processing', 'requires_confirmation', 'requires_capture', 'requires_payment_method', 'unknown', null])
    assert.equal(registrationPaymentEvidence(attempt, { ...intent, status, last_payment_error: { message: 'synthetic' } }).state, 'unresolved');
});
test('registration payment evidence separates bank action, cancellation and processor success from impact', () => {
  assert.equal(registrationPaymentEvidence(attempt, { ...intent, status: 'requires_action' }).state, 'requires_action');
  assert.equal(registrationPaymentEvidence(attempt, { ...intent, status: 'canceled' }).state, 'processor_canceled');
  const paid = { ...intent, status: 'succeeded', amount_received: 2000, latest_charge: { id: 'ch_synthetic' },
    customer: { id: attempt.customer_id }, payment_method: { id: attempt.payment_method_id } };
  assert.equal(registrationPaymentEvidence(attempt, paid).state, 'processor_succeeded');
  for (const delta of [{ amount_received: 1999 }, { latest_charge: null }])
    assert.throws(() => registrationPaymentEvidence(attempt, { ...paid, ...delta }), /payment_mismatch/);
  assert.equal(JSON.stringify(registrationPaymentEvidence(attempt, paid)).includes('cus_'), false);
});
