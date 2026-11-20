import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { setTimeout as pause } from 'node:timers/promises';
import { pathToFileURL } from 'node:url';
import pg from 'pg';

const sealMigration = '20261117214500_rescuer_seal_profile.sql';
const bucket = 'dopmi-rescuer-profile-media';

// Exported only to validate the bootstrap with an in-memory engine separately.
// That validation is not evidence of overlapping PostgreSQL transactions.
export const bootstrapSql = `
  create schema auth; create schema storage;
  create table auth.users(
    id uuid primary key,email text,raw_user_meta_data jsonb default '{}',
    email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,
    phone_confirmed_at timestamptz,created_at timestamptz default now(),deleted_at timestamptz
  );
  create table auth.identities(user_id uuid,provider text,provider_id text);
  create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
  create function auth.uid() returns uuid language sql stable as
    $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  create function auth.jwt() returns jsonb language sql stable as
    $$select jsonb_build_object('role',current_setting('role',true),
      'sub',nullif(current_setting('request.jwt.claim.sub',true),''),
      'session_id',nullif(current_setting('request.jwt.claim.session_id',true),''))$$;
  grant usage on schema auth,public to anon,authenticated,service_role;
  create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
  create table storage.objects(
    id uuid primary key default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb,
    unique(bucket_id,name)
  );
  alter table storage.objects enable row level security;
  grant usage on schema storage to anon,authenticated;
  grant select on storage.objects to anon;
  grant select,insert,update,delete on storage.objects to authenticated;
`;

export async function loadSealSchema(execute) {
  await execute(bootstrapSql);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  const files = (await readdir(directory))
    .filter(file => file.endsWith('.sql') && file <= sealMigration).sort();
  assert.ok(files.includes(sealMigration), 'The frozen seal migration must be present');
  for (const file of files) await execute(await readFile(new URL(file, directory), 'utf8'));
  return files.length;
}

export function assertLocalEnvironment(environment = process.env) {
  assert.equal(environment.DOPMI_RESCUER_SEAL_POSTGRES_TEST, 'true', 'Explicit disposable PostgreSQL opt-in is required');
  assert.equal(environment.PGPASSWORD, 'postgres', 'Only disposable CI PGPASSWORD=postgres is supported');
}

const metadata = {
  display_name: 'Sello sintético', intent: 'rescue', terms_version: 'terms-2026-10-17',
  privacy_version: 'privacy-2026-10-17', adult_confirmed: true,
};
const value = async (client, sql, params = []) => (await client.query(sql, params)).rows[0]?.value;

export async function seedSealFixture(client) {
  const owner = randomUUID(), session = randomUUID();
  const path = `${owner}/${owner}/${randomUUID()}.jpg`;
  await client.query(`insert into auth.users(id,email,phone,email_confirmed_at,phone_confirmed_at,raw_user_meta_data)
    values($1,$2,'528100010101',now(),now(),$3::jsonb)`, [owner, `${owner}@example.test`, JSON.stringify(metadata)]);
  await client.query('insert into auth.sessions(id,user_id) values($1,$2)', [session, owner]);
  await client.query(`insert into public.dopmi_rescuer_profiles(owner_id,display_name,avatar_path,instagram_url)
    values($1,'Refugio sintético',$2,'https://www.instagram.com/refugio.test')`, [owner, path]);
  await client.query('insert into storage.objects(bucket_id,name,owner_id) values($1,$2,$3)', [bucket, path, owner]);
  return { owner, session, path };
}

export async function beginOwner(client, fixture) {
  await client.query('begin isolation level read committed');
  // Match the transaction context used by Storage's SQL metadata operation.
  // This runner does not invoke the Storage HTTP API or upload/delete a blob.
  await client.query("set local storage.allow_delete_query='true'");
  await client.query("select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.session_id',$2,true)", [fixture.owner, fixture.session]);
  await client.query('set local role authenticated');
  assert.equal(await value(client, "select current_user='authenticated' and row_security_active('storage.objects'::regclass) value"), true,
    'The actual Storage DELETE must run with active RLS as authenticated');
}

const discard = (client, fixture) => client.query(
  'delete from storage.objects where bucket_id=$1 and name=$2 returning id,name', [bucket, fixture.path],
);
const submit = (client) => value(client, 'select public.dopmi_submit_rescuer_seal() value');
const objects = (client, fixture) => value(client,
  'select count(*)::int value from storage.objects where bucket_id=$1 and name=$2', [bucket, fixture.path]);
const requests = (client, fixture) => value(client,
  "select count(*)::int value from public.dopmi_rescue_records where owner_id=$1 and kind='verification'", [fixture.owner]);

