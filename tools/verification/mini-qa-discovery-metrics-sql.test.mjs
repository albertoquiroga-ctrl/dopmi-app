import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

// Disposable local PostgreSQL/WASM. No remote URL, Auth service, device or money.
const migration = '20261103024530_mini_qa_discovery_metrics.sql';
const owner = randomUUID(), viewer = randomUUID(), other = randomUUID(), hidden = randomUUID();
const secondPhone = randomUUID(), sessions = new Map();
const historyFunctions = ['dopmi_seen_adoptions()', 'dopmi_mark_adoption_seen(uuid)', 'dopmi_reset_seen_adoptions()'];
let db, baselineAcl, migrationCount = 0;
const value = async (sql, args = []) => (await db.query(sql, args)).rows[0]?.value;

async function actor(id = viewer, role = 'authenticated', session = sessions.get(id)) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
  await db.query("select set_config('request.jwt.claim.session_id',$1,true)", [session ?? '']);
  await db.exec(`set local role ${role}`);
}

async function rejected(action, code = '42501') {
  await db.exec('savepoint rejection');
  try { await assert.rejects(action, { code }); }
  finally { await db.exec('rollback to savepoint rejection; release savepoint rejection'); }
}

const seen = () => value('select public.dopmi_seen_adoptions() value');
const mark = id => db.query('select public.dopmi_mark_adoption_seen($1)', [id]);
const reset = () => db.query('select public.dopmi_reset_seen_adoptions()');
const metrics = id => value('select public.dopmi_rescuer_public_metrics($1) value', [id]);
const owned = () => value("select public.dopmi_owned_cases('adoption') value");
const funnel = () => value("select public.dopmi_rescuer_funnel('month') value");

async function adoption({ who = owner, status = 'published', name = 'Mascota pública sintética', published = status !== 'draft' } = {}) {
  await db.exec('reset role');
  const id = randomUUID(), photo = `${who}/${id}/synthetic.jpg`;
  const payload = {
    pet_name: name, species: 'dog', sex: 'female', size: 'medium', age_band: 'adult',
    age_months: 24, city: 'Monterrey', region: 'Nuevo León', story: 'Historia pública sintética',
    publisher_name: 'Nombre público aprobado', publisher_bio: 'Biografía pública', photos: [photo],
    personality: ['affectionate'], vaccinated: true, sterilized: false,
  };
  await db.query(`insert into public.dopmi_adoptions(id,owner_id,pet_name,species,sex,size,age_band,age_months,
    city,region,story,publisher_name,publisher_bio,photos,status,published_at)
    values($1,$2,$3,'dog','female','medium','adult',24,$4,$5,$6,$7,$8,$9::text[],$10,
      case when $11 then now()-interval '1 day' else null end)`,
    [id, who, name, payload.city, payload.region, payload.story, payload.publisher_name, payload.publisher_bio, payload.photos, status, published]);
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-adoption-photos',$1)", [photo]);
  return { id, payload };
}

async function audienceInventory() {
  await db.exec('reset role');
  const result = {};
  for (const table of ['public.dopmi_favorites', 'private.dopmi_adoption_views', 'private.dopmi_adoption_view_days']) {
    result[table] = (await db.query(`select to_jsonb(t) value from ${table} t order by to_jsonb(t)::text`)).rows;
  }
  return result;
}

