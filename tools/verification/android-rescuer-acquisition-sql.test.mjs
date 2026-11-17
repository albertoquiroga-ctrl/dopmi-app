import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const migration = '20261112232613_android_rescuer_acquisition.sql';
const report = await readFile(new URL('./android-rescuer-acquisition.sql', import.meta.url), 'utf8');
const owner = randomUUID();
const other = randomUUID();
const reviewer = randomUUID();
const sessions = new Map();
let db;

const value = async (sql, params = []) => (await db.query(sql, params)).rows[0]?.value;
const consent = enabled => db.query('select public.dopmi_set_adoption_measurement($1)', [enabled]);
const ago = milliseconds => new Date(Date.now() - milliseconds).toISOString();
const attribute = (variant, clickedAt = ago(5000)) => db.query(
  'select public.dopmi_record_android_rescuer_acquisition($1,$2)', [variant, clickedAt],
);
const source = id => value(
  'select to_jsonb(s) value from private.dopmi_android_rescuer_acquisition s where actor_id=$1',
  [id],
);

async function adoption(actor, fields = {}) {
  const id = randomUUID();
  const photo = actor + '/' + id + '/' + randomUUID() + '.jpg';
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-adoption-photos',$1)", [photo]);
  await db.query(
    `insert into public.dopmi_adoptions(
      id,owner_id,pet_name,city,region,story,publisher_name,photos,status,submitted_at,published_at,age_band,personality
    ) values (
      $1,$2,'Luna','Monterrey','Nuevo León','Luna necesita una familia que le dedique tiempo',
      'Persona sintética',$3,$4,$5,$6,'adult',array['affectionate']::text[]
    )`,
    [id, actor, [photo], fields.status ?? 'draft', fields.submittedAt ?? null, fields.publishedAt ?? null],
  );
  return { id, version: 1 };
}

const transition = (post, action = 'submit') => value(
  'select public.dopmi_transition_adoption($1,$2,$3) value',
  [post.id, post.version, action],
);
const review = (post, decision) => value(
  "select public.dopmi_review_adoption($1,$2,$3,'Evidencia de revisión sintética') value",
  [post.id, post.version, decision],
);

async function asActor(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)", [id ?? '', sessions.get(id) ?? '']);
  await db.exec('set local role ' + role);
}

async function rejects(operation, code) {
  await db.exec('savepoint rejected');
  await assert.rejects(operation, { code });
  await db.exec('rollback to savepoint rejected; release savepoint rejected');
}

