import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

// Explicit DEV acceptance against two newly prepared synthetic Auth fixtures.
// Never use existing human accounts or commit the credential configuration.
assert.equal(process.argv[2], '--execute-dev-fixture');
const configPath = process.argv[3];
assert.ok(configPath);
const config = JSON.parse(await readFile(configPath, 'utf8'));
assert.equal(config.url, 'https://ohqxranynackjignryep.supabase.co');
if (!config.key.startsWith('sb_publishable_')) {
  assert.equal(JSON.parse(Buffer.from(config.key.split('.')[1], 'base64url')).role, 'anon');
}
assert.equal(config.accounts.length, 2);
for (const account of config.accounts) {
  assert.match(account.id, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(account.email, `parity-photo-318-${account.id}@example.invalid`);
}
const bucket = 'dopmi-account-profile-media';
const owner = config.accounts[0].id;
const path = `${owner}/${owner}/${randomUUID()}.jpg`;
const journal = { path, stage: 'login', passed: [], cleanup: false };
await writeFile(`${configPath}.state.json`, JSON.stringify(journal));
const sessions = [];
async function call(endpoint, body, token, method = 'POST', contentType = 'application/json') {
  const response = await fetch(config.url + endpoint, {
    method, signal: AbortSignal.timeout(20000),
    headers: { apikey: config.key, ...(token ? { Authorization: `Bearer ${token}` } : {}), 'Content-Type': contentType },
    ...(method === 'GET' ? {} : { body: Buffer.isBuffer(body) ? body : JSON.stringify(body) }),
  });
  return response;
}
async function rpc(name, body, token) {
  const response = await call(`/rest/v1/rpc/${name}`, body, token);
  assert.equal(response.ok, true, `${name}: HTTP ${response.status}`);
  return response.json();
}
try {
  for (const account of config.accounts) {
    const response = await call('/auth/v1/token?grant_type=password', { email: account.email, password: account.password });
    assert.equal(response.ok, true, `fixture login: HTTP ${response.status}`);
    const session = await response.json();
    assert.equal(session.user.id, account.id);
    sessions.push(session.access_token);
  }
  journal.stage = 'private-name';
  await rpc('dopmi_save_account_names', { payload: { first_name: 'Cuenta', last_name: 'Prueba A', phone: '', city: 'Monterrey, NL' } }, sessions[0]);
  const names = await rpc('dopmi_my_account_names', {}, sessions[0]);
  assert.equal(names.first_name, 'Cuenta');
  assert.equal(names.last_name, 'Prueba A');
  journal.passed.push('private-name-roundtrip');
  assert.equal(await rpc('dopmi_my_account_photo', {}, sessions[0]), null);
  journal.stage = 'upload';
  const bytes = await readFile(new URL('../../apps/mobile/assets/onboarding/account-rescue.jpg', import.meta.url));
  const upload = await call(`/storage/v1/object/${bucket}/${path}`, bytes, sessions[0], 'POST', 'image/jpeg');
  assert.equal(upload.ok, true, `photo upload: HTTP ${upload.status}`);
  journal.passed.push('authenticated-jpeg-upload');
  journal.stage = 'link';
  for (let attempt = 0; attempt < 2; attempt++) {
    const receipt = await rpc('dopmi_save_account_photo', { photo_path: path }, sessions[0]);
    assert.equal(receipt.photo_path, path);
  }
  assert.equal((await rpc('dopmi_my_account_photo', {}, sessions[0])).photo_path, path);
  assert.equal(await rpc('dopmi_my_account_photo', {}, sessions[1]), null);
  journal.passed.push('private-link-read-and-idempotent-retry');
  journal.stage = 'storage-permissions';
  const signed = await call(`/storage/v1/object/sign/${bucket}/${path}`, { expiresIn: 60 }, sessions[0]);
  assert.equal(signed.ok, true);
  const signedData = await signed.json();
  const image = await fetch(config.url + '/storage/v1' + signedData.signedURL, { signal: AbortSignal.timeout(20000) });
  assert.equal(image.ok, true);
  assert.match(image.headers.get('content-type'), /^image\/jpeg/);
  for (const token of [sessions[1], undefined]) {
    assert.equal((await call(`/storage/v1/object/sign/${bucket}/${path}`, { expiresIn: 60 }, token)).ok, false);
  }
  const foreignSave = await call('/rest/v1/rpc/dopmi_save_account_photo', { photo_path: path }, sessions[1]);
  assert.equal(foreignSave.ok, false);
  journal.passed.push('owner-signed-read-peer-and-anonymous-denied');
  journal.stage = 'cleanup';
} finally {
  if (sessions[0]) {
    await rpc('dopmi_save_account_photo', { photo_path: null }, sessions[0]);
    const removal = await call(`/storage/v1/object/${bucket}`, { prefixes: [path] }, sessions[0], 'DELETE');
    assert.equal(removal.ok, true, `fixture removal: HTTP ${removal.status}`);
    assert.equal(await rpc('dopmi_my_account_photo', {}, sessions[0]), null);
    assert.equal((await call(`/storage/v1/object/sign/${bucket}/${path}`, { expiresIn: 60 }, sessions[0])).ok, false);
    journal.cleanup = true;
  }
  for (const token of sessions) await call('/auth/v1/logout?scope=global', {}, token);
  await writeFile(`${configPath}.state.json`, JSON.stringify(journal, null, 2));
  console.log(JSON.stringify(journal));
}
