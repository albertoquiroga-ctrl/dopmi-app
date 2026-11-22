import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { setTimeout as pause } from 'node:timers/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';

const migration = '20261121233958_android_campaign_placements.sql';
const manifest = JSON.parse(await readFile(new URL('../campaigns/rescuer-pilot-60-v1.json', import.meta.url), 'utf8'));
const qa = manifest.placements.find(p => p.isQa);
const publicPlacement = manifest.placements.find(p => p.armId === 'R4' && !p.isQa);
const notice = 'usage-analytics-2026-11-21';
const owner = randomUUID(), adopter = randomUUID(), reviewer = randomUUID(), outsider = randomUUID();
const existingLegacy = randomUUID();
const sessions = new Map();
const metadata = { display_name: 'Persona sintética', terms_version: 'terms-2026-10-17',
  privacy_version: 'privacy-2026-10-17', adult_confirmed: true };
const definitions = `select n.nspname,p.proname,p.oid::text,p.prosrc,p.proconfig,p.proacl::text,
  p.prosecdef,p.provolatile,p.proargnames,p.proargdefaults::text from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('private','public')
  and p.proname not in ('dopmi_record_android_experiment_acquisition','dopmi_observe_campaign_adoption_submission')
  order by n.nspname,p.proname,p.oid`;
const triggers = `select t.tgname,t.tgrelid::regclass::text,pg_get_triggerdef(t.oid) as definition
  from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
  where not t.tgisinternal and n.nspname in ('public','private')
  and t.tgname <> 'dopmi_observe_campaign_adoption_submission' order by t.tgrelid,t.tgname`;
let db, previousDefinitions, previousTriggers, previousSource, previousEvents;
const value = async (sql, params = []) => (await db.query(sql, params)).rows[0]?.value;

async function bootstrap(target, roles = false, capture = false) {
  if (roles) await target.exec('create role anon; create role authenticated; create role service_role');
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
    if (file === migration && capture) {
      // New local synthetic pre-upgrade data only. The production migration
      // must add a nullable label without modifying an existing source/event.
      await person(existingLegacy, target);
      await target.query('insert into private.dopmi_adoption_measurement(actor_id,consent,revision) values($1,true,1)', [existingLegacy]);
      await target.query(`insert into private.dopmi_android_rescuer_acquisition(actor_id,variant,clicked_at,attributed_at)
        values($1,'personal-b',clock_timestamp()-interval '20 days',clock_timestamp()-interval '20 days')`, [existingLegacy]);
      await target.query(`insert into private.dopmi_android_acquisition_events(actor_id,event_type,observed_at)
        values($1,'automatic_greeting',clock_timestamp()-interval '19 days')`, [existingLegacy]);
      previousSource = (await target.query('select to_jsonb(s) value from private.dopmi_android_rescuer_acquisition s where actor_id=$1', [existingLegacy])).rows[0].value;
      previousEvents = (await target.query('select * from private.dopmi_android_acquisition_events where actor_id=$1', [existingLegacy])).rows;
      previousDefinitions = (await target.query(definitions)).rows;
      previousTriggers = (await target.query(triggers)).rows;
    }
    await target.exec(await readFile(new URL(file, directory), 'utf8'));
  }
}

async function person(id, target = db) {
  await target.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)',
    [id, id + '@example.test', metadata]);
  const session = randomUUID(); sessions.set(id, session);
  await target.query('insert into auth.sessions(id,user_id) values($1,$2)', [session, id]);
}
async function actor(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)",
    [id ?? '', sessions.get(id) ?? '']);
  await db.exec('set local role ' + role);
}
const state = () => value('select public.dopmi_adoption_measurement_state() value');
const choose = async consent => {
  const current = await state();
  return value('select public.dopmi_choose_usage_analytics($1,$2,$3) value', [consent, current.revision, notice]);
};
const claim = (token = qa.token, revision = 1, clicked = new Date(Date.now() - 10000).toISOString()) => value(
  'select public.dopmi_record_android_experiment_acquisition($1,$2,$3) value', [token, clicked, revision]);
