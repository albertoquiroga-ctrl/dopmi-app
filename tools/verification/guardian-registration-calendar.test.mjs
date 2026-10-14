import { test } from 'node:test';
import assert from 'node:assert/strict';
import { guardianRegistrationEvaluation } from '../../supabase/functions/_shared/guardian-registration-calendar.mjs';

const seconds = value => Date.parse(value) / 1000;
test('registration anniversary recovers day 31 after an omitted short month', () => {
  const registered = seconds('2027-01-31T23:17:09Z');
  assert.equal(guardianRegistrationEvaluation(registered, 1), seconds('2027-02-28T23:17:09Z'));
  assert.equal(guardianRegistrationEvaluation(registered, 2), seconds('2027-03-31T23:17:09Z'));
  assert.equal(guardianRegistrationEvaluation(registered, 3), seconds('2027-04-30T23:17:09Z'));
});
test('leap year and year boundary preserve original UTC anniversary and time', () => {
  const registered = seconds('2023-12-31T00:00:01Z');
  assert.equal(guardianRegistrationEvaluation(registered, 2), seconds('2024-02-29T00:00:01Z'));
  assert.equal(guardianRegistrationEvaluation(registered, 14), seconds('2025-02-28T00:00:01Z'));
  assert.equal(guardianRegistrationEvaluation(registered, 15), seconds('2025-03-31T00:00:01Z'));
});
test('explicit offset becomes UTC once; delayed first charge cannot move anniversary', () => {
  const registered = seconds('2026-01-30T20:15:00-06:00');
  assert.equal(guardianRegistrationEvaluation(registered, 1), seconds('2026-02-28T02:15:00Z'));
  assert.equal(guardianRegistrationEvaluation(registered, 3), seconds('2026-04-30T02:15:00Z'));
});
test('rejects invalid origin and non-future or unbounded cycle numbers', () => {
  for (const date of [NaN, 0, -1, 1.5, 4102444801])
    assert.throws(() => guardianRegistrationEvaluation(date, 1), /invalid/);
  for (const cycle of [NaN, 0, -1, 1.5, 1201, '1'])
    assert.throws(() => guardianRegistrationEvaluation(1700000000, cycle), /invalid/);
});
