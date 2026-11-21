import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { setTimeout as pause } from 'node:timers/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';

const migration = '20261121062012_usage_analytics_choice.sql';
const notice = 'usage-analytics-2026-11-21';
const owner = randomUUID(), other = randomUUID(), legacyOff = randomUUID(), legacyOn = randomUUID();
const metadata = { display_name: 'Persona sintética', terms_version: 'terms-2026-10-17',
  privacy_version: 'privacy-2026-10-17', adult_confirmed: true };
let db, previousBodies;
const value = async (sql, params = []) => (await db.query(sql, params)).rows[0]?.value;
const state = () => value('select public.dopmi_adoption_measurement_state() value');
const choose = (consent, revision, version = notice) => value(
  'select public.dopmi_choose_usage_analytics($1,$2,$3) value', [consent, revision, version]);
const snapshot = (consent, revision, has_choice = true, notice_version = notice) =>
  ({ consent, revision, has_choice, notice_version });

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
      previousBodies = (await target.query(`select oid::regprocedure::text signature,prosrc from pg_proc
        where oid in ('public.dopmi_set_adoption_measurement(boolean)'::regprocedure,
          'public.dopmi_set_adoption_measurement_v2(boolean,bigint)'::regprocedure,
          'private.dopmi_increment_adoption_measurement_revision()'::regprocedure) order by 1`)).rows;
      for (const [id, consent] of [[legacyOff, false], [legacyOn, true]]) {
        await target.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)', [id, id + '@example.test', metadata]);
        await target.query('insert into private.dopmi_adoption_measurement(actor_id,consent,revision) values($1,$2,0)', [id, consent]);
      }
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
async function receipts(id = owner) {
  await db.exec('reset role');
  return (await db.query(`select actor_id,revision,consent,notice_version,decision_source,decided_at
    from private.dopmi_usage_analytics_choices where actor_id=$1 order by revision`, [id])).rows;
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

test('absence is distinct from a legacy OFF at revision zero and reads never create a choice', async () => {
  await actor(owner);
  assert.deepEqual(await state(), snapshot(false, 0, false, null));
  assert.deepEqual(await state(), snapshot(false, 0, false, null));
  await actor(legacyOff);
  assert.deepEqual(await state(), snapshot(false, 0, true, null));
  await actor(legacyOn);
  assert.deepEqual(await state(), snapshot(true, 0, true, null));
  await db.exec('reset role');
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_measurement where actor_id=$1', [owner]), 0);
  assert.equal(await value('select count(*)::int value from private.dopmi_usage_analytics_choices'), 0);
});

test('a conflicting expected revision on absence creates neither OFF placeholder nor receipt', async () => {
  await actor(owner);
  assert.deepEqual(await choose(true, 9), { applied: false, ...snapshot(false, 0, false, null) });
  assert.deepEqual(await state(), snapshot(false, 0, false, null));
  assert.deepEqual(await receipts(), []);
});

test('an explicit ON records its notice, owner, decision source and server time at the accepted revision', async () => {
  await actor(owner);
  assert.deepEqual(await choose(true, 0), { applied: true, ...snapshot(true, 1) });
  assert.deepEqual(await state(), snapshot(true, 1));
  const rows = await receipts();
  assert.equal(rows.length, 1);
  assert.deepEqual({ ...rows[0], decided_at: undefined }, {
    actor_id: owner, revision: 1, consent: true, notice_version: notice,
    decision_source: 'explicit_in_app_choice', decided_at: undefined,
  });
  assert.equal(await value('select $1::timestamptz between transaction_timestamp() and clock_timestamp() value', [rows[0].decided_at]), true);
});

test('an explicit OFF can be the first decision and is not mistaken for absence', async () => {
  await actor(owner);
  assert.deepEqual(await choose(false, 0), { applied: true, ...snapshot(false, 1) });
  assert.deepEqual(await state(), snapshot(false, 1));
  const rows = await receipts();
  assert.equal(rows.length, 1);
  assert.equal(rows[0].consent, false);
});

test('accepted decisions append evidence while stale ON creates no receipt and cannot undo OFF', async () => {
  await actor(owner);
  await choose(true, 0);
  await choose(false, 1);
  assert.deepEqual(await choose(true, 1), { applied: false, ...snapshot(false, 2) });
  const rows = await receipts();
  assert.deepEqual(rows.map(({ revision, consent }) => ({ revision, consent })), [
    { revision: 1, consent: true }, { revision: 2, consent: false },
  ]);
  await actor(owner);
  assert.deepEqual(await choose(false, 2), { applied: true, ...snapshot(false, 3) });
  assert.deepEqual((await receipts()).slice(0, 2), rows);
});

test('legacy writers preserve their contracts and never inherit an earlier notice at a new revision', async () => {
  await actor(owner);
  await choose(true, 0);
  await db.query('select public.dopmi_set_adoption_measurement(false)');
  assert.deepEqual(await state(), snapshot(false, 2, true, null));
  assert.deepEqual(await value('select public.dopmi_set_adoption_measurement_v2(true,2) value'),
    { applied: true, consent: true, revision: 3 });
  assert.deepEqual(await state(), snapshot(true, 3, true, null));
  assert.equal((await receipts()).length, 1);
  const bodies = (await db.query(`select oid::regprocedure::text signature,prosrc from pg_proc
    where oid in ('public.dopmi_set_adoption_measurement(boolean)'::regprocedure,
      'public.dopmi_set_adoption_measurement_v2(boolean,bigint)'::regprocedure,
      'private.dopmi_increment_adoption_measurement_revision()'::regprocedure) order by 1`)).rows;
  assert.deepEqual(bodies, previousBodies);
});

test('the explicit OFF uses existing Android and iOS revocation cascades', async () => {
  await actor(owner);
  await choose(true, 0);
  await db.query("select public.dopmi_record_android_rescuer_acquisition('personal-a',clock_timestamp()-interval '1 minute')");
  await db.query("select public.dopmi_record_ios_cpp_acquisition('personal-a',1)");
  await db.exec('reset role');
  const post = randomUUID();
  await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Mascota sintética','published')", [post, other]);
  await actor(owner);
  await db.query('select public.dopmi_start_adoption_contact($1)', [post]);
  await choose(false, 1);
  await db.exec('reset role');
  for (const table of ['dopmi_android_rescuer_acquisition', 'dopmi_android_acquisition_events',
    'dopmi_ios_cpp_acquisition', 'dopmi_ios_cpp_acquisition_events']) {
    assert.equal(await value(`select count(*)::int value from private.${table} where actor_id=$1`, [owner]), 0);
  }
  assert.equal((await receipts()).length, 2);
});

test('only an explicit boolean, nonnegative revision and exact displayed notice can create evidence', async () => {
  await actor(owner);
  for (const args of [[null, 0, notice], [true, null, notice], [true, -1, notice],
    [true, 0, null], [true, 0, 'terms-live-2026-11-01'], [true, 0, notice + ' ']]) {
    await rejects(() => choose(...args), '22023');
  }
  assert.deepEqual(await state(), snapshot(false, 0, false, null));
  assert.deepEqual(await receipts(), []);
});

test('the state and choice expose only the authenticated owner and no direct receipt access', async () => {
  await actor(owner);
  await choose(true, 0);
  await actor(other);
  assert.deepEqual(await state(), snapshot(false, 0, false, null));
  assert.deepEqual(await choose(false, 0), { applied: true, ...snapshot(false, 1) });
  for (const sql of ['select * from private.dopmi_usage_analytics_choices',
    'delete from private.dopmi_usage_analytics_choices',
    "update private.dopmi_usage_analytics_choices set consent=true",
    `insert into private.dopmi_usage_analytics_choices(actor_id,revision,consent,notice_version)
      values('${owner}',2,true,'${notice}')`]) {
    await rejects(() => db.exec(sql), '42501');
  }
  await actor(owner);
  assert.deepEqual(await state(), snapshot(true, 1));
});

test('choice RPC is authenticated-only and requires the existing active, confirmed, legal actor', async () => {
  for (const role of ['anon', 'authenticated', 'service_role']) {
    assert.equal(await value('select has_function_privilege($1,$2,\'execute\') value',
      [role, 'public.dopmi_choose_usage_analytics(boolean,bigint,text)']), role === 'authenticated');
    assert.equal(await value('select has_table_privilege($1,$2,\'select\') value',
      [role, 'private.dopmi_usage_analytics_choices']), false);
  }
  await actor(null, 'anon');
  await rejects(() => choose(true, 0), '42501');
  await actor(null);
  await rejects(() => choose(true, 0), '42501');
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [owner]);
  await actor(owner);
  await rejects(() => choose(true, 0), '42501');
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='active',terms_accepted_at=null where id=$1", [owner]);
  await actor(owner);
  await rejects(() => choose(true, 0), '22023');
});

