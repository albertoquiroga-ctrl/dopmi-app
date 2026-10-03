import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nativeSavedWalletService } from '../../supabase/functions/_shared/native-saved-wallet.mjs';
import { savedCardConsentVersion } from '../../supabase/functions/_shared/saved-card.mjs';

// Registered by payments.test.mjs against its fully migrated PostgreSQL fixture.
export function registerNativeWalletSqlCases(f) {
  const { donor, other, staff, key, role, rejected, savedCardRpc, savedCardInput,
    savedCardReturn, savedCardFixture, independentMethod, activationRpc,
    guardianConsentVersion, methodFixture } = f;
  const query = (...args) => f.getDb().query(...args);
  const native = async (op, data = {}) => (await query(
    'select public.dopmi_saved_wallet_server($1,$2::jsonb) value', [op, JSON.stringify(data)])).rows[0].value;
  const input = { owner_id: donor, key, consent: true, consent_version: savedCardConsentVersion,
    wallet_type: 'google_pay', return_url: savedCardReturn };
  async function reserved() {
    const j = await native('prepare', input);
    const c = await native('claim', { id: j.id });
    await native('customer', { id: j.id, lease: c.lease, customer_id: 'cus_native' });
    await native('native_setup', { id: j.id, lease: c.lease, setup_intent_id: 'seti_native' });
    return { ...j, ...c, setup_intent_id: 'seti_native', customer_id: 'cus_native' };
  }
  test('native wallet SQL reserves provider/key and separates normal receipts and queues', async () => {
    const j = await native('prepare', input);
    assert.equal((await native('prepare', input)).id, j.id);
    await rejected(() => native('prepare', { ...input, wallet_type: 'apple_pay' }), /solicitud cambió/);
    await rejected(() => native('prepare', { ...input, wallet_type: 'fake' }), /Billetera/);
    await rejected(() => savedCardRpc('prepare', { owner_id: donor, ...savedCardInput, return_url: savedCardReturn }), /solicitud cambió/);
    assert.deepEqual(await savedCardRpc('candidates'), []);
    assert.deepEqual(await native('candidates'), [{ id: j.id }]);
    await role(donor);
    assert.equal((await query('select dopmi_saved_card_state() v')).rows[0].v, null);
    assert.deepEqual((await query('select dopmi_saved_wallet_state() v')).rows[0].v,
      { key, status: 'pending', wallet_type: 'google_pay', card_id: null });
  });
  test('native wallet SQL denies browser writes and foreign or staff receipt access', async () => {
    const j = await native('prepare', input);
    for (const [actor, name] of [[donor, 'authenticated'], [other, 'authenticated'], [staff, 'authenticated'], ['', 'anon']]) {
      await role(actor, name);
      await rejected(() => native('get', { id: j.id }), /permission denied/);
      await rejected(() => query('select * from private.dopmi_saved_card_jobs'), /permission denied/);
      if (name === 'anon') await rejected(() => query('select dopmi_saved_wallet_state()'), /permission denied/);
      else {
        const own = (await query('select dopmi_saved_wallet_state() v')).rows[0].v;
        assert.equal(own?.key ?? null, actor === donor ? key : null);
        if (own) assert.deepEqual(Object.keys(own).sort(), ['card_id', 'key', 'status', 'wallet_type']);
      }
    }
  });
  test('native wallet SQL needs active lease and matching immutable SetupIntent before proof', async () => {
    const j = await native('prepare', input);
    await rejected(() => native('native_setup', { id: j.id, lease: key, setup_intent_id: 'seti_native' }), /vencido/);
    const c = await native('claim', { id: j.id });
    await rejected(() => native('native_setup', { id: j.id, lease: c.lease, setup_intent_id: 'seti_native' }), /no coincide/);
    await native('customer', { id: j.id, lease: c.lease, customer_id: 'cus_native' });
    await native('native_setup', { id: j.id, lease: c.lease, setup_intent_id: 'seti_native' });
    await rejected(() => native('native_setup', { id: j.id, lease: c.lease, setup_intent_id: 'seti_changed' }), /no coincide/);
    await rejected(() => native('native_saved', { id: j.id, lease: c.lease, setup_intent_id: 'seti_changed', payment_method_id: 'pm_native' }), /no confirmada/);
    await rejected(() => savedCardRpc('session', { id: j.id, lease: c.lease, session_id: 'cs_test_wrong' }), /comprobante nativo/);
    await native('release', { id: j.id, lease: c.lease });
    await rejected(() => native('native_saved', { id: j.id, lease: c.lease, setup_intent_id: 'seti_native', payment_method_id: 'pm_native' }), /vencido/);
    await rejected(() => savedCardRpc('customer', { id: j.id, lease: c.lease, customer_id: 'cus_late' }), /vencido/);
    const renewed = await native('claim', { id: j.id });
    const done = await native('native_saved', { id: j.id, lease: renewed.lease, setup_intent_id: 'seti_native', payment_method_id: 'pm_native' });
    assert.equal(done.status, 'saved'); assert.equal(done.session_id, null);
    await role(donor);
    assert.deepEqual((await query('select dopmi_saved_wallet_state() v')).rows[0].v,
      { key, status: 'saved', wallet_type: 'google_pay', card_id: 'pm_native' });
  });
  test('native wallet SQL rechecks identity, expected setup, expiry and lease before secret', async () => {
    const j = await reserved();
    const ready = () => native('native_ready', { id: j.id, setup_intent_id: j.setup_intent_id });
    assert.equal(await ready(), null);
    await native('release', { id: j.id, lease: j.lease });
    assert.equal((await ready()).id, j.id);
    assert.equal(await native('native_ready', { id: j.id, setup_intent_id: 'seti_wrong' }), null);
    await query('update auth.users set email_confirmed_at=null where id=$1', [donor]);
    assert.equal(await ready(), null); assert.equal(await native('claim', { id: j.id }), null);
    await query('update auth.users set email_confirmed_at=now() where id=$1', [donor]);
    await query("update profiles set account_status='suspended' where id=$1", [donor]);
    assert.equal(await ready(), null);
    await query("update profiles set account_status='active' where id=$1", [donor]);
    await query("update private.dopmi_saved_card_jobs set expires_at=now()-interval '1 second' where id=$1", [j.id]);
    assert.equal(await ready(), null);
  });
  test('native wallet SQL keeps expired setup reconcilable rather than assuming cancellation', async () => {
    const j = await reserved(); await native('release', { id: j.id, lease: j.lease });
    await query("update private.dopmi_saved_card_jobs set expires_at=now()-interval '1 day',attempts=8,first_attempt_at=now()-interval '2 days' where id=$1", [j.id]);
    const c = await native('claim', { id: j.id }); assert.equal(c.status, 'pending'); assert.equal(c.attempts, 8);
    assert.equal((await native('expired', { id: j.id, lease: c.lease })).status, 'expired');
    const ordinary = savedCardFixture(); const normal = await ordinary.prepare({ key: crypto.randomUUID() });
    await rejected(() => native('get', { id: normal.id }), /comprobante Checkout/);
  });
  test('native wallet SetupIntent cannot be reused by another owner or mixed with a Checkout Session', async () => {
    const j = await reserved();
    await rejected(() => query("update private.dopmi_saved_card_jobs set session_id='cs_test_mixed' where id=$1", [j.id]), /flow_check/);
    const peer = await native('prepare', { ...input, owner_id: other });
    const c = await native('claim', { id: peer.id });
    await native('customer', { id: peer.id, lease: c.lease, customer_id: 'cus_peer' });
    await rejected(() => native('native_setup', { id: peer.id, lease: c.lease, setup_intent_id: 'seti_native' }), /unique constraint/);
    assert.equal((await native('get', { id: peer.id })).setup_intent_id, null);
  });
  test('native wallet secret authorization fails when the reserved customer stops matching its owner wallet', async () => {
    const j = await reserved(); await native('release', { id: j.id, lease: j.lease });
    assert.equal((await native('native_ready', { id: j.id, setup_intent_id: j.setup_intent_id })).id, j.id);
    await query("update private.dopmi_saved_card_customers set stripe_customer_id='cus_changed' where owner_id=$1", [donor]);
    assert.equal(await native('native_ready', { id: j.id, setup_intent_id: j.setup_intent_id }), null);
  });
  test('native wallet reservation blocks normal setup, independent method and activation', async () => {
    await native('prepare', input);
    await rejected(() => savedCardRpc('prepare', { owner_id: donor, ...savedCardInput, key: crypto.randomUUID(), return_url: savedCardReturn }), /pendiente/);
    await rejected(() => independentMethod('prepare', { owner_id: donor, key: crypto.randomUUID(), consent: true,
      consent_version: 'saved-card-methods-2026-10-03', action: 'default', selected_method_id: 'pm_native' }), /pendiente/);
    await rejected(() => activationRpc('prepare', { donor_id: donor, key: crypto.randomUUID(), gross_cents: 10000, consent: true,
      consent_version: guardianConsentVersion, return_url: 'https://example.test/return' }), /alta de tarjeta/);
  });
  test('native wallet and Guardian method block each other without changing the accepted plan', async () => {
    const g = await methodFixture();
    const before = (await query('select to_jsonb(s) v from private.dopmi_guardian_subscriptions s')).rows[0].v;
    await native('prepare', input);
    await rejected(() => g.prepare(), /conciliación/);
    assert.deepEqual((await query('select to_jsonb(s) v from private.dopmi_guardian_subscriptions s')).rows[0].v, before);
    await query("update private.dopmi_saved_card_jobs set status='expired'");
    await g.prepare();
    await rejected(() => native('prepare', { ...input, key: crypto.randomUUID() }), /medio Guardián pendiente/);
  });
  for (const wallet of ['apple_pay', 'google_pay']) test(`native ${wallet} SQL service recovers lost setup response and proves the selected wallet`, async () => {
    const j = await native('prepare', { ...input, wallet_type: wallet });
    let setup; const calls = []; let lose = true;
    const stripe = {
      customers: { create: async (data, options) => { calls.push({ kind: 'customer', data, options }); return { id: 'cus_native', livemode: false }; },
        retrieve: async () => ({ id: 'cus_native', livemode: false }) },
      setupIntents: { create: async (data, options) => {
        calls.push({ kind: 'setup', data, options });
        setup ??= { ...data, id: 'seti_native', livemode: false, status: 'requires_payment_method',
          client_secret: 'seti_native_secret_fixture', payment_method: 'pm_native' };
        if (lose) { lose = false; throw Error('lost setup response'); } return structuredClone(setup);
      }, retrieve: async () => structuredClone(setup) },
      paymentMethods: { retrieve: async () => ({ id: 'pm_native', customer: 'cus_native', livemode: false,
        type: 'card', card: { wallet: { type: wallet } } }) },
    };
    const service = nativeSavedWalletService({ stripe, rpc: native });
    await assert.rejects(service.receipt(j.id), /lost setup response/);
    const pending = await service.receipt(j.id);
    assert.equal(pending.status, 'pending'); assert.equal(pending.setup_client_secret, 'seti_native_secret_fixture');
    const attempts = calls.filter(x => x.kind === 'setup'); assert.deepEqual(attempts[0], attempts[1]);
    assert.equal(calls.filter(x => x.kind === 'customer').length, 1);
    setup.status = 'succeeded';
    const done = await service.receipt(j.id);
    assert.equal(done.status, 'saved'); assert.equal(done.card_id, 'pm_native'); assert.equal(done.setup_client_secret, null);
    assert.deepEqual(await service.receipt(j.id), done); assert.equal(calls.length, 3);
    for (const table of ['dopmi_guardian_subscriptions', 'dopmi_guardian_activations', 'dopmi_guardian_cycles'])
      assert.equal((await query(`select count(*)::int n from private.${table}`)).rows[0].n, 0);
    assert.equal((await query('select count(*)::int n from dopmi_donations')).rows[0].n, 0);
  });
}
