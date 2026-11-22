import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { setTimeout as pause } from 'node:timers/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';

// Additive confirmed-value contract; these regressions preceded its implementation.
// No test connects to Supabase, Firebase, GA or any non-local service.
const baseline = '20261121233958_android_campaign_placements.sql';
const owner = randomUUID(), adopter = randomUUID(), outsider = randomUUID();
const legacyPost = randomUUID(), legacyThread = randomUUID();
const sessions = new Map();
const notice = 'usage-analytics-2026-11-21';
const metadata = { display_name: 'Persona sintética', terms_version: 'terms-2026-10-17',
  privacy_version: 'privacy-2026-10-17', adult_confirmed: true };
const legacySignatures = [
  'public.dopmi_start_adoption_contact(uuid)',
  'public.dopmi_send_message(uuid,uuid,text)',
  'public.dopmi_send_message_v2(uuid,uuid,text,text)',
  'public.dopmi_close_adoption(uuid,integer,text,boolean,text)',
  'public.dopmi_thread_messages(uuid,timestamp with time zone,uuid)',
];
const proposedSignatures = [
  'public.dopmi_start_adoption_contact_v2(uuid)',
  'public.dopmi_send_message_v3(uuid,uuid,text,text)',
  'public.dopmi_close_adoption_v2(uuid,integer,text,boolean,text)',
];
let db, legacyContract, legacyMessageKeys;
const value = async (sql, params = []) => (await db.query(sql, params)).rows[0]?.value;
const authStorageSchema = `create schema auth; create schema storage;
  create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz,created_at timestamptz default now(),deleted_at timestamptz);
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
  grant select,insert,update,delete on storage.objects to authenticated;`;

async function actor(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)",
    [id ?? '', sessions.get(id) ?? '']);
  await db.exec('set local role ' + role);
}

async function consent(id, enabled) {
  await actor(id);
  const state = await value('select public.dopmi_adoption_measurement_state() value');
  const result = await value('select public.dopmi_choose_usage_analytics($1,$2,$3) value',
    [enabled, state.revision, notice]);
  assert.equal(result.applied, true);
}

async function post(publisher = owner) {
  await db.exec('reset role');
  const id = randomUUID();
  await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Luna sintética','published')", [id, publisher]);
  return id;
}

const contact = id => value('select public.dopmi_start_adoption_contact_v2($1) value', [id]);
const send = (thread, id = randomUUID(), body = 'Respuesta sintética', photo = null) => value(
  'select public.dopmi_send_message_v3($1,$2,$3,$4) value', [thread, id, body, photo]);
const close = (id, version, reason = 'adopted', support = false) => value(
  'select public.dopmi_close_adoption_v2($1,$2,$3,$4,$5) value', [id, version, reason, support, '']);

async function rejects(operation, code) {
  await db.exec('savepoint rejected');
  await assert.rejects(operation, { code });
  await db.exec('rollback to savepoint rejected; release savepoint rejected');
}

async function rpcContract() {
  await db.exec('reset role');
  return (await db.query(`select p.oid::regprocedure::text signature,p.proacl::text acl,
    p.proargnames,p.proargdefaults::text defaults,p.prorettype::regtype::text result
    from pg_proc p where p.oid=any($1::regprocedure[]) order by 1`, [legacySignatures])).rows;
}

