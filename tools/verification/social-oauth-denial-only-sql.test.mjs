import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID, createHash } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { socialHandler, socialCallback } from '../../supabase/functions/_shared/social-verification.mjs';

// Opt-in real PostgreSQL uses only a fresh database on the existing local test
// cluster. No remote URL, existing application DB, provider call or user fixture.
const real = process.env.DOPMI_SOCIAL_DENIAL_POSTGRES_TEST === 'true';
const port = process.env.DOPMI_SOCIAL_DENIAL_POSTGRES_PORT ?? '55439';
assert.ok(['55439', '54322'].includes(port), 'Only the two explicit local PostgreSQL test ports are accepted');
const config = { host: '127.0.0.1', port: Number(port), user: 'postgres', database: 'postgres', connectionTimeoutMillis: 5000 };
const database = `dopmi_denial_test_${randomUUID().replaceAll('-', '')}`;
let db, admin, client, created = false;
const sources = [];
before(async () => {
  if (real) {
    admin = new pg.Client(config); await admin.connect();
    assert.equal(admin.connectionParameters.host, '127.0.0.1');
    assert.equal(admin.connectionParameters.port, Number(port));
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
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  const path = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(path)).filter(x => x.endsWith('.sql')).sort()) {
    const bytes = await readFile(new URL(file, path));
    await db.exec(bytes.toString('utf8'));
    sources.push({ file, sha256: createHash('sha256').update(bytes).digest('hex') });
  }
  console.log(`${real ? 'PostgreSQL real' : 'PGlite'}: ${sources.length} migrations; isolated synthetic social actors only`);
}, { timeout: 120000 });
after(async () => {
  if (real) { await client?.end(); if (created) await admin.query(`drop database "${database}"`); await admin?.end(); }
  else await db?.close();
});
async function fixture() {
  const owner = randomUUID(), session = randomUUID(), other = randomUUID(), otherSession = randomUUID();
  for (const id of [owner, other]) await db.query(`insert into auth.users(id,email_confirmed_at,raw_user_meta_data)
    values($1,now(),'{"admin":true,"role":"admin","mode":"rescuer","social_denial_allowed":true}')`, [id]);
  await db.query('insert into auth.sessions(id,user_id) values($1,$2),($3,$4)', [session, owner, otherSession, other]);
  const id = (await db.query(`insert into private.social_oauth_denial_grants(owner_id,session_id,starts_at,expires_at)
    values($1,$2,clock_timestamp()-interval '1 second',clock_timestamp()+interval '14 minutes') returning id`, [owner, session])).rows[0].id;
  return { owner, session, other, otherSession, id };
}
const available = async (f, owner = f.owner, session = f.session) => (await db.query(
  'select public.social_verification_denial_available($1,$2) as value', [owner, session])).rows[0].value;
const hash = () => createHash('sha256').update(randomUUID()).digest('hex');
const start = async (f, { owner = f.owner, session = f.session, provider = 'facebook', state = hash() } = {}) =>
  (await db.query('select public.social_verification_denial_start($1,$2,$3,$4) as id', [owner, session, provider, state])).rows[0].id;

test('permission is bound to actor and live exact session, not editable metadata or another provider', async () => {
  const f = await fixture();
  assert.equal(await available(f), true);
  for (const [owner, session] of [[f.other, f.otherSession], [f.owner, f.otherSession], [f.other, f.session], [f.owner, null]]) {
    assert.equal(await available(f, owner, session), false);
    await assert.rejects(start(f, { owner, session }), /denial_unavailable/);
  }
  await assert.rejects(start(f, { provider: 'instagram' }), /denial_unavailable/);
  await db.query('update auth.sessions set not_after=clock_timestamp() where id=$1', [f.session]);
  assert.equal(await available(f), false);
  await assert.rejects(start(f), /denial_unavailable/);
});

test('one start consumes permission atomically; lost response, retries and attempt retention cannot reopen it', async () => {
  const f = await fixture(), state = hash();
  const attempt = await start(f, { state }); // Caller discards the successful response.
  assert.equal(await available(f), false);
  await assert.rejects(start(f), /denial_unavailable/);
  await assert.rejects(start(f, { state }), /denial_unavailable/);
  const a = (await db.query('select purpose,status,expires_at,created_at from public.social_verification_attempts where id=$1', [attempt])).rows[0];
  assert.equal(a.purpose, 'denial_only'); assert.equal(a.status, 'pending');
  assert.equal(new Date(a.expires_at) - new Date(a.created_at), 600000);
  assert.equal((await db.query('select count(*)::int as n from public.social_verification_attempts where owner_id=$1', [f.owner])).rows[0].n, 1);
  await db.query('delete from public.social_verification_attempts where id=$1', [attempt]);
  assert.equal(await available(f), false); await assert.rejects(start(f), /denial_unavailable/);
  const g = (await db.query('select consumed_at,consumed_attempt_id from private.social_oauth_denial_grants where id=$1', [f.id])).rows[0];
  assert.ok(g.consumed_at); assert.equal(g.consumed_attempt_id, attempt);
});

