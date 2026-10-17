import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { guardianRegistrationMethodChange } from '../../supabase/functions/_shared/guardian-registration-method-change.mjs';
import { nativeSavedCardService } from '../../supabase/functions/_shared/native-saved-card.mjs';

let db, admin, client;
const real = process.env.DOPMI_METHOD_POSTGRES_TEST === 'true';
const database = `dopmi_b4_method_test_${randomUUID().replaceAll('-', '')}`;
const config = { host: '127.0.0.1', port: 55439, user: 'postgres', database: 'postgres', connectionTimeoutMillis: 5000 };
if(real) pg.types.setTypeParser(20, Number);
const donor = '94000000-0000-4000-8000-000000000001';
const rescuer = '94000000-0000-4000-8000-000000000002';
const other = '94000000-0000-4000-8000-000000000003';
const expense = '95000000-0000-4000-8000-000000000003';
const key = '96000000-0000-4000-8000-000000000001';
before(async () => {
  if (real) {
    admin = new pg.Client(config); await admin.connect();
    assert.equal(admin.connectionParameters.host,'127.0.0.1'); assert.equal(admin.connectionParameters.port,55439);
    await admin.query(`create database "${database}" template template0`);
    client = new pg.Client({...config,database}); await client.connect();
    db = {exec: text=>client.query(text),query:(text,values)=>client.query(text,values)};
  } else db = new PGlite();
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
  const migrations = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(migrations)).filter(v => v.endsWith('.sql')).sort())
    await db.exec(await readFile(new URL(file, migrations), 'utf8'));
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    select id::uuid,id||'@example.test',now(),$2::jsonb from unnest($1::text[]) id`,
  [[donor, rescuer, other], JSON.stringify({ display_name: 'Prueba', terms_accepted: true, terms_version: 'development-2026-09-13' })]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
    ('95000000-0000-4000-8000-000000000001',$1,'verification','approved','{"public_name":"Refugio"}',null,0),
    ('95000000-0000-4000-8000-000000000002',$1,'case','approved','{"pet_name":"Luna"}',null,0),
    ($2,$1,'expense','approved','{"title":"Medicamentos"}','95000000-0000-4000-8000-000000000002',12000)`, [rescuer, expense]);
  await db.query(`insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
    values($1,'acct_synthetic',true,true)`, [rescuer]);
}, { timeout: 120000 });
after(async () => {
 if(real) { await client?.end(); if(admin) { await admin.query(`drop database "${database}"`); await admin.end(); } }
 else await db?.close();
});
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));
const id='97000000-0000-4000-8000-000000000001';
const changeKey='97000000-0000-4000-8000-000000000002';
const change = async (operation, fields={}) => (await db.query('select public.dopmi_guardian_registration_method_server($1,$2::jsonb) value',
 [operation,JSON.stringify({owner_id:donor,id,key:changeKey,...fields})])).rows[0].value;
