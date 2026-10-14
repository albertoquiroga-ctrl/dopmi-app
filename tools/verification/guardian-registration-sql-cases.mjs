import { test } from 'node:test';
import assert from 'node:assert/strict';
import { guardianRegistrationEvaluation } from '../../supabase/functions/_shared/guardian-registration-calendar.mjs';
import { guardianRegistrationWorker } from '../../supabase/functions/_shared/guardian-registration-worker.mjs';

export function registerGuardianRegistrationSqlCases(getDb, { donor, other, staff, key }) {
  const rpc = async (operation, data) => (await getDb().query(
    'select public.dopmi_guardian_registration_server($1,$2::jsonb) value',
    [operation, JSON.stringify({ owner_id: donor, ...data })])).rows[0].value;
  const prepare = (data = {}) => rpc('prepare', { key, gross_cents: 2000, consent: true,
    consent_version: 'guardian-registration-2026-10-14', ...data });
  const reject = async (fn, pattern) => {
    await getDb().exec('savepoint registration_negative');
    await assert.rejects(fn, pattern);
    await getDb().exec('rollback to savepoint registration_negative');
  };
  const role = async (actor, name = 'authenticated') => {
    await getDb().exec('reset role');
    await getDb().query("select set_config('request.jwt.claim.sub',$1,true)", [actor]);
    await getDb().exec(`set local role ${name}`);
  };
  const ready = async (extra = {}) => {
    const db = getDb(); const r = await prepare(extra);
    const wallet = (await db.query('insert into private.dopmi_saved_card_customers(owner_id,stripe_customer_id) values($1,$2) returning id',
      [donor, 'cus_evaluation'])).rows[0].id;
    const job = (await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,return_url)
      values($1,$2,$3,'saved-cards-2026-10-03','cus_evaluation','https://example.test/return') returning id`,
      [donor, r.id, wallet])).rows[0].id;
    await db.query("update private.dopmi_saved_card_jobs set status='saved',session_id='cs_test_evaluation',setup_intent_id='seti_evaluation',payment_method_id='pm_evaluation' where id=$1", [job]);
    return rpc('reconcile_method', { id: r.id });
  };
  const evaluate = async id => (await getDb().query('select public.dopmi_guardian_registration_evaluate($1) value', [id])).rows[0].value;
  const attemptRpc = async (operation, data = {}) => (await getDb().query(
    'select public.dopmi_guardian_registration_attempt_server($1,$2::jsonb) value',
    [operation, JSON.stringify(data)])).rows[0].value;
  const authorize = async id => (await getDb().query(
    'select public.dopmi_guardian_registration_authorize_payment($1) value', [id])).rows[0].value;
  const bind = async (id, processor) => (await getDb().query(
    'select public.dopmi_guardian_registration_bind_payment($1,$2) value', [id, processor])).rows[0].value;
  const payment = async (operation, data = {}) => (await getDb().query(
    'select public.dopmi_guardian_registration_payment_server($1,$2::jsonb) value',
    [operation, JSON.stringify(data)])).rows[0].value;
  const settlement = async data => (await getDb().query(
    "select public.dopmi_guardian_settlement_server('settle_registration',$1::jsonb) value", [JSON.stringify(data)])).rows[0].value;
  const resolve = async id => (await getDb().query(
    'select public.dopmi_guardian_registration_resolve_payment($1) value', [id])).rows[0].value;
  const paidAttempt = async () => {
    const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1'); await authorize(a.id);
    await payment('observe', { id: a.id, payment_intent_id: 'pi_registration1', state: 'processor_succeeded' });
    return { r, a, data: { registration_attempt_id: a.id, donor_id: donor, customer_id: a.customer_id,
      payment_method_id: a.payment_method_id, payment_intent_id: 'pi_registration1', charge_id: 'ch_registration1',
      gross_cents: 2000, platform_fee_cents: 40, stripe_fee_cents: 100, net_cents: 1860 } };
  };
  const projection = async () => (await getDb().query('select public.dopmi_guardian_registration_state() value')).rows[0].value;
  const bank = async (r, a, owner = donor) => (await getDb().query(
    'select public.dopmi_guardian_registration_bank_action($1,$2,$3) value', [owner,r,a])).rows[0].value;
  const bankAttempt = async () => {
    const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1'); await authorize(a.id);
    await payment('observe', { id: a.id, payment_intent_id: 'pi_registration1', state: 'requires_action' });
    return { r, a };
  };
  test('registration bank gate: same immutable marked attempt, no renewed reservation or send marker', async () => {
    const { r, a } = await bankAttempt(); const first = await bank(r.id,a.id); const replay = await bank(r.id,a.id);
    assert.equal(first.id,a.id); assert.equal(first.stripe_payment_intent_id,'pi_registration1');
    assert.equal(first.expires_at,a.expires_at); assert.equal(replay.pay_requested_at,first.pay_requested_at);
    assert.equal(replay.expires_at,first.expires_at);
  });
  test('registration bank gate: foreign owner, canceled registration and client roles cannot release action', async () => {
    const db = getDb(); const { r, a } = await bankAttempt();
    await reject(() => bank(r.id,a.id,other), /Registro no disponible/);
    for (const actor of [donor,other,staff,'']) {
      await role(actor,actor?'authenticated':'anon'); await reject(() => bank(r.id,a.id), /permission denied/);
    }
    await db.exec('reset role'); await rpc('cancel',{id:r.id});
    await reject(() => bank(r.id,a.id), /Registro no disponible/);
  });
  test('registration bank gate: original attempt and actual reservation TTL independently enforced', async () => {
    const db = getDb(); const { r, a } = await bankAttempt(); await db.exec('savepoint bank_ttl');
    await db.query("update private.dopmi_guardian_registration_attempts set expires_at=clock_timestamp()+interval '1 minute' where id=$1",[a.id]);
    await reject(() => bank(r.id,a.id), /Acción bancaria no disponible/); await db.exec('rollback to savepoint bank_ttl');
    await db.query("update private.dopmi_guardian_cycles set expires_at=clock_timestamp()+interval '1 minute' where id=$1",[a.reservation_id]);
    await reject(() => bank(r.id,a.id), /Reserva no vigente/);
  });
  test('registration bank gate: lost capacity refuses action without releasing uncertain funds', async () => {
    const db = getDb(); const { r, a } = await bankAttempt();
    await db.exec("update public.dopmi_rescue_records set reimbursable_cents=1000 where kind='expense'");
    await reject(() => bank(r.id,a.id), /Reserva no vigente/);
    assert.equal((await db.query('select status from private.dopmi_guardian_cycles where id=$1',[a.reservation_id])).rows[0].status,'reserved');
  });
  test('registration projection: owner allowlist hides method, processor and other private identities', async () => {
    const db = getDb(); await ready();
    await role(donor); const own = await projection(); assert.equal(own.status, 'registered');
    assert.equal(own.payment.state, 'not_evaluated');
    for (const hidden of ['owner_id','method_job_id','customer_id','payment_method_id','stripe_payment_intent_id','pay_requested_at','client_secret'])
      assert.equal(JSON.stringify(own).includes(hidden), false);
    for (const actor of [other, staff]) { await role(actor); assert.equal(await projection(), null); }
    await role('', 'anon'); await reject(() => projection(), /permission denied/);
    await db.exec('reset role');
  });
  test('registration projection: processor success is not allocation, refund fallback is not impact', async () => {
    const db = getDb(); const { a, data } = await paidAttempt();
    await role(donor); let result = await projection();
    assert.equal(result.payment.state, 'processor_confirmed'); assert.equal(result.payment.allocated_cents, 0);
    await db.exec('reset role');
    await db.exec('savepoint allocated_branch'); await settlement(data);
    await role(donor); result = await projection();
    assert.equal(result.payment.state, 'allocated'); assert.equal(Number(result.payment.allocated_cents), 1860);
    await db.exec('reset role'); await db.exec('rollback to savepoint allocated_branch');
    await db.query("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 second' where id=$1", [a.reservation_id]);
    await settlement(data); await role(donor); result = await projection();
    assert.equal(result.payment.state, 'refund_pending'); assert.equal(result.payment.allocated_cents, 0);
    assert.equal(Number(result.payment.refund_cents), 2000);
  });
  test('registration projection: canceled enrollment preserves uncertainty and hides future evaluation', async () => {
    const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1'); await authorize(a.id); await rpc('cancel', { id: r.id });
    await role(donor); const result = await projection();
    assert.equal(result.status, 'canceled'); assert.equal(result.next_evaluation_at, null);
    assert.equal(result.payment.state, 'processing'); assert.equal(result.payment.attempt_id, a.id);
  });
  test('registration projection: next anniversary stays future after several omitted intervals', async () => {
    const db = getDb(); const r = await ready();
    await db.query("update private.dopmi_guardian_registrations set registered_at=date_trunc('second',now()-interval '3 months') where id=$1", [r.id]);
    await role(donor); const result = await projection();
    assert.ok(Date.parse(result.next_evaluation_at)>Date.now());
    assert.equal(result.payment.state, 'not_evaluated');
  });
  test('registration worker integration: real SQL ports bind authorize observe settle resolve once', async () => {
    const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    let processor, created = 0, confirmed = 0;
    const worker = guardianRegistrationWorker({ paymentRpc: payment, bind, authorize, resolve, settle: settlement,
      stripe: { paymentIntents: {
        create: async (params, options) => {
          created++; assert.equal(params.confirm, false);
          assert.equal(options.idempotencyKey, `guardian-registration-create:${a.id}`);
          processor = { ...params, id: 'pi_integrated', livemode: false, status: 'requires_confirmation', capture_method: 'automatic' };
          return processor;
        },
        confirm: async (id, params, options) => {
          confirmed++; const stored = await payment('get', { id: a.id });
          assert.ok(stored.pay_requested_at); assert.equal(stored.stripe_payment_intent_id, id);
          assert.equal(options.idempotencyKey, `guardian-registration:${a.id}`);
          assert.equal(params.off_session, true);
          processor = { ...processor, status: 'succeeded', amount_received: 2000,
            latest_charge: { id: 'ch_integrated', livemode: false, payment_intent: id,
              customer: a.customer_id, currency: 'mxn', amount: 2000, paid: true, captured: true,
              disputed: false, refunded: false, amount_refunded: 0,
              balance_transaction: { id: 'txn_integrated', source: 'ch_integrated', currency: 'mxn', amount: 2000, fee: 100, net: 1900 } } };
          return processor;
        },
        retrieve: async id => { assert.equal(id, 'pi_integrated'); return processor; },
      } },
    });
    assert.deepEqual(await worker.reconcile({ allowNewPayments: true }), { observed: 1, finalized: 1, failed: 0 });
    const stored = await payment('get', { id: a.id });
    assert.ok(stored.resolved_at); assert.equal(stored.settlement.status, 'allocated');
    assert.equal(Number(stored.settlement.allocated_cents), 1860);
    assert.deepEqual(await worker.reconcile({ allowNewPayments: true }), { observed: 0, finalized: 0, failed: 0 });
    assert.equal(created, 1); assert.equal(confirmed, 1);
  });
  test('registration resolution: paid evidence requires settlement, replay preserves cycle until anniversary', async () => {
    const db = getDb(); const { r, a, data } = await paidAttempt();
    assert.ok((await payment('finalization_candidates')).some(row => row.id === a.id));
    await reject(() => resolve(a.id), /Liquidación pendiente/);
    await settlement(data);
    assert.equal((await payment('get', { id: a.id })).settlement.registration_attempt_id, a.id);
    const resolved = await resolve(a.id); assert.ok(resolved.resolved_at);
    assert.deepEqual(await resolve(a.id), resolved);
    assert.ok(!(await payment('finalization_candidates')).some(row => row.id === a.id));
    assert.equal((await attemptRpc('prepare', { id: r.id })).id, a.id);
    assert.equal(await authorize(a.id), null);
    await db.query("update private.dopmi_guardian_registrations set registered_at=date_trunc('second',now()-interval '1 month') where id=$1", [r.id]);
    await db.query("update private.dopmi_guardian_registration_evaluations set next_evaluation_at=now()-interval '1 second' where id=$1", [a.evaluation_id]);
    const next = await attemptRpc('prepare', { id: r.id });
    assert.notEqual(next.id, a.id); assert.equal(next.pay_requested_at, null);
    assert.notEqual(next.reservation_id, a.reservation_id);
    assert.equal((await attemptRpc('prepare', { id: r.id })).id, next.id);
  });
  test('registration resolution: confirmed cancellation releases hold without same-cycle recollection', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1'); await authorize(a.id);
    await reject(() => resolve(a.id), /Confirmación pendiente/);
    await payment('observe', { id: a.id, payment_intent_id: 'pi_registration1', state: 'processor_canceled' });
    const result = await resolve(a.id); assert.ok(result.resolved_at); assert.equal(result.status, 'canceled');
    assert.equal((await db.query('select status from private.dopmi_guardian_cycles where id=$1', [a.reservation_id])).rows[0].status, 'released');
    assert.equal((await attemptRpc('prepare', { id: r.id })).id, a.id);
    assert.equal(await authorize(a.id), null);
    assert.deepEqual(await resolve(a.id), result);
  });
  test('registration resolution: uncertain marker blocks a later cycle and client roles cannot resolve', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1'); await authorize(a.id);
    await db.query("update private.dopmi_guardian_registrations set registered_at=now()-interval '2 months' where id=$1", [r.id]);
    assert.equal((await attemptRpc('prepare', { id: r.id })).id, a.id);
    for (const actor of [donor, other, staff, '']) {
      await role(actor, actor ? 'authenticated' : 'anon');
      await reject(() => resolve(a.id), /permission denied/);
    }
  });
  test('registration settlement: actual net all assigned, source binding and replay create one job', async () => {
    const db = getDb(); const { a, data } = await paidAttempt();
    const result = await settlement(data);
    assert.equal(result.registration_attempt_id, a.id); assert.equal(result.status, 'allocated');
    assert.equal(Number(result.allocated_cents), 1860); assert.equal(Number(result.refund_cents), 0);
    assert.equal(Number(result.platform_fee_cents), 40); assert.equal(Number(result.stripe_fee_cents), 100);
    assert.deepEqual(await settlement(data), result);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_jobs where cycle_id=$1', [a.reservation_id])).rows[0].n, 1);
    await reject(() => settlement({ ...data, stripe_fee_cents: 101, net_cents: 1859 }), /otra evidencia/);
  });
  test('registration settlement: expired capacity prepares full refund with no partial allocation', async () => {
    const db = getDb(); const { a, data } = await paidAttempt();
    await db.query("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 second' where id=$1", [a.reservation_id]);
    const result = await settlement(data);
    assert.equal(result.status, 'refund_pending'); assert.equal(Number(result.allocated_cents), 0);
    assert.equal(Number(result.refund_cents), 2000); assert.equal(Number(result.platform_loss_cents), 100);
    const jobs = (await db.query('select kind from private.dopmi_guardian_jobs where cycle_id=$1', [a.reservation_id])).rows;
    assert.deepEqual(jobs.map(j => j.kind), ['refund']);
    assert.deepEqual(await settlement(data), result);
  });
  test('registration settlement: source identity, marker and observed success mandatory, clients denied', async () => {
    const db = getDb(); const { a, data } = await paidAttempt();
    for (const delta of [{ donor_id: other }, { payment_intent_id: 'pi_foreign' }, { customer_id: 'cus_other' },
      { payment_method_id: 'pm_other' }, { gross_cents: 2100 }, { checkout_session_id: 'cs_test_other' }, { invoice_id: 'in_other' }])
      await reject(() => settlement({ ...data, ...delta }), /no coincide/);
    await db.exec('savepoint success_state');
    await db.query("update private.dopmi_guardian_registration_attempts set processor_state='unresolved' where id=$1", [a.id]);
    await reject(() => settlement(data), /no coincide/); await db.exec('rollback to savepoint success_state');
    for (const actor of [donor, other, staff, '']) {
      await role(actor, actor ? 'authenticated' : 'anon');
      await reject(() => settlement(data), /permission denied/);
    }
  });
  test('registration settlement: cancellation after send cannot hide paid evidence', async () => {
    const { r, data } = await paidAttempt();
    await rpc('cancel', { id: r.id });
    assert.equal((await settlement(data)).status, 'allocated');
    assert.equal((await rpc('get', { id: r.id })).status, 'canceled');
  });
  test('registration observation: private lookup and discovery reject every client role', async () => {
    const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    assert.equal((await payment('get', { id: a.id })).owner_id, donor);
    assert.ok((await payment('candidates')).some(row => row.id === a.id));
    for (const actor of [donor, other, staff, '']) {
      await role(actor, actor ? 'authenticated' : 'anon');
      for (const operation of ['get', 'candidates', 'observe'])
        await reject(() => payment(operation, { id: a.id }), /permission denied/);
    }
  });
  test('registration observation: marker and exact identity required, no donation from processor success', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    const data = { id: a.id, payment_intent_id: 'pi_registration1', state: 'processor_succeeded' };
    await bind(a.id, data.payment_intent_id);
    await reject(() => payment('observe', data), /Evidencia no vinculada/);
    await authorize(a.id);
    await reject(() => payment('observe', { ...data, payment_intent_id: 'pi_wrong' }), /Evidencia no vinculada/);
    await reject(() => payment('observe', { ...data, state: 'paid' }), /Evidencia no vinculada/);
    const observed = await payment('observe', data);
    assert.equal(observed.processor_state, 'processor_succeeded');
    assert.ok(observed.processor_checked_at);
    assert.equal((await db.query('select count(*)::int n from public.dopmi_donations')).rows[0].n, 0);
    assert.equal((await db.query('select status from private.dopmi_guardian_cycles where id=$1', [a.reservation_id])).rows[0].status, 'reserved');
  });
  test('registration observation: terminal evidence survives replay and out of order updates', async () => {
    const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1'); await authorize(a.id);
    const data = { id: a.id, payment_intent_id: 'pi_registration1' };
    await payment('observe', { ...data, state: 'requires_action' });
    const terminal = await payment('observe', { ...data, state: 'processor_succeeded' });
    for (const state of ['unresolved', 'requires_action', 'processor_succeeded']) {
      const replay = await payment('observe', { ...data, state });
      assert.equal(replay.processor_state, 'processor_succeeded');
      assert.equal(replay.processor_checked_at, terminal.processor_checked_at);
    }
    await reject(() => payment('observe', { ...data, state: 'processor_canceled' }), /Evidencia contradictoria/);
    assert.ok(!(await payment('candidates')).some(row => row.id === a.id));
  });
  test('registration observation: canceled registration with uncertain marker remains discoverable after TTL', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1'); await authorize(a.id); await rpc('cancel', { id: r.id });
    await db.query("update private.dopmi_guardian_registration_attempts set expires_at=now()-interval '1 second' where id=$1", [a.id]);
    assert.ok((await payment('candidates')).some(row => row.id === a.id));
    await payment('observe', { id: a.id, payment_intent_id: 'pi_registration1', state: 'processor_canceled' });
    assert.ok(!(await payment('candidates')).some(row => row.id === a.id));
  });
  test('registration payment identity: immutable replay, no marker, private server-only binding', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    const bound = await bind(a.id, 'pi_registration1');
    assert.equal(bound.stripe_payment_intent_id, 'pi_registration1');
    assert.equal(bound.pay_requested_at, null);
    assert.equal((await bind(a.id, 'pi_registration1')).id, a.id);
    await reject(() => bind(a.id, 'pi_registration2'), /inmutable/);
    await reject(() => bind(a.id, 'invalid'), /inválida/);
    for (const actor of [donor, other, staff, '']) {
      await role(actor, actor ? 'authenticated' : 'anon');
      await reject(() => bind(a.id, 'pi_registration1'), /permission denied/);
    }
    await db.exec('reset role');
    assert.equal((await db.query('select count(*)::int n from public.dopmi_donations')).rows[0].n, 0);
  });
  test('registration payment identity: cancellation and expired or already marked attempts reject new binding', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await db.exec('savepoint valid_binding');
    await db.query("update private.dopmi_guardian_registration_attempts set expires_at=now()-interval '1 second' where id=$1", [a.id]);
    await reject(() => bind(a.id, 'pi_registration1'), /Intento no disponible/);
    await db.exec('rollback to savepoint valid_binding');
    await db.exec('savepoint before_marker');
    // Binding is now mandatory before authorization. Direct table mutation
    // models an old in-flight row, not a way exposed to the client.
    await db.query('update private.dopmi_guardian_registration_attempts set pay_requested_at=now() where id=$1', [a.id]);
    await reject(() => bind(a.id, 'pi_registration1'), /Intento no disponible/);
    await db.exec('rollback to savepoint before_marker');
    await rpc('cancel', { id: r.id });
    await reject(() => bind(a.id, 'pi_registration1'), /Intento no disponible/);
    assert.equal((await db.query('select stripe_payment_intent_id from private.dopmi_guardian_registration_attempts where id=$1', [a.id])).rows[0].stripe_payment_intent_id, null);
  });
  test('registration payment identity: cancellation preserves a bound identity for reconciliation only', async () => {
    const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1');
    await rpc('cancel', { id: r.id });
    assert.equal((await bind(a.id, 'pi_registration1')).status, 'canceled');
    assert.equal(await authorize(a.id), null);
    await reject(() => bind(a.id, 'pi_registration2'), /inmutable/);
  });
  test('registration authorization: one durable marker, same identity, no duplicate send permission', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    assert.equal(a.pay_requested_at, null);
    assert.equal(await authorize(a.id), null);
    assert.equal((await getDb().query('select pay_requested_at from private.dopmi_guardian_registration_attempts where id=$1', [a.id])).rows[0].pay_requested_at, null);
    await bind(a.id, 'pi_registration1');
    const permitted = await authorize(a.id);
    assert.equal(permitted.stripe_payment_intent_id, 'pi_registration1');
    assert.equal(permitted.id, a.id); assert.equal(permitted.gross_cents, a.gross_cents);
    assert.equal(permitted.payment_key, `guardian-registration:${a.id}`);
    assert.ok(permitted.pay_requested_at);
    assert.equal(await authorize(a.id), null);
    await db.query("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 second' where id=$1", [a.reservation_id]);
    const replay = await attemptRpc('prepare', { id: r.id });
    assert.equal(replay.pay_requested_at, permitted.pay_requested_at);
    assert.equal(replay.status, 'prepared');
    assert.equal(await authorize(a.id), null);
    assert.equal((await db.query('select count(*)::int n from public.dopmi_donations')).rows[0].n, 0);
  });
  test('registration authorization: cancellation before marker wins, after marker preserves uncertain hold', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1');
    await authorize(a.id); await rpc('cancel', { id: r.id });
    assert.equal((await rpc('get', { id: r.id })).status, 'canceled');
    assert.equal(await authorize(a.id), null);
    assert.equal((await attemptRpc('prepare', { id: r.id })).id, a.id);
    assert.equal((await db.query('select status from private.dopmi_guardian_cycles where id=$1', [a.reservation_id])).rows[0].status, 'reserved');
    assert.equal((await db.query('select status from private.dopmi_guardian_registration_evaluations where id=$1', [a.evaluation_id])).rows[0].status, 'reserved');
    await reject(() => prepare({ key: '72000000-0000-4000-8000-000000000099' }), /Registro Guardián existente/);
    await reject(() => db.query('select public.dopmi_guardian_activation_server($1,$2::jsonb)',
      ['prepare', JSON.stringify({ donor_id: donor, key, gross_cents: 2000, consent: true,
        consent_version: 'guardian-2026-09-24', return_url: 'https://example.test/return' })]), /Cobro requiere conciliación/);
  });
  test('registration authorization: canceled unmarked attempt cannot authorize', async () => {
    const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1');
    await rpc('cancel', { id: r.id }); assert.equal(await authorize(a.id), null);
  });
  test('registration authorization: short TTL and reduced capacity cannot mark a send', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1');
    await db.exec('savepoint ttl_only');
    await db.query("update private.dopmi_guardian_cycles set expires_at=clock_timestamp()+interval '1 minute' where id=$1", [a.reservation_id]);
    // The immutable attempt expiry must match the actual live reservation.
    assert.equal(await authorize(a.id), null);
    await db.exec('rollback to savepoint ttl_only');
    assert.ok(Date.parse(a.expires_at) > Date.now() + 120000);
    await db.exec('savepoint positive_control');
    assert.ok((await authorize(a.id)).pay_requested_at);
    await db.exec('rollback to savepoint positive_control');
    await db.exec("update public.dopmi_rescue_records set reimbursable_cents=1000 where kind='expense'");
    assert.equal(await authorize(a.id), null);
    assert.equal((await db.query('select pay_requested_at from private.dopmi_guardian_registration_attempts where id=$1', [a.id])).rows[0].pay_requested_at, null);
  });
  test('registration authorization: fresh account, consent, method and server-only privileges', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1');
    await db.query("update profiles set account_status='suspended' where id=$1", [donor]);
    await reject(() => authorize(a.id), /Cuenta no disponible/);
    await db.query("update profiles set account_status='active' where id=$1", [donor]);
    await reject(() => db.query("update private.dopmi_guardian_registrations set consent_version='old' where id=$1", [r.id]), /check constraint/);
    await db.query("update private.dopmi_saved_card_jobs set payment_method_id='pm_changed' where id=$1", [r.method_job_id]);
    await reject(() => authorize(a.id), /El método cambió/);
    for (const actor of [donor, other, staff, '']) {
      await role(actor, actor ? 'authenticated' : 'anon');
      await reject(() => authorize(a.id), /permission denied/);
    }
    await db.exec('reset role');
    assert.equal((await db.query('select pay_requested_at from private.dopmi_guardian_registration_attempts where id=$1', [a.id])).rows[0].pay_requested_at, null);
  });
  test('registration discovery: twenty expired uncertain owners cannot starve the twenty-first eligible owner', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await bind(a.id, 'pi_registration1'); await authorize(a.id);
    await db.query("update private.dopmi_guardian_registrations set registered_at='2025-01-01T00:00:00Z' where id=$1", [r.id]);
    await db.query("update private.dopmi_guardian_registration_evaluations set next_evaluation_at=now()-interval '1 day' where id=$1", [a.evaluation_id]);
    await db.query("update private.dopmi_guardian_registration_attempts set expires_at=now()-interval '1 day' where id=$1", [a.id]);
    for (let n=1;n<=19;n++) {
      const owner = '99000000-0000-4000-8000-' + String(n).padStart(12,'0');
      await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),'{"display_name":"Prueba","terms_accepted":true,"terms_version":"development-2026-09-13"}')`,[owner,owner+'@example.test']);
      const ids = (await db.query('select gen_random_uuid() reg,gen_random_uuid() ev,gen_random_uuid() cycle,gen_random_uuid() att')).rows[0];
      const copy = async (table, sourceId, changes) => db.query(`insert into ${table} select (jsonb_populate_record(null::${table},to_jsonb(src)||$2::jsonb)).* from ${table} src where id=$1`,[sourceId,JSON.stringify(changes)]);
      await copy('private.dopmi_guardian_registrations',r.id,{id:ids.reg,owner_id:owner,registered_at:'2025-01-01T00:00:00Z'});
      await copy('private.dopmi_guardian_cycles',a.reservation_id,{id:ids.cycle,donor_id:owner,cycle_key:ids.ev});
      await copy('private.dopmi_guardian_registration_evaluations',a.evaluation_id,{id:ids.ev,registration_id:ids.reg,reservation_id:ids.cycle});
      await copy('private.dopmi_guardian_registration_attempts',a.id,{id:ids.att,owner_id:owner,registration_id:ids.reg,evaluation_id:ids.ev,reservation_id:ids.cycle,stripe_payment_intent_id:'pi_uncertain'+n});
    }
    const target = await prepare({owner_id:other});
    const wallet = (await db.query("insert into private.dopmi_saved_card_customers(owner_id,stripe_customer_id) values($1,'cus_eligible21') returning id",[other])).rows[0].id;
    const job = (await db.query("insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,return_url) values($1,$2,$3,'saved-cards-2026-10-03','cus_eligible21','https://example.test/return') returning id",[other,target.id,wallet])).rows[0].id;
    await db.query("update private.dopmi_saved_card_jobs set status='saved',session_id='cs_test_eligible21',setup_intent_id='seti_eligible21',payment_method_id='pm_eligible21' where id=$1",[job]);
    await rpc('reconcile_method',{owner_id:other,id:target.id});
    const before = (await db.query('select id,status,expires_at,pay_requested_at,resolved_at from private.dopmi_guardian_registration_attempts order by id')).rows;
    const holds = (await db.query('select id,status,reserved_cents from private.dopmi_guardian_cycles order by id')).rows;
    const candidates = await attemptRpc('candidates');
    assert.deepEqual(candidates,[{id:target.id}]); assert.ok(candidates.length<=20);
    assert.equal(new Set((await db.query('select owner_id from private.dopmi_guardian_registrations')).rows.map(v=>v.owner_id)).size,21);
    assert.equal((await payment('candidates')).length,20);
    assert.deepEqual((await db.query('select id,status,expires_at,pay_requested_at,resolved_at from private.dopmi_guardian_registration_attempts order by id')).rows,before);
    assert.deepEqual((await db.query('select id,status,reserved_cents from private.dopmi_guardian_cycles order by id')).rows,holds);
    const progressed = await attemptRpc('prepare',{id:target.id});
    assert.equal(progressed.owner_id,other); assert.equal(progressed.status,'prepared');
    assert.equal(progressed.pay_requested_at,null);
  });
  test('registration attempt: durable identity, immutable amount and TTL, cancellation stops preparation', async () => {
    const db = getDb(); const r = await ready();
    assert.deepEqual(await attemptRpc('candidates'), [{ id: r.id }]);
    const a = await attemptRpc('prepare', { id: r.id });
    assert.equal(a.status, 'prepared'); assert.equal(a.gross_cents, 2000);
    assert.equal(a.customer_id, 'cus_evaluation'); assert.equal(a.payment_method_id, 'pm_evaluation');
    assert.deepEqual(await attemptRpc('prepare', { id: r.id }), a);
    assert.deepEqual(await attemptRpc('candidates'), []);
    await rpc('change_amount', { id: r.id, revision: r.revision, gross_cents: 5000,
      consent: true, consent_version: r.consent_version });
    assert.deepEqual(await attemptRpc('prepare', { id: r.id }), a);
    await rpc('cancel', { id: r.id });
    assert.equal(await attemptRpc('prepare', { id: r.id }), null);
    const canceled = (await db.query('select * from private.dopmi_guardian_registration_attempts')).rows[0];
    assert.equal(canceled.id, a.id); assert.equal(canceled.status, 'canceled');
    for (const table of ['private.dopmi_guardian_activations', 'private.dopmi_guardian_subscriptions', 'public.dopmi_donations'])
      assert.equal((await db.query(`select count(*)::int n from ${table}`)).rows[0].n, 0);
  });
  test('registration attempt: expired reservation never renews attempt or capacity', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await db.query("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 second' where id=$1", [a.reservation_id]);
    const expired = await attemptRpc('prepare', { id: r.id });
    assert.equal(expired.status, 'expired'); assert.equal(expired.id, a.id); assert.equal(expired.expires_at, a.expires_at);
    assert.deepEqual(await attemptRpc('prepare', { id: r.id }), expired);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_cycles')).rows[0].n, 1);
  });
  test('registration attempt: no capacity persists omission without an attempt or later recobro', async () => {
    const db = getDb(); const r = await ready({ gross_cents: 20000 });
    assert.equal(await attemptRpc('prepare', { id: r.id }), null);
    await rpc('change_amount', { id: r.id, revision: r.revision, gross_cents: 2000,
      consent: true, consent_version: r.consent_version });
    assert.equal(await attemptRpc('prepare', { id: r.id }), null);
    assert.deepEqual(await attemptRpc('candidates'), []);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_registration_attempts')).rows[0].n, 0);
  });
  test('registration attempt: changed approved capacity invalidates hold before durable preparation', async () => {
    const db = getDb(); const r = await ready(); const e = await evaluate(r.id);
    await db.exec("update public.dopmi_rescue_records set reimbursable_cents=1000 where kind='expense'");
    assert.equal(await attemptRpc('prepare', { id: r.id }), null);
    assert.equal((await db.query('select status from private.dopmi_guardian_cycles where id=$1', [e.reservation_id])).rows[0].status, 'released');
    assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_registration_attempts')).rows[0].n, 0);
  });
  test('registration attempt: account and exact setup binding revalidated on replay', async () => {
    const db = getDb(); const r = await ready(); const a = await attemptRpc('prepare', { id: r.id });
    await db.query("update profiles set account_status='suspended' where id=$1", [donor]);
    await reject(() => attemptRpc('prepare', { id: r.id }), /Cuenta no disponible/);
    await db.query("update profiles set account_status='active' where id=$1", [donor]);
    await db.query('update private.dopmi_saved_card_jobs set request_key=$1 where id=$2', [key, r.method_job_id]);
    await reject(() => attemptRpc('prepare', { id: r.id }), /Método no confirmado/);
    await db.query('update private.dopmi_saved_card_jobs set request_key=$1,payment_method_id=$2 where id=$3', [r.id, 'pm_changed', r.method_job_id]);
    await reject(() => attemptRpc('prepare', { id: r.id }), /El método cambió/);
    assert.equal((await db.query('select id from private.dopmi_guardian_registration_attempts')).rows[0].id, a.id);
  });
  test('registration attempt: RPC and private evidence forbidden to owner, other, admin and anon', async () => {
    const db = getDb(); const r = await ready(); await attemptRpc('prepare', { id: r.id });
    for (const actor of [donor, other, staff, '']) {
      await role(actor, actor ? 'authenticated' : 'anon');
      await reject(() => attemptRpc('candidates'), /permission denied/);
      await reject(() => attemptRpc('prepare', { id: r.id }), /permission denied/);
      await reject(() => db.query('select * from private.dopmi_guardian_registration_attempts'), /permission denied/);
    }
    await db.exec('reset role; set local role service_role');
    assert.deepEqual(await attemptRpc('candidates'), []);
    await reject(() => db.query('select * from private.dopmi_guardian_registration_attempts'), /permission denied/);
    await db.exec('reset role');
  });
  test('registration evaluation: method required, full upper-net reservation, stable replay and cancel release without charge', async () => {
    const db = getDb(); const pending = await prepare();
    assert.equal(await evaluate(pending.id), null);
    // Reuse the existing pending registration and its deterministic setup.
    const r = await ready(); const e = await evaluate(r.id);
    assert.equal(e.cycle_number, 0); assert.equal(e.status, 'reserved');
    const hold = (await db.query('select * from private.dopmi_guardian_cycles where id=$1', [e.reservation_id])).rows[0];
    assert.equal(Number(hold.reserved_cents), 1960); assert.equal(hold.cycle_key, e.id);
    assert.deepEqual(await evaluate(r.id), e);
    const changed = await rpc('change_amount', { id: r.id, revision: r.revision, gross_cents: 5000,
      consent: true, consent_version: r.consent_version });
    assert.equal(changed.gross_cents, 5000);
    assert.deepEqual(await evaluate(r.id), e); // new amount applies next cycle
    await rpc('cancel', { id: r.id }); assert.equal(await evaluate(r.id), null);
    assert.equal((await db.query('select status from private.dopmi_guardian_cycles where id=$1', [hold.id])).rows[0].status, 'released');
    assert.equal((await db.query('select status from private.dopmi_guardian_registration_evaluations where id=$1', [e.id])).rows[0].status, 'canceled');
    for (const table of ['private.dopmi_guardian_activations', 'private.dopmi_guardian_subscriptions', 'public.dopmi_donations'])
      assert.equal(Number((await db.query(`select count(*) n from ${table}`)).rows[0].n), 0);
  });
  test('registration evaluation: omitted cycle stays omitted after capacity returns and amount changes', async () => {
    const db = getDb(); const r = await ready({ gross_cents: 20000 });
    const e = await evaluate(r.id); assert.equal(e.status, 'skipped');
    assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_allocations')).rows[0].n, 0);
    await rpc('change_amount', { id: r.id, revision: r.revision, gross_cents: 2000, consent: true, consent_version: r.consent_version });
    assert.deepEqual(await evaluate(r.id), e);
    assert.ok(Date.parse(e.next_evaluation_at) > Date.parse(e.due_at));
    assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_cycles')).rows[0].n, 1);
  });
  test('registration evaluation: delayed worker evaluates current anniversary only, original month-end survives', async () => {
    const db = getDb(); const r = await ready();
    await db.query("update private.dopmi_guardian_registrations set registered_at=date_trunc('year',now() at time zone 'UTC') at time zone 'UTC' - interval '1 year' + interval '30 days' where id=$1", [r.id]);
    const e = await evaluate(r.id);
    assert.ok(e.cycle_number >= 11); assert.ok(Date.parse(e.due_at) <= Date.now());
    assert.ok(Date.parse(e.next_evaluation_at) > Date.now());
    assert.equal(Number((await db.query('select count(*) n from private.dopmi_guardian_registration_evaluations')).rows[0].n), 1);
    const origin = (await db.query('select registered_at from private.dopmi_guardian_registrations where id=$1', [r.id])).rows[0].registered_at;
    assert.equal(Date.parse(e.next_evaluation_at) / 1000, guardianRegistrationEvaluation(Date.parse(origin) / 1000, e.cycle_number + 1));
  });
  test('registration evaluation: expired hold never renewed, ownership and method evidence remain authoritative', async () => {
    const db = getDb(); const r = await ready(); const e = await evaluate(r.id);
    await db.query("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 second' where id=$1", [e.reservation_id]);
    const expired = await evaluate(r.id); assert.equal(expired.status, 'expired'); assert.equal(expired.id, e.id);
    assert.deepEqual(await evaluate(r.id), expired);
    await db.query("update private.dopmi_saved_card_jobs set request_key=$1 where id=$2", [key, r.method_job_id]);
    await reject(() => evaluate(r.id), /Método no confirmado/);
    for (const actor of [donor, other, staff]) {
      await role(actor); await reject(() => evaluate(r.id), /permission denied/);
      await reject(() => db.query('select * from private.dopmi_guardian_registration_evaluations'), /permission denied/);
    }
    await role('', 'anon'); await reject(() => evaluate(r.id), /permission denied/);
    await db.exec('reset role');
  });
  test('registration evaluation: competing owners cannot reserve the same full capacity', async () => {
    const db = getDb(); const r = await ready({ gross_cents: 10000 }); const e = await evaluate(r.id);
    assert.equal(e.status, 'reserved');
    const competing = (await db.query('select public.dopmi_guardian_reserve($1,$2,4000) value', [other, key])).rows[0].value;
    assert.equal(competing.status, 'skipped'); assert.equal(competing.reserved_cents, 0);
    // Existing H4 capacity reader must see this new reservation too.
    assert.equal(Number((await db.query('select sum(amount_cents) n from private.dopmi_guardian_allocations where cycle_id=$1', [e.reservation_id])).rows[0].n), 9800);
  });
  test('registration evaluation: next anniversary uses changed amount without collecting skipped month', async () => {
    const db = getDb(); const r = await ready({ gross_cents: 20000 }); const skipped = await evaluate(r.id);
    assert.equal(skipped.status, 'skipped');
    await rpc('change_amount', { id: r.id, revision: r.revision, gross_cents: 2000, consent: true, consent_version: r.consent_version });
    // Shift only the synthetic origin, emulating a clock advance across an
    // anniversary without injecting a caller-controlled date into the RPC.
    await db.query("update private.dopmi_guardian_registrations set registered_at=date_trunc('month',now())-interval '1 month' where id=$1", [r.id]);
    const next = await evaluate(r.id); assert.equal(next.cycle_number, 1); assert.equal(next.status, 'reserved');
    assert.equal(next.gross_cents, 2000); assert.notEqual(next.id, skipped.id);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_registration_evaluations')).rows[0].n, 2);
    assert.equal((await db.query('select status from private.dopmi_guardian_registration_evaluations where id=$1', [skipped.id])).rows[0].status, 'skipped');
  });
  test('registration evaluation: future anniversary and inactive owner cannot create holds', async () => {
    const db = getDb(); const r = await ready();
    await db.query("update private.dopmi_guardian_registrations set registered_at=now()+interval '1 day' where id=$1", [r.id]);
    assert.equal(await evaluate(r.id), null);
    await db.query("update profiles set account_status='suspended' where id=$1", [donor]);
    await reject(() => evaluate(r.id), /Cuenta no disponible/);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_cycles')).rows[0].n, 0);
  });
  test('registration SQL worker: discovers only confirmed exact owner setup, cancellation and ACL win', async () => {
    const db = getDb(); const r = await prepare();
    const candidates = async () => (await db.query(
      "select public.dopmi_guardian_registration_server('method_candidates','{}') value")).rows[0].value;
    assert.deepEqual(await candidates(), []);
    const wallet = (await db.query('insert into private.dopmi_saved_card_customers(owner_id,stripe_customer_id) values($1,$2) returning id',
      [donor, 'cus_workerregistration'])).rows[0].id;
    const job = (await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,return_url)
      values($1,$2,$3,'saved-cards-2026-10-03','cus_workerregistration','https://example.test/return') returning id`,
      [donor, r.id, wallet])).rows[0].id;
    assert.deepEqual(await candidates(), []);
    await db.query("update private.dopmi_saved_card_jobs set status='saved',session_id='cs_test_workerregistration',setup_intent_id='seti_workerregistration',payment_method_id='pm_workerregistration' where id=$1", [job]);
    assert.deepEqual(await candidates(), [{ id: r.id, owner_id: donor }]);
    await db.query('update private.dopmi_saved_card_jobs set owner_id=$1 where id=$2', [other, job]);
    assert.deepEqual(await candidates(), []);
    await db.query('update private.dopmi_saved_card_jobs set owner_id=$1,request_key=$2 where id=$3', [donor, key, job]);
    assert.deepEqual(await candidates(), []);
    await db.query('update private.dopmi_saved_card_jobs set request_key=$1 where id=$2', [r.id, job]);
    for (const actor of [donor, other, staff]) {
      await role(actor);
      await reject(candidates, /permission denied/);
    }
    await db.exec('reset role');
    await rpc('cancel', { id: r.id });
    assert.deepEqual(await candidates(), []);
    assert.equal((await rpc('reconcile_method', { id: r.id })).status, 'canceled');
  });
  test('registration SQL: no capacity needed, durable replay, no contribution or subscription', async () => {
    const db = getDb();
    const before = (await db.query('select count(*) n from private.dopmi_guardian_subscriptions')).rows[0].n;
    const r = await prepare();
    assert.equal(r.status, 'method_pending');
    assert.equal(r.method_job_id, null);
    assert.deepEqual(await prepare(), r);
    assert.equal((await db.query('select count(*) n from private.dopmi_guardian_subscriptions')).rows[0].n, before);
    await reject(() => prepare({ gross_cents: 5000 }), /solicitud cambió/);
    await reject(() => prepare({ key: '72000000-0000-4000-8000-000000000099' }), /existente/);
    for (const data of [{ consent: false }, { gross_cents: 1999 }, { consent_version: 'old' }])
      await reject(() => prepare(data), /Autorización/);
  });
  test('registration SQL: only owner confirmed setup can complete, repeated confirmation and cancel are safe', async () => {
    const db = getDb();
    const r = await prepare();
    const wallet = (await db.query('insert into private.dopmi_saved_card_customers(owner_id,stripe_customer_id) values($1,$2) returning id', [donor, 'cus_registration'])).rows[0].id;
    const job = (await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,return_url)
      values($1,$2,$3,'saved-cards-2026-10-03','cus_registration','https://example.test/functions/v1/payment-return') returning id`, [donor, key, wallet])).rows[0].id;
    await reject(() => rpc('confirm_method', { id: r.id, method_job_id: job }), /Método no confirmado/);
    await db.query("update private.dopmi_saved_card_jobs set status='saved',session_id='cs_test_registration',setup_intent_id='seti_registration',payment_method_id='pm_registration' where id=$1", [job]);
    await db.query('update private.dopmi_saved_card_jobs set owner_id=$1 where id=$2', [other, job]);
    await reject(() => rpc('confirm_method', { id: r.id, method_job_id: job }), /Método no confirmado/);
    await db.query('update private.dopmi_saved_card_jobs set owner_id=$1 where id=$2', [donor, job]);
    await reject(() => rpc('confirm_method', { owner_id: other, id: r.id, method_job_id: job }), /Registro no disponible/);
    await reject(() => rpc('confirm_method', { id: r.id, method_job_id: job }), /Método no confirmado/);
    await db.query('update private.dopmi_saved_card_jobs set request_key=$1 where id=$2', [r.id, job]);
    const saved = await rpc('confirm_method', { id: r.id, method_job_id: job });
    assert.equal(saved.status, 'registered');
    assert.deepEqual(await rpc('confirm_method', { id: r.id, method_job_id: job }), saved);
    const canceled = await rpc('cancel', { id: r.id });
    assert.equal(canceled.status, 'canceled');
    assert.deepEqual(await rpc('cancel', { id: r.id }), canceled);
    assert.equal((await rpc('confirm_method', { id: r.id, method_job_id: job })).status, 'canceled');
  });
  test('registration SQL: recoverable setup binds only exact registration key, confirmed owner method and cancellation', async () => {
    const db = getDb(); const r = await prepare();
    await reject(() => db.query('select public.dopmi_guardian_activation_server($1,$2::jsonb)', ['prepare', JSON.stringify({
      donor_id: donor, key: '72000000-0000-4000-8000-000000000077', gross_cents: 2000,
      consent: true, consent_version: 'guardian-2026-09-24',
    })]), /Registro Guardián existente/);
    assert.equal((await rpc('reconcile_method', { id: r.id })).status, 'method_pending');
    const wallet = (await db.query('insert into private.dopmi_saved_card_customers(owner_id,stripe_customer_id) values($1,$2) returning id', [donor, 'cus_registrationresume'])).rows[0].id;
    const job = (await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,return_url)
      values($1,$2,$3,'saved-cards-2026-10-03','cus_registrationresume','https://example.test/functions/v1/payment-return') returning id`, [donor, key, wallet])).rows[0].id;
    await db.query("update private.dopmi_saved_card_jobs set status='saved',session_id='cs_test_registrationresume',setup_intent_id='seti_registrationresume',payment_method_id='pm_registrationresume' where id=$1", [job]);
    assert.equal((await rpc('reconcile_method', { id: r.id })).status, 'method_pending');
    await db.query('update private.dopmi_saved_card_jobs set request_key=$1,owner_id=$2 where id=$3', [r.id, other, job]);
    assert.equal((await rpc('reconcile_method', { id: r.id })).status, 'method_pending');
    await db.query('update private.dopmi_saved_card_jobs set owner_id=$1 where id=$2', [donor, job]);
    const confirmed = await rpc('reconcile_method', { id: r.id });
    assert.equal(confirmed.status, 'registered');
    assert.equal(confirmed.method_job_id, job);
    assert.deepEqual(await rpc('reconcile_method', { id: r.id }), confirmed);
    await rpc('cancel', { id: r.id });
    assert.equal((await rpc('reconcile_method', { id: r.id })).status, 'canceled');
  });
  test('registration SQL: amount consent and optimistic revision work before first charge', async () => {
    const r = await prepare();
    const input = { id: r.id, revision: r.revision, gross_cents: 5000, consent: true, consent_version: r.consent_version };
    await reject(() => rpc('change_amount', { ...input, consent: false }), /Autorización/);
    const changed = await rpc('change_amount', input);
    assert.equal(changed.gross_cents, 5000);
    assert.equal(changed.registered_at, r.registered_at);
    assert.equal(changed.next_evaluation_at, r.next_evaluation_at);
    await reject(() => rpc('change_amount', input), /registro cambió/);
    assert.equal((await prepare()).gross_cents, 5000);
    await rpc('cancel', { id: r.id });
    await reject(() => rpc('change_amount', { ...input, revision: changed.revision + 1 }), /registro cambió/);
  });
  test('registration SQL: private state and server RPC enforce grants and ownership including admin', async () => {
    const r = await prepare();
    for (const actor of [other, staff]) {
      await role(actor);
      assert.equal((await getDb().query('select public.dopmi_guardian_registration_state() value')).rows[0].value, null);
      await reject(() => getDb().query('select * from private.dopmi_guardian_registrations'), /permission denied/);
      await reject(() => rpc('get', { id: r.id }), /permission denied/);
    }
    await role(donor);
    const state = (await getDb().query('select public.dopmi_guardian_registration_state() value')).rows[0].value;
    assert.equal(state.id, r.id);
    assert.equal(Object.hasOwn(state, 'method_job_id'), false);
    assert.equal(Object.hasOwn(state, 'owner_id'), false);
    await role('', 'anon');
    await reject(() => getDb().query('select public.dopmi_guardian_registration_state()'), /permission denied/);
    await getDb().exec('reset role');
  });
  test('registration SQL: current state prefers open registration over canceled with tied timestamps', async () => {
    const db = getDb();
    const previous = await prepare();
    await rpc('cancel', { id: previous.id });
    const current = await prepare({ key: '72000000-0000-4000-8000-000000000098' });
    await db.query('update private.dopmi_guardian_registrations set registered_at=$1 where owner_id=$2', [previous.registered_at, donor]);
    // Force the canceled row to win the old UUID descending tie-break.
    await db.query("update private.dopmi_guardian_registrations set id='ffffffff-ffff-4fff-8fff-ffffffffffff' where id=$1", [previous.id]);
    await role(donor);
    const state = (await db.query('select public.dopmi_guardian_registration_state() value')).rows[0].value;
    assert.equal(state.id, current.id);
    assert.equal(state.status, 'method_pending');
    await db.exec('reset role');
    await rpc('cancel', { id: current.id });
    await role(donor);
    assert.equal((await db.query('select public.dopmi_guardian_registration_state() value')).rows[0].value.status, 'canceled');
    await db.exec('reset role');
  });
  test('registration SQL: UTC calendar agrees with runtime through leap and short months', async () => {
    for (const origin of ['2023-12-31T00:00:01Z', '2026-01-30T20:15:00-06:00']) {
      for (const cycle of [1, 2, 3, 14, 15]) {
        const result = (await getDb().query('select extract(epoch from private.dopmi_guardian_registration_date($1,$2)) value', [origin, cycle])).rows[0].value;
        assert.equal(Number(result), guardianRegistrationEvaluation(Date.parse(origin) / 1000, cycle));
      }
    }
  });
}