test('window, revocation and live-session checks apply at start and callback; expiry is capped by grant', async () => {
  const future = await fixture();
  await db.query("update private.social_oauth_denial_grants set starts_at=clock_timestamp()+interval '1 minute',expires_at=clock_timestamp()+interval '2 minutes' where id=$1", [future.id]);
  assert.equal(await available(future), false); await assert.rejects(start(future), /denial_unavailable/);
  const expired = await fixture();
  await db.query("update private.social_oauth_denial_grants set starts_at=clock_timestamp()-interval '2 minutes',expires_at=clock_timestamp()-interval '1 minute' where id=$1", [expired.id]);
  assert.equal(await available(expired), false); await assert.rejects(start(expired), /denial_unavailable/);
  for (const invalidation of ['grant_expired', 'session_expired', 'grant_revoked', 'attempt_expired']) {
    const f = await fixture(), state = hash();
    await db.query("update private.social_oauth_denial_grants set expires_at=clock_timestamp()+interval '1 minute' where id=$1", [f.id]);
    const attempt = await start(f, { state });
    const expiry = (await db.query(`select a.expires_at=g.expires_at as capped from public.social_verification_attempts a
      join private.social_oauth_denial_grants g on g.consumed_attempt_id=a.id where a.id=$1`, [attempt])).rows[0];
    assert.equal(expiry.capped, true);
    if (invalidation === 'grant_expired') await db.query("update private.social_oauth_denial_grants set expires_at=clock_timestamp()-interval '1 millisecond' where id=$1", [f.id]);
    if (invalidation === 'session_expired') await db.query('update auth.sessions set not_after=clock_timestamp() where id=$1', [f.session]);
    if (invalidation === 'grant_revoked') await db.query('update private.social_oauth_denial_grants set revoked_at=clock_timestamp() where id=$1', [f.id]);
    if (invalidation === 'attempt_expired') await db.query('update public.social_verification_attempts set expires_at=clock_timestamp() where id=$1', [attempt]);
    assert.deepEqual((await db.query('select * from public.social_verification_consume($1)', [state])).rows, []);
    await assert.rejects(db.query('select public.social_verification_finish($1,$2,$3)', [attempt, '77', 'Synthetic']), /invalid_attempt/);
  }
});

test('a consumed denial state cannot be finished even by the server; ordinary verification remains supported', async () => {
  const f = await fixture(), state = hash(), attempt = await start(f, { state });
  const consumed = await db.query('select * from public.social_verification_consume($1)', [state]);
  assert.equal(consumed.rows[0].purpose, 'denial_only'); assert.equal(consumed.rows[0].status, 'processing');
  assert.equal((await db.query('select * from public.social_verification_consume($1)', [state])).rows.length, 0);
  await assert.rejects(db.query('select public.social_verification_finish($1,$2,$3)', [attempt, '42', 'Synthetic']), /invalid_attempt/);
  assert.equal((await db.query('select count(*)::int as n from public.social_verification_proofs where owner_id=$1', [f.owner])).rows[0].n, 0);
  const normalState = hash();
  const normal = (await db.query('select public.social_verification_start($1,$2,$3,$4) as id', [f.other, f.otherSession, 'facebook', normalState])).rows[0].id;
  assert.equal((await db.query('select * from public.social_verification_consume($1)', [normalState])).rows[0].purpose, 'verification');
  await db.query('select public.social_verification_finish($1,$2,$3)', [normal, '51', 'Synthetic normal']);
  assert.equal((await db.query('select status from public.social_verification_attempts where id=$1', [normal])).rows[0].status, 'verified');
});

test('global-flag drift cannot create an ordinary proof for an actor/session whose denial permission is active', async () => {
  const f = await fixture();
  const normal = () => db.query('select public.social_verification_start($1,$2,$3,$4)', [f.owner, f.session, 'facebook', hash()]);
  await assert.rejects(normal(), /denial_only_required/);
  await start(f);
  await assert.rejects(normal(), /denial_only_required/);
  assert.equal((await db.query('select count(*)::int as n from public.social_verification_attempts where owner_id=$1 and purpose=$2', [f.owner, 'verification'])).rows[0].n, 0);
});

