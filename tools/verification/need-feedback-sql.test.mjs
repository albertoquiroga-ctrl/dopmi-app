import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

// The repository's disposable PostgreSQL/Auth/Storage bootstrap. No Supabase
// service, Docker daemon, remote URL, live identity or financial API is used.
let db, priorDefinitions, definitionsAfterComments;
const migration = '20261102061534_admin_case_need_comments.sql';
const owner = randomUUID(), reviewer = randomUUID(), secondReviewer = randomUUID(), other = randomUUID();
const keptFunctions = ['public.dopmi_rescue_detail(uuid)',
  'public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean)',
  'public.dopmi_save_rescue(text,jsonb,jsonb,jsonb,uuid,integer,uuid)',
  'public.dopmi_transition_rescue(uuid,integer,text)'];
const value = async (sql, args = []) => (await db.query(sql, args)).rows[0]?.value;
async function actor(id = reviewer, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
  await db.exec(`set local role ${role}`);
}
async function rejected(action, code) {
  await db.exec('savepoint rejection');
  await assert.rejects(action, { code });
  await db.exec('rollback to savepoint rejection');
}
const packet = (id, page = 1) => value('select public.dopmi_admin_rescue_packet($1,$2) value', [id, page]);
const comment = (id, version, comments, request = randomUUID()) => value(
  'select public.dopmi_comment_case_needs($1,$2,$3::jsonb,$4) value', [id, version, JSON.stringify(comments), request]);
const planned = (f, body = 'Aclara el tratamiento', version = 4) => ({ target_kind: 'planned', target_id: f.need, target_version: version, body });
const expenseComment = (f, body = 'Adjunta el desglose', version = 2) => ({ target_kind: 'expense', target_id: f.expense, target_version: version, body });
async function fixture() {
  await db.exec('reset role');
  const f = { id: randomUUID(), need: randomUUID(), expense: randomUUID(), draft: randomUUID(), mixed: randomUUID() };
  const needs = [{ id: f.need, type: 'veterinary', title: 'Consulta prevista', amount_cents: 30000, detail: '', urgent: false }];
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,version,public_data,video_thanks_required)
    values($1,$2,'case','submitted',4,$3::jsonb,false)`, [f.id, owner, JSON.stringify({ pet_name: 'Luna sintética', need_items: needs })]);
  for (const [id, who, status, title] of [[f.expense, owner, 'submitted', 'Consulta pagada'],
    [f.draft, owner, 'draft', 'BORRADOR PRIVADO'], [f.mixed, other, 'submitted', 'OTRO PROPIETARIO']]) {
    await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,status,version,public_data,private_data,files)
      values($1::uuid,$2::uuid,'expense',$3,$4,2,$5::jsonb,'{"vendor":"Proveedor sintético","amount_cents":"30000"}',
      jsonb_build_array(jsonb_build_object('role','receipt','path',$2::uuid::text||'/'||$1::uuid::text||'/00000000-0000-4000-8000-000000000001.pdf')))`,
    [id, who, f.id, status, JSON.stringify({ title })]);
  }
  return f;
}
async function definitions() {
  return Promise.all(keptFunctions.map(name => value('select pg_get_functiondef($1::regprocedure) value', [name])));
}
async function inventory() {
  await db.exec('reset role');
  const result = {};
  for (const table of ['public.dopmi_rescue_records', 'public.dopmi_donations', 'private.dopmi_case_allocations',
    'private.dopmi_connect_accounts', 'private.dopmi_payment_environment', 'private.dopmi_video_settings', 'private.dopmi_store_settings']) {
    result[table] = (await db.query(`select to_jsonb(t) value from ${table} t order by to_jsonb(t)::text`)).rows;
  }
  return result;
}

