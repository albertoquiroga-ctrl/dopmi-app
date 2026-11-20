import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { setTimeout as pause } from 'node:timers/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';

const migration = '20261120210928_adoption_measurement_consent_revision.sql';
const owner = randomUUID(), other = randomUUID(), existing = randomUUID();
const metadata = { display_name: 'Persona sintética', terms_version: 'terms-2026-10-17',
  privacy_version: 'privacy-2026-10-17', adult_confirmed: true };
let db, legacyBody;
const value = async (sql, params = []) => (await db.query(sql, params)).rows[0]?.value;
const state = () => value('select public.dopmi_adoption_measurement_state() value');
const set = (consent, expected) => value('select public.dopmi_set_adoption_measurement_v2($1,$2) value', [consent, expected]);

async function bootstrap(target) {
  await target.exec(`create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz,created_at timestamptz default now());
    create table auth.identities(user_id uuid,provider text,provider_id text);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('role',current_setting('role',true))$$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to anon,authenticated;
    grant select on storage.objects to anon;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(directory)).filter(file => file.endsWith('.sql') && file <= migration).sort()) {
    if (file === migration) {
      legacyBody = (await target.query("select prosrc value from pg_proc where oid='public.dopmi_set_adoption_measurement(boolean)'::regprocedure")).rows[0].value;
      await target.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)', [existing, existing + '@example.test', metadata]);
      await target.query('insert into private.dopmi_adoption_measurement(actor_id,consent) values($1,true)', [existing]);
    }
    await target.exec(await readFile(new URL(file, directory), 'utf8'));
  }
}

async function actor(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
  await db.exec('set local role ' + role);
}
async function rejects(operation, code) {
  await db.exec('savepoint rejected');
  await assert.rejects(operation, { code });
  await db.exec('rollback to savepoint rejected; release savepoint rejected');
}
async function attributionWithGreeting() {
  await db.query("select public.dopmi_record_android_rescuer_acquisition('personal-a',clock_timestamp()-interval '1 minute')");
  await db.exec('reset role');
  const post = randomUUID();
  await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Mascota sintética','published')", [post, other]);
  await actor(owner);
  return value('select public.dopmi_start_adoption_contact($1) value', [post]);
}
async function privateCounts(id = owner) {
  await db.exec('reset role');
  return value(`select jsonb_build_object(
    'sources',(select count(*) from private.dopmi_android_rescuer_acquisition where actor_id=$1),
    'events',(select count(*) from private.dopmi_android_acquisition_events where actor_id=$1)
  ) value`, [id]);
}

before(async () => {
  db = new PGlite();
  await db.exec('create role anon; create role authenticated; create role service_role');
  await bootstrap(db);
  for (const id of [owner, other]) {
    await db.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)', [id, id + '@example.test', metadata]);
  }
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('missing consent reads false/revision zero without creating a measurement row', async () => {
  assert.notEqual(await value("select to_regprocedure('public.dopmi_adoption_measurement_state()')::text value"), null);
  await actor(owner);
  assert.deepEqual(await state(), { consent: false, revision: 0 });
  assert.deepEqual(await state(), { consent: false, revision: 0 });
  await db.exec('reset role');
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_measurement where actor_id=$1', [owner]), 0);
});

test('a measurement retained from before the migration keeps its consent and revision zero', async () => {
  await actor(existing);
  assert.deepEqual(await state(), { consent: true, revision: 0 });
  await db.exec('select public.dopmi_set_adoption_measurement(false)');
  assert.deepEqual(await state(), { consent: false, revision: 1 });
});

test('CAS ON then OFF increments revisions and a delayed ON cannot restore attribution or milestones', async () => {
  await actor(owner);
  assert.deepEqual(await set(true, 0), { applied: true, consent: true, revision: 1 });
  const thread = await attributionWithGreeting();
  assert.deepEqual(await privateCounts(), { sources: 1, events: 1 });
  await actor(owner);
  assert.deepEqual(await set(false, 1), { applied: true, consent: false, revision: 2 });
  assert.deepEqual(await privateCounts(), { sources: 0, events: 0 });
  await actor(owner);
  assert.deepEqual(await set(true, 1), { applied: false, consent: false, revision: 2 });
  assert.deepEqual(await state(), { consent: false, revision: 2 });
  await db.query("select public.dopmi_record_android_rescuer_acquisition('pagina-b',clock_timestamp()-interval '1 minute')");
  await db.query("select public.dopmi_send_message($1,$2,'Mensaje sintético tras retirar consentimiento')", [thread, randomUUID()]);
  assert.deepEqual(await privateCounts(), { sources: 0, events: 0 });
});

test('a revision conflict returns current consent without updating its revision or timestamp', async () => {
  await actor(owner);
  assert.deepEqual(await set(true, 7), { applied: false, consent: false, revision: 0 });
  await db.exec('reset role');
  const previous = await value('select to_jsonb(m) value from private.dopmi_adoption_measurement m where actor_id=$1', [owner]);
  await actor(owner);
  assert.deepEqual(await set(true, 7), { applied: false, consent: false, revision: 0 });
  await db.exec('reset role');
  assert.deepEqual(await value('select to_jsonb(m) value from private.dopmi_adoption_measurement m where actor_id=$1', [owner]), previous);
});

test('legacy v1 retains its body and increments revisions on every UPDATE, including unchanged consent', async () => {
  await actor(owner);
  await set(true, 0);
  await db.exec('select public.dopmi_set_adoption_measurement(true)');
  assert.deepEqual(await state(), { consent: true, revision: 2 });
  assert.deepEqual(await set(false, 1), { applied: false, consent: true, revision: 2 });
  await attributionWithGreeting();
  await db.exec('select public.dopmi_set_adoption_measurement(false)');
  assert.deepEqual(await state(), { consent: false, revision: 3 });
  assert.deepEqual(await set(true, 2), { applied: false, consent: false, revision: 3 });
  assert.deepEqual(await privateCounts(), { sources: 0, events: 0 });
  assert.equal(await value("select prosrc value from pg_proc where oid='public.dopmi_set_adoption_measurement(boolean)'::regprocedure"), legacyBody);
});

for (const initialConsent of [false, true]) {
  test(`the first legacy v1 INSERT advances absent revision zero for consent ${initialConsent}`, async () => {
    await actor(owner);
    assert.deepEqual(await state(), { consent: false, revision: 0 });
    await db.query('select public.dopmi_set_adoption_measurement($1)', [initialConsent]);
    assert.deepEqual(await state(), { consent: initialConsent, revision: 1 });
    assert.deepEqual(await set(!initialConsent, 0), { applied: false, consent: initialConsent, revision: 1 });
    if (!initialConsent) {
      await db.query("select public.dopmi_record_android_rescuer_acquisition('personal-a',clock_timestamp()-interval '1 minute')");
      assert.deepEqual(await privateCounts(), { sources: 0, events: 0 });
    }
  });
}

test('CAS requires an explicit boolean and a nonnegative nonnull revision', async () => {
  await actor(owner);
  for (const args of [[null, 0], [true, null], [true, -1]]) {
    await rejects(() => set(...args), '22023');
  }
  assert.deepEqual(await state(), { consent: false, revision: 0 });
  assert.deepEqual(await set(false, 0), { applied: true, consent: false, revision: 1 });
});

test('state and CAS are bound to the authenticated owner and reveal only consent/revision', async () => {
  await actor(owner);
  await set(true, 0);
  await actor(other);
  assert.deepEqual(await state(), { consent: false, revision: 0 });
  assert.deepEqual(await set(false, 1), { applied: false, consent: false, revision: 0 });
  assert.deepEqual(await set(true, 0), { applied: true, consent: true, revision: 1 });
  await actor(owner);
  assert.deepEqual(await state(), { consent: true, revision: 1 });
  await rejects(() => db.exec('select revision from private.dopmi_adoption_measurement'), '42501');
});

test('new RPCs are authenticated-only, require active/legal actors, and keep their trigger private', async () => {
  for (const signature of ['public.dopmi_adoption_measurement_state()', 'public.dopmi_set_adoption_measurement_v2(boolean,bigint)']) {
    for (const role of ['anon', 'authenticated', 'service_role']) {
      assert.equal(await value('select has_function_privilege($1,$2,\'execute\') value', [role, signature]), role === 'authenticated');
    }
  }
  for (const role of ['anon', 'authenticated', 'service_role']) {
    assert.equal(await value("select has_function_privilege($1,'private.dopmi_increment_adoption_measurement_revision()','execute') value", [role]), false);
  }
  await actor(null, 'anon');
  await rejects(state, '42501');
  await actor(null);
  await rejects(() => set(true, 0), '42501');
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [owner]);
  await actor(owner);
  await rejects(state, '42501');
  await rejects(() => set(true, 0), '42501');
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='active',terms_accepted_at=null where id=$1", [owner]);
  await actor(owner);
  await rejects(state, '22023');
  await rejects(() => set(true, 0), '22023');
});

test('real PostgreSQL: both CAS lock orders reject stale writes and opt-out removes dependent data', {
  skip: process.env.DOPMI_ACQUISITION_POSTGRES_TEST !== 'true', timeout: 90000,
}, async () => {
  assert.equal(process.env.PGPASSWORD, 'postgres', 'Only the disposable CI stack is supported');
  const config = { host: '127.0.0.1', port: 54322, user: 'postgres', database: 'postgres', password: 'postgres',
    ssl: false, connectionTimeoutMillis: 5000, options: '-c statement_timeout=20000 -c lock_timeout=15000' };
  const admin = new pg.Client(config);
  const database = `dopmi_consent_cas_${randomUUID().replaceAll('-', '')}`;
  const scoped = { ...config, database };
  const control = new pg.Client(scoped), first = new pg.Client(scoped), second = new pg.Client(scoped);
  const connected = [];
  let created = false, adminConnected = false, pending;
  const current = (client, sql, params = []) => client.query(sql, params).then(result => result.rows[0]?.value);
  const cas = (client, consent, revision) => current(client, 'select public.dopmi_set_adoption_measurement_v2($1,$2) value', [consent, revision]);
  async function asActor(client, id) {
    await client.query('begin');
    await client.query("select set_config('request.jwt.claim.sub',$1,true)", [id]);
    await client.query('set local role authenticated');
  }
  async function blocked(waiter, blocker) {
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      if (await current(control, 'select $2::int=any(pg_blocking_pids($1::int)) value', [waiter.processID, blocker.processID])) return;
      await pause(25);
    }
    assert.fail('CAS request was not observed waiting on the competing transaction');
  }
  try {
    await admin.connect(); adminConnected = true;
    assert.equal(admin.connectionParameters.host, '127.0.0.1');
    assert.equal(admin.connectionParameters.port, 54322);
    await admin.query(`create database "${database}" template template0`); created = true;
    for (const client of [control, first, second]) { await client.connect(); connected.push(client); }
    await bootstrap({ exec: sql => control.query(sql), query: (sql, params) => control.query(sql, params) });
    for (const offWins of [true, false]) {
      const actorId = randomUUID(), publisher = randomUUID(), postId = randomUUID();
      await control.query('begin');
      for (const id of [actorId, publisher]) {
        await control.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)', [id, id + '@example.test', metadata]);
      }
      await control.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'CAS sintético','published')", [postId, publisher]);
      await control.query('commit');
      await asActor(first, actorId);
      assert.deepEqual(await cas(first, true, 0), { applied: true, consent: true, revision: 1 });
      await first.query("select public.dopmi_record_android_rescuer_acquisition('personal-a',clock_timestamp()-interval '1 minute')");
      await first.query('select public.dopmi_start_adoption_contact($1)', [postId]);
      await first.query('commit');
      await asActor(first, actorId);
      assert.deepEqual(await cas(first, !offWins, 1), { applied: true, consent: !offWins, revision: 2 });
      await asActor(second, actorId);
      pending = cas(second, offWins, 1); pending.catch(() => {});
      await blocked(second, first);
      await first.query('commit');
      assert.deepEqual(await pending, { applied: false, consent: !offWins, revision: 2 });
      await second.query('commit'); pending = null;
      await asActor(first, actorId);
      assert.deepEqual(await cas(first, false, 2), { applied: true, consent: false, revision: 3 });
      await first.query('commit');
      assert.equal(await current(control, 'select count(*)::int value from private.dopmi_android_rescuer_acquisition where actor_id=$1', [actorId]), 0);
      assert.equal(await current(control, 'select count(*)::int value from private.dopmi_android_acquisition_events where actor_id=$1', [actorId]), 0);
    }
  } finally {
    try {
      await Promise.allSettled(connected.map(client => client.query('rollback')));
      if (pending) await pending.catch(() => {});
    } finally {
      await Promise.allSettled(connected.map(client => client.end()));
      try { if (created) await admin.query(`drop database "${database}"`); }
      finally { if (adminConnected) await admin.end(); }
    }
  }
});