async function registration() {
 const job=(await db.query(`insert into private.dopmi_saved_card_customers(owner_id,stripe_customer_id) values($1,'cus_method') returning id`,[donor])).rows[0];
 const saved=(await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,setup_intent_id,payment_method_id,status,return_url,wallet_type)
 values($1,$2,$3,'saved-cards-2026-10-03','cus_method','seti_old','pm_old','saved','https://example.test/functions/v1/payment-return','card') returning id`,[donor,id,job.id])).rows[0];
 await db.query(`insert into private.dopmi_guardian_registrations(id,owner_id,request_key,initial_gross_cents,gross_cents,consent_version,status,method_job_id,revision)
 values($1,$2,$1,2000,2000,'guardian-registration-2026-10-14','registered',$3,1)`,[id,donor,saved.id]);
 return saved.id;
}
async function rejected(action) {
 await db.exec('savepoint expected_failure');
 await assert.rejects(action);
 await db.exec('rollback to savepoint expected_failure');
}
const prepare=()=>change('prepare',{revision:1,consent:true,consent_version:'saved-cards-2026-10-03'});
async function savedChange(m) {
 return (await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,setup_intent_id,payment_method_id,status,return_url,wallet_type)
 select $1,$2,id,'saved-cards-2026-10-03','cus_method','seti_new','pm_new','saved','https://example.test/functions/v1/payment-return','card'
 from private.dopmi_saved_card_customers where owner_id=$1 returning id`,[donor,m.id])).rows[0].id;
}
test('method SQL: owner consent and revision gate before setup; same key recovers one job',async()=>{
 await registration();
 await rejected(()=>change('prepare',{revision:1,consent:false,consent_version:'saved-cards-2026-10-03'}));
 await rejected(()=>change('prepare',{owner_id:other,revision:1,consent:true,consent_version:'saved-cards-2026-10-03'}));
 await rejected(()=>change('prepare',{revision:0,consent:true,consent_version:'saved-cards-2026-10-03'}));
 const m=await prepare(); assert.equal((await prepare()).id,m.id);
 assert.equal((await db.query('select count(*)::integer n from private.dopmi_saved_card_jobs')).rows[0].n,1);
});
test('method SQL: native adapter authorizes linked change only; pending setup cannot change registration',async()=>{
 await registration(); const m=await prepare();
 const result=await db.query(`select public.dopmi_saved_native_card_server('prepare_registration',$1::jsonb) value`,[JSON.stringify({owner_id:donor,key:m.id,consent:true,consent_version:'saved-cards-2026-10-03',return_url:'https://example.test/functions/v1/payment-return'})]);
 assert.equal(result.rows[0].value.request_key,m.id);
 assert.equal((await change('reconcile')).status,'pending');
 await rejected(()=>db.query(`select public.dopmi_saved_native_card_server('prepare_registration',$1::jsonb)`,[JSON.stringify({owner_id:donor,key:changeKey,consent:true,consent_version:'saved-cards-2026-10-03',return_url:'https://example.test/functions/v1/payment-return'})]));
});
test('method SQL: confirmed setup changes future method once; no payment, amount or enrollment created',async()=>{
 const old=await registration(); const m=await prepare(); const newJob=await savedChange(m);
 assert.equal((await change('reconcile')).status,'applied');
 assert.equal((await change('reconcile')).status,'applied');
 const r=(await db.query('select method_job_id,revision,gross_cents,status from private.dopmi_guardian_registrations where id=$1',[id])).rows[0];
 assert.equal(r.method_job_id,newJob); assert.equal(r.revision,2); assert.equal(r.gross_cents,2000); assert.equal(r.status,'registered');
 assert.equal((await db.query('select count(*)::integer n from private.dopmi_guardian_registration_attempts')).rows[0].n,0);
 assert.equal((await db.query('select private.dopmi_registration_method_valid($1,$2,$3) ok',[id,donor,old])).rows[0].ok,true);
 assert.equal((await db.query('select private.dopmi_registration_method_valid($1,$2,$3) ok',[id,donor,newJob])).rows[0].ok,true);
});
test('method SQL: normal cancellation wins even when setup succeeded',async()=>{
 await registration(); const m=await prepare(); await savedChange(m);
 await db.query(`select public.dopmi_guardian_registration_server('cancel',$1::jsonb)`,[JSON.stringify({owner_id:donor,id})]);
 assert.equal((await change('reconcile')).status,'canceled');
 assert.equal((await db.query('select revision from private.dopmi_guardian_registrations where id=$1',[id])).rows[0].revision,2);
});
test('method SQL: amount revision wins pending setup without changing the saved method',async()=>{
 const old=await registration(); const m=await prepare(); await savedChange(m);
 await db.query(`select public.dopmi_guardian_registration_server('change_amount',$1::jsonb)`,[JSON.stringify({owner_id:donor,id,revision:1,gross_cents:5000,consent:true,consent_version:'guardian-registration-2026-10-14'})]);
 assert.equal((await change('reconcile')).status,'canceled');
 assert.equal((await db.query('select method_job_id from private.dopmi_guardian_registrations where id=$1',[id])).rows[0].method_job_id,old);
});
test('method SQL: prepared payment retains original method after a future-method change',async()=>{
 await registration();
 const prepared=(await db.query(`select public.dopmi_guardian_registration_attempt_server('prepare',$1::jsonb) value`,[JSON.stringify({id})])).rows[0].value;
 assert.equal(prepared.status,'prepared'); assert.equal(prepared.payment_method_id,'pm_old');
 const m=await prepare(); await savedChange(m); await change('reconcile');
 const retry=(await db.query(`select public.dopmi_guardian_registration_attempt_server('prepare',$1::jsonb) value`,[JSON.stringify({id})])).rows[0].value;
 assert.equal(retry.id,prepared.id); assert.equal(retry.payment_method_id,'pm_old');
 await db.query('select public.dopmi_guardian_registration_bind_payment($1,$2)',[prepared.id,'pi_snapshot']);
 const authorized=(await db.query('select public.dopmi_guardian_registration_authorize_payment($1) value',[prepared.id])).rows[0].value;
 assert.ok(authorized); assert.equal(authorized.id,prepared.id); assert.equal(authorized.payment_method_id,'pm_old');
 await db.query("update private.dopmi_guardian_registration_attempts set processor_state='requires_action' where id=$1",[prepared.id]);
 const bank=(await db.query('select public.dopmi_guardian_registration_bank_action($1,$2,$3) value',[donor,id,prepared.id])).rows[0].value;
 assert.equal(bank.payment_method_id,'pm_old');
});
test('method SQL: safe owner projection supports recovery and rejects private table access',async()=>{
 await registration();const m=await prepare();
 await db.query("select set_config('request.jwt.claim.sub',$1,true)",[donor]);
 await db.exec('set local role authenticated');
 const state=(await db.query('select public.dopmi_guardian_registration_state() value')).rows[0].value;
 assert.equal(state.method_status,'saved');assert.equal(state.method_change.key,changeKey);assert.equal(state.method_change.status,'pending');
 for(const forbidden of ['owner_id','customer_id','method_job_id','payment_method_id','setup_intent_id','setup_client_secret'])
 assert.equal(JSON.stringify(state).includes(forbidden),false);
 await rejected(()=>db.query('select * from private.dopmi_guardian_registration_method_changes'));
 await db.exec('reset role');
 await db.query("select set_config('request.jwt.claim.sub',$1,true)",[other]);await db.exec('set local role authenticated');
 assert.equal((await db.query('select public.dopmi_guardian_registration_state() value')).rows[0].value,null);
});
test('method SQL: a later evaluation selects the new method without changing the old attempt',async()=>{
 await registration();const m=await prepare();await savedChange(m);await change('reconcile');
 const prepared=(await db.query(`select public.dopmi_guardian_registration_attempt_server('prepare',$1::jsonb) value`,[JSON.stringify({id})])).rows[0].value;
 assert.equal(prepared.payment_method_id,'pm_new');assert.equal(prepared.gross_cents,2000);
});

