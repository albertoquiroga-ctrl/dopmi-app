import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { requireExpectedLivemode, requireStripeKey, requireTestKey, stripeApi, verifySignature,
  paymentService } from '../../supabase/functions/_shared/payments.mjs';
import { chargePaymentMethodSnapshot } from '../../supabase/functions/_shared/payment-method-snapshot.mjs';
import { oneoffNativeService, oneoffConsentVersion } from '../../supabase/functions/_shared/oneoff-native.mjs';
import { oneoffCaseService } from '../../supabase/functions/_shared/oneoff-case.mjs';
import { guardianPaidInvoice } from '../../supabase/functions/_shared/guardian-billing.mjs';
import { readGuardianPaidEvidence } from '../../supabase/functions/_shared/guardian-reconciliation.mjs';
import { guardianActivationService, guardianConsentVersion } from '../../supabase/functions/_shared/guardian-activation.mjs';
import { guardianScheduleService } from '../../supabase/functions/_shared/guardian-schedule.mjs';
import { guardianChangeService } from '../../supabase/functions/_shared/guardian-changes.mjs';
import { guardianCollectionService } from '../../supabase/functions/_shared/guardian-collection.mjs';
import { guardianRecoveryService } from '../../supabase/functions/_shared/guardian-recovery.mjs';
import { guardianMethodService } from '../../supabase/functions/_shared/guardian-method.mjs';
import { guardianMethodListService } from '../../supabase/functions/_shared/guardian-method-list.mjs';
import { guardianRefundService } from '../../supabase/functions/_shared/guardian-refunds.mjs';
import { guardianService } from '../../supabase/functions/_shared/guardian-service.mjs';
import { guardianRegistrationWorker } from '../../supabase/functions/_shared/guardian-registration-worker.mjs';
import { guardianRegistrationConsumer } from '../../supabase/functions/_shared/guardian-registration-consumer.mjs';
import { guardianRegistrationBankAction } from '../../supabase/functions/_shared/guardian-registration-bank-action.mjs';
import { registrationSettlementEvidence } from '../../supabase/functions/_shared/guardian-registration-settlement.mjs';
import { nativeSavedCardService } from '../../supabase/functions/_shared/native-saved-card.mjs';
import { nativeSavedWalletService } from '../../supabase/functions/_shared/native-saved-wallet.mjs';
import { savedCardService, savedCardConsentVersion } from '../../supabase/functions/_shared/saved-card.mjs';
import { savedCardMethodService } from '../../supabase/functions/_shared/saved-card-method.mjs';
import { guardianPreflight } from '../../supabase/functions/_shared/guardian-preflight.mjs';

const owner = '90000000-0000-4000-8000-000000000001';
const caseId = '91000000-0000-4000-8000-000000000001';
const requestKey = '92000000-0000-4000-8000-000000000001';
const donationId = '93000000-0000-4000-8000-000000000001';
const attemptId = '94000000-0000-4000-8000-000000000001';
const cycleId = '95000000-0000-4000-8000-000000000001';
const liveConsent = 'oneoff-live-2026-10-28';
const card = { type: 'card', card: { brand: 'visa', last4: '4242' } };

for (const channel of ['activation', 'guardian-method', 'saved-card']) {
  test(`LIVE ${channel} resumes its bound cs_live Checkout without creating a replacement`, async () => {
    const sessionId = 'cs_live_synthetic';
    const expiresAt = new Date(Date.now() + 3600000).toISOString();
    const job = { id: requestKey, cycle_id: cycleId, request_key: requestKey,
      session_id: sessionId, status: 'pending', plan_status: 'active',
      customer_id: 'cus_mode', gross_cents: 5000, checkout_expires_at: expiresAt };
    const session = { id: sessionId, livemode: true, mode: channel === 'activation' ? 'payment' : 'setup',
      customer: 'cus_mode', customer_creation: 'always', currency: 'mxn',
      client_reference_id: channel === 'activation' ? cycleId : requestKey,
      amount_total: 5000, amount_subtotal: 5000, expires_at: Math.floor(Date.parse(expiresAt) / 1000),
      automatic_tax: { enabled: false }, total_details: { amount_tax: 0, amount_discount: 0, amount_shipping: 0 },
      status: 'open', payment_status: 'unpaid', url: 'https://checkout.stripe.com/synthetic',
      metadata: { dopmi_saved_card_job: requestKey, consent_version: savedCardConsentVersion } };
    const reads = [], writes = [];
    const dependencies = { expectedLivemode: true, returnUrl: 'https://example.test/return',
      rpc: async operation => {
        if (['prepare', 'get'].includes(operation)) return structuredClone(job);
        if (operation === 'claim') return null;
        writes.push(operation); assert.fail(operation);
      }, stripe: { checkout: { sessions: {
        retrieve: async id => { reads.push(id); return structuredClone(session); },
        create: () => assert.fail('bound checkout cannot create a replacement'),
      } } } };
    const factory = channel === 'activation' ? guardianActivationService :
      channel === 'guardian-method' ? guardianMethodService : savedCardService;
    const service = factory(dependencies);
    const input = { key: requestKey, consent: true,
      consent_version: channel === 'activation' ? guardianConsentVersion : savedCardConsentVersion };
    assert.equal((await service.checkout(owner, input)).checkout_url, session.url);
    assert.deepEqual(reads, [sessionId]);
    session.livemode = false;
    await assert.rejects(service.checkout(owner, input));
    assert.deepEqual(writes, []);
  });
}

test('server mode and Stripe credential families are explicit booleans with legacy TEST default', () => {
  assert.equal(requireExpectedLivemode(false), false);
  assert.equal(requireExpectedLivemode(true), true);
  for (const prefix of ['sk', 'rk']) {
    requireStripeKey(`${prefix}_test_synthetic`);
    requireStripeKey(`${prefix}_live_synthetic`, true);
    assert.throws(() => requireStripeKey(`${prefix}_live_synthetic`), { code: 'payments_not_configured' });
    assert.throws(() => requireStripeKey(`${prefix}_test_synthetic`, true), { code: 'payments_not_configured' });
  }
  requireTestKey('sk_test_synthetic');
  assert.throws(() => requireTestKey('sk_live_synthetic'), { code: 'payments_not_configured' });
  for (const value of [null, 'true', 'false', 1, 0, {}, []]) {
    assert.throws(() => requireExpectedLivemode(value), { code: 'payments_not_configured' });
    assert.throws(() => requireStripeKey('sk_live_synthetic', value), { code: 'payments_not_configured' });
  }
  assert.throws(() => requireStripeKey('pk_live_synthetic', true), { code: 'payments_not_configured' });
});

