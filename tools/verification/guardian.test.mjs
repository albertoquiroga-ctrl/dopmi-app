import { readGuardianPaidEvidence } from '../../supabase/functions/_shared/guardian-reconciliation.mjs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { planGuardianAllocation, trimGuardianReservation } from '../../supabase/functions/_shared/guardian-allocation.mjs';
import { guardianInvoiceCycleKey, guardianRenewalCandidate, guardianFinalizedInvoiceForCollection, guardianPaidInvoice } from '../../supabase/functions/_shared/guardian-billing.mjs';

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

test('confirmed fee reduces only the tail of the full reservation', () => {
  const held = [{ expense_id: 'a', amount_cents: 2500 },
    { expense_id: 'b', amount_cents: 2000 }, { expense_id: 'c', amount_cents: 400 }];
  assert.deepEqual(trimGuardianReservation(4314, 4900, held), [
    { expense_id: 'a', amount_cents: 2500 }, { expense_id: 'b', amount_cents: 1814 },
  ]);
  assert.deepEqual(trimGuardianReservation(4900, 4900, held), held);
  assert.deepEqual(held[1], { expense_id: 'b', amount_cents: 2000 });
});

test('a missing, duplicated or insufficient hold cannot produce an allocation', () => {
  const held = [{ expense_id: 'a', amount_cents: 3000 }, { expense_id: 'b', amount_cents: 1900 }];
  for (const change of [() => trimGuardianReservation(4901, 4900, held),
    () => trimGuardianReservation(4314, 5000, held),
    () => trimGuardianReservation(4314, 4900, []),
    () => trimGuardianReservation(4314, 4900, [{ ...held[0] }, { ...held[0], amount_cents: 1900 }]),
    () => trimGuardianReservation(4314, 4900, [{ ...held[0], amount_cents: 0 }, held[1]])])
    assert.throws(change, TypeError);
});

const subscription = { id: 'sub_guardian1', customer: 'cus_guardian1', livemode: false,
  status: 'active', collection_method: 'send_invoice', pause_collection: { behavior: 'keep_as_draft', resumes_at: null } };
const invoice = { id: 'in_cycle1', parent: { subscription_details: { subscription: subscription.id } },
  customer: subscription.customer,
  livemode: false, billing_reason: 'subscription_cycle', status: 'draft', auto_advance: false,
  collection_method: 'send_invoice', currency: 'mxn', total: 5000, amount_due: 5000,
  amount_paid: 0, amount_remaining: 5000, attempted: false, attempt_count: 0, starting_balance: 0,
  total_taxes: [], total_discount_amounts: [],
  lines: { has_more: false, total_count: 1, data: [{ amount: 5000, currency: 'mxn', quantity: 1,
    pricing: { price_details: { price: 'price_guardian1' } },
    parent: { subscription_item_details: { subscription: subscription.id } },
    taxes: [], discount_amounts: [] }] } };
const expected = { subscription_id: subscription.id, customer_id: subscription.customer,
  price_id: 'price_guardian1', gross_cents: 5000 };

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
    { amount_remaining: 4900 }, { attempt_count: 1 }, { starting_balance: -100 },
    { attempted: true }, { livemode: true },
    { billing_reason: 'subscription_create' },
    { parent: { subscription_details: { subscription: 'sub_other' } } }])
    assert.throws(() => guardianRenewalCandidate({ ...invoice, ...changed }, subscription, expected));
  assert.throws(() => guardianRenewalCandidate(invoice, subscription, { ...expected, gross_cents: 20000 }),
    /invoice_amount_mismatch/);
  const changedLine = entry => ({ ...invoice, lines: { ...invoice.lines, data: [entry] } });
  const line = invoice.lines.data[0];
  for (const altered of [{ amount: 4900 }, { quantity: 2 }, { taxes: [{ amount: 100 }] },
    { discount_amounts: [{ amount: 100 }] },
    { pricing: { price_details: { price: 'price_other' } } },
    { parent: { subscription_item_details: { subscription: 'sub_other' } } }])
    assert.throws(() => guardianRenewalCandidate(changedLine({ ...line, ...altered }), subscription, expected),
      /invoice_line_mismatch/);
  assert.throws(() => guardianRenewalCandidate({ ...invoice, lines: { ...invoice.lines, has_more: true } },
    subscription, expected), /invoice_line_mismatch/);
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

const paid = { ...invoice, status: 'paid', amount_paid: 5000, amount_remaining: 0,
  attempted: true, attempt_count: 1 };
const paymentIntent = { id: 'pi_guardian1', livemode: false, customer: subscription.customer,
  currency: 'mxn', status: 'succeeded', amount_received: 5000,
  latest_charge: { id: 'ch_guardian1', livemode: false, payment_intent: 'pi_guardian1',
    currency: 'mxn', amount: 5000, paid: true, captured: true, disputed: false,
    amount_refunded: 0, balance_transaction: { currency: 'mxn', amount: 5000, fee: 586 } } };
