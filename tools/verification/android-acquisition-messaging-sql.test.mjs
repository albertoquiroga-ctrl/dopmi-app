import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { setTimeout as pause } from 'node:timers/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';

const baseMigration = '20261112232613_android_rescuer_acquisition.sql';
const messageMigration = '20261120205535_android_acquisition_message_events.sql';
const report = await readFile(new URL('./android-rescuer-acquisition.sql', import.meta.url), 'utf8');
const owner = randomUUID(), adopter = randomUUID(), outsider = randomUUID();
const legacyOwner = randomUUID(), legacyAdopter = randomUUID();
const legacyPost = randomUUID(), legacyThread = randomUUID(), legacyMessage = randomUUID();
const sessions = new Map();
const metadata = { display_name: 'Persona sintética', terms_version: 'terms-2026-10-17',
  privacy_version: 'privacy-2026-10-17', adult_confirmed: true };
let db;
let originalRpcAcl;
const value = async (sql, params = []) => (await db.query(sql, params)).rows[0]?.value;

async function actor(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)", [id ?? '', sessions.get(id) ?? '']);
  await db.exec('set local role ' + role);
}

async function capture(id, variant = 'personal-a') {
  await actor(id);
  await db.exec('select public.dopmi_set_adoption_measurement(true)');
  await db.query("select public.dopmi_record_android_rescuer_acquisition($1,clock_timestamp()-interval '1 minute')", [variant]);
}

async function post(publisher = owner) {
  await db.exec('reset role');
  const id = randomUUID();
  await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Luna sintética','published')", [id, publisher]);
  return id;
}

const contact = postId => value('select public.dopmi_start_adoption_contact($1) value', [postId]);
const send = (thread, id = randomUUID(), body = 'Mensaje sintético', photo = null) => value(
  'select public.dopmi_send_message_v2($1,$2,$3,$4) value', [thread, id, body, photo],
);
async function events(id) {
  await db.exec('reset role');
  return (await db.query('select event_type,observed_at from private.dopmi_android_acquisition_events where actor_id=$1 order by event_type', [id])).rows;
}
async function rejects(operation, code) {
  await db.exec('savepoint rejected');
  await assert.rejects(operation, { code });
  await db.exec('rollback to savepoint rejected; release savepoint rejected');
}
async function photo(thread, sender, id) {
  await db.exec('reset role');
  const path = `${sender}/${thread}/${id}.jpg`;
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-chat-photos',$1)", [path]);
  return path;
}