test('every financial service rejects a nonboolean mode before using injected dependencies', () => {
  const factories = [paymentService, oneoffNativeService, oneoffCaseService,
    guardianActivationService, guardianScheduleService, guardianChangeService,
    guardianCollectionService, guardianRecoveryService, guardianMethodService,
    guardianMethodListService, guardianRefundService, guardianService,
    guardianRegistrationWorker, guardianRegistrationConsumer, guardianRegistrationBankAction,
    nativeSavedCardService, nativeSavedWalletService,
    savedCardService, savedCardMethodService];
  for (const factory of factories)
    assert.throws(() => factory({ expectedLivemode: 'true' }), { code: 'payments_not_configured' }, factory.name);
});

test('LIVE transport keeps its historical API payload and rejects explicitly foreign or malformed modes', async () => {
  const calls = [];
  let result = { id: 'pi_live', livemode: true };
  const api = stripeApi('rk_live_synthetic', async (url, options) => {
    calls.push({ url, options });
    return Response.json(result);
  }, { expectedLivemode: true });
  assert.equal((await api('payment_intents', { amount: 2000, currency: 'mxn' }, 'stable-key')).id, 'pi_live');
  assert.equal(calls[0].url, 'https://api.stripe.com/v1/payment_intents');
  assert.equal(calls[0].options.headers['Stripe-Version'], '2025-02-24.acacia');
  assert.equal(calls[0].options.headers['Idempotency-Key'], 'stable-key');
  assert.equal(calls[0].options.body.get('amount'), '2000');
  result = { id: 'acct_platform', object: 'account' };
  assert.equal((await api('account')).id, 'acct_platform');
  for (const livemode of [false, 'true', null]) {
    result = { id: 'pi_foreign', livemode };
    await assert.rejects(api('payment_intents/pi_foreign'), { code: 'test_mode_rejected' });
  }
  const testApi = stripeApi('sk_test_synthetic', async () => Response.json({ id: 'pi_live', livemode: true }));
  await assert.rejects(testApi('payment_intents/pi_live'), { code: 'live_mode_rejected' });
});

test('valid signatures authenticate the exact expected event mode and never infer it from the signature', async () => {
  const timestamp = 1793188800;
  const secret = 'whsec_synthetic';
  const signed = event => {
    const body = JSON.stringify(event);
    const signature = createHmac('sha256', secret).update(`${timestamp}.${body}`).digest('hex');
    return { body, header: `t=${timestamp},v1=${signature}` };
  };
  for (const expectedLivemode of [false, true]) {
    const event = { id: 'evt_exactmode', livemode: expectedLivemode, type: 'payment_intent.succeeded' };
    const valid = signed(event);
    assert.deepEqual(await verifySignature(valid.body, valid.header, secret, timestamp * 1000, { expectedLivemode }), event);
    for (const livemode of [!expectedLivemode, 'true', null, undefined]) {
      const foreign = signed({ ...event, livemode });
      await assert.rejects(verifySignature(foreign.body, foreign.header, secret, timestamp * 1000,
        { expectedLivemode }), { code: expectedLivemode ? 'invalid_live_event' : 'invalid_test_event' });
    }
    await assert.rejects(verifySignature(valid.body, valid.header, 'whsec_other', timestamp * 1000,
      { expectedLivemode }), { code: 'invalid_signature' });
  }
});

test('historical card snapshots come only from the charge in the configured financial mode', () => {
  for (const expectedLivemode of [false, true]) {
    const charge = { id: 'ch_snapshot', livemode: expectedLivemode, payment_method_details: card };
    assert.deepEqual(chargePaymentMethodSnapshot(charge, { expectedLivemode }),
      { payment_method: { type: 'card', brand: 'visa', last4: '4242' } });
    for (const livemode of [!expectedLivemode, undefined, 'true'])
      assert.deepEqual(chargePaymentMethodSnapshot({ ...charge, livemode }, { expectedLivemode }), {});
  }
  assert.throws(() => chargePaymentMethodSnapshot({}, { expectedLivemode: 1 }), { code: 'payments_not_configured' });
});

test('LIVE hosted checkout always requires the native consent-bound flow before input validation or any I/O', async () => {
  const calls = { rpc: 0, stripe: 0, customer: 0 };
  const service = paymentService({ expectedLivemode: true,
    rpc: async () => { calls.rpc++; assert.fail('LIVE hosted checkout cannot prepare a donation'); },
    stripe: async () => { calls.stripe++; assert.fail('LIVE hosted checkout cannot use Stripe'); },
    lookupCustomer: async () => { calls.customer++; assert.fail('LIVE hosted checkout cannot discover a customer'); },
  });
  const validFields = { expense_id: caseId, key: requestKey, gross_cents: 2000 };
  for (const input of [undefined, null, {}, validFields,
    { ...validFields, consent: true, consent_version: 'arbitrary-consent' },
    { ...validFields, consent: true, consent_version: liveConsent, expectedLivemode: false,
      livemode: false, mode: 'test', payment_flow: 'hosted', donor_id: owner },
    { ...validFields, consent: true, consent_version: oneoffConsentVersion },
  ]) await assert.rejects(service.checkout(owner, input), { code: 'native_checkout_required', status: 409 });
  assert.deepEqual(calls, { rpc: 0, stripe: 0, customer: 0 });
});

test('legacy TEST hosted checkout retains its historical card payload and stable idempotency key', async () => {
  const input = { expense_id: caseId, key: requestKey, gross_cents: 2000 };
  const createdAt = new Date().toISOString();
  const donation = { id: donationId, gross_cents: 2000, expense_title: 'Atención veterinaria',
    payment_status: 'pending', payment_flow: 'hosted', created_at: createdAt };
  const requests = [], writes = [];
  const service = paymentService({ returnUrl: 'https://example.test/return',
    rpc: async (op, data) => {
      writes.push({ op, data });
      if (op === 'prepare') {
        assert.deepEqual(data, { actor: owner, expense_id: caseId, gross_cents: 2000, key: requestKey });
        return structuredClone(donation);
      }
      assert.equal(op, 'checkout_save');
      return {};
    }, stripe: async (path, body, key) => {
      requests.push({ path, body, key });
      return { id: 'cs_test_legacy', livemode: false, status: 'open', url: 'https://checkout.stripe.com/synthetic' };
    } });
  assert.deepEqual(await service.checkout(owner, input), { donation_id: donationId,
    url: 'https://checkout.stripe.com/synthetic', status: 'pending' });
  assert.equal(requests.length, 1);
  assert.equal(requests[0].path, 'checkout/sessions');
  assert.equal(requests[0].key, `dopmi-checkout-${donationId}`);
  assert.equal(requests[0].body.mode, 'payment');
  assert.equal(requests[0].body['payment_method_types[0]'], 'card');
  assert.equal(requests[0].body.allowed_payment_method_types, undefined);
  assert.equal(requests[0].body['payment_intent_data[metadata][dopmi_donation]'], donationId);
  assert.equal(requests[0].body['line_items[0][price_data][unit_amount]'], 2000);
  assert.equal(requests[0].body.expires_at, Math.floor(Date.parse(createdAt) / 1000) + 3600);
  assert.deepEqual(writes[1], { op: 'checkout_save', data: { donation_id: donationId,
    session_id: 'cs_test_legacy', url: 'https://checkout.stripe.com/synthetic' } });
});

