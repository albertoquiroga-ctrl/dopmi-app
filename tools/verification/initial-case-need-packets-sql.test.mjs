import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

// Disposable PostgreSQL/WASM only. No Auth service, provider or remote connection.
const migration = '20261102172057_initial_case_need_packets.sql';
const owner = randomUUID(), reviewer = randomUUID(), other = randomUUID();
let db, priorOids;
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
const transition = (id, version = 1, action = 'submit') => value(
  'select public.dopmi_transition_rescue($1,$2,$3) value', [id, version, action]);
const packet = (id, page = 1) => value('select public.dopmi_admin_rescue_packet($1,$2) value', [id, page]);
const decide = (f, reviews = f.reviews, request = randomUUID(), decision = 'approved', version = f.version) => value(
  'select public.dopmi_review_initial_case_packet($1,$2,$3,$4,$5,true,$6::jsonb,$7) value',
  [f.id, version, f.submission, decision, 'Revisión sintética completa', JSON.stringify(reviews), request]);
async function draft(kind = 'case', parent = null, who = owner) {
  const id = randomUUID();
  const publicData = kind === 'case'
    ? { pet_name: 'Caso sintético', species: 'dog', sex: 'female', age: '2 años', story: 'Rescate sintético para pruebas locales', city: 'Monterrey', state: 'Nuevo León', need_items: [] }
    : { title: 'Medicamento pagado', description: 'Gasto sintético ya pagado', category: 'medicine' };
  const privateData = kind === 'case' ? {} : { paid_on: '2026-09-01', vendor: 'Proveedor sintético', amount_cents: '10000', receipt_reference: id };
  const files = (kind === 'case' ? ['public'] : ['receipt', 'proof']).map(role => ({ role, path: `${who}/${id}/${randomUUID()}.${role === 'receipt' ? 'pdf' : 'jpg'}` }));
  await db.exec('reset role');
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,public_data,private_data,files,video_thanks_required)
    values($1,$2,$3,$4,$5::jsonb,$6::jsonb,$7::jsonb,false)`, [id, who, kind, parent, JSON.stringify(publicData), JSON.stringify(privateData), JSON.stringify(files)]);
  for (const file of files) await db.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)", [file.path]);
  return { id, files, publicData, privateData };
}
async function ready() {
  await db.exec('reset role');
  await db.query(`insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
    values($1,'acct_initial_packet_synthetic',true,true) on conflict(owner_id) do update set transfers_enabled=true,payouts_enabled=true`, [owner]);
}
async function fixture(count = 2, stripeReady = true) {
  const f = await draft(); f.children = [];
  for (let i = 0; i < count; i++) f.children.push(await draft('expense', f.id));
  if (stripeReady) await ready();
  await actor(owner); const submitted = await transition(f.id); f.version = submitted.version;
  await db.exec('reset role');
  f.submission = await value('select id value from private.dopmi_case_need_submissions where case_id=$1', [f.id]);
  f.reviews = f.children.map(c => ({ expense_id: c.id, expense_version: 1, amount_cents: 10000, is_urgent: false, urgency_note: '', publish_content: true }));
  await actor(); return f;
}
async function inventory(f) {
  await db.exec('reset role');
  return (await db.query(`select to_jsonb(r) value from public.dopmi_rescue_records r
    where id=$1 or parent_id=$1 order by id`, [f.id])).rows;
}
async function oids() {
  return (await db.query(`select p.proname,p.oid::text value from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=any($1::text[]) order by p.proname`, [[
    'dopmi_transition_rescue', 'dopmi_review_rescue', 'dopmi_admin_rescue_packet', 'dopmi_rescue_file_access',
  ]])).rows;
}
before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.identities(user_id uuid,provider text,provider_id text);
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(directory)).filter(f => f.endsWith('.sql')).sort()) {
    if (file === migration) priorOids = await oids();
    try { await db.exec(await readFile(new URL(file, directory), 'utf8')); }
    catch (error) { throw new Error(`Migration ${file}: ${error.code}: ${error.message}`); }
  }
  for (const id of [owner, reviewer, other]) await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    values($1,$2,now(),'{"display_name":"Nombre privado","is_admin":true,"terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}')`, [id, `${id}@example.test`]);
  await db.query('insert into private.admin_memberships(user_id) values($1)', [reviewer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('public function OIDs remain bound to policies and private manifests have no client/server-role ACL', async () => {
  assert.deepEqual(await oids(), priorOids);
  for (const table of ['dopmi_case_need_submissions', 'dopmi_case_need_submission_expenses']) {
    assert.equal(await value(`select relrowsecurity value from pg_class where oid=$1::regclass`, [`private.${table}`]), true);
    for (const role of ['anon', 'authenticated', 'service_role']) {
      assert.equal(await value("select has_table_privilege($1,$2,'select,insert,update,delete') value", [role, `private.${table}`]), false);
    }
  }
  for (const name of ['dopmi_transition_rescue_before_initial_packet(uuid,integer,text)', 'dopmi_rescue_file_access_before_initial_packet(text,boolean)',
    'dopmi_admin_rescue_packet_before_initial_packet(uuid,integer)', 'dopmi_review_rescue_before_initial_packet(uuid,integer,text,text,bigint,boolean,text,boolean)']) {
    for (const role of ['anon', 'authenticated', 'service_role']) assert.equal(await value("select has_function_privilege($1,$2,'execute') value", [role, `public.${name}`]), false);
  }
});

test('explicit submission shares every exact draft; later drafts and foreign-owner children stay private', async () => {
  const f = await fixture(21);
  const late = await draft('expense', f.id); const foreign = await draft('expense', f.id, other);
  await actor();
  const one = await packet(f.id), two = await packet(f.id, 2);
  const ids = f.children.map(c => c.id).sort();
  assert.equal(one.expenses.total, 21); assert.equal(one.expenses.items.length, 20); assert.equal(two.expenses.items.length, 1);
  assert.deepEqual(one.initial_packet, { id: f.submission, case_version: 2, source_case_version: 2, expense_ids: ids });
  assert.deepEqual([...one.expenses.items, ...two.expenses.items].map(e => e.id), ids);
  assert.ok(one.expenses.items.every(e => e.status === 'draft' && e.version === 1 && e.submission_id === f.submission));
  for (const hidden of [late, foreign]) {
    assert.doesNotMatch(JSON.stringify(one), new RegExp(hidden.id));
    assert.equal(await value('select public.dopmi_rescue_file_access($1) value', [hidden.files[0].path]), false);
  }
  assert.equal(await value('select public.dopmi_rescue_file_access($1) value', [f.children[0].files[0].path]), true);
  await rejected(() => value('select public.dopmi_rescue_detail($1) value', [f.children[0].id]), '42501');
});

test('real Storage RLS pins shared paths against deletion/reinsertion and freezes only captured children', async () => {
  const f = await fixture(1), child = f.children[0], path = child.files[0].path;
  const late = await draft('expense', f.id);
  await actor(owner);
  assert.equal((await db.query('delete from storage.objects where name=$1 returning name', [path])).rows.length, 0);
  await rejected(() => db.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)", [path]), '42501');
  assert.equal((await db.query("update storage.objects set metadata='{}' where name=$1 returning name", [path])).rows.length, 0);
  await rejected(() => value('select public.dopmi_save_rescue($1,$2::jsonb,$3::jsonb,$4::jsonb,$5,1,$6) value',
    ['expense', JSON.stringify({ ...child.publicData, title: 'Cambio privado' }), JSON.stringify(child.privateData), JSON.stringify(child.files), child.id, f.id]), '22023');
  await rejected(() => value('select public.dopmi_save_rescue($1,$2::jsonb,$3::jsonb,$4::jsonb,$5,1,$6) value',
    ['expense', JSON.stringify(child.publicData), JSON.stringify(child.privateData), JSON.stringify(child.files), child.id, f.id]), '22023');
  await rejected(() => value('select public.dopmi_save_rescue($1,$2::jsonb,$3::jsonb,$4::jsonb,$5,1,$6) value',
    ['expense', JSON.stringify({ ...late.publicData, title: 'Borrador posterior' }), JSON.stringify(late.privateData), JSON.stringify(late.files), late.id, f.id]), '22023');
  await transition(f.id, f.version, 'withdraw');
  assert.equal((await db.query('delete from storage.objects where name=$1 returning name', [path])).rows.length, 1);
  await actor(); await rejected(() => packet(f.id), '42501');
});

test('pending Stripe keeps manifest private and promotes exactly its original membership and versions', async () => {
  const f = await fixture(1, false), late = await draft('expense', f.id);
  await actor(); await rejected(() => packet(f.id), '42501');
  assert.equal(await value('select public.dopmi_rescue_file_access($1) value', [f.children[0].files[0].path]), false);
  await actor(owner, 'service_role');
  await value("select public.dopmi_payment_server('connect_get',$1::jsonb) value", [JSON.stringify({ actor: owner })]);
  await value("select public.dopmi_payment_server('connect_save',$1::jsonb) value", [JSON.stringify({ actor: owner, account_id: 'acct_initial_packet_synthetic', transfers_enabled: true, payouts_enabled: true, details_submitted: true })]);
  await actor(); const result = await packet(f.id);
  assert.equal(result.initial_packet.id, f.submission); assert.equal(result.initial_packet.source_case_version, 2);
  assert.equal(result.initial_packet.case_version, 3); assert.deepEqual(result.initial_packet.expense_ids, [f.children[0].id]);
  assert.doesNotMatch(JSON.stringify(result), new RegExp(late.id));
});

test('comments target frozen expense versions and legacy APIs cannot split the initial decision', async () => {
  const f = await fixture(1), child = f.children[0], request = randomUUID();
  const comments = [{ target_kind: 'expense', target_id: child.id, target_version: 1, body: 'Aclara este comprobante' }];
  const result = await value('select public.dopmi_comment_case_needs($1,$2,$3::jsonb,$4) value', [f.id, f.version, JSON.stringify(comments), request]);
  assert.equal(result.comments[0].target_title, child.publicData.title);
  assert.equal((await packet(f.id)).need_comments[0].id, result.comments[0].id);
  for (const id of [f.id, child.id]) await rejected(() => value("select public.dopmi_review_rescue($1,$2,'approved','Revisión completa',7000,false,'',true) value", [id, id === f.id ? f.version : 1]), '22023');
  const late = await draft('expense', f.id); await actor();
  await rejected(() => value('select public.dopmi_comment_case_needs($1,$2,$3::jsonb,$4) value', [f.id, f.version, JSON.stringify([{ ...comments[0], target_id: late.id }]), randomUUID()]), '40001');
});

test('one explicit financial review atomically approves case and exact children; canonical replay writes nothing', async () => {
  const f = await fixture(), request = randomUUID();
  const result = await decide(f, f.reviews, request);
  assert.equal(result.record.status, 'approved'); assert.equal(result.expenses.length, 2);
  assert.ok(result.expenses.every(e => e.status === 'approved' && e.reimbursable_cents === 10000 && e.urgent === false && e.version === 3));
  const before = await inventory(f); await actor();
  assert.deepEqual(await decide(f, [...f.reviews].reverse(), request), result);
  assert.deepEqual(await inventory(f), before); await actor();
  await rejected(() => decide(f, [{ ...f.reviews[0], amount_cents: 8000 }, f.reviews[1]], request), '22023');
  await db.exec('reset role');
  assert.equal(await value("select count(*)::int value from private.dopmi_rescue_history where record_id=$1 and action='approved'", [f.id]), 1);
  assert.equal(await value("select count(*)::int value from private.dopmi_rescue_history where record_id=any($1::uuid[]) and action='initial_packet_submit' and actor_id=$2 and actor_type='user'", [f.children.map(c => c.id), reviewer]), 2);
  // New needs require a new case; this remains closed after first publication.
  await rejected(() => draft('expense', f.id), '22023');
});

test('missing/extra/stale/malformed choices and a failure on the last child roll back every approval', async () => {
  const f = await fixture(), before = await inventory(f); await actor();
  for (const [reviews, code] of [[f.reviews.slice(0, 1), '40001'], [[...f.reviews, { ...f.reviews[0], expense_id: randomUUID() }], '40001'],
    [[{ ...f.reviews[0], expense_version: 2 }, f.reviews[1]], '40001'], [[{ ...f.reviews[0], amount_cents: 0 }, f.reviews[1]], '22023'],
    [[{ ...f.reviews[0], is_urgent: true, urgency_note: '' }, f.reviews[1]], '22023'],
    [[f.reviews[0], { ...f.reviews[1], amount_cents: 10001 }], '22023'], [[{ ...f.reviews[0], publish_content: false }, f.reviews[1]], '22023'],
    [[f.reviews[0], f.reviews[0]], '22023']]) await rejected(() => decide(f, reviews), code);
  await rejected(() => decide(f, f.reviews, randomUUID(), 'approved', f.version - 1), '40001');
  assert.deepEqual(await inventory(f), before);
  await db.exec('reset role');
  assert.equal(await value('select count(*)::int value from private.dopmi_case_need_submissions where case_id=$1 and decision_request_id is not null', [f.id]), 0);
});

test('duplicate sibling receipts fail together and existing financial guards remain active', async () => {
  const a = await draft(), first = await draft('expense', a.id), second = await draft('expense', a.id);
  await db.query('update public.dopmi_rescue_records set private_data=$1::jsonb where id=$2', [JSON.stringify(first.privateData), second.id]);
  await ready(); await actor(owner); await transition(a.id); await actor();
  const p = await packet(a.id), f = { id: a.id, version: 2, submission: p.initial_packet.id,
    reviews: [first, second].map(e => ({ expense_id: e.id, expense_version: 1, amount_cents: 1000, is_urgent: false, urgency_note: '', publish_content: true })) };
  await rejected(() => decide(f), '22023');
  await db.exec('reset role'); assert.equal(await value('select status value from public.dopmi_rescue_records where id=$1', [a.id]), 'submitted');
  assert.match(await value("select pg_get_functiondef('private.dopmi_guard_funded_expense()'::regprocedure) value"), /dopmi_donations/);
});

test('authorization is checked before replay; self review, revoked membership and inactive owners fail', async () => {
  const f = await fixture(1), request = randomUUID();
  for (const id of [owner, other]) { await actor(id); await rejected(() => decide(f), '42501'); }
  await db.exec('reset role'); await db.query('insert into private.admin_memberships(user_id) values($1)', [owner]);
  await actor(owner); await rejected(() => decide(f), '42501');
  await db.exec('reset role'); await db.query("update public.profiles set account_status='suspended' where id=$1", [owner]);
  await actor(); await rejected(() => decide(f), '22023');
  await db.exec('reset role'); await db.query("update public.profiles set account_status='active' where id=$1", [owner]);
  await db.query('update auth.users set email_confirmed_at=null where id=$1', [owner]);
  await actor(); await rejected(() => decide(f), '22023');
  await db.exec('reset role'); await db.query('update auth.users set email_confirmed_at=now() where id=$1', [owner]);
  await actor(); await decide(f, f.reviews, request);
  await db.exec('reset role'); await db.query('update private.admin_memberships set active=false where user_id=$1', [reviewer]);
  await actor(); await rejected(() => decide(f, f.reviews, request), '42501');
  for (const role of ['anon', 'service_role']) { await actor(null, role); await rejected(() => decide(f, f.reviews, request), '42501'); }
});

test('correction releases pins, resubmit captures new content/membership, and no historical manifest is inferred', async () => {
  const f = await fixture(1), path = f.children[0].files[0].path;
  await decide(f, [], randomUUID(), 'changes_requested');
  assert.equal((await packet(f.id)).initial_packet, null);
  assert.equal((await packet(f.id)).expenses.total, 0);
  assert.equal(await value('select public.dopmi_rescue_file_access($1) value', [path]), false);
  await actor(owner); assert.equal((await db.query('delete from storage.objects where name=$1 returning name', [path])).rows.length, 1);
  await db.exec('reset role'); await db.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)", [path]);
  const late = await draft('expense', f.id); await actor(owner); const submitted = await transition(f.id, 3); await actor();
  const next = await packet(f.id);
  assert.notEqual(next.initial_packet.id, f.submission); assert.equal(next.initial_packet.case_version, submitted.version);
  assert.deepEqual(next.initial_packet.expense_ids, [f.children[0].id, late.id].sort());
  const historical = await draft(); await db.query("update public.dopmi_rescue_records set status='submitted',version=2 where id=$1", [historical.id]);
  await actor(); assert.equal((await packet(historical.id)).initial_packet, null);
  assert.equal((await value("select public.dopmi_review_rescue($1,2,'approved','Caso histórico revisado',0,false,'',true) value", [historical.id])).status, 'approved');
});

test('empty initial manifest preserves safe legacy approval while the joint API also supports no expenses', async () => {
  const empty = await fixture(0);
  assert.deepEqual((await packet(empty.id)).initial_packet.expense_ids, []);
  assert.equal((await value("select public.dopmi_review_rescue($1,2,'approved','Caso sin gastos revisado',0,false,'',true) value", [empty.id])).status, 'approved');
  const another = await fixture(0); assert.equal((await decide(another, [])).record.status, 'approved');
});

test('incomplete expense prevents the submission atomically with its title and the existing validation error', async () => {
  const f = await draft(), expense = await draft('expense', f.id);
  await db.query("update public.dopmi_rescue_records set private_data=private_data-'paid_on' where id=$1", [expense.id]);
  await ready(); await actor(owner);
  await db.exec('savepoint incomplete');
  await assert.rejects(() => transition(f.id), error => error.code === '22023' && /Medicamento pagado/.test(error.message) && /fecha válida/.test(error.message));
  await db.exec('rollback to savepoint incomplete'); await db.exec('reset role');
  assert.equal(await value('select status value from public.dopmi_rescue_records where id=$1', [f.id]), 'draft');
  assert.equal(await value('select count(*)::int value from private.dopmi_case_need_submissions where case_id=$1', [f.id]), 0);
  assert.equal(await value("select count(*)::int value from private.dopmi_rescue_history where record_id=$1 and action='submit'", [f.id]), 0);
});

test('missing evidence and a funded source hit established validators/triggers and roll back the parent', async () => {
  const f = await fixture(1); await db.exec('reset role');
  await db.query('delete from storage.objects where name=$1', [f.children[0].files[0].path]);
  await actor(); await rejected(() => decide(f), '22023');
  await db.exec('reset role');
  assert.equal(await value('select status value from public.dopmi_rescue_records where id=$1', [f.id]), 'submitted');
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)", [f.children[0].files[0].path]);
  await db.query(`insert into public.dopmi_donations(donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,
    gross_cents,platform_fee_cents,reserved_cents,allocated_cents)
    values($1,$2,$3,'Sintético','Prueba local',$4,1000,0,0,100)`, [other, owner, f.children[0].id, randomUUID()]);
  await actor(); await rejected(() => decide(f), '22023');
  await db.exec('reset role');
  assert.equal(await value('select status value from public.dopmi_rescue_records where id=$1', [f.id]), 'submitted');
  assert.equal(await value('select status value from public.dopmi_rescue_records where id=$1', [f.children[0].id]), 'draft');
});

