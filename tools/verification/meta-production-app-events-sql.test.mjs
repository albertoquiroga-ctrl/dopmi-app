import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import pg from 'pg';
import { PGlite } from '@electric-sql/pglite';
import { pgtap } from '@electric-sql/pglite/pgtap';

const migration = '20261122222303_meta_production_adoption_events.sql';
const protectedFunctions = [
  'public.dopmi_send_message(uuid,uuid,text)',
  'public.dopmi_send_message_v2(uuid,uuid,text,text)',
  'public.dopmi_send_message_v3(uuid,uuid,text,text)',
  'private.dopmi_send_message_result(uuid,uuid,text,text,text)',
  'private.dopmi_send_message_with_origin(uuid,uuid,text,text,text)',
  'private.dopmi_confirmed_adoption_signals(uuid,text)',
  'public.dopmi_start_adoption_contact(uuid)',
  'public.dopmi_start_adoption_contact_v2(uuid)',
  'public.dopmi_transition_adoption(uuid,integer,text)',
  'public.dopmi_adoption_measurement_state()',
  'public.dopmi_choose_usage_analytics(boolean,bigint,text)',
];
let db, beforeMigration;
const schema = `create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage; create schema extensions;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',
      email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz,
      created_at timestamptz not null default now(),is_anonymous boolean not null default false,deleted_at timestamptz);
    create table auth.identities(user_id uuid,provider text,provider_id text);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('role',current_setting('role',true))$$;
    grant usage on schema auth,public,extensions to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to anon,authenticated;
    grant select on storage.objects to anon;
    grant select,insert,update,delete on storage.objects to authenticated;`;
const definitions = () => db.query(`select oid::text,oid::regprocedure::text signature,
  pg_get_functiondef(oid) definition,proacl::text acl
  from pg_proc where oid=any($1::regprocedure[]) order by 2`, [protectedFunctions]).then(r => r.rows);

before(async () => {
  db = new PGlite({ extensions: { pgtap } });
  await db.exec(schema);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(directory)).filter(file => file.endsWith('.sql') && file <= migration).sort()) {
    if (file === migration) beforeMigration = await definitions();
    try { await db.exec(await readFile(new URL(file, directory), 'utf8')); }
    catch (error) { throw new Error(`Migration ${file}: ${error.code}: ${error.message}`); }
  }
}, { timeout: 120000 });

after(async () => db?.close());

test('Meta migration preserves confirmed-value, attribution and legacy RPC identities and permissions', async () => {
  assert.deepEqual(await definitions(), beforeMigration);
});

test('Meta production preference, message envelope, private submission and worker lifetime pass actual pgTAP', async t => {
  const source = await readFile(new URL('../../supabase/tests/meta_production_app_events.test.sql', import.meta.url), 'utf8');
  const result = await db.exec(source);
  const reports = result.flatMap(item => item.rows).flatMap(Object.values).filter(value => typeof value === 'string');
  const failures = reports.filter(value => value.startsWith('not ok'));
  assert.deepEqual(failures, []);
  assert.ok(reports.some(value => /^1\.\.[1-9][0-9]+$/.test(value)), 'pgTAP completed its complete plan');
  assert.ok(reports.filter(value => value.startsWith('ok ')).length >= 80, 'all integration scenarios executed');
  t.diagnostic(`${reports.filter(value => value.startsWith('ok ')).length} pgTAP assertions passed`);
});