function paymentFixture(expectedLivemode = true) {
  const donation = { id: donationId, donor_id: owner, rescuer_id: caseId, destination: 'acct_rescuer',
    gross_cents: 2000, currency: 'mxn', allocated_cents: 1860, refund_cents: 0,
    payment_status: 'pending', processed_at: null, transfer_status: 'pending',
    stripe_payment_intent_id: 'pi_paymentmode', created_at: new Date().toISOString() };
  const charge = { id: 'ch_paymentmode', livemode: expectedLivemode, payment_intent: 'pi_paymentmode',
    amount: 2000, currency: 'mxn', paid: true, captured: true, disputed: false, amount_refunded: 0,
    payment_method_details: card, balance_transaction: { currency: 'mxn', amount: 2000, fee: 100 } };
  const intent = { id: 'pi_paymentmode', livemode: expectedLivemode, status: 'succeeded',
    metadata: { dopmi_donation: donationId, consent_version: expectedLivemode ? liveConsent : oneoffConsentVersion },
    amount: 2000, amount_received: 2000, currency: 'mxn', latest_charge: charge };
  const transfer = { id: 'tr_paymentmode', livemode: expectedLivemode, amount: 1860, currency: 'mxn',
    destination: 'acct_rescuer', source_transaction: charge.id, transfer_group: `dopmi_${donationId}`,
    reversed: false, amount_reversed: 0 };
  const state = { rpcs: [], transferRequests: [], providerTransfers: new Map(), loseTransfer: false };
  let claimed = false;
  const service = paymentService({ expectedLivemode, logger: {},
    rpc: async (op, data) => {
      state.rpcs.push({ op, data: structuredClone(data) });
      if (op === 'get' || op === 'replay_get') return structuredClone(donation);
      if (op === 'lookup_account') return { owner_id: caseId, account_id: donation.destination };
      if (op === 'connect_save') return {};
      if (op === 'settle') {
        donation.processed_at = new Date().toISOString(); donation.payment_status = 'confirmed';
        donation.stripe_charge_id = data.charge_id; donation.stripe_payment_intent_id = data.payment_intent_id;
        return structuredClone(donation);
      }
      if (op === 'claim') {
        if (!donation.processed_at || donation.transfer_status === 'transferred' || claimed) return null;
        claimed = true;
        return { id: 'synthetic-transfer-job', lease: 'synthetic-lease', kind: 'transfer', donation_id: donationId };
      }
      if (op === 'finish_job') {
        claimed = false;
        if (data.result_id) { donation.transfer_status = 'transferred'; donation.stripe_transfer_id = data.result_id; }
        return {};
      }
      assert.fail(`unexpected RPC ${op}`);
    }, stripe: async (path, body, key) => {
      if (path.startsWith(`payment_intents/${intent.id}`)) return structuredClone(intent);
      if (path === `charges/${donation.stripe_charge_id}`) return structuredClone(charge);
      if (path === `accounts/${donation.destination}`) return { id: donation.destination, object: 'account',
        capabilities: { transfers: 'active' }, payouts_enabled: true, details_submitted: true };
      if (path === 'transfers') {
        state.transferRequests.push({ body: structuredClone(body), key });
        if (!state.providerTransfers.has(key)) state.providerTransfers.set(key, structuredClone(transfer));
        if (state.loseTransfer) { state.loseTransfer = false; throw new Error('synthetic lost transfer response'); }
        return structuredClone(state.providerTransfers.get(key));
      }
      assert.fail(`unexpected Stripe path ${path}`);
    } });
  return { donation, intent, charge, transfer, state, service };
}

test('LIVE payment settlement and worker recover one stable transfer without duplicating settlement or delivery', async () => {
  const f = paymentFixture();
  assert.equal((await f.service.settleIntent(f.intent.id, donationId)).payment_status, 'confirmed');
  const settled = f.state.rpcs.find(call => call.op === 'settle').data;
  assert.equal(settled.stripe_fee_cents, 100);
  assert.deepEqual(settled.payment_method, { type: 'card', brand: 'visa', last4: '4242' });
  f.state.loseTransfer = true;
  assert.deepEqual(await f.service.work(1), { processed: 0, failed: 1 });
  assert.equal(f.donation.transfer_status, 'pending');
  assert.deepEqual(await f.service.work(1), { processed: 1, failed: 0 });
  assert.equal(f.donation.stripe_transfer_id, f.transfer.id);
  assert.equal(f.state.providerTransfers.size, 1);
  assert.deepEqual(f.state.transferRequests[0], f.state.transferRequests[1]);
  assert.equal(f.state.transferRequests[0].key, `dopmi-transfer-${donationId}`);
  assert.equal(f.state.transferRequests[0].body.source_transaction, f.charge.id);
  assert.equal((await f.service.reprocessDonation(donationId)).transfer_status, 'transferred');
  assert.equal(f.state.transferRequests.length, 2);
  assert.equal(f.state.rpcs.filter(call => call.op === 'settle').length, 1);
});

test('payment service rejects crossed PI and Charge modes before settlement and foreign Charge bindings before transfers', async () => {
  for (const expectedLivemode of [false, true]) {
    for (const target of ['intent', 'charge']) {
      for (const livemode of [!expectedLivemode, undefined, 'true']) {
        const f = paymentFixture(expectedLivemode);
        f[target].livemode = livemode;
        await assert.rejects(f.service.settleIntent(f.intent.id, donationId), { code: 'charge_mismatch' });
        assert.equal(f.state.rpcs.length, 0);
        assert.equal(f.state.transferRequests.length, 0);
      }
    }
    for (const patch of [{ livemode: !expectedLivemode }, { id: 'ch_foreign' }, { payment_intent: 'pi_foreign' }]) {
      const f = paymentFixture(expectedLivemode);
      await f.service.settleIntent(f.intent.id, donationId);
      Object.assign(f.charge, patch);
      assert.deepEqual(await f.service.work(1), { processed: 0, failed: 1 });
      assert.equal(f.state.transferRequests.length, 0);
      assert.equal(f.donation.transfer_status, 'pending');
      assert.equal(f.state.rpcs.at(-1).data.error_code, 'charge_mismatch');
    }
  }
});

