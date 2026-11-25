import { after, before, beforeEach, afterEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { setTimeout as pause } from 'node:timers/promises';

const migration = '20261125222901_adoption_detail_reports.sql';
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
const view = () => db.query('select public.dopmi_record_adoption_detail_view($1,true)', [post]);
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

test('detail views require consent and deduplicate people independently from card impressions', async () => {
  await actor(visitor); await view();
  await db.exec('select public.dopmi_set_adoption_measurement(true)');
  await db.query('select public.dopmi_record_adoption_view($1,true)', [post]);
  await actor(staff); assert.equal((await report()).items[0].detail_viewers, 0);
  await actor(visitor); await view(); await view();
  await actor(second); await db.exec('select public.dopmi_set_adoption_measurement(true)'); await view();
  await actor(owner); await db.exec('select public.dopmi_set_adoption_measurement(true)'); await view();
  await actor(staff);
  const page = await report();
  assert.equal(page.items[0].detail_viewers, 2);
  assert.ok(page.detail_tracking_started_at);
  assert.deepEqual(Object.keys(page.items[0]).sort(), ['id','pet_name','species','publisher_name','city','region','published_at','detail_viewers','current_favorites','contacts','first_replies'].sort());
});

test('report counts current favorites and distinct contacting people, and owner replies once per conversation', async () => {
  await actor(visitor);
  await db.query('select public.dopmi_set_favorite($1,true)', [post]);
  const thread = await value('select public.dopmi_start_adoption_contact($1) value', [post]);
  await db.query('select public.dopmi_send_message($1,$2,$3)', [thread, randomUUID(), 'Mensaje sintético']);
  await actor(second);
  await db.query('select public.dopmi_set_favorite($1,true)', [post]);
  const another = await value('select public.dopmi_start_adoption_contact($1) value', [post]);
  await db.query('select public.dopmi_set_favorite($1,false)', [post]);
  await actor(owner); await db.query('select public.dopmi_read_thread($1)', [another]);
  await actor(staff); assert.equal((await report()).items[0].first_replies, 0);
  await actor(owner);
  const message = randomUUID();
  for (const id of [message, message, randomUUID()]) await db.query('select public.dopmi_send_message($1,$2,$3)', [thread, id, 'Respuesta sintética']);
  await db.query('select public.dopmi_close_thread($1)', [thread]);
  await actor(staff);
  const row = (await report()).items[0];
  assert.equal(row.current_favorites, 1); assert.equal(row.contacts, 2); assert.equal(row.first_replies, 1);
});

test('only published adoptions from active owners are reported, with literal search, species and pagination', async () => {
  await db.query("insert into public.dopmi_adoptions(owner_id,pet_name,species,status) values($1,'Michi','cat','published'),($1,'Pendiente','dog','submitted'),($1,'Adoptada','dog','adopted')", [owner]);
  await actor(staff);
  assert.equal((await report()).total, 2);
  assert.equal((await report('', 'cat')).items[0].pet_name, 'Michi');
  assert.equal((await report('Luna')).total, 1); assert.equal((await report('%')).total, 0);
  await denied(() => report('', 'bird'), '22023'); await denied(() => report('', '', 0), '22023');
  await db.exec('reset role');
  await db.query("insert into public.dopmi_adoptions(owner_id,pet_name,status) select $1,'Mascota '||n,'published' from generate_series(1,22)n", [owner]);
  await actor(staff);
  const first = await report(), next = await report('', '', 2);
  assert.equal(first.total, 24); assert.equal(first.items.length, 20); assert.equal(next.items.length, 4);
  assert.equal(new Set([...first.items, ...next.items].map(p => p.id)).size, 24);
  await db.exec('reset role'); await db.query("update public.profiles set account_status='suspended' where id=$1", [owner]);
  await actor(staff); assert.equal((await report()).total, 0);
});

test('server authorization rejects ordinary metadata admins, anonymous and revoked members, without granting chat access', async () => {
  await actor(visitor);
  await value('select public.dopmi_start_adoption_contact($1) value', [post]);
  await denied(() => report());
  await denied(() => db.exec('select * from private.dopmi_adoption_detail_views'));
  await actor(null, 'anon'); await denied(() => report()); await denied(() => view());
  await actor(staff);
  assert.equal(await value('select count(*)::int value from public.dopmi_messages'), 0);
  await report();
  await db.exec('reset role');
  assert.equal(await value("select count(*)::int value from private.admin_access_log where action='adoptions.report'"), 1);
  await db.query('update private.admin_memberships set active=false where user_id=$1', [staff]);
  await actor(staff); await denied(() => report());
});

test('withdrawing consent erases detail observations and late requests remain uncounted', async () => {
  await actor(visitor); await db.exec('select public.dopmi_set_adoption_measurement(true)'); await view();
  await actor(staff); assert.equal((await report()).items[0].detail_viewers, 1);
  await actor(visitor); await db.exec('select public.dopmi_set_adoption_measurement(false)'); await view();
  await actor(staff); assert.equal((await report()).items[0].detail_viewers, 0);
  await actor(visitor); await db.exec('select public.dopmi_set_adoption_measurement(true)');
  await db.query('select public.dopmi_record_adoption_detail_view($1,false)', [post]);
  await actor(staff); assert.equal((await report()).items[0].detail_viewers, 0);
});

for (const confirmed of [false, true]) {
  test(`first replies include ${confirmed ? 'server-confirmed replies with transaction-start timestamp inversion' : 'closed historical conversations with unknown legacy origin'}`, async () => {
    const thread = randomUUID();
    await db.query("insert into public.dopmi_threads(id,post_id,owner_id,adopter_id,pet_name,status) values($1,$2,$3,$4,'Luna','closed')", [thread, post, owner, visitor]);
    await db.query("insert into public.dopmi_messages(id,thread_id,sender_id,body,origin,created_at) values($1,$2,$3,'Contacto sintético','unknown',now()-interval '2 hours')", [randomUUID(),thread,visitor]);
    await db.query("insert into public.dopmi_messages(id,thread_id,sender_id,body,origin,is_adoption_reply,created_at) values($1,$2,$3,'Respuesta sintética',$4,$5,now()-$6*interval '1 hour')", [randomUUID(),thread,owner,confirmed?'user':'unknown',confirmed?true:null,confirmed?3:1]);
    await actor(staff); const row = (await report()).items[0];
    assert.equal(row.contacts, 1); assert.equal(row.first_replies, 1);
  });
}

test('unpublished details and suspended actors cannot add observations', async () => {
  await actor(visitor); await db.exec('select public.dopmi_set_adoption_measurement(true)');
  await db.exec('reset role'); await db.query("update public.dopmi_adoptions set status='draft' where id=$1", [post]);
  await actor(visitor); await view();
  await db.exec('reset role'); await db.query("update public.dopmi_adoptions set status='published' where id=$1", [post]);
  await db.query("update public.profiles set account_status='suspended' where id=$1", [visitor]);
  await actor(visitor); await denied(() => view());
  await actor(staff); assert.equal((await report()).items[0].detail_viewers, 0);
});

test('PostgreSQL concurrent devices deduplicate and consent withdrawal wins a waiting observation',
  { skip: !postgresDatabase }, async () => {
    await actor(visitor); await db.exec('select public.dopmi_set_adoption_measurement(true)');
    await db.exec('reset role; commit');
    const connect = async () => {
      const client = new pg.Client({ host:'127.0.0.1',port:54322,database:postgresDatabase,user:'postgres',password:'postgres' });
      await client.connect(); return client;
    };
    const first = await connect(), next = await connect();
    const begin = async client => {
      await client.query('begin');
      await client.query("select set_config('request.jwt.claim.sub',$1,true)",[visitor]);
      await client.query('set local role authenticated');
    };
    try {
      await Promise.all([first,next].map(async client => {
        await begin(client);
        await client.query('select public.dopmi_record_adoption_detail_view($1,true)',[post]);
        await client.query('commit');
      }));
      assert.equal(await value('select count(*)::int value from private.dopmi_adoption_detail_views where post_id=$1',[post]),1);
      await begin(first);
      await first.query('select public.dopmi_set_adoption_measurement(false)');
      await begin(next);
      const pending = next.query('select public.dopmi_record_adoption_detail_view($1,true)',[post]);
      // Observe the actual lock instead of treating elapsed time as proof.
      let waiting = false;
      for (let attempt=0;attempt<100;attempt++) {
        waiting = await value("select coalesce(wait_event_type='Lock',false) value from pg_stat_activity where pid=$1",[next.processID]);
        if (waiting) break;
        await pause(10);
      }
      assert.equal(waiting,true);
      await first.query('commit'); await pending; await next.query('commit');
      assert.equal(await value('select count(*)::int value from private.dopmi_adoption_detail_views where post_id=$1',[post]),0);
    } finally {
      await Promise.all([first,next].map(async client => { await client.query('rollback'); await client.end(); }));
      await db.exec('begin');
    }
  });
