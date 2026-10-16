import { test } from 'node:test';
import assert from 'node:assert/strict';

// Uses the caller's fully migrated fixture and per-test transaction hooks.
export function registerNativeSavedCardSqlCases(getDb, { donor, other, staff, key }) {
  const query = (...args) => getDb().query(...args);
  const rpc = async (operation, data = {}) => (await query(
    'select public.dopmi_saved_native_card_server($1,$2::jsonb) value',
    [operation, JSON.stringify(data)])).rows[0].value;
  const reg = async (operation, data = {}) => (await query(
    'select public.dopmi_guardian_registration_server($1,$2::jsonb) value',
    [operation, JSON.stringify({ owner_id: donor, ...data })])).rows[0].value;
  const wallet = async (operation, data = {}) => (await query(
    'select public.dopmi_saved_wallet_server($1,$2::jsonb) value',
    [operation, JSON.stringify(data)])).rows[0].value;
  const card = async (operation, data = {}) => (await query(
    'select public.dopmi_saved_card_server($1,$2::jsonb) value',
    [operation, JSON.stringify(data)])).rows[0].value;
  const reject = async (fn, pattern) => {
    await getDb().exec('savepoint native_card_negative');
    await assert.rejects(fn, pattern);
    await getDb().exec('rollback to savepoint native_card_negative');
  };
  const prepare = () => reg('prepare', { key, gross_cents: 2000, consent: true,
    consent_version: 'guardian-registration-2026-10-14' });
  const input = registration => ({ owner_id: donor, key: registration.id, consent: true,
    consent_version: 'saved-cards-2026-10-03', return_url: 'https://example.test/functions/v1/payment-return' });
  const reserved = async () => {
    const r = await prepare(); const j = await rpc('prepare_registration', input(r));
    const claim = await rpc('claim', { id: j.id });
    await rpc('customer', { id: j.id, lease: claim.lease, customer_id: 'cus_nativecard' });
    await rpc('native_setup', { id: j.id, lease: claim.lease, setup_intent_id: 'seti_nativecard' });
    return { r, j: { ...j, ...claim, setup_intent_id: 'seti_nativecard' } };
  };
  test('native card SQL reserves only its registration owner and separates wallet/hosted queues', async () => {
    const r = await prepare();
    assert.equal(await rpc('registration_job', { owner_id: donor, key: r.id }), null);
    const j = await rpc('prepare_registration', input(r));
    assert.equal(j.wallet_type, 'card'); assert.equal(j.session_id, null);
    assert.equal((await rpc('prepare_registration', input(r))).id, j.id);
    await reject(() => rpc('prepare_registration', { ...input(r), owner_id: other }), /Registro no disponible/);
    assert.deepEqual(await rpc('candidates'), [{ id: j.id }]);
    assert.deepEqual(await card('candidates'), []); assert.deepEqual(await wallet('candidates'), []);
    assert.equal(await wallet('lookup_setup', { setup_intent_id: 'seti_nativecard' }), null);
    await query("select set_config('request.jwt.claim.sub',$1,true)", [donor]);
    assert.equal((await query('select public.dopmi_saved_wallet_state() value')).rows[0].value, null);
    assert.equal((await query('select public.dopmi_saved_card_state() value')).rows[0].value, null);
    assert.equal((await reg('get', { id: r.id })).method_job_id, null);
  });
  test('native card SQL refuses client roles and cannot enter the wallet prepare endpoint', async () => {
    const r = await prepare();
    await reject(() => wallet('prepare', { ...input(r), wallet_type: 'card' }), /Billetera no disponible/);
    for (const [actor, role] of [[donor,'authenticated'],[other,'authenticated'],[staff,'authenticated'],['','anon']]) {
      await getDb().exec('reset role');
      await query("select set_config('request.jwt.claim.sub',$1,true)", [actor]);
      await getDb().exec(`set local role ${role}`);
      await reject(() => rpc('prepare_registration', input(r)), /permission denied/);
      await reject(() => query('select * from private.dopmi_saved_card_jobs'), /permission denied/);
    }
    await getDb().exec('reset role');
  });
  test('native card SQL requires lease, immutable setup and fresh registration before SDK receipt', async () => {
    const { r, j } = await reserved();
    const data = { id: j.id, setup_intent_id: j.setup_intent_id };
    assert.equal(await rpc('native_ready', data), null);
    await reject(() => rpc('native_setup', { id: j.id, lease: j.lease, setup_intent_id: 'seti_other' }), /no coincide/);
    await rpc('release', { id: j.id, lease: j.lease });
    assert.equal((await rpc('native_ready', data)).id, j.id);
    await reg('cancel', { id: r.id });
    assert.equal(await rpc('native_ready', data), null);
    await reject(() => rpc('native_saved', { id: j.id, lease: j.lease,
      setup_intent_id: j.setup_intent_id, payment_method_id: 'pm_nativecard' }), /vencido/);
    assert.equal((await reg('get', { id: r.id })).status, 'canceled');
  });
  test('native card SQL provider proof completes registration once without a Checkout Session', async () => {
    const { r, j } = await reserved();
    await rpc('native_saved', { id: j.id, lease: j.lease,
      setup_intent_id: j.setup_intent_id, payment_method_id: 'pm_nativecard' });
    const registered = await reg('reconcile_method', { id: r.id });
    assert.equal(registered.status, 'registered'); assert.equal(registered.method_job_id, j.id);
    assert.equal((await reg('reconcile_method', { id: r.id })).revision, registered.revision);
    assert.deepEqual(await rpc('candidates'), []);
  });
  test('native card SQL preserves an existing hosted request instead of forking another setup', async () => {
    const r = await prepare(); const j = await card('prepare', input(r));
    const reused = await rpc('prepare_registration', input(r));
    assert.equal(reused.id, j.id); assert.equal(reused.wallet_type, null);
    const claim = await card('claim', { id: j.id });
    await card('customer', { id: j.id, lease: claim.lease, customer_id: 'cus_hostedcard' });
    await card('session', { id: j.id, lease: claim.lease, session_id: 'cs_test_hostedcard' });
    await card('release', { id: j.id, lease: claim.lease });
    const resumed = await rpc('prepare_registration', input(r));
    assert.equal(resumed.id, j.id); assert.equal(resumed.session_id, 'cs_test_hostedcard');
    await reject(() => rpc('get', { id: j.id }), /Método nativo no disponible/);
    assert.deepEqual(await rpc('candidates'), []);
  });
}
