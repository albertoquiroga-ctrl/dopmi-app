import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { savedCardMethodService } from '../../supabase/functions/_shared/saved-card-method.mjs';
import { guardianMethodListService } from '../../supabase/functions/_shared/guardian-method-list.mjs';
import { nativeSavedCardService } from '../../supabase/functions/_shared/native-saved-card.mjs';

let db, admin, client;
const real = process.env.DOPMI_NATIVE_WALLET_POSTGRES_TEST === 'true';
const database = `dopmi_native_wallet_guard_test_${randomUUID().replaceAll('-', '')}`;
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
const walletInput={owner_id:donor,key:'99000000-0000-4000-8000-000000000001',action:'remove',selected_method_id:'pm_new',consent:true,consent_version:'saved-card-methods-2026-10-03'};
const wallet=(operation,data)=>db.query('select public.dopmi_saved_card_method_server($1,$2::jsonb) value',[operation,JSON.stringify(data)]).then(r=>r.rows[0].value);
async function current(){await registration();const m=await prepare();await savedChange(m);await change('reconcile');}
async function cancel(){await db.query(`select public.dopmi_guardian_registration_server('cancel',$1::jsonb)`,[JSON.stringify({owner_id:donor,id})]);}
function stripeFixture(){
 const f={detaches:[],updates:[],lost:false,method:{id:'pm_new',customer:'cus_method',livemode:false,type:'card',card:{brand:'visa',last4:'4242',exp_month:12,exp_year:2034}},customer:{id:'cus_method',livemode:false,invoice_settings:{default_payment_method:null}}};
 f.stripe={customers:{retrieve:async()=>structuredClone(f.customer),update:async(id,data,options)=>{f.updates.push({id,data,options});f.customer.invoice_settings.default_payment_method=data.invoice_settings.default_payment_method;return structuredClone(f.customer);}},paymentMethods:{retrieve:async()=>structuredClone(f.method),list:async()=>({data:[structuredClone(f.method)],has_more:false}),detach:async(id,data,options)=>{f.detaches.push({id,data,options});f.method.customer=null;if(f.lost){f.lost=false;throw Error('lost detach response');}}},subscriptions:{list:async()=>({data:[],has_more:false})},invoices:{list:async()=>({data:[],has_more:false})},paymentIntents:{list:async()=>({data:[],has_more:false})}};
 return f;
}
test('native current non-default method blocks wallet removal with no subscription or PaymentIntent',async()=>{
 await current();const f=stripeFixture();const service=savedCardMethodService({stripe:f.stripe,rpc:wallet});
 await rejected(()=>service.submit(donor,{key:walletInput.key,action:'remove',selected_method_id:'pm_new',consent:true,consent_version:walletInput.consent_version}));
 assert.equal(f.detaches.length,0);
 assert.equal((await db.query("select private.dopmi_native_guardian_uses_method($1,'pm_new') value",[donor])).rows[0].value,true);
 assert.equal((await db.query('select count(*)::integer n from private.dopmi_guardian_registration_attempts')).rows[0].n,0);
});
test('owner list marks native current card separately from customer default without leaking private processor state',async()=>{
 await current();const f=stripeFixture();const read=guardianMethodListService({stripe:f.stripe,lookup:async actor=>(await db.query('select public.dopmi_saved_card_owner_server($1) value',[actor])).rows[0].value});
 const mine=await read(donor);assert.equal(mine.items[0].guardian_current,true);assert.equal(mine.items[0].default,false);assert.equal(mine.items[0].brand,'visa');assert.equal(mine.items[0].last4,'4242');
 assert.deepEqual(await read(other),{items:[]});
 for(const hidden of ['registration_method_id','customer_id','setup_intent','client_secret','owner_id'])assert.equal(JSON.stringify(mine).includes(hidden),false);
});
test('cancellation without pending attempt unlocks removal and lost response does not detach twice',async()=>{
 await current();await cancel();const f=stripeFixture();f.lost=true;const service=savedCardMethodService({stripe:f.stripe,rpc:wallet});
 const input={key:walletInput.key,action:'remove',selected_method_id:'pm_new',consent:true,consent_version:walletInput.consent_version};
 await assert.rejects(service.submit(donor,input),/lost detach response/);
 assert.equal((await service.submit(donor,input)).status,'removed');assert.equal(f.detaches.length,1);
 assert.ok(f.detaches[0].options.idempotencyKey.startsWith('dopmi-saved-card-remove:'));
});
test('canceled registration still protects original attempt method while its payment is unresolved',async()=>{
 await registration();const attempt=(await db.query(`select public.dopmi_guardian_registration_attempt_server('prepare',$1::jsonb) value`,[JSON.stringify({id})])).rows[0].value;
 const m=await prepare();await savedChange(m);await change('reconcile');
 await db.query('select public.dopmi_guardian_registration_bind_payment($1,$2)',[attempt.id,'pi_nativeGuard']);
 await db.query('select public.dopmi_guardian_registration_authorize_payment($1)',[attempt.id]);await cancel();
 assert.equal((await db.query('select private.dopmi_native_guardian_uses_method($1,$2) value',[donor,'pm_old'])).rows[0].value,true);
 await rejected(()=>wallet('prepare',{...walletInput,selected_method_id:'pm_old'}));
 await db.query("update private.dopmi_guardian_registration_attempts set processor_state='processor_canceled',resolved_at=now() where id=$1",[attempt.id]);
 assert.equal((await db.query('select private.dopmi_guardian_blocks_saved_method($1) value',[donor])).rows[0].value,false);
});
test('wallet prewrite rechecks registration race under shared lock before any detach permission',async()=>{
 await current();await cancel();const job=await wallet('prepare',walletInput);const claimed=await wallet('claim',{id:job.id});
 await wallet('snapshot',{id:job.id,lease:claimed.lease,default_method_id:null});
 // A fresh enrollment may win after wallet preparation, but its method setup
 // cannot complete while this wallet mutation is still pending.
 const fresh=(await db.query(`select public.dopmi_guardian_registration_server('prepare',$1::jsonb) value`,[JSON.stringify({owner_id:donor,key:'99000000-0000-4000-8000-000000000002',gross_cents:2000,consent:true,consent_version:'guardian-registration-2026-10-14'})])).rows[0].value;
 assert.equal(fresh.status,'method_pending');
 // Independently confirmed setup evidence becomes current after the old wallet
 // job was prepared. The fresh prewrite must still deny its removal.
 await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,setup_intent_id,payment_method_id,status,return_url,wallet_type)
 select $1,$2,id,'saved-cards-2026-10-03','cus_method','seti_fresh','pm_new','saved','https://example.test/functions/v1/payment-return','card'
 from private.dopmi_saved_card_customers where owner_id=$1`,[donor,fresh.id]);
 await db.query("select public.dopmi_guardian_registration_server('reconcile_method',$1::jsonb)",[JSON.stringify({owner_id:donor,id:fresh.id})]);
 assert.equal(await wallet('write_mutation',{id:job.id,lease:claimed.lease}),null);
 await rejected(()=>db.query(`select public.dopmi_saved_native_card_server('prepare_registration',$1::jsonb)`,[JSON.stringify({owner_id:donor,key:fresh.id,consent:true,consent_version:'saved-cards-2026-10-03',return_url:'https://example.test/functions/v1/payment-return'})]));
});

test('native active registration still permits changing independent wallet default',async()=>{
 await current();const f=stripeFixture();f.customer.invoice_settings.default_payment_method='pm_old';f.method.id='pm_unused';
 const service=savedCardMethodService({stripe:f.stripe,rpc:wallet});
 const result=await service.submit(donor,{...walletInput,action:'default',selected_method_id:'pm_unused'});
 assert.equal(result.status,'applied');assert.equal(f.updates.length,1);assert.equal(f.detaches.length,0);
 assert.equal(f.customer.invoice_settings.default_payment_method,'pm_unused');
 const link=(await db.query('select public.dopmi_saved_card_owner_server($1) value',[donor])).rows[0].value;assert.equal(link.registration_method_id,'pm_new');
});
test('native active registration still permits removal of another unused card',async()=>{
 await current();const f=stripeFixture();f.customer.invoice_settings.default_payment_method='pm_old';f.method.id='pm_unused';
 const service=savedCardMethodService({stripe:f.stripe,rpc:wallet});
 const result=await service.submit(donor,{...walletInput,selected_method_id:'pm_unused'});
 assert.equal(result.status,'removed');assert.equal(f.detaches.length,1);assert.equal(f.customer.invoice_settings.default_payment_method,'pm_old');
 const link=(await db.query('select public.dopmi_saved_card_owner_server($1) value',[donor])).rows[0].value;assert.equal(link.registration_method_id,'pm_new');
});
test('confirmed pending method change is protected before it becomes the current method',async()=>{
 await current();const m=await change('prepare',{key:'99000000-0000-4000-8000-000000000011',revision:2,consent:true,consent_version:'saved-cards-2026-10-03'});
 await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,setup_intent_id,payment_method_id,status,return_url,wallet_type)
 select $1,$2,id,'saved-cards-2026-10-03','cus_method','seti_future','pm_future','saved','https://example.test/functions/v1/payment-return','card'
 from private.dopmi_saved_card_customers where owner_id=$1`,[donor,m.id]);
 assert.equal((await db.query("select private.dopmi_native_guardian_uses_method($1,'pm_future') value",[donor])).rows[0].value,true);
 await rejected(()=>wallet('prepare',{...walletInput,selected_method_id:'pm_future'}));
});
test('method change cannot adopt a new method after concurrent wallet removal was authorized',async()=>{
 await current();const nextKey='99000000-0000-4000-8000-000000000012';
 const m=await change('prepare',{key:nextKey,revision:2,consent:true,consent_version:'saved-cards-2026-10-03'});
 const job=await wallet('prepare',{...walletInput,selected_method_id:'pm_future'});const lease=(await wallet('claim',{id:job.id})).lease;
 await wallet('snapshot',{id:job.id,lease,default_method_id:null});assert.ok(await wallet('write_mutation',{id:job.id,lease}));
 await db.query(`insert into private.dopmi_saved_card_jobs(owner_id,request_key,wallet_id,consent_version,customer_id,setup_intent_id,payment_method_id,status,return_url,wallet_type)
 select $1,$2,id,'saved-cards-2026-10-03','cus_method','seti_future','pm_future','saved','https://example.test/functions/v1/payment-return','card'
 from private.dopmi_saved_card_customers where owner_id=$1`,[donor,m.id]);
 assert.equal((await change('reconcile',{key:nextKey})).status,'canceled');
 assert.equal((await db.query('select public.dopmi_saved_card_owner_server($1) value',[donor])).rows[0].value.registration_method_id,'pm_new');
 const f=stripeFixture();f.method.id='pm_future';const service=savedCardMethodService({stripe:f.stripe,rpc:wallet});
 await wallet('release',{id:job.id,lease});assert.equal((await service.run(job.id)).status,'removed');assert.equal(f.detaches.length,1);
 assert.equal((await change('reconcile',{key:nextKey})).status,'canceled');
});
test('real PostgreSQL cancellation and concurrent removal serialize on the shared wallet lock', {skip:!real},async()=>{
 await current();await db.exec('commit');
 const first=new pg.Client({...config,database}),second=new pg.Client({...config,database});await first.connect();await second.connect();
 try{
  await first.query('begin');await first.query("select pg_advisory_xact_lock(hashtextextended('dopmi-saved-card:'||$1,0))",[donor]);
  const pid=(await second.query('select pg_backend_pid() pid')).rows[0].pid;
  const removal=second.query("select public.dopmi_saved_card_method_server('prepare',$1::jsonb) value",[JSON.stringify(walletInput)]);
  let waiting=false;for(let retry=0;retry<50;retry++){
   const state=(await first.query('select cardinality(pg_blocking_pids($1)) n',[pid])).rows[0];if(state.n>0){waiting=true;break;}
   await new Promise(resolve=>setTimeout(resolve,10));
  }
  assert.equal(waiting,true,'wallet preparation must wait for owner lock');
  await first.query("select public.dopmi_guardian_registration_server('cancel',$1::jsonb)",[JSON.stringify({owner_id:donor,id})]);
  await first.query('commit');
  assert.equal((await removal).rows[0].value.status,'pending');
  const registration=(await second.query('select status,revision from private.dopmi_guardian_registrations where id=$1',[id])).rows[0];
  assert.equal(registration.status,'canceled');assert.equal(registration.revision,3);
 }finally{await first.query('rollback');await first.end();await second.end();}
});