async function existingAcl() {
  return (await db.query(`select oid::text,proacl::text from pg_proc where oid=any(array[
    'public.dopmi_rescuer_public_metrics(uuid)'::regprocedure,
    'private.dopmi_owned_case_rows(uuid)'::regprocedure]) order by oid`)).rows;
}

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
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  const migrations = (await readdir(directory)).filter(file => file.endsWith('.sql') && file <= migration).sort();
  assert.ok(migrations.includes(migration));
  for (const file of migrations) {
    if (file === migration) baselineAcl = await existingAcl();
    try { await db.exec(await readFile(new URL(file, directory), 'utf8')); }
    catch (error) { throw new Error(`Migration ${file}: ${error.code}: ${error.message}`); }
    migrationCount++;
  }
  for (const id of [owner, viewer, other, hidden]) {
    await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      values($1,$2,now(),'{"display_name":"Nombre privado","terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}')`, [id, `${id}@example.test`]);
    const session = randomUUID(); sessions.set(id, session);
    await db.query('insert into auth.sessions(id,user_id) values($1,$2)', [session, id]);
  }
  await db.query('insert into auth.sessions(id,user_id) values($1,$2)', [secondPhone, viewer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('history persists between sessions of the same account and idempotency preserves its first observation', async t => {
  t.diagnostic(`Loaded ${migrationCount} repository migrations through ${migration}`);
  const post = await adoption();
  await actor(viewer); await mark(post.id);
  await db.exec('reset role');
  await db.query("update private.dopmi_adoption_seen set seen_at=now()-interval '2 days' where actor_id=$1 and post_id=$2", [viewer, post.id]);
  const first = await value('select seen_at value from private.dopmi_adoption_seen where actor_id=$1 and post_id=$2', [viewer, post.id]);
  await actor(viewer, 'authenticated', secondPhone); await mark(post.id);
  assert.deepEqual(await seen(), [post.id]);
  await db.exec('reset role');
  assert.deepEqual(await value('select seen_at value from private.dopmi_adoption_seen where actor_id=$1 and post_id=$2', [viewer, post.id]), first);
  await actor(other); assert.deepEqual(await seen(), []); await mark(post.id);
  await actor(viewer); assert.deepEqual(await seen(), [post.id]);
  const identifiers = await seen();
  assert.ok(identifiers.every(id => typeof id === 'string' && id === post.id));
  assert.ok(!identifiers.includes(owner) && !identifiers.includes(viewer));
});

test('reset clears only the caller history and leaves favorites and consented view evidence intact', async () => {
  const first = await adoption(), second = await adoption();
  await actor(viewer);
  await db.query('select public.dopmi_set_favorite($1,true)', [first.id]);
  await db.query('select public.dopmi_set_adoption_measurement(true)');
  await db.query('select public.dopmi_record_adoption_view($1,true)', [first.id]);
  await mark(first.id); await mark(second.id);
  await actor(other); await mark(second.id);
  const before = await audienceInventory();
  await actor(viewer, 'authenticated', secondPhone); await reset();
  assert.deepEqual(await seen(), []);
  await actor(other); assert.deepEqual(await seen(), [second.id]);
  assert.deepEqual(await audienceInventory(), before);
});

test('private, missing and inactive-owner posts do not enter discovery history', async () => {
  const drafts = [];
  for (const status of ['draft', 'submitted', 'changes_requested', 'rejected', 'adopted', 'archived']) {
    drafts.push(await adoption({ status, published: false }));
  }
  const suspended = await adoption({ who: hidden });
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [hidden]);
  await actor(viewer);
  for (const post of [...drafts, suspended, { id: randomUUID() }]) await mark(post.id);
  assert.deepEqual(await seen(), []);
});

test('history RPCs reject missing identity, inactive accounts and non-client roles', async () => {
  const post = await adoption();
  const calls = [seen, () => mark(post.id), reset];
  for (const role of ['anon', 'service_role']) {
    await actor(viewer, role);
    for (const call of calls) await rejected(call);
  }
  await actor(null);
  for (const call of calls) await rejected(call);
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [viewer]);
  await actor(viewer);
  for (const call of calls) await rejected(call);
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='active' where id=$1", [viewer]);
  await db.query('update auth.users set email_confirmed_at=null where id=$1', [viewer]);
  await actor(viewer);
  for (const call of calls) await rejected(call);
});

test('history is an unexposed RLS table with narrow authenticated RPC ACLs and unchanged prior ACLs', async () => {
  assert.deepEqual(await existingAcl(), baselineAcl);
  assert.equal(await value("select relrowsecurity value from pg_class where oid='private.dopmi_adoption_seen'::regclass"), true);
  const columns = (await db.query(`select column_name from information_schema.columns where table_schema='private'
    and table_name='dopmi_adoption_seen' order by ordinal_position`)).rows.map(row => row.column_name);
  assert.deepEqual(columns, ['actor_id', 'post_id', 'seen_at']);
  for (const signature of historyFunctions) {
    for (const role of ['anon', 'authenticated', 'service_role']) {
      assert.equal(await value('select has_function_privilege($1,$2,\'EXECUTE\') value', [role, `public.${signature}`]), role === 'authenticated');
    }
  }
  await actor(viewer);
  await rejected(() => db.query('select * from private.dopmi_adoption_seen'));
  await rejected(() => db.query('insert into private.dopmi_adoption_seen(actor_id,post_id) values($1,$2)', [other, randomUUID()]));
});

test('adoption-only public profiles expose real zero/nonzero counters without granting a shelter badge', async () => {
  await adoption(); await adoption({ status: 'adopted' });
  await adoption({ status: 'draft', published: false, name: 'Borrador privado que no debe contarse' });
  await adoption({ who: other });
  assert.equal(await value('select private.dopmi_rescuer_verified($1) value', [owner]), false);
  await actor(viewer, 'anon');
  assert.equal(await value('select public.dopmi_rescuer_public($1) value', [owner]), null);
  const profile = await value('select public.dopmi_public_profile($1) value', [owner]);
  assert.equal(profile.adopted_count, 1); assert.notEqual(profile.verified, true);
  const result = await metrics(owner);
  assert.equal(result.active_adoptions, 1); assert.equal(result.published_adoptions, 2);
  assert.equal(result.active_donation_cases, 0); assert.equal(result.received_support_pets, 0);
  assert.equal(JSON.stringify(result).includes('Borrador privado'), false);
  assert.equal(JSON.stringify(result).includes('Nombre privado'), false);
});

test('profiles with only private posts and suspended public owners return no public metrics', async () => {
  await adoption({ who: hidden, status: 'draft', published: false });
  await adoption();
  await actor(viewer, 'anon');
  assert.equal(await metrics(hidden), null);
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [owner]);
  await actor(viewer, 'anon');
  assert.equal(await metrics(owner), null);
});

test('consented non-owner observations produce one lifetime card view and one period view, with owner/false-consent excluded', async () => {
  const post = await adoption();
  await actor(viewer); await db.query('select public.dopmi_record_adoption_view($1,true)', [post.id]);
  await db.query('select public.dopmi_set_adoption_measurement(false)');
  await db.query('select public.dopmi_record_adoption_view($1,true)', [post.id]);
  await actor(owner); await db.query('select public.dopmi_set_adoption_measurement(true)');
  await db.query('select public.dopmi_record_adoption_view($1,true)', [post.id]);
  assert.equal((await owned()).items[0].unique_view_count, 0);
  assert.equal((await funnel()).adoption.views, 0);
  await actor(viewer); await db.query('select public.dopmi_set_adoption_measurement(true)');
  await db.query('select public.dopmi_record_adoption_view($1,false)', [post.id]);
  await actor(owner); assert.equal((await owned()).items[0].unique_view_count, 0);
  await actor(viewer); await db.query('select public.dopmi_record_adoption_view($1,true)', [post.id]);
  await db.query('select public.dopmi_record_adoption_view($1,true)', [post.id]);
  await actor(viewer, 'authenticated', secondPhone);
  await db.query('select public.dopmi_record_adoption_view($1,true)', [post.id]);
  await actor(owner);
  assert.equal((await owned()).items[0].unique_view_count, 1);
  assert.equal((await funnel()).adoption.views, 1);
  assert.equal((await value('select public.dopmi_rescuer_dashboard_v2() value')).adoption_metrics.unique_viewers, 1);
  await actor(other); assert.equal((await owned()).total, 0); assert.equal((await funnel()).adoption.views, 0);
});

test('owner case rows overlay a private adoption edit while keeping real view counters and approved public data', async () => {
  const post = await adoption();
  await actor(viewer); await db.query('select public.dopmi_set_adoption_measurement(true)');
  await db.query('select public.dopmi_record_adoption_view($1,true)', [post.id]);
  await actor(owner);
  await value('select public.dopmi_save_adoption($1::jsonb,$2,1) value', [JSON.stringify({ ...post.payload, pet_name: 'Edición privada sintética', story: 'x' }), post.id]);
  const item = (await owned()).items[0];
  assert.equal(item.pet_name, 'Edición privada sintética'); assert.equal(item.record.pet_name, item.pet_name);
  assert.equal(item._has_private_draft, true); assert.equal(item.phase, 'active'); assert.equal(item.unique_view_count, 1);
  await actor(viewer, 'anon');
  const publicPost = await value('select public.dopmi_adoption_detail($1) value', [post.id]);
  assert.equal(publicPost.pet_name, 'Mascota pública sintética');
  assert.equal(JSON.stringify(publicPost).includes('Edición privada'), false);
  assert.equal((await metrics(owner)).active_adoptions, 1);
  await actor(other); assert.equal((await owned()).total, 0);
});


test('account finalization clears functional history before deferred Auth cleanup and preserves other accounts', async () => {
  const post = await adoption();
  await actor(viewer); await mark(post.id);
  await actor(other); await mark(post.id);
  await actor(viewer, 'service_role');
  const requestKey = randomUUID();
  const deletion = operation => value('select public.dopmi_account_deletion_server($1,$2::jsonb) value',
    [operation, JSON.stringify({owner_id: viewer, request_key: requestKey})]);
  await deletion('request');
  assert.equal((await deletion('finalize')).status, 'completado');
  await db.exec('reset role');
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_seen where actor_id=$1', [viewer]), 0);
  assert.equal(await value('select count(*)::int value from auth.users where id=$1', [viewer]), 1);
  await actor(other); assert.deepEqual(await seen(), [post.id]);
  await db.exec('reset role');
  await db.query('delete from auth.users where id=$1', [other]);
  assert.equal(await value('select count(*)::int value from private.dopmi_adoption_seen where actor_id=$1', [other]), 0);
});