test('payment worker never confirms a crossed or malformed Transfer response as delivered', async () => {
  for (const expectedLivemode of [false, true]) {
    for (const livemode of [!expectedLivemode, undefined, 'true']) {
      const f = paymentFixture(expectedLivemode);
      await f.service.settleIntent(f.intent.id, donationId);
      f.transfer.livemode = livemode;
      assert.deepEqual(await f.service.work(1), { processed: 0, failed: 1 });
      assert.equal(f.donation.transfer_status, 'pending');
      assert.equal(f.donation.stripe_transfer_id, undefined);
      assert.equal(f.state.rpcs.at(-1).data.error_code, 'transfer_mismatch');
      assert.equal(f.state.rpcs.some(call => call.op === 'finish_job' && call.data.result_id), false);
    }
  }
});

function oneoffFixture(factory, targetField, expectedLivemode = true) {
  const consent = expectedLivemode ? liveConsent : oneoffConsentVersion;
  const input = { [targetField]: caseId, key: requestKey, gross_cents: 2000, consent: true, consent_version: consent };
  const donation = { id: donationId, donor_id: owner, [targetField]: caseId,
    idempotency_key: requestKey, gross_cents: 2000, payment_status: 'pending', payment_flow: 'native',
    consent_version: consent, created_at: new Date().toISOString() };
  const state = { loseCreate: false, mutate: value => value, creates: [], rpcs: [], intents: new Map(),
    settled: [], providerCalls: [], hostedCalls: [], mutateBind: value => value };
  const service = factory({ expectedLivemode,
    rpc: async (operation, data) => {
      state.rpcs.push({ operation, data: structuredClone(data) });
      if (operation === 'bind') {
        donation.stripe_payment_intent_id = data.payment_intent_id;
        return state.mutateBind(structuredClone(donation));
      }
      return structuredClone(donation);
    },
    stripe: { paymentIntents: {
      create: async (body, options) => {
        state.providerCalls.push('create');
        state.creates.push({ body: structuredClone(body), options: structuredClone(options) });
        if (!state.intents.has(options.idempotencyKey)) state.intents.set(options.idempotencyKey,
          { ...structuredClone(body), id: 'pi_oneoffmode', livemode: expectedLivemode,
            status: 'requires_payment_method', client_secret: 'pi_oneoffmode_secret_synthetic' });
        if (state.loseCreate) { state.loseCreate = false; throw new Error('synthetic lost creation response'); }
        return state.mutate(structuredClone(state.intents.get(options.idempotencyKey)));
      },
      retrieve: async id => {
        state.providerCalls.push('retrieve');
        assert.equal(id, 'pi_oneoffmode');
        return state.mutate(structuredClone([...state.intents.values()][0]));
      },
      cancel: () => { state.providerCalls.push('cancel'); assert.fail('fresh oneoff cannot expire'); },
    } },
    hosted: {
      checkout: async (actor, data) => {
        state.hostedCalls.push({ action: 'checkout', actor, data });
        return { url: 'https://checkout.stripe.com/synthetic' };
      },
      reprocessDonation: async id => { state.hostedCalls.push({ action: 'reprocess', id }); state.settled.push(id); },
    },
  });
  return { input, donation, state, service };
}

for (const [name, factory, field] of [
  ['expense', oneoffNativeService, 'expense_id'], ['case', oneoffCaseService, 'case_id'],
]) {
  test(`LIVE oneoff ${name} retries one stable intent with the server-selected LIVE consent`, async () => {
    const f = oneoffFixture(factory, field);
    f.state.loseCreate = true;
    await assert.rejects(f.service.submit(owner, f.input), /lost creation response/);
    const result = await f.service.submit(owner, f.input);
    assert.equal(result.status, 'pending');
    assert.equal(result.payment_client_secret, 'pi_oneoffmode_secret_synthetic');
    assert.equal(f.state.intents.size, 1);
    assert.deepEqual(f.state.creates[0], f.state.creates[1]);
    assert.equal(f.state.creates[0].body.metadata.consent_version, liveConsent);
    assert.equal(f.state.creates[0].options.idempotencyKey, `dopmi-native-oneoff-${donationId}`);
    assert.equal(f.state.creates[0].body.confirm, undefined);
    assert.deepEqual(f.state.settled, []);
    await f.service.submit(owner, f.input);
    assert.equal(f.state.creates.length, 2);
  });

  test(`oneoff ${name} rejects cross-mode evidence before binding and a forged consent before preparation`, async () => {
    for (const expectedLivemode of [false, true]) {
      const f = oneoffFixture(factory, field, expectedLivemode);
      f.state.mutate = value => ({ ...value, livemode: !expectedLivemode });
      await assert.rejects(f.service.submit(owner, f.input), { code: 'charge_mismatch' });
      assert.equal(f.donation.stripe_payment_intent_id, undefined);
      assert.equal(f.state.rpcs.some(call => call.operation === 'bind'), false);
      assert.deepEqual(f.state.settled, []);
      const forged = oneoffFixture(factory, field, expectedLivemode);
      await assert.rejects(forged.service.submit(owner, { ...forged.input,
        consent_version: expectedLivemode ? oneoffConsentVersion : liveConsent }), { code: 'payment_consent_required' });
      assert.equal(forged.state.rpcs.length, 0);
      assert.equal(forged.state.creates.length, 0);
    }
  });

  for (const action of ['submit', 'status']) {
    test(`oneoff ${name} ${action} rejects pending persisted consent from another mode or missing consent before any provider call`, async () => {
      for (const expectedLivemode of [false, true]) {
        for (const paymentFlow of ['native', 'hosted']) {
          for (const bound of [false, true]) {
            for (const storedConsent of [expectedLivemode ? oneoffConsentVersion : liveConsent, undefined]) {
              const f = oneoffFixture(factory, field, expectedLivemode);
              f.donation.payment_flow = paymentFlow;
              if (bound) f.donation.stripe_payment_intent_id = 'pi_oneoffmode';
              if (storedConsent === undefined) delete f.donation.consent_version;
              else f.donation.consent_version = storedConsent;
              const original = structuredClone(f.donation);
              await assert.rejects(f.service[action](owner, f.input), { code: 'payment_consent_required', status: 409 });
              assert.deepEqual(f.state.providerCalls, []);
              assert.deepEqual(f.state.hostedCalls, []);
              assert.deepEqual(f.state.settled, []);
              assert.deepEqual(f.donation, original);
              assert.equal(f.state.rpcs.length, 1);
              assert.equal(f.state.rpcs[0].operation, action === 'submit' ? 'prepare' : 'get');
              if (action === 'submit') assert.equal(f.state.rpcs[0].data.consent_version,
                expectedLivemode ? liveConsent : oneoffConsentVersion);
            }
          }
        }
      }
    });
  }

  test(`oneoff ${name} historical terminal receipts remain readable in both modes without provider or hosted work`, async () => {
    for (const action of ['submit', 'status']) {
      for (const expectedLivemode of [false, true]) {
        for (const paymentFlow of ['native', 'hosted']) {
          for (const bound of [false, true]) {
            for (const storedConsent of [expectedLivemode ? oneoffConsentVersion : liveConsent, undefined]) {
              for (const status of ['confirmed', 'canceled', 'refunded']) {
                const f = oneoffFixture(factory, field, expectedLivemode);
                f.donation.payment_flow = paymentFlow;
                f.donation.payment_status = status;
                if (bound) f.donation.stripe_payment_intent_id = 'pi_oneoffmode';
                if (storedConsent === undefined) delete f.donation.consent_version;
                else f.donation.consent_version = storedConsent;
                const original = structuredClone(f.donation);
                assert.deepEqual(await f.service[action](owner, f.input), { donation_id: donationId, status });
                assert.deepEqual(f.state.providerCalls, []);
                assert.deepEqual(f.state.hostedCalls, []);
                assert.deepEqual(f.donation, original);
              }
            }
          }
        }
      }
    }
  });

  test(`oneoff ${name} rechecks persisted consent after binding before reading or exposing the created PI`, async () => {
    for (const expectedLivemode of [false, true]) {
      for (const storedConsent of [expectedLivemode ? oneoffConsentVersion : liveConsent, undefined]) {
        const f = oneoffFixture(factory, field, expectedLivemode);
        f.state.mutateBind = row => {
          if (storedConsent === undefined) delete row.consent_version;
          else row.consent_version = storedConsent;
          return row;
        };
        await assert.rejects(f.service.submit(owner, f.input), { code: 'payment_consent_required', status: 409 });
        assert.deepEqual(f.state.providerCalls, ['create']);
        assert.deepEqual(f.state.hostedCalls, []);
        assert.equal(f.state.intents.size, 1);
        assert.equal(f.donation.stripe_payment_intent_id, 'pi_oneoffmode');
        assert.equal(f.donation.consent_version, f.input.consent_version);
        assert.equal(f.donation.idempotency_key, requestKey);
        assert.equal(f.donation.id, donationId);
        // The valid row from a later owner read recovers the same already bound
        // resource. It cannot create or bind a replacement after the rejection.
        assert.equal((await f.service.submit(owner, f.input)).payment_client_secret,
          'pi_oneoffmode_secret_synthetic');
        assert.deepEqual(f.state.providerCalls, ['create', 'retrieve']);
        assert.equal(f.state.creates.length, 1);
        assert.equal(f.state.rpcs.filter(call => call.operation === 'bind').length, 1);
      }
    }
  });
}