before(async () => {
  db = new PGlite();
  await db.exec('create role anon; create role authenticated; create role service_role;');
  await db.exec(authStorageSchema);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  const migrations = (await readdir(directory)).filter(file => file.endsWith('.sql')).sort();
  for (const file of migrations.filter(file => file <= baseline)) {
    await db.exec(await readFile(new URL(file, directory), 'utf8'));
  }
  for (const id of [owner, adopter, outsider]) {
    await db.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)',
      [id, id + '@example.test', metadata]);
    sessions.set(id, randomUUID());
    await db.query('insert into auth.sessions(id,user_id) values($1,$2)', [sessions.get(id), id]);
  }
  await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Legado sintético','published')", [legacyPost, owner]);
  await db.query("insert into public.dopmi_threads(id,post_id,owner_id,adopter_id,pet_name) values($1,$2,$3,$4,'Legado sintético')", [legacyThread, legacyPost, owner, adopter]);
  for (const sender of [adopter, owner]) {
    await db.query("insert into public.dopmi_messages(id,thread_id,sender_id,body,origin) values($1,$2,$3,'Legado sintético','unknown')", [randomUUID(), legacyThread, sender]);
  }
  legacyContract = await rpcContract();
  legacyMessageKeys = Object.keys(await value('select to_jsonb(m) value from public.dopmi_messages m limit 1')).sort();
  for (const file of migrations.filter(file => file > baseline)) {
    await db.exec(await readFile(new URL(file, directory), 'utf8'));
  }
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('confirmed value RPCs expose the additive JSON contract without changing legacy RPCs', async () => {
  for (const signature of proposedSignatures) {
    assert.notEqual(await value('select to_regprocedure($1)::text value', [signature]), null,
      'Missing proposed confirmed-value RPC: ' + signature);
    for (const role of ['anon', 'service_role']) {
      assert.equal(await value('select has_function_privilege($1,$2,\'execute\') value', [role, signature]), false);
    }
    assert.equal(await value("select has_function_privilege('authenticated',$1,'execute') value", [signature]), true);
  }
  assert.deepEqual(await rpcContract(), legacyContract);
});

test('new contact returns one creation signal; reopening and the legacy UUID route do not create another greeting', async () => {
  const postId = await post();
  await consent(adopter, true);
  const first = await contact(postId);
  assert.equal(first.created_new, true);
  assert.deepEqual(first.signals, ['adoption_contact_created']);
  const again = await contact(postId);
  assert.equal(again.thread_id, first.thread_id);
  assert.equal(again.created_new, false);
  assert.deepEqual(again.signals, []);
  assert.equal(await value('select public.dopmi_start_adoption_contact($1) value', [postId]), first.thread_id);
  assert.equal(await value("select count(*)::int value from public.dopmi_messages where thread_id=$1 and origin='automatic_greeting'", [first.thread_id]), 1);
});

test('contact without consent still works; opting in later never backfills that contact', async () => {
  const postId = await post();
  await actor(adopter);
  const first = await contact(postId);
  assert.equal(first.created_new, true);
  assert.deepEqual(first.signals, []);
  await consent(adopter, true);
  assert.deepEqual((await contact(postId)).signals, []);
});

test('first human owner reply after an incoming greeting counts once per thread; retrying its UUID does not count again', async () => {
  const postId = await post();
  await actor(adopter);
  const started = await contact(postId);
  await consent(owner, true);
  await db.query('select public.dopmi_read_thread($1)', [started.thread_id]);
  const id = randomUUID();
  const first = await send(started.thread_id, id);
  assert.equal(first.message.origin, 'user');
  assert.deepEqual(first.signals, ['rescuer_first_reply']);
  const retry = await send(started.thread_id, id);
  assert.equal(retry.message.id, id);
  assert.deepEqual(retry.signals, []);
  assert.deepEqual((await send(started.thread_id)).signals, []);
});

test('a valid photo-only owner reply counts; an unavailable attachment creates no message', async () => {
  const postId = await post();
  await actor(adopter);
  const started = await contact(postId);
  await consent(owner, true);
  await rejects(() => send(started.thread_id, randomUUID(), '', 'invalid/photo.jpg'), '22023');
  const id = randomUUID(), path = `${owner}/${started.thread_id}/${id}.jpg`;
  await db.exec('reset role');
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-chat-photos',$1)", [path]);
  await actor(owner);
  assert.deepEqual((await send(started.thread_id, id, '', path)).signals, ['rescuer_first_reply']);
});

