// Acceptance-only transport. Never imported by the normal server runtime.
// All instances hide the targeted new-price subscription until expiry or removal,
// so a webhook/Cron instance cannot confirm it before the operator crosses time.
export function changeLossFetch({ fetchImpl, target, testKey, now = Date.now, record }) {
  const validId = (prefix, value) => new RegExp(`^${prefix}_[A-Za-z0-9]+$`).test(value ?? '');
  if (!/^(?:rk|sk)_test_[A-Za-z0-9]+$/.test(testKey ?? '')
    || !validId('sub', target?.subscription) || !validId('cus', target?.customer)
    || !validId('si', target?.item) || !Number.isSafeInteger(target?.amount) || target.amount < 5000
    || !Number.isSafeInteger(target?.expiresAt) || target.expiresAt <= now()
    || target.expiresAt > now() + 30 * 60000) throw new Error('invalid_change_loss_target');
  const path = `https://api.stripe.com/v1/subscriptions/${target.subscription}`;
  return async (url, init) => {
    const method = init?.method ?? 'GET';
    let requestIdempotencyKey = null, requestedPrice = null;
    const headers = new Headers(init?.headers);
    if (now() >= target.expiresAt || String(url) !== path || !['GET', 'POST'].includes(method)
      || headers.get('authorization') !== `Bearer ${testKey}` || headers.has('stripe-account'))
      return fetchImpl(url, init);
    if (method === 'POST') {
      if (!/^guardian-change-amount:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(headers.get('idempotency-key') ?? ''))
        return fetchImpl(url, init);
      const body = new URLSearchParams(init.body);
      if ([...body].length !== 5 || body.get('items[0][id]') !== target.item
        || !validId('price', body.get('items[0][price]')) || body.get('items[0][quantity]') !== '1'
        || body.get('billing_cycle_anchor') !== 'unchanged' || body.get('proration_behavior') !== 'none')
        return fetchImpl(url, init);
      requestIdempotencyKey = headers.get('idempotency-key');
      requestedPrice = body.get('items[0][price]');
    }
    const response = await fetchImpl(url, init);
    if (!response.ok) return response;
    const reader = response.clone().body?.getReader();
    if (!reader) return response;
    let timer, result;
    try {
      result = await Promise.race([
        (async () => {
          const chunks = []; let size = 0;
          for (;;) {
            const { done, value } = await reader.read(); if (done) break;
            size += value.byteLength; if (size > 262144) throw new Error('response_limit');
            chunks.push(value);
          }
          const bytes = new Uint8Array(size); let offset = 0;
          for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
          return JSON.parse(new TextDecoder().decode(bytes));
        })(),
        new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('response_timeout')), 20000); }),
      ]);
    } catch { return response; }
    finally { clearTimeout(timer); reader.cancel().catch(() => {}); }
    const item = result?.items?.data?.[0];
    if (result?.id !== target.subscription || result.livemode !== false || result.status !== 'active' || result.customer !== target.customer
      || result.items?.has_more !== false || result.items?.data?.length !== 1 || item?.id !== target.item
      || item.quantity !== 1 || item.price?.currency !== 'mxn' || item.price?.unit_amount !== target.amount
      || !validId('price', item.price?.id) || (method === 'POST' && item.price.id !== requestedPrice)
      || now() >= target.expiresAt) return response;
    await response.body?.cancel();
    const requestId = response.headers.get('request-id');
    record({ event: 'guardian_test_change_response_consumed', method, subscription: target.subscription,
      status: response.status, amount: target.amount,
      guardianRequest: requestIdempotencyKey?.slice('guardian-change-amount:'.length) ?? null,
      price: item.price.id,
      requestId: validId('req', requestId) ? requestId : null, observedAt: new Date(now()).toISOString() });
    throw new TypeError('guardian_test_change_response_lost');
  };
}