function billingFixture(livemode = true) {
  const subscription = { id: 'sub_mode', customer: 'cus_mode', livemode, status: 'active',
    collection_method: 'send_invoice', pause_collection: { behavior: 'keep_as_draft', resumes_at: null } };
  const invoice = { id: 'in_mode', livemode, customer: subscription.customer,
    parent: { subscription_details: { subscription: subscription.id } }, billing_reason: 'subscription_cycle',
    status: 'paid', auto_advance: false, collection_method: 'send_invoice', currency: 'mxn',
    total: 5000, amount_due: 5000, amount_paid: 5000, amount_remaining: 0,
    attempt_count: 1, attempted: true, starting_balance: 0,
    total_taxes: [], total_discount_amounts: [], lines: { has_more: false, total_count: 1,
      data: [{ amount: 5000, currency: 'mxn', quantity: 1,
        pricing: { price_details: { price: 'price_mode' } },
        parent: { subscription_item_details: { subscription: subscription.id } },
        period: { start: 1793188800, end: 1795867200 }, taxes: [], discount_amounts: [] }] } };
  const intent = { id: 'pi_mode', livemode, customer: subscription.customer,
    currency: 'mxn', status: 'succeeded', amount_received: 5000,
    latest_charge: { id: 'ch_mode', livemode, payment_intent: 'pi_mode', currency: 'mxn',
      amount: 5000, paid: true, captured: true, disputed: false, amount_refunded: 0,
      payment_method_details: card, balance_transaction: { currency: 'mxn', amount: 5000, fee: 586 } } };
  const payments = { has_more: false, data: [{ id: 'inpay_mode', livemode, invoice: invoice.id, status: 'paid',
    amount_requested: 5000, amount_paid: 5000, payment: { type: 'payment_intent', payment_intent: intent.id } }] };
  invoice.payments = payments;
  const expected = { invoice_id: invoice.id, subscription_id: subscription.id,
    customer_id: subscription.customer, price_id: 'price_mode', gross_cents: 5000 };
  return { subscription, invoice, intent, payments, expected };
}

test('LIVE paid invoice evidence preserves actual fee, full net and historical card snapshot', async () => {
  const f = billingFixture();
  const evidence = guardianPaidInvoice(f.invoice, f.subscription, f.expected, f.payments, f.intent, { expectedLivemode: true });
  assert.equal(evidence.net_cents, 4314);
  assert.equal(evidence.stripe_fee_cents, 586);
  assert.deepEqual(evidence.payment_method, { type: 'card', brand: 'visa', last4: '4242' });
  const calls = [];
  const deps = { invoiceSnapshot: {
    stripe_invoice_id: f.invoice.id, stripe_subscription_id: f.subscription.id,
    price_id: 'price_mode', gross_cents: 5000, period_start: 1793188800 },
    stripe: {
      invoices: { retrieve: async (id, params) => { calls.push(['invoice', id, params]); return structuredClone(f.invoice); } },
      subscriptions: { retrieve: async id => { calls.push(['subscription', id]); return structuredClone(f.subscription); } },
      paymentIntents: { retrieve: async (id, params) => { calls.push(['intent', id, params]); return structuredClone(f.intent); } },
    }, lookupSubscription: async id => {
      calls.push(['owner', id]);
      return { donor_id: owner, status: 'active', stripe_subscription_id: f.subscription.id,
        stripe_customer_id: f.subscription.customer, stripe_price_id: 'price_current', gross_cents: 20000 };
    } };
  assert.deepEqual(await readGuardianPaidEvidence(deps, f.invoice.id, { expectedLivemode: true }), { donor_id: owner, ...evidence });
  assert.equal(calls.length, 4);
  assert.deepEqual(calls[3], ['intent', f.intent.id, { expand: ['latest_charge.balance_transaction'] }]);
  deps.invoiceSnapshot.stripe_invoice_id = 'in_foreign';
  await assert.rejects(readGuardianPaidEvidence(deps, f.invoice.id, { expectedLivemode: true }), { code: 'guardian_invoice_snapshot_mismatch' });
});