test('rejection grants no financial state, and a request UUID cannot cross actor, case or payload', async () => {
  const f = await fixture(1), request = randomUUID();
  const rejection = await decide(f, [], request, 'rejected');
  assert.equal(rejection.record.status, 'rejected'); assert.deepEqual(rejection.expenses, []);
  assert.deepEqual(await decide(f, [], request, 'rejected'), rejection);
  await db.exec('reset role');
  assert.equal(await value('select reimbursable_cents::int value from public.dopmi_rescue_records where id=$1', [f.children[0].id]), 0);
  await db.query('insert into private.admin_memberships(user_id) values($1)', [other]);
  await actor(other); await rejected(() => decide(f, [], request, 'rejected'), '22023');
  const another = await fixture(1); await rejected(() => decide(another, another.reviews, request), '22023');
  await rejected(() => decide(f, [], request, 'changes_requested'), '22023');
});

test('unversioned source tampering cannot approve a different parent or child snapshot', async () => {
  const f = await fixture(1); await db.exec('reset role');
  await db.query("update public.dopmi_rescue_records set public_data=public_data||'{\"story\":\"Cambio privilegiado sin versión\"}' where id=$1", [f.id]);
  await actor(); await rejected(() => decide(f), '40001');
  await db.exec('reset role');
  await db.query('update public.dopmi_rescue_records set public_data=$1::jsonb where id=$2', [JSON.stringify(f.publicData), f.id]);
  // Even a status/version-only save cannot replace the captured source version.
  await rejected(() => db.query('update public.dopmi_rescue_records set version=version+1 where id=$1', [f.children[0].id]), '22023');
});

test('owner cannot remove an unread captured draft while submitted or pending Stripe; withdrawal permits removal and retains historical JSON', async () => {
  for (const stripeReady of [false, true]) {
    const f = await fixture(1, stripeReady), child = f.children[0];
    await actor(owner);
    await rejected(() => value('select public.dopmi_remove_draft_expense($1,1) value', [child.id]), '22023');
    await db.exec('reset role');
    assert.equal(await value('select count(*)::int value from private.dopmi_case_need_submission_expenses where submission_id=$1', [f.submission]), 1);
    await actor(owner); await transition(f.id, f.version, 'withdraw');
    await value('select public.dopmi_remove_draft_expense($1,1) value', [child.id]);
    await db.exec('reset role');
    assert.equal(await value('select count(*)::int value from public.dopmi_rescue_records where id=$1', [child.id]), 0);
    assert.equal(await value('select count(*)::int value from private.dopmi_case_need_submission_expenses where submission_id=$1 and expense_id=$2', [f.submission, child.id]), 1);
  }
});