const legacy = () => value("select public.dopmi_record_android_rescuer_acquisition('personal-b',clock_timestamp()-interval '10 seconds') value");
async function capture(id = owner, token = qa.token) {
  await actor(id); const accepted = await choose(true); return claim(token, accepted.revision);
}
async function source(id = owner) {
  await db.exec('reset role');
  return value('select to_jsonb(s) value from private.dopmi_android_rescuer_acquisition s where actor_id=$1', [id]);
}
async function events(id = owner) {
  await db.exec('reset role');
  return (await db.query('select event_type from private.dopmi_android_acquisition_events where actor_id=$1 order by event_type', [id])).rows.map(r => r.event_type);
}
async function receipts(id = owner) {
  await db.exec('reset role');
  return (await db.query('select * from private.dopmi_campaign_adoption_submissions where actor_id=$1 order by post_id', [id])).rows;
}
async function enable(token = publicPlacement.token) {
  await db.exec('reset role');
  await db.query('update private.dopmi_campaign_placements set enabled=true where token=$1', [token]);
}
async function rejects(operation, code) {
  await db.exec('savepoint rejected'); await assert.rejects(operation, { code });
  await db.exec('rollback to savepoint rejected; release savepoint rejected');
}
async function adoption(who = owner) {
  await db.exec('reset role');
  const id = randomUUID(), photo = `${who}/${id}/${randomUUID()}.jpg`;
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-adoption-photos',$1)", [photo]);
  await db.query(`insert into public.dopmi_adoptions(id,owner_id,pet_name,city,region,story,publisher_name,photos,
    age_band,personality) values($1,$2,'Mascota sintética','Monterrey','Nuevo León',
    'Una historia sintética suficientemente larga para revisar','Persona sintética',$3,'adult',array['affectionate']::text[])`, [id, who, [photo]]);
  return { id, version: 1 };
}
const submit = post => value("select public.dopmi_transition_adoption($1,$2,'submit') value", [post.id, post.version]);
const review = (post, decision = 'published') => value("select public.dopmi_review_adoption($1,$2,$3,'Revisión sintética de prueba') value", [post.id, post.version, decision]);
const contact = id => value('select public.dopmi_start_adoption_contact($1) value', [id]);
const send = (thread, id = randomUUID()) => value("select public.dopmi_send_message_v2($1,$2,'Mensaje sintético',null) value", [thread, id]);

