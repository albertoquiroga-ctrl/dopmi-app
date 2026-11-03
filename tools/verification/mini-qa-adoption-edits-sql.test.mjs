import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

// Complete migration prefix in disposable PostgreSQL/WASM. No remote services,
// users, financial commands or provider requests are involved.
const migration = '20261103024404_mini_qa_adoption_edits.sql';
const owner = randomUUID(), reviewer = randomUUID(), other = randomUUID();
const sessions = new Map();
let db, previousFunctions, previousFinalize;
const value = async (sql, args = []) => (await db.query(sql, args)).rows[0]?.value;
async function actor(id = owner, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
  await db.query("select set_config('request.jwt.claim.session_id',$1,true)", [sessions.get(id) ?? '']);
  await db.exec(`set local role ${role}`);
}
async function rejected(operation, code) {
  await db.exec('savepoint rejected');
  await assert.rejects(operation, { code });
  await db.exec('rollback to savepoint rejected; release savepoint rejected');
}
const signatures = [
  'public.dopmi_save_adoption(jsonb,uuid,integer)',
  'public.dopmi_transition_adoption(uuid,integer,text)',
  'public.dopmi_review_adoption(uuid,integer,text,text)',
  'public.dopmi_admin_adoptions(text,integer)',
  'public.dopmi_can_read_photo(text)',
  'public.dopmi_can_write_photo(text)',
  'private.dopmi_rescue_validate(public.dopmi_rescue_records)',
  'public.dopmi_account_deletion_server(text,jsonb)',
];
const functionInventory = () => db.query(`select p.oid::text,p.oid::regprocedure::text name,p.proacl::text
  from pg_proc p where p.oid=any($1::regprocedure[]) order by p.oid`, [signatures]).then(r => r.rows);

