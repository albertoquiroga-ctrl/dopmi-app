import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { setTimeout as pause } from 'node:timers/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';

// These tests use synthetic identities only. PostgreSQL races additionally require
// explicit opt-in to the disposable loopback stack and drop their own database.
const migration = '20261122222843_admin_report_context.sql';
const directory = new URL('../../supabase/migrations/', import.meta.url);
const staff = randomUUID(), peerStaff = randomUUID(), owner = randomUUID(), reporter = randomUUID(), other = randomUUID();
const legacyReport = randomUUID(), legacyPost = randomUUID();
const schema = `create schema auth; create schema storage;
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
 grant select,insert,update,delete on storage.objects to authenticated;`;
const signatures = [
 'public.dopmi_admin_report_detail(uuid)',
 'public.dopmi_admin_report_conversation(uuid,integer,uuid,timestamp with time zone,uuid)',
 'public.dopmi_admin_report_action(uuid,integer,text,text,uuid,integer,timestamp with time zone,uuid)',
];
let db, fixture, originalContracts;
const value = async (sql, args = []) => (await db.query(sql, args)).rows[0]?.value;
async function actor(id, role = 'authenticated') {
 await db.exec('reset role');
 await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
 await db.exec('set local role ' + role);
}
async function rejected(fn, code) {
 await db.exec('savepoint denied');
 try { await assert.rejects(fn, { code }); }
 finally { await db.exec('rollback to savepoint denied; release savepoint denied'); }
}
const detail = id => value('select public.dopmi_admin_report_detail($1) value', [id]);
const messages = (f, overrides = {}) => value('select public.dopmi_admin_report_conversation($1,$2,$3,$4,$5) value',
 [f.report, overrides.version ?? 1, overrides.thread ?? f.thread, overrides.before_time ?? null, overrides.before_id ?? null]);
const action = (f, kind, options = {}) => value('select public.dopmi_admin_report_action($1,$2,$3,$4,$5,$6,$7,$8) value',
 [f.report, options.version ?? 1, kind, options.reason ?? 'Motivo sintético suficiente', options.request ?? randomUUID(),
 options.target_version ?? null, options.account_updated_at ?? null, options.suspension ?? null]);

