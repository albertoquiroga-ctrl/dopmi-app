import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { setTimeout as pause } from 'node:timers/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';

const migration = '20261121022319_ios_cpp_acquisition.sql';
const owner = randomUUID(), adopter = randomUUID(), reviewer = randomUUID(), outsider = randomUUID();
const sessions = new Map();
const metadata = { display_name: 'Persona sintética', terms_version: 'terms-2026-10-17',
  privacy_version: 'privacy-2026-10-17', adult_confirmed: true };
const originalDefinitions = `select n.nspname,p.proname,p.oid::text,p.prosrc,p.proconfig,p.proacl::text,
  p.prosecdef,p.provolatile,p.proargnames,p.proargdefaults::text from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('private','public') and
  (p.proname like '%android%acquisition%' or p.proname in
    ('dopmi_set_adoption_measurement','dopmi_set_adoption_measurement_v2','dopmi_adoption_measurement_state',
     'dopmi_send_message','dopmi_send_message_v2','dopmi_start_adoption_contact','dopmi_send_message_with_origin'))
  order by n.nspname,p.proname`;
let db, previousDefinitions;
const value = async (sql, params = []) => (await db.query(sql, params)).rows[0]?.value;

async function bootstrap(target, createRoles = false, capture = false) {
  if (createRoles) await target.exec('create role anon; create role authenticated; create role service_role');
  await target.exec(`create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',
      email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz,
      created_at timestamptz default now());
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
    if (file === migration && capture) previousDefinitions = (await target.query(originalDefinitions)).rows;
    await target.exec(await readFile(new URL(file, directory), 'utf8'));
  }
}

async function person(id = randomUUID(), target = db) {
  await target.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)',
    [id, id + '@example.test', metadata]);
  const session = randomUUID();
  sessions.set(id, session);
  await target.query('insert into auth.sessions(id,user_id) values($1,$2)', [session, id]);
  return id;
}
async function actor(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)",
    [id ?? '', sessions.get(id) ?? '']);
  await db.exec('set local role ' + role);
}
const state = () => value('select public.dopmi_adoption_measurement_state() value');
const cas = (enabled, revision) => value('select public.dopmi_set_adoption_measurement_v2($1,$2) value', [enabled, revision]);
const enroll = (variant = 'personal-a', revision = 1) => value(
  'select public.dopmi_record_ios_cpp_acquisition($1,$2) value', [variant, revision]);
async function capture(id) {
  await actor(id);
  const prior = await state();
  const current = await cas(true, prior.revision);
  return enroll('personal-a', current.revision);
}
async function source(id) {
  await db.exec('reset role');
  return value('select to_jsonb(s) value from private.dopmi_ios_cpp_acquisition s where actor_id=$1', [id]);
}
async function events(id) {
  await db.exec('reset role');
  return (await db.query('select event_type,observed_at from private.dopmi_ios_cpp_acquisition_events where actor_id=$1 order by event_type', [id])).rows;
}
async function rejects(operation, code) {
  await db.exec('savepoint rejected');
  await assert.rejects(operation, { code });
  await db.exec('rollback to savepoint rejected; release savepoint rejected');
}
async function adoption(who = owner, fields = {}) {
  await db.exec('reset role');
  const id = randomUUID(), photo = `${who}/${id}/${randomUUID()}.jpg`;
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-adoption-photos',$1)", [photo]);
  await db.query(`insert into public.dopmi_adoptions(id,owner_id,pet_name,city,region,story,publisher_name,photos,
    status,submitted_at,published_at,age_band,personality) values($1,$2,'Mascota sintética','Monterrey',
    'Nuevo León','Una historia sintética suficientemente larga para revisar','Persona sintética',$3,$4,$5,$6,
    'adult',array['affectionate']::text[])`,
  [id, who, [photo], fields.status ?? 'draft', fields.submittedAt ?? null, fields.publishedAt ?? null]);
  return { id, version: 1 };
}
const transition = (post, action = 'submit') => value('select public.dopmi_transition_adoption($1,$2,$3) value', [post.id, post.version, action]);
const review = (post, decision = 'published') => value("select public.dopmi_review_adoption($1,$2,$3,'Revisión sintética legítima de prueba') value", [post.id, post.version, decision]);
const contact = id => value('select public.dopmi_start_adoption_contact($1) value', [id]);
const send = (thread, id = randomUUID(), body = 'Mensaje sintético', photo = null) => value(
  'select public.dopmi_send_message_v2($1,$2,$3,$4) value', [thread, id, body, photo]);

before(async () => {
  db = new PGlite();
  await bootstrap(db, true, true);
  for (const id of [owner, adopter, reviewer, outsider]) await person(id);
  await db.query('insert into private.admin_memberships(user_id) values($1)', [reviewer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('personal-a enrollment records only the authenticated actor and server receipt time', async () => {
  const beforeTime = await value('select clock_timestamp() value');
  assert.deepEqual(await capture(owner), { status: 'recorded' });
  const row = await source(owner);
  const afterTime = await value('select clock_timestamp() value');
  assert.equal(row.actor_id, owner);
  assert.equal(row.variant, 'personal-a');
  assert.equal(row.source_method, 'ios_cpp_open');
  assert.ok(new Date(row.attributed_at) >= new Date(beforeTime));
  assert.ok(new Date(row.attributed_at) <= new Date(afterTime));
  assert.equal(row.first_adoption_id, null);
  assert.equal(row.first_submitted_at, null);
  assert.equal(row.first_approved_at, null);
  assert.equal('clicked_at' in row, false);
  assert.equal('installed_at' in row, false);
  assert.equal(await source(adopter), undefined);
});

test('only personal-a and a nonnegative explicit consent revision are accepted', async () => {
  await actor(owner);
  await cas(true, 0);
  for (const variant of [null, '', 'personal-b', 'pagina-a', 'pagina-b', 'PERSONAL-A', 'personal-a?x=1']) {
    await rejects(() => enroll(variant, 1), '22023');
  }
  await rejects(() => enroll('personal-a', null), '22023');
  await rejects(() => enroll('personal-a', -1), '22023');
  assert.equal(await source(owner), undefined);
});

test('absent consent and stale enrollment after OFF then ON create no source', async () => {
  await actor(owner);
  assert.deepEqual(await enroll('personal-a', 0), { status: 'consent_changed' });
  assert.deepEqual(await cas(true, 0), { applied: true, consent: true, revision: 1 });
  await cas(false, 1);
  await cas(true, 2);
  assert.deepEqual(await enroll('personal-a', 1), { status: 'consent_changed' });
  assert.equal(await source(owner), undefined);
  await actor(owner);
  assert.deepEqual(await enroll('personal-a', 3), { status: 'recorded' });
});

test('first source is immutable across retries and later accepted consent revisions', async () => {
  await capture(owner);
  const original = await source(owner);
  await actor(owner);
  assert.deepEqual(await enroll(), { status: 'already_recorded' });
  await cas(true, 1);
  assert.deepEqual(await enroll('personal-a', 2), { status: 'already_recorded' });
  assert.deepEqual(await source(owner), original);
});

test('known submission or review history excludes enrollment but a private draft does not', async () => {
  await adoption(owner, { status: 'draft', submittedAt: '2026-11-01T12:00:00Z' });
  const old = await adoption(adopter, { status: 'archived' });
  await db.query("insert into private.dopmi_adoption_reviews(post_id,actor_id,decision,feedback,version) values($1,$2,'changes_requested','Historial sintético',1)", [old.id, reviewer]);
  await adoption(outsider);
  assert.deepEqual(await capture(owner), { status: 'ineligible' });
  assert.deepEqual(await capture(adopter), { status: 'ineligible' });
  assert.deepEqual(await capture(outsider), { status: 'recorded' });
  assert.equal(await source(owner), undefined);
  assert.equal(await source(adopter), undefined);
});

test('first original submission and its own approval count once across corrections', async () => {
  const first = await adoption(), second = await adoption();
  await capture(owner);
  await actor(owner);
  const submitted = await transition(first);
  const captured = await source(owner);
  assert.equal(captured.first_adoption_id, first.id);
  assert.ok(captured.first_submitted_at >= captured.attributed_at);
  assert.equal(captured.first_approved_at, null);
  await actor(reviewer);
  const corrected = await review(submitted, 'changes_requested');
  await actor(owner);
  const resubmitted = await transition(corrected);
  const next = await transition(second);
  await actor(reviewer);
  await review(next);
  assert.deepEqual(await source(owner), captured);
  await actor(reviewer);
  await review(resubmitted);
  const approved = await source(owner);
  assert.equal(approved.first_adoption_id, first.id);
  assert.equal(approved.first_submitted_at, captured.first_submitted_at);
  assert.ok(approved.first_approved_at >= approved.first_submitted_at);
});

test('submission stops at 336 hours from server attribution while normal submission still succeeds', async () => {
  const draft = await adoption();
  await capture(owner);
  await db.exec('reset role');
  await db.query("update private.dopmi_ios_cpp_acquisition set attributed_at=clock_timestamp()-interval '336 hours' where actor_id=$1", [owner]);
  await actor(owner);
  assert.equal((await transition(draft)).status, 'submitted');
  assert.equal((await source(owner)).first_submitted_at, null);
});

test('approval of the captured first submission remains observable after its window', async () => {
  const draft = await adoption();
  await capture(owner);
  await actor(owner);
  const submitted = await transition(draft);
  await db.exec('reset role');
  await db.query("update private.dopmi_ios_cpp_acquisition set attributed_at=clock_timestamp()-interval '400 hours' where actor_id=$1", [owner]);
  await actor(reviewer);
  assert.equal((await review(submitted)).status, 'published');
  assert.ok((await source(owner)).first_approved_at);
});

test('greeting, adopter composer text or photo, and rescuer reply use server origin and own actor', async () => {
  await capture(owner);
  await capture(adopter);
  const listing = await adoption(owner, { status: 'published' });
  await actor(adopter);
  const thread = await contact(listing.id);
  assert.deepEqual((await events(adopter)).map(e => e.event_type), ['automatic_greeting']);
  assert.deepEqual(await events(owner), []);
  await actor(adopter);
  assert.equal(await contact(listing.id), thread);
  const photoId = randomUUID(), photo = `${adopter}/${thread}/${photoId}.jpg`;
  await db.exec('reset role');
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-chat-photos',$1)", [photo]);
  await actor(adopter);
  assert.equal((await send(thread, photoId, '', photo)).origin, 'user');
  await send(thread, randomUUID(), 'Segundo mensaje');
  await actor(owner);
  await send(thread, randomUUID(), 'Respuesta sintética');
  assert.deepEqual((await events(adopter)).map(e => e.event_type), ['automatic_greeting', 'first_user_message']);
  assert.deepEqual((await events(owner)).map(e => e.event_type), ['first_rescuer_reply']);
  assert.deepEqual(await events(outsider), []);
  const originSource = await source(adopter);
  for (const e of await events(adopter)) assert.ok(new Date(e.observed_at) >= new Date(originSource.attributed_at));
});

test('unknown legacy messages and an owner message without prior inbound do not become milestones', async () => {
  await capture(owner);
  await capture(adopter);
  const listing = await adoption(owner, { status: 'published' });
  const thread = randomUUID();
  await db.query('insert into public.dopmi_threads(id,post_id,owner_id,adopter_id,pet_name) values($1,$2,$3,$4,$5)', [thread, listing.id, owner, adopter, 'Mascota sintética']);
  await actor(owner);
  await send(thread);
  assert.deepEqual(await events(owner), []);
  await db.query("insert into public.dopmi_messages(id,thread_id,sender_id,body) values($1,$2,$3,'Texto que parece saludo')", [randomUUID(), thread, adopter]);
  assert.deepEqual(await events(adopter), []);
  await actor(owner);
  await send(thread);
  assert.deepEqual((await events(owner)).map(e => e.event_type), ['first_rescuer_reply']);
});

test('participant authorization and empty-message validation remain intact with iOS observers', async () => {
  await capture(outsider);
  const listing = await adoption(owner, { status: 'published' });
  await actor(adopter);
  const thread = await contact(listing.id);
  await actor(outsider);
  await rejects(() => send(thread), '42501');
  await actor(adopter);
  await rejects(() => send(thread, randomUUID(), ''), '22023');
  assert.deepEqual(await events(outsider), []);
});

test('an old UUID retry cannot backfill a milestone after opt-out and a new enrollment', async () => {
  await capture(adopter);
  const listing = await adoption(owner, { status: 'published' });
  await actor(adopter);
  const thread = await contact(listing.id), id = randomUUID();
  const original = await send(thread, id);
  await cas(false, 1);
  await cas(true, 2);
  await enroll('personal-a', 3);
  assert.deepEqual(await send(thread, id), original);
  assert.deepEqual(await events(adopter), []);
  await actor(adopter);
  await send(thread);
  assert.deepEqual((await events(adopter)).map(e => e.event_type), ['first_user_message']);
});

test('expired message window does not block delivery and records no event', async () => {
  await capture(adopter);
  const listing = await adoption(owner, { status: 'published' });
  await db.query("update private.dopmi_ios_cpp_acquisition set attributed_at=clock_timestamp()-interval '336 hours' where actor_id=$1", [adopter]);
  await actor(adopter);
  const thread = await contact(listing.id);
  assert.equal((await send(thread)).origin, 'user');
  assert.deepEqual(await events(adopter), []);
});

test('opt-out, retained-profile deletion and Auth deletion purge only the matching actor', async () => {
  for (const id of [owner, adopter, outsider]) await capture(id);
  const listing = await adoption(reviewer, { status: 'published' });
  await actor(owner);
  await contact(listing.id);
  await cas(false, 1);
  assert.equal(await source(owner), undefined);
  assert.deepEqual(await events(owner), []);
  assert.ok(await source(adopter));
  await db.query("update public.profiles set account_status='deleted' where id=$1", [adopter]);
  assert.equal(await source(adopter), undefined);
  await db.query('delete from auth.users where id=$1', [outsider]);
  assert.equal(await source(outsider), undefined);
});

test('iOS private tables and trigger functions are inaccessible and original Android/RPC definitions are unchanged', async () => {
  assert.deepEqual((await db.query(originalDefinitions)).rows, previousDefinitions);
  for (const table of ['dopmi_ios_cpp_acquisition', 'dopmi_ios_cpp_acquisition_events']) {
    assert.equal(await value('select relrowsecurity value from pg_class where oid=$1::regclass', ['private.' + table]), true);
    for (const role of ['anon', 'authenticated', 'service_role']) {
      assert.equal(await value('select has_table_privilege($1,$2,\'select,insert,update,delete\') value', [role, 'private.' + table]), false);
    }
  }
  for (const role of ['anon', 'authenticated', 'service_role']) {
    assert.equal(await value("select has_function_privilege($1,'public.dopmi_record_ios_cpp_acquisition(text,bigint)','execute') value", [role]), role === 'authenticated');
    for (const signature of ['private.dopmi_observe_ios_cpp_acquisition()', 'private.dopmi_observe_ios_cpp_message_acquisition()',
      'private.dopmi_clear_ios_cpp_acquisition_on_opt_out()', 'private.dopmi_clear_ios_cpp_acquisition_on_delete()']) {
      assert.equal(await value('select has_function_privilege($1,$2,\'execute\') value', [role, signature]), false);
    }
  }
  await actor(owner);
  await rejects(() => db.exec('select * from private.dopmi_ios_cpp_acquisition'), '42501');
  await actor(null, 'anon');
  await rejects(() => enroll(), '42501');
  await actor(null);
  await rejects(() => enroll(), '42501');
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [owner]);
  await actor(owner);
  await rejects(() => enroll(), '42501');
});

test('Android enrollment and milestones still work with the new observers and stay separately reported', async () => {
  await capture(adopter);
  await actor(adopter);
  await db.query("select public.dopmi_record_android_rescuer_acquisition('pagina-b',clock_timestamp()-interval '1 minute')");
  const listing = await adoption(owner, { status: 'published' });
  await actor(adopter);
  const thread = await contact(listing.id);
  await send(thread);
  await db.exec('reset role');
  const android = await value('select to_jsonb(s) value from private.dopmi_android_rescuer_acquisition s where actor_id=$1', [adopter]);
  assert.equal(android.variant, 'pagina-b');
  assert.equal((await source(adopter)).variant, 'personal-a');
  assert.equal(await value('select count(*)::int value from private.dopmi_android_acquisition_events where actor_id=$1', [adopter]), 2);
  const report = await readFile(new URL('./ios-cpp-acquisition.sql', import.meta.url), 'utf8');
  const rows = (await db.query(report)).rows;
  assert.equal(rows.length, 1);
  assert.equal(rows[0].source_method, 'ios_cpp_open');
  assert.equal(rows[0].variant, 'personal-a');
  assert.equal(rows[0].attributed_accounts, 1);
  assert.equal(rows[0].first_observable_automatic_greetings_14d, 1);
  assert.equal(rows[0].first_observable_user_messages_14d, 1);
  assert.equal(rows[0].first_observable_rescuer_replies_14d, 0);
  assert.doesNotMatch(JSON.stringify(rows), new RegExp([adopter, owner, thread, listing.id, 'sintétic'].join('|')));
  assert.equal(Object.keys(rows[0]).some(key => key.startsWith('new_')), false);
});

// PGlite establishes behavior; overlapping lock orders require actual PostgreSQL.
test('real PostgreSQL: iOS enrollment, revocation, message and submission races remain atomic', {
  skip: process.env.DOPMI_ACQUISITION_POSTGRES_TEST !== 'true', timeout: 120000,
}, async () => {
  assert.equal(process.env.PGPASSWORD, 'postgres', 'Only the disposable test stack is supported');
  const port = Number(process.env.DOPMI_IOS_CPP_POSTGRES_PORT ?? 54322);
  assert.ok(Number.isInteger(port) && port >= 1024 && port <= 65535);
  const config = { host: '127.0.0.1', port, user: 'postgres', database: 'postgres', password: 'postgres',
    ssl: false, connectionTimeoutMillis: 5000, options: '-c statement_timeout=20000 -c lock_timeout=15000' };
  const admin = new pg.Client(config);
  const database = `dopmi_ios_cpp_${randomUUID().replaceAll('-', '')}`;
  const scoped = { ...config, database };
  const control = new pg.Client(scoped), first = new pg.Client(scoped), second = new pg.Client(scoped);
  const connected = [];
  let created = false, adminConnected = false, pending;
  const current = async (client, sql, params = []) => (await client.query(sql, params)).rows[0]?.value;
  const change = async (client, enabled) => {
    const prior = await current(client, 'select public.dopmi_adoption_measurement_state() value');
    return current(client, 'select public.dopmi_set_adoption_measurement_v2($1,$2) value', [enabled, prior.revision]);
  };
  const attribute = (client, revision) => current(client, "select public.dopmi_record_ios_cpp_acquisition('personal-a',$1) value", [revision]);
  async function as(client, id) {
    await client.query('begin');
    await client.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)", [id, sessions.get(id)]);
    await client.query('set local role authenticated');
  }
  async function blocked(waiter, blocker) {
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      if (await current(control, 'select $2::int=any(pg_blocking_pids($1::int)) value', [waiter.processID, blocker.processID])) return;
      await pause(25);
    }
    assert.fail('Expected competing PostgreSQL transaction was not observed blocking');
  }
  async function fixture() {
    const who = randomUUID(), publisher = randomUUID(), listing = randomUUID();
    for (const id of [who, publisher]) await person(id, { query: (...args) => control.query(...args) });
    await control.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Carrera sintética','published')", [listing, publisher]);
    await as(first, who);
    const opted = await change(first, true);
    await first.query('commit');
    return { who, listing, revision: opted.revision };
  }
  const count = who => current(control, 'select count(*)::int value from private.dopmi_ios_cpp_acquisition_events where actor_id=$1', [who]);
  try {
    await admin.connect(); adminConnected = true;
    assert.equal(admin.connectionParameters.host, '127.0.0.1');
    await admin.query(`create database "${database}" template template0`); created = true;
    for (const client of [control, first, second]) { await client.connect(); connected.push(client); }
    await bootstrap({ exec: sql => control.query(sql), query: (...args) => control.query(...args) });

    const f = await fixture();
    // Enrollment first: contact waits on consent, then captures one greeting.
    await as(first, f.who); await attribute(first, f.revision);
    await as(second, f.who); pending = current(second, 'select public.dopmi_start_adoption_contact($1) value', [f.listing]); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    const thread = await pending; await second.query('commit'); pending = null;
    assert.equal(await count(f.who), 1);

    // Message first: OFF waits, then cascades all acquisition data.
    await as(first, f.who);
    const oldId = randomUUID();
    const oldMessage = await current(first, "select public.dopmi_send_message($1,$2,'Carrera sintética') value", [thread, oldId]);
    await as(second, f.who); pending = change(second, false); pending.catch(() => {});
    await blocked(second, first); await first.query('commit'); await pending;
    await second.query('commit'); pending = null; assert.equal(await count(f.who), 0);

    // OFF first: the later delivery proceeds without recording a milestone.
    await as(first, f.who); let on = await change(first, true); await attribute(first, on.revision); await first.query('commit');
    await as(first, f.who); await change(first, false);
    await as(second, f.who); pending = current(second, "select public.dopmi_send_message($1,$2,'Después de OFF') value", [thread, randomUUID()]); pending.catch(() => {});
    await blocked(second, first); await first.query('commit'); await pending;
    await second.query('commit'); pending = null; assert.equal(await count(f.who), 0);

    // OFF then ON commits while an old consent-revision enrollment waits.
    await as(first, f.who); on = await change(first, true); const staleRevision = on.revision; await first.query('commit');
    await as(first, f.who); await change(first, false); on = await change(first, true);
    await as(second, f.who); pending = attribute(second, staleRevision); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    assert.deepEqual(await pending, { status: 'consent_changed' });
    await second.query('commit'); pending = null;
    assert.equal(await current(control, 'select count(*)::int value from private.dopmi_ios_cpp_acquisition where actor_id=$1', [f.who]), 0);

    // A repeated old UUID after fresh enrollment must not backfill.
    await as(first, f.who); await attribute(first, on.revision);
    assert.deepEqual(await current(first, "select public.dopmi_send_message($1,$2,'Carrera sintética') value", [thread, oldId]), oldMessage);
    await first.query('commit'); assert.equal(await count(f.who), 0);

    // Concurrent UUID retries still deliver and notify exactly once.
    const duplicate = randomUUID();
    await as(first, f.who); const sent = await current(first, "select public.dopmi_send_message($1,$2,'Único') value", [thread, duplicate]);
    await as(second, f.who); pending = current(second, "select public.dopmi_send_message($1,$2,'Único') value", [thread, duplicate]); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    assert.deepEqual(await pending, sent); await second.query('commit'); pending = null;
    assert.equal(await count(f.who), 1);
    assert.equal(await current(control, 'select count(*)::int value from public.dopmi_messages where id=$1', [duplicate]), 1);
    assert.equal(await current(control, "select count(*)::int value from public.dopmi_notifications where source_id=$1 and kind='message'", [duplicate]), 1);

    // Message first, enrollment second: no historic INSERT is backfilled.
    const before = await fixture();
    await as(first, before.who); const existingThread = await current(first, 'select public.dopmi_start_adoption_contact($1) value', [before.listing]);
    await as(second, before.who); pending = attribute(second, before.revision); pending.catch(() => {});
    await blocked(second, first); await first.query('commit'); await pending;
    await second.query('commit'); pending = null; assert.equal(await count(before.who), 0);
    await as(first, before.who); await current(first, "select public.dopmi_send_message($1,$2,'Después de atribución') value", [existingThread, randomUUID()]);
    await first.query('commit'); assert.equal(await count(before.who), 1);

    // A profile retained for account deletion cannot retain a concurrent milestone.
    const deleted = await fixture();
    await as(first, deleted.who); await attribute(first, deleted.revision);
    const deletionThread = await current(first, 'select public.dopmi_start_adoption_contact($1) value', [deleted.listing]);
    await first.query('commit');
    await as(first, deleted.who); await current(first, "select public.dopmi_send_message($1,$2,'Antes de eliminación') value", [deletionThread, randomUUID()]);
    await second.query('begin');
    pending = second.query("update public.profiles set account_status='deleted' where id=$1", [deleted.who]); pending.catch(() => {});
    await blocked(second, first); await first.query('commit'); await pending;
    await second.query('commit'); pending = null;
    assert.equal(await count(deleted.who), 0);
    assert.equal(await current(control, 'select count(*)::int value from private.dopmi_ios_cpp_acquisition where actor_id=$1', [deleted.who]), 0);

    // Enrollment and first submission share consent lock without inverse adoption locks.
    for (const enrollFirst of [true, false]) {
      const item = await fixture(), postId = randomUUID();
      await control.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Primera sintética','draft')", [postId, item.who]);
      await as(first, item.who);
      if (enrollFirst) await attribute(first, item.revision);
      else {
        await first.query('reset role');
        await first.query("update public.dopmi_adoptions set status='submitted',submitted_at=clock_timestamp() where id=$1", [postId]);
      }
      await as(second, item.who);
      pending = enrollFirst
        ? second.query('reset role').then(() => second.query("update public.dopmi_adoptions set status='submitted',submitted_at=clock_timestamp() where id=$1", [postId]))
        : attribute(second, item.revision);
      pending.catch(() => {});
      await blocked(second, first); await first.query('commit'); const result = await pending;
      await second.query('commit'); pending = null;
      const source = await current(control, 'select to_jsonb(s) value from private.dopmi_ios_cpp_acquisition s where actor_id=$1', [item.who]);
      if (enrollFirst) assert.equal(source.first_adoption_id, postId);
      else { assert.deepEqual(result, { status: 'ineligible' }); assert.equal(source, undefined); }
    }
  } finally {
    try {
      await Promise.allSettled(connected.map(client => client.query('rollback')));
      if (pending) await pending.catch(() => {});
    } finally {
      await Promise.allSettled(connected.map(client => client.end()));
      try {
        if (created) {
          assert.match(database, /^dopmi_ios_cpp_[0-9a-f]{32}$/);
          await admin.query(`drop database "${database}"`);
          assert.equal(await current(admin, 'select count(*)::int value from pg_database where datname=$1', [database]), 0);
        }
      } finally { if (adminConnected) await admin.end(); }
    }
  }
});