test('an owner message without an adopter entry is not a reply; the first answer after an entry is', async () => {
  const postId = await post();
  await actor(adopter);
  const thread = await value('select public.dopmi_start_thread($1) value', [postId]);
  await consent(owner, true);
  assert.deepEqual((await send(thread)).signals, []);
  await actor(adopter);
  assert.deepEqual((await send(thread)).signals, []);
  await actor(owner);
  assert.deepEqual((await send(thread)).signals, ['rescuer_first_reply']);
});

test('first reply while analytics is OFF cannot become a conversion after later opt-in', async () => {
  const postId = await post();
  await actor(adopter);
  const started = await contact(postId);
  await consent(owner, false);
  assert.deepEqual((await send(started.thread_id)).signals, []);
  await consent(owner, true);
  assert.deepEqual((await send(started.thread_id)).signals, []);
});

test('existing legacy owner replies are never reclassified or backfilled as a new first reply', async () => {
  await consent(owner, true);
  const legacyId = await value('select id value from public.dopmi_messages where thread_id=$1 and sender_id=$2', [legacyThread, owner]);
  const retried = await send(legacyThread, legacyId, 'Legado sintético');
  assert.equal(retried.message.origin, 'unknown');
  assert.deepEqual(retried.signals, []);
  assert.equal(await value('select is_adoption_reply value from public.dopmi_messages where id=$1', [legacyId]), null);
  assert.deepEqual((await send(legacyThread)).signals, []);
});

test('non-participants cannot send or manufacture a confirmed reply', async () => {
  const postId = await post();
  await actor(adopter);
  const started = await contact(postId);
  await consent(outsider, true);
  await rejects(() => send(started.thread_id), '42501');
});

test('marking adopted is a confirmed owner declaration regardless of reported Dopmi assistance', async () => {
  const postId = await post();
  await consent(owner, true);
  const version = await value('select version value from public.dopmi_adoptions where id=$1', [postId]);
  const result = await close(postId, version, 'adopted', false);
  assert.equal(result.adoption.status, 'adopted');
  assert.deepEqual(result.signals, ['adoption_marked_adopted']);
  await rejects(() => close(postId, version, 'adopted', false), 'PT409');
  await db.exec('reset role');
  const closure = await value('select to_jsonb(c) value from private.dopmi_adoption_closures c where post_id=$1 order by version desc limit 1', [postId]);
  assert.equal(closure.reason, 'adopted');
  assert.equal(closure.dopmi_support, false);
});

test('ordinary archival and non-consented adoption closure never emit an adoption conversion', async () => {
  const archivedPost = await post(), adoptedPost = await post();
  await actor(owner);
  for (const [id, reason, support] of [[archivedPost, 'other', null], [adoptedPost, 'adopted', false]]) {
    const version = await value('select version value from public.dopmi_adoptions where id=$1', [id]);
    assert.deepEqual((await close(id, version, reason, support)).signals, []);
  }
});

test('the prospective reply marker stays NULL on legacy rows and is writable only by server helpers', async () => {
  assert.equal(await value(`select count(*)::int value from public.dopmi_messages
    where thread_id=$1 and is_adoption_reply is null`, [legacyThread]), 2);
  for (const privilege of ['insert', 'update']) {
    assert.equal(await value('select has_column_privilege($1,$2,$3,$4) value',
      ['authenticated', 'public.dopmi_messages', 'is_adoption_reply', privilege]), false);
  }
  for (const signature of [
    'private.dopmi_confirmed_adoption_signals(uuid,text)',
    'private.dopmi_start_adoption_contact_result(uuid)',
    'private.dopmi_send_message_result(uuid,uuid,text,text,text)',
    'private.dopmi_send_message_with_origin(uuid,uuid,text,text,text)',
  ]) {
    for (const role of ['anon', 'authenticated', 'service_role']) {
      assert.equal(await value('select has_function_privilege($1,$2,\'execute\') value', [role, signature]), false);
    }
  }
  await actor(owner);
  await rejects(() => db.query('update public.dopmi_messages set is_adoption_reply=true where thread_id=$1', [legacyThread]), '42501');
});

