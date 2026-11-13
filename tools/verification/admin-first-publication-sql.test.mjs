import { after, afterEach, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const migration = '20261112232548_admin_first_publication.sql';
const reviewer = randomUUID();
let db;

async function createAccount({
  id = randomUUID(), ageHours = 48, rescuer = false, anonymous = false, deleted = false,
} = {}) {
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data,created_at,is_anonymous,deleted_at)
    values($1,$2,now(),$3,now()-$4*interval '1 hour',$5,case when $6 then now() end)`,
  [id, `${id}@example.test`, JSON.stringify({ intent: rescuer ? 'rescue' : 'adopt', is_admin: true }),
    ageHours, anonymous, deleted]);
  return id;
}

async function actor(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
  await db.exec(`set local role ${role}`);
}

async function report() {
  return (await db.query('select public.dopmi_admin_first_publication() as report')).rows[0].report;
}

async function denied() {
  await db.exec('savepoint denied_report');
  try {
    await assert.rejects(report(), { code: '42501' });
  } finally {
    await db.exec('rollback to savepoint denied_report; release savepoint denied_report');
  }
}

async function listing(owner, { status = 'draft', ageHours = 28, photo = false,
  submittedHours = null, publishedHours = null } = {}) {
  const id = randomUUID();
  await db.query(`insert into public.dopmi_adoptions(id,owner_id,pet_name,photos,status,created_at,submitted_at,published_at)
    values($1,$2,'Mascota sintética',$3,$4,now()-$5*interval '1 hour',
      now()-$6*interval '1 hour',now()-$7*interval '1 hour')`,
  [id, owner, photo ? [`${owner}/${id}/photo.jpg`] : [], status, ageHours, submittedHours, publishedHours]);
  return id;
}

function metrics({ generated_at, window_started_at, ...counts }) {
  assert.equal(Date.parse(generated_at) - Date.parse(window_started_at), 7 * 24 * 60 * 60 * 1000);
  return counts;
}

before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.identities(user_id uuid,provider text,provider_id text);
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',
      email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz,
      created_at timestamptz not null default now(),is_anonymous boolean not null default false,deleted_at timestamptz);
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
    if (file === migration) {
      await db.exec('alter default privileges in schema public grant execute on functions to anon, authenticated, service_role');
    }
    try {
      await db.exec(await readFile(new URL(file, directory), 'utf8'));
    } catch (error) {
      throw new Error(`Migration ${file}: ${error.code}: ${error.message}`, { cause: error });
    }
  }
  await createAccount({ id: reviewer, ageHours: 240 });
  await db.query('insert into private.admin_memberships(user_id) values($1)', [reviewer]);
}, { timeout: 120000 });

after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('report requires an active administrator and revokes inherited API execution grants', async () => {
  const ordinaryAccount = await createAccount();
  await actor(null, 'anon');
  await denied();
  await actor(reviewer, 'service_role');
  await denied();
  await actor(ordinaryAccount);
  await denied();
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1", [reviewer]);
  await actor(reviewer);
  await denied();
});

test('empty cohort and queue return numeric zeroes and no review age', async () => {
  await actor(reviewer);
  assert.deepEqual(metrics(await report()), {
    accounts_created: 0,
    rescuer_mode_accounts: 0,
    authors_with_drafts: 0,
    authors_with_photo: 0,
    authors_with_submissions: 0,
    authors_with_publications: 0,
    first_reviews_pending: 0,
    oldest_first_review_hours: null,
    stalled_draft_authors: 0,
  });
});

test('cohort counts each author once, flags stalled drafts, and measures original reviews globally', async () => {
  const stalled = await createAccount({ rescuer: true });
  await listing(stalled, { ageHours: 30 });
  await listing(stalled, { ageHours: 29 });

  const recentDraft = await createAccount({ rescuer: true });
  await listing(recentDraft, { ageHours: 5 });

  const withPhoto = await createAccount({ rescuer: true });
  await listing(withPhoto);
  await listing(withPhoto, { ageHours: 4, photo: true });

  const pending = await createAccount({ ageHours: 72 });
  await listing(pending, { status: 'submitted', ageHours: 46, submittedHours: 31.5 });

  const reviewed = await createAccount();
  const reviewedDraft = await listing(reviewed);
  await db.query(`insert into private.dopmi_adoption_reviews(post_id,actor_id,decision,feedback,version)
    values($1,$2,'changes_requested','Ajuste sintético',2)`, [reviewedDraft, reviewer]);

  const published = await createAccount({ ageHours: 96, rescuer: true });
  const publishedListing = await listing(published, {
    status: 'published', ageHours: 76, submittedHours: 74, publishedHours: 70,
  });
  await db.query(`insert into private.dopmi_adoption_edits(id,owner_id,status,submitted_at)
    values($1,$2,'submitted',now()-interval '65 hours')`, [publishedListing, published]);

  await createAccount();
  const oldAccount = await createAccount({ ageHours: 169 });
  await listing(oldAccount, { status: 'submitted', ageHours: 70, submittedHours: 59.5 });
  await createAccount({ anonymous: true, rescuer: true });
  await createAccount({ deleted: true, rescuer: true });

  await actor(reviewer);
  assert.deepEqual(metrics(await report()), {
    accounts_created: 7,
    rescuer_mode_accounts: 4,
    authors_with_drafts: 6,
    authors_with_photo: 1,
    authors_with_submissions: 3,
    authors_with_publications: 1,
    first_reviews_pending: 2,
    oldest_first_review_hours: 59,
    stalled_draft_authors: 1,
  });
});