before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
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
  for (const file of (await readdir(directory)).filter(file => file.endsWith('.sql') && file <= baseMigration).sort()) {
    await db.exec(await readFile(new URL(file, directory), 'utf8'));
  }
  for (const id of [owner, adopter, outsider, legacyOwner, legacyAdopter]) {
    await db.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)', [id, id + '@example.test', metadata]);
    sessions.set(id, randomUUID());
    await db.query('insert into auth.sessions(id,user_id) values($1,$2)', [sessions.get(id), id]);
  }
  // A real pre-migration row whose text looks like a greeting stays unknown.
  await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Legado sintético','published')", [legacyPost, legacyOwner]);
  await db.query("insert into public.dopmi_threads(id,post_id,owner_id,adopter_id,pet_name) values($1,$2,$3,$4,'Legado sintético')", [legacyThread, legacyPost, legacyOwner, legacyAdopter]);
  await db.query("insert into public.dopmi_messages(id,thread_id,sender_id,body) values($1,$2,$3,'¡Hola! 👋 Me encantó Legado sintético')", [legacyMessage, legacyThread, legacyAdopter]);
  originalRpcAcl = (await db.query("select oid::regprocedure::text signature,proacl::text acl,proargnames,proargdefaults::text defaults from pg_proc where oid=any(array['public.dopmi_send_message(uuid,uuid,text)'::regprocedure,'public.dopmi_send_message_v2(uuid,uuid,text,text)'::regprocedure,'public.dopmi_start_adoption_contact(uuid)'::regprocedure]) order by 1")).rows;
  await db.exec(await readFile(new URL(messageMigration, directory), 'utf8'));
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('contact greeting, composer and rescuer reply have server-selected origins and actors', async () => {
  await capture(owner, 'pagina-b');
  await capture(adopter, 'personal-a');
  const postId = await post();
  await actor(adopter);
  const thread = await contact(postId);
  await db.exec('reset role');
  const greeting = await value('select to_jsonb(m) value from public.dopmi_messages m where thread_id=$1', [thread]);
  assert.equal(greeting.origin, 'automatic_greeting');
  assert.deepEqual((await events(adopter)).map(e => e.event_type), ['automatic_greeting']);
  assert.deepEqual(await events(owner), []);
  await actor(adopter);
  assert.equal(await contact(postId), thread);
  // Matching text is still a compositor message, never inferred as automatic.
  const manual = await send(thread, randomUUID(), greeting.body);
  assert.equal(manual.origin, 'user');
  assert.deepEqual((await events(adopter)).map(e => e.event_type), ['automatic_greeting', 'first_user_message']);
  assert.deepEqual(await events(owner), []);
  await actor(owner);
  assert.equal((await send(thread)).origin, 'user');
  assert.deepEqual((await events(owner)).map(e => e.event_type), ['first_rescuer_reply']);
  assert.equal(await value('select count(*)::int value from public.dopmi_messages where thread_id=$1', [thread]), 3);
  assert.equal(await value("select count(*)::int value from public.dopmi_notifications where thread_id=$1 and kind='message'", [thread]), 3);
});

test('a rescuer compositor reply to only an automatic greeting counts without an adopter manual message', async () => {
  await capture(owner);
  const postId = await post();
  await actor(adopter);
  const thread = await contact(postId);
  await actor(owner);
  await send(thread);
  assert.deepEqual((await events(owner)).map(e => e.event_type), ['first_rescuer_reply']);
  assert.deepEqual(await events(adopter), []);
});

test('photo-only compositor sends count for the adopter and the actual rescuer', async () => {
  await capture(owner);
  await capture(adopter);
  const postId = await post();
  await actor(adopter);
  const thread = await value('select public.dopmi_start_thread($1) value', [postId]);
  for (const sender of [adopter, owner]) {
    const id = randomUUID();
    const path = await photo(thread, sender, id);
    await actor(sender);
    const message = await send(thread, id, '', path);
    assert.equal(message.origin, 'user');
  }
  assert.deepEqual((await events(adopter)).map(e => e.event_type), ['first_user_message']);
  assert.deepEqual((await events(owner)).map(e => e.event_type), ['first_rescuer_reply']);
});

test('an owner send in an empty legacy thread is not a reply until an adopter message exists', async () => {
  await capture(owner);
  const postId = await post();
  await actor(adopter);
  const thread = await value('select public.dopmi_start_thread($1) value', [postId]);
  await actor(owner);
  await send(thread);
  assert.deepEqual(await events(owner), []);
  await actor(adopter);
  await send(thread);
  await actor(owner);
  await send(thread);
  assert.deepEqual((await events(owner)).map(e => e.event_type), ['first_rescuer_reply']);
});

test('same UUID retries preserve the original result and do not duplicate milestones or notifications', async () => {
  await capture(adopter);
  const postId = await post();
  await actor(adopter);
  const thread = await contact(postId);
  const id = randomUUID();
  const first = await value('select public.dopmi_send_message($1,$2,$3) value', [thread, id, 'Respuesta sintética']);
  assert.equal(first.origin, 'user');
  const firstEvents = await events(adopter);
  await actor(adopter);
  assert.deepEqual(await send(thread, id, 'Respuesta sintética'), first);
  await rejects(() => send(thread, id, 'Otro texto'), '22023');
  await actor(owner);
  await rejects(() => send(thread, id, 'Respuesta sintética'), '22023');
  assert.deepEqual(await events(adopter), firstEvents);
  assert.equal(await value('select count(*)::int value from public.dopmi_messages where thread_id=$1', [thread]), 2);
  assert.equal(await value("select count(*)::int value from public.dopmi_notifications where thread_id=$1 and kind='message'", [thread]), 2);
});