function integratedFixture({loseSetupResponse=false}={}) {
 const operations=[],creates=[],setups=new Map();let succeeded=false,lost=loseSetupResponse;
 const rpc=name=>async(operation,data)=>{
  operations.push({name,operation,data:structuredClone(data)});
  return (await db.query('select public.'+name+'($1,$2::jsonb) value',[operation,JSON.stringify(data)])).rows[0].value;
 };
 const stripe={
  customers:{retrieve:async id=>({id,livemode:false})},
  setupIntents:{create:async(data,options)=>{
   creates.push({data:structuredClone(data),options:structuredClone(options)});
   if(!setups.has(options.idempotencyKey))setups.set(options.idempotencyKey,{id:'seti_integrated',livemode:false,
    customer:data.customer,usage:data.usage,payment_method_types:['card'],status:'requires_payment_method',
    client_secret:'seti_integrated_secret_fixture',metadata:data.metadata,payment_method:'pm_integrated'});
   if(lost){lost=false;throw Error('lost setup response');}
   return structuredClone(setups.get(options.idempotencyKey));
  },retrieve:async()=>({...structuredClone([...setups.values()][0]),status:succeeded?'succeeded':'requires_payment_method'})},
  paymentMethods:{retrieve:async id=>({id,customer:'cus_method',livemode:false,type:'card',card:{}})},
 };
 const native=nativeSavedCardService({stripe,rpc:rpc('dopmi_saved_native_card_server'),
  hosted:{checkout:()=>{throw Error('native change cannot use hosted');}},returnUrl:'https://example.test/functions/v1/payment-return'});
 const service=guardianRegistrationMethodChange({rpc:rpc('dopmi_guardian_registration_method_server'),savedNativeCard:native});
 return{service,operations,creates,setups,confirm:()=>{succeeded=true;}};
}
const integratedInput={id,key:changeKey,revision:1,consent:true,consent_version:'saved-cards-2026-10-03'};
test('integrated method change starts real SQL prepare and claim before no-charge Setup; confirmation applies once',async()=>{
 const old=await registration();const f=integratedFixture();
 const pending=await f.service.submit(donor,integratedInput);
 assert.equal(pending.status,'pending');assert.equal(pending.setup_client_secret,'seti_integrated_secret_fixture');
 assert.equal(f.creates.length,1);
 const nativeJobs=(await db.query('select id,request_key,status,setup_intent_id from private.dopmi_saved_card_jobs where id<>$1',[old])).rows;
 assert.equal(nativeJobs.length,1);assert.equal(nativeJobs[0].setup_intent_id,'seti_integrated');
 const claimIndex=f.operations.findIndex(c=>c.operation==='claim');
 assert.ok(claimIndex>f.operations.findIndex(c=>c.operation==='prepare_registration'));
 assert.ok(claimIndex<f.operations.findIndex(c=>c.operation==='native_setup'));
 assert.equal((await db.query('select revision from private.dopmi_guardian_registrations where id=$1',[id])).rows[0].revision,1);
 f.confirm();const applied=await f.service.status(donor,{id,key:changeKey});
 assert.equal(applied.status,'applied');assert.equal(applied.registration_revision,2);assert.equal(applied.setup_client_secret,null);
 assert.equal((await db.query('select count(*)::integer n from private.dopmi_guardian_registration_attempts')).rows[0].n,0);
 assert.equal(f.setups.size,1);
});
test('integrated method setup lost response retries same SQL change, saved-card job and Stripe idempotency key',async()=>{
 await registration();const f=integratedFixture({loseSetupResponse:true});
 await assert.rejects(f.service.submit(donor,integratedInput),/lost setup response/);
 const pending=await f.service.submit(donor,integratedInput);assert.equal(pending.status,'pending');
 assert.equal(f.creates.length,2);assert.deepEqual(f.creates[0],f.creates[1]);assert.equal(f.setups.size,1);
 assert.equal((await db.query('select count(*)::integer n from private.dopmi_guardian_registration_method_changes')).rows[0].n,1);
 assert.equal((await db.query('select count(*)::integer n from private.dopmi_saved_card_jobs')).rows[0].n,2);
 f.confirm();assert.equal((await f.service.status(donor,{id,key:changeKey})).status,'applied');
});
test('worker changes flag disabled leaves confirmed setup unapplied and registration revision intact',async()=>{
 const old=await registration();const m=await prepare();await savedChange(m);
 const f=integratedFixture();
 // Execute the actual runtime branch with the real SQL-backed service. This
 // exercises flag wiring as well as the absence of a reconciliation write.
 const runtime=await readFile(new URL('../../supabase/functions/_shared/guardian-runtime.ts',import.meta.url),'utf8');
 const branch=runtime.match(/const registrationMethods = [\s\S]*?;/)?.[0];assert.ok(branch);
 const run=new Function('Deno','registrationMethod','return (async()=>{'+branch+'return registrationMethods;})()');
 assert.deepEqual(await run({env:{get:()=> 'false'}},f.service),{applied:0,failed:0});
 assert.equal(f.operations.length,0);
 const before=(await db.query('select method_job_id,revision from private.dopmi_guardian_registrations where id=$1',[id])).rows[0];
 assert.equal(before.method_job_id,old);assert.equal(before.revision,1);
 assert.deepEqual(await run({env:{get:()=> 'true'}},f.service),{applied:1,failed:0});
 const after=(await db.query('select method_job_id,revision from private.dopmi_guardian_registrations where id=$1',[id])).rows[0];
 assert.notEqual(after.method_job_id,old);assert.equal(after.revision,2);
});
