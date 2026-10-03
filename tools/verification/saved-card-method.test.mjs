import test from 'node:test';
import assert from 'node:assert/strict';
import { savedCardMethodService } from '../../supabase/functions/_shared/saved-card-method.mjs';

function fixture(action = 'default') {
  let job = { id: 'job', status: 'pending', action, customer_id: 'cus_owner', selected_method_id: 'pm_target',
    expires_at: new Date(Date.now() + 60000).toISOString(), lease: 'lease', mutation_requested_at: null };
  const customer = { id: 'cus_owner', livemode: false, invoice_settings: { default_payment_method: 'pm_old' } };
  const method = { id: 'pm_target', type: 'card', livemode: false, customer: 'cus_owner' };
  const pages = { subscriptions: [], invoices: [], paymentIntents: [] };
  const f = { customer, method, pages, writes: [], lost: false, cancel: false, more: false,
    get job() { return job; },
    async rpc(op, data) {
      if (op === 'get') return { ...job };
      if (op === 'claim') return { ...job };
      assert.equal(data.lease, 'lease');
      if (op === 'snapshot') job.default_method_id = data.default_method_id;
      if (op === 'write_mutation') {
        if (f.cancel) { job.status = 'expired'; return null; }
        job.mutation_requested_at = new Date().toISOString();
      }
      if (['applied', 'removed', 'refused', 'expired'].includes(op)) job.status = op;
      return { ...job };
    },
  };
  const stripe = {
    customers: { retrieve: async () => structuredClone(customer), update: async (id, data, options) => {
      f.writes.push({ kind: 'default', id, data, options });
      customer.invoice_settings.default_payment_method = data.invoice_settings.default_payment_method;
      if (f.lost) { f.lost = false; throw new Error('lost response'); }
      return structuredClone(customer);
    } },
    paymentMethods: { retrieve: async () => structuredClone(method), detach: async (id, data, options) => {
      f.writes.push({ kind: 'remove', id, data, options }); method.customer = null;
      if (f.lost) { f.lost = false; throw new Error('lost response'); }
      return structuredClone(method);
    } },
  };
  for (const name of Object.keys(pages)) stripe[name] = { list: async params => ({
    data: structuredClone(pages[name].filter(row => !params.status || params.status === 'all' || row.status === params.status)), has_more: f.more,
  }) };
  f.service = savedCardMethodService({ stripe, rpc: f.rpc });
  return f;
}

for (const action of ['default', 'remove']) {
  test(`${action}: exact minimal mutation, fresh proof, no duplicate after lost response`, async () => {
    const f = fixture(action); f.lost = true;
    await assert.rejects(f.service.run('job'), /lost response/);
    assert.equal(f.job.status, 'pending');
    assert.equal((await f.service.run('job')).status, action === 'default' ? 'applied' : 'removed');
    await f.service.run('job');
    assert.equal(f.writes.length, 1);
    assert.equal(f.writes[0].options.idempotencyKey, `dopmi-saved-card-${action}:job`);
    assert.deepEqual(f.writes[0].data, action === 'default' ? { invoice_settings: { default_payment_method: 'pm_target' } } : {});
    assert.equal(f.customer.invoice_settings.default_payment_method, action === 'default' ? 'pm_target' : 'pm_old');
  });
  test(`${action}: owner, live and non-card mismatch cannot write`, async () => {
    for (const patch of [{ customer: 'cus_other' }, { livemode: true }, { type: 'us_bank_account' }]) {
      const f = fixture(action); Object.assign(f.method, patch);
      await assert.rejects(f.service.run('job'), /saved_card_method_owner_mismatch/); assert.equal(f.writes.length, 0);
    }
  });
  test(`${action}: incomplete usage and cancellation never write`, async () => {
    const paged = fixture(action); paged.more = true;
    await assert.rejects(paged.service.run('job'), /saved_card_usage_unconfirmed/); assert.equal(paged.writes.length, 0);
    const canceled = fixture(action); canceled.cancel = true;
    assert.equal((await canceled.service.run('job')).status, 'expired'); assert.equal(canceled.writes.length, 0);
  });
  test(`${action}: expired unstarted job performs no mutation`, async () => {
    const f = fixture(action); f.job.expires_at = '2020-01-01T00:00:00Z';
    assert.equal((await f.service.run('job')).status, 'expired'); assert.equal(f.writes.length, 0);
  });
  test(`${action}: pending use refuses without an optimistic success`, async () => {
    for (const [resource, row] of [
      ['subscriptions', { id: 'sub_active', status: 'active', default_payment_method: 'pm_target' }],
      ['invoices', { id: 'in_open', status: 'open', default_payment_method: 'pm_target' }],
      ['paymentIntents', { id: 'pi_pending', status: 'requires_action', payment_method: 'pm_target' }],
    ]) {
      const f = fixture(action); f.pages[resource].push({ ...row, customer: 'cus_owner', livemode: false });
      assert.equal((await f.service.run('job')).status, 'refused'); assert.equal(f.writes.length, 0);
    }
  });
}
test('default customer mismatch and Guardian job cannot mutate independent wallet', async () => {
  const f = fixture(); f.customer.livemode = true;
  await assert.rejects(f.service.run('job'), /saved_card_customer_mismatch/);
  const guardian = fixture(); guardian.job.subscription_id = 'sub_active';
  await assert.rejects(guardian.service.run('job'), /saved_card_method_job_invalid/);
  assert.equal(guardian.writes.length, 0);
});
test('removal of customer default is refused', async () => {
  const f = fixture('remove'); f.customer.invoice_settings.default_payment_method = 'pm_target';
  assert.equal((await f.service.run('job')).status, 'refused'); assert.equal(f.writes.length, 0);
});
test('removal waits when an open invoice has no explicit method', async () => {
  const f = fixture('remove');
  f.pages.invoices.push({ id: 'in_unresolved', status: 'open', customer: 'cus_owner', livemode: false, default_payment_method: null });
  assert.equal((await f.service.run('job')).status, 'refused'); assert.equal(f.writes.length, 0);
});