async function contracts() {
 return (await db.query(`select p.oid::regprocedure::text signature,p.proacl::text acl,p.proargnames,p.proargdefaults::text defaults
 from pg_proc p where p.oid=any(array['public.dopmi_admin_reports(text,integer,integer)'::regprocedure,
 'public.dopmi_admin_resolve_report(uuid,text,text)'::regprocedure,'public.dopmi_review_adoption(uuid,integer,text,text)'::regprocedure]) order by 1`)).rows;
}
async function identities(client) {
 for (const [id, name] of [[staff, 'Administradora sintética'], [peerStaff, 'Otra administradora'], [owner, 'Rescatista sintética'], [reporter, 'Reportante sintético'], [other, 'Tercero sintético']]) {
  await client.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)',
   [id, id + '@example.test', { display_name: name, is_admin: true }]);
 }
 await client.query('insert into private.admin_memberships(user_id) values($1),($2)', [staff, peerStaff]);
}
async function setup(client, { pglite = false, legacy = false } = {}) {
 if (pglite) await client.exec('create role anon; create role authenticated; create role service_role;');
 const execute = sql => pglite ? client.exec(sql) : client.query(sql);
 await execute(schema);
 const files = (await readdir(directory)).filter(f => f.endsWith('.sql') && f <= migration).sort();
 for (const file of files) {
  if (file === migration && legacy) {
   await identities(client);
   await client.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Legado','published')", [legacyPost, owner]);
   await client.query("insert into public.dopmi_content_reports(id,reporter_id,target_type,target_id,reason,created_at,updated_at) values($1,$2,'adoption',$3,'unsafe','2026-11-20T10:00:00Z','2026-11-21T11:00:00Z')", [legacyReport, reporter, legacyPost]);
   originalContracts = await contracts();
  }
  await execute(await readFile(new URL(file, directory), 'utf8'));
 }
 if (!legacy) await identities(client);
}
async function makeFixture(client = db, { subject = owner, type = 'adoption' } = {}) {
 const post = randomUUID(), report = randomUUID(), thread = randomUUID(), otherPost = randomUUID(), otherThread = randomUUID();
 const photo = `${subject}/${post}/${randomUUID()}.jpg`;
 await client.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,story,city,region,photos,status,published_at) values($1,$2,'Luna sintética','Historia pública','Monterrey','Nuevo León',$3,'published',clock_timestamp())", [post, subject, [photo]]);
 await client.query("insert into storage.objects(bucket_id,name) values('dopmi-adoption-photos',$1)", [photo]);
 await client.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Otro contexto','published')", [otherPost, subject]);
 await client.query("insert into public.dopmi_threads(id,post_id,owner_id,adopter_id,pet_name,created_at) values($1,$2,$3,$4,'Luna sintética',clock_timestamp()-interval '3 minutes'),($5,$6,$3,$4,'Otro contexto',clock_timestamp()-interval '3 minutes')", [thread, post, subject, reporter, otherThread, otherPost]);
 let target = post;
 if (type === 'rescuer') target = subject;
 if (type === 'case') {
  target = randomUUID();
  await client.query("insert into public.dopmi_rescue_records(id,owner_id,kind,status,public_data,approved_snapshot) values($1,$2,'case','approved','{}','{\"pet_name\":\"Caso sintético\",\"story\":\"Descripción aprobada\",\"photos\":[]}')", [target, subject]);
 }
 const hasCutoff = (await client.query("select exists(select 1 from information_schema.columns where table_schema='public' and table_name='dopmi_content_reports' and column_name='reported_at') value")).rows[0].value;
 await client.query(hasCutoff
  ? "insert into public.dopmi_content_reports(id,reporter_id,target_type,target_id,reason,details,created_at,reported_at) values($1,$2,$3,$4,'unsafe','Contexto enviado',clock_timestamp()-interval '1 minute',clock_timestamp()-interval '1 minute')"
  : "insert into public.dopmi_content_reports(id,reporter_id,target_type,target_id,reason,details,created_at) values($1,$2,$3,$4,'unsafe','Contexto enviado',clock_timestamp()-interval '1 minute')", [report, reporter, type, target]);
 await client.query("insert into public.dopmi_messages(id,thread_id,sender_id,body,created_at) values($1,$2,$3,'Texto anterior al reporte',clock_timestamp()-interval '2 minutes'),($4,$2,$5,'Texto posterior privado',clock_timestamp())", [randomUUID(), thread, reporter, randomUUID(), subject]);
 return { post, report, thread, otherThread, otherPost, target, subject, photo };
}

before(async () => { db = new PGlite(); await setup(db, { pglite: true, legacy: true }); }, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => { await db.exec('begin'); fixture = await makeFixture(); await actor(staff); });
afterEach(async () => db.exec('rollback'));

test('new report APIs exist with closed default ACLs and preserve legacy signatures', async () => {
 for (const signature of signatures) {
  assert.notEqual(await value('select to_regprocedure($1)::text value', [signature]), null, 'Missing report moderation RPC: ' + signature);
  for (const role of ['anon', 'service_role']) assert.equal(await value("select has_function_privilege($1,$2,'execute') value", [role, signature]), false);
  assert.equal(await value("select has_function_privilege('authenticated',$1,'execute') value", [signature]), true);
 }
 assert.deepEqual(await contracts(), originalContracts);
});

test('legacy report cutoff comes from persisted creation, not later resolution or migration time', async () => {
 const d = await detail(legacyReport);
 assert.equal(d.report.reported_at, '2026-11-20T10:00:00+00:00');
 assert.equal(d.report.cutoff_basis, 'legacy_created_at');
 assert.equal(d.report.version, 1);
 await value("select public.dopmi_admin_resolve_report($1,'reviewing','Nota previa') value", [legacyReport]);
 const changed = await detail(legacyReport);
 assert.equal(changed.report.version, 2);
 assert.equal(changed.report.reported_at, d.report.reported_at);
});