before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.identities(user_id uuid,provider text,provider_id text);
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
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
  for (const file of (await readdir(directory)).filter(f => f.endsWith('.sql') && f <= migration).sort()) {
    if (file === migration) {
      previousFunctions = await functionInventory();
      previousFinalize = await value("select pg_get_functiondef('public.dopmi_account_deletion_server(text,jsonb)'::regprocedure) value");
    }
    try { await db.exec(await readFile(new URL(file, directory), 'utf8')); }
    catch (error) { throw new Error(`Migration ${file}: ${error.code}: ${error.message}`); }
  }
  for (const id of [owner, reviewer, other]) {
    await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      values($1,$2,now(),' {"display_name":"Persona sintética","is_admin":true,"terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}')`, [id, `${id}@example.test`]);
    const session = randomUUID(); sessions.set(id, session);
    await db.query('insert into auth.sessions(id,user_id) values($1,$2)', [session, id]);
  }
  await db.query('insert into private.admin_memberships(user_id) values($1)', [reviewer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

const own = id => value('select public.dopmi_adoption_own($1) value', [id]);
const save = (payload, id = null, version = null) => value('select public.dopmi_save_adoption($1::jsonb,$2,$3) value', [JSON.stringify(payload), id, version]);
const transition = (a, action = 'submit') => value('select public.dopmi_transition_adoption($1,$2,$3) value', [a.id, a.version, action]);
const review = (a, decision = 'published', feedback = 'Revisión completa sintética') => value('select public.dopmi_review_adoption($1,$2,$3,$4) value', [a.id, a.version, decision, feedback]);
const catalog = () => value("select public.dopmi_catalog('{}') value");
const detail = id => value('select public.dopmi_adoption_detail($1) value', [id]);
async function raw(id) {
  await db.exec('reset role');
  return value('select to_jsonb(a) value from public.dopmi_adoptions a where id=$1', [id]);
}
async function publication(status = 'published') {
  await db.exec('reset role');
  const id = randomUUID();
  const photo = `${owner}/${id}/${randomUUID()}.jpg`;
  const extra = `${owner}/${id}/${randomUUID()}.jpg`;
  await db.query(`insert into public.dopmi_adoptions(id,owner_id,pet_name,status,story,city,region,publisher_name,photos,published_at,
    approximate_latitude,approximate_longitude) values($1,$2,'Luna aprobada',$3,'Historia aprobada y pública','Monterrey','Nuevo León',
    'Persona sintética',$4::text[],'2026-10-01T00:00:00Z',25.686614,-100.316113)`, [id, owner, status, [photo]]);
  for (const path of [photo, extra]) await db.query("insert into storage.objects(bucket_id,name) values('dopmi-adoption-photos',$1)", [path]);
  const baseline = await raw(id);
  await actor();
  return { id, photo, extra, baseline, version: 1 };
}
const proposed = f => ({ ...f.baseline, pet_name: 'Luna privada', story: 'X', photos: [f.extra],
  approximate_latitude: 25.700001, approximate_longitude: -100.300001, location_precision_version: 1 });
const publicFields = a => {
  const { version, updated_at, ...fields } = a;
  return fields;
};

test('existing function OIDs and role grants are preserved; new state is private and empty', async () => {
  assert.deepEqual(await functionInventory(), previousFunctions);
  assert.equal(await value("select pg_get_functiondef('public.dopmi_account_deletion_server(text,jsonb)'::regprocedure) value"), previousFinalize);
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_edits'), 0);
  assert.equal(await value("select relrowsecurity value from pg_class where oid='private.dopmi_adoption_edits'::regclass"), true);
  for (const role of ['anon', 'authenticated', 'service_role']) {
    assert.equal(await value("select has_table_privilege($1,'private.dopmi_adoption_edits','select,insert,update,delete') value", [role]), false);
    for (const signature of ['private.dopmi_adoption_owner_row(public.dopmi_adoptions)', 'private.dopmi_adoption_validate(public.dopmi_adoptions)', 'private.dopmi_cleanup_adoption_edits_on_account_delete()'])
      assert.equal(await value("select has_function_privilege($1,$2,'execute') value", [role, signature]), false);
  }
  for (const signature of ['public.dopmi_adoption_own(uuid)', 'public.dopmi_adoption_mine(integer,integer)']) {
    assert.equal(await value("select has_function_privilege('authenticated',$1,'execute') value", [signature]), true);
    assert.equal(await value("select has_function_privilege('anon',$1,'execute') value", [signature]), false);
    assert.equal(await value("select has_function_privilege('service_role',$1,'execute') value", [signature]), false);
  }
});

test('saving a published edit keeps all approved fields, public media and location unchanged', async () => {
  const f = await publication();
  const a = await save(proposed(f), f.id, f.version);
  assert.equal(a.status, 'published'); assert.equal(a._has_private_draft, true);
  assert.equal(a.pet_name, 'Luna privada'); assert.equal(a.approximate_latitude, 25.700001);
  assert.deepEqual(publicFields(await raw(f.id)), publicFields(f.baseline));
  await actor(); assert.equal((await own(f.id)).pet_name, 'Luna privada');
  const mine = await value('select public.dopmi_adoption_mine() value');
  assert.equal(mine.total, 1); assert.equal(mine.items[0].pet_name, 'Luna privada');
  await actor(null, 'anon');
  assert.equal((await detail(f.id)).pet_name, 'Luna aprobada');
  assert.doesNotMatch(JSON.stringify(await detail(f.id)), /approximate_latitude|approximate_longitude/);
  assert.equal((await catalog()).items[0].pet_name, 'Luna aprobada');
  assert.equal(await value('select public.dopmi_can_read_photo($1) value', [f.photo]), true);
  assert.equal(await value('select public.dopmi_can_read_photo($1) value', [f.extra]), false);
});

test('private drafts are unavailable to another account or a reviewer before submission', async () => {
  const f = await publication(); await save(proposed(f), f.id, 1);
  await actor(other); assert.equal(await own(f.id), null);
  assert.equal((await value('select public.dopmi_adoption_mine() value')).total, 0);
  await rejected(() => save(proposed(f), f.id, 2), '42501');
  await rejected(() => transition({ id: f.id, version: 2 }), '42501');
  await actor(reviewer);
  const pending = await value("select public.dopmi_admin_adoptions('submitted') value"); assert.equal(pending.total, 0);
  const active = await value("select public.dopmi_admin_adoptions('published') value");
  assert.equal(active.items[0].pet_name, 'Luna aprobada');
  assert.equal(active.items[0]._has_private_draft, false);
  assert.equal(await value('select public.dopmi_can_read_photo($1) value', [f.extra]), false);
  await rejected(() => value('select * from private.dopmi_adoption_edits'), '42501');
});

test('submit, reviewer preview and withdraw retain the approved publication and global version guards', async () => {
  const f = await publication(); const draft = await save(proposed(f), f.id, 1);
  const sent = await transition(draft); assert.equal(sent.status, 'submitted'); assert.equal(sent.version, 3);
  await rejected(() => save(proposed(f), f.id, sent.version), '22023');
  await rejected(() => transition(draft), '40001');
  await actor(reviewer);
  const pending = await value("select public.dopmi_admin_adoptions('submitted') value");
  assert.equal(pending.total, 1); assert.equal(pending.items[0].pet_name, 'Luna privada');
  assert.equal(pending.items[0].version, 3);
  assert.equal(await value('select public.dopmi_can_read_photo($1) value', [f.extra]), true);
  await actor(); const withdrawn = await transition(sent, 'withdraw');
  assert.equal(withdrawn.status, 'published'); assert.equal(withdrawn.version, 4);
  assert.deepEqual(publicFields(await raw(f.id)), publicFields(f.baseline));
  await actor(reviewer); await rejected(() => review(sent), '40001');
});

test('approving a submitted edit replaces the complete typed proposal atomically', async () => {
  const f = await publication(); const sent = await transition(await save(proposed(f), f.id, 1));
  await actor(reviewer); const approved = await review(sent);
  assert.equal(approved._has_private_draft, false); assert.equal(approved.version, 4);
  const row = await raw(f.id); assert.equal(row.pet_name, 'Luna privada'); assert.equal(row.story, 'X');
  assert.equal(row.approximate_latitude, 25.700001); assert.deepEqual(row.photos, [f.extra]);
  assert.equal(row.published_at, f.baseline.published_at);
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_edits'), 0);
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_reviews where post_id=$1', [f.id]), 1);
  await actor(null, 'anon'); assert.equal((await detail(f.id)).pet_name, 'Luna privada');
  assert.equal(await value('select public.dopmi_can_read_photo($1) value', [f.extra]), true);
  assert.equal(await value('select public.dopmi_can_read_photo($1) value', [f.photo]), false);
});

for (const decision of ['changes_requested', 'rejected']) test(`returning an edit as ${decision} preserves the active approved version`, async () => {
  const f = await publication(); const sent = await transition(await save(proposed(f), f.id, 1));
  await actor(reviewer); const returned = await review(sent, decision);
  assert.equal(returned.status, decision); assert.equal(returned.pet_name, 'Luna privada');
  assert.deepEqual(publicFields(await raw(f.id)), publicFields(f.baseline));
  await actor(); const corrected = await save(proposed(f), f.id, returned.version);
  assert.equal(corrected.status, 'published');
  await actor(null, 'anon'); assert.equal((await detail(f.id)).pet_name, 'Luna aprobada');
});

test('moderator withdrawal hides approved content and a draft cannot republish or bypass a new review', async () => {
  const f = await publication(); const draft = await save(proposed(f), f.id, 1);
  await actor(reviewer); const archived = await review(draft, 'archived');
  assert.equal(archived.status, 'draft');
  await actor(null, 'anon'); assert.equal(await detail(f.id), null);
  await actor(); const edited = await save(proposed(f), f.id, archived.version);
  assert.equal(edited.status, 'draft');
  await actor(reviewer); await rejected(() => review(edited), '22023');
  await actor(); const sent = await transition(edited);
  await actor(reviewer); await rejected(() => review({ ...sent, version: draft.version }), '40001');
  const restored = await review(sent); assert.equal(restored.status, 'published');
  await actor(null, 'anon'); assert.equal((await detail(f.id)).pet_name, 'Luna privada');
});

test('closing through Mis Casos invalidates a pending proposal without reopening or changing the approved data', async () => {
  const f = await publication(); const draft = await save(proposed(f), f.id, 1);
  const closed = await value("select public.dopmi_close_adoption($1,$2,'adopted',true,'Cierre sintético') value", [f.id, draft.version]);
  assert.equal(closed.status, 'adopted'); assert.equal(closed.pet_name, 'Luna aprobada');
  await db.exec('reset role'); assert.equal(await value('select count(*)::int value from private.dopmi_adoption_edits'), 0);
  await actor(reviewer); await rejected(() => review(draft), '40001');
  await actor(); await rejected(() => transition({ ...draft, version: closed.version }), '22023');
});

test('private photo uploads cannot overwrite or delete the approved photo; submitted media stays sealed', async () => {
  const f = await publication(); let a = await save(proposed(f), f.id, 1);
  assert.equal(await value('select public.dopmi_can_write_photo($1) value', [f.photo]), false);
  assert.equal(await value('select public.dopmi_can_write_photo($1) value', [f.extra]), true);
  await db.query("delete from storage.objects where bucket_id='dopmi-adoption-photos' and name=$1", [f.photo]);
  await db.exec('reset role'); assert.equal(await value('select count(*)::int value from storage.objects where name=$1', [f.photo]), 1);
  await actor(); a = await transition(a);
  assert.equal(await value('select public.dopmi_can_write_photo($1) value', [f.extra]), false);
  await actor(other); assert.equal(await value('select public.dopmi_can_write_photo($1) value', [f.extra]), false);
  await actor(null, 'anon'); assert.equal((await db.query("select name from storage.objects where bucket_id='dopmi-adoption-photos'")).rows.length, 1);
});

test('new adoption stories require one nonblank character; empty stories still cannot be submitted', async () => {
  const f = await publication('draft');
  let a = await save({ ...f.baseline, story: '   ' }, f.id, 1);
  await rejected(() => transition(a), '22023');
  a = await save({ ...f.baseline, story: '\n\t' }, f.id, a.version);
  await rejected(() => transition(a), '22023');
  a = await save({ ...f.baseline, story: 'Á' }, f.id, a.version);
  assert.equal((await transition(a)).status, 'submitted');
});

test('missing files, foreign photo paths, categories, length and sixth supplemental photo boundaries remain enforced', async () => {
  const f = await publication();
  await rejected(() => save({ ...proposed(f), photos: [`${other}/${f.id}/${randomUUID()}.jpg`] }, f.id, 1), '22023');
  await rejected(() => save({ ...proposed(f), photos: Array.from({ length: 7 }, () => f.extra) }, f.id, 1), '23514');
  await rejected(() => save({ ...proposed(f), story: 'X'.repeat(4001) }, f.id, 1), '23514');
  let a = await save({ ...proposed(f), species: null }, f.id, 1);
  await rejected(() => transition(a), '22023');
  a = await save({ ...proposed(f), photos: [`${owner}/${f.id}/${randomUUID()}.jpg`] }, f.id, a.version);
  await rejected(() => transition(a), '22023');
  assert.deepEqual(publicFields(await raw(f.id)), publicFields(f.baseline));
});

test('forged user metadata does not grant review privileges and a linked edit cannot be reviewed by its owner', async () => {
  const f = await publication(); const sent = await transition(await save(proposed(f), f.id, 1));
  await rejected(() => review(sent), '42501');
  await db.exec('reset role'); await db.query('insert into private.admin_memberships(user_id) values($1)', [owner]);
  await actor(); await rejected(() => review(sent), '42501');
  await actor(reviewer); assert.equal((await review(sent)).status, 'published');
});

test('support story accepts one character while other required support fields retain their minimums', async () => {
  await db.exec('reset role'); const id = randomUUID(); const photo = `${owner}/${id}/${randomUUID()}.jpg`;
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)", [photo]);
  const fields = { species: 'dog', sex: 'female', age: 'adult', story: 'X', city: 'Monterrey', state: 'Nuevo León', need_items: [] };
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,public_data,files,video_thanks_required)
    values($1,$2,'case',$3::jsonb,$4::jsonb,false)`, [id, owner, JSON.stringify(fields), JSON.stringify([{ role: 'public', path: photo }])]);
  await value('select private.dopmi_rescue_validate(r) from public.dopmi_rescue_records r where id=$1', [id]);
  await db.query("update public.dopmi_rescue_records set public_data=jsonb_set(public_data,'{story}','\" \"') where id=$1", [id]);
  await rejected(() => value('select private.dopmi_rescue_validate(r) from public.dopmi_rescue_records r where id=$1', [id]), '22023');
  await db.query("update public.dopmi_rescue_records set public_data=$2::jsonb where id=$1", [id, JSON.stringify({ ...fields, city: 'M' })]);
  await rejected(() => value('select private.dopmi_rescue_validate(r) from public.dopmi_rescue_records r where id=$1', [id]), '22023');
});