test('legacy send and list RPCs retain their message JSON keys and one notification per UUID', async () => {
  const postId = await post();
  await actor(adopter);
  const thread = await value('select public.dopmi_start_adoption_contact($1) value', [postId]);
  await consent(owner, true);
  const id = randomUUID();
  const original = await value('select public.dopmi_send_message($1,$2,$3) value', [thread, id, 'Legado nuevo']);
  const retry = await value('select public.dopmi_send_message_v2($1,$2,$3) value', [thread, id, 'Legado nuevo']);
  assert.deepEqual(Object.keys(original).sort(), legacyMessageKeys);
  assert.deepEqual(retry, original);
  assert.deepEqual((await send(thread, id, 'Legado nuevo')).signals, []);
  const messages = await value('select public.dopmi_thread_messages($1) value', [thread]);
  for (const message of messages) assert.deepEqual(Object.keys(message).sort(), legacyMessageKeys);
  await db.exec('reset role');
  assert.equal(await value('select count(*)::int value from public.dopmi_notifications where source_id=$1', [id]), 1);
  assert.equal(await value('select is_adoption_reply value from public.dopmi_messages where id=$1', [id]), true);
});

test('a queued duplicate contact and message each create exactly one row and one conversion', async () => {
  const postId = await post();
  await consent(adopter, true);
  // PGlite serializes a single connection. These exercise overlapping callers;
  // lock races on distinct PostgreSQL sessions require the local PG runner.
  const contacts = await Promise.all([contact(postId), contact(postId)]);
  assert.equal(contacts[0].thread_id, contacts[1].thread_id);
  assert.equal(contacts.filter(result => result.created_new).length, 1);
  assert.equal(contacts.filter(result => result.signals.length).length, 1);
  await consent(owner, true);
  const id = randomUUID();
  const messages = await Promise.all([send(contacts[0].thread_id, id), send(contacts[0].thread_id, id)]);
  assert.equal(messages.filter(result => result.signals.length).length, 1);
  await db.exec('reset role');
  assert.equal(await value('select count(*)::int value from public.dopmi_messages where id=$1', [id]), 1);
  assert.equal(await value('select count(*)::int value from public.dopmi_notifications where source_id=$1', [id]), 1);
});

test('reply detection uses persisted server markers even when every message has the same timestamp', async () => {
  const postId = await post();
  await actor(adopter);
  const thread = await value('select public.dopmi_start_thread($1) value', [postId]);
  await consent(owner, true);
  const beforeIncoming = randomUUID();
  assert.deepEqual((await send(thread, beforeIncoming, 'Antes de entrada')).signals, []);
  await actor(adopter);
  await send(thread);
  await actor(owner);
  assert.deepEqual((await send(thread, beforeIncoming, 'Antes de entrada')).signals, []);
  assert.deepEqual((await send(thread)).signals, ['rescuer_first_reply']);
  await db.exec('reset role');
  assert.equal(await value('select is_adoption_reply value from public.dopmi_messages where id=$1', [beforeIncoming]), false);
  assert.equal(await value('select count(distinct created_at)::int value from public.dopmi_messages where thread_id=$1', [thread]), 1);
});

test('legacy incoming messages qualify as input while legacy owner NULL in another thread cannot suppress a reply', async () => {
  const postId = await post();
  await actor(adopter);
  const thread = await value('select public.dopmi_start_thread($1) value', [postId]);
  await db.exec('reset role');
  await db.query("insert into public.dopmi_messages(id,thread_id,sender_id,body) values($1,$2,$3,'Entrada heredada')", [randomUUID(), thread, adopter]);
  await consent(owner, true);
  assert.deepEqual((await send(thread)).signals, ['rescuer_first_reply']);
});

test('the acting account must consent: another participant opting in grants no signal', async () => {
  const postId = await post();
  await consent(owner, true);
  await consent(adopter, false);
  assert.deepEqual((await contact(postId)).signals, []);
});

