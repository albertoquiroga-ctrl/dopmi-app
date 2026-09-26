import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';
import Stripe from 'stripe';
import { startGuardianResponseLossProxy } from './guardian-response-loss-proxy.mjs';

const testKey = 'sk_test_localFixtureOnly';
const path = '/v1/subscriptions/sub_fixture';
const idempotencyKey = 'guardian-change:fixture';
function send(port, { method = 'POST', key = testKey, url = path, stableKey = idempotencyKey } = {}) {
  return new Promise((resolve, reject) => {
    const request = http.request({ host: '127.0.0.1', port, path: url, method, agent: false,
      headers: { authorization: `Bearer ${key}`, 'idempotency-key': stableKey } }, response => {
      let body = '';
      response.on('data', chunk => { body += chunk; });
      response.on('end', () => resolve({ status: response.statusCode, body }));
      response.on('error', reject);
    });
    request.on('error', reject);
    request.end();
  });
}
async function fixture(t, status = 200) {
  const requests = [];
  let applied = false;
  const upstream = http.createServer((request, response) => {
    requests.push({ method: request.method, url: request.url });
    if (request.method === 'POST' && status === 200) applied = true;
    response.writeHead(status, { 'content-type': 'application/json', 'request-id': 'req_fixture' });
    response.end(JSON.stringify({ id: 'sub_fixture', applied,
      secret_fixture_field: 'must-not-appear-in-evidence' }));
  });
  await new Promise(resolve => upstream.listen(0, '127.0.0.1', resolve));
  const proxy = await startGuardianResponseLossProxy({ testKey, path, idempotencyKey,
    readPaths: [path], upstreamOrigin: `http://127.0.0.1:${upstream.address().port}` });
  t.after(async () => {
    await proxy.close();
    await new Promise(resolve => upstream.close(resolve));
  });
  return { proxy, requests };
}

test('a successful upstream write loses the actual TCP response, then recovers by reading once', async t => {
  const { proxy, requests } = await fixture(t);
  await assert.rejects(send(proxy.port), error => error.code === 'ECONNRESET');
  const recovered = await send(proxy.port, { method: 'GET' });
  assert.equal(recovered.status, 200);
  assert.equal(JSON.parse(recovered.body).applied, true);
  assert.equal((await send(proxy.port)).status, 409);
  assert.deepEqual(requests, [{ method: 'POST', url: path }, { method: 'GET', url: path }]);
  assert.equal(proxy.evidence().length, 1);
  assert.deepEqual(Object.keys(proxy.evidence()[0]).sort(),
    ['method', 'objectId', 'observedAt', 'path', 'requestId', 'responseDropped', 'status'].sort());
  assert.equal(proxy.evidence()[0].objectId, 'sub_fixture');
  assert.equal(proxy.evidence()[0].requestId, 'req_fixture');
  assert.doesNotMatch(JSON.stringify(proxy.evidence()), /must-not-appear|sk_test|Bearer/);
});

test('unapproved keys, methods, paths and idempotency keys never reach upstream', async t => {
  const { proxy, requests } = await fixture(t);
  for (const options of [{ key: 'sk_live_forbidden' }, { method: 'DELETE' },
    { url: '/v1/subscriptions/sub_other' }, { stableKey: 'different' },
    { method: 'GET', url: `${path}?expand[]=customer` }]) {
    assert.ok([401, 403].includes((await send(proxy.port, options)).status));
  }
  assert.equal(requests.length, 0);
  assert.deepEqual(proxy.evidence(), []);
});

test('a Stripe error is delivered, not misreported as an accepted lost write', async t => {
  const { proxy, requests } = await fixture(t, 400);
  assert.equal((await send(proxy.port)).status, 400);
  assert.equal((await send(proxy.port)).status, 409);
  assert.equal(requests.length, 1);
  assert.deepEqual(proxy.evidence(), []);
});

test('parallel retries cannot forward a second write', async t => {
  const { proxy, requests } = await fixture(t);
  const outcomes = await Promise.allSettled([send(proxy.port), send(proxy.port)]);
  assert.equal(outcomes.filter(x => x.status === 'rejected' && x.reason.code === 'ECONNRESET').length, 1);
  assert.equal(outcomes.filter(x => x.status === 'fulfilled' && x.value.status === 409).length, 1);
  assert.equal(requests.length, 1);
});