test('deleting the account removes its analytics state and all decision receipts', async () => {
  await actor(owner);
  await choose(true, 0);
  await choose(false, 1);
  await db.exec('reset role');
  await db.query('delete from auth.users where id=$1', [owner]);
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_measurement where actor_id=$1', [owner]), 0);
  assert.deepEqual(await receipts(), []);
});

test('real PostgreSQL: either lock winner owns the receipt and stale decisions cannot undo it', {
  skip: process.env.DOPMI_ACQUISITION_POSTGRES_TEST !== 'true', timeout: 90000,
}, async () => {
  assert.equal(process.env.PGPASSWORD, 'postgres', 'Only the disposable CI stack is supported');
  const config = { host: '127.0.0.1', port: 54322, user: 'postgres', database: 'postgres', password: 'postgres',
    ssl: false, connectionTimeoutMillis: 5000, options: '-c statement_timeout=20000 -c lock_timeout=15000' };
  const admin = new pg.Client(config), database = `dopmi_usage_choice_${randomUUID().replaceAll('-', '')}`;
  const scoped = { ...config, database };
  const control = new pg.Client(scoped), first = new pg.Client(scoped), second = new pg.Client(scoped);
  const connected = [];
  let created = false, adminConnected = false, pending;
  const current = (client, sql, params = []) => client.query(sql, params).then(result => result.rows[0]?.value);
  const write = (client, consent, revision) => current(client,
    'select public.dopmi_choose_usage_analytics($1,$2,$3) value', [consent, revision, notice]);
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
    assert.fail('Choice request was not observed waiting on the competing transaction');
  }
  try {
    await admin.connect(); adminConnected = true;
    await admin.query(`create database "${database}" template template0`); created = true;
    for (const client of [control, first, second]) { await client.connect(); connected.push(client); }
    await bootstrap({ exec: sql => control.query(sql), query: (sql, params) => control.query(sql, params) });
    for (const winnerConsent of [true, false]) {
      const id = randomUUID();
      await control.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)', [id, id + '@example.test', metadata]);
      await asActor(first, id);
      assert.deepEqual(await write(first, winnerConsent, 0), { applied: true, ...snapshot(winnerConsent, 1) });
      await asActor(second, id);
      pending = write(second, !winnerConsent, 0); pending.catch(() => {});
      await blocked(second, first);
      await first.query('commit');
      assert.deepEqual(await pending, { applied: false, ...snapshot(winnerConsent, 1) });
      await second.query('commit'); pending = null;
      const rows = (await control.query('select revision,consent from private.dopmi_usage_analytics_choices where actor_id=$1', [id])).rows;
      assert.deepEqual(rows, [{ revision: '1', consent: winnerConsent }]);
    }
  } finally {
    await Promise.allSettled(connected.map(client => client.query('rollback')));
    if (pending) await pending.catch(() => {});
    await Promise.allSettled(connected.map(client => client.end()));
    try { if (created) await admin.query(`drop database "${database}"`); }
    finally { if (adminConnected) await admin.end(); }
  }
});
