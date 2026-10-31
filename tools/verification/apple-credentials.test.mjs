import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
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
  assert.deepEqual(await f.service.revoke('owner'), { revoked: false });
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

test('Apple account deletion requires durable revocation and supports recovery without profile reactivation', async t => {
  const real = process.env.DOPMI_APPLE_DELETION_POSTGRES_TEST === 'true';
  const port = process.env.DOPMI_APPLE_DELETION_POSTGRES_PORT ?? '54322';
  assert.ok(['55439', '54322'].includes(port));
  const config = { host: '127.0.0.1', port: Number(port), user: 'postgres', database: 'postgres', connectionTimeoutMillis: 5000 };
  const database = `dopmi_apple_deletion_test_${randomUUID().replaceAll('-', '')}`;
  let db, admin, client, created = false;
  try {
    if (real) {
      admin = new pg.Client(config); await admin.connect();
      await admin.query(`create database "${database}" template template0`); created = true;
      client = new pg.Client({ ...config, database }); await client.connect();
      db = { exec: sql => client.query(sql), query: (sql, args) => client.query(sql, args) };
    } else db = new PGlite();
    await db.exec(`do $$begin
      if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
      if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
      if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
      end$$;
      create schema auth; create schema storage;
      create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
      create table auth.identities(user_id uuid references auth.users(id) on delete cascade, provider text, provider_id text);
      create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth,public to anon,authenticated,service_role;
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
      alter table storage.objects enable row level security;
      grant usage on schema storage to authenticated;
      grant select,insert,update,delete on storage.objects to authenticated;`);
    const path = new URL('../../supabase/migrations/', import.meta.url);
    for (const file of (await readdir(path)).filter(x => x.endsWith('.sql')).sort())
      await db.exec(await readFile(new URL(file, path), 'utf8'));
    let sequence = 20;
    const owner = async (provider = 'apple') => {
      const id = `00000000-0000-4000-8000-${String(sequence++).padStart(12, '0')}`;
      await db.query(`insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())`, [id, `${sequence}@example.test`]);
      if (provider) await db.query('insert into auth.identities values($1,$2,$3)', [id, provider, `subject-${id}`]);
      return id;
    };
    const deletion = async (id, operation, requestKey = id) => (await db.query('select public.dopmi_account_deletion_server($1,$2::jsonb) value',
      [operation, JSON.stringify({ owner_id: id, request_key: requestKey })])).rows[0].value;
    const credential = async (id, operation, requestHash = 'a'.repeat(64), subject = `subject-${id}`) => (await db.query(
      'select public.dopmi_apple_credential_server($1,$2,$3,$4,$5) value',
      [operation, id, subject, requestHash, JSON.stringify({ key_id: 'v1', iv: 'iv', ciphertext: 'x'.repeat(30) })])).rows[0].value;
    const status = async id => (await db.query('select account_status from public.profiles where id=$1', [id])).rows[0].account_status;

    await t.test('orphaned Apple identity blocks request and direct Auth deletion before retiring the profile', async () => {
      const id = await owner();
      await assert.rejects(deletion(id, 'request'), /apple_reauthentication_required/);
      assert.equal(await status(id), 'active');
      await assert.rejects(db.query('delete from auth.users where id=$1', [id]), /apple_revocation_required/);
    });
    await t.test('legacy in-progress orphan blocks finalize and can recover a fresh grant while staying withdrawn', async () => {
      const id = await owner();
      await db.query("insert into private.dopmi_account_deletions(owner_id,request_key,status) values($1,$1,'procesando')", [id]);
      await db.query("update public.profiles set account_status='deletion_requested' where id=$1", [id]);
      assert.equal((await deletion(id, 'finalize')).attention_code, 'revocacion_apple_pendiente');
      await credential(id, 'require_active'); await credential(id, 'save');
      assert.equal(await status(id), 'deletion_requested');
      await assert.rejects(deletion(id, 'auth_cleanup'), /apple_revocation_required/);
      await credential(id, 'remove');
      assert.equal((await deletion(id, 'finalize')).status, 'completado');
      await assert.rejects(credential(id, 'require_active', 'b'.repeat(64)), /apple_identity_required/);
      await assert.rejects(credential(id, 'save', 'b'.repeat(64)), /apple_identity_required/);
      await db.query('delete from auth.users where id=$1', [id]);
    });
    await t.test('missing or mismatched remove cannot fabricate revocation evidence', async () => {
      const id = await owner();
      await db.query("insert into private.dopmi_account_deletions(owner_id,request_key,status) values($1,$1,'procesando')", [id]);
      await credential(id, 'remove');
      assert.equal((await deletion(id, 'finalize')).attention_code, 'revocacion_apple_pendiente');
      await credential(id, 'require_active'); await credential(id, 'save');
      await assert.rejects(credential(id, 'remove', 'b'.repeat(64)), /credential_changed/);
      assert.equal((await deletion(id, 'finalize')).attention_code, 'revocacion_apple_pendiente');
    });
    await t.test('provider revoke failure retains the credential and cannot finalize; retry succeeds durably', async () => {
      const id = await owner();
      const cipher = await credentialCipher(randomBytes(32).toString('base64'), 'v1');
      let failRevoke = true;
      const rpc = async (operation, extra = {}) => (await db.query(
        'select public.dopmi_apple_credential_server($1,$2,$3,$4,$5) value',
        [operation, id, extra.subject, extra.request_hash, extra.envelope && JSON.stringify(extra.envelope)])).rows[0].value;
      const service = appleCredentialService({ cipher, hash,
        api: { exchange: async () => ({ refreshToken: 'synthetic-private-token', idToken: 'signed' }),
          revoke: async () => { if (failRevoke) throw new Error('offline'); } },
        verifyToken: async () => {},
        store: { get: () => rpc('get'), requireActive: (_, subject, request_hash) => rpc('require_active', { subject, request_hash }),
          save: (_, row) => rpc('save', row), remove: (_, request_hash) => rpc('remove', { request_hash }),
          cancelRegistration: (_, request_hash) => rpc('cancel_registration', { request_hash }) },
      });
      await service.register({ id, appleSubject: `subject-${id}` }, { code: 'synthetic-code', nonce: 'n'.repeat(32) });
      await deletion(id, 'request');
      await assert.rejects(service.revoke(id), /offline/);
      assert.equal((await deletion(id, 'finalize')).attention_code, 'revocacion_apple_pendiente');
      assert.equal(await status(id), 'deletion_requested');
      failRevoke = false;
      assert.deepEqual(await service.revoke(id), { revoked: true });
      assert.equal((await deletion(id, 'finalize')).status, 'completado');
      assert.equal((await db.query('select apple_revoked_request_key=request_key proof from private.dopmi_account_deletions where owner_id=$1', [id])).rows[0].proof, true);
    });
    await t.test('new request key resumes the same owner job after revoke attention and Apple reauthentication', async () => {
      const id = await owner();
      const cipher = await credentialCipher(randomBytes(32).toString('base64'), 'v1');
      const rpc = async (operation, extra = {}) => (await db.query('select public.dopmi_apple_credential_server($1,$2,$3,$4,$5) value',
        [operation, id, extra.subject, extra.request_hash, extra.envelope && JSON.stringify(extra.envelope)])).rows[0].value;
      let failRevoke = true;
      const service = appleCredentialService({ cipher, hash, verifyToken: async () => {},
        api: { exchange: async code => ({ refreshToken: `synthetic-${code}`, idToken: 'signed' }),
          revoke: async () => { if (failRevoke) throw Error('offline'); } },
        store: { get: () => rpc('get'), requireActive: (_, subject, request_hash) => rpc('require_active', { subject, request_hash }),
          save: (_, row) => rpc('save', row), remove: (_, request_hash) => rpc('remove', { request_hash }),
          cancelRegistration: (_, request_hash) => rpc('cancel_registration', { request_hash }) },
      });
      const actor = { id, appleSubject: `subject-${id}` };
      await service.register(actor, { code: 'first-code', nonce: 'n'.repeat(32) });
      await deletion(id, 'request');
      await assert.rejects(service.revoke(id), /offline/);
      await deletion(id, 'attention');
      await service.register(actor, { code: 'reauth-code', nonce: 'n'.repeat(32) });
      const before = (await db.query('select to_jsonb(d) value from private.dopmi_account_deletions d where owner_id=$1', [id])).rows[0].value;
      const resumed = await deletion(id, 'request', randomUUID());
      assert.equal(resumed.status, 'requiere_atencion');
      assert.equal(resumed.request_key, undefined);
      assert.deepEqual((await db.query('select to_jsonb(d) value from private.dopmi_account_deletions d where owner_id=$1', [id])).rows[0].value, before);
      assert.equal((await db.query('select count(*)::int n from private.dopmi_account_deletions where owner_id=$1', [id])).rows[0].n, 1);
      assert.equal(before.request_key, id);
      assert.equal(await status(id), 'deletion_requested');
      failRevoke = false; await service.revoke(id);
      assert.equal((await deletion(id, 'finalize')).status, 'completado');
      assert.equal((await db.query('select apple_revoked_request_key=request_key proof from private.dopmi_account_deletions where owner_id=$1', [id])).rows[0].proof, true);
    });
    await t.test('actual Edge resumes completed Auth cleanup with a new key and keeps the canonical proof', async () => {
      const id = await owner();
      await credential(id, 'require_active'); await credential(id, 'save');
      let handler, authDeletes = 0, revokes = 0;
      const source = await readFile(new URL('../../supabase/functions/account-deletion/index.ts', import.meta.url), 'utf8');
      const script = stripTypeScriptTypes(source.replace(/^import .*;\r?$/gm, ''));
      const edgeDb = {
        rpc: async (name, args) => {
          try {
            if (name === 'dopmi_account_deletion_server') return { data: (await db.query('select public.dopmi_account_deletion_server($1,$2) value', [args.operation, JSON.stringify(args.data)])).rows[0].value };
            return { data: await credential(id, args.operation) };
          } catch (error) { return { error }; }
        },
        auth: { getUser: async () => ({ data: { user: { id, last_sign_in_at: new Date().toISOString() } } }),
          admin: { signOut: async () => ({}), deleteUser: async () => {
            authDeletes++;
            if (authDeletes === 1) return { error: { message: 'temporary Auth failure' } };
            await db.query('delete from auth.users where id=$1', [id]); return {};
          } } },
        storage: { from: () => ({ list: async () => ({ data: [] }) }) },
      };
      runInNewContext(script, { Response, Date, createClient: () => edgeDb,
        appleRuntime: async () => ({ service: { revoke: async () => { revokes++; await credential(id, 'remove'); } } }),
        Deno: { env: { get: () => 'synthetic-config' }, serve: value => { handler = value; } } });
      const request = request_key => new Request('https://example.test/account-deletion', { method: 'POST',
        headers: { Authorization: 'Bearer synthetic-token' }, body: JSON.stringify({ request_key, confirmation: 'ELIMINAR' }) });
      const first = await handler(request(id));
      assert.equal(first.status, 202); assert.equal((await first.json()).auth_cleanup, 'pending');
      const before = (await db.query('select to_jsonb(d) value from private.dopmi_account_deletions d where owner_id=$1', [id])).rows[0].value;
      const second = await handler(request(randomUUID()));
      assert.equal(second.status, 200); assert.equal((await second.json()).status, 'completado');
      assert.equal(authDeletes, 2); assert.equal(revokes, 1);
      assert.deepEqual((await db.query('select to_jsonb(d) value from private.dopmi_account_deletions d where owner_id=$1', [id])).rows[0].value, before);
      assert.equal((await db.query('select count(*)::int n from auth.users where id=$1', [id])).rows[0].n, 0);
    });
    await t.test('durable intent blocks deletion during deferred exchange and prevents blind exchange retries', async () => {
      const id = await owner();
      let exchanges = 0, release, entered;
      const started = new Promise(resolve => { entered = resolve; });
      const deferred = new Promise(resolve => { release = resolve; });
      const cipher = await credentialCipher(randomBytes(32).toString('base64'), 'v1');
      const rpc = async (operation, extra = {}) => (await db.query('select public.dopmi_apple_credential_server($1,$2,$3,$4,$5) value',
        [operation, id, extra.subject, extra.request_hash, extra.envelope && JSON.stringify(extra.envelope)])).rows[0].value;
      const service = appleCredentialService({ cipher, hash, verifyToken: async () => {},
        api: { exchange: async () => { exchanges++; entered(); await deferred; return { refreshToken: 'synthetic-token', idToken: 'signed' }; }, revoke: async () => {} },
        store: { get: () => rpc('get'), requireActive: (_, subject, request_hash) => rpc('require_active', { subject, request_hash }),
          save: (_, row) => rpc('save', row), remove: (_, request_hash) => rpc('remove', { request_hash }),
          cancelRegistration: (_, request_hash) => rpc('cancel_registration', { request_hash }) },
      });
      const actor = { id, appleSubject: `subject-${id}` }, input = { code: 'deferred-code', nonce: 'n'.repeat(32) };
      const pending = service.register(actor, input);
      await started;
      await assert.rejects(deletion(id, 'request'), /apple_registration_pending/);
      await assert.rejects(db.query('delete from auth.users where id=$1', [id]), /apple_revocation_required/);
      await assert.rejects(service.register(actor, input), /apple_registration_pending/);
      await assert.rejects(service.register(actor, { ...input, code: 'different-code' }), /apple_registration_pending/);
      assert.equal(exchanges, 1);
      release(); assert.deepEqual(await pending, { registered: true });
      assert.equal((await credential(id, 'get')).pending_request_hash, null);
      await deletion(id, 'request'); await service.revoke(id);
      assert.equal((await deletion(id, 'finalize')).status, 'completado');
    });
    await t.test('uncertain exchange remains blocked; a definitive no-grant response permits a fresh retry', async () => {
      for (const noGrant of [false, true]) {
        const id = await owner();
        const cipher = await credentialCipher(randomBytes(32).toString('base64'), 'v1');
        const rpc = async (operation, extra = {}) => (await db.query('select public.dopmi_apple_credential_server($1,$2,$3,$4,$5) value',
          [operation, id, extra.subject, extra.request_hash, extra.envelope && JSON.stringify(extra.envelope)])).rows[0].value;
        let fail = true;
        const service = appleCredentialService({ cipher, hash, verifyToken: async () => {},
          api: { exchange: async () => { if (fail) throw Object.assign(new Error('provider failure'), { noGrant }); return { refreshToken: 'synthetic-token', idToken: 'signed' }; }, revoke: async () => {} },
          store: { get: () => rpc('get'), requireActive: (_, subject, request_hash) => rpc('require_active', { subject, request_hash }),
            save: (_, row) => rpc('save', row), remove: (_, request_hash) => rpc('remove', { request_hash }),
            cancelRegistration: (_, request_hash) => rpc('cancel_registration', { request_hash }) },
        });
        const actor = { id, appleSubject: `subject-${id}` }, input = { code: 'failed-code', nonce: 'n'.repeat(32) };
        await assert.rejects(service.register(actor, input), /apple_registration_incomplete/);
        fail = false;
        if (noGrant) assert.deepEqual(await service.register(actor, { ...input, code: 'fresh-code' }), { registered: true });
        else {
          await assert.rejects(service.register(actor, { ...input, code: 'fresh-code' }), /apple_registration_pending/);
          await assert.rejects(service.revoke(id), /apple_registration_pending/);
        }
      }
    });
    await t.test('failed validation or persistence clears intent only after confirmed revoke of the unpersisted grant', async () => {
      for (const phase of ['validation', 'persistence']) for (const revokeFails of [false, true]) {
        const id = await owner();
        const cipher = await credentialCipher(randomBytes(32).toString('base64'), 'v1');
        const rpc = async (operation, extra = {}) => (await db.query('select public.dopmi_apple_credential_server($1,$2,$3,$4,$5) value',
          [operation, id, extra.subject, extra.request_hash, extra.envelope && JSON.stringify(extra.envelope)])).rows[0].value;
        let fail = true, revokes = 0;
        const service = appleCredentialService({ cipher, hash,
          verifyToken: async () => { if (fail && phase === 'validation') throw Error('invalid token'); },
          api: { exchange: async () => ({ refreshToken: 'synthetic-token', idToken: 'signed' }),
            revoke: async () => { revokes++; if (revokeFails) throw Error('offline'); } },
          store: { get: () => rpc('get'), requireActive: (_, subject, request_hash) => rpc('require_active', { subject, request_hash }),
            save: (_, row) => { if (fail && phase === 'persistence') throw Error('save unavailable'); return rpc('save', row); },
            remove: (_, request_hash) => rpc('remove', { request_hash }),
            cancelRegistration: (_, request_hash) => rpc('cancel_registration', { request_hash }) },
        });
        const actor = { id, appleSubject: `subject-${id}` }, input = { code: `${phase}-code`, nonce: 'n'.repeat(32) };
        await assert.rejects(service.register(actor, input), /apple_registration_incomplete/);
        assert.equal(revokes, 1);
        assert.equal(await status(id), 'active');
        if (revokeFails) {
          assert.ok((await credential(id, 'get')).pending_request_hash);
          await assert.rejects(deletion(id, 'request'), /apple_registration_pending/);
        } else {
          assert.equal(await credential(id, 'get'), null);
          fail = false;
          assert.deepEqual(await service.register(actor, { ...input, code: 'fresh-code' }), { registered: true });
        }
      }
    });
    await t.test('legacy deleted presentation with an unfinished job can recover without restoring access', async () => {
      const id = await owner();
      await db.query("insert into private.dopmi_account_deletions(owner_id,request_key,status) values($1,$1,'procesando')", [id]);
      await db.query("update public.profiles set account_status='deleted' where id=$1", [id]);
      await credential(id, 'require_active'); await credential(id, 'save');
      assert.equal(await status(id), 'deleted');
      await credential(id, 'remove'); assert.equal((await deletion(id, 'finalize')).status, 'completado');
    });
    await t.test('a newly registered grant invalidates the previous operation proof', async () => {
      const id = await owner();
      await credential(id, 'require_active'); await credential(id, 'save');
      await deletion(id, 'request'); await credential(id, 'remove');
      await credential(id, 'require_active', 'b'.repeat(64)); await credential(id, 'save', 'b'.repeat(64));
      assert.equal((await deletion(id, 'finalize')).attention_code, 'revocacion_apple_pendiente');
      await credential(id, 'remove', 'b'.repeat(64));
      assert.equal((await deletion(id, 'finalize')).status, 'completado');
    });
    await t.test('clients cannot attest another owner or bypass server-only deletion authorization', async () => {
      const id = await owner(), other = await owner();
      await assert.rejects(credential(id, 'save', 'a'.repeat(64), `subject-${other}`), /apple_identity_required/);
      for (const role of ['anon', 'authenticated']) {
        await db.exec(`set role ${role}`);
        await assert.rejects(credential(other, 'remove'), /permission denied/);
        await assert.rejects(deletion(other, 'finalize'), /permission denied/);
        await db.exec('reset role');
      }
    });
    await t.test('Google-only and email accounts retain the existing deletion path', async () => {
      for (const provider of ['google', null]) {
        const id = await owner(provider);
        assert.equal((await deletion(id, 'request')).status, 'procesando');
        assert.equal((await deletion(id, 'finalize')).status, 'completado');
        await deletion(id, 'auth_cleanup');
        await db.query('delete from auth.users where id=$1', [id]);
      }
    });
    await t.test('real PostgreSQL serializes finalize versus save in both orders', { skip: !real }, async () => {
      const a = new pg.Client({ ...config, database }), b = new pg.Client({ ...config, database });
      await a.connect(); await b.connect();
      const waitForLock = async () => {
        const deadline = Date.now() + 5000;
        while (Date.now() < deadline) {
          const state = (await client.query("select wait_event_type from pg_stat_activity where pid=$1", [b.processID])).rows[0];
          if (state?.wait_event_type === 'Lock') return;
          await new Promise(resolve => setTimeout(resolve, 10));
        }
        assert.fail('second session did not wait on the account lock');
      };
      try {
        for (const first of ['finalize', 'save']) {
          const id = await owner();
          await credential(id, 'require_active'); await credential(id, 'save');
          await deletion(id, 'request'); await credential(id, 'remove');
          const finalize = connection => connection.query('select public.dopmi_account_deletion_server($1,$2::jsonb) value', ['finalize', JSON.stringify({ owner_id: id })]);
          const save = async connection => {
            await connection.query('select public.dopmi_apple_credential_server($1,$2,$3,$4) value', ['require_active', id, `subject-${id}`, 'b'.repeat(64)]);
            return connection.query('select public.dopmi_apple_credential_server($1,$2,$3,$4,$5) value',
              ['save', id, `subject-${id}`, 'b'.repeat(64), JSON.stringify({ key_id: 'v1', iv: 'iv', ciphertext: 'x'.repeat(30) })]);
          };
          await a.query('begin');
          await (first === 'finalize' ? finalize(a) : save(a));
          const pending = (first === 'finalize' ? save(b) : finalize(b)).then(value => ({ value }), error => ({ error }));
          await waitForLock(); await a.query('commit');
          const outcome = await pending;
          if (first === 'finalize') {
            assert.match(outcome.error?.message ?? '', /apple_identity_required/);
            assert.equal(await credential(id, 'get'), null);
          } else {
            assert.equal(outcome.value.rows[0].value.attention_code, 'revocacion_apple_pendiente');
            assert.ok(await credential(id, 'get'));
          }
        }
      } finally { await a.query('rollback'); await a.end(); await b.end(); }
    });
  } finally {
    if (real) { await client?.end(); if (created) await admin.query(`drop database "${database}"`); await admin?.end(); }
    else await db?.close();
  }
});

