import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { guardianRegistrationWorker } from '../../supabase/functions/_shared/guardian-registration-worker.mjs';
import { guardianService } from '../../supabase/functions/_shared/guardian-service.mjs';
import { registrationPaymentReply } from '../../supabase/functions/_shared/guardian-registration-rpc.mjs';

const attemptId = '81000000-0000-4000-8000-000000000001';
const cycleId = '81000000-0000-4000-8000-000000000002';
const eventId = 'evt_RegistrationTest';
const piId = 'pi_RegistrationTest';
const fixture = () => ({ id: attemptId, reservation_id: cycleId, owner_id: 'synthetic-owner',
  status: 'prepared', stripe_payment_intent_id: piId, pay_requested_at: '2026-10-15T10:00:00Z',
  gross_cents: 2000, customer_id: 'cus_RegistrationTest', payment_method_id: 'pm_RegistrationTest',
  processor_state: 'unresolved', settlement: null, resolved_at: null });
const paid = () => ({ id: piId, status: 'succeeded', livemode: false, currency: 'mxn', amount: 2000,
  amount_received: 2000, customer: 'cus_RegistrationTest', payment_method: 'pm_RegistrationTest',
  metadata: { guardian_registration_attempt_id: attemptId }, capture_method: 'automatic',
  latest_charge: { id: 'ch_RegistrationTest', livemode: false, payment_intent: piId,
    customer: 'cus_RegistrationTest', currency: 'mxn', amount: 2000, paid: true, captured: true,
    disputed: false, refunded: false, amount_refunded: 0,
    balance_transaction: { id: 'txn_RegistrationTest', source: 'ch_RegistrationTest', currency: 'mxn',
      amount: 2000, fee: 100, net: 1900 } } });

function harness({ row = fixture(), intent = paid(), event = {}, readError = null } = {}) {
  const calls = [], state = { row, intent };
  const snapshot = { id: piId, metadata: { guardian_registration_attempt_id: attemptId } };
  const stripe = { events: { retrieve: async id => { calls.push(['event', id]);
    return { id: eventId, livemode: false, type: 'payment_intent.succeeded', data: { object: snapshot }, ...event }; } },
    paymentIntents: { retrieve: async id => { calls.push(['intent', id]); return structuredClone(state.intent); },
      create: () => assert.fail('webhook cannot create payment'),
      confirm: () => assert.fail('webhook cannot confirm payment'),
      cancel: () => assert.fail('terminal webhook cannot cancel another payment') } };
  const worker = guardianRegistrationWorker({ stripe,
    paymentRpc: async (op, data) => {
      calls.push([op, data.id]);
      assert.ok(['get', 'observe'].includes(op), 'webhook cannot discover global candidates');
      if (readError) throw readError;
      if (!state.row || data.id !== state.row.id) return null;
      if (op === 'observe') {
        assert.equal(data.payment_intent_id, state.row.stripe_payment_intent_id);
        state.row.processor_state = data.state;
      }
      return structuredClone(state.row);
    },
    bind: () => assert.fail('webhook cannot bind new payment'),
    authorize: () => assert.fail('webhook cannot authorize new payment'),
    settle: async evidence => { calls.push(['settle', evidence.registration_attempt_id]);
      assert.equal(evidence.registration_attempt_id, attemptId); assert.equal(evidence.payment_intent_id, piId);
      state.row.settlement = { cycle_id: cycleId, registration_attempt_id: attemptId, payment_intent_id: piId }; },
    resolve: async id => { calls.push(['resolve', id]); state.row.resolved_at = '2026-10-15T10:01:00Z'; },
  });
  return { worker, state, calls };
}

test('native registration webhook finalizes only its already marked bound attempt and duplicate preserves cycle', async () => {
  const { worker, state, calls } = harness();
  assert.deepEqual(await worker.handleWebhook(eventId), { received: true, guardian_registration: true,
    observed: 1, finalized: 1, cycleId });
  assert.equal(state.row.processor_state, 'processor_succeeded'); assert.ok(state.row.resolved_at);
  assert.deepEqual(await worker.handleWebhook(eventId), { received: true, guardian_registration: true,
    observed: 0, finalized: 0, cycleId });
  assert.equal(calls.filter(([op]) => op === 'settle').length, 1);
  assert.equal(calls.filter(([op]) => op === 'resolve').length, 1);
});