before(async () => {
  db = new PGlite(); await bootstrap(db, true, true);
  for (const id of [owner, adopter, reviewer, outsider]) await person(id);
  await db.query('insert into private.admin_memberships(user_id) values($1)', [reviewer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('registered QA token records one source using registry assignment and exact accepted consent revision', async () => {
  assert.deepEqual(await capture(), { status: 'recorded' });
  const row = await source();
  assert.equal(row.placement_token, qa.token);
  assert.equal(row.variant, qa.variant);
  assert.equal(row.first_adoption_id, null);
  assert.ok(new Date(row.clicked_at) <= new Date(row.attributed_at));
  assert.equal(await source(outsider), undefined);
});

test('registry seed matches all 60 public placements and separate QA; arm assignment is enforced', async () => {
  const rows = (await db.query('select * from private.dopmi_campaign_placements order by token')).rows;
  assert.equal(rows.length, 61);
  for (const item of manifest.placements) {
    const row = rows.find(r => r.token === item.token);
    assert.equal(row.experiment_id, manifest.experimentId);
    assert.equal(row.arm_id, item.armId); assert.equal(row.variant, item.variant);
    assert.equal(row.is_qa, item.isQa); assert.equal(row.enabled, item.isQa);
  }
  for (const arm of ['R1','R2','R3','R4']) assert.equal(rows.filter(r => !r.is_qa && r.arm_id === arm).length, 15);
  await rejects(() => db.query(`insert into private.dopmi_campaign_placements(token,experiment_id,arm_id,variant,is_qa,enabled)
    values($1,$2,'R1','pagina-a',false,false)`, ['f'.repeat(32), manifest.experimentId]), '23514');
});

test('additive migration preserves pre-existing legacy source and event data without labels or backfill', async () => {
  const current = await source(existingLegacy), { placement_token, ...originalColumns } = current;
  assert.equal(placement_token, null); assert.deepEqual(originalColumns, previousSource);
  assert.deepEqual((await db.query('select * from private.dopmi_android_acquisition_events where actor_id=$1', [existingLegacy])).rows, previousEvents);
  assert.deepEqual(await receipts(existingLegacy), []);
});

test('unknown, malformed, disabled and null tokens never become arbitrary legacy claims', async () => {
  await actor(owner); const accepted = await choose(true);
  for (const token of [null, '', 'A'.repeat(32), 'f'.repeat(32), publicPlacement.token, qa.token + '?x=1']) {
    assert.deepEqual(await claim(token, accepted.revision), { status: 'invalid_placement' });
  }
  assert.equal(await source(), undefined);
});

test('invalid click dates or consent revision are rejected without source mutation', async () => {
  await actor(owner); const accepted = await choose(true);
  for (const clicked of [null, new Date(Date.now() + 86400000).toISOString(), new Date(Date.now() - 337 * 3600000).toISOString()]) {
    await rejects(() => claim(qa.token, accepted.revision, clicked), '22023');
  }
  for (const revision of [null, -1]) await rejects(() => claim(qa.token, revision), '22023');
  assert.equal(await source(), undefined);
});

test('absent consent, OFF and old revision after OFF then ON cannot enroll', async () => {
  await actor(owner); assert.deepEqual(await claim(qa.token, 0), { status: 'consent_changed' });
  const old = await choose(true); await choose(false);
  assert.deepEqual(await claim(qa.token, old.revision), { status: 'consent_changed' });
  const current = await choose(true);
  assert.deepEqual(await claim(qa.token, old.revision), { status: 'consent_changed' });
  assert.deepEqual(await claim(qa.token, current.revision), { status: 'recorded' });
});

test('legacy first source wins unchanged and cannot be enriched with placement later', async () => {
  await actor(owner); const accepted = await choose(true); await legacy();
  const original = await source(); await actor(owner);
  assert.deepEqual(await claim(qa.token, accepted.revision), { status: 'already_recorded' });
  assert.deepEqual(await source(), original); assert.equal(original.placement_token, null);
});

test('experiment first source survives legacy claim, another placement and retry unchanged', async () => {
  await capture(); const original = await source(); await enable(); await actor(owner);
  await legacy(); assert.deepEqual(await claim(publicPlacement.token), { status: 'already_recorded' });
  assert.deepEqual(await claim(), { status: 'already_recorded' });
  assert.deepEqual(await source(), original);
});

test('known prior submission excludes enrollment while private drafts remain eligible', async () => {
  const draft = await adoption(); await capture(); assert.equal((await source()).first_adoption_id, null);
  const prior = await adoption(adopter); await actor(adopter); await submit(prior);
  assert.deepEqual(await capture(adopter), { status: 'ineligible' });
  assert.equal(await source(adopter), undefined);
  assert.equal((await db.query('select status from public.dopmi_adoptions where id=$1', [draft.id])).rows[0].status, 'draft');
});

test('same first original and approval remain exact through corrections and later pets', async () => {
  const first = await adoption(), second = await adoption(); await capture(); await actor(owner);
  const submitted = await submit(first); const original = await source();
  assert.equal(original.first_adoption_id, first.id); assert.equal(original.placement_token, qa.token);
  await actor(reviewer); const corrected = await review(submitted, 'changes_requested');
  await actor(owner); const resubmitted = await submit(corrected); const next = await submit(second);
  await actor(reviewer); await review(next); assert.deepEqual(await source(), original);
  await actor(reviewer); await review(resubmitted);
  const approved = await source(); assert.equal(approved.first_adoption_id, first.id);
  assert.equal(approved.first_submitted_at, original.first_submitted_at); assert.ok(approved.first_approved_at);
});

test('each original submitted publication has an immutable placement receipt through draft and correction cycles', async () => {
  assert.equal(await value("select to_regclass('private.dopmi_campaign_adoption_submissions')::text value"),
    'private.dopmi_campaign_adoption_submissions');
  await capture(); const first = await adoption(), second = await adoption(); await actor(owner);
  const original = await submit(first), another = await submit(second);
  const captured = await receipts(); assert.equal(captured.length, 2);
  assert.ok(captured.every(r => r.actor_id === owner && r.placement_token === qa.token));
  await actor(reviewer); const correction = await review(original, 'changes_requested');
  await actor(owner); await submit(correction);
  const withdrawn = await value("select public.dopmi_transition_adoption($1,$2,'withdraw') value", [another.id, another.version]);
  const saved = await value('select public.dopmi_save_adoption($1,$2,$3) value', [withdrawn, withdrawn.id, withdrawn.version]);
  assert.equal(saved.submitted_at, null); await submit(saved);
  assert.deepEqual(await receipts(), captured);
});

test('existing Android message observers separate own greeting, composer and owner reply', async () => {
  await capture(); const post = await adoption(); await actor(owner); const submitted = await submit(post);
  await actor(reviewer); await review(submitted);
  await capture(adopter); await actor(adopter); const thread = await contact(post.id);
  assert.deepEqual(await events(adopter), ['automatic_greeting']);
  await actor(adopter); await send(thread); assert.deepEqual(await events(adopter), ['automatic_greeting','first_user_message']);
  await actor(owner); await send(thread);
  assert.deepEqual(await events(adopter), ['automatic_greeting','first_user_message']);
  assert.deepEqual(await events(owner), ['first_rescuer_reply']);
});

test('336-hour window excludes late submissions without blocking normal app behavior', async () => {
  const post = await adoption(); await capture(); await db.exec('reset role');
  await db.query("update private.dopmi_android_rescuer_acquisition set clicked_at=clock_timestamp()-interval '337 hours' where actor_id=$1", [owner]);
  await actor(owner); assert.equal((await submit(post)).status, 'submitted');
  assert.equal((await source()).first_submitted_at, null);
  assert.deepEqual(await receipts(), []);
});

test('opt-out, retained profile deletion and Auth deletion remove sources but preserve registry', async () => {
  await capture(); await actor(owner); await choose(false); assert.equal(await source(), undefined);
  await capture(adopter); const retained = await adoption(adopter); await actor(adopter); await submit(retained);
  assert.equal((await receipts(adopter)).length, 1); await db.exec('reset role');
  await db.query("update public.profiles set account_status='deleted' where id=$1", [adopter]);
  assert.equal(await source(adopter), undefined); assert.deepEqual(await receipts(adopter), []);
  await capture(outsider); const deleted = await adoption(outsider); await actor(outsider); await submit(deleted);
  assert.equal((await receipts(outsider)).length, 1); await db.exec('reset role'); await db.query('delete from auth.users where id=$1', [outsider]);
  assert.equal(await source(outsider), undefined);
  assert.deepEqual(await receipts(owner), []); assert.deepEqual(await receipts(outsider), []);
  assert.equal(await value('select count(*)::int value from private.dopmi_campaign_placements'), 61);
});

test('operator reports include 60 zero-capable placements with QA separate and exact owned publication joins', async () => {
  const aggregateSql = await readFile(new URL('./android-campaign-placements.sql', import.meta.url), 'utf8');
  let reports = await db.exec(aggregateSql);
  assert.equal(reports.length, 2); assert.equal(reports[0].rows.length, 60); assert.equal(reports[1].rows.length, 1);
  assert.ok(reports[0].rows.every(r => r.attributed_accounts === 0));
  await enable(); await capture(owner, publicPlacement.token); const first = await adoption(), second = await adoption();
  await actor(owner); await submit(first); await submit(second);
  const foreign = await adoption(outsider); await actor(outsider); await submit(foreign);
  const draft = await adoption();
  await db.exec('reset role'); reports = await db.exec(aggregateSql);
  const measured = reports[0].rows.find(r => r.placement_token === publicPlacement.token);
  assert.equal(measured.attributed_accounts, 1); assert.equal(measured.first_observable_submissions_14d, 1);
  assert.equal(measured.all_submitted_pets_14d, 2);
  const detailSql = await readFile(new URL('./android-campaign-placement-publications.sql', import.meta.url), 'utf8');
  const details = await db.exec(detailSql);
  assert.equal(details[0].rows.length, 1); assert.equal(details[0].rows[0].post_id, first.id);
  assert.equal(details[1].rows.length, 1); assert.equal(details[1].rows[0].post_id, second.id);
  assert.ok(!details.flatMap(r => r.rows).some(r => [foreign.id, draft.id].includes(r.post_id)));
  // Even a corrupt primary reference cannot disclose another owner's pet.
  await db.query('update private.dopmi_android_rescuer_acquisition set first_adoption_id=$1 where actor_id=$2', [foreign.id, owner]);
  assert.equal((await db.exec(detailSql))[0].rows.length, 0);
  await db.query('update private.dopmi_android_rescuer_acquisition set first_adoption_id=$1 where actor_id=$2', [first.id, owner]);
  // A later mutable timestamp must not change the stable receipt's inclusion.
  await db.query("update public.dopmi_adoptions set submitted_at=clock_timestamp()+interval '337 hours' where id=$1", [second.id]);
  assert.equal((await db.exec(detailSql))[1].rows.length, 1);
  await actor(owner); await choose(false); await db.exec('reset role');
  assert.equal((await db.exec(detailSql))[0].rows.length, 0);
  assert.deepEqual(await receipts(), []);
});

test('receipt capture excludes legacy sources, other owners, drafts, published edits and post deletion', async () => {
  await actor(owner); await choose(true); await legacy(); const legacyPost = await adoption(); await actor(owner); await submit(legacyPost);
  assert.deepEqual(await receipts(), []);
  await capture(adopter); const post = await adoption(adopter), draft = await adoption(adopter);
  await actor(adopter); const submitted = await submit(post); const original = await receipts(adopter);
  assert.equal(original.length, 1); assert.equal(original[0].post_id, post.id);
  await actor(reviewer); const published = await review(submitted);
  await actor(adopter); const edited = await value('select public.dopmi_save_adoption($1,$2,$3) value', [published, published.id, published.version]);
  await submit(edited); assert.deepEqual(await receipts(adopter), original);
  await db.exec('reset role'); await db.query('delete from public.dopmi_adoptions where id=$1', [post.id]);
  assert.deepEqual(await receipts(adopter), []);
  assert.equal((await db.query('select status from public.dopmi_adoptions where id=$1', [draft.id])).rows[0].status, 'draft');
});

test('private registry has no client CRUD and all previous functions and triggers remain unchanged', async () => {
  assert.deepEqual((await db.query(definitions)).rows, previousDefinitions);
  assert.deepEqual((await db.query(triggers)).rows, previousTriggers);
  const tables = (await db.query("select relrowsecurity from pg_class where oid in ('private.dopmi_campaign_placements'::regclass,'private.dopmi_campaign_adoption_submissions'::regclass)")).rows;
  assert.equal(tables.length, 2); assert.ok(tables.every(row => row.relrowsecurity));
  for (const role of ['anon','authenticated','service_role']) {
    for (const table of ['private.dopmi_campaign_placements','private.dopmi_campaign_adoption_submissions']) {
      for (const privilege of ['SELECT','INSERT','UPDATE','DELETE']) {
        assert.equal(await value('select has_table_privilege($1,$2,$3) value', [role, table, privilege]), false);
      }
    }
  }
  const rpc = (await db.query("select prosecdef,proconfig from pg_proc where oid='public.dopmi_record_android_experiment_acquisition(text,timestamp with time zone,bigint)'::regprocedure")).rows[0];
  assert.equal(rpc.prosecdef, true); assert.deepEqual(rpc.proconfig, ['search_path=""']);
  const observer = (await db.query("select prosecdef,proconfig from pg_proc where oid='private.dopmi_observe_campaign_adoption_submission()'::regprocedure")).rows[0];
  assert.equal(observer.prosecdef, true); assert.deepEqual(observer.proconfig, ['search_path=""']);
  for (const role of ['anon','authenticated','service_role']) {
    assert.equal(await value('select has_function_privilege($1,$2,$3) value',
      [role, 'private.dopmi_observe_campaign_adoption_submission()', 'EXECUTE']), false);
  }
  await actor(owner); await rejects(() => db.exec('select * from private.dopmi_campaign_placements'), '42501');
  await actor(null, 'anon'); await rejects(() => claim(), '42501');
});

test('real PostgreSQL: legacy/new first-source races and stale-consent races are atomic', {
  skip: process.env.DOPMI_ACQUISITION_POSTGRES_TEST !== 'true', timeout: 180000,
}, async () => {
  assert.equal(process.env.PGPASSWORD, 'postgres', 'Only the disposable local stack is supported');
  const port = Number(process.env.DOPMI_CAMPAIGN_POSTGRES_PORT ?? 54322);
  assert.ok(Number.isInteger(port) && port >= 1024 && port <= 65535);
  const config = { host: '127.0.0.1', port, user: 'postgres', database: 'postgres', password: 'postgres',
    ssl: false, connectionTimeoutMillis: 5000, options: '-c statement_timeout=20000 -c lock_timeout=15000' };
  const database = `dopmi_campaign_${randomUUID().replaceAll('-', '')}`;
  const admin = new pg.Client({ ...config, options: '-c statement_timeout=90000 -c lock_timeout=15000' });
  const control = new pg.Client({ ...config, database });
  const first = new pg.Client({ ...config, database }), second = new pg.Client({ ...config, database });
  const connected = []; let creationAttempted = false, adminConnected = false, pending;
  const scalar = async (client, sql, params = []) => (await client.query(sql, params)).rows[0]?.value;
  const as = async (client, id) => {
    await client.query('begin');
    await client.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)", [id, sessions.get(id)]);
    await client.query('set local role authenticated');
  };
  const change = async (client, enabled) => {
    const prior = await scalar(client, 'select public.dopmi_adoption_measurement_state() value');
    return scalar(client, 'select public.dopmi_choose_usage_analytics($1,$2,$3) value', [enabled, prior.revision, notice]);
  };
  const enroll = (client, revision, token = qa.token) => scalar(client,
    "select public.dopmi_record_android_experiment_acquisition($1,clock_timestamp()-interval '10 seconds',$2) value", [token, revision]);
  const old = client => scalar(client, "select public.dopmi_record_android_rescuer_acquisition('personal-b',clock_timestamp()-interval '10 seconds') value");
  const get = id => scalar(control, 'select to_jsonb(s) value from private.dopmi_android_rescuer_acquisition s where actor_id=$1', [id]);
  async function fixture() {
    const id = randomUUID(); await person(id, control); await as(first, id);
    const on = await change(first, true); await first.query('commit'); return { id, revision: on.revision };
  }
  async function blocked(waiter, blocker) {
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      if (await scalar(control, 'select $2::int=any(pg_blocking_pids($1::int)) value', [waiter.processID, blocker.processID])) return;
      await pause(25);
    }
    assert.fail('Expected PostgreSQL lock contention was not observed');
  }
  try {
    await admin.connect(); adminConnected = true;
    assert.equal(admin.connectionParameters.host, '127.0.0.1');
    creationAttempted = true; await admin.query(`create database "${database}" template template0`);
    for (const client of [control, first, second]) { await client.connect(); connected.push(client); }
    await bootstrap({ exec: sql => control.query(sql), query: (...args) => control.query(...args) });
    for (const legacyFirst of [true, false]) {
      const f = await fixture(); await as(first, f.id);
      await (legacyFirst ? old(first) : enroll(first, f.revision));
      await as(second, f.id); pending = legacyFirst ? enroll(second, f.revision) : old(second); pending.catch(() => {});
      await blocked(second, first); await first.query('commit'); await pending; await second.query('commit'); pending = null;
      const winner = await get(f.id);
      assert.equal(winner.placement_token, legacyFirst ? null : qa.token);
      assert.equal(winner.variant, legacyFirst ? 'personal-b' : qa.variant);
    }
    await control.query('update private.dopmi_campaign_placements set enabled=true where token=$1', [publicPlacement.token]);
    const competing = await fixture(); await as(first, competing.id); await enroll(first, competing.revision);
    await as(second, competing.id); pending = enroll(second, competing.revision, publicPlacement.token); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    assert.deepEqual(await pending, { status: 'already_recorded' }); await second.query('commit'); pending = null;
    assert.equal((await get(competing.id)).placement_token, qa.token);
    const stale = await fixture(); await as(first, stale.id); await change(first, false); await change(first, true);
    await as(second, stale.id); pending = enroll(second, stale.revision); pending.catch(() => {});
    await blocked(second, first); await first.query('commit');
    assert.deepEqual(await pending, { status: 'consent_changed' }); await second.query('commit'); pending = null;
    assert.equal(await get(stale.id), undefined);
    const revoked = await fixture(); await as(first, revoked.id); await enroll(first, revoked.revision);
    await as(second, revoked.id); pending = change(second, false); pending.catch(() => {});
    await blocked(second, first); await first.query('commit'); await pending; await second.query('commit'); pending = null;
    assert.equal(await get(revoked.id), undefined);

    // Enrollment and first submission serialize on consent; no inverse post
    // lock is added by the new enrollment RPC or the additional receipt.
    for (const enrollFirst of [true, false]) {
      const f = await fixture(), post = randomUUID();
      await control.query("insert into public.dopmi_adoptions(id,owner_id,pet_name) values($1,$2,'Carrera sintética')", [post, f.id]);
      const publish = async client => {
        await client.query('reset role');
        return client.query("update public.dopmi_adoptions set status='submitted',submitted_at=clock_timestamp() where id=$1", [post]);
      };
      await as(first, f.id); await (enrollFirst ? enroll(first, f.revision) : publish(first));
      await as(second, f.id); pending = enrollFirst ? publish(second) : enroll(second, f.revision); pending.catch(() => {});
      await blocked(second, first); await first.query('commit'); const result = await pending;
      await second.query('commit'); pending = null;
      const acquired = await get(f.id);
      const receiptCount = await scalar(control, 'select count(*)::int value from private.dopmi_campaign_adoption_submissions where actor_id=$1', [f.id]);
      if (enrollFirst) { assert.equal(acquired.first_adoption_id, post); assert.equal(receiptCount, 1); }
      else { assert.deepEqual(result, { status: 'ineligible' }); assert.equal(acquired, undefined); assert.equal(receiptCount, 0); }
    }

    // A receipt insertion may win before OFF/deletion; the later source purge
    // must still cascade it, with the original listing operation succeeding.
    for (const deletion of [false, true]) {
      const f = await fixture(), post = randomUUID();
      await as(first, f.id); await enroll(first, f.revision); await first.query('commit');
      await control.query("insert into public.dopmi_adoptions(id,owner_id,pet_name) values($1,$2,'Recibo sintético')", [post, f.id]);
      await as(first, f.id); await first.query('reset role');
      await first.query("update public.dopmi_adoptions set status='submitted',submitted_at=clock_timestamp() where id=$1", [post]);
      if (deletion) {
        await second.query('begin');
        pending = second.query("update public.profiles set account_status='deleted' where id=$1", [f.id]);
      } else { await as(second, f.id); pending = change(second, false); }
      pending.catch(() => {}); await blocked(second, first); await first.query('commit'); await pending;
      await second.query('commit'); pending = null;
      assert.equal(await get(f.id), undefined);
      assert.equal(await scalar(control, 'select count(*)::int value from private.dopmi_campaign_adoption_submissions where actor_id=$1', [f.id]), 0);
    }
  } finally {
    await Promise.allSettled(connected.map(client => client.query('rollback')));
    if (pending) await pending.catch(() => {});
    await Promise.allSettled(connected.map(client => client.end()));
    try {
      if (creationAttempted) {
        assert.match(database, /^dopmi_campaign_[0-9a-f]{32}$/);
        if (await scalar(admin, 'select count(*)::int value from pg_database where datname=$1', [database])) {
          await admin.query(`drop database "${database}"`);
        }
        assert.equal(await scalar(admin, 'select count(*)::int value from pg_database where datname=$1', [database]), 0);
      }
    } finally { if (adminConnected) await admin.end(); }
  }
});
