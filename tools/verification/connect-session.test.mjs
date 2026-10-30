import test from 'node:test';
import assert from 'node:assert/strict';
import { paymentService } from '../../supabase/functions/_shared/payments.mjs';
function fixture({ mutate = () => {}, mutateAccount = () => {}, revoke = false, wrongOwner = false, failSession = false } = {}) {
  const calls = []; let reads = 0;
  const service = paymentService({
    rpc: async (op, data) => {
      calls.push({op, data});
      if (op === 'connect_get') {
        if (revoke && ++reads === 3) throw new Error('revoked');
        return {owner_id: wrongOwner ? 'other' : 'owner', account_id: 'acct_owned'};
      }
      if (op === 'connect_save') return data;
      throw new Error('unexpected rpc');
    },
    stripe: async (path, fields) => {
      calls.push({path, fields});
      if (path === 'accounts/acct_owned') {
        // Stripe's Account object has no livemode field. Test mode is enforced
        // by stripeApi's test key and the AccountSession response below.
        const response = {object: 'account', id: 'acct_owned', type: 'express', country: 'MX'};
        mutateAccount(response); return response;
      }
      assert.equal(path, 'account_sessions');
      assert.deepEqual(fields, { account: 'acct_owned', 'components[account_onboarding][enabled]': true, 'components[account_onboarding][features][disable_stripe_user_authentication]': false });
      if (failSession) throw new Error('stripe_unavailable');
      const response = {object: 'account_session', account: 'acct_owned', livemode: false, client_secret: 'synthetic_session_secret', expires_at: Math.floor(Date.now()/1000)+300, components: { account_onboarding: {enabled: true, features: {disable_stripe_user_authentication: false}}, payments: {enabled: false}, payouts: {enabled: false} }};
      mutate(response); return response;
    }, returnUrl: 'https://example.test/return',
  }); return {service, calls};
}
test('Connect accepts the Stripe Account contract without livemode and delegates only onboarding', async () => {
  const {service, calls} = fixture();
  const result = await service.connect('owner', 'session');
  assert.deepEqual(Object.keys(result).sort(), ['client_secret','expires_at']);
  assert.equal(calls.filter(c => c.op === 'connect_get').length, 3);
  assert.equal(calls.filter(c => c.path === 'account_sessions').length, 1);
});
test('Connect rejects ownership mismatch before session creation', async () => {
  const {service,calls} = fixture({wrongOwner:true});
  await assert.rejects(service.connect('owner','session'), /access_denied/);
  assert.equal(calls.filter(c=>c.path==='account_sessions').length,0);
});

test('Connect rejects a mismatched Account contract before session creation', async () => {
  for (const mutateAccount of [
    a=>a.object='account_session', a=>delete a.object, a=>a.id='acct_other',
    a=>a.type='standard', a=>a.country='US', a=>a.livemode=true,
    a=>a.livemode=null, a=>a.livemode='false',
  ]) {
    const {service,calls} = fixture({mutateAccount});
    await assert.rejects(service.connect('owner','session'), /connect_account_mismatch/);
    assert.equal(calls.filter(c=>c.path==='account_sessions').length,0);
  }
});

test('Connect preserves acceptance of an explicit false Account livemode field', async () => {
  const {service} = fixture({mutateAccount:a=>a.livemode=false});
  await service.connect('owner','session');
});
test('Connect rejects privilege expansion, auth bypass, expired/live/mismatched session', async () => {
  for (const mutate of [s=>s.components.payments.enabled=true,s=>s.components.payouts.enabled=true,s=>s.components.account_onboarding.features.disable_stripe_user_authentication=true,s=>s.account='acct_other',s=>s.object='account',s=>s.livemode=true,s=>delete s.livemode,s=>s.expires_at=1,s=>s.client_secret=null]) {
    const {service} = fixture({mutate});
    await assert.rejects(service.connect('owner','session'),/connect_session_invalid/);
  }
});
test('Connect revalidates PostgreSQL guard after session creation without returning secret', async () => {
  const {service} = fixture({revoke:true});
  await assert.rejects(service.connect('owner','session'),/revoked/);
});

test('Connect propagates session creation errors without falling back to an account link', async () => {
  const {service,calls} = fixture({failSession:true});
  await assert.rejects(service.connect('owner','session'), /stripe_unavailable/);
  assert.equal(calls.filter(c=>c.path==='account_sessions').length,1);
  assert.equal(calls.some(c=>c.path==='account_links'),false);
});