test('native registration canceled webhook resolves same marked attempt without delivery jobs', async () => {
  const { worker, state, calls } = harness({ event: { type: 'payment_intent.canceled' },
    intent: { ...paid(), status: 'canceled', amount_received: 0, latest_charge: null, payment_method: null } });
  assert.deepEqual(await worker.handleWebhook(eventId), { received: true, guardian_registration: true,
    observed: 1, finalized: 1, cycleId: null });
  assert.equal(state.row.processor_state, 'processor_canceled'); assert.ok(state.row.resolved_at);
  assert.equal(calls.some(([op]) => op === 'settle'), false);
});

test('native registration webhook uses fresh PI instead of stale succeeded event snapshot', async () => {
  const { worker, state, calls } = harness({ intent: { ...paid(), status: 'processing', amount_received: 0 } });
  assert.deepEqual(await worker.handleWebhook(eventId), { received: true, guardian_registration: true,
    observed: 1, finalized: 0, cycleId: null });
  assert.equal(state.row.processor_state, 'unresolved'); assert.equal(state.row.resolved_at, null);
  assert.equal(calls.some(([op]) => ['settle', 'resolve'].includes(op)), false);
});

test('native registration webhook ignores foreign PI even with forged valid attempt metadata', async () => {
  const { worker, calls } = harness({ event: { data: { object: { id: 'pi_ForeignTest',
    metadata: { guardian_registration_attempt_id: attemptId } } } } });
  assert.equal(await worker.handleWebhook(eventId), null);
  assert.deepEqual(calls, [['event', eventId], ['get', attemptId]]);
});

test('native registration webhook cannot turn unmarked prepared binding into permission to charge', async () => {
  const { worker, calls } = harness({ row: { ...fixture(), pay_requested_at: null } });
  assert.equal(await worker.handleWebhook(eventId), null);
  assert.equal(calls.some(([op]) => ['intent', 'observe', 'settle', 'resolve'].includes(op)), false);
});

test('native registration webhook ignores absent or malformed hint without DB lookup', async () => {
  for (const metadata of [{}, { guardian_registration_attempt_id: 'not-a-uuid' }]) {
    const { worker, calls } = harness({ event: { data: { object: { id: piId, metadata } } } });
    assert.equal(await worker.handleWebhook(eventId), null);
    assert.deepEqual(calls, [['event', eventId]]);
  }
});

test('native registration webhook ignores nonexistent valid UUID and does not hide DB failures', async () => {
  assert.equal(await harness({ row: null }).worker.handleWebhook(eventId), null);
  await assert.rejects(harness({ readError: new Error('database unavailable') }).worker.handleWebhook(eventId), /database unavailable/);
});

test('registration RPC returns absence only for its exact SQL get exception, not permission failure', async () => {
  const absent = { error: { code: '42501', message: 'Intento no disponible' }, data: null };
  assert.equal(registrationPaymentReply('get', absent), null);
  const row = fixture();
  assert.equal(registrationPaymentReply('get', { error: null, data: row }), row);
  for (const [operation, error] of [
    ['get', { code: '42501', message: 'permission denied for function dopmi_guardian_registration_payment_server' }],
    ['get', { code: '42501', message: 'new row violates row-level security policy' }],
    ['get', { code: '42501', message: 'Intento no disponible ' }],
    ['get', { code: '08006', message: 'connection failure' }],
    ['observe', absent.error],
  ]) {
    assert.throws(() => registrationPaymentReply(operation, { error, data: null }),
      error => error.code === 'guardian_database_unavailable' && error.status === 503);
  }
  let denied;
  try { registrationPaymentReply('get', { error: { code: '42501', message: 'permission denied' } }); }
  catch (error) { denied = error; }
  await assert.rejects(harness({ readError: denied }).worker.handleWebhook(eventId),
    error => error.code === 'guardian_database_unavailable' && error.status === 503);
});

test('native registration webhook rejects LIVE, mismatched event identity and invalid event id before writes', async () => {
  for (const event of [{ livemode: true }, { id: 'evt_Foreign' }]) {
    const { worker, calls } = harness({ event });
    await assert.rejects(worker.handleWebhook(eventId), /guardian_event_invalid/);
    assert.deepEqual(calls, [['event', eventId]]);
  }
  const { worker, calls } = harness();
  await assert.rejects(worker.handleWebhook('invalid'), /guardian_event_invalid/);
  assert.deepEqual(calls, []);
});

