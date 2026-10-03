import { PaymentError } from './payments.mjs';

const id = value => typeof value === 'string' ? value : value?.id;
const fail = () => { throw new PaymentError('guardian_methods_unavailable', 503); };

// Reads only. The server-owned registry supplies the Stripe identities.
// Never return raw provider objects, billing details, or client secrets.
export function guardianMethodListService({ stripe, lookup }) {
  return async actor => {
    const link = await lookup(actor);
    if (!link) return { items: [] };
    if (!/^cus_[A-Za-z0-9]+$/.test(link.customer_id ?? '') ||
        (link.subscription_id != null && !/^sub_[A-Za-z0-9]+$/.test(link.subscription_id))) fail();
    const customer = await stripe.customers.retrieve(link.customer_id);
    if (customer?.id !== link.customer_id || customer.deleted === true || customer.livemode !== false) fail();
    let defaultId = id(customer.invoice_settings?.default_payment_method);
    if (link.subscription_id) {
      const subscription = await stripe.subscriptions.retrieve(link.subscription_id);
      if (subscription?.id !== link.subscription_id || subscription.livemode !== false ||
          id(subscription.customer) !== link.customer_id) fail();
      defaultId = id(subscription.default_payment_method);
    }
    const items = [], seen = new Set();
    let cursor;
    for (let page = 0; page < 5; page++) {
      const result = await stripe.paymentMethods.list({ customer: link.customer_id, type: 'card', limit: 100,
        ...(cursor ? { starting_after: cursor } : {}) });
      if (!Array.isArray(result?.data) || typeof result.has_more !== 'boolean') fail();
      for (const method of result.data) {
        if (!/^pm_[A-Za-z0-9]+$/.test(method?.id ?? '') || seen.has(method.id) ||
            method.livemode !== false || id(method.customer) !== link.customer_id || method.type !== 'card') fail();
        seen.add(method.id);
        const card = method.card;
        if (!card || !/^[a-z_]{2,30}$/.test(card.brand ?? '') || !/^\d{4}$/.test(card.last4 ?? '') ||
            !Number.isInteger(card.exp_month) || card.exp_month < 1 || card.exp_month > 12 ||
            !Number.isInteger(card.exp_year) || card.exp_year < 2000 || card.exp_year > 2200) fail();
        items.push({ id: method.id, brand: card.brand, last4: card.last4,
          exp_month: card.exp_month, exp_year: card.exp_year,
          wallet: ['apple_pay', 'google_pay'].includes(card.wallet?.type) ? card.wallet.type : null,
          default: method.id === defaultId });
      }
      if (!result.has_more) return { items };
      if (!result.data.length) fail();
      cursor = result.data.at(-1).id;
    }
    fail(); // Never disguise a partial list as a complete inventory.
  };
}
