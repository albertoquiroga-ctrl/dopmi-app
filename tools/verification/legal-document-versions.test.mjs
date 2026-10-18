import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { randomUUID } from 'node:crypto';

// Only this suite's new disposable database; no remote URL or existing app DB.
const real = process.env.DOPMI_LEGAL_POSTGRES_TEST === 'true';
const config = { host: '127.0.0.1', port: 55439, user: 'postgres', database: 'postgres', connectionTimeoutMillis: 5000 };
const database = `dopmi_legal_test_${randomUUID().replaceAll('-', '')}`;
let db, admin, client, created=false;
const owner=randomUUID(), other=randomUUID();
const legacy=['terms-2026-09-28','privacy-2026-09-28',true];
const current=['terms-2026-10-17','privacy-2026-10-17',true];
before(async()=>{
  if(real){
    admin=new pg.Client(config); await admin.connect();
    assert.equal(admin.connectionParameters.host,'127.0.0.1');
    assert.equal(admin.connectionParameters.port,55439);
    await admin.query(`create database "${database}" template template0`);created=true;
    client=new pg.Client({...config,database}); await client.connect();
    db={exec:sql=>client.query(sql),query:(sql,values)=>client.query(sql,values)};
  } else db=new PGlite();
  await db.exec(`do $$begin
    if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
    if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
    if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
    end$$;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  const path=new URL('../../supabase/migrations/',import.meta.url);
  for(const file of (await readdir(path)).filter(x=>x.endsWith('.sql')).sort())
    await db.exec(await readFile(new URL(file,path),'utf8'));
  for(const id of [owner,other]) await signup(id,{});
  // Existing synthetic pending contribution proves consent neither changes its
  // reservation nor creates a second payment. No Stripe/Auth HTTP is involved.
  const verification=randomUUID(),caseId=randomUUID(),expense=randomUUID();
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
    ($1,$4,'verification','approved','{"public_name":"Prueba"}',null,0),
    ($2,$4,'case','approved','{"pet_name":"Prueba"}',null,0),
    ($3,$4,'expense','approved','{"title":"Prueba"}',$2,12000)`,[verification,caseId,expense,other]);
  await db.query("insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled) values($1,'acct_legal_test',true,true)",[other]);
  await db.query("select public.dopmi_oneoff_native_server('prepare',$1::jsonb)", [JSON.stringify({actor:owner,key:randomUUID(),expense_id:expense,gross_cents:1000,consent:true,consent_version:'oneoff-test-2026-10-15'})]);
},{timeout:120000});
after(async()=>{
  if(real){await client?.end();if(created)await admin.query(`drop database "${database}"`);await admin?.end();}
  else await db?.close();
});
beforeEach(async()=>{
  await db.query('delete from private.dopmi_consents where owner_id=$1',[owner]);
  await db.query("update public.profiles set account_status='active',terms_version=null,privacy_version=null,terms_accepted_at=null,privacy_accepted_at=null,adult_confirmed_at=null where id=$1",[owner]);
  await db.exec('begin');
});
afterEach(async()=>db.exec('rollback'));
async function signup(id,meta){await db.query('insert into auth.users(id,raw_user_meta_data,email_confirmed_at) values($1,$2::jsonb,now())',[id,JSON.stringify(meta)]);}
async function actor(id=owner,role='authenticated'){
  await db.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);
  await db.exec(`set local role ${role}`);
}
async function reset(){await db.exec('reset role');}
async function accept(pair=current){return (await db.query('select public.dopmi_accept_legal($1,$2,$3) value',pair)).rows[0].value;}
async function fail(fn,match){await db.exec('savepoint rejected');await assert.rejects(fn(),match);await db.exec('rollback to savepoint rejected');}
async function profile(id=owner){return (await db.query('select * from public.profiles where id=$1',[id])).rows[0];}
async function inventory(){
  const names=(await db.query(`select n.nspname||'.'||c.relname name from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where c.relkind='r' and n.nspname in ('public','private') and c.relname<>'dopmi_consents' and c.relname<>'profiles' order by 1`)).rows;
  const result={};for(const {name} of names)result[name]=(await db.query(`select to_jsonb(t) value from ${name} t order by to_jsonb(t)::text`)).rows;
  return result;
}