test('native registration webhook rejects fresh foreign/live/customer/amount/method identity without writes', async () => {
  for (const delta of [{ id: 'pi_Foreign' }, { livemode: true }, { customer: 'cus_Foreign' },
    { amount: 3000 }, { payment_method: 'pm_Foreign' }, { metadata: {} }]) {
    const { worker, calls } = harness({ intent: { ...paid(), ...delta } });
    await assert.rejects(worker.handleWebhook(eventId), /guardian_registration_payment_mismatch/);
    assert.equal(calls.some(([op]) => ['observe', 'settle', 'resolve'].includes(op)), false);
  }
});

test('native registration webhook rejects contradictory terminal evidence and foreign settlement scope', async () => {
  const canceled = { ...fixture(), processor_state: 'processor_canceled', resolved_at: 'synthetic' };
  await assert.rejects(harness({ row: canceled }).worker.handleWebhook(eventId), /guardian_registration_payment_mismatch/);
  const settled = { ...fixture(), processor_state: 'processor_succeeded', resolved_at: 'synthetic',
    settlement: { cycle_id: '81000000-0000-4000-8000-000000000003', registration_attempt_id: attemptId, payment_intent_id: piId } };
  await assert.rejects(harness({ row: settled }).worker.handleWebhook(eventId), /guardian_registration_settlement_mismatch/);
});

test('native registration webhook leaves unrelated types to their existing handlers', async () => {
  const { worker, calls } = harness({ event: { type: 'setup_intent.succeeded' } });
  assert.equal(await worker.handleWebhook(eventId), null); assert.deepEqual(calls, [['event', eventId]]);
});

test('native registration result drains only DB cycle jobs through existing settlement worker', async () => {
  const { worker } = harness(); const handled = await worker.handleWebhook(eventId);
  const foreignCycle = '81000000-0000-4000-8000-000000000003';
  const jobs = [{ id: 'own-job', cycle_id: cycleId, expense_id: 'own-expense', kind: 'transfer', job_key: 'own-key', lease: 'own-lease' },
    { id: 'foreign-job', cycle_id: foreignCycle, expense_id: 'foreign-expense', kind: 'transfer' }];
  let transferred = 0; const claims = [];
  const service = guardianService({ stripe: {
    charges: { retrieve: async () => ({ ...paid().latest_charge, balance_transaction: undefined }) },
    accounts: { retrieve: async id => ({ id, capabilities: { transfers: 'active' }, payouts_enabled: true }) },
    transfers: { create: async (params, options) => { transferred++; assert.equal(options.idempotencyKey, 'own-key');
      return { ...params, id: 'tr_RegistrationTest', livemode: false, reversed: false, amount_reversed: 0 }; } },
  }, rpc: async (op, data) => {
    if (op === 'claim') { claims.push(data); assert.equal(data.cycle_id, cycleId);
      const index = jobs.findIndex(job => job.cycle_id === data.cycle_id); return index < 0 ? null : jobs.splice(index, 1)[0]; }
    if (op === 'get') { assert.equal(data.cycle_id, cycleId); return { charge_id: 'ch_RegistrationTest',
      payment_intent_id: piId, gross_cents: 2000, refund_cents: 0,
      allocations: [{ expense_id: 'own-expense', rescuer_id: 'rescuer', amount_cents: 1860, destination: 'acct_Test' }] }; }
    if (op === 'destination') return { owner_id: 'rescuer', account_id: 'acct_Test', payable: true };
    if (op === 'finish') { assert.equal(data.job_id, 'own-job'); return {}; }
    assert.fail(`unexpected operation ${op}`);
  } });
  assert.deepEqual(await service.work(10, handled.cycleId), { processed: 1, failed: 0 });
  assert.equal(transferred, 1); assert.equal(jobs.length, 1); assert.equal(jobs[0].cycle_id, foreignCycle);
  assert.equal(claims.length, 2);
});

test('native registration HTTP wiring never uses global work or collection admission for its event', async () => {
  const source = await readFile(new URL('../../supabase/functions/stripe-webhook/index.ts', import.meta.url), 'utf8');
  const branch = source.slice(source.indexOf('const registrationEvent'), source.indexOf("if (Deno.env.get('DOPMI_GUARDIAN_REFUNDS_ENABLED')"));
  assert.match(branch, /registrationPayments\.handleWebhook\(event\.id\)/);
  assert.match(branch, /guardian\.work\(10, registrationEvent\.cycleId\)/);
  assert.doesNotMatch(branch, /guardian\.work\(\)|COLLECTION_ENABLED|\.reconcile\(/);
});