before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.identities(user_id uuid,provider text,provider_id text);
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(directory)).filter(f => f.endsWith('.sql')).sort()) {
    if (file === migration) priorDefinitions = await definitions();
    try { await db.exec(await readFile(new URL(file, directory), 'utf8')); }
    catch (error) { throw new Error(`Migration ${file}: ${error.code}: ${error.message}`); }
    if (file === migration) definitionsAfterComments = await definitions();
  }
  for (const id of [owner, reviewer, secondReviewer, other]) {
    await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      values($1,$2,now(),'{"display_name":"PERSONAL STAFF NAME","is_admin":true}')`, [id, `${id}@example.test`]);
  }
  await db.query('insert into private.admin_memberships(user_id) values($1),($2)', [reviewer, secondReviewer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('additive migration preserves existing review, save, transition, detail and private ACLs', async () => {
  // Check the additive comments migration at its own boundary. Later delivery
  // migrations can intentionally extend the initial-case submission contract.
  assert.deepEqual(definitionsAfterComments, priorDefinitions);
  for (const name of ['public.dopmi_admin_rescue_packet(uuid,integer)', 'public.dopmi_comment_case_needs(uuid,integer,jsonb,uuid)']) {
    for (const role of ['anon', 'service_role']) assert.equal(await value('select has_function_privilege($1,$2,\'execute\') value', [role, name]), false);
    assert.equal(await value('select has_function_privilege(\'authenticated\',$1,\'execute\') value', [name]), true);
  }
  assert.equal(await value("select has_function_privilege('authenticated','private.dopmi_need_comment_dto(uuid,uuid,integer,timestamptz,jsonb)','execute') value"), false);
  assert.equal(await value("select has_table_privilege('authenticated','private.dopmi_rescue_history','select') value"), false);
});

test('packet excludes private/mixed-owner children before totals and audits only visible children', async () => {
  const f = await fixture();
  const pending = randomUUID();
  await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,status) values($1,$2,'case','pending_stripe')", [pending, owner]);
  await actor();
  const result = await packet(f.id);
  assert.equal(result.record.id, f.id); assert.ok('history' in result && 'verified' in result && 'case_status' in result);
  assert.deepEqual(result.expenses.items.map(e => e.id), [f.expense]);
  assert.equal(result.expenses.total, 1); assert.equal(result.expenses.page, 1);
  assert.deepEqual(result.need_comments, []);
  assert.doesNotMatch(JSON.stringify(result), /BORRADOR PRIVADO|OTRO PROPIETARIO|https:\/\//);
  await rejected(() => packet(pending), '42501');
  for (const page of [0, -1, 1001, null]) await rejected(() => packet(f.id, page), '22023');
  await db.exec('reset role');
  const audits = (await db.query("select record_id from private.dopmi_rescue_history where action='read' order by record_id")).rows.map(x => x.record_id);
  assert.deepEqual(audits.sort(), [f.id, f.expense].sort());
});

test('packet paginates twenty accessible expenses and keeps non-case legacy shape', async () => {
  const f = await fixture();
  await db.query(`insert into public.dopmi_rescue_records(owner_id,kind,parent_id,status)
    select $1,'expense',$2,'submitted' from generate_series(1,20)`, [owner, f.id]);
  await actor();
  const one = await packet(f.id), two = await packet(f.id, 2);
  assert.equal(one.expenses.total, 21); assert.equal(one.expenses.items.length, 20); assert.equal(two.expenses.items.length, 1);
  assert.equal(new Set([...one.expenses.items, ...two.expenses.items].map(e => e.id)).size, 21);
  const legacy = await packet(f.expense);
  assert.deepEqual(legacy.expenses, { total: 0, page: 1, items: [] }); assert.deepEqual(legacy.need_comments, []);
});

test('both RPCs require current active confirmed membership; owner and metadata cannot grant review', async () => {
  const f = await fixture();
  for (const id of [owner, other]) {
    await actor(id);
    await rejected(() => packet(f.id), '42501');
    await rejected(() => comment(f.id, 4, [planned(f)]), '42501');
  }
  await db.exec('reset role');
  await db.query('insert into private.admin_memberships(user_id) values($1)', [owner]);
  await actor(owner); await rejected(() => comment(f.id, 4, [planned(f)]), '42501');
  for (const change of ["update private.admin_memberships set active=false where user_id=$1",
    "update public.profiles set account_status='suspended' where id=$1", 'update auth.users set email_confirmed_at=null where id=$1']) {
    await db.exec('reset role'); await db.exec('savepoint role_state'); await db.query(change, [reviewer]);
    await actor(); await rejected(() => packet(f.id), '42501'); await rejected(() => comment(f.id, 4, [planned(f)]), '42501');
    await db.exec('reset role'); await db.exec('rollback to savepoint role_state');
  }
  for (const role of ['anon', 'service_role']) {
    await actor(null, role); await rejected(() => packet(f.id), '42501');
    await rejected(() => comment(f.id, 4, [planned(f)]), '42501');
  }
});

test('one atomic batch has minimal DTOs and contextual legacy history, with no record or finance delta', async () => {
  const f = await fixture(), request = randomUUID();
  const before = await inventory(); await actor();
  const result = await comment(f.id, 4, [planned(f, '  Aclara el tratamiento  '), expenseComment(f)], request);
  assert.equal(result.request_id, request); assert.equal(result.record_id, f.id); assert.equal(result.case_version, 4);
  assert.equal(result.comments.length, 2);
  for (const c of result.comments) {
    assert.deepEqual(Object.keys(c).sort(), ['id', 'request_id', 'case_id', 'case_version', 'target_kind', 'target_id', 'target_version', 'target_title', 'body', 'created_at'].sort());
    assert.equal(c.id, `${request}:${c.target_kind}:${c.target_id}`);
  }
  const resultPacket = await packet(f.id);
  assert.equal(resultPacket.need_comments.length, 2);
  assert.doesNotMatch(JSON.stringify(resultPacket.need_comments), /snapshot|PERSONAL STAFF NAME|vendor|actor_id|files/);
  assert.match(resultPacket.history.find(h => h.action === 'need_comments').feedback, /Consulta prevista:\nAclara el tratamiento/);
  assert.match(resultPacket.history.find(h => h.action === 'need_comments').feedback, /Consulta pagada:\nAdjunta el desglose/);
  assert.deepEqual(await inventory(), before);
  const event = await value("select to_jsonb(h) value from private.dopmi_rescue_history h where id=$1", [request]);
  assert.equal(event.actor_id, reviewer); assert.equal(event.actor_type, 'user'); assert.equal(event.source, 'user');
  assert.equal(event.snapshot.id, f.id); assert.equal(event.version, 4);
  await actor(owner);
  const ownerDetail = await value('select public.dopmi_rescue_detail($1) value', [f.id]);
  assert.match(ownerDetail.history.find(h => h.action === 'need_comments').feedback, /Consulta pagada/);
});

test('stale parent/child, changed planned version, foreign and draft targets reject the entire batch', async () => {
  const f = await fixture(); await actor();
  await rejected(() => comment(f.id, 3, [planned(f)]), '40001');
  for (const bad of [planned(f, 'Cambio', 3), expenseComment(f, 'Cambio', 1),
    { ...expenseComment(f), target_id: f.draft }, { ...expenseComment(f), target_id: f.mixed },
    { ...planned(f), target_id: randomUUID() }]) {
    await rejected(() => comment(f.id, 4, bad.target_id === f.need ? [bad] : [planned(f), bad]), '40001');
  }
  await db.exec('reset role');
  assert.equal(await value("select count(*)::integer value from private.dopmi_rescue_history where record_id=$1 and action='need_comments'", [f.id]), 0);
});

test('input requires exact bounded typed entries and unique targets', async () => {
  const f = await fixture(); await actor();
  const valid = planned(f);
  const invalid = [null, {}, [], [null], [{ ...valid, extra: true }], [{ ...valid, body: ' \n\t ' }],
    [{ ...valid, body: 'x'.repeat(1001) }], [{ ...valid, target_id: 'no-uuid' }], [{ ...valid, target_kind: 'case' }],
    [{ ...valid, target_version: '4' }], [{ ...valid, target_version: 4.1 }], [{ ...valid, target_version: 2147483648 }],
    [{ ...valid, target_version: null }], [{ ...valid, body: null }], [valid, valid], Array(41).fill(valid),
    Array.from({ length: 21 }, () => ({ ...valid, target_id: randomUUID(), body: 'x'.repeat(1000) })),
    [{ ...valid, body: '\\'.repeat(100001) }]];
  for (const input of invalid) await rejected(() => comment(f.id, 4, input), '22023');
  await rejected(() => comment(f.id, 4, [valid], null), '22023');
});

test('same canonical request replays once even after review, while payload/actor/case/version collisions fail', async () => {
  const f = await fixture(), second = await fixture(), request = randomUUID(); await actor();
  const first = await comment(f.id, 4, [planned(f), expenseComment(f)], request);
  const replay = await comment(f.id, 4, [expenseComment(f), planned(f, '  Aclara el tratamiento\n')], request);
  assert.deepEqual(replay, first);
  await rejected(() => comment(f.id, 4, [planned(f, 'Otro mensaje'), expenseComment(f)], request), '22023');
  await rejected(() => comment(f.id, 5, [planned(f), expenseComment(f)], request), '22023');
  await rejected(() => comment(second.id, 4, [planned(second)], request), '22023');
  await actor(secondReviewer); await rejected(() => comment(f.id, 4, [planned(f), expenseComment(f)], request), '22023');
  await db.exec('reset role');
  await db.query("update public.dopmi_rescue_records set status='changes_requested',version=5 where id=$1", [f.id]);
  await actor(); assert.deepEqual(await comment(f.id, 4, [planned(f), expenseComment(f)], request), first);
  await rejected(() => comment(f.id, 5, [planned(f, 'Nueva revisión', 5)]), '22023');
  await db.exec('reset role');
  assert.equal(await value("select count(*)::integer value from private.dopmi_rescue_history where record_id=$1 and action='need_comments'", [f.id]), 1);
});

test('simultaneous client retries reconcile once on the serialized PGlite connection and cannot reuse read events', async () => {
  const f = await fixture(), request = randomUUID(); await actor();
  const responses = await Promise.all(Array.from({ length: 3 }, () => comment(f.id, 4, [planned(f)], request)));
  assert.deepEqual(responses[1], responses[0]); assert.deepEqual(responses[2], responses[0]);
  await packet(f.id); await db.exec('reset role');
  const audit = await value("select id value from private.dopmi_rescue_history where record_id=$1 and action='read' limit 1", [f.id]);
  assert.equal(await value("select count(*)::integer value from private.dopmi_rescue_history where id=$1", [request]), 1);
  await actor(); await rejected(() => comment(f.id, 4, [planned(f)], audit), '22023');
  // PGlite serializes queries in one connection; cross-session advisory-lock
  // contention remains a PostgreSQL CI check, not evidence claimed here.
});

test('replay still checks revoked membership and private case access before revealing a stored response', async () => {
  const f = await fixture(), request = randomUUID(); await actor(); await comment(f.id, 4, [planned(f)], request);
  await db.exec('reset role'); await db.query('update private.admin_memberships set active=false where user_id=$1', [reviewer]);
  await actor(); await rejected(() => comment(f.id, 4, [planned(f)], request), '42501');
  await db.exec('reset role'); await db.query('update private.admin_memberships set active=true where user_id=$1', [reviewer]);
  for (const status of ['draft', 'pending_stripe']) {
    await db.exec('reset role'); await db.query('update public.dopmi_rescue_records set status=$1,submitted_at=null where id=$2', [status, f.id]);
    await actor(); await rejected(() => packet(f.id), '42501'); await rejected(() => comment(f.id, 4, [planned(f)], request), '42501');
  }
});

test('planned target ID reuse preserves historical version and expense comments hide after withdrawal', async () => {
  const f = await fixture(); await actor(); const first = await comment(f.id, 4, [planned(f), expenseComment(f)]);
  await db.exec('reset role');
  await db.query("update public.dopmi_rescue_records set version=5,public_data=jsonb_set(public_data,'{need_items,0,title}','\"Nueva consulta\"') where id=$1", [f.id]);
  await db.query("update public.dopmi_rescue_records set status='draft',public_data=' {\"title\":\"NUEVO BORRADOR\"}' where id=$1", [f.expense]);
  await actor(); await rejected(() => comment(f.id, 5, [planned(f)]), '40001');
  const result = await packet(f.id);
  assert.equal(result.expenses.total, 0); assert.equal(result.need_comments.length, 1);
  assert.equal(result.need_comments[0].target_version, 4); assert.equal(result.need_comments[0].target_title, 'Consulta prevista');
  assert.equal(result.need_comments[0].id, first.comments.find(c => c.target_kind === 'planned').id);
  assert.doesNotMatch(JSON.stringify(result), /NUEVO BORRADOR/);
});

test('packet bounds individual comments to 100 across multi-comment history events', async () => {
  const f = await fixture();
  await db.query(`insert into private.dopmi_rescue_history(record_id,actor_id,action,version,snapshot,created_at)
    select $1,$2,'need_comments',4,jsonb_build_object('_need_comments',jsonb_build_array($3::jsonb,$3::jsonb)),
      now()+n*interval '1 second' from generate_series(1,60)n`,
  [f.id, reviewer, JSON.stringify({ ...planned(f), target_title: 'Consulta prevista' })]);
  await actor(); const result = await packet(f.id);
  assert.equal(result.need_comments.length, 100);
  assert.ok(result.need_comments.every(c => c.target_title === 'Consulta prevista'));
});