test('detail derives both people, current public content and one exact adoption thread without private fields', async () => {
 const d = await detail(fixture.report);
 assert.equal(d.report.target_type, 'adoption');
 assert.equal(d.reporter.id, reporter); assert.equal(d.subject.id, owner);
 assert.equal(d.content.id, fixture.post); assert.equal(d.content.title, 'Luna sintética');
 assert.deepEqual(d.content.public_photos, [fixture.photo]);
 assert.equal(d.content.current_snapshot, true);
 assert.equal(d.conversation.available, true);
 assert.deepEqual(d.conversation.threads.map(t => t.id), [fixture.thread]);
 assert.equal(d.conversation.threads[0].message_count_before_cutoff, 1);
 for (const forbidden of ['@example.test', 'phone', 'approximate_latitude', 'attachment_path', 'Texto posterior privado']) assert.equal(JSON.stringify(d).includes(forbidden), false);
 assert.equal(d.report.status, 'open'); assert.equal(d.history.length, 0);
 await db.exec('reset role');
 assert.equal(await value("select count(*)::int value from private.dopmi_report_reads where report_id=$1 and action='detail'", [fixture.report]), 1);
 assert.equal(await value('select count(*)::int value from private.dopmi_report_actions where report_id=$1', [fixture.report]), 0);
});

test('anonymous, ordinary, inactive and revoked administrators cannot read or act', async () => {
 for (const [id, role] of [[null, 'anon'], [other, 'authenticated']]) {
  await actor(id, role); await rejected(() => detail(fixture.report), '42501');
  await rejected(() => messages(fixture), '42501'); await rejected(() => action(fixture, 'reviewing'), '42501');
 }
 await db.exec('reset role'); await db.query("update public.profiles set account_status='suspended' where id=$1", [staff]);
 await actor(staff); await rejected(() => detail(fixture.report), '42501');
 await db.exec('reset role'); await db.query("update public.profiles set account_status='active' where id=$1", [staff]);
 await db.query('update private.admin_memberships set active=false where user_id=$1', [staff]);
 await actor(staff); await rejected(() => detail(fixture.report), '42501');
});

test('conversation is text-only, cutoff-bound and has no raw message or storage permission expansion', async () => {
 await db.exec('reset role');
 await db.query("insert into public.dopmi_messages(id,thread_id,sender_id,body,attachment_path,created_at) values($1,$2,$3,'',$4,clock_timestamp()-interval '2 minutes')", [randomUUID(), fixture.thread, owner, `${owner}/${fixture.thread}/${randomUUID()}.jpg`]);
 await actor(staff);
 const page = await messages(fixture);
 assert.equal(page.items.length, 2);
 assert.ok(page.items.some(x => x.has_attachment));
 assert.ok(page.items.every(x => ['reporter', 'subject'].includes(x.sender_role)));
 assert.equal(JSON.stringify(page).includes('attachment_path'), false);
 assert.equal(JSON.stringify(page).includes('Texto posterior privado'), false);
 assert.equal(await value('select count(*)::int value from public.dopmi_messages'), 0);
 assert.equal(await value('select public.dopmi_chat_photo_access($1) value', [`${owner}/${fixture.thread}/${randomUUID()}.jpg`]), false);
 await rejected(() => value('select public.dopmi_thread_messages($1) value', [fixture.thread]), '42501');
});

test('pagination is stable newest-first and neither skips tied timestamps nor crosses cutoff', async () => {
 await db.exec('reset role');
 const time = '2026-01-01T00:00:00Z';
 for (let i = 0; i < 44; i++) await db.query('insert into public.dopmi_messages(id,thread_id,sender_id,body,created_at) values($1,$2,$3,$4,$5)', [randomUUID(), fixture.thread, reporter, `Texto sintético ${i}`, time]);
 await actor(staff);
 const a = await messages(fixture); assert.equal(a.items.length, 40); assert.ok(a.next_cursor);
 const b = await messages(fixture, a.next_cursor); assert.equal(b.items.length, 5); assert.equal(b.next_cursor, null);
 assert.equal(new Set([...a.items, ...b.items].map(x => x.id)).size, 45);
 assert.ok(a.items.every(x => Date.parse(x.created_at) <= Date.parse(a.cutoff)));
});

test('wrong thread, wrong report type, stale version, partial cursor and missing report fail closed', async () => {
 await rejected(() => messages(fixture, { thread: fixture.otherThread }), '42501');
 await rejected(() => messages(fixture, { version: 2 }), '40001');
 await rejected(() => messages(fixture, { before_time: '2026-01-01T00:00:00Z' }), '22023');
 await rejected(() => detail(randomUUID()), '22023');
 await db.exec('reset role'); const f = await makeFixture(db, { type: 'case' }); await actor(staff);
 assert.equal((await detail(f.report)).conversation.available, false);
 await rejected(() => messages(f), '42501');
});

