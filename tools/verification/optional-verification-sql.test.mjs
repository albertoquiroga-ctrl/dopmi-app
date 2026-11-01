import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

// Disposable PostgreSQL only: no Auth service, remote database or Stripe calls.
let db, beforeMigration, afterMigration;
const owner=randomUUID(), reviewer=randomUUID(), other=randomUUID();
const row=async(sql,args=[]) => (await db.query(sql,args)).rows[0]?.value;
async function actor(id,role='authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);
  await db.exec(`set local role ${role}`);
}
async function rejected(action,pattern) {
  await db.exec('savepoint rejection'); await assert.rejects(action(),pattern);
  await db.exec('rollback to savepoint rejection');
}
async function draft(kind='case',parent=null) {
  const id=randomUUID();
  const publicData=kind==='case'
    ? {pet_name:'Caso sintético',species:'dog',sex:'female',age:'2 años',story:'Rescate sintético para pruebas locales',city:'Monterrey',state:'Nuevo León'}
    : {title:'Medicamento',description:'Gasto ya pagado de prueba',category:'medicine'};
  const privateData=kind==='case'?{}:{paid_on:'2026-09-01',vendor:'Proveedor sintético',amount_cents:'10000',receipt_reference:id};
  const files=(kind==='case'?['public']:['receipt','proof']).map(role=>({role,path:`${owner}/${id}/${randomUUID()}.${role==='receipt'?'pdf':'jpg'}`}));
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,public_data,private_data,files,video_thanks_required)
    values($1,$2,$3,$4,$5::jsonb,$6::jsonb,$7::jsonb,false)`,[id,owner,kind,parent,JSON.stringify(publicData),JSON.stringify(privateData),JSON.stringify(files)]);
  for(const file of files) await db.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)",[file.path]);
  return id;
}
async function transition(id,version=1,action='submit') {
  return row('select public.dopmi_transition_rescue($1,$2,$3) value',[id,version,action]);
}
async function connect(ready=true) {
  await actor(owner,'service_role');
  await row("select public.dopmi_payment_server('connect_get',$1::jsonb) value",[JSON.stringify({actor:owner})]);
  return row("select public.dopmi_payment_server('connect_save',$1::jsonb) value",[JSON.stringify({actor:owner,account_id:'acct_optional_synthetic',transfers_enabled:ready,payouts_enabled:ready,details_submitted:true})]);
}
async function approvedCase() {
  const id=await draft(); await connect(); await actor(owner); await transition(id);
  await actor(reviewer);
  await row("select public.dopmi_review_rescue($1,2,'approved','Caso revisado',0,false,'',true) value",[id]);
  return id;
}
async function inventory() {
  const result={};
  for(const name of ['public.dopmi_rescue_records','private.dopmi_rescue_history','private.dopmi_connect_accounts',
    'public.dopmi_donations','private.dopmi_payment_environment','private.dopmi_video_settings','private.dopmi_store_settings'])
    result[name]=(await db.query(`select to_jsonb(t) value from ${name} t order by to_jsonb(t)::text`)).rows;
  for(const name of ['private.dopmi_rescuer_verified(uuid)','private.dopmi_rescue_validate(public.dopmi_rescue_records)',
    'public.dopmi_oneoff_native_server(text,jsonb)','public.dopmi_guardian_collection_server(text,jsonb)'])
    result[name]=await row('select pg_get_functiondef($1::regprocedure) value',[name]);
  return result;
}

before(async()=>{
  db=new PGlite();
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
  const directory=new URL('../../supabase/migrations/',import.meta.url);
  for(const file of (await readdir(directory)).filter(f=>f.endsWith('.sql')).sort()) {
    if(file.endsWith('_optional_shelter_verification.sql')) {
      const legacy=randomUUID();
      await db.query("insert into auth.users(id,email,email_confirmed_at) values($1,'legacy-optional@example.test',now())",[legacy]);
      await db.query(`insert into public.dopmi_rescue_records(owner_id,kind,status,approved_snapshot,video_thanks_required)
        values($1,'case','closed','{"pet_name":"Caso histórico"}',false)`,[legacy]);
      beforeMigration=await inventory();
    }
    await db.exec(await readFile(new URL(file,directory),'utf8'));
    if(file.endsWith('_optional_shelter_verification.sql')) afterMigration=await inventory();
  }
  for(const id of [owner,reviewer,other]) await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    values($1,$2,now(),'{"display_name":"Nombre privado","terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}')`,[id,`${id}@example.test`]);
  await db.query('insert into private.admin_memberships(user_id) values($1)',[reviewer]);
},{timeout:120000});
after(async()=>db?.close());
beforeEach(async()=>db.exec('begin'));
afterEach(async()=>db.exec('rollback'));

