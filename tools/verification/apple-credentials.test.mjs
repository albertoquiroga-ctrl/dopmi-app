import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { generateKeyPair, SignJWT, jwtVerify } from 'jose';
import { credentialCipher, appleTokenApi, appleCredentialService, appleIdentityVerifier } from '../../supabase/functions/_shared/apple-credentials.mjs';
const hash = async text => createHash('sha256').update(text).digest('hex');

test('real JWT verification rejects wrong issuer, audience, subject, nonce, expiry and signature', async () => {
  const {privateKey, publicKey} = await generateKeyPair('RS256');
  const verifier = appleIdentityVerifier({jwtVerify, keys:publicKey, audience:'com.mycompany.dopmi'});
  const claims = {iss:'https://appleid.apple.com',aud:'com.mycompany.dopmi',sub:'subject',nonce:'hash',
    iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+300};
  const sign = payload => new SignJWT(payload).setProtectedHeader({alg:'RS256'}).sign(privateKey);
  await verifier(await sign(claims), {subject:'subject',nonce:'hash'});
  for (const bad of [{iss:'other'},{aud:'other'},{sub:'other'},{nonce:'other'},{exp:1}]) {
    await assert.rejects(verifier(await sign({...claims,...bad}),{subject:'subject',nonce:'hash'}));
  }
  const foreign = await generateKeyPair('RS256');
  const fake = await new SignJWT(claims).setProtectedHeader({alg:'RS256'}).sign(foreign.privateKey);
  await assert.rejects(verifier(fake,{subject:'subject',nonce:'hash'}));
});

test('encryption is randomized, owner-bound and tamper-evident', async () => {
  const cipher = await credentialCipher(randomBytes(32).toString('base64'), 'v1');
  const a = await cipher.seal('owner-a', 'private-refresh-token');
  const b = await cipher.seal('owner-a', 'private-refresh-token');
  assert.notEqual(a.ciphertext, b.ciphertext);
  assert.equal(await cipher.open('owner-a', a), 'private-refresh-token');
  await assert.rejects(cipher.open('owner-b', a), /credential_unavailable/);
  await assert.rejects(cipher.open('owner-a', { ...a, key_id: 'v2' }), /credential_key_unavailable/);
  await assert.rejects(cipher.open('owner-a', { ...a, ciphertext: b.ciphertext }), /credential_unavailable/);
  assert.ok(!JSON.stringify(a).includes('private-refresh-token'));
  await assert.rejects(credentialCipher('bad', 'v1'), /identity_not_configured/);
});

test('Apple transport restricts endpoints, redirects and sanitizes failures', async () => {
  const calls = [];
  const api = appleTokenApi({ clientId: 'com.mycompany.dopmi', clientSecret: async () => 'secret',
    fetcher: async (url, options) => {
      calls.push(url); assert.equal(options.redirect, 'error');
      assert.equal(options.body.get('client_id'), 'com.mycompany.dopmi');
      assert.equal(options.body.get('client_secret'), 'secret');
      return url.endsWith('/token') ? Response.json({ refresh_token: 'refresh', id_token: 'signed' }) : new Response('');
    } });
  assert.deepEqual(await api.exchange('code'), { refreshToken: 'refresh', idToken: 'signed' });
  await api.revoke('refresh');
  assert.deepEqual(calls, ['https://appleid.apple.com/auth/token', 'https://appleid.apple.com/auth/revoke']);
  const failed = appleTokenApi({clientId:'app', clientSecret:async ()=>'secret', fetcher:async()=>new Response('secret', {status:400})});
  await assert.rejects(failed.exchange('code'), error => error.message === 'apple_unavailable');
});

async function fixture({ failSave = false, lostSaveResponse = false, invalidToken = false, failRevoke = false } = {}) {
  let row = null, exchanges = 0, revokes = 0;
  const cipher = await credentialCipher(randomBytes(32).toString('base64'), 'v1');
  const store = {
    get: async () => row,
    requireActive: async () => {},
    save: async (_, value) => {
      if (failSave) throw Error('database unavailable');
      row = value;
      if (lostSaveResponse) throw Error('response lost');
    },
    remove: async (_, key) => { assert.equal(row.request_hash, key); row = null; },
  };
  const service = appleCredentialService({ store, cipher, hash,
    api: { exchange: async () => { exchanges++; return { refreshToken: 'private-token', idToken: 'signed' }; },
      revoke: async () => { revokes++; if (failRevoke) throw Error('offline'); } },
    verifyToken: async (_, expected) => {
      assert.equal(expected.subject, 'apple-subject');
      assert.equal(expected.nonce, await hash('n'.repeat(32)));
      if (invalidToken) throw Error('wrong audience or nonce');
    },
  });
  const register = () => service.register({ id: 'owner', appleSubject: 'apple-subject' }, { code: 'authorization-code', nonce: 'n'.repeat(32) });
  return { service, register, row: () => row, exchanges: () => exchanges, revokes: () => revokes };
}

