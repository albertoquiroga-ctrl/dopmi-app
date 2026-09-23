import { test } from 'node:test';
import assert from 'node:assert/strict';
import { planGuardianAllocation } from '../../supabase/functions/_shared/guardian-allocation.mjs';

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