test('client roles cannot configure/read permissions or execute private server entrypoints; service has no grant DML', async () => {
  for (const role of ['anon', 'authenticated']) {
    await db.exec(`set role ${role}`);
    try {
      await assert.rejects(db.query('select * from private.social_oauth_denial_grants'), /permission denied/);
      await assert.rejects(db.query('select public.social_verification_denial_available($1,$2)', [randomUUID(), randomUUID()]), /permission denied/);
      await assert.rejects(db.query('select public.social_verification_denial_start($1,$2,$3,$4)', [randomUUID(), randomUUID(), 'facebook', hash()]), /permission denied/);
      await assert.rejects(db.query('select public.social_verification_finish($1,$2,$3)', [randomUUID(), '42', 'Synthetic']), /permission denied/);
    } finally { await db.exec('reset role'); }
  }
  for (const privilege of ['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
    assert.equal((await db.query("select has_table_privilege('service_role','private.social_oauth_denial_grants',$1) as allowed", [privilege])).rows[0].allowed, false);
  assert.equal((await db.query("select relrowsecurity from pg_class where oid='private.social_oauth_denial_grants'::regclass")).rows[0].relrowsecurity, true);
});

test('permission rejects widened provider, purpose, budget, duration and mismatched consumption markers', async () => {
  const f = await fixture();
  for (const update of ["provider='instagram'", "purpose='verification'", 'max_starts=2', "project_ref='other'", "expires_at=starts_at+interval '16 minutes'", 'consumed_at=clock_timestamp()'])
    await assert.rejects(db.query(`update private.social_oauth_denial_grants set ${update} where id=$1`, [f.id]), /check constraint/);
});

function runtime(f) {
  return {
    env: key => ({ SUPABASE_URL: 'https://ohqxranynackjignryep.supabase.co', SOCIAL_VERIFICATION_ENABLED: 'false',
      SOCIAL_FACEBOOK_CLIENT_ID: '123', SOCIAL_FACEBOOK_CLIENT_SECRET: 'synthetic-secret',
      SOCIAL_VERIFICATION_CALLBACK_URL: 'https://ohqxranynackjignryep.supabase.co/functions/v1/social-verification-callback' })[key],
    authenticate: async () => ({ id: f.owner, session_id: f.session }),
    list: async owner => (await db.query('select provider,label,verified_at from public.social_verification_proofs where owner_id=$1', [owner])).rows,
    denialAvailable: (owner, session) => available(f, owner, session),
    startDenial: async (owner, session, provider, state) => ({ id: await start(f, { owner, session, provider, state }) }),
    consume: async state => (await db.query('select * from public.social_verification_consume($1)', [state])).rows[0] ?? null,
    fail: (id, status) => db.query("update public.social_verification_attempts set status=$2 where id=$1 and status='processing'", [id, status]),
    finish: () => assert.fail('denial-only endpoint cannot finish'),
    fetcher: () => assert.fail('denial-only endpoint cannot call provider'),
  };
}
const request = body => new Request('https://local', { method: 'POST', headers: { Authorization: 'Bearer authoritative-test-session' }, body: JSON.stringify(body) });
async function financeCounts() {
  const tables = (await db.query(`select schemaname,tablename from pg_tables where schemaname in ('private','public')
    and (tablename like 'dopmi_guardian_%' or tablename in ('dopmi_donations','dopmi_checkouts','dopmi_payment_jobs','dopmi_refund_adjustments','dopmi_case_allocations')) order by schemaname,tablename`)).rows;
  for (const required of ['dopmi_donations', 'dopmi_guardian_registrations', 'dopmi_case_allocations'])
    assert.ok(tables.some(t => t.tablename === required), `Financial footprint must cover ${required}`);
  const counts = {};
  for (const table of tables) {
    assert.match(table.tablename, /^[a-z_]+$/);
    counts[table.tablename] = (await db.query(`select count(*)::int as n,
      md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,'[]')) as digest
      from ${table.schemaname}.${table.tablename} t`)).rows[0];
  }
  return counts;
}

test('Edge/SQL together preserve one attempt after a lost HTTP response and close the availability', async () => {
  const f = await fixture(), rt = runtime(f);
  const create = rt.startDenial;
  rt.startDenial = async (...args) => { await create(...args); throw new Error('response_lost_after_commit'); };
  const handler = socialHandler(rt);
  assert.equal((await handler(request({ operation: 'start', provider: 'facebook' }))).status, 400);
  assert.equal((await handler(request({ operation: 'start', provider: 'facebook' }))).status, 503);
  assert.deepEqual((await (await handler(request({ operation: 'list' }))).json()).available_providers, []);
  const attempts = (await db.query('select id,purpose,status from public.social_verification_attempts where owner_id=$1', [f.owner])).rows;
  assert.equal(attempts.length, 1); assert.equal(attempts[0].purpose, 'denial_only'); assert.equal(attempts[0].status, 'pending');
});

test('local real-state callback denial and mistaken positive code both leave account and financial data unchanged', async () => {
  const counts = await financeCounts();
  for (const outcome of ['error=access_denied', 'code=positive-code']) {
    const f = await fixture(), rt = runtime(f);
    const profile = (await db.query('select to_jsonb(p) as value from public.profiles p where id=$1', [f.owner])).rows[0].value;
    const user = (await db.query('select to_jsonb(u) as value from auth.users u where id=$1', [f.owner])).rows[0].value;
    const handler = socialHandler(rt);
    const startResponse = await handler(request({ operation: 'start', provider: 'facebook' }));
    assert.equal(startResponse.status, 200);
    const begun = await startResponse.json(), state = new URL(begun.authorization_url).searchParams.get('state');
    const callback = socialCallback(rt);
    assert.equal((await callback(new Request(`https://local?state=${state}&${outcome}`))).status, outcome.startsWith('error') ? 200 : 400);
    assert.equal((await callback(new Request(`https://local?state=${state}&${outcome}`))).status, 400);
    const attempt = (await db.query('select status from public.social_verification_attempts where id=$1', [begun.attempt_id])).rows[0];
    assert.equal(attempt.status, outcome.startsWith('error') ? 'denied' : 'failed');
    assert.equal((await db.query('select count(*)::int as n from public.social_verification_proofs where owner_id=$1', [f.owner])).rows[0].n, 0);
    assert.deepEqual((await db.query('select to_jsonb(p) as value from public.profiles p where id=$1', [f.owner])).rows[0].value, profile);
    assert.deepEqual((await db.query('select to_jsonb(u) as value from auth.users u where id=$1', [f.owner])).rows[0].value, user);
  }
  assert.deepEqual(await financeCounts(), counts);
});

test('two real concurrent starts create one attempt and one permanently consumed permission', { skip: !real }, async () => {
  const f = await fixture(), a = new pg.Client({ ...config, database }), b = new pg.Client({ ...config, database });
  await a.connect(); await b.connect();
  try {
    const calls = await Promise.allSettled([a, b].map(c => c.query('select public.social_verification_denial_start($1,$2,$3,$4) as id', [f.owner, f.session, 'facebook', hash()])));
    assert.equal(calls.filter(c => c.status === 'fulfilled').length, 1);
    assert.match(calls.find(c => c.status === 'rejected').reason.message, /denial_unavailable/);
    assert.equal((await db.query('select count(*)::int as n from public.social_verification_attempts where owner_id=$1', [f.owner])).rows[0].n, 1);
    assert.equal(await available(f), false);
  } finally { await a.end(); await b.end(); }
});

test('lock waits cannot extend a grant past its database-clock expiry', { skip: !real }, async () => {
  const f = await fixture(), blocker = new pg.Client({ ...config, database }), waiting = new pg.Client({ ...config, database });
  await blocker.connect(); await waiting.connect();
  try {
    await blocker.query('begin');
    await blocker.query("update private.social_oauth_denial_grants set expires_at=clock_timestamp()+interval '250 milliseconds' where id=$1", [f.id]);
    // The waiting start transaction begins before expiry and blocks on the row.
    const result = waiting.query('select public.social_verification_denial_start($1,$2,$3,$4)', [f.owner, f.session, 'facebook', hash()]);
    const observed = result.then(() => ({ ok: true }), e => ({ error: e.message }));
    await blocker.query('select pg_sleep(0.4)'); await blocker.query('commit');
    assert.match((await observed).error, /denial_unavailable/);
    assert.equal((await db.query('select count(*)::int as n from public.social_verification_attempts where owner_id=$1', [f.owner])).rows[0].n, 0);
  } finally { await blocker.query('rollback'); await blocker.end(); await waiting.end(); }
});