test('ordinary owner submits privately, waits for Stripe, and reaches review without a shelter verification',async()=>{
  const id=await draft(); await actor(owner);
  assert.equal((await transition(id)).status,'pending_stripe');
  assert.equal(await row('select public.dopmi_rescuer_public($1) value',[owner]),null);
  await connect(false);
  await db.exec('reset role');
  assert.equal(await row('select status value from public.dopmi_rescue_records where id=$1',[id]),'pending_stripe');
  await connect();
  await db.exec('reset role');
  assert.equal(await row('select status value from public.dopmi_rescue_records where id=$1',[id]),'submitted');
  assert.equal(await row('select private.dopmi_rescuer_verified($1) value',[owner]),false);
  const audit=await row(`select to_jsonb(h) value from private.dopmi_rescue_history h where record_id=$1 and action='stripe_ready'`,[id]);
  assert.equal(audit.actor_type,'system'); assert.equal(audit.actor_id,null);
  await actor(other);
  assert.equal((await row('select public.dopmi_rescue_public($1) value',[id])).total,0);
  await rejected(()=>row('select public.dopmi_rescue_detail($1) value',[id]),/Solicitud no disponible/);
});

test('case and paid expense receive independent review; payment eligibility does not grant the verification badge',async()=>{
  const id=await approvedCase(); await db.exec('reset role');
  const expense=await draft('expense',id); await actor(owner); await transition(expense);
  await actor(reviewer);
  await row("select public.dopmi_review_rescue($1,2,'approved','Gasto revisado',10000,false,'',true) value",[expense]);
  await db.exec('reset role');
  assert.equal(await row('select private.dopmi_expense_payable(r) value from public.dopmi_rescue_records r where id=$1',[expense]),true);
  await actor(other,'anon');
  const catalog=await row('select public.dopmi_rescue_public($1) value',[id]);
  assert.equal(catalog.total,2);
  assert.equal(catalog.items.find(r=>r.id===id).rescuer_verified,false);
  const profile=await row('select public.dopmi_rescuer_public($1) value',[owner]);
  assert.equal(profile.verified,false); assert.equal(profile.name,'Rescatista Dopmi');
  assert.equal(profile.cases.length,1);
  assert.equal(JSON.stringify(profile).includes('Nombre privado'),false);
  await actor(other,'service_role');
  const prepared=await row("select public.dopmi_payment_server('prepare',$1::jsonb) value",[JSON.stringify({actor:other,key:randomUUID(),expense_id:expense,gross_cents:2000})]);
  assert.equal(prepared.expense_id,expense);
});

test('suspended or unconfirmed owners cannot expose cases or start Connect; financial readiness remains required',async()=>{
  const id=await approvedCase(); await db.exec('reset role');
  const expense=await draft('expense',id);
  await db.query("update public.dopmi_rescue_records set status='approved',approved_snapshot=public_data,reimbursable_cents=10000 where id=$1",[expense]);
  await db.query('update private.dopmi_connect_accounts set payouts_enabled=false where owner_id=$1',[owner]);
  assert.equal(await row('select private.dopmi_expense_payable(r) value from public.dopmi_rescue_records r where id=$1',[expense]),false);
  await db.query("update public.profiles set account_status='suspended' where id=$1",[owner]);
  assert.equal(await row('select public.dopmi_rescuer_public($1) value',[owner]),null);
  assert.equal((await row('select public.dopmi_rescue_public($1) value',[id])).total,0);
  await rejected(()=>connect(),/Cuenta activa y confirmada requerida/);
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='active' where id=$1",[owner]);
  await db.query('update auth.users set email_confirmed_at=null where id=$1',[owner]);
  assert.equal((await row('select public.dopmi_rescue_public($1) value',[id])).total,0);
  await rejected(()=>connect(),/Cuenta activa y confirmada requerida/);
});

