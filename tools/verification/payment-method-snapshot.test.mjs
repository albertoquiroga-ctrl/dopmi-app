import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chargePaymentMethodSnapshot } from '../../supabase/functions/_shared/payment-method-snapshot.mjs';

test('historical card display whitelists only exact Charge brand and last4', () => {
  const charge = { livemode: false, payment_method: 'pm_removed', customer: 'cus_private',
    payment_method_details: { type: 'card', card: { brand: 'mastercard', last4: '0042',
      number: 'synthetic-full-number', fingerprint: 'synthetic-fingerprint', exp_year: 2040,
      wallet: { type: 'google_pay' }, checks: { cvc_check: 'pass' } } } };
  const before = structuredClone(charge);
  assert.deepEqual(chargePaymentMethodSnapshot(charge), {
    payment_method: { type: 'card', brand: 'mastercard', last4: '0042' },
  });
  assert.deepEqual(charge, before);
  // A removed current method does not alter facts retained on the Charge.
  delete charge.payment_method;
  assert.deepEqual(chargePaymentMethodSnapshot(charge), chargePaymentMethodSnapshot(before));
});

test('missing, live, unsupported and malformed card data remains absent without guessing', () => {
  const valid = { livemode: false, payment_method_details: { type: 'card', card: { brand: 'visa', last4: '1234' } } };
  for (const charge of [null, {}, { ...valid, livemode: true }, { ...valid, livemode: undefined },
    { ...valid, payment_method_details: { type: 'link', card: valid.payment_method_details.card } },
    { livemode: false, payment_method: { card: { brand: 'visa', last4: '4242' } } },
    ...[
      { brand: '<script>', last4: '1234' }, { brand: 'Visa', last4: '1234' },
      { brand: 'sk_test_synthetic', last4: '1234' },
      { brand: '4242424242424242', last4: '1234' }, { brand: 'x'.repeat(33), last4: '1234' },
      { brand: 'visa', last4: 4242 }, { brand: 'visa', last4: '12345' },
      { brand: 'visa', last4: '12a4' }, { brand: 'visa', last4: null },
    ].map(card => ({ ...valid, payment_method_details: { type: 'card', card } })),
  ]) assert.deepEqual(chargePaymentMethodSnapshot(charge), {});
});

test('documented processor brands are retained verbatim instead of mapping unknown brands to Visa', () => {
  for (const brand of ['amex','cartes_bancaires','diners','discover','eftpos_au',
    'jcb','link','mastercard','unionpay','visa','unknown']) {
    assert.deepEqual(chargePaymentMethodSnapshot({livemode:false,
      payment_method_details:{type:'card',card:{brand,last4:'0001'}}}),
    {payment_method:{type:'card',brand,last4:'0001'}});
  }
});
