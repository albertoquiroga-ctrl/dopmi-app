import test from 'node:test';
import assert from 'node:assert/strict';
import { nativeSavedWalletService } from '../../supabase/functions/_shared/native-saved-wallet.mjs';
import { savedCardConsentVersion } from '../../supabase/functions/_shared/saved-card.mjs';

function fixture(wallet = 'google_pay') {
  const job = { id: 'job', request_key: 'key', status: 'pending', wallet_type: wallet,
    wallet_id: 'a52540a5-e18d-40a7-9e43-748510ebbe3e',
    customer_id: 'cus_owner', consent_version: savedCardConsentVersion,
    expires_at: new Date(Date.now() + 60000).toISOString(), lease: 'lease' };
  const setup = { id: 'seti_wallet', customer: 'cus_owner', livemode: false,
    usage: 'off_session', payment_method_types: ['card'], status: 'requires_payment_method',
    client_secret: 'seti_wallet_secret_fixture', payment_method: 'pm_wallet',
    metadata: { dopmi_saved_card_job: 'job', wallet_type: wallet, consent_version: savedCardConsentVersion } };
  const method = { id: 'pm_wallet', customer: 'cus_owner', livemode: false, type: 'card', card: { wallet: { type: wallet } } };
  const f = { job, setup, method, calls: [], operations: [], lost: false, leased: true, race: false,
    customer: { id: 'cus_owner', livemode: false, invoice_settings: { default_payment_method: 'pm_old' } },
    async rpc(op, data) {
      f.operations.push(op);
      if (op === 'get') return structuredClone(job);
      if (op === 'claim') return f.leased ? structuredClone(job) : null;
      if (op === 'native_ready') return f.leased ? structuredClone(job) : null;
      assert.equal(data.lease, 'lease');
      if (op === 'native_setup') job.setup_intent_id = data.setup_intent_id;
      if (op === 'customer') job.customer_id = data.customer_id;
      if (op === 'native_saved') {
        assert.equal(data.setup_intent_id, setup.id);
        job.status = 'saved'; job.payment_method_id = data.payment_method_id;
      }
      if (op === 'expired') job.status = 'expired';
      return structuredClone(job);
    },
  };
  const stripe = {
    customers: { retrieve: async () => structuredClone(f.customer), create: async (data, options) => {
      f.calls.push({ operation: 'customer', data, options });
      if (f.lostCustomer) { f.lostCustomer = false; throw Error('lost customer response'); }
      return structuredClone(f.customer);
    } },
    setupIntents: {
      create: async (data, options) => {
        f.calls.push({ operation: 'create', data, options });
        if (f.lost) { f.lost = false; throw Error('lost response'); }
        return structuredClone(setup);
      },
      retrieve: async () => structuredClone(setup),
      cancel: async (id, data, options) => {
        f.calls.push({ operation: 'cancel', id, data, options });
        if (f.race) { setup.status = 'succeeded'; throw Error('confirmation won'); }
        setup.status = 'canceled'; return structuredClone(setup);
      },
    },
    paymentMethods: { retrieve: async () => structuredClone(method) },
  };
  f.service = nativeSavedWalletService({ stripe, rpc: f.rpc });
  return f;
}