// A new database on the existing disposable loopback stack keeps local app and
// Auth data intact. No URL/host input can redirect this opt-in suite to a remote.
test('real PostgreSQL: production Meta pgTAP and message/revocation races preserve product actions', {
  skip: process.env.DOPMI_META_ADS_POSTGRES_TEST !== 'true', timeout: 120000,
}, async t => {
  assert.equal(process.env.PGPASSWORD, 'postgres', 'Only the disposable CI stack is supported');
  const config = { host: '127.0.0.1', port: 54322, user: 'postgres', database: 'postgres',
    password: 'postgres', ssl: false, connectionTimeoutMillis: 5000,
    options: '-c statement_timeout=20000 -c lock_timeout=15000' };
  const database = `dopmi_meta_ads_test_${randomUUID().replaceAll('-', '')}`;
  const admin = new pg.Client(config), control = new pg.Client({ ...config, database });
  const first = new pg.Client({ ...config, database }), second = new pg.Client({ ...config, database });
  const clients = [];
  let adminConnected = false, created = false, pending;
  const value = async (client, sql, params = []) => (await client.query(sql, params)).rows[0]?.value;
  const actor = async (client, id) => {
    await client.query('begin');
    await client.query("select set_config('request.jwt.claim.sub',$1,true)", [id]);
    await client.query('set local role authenticated');
  };
  const blocked = async (waiter, blocker) => {
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      if (await value(control, 'select $2::int=any(pg_blocking_pids($1::int)) value', [waiter.processID, blocker.processID])) return;
      await new Promise(resolve => setTimeout(resolve, 25));
    }
    assert.fail('Expected overlapping Meta consent/dedup lock was not observed');
  };
  const context = { advertising_id: randomUUID(), os_version: '17', app_version: '2.3.6', app_build: 439 };
  const send = (client, thread) => value(client, 'select public.dopmi_send_message_meta_v2($1,$2,$3,null,$4) value',
    [thread, randomUUID(), 'Mensaje sintético local', context]);
  try {
    await admin.connect(); adminConnected = true;
    await admin.query(`create database "${database}" template template0`); created = true;
    for (const client of [control, first, second]) { await client.connect(); clients.push(client); }
    await control.query(schema.replace('create role anon; create role authenticated; create role service_role;', ''));
    const directory = new URL('../../supabase/migrations/', import.meta.url);
    for (const file of (await readdir(directory)).filter(file => file.endsWith('.sql') && file <= migration).sort()) {
      await control.query(await readFile(new URL(file, directory), 'utf8'));
    }
    const sql = await readFile(new URL('../../supabase/tests/meta_production_app_events.test.sql', import.meta.url), 'utf8');
    const result = await control.query(sql);
    const reports = result.flatMap(item => item.rows).flatMap(Object.values).filter(item => typeof item === 'string');
    assert.deepEqual(reports.filter(item => item.startsWith('not ok')), []);
    assert.ok(reports.some(item => /^1\.\.[1-9][0-9]+$/.test(item)));
    t.diagnostic(`${reports.filter(item => item.startsWith('ok ')).length} native pgTAP assertions passed`);

    const adopter = randomUUID(), owner = randomUUID();
    for (const id of [adopter, owner]) await control.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      values($1,$2,now(),'{"display_name":"Prueba local","terms_version":"development-2026-09-13","terms_accepted":true}')`,
      [id, `${id}@example.test`]);
    await control.query('select public.dopmi_set_meta_ads_gate(true)');
    const threads = [];
    for (let i = 0; i < 2; i++) {
      const listing = randomUUID();
      await control.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Luna sintética','published')", [listing, owner]);
      await actor(first, adopter);
      threads.push(await value(first, 'select public.dopmi_start_adoption_contact($1) value', [listing]));
      await first.query('select public.dopmi_set_meta_ads_preference(true)');
      await first.query('commit');
    }
    await actor(first, adopter); await send(first, threads[0]);
    await actor(second, adopter); pending = send(second, threads[1]); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    await pending; pending = undefined; await second.query('commit');
    assert.equal(await value(control, 'select count(*)::int value from private.dopmi_meta_ads_outbox where actor_id=$1', [adopter]), 1);
    assert.equal(await value(control, "select count(*)::int value from public.dopmi_messages where sender_id=$1 and origin='user'", [adopter]), 2);

    // Remove only synthetic dedup evidence so this independent race can prove
    // the actual consent-row lock. This is never a production operation.
    await control.query('delete from private.dopmi_meta_ads_outbox where actor_id=$1', [adopter]);
    await actor(first, adopter); await first.query('select public.dopmi_set_meta_ads_preference(false)');
    await actor(second, adopter); pending = send(second, threads[0]); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    const afterRevocation = await pending; pending = undefined; await second.query('commit');
    assert.equal(afterRevocation.message.body, 'Mensaje sintético local');
    assert.equal(await value(control, 'select count(*)::int value from private.dopmi_meta_ads_outbox where actor_id=$1', [adopter]), 0);
  } finally {
    for (const client of clients) await client.query('rollback').catch(() => {});
    if (pending) await pending.catch(() => {});
    for (const client of clients) await client.end();
    if (created) await admin.query(`drop database "${database}"`);
    if (adminConnected) await admin.end();
  }
});