const invoicePayments = { has_more: false, data: [{ id: 'inpay_guardian1', invoice: invoice.id,
  status: 'paid', amount_requested: 5000, amount_paid: 5000,
  payment: { type: 'payment_intent', payment_intent: paymentIntent.id } }] };

test('paid invoice needs processor confirmation before calculating the full assignable net', () => {
  const saved = { ...expected, invoice_id: paid.id };
  assert.deepEqual(guardianPaidInvoice(paid, subscription, saved, invoicePayments, paymentIntent), {
    invoice_id: paid.id, subscription_id: subscription.id,
    invoice_payment_id: 'inpay_guardian1',
    payment_intent_id: paymentIntent.id, charge_id: paymentIntent.latest_charge.id,
    gross_cents: 5000, platform_fee_cents: 100, stripe_fee_cents: 586, net_cents: 4314,
  });
  assert.equal(guardianPaidInvoice({ ...paid, attempt_count: 2 }, subscription, saved,
    { ...invoicePayments, data: [
      { id: 'inpay_failed', invoice: paid.id, status: 'open', amount_paid: 0 },
      ...invoicePayments.data,
    ] }, paymentIntent).net_cents, 4314);
  for (const changed of [{ amount_paid: 0 }, { amount_remaining: 5000 }, { status: 'open' },
    { auto_advance: true }, { attempt_count: 0 }])
    assert.throws(() => guardianPaidInvoice({ ...paid, ...changed }, subscription, saved,
      invoicePayments, paymentIntent));
  assert.throws(() => guardianPaidInvoice(paid, subscription, { ...saved, invoice_id: 'in_other' },
    invoicePayments, paymentIntent), /invoice_identity_mismatch/);
  for (const changed of [{ invoice: 'in_other' }, { amount_paid: 4900 }, { status: 'open' },
    { payment: { type: 'payment_intent', payment_intent: 'pi_other' } }])
    assert.throws(() => guardianPaidInvoice(paid, subscription, saved,
      { ...invoicePayments, data: [{ ...invoicePayments.data[0], ...changed }] }, paymentIntent),
    /invoice_payment_mismatch/);
  assert.throws(() => guardianPaidInvoice(paid, subscription, saved,
    { ...invoicePayments, has_more: true }, paymentIntent), /invoice_payment_mismatch/);
  assert.throws(() => guardianPaidInvoice(paid, subscription, saved,
    { ...invoicePayments, data: [
      { id: 'inpay_other', invoice: paid.id, status: 'open', amount_paid: 100 },
      ...invoicePayments.data,
    ] }, paymentIntent), /invoice_payment_mismatch/);
});

test('paid invoice rejects refunded, disputed, unmatched or fee-pending charges', () => {
  const saved = { ...expected, invoice_id: paid.id };
  const withCharge = patch => ({ ...paymentIntent, latest_charge: { ...paymentIntent.latest_charge, ...patch } });
  for (const changed of [{ amount_refunded: 5000 }, { disputed: true }, { paid: false },
    { amount: 4900 }, { currency: 'usd' }, { payment_intent: 'pi_other' }, { livemode: true }])
    assert.throws(() => guardianPaidInvoice(paid, subscription, saved, invoicePayments, withCharge(changed)),
      /charge_not_confirmed/);
  assert.throws(() => guardianPaidInvoice(paid, subscription, saved,
    invoicePayments, { ...paymentIntent, amount_received: 4900 }), /charge_not_confirmed/);
  assert.throws(() => guardianPaidInvoice(paid, subscription, saved,
    invoicePayments, withCharge({ balance_transaction: 'txn_not_expanded' })), /processor_fee_not_ready/);
  assert.throws(() => guardianPaidInvoice(paid, subscription, saved,
    invoicePayments, withCharge({ balance_transaction: { currency: 'mxn', amount: 5000, fee: 4900 } })),
  /processor_fee_exceeds_payment/);
});

// Evidence retrieval uses fresh Stripe reads and the server registry only.
const registeredPlan = { donor_id: '00000000-0000-4000-8000-000000000001',
  stripe_subscription_id: subscription.id, stripe_customer_id: subscription.customer,
  stripe_price_id: expected.price_id, gross_cents: 5000, status: 'active' };
function evidenceReader({ inv = { ...paid, payments: invoicePayments },
  sub = subscription, intent = paymentIntent, plan = registeredPlan } = {}) {
  const calls = [];
  const read = (name, result) => async (...args) => { calls.push([name, ...args]); return result; };
  return { calls, deps: {
    stripe: { invoices: { retrieve: read('invoice', inv) },
      subscriptions: { retrieve: read('subscription', sub) },
      paymentIntents: { retrieve: read('intent', intent) } },
    lookupSubscription: read('registry', plan),
  } };
}