test('configuration rejects live credentials and external forwarding destinations', async () => {
  for (const override of [{ testKey: 'sk_live_forbidden' },
    { upstreamOrigin: 'https://example.com' }, { upstreamOrigin: 'http://api.stripe.com' },
    { upstreamOrigin: 'https://api.stripe.com/other' }, { path: '/v1/../charges' },
    { idempotencyKey: '' }]) {
    await assert.rejects(startGuardianResponseLossProxy({ testKey, path, idempotencyKey, ...override }));
  }
});

test('an explicitly allowlisted GET query is forwarded without allowing other expansions', async t => {
  const upstream = http.createServer((request, response) => response.end(JSON.stringify({ url: request.url })));
  await new Promise(resolve => upstream.listen(0, '127.0.0.1', resolve));
  const queryPath = `${path}?expand%5B%5D=latest_invoice`;
  const proxy = await startGuardianResponseLossProxy({ testKey, path, idempotencyKey,
    readPaths: [queryPath], upstreamOrigin: `http://127.0.0.1:${upstream.address().port}` });
  t.after(async () => { await proxy.close(); await new Promise(resolve => upstream.close(resolve)); });
  assert.equal(JSON.parse((await send(proxy.port, { method: 'GET', url: queryPath })).body).url, queryPath);
  assert.equal((await send(proxy.port, { method: 'GET', url: `${path}?expand%5B%5D=customer` })).status, 403);
});

test('a trickling upstream cannot extend the absolute deadline', { timeout: 3000 }, async t => {
  const upstream = http.createServer((request, response) => {
    response.writeHead(200);
    const timer = setInterval(() => response.write(' '), 10);
    response.once('close', () => clearInterval(timer));
  });
  await new Promise(resolve => upstream.listen(0, '127.0.0.1', resolve));
  const proxy = await startGuardianResponseLossProxy({ testKey, path, idempotencyKey, deadlineMs: 100,
    upstreamOrigin: `http://127.0.0.1:${upstream.address().port}` });
  t.after(async () => { await proxy.close(); await new Promise(resolve => upstream.close(resolve)); });
  await assert.rejects(send(proxy.port), error => error.code === 'ECONNRESET');
  assert.deepEqual(proxy.evidence(), []);
});

test('closing the instrument terminates in-flight upstream and downstream connections', { timeout: 3000 }, async () => {
  let reached;
  const accepted = new Promise(resolve => { reached = resolve; });
  const upstream = http.createServer(() => reached());
  await new Promise(resolve => upstream.listen(0, '127.0.0.1', resolve));
  const proxy = await startGuardianResponseLossProxy({ testKey, path, idempotencyKey,
    upstreamOrigin: `http://127.0.0.1:${upstream.address().port}` });
  const outcome = send(proxy.port).then(() => 'unexpected', error => error.code);
  await accepted;
  await proxy.close();
  assert.equal(await outcome, 'ECONNRESET');
  await new Promise(resolve => upstream.close(resolve));
});

test('Stripe 22.6 Fetch client reports the lost response and recovers the same object by reading', async t => {
  const { proxy, requests } = await fixture(t);
  const stripe = new Stripe(testKey, { apiVersion: '2026-08-26.dahlia',
    host: '127.0.0.1', port: proxy.port, protocol: 'http',
    maxNetworkRetries: 0, timeout: 2000, httpClient: Stripe.createFetchHttpClient() });
  let sent = 0;
  stripe.on('request', () => { sent++; });
  await assert.rejects(stripe.subscriptions.update('sub_fixture', { proration_behavior: 'none' },
    { idempotencyKey }), error => error.type === 'StripeConnectionError');
  assert.equal(sent, 1);
  const recovered = await stripe.subscriptions.retrieve('sub_fixture');
  assert.equal(recovered.id, 'sub_fixture');
  assert.equal(recovered.applied, true);
  assert.deepEqual(requests, [{ method: 'POST', url: path }, { method: 'GET', url: path }]);
});

test('Stripe Node transport closed-connection retry is blocked even with maxNetworkRetries zero', async t => {
  const { proxy, requests } = await fixture(t);
  const stripe = new Stripe(testKey, { apiVersion: '2026-08-26.dahlia',
    host: '127.0.0.1', port: proxy.port, protocol: 'http', maxNetworkRetries: 0, timeout: 2000 });
  let sent = 0;
  stripe.on('request', () => { sent++; });
  await assert.rejects(stripe.subscriptions.update('sub_fixture', { proration_behavior: 'none' },
    { idempotencyKey }), error => error.statusCode === 409);
  assert.equal(sent, 2);
  assert.equal(requests.length, 1);
  assert.equal(proxy.evidence().length, 1);
});