test('new acceptance preserves old evidence, own identity and financial state; replay keeps the original timestamp',async()=>{
  await actor();const old=await accept(legacy);await reset();
  const oldProof=(await db.query('select * from private.dopmi_consents where owner_id=$1',[owner])).rows[0];
  const untouched=await profile(other), before=await inventory();
  assert.equal(before['public.dopmi_donations'].length,1);
  await actor();const history=(await db.query('select public.dopmi_payment_activity() value')).rows[0].value;
  const first=await accept();
  assert.deepEqual((await db.query('select public.dopmi_payment_activity() value')).rows[0].value,history);
  await reset();
  const initial=await profile();
  // Separate transaction timestamps make a replay timestamp regression observable.
  await db.exec('commit');await db.exec('begin');
  await actor();const replay=await accept();await reset();
  assert.deepEqual(replay,first);assert.deepEqual(await profile(),initial);
  assert.deepEqual(await profile(other),untouched);assert.deepEqual(await inventory(),before);
  const proofs=(await db.query('select * from private.dopmi_consents where owner_id=$1 order by terms_version',[owner])).rows;
  assert.equal(proofs.length,2);assert.deepEqual(proofs[0],oldProof);
  assert.equal(initial.terms_version,current[0]);assert.equal(initial.privacy_version,current[1]);
  assert.equal(new Date(initial.adult_confirmed_at).toISOString(),new Date(old.accepted_at).toISOString());
  // Remove committed fixture changes so other cases begin clean.
  await db.query('delete from private.dopmi_consents where owner_id=$1',[owner]);
  await db.query('update public.profiles set terms_version=null,privacy_version=null,terms_accepted_at=null,privacy_accepted_at=null,adult_confirmed_at=null where id=$1',[owner]);
  await db.exec('commit');await db.exec('begin');
});

test('exact complete pairs only: mixed, future, unknown, null and unconfirmed adult fail without writes',async()=>{
  await actor();
  for(const pair of [[legacy[0],current[1],true],[current[0],legacy[1],true],['terms-2099-01-01','privacy-2099-01-01',true],['unknown','unknown',true],[null,current[1],true],[current[0],null,true],[...current.slice(0,2),false],[...current.slice(0,2),null]])
    await fail(()=>accept(pair),/Aceptación legal inválida/);
  await reset();assert.equal((await profile()).terms_version,null);
  assert.equal((await db.query('select count(*)::int n from private.dopmi_consents')).rows[0].n,0);
});

test('old 318 remains compatible until explicit upgrade; neither September nor development RPC can downgrade',async()=>{
  await actor();await accept(legacy);await fail(()=>db.query('select public.accept_current_terms()'),/versión más reciente/);
  await accept();await reset();const before=await profile();
  await actor();await fail(()=>accept(legacy),/versión más reciente/);
  await fail(()=>db.query('select public.accept_current_terms()'),/versión más reciente/);
  await reset();assert.deepEqual(await profile(),before);
});

test('only active auth.uid can accept; anonymous/service execution and direct consent editing are denied',async()=>{
  for(const status of ['suspended','deletion_requested','deleted']){
    await db.query('update public.profiles set account_status=$2 where id=$1',[owner,status]);
    await actor();await fail(()=>accept(),/Cuenta no disponible/);await reset();
  }
  await actor('');await fail(()=>accept(),/Aceptación legal inválida/);await reset();
  for(const role of ['anon','service_role']){await actor(owner,role);await fail(()=>accept(),/permission denied/);await reset();}
  await actor();
  await fail(()=>db.query("update public.profiles set terms_version='terms-2026-10-17'"),/permission denied/);
  await fail(()=>db.query('select * from private.dopmi_consents'),/permission denied/);
  await fail(()=>db.query("insert into private.dopmi_consents(owner_id,terms_version,privacy_version,adult_confirmed) values($1,$2,$3,true)",[other,...current.slice(0,2)]),/permission denied/);
});

test('signup records exact old/new consent and rejects fake/mixed metadata without granting admin authority',async()=>{
  for(const pair of [legacy,current]){
    const id=randomUUID();await signup(id,{terms_version:pair[0],privacy_version:pair[1],adult_confirmed:true,intent:'rescue',is_admin:true,role:'admin'});
    assert.equal((await profile(id)).terms_version,pair[0]);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_consents where owner_id=$1',[id])).rows[0].n,1);
    await actor(id);assert.equal((await db.query('select public.dopmi_is_admin() value')).rows[0].value,false);await reset();
  }
  for(const meta of [{terms_version:current[0],privacy_version:legacy[1],adult_confirmed:true},{terms_version:'terms-2099-01-01',privacy_version:'privacy-2099-01-01',adult_confirmed:true},{terms_version:current[0],privacy_version:current[1],adult_confirmed:false},{}]){
    const id=randomUUID();await signup(id,meta);assert.equal((await profile(id)).terms_version,null);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_consents where owner_id=$1',[id])).rows[0].n,0);
  }
  const id=randomUUID();await signup(id,{terms_version:'development-2026-09-13',terms_accepted:true});
  assert.equal((await profile(id)).terms_version,'development-2026-09-13');assert.equal((await profile(id)).privacy_version,null);
  const unaccepted=randomUUID();await signup(unaccepted,{});
  await db.query('update auth.users set raw_user_meta_data=$2::jsonb where id=$1',[unaccepted,JSON.stringify({terms_version:current[0],privacy_version:current[1],adult_confirmed:true,role:'admin'})]);
  assert.equal((await profile(unaccepted)).terms_version,null);
});