test('invalid, mismatched UUID, closed-thread and unauthorized operations create no extra messages or notifications', async () => {
  const postId = await post();
  await actor(adopter);
  const started = await contact(postId);
  await consent(owner, true);
  await rejects(() => send(started.thread_id, randomUUID(), '   '), '22023');
  const id = randomUUID();
  await send(started.thread_id, id);
  await rejects(() => send(started.thread_id, id, 'Payload diferente'), '22023');
  const otherPost = await post();
  await actor(adopter);
  const otherThread = await value('select public.dopmi_start_thread($1) value', [otherPost]);
  await actor(owner);
  await rejects(() => send(otherThread, id), '22023');
  await actor(adopter);
  await rejects(() => send(started.thread_id, id), '22023');
  await value('select public.dopmi_close_thread($1) value', [started.thread_id]);
  await actor(owner);
  await rejects(() => send(started.thread_id), '22023');
  // Existing successful UUID remains safely retrievable after the thread closes.
  assert.deepEqual((await send(started.thread_id, id)).signals, []);
  await actor(outsider);
  await rejects(() => send(started.thread_id), '42501');
  await actor(owner);
  await rejects(() => contact(postId), '22023');
  await actor(null, 'anon');
  await rejects(() => contact(postId), '42501');
  await db.exec('reset role');
  assert.equal(await value('select count(*)::int value from public.dopmi_messages where thread_id=$1', [started.thread_id]), 2);
  assert.equal(await value('select count(*)::int value from public.dopmi_notifications where thread_id=$1', [started.thread_id]), 2);
});

test('a prior legacy adopted closure prevents reattribution after reactivation and an intervening other closure', async () => {
  const postId = await post();
  await consent(owner, true);
  await value('select public.dopmi_close_adoption($1,1,$2,$3) value', [postId, 'adopted', false]);
  await db.exec('reset role');
  await db.query("update public.dopmi_adoptions set status='published',version=version+1 where id=$1", [postId]);
  await actor(owner);
  let version = await value('select version value from public.dopmi_adoptions where id=$1', [postId]);
  assert.deepEqual((await close(postId, version, 'other', null)).signals, []);
  await db.exec('reset role');
  await db.query("update public.dopmi_adoptions set status='published',version=version+1 where id=$1", [postId]);
  await actor(owner);
  version = await value('select version value from public.dopmi_adoptions where id=$1', [postId]);
  assert.deepEqual((await close(postId, version)).signals, []);
});

test('an earlier other closure permits the first adopted declaration, but OFF then opt-in does not backfill it', async () => {
  const postId = await post();
  await actor(owner);
  await close(postId, 1, 'other', null);
  await db.exec('reset role');
  await db.query("update public.dopmi_adoptions set status='published',version=version+1 where id=$1", [postId]);
  await consent(owner, true);
  let version = await value('select version value from public.dopmi_adoptions where id=$1', [postId]);
  assert.deepEqual((await close(postId, version)).signals, ['adoption_marked_adopted']);
  const offPost = await post();
  await consent(owner, false);
  assert.deepEqual((await close(offPost, 1)).signals, []);
  await db.exec('reset role');
  await db.query("update public.dopmi_adoptions set status='published',version=version+1 where id=$1", [offPost]);
  await consent(owner, true);
  version = await value('select version value from public.dopmi_adoptions where id=$1', [offPost]);
  assert.deepEqual((await close(offPost, version)).signals, []);
});

test('adoption closure rejects outsiders and stale versions before changing the post or closure history', async () => {
  const postId = await post();
  await consent(outsider, true);
  await rejects(() => close(postId, 1), '42501');
  await consent(owner, true);
  await rejects(() => close(postId, 2), 'PT409');
  await rejects(() => close(postId, 1, 'adopted', null), '22023');
  await db.exec('reset role');
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_closures where post_id=$1', [postId]), 0);
  assert.equal(await value('select status value from public.dopmi_adoptions where id=$1', [postId]), 'published');
});