test('server evidence reader resolves ownership and net from fresh authoritative reads', async () => {
  const { calls, deps } = evidenceReader();
  const result = await readGuardianPaidEvidence(deps, paid.id);
  assert.equal(result.donor_id, registeredPlan.donor_id);
  assert.equal(result.net_cents, 4314);
  assert.equal(result.payment_intent_id, paymentIntent.id);
  assert.deepEqual(calls, [ ['invoice', paid.id, { expand: ['payments'] }],
    ['registry', subscription.id], ['subscription', subscription.id],
    ['intent', paymentIntent.id, { expand: ['latest_charge.balance_transaction'] }] ]);
  assert.deepEqual(await readGuardianPaidEvidence(deps, paid.id), result);
});

test('cancellation preserves paid evidence but still forbids new renewal collection', async () => {
  const canceled = { ...subscription, status: 'canceled' };
  const { deps } = evidenceReader({ sub: canceled, plan: { ...registeredPlan, status: 'canceled' } });
  assert.equal((await readGuardianPaidEvidence(deps, paid.id)).net_cents, 4314);
  assert.throws(() => guardianRenewalCandidate(invoice, canceled, expected), /billing_not_fail_closed/);
  assert.throws(() => guardianFinalizedInvoiceForCollection({ ...invoice, status: 'open' }, canceled,
    { ...expected, invoice_id: invoice.id }), /billing_not_fail_closed/);
  for (const status of ['past_due', 'unpaid', 'incomplete']) {
    const { deps } = evidenceReader({ sub: { ...subscription, status } });
    await assert.rejects(readGuardianPaidEvidence(deps, paid.id), /billing_not_fail_closed/);
  }
});

test('reader rejects unsafe invoice identifiers, live mode and unpaid invoices before ownership lookup', async () => {
  const { deps, calls } = evidenceReader();
  await assert.rejects(readGuardianPaidEvidence(deps, 'in_bad?expand=customer'), /invalid_invoice_identity/);
  assert.equal(calls.length, 0);
  for (const patch of [{ id: 'in_other' }, { livemode: true }, { status: 'open' }]) {
    const reader = evidenceReader({ inv: { ...paid, payments: invoicePayments, ...patch } });
    await assert.rejects(readGuardianPaidEvidence(reader.deps, paid.id), /invoice_not_confirmed/);
    assert.equal(reader.calls.length, 1);
  }
});

test('reader rejects missing registry, wrong customer and incomplete payment lists', async () => {
  for (const plan of [null, { ...registeredPlan, stripe_subscription_id: 'sub_other' },
    { ...registeredPlan, donor_id: null }]) {
    const reader = evidenceReader({ plan });
    await assert.rejects(readGuardianPaidEvidence(reader.deps, paid.id), /guardian_subscription_not_registered/);
    assert.equal(reader.calls.length, 2);
  }
  const wrong = evidenceReader({ plan: { ...registeredPlan, stripe_customer_id: 'cus_other' } });
  await assert.rejects(readGuardianPaidEvidence(wrong.deps, paid.id), /invoice_identity_mismatch/);
  for (const payments of [{ ...invoicePayments, has_more: true }, { has_more: false, data: [] },
    { has_more: false, data: [...invoicePayments.data, ...invoicePayments.data] }]) {
    const reader = evidenceReader({ inv: { ...paid, payments } });
    await assert.rejects(readGuardianPaidEvidence(reader.deps, paid.id), /invoice_payment_mismatch/);
    assert.equal(reader.calls.length, 2);
  }
});

test('fee unavailable or refunded payments produce no evidence; retry re-reads Stripe', async () => {
  const reader = evidenceReader({ intent: { ...paymentIntent,
    latest_charge: { ...paymentIntent.latest_charge, balance_transaction: null } } });
  await assert.rejects(readGuardianPaidEvidence(reader.deps, paid.id), /processor_fee_not_ready/);
  reader.deps.stripe.paymentIntents.retrieve = async () => structuredClone(paymentIntent);
  assert.equal((await readGuardianPaidEvidence(reader.deps, paid.id)).net_cents, 4314);
  const refunded = evidenceReader({ intent: { ...paymentIntent,
    latest_charge: { ...paymentIntent.latest_charge, amount_refunded: 5000 } } });
  await assert.rejects(readGuardianPaidEvidence(refunded.deps, paid.id), /charge_not_confirmed/);
});

test('Stripe and registry failures propagate without claiming successful reconciliation', async () => {
  for (const target of ['invoice', 'registry', 'intent']) {
    const reader = evidenceReader();
    const failure = async () => { throw new Error('upstream_unavailable'); };
    if (target === 'invoice') reader.deps.stripe.invoices.retrieve = failure;
    else if (target === 'intent') reader.deps.stripe.paymentIntents.retrieve = failure;
    else reader.deps.lookupSubscription = failure;
    await assert.rejects(readGuardianPaidEvidence(reader.deps, paid.id), /upstream_unavailable/);
  }
});
