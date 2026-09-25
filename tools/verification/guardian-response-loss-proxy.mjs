import http from 'node:http';
import https from 'node:https';

// Local acceptance instrument only. Never import this into a deployed function.
// A single allowlisted Stripe test write is forwarded. Its successful response
// is consumed here, then the downstream TCP connection is destroyed before any
// response bytes reach the client. Recovery can only read through this proxy.
export async function startGuardianResponseLossProxy({
  testKey, path, idempotencyKey, readPaths = [],
  upstreamOrigin = 'https://api.stripe.com',
  deadlineMs = 20000,
}) {
  const origin = new URL(upstreamOrigin);
  const localFixture = origin.protocol === 'http:' && origin.hostname === '127.0.0.1';
  if ((!localFixture && origin.origin !== 'https://api.stripe.com')
    || origin.pathname !== '/' || origin.search || origin.hash || origin.username || origin.password)
    throw new Error('Only Stripe HTTPS or an explicit loopback fixture is allowed');
  if (!/^(sk|rk)_test_[A-Za-z0-9]+$/.test(testKey ?? '')) throw new Error('Stripe test key required');
  const validPath = value => typeof value === 'string' && /^\/v1\/[A-Za-z0-9_/-]+$/.test(value)
    && !value.includes('//') && !value.includes('..');
  const validReadPath = value => {
    if (typeof value !== 'string' || /[\x00-\x20\x7f]/.test(value)) return false;
    try {
      const url = new URL(value, 'https://api.stripe.com');
      return value.startsWith('/v1/') && url.origin === 'https://api.stripe.com'
        && !url.hash && validPath(value.split('?')[0]);
    } catch { return false; }
  };
  if (!validPath(path) || !readPaths.every(validReadPath)
    || typeof idempotencyKey !== 'string' || !/^[\x21-\x7e]{1,255}$/.test(idempotencyKey))
    throw new Error('Exact API paths and a stable idempotency key are required');
  if (!Number.isSafeInteger(deadlineMs) || deadlineMs < 1 || deadlineMs > 20000)
    throw new Error('Deadline must be between 1 and 20000 milliseconds');
  const evidence = [];
  const connections = new Set();
  const upstreamRequests = new Set();
  let writeStarted = false;
  const server = http.createServer(async (request, response) => {
    let upstream;
    const deadline = setTimeout(() => {
      upstream?.destroy(new Error('absolute_deadline'));
      response.destroy();
      request.destroy();
    }, deadlineMs);
    response.once('close', () => {
      clearTimeout(deadline);
      upstream?.destroy();
    });
    response.once('finish', () => clearTimeout(deadline));
    const reject = (status, code) => {
      response.writeHead(status, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ error: code }));
    };
    if (request.headers.authorization !== `Bearer ${testKey}`) return reject(401, 'test_key_mismatch');
    const write = request.method === 'POST' && request.url === path
      && request.headers['idempotency-key'] === idempotencyKey;
    const read = request.method === 'GET' && readPaths.includes(request.url);
    if (!write && !read) return reject(403, 'operation_not_allowlisted');
    if (write && writeStarted) return reject(409, 'write_already_forwarded');
    if (write) writeStarted = true; // Also blocks concurrent/automatic SDK retries.
    const chunks = [];
    let bytes = 0;
    try {
      for await (const chunk of request) {
        bytes += chunk.length;
        if (bytes > 65536) return reject(413, 'request_too_large');
        chunks.push(chunk);
      }
    } catch { return; }
    const body = Buffer.concat(chunks);
    const headers = { authorization: `Bearer ${testKey}`, 'content-length': body.length };
    for (const name of ['content-type', 'stripe-version', 'idempotency-key']) {
      if (typeof request.headers[name] === 'string') headers[name] = request.headers[name];
    }
    const transport = origin.protocol === 'https:' ? https : http;
    upstream = transport.request(new URL(request.url, origin), {
      method: request.method, headers, timeout: 20000,
    }, incoming => {
      const collected = [];
      let size = 0;
      incoming.on('data', chunk => {
        size += chunk.length;
        if (size > 2097152) incoming.destroy(new Error('response_limit'));
        else collected.push(chunk);
      });
      incoming.on('error', () => response.destroy());
      incoming.on('end', () => {
        const payload = Buffer.concat(collected);
        const successful = incoming.statusCode >= 200 && incoming.statusCode < 300;
        if (write && successful) {
          let objectId = null;
          try {
            const id = JSON.parse(payload.toString('utf8')).id;
            if (typeof id === 'string' && /^[A-Za-z0-9_]{1,200}$/.test(id)) objectId = id;
          } catch { /* A non-JSON success is still lost, never fabricated as success evidence. */ }
          const requestId = incoming.headers['request-id'];
          evidence.push(Object.freeze({ method: 'POST', path, status: incoming.statusCode,
            requestId: typeof requestId === 'string' && /^req_[A-Za-z0-9]+$/.test(requestId) ? requestId : null,
            objectId, responseDropped: true, observedAt: new Date().toISOString() }));
          response.destroy();
          return;
        }
        response.writeHead(incoming.statusCode ?? 502, { 'content-type': 'application/json' });
        response.end(payload);
      });
    });
    upstreamRequests.add(upstream);
    upstream.once('close', () => upstreamRequests.delete(upstream));
    upstream.on('timeout', () => upstream.destroy(new Error('upstream_timeout')));
    upstream.on('error', () => {
      if (!response.destroyed && !response.headersSent) reject(502, 'upstream_unavailable');
    });
    upstream.end(body);
  });
  server.on('connection', socket => {
    connections.add(socket);
    socket.once('close', () => connections.delete(socket));
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return {
    port: server.address().port,
    evidence: () => evidence.map(item => ({ ...item })),
    close: () => new Promise((resolve, reject) => {
      server.close(error => error ? reject(error) : resolve());
      for (const request of upstreamRequests) request.destroy();
      for (const socket of connections) socket.destroy();
    }),
  };
}
