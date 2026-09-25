import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { createInterface } from 'node:readline';
import Stripe from 'stripe';
import { guardianRefundService } from '../../supabase/functions/_shared/guardian-refunds.mjs';
import { startGuardianResponseLossProxy } from './guardian-response-loss-proxy.mjs';

// Operator-driven acceptance only. RPC requests must be relayed unchanged to
// dopmi_guardian_refund_server in the test project. No service key is needed.
// This does not create a refund or a fixture, and never runs automatically.
const [flag, cycleId, transferId] = process.argv.slice(2);
assert.equal(process.argv.length, 5);
assert.equal(flag, '--execute-test-reversal');
assert.match(cycleId ?? '', /^[0-9a-f-]{36}$/);
assert.match(transferId ?? '', /^tr_[A-Za-z0-9]+$/);
const input = createInterface({ input: process.stdin, terminal: false });
let pending, sequence = 0, proxy, attempted = false, permit, binding;
const emit = value => process.stdout.write(`${JSON.stringify(value)}\n`);
input.on('line', line => {
  if (!pending) return;
  const current = pending;
  pending = null;
  clearTimeout(current.timer);
  try {
    const response = JSON.parse(line);
    assert.equal(response.id, current.id);
    assert.equal(response.ok, true);
    current.resolve(response.result);
  } catch { current.reject(new Error('rpc_relay_failed')); }
});
input.on('close', () => {
  if (pending) {
    clearTimeout(pending.timer);
    pending.reject(new Error('rpc_relay_closed'));
    pending = null;
  }
});
const rpc = async (operation, data) => {
  assert.equal(data.cycle_id, cycleId);
  assert.ok(['get', 'observe', 'claim', 'authorize', 'confirmed', 'complete', 'fail', 'checked'].includes(operation));
  const result = await new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      pending = null;
      reject(new Error('rpc_relay_timeout'));
    }, 90000);
    pending = { id, resolve, reject, timer };
    emit({ type: 'rpc', id, operation, data });
  });
  if (operation === 'claim' && result) {
    binding = result.reversals.find(r => r.transfer_id === transferId);
    assert.ok(binding && !binding.reversal_id);
    assert.equal(result.cycle_id, cycleId);
  }
  if (operation === 'authorize') {
    assert.equal(data.expense_id, binding?.expense_id);
    assert.equal(result?.allowed, true);
    assert.equal(result.key, `guardian-reversal:${cycleId}:${binding.expense_id}`);
    permit = result.key;
  }
  return result;
};
try {
  const raw = (await readFile(join(process.env.LOCALAPPDATA, 'Dopmi', 'acceptance', 'stripe-test.env'), 'utf8')).trim();
  const match = /^STRIPE_SECRET_KEY_H4_TEST=((?:rk|sk)_test_[A-Za-z0-9]+)$/.exec(raw);
  assert.ok(match);
  const options = { apiVersion: '2026-08-26.dahlia', maxNetworkRetries: 0,
    timeout: 20000, httpClient: Stripe.createFetchHttpClient() };
  const stripe = new Stripe(match[1], options);
  const guarded = {
    charges: { retrieve: (...args) => stripe.charges.retrieve(...args) },
    refunds: { list: (...args) => stripe.refunds.list(...args) },
    transfers: {
      retrieve: (...args) => stripe.transfers.retrieve(...args),
      listReversals: (...args) => stripe.transfers.listReversals(...args),
      createReversal: async (id, body, request) => {
        assert.equal(id, transferId);
        assert.equal(attempted, false);
        assert.ok(permit);
        assert.equal(request.idempotencyKey, permit);
        assert.deepEqual(body, { amount: binding.amount_cents,
          metadata: { dopmi_guardian_cycle: cycleId, dopmi_guardian_expense: binding.expense_id } });
        attempted = true;
        proxy = await startGuardianResponseLossProxy({ testKey: match[1],
          path: `/v1/transfers/${transferId}/reversals`, idempotencyKey: permit });
        const lossy = new Stripe(match[1], { ...options, host: '127.0.0.1', port: proxy.port, protocol: 'http' });
        return lossy.transfers.createReversal(id, body, request);
      },
    },
  };
  await guardianRefundService({ stripe: guarded, rpc, logger: { log() {}, error() {}, warn() {} } }).reconcileCycle(cycleId);
  emit({ type: 'result', responseLossObserved: false, attempted });
} catch (error) {
  emit({ type: 'result', errorType: error.type ?? error.name,
    attempted, evidence: proxy?.evidence() ?? [] });
  process.exitCode = 1;
} finally {
  await proxy?.close();
  input.close();
}