test('case ownership, independent admin review, evidence and service-only finance remain enforced',async()=>{
  const id=await draft(); await actor(other);
  await rejected(()=>transition(id),/Solicitud no disponible/);
  await rejected(()=>row("select public.dopmi_payment_server('connect_begin',$1::jsonb) value",[JSON.stringify({actor:owner})]),/permission denied/);
  await actor(owner);
  await rejected(()=>row("select public.dopmi_review_rescue($1,1,'approved','Caso revisado',0,false,'',true) value",[id]),/Acceso administrativo/);
  await db.exec('reset role');
  await db.query('insert into private.admin_memberships(user_id) values($1)',[owner]);
  await connect(); await actor(owner); await transition(id);
  await rejected(()=>row("select public.dopmi_review_rescue($1,2,'approved','Caso revisado',0,false,'',true) value",[id]),/Otra persona del equipo/);
  await db.exec('reset role');
  const bad=await draft(); await db.query("update public.dopmi_rescue_records set files='[]' where id=$1",[bad]);
  await actor(owner); await rejected(()=>transition(bad),/Falta adjuntar evidencia/);
});

test('only the separate approved verification supplies the public badge; withdrawing it preserves independently approved cases',async()=>{
  const id=await approvedCase(); await db.exec('reset role');
  const verification=randomUUID();
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot) values($1,$2,'verification','approved','{"public_name":"Refugio aprobado"}')`,[verification,owner]);
  assert.equal((await row('select public.dopmi_rescuer_public($1) value',[owner])).verified,true);
  assert.equal((await row('select public.dopmi_rescue_public($1) value',[id])).items[0].rescuer_verified,true);
  await db.query("update public.dopmi_rescue_records set status='changes_requested',approved_snapshot=null where id=$1",[verification]);
  assert.equal((await row('select public.dopmi_rescue_public($1) value',[id])).total,1);
  assert.equal((await row('select public.dopmi_rescuer_public($1) value',[owner])).verified,false);
});

test('the migration preserves rows, historical snapshots, flags, validation and financial definitions; private helper is not a client API',async()=>{
  assert.deepEqual(afterMigration,beforeMigration);
  assert.equal(await row("select has_function_privilege('anon','private.dopmi_support_owner_active(uuid)','execute') value"),false);
  assert.equal(await row("select has_function_privilege('authenticated','private.dopmi_support_owner_active(uuid)','execute') value"),false);
  assert.equal(await row("select has_function_privilege('authenticated','public.dopmi_payment_server(text,jsonb)','execute') value"),false);
});

test('an ordinary case owner can submit a public profile but only its approved snapshot and consented contacts are exposed',async()=>{
  await approvedCase(); await actor(owner);
  const profile=await row('select public.dopmi_save_rescuer_profile($1::jsonb,null) value',[JSON.stringify({display_name:'Nombre público elegido',bio:'Descripción pública del rescatista',city:'Monterrey',region:'Nuevo León',instagram_url:'',facebook_url:'',avatar_path:''})]);
  const pending=await row("select public.dopmi_transition_rescuer_profile($1,'submit') value",[profile.version]);
  assert.equal(pending.status,'submitted');
  assert.equal((await row('select public.dopmi_rescuer_public($1) value',[owner])).name,'Rescatista Dopmi');
  await actor(reviewer);
  await row("select public.dopmi_review_rescuer_profile($1,$2,'published','') value",[owner,pending.version]);
  const result=await row('select public.dopmi_rescuer_public($1) value',[owner]);
  assert.equal(result.name,'Nombre público elegido'); assert.equal(result.verified,false);
  assert.equal(result.public_email,''); assert.equal(result.public_phone,'');
});
