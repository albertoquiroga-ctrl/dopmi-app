// Temporary test-deployment instrument. Not imported by the normal runtime.
// Consume an actual Stripe success at the HTTP boundary before SDK delivery.
export function refundLossFetch({ fetchImpl, target, testKey, now = Date.now, record }) {
  if (!/^(?:rk|sk)_test_[A-Za-z0-9]+$/.test(testKey ?? '')) throw new Error('invalid_test_key');
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
  if (!uuid.test(target?.cycle ?? '') || !uuid.test(target?.expense ?? '')
    || !/^tr_[A-Za-z0-9]+$/.test(target?.transfer ?? '')
    || !Number.isSafeInteger(target?.amount) || target.amount <= 0
    || !Number.isSafeInteger(target?.expiresAt)
    || target.expiresAt <= now() || target.expiresAt > now() + 30 * 60000)
    throw new Error('invalid_refund_loss_target');
  const path = `https://api.stripe.com/v1/transfers/${target.transfer}/reversals`;
  const key = `guardian-reversal:${target.cycle}:${target.expense}`;
  let consumed = false;
  return async (url, init) => {
    if (consumed || now() >= target.expiresAt || String(url) !== path || init?.method !== 'POST')
      return fetchImpl(url, init);
    const headers = new Headers(init.headers);
    if (headers.get('authorization') !== `Bearer ${testKey}` || headers.has('stripe-account')
      || headers.get('idempotency-key') !== key)
      return fetchImpl(url, init);
    const body = new URLSearchParams(init.body);
    const expected = new Map([
      ['amount', String(target.amount)],
      ['metadata[dopmi_guardian_cycle]', target.cycle],
      ['metadata[dopmi_guardian_expense]', target.expense],
    ]);
    if ([...body].length !== expected.size || [...expected].some(([k, v]) => body.get(k) !== v))
      return fetchImpl(url, init);
    consumed = true;
    const response = await fetchImpl(url, init);
    if (!response.ok) return response;
    // Read the upstream response; never invent a success or a reversal ID.
    const reader = response.clone().body.getReader();
    let timer, bytes = 0;
    const chunks = [];
    let result;
    try {
      const text = await Promise.race([
        (async () => {
          for (;;) {
            const { done, value } = await reader.read();
            if (done) break;
            bytes += value.byteLength;
            if (bytes > 32768) throw new Error('response_limit');
            chunks.push(value);
          }
          const buffer = new Uint8Array(bytes);
          let offset = 0;
          for (const chunk of chunks) { buffer.set(chunk, offset); offset += chunk.byteLength; }
          return new TextDecoder().decode(buffer);
        })(),
        new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('response_timeout')), 20000); }),
      ]);
      result = JSON.parse(text);
    } catch { return response; }
    finally { clearTimeout(timer); reader.cancel().catch(() => {}); }
    if (!/^trr_[A-Za-z0-9]+$/.test(result?.id ?? '') || result.transfer !== target.transfer
      || result.amount !== target.amount || result.currency !== 'mxn') return response;
    await response.body?.cancel();
    const requestId = response.headers.get('request-id');
    record({ event: 'guardian_test_refund_response_consumed',
      cycle: target.cycle, transfer: target.transfer, status: response.status,
      reversal: /^trr_[A-Za-z0-9]+$/.test(result?.id ?? '') ? result.id : null,
      requestId: /^req_[A-Za-z0-9]+$/.test(requestId ?? '') ? requestId : null,
      amount: Number.isSafeInteger(result?.amount) ? result.amount : null,
      observedAt: new Date(now()).toISOString() });
    throw new TypeError('guardian_test_response_lost');
  };
}