test('cancellation snapshot reads only own registration even suspended/unconfirmed, with no reconciliation or writes',async()=>{
  const id=randomUUID(),key=randomUUID();
  await db.query(`insert into private.dopmi_guardian_registrations
    (id,owner_id,request_key,initial_gross_cents,gross_cents,consent_version,registered_at)
    values($1,$2,$3,2000,2000,'guardian-registration-2026-10-14','2026-08-31T10:00:00Z')`,[id,owner,key]);
  const read=async()=>(await db.query('select public.dopmi_guardian_registration_cancellation_state() value')).rows[0].value;
  await actor();const active=await read();
  const standard=(await db.query('select public.dopmi_guardian_registration_state() value')).rows[0].value;
  const {method_status,method_change,...same}=standard;
  assert.deepEqual(active,same);
  assert.deepEqual(Object.keys(active).sort(),['id','key','status','gross_cents','revision','registered_at','consent_version','next_evaluation_at','evaluation','payment'].sort());
  assert.equal(active.id,id);assert.equal(active.key,key);assert.equal(active.payment.state,'not_evaluated');
  assert.equal(active.method_status,undefined);assert.equal(active.method_change,undefined);
  await reset();
  const before=await inventory();
  for(const status of ['active','suspended','deletion_requested','deleted']){
    await db.query('update public.profiles set account_status=$2 where id=$1',[owner,status]);
    await db.query('update auth.users set email_confirmed_at=null where id=$1',[owner]);
    await actor();assert.deepEqual(await read(),active);
    await fail(()=>db.query('select public.dopmi_guardian_registration_state()'),/Cuenta no disponible/);
    await reset();assert.deepEqual(await inventory(),before);
  }
  // No own registration is represented honestly, never another owner's data.
  await actor(other);assert.equal(await read(),null);await reset();
  await actor(randomUUID());await fail(()=>read(),/Cuenta no disponible/);await reset();
  await actor('');await fail(()=>read(),/Cuenta no disponible/);await reset();
  for(const role of ['anon','service_role']){await actor(owner,role);await fail(()=>read(),/permission denied/);await reset();}
  await db.query("update private.dopmi_guardian_registrations set status='canceled',canceled_at=now(),revision=1 where id=$1",[id]);
  await actor();const canceled=await read();assert.equal(canceled.status,'canceled');assert.equal(canceled.next_evaluation_at,null);await reset();
  // Retained profile alone cannot authorize a JWT whose Auth subject is gone.
  await db.exec('savepoint removed_auth');await db.query('delete from auth.users where id=$1',[owner]);
  await actor();await fail(()=>read(),/Cuenta no disponible/);await reset();await db.exec('rollback to savepoint removed_auth');
});

test('PostgreSQL concurrency: simultaneous current accepts share one durable proof and timestamp',{skip:!real},async()=>{
  const id=randomUUID();await signup(id,{});await db.exec('commit');await db.exec('begin');
  const a=new pg.Client({...config,database}),b=new pg.Client({...config,database});await a.connect();await b.connect();
  try{
    for(const c of [a,b]){
      await c.query('set statement_timeout=10000;set lock_timeout=5000;begin');
      await c.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);await c.query('set local role authenticated');
    }
    const first=(await a.query('select public.dopmi_accept_legal($1,$2,$3) value',current)).rows[0].value;
    let finished=false;
    const waiting=b.query('select public.dopmi_accept_legal($1,$2,$3) value',current).finally(()=>{finished=true;});
    await a.query('select pg_sleep(0.15)');assert.equal(finished,false);
    await a.query('commit');assert.deepEqual((await waiting).rows[0].value,first);await b.query('commit');
    assert.equal((await db.query('select count(*)::int n from private.dopmi_consents where owner_id=$1',[id])).rows[0].n,1);
  }finally{await a.query('rollback').catch(()=>{});await b.query('rollback').catch(()=>{});await a.end();await b.end();}
});

test('PostgreSQL concurrency: newer acceptance serializes with old request and prevents rollback to old pair',{skip:!real},async()=>{
  const id=randomUUID();await signup(id,{});await db.exec('commit');await db.exec('begin');
  const a=new pg.Client({...config,database}),b=new pg.Client({...config,database});await a.connect();await b.connect();
  try{
    for(const c of [a,b])await c.query("set statement_timeout=10000;set lock_timeout=5000");
    await a.query('begin');await a.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);await a.query('set local role authenticated');
    const first=(await a.query('select public.dopmi_accept_legal($1,$2,$3) value',current)).rows[0].value;
    await b.query('begin');await b.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);await b.query('set local role authenticated');
    let finished=false;
    const waiting=b.query('select public.dopmi_accept_legal($1,$2,$3) value',legacy).then(r=>({r}),error=>({error})).finally(()=>{finished=true;});
    await a.query('select pg_sleep(0.15)');assert.equal(finished,false);
    await a.query('commit');assert.match((await waiting).error.message,/versión más reciente/);await b.query('rollback');
    const replay=(await b.query("select set_config('request.jwt.claim.sub',$1,false)",[id]),await b.query('select public.dopmi_accept_legal($1,$2,$3) value',current)).rows[0].value;
    assert.deepEqual(replay,first);
    assert.equal((await b.query('select count(*)::int n from private.dopmi_consents where owner_id=$1',[id])).rows[0].n,1);
  }finally{await a.query('rollback').catch(()=>{});await b.query('rollback').catch(()=>{});await a.end();await b.end();}
});