test('invoice, subscription, PaymentIntent and Charge cannot cross modes even with matching IDs and amounts', () => {
  for (const expectedLivemode of [false, true]) {
    const f = billingFixture(expectedLivemode);
    const paid = (invoice = f.invoice, sub = f.subscription, intent = f.intent, payments = f.payments) =>
      guardianPaidInvoice(invoice, sub, f.expected, payments, intent, { expectedLivemode });
    assert.equal(paid().net_cents, 4314);
    for (const livemode of [!expectedLivemode, 'true', undefined]) {
      assert.throws(() => paid({ ...f.invoice, livemode }), { code: 'invoice_identity_mismatch' });
      assert.throws(() => paid(f.invoice, { ...f.subscription, livemode }), { code: 'invoice_identity_mismatch' });
      assert.throws(() => paid(f.invoice, f.subscription, { ...f.intent, livemode }), { code: 'charge_not_confirmed' });
      assert.throws(() => paid(f.invoice, f.subscription,
        { ...f.intent, latest_charge: { ...f.intent.latest_charge, livemode } }), { code: 'charge_not_confirmed' });
      assert.throws(() => paid(f.invoice, f.subscription, f.intent,
        { ...f.payments, data: [{ ...f.payments.data[0], livemode }] }), { code: 'invoice_payment_mismatch' });
    }
  }
});

function registrationFixture(livemode = true) {
  const attempt = { id: attemptId, owner_id: owner, reservation_id: cycleId,
    stripe_payment_intent_id: 'pi_registrationmode', customer_id: 'cus_registrationmode',
    payment_method_id: 'pm_registrationmode', pay_requested_at: '2026-10-28T12:00:00Z',
    gross_cents: 2000, processor_state: 'processor_succeeded', resolved_at: null, settlement: null };
  const intent = { id: attempt.stripe_payment_intent_id, livemode, currency: 'mxn', amount: 2000,
    customer: attempt.customer_id, payment_method: attempt.payment_method_id,
    metadata: { guardian_registration_attempt_id: attempt.id }, status: 'succeeded',
    amount_received: 2000, capture_method: 'automatic_async',
    latest_charge: { id: 'ch_registrationmode', livemode, payment_intent: attempt.stripe_payment_intent_id,
      customer: attempt.customer_id, currency: 'mxn', amount: 2000, paid: true, captured: true,
      disputed: false, amount_refunded: 0, refunded: false, payment_method_details: card,
      balance_transaction: { id: 'txn_registrationmode', source: 'ch_registrationmode', currency: 'mxn',
        amount: 2000, fee: 100, net: 1900 } } };
  return { attempt, intent };
}

test('registration LIVE settlement propagates mode through PI/Charge checks and card evidence', () => {
  const f = registrationFixture();
  const result = registrationSettlementEvidence(f.attempt, f.intent, { expectedLivemode: true });
  assert.equal(result.net_cents, 1860);
  assert.equal(result.donor_id, owner);
  assert.deepEqual(result.payment_method, { type: 'card', brand: 'visa', last4: '4242' });
  assert.throws(() => registrationSettlementEvidence(f.attempt, { ...f.intent, livemode: false },
    { expectedLivemode: true }), { code: 'guardian_registration_payment_mismatch' });
  assert.throws(() => registrationSettlementEvidence(f.attempt,
    { ...f.intent, latest_charge: { ...f.intent.latest_charge, livemode: false } },
    { expectedLivemode: true }), { code: 'guardian_registration_charge_unconfirmed' });
});

test('LIVE registration retries incomplete fee evidence on the same binding and ignores foreign events without writes', async () => {
  const f = registrationFixture();
  const row = f.attempt;
  let current = { ...f.intent, latest_charge: { ...f.intent.latest_charge, balance_transaction: null } };
  let event = { id: 'evt_registrationmode', livemode: true, type: 'payment_intent.succeeded',
    data: { object: { id: f.intent.id, metadata: f.intent.metadata } } };
  const observed = { loads: 0, intents: 0, settlements: [], resolutions: [] };
  const worker = guardianRegistrationWorker({ expectedLivemode: true,
    stripe: { events: { retrieve: async () => structuredClone(event) }, paymentIntents: {
      retrieve: async id => { observed.intents++; assert.equal(id, f.intent.id); return structuredClone(current); },
      create: () => assert.fail('reconciliation cannot create another payment'),
      confirm: () => assert.fail('reconciliation cannot authorize another charge'),
    } },
    paymentRpc: async (op, data) => {
      assert.equal(op, 'get'); observed.loads++;
      return data.id === row.id ? structuredClone(row) : null;
    }, bind: () => assert.fail('bound payment cannot rebind'), authorize: () => assert.fail('bound payment cannot reauthorize'),
    settle: async evidence => {
      observed.settlements.push(evidence);
      row.settlement = { cycle_id: cycleId, registration_attempt_id: attemptId, payment_intent_id: f.intent.id };
    }, resolve: async id => { observed.resolutions.push(id); row.resolved_at = '2026-10-28T12:01:00Z'; },
  });
  event.data.object.metadata.guardian_registration_attempt_id = requestKey;
  assert.equal(await worker.handleWebhook(event.id), null);
  assert.equal(observed.intents, 0);
  assert.equal(observed.settlements.length, 0);
  assert.equal(observed.resolutions.length, 0);
  event.data.object.metadata.guardian_registration_attempt_id = attemptId;
  event.livemode = false;
  const loadsBefore = observed.loads;
  await assert.rejects(worker.handleWebhook(event.id), { code: 'guardian_event_invalid' });
  assert.equal(observed.loads, loadsBefore);
  event.livemode = true;
  await assert.rejects(worker.handleWebhook(event.id), { code: 'guardian_registration_charge_unconfirmed' });
  assert.equal(observed.settlements.length, 0);
  assert.equal(observed.resolutions.length, 0);
  current = f.intent;
  assert.equal((await worker.handleWebhook(event.id)).finalized, 1);
  assert.equal((await worker.handleWebhook(event.id)).finalized, 0);
  assert.equal(observed.settlements.length, 1);
  assert.equal(observed.settlements[0].payment_intent_id, f.intent.id);
  assert.deepEqual(observed.resolutions, [attemptId]);
});