test('new envelopes retain existing Android and iOS acquisition milestones without using their cohorts to gate global signals', async () => {
  // The main owner already has a legacy published post and is intentionally
  // ineligible for new acquisition enrollment. This publisher has no history.
  const publisher = outsider;
  for (const id of [adopter, publisher]) {
    await consent(id, true);
    await value("select public.dopmi_record_android_rescuer_acquisition('personal-a',clock_timestamp()-interval '1 minute') value");
    const state = await value('select public.dopmi_adoption_measurement_state() value');
    assert.deepEqual(await value("select public.dopmi_record_ios_cpp_acquisition('personal-a',$1) value", [state.revision]), { status: 'recorded' });
  }
  const postId = await post(publisher);
  await actor(adopter);
  const started = await contact(postId);
  assert.deepEqual(started.signals, ['adoption_contact_created']);
  await send(started.thread_id);
  await actor(publisher);
  assert.deepEqual((await send(started.thread_id)).signals, ['rescuer_first_reply']);
  await db.exec('reset role');
  for (const table of ['dopmi_android_acquisition_events', 'dopmi_ios_cpp_acquisition_events']) {
    assert.deepEqual((await db.query(`select event_type from private.${table} where actor_id=$1 order by event_type`, [adopter])).rows,
      [{ event_type: 'automatic_greeting' }, { event_type: 'first_user_message' }]);
    assert.deepEqual((await db.query(`select event_type from private.${table} where actor_id=$1 order by event_type`, [publisher])).rows,
      [{ event_type: 'first_rescuer_reply' }]);
  }
});