test('profile and case reports never enumerate chats and withdrawal explains the unsupported capability', async () => {
 for (const type of ['case', 'rescuer']) {
  await db.exec('reset role'); const f = await makeFixture(db, { type }); await actor(staff);
  const d = await detail(f.report);
  assert.equal(d.conversation.available, false); assert.deepEqual(d.conversation.threads, []);
  assert.equal(d.capabilities.withdraw_publication.allowed, false); assert.ok(d.capabilities.withdraw_publication.reason.length > 10);
  assert.equal(d.capabilities.suspend_account.allowed, true);
  await rejected(() => action(f, 'withdraw_publication', { target_version: 1 }), '22023');
 }
});

test('a future thread reveals neither metadata nor text through a report created before that contact', async () => {
 await db.exec('reset role'); await db.query('update public.dopmi_threads set created_at=clock_timestamp() where id=$1', [fixture.thread]);
 await actor(staff); const d = await detail(fixture.report);
 assert.equal(d.conversation.available, false); assert.deepEqual(d.conversation.threads, []);
 await rejected(() => messages(fixture), '42501');
});

test('only the originating report can offer or execute restoration of its suspension', async () => {
 await db.exec('reset role'); const otherReport = await makeFixture(); await actor(staff);
 let d = await detail(fixture.report);
 const suspended = await action(fixture, 'suspend_account', { account_updated_at: d.subject.account_updated_at });
 d = await detail(otherReport.report);
 assert.equal(d.capabilities.reactivate_account.allowed, false);
 assert.match(d.capabilities.reactivate_account.reason, /reporte que originó/i);
 await rejected(() => action(otherReport, 'reactivate_account', { account_updated_at: d.subject.account_updated_at, suspension: suspended.action_id }), '42501');
 const original = await detail(fixture.report); assert.equal(original.capabilities.reactivate_account.allowed, true);
});

test('a stale account timestamp cannot suspend an account or create an action receipt', async () => {
 await rejected(() => action(fixture, 'suspend_account', { account_updated_at: '2000-01-01T00:00:00Z' }), '40001');
 const d = await detail(fixture.report); assert.equal(d.subject.account_status, 'active'); assert.equal(d.report.version, 1);
 await db.exec('reset role'); assert.equal(await value('select count(*)::int value from private.dopmi_report_actions where report_id=$1', [fixture.report]), 0);
});

test('case public photos contain only approved string paths, never embedded document objects', async () => {
 await db.exec('reset role'); const f = await makeFixture(db, { type: 'case' });
 const approved = `${owner}/${f.target}/${randomUUID()}.jpg`;
 await db.query("update public.dopmi_rescue_records set approved_snapshot=approved_snapshot||jsonb_build_object('photos',$2::jsonb) where id=$1", [f.target, JSON.stringify([approved, 'documento-privado.pdf', { private_path: 'documento-privado.pdf' }])]);
 await actor(staff); const d = await detail(f.report); assert.deepEqual(d.content.public_photos, [approved]);
});

test('suspension and restoration preserve existing donation, Connect, case, worker and environment state', async () => {
 await db.exec('reset role');
 const caseId = randomUUID(), expenseId = randomUUID(), donationId = randomUUID();
 await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind) values($1,$2,'case')", [caseId, owner]);
 await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id) values($1,$2,'expense',$3)", [expenseId, owner, caseId]);
 await db.query("insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,reserved_cents) values($1,$2,$3,$4,'Gasto sintético','Caso sintético',$5,1000,20,980)", [donationId, reporter, owner, expenseId, randomUUID()]);
 await db.query("insert into private.dopmi_connect_accounts(owner_id,account_id) values($1,'acct_synthetic_report')", [owner]);
 const state = () => value(`select jsonb_build_object('donation',(select to_jsonb(d) from public.dopmi_donations d where id=$1),
  'connect',(select to_jsonb(c) from private.dopmi_connect_accounts c where owner_id=$2),
  'environment',(select to_jsonb(e) from private.dopmi_payment_environment e),
  'jobs',(select coalesce(jsonb_agg(to_jsonb(j) order by j.id),'[]') from private.dopmi_payment_jobs j),
  'case',(select to_jsonb(r) from public.dopmi_rescue_records r where id=$3)) value`, [donationId, owner, caseId]);
 const before = await state(); await actor(staff); let d = await detail(fixture.report);
 const receipt = await action(fixture, 'suspend_account', { account_updated_at: d.subject.account_updated_at });
 d = await detail(fixture.report);
 await action(fixture, 'reactivate_account', { version: 2, account_updated_at: d.subject.account_updated_at, suspension: receipt.action_id });
 await db.exec('reset role'); assert.deepEqual(await state(), before);
});