export async function run() {
  assertLocalEnvironment();
  // No environment URL/host/database is consumed. Only a new database on the
  // disposable CI engine is touched; existing Supabase application rows are not read.
  const config = { host: '127.0.0.1', port: 54322, user: 'postgres', database: 'postgres',
    password: 'postgres', ssl: false, connectionTimeoutMillis: 5000,
    options: '-c timezone=UTC -c statement_timeout=25000 -c lock_timeout=20000' };
  const database = `dopmi_seal_test_${randomUUID().replaceAll('-', '')}`;
  assert.match(database, /^dopmi_seal_test_[0-9a-f]{32}$/);
  const admin = new pg.Client(config);
  const clients = ['control', 'submitting', 'deleting'].map(name => new pg.Client({
    ...config, database, application_name: `${database}_${name}`,
  }));
  const [control, submitting, deleting] = clients;
  const connected = [];
  let adminConnected = false, created = false, pending, migrations;
  function track(operation) {
    const state = { completed: false };
    state.result = operation.then(
      result => { state.completed = true; return { result }; },
      error => { state.completed = true; return { error }; },
    );
    pending = state.result;
    return state;
  }
  async function blocked(waiter, blocker, operation) {
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      const row = (await control.query(`select wait_event_type,wait_event,
        $2::int=any(pg_blocking_pids(pid)) blocked from pg_stat_activity where pid=$1`,
      [waiter.processID, blocker.processID])).rows[0];
      if (row?.blocked && row.wait_event_type === 'Lock' && row.wait_event === 'advisory') return;
      assert.equal(operation.completed, false, 'The competing operation completed without the expected rescue lock overlap');
      await pause(25);
    }
    assert.fail('Expected independent PostgreSQL backends to overlap on the rescue advisory lock');
  }
  try {
    await admin.connect(); adminConnected = true;
    assert.equal(admin.connectionParameters.host, '127.0.0.1');
    assert.equal(admin.connectionParameters.port, 54322);
    const role = (await admin.query("select rolbypassrls,rolsuper from pg_roles where rolname='authenticated'")).rows[0];
    assert.deepEqual(role, { rolbypassrls: false, rolsuper: false }, 'The CI authenticated role must not bypass RLS');
    await admin.query(`create database "${database}" template template0`); created = true;
    for (const client of clients) { await client.connect(); connected.push(client); }
    assert.notEqual(submitting.processID, deleting.processID);
    migrations = await loadSealSchema(sql => control.query(sql));
    assert.equal(await value(control, "select provolatile='v' value from pg_proc where oid='public.dopmi_rescuer_profile_file_access(text,boolean)'::regprocedure"), true);
    const policies = (await control.query(`select policyname,cmd,permissive from pg_policies
      where schemaname='storage' and tablename='objects'
      and policyname in ('dopmi_rescuer_profile_files_read','dopmi_rescuer_profile_files_delete','dopmi_rescuer_profile_delete_boundary')
      order by policyname`)).rows;
    assert.deepEqual(policies, [
      { policyname: 'dopmi_rescuer_profile_delete_boundary', cmd: 'DELETE', permissive: 'RESTRICTIVE' },
      { policyname: 'dopmi_rescuer_profile_files_delete', cmd: 'DELETE', permissive: 'PERMISSIVE' },
      { policyname: 'dopmi_rescuer_profile_files_read', cmd: 'SELECT', permissive: 'PERMISSIVE' },
    ], 'Exercise the product Storage policies, without substituting a helper-only check');
    assert.equal(await value(control, "select has_table_privilege('authenticated','storage.objects','DELETE') value"), true);
    const first = await seedSealFixture(control), second = await seedSealFixture(control);

    // The other synthetic actor cannot read or delete the first actor's photo.
    await beginOwner(deleting, second);
    assert.equal(await objects(deleting, first), 0);
    assert.equal((await discard(deleting, first)).rowCount, 0);
    await deleting.query('rollback');
    assert.equal(await objects(control, first), 1);
    for (const fixture of [first, second]) {
      await beginOwner(submitting, fixture);
      assert.deepEqual((await value(submitting, 'select public.dopmi_rescuer_seal_status() value')).missing, []);
      assert.equal(await objects(submitting, fixture), 1);
      await submitting.query('commit');
    }

    // Submission owns the rescue lock. The DELETE statement begins before
    // commit, so the VOLATILE policy must re-read the newly submitted seal.
    await beginOwner(submitting, first);
    const submitted = await submit(submitting);
    assert.equal(submitted.status, 'submitted');
    await beginOwner(deleting, first);
    const waitingDelete = track(discard(deleting, first));
    await blocked(deleting, submitting, waitingDelete);
    await submitting.query('commit');
    const deniedDelete = await waitingDelete.result; pending = undefined;
    assert.equal(deniedDelete.error, undefined);
    assert.equal(deniedDelete.result.rowCount, 0, 'A photo pinned by the submitted seal cannot be deleted');
    await deleting.query('commit');
    assert.equal(await objects(control, first), 1);
    assert.equal(await requests(control, first), 1);
    assert.equal(await value(control, 'select status value from public.dopmi_rescue_records where id=$1', [submitted.record_id]), 'submitted');

    // An actual authorized DELETE owns the same lock, then remains uncommitted.
    // Submission must wait and must see the committed absence of that object.
    await beginOwner(deleting, second);
    assert.equal((await discard(deleting, second)).rowCount, 1);
    await beginOwner(submitting, second);
    const waitingSubmit = track(submit(submitting));
    await blocked(submitting, deleting, waitingSubmit);
    await deleting.query('commit');
    const missingPhoto = await waitingSubmit.result; pending = undefined;
    assert.equal(missingPhoto.error, undefined);
    assert.equal(missingPhoto.result.status, 'not_started');
    assert.equal(missingPhoto.result.record_id, null);
    assert.deepEqual(missingPhoto.result.missing, ['photo']);
    await submitting.query('commit');
    assert.equal(await objects(control, second), 0);
    assert.equal(await requests(control, second), 0, 'Missing evidence must not create even a draft seal request');
  } finally {
    try {
      await Promise.allSettled(connected.filter(client => client !== control).map(client => client.query('rollback')));
      if (pending) await pending;
    } finally {
      await Promise.allSettled(connected.map(client => client.end()));
      try {
        if (created) await admin.query(`drop database "${database}"`);
      } finally {
        if (adminConnected) await admin.end();
      }
    }
  }
  console.log(`Rescuer seal PostgreSQL: 2 observed advisory-lock races passed through real Storage RLS (${migrations} migrations); isolated database dropped; no Storage HTTP/blob acceptance claimed`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await run();