// Distinct PostgreSQL connections are necessary to prove the FOR UPDATE gates.
// Explicit opt-in supports only the existing disposable loopback Supabase stack;
// a fresh database contains synthetic fixtures and is dropped in finally.
test('real PostgreSQL: contact, reply, UUID, close and consent races serialize confirmed outcomes', {
  skip: process.env.DOPMI_VALUE_SIGNALS_POSTGRES_TEST !== 'true', timeout: 120000,
}, async () => {
  assert.equal(process.env.PGPASSWORD, 'postgres', 'Only the disposable CI stack is supported');
  const config = { host: '127.0.0.1', port: 54322, user: 'postgres', database: 'postgres',
    password: 'postgres', ssl: false, connectionTimeoutMillis: 5000,
    options: '-c statement_timeout=20000 -c lock_timeout=15000' };
  const database = `dopmi_value_signals_test_${randomUUID().replaceAll('-', '')}`;
  const admin = new pg.Client(config);
  const isolated = { ...config, database };
  const control = new pg.Client(isolated), first = new pg.Client(isolated), second = new pg.Client(isolated);
  const connected = [];
  let created = false, adminConnected = false, pending;
  const current = async (client, sql, params = []) => (await client.query(sql, params)).rows[0]?.value;
  async function as(client, who) {
    await client.query('begin');
    await client.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)", [who, sessions.get(who)]);
    await client.query('set local role authenticated');
  }
  async function blocked(waiter, blocker) {
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      if (await current(control, 'select $2::int=any(pg_blocking_pids($1::int)) value', [waiter.processID, blocker.processID])) return;
      await pause(25);
    }
    assert.fail('Expected overlapping database lock was not observed');
  }
  async function choose(client, enabled) {
    const state = await current(client, 'select public.dopmi_adoption_measurement_state() value');
    return current(client, 'select public.dopmi_choose_usage_analytics($1,$2,$3) value', [enabled, state.revision, notice]);
  }
  const open = (client, listing) => current(client, 'select public.dopmi_start_adoption_contact_v2($1) value', [listing]);
  const write = (client, thread, id = randomUUID()) => current(client,
    "select public.dopmi_send_message_v3($1,$2,'Respuesta sintética de carrera') value", [thread, id]);
  const finish = (client, listing) => current(client, "select public.dopmi_close_adoption_v2($1,1,'adopted',false) value", [listing]);
  async function listing() {
    const id = randomUUID();
    await control.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Luna sintética','published')", [id, owner]);
    return id;
  }
  async function thread() {
    const id = await listing();
    await as(first, adopter);
    const result = await open(first, id);
    await first.query('commit');
    return result.thread_id;
  }
  try {
    await admin.connect(); adminConnected = true;
    assert.equal(admin.connectionParameters.host, '127.0.0.1');
    assert.equal(admin.connectionParameters.port, 54322);
    await admin.query(`create database "${database}" template template0`); created = true;
    for (const client of [control, first, second]) { await client.connect(); connected.push(client); }
    await control.query(authStorageSchema);
    const directory = new URL('../../supabase/migrations/', import.meta.url);
    for (const file of (await readdir(directory)).filter(file => file.endsWith('.sql')).sort()) {
      await control.query(await readFile(new URL(file, directory), 'utf8'));
    }
    for (const id of [owner, adopter]) {
      await control.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)', [id, id + '@example.test', metadata]);
      await control.query('insert into auth.sessions(id,user_id) values($1,$2)', [sessions.get(id), id]);
      await as(first, id); await choose(first, true); await first.query('commit');
    }

    const contactPost = await listing();
    await as(first, adopter);
    const contactA = await open(first, contactPost);
    await as(second, adopter); pending = open(second, contactPost); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    const contactB = await pending; pending = undefined; await second.query('commit');
    assert.deepEqual(contactA.signals, ['adoption_contact_created']);
    assert.deepEqual(contactB.signals, []);
    assert.equal(contactB.thread_id, contactA.thread_id);
    assert.equal(await current(control, 'select count(*)::int value from public.dopmi_messages where thread_id=$1', [contactA.thread_id]), 1);

    await as(first, owner);
    const replyA = await write(first, contactA.thread_id);
    await as(second, owner); pending = write(second, contactA.thread_id); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    const replyB = await pending; pending = undefined; await second.query('commit');
    assert.deepEqual(replyA.signals, ['rescuer_first_reply']);
    assert.deepEqual(replyB.signals, []);

    const duplicateThread = await thread(), duplicate = randomUUID();
    await as(first, owner);
    const original = await write(first, duplicateThread, duplicate);
    await as(second, owner); pending = write(second, duplicateThread, duplicate); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    const retried = await pending; pending = undefined; await second.query('commit');
    assert.deepEqual(original.signals, ['rescuer_first_reply']);
    assert.deepEqual(retried.signals, []);
    assert.deepEqual(retried.message, original.message);
    assert.equal(await current(control, 'select count(*)::int value from public.dopmi_notifications where source_id=$1', [duplicate]), 1);

    const adoptedPost = await listing();
    await as(first, owner);
    const closed = await finish(first, adoptedPost);
    await as(second, owner); pending = finish(second, adoptedPost); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    await assert.rejects(pending, { code: 'PT409' }); pending = undefined; await second.query('rollback');
    assert.deepEqual(closed.signals, ['adoption_marked_adopted']);
    assert.equal(await current(control, 'select count(*)::int value from private.dopmi_adoption_closures where post_id=$1', [adoptedPost]), 1);

    const offThread = await thread();
    await as(first, owner); await choose(first, false);
    await as(second, owner); pending = write(second, offThread); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    const offReply = await pending; pending = undefined; await second.query('commit');
    assert.deepEqual(offReply.signals, []);
    await as(first, owner); await choose(first, true);
    assert.deepEqual((await write(first, offThread)).signals, []);
    await first.query('commit');

    const onThread = await thread();
    await as(first, owner);
    const onReply = await write(first, onThread);
    await as(second, owner); pending = choose(second, false); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    assert.equal((await pending).applied, true); pending = undefined; await second.query('commit');
    assert.deepEqual(onReply.signals, ['rescuer_first_reply']);
  } finally {
    for (const client of connected) await client.query('rollback').catch(() => {});
    if (pending) await pending.catch(() => {});
    for (const client of connected) await client.end();
    if (created) await admin.query(`drop database "${database}"`);
    if (adminConnected) await admin.end();
  }
});