test('clients cannot choose origins, invoke the internal helper, or inspect attribution milestones', async () => {
  await capture(adopter);
  const postId = await post();
  await actor(adopter);
  const thread = await contact(postId);
  const message = randomUUID();
  await rejects(() => db.query("insert into public.dopmi_messages(id,thread_id,sender_id,body,origin) values($1,$2,$3,'Falso','automatic_greeting')", [message, thread, adopter]), '42501');
  await rejects(() => db.query("update public.dopmi_messages set origin='user' where thread_id=$1", [thread]), '42501');
  await rejects(() => db.exec('select * from private.dopmi_android_acquisition_events'), '42501');
  await rejects(() => db.query("select private.dopmi_send_message_with_origin($1,$2,'Falso',null,'automatic_greeting')", [thread, message]), '42501');
  await db.exec('reset role');
  assert.equal(await value("select relrowsecurity value from pg_class where oid='private.dopmi_android_acquisition_events'::regclass"), true);
  for (const role of ['anon', 'authenticated', 'service_role']) {
    assert.equal(await value("select has_table_privilege($1,'private.dopmi_android_acquisition_events','select,insert,update,delete') value", [role]), false);
    assert.equal(await value("select has_function_privilege($1,'private.dopmi_send_message_with_origin(uuid,uuid,text,text,text)','execute') value", [role]), false);
    assert.equal(await value("select has_function_privilege($1,'private.dopmi_observe_android_message_acquisition()','execute') value", [role]), false);
  }
  assert.equal(await value("select has_column_privilege('authenticated','public.dopmi_messages','origin','insert,update') value"), false);
  assert.deepEqual((await db.query("select oid::regprocedure::text signature,proacl::text acl,proargnames,proargdefaults::text defaults from pg_proc where oid=any(array['public.dopmi_send_message(uuid,uuid,text)'::regprocedure,'public.dopmi_send_message_v2(uuid,uuid,text,text)'::regprocedure,'public.dopmi_start_adoption_contact(uuid)'::regprocedure]) order by 1")).rows, originalRpcAcl);
  assert.deepEqual((await db.query("select column_name from information_schema.columns where table_schema='private' and table_name='dopmi_android_acquisition_events' order by ordinal_position")).rows.map(r => r.column_name), ['actor_id', 'event_type', 'observed_at']);
});

test('unauthorized, invalid-photo and closed-thread attempts have no milestones or extra messages', async () => {
  await capture(outsider);
  await capture(adopter);
  const postId = await post();
  await actor(adopter);
  const thread = await value('select public.dopmi_start_thread($1) value', [postId]);
  await actor(outsider);
  await rejects(() => send(thread), '42501');
  await actor(adopter);
  await rejects(() => send(thread, randomUUID(), '', 'otra/foto.jpg'), '22023');
  await db.query('select public.dopmi_close_thread($1)', [thread]);
  await rejects(() => send(thread), '22023');
  assert.deepEqual(await events(adopter), []);
  assert.deepEqual(await events(outsider), []);
  assert.equal(await value('select count(*)::int value from public.dopmi_messages where thread_id=$1', [thread]), 0);
});

test('rejected listings and suspended senders cannot create a greeting or compositor milestone', async () => {
  await capture(adopter);
  const postId = await post();
  await db.query("update public.dopmi_adoptions set status='rejected' where id=$1", [postId]);
  await actor(adopter);
  await rejects(() => contact(postId), '22023');
  await db.exec('reset role');
  await db.query("update public.dopmi_adoptions set status='published' where id=$1", [postId]);
  await actor(adopter);
  const thread = await value('select public.dopmi_start_thread($1) value', [postId]);
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [adopter]);
  await actor(adopter);
  await rejects(() => send(thread), '42501');
  assert.deepEqual(await events(adopter), []);
});