test('identical open retry preserves cutoff while changed/reopened report invalidates older pages', async () => {
 const d = await detail(fixture.report); await actor(reporter);
 assert.equal(await value("select public.dopmi_report_content('adoption',$1,'unsafe','Contexto enviado') value", [fixture.post]), fixture.report);
 await actor(staff); const same = await detail(fixture.report);
 assert.equal(same.report.version, d.report.version); assert.equal(same.report.reported_at, d.report.reported_at);
 await actor(reporter); await value("select public.dopmi_report_content('adoption',$1,'unsafe','Contexto actualizado') value", [fixture.post]);
 await actor(staff); const changed = await detail(fixture.report);
 assert.equal(changed.report.version, 2); assert.equal(changed.report.cutoff_basis, 'reported_at');
 assert.ok(Date.parse(changed.report.reported_at) > Date.parse(d.report.reported_at));
 await rejected(() => messages(fixture), '40001');
});

test('report actions require reason and current report/target versions with zero effects on failure', async () => {
 await rejected(() => action(fixture, 'reviewing', { reason: 'no' }), '22023');
 await rejected(() => action(fixture, 'reviewing', { version: 2 }), '40001');
 await rejected(() => action(fixture, 'withdraw_publication', { target_version: 9 }), '40001');
 const d = await detail(fixture.report); assert.equal(d.report.status, 'open'); assert.equal(d.content.status, 'published');
 await db.exec('reset role'); assert.equal(await value('select count(*)::int value from private.dopmi_report_actions where report_id=$1', [fixture.report]), 0);
});

test('withdrawal archives the existing approved adoption and records existing review/notification without resolving report', async () => {
 const result = await action(fixture, 'withdraw_publication', { target_version: 1 });
 assert.equal(result.report_version, 2); assert.equal(result.replayed, false); assert.equal(result.target_state.status, 'archived');
 const d = await detail(fixture.report); assert.equal(d.content, null); assert.equal(d.report.status, 'open');
 assert.equal(d.capabilities.withdraw_publication.allowed, false); assert.equal(d.history.length, 1);
 await db.exec('reset role');
 assert.equal(await value("select count(*)::int value from private.dopmi_adoption_reviews where post_id=$1 and decision='archived'", [fixture.post]), 1);
 assert.equal(await value("select count(*)::int value from public.dopmi_notifications where post_id=$1 and title='Tu publicación fue retirada'", [fixture.post]), 1);
});

test('a suspended owner can still have the reported publication withdrawn; reactivation does not republish it', async () => {
 let d = await detail(fixture.report);
 const suspended = await action(fixture, 'suspend_account', { account_updated_at: d.subject.account_updated_at });
 d = await detail(fixture.report); assert.equal(d.subject.account_status, 'suspended'); assert.equal(d.report.status, 'open');
 assert.equal(d.subject.active_suspension_action_id, suspended.action_id);
 await action(fixture, 'withdraw_publication', { version: 2, target_version: 1 });
 d = await detail(fixture.report);
 await action(fixture, 'reactivate_account', { version: 3, account_updated_at: d.subject.account_updated_at, suspension: suspended.action_id });
 d = await detail(fixture.report); assert.equal(d.subject.account_status, 'active'); assert.equal(d.content, null);
 assert.equal(d.history[0].next_state.target.status, 'archived');
 assert.equal(d.subject.active_suspension_action_id, null); assert.equal(d.capabilities.reactivate_account.allowed, false);
});

