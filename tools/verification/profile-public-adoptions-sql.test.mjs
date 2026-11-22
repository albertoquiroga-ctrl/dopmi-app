import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

// Complete repository migrations in disposable PostgreSQL/WASM only.
const owner = randomUUID(), viewer = randomUUID(), other = randomUUID();
const sessions = new Map();
const migration = '20261121012608_public_profile_adoptions.sql';
let db, previousFunction;
const value = async (sql, params = []) => (await db.query(sql, params)).rows[0]?.value;
const profile = (id = owner) => value('select public.dopmi_public_profile($1) value', [id]);
const functionAccess = () => value(`select jsonb_build_object('oid', oid::text, 'acl', proacl::text,
  'security_definer', prosecdef, 'volatility', provolatile, 'configuration', proconfig) value
  from pg_proc where oid = 'public.dopmi_public_profile(uuid)'::regprocedure`);

async function actor(id = viewer, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
  await db.query("select set_config('request.jwt.claim.session_id',$1,true)", [sessions.get(id) ?? '']);
  await db.exec(`set local role ${role}`);
}

async function adoption({ id = randomUUID(), who = owner, status = 'published',
  name = 'Mascota aprobada', date = '2026-11-01T12:00:00Z' } = {}) {
  await db.exec('reset role');
  const photo = `${who}/${id}/approved.jpg`;
  const payload = { pet_name: name, species: 'cat', sex: 'male', size: 'small',
    age_band: 'puppy', age_months: 3, story: 'Historia aprobada', city: 'Monterrey',
    region: 'Nuevo León', publisher_name: 'Nombre público aprobado',
    publisher_bio: 'Biografía aprobada', photos: [photo],
    approximate_latitude: 25.686614, approximate_longitude: -100.316113,
    location_precision_version: 1 };
  await db.query(`insert into public.dopmi_adoptions(id,owner_id,pet_name,species,sex,size,
    age_band,age_months,story,city,region,publisher_name,publisher_bio,photos,status,published_at,
    approximate_latitude,approximate_longitude)
    values($1,$2,$3,'cat','male','small','puppy',3,$4,$5,$6,$7,$8,$9::text[],$10,$11::timestamptz,$12,$13)`,
  [id, who, name, payload.story, payload.city, payload.region, payload.publisher_name,
    payload.publisher_bio, payload.photos, status, date,
    payload.approximate_latitude, payload.approximate_longitude]);
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-adoption-photos',$1)", [photo]);
  return { id, photo, payload };
}

before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',
      email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz,
      created_at timestamptz default now(),deleted_at timestamptz);
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
  for (const file of (await readdir(directory)).filter(file => file.endsWith('.sql')).sort()) {
    if (file === migration) previousFunction = await functionAccess();
    await db.exec(await readFile(new URL(file, directory), 'utf8'));
  }
  for (const id of [owner, viewer, other]) {
    await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      values($1,$2,now(),' {"display_name":"Nombre privado","terms_version":"terms-2026-10-17",
        "privacy_version":"privacy-2026-10-17","adult_confirmed":true}')`, [id, `${id}@example.test`]);
    const session = randomUUID();
    sessions.set(id, session);
    await db.query('insert into auth.sessions(id,user_id) values($1,$2)', [session, id]);
  }
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('the additive profile fix preserves the function identity, grants and definer configuration', async () => {
  assert.ok(previousFunction, 'The tested migration must be loaded');
  assert.deepEqual(await functionAccess(), previousFunction);
});

test('an ordinary public profile includes only its own available adoptions for anonymous and signed-in visitors', async () => {
  const published = await adoption();
  for (const status of ['draft', 'submitted', 'changes_requested', 'rejected', 'adopted', 'archived']) {
    await adoption({ status, name: `Excluir ${status}` });
  }
  await adoption({ who: other, name: 'Otra rescatista' });
  assert.equal(await value('select private.dopmi_rescuer_verified($1) value', [owner]), false);
  assert.equal(await value('select public.dopmi_rescuer_public($1) value', [owner]), null);
  for (const role of ['anon', 'authenticated']) {
    await actor(role === 'anon' ? null : viewer, role);
    const result = await profile();
    assert.ok(Array.isArray(result.adoptions));
    assert.deepEqual(result.adoptions.map(post => post.id), [published.id]);
    assert.equal(result.adoptions[0].pet_name, 'Mascota aprobada');
    assert.equal(result.adoptions[0].owner_id, owner);
    assert.notEqual(result.verified, true);
    assert.doesNotMatch(JSON.stringify(result), /Nombre privado|approximate_latitude|approximate_longitude|review_feedback|email|phone/);
  }
});

test('a private correction keeps the approved name, story and photo in the public profile', async () => {
  const published = await adoption();
  await actor(owner);
  const proposal = { ...published.payload, pet_name: 'Nombre de la edición privada',
    story: 'Historia de la edición privada', photos: [`${owner}/${published.id}/private.jpg`] };
  await value('select public.dopmi_save_adoption($1::jsonb,$2,1) value', [JSON.stringify(proposal), published.id]);
  await actor(null, 'anon');
  const result = await profile();
  assert.equal(result.adoptions.length, 1);
  assert.equal(result.adoptions[0].pet_name, 'Mascota aprobada');
  assert.equal(result.adoptions[0].story, 'Historia aprobada');
  assert.deepEqual(result.adoptions[0].photos, [published.photo]);
  assert.doesNotMatch(JSON.stringify(result), /edición privada|private\.jpg|approximate_latitude|approximate_longitude/);
});

test('suspended and deleted publishers expose neither their profile nor their previously public listings', async () => {
  await adoption();
  for (const status of ['suspended', 'deleted']) {
    await db.exec('reset role');
    await db.query('update public.profiles set account_status=$2 where id=$1', [owner, status]);
    await actor(null, 'anon');
    assert.equal(await profile(), null);
  }
});

test('an adopted-only history retains the public profile with an empty adoption list and its true historical count', async () => {
  await adoption({ status: 'adopted' });
  await actor(null, 'anon');
  const result = await profile();
  assert.equal(result.adopted_count, 1);
  assert.deepEqual(result.adoptions, []);
});

test('private-only and unknown publishers have no public profile', async () => {
  await adoption({ status: 'draft', date: null });
  await actor(null, 'anon');
  assert.equal(await profile(), null);
  assert.equal(await profile(randomUUID()), null);
});

test('published listings use newest publication first with stable ID ordering for equal timestamps', async () => {
  const older = await adoption({ date: '2026-10-01T00:00:00Z' });
  const first = await adoption({ id: '50000000-0000-4000-8000-000000000001', date: '2026-11-02T00:00:00Z' });
  const second = await adoption({ id: '50000000-0000-4000-8000-000000000002', date: '2026-11-02T00:00:00Z' });
  await actor(viewer);
  assert.deepEqual((await profile()).adoptions.map(post => post.id), [first.id, second.id, older.id]);
});