test('registration is encrypted and retries do not consume the code twice', async () => {
  const f = await fixture();
  assert.deepEqual(await f.register(), { registered: true });
  await f.register();
  assert.equal(f.exchanges(), 1);
  assert.ok(!JSON.stringify(f.row()).includes('private-token'));
  await f.service.revoke('owner');
  await f.service.revoke('owner');
  assert.equal(f.revokes(), 1);
  assert.equal(f.row(), null);
});
test('lost save response is reconciled without revoking the saved grant', async () => {
  const f = await fixture({ lostSaveResponse: true });
  assert.deepEqual(await f.register(), { registered: true });
  assert.equal(f.revokes(), 0);
});
test('invalid identity tokens and failed persistence never report success', async () => {
  for (const options of [{ invalidToken: true }, { failSave: true }]) {
    const f = await fixture(options);
    await assert.rejects(f.register(), /apple_registration_incomplete/);
    assert.equal(f.row(), null);
    assert.equal(f.revokes(), 1);
  }
});
test('failed revocation retains the encrypted token for retry', async () => {
  const f = await fixture({ failRevoke: true });
  await f.register();
  await assert.rejects(f.service.revoke('owner'));
  assert.ok(f.row());
});
test('registration requires a server-verified Apple identity and bounded inputs', async () => {
  const f = await fixture();
  await assert.rejects(f.service.register({ id: 'owner' }, { code: 'code', nonce: 'n'.repeat(32) }), /apple_identity_required/);
  await assert.rejects(f.service.register({ id: 'owner', appleSubject: 'subject' }, { code: 'code', nonce: '' }), /invalid_request/);
  assert.equal(f.exchanges(), 0);
});

test('database denies clients and binds server credentials to an active linked identity', async () => {
  const db = new PGlite();
  try {
    await db.exec(`create role anon; create role authenticated; create role service_role;
      create schema private; create schema auth;
      create table auth.users(id uuid primary key);
      create table auth.identities(user_id uuid, provider text, provider_id text);
      create table public.profiles(id uuid primary key, account_status text);
      grant usage on schema public to anon, authenticated, service_role;
      insert into auth.users values ('00000000-0000-4000-8000-000000000001');
      insert into public.profiles values ('00000000-0000-4000-8000-000000000001','active');
      insert into auth.identities values ('00000000-0000-4000-8000-000000000001','apple','subject');`);
    await db.exec(await readFile(new URL('../../supabase/migrations/20260928154523_h10_apple_credentials.sql', import.meta.url), 'utf8'));
    for (const role of ['anon', 'authenticated']) {
      await db.exec(`set role ${role}`);
      await assert.rejects(db.query(`select public.dopmi_apple_credential_server('get','00000000-0000-4000-8000-000000000001')`), /permission denied/);
      await assert.rejects(db.query('select * from private.dopmi_apple_credentials'), /permission denied/);
      await db.exec('reset role');
    }
    await db.exec('set role service_role');
    await assert.rejects(db.query(`select public.dopmi_apple_credential_server('save','00000000-0000-4000-8000-000000000001','wrong')`), /apple_identity_required/);
    const args = ['save','00000000-0000-4000-8000-000000000001','subject','a'.repeat(64), JSON.stringify({key_id:'v1',iv:'iv',ciphertext:'x'.repeat(30)})];
    await db.query('select public.dopmi_apple_credential_server($1,$2,$3,$4,$5)', args);
    await db.exec('reset role');
    await db.exec(`update public.profiles set account_status='suspended'`);
    await db.exec('set role service_role');
    await assert.rejects(db.query('select public.dopmi_apple_credential_server($1,$2,$3,$4,$5)', args), /apple_identity_required/);
    await assert.rejects(db.query(`select public.dopmi_apple_credential_server('remove',$1,null,$2)`, [args[1], 'b'.repeat(64)]), /credential_changed/);
    await db.query(`select public.dopmi_apple_credential_server('remove',$1,null,$2)`, [args[1], args[3]]);
  } finally { await db.close(); }
});
