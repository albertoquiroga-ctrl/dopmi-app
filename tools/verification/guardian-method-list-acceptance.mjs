import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';

assert.equal(process.argv[2], '--execute-dev-fixture');
const path = process.argv[3];
const config = JSON.parse(await readFile(path, 'utf8'));
assert.equal(config.url, 'https://ohqxranynackjignryep.supabase.co');
assert.match(config.id, /^[0-9a-f-]{36}$/);
assert.equal(config.email, `parity-methods-354-${config.id}@example.invalid`);
assert.match(config.key, /^sb_publishable_/);
let token;
const result = { passed: [], logout: false };
async function call(endpoint, body, authenticated = true) {
  return fetch(config.url + endpoint, { method: 'POST', signal: AbortSignal.timeout(20000),
    headers: { apikey: config.key, 'Content-Type': 'application/json',
      ...(authenticated && token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body) });
}
try {
  const login = await call('/auth/v1/token?grant_type=password',
    { email: config.email, password: config.password }, false);
  assert.equal(login.status, 200);
  const session = await login.json();
  assert.equal(session.user.id, config.id);
  token = session.access_token;
  result.passed.push('real-auth-confirmed-fixture');
  const list = await call('/functions/v1/guardian-client', { action: 'methods' });
  assert.equal(list.status, 200);
  assert.deepEqual(await list.json(), { items: [] });
  result.passed.push('no-registry-empty-list-no-invented-cards');
  for (const body of [
    { action: 'methods', customer_id: 'cus_peer' },
    { action: 'methods', donor_id: config.id },
    { action: 'methods', payment_method_id: 'pm_peer' },
  ]) {
    const response = await call('/functions/v1/guardian-client', body);
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'invalid_request' });
  }
  result.passed.push('caller-owner-and-processor-fields-rejected');
  const raw = await call('/rest/v1/rpc/dopmi_guardian_method_owner_server', { target_actor: config.id });
  assert.equal(raw.status, 403);
  result.passed.push('direct-private-lookup-denied');
} finally {
  if (token) {
    const logout = await call('/auth/v1/logout?scope=global', {});
    result.logout = logout.ok;
  }
  await writeFile(`${path}.state.json`, JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
}