test('real finalization purges a submitted private edit while retaining the anonymized post and legal/moderation evidence', async () => {
  const f = await publication('submitted');
  await actor(reviewer);
  const approved = await review(f);
  f.baseline = approved;
  await actor();
  const sent = await transition(await save({ ...proposed(f), story: 'Historia privada pendiente que debe eliminarse' }, f.id, approved.version));
  await actor(reviewer);
  assert.equal((await value("select public.dopmi_admin_adoptions('submitted') value")).items[0].story,
    'Historia privada pendiente que debe eliminarse');
  await db.exec('reset role');
  const retained = async () => ({
    reviews: (await db.query('select to_jsonb(r) value from private.dopmi_adoption_reviews r where post_id=$1 order by id', [f.id])).rows,
    consents: (await db.query('select to_jsonb(c) value from private.dopmi_consents c where owner_id=$1 order by id', [owner])).rows,
    objects: (await db.query('select to_jsonb(o) value from storage.objects o order by name')).rows,
  });
  const evidence = await retained();
  assert.equal(evidence.reviews.length, 1);
  assert.ok(evidence.consents.length > 0);
  const deletion = operation => value('select public.dopmi_account_deletion_server($1,$2::jsonb) value',
    [operation, JSON.stringify({ owner_id: owner, request_key: randomUUID() })]);
  assert.equal((await deletion('request')).status, 'procesando');
  assert.equal((await deletion('finalize')).status, 'completado');
  assert.equal((await deletion('finalize')).status, 'completado');
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_edits where owner_id=$1', [owner]), 0);
  assert.deepEqual(await retained(), evidence);
  const row = await raw(f.id);
  assert.equal(row.pet_name, 'Publicación retirada');
  assert.equal(row.publisher_name, 'Cuenta eliminada');
  assert.equal(row.status, 'archived');
  assert.deepEqual(row.photos, []);
  assert.equal(row.story, '');
  assert.equal(await value('select account_status value from public.profiles where id=$1', [owner]), 'deleted');
  assert.equal((await deletion('auth_cleanup')).status, 'completado');
  await db.query('delete from auth.users where id=$1', [owner]);
  assert.equal(await value('select count(*)::int value from auth.users where id=$1', [owner]), 0);
  assert.deepEqual(await retained(), evidence);
  assert.equal((await raw(f.id)).pet_name, 'Publicación retirada');
  await actor(reviewer);
  assert.equal((await value("select public.dopmi_admin_adoptions('submitted') value")).total, 0);
  const all = await value("select public.dopmi_admin_adoptions('') value");
  assert.doesNotMatch(JSON.stringify(all), /Historia privada pendiente que debe eliminarse|Luna privada/);
  assert.equal(await value('select public.dopmi_can_read_photo($1) value', [f.extra]), false);
  await rejected(() => review(sent), '42501');
  await actor(null, 'anon');
  assert.equal(await detail(f.id), null);
  assert.equal(await value('select public.dopmi_can_read_photo($1) value', [f.extra]), false);
});