test('suspension cannot target self, another admin, unavailable or already suspended accounts', async () => {
 for (const target of [staff, peerStaff]) {
  await db.exec('reset role'); const f = await makeFixture(db, { subject: target }); await actor(staff);
  const d = await detail(f.report); assert.equal(d.capabilities.suspend_account.allowed, false);
  await rejected(() => action(f, 'suspend_account', { account_updated_at: d.subject.account_updated_at }), '42501');
 }
 for (const state of ['suspended', 'deletion_requested', 'deleted']) {
  await db.exec('reset role'); await db.query('update public.profiles set account_status=$2 where id=$1', [owner, state]); await actor(staff);
  const d = await detail(fixture.report); assert.equal(d.capabilities.suspend_account.allowed, false);
  await rejected(() => action(fixture, 'suspend_account', { account_updated_at: d.subject?.account_updated_at }), '42501');
 }
});

test('reactivation requires this flow, current suspension action and unchanged account even after external profile updates', async () => {
 let d = await detail(fixture.report);
 await action(fixture, 'suspend_account', { account_updated_at: d.subject.account_updated_at });
 d = await detail(fixture.report);
 await rejected(() => action(fixture, 'reactivate_account', { version: 2, account_updated_at: d.subject.account_updated_at, suspension: randomUUID() }), '40001');
 await db.exec('reset role'); await db.query("update public.profiles set city='Cambio externo' where id=$1", [owner]); await actor(staff);
 const updated = await detail(fixture.report); assert.equal(updated.capabilities.reactivate_account.allowed, false);
 await rejected(() => action(fixture, 'reactivate_account', { version: 2, account_updated_at: updated.subject.account_updated_at, suspension: d.subject.active_suspension_action_id }), '42501');
});

test('action UUID replay returns original receipt, changed payload or actor is denied and no duplicate sanction is produced', async () => {
 const request = randomUUID(), args = { request, target_version: 1 };
 const first = await action(fixture, 'withdraw_publication', args);
 const replay = await action(fixture, 'withdraw_publication', args);
 assert.deepEqual({ ...replay, replayed: false }, first);
 await rejected(() => action(fixture, 'withdraw_publication', { ...args, reason: 'Otro motivo suficiente' }), '22023');
 await actor(peerStaff); await rejected(() => action(fixture, 'withdraw_publication', args), '42501');
 await db.exec('reset role'); assert.equal(await value('select count(*)::int value from private.dopmi_report_actions where request_id=$1', [request]), 1);
});

test('resolved reports retain the same readable cutoff and actions do not silently close unrelated reports', async () => {
 const before = await detail(fixture.report);
 await action(fixture, 'resolve'); const after = await detail(fixture.report);
 assert.equal(after.report.status, 'resolved'); assert.equal(after.report.reported_at, before.report.reported_at);
 assert.equal((await messages(fixture, { version: 2 })).items.length, 1);
});

test('missing/private target does not expose a draft or enable a sanction on an unrelated account', async () => {
 await db.exec('reset role');
 await db.query("update public.dopmi_adoptions set status='draft',story='Borrador privado no aprobado' where id=$1", [fixture.post]);
 await actor(staff); const draft = await detail(fixture.report);
 assert.equal(draft.content, null); assert.equal(JSON.stringify(draft).includes('Borrador privado no aprobado'), false);
 await db.exec('reset role'); await db.query('delete from public.dopmi_adoptions where id=$1', [fixture.post]); await actor(staff);
 const gone = await detail(fixture.report); assert.equal(gone.subject, null); assert.equal(gone.content, null);
 assert.equal(gone.capabilities.suspend_account.allowed, false);
});

test('archive then private draft edit and rearchive never exposes unapproved text or photos through an old report', async () => {
 await value("select public.dopmi_review_adoption($1,1,'archived','Retiro sintético') value", [fixture.post]);
 await actor(owner);
 await value('select public.accept_current_terms() value');
 const privatePhoto = `${owner}/${fixture.post}/${randomUUID()}.jpg`;
 const saved = await value('select public.dopmi_save_adoption($1,$2,2) value', [{ pet_name: 'Nombre privado no aprobado', story: 'Historia privada sin revisión', city: 'Ciudad', region: 'Estado', photos: [privatePhoto] }, fixture.post]);
 assert.equal(saved.status, 'draft');
 await value("select public.dopmi_transition_adoption($1,3,'archive') value", [fixture.post]);
 await actor(staff); const d = await detail(fixture.report);
 assert.equal(d.content, null);
 assert.equal(JSON.stringify(d).includes('Historia privada sin revisión'), false);
 assert.equal(JSON.stringify(d).includes(privatePhoto), false);
});