before(async () => {
  db = new PGlite();
  await db.exec([
    'create role anon; create role authenticated; create role service_role',
    'create schema auth; create schema storage',
    "create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz,created_at timestamptz default now())",
    'create table auth.identities(user_id uuid,provider text,provider_id text)',
    'create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz)',
    "create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$",
    "create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('role',current_setting('role',true))$$",
    'grant usage on schema auth,public to anon,authenticated,service_role',
    'create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[])',
    'create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb)',
    'alter table storage.objects enable row level security',
    'grant usage on schema storage to anon,authenticated',
    'grant select on storage.objects to anon',
    'grant select,insert,update,delete on storage.objects to authenticated',
  ].join(';'));
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(directory)).filter(file => file.endsWith('.sql') && file <= migration).sort()) {
    try {
      await db.exec(await readFile(new URL(file, directory), 'utf8'));
    } catch (error) {
      throw new Error('Migration ' + file + ': ' + error.code + ' ' + error.message, { cause: error });
    }
  }
  for (const id of [owner, other, reviewer]) {
    const metadata = {
    display_name: 'Persona sintética',
    terms_version: 'terms-2026-10-17',
    privacy_version: 'privacy-2026-10-17',
    adult_confirmed: true,
  };
    await db.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)', [id, id + '@example.test', metadata]);
    sessions.set(id, randomUUID());
    await db.query('insert into auth.sessions(id,user_id) values($1,$2)', [sessions.get(id), id]);
  }
  await db.query('insert into private.admin_memberships(user_id) values($1)', [reviewer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('only authenticated active actors can submit an allowlisted variant and the table is private', async () => {
  assert.equal(await value("select relrowsecurity value from pg_class where oid='private.dopmi_android_rescuer_acquisition'::regclass"), true);
  for (const role of ['anon', 'authenticated', 'service_role']) {
    assert.equal(await value("select has_table_privilege($1,'private.dopmi_android_rescuer_acquisition','select,insert,update,delete') value", [role]), false);
    assert.equal(await value("select has_function_privilege($1,'public.dopmi_record_android_rescuer_acquisition(text,timestamptz)','execute') value", [role]), role === 'authenticated');
  }
  await asActor(null, 'anon');
  await rejects(() => attribute('personal-a'), '42501');
  await asActor(null);
  await rejects(() => attribute('personal-a'), '42501');
  await asActor(owner);
  await rejects(() => attribute('personal-c'), '22023');
  await rejects(() => attribute(null), '22023');
  await rejects(() => attribute('personal-a', null), '22023');
  await rejects(() => attribute('personal-a', ago(-60_000)), '22023');
  await rejects(() => attribute('personal-a', ago(337 * 3_600_000)), '22023');
  await rejects(() => db.exec('select * from private.dopmi_android_rescuer_acquisition'), '42501');
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [owner]);
  await asActor(owner);
  await rejects(() => attribute('personal-a'), '42501');
});

test('synced opt-in gates capture and a retry does not replace the first variant or its timestamp', async () => {
  await asActor(owner);
  await attribute('personal-a');
  await consent(false);
  await attribute('personal-a');
  await db.exec('reset role');
  assert.equal(await source(owner), undefined);
  await asActor(owner);
  await consent(true);
  await attribute('personal-a');
  await db.exec('reset role');
  const first = await source(owner);
  assert.equal(first.variant, 'personal-a');
  await asActor(owner);
  await attribute('personal-a');
  await attribute('pagina-b');
  await db.exec('reset role');
  assert.deepEqual(await source(owner), first);
});

test('known previous submissions and reviews exclude an actor, while an existing draft does not', async () => {
  await adoption(owner, { status: 'draft', submittedAt: '2026-11-01T10:00:00Z' });
  const reviewed = await adoption(other, { status: 'archived' });
  await db.query("insert into private.dopmi_adoption_reviews(post_id,actor_id,decision,feedback,version) values($1,$2,'changes_requested','Anterior',1)", [reviewed.id, reviewer]);
  await adoption(reviewer);
  for (const id of [owner, other, reviewer]) {
    await asActor(id);
    await consent(true);
    await attribute('personal-b');
  }
  await db.exec('reset role');
  assert.equal(await source(owner), undefined);
  assert.equal(await source(other), undefined);
  assert.equal((await source(reviewer)).variant, 'personal-b');
});

test('the original submission and its later approval count once through corrections and resubmission', async () => {
  const firstDraft = await adoption(owner);
  const secondDraft = await adoption(owner);
  const otherDraft = await adoption(other);
  const clickedAt = ago(60_000);
  await db.query("update auth.users set created_at=clock_timestamp() where id=$1", [owner]);
  await db.query("update auth.users set created_at=clock_timestamp()-interval '1 day' where id=$1", [other]);
  await asActor(other);
  await consent(true);
  await attribute('pagina-a', clickedAt);
  await transition(otherDraft);
  await asActor(owner);
  await consent(true);
  await attribute('pagina-a', clickedAt);
  const first = await transition(firstDraft);
  assert.equal(first.status, 'submitted');
  await db.exec('reset role');
  const captured = await source(owner);
  assert.equal(captured.first_adoption_id, first.id);
  assert.ok(captured.first_submitted_at);
  assert.equal(captured.first_approved_at, null);

  await asActor(reviewer);
  const corrected = await review(first, 'changes_requested');
  await asActor(owner);
  const resubmitted = await transition(corrected);
  const second = await transition(secondDraft);
  await asActor(reviewer);
  await review(second, 'published');
  await db.exec('reset role');
  assert.deepEqual(await source(owner), captured);

  await asActor(reviewer);
  const approved = await review(resubmitted, 'published');
  assert.equal(approved.status, 'published');
  await asActor(owner);
  const archived = await transition(approved, 'archive');
  assert.equal(archived.status, 'archived');
  await db.exec('reset role');
  const converted = await source(owner);
  assert.equal(converted.first_submitted_at, captured.first_submitted_at);
  assert.ok(converted.first_approved_at >= captured.first_submitted_at);
  const rows = (await db.query(report)).rows;
  assert.equal(rows.length, 4);
  const result = rows.find(row => row.variant === 'pagina-a');
  assert.equal(result.attributed_accounts, 2);
  assert.equal(result.first_observable_submissions_14d, 2);
  assert.equal(result.first_observable_submissions_approved, 1);
  assert.equal(result.new_attributed_accounts, 1);
  assert.equal(result.new_first_submissions_14d, 1);
  assert.doesNotMatch(JSON.stringify(rows), new RegExp(owner + '|' + first.id + '|Luna'));
});

test('the first submission stops counting at 14 days and publication still proceeds', async () => {
  const draft = await adoption(owner);
  await asActor(owner);
  await consent(true);
  await attribute('pagina-b');
  await db.exec('reset role');
  await db.query("update private.dopmi_android_rescuer_acquisition set clicked_at=clock_timestamp()-interval '336 hours' where actor_id=$1", [owner]);
  await asActor(owner);
  const submitted = await transition(draft);
  await asActor(reviewer);
  assert.equal((await review(submitted, 'published')).status, 'published');
  await db.exec('reset role');
  const captured = await source(owner);
  assert.equal(captured.first_submitted_at, null);
  assert.equal(captured.first_approved_at, null);
  const result = (await db.query(report)).rows.find(row => row.variant === 'pagina-b');
  assert.equal(result.matured_accounts, 1);
  assert.equal(result.first_observable_submissions_14d, 0);
});

test('opt-out, finalized profile deletion, and Auth deletion remove attribution', async () => {
  for (const id of [owner, other, reviewer]) {
    await asActor(id);
    await consent(true);
    await attribute('personal-a');
  }
  await asActor(owner);
  await consent(false);
  await attribute('pagina-b');
  await db.exec('reset role');
  assert.equal(await source(owner), undefined);
  await db.query("update public.profiles set account_status='deleted' where id=$1", [other]);
  assert.equal(await source(other), undefined);
  await db.query('delete from auth.users where id=$1', [reviewer]);
  assert.equal(await source(reviewer), undefined);
});