test('LIVE registration consumer preserves its one-way authorization after a lost confirmation response', async () => {
  const f = registrationFixture();
  const row = { ...f.attempt, status: 'prepared', stripe_payment_intent_id: null, pay_requested_at: null };
  const calls = { create: [], confirm: [], bind: [], authorize: [], observe: [] };
  let status = 'requires_confirmation';
  const intent = () => ({ ...f.intent, status, latest_charge: status === 'succeeded' ? 'ch_registrationmode' : null });
  const consumer = guardianRegistrationConsumer({ expectedLivemode: true,
    load: async () => structuredClone(row),
    bind: async (id, paymentId) => {
      calls.bind.push([id, paymentId]); row.stripe_payment_intent_id = paymentId; return structuredClone(row);
    }, authorize: async id => {
      calls.authorize.push(id); row.pay_requested_at = new Date().toISOString();
      row.payment_key = `guardian-registration:${id}`; return structuredClone(row);
    }, observe: async (id, evidence) => {
      calls.observe.push({ id, evidence }); row.processor_state = evidence.state; return structuredClone(row);
    }, stripe: { paymentIntents: {
      create: async (body, options) => { calls.create.push({ body, options }); return intent(); },
      retrieve: async id => { assert.equal(id, f.intent.id); return intent(); },
      confirm: async (id, body, options) => {
        calls.confirm.push({ id, body, options }); status = 'processing';
        throw new Error('synthetic lost confirmation response');
      }, cancel: () => assert.fail('processing payment cannot be canceled'),
    } } });
  assert.deepEqual(await consumer.consume(attemptId), { state: 'unresolved' });
  assert.equal(row.stripe_payment_intent_id, f.intent.id);
  assert.ok(row.pay_requested_at);
  assert.equal((await consumer.consume(attemptId)).state, 'unresolved');
  status = 'succeeded';
  assert.equal((await consumer.consume(attemptId)).state, 'processor_succeeded');
  assert.equal(calls.create.length, 1);
  assert.equal(calls.confirm.length, 1);
  assert.deepEqual(calls.bind, [[attemptId, f.intent.id]]);
  assert.deepEqual(calls.authorize, [attemptId]);
  assert.equal(calls.create[0].body.confirm, false);
  assert.deepEqual(calls.create[0].body.allowed_payment_method_types, ['card']);
  assert.equal(calls.confirm[0].options.idempotencyKey, `guardian-registration:${attemptId}`);
});

test('LIVE bank action releases a transient secret only after owner checks and exact LIVE PI evidence', async () => {
  const f = registrationFixture();
  const row = { ...f.attempt, registration_id: requestKey, processor_state: 'requires_action' };
  let gates = 0;
  const current = { ...f.intent, status: 'requires_action', next_action: { type: 'use_stripe_sdk' },
    client_secret: `${f.intent.id}_secret_synthetic` };
  const action = guardianRegistrationBankAction({ expectedLivemode: true,
    authorizeAction: async (actor, registrationId, id) => {
      gates++; assert.equal(actor, owner); assert.equal(registrationId, requestKey); assert.equal(id, attemptId);
      return structuredClone(row);
    }, stripe: { paymentIntents: { retrieve: async () => structuredClone(current),
      create: () => assert.fail('bank action cannot create a charge'),
      confirm: () => assert.fail('bank action cannot confirm a charge') } } });
  assert.deepEqual(await action(owner, { id: requestKey, attempt_id: attemptId }), {
    id: requestKey, attempt_id: attemptId, state: 'requires_action', client_secret: current.client_secret,
  });
  assert.equal(gates, 2);
  current.livemode = false;
  await assert.rejects(action(owner, { id: requestKey, attempt_id: attemptId }),
    { code: 'guardian_registration_payment_mismatch' });
  assert.equal(gates, 3);
});

test('LIVE collection propagates its mode into recovery of the same already voided invoice without another send', async () => {
  const f = billingFixture();
  const job = { invoice_id: f.invoice.id, subscription_id: f.subscription.id,
    customer_id: f.subscription.customer, price_id: 'price_mode', gross_cents: 5000,
    payment_method_id: 'pm_mode', period_start: 1793188800, period_end: 1795867200,
    pay_requested_at: '2026-10-28T12:00:00Z', recovery_intent_id: f.intent.id,
    recovery_invoice_payment_id: 'inpay_mode', lease: 'synthetic-lease' };
  const invoice = { ...f.invoice, status: 'void', amount_paid: 0, amount_remaining: 0 };
  const payment = { id: 'inpay_mode', livemode: true, invoice: f.invoice.id, currency: 'mxn',
    is_default: true, status: 'canceled', amount_paid: 0, amount_requested: 0,
    payment: { type: 'payment_intent', payment_intent: f.intent.id } };
  const intent = { ...f.intent, status: 'canceled', amount: 5000, amount_received: 0,
    amount_capturable: 0, payment_method: job.payment_method_id, latest_charge: null };
  const checkpoints = [];
  const service = guardianCollectionService({ expectedLivemode: true, logger: {},
    stripe: {
      invoices: { retrieve: async () => structuredClone(invoice),
        pay: () => assert.fail('known pay marker cannot be sent again'),
        voidInvoice: () => assert.fail('known void must be observed, not repeated') },
      invoicePayments: { list: async () => ({ has_more: false, data: [structuredClone(payment)] }) },
      paymentIntents: { retrieve: async () => structuredClone(intent) },
    }, rpc: async op => op === 'get' ? structuredClone(job) : null,
    recoveryRpc: async (op, data) => {
      checkpoints.push({ op, data });
      if (op === 'claim') return structuredClone(job);
      if (op === 'voided') return { ...job, status: 'voided' };
      return structuredClone(job);
    }, reconcileInvoice: () => assert.fail('voided evidence cannot settle a payment'),
  });
  assert.equal((await service.run(f.invoice.id)).status, 'voided');
  assert.deepEqual(checkpoints.map(call => call.op), ['claim', 'observe', 'voided']);
  assert.equal(checkpoints[2].data.intent_id, f.intent.id);
  assert.equal(checkpoints[2].data.invoice_payment_id, payment.id);
});

test('LIVE saved-method inventory preserves owner bindings while returning only safe card fields', async () => {
  const customer = { id: 'cus_cardmode', livemode: true, email: 'private@example.test' };
  const subscription = { id: 'sub_cardmode', livemode: true, customer: customer.id, default_payment_method: 'pm_cardmode' };
  const method = { id: 'pm_cardmode', livemode: true, customer: customer.id, type: 'card',
    billing_details: { email: 'private@example.test' }, card: { brand: 'visa', last4: '4242', exp_month: 10, exp_year: 2030 } };
  const list = guardianMethodListService({ expectedLivemode: true,
    lookup: async actor => { assert.equal(actor, owner); return { customer_id: customer.id,
      subscription_id: subscription.id, registration_method_id: method.id }; },
    stripe: { customers: { retrieve: async () => customer },
      subscriptions: { retrieve: async () => subscription },
      paymentMethods: { list: async () => ({ has_more: false, data: [method] }) } } });
  assert.deepEqual(await list(owner), { items: [{ id: method.id, brand: 'visa', last4: '4242',
    exp_month: 10, exp_year: 2030, wallet: null, default: true, guardian_current: true }] });
  method.customer = 'cus_other';
  await assert.rejects(list(owner), { code: 'guardian_methods_unavailable' });
  method.customer = customer.id;
  method.livemode = false;
  await assert.rejects(list(owner), { code: 'guardian_methods_unavailable' });
});