test('moderation audit survives reporter report deletion; private new state remains RPC-only', async () => {
 await action(fixture, 'dismiss'); await db.exec('reset role');
 await db.query('delete from public.dopmi_content_reports where id=$1', [fixture.report]);
 assert.equal(await value('select count(*)::int value from private.dopmi_report_actions where report_id=$1', [fixture.report]), 1);
 await actor(other);
 for (const table of ['dopmi_report_actions', 'dopmi_report_reads', 'dopmi_report_suspensions']) await rejected(() => db.query('select * from private.' + table), '42501');
});

test('real PostgreSQL: concurrent report versions, UUID retry and two-report suspension serialize once', {
 skip: process.env.DOPMI_REPORT_CONTEXT_POSTGRES_TEST !== 'true', timeout: 120000,
}, async () => {
 assert.equal(process.env.PGPASSWORD, 'postgres', 'Only disposable loopback PostgreSQL is supported');
 const config = { host: '127.0.0.1', port: 54322, user: 'postgres', password: 'postgres', database: 'postgres', ssl: false,
  connectionTimeoutMillis: 5000, options: '-c statement_timeout=20000 -c lock_timeout=15000' };
 const database = 'dopmi_report_context_' + randomUUID().replaceAll('-', '');
 const admin = new pg.Client(config), control = new pg.Client({ ...config, database }), first = new pg.Client({ ...config, database }), second = new pg.Client({ ...config, database });
 const connected = []; let created = false, pending;
 const current = async (c, sql, args = []) => (await c.query(sql, args)).rows[0]?.value;
 async function as(c, who = staff) { await c.query('begin'); await c.query("select set_config('request.jwt.claim.sub',$1,true)", [who]); await c.query('set local role authenticated'); }
 const perform = (c, f, kind, { version = 1, request = randomUUID(), stamp = null } = {}) => current(c,
  "select public.dopmi_admin_report_action($1,$2,$3,'Motivo de concurrencia',$4,null,$5,null) value", [f.report, version, kind, request, stamp]);
 async function blocked(waiter, blocker) {
  const deadline = Date.now() + 10000;
  while (Date.now() < deadline) {
   if (await current(control, 'select $2::int=any(pg_blocking_pids($1::int)) value', [waiter.processID, blocker.processID])) return;
   await pause(25);
  }
  assert.fail('Expected overlapping lock not observed');
 }
 try {
  await admin.connect(); assert.equal(admin.connectionParameters.host, '127.0.0.1');
  await admin.query(`create database "${database}" template template0`); created = true;
  for (const c of [control, first, second]) { await c.connect(); connected.push(c); }
  await setup(control);
  let f = await makeFixture(control);
  await as(first); await perform(first, f, 'reviewing'); await as(second);
  pending = perform(second, f, 'dismiss'); pending.catch(() => {});
  await blocked(second, first); await first.query('commit'); await assert.rejects(pending, { code: '40001' }); pending = undefined; await second.query('rollback');
  assert.equal(await current(control, 'select count(*)::int value from private.dopmi_report_actions where report_id=$1', [f.report]), 1);
  f = await makeFixture(control); const request = randomUUID();
  await as(first); const a = await perform(first, f, 'resolve', { request }); await as(second);
  pending = perform(second, f, 'resolve', { request }); pending.catch(() => {});
  await blocked(second, first); await first.query('commit'); const b = await pending; pending = undefined; await second.query('commit');
  assert.equal(a.action_id, b.action_id); assert.equal(b.replayed, true);
  const left = await makeFixture(control), right = await makeFixture(control);
  const stamp = await current(control, 'select updated_at::text value from public.profiles where id=$1', [owner]);
  await as(first); await perform(first, left, 'suspend_account', { stamp }); await as(second);
  pending = perform(second, right, 'suspend_account', { stamp }); pending.catch(() => {});
  await blocked(second, first); await first.query('commit'); await assert.rejects(pending, error => ['42501', '40001'].includes(error.code)); pending = undefined; await second.query('rollback');
  assert.equal(await current(control, "select count(*)::int value from private.dopmi_report_actions where action='suspend_account' and subject_id=$1", [owner]), 1);
 } finally {
  for (const c of connected) await c.query('rollback').catch(() => {});
  if (pending) await pending.catch(() => {});
  for (const c of connected) await c.end();
  if (created) await admin.query(`drop database "${database}"`);
  await admin.end();
 }
});