for (const wallet of ['apple_pay', 'google_pay']) {
  test(`${wallet}: no-charge setup, minimal pending receipt, confirmed wallet proof and stable terminal replay`, async () => {
    const f = fixture(wallet);
    assert.deepEqual(await f.service.receipt('job'), { key: 'key', status: 'pending', wallet_type: wallet,
      card_id: null, setup_client_secret: 'seti_wallet_secret_fixture' });
    assert.deepEqual(f.calls[0], { operation: 'create', data: { customer: 'cus_owner', usage: 'off_session',
      payment_method_types: ['card'], metadata: { dopmi_saved_card_job: 'job', wallet_type: wallet,
        consent_version: savedCardConsentVersion } }, options: { idempotencyKey: 'dopmi-saved-wallet-setup:job' } });
    f.setup.status = 'succeeded';
    const terminal = { key: 'key', status: 'saved', wallet_type: wallet, card_id: 'pm_wallet', setup_client_secret: null };
    assert.deepEqual(await f.service.receipt('job'), terminal);
    assert.deepEqual(await f.service.receipt('job'), terminal);
    assert.equal(f.calls.length, 1);
    assert.equal(f.customer.invoice_settings.default_payment_method, 'pm_old');
    assert.equal(f.operations.filter(op => op === 'native_saved').length, 1);
    assert.equal(f.operations.filter(op => op === 'release').length, 2);
  });
  test(`${wallet}: a card or different wallet never becomes a confirmed wallet`, async () => {
    for (const patch of [{ customer: 'cus_other' }, { livemode: true }, { type: 'bank_account' },
      { card: {} }, { card: { wallet: { type: wallet === 'apple_pay' ? 'google_pay' : 'apple_pay' } } }]) {
      const f = fixture(wallet); f.job.setup_intent_id = f.setup.id; f.setup.status = 'succeeded';
      Object.assign(f.method, patch);
      await assert.rejects(f.service.run('job'), /saved_wallet_method_mismatch/);
      assert.equal(f.job.status, 'pending'); assert.ok(!f.operations.includes('native_saved'));
      assert.equal(f.operations.at(-1), 'release');
    }
  });
}
test('lost setup response retries the same provider resource key without confirming anything', async () => {
  const f = fixture(); f.lost = true;
  await assert.rejects(f.service.receipt('job'), /lost response/);
  assert.equal(f.job.setup_intent_id, undefined);
  await f.service.receipt('job');
  assert.deepEqual(f.calls[0], f.calls[1]);
  assert.equal(f.job.status, 'pending');
});
test('wrong customer, live mode, consent and Checkout jobs cannot start native setup', async () => {
  for (const patch of [{ wallet_type: 'simulated' }, { consent_version: 'unapproved' }, { session_id: 'cs_test_other' }]) {
    const f = fixture(); Object.assign(f.job, patch);
    await assert.rejects(f.service.run('job'), /saved_wallet_job_invalid/);
    assert.equal(f.calls.length, 0);
  }
  for (const patch of [{ id: 'cus_other' }, { livemode: true }, { deleted: true }]) {
    const f = fixture(); Object.assign(f.customer, patch);
    await assert.rejects(f.service.run('job'), /saved_wallet_customer_mismatch/);
    assert.equal(f.calls.length, 0);
  }
});
test('a SetupIntent for another job, provider or usage is never exposed or confirmed', async () => {
  for (const patch of [{ customer: 'cus_other' }, { livemode: true }, { usage: 'on_session' },
    { payment_method_types: ['card', 'us_bank_account'] }, { metadata: {} },
    { metadata: { dopmi_saved_card_job: 'other' } }]) {
    const f = fixture(); f.job.setup_intent_id = f.setup.id; Object.assign(f.setup, patch);
    await assert.rejects(f.service.receipt('job'), /saved_wallet_setup_mismatch/);
    assert.equal(f.job.status, 'pending');
  }
});
test('expiration cancels an existing SetupIntent and never reissues its secret', async () => {
  const f = fixture(); f.job.setup_intent_id = f.setup.id; f.job.expires_at = '2020-01-01T00:00:00Z';
  const receipt = await f.service.receipt('job');
  assert.equal(receipt.status, 'expired'); assert.equal(receipt.setup_client_secret, null);
  assert.equal(f.calls[0].options.idempotencyKey, 'dopmi-saved-wallet-expire:job');
  const unstarted = fixture(); unstarted.job.expires_at = '2020-01-01T00:00:00Z';
  assert.equal((await unstarted.service.receipt('job')).status, 'expired');
  assert.equal(unstarted.calls.length, 0);
});
test('confirmation winning the expiration race requires fresh wallet proof', async () => {
  const f = fixture(); f.job.setup_intent_id = f.setup.id; f.job.expires_at = '2020-01-01T00:00:00Z'; f.race = true;
  assert.equal((await f.service.receipt('job')).status, 'saved');
  assert.equal(f.calls.length, 1); assert.equal(f.calls[0].operation, 'cancel');
});
test('no lease cannot create a SetupIntent or expose an unknown secret', async () => {
  const f = fixture(); f.leased = false;
  assert.equal((await f.service.receipt('job')).setup_client_secret, null);
  assert.equal(f.calls.length, 0);
  f.job.setup_intent_id = f.setup.id;
  assert.equal((await f.service.receipt('job')).setup_client_secret, null);
  assert.equal(f.calls.length, 0);
});
test('first wallet shares the saved-card customer key and survives a lost customer response', async () => {
  const f = fixture(); f.job.customer_id = null; f.lostCustomer = true;
  await assert.rejects(f.service.run('job'), /lost customer response/);
  assert.equal(f.job.customer_id, null);
  await f.service.run('job');
  assert.deepEqual(f.calls[0], f.calls[1]);
  assert.equal(f.calls[0].options.idempotencyKey, `dopmi-saved-card-customer:${f.job.wallet_id}`);
  assert.equal(f.job.customer_id, 'cus_owner');
  assert.equal(f.calls[2].operation, 'create');
});
test('expired first wallet cannot create even a customer', async () => {
  const f = fixture(); f.job.customer_id = null; f.job.expires_at = '2020-01-01T00:00:00Z';
  assert.equal((await f.service.run('job')).status, 'expired');
  assert.equal(f.calls.length, 0);
});