function refundFixture(expectedLivemode = true) {
  const settlement = { cycle_id: cycleId, charge_id: 'ch_refundmode', payment_intent_id: 'pi_refundmode',
    gross_cents: 5000, allocated_cents: 4314, adjustment: { lease: 'synthetic-lease', status: 'pending' },
    reversals: [{ transfer_id: 'tr_refundmode', expense_id: caseId, destination: 'acct_rescuer', amount_cents: 4314 }] };
  const charge = { id: settlement.charge_id, livemode: expectedLivemode, payment_intent: settlement.payment_intent_id,
    amount: 5000, currency: 'mxn', paid: true, captured: true, disputed: false, amount_refunded: 5000 };
  const refund = { id: 're_refundmode', charge: charge.id, payment_intent: settlement.payment_intent_id,
    currency: 'mxn', amount: 5000, status: 'succeeded' };
  const transfer = { id: 'tr_refundmode', livemode: expectedLivemode, amount: 4314, currency: 'mxn',
    destination: 'acct_rescuer', source_transaction: charge.id, transfer_group: `dopmi_guardian_${cycleId}`,
    reversed: true, amount_reversed: 4314 };
  const state = { rpcs: [], refundReads: 0, transferReads: 0 };
  const service = guardianRefundService({ expectedLivemode, logger: {},
    stripe: {
      charges: { retrieve: async () => structuredClone(charge) },
      refunds: { list: async () => { state.refundReads++; return { has_more: false, data: [structuredClone(refund)] }; } },
      transfers: {
        retrieve: async () => { state.transferReads++; return structuredClone(transfer); },
        listReversals: async () => ({ has_more: false, data: [{ id: 'trr_refundmode', transfer: transfer.id,
          amount: 4314, currency: 'mxn' }] }),
        createReversal: () => assert.fail('existing reversal must not be repeated'),
      },
    }, rpc: async (op, data) => {
      state.rpcs.push({ op, data });
      if (op === 'get' || op === 'observe' || op === 'claim') return structuredClone(settlement);
      if (op === 'complete') return { ...structuredClone(settlement), adjustment: { status: 'completed' } };
      if (op === 'authorize') assert.fail('existing reversal must not request authorization');
      return null;
    } });
  return { service, charge, refund, transfer, state };
}

test('LIVE refund evidence accepts the documented mode-less Refund only under its exact LIVE Charge and Transfer', async () => {
  const f = refundFixture();
  assert.equal((await f.service.reconcileCycle(cycleId)).adjustment.status, 'completed');
  assert.equal(f.state.refundReads, 2);
  assert.equal(f.state.transferReads, 1);
  const observed = f.state.rpcs.find(call => call.op === 'observe').data;
  assert.deepEqual(observed.refunds, [{ id: 're_refundmode', amount: 5000 }]);
  assert.equal(f.state.rpcs.filter(call => call.op === 'confirmed').length, 1);
});

test('refund reconciliation rejects cross-mode parents and explicit malformed Refund modes before confirmation', async () => {
  for (const expectedLivemode of [false, true]) {
    const f = refundFixture(expectedLivemode);
    f.charge.livemode = !expectedLivemode;
    await assert.rejects(f.service.reconcileCycle(cycleId), { code: 'guardian_refund_charge_mismatch' });
    assert.equal(f.state.refundReads, 0);
    assert.equal(f.state.rpcs.some(call => call.op === 'observe'), false);
    const foreignTransfer = refundFixture(expectedLivemode);
    foreignTransfer.transfer.livemode = !expectedLivemode;
    await assert.rejects(foreignTransfer.service.reconcileCycle(cycleId), { code: 'guardian_reversal_transfer_mismatch' });
    assert.equal(foreignTransfer.state.rpcs.some(call => call.op === 'confirmed'), false);
    for (const livemode of [!expectedLivemode, 'true', null]) {
      const malformed = refundFixture(expectedLivemode);
      malformed.refund.livemode = livemode;
      await assert.rejects(malformed.service.reconcileCycle(cycleId), { code: 'guardian_refund_list_invalid' });
      assert.equal(malformed.state.rpcs.some(call => call.op === 'observe'), false);
    }
  }
});

test('LIVE preflight confirms the server-selected platform account and exposes no account PII or credentials', async () => {
  const key = 'sk_live_synthetic';
  const expectedAccountId = 'acct_platform';
  const calls = [];
  const result = await guardianPreflight(key, async (url, options) => {
    const parsed = new URL(url);
    calls.push(parsed.pathname);
    assert.equal(options.method, 'GET');
    assert.equal(options.redirect, 'error');
    assert.equal(options.headers.Authorization, `Bearer ${key}`);
    assert.equal(options.headers['Stripe-Version'], '2026-08-26.dahlia');
    if (parsed.pathname === '/v1/account') return Response.json({ object: 'account', id: expectedAccountId,
      email: 'private@example.test', business_profile: { name: 'private_identity' }, external_accounts: { data: ['private_bank'] } });
    assert.equal(parsed.search, '?limit=1');
    return new Response('private_resource_payload');
  }, { expectedLivemode: true, expectedAccountId });
  assert.equal(result.test_mode, false);
  assert.equal(result.key_type, 'standard');
  assert.equal(result.reads_ready, true);
  assert.equal(result.checks.length, 17);
  assert.equal(calls.filter(path => path === '/v1/account').length, 1);
  const serialized = JSON.stringify(result);
  for (const privateValue of [key, 'private', expectedAccountId]) assert.equal(serialized.includes(privateValue), false);
});

test('preflight rejects crossed credential families before I/O and mismatched or malformed account evidence', async () => {
  await assert.rejects(guardianPreflight('sk_test_synthetic', () => assert.fail('wrong key cannot read account'),
    { expectedLivemode: true, expectedAccountId: 'acct_platform' }), { code: 'payments_not_configured' });
  for (const patch of [{ id: 'acct_other' }, { livemode: false }, { livemode: 'true' }, { object: 'customer' }]) {
    const result = await guardianPreflight('rk_live_synthetic', async url => new URL(url).pathname === '/v1/account'
      ? Response.json({ object: 'account', id: 'acct_platform', ...patch }) : Response.json({}),
    { expectedLivemode: true, expectedAccountId: 'acct_platform' });
    assert.equal(result.reads_ready, false);
    assert.equal(result.checks.find(check => check.resource === 'account').ok, false);
    assert.equal(result.write_permissions, 'not_verified');
  }
});
