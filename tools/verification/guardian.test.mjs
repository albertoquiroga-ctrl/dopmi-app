import { test } from 'node:test';
import assert from 'node:assert/strict';
import { planGuardianAllocation } from '../../supabase/functions/_shared/guardian-allocation.mjs';
import { guardianInvoiceCycleKey, guardianRenewalCandidate, guardianFinalizedInvoiceForCollection } from '../../supabase/functions/_shared/guardian-billing.mjs';

const expense = (id, available_cents, urgent, approved_at, payable = true) =>
  ({ id, available_cents, urgent, approved_at, payable });

test('urgency wins, then oldest approval, then id; fill each expense before the next', () => {
  const candidates = [
    expense('z', 3000, false, '2026-09-01T00:00:00Z'),
    expense('b', 2000, true, '2026-09-03T00:00:00Z'),
    expense('c', 1000, true, '2026-09-03T00:00:00Z'),
    expense('a', 2500, true, '2026-09-02T00:00:00Z'),
  ];
  assert.deepEqual(planGuardianAllocation(4500, candidates), { fully_allocated: true, allocations: [
    { expense_id: 'a', amount_cents: 2500 }, { expense_id: 'b', amount_cents: 2000 },
  ] });
  assert.equal(candidates[0].id, 'z');
  assert.deepEqual(planGuardianAllocation(5500, candidates).allocations.map(a => a.expense_id), ['a', 'b', 'c']);
});

test('insufficient approved capacity skips entire monthly net amount without a partial plan', () => {
  assert.deepEqual(planGuardianAllocation(5001, [expense('a', 5000, true, '2026-09-01T00:00:00Z')]),
    { fully_allocated: false, allocations: [] });
  assert.deepEqual(planGuardianAllocation(1000, []), { fully_allocated: false, allocations: [] });
});

test('unpayable and exhausted expenses cannot absorb a quota', () => {
  const candidates = [expense('a', 2000, true, '2026-09-01T00:00:00Z', false),
    expense('b', 0, true, '2026-09-01T00:00:00Z'),
    expense('c', 1100, false, '2026-09-02T00:00:00Z')];
  assert.deepEqual(planGuardianAllocation(1100, candidates), { fully_allocated: true,
    allocations: [{ expense_id: 'c', amount_cents: 1100 }] });
  assert.deepEqual(planGuardianAllocation(1101, candidates), { fully_allocated: false, allocations: [] });
});

test('rejects invalid amounts, duplicate expenses and missing approval dates', () => {
  const valid = expense('a', 1000, false, '2026-09-01T00:00:00Z');
  for (const amount of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1])
    assert.throws(() => planGuardianAllocation(amount, [valid]), TypeError);
  assert.throws(() => planGuardianAllocation(1000, [valid, valid]), TypeError);
  assert.throws(() => planGuardianAllocation(1000, [{ ...valid, approved_at: '' }]), TypeError);
  assert.throws(() => planGuardianAllocation(1000, [{ ...valid, available_cents: -1 }]), TypeError);
});

const subscription = { id: 'sub_guardian1', customer: 'cus_guardian1', livemode: false,
  status: 'active', collection_method: 'send_invoice', pause_collection: { behavior: 'keep_as_draft', resumes_at: null } };
const invoice = { id: 'in_cycle1', parent: { subscription_details: { subscription: subscription.id } },
  customer: subscription.customer,
  livemode: false, billing_reason: 'subscription_cycle', status: 'draft', auto_advance: false,
  collection_method: 'send_invoice', currency: 'mxn', total: 5000, amount_due: 5000,
  amount_paid: 0, attempted: false, starting_balance: 0 };
const expected = { subscription_id: subscription.id, customer_id: subscription.customer, gross_cents: 5000 };

test('renewal requires a paused subscription and an exact unpaid draft invoice before reserving', () => {
  assert.deepEqual(guardianRenewalCandidate(invoice, subscription, expected),
    { invoice_id: invoice.id, subscription_id: subscription.id, gross_cents: 5000 });
  assert.throws(() => guardianRenewalCandidate({ ...invoice, auto_advance: true }, subscription, expected),
    /invoice_not_safe_to_collect/);
  assert.throws(() => guardianRenewalCandidate(invoice, { ...subscription, pause_collection: null }, expected),
    /billing_not_fail_closed/);
  assert.throws(() => guardianRenewalCandidate(invoice,
    { ...subscription, pause_collection: { behavior: 'keep_as_draft', resumes_at: 1790000000 } }, expected),
  /billing_not_fail_closed/);
  assert.throws(() => guardianRenewalCandidate({ ...invoice, status: 'paid' }, subscription, expected),
    /invoice_not_safe_to_collect/);
});

test('renewal rejects another account, changed price, credited invoice, live mode or initial invoice', () => {
  for (const changed of [{ customer: 'cus_other' }, { amount_due: 4900 }, { total: 4900 },
    { starting_balance: -100 }, { attempted: true }, { livemode: true },
    { billing_reason: 'subscription_create' },
    { parent: { subscription_details: { subscription: 'sub_other' } } }])
    assert.throws(() => guardianRenewalCandidate({ ...invoice, ...changed }, subscription, expected));
  assert.throws(() => guardianRenewalCandidate(invoice, subscription, { ...expected, gross_cents: 20000 }),
    /invoice_amount_mismatch/);
});

test('Stripe invoice identity yields a stable cycle key without sharing one between invoices', async () => {
  const key = await guardianInvoiceCycleKey(subscription.id, invoice.id);
  assert.match(key, /^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(key, await guardianInvoiceCycleKey(subscription.id, invoice.id));
  assert.notEqual(key, await guardianInvoiceCycleKey(subscription.id, 'in_cycle2'));
  assert.notEqual(key, await guardianInvoiceCycleKey('sub_guardian2', invoice.id));
  await assert.rejects(guardianInvoiceCycleKey(subscription.id, 'wrong'), /invalid_invoice_identity/);
});

test('finalized invoice keeps the same reserved identity and remains unattempted while collection stays paused', () => {
  const finalized = { ...invoice, status: 'open' };
  const reserved = { ...expected, invoice_id: invoice.id };
  assert.deepEqual(guardianFinalizedInvoiceForCollection(finalized, subscription, reserved),
    { invoice_id: invoice.id, subscription_id: subscription.id, gross_cents: 5000 });
  for (const changed of [{ id: 'in_other' }, { amount_due: 4900 }, { attempted: true },
    { amount_paid: 5000 }, { auto_advance: true }, { status: 'paid' }])
    assert.throws(() => guardianFinalizedInvoiceForCollection({ ...finalized, ...changed }, subscription, reserved));
  assert.throws(() => guardianFinalizedInvoiceForCollection(finalized,
    { ...subscription, pause_collection: null }, reserved), /billing_not_fail_closed/);
  assert.throws(() => guardianFinalizedInvoiceForCollection(finalized, subscription,
    { ...reserved, invoice_id: 'in_other' }), /invoice_identity_mismatch/);
});