function creationFixture(retryKey, { lostSave = false, lostCommittedSave = false, lostCreate = false, startedAt = new Date().toISOString(), rowOwner = 'owner' } = {}) {
  let bound = false, saves = 0;
  const keys = [], resources = new Map();
  const row = () => ({ owner_id: rowOwner, account_id: bound ? 'acct_recovered' : null,
    create_started_at: startedAt, create_idempotency_key: retryKey });
  const service = paymentService({
    rpc: async (op) => {
      if (op === 'connect_get' || op === 'connect_begin') return row();
      if (op === 'connect_save') {
        saves++;
        if (lostSave && saves === 1) throw new Error('lost_save_response');
        bound = true;
        if (lostCommittedSave && saves === 1) throw new Error('lost_committed_save_response');
        return row();
      }
      throw new Error(`unexpected ${op}`);
    },
    stripe: async (path, fields, key) => {
      if (path === 'accounts') {
        keys.push(key);
        if (!resources.has(key)) resources.set(key, { id: 'acct_recovered' });
        if (lostCreate && keys.length === 1) throw new Error('lost_create_response');
        return resources.get(key);
      }
      if (path === 'accounts/acct_recovered') return { object: 'account', id: 'acct_recovered', type: 'express', country: 'MX' };
      assert.equal(path, 'account_sessions');
      return { object: 'account_session', account: 'acct_recovered', livemode: false,
        client_secret: 'synthetic_session_secret', expires_at: Math.floor(Date.now()/1000)+300,
        components: { account_onboarding: { enabled: true, features: { disable_stripe_user_authentication: false } } } };
    },
    returnUrl: 'https://example.test/return',
  });
  return { service, keys, resources };
}

test('Connect recovery uses the durable actor-bound retry key instead of the cached legacy failure', async () => {
  const key = 'dopmi-account-owner-retry-10000000-0000-4000-8000-000000000001';
  const { service, keys } = creationFixture(key);
  await service.connect('owner', 'session');
  assert.deepEqual(keys, [key]);
});

test('Connect recovery reuses the same key after creation succeeds but binding response is lost', async () => {
  const key = 'dopmi-account-owner-retry-10000000-0000-4000-8000-000000000001';
  const { service, keys } = creationFixture(key, { lostSave: true });
  await assert.rejects(service.connect('owner', 'session'), /lost_save_response/);
  await service.connect('owner', 'session');
  assert.deepEqual(keys, [key, key]);
});

test('Connect preserves legacy creation key when there is no authorized recovery', async () => {
  for (const key of [null, undefined]) {
    const { service, keys } = creationFixture(key);
    await service.connect('owner', 'session');
    assert.deepEqual(keys, ['dopmi-account-owner']);
  }
});

test('Connect refuses malformed or cross-actor recovery keys without falling back or creating an account', async () => {
  for (const key of ['', 'dopmi-account-other-retry-10000000-0000-4000-8000-000000000001',
    'dopmi-account-owner-retry-random', false, 1]) {
    const { service, keys } = creationFixture(key);
    await assert.rejects(service.connect('owner', 'session'), /connect_creation_recovery_invalid/);
    assert.deepEqual(keys, []);
  }
});


test('Connect recovery retains the 23-hour window and never rotates an expired attempt automatically', async () => {
  const retryKey = 'dopmi-account-owner-retry-10000000-0000-4000-8000-000000000001';
  const { service, keys } = creationFixture(retryKey, { startedAt: new Date(Date.now()-24*3600000).toISOString() });
  await assert.rejects(service.connect('owner', 'session'), /manual_reconciliation_required/);
  assert.deepEqual(keys, []);
});

test('Connect recovery rejects a key returned with a different row owner', async () => {
  const retryKey = 'dopmi-account-owner-retry-10000000-0000-4000-8000-000000000001';
  const { service, keys } = creationFixture(retryKey, { rowOwner: 'another-owner' });
  await assert.rejects(service.connect('owner', 'session'), /connect_creation_recovery_invalid/);
  assert.deepEqual(keys, []);
});


test('Connect recovery reconciles a committed bind with a lost reply without another account create', async () => {
  const retryKey = 'dopmi-account-owner-retry-10000000-0000-4000-8000-000000000001';
  const { service, keys, resources } = creationFixture(retryKey, { lostCommittedSave: true });
  await assert.rejects(service.connect('owner', 'session'), /lost_committed_save_response/);
  await service.connect('owner', 'session');
  assert.deepEqual(keys, [retryKey]);
  assert.equal(resources.size, 1);
});

test('Connect recovery keeps one provider resource after creation committed but its reply was lost', async () => {
  const retryKey = 'dopmi-account-owner-retry-10000000-0000-4000-8000-000000000001';
  const { service, keys, resources } = creationFixture(retryKey, { lostCreate: true });
  await assert.rejects(service.connect('owner', 'session'), /lost_create_response/);
  await service.connect('owner', 'session');
  assert.deepEqual(keys, [retryKey, retryKey]);
  assert.equal(resources.size, 1);
});