test('direct Auth removal cascades only the private edit and leaves retained public/moderation records intact', async () => {
  const f = await publication('submitted');
  await actor(reviewer); const approved = await review(f);
  f.baseline = approved;
  await actor(); await transition(await save(proposed(f), f.id, approved.version));
  await db.exec('reset role');
  const before = await raw(f.id);
  const reviews = (await db.query('select to_jsonb(r) value from private.dopmi_adoption_reviews r where post_id=$1', [f.id])).rows;
  const consents = (await db.query('select to_jsonb(c) value from private.dopmi_consents c where owner_id=$1', [owner])).rows;
  await db.query('delete from auth.users where id=$1', [owner]);
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_edits where owner_id=$1', [owner]), 0);
  assert.deepEqual(await raw(f.id), before);
  assert.deepEqual((await db.query('select to_jsonb(r) value from private.dopmi_adoption_reviews r where post_id=$1', [f.id])).rows, reviews);
  assert.deepEqual((await db.query('select to_jsonb(c) value from private.dopmi_consents c where owner_id=$1', [owner])).rows, consents);
  await actor(reviewer);
  assert.equal((await value("select public.dopmi_admin_adoptions('submitted') value")).total, 0);
  assert.equal(await value('select public.dopmi_can_read_photo($1) value', [f.extra]), false);
});