test('legacy origins stay unknown and retrying their UUID never backfills a conversion', async () => {
  await capture(legacyAdopter);
  await db.exec('reset role');
  const prior = await value('select to_jsonb(m) value from public.dopmi_messages m where id=$1', [legacyMessage]);
  assert.equal(prior.origin, 'unknown');
  await actor(legacyAdopter);
  assert.deepEqual(await send(legacyThread, legacyMessage, prior.body), prior);
  assert.equal(await contact(legacyPost), legacyThread);
  assert.deepEqual(await events(legacyAdopter), []);
  await actor(legacyAdopter);
  await send(legacyThread, randomUUID(), prior.body);
  assert.deepEqual((await events(legacyAdopter)).map(e => e.event_type), ['first_user_message']);
});

test('messages persisted before attribution remain uncounted on retries; only a later INSERT counts', async () => {
  const postId = await post();
  await actor(adopter);
  const thread = await contact(postId);
  const id = randomUUID();
  const first = await send(thread, id);
  await capture(adopter);
  assert.deepEqual(await send(thread, id), first);
  assert.deepEqual(await events(adopter), []);
  await actor(adopter);
  await send(thread);
  const captured = await events(adopter);
  assert.deepEqual(captured.map(e => e.event_type), ['first_user_message']);
  assert.equal(await value('select e.observed_at>=s.attributed_at value from private.dopmi_android_acquisition_events e join private.dopmi_android_rescuer_acquisition s using(actor_id) where e.actor_id=$1', [adopter]), true);
});

test('the 336-hour bound and attribution ordering exclude messages without blocking their delivery', async () => {
  await capture(adopter);
  const postId = await post();
  await actor(adopter);
  const thread = await value('select public.dopmi_start_thread($1) value', [postId]);
  await db.exec('reset role');
  await db.query("update private.dopmi_android_rescuer_acquisition set attributed_at=clock_timestamp()+interval '1 hour' where actor_id=$1", [adopter]);
  await actor(adopter);
  await send(thread);
  assert.deepEqual(await events(adopter), []);
  await db.query("update private.dopmi_android_rescuer_acquisition set attributed_at=clock_timestamp()-interval '335 hours',clicked_at=clock_timestamp()-interval '336 hours' where actor_id=$1", [adopter]);
  await actor(adopter);
  await send(thread);
  assert.deepEqual(await events(adopter), []);
  assert.equal(await value('select count(*)::int value from public.dopmi_messages where thread_id=$1', [thread]), 2);
});

test('opt-out and finalized deletion cascade milestones while retaining participant messages', async () => {
  await capture(owner);
  await capture(adopter);
  const postId = await post();
  await actor(adopter);
  const thread = await contact(postId);
  await send(thread);
  await actor(owner);
  await send(thread);
  await actor(adopter);
  await db.exec('select public.dopmi_set_adoption_measurement(false)');
  assert.deepEqual(await events(adopter), []);
  assert.equal(await value('select count(*)::int value from public.dopmi_messages where thread_id=$1', [thread]), 3);
  await actor(adopter);
  await send(thread);
  assert.deepEqual(await events(adopter), []);
  assert.equal(await value('select count(*)::int value from public.dopmi_messages where thread_id=$1', [thread]), 4);
  await db.query("update public.profiles set account_status='deleted' where id=$1", [owner]);
  assert.deepEqual(await events(owner), []);
  assert.equal(await value('select count(*)::int value from private.dopmi_android_rescuer_acquisition where actor_id=any($1::uuid[])', [[owner, adopter]]), 0);
});

