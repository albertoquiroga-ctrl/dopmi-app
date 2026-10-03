import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import Stripe from 'stripe';
import { guardianMethodService } from '../../supabase/functions/_shared/guardian-method.mjs';
import { guardianMethodListService } from '../../supabase/functions/_shared/guardian-method-list.mjs';

// An isolated zero-price test subscription cannot create a payable renewal.
// No Dopmi registry, financial jobs, human customer, or real card is involved.
assert.equal(process.argv[2], '--execute-test-fixture');
const label = process.argv[3]?.replace(/^--fixture-label=/, '') ?? '355';
const selectDefault = process.argv[4] === '--select-default';
assert.ok(process.argv.length <= 5 && /^[a-z0-9-]{1,20}$/.test(label));
if (process.argv[4]) assert.ok(selectDefault);
if (process.argv[3]) assert.ok(process.argv[3].startsWith('--fixture-label='));
const journalPath = join(process.env.LOCALAPPDATA, 'Temp', `dopmi-method-stripe-${label}.json`);
let state;
try { state = JSON.parse(await readFile(journalPath, 'utf8')); }
catch (error) {
  if (error.code !== 'ENOENT') throw error;
  state = { run: randomUUID(), createdAt: Date.now(), cards: [], selectDefault };
  await writeFile(journalPath, JSON.stringify(state), { flag: 'wx' });
}
assert.equal(state.selectDefault === true, selectDefault, 'Fixture mode must remain stable');
assert.match(state.run, /^[0-9a-f-]{36}$/);
assert.ok(Date.now() - state.createdAt < 23 * 3600000, 'Outside mutation retry window');
const save = () => writeFile(journalPath, JSON.stringify(state, null, 2));
const option = kind => ({ idempotencyKey: `dopmi-method-read:${state.run}:${kind}` });
let stage = 'key', stripe;
try {
  const credentials = (await readFile(join(process.env.LOCALAPPDATA,
    'Dopmi', 'acceptance', 'stripe-test.env'), 'utf8')).trim();
  const match = /^STRIPE_SECRET_KEY_H4_TEST=((?:rk|sk)_test_[A-Za-z0-9]+)$/.exec(credentials);
  assert.ok(match);
  stripe = new Stripe(match[1], { apiVersion: '2026-08-26.dahlia', maxNetworkRetries: 0,
    timeout: 20000, httpClient: Stripe.createFetchHttpClient() });
  const known = await stripe.checkout.sessions.retrieve('cs_test_a1qfHlwmhBMH2VIXpcf9sUmt78LEQwY4XKzDJns4d653y7fUluM3dDXXi1');
  assert.equal(known.livemode, false);
  if (state.cleaned) {
    console.log(JSON.stringify({ completed: state.verified === true, cleaned: true, reused: true }));
    if (!state.verified) process.exitCode = 1;
  }
  else {
    const metadata = { dopmi_method_read_acceptance: state.run };
    stage = 'customer';
    if (!state.customer) {
      state.customer = (await stripe.customers.create({ name: `Fixture métodos ${state.run}`, email: `parity-methods-${state.run}@example.invalid`, metadata }, option('customer'))).id;
      await save();
    }
    stage = 'product';
    if (!state.product) {
      state.product = (await stripe.products.create({ name: `Fixture lectura sin cobro ${state.run}`, metadata }, option('product'))).id;
      await save();
    }
    stage = 'zero-price';
    if (!state.price) {
      state.price = (await stripe.prices.create({ product: state.product, unit_amount: 0,
        currency: 'mxn', recurring: { interval: 'month' }, metadata }, option('price'))).id;
      await save();
    }
    stage = 'test-cards';
    for (const alias of ['pm_card_visa', 'pm_card_mastercard']) {
      if (state.cards.some(card => card.alias === alias)) continue;
      const method = await stripe.paymentMethods.attach(alias, { customer: state.customer }, option(alias));
      assert.equal(method.livemode, false);
      state.cards.push({ alias, id: method.id }); await save();
    }
    stage = 'zero-subscription';
    if (!state.subscription) {
      state.subscription = (await stripe.subscriptions.create({ customer: state.customer,
        items: [{ price: state.price }], default_payment_method: state.cards[0].id,
        collection_method: 'send_invoice', days_until_due: 1, metadata,
        ...(selectDefault ? { automatic_tax: { enabled: false } } : {}) }, option('subscription'))).id;
      await save();
    }
    if (selectDefault) {
      stage = 'pause-zero-subscription';
      const sub = await stripe.subscriptions.retrieve(state.subscription);
      assert.equal(sub.livemode, false);
      assert.equal(sub.metadata.dopmi_method_read_acceptance, state.run);
      assert.equal(sub.items.data[0].price.unit_amount, 0);
      if (sub.pause_collection?.behavior !== 'keep_as_draft') {
        await stripe.subscriptions.update(sub.id,
          { pause_collection: { behavior: 'keep_as_draft' }, proration_behavior: 'none' }, option('pause'));
      }
    }
    const read = guardianMethodListService({ stripe, lookup: async actor => {
      assert.equal(actor, state.run);
      return { customer_id: state.customer, subscription_id: state.subscription };
    } });
    stage = 'read';
    const list = await read(state.run);
    assert.equal(list.items.length, 2);
    assert.equal(list.items.filter(card => card.default).length, 1);
    assert.ok([state.cards[0].id, ...(selectDefault && state.methodJob ? [state.cards[1].id] : [])].includes(list.items.find(card => card.default).id));
    assert.deepEqual(list.items.map(card => card.brand).sort(), ['mastercard', 'visa']);
    assert.ok(list.items.every(card => Object.keys(card).length === 7));
    if (selectDefault) {
      stage = 'select-default';
      const before = await stripe.subscriptions.retrieve(state.subscription);
      assert.equal(before.metadata.dopmi_method_read_acceptance, state.run);
      assert.equal(before.livemode, false);
      assert.equal(before.items.data[0].price.unit_amount, 0);
      const calendar = sub => [sub.billing_cycle_anchor, sub.items.data[0].current_period_start,
        sub.items.data[0].current_period_end, sub.latest_invoice];
      state.calendar ??= calendar(before);
      state.methodJob ??= {
        id: randomUUID(), status: 'pending', selected_method_id: state.cards[1].id,
        current_method_id: state.cards[0].id, customer_id: state.customer,
        subscription_id: state.subscription, price_id: state.price,
        plan_status: 'active', lease: randomUUID(),
        expires_at: new Date(state.createdAt + 35 * 60000).toISOString(),
      };
      await save();
      // Local checkpoint adapter is deliberate: this verifies real Stripe SDK
      // behavior of the production service, not database locks or Auth routing.
      const rpc = async (operation, data) => {
        assert.equal(data.job_id, state.methodJob.id);
        if (operation === 'get' || operation === 'claim' || operation === 'release') return { ...state.methodJob };
        if (operation === 'verified_saved') {
          assert.equal(data.payment_method_id, state.cards[1].id);
          state.methodJob.payment_method_id = data.payment_method_id;
        } else if (operation === 'snapshot') state.methodJob.billing_anchor = data.billing_anchor;
        else if (operation === 'write_update') state.methodJob.mutation_requested_at ??= new Date().toISOString();
        else if (operation === 'applied') {
          assert.equal(data.payment_method_id, state.cards[1].id);
          state.methodJob.status = 'applied';
        } else if (operation === 'failed') state.methodJob.error_code = data.error_code;
        else throw new Error('Unexpected checkpoint');
        await save();
        return { ...state.methodJob };
      };
      const observedStripe = {
        paymentMethods: stripe.paymentMethods,
        subscriptions: {
          retrieve: stripe.subscriptions.retrieve.bind(stripe.subscriptions),
          update: async (...args) => {
            assert.equal(args[0], state.subscription);
            assert.deepEqual(args[1], { default_payment_method: state.cards[1].id, proration_behavior: 'none' });
            state.selectionUpdateCalls = (state.selectionUpdateCalls ?? 0) + 1;
            await save();
            const result = await stripe.subscriptions.update(...args);
            if (!state.acceptedResponseLost) {
              state.acceptedResponseLost = true;
              await save();
              throw new Error('Synthetic response loss after real accepted update');
            }
            return result;
          },
        },
      };
      const service = guardianMethodService({ stripe: observedStripe, rpc,
        returnUrl: 'https://example.invalid/guardian-return', logger: { log() {} } });
      if (!state.acceptedResponseLost) {
        await assert.rejects(service.run(state.methodJob.id), /Synthetic response loss/);
        assert.equal(state.methodJob.status, 'pending');
        assert.equal((await stripe.subscriptions.retrieve(state.subscription)).default_payment_method, state.cards[1].id);
      }
      assert.equal((await service.run(state.methodJob.id)).status, 'applied');
      assert.equal(state.acceptedResponseLost, true);
      assert.equal(state.selectionUpdateCalls, 1);
      const after = await stripe.subscriptions.retrieve(state.subscription);
      assert.equal(after.default_payment_method, state.cards[1].id);
      assert.deepEqual(calendar(after), state.calendar);
      assert.equal((await service.run(state.methodJob.id)).status, 'applied');
      const selected = await read(state.run);
      assert.equal(selected.items.filter(card => card.default).length, 1);
      assert.equal(selected.items.find(card => card.default).id, state.cards[1].id);
      state.defaultSelectionVerified = true;
      await save();
    }
    const invoices = await stripe.invoices.list({ customer: state.customer, limit: 100 });
    assert.equal(invoices.has_more, false);
    assert.ok(invoices.data.every(invoice => invoice.amount_due === 0 && invoice.amount_paid === 0));
    const charges = await stripe.charges.list({ customer: state.customer, limit: 100 });
    assert.equal(charges.has_more, false);
    assert.equal(charges.data.length, 0);
    const intents = await stripe.paymentIntents.list({ customer: state.customer, limit: 100 });
    assert.equal(intents.has_more, false);
    assert.equal(intents.data.length, 0);
    state.noChargesOrPaymentIntents = true;
    state.verified = true; await save();
  }
} catch (error) {
  state.failure = { stage, code: error.code ?? null, param: error.param ?? null }; await save();
  console.log(JSON.stringify({ completed: false, stage, param: error.param ?? null, type: error.type ?? error.name,
    code: error.code ?? null, status: error.statusCode ?? null }));
  process.exitCode = 1;
} finally {
  if (stripe && !state.cleaned) {
    try {
      stage = 'cleanup';
      if (state.subscription) {
        const sub = await stripe.subscriptions.retrieve(state.subscription);
        assert.equal(sub.metadata.dopmi_method_read_acceptance, state.run);
        assert.equal(sub.livemode, false);
        if (sub.status !== 'canceled') await stripe.subscriptions.cancel(sub.id, { prorate: false, invoice_now: false });
        assert.equal((await stripe.subscriptions.retrieve(sub.id)).status, 'canceled');
      }
      if (state.customer) {
        const customer = await stripe.customers.retrieve(state.customer);
        if (!customer.deleted) {
          assert.equal(customer.metadata.dopmi_method_read_acceptance, state.run);
          assert.equal(customer.livemode, false);
          await stripe.customers.del(customer.id);
        }
        assert.equal((await stripe.customers.retrieve(state.customer)).deleted, true);
      }
      if (state.price) {
        assert.equal((await stripe.prices.retrieve(state.price)).unit_amount, 0);
        await stripe.prices.update(state.price, { active: false });
        assert.equal((await stripe.prices.retrieve(state.price)).active, false);
      }
      if (state.product) {
        const product = await stripe.products.retrieve(state.product);
        assert.equal(product.metadata.dopmi_method_read_acceptance, state.run);
        await stripe.products.update(product.id, { active: false });
        assert.equal((await stripe.products.retrieve(product.id)).active, false);
      }
      state.cleaned = true; await save();
      console.log(JSON.stringify({ completed: state.verified === true, cleaned: true, cards: state.cards.length, defaultSelectionVerified: state.defaultSelectionVerified === true }));
    } catch (error) {
      console.log(JSON.stringify({ completed: false, cleaned: false, stage,
        type: error.type ?? error.name, code: error.code ?? null }));
      process.exitCode = 1;
    }
  }
}
