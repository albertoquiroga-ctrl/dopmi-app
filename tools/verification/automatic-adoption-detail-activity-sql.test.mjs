import { after, before, beforeEach, afterEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { setTimeout as pause } from 'node:timers/promises';

const migration = '20261126202302_automatic_adoption_detail_activity.sql';
const owner = randomUUID(), visitor = randomUUID(), second = randomUUID(), staff = randomUUID();
const managePostgres = process.env.DOPMI_REPORT_POSTGRES_TEST === 'true';
const postgresDatabase = process.env.DOPMI_REPORT_POSTGRES_DATABASE
  || (managePostgres ? 'dopmi_reports_' + randomUUID().replaceAll('-', '') : null);
let db, post, postgresAdmin, createdDatabase = false;
const value = async (sql, params = []) => (await db.query(sql, params)).rows[0]?.value;
async function actor(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
  await db.exec('set local role ' + role);
}
const report = (search = '', species = '', page = 1) => value(
  'select public.dopmi_admin_adoption_report($1,$2,$3) value', [search, species, page]);
const view = () => db.query('select public.dopmi_record_adoption_detail_activity($1)', [post]);
async function denied(operation, code = '42501') {
  await db.exec('savepoint rejected');
  await assert.rejects(operation, { code });
  await db.exec('rollback to savepoint rejected; release savepoint rejected');
}
before(async () => {
  if (postgresDatabase) {
    if (!/^dopmi_reports_[a-z0-9_]+$/.test(postgresDatabase)) throw new Error('Only an isolated local report test database is allowed');
    if (managePostgres) {
      postgresAdmin = new pg.Client({host:'127.0.0.1',port:54322,database:'postgres',user:'postgres',password:'postgres'});
      await postgresAdmin.connect();
      await postgresAdmin.query('create database ' + postgresDatabase);
      createdDatabase = true;
    }
    const client = new pg.Client({ host: '127.0.0.1', port: 54322, database: postgresDatabase, user: 'postgres', password: 'postgres' });
    await client.connect();
    db = { query: (sql, params) => client.query(sql, params), exec: sql => client.query(sql), close: () => client.end() };
  } else {
    db = new PGlite();
    await db.exec('create role anon; create role authenticated; create role service_role;');
  }
  await db.exec(`
    create schema auth; create schema storage; create schema extensions;
    create table auth.identities(user_id uuid,provider text,provider_id text);
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',
      email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz,
      created_at timestamptz default now(),is_anonymous boolean default false,deleted_at timestamptz);
    create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id) on delete cascade,not_after timestamptz);
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
    await db.exec(await readFile(new URL(file, directory), 'utf8'));
  }
  for (const id of [owner, visitor, second, staff]) {
    await db.query('insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3)',
      [id, id + '@example.test', { display_name: 'Persona sintética', terms_version: 'terms-2026-10-17', privacy_version: 'privacy-2026-10-17', adult_confirmed: true, is_admin: true }]);
  }
  await db.query('insert into private.admin_memberships(user_id) values($1)', [staff]);
}, { timeout: 120000 });
after(async () => {
  try { await db?.close(); }
  finally {
    if (createdDatabase) await postgresAdmin.query('drop database ' + postgresDatabase);
    await postgresAdmin?.end();
  }
});
beforeEach(async () => {
  await db.exec('begin');
  post = randomUUID();
  await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status,publisher_name) values($1,$2,'Luna','published','Rescatista sintética')", [post, owner]);
});
afterEach(async () => db.exec('rollback'));


test('operational detail counts without an optional analytics choice and deduplicates people', async () => {
  await actor(visitor); await view(); await view();
  await actor(staff); assert.equal((await report()).items[0].detail_viewers, 1);
  await actor(second); await view();
  await actor(staff); assert.equal((await report()).items[0].detail_viewers, 2);
});

test('legacy and operational visits deduplicate while legacy withdrawal remains effective', async () => {
  const legacyPost = randomUUID();
  await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status,publisher_name) values($1,$2,'Anterior','published','Rescatista sintética')", [legacyPost,owner]);
  await actor(visitor);
  await db.exec('select public.dopmi_set_adoption_measurement(true)');
  for (const id of [post,legacyPost]) await db.query('select public.dopmi_record_adoption_detail_view($1,true)',[id]);
  await view();
  await actor(staff);
  assert.deepEqual((await report()).items.map(row => row.detail_viewers),[1,1]);
  await actor(visitor); await db.exec('select public.dopmi_set_adoption_measurement(false)');
  await actor(staff);
  const rows=(await report()).items;
  assert.equal(rows.find(row=>row.id===post).detail_viewers,1);
  assert.equal(rows.find(row=>row.id===legacyPost).detail_viewers,0);
});

test('an explicit analytics OFF does not prevent operational visits or enable analytics', async () => {
  await actor(visitor); await db.exec('select public.dopmi_set_adoption_measurement(false)'); await view();
  assert.equal((await value('select public.dopmi_adoption_measurement_state() value')).consent,false);
  await actor(staff); assert.equal((await report()).items[0].detail_viewers,1);
});

test('owners, drafts, missing posts and suspended listing owners do not add visits', async () => {
  await actor(owner); await view();
  await actor(visitor); await db.query('select public.dopmi_record_adoption_detail_activity($1)',[randomUUID()]);
  await db.exec('reset role'); await db.query("update public.dopmi_adoptions set status='draft' where id=$1",[post]);
  await actor(visitor); await view();
  await db.exec('reset role'); await db.query("update public.dopmi_adoptions set status='published' where id=$1",[post]);
  await db.query("update public.profiles set account_status='suspended' where id=$1",[owner]);
  await actor(visitor); await view();
  await db.exec('reset role'); await db.query("update public.profiles set account_status='active' where id=$1",[owner]);
  await actor(staff); assert.equal((await report()).items[0].detail_viewers,0);
});

test('anonymous and suspended actors are denied; private activity and chat remain inaccessible to admins', async () => {
  await actor(null,'anon'); await denied(()=>view());
  await actor(visitor); await view();
  await denied(()=>db.exec('select * from private.dopmi_adoption_detail_activity'));
  await db.exec('reset role'); await db.query("update public.profiles set account_status='suspended' where id=$1",[second]);
  await actor(second); await denied(()=>view());
  await actor(visitor); await value('select public.dopmi_start_adoption_contact($1) value',[post]);
  await denied(()=>report());
  await actor(staff);
  assert.equal(await value('select count(*)::int value from public.dopmi_messages'),0);
  const row=(await report()).items[0];
  assert.equal(row.detail_viewers,1); assert.equal(row.contacts,1); assert.equal(row.first_replies,0);
  await denied(()=>db.exec('select * from private.dopmi_adoption_detail_activity'));
});

for (const deletion of ['profile','auth']) {
  test(`${deletion} deletion removes operational visits`, async () => {
    await actor(visitor); await view();
    await actor(staff); assert.equal((await report()).items[0].detail_viewers,1);
    await db.exec('reset role');
    if(deletion==='profile') await db.query("update public.profiles set account_status='deleted' where id=$1",[visitor]);
    else await db.query('delete from auth.users where id=$1',[visitor]);
    await actor(staff); assert.equal((await report()).items[0].detail_viewers,0);
    await actor(visitor); await denied(()=>view());
  });
}

async function pgClient() {
  const client=new pg.Client({host:'127.0.0.1',port:54322,database:postgresDatabase,user:'postgres',password:'postgres'});
  await client.connect(); return client;
}
async function pgActor(client) {
  await client.query('begin');
  await client.query("select set_config('request.jwt.claim.sub',$1,true)",[visitor]);
  await client.query('set local role authenticated');
}
test('PostgreSQL simultaneous devices count one person', {skip:!postgresDatabase}, async () => {
  await db.exec('reset role; commit');
  const first=await pgClient(),next=await pgClient();
  let mainTransaction=false;
  try {
    await Promise.all([first,next].map(async client=>{
      await pgActor(client);
      await client.query('select public.dopmi_record_adoption_detail_activity($1)',[post]);
      await client.query('commit');
    }));
    await db.exec('begin'); mainTransaction=true;
    await actor(staff); assert.equal((await report()).items[0].detail_viewers,1);
  } finally {
    await Promise.all([first,next].map(async client=>{await client.query('rollback');await client.end();}));
    if(!mainTransaction) await db.exec('begin');
  }
});
test('PostgreSQL account deletion can take its canonical auth then profile locks before a waiting visit',
  {skip:!postgresDatabase}, async () => {
    await db.exec('reset role; commit');
    const deletion=await pgClient(),recording=await pgClient();
    let pending,mainTransaction=false;
    try {
      await deletion.query('begin');
      await deletion.query('select id from auth.users where id=$1 for update',[visitor]);
      await pgActor(recording);
      pending=recording.query('select public.dopmi_record_adoption_detail_activity($1)',[post]);
      let waiting=false;
      for(let attempt=0;attempt<100;attempt++) {
        waiting=await value("select coalesce(wait_event_type='Lock',false) value from pg_stat_activity where pid=$1",[recording.processID]);
        if(waiting) break;
        await pause(10);
      }
      assert.equal(waiting,true,'recorder must wait for the locked Auth actor');
      // This is the actual deletion lock order, not a timeout treated as success.
      // The recorder must not already retain a conflicting profile lock.
      await deletion.query('select id from public.profiles where id=$1 for update nowait',[visitor]);
      await deletion.query("update public.profiles set account_status='deleted' where id=$1",[visitor]);
      await deletion.query('commit');
      await pending;
      await recording.query('commit');
      await db.exec('begin'); mainTransaction=true;
      await actor(staff); assert.equal((await report()).items[0].detail_viewers,0);
    } finally {
      await deletion.query('rollback');
      await pending?.catch(()=>{});
      await recording.query('rollback');
      await Promise.all([deletion,recording].map(client=>client.end()));
      if(!mainTransaction) await db.exec('begin');
    }
  });