test('actual deletion Edge handler blocks orphan and legacy cleanup and keeps failed revocation retryable', async () => {
  const source = await readFile(new URL('../../supabase/functions/account-deletion/index.ts', import.meta.url), 'utf8');
  const script = stripTypeScriptTypes(source.replace(/^import .*;\r?$/gm, ''));
  const key = '00000000-0000-4000-8000-000000000001';
  const request = () => new Request('https://example.test/account-deletion', { method: 'POST',
    headers: { Authorization: 'Bearer synthetic-token' }, body: JSON.stringify({ request_key: key, confirmation: 'ELIMINAR' }) });
  const fixture = ({ orphan = false, legacy = false, failRevoke = false, google = false } = {}) => {
    const events = []; let handler;
    const db = { auth: { getUser: async () => ({ data: { user: { id: key, last_sign_in_at: new Date().toISOString() } } }),
      admin: { signOut: async () => { events.push('signOut'); return {}; }, deleteUser: async () => { events.push('deleteUser'); return {}; } } },
      rpc: async (name, args) => {
        const operation = args.operation; events.push(`${name}:${operation}`);
        if (name === 'dopmi_apple_credential_server') return { data: google ? null : {} };
        if ((orphan && operation === 'request') || (legacy && operation === 'auth_cleanup'))
          return { error: { message: orphan ? 'apple_reauthentication_required' : 'apple_revocation_required' } };
        return { data: { status: legacy || operation === 'finalize' ? 'completado' : operation === 'attention' ? 'requiere_atencion' : 'procesando' } };
      }, storage: { from: () => ({ list: async () => ({ data: [] }) }) } };
    runInNewContext(script, { Response, Date, createClient: () => db,
      appleRuntime: async () => ({ service: { revoke: async () => { events.push('revoke'); if (failRevoke) throw Error('offline'); } } }),
      Deno: { env: { get: () => 'synthetic-config' }, serve: value => { handler = value; } } });
    return { handler, events };
  };
  for (const scenario of [{ orphan: true }, { legacy: true }]) {
    const f = fixture(scenario), response = await f.handler(request());
    assert.equal(response.status, 409); assert.equal((await response.json()).error, 'apple_reauthentication_required');
    assert.ok(!f.events.includes('deleteUser')); assert.ok(!f.events.includes('signOut'));
  }
  const failed = fixture({ failRevoke: true });
  assert.equal((await failed.handler(request())).status, 409);
  assert.ok(!failed.events.includes('dopmi_account_deletion_server:finalize'));
  assert.ok(!failed.events.includes('deleteUser'));
  const google = fixture({ google: true });
  assert.equal((await google.handler(request())).status, 200);
  assert.ok(google.events.indexOf('dopmi_account_deletion_server:auth_cleanup') < google.events.indexOf('deleteUser'));
});
