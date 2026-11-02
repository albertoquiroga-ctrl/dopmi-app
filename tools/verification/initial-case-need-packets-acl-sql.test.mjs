import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

// Reproduce the catalog-only PROD precondition locally. No identity, record,
// provider, remote connection or financial instruction is created by this test.
const initial = '20261102172057_initial_case_need_packets.sql';
const repair = '20261102183408_restore_initial_packet_server_acl.sql';
const restored = [
  'public.dopmi_transition_rescue(uuid,integer,text)',
  'public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean)',
  'public.dopmi_rescue_file_access(text,boolean)',
].sort();
const joint = 'public.dopmi_review_initial_case_packet(uuid,integer,uuid,text,text,boolean,jsonb,uuid)';
let db, baselinePrivileges, fault, fixed;
const value = async (sql, args = []) => (await db.query(sql, args)).rows[0]?.value;
async function inventory() {
  return {
    functions: (await db.query(`select n.nspname||'.'||p.proname||'('||replace(oidvectortypes(p.proargtypes),', ', ',')||')' signature,p.oid::text oid,
      pg_get_functiondef(p.oid) definition,p.proacl::text acl,
      has_function_privilege('anon',p.oid,'execute') anon,
      has_function_privilege('authenticated',p.oid,'execute') authenticated,
      has_function_privilege('service_role',p.oid,'execute') service_role
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname in ('public','private') order by p.oid`)).rows,
    tables: (await db.query(`select c.oid::text oid,c.relacl::text acl,c.relrowsecurity rls,
      c.relforcerowsecurity force_rls from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in ('public','private','storage') order by c.oid`)).rows,
    services: await value(`select jsonb_build_object(
      'environment',(select environment from private.dopmi_payment_environment where singleton),
      'video',(select enabled from private.dopmi_video_settings where singleton),
      'store',(select enabled from private.dopmi_store_settings where singleton)) value`),
  };
}
async function servicePrivileges() {
  return Promise.all(restored.map(signature => value("select has_function_privilege('service_role',$1,'execute') value", [signature])));
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
    if (file === initial) {
      // These three grants existed in the actual PROD preflight. They were not
      // present in the old local bootstrap, which hid the ACL regression.
      for (const signature of restored) await db.exec(`grant execute on function ${signature} to service_role`);
      baselinePrivileges = await servicePrivileges();
    }
    if (file === repair) fault = await inventory();
    await db.exec(await readFile(new URL(file, directory), 'utf8'));
    if (file === repair) fixed = await inventory();
  }
}, { timeout: 120000 });
after(async () => db?.close());

test('reproduce the observed PROD grants and restore exactly the three lost EXECUTE entries', async () => {
  assert.deepEqual(baselinePrivileges, [true, true, true]);
  const faults = fault.functions.filter(f => restored.includes(f.signature));
  assert.equal(faults.length, 3); assert.ok(faults.every(f => f.service_role === false));
  const changed = fixed.functions.filter(f => f.acl !== fault.functions.find(previous => previous.oid === f.oid)?.acl);
  assert.deepEqual(changed.map(f => f.signature).sort(), restored);
  assert.ok(changed.every(f => f.service_role === true));
  assert.deepEqual(await servicePrivileges(), [true, true, true]);
});

test('repair changes no function body/OID, other role access, tables, settings or new packet/delegate grants', async () => {
  const withoutChangedAcl = entries => entries.map(({ acl, service_role, ...entry }) => entry);
  assert.deepEqual(withoutChangedAcl(fixed.functions), withoutChangedAcl(fault.functions));
  assert.deepEqual(fixed.tables, fault.tables); assert.deepEqual(fixed.services, fault.services);
  for (const f of fixed.functions) {
    if (!restored.includes(f.signature)) assert.equal(f.acl, fault.functions.find(previous => previous.oid === f.oid).acl);
    if (f.signature === joint || /dopmi_initial_case_|_before_initial_packet\(/.test(f.signature)) assert.equal(f.service_role, false, f.signature);
  }
  assert.equal(await value("select has_function_privilege('service_role',$1,'execute') value", [joint]), false);
});

test('service role reaches existing guarded bodies but cannot execute the joint packet API', async () => {
  await db.exec('begin; set local role service_role');
  try {
    assert.equal(await value("select public.dopmi_rescue_file_access('invalid') value"), false);
    await db.exec('savepoint transition_guard');
    await assert.rejects(() => value("select public.dopmi_transition_rescue(null,1,'submit') value"),
      error => error.code === '42501' && /Cuenta activa y confirmada requerida/.test(error.message));
    await db.exec('rollback to savepoint transition_guard');
    await db.exec('savepoint review_guard');
    await assert.rejects(() => value("select public.dopmi_review_rescue(null,1,'approved','Sin identidad',0,false,'',true) value"),
      error => error.code === '42501' && /Acceso administrativo requerido/.test(error.message));
    await db.exec('rollback to savepoint review_guard');
    await db.exec('savepoint joint_acl');
    await assert.rejects(() => value(`select public.dopmi_review_initial_case_packet(null,1,null,'approved',
      'Sin identidad',true,'[]',null) value`), error => error.code === '42501' && /permission denied/.test(error.message));
    await db.exec('rollback to savepoint joint_acl');
  } finally { await db.exec('rollback'); }
});