test('the aggregate report separates actor conversions and exposes no conversation identifiers or content', async () => {
  await capture(owner, 'pagina-b');
  await capture(adopter, 'personal-a');
  const postId = await post();
  await actor(adopter);
  const thread = await contact(postId);
  await send(thread);
  await actor(owner);
  await send(thread);
  await db.exec('reset role');
  const rows = (await db.query(report)).rows;
  const reader = rows.find(r => r.variant === 'personal-a');
  assert.equal(reader.first_observable_automatic_greetings_14d, 1);
  assert.equal(reader.first_observable_user_messages_14d, 1);
  assert.equal(reader.first_observable_rescuer_replies_14d, 0);
  const publisher = rows.find(r => r.variant === 'pagina-b');
  assert.equal(publisher.first_observable_automatic_greetings_14d, 0);
  assert.equal(publisher.first_observable_user_messages_14d, 0);
  assert.equal(publisher.first_observable_rescuer_replies_14d, 1);
  assert.doesNotMatch(JSON.stringify(rows), new RegExp([owner, adopter, postId, thread, 'sintétic'].join('|')));
});

// CI enables this only after starting its disposable Supabase PostgreSQL.
// PGlite does not prove overlapping transactions, so concurrency is a distinct gate.
test('real PostgreSQL: consent, enrollment, contact and UUID races keep milestones atomic', {
  skip: process.env.DOPMI_ACQUISITION_POSTGRES_TEST !== 'true', timeout: 90000,
}, async () => {
  assert.equal(process.env.PGPASSWORD, 'postgres', 'Only the disposable CI stack is supported');
  const config = { host: '127.0.0.1', port: 54322, user: 'postgres', database: 'postgres',
    password: 'postgres', ssl: false, connectionTimeoutMillis: 5000,
    options: '-c statement_timeout=20000 -c lock_timeout=15000' };
  const admin = new pg.Client(config);
  const database = `dopmi_acquisition_test_${randomUUID().replaceAll('-', '')}`;
  const isolated = { ...config, database };
  const control = new pg.Client(isolated), first = new pg.Client(isolated), second = new pg.Client(isolated);
  const people = [randomUUID(), randomUUID()];
  const session = randomUUID(), listing = randomUUID();
  const connected = [];
  let pending, created = false, adminConnected = false, seeded = false;
  const queryValue = async (client, sql, params = []) => (await client.query(sql, params)).rows[0]?.value;
  async function asReader(client) {
    await client.query('begin');
    await client.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)", [people[1], session]);
    await client.query('set local role authenticated');
  }
  async function blocked(waiter, blocker) {
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      if (await queryValue(control, 'select $2::int=any(pg_blocking_pids($1::int)) value', [waiter.processID, blocker.processID])) return;
      await pause(25);
    }
    assert.fail('Expected overlapping database lock was not observed');
  }
  const optIn = client => client.query('select public.dopmi_set_adoption_measurement(true)');
  const enroll = client => client.query("select public.dopmi_record_android_rescuer_acquisition('personal-a',clock_timestamp()-interval '1 minute')");
  const optOut = client => client.query('select public.dopmi_set_adoption_measurement(false)');
  const open = client => queryValue(client, 'select public.dopmi_start_adoption_contact($1) value', [listing]);
  const write = (client, thread, message) => queryValue(client, "select public.dopmi_send_message($1,$2,'Mensaje de carrera sintética') value", [thread, message]);
  const counts = () => queryValue(control, 'select count(*)::int value from private.dopmi_android_acquisition_events where actor_id=$1', [people[1]]);
  try {
    await admin.connect(); adminConnected = true;
    assert.equal(admin.connectionParameters.host, '127.0.0.1');
    assert.equal(admin.connectionParameters.port, 54322);
    await admin.query(`create database "${database}" template template0`); created = true;
    for (const client of [control, first, second]) { await client.connect(); connected.push(client); }
    // Reuse the CI PostgreSQL engine, with a new database and synthetic Auth /
    // Storage schema. Existing Supabase application tables are never read.
    await control.query(`create schema auth; create schema storage;
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
    for (const file of (await readdir(directory)).filter(file => file.endsWith('.sql') && file <= baseMigration).sort()) {
      await control.query(await readFile(new URL(file, directory), 'utf8'));
    }
    await control.query(await readFile(new URL(messageMigration, directory), 'utf8'));
    await control.query('begin');
    for (const id of people) {
      await control.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)', [id, id + '@example.test', metadata]);
    }
    await control.query('insert into auth.sessions(id,user_id) values($1,$2)', [session, people[1]]);
    await control.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Carrera sintética','published')", [listing, people[0]]);
    await control.query('commit');
    seeded = true;
    await asReader(first); await optIn(first); await enroll(first); await first.query('commit');

    // Concurrent contacts: only the creator emits one automatic greeting.
    await asReader(first); const thread = await open(first);
    await asReader(second); pending = open(second); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    assert.equal(await pending, thread); await second.query('commit'); pending = null;
    assert.equal(await counts(), 1);

    // Message wins consent lock; revocation waits and then cascades all milestones.
    await asReader(first); const message = randomUUID(); const sent = await write(first, thread, message);
    await asReader(second); pending = optOut(second); pending.catch(() => {});
    await blocked(second, first); await first.query('commit'); await pending;
    await second.query('commit'); pending = null; assert.equal(await counts(), 0);

    // Revocation wins: delivery waits but observes revoked consent after the lock.
    await asReader(first); await optIn(first); await enroll(first); await first.query('commit');
    await asReader(first); await optOut(first);
    await asReader(second); pending = write(second, thread, randomUUID()); pending.catch(() => {});
    await blocked(second, first); await first.query('commit'); await pending;
    await second.query('commit'); pending = null; assert.equal(await counts(), 0);

    // Enrollment wins: the subsequent compositor INSERT is within the source window.
    await asReader(first); await optIn(first); await enroll(first);
    await asReader(second); pending = write(second, thread, randomUUID()); pending.catch(() => {});
    await blocked(second, first); await first.query('commit'); await pending;
    await second.query('commit'); pending = null; assert.equal(await counts(), 1);

    // A repeated old UUID never recreates a milestone after consent was revoked.
    await asReader(first); await optOut(first); await optIn(first); await enroll(first); await first.query('commit');
    await asReader(first); assert.deepEqual(await write(first, thread, message), sent); await first.query('commit');
    assert.equal(await counts(), 0);

    // Two devices with the same new UUID share the thread lock and one notification.
    const duplicate = randomUUID();
    await asReader(first); const original = await write(first, thread, duplicate);
    await asReader(second); pending = write(second, thread, duplicate); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    assert.deepEqual(await pending, original); await second.query('commit'); pending = null;
    assert.equal(await counts(), 1);
    assert.equal(await queryValue(control, 'select count(*)::int value from public.dopmi_messages where id=$1', [duplicate]), 1);
    assert.equal(await queryValue(control, "select count(*)::int value from public.dopmi_notifications where source_id=$1 and kind='message'", [duplicate]), 1);

    // Message wins before enrollment: the trigger holds consent but finds no
    // source; enrollment waits and cannot backfill that already-inserted UUID.
    await asReader(first); await optOut(first); await optIn(first); await first.query('commit');
    const earlier = randomUUID();
    await asReader(first); await write(first, thread, earlier);
    await asReader(second); pending = enroll(second); pending.catch(() => {});
    await blocked(second, first); await first.query('commit'); await pending;
    await second.query('commit'); pending = null; assert.equal(await counts(), 0);
    await asReader(first); await write(first, thread, earlier); await first.query('commit');
    assert.equal(await counts(), 0);
  } finally {
    try {
      await Promise.allSettled(connected.map(client => client.query('rollback')));
      if (pending) await pending.catch(() => {});
      if (seeded && connected.includes(control)) {
        await control.query('begin');
        await control.query('delete from auth.users where id=any($1::uuid[])', [people]);
        await control.query('commit');
        assert.equal(await queryValue(control, 'select count(*)::int value from public.profiles where id=any($1::uuid[])', [people]), 0);
      }
    } finally {
      await Promise.allSettled(connected.map(client => client.end()));
      try { if (created) await admin.query(`drop database "${database}"`); }
      finally { if (adminConnected) await admin.end(); }
    }
  }
});
