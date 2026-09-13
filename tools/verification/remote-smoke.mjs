import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

// Read-only: uses a public key, never asks for a service-role key or logs tokens.
const config = JSON.parse(await readFile(new URL('../../apps/mobile/config.local.json', import.meta.url), 'utf8'));
assert.ok(config.SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_'), 'Use the public development key');
const base = config.SUPABASE_URL;
const headers = { apikey: config.SUPABASE_PUBLISHABLE_KEY, 'Content-Type': 'application/json' };
const settingsResponse = await fetch(`${base}/auth/v1/settings`, { headers });
assert.equal(settingsResponse.status, 200, 'Auth service reachable');
const settings = await settingsResponse.json();
assert.equal(settings.mailer_autoconfirm, false, 'Email confirmation must be required');
console.log('PASS: Auth reachable; confirmation required.');
for (const [path, method] of [
  ['/rest/v1/profiles?select=id&limit=1', 'GET'],
  ['/rest/v1/users?select=id&limit=1', 'GET'],
  ['/rest/v1/rpc/dopmi_is_admin', 'POST'],
  ['/rest/v1/rpc/admin_list_users', 'POST'],
]) {
  const response = await fetch(base + path, { method, headers, ...(method === 'POST' ? { body: '{}' } : {}) });
  assert.ok([401, 403].includes(response.status), `${path} must reject anonymous access (got ${response.status})`);
  console.log(`PASS: anonymous access rejected by ${path.split('?')[0]}.`);
}
