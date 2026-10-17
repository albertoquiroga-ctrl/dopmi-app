import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { paymentService } from '../../supabase/functions/_shared/payments.mjs';

let db, admin, client;
const real = process.env.DOPMI_IMPACT_POSTGRES_TEST === 'true';
const database = `dopmi_impact_test_${randomUUID().replaceAll('-', '')}`;
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
  await bootstrap(db);
}, { timeout: 120000 });

async function bootstrap(db,{instrument=true}={}){
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
  for (const file of (await readdir(migrations)).filter(v => v.endsWith('.sql') && (instrument || v!=='20261017162026_monthly_impact_coverage.sql')).sort())
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
}

after(async () => {
 if(real) { await client?.end(); if(admin) { await admin.query(`drop database "${database}"`); await admin.end(); } }
 else await db?.close();
});
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));
const call = async (operation, fields = {}) => (await db.query(
  'select public.dopmi_oneoff_case_server($1,$2::jsonb) value',
  [operation, JSON.stringify({ actor: donor, key, ...fields })])).rows[0].value;
const caseId = '95000000-0000-4000-8000-000000000002';
const second = '95000000-0000-4000-8000-000000000004';
const payload = { case_id: caseId, gross_cents: 10000, consent: true, consent_version: 'oneoff-test-2026-10-15' };
async function rejected(fn, match) {
  await db.exec('savepoint expected_failure');
  await assert.rejects(fn(), match);
  await db.exec('rollback to savepoint expected_failure');
}

async function setActor(id=donor){await db.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);}
async function finance({actor=donor,expenseId=expense,gross=10000,fee=600,at=null}={}) {
 const requestKey=randomUUID(),suffix=requestKey.replaceAll('-','');
 const d=(await db.query("select public.dopmi_payment_server('prepare',$1::jsonb) value",[JSON.stringify({actor,key:requestKey,expense_id:expenseId,gross_cents:gross})])).rows[0].value;
 const paid=(await db.query("select public.dopmi_payment_server('settle',$1::jsonb) value",[JSON.stringify({donation_id:d.id,currency:'mxn',gross_cents:gross,stripe_fee_cents:fee,charge_id:'ch_'+suffix,payment_intent_id:'pi_'+suffix})])).rows[0].value;
 if(at)await db.query('update public.dopmi_donations set processed_at=$2 where id=$1',[d.id,at]);
 return paid;
}
async function personal(month=null){return(await db.query('select public.dopmi_monthly_personal_impact($1::date) value',[month])).rows[0].value;}
async function community(month=null){return(await db.query('select public.dopmi_monthly_community_impact($1::date) value',[month])).rows[0].value;}
async function urgent(capacity=9200){await db.query('update public.dopmi_rescue_records set urgent=true,reimbursable_cents=$2 where id=$1',[expense,capacity]);}
async function reverse(d){
 await db.query("update public.dopmi_donations set transfer_status='transferred',stripe_transfer_id=$2 where id=$1",[d.id,'tr_'+d.id.replaceAll('-','')]);
 await db.query("update private.dopmi_payment_jobs set status='done' where donation_id=$1 and kind='transfer'",[d.id]);
 await db.query("select public.dopmi_refund_adjustment('begin',$1::jsonb)",[JSON.stringify({donation_id:d.id})]);
 const job=(await db.query('select public.dopmi_payment_job_claim($1) value',['reversal:'+d.id])).rows[0].value;
 await db.query("select public.dopmi_refund_adjustment('finish',$1::jsonb)",[JSON.stringify({job_id:job.id,lease:job.lease,charge_id:d.stripe_charge_id,transfer_id:'tr_'+d.id.replaceAll('-',''),refund_cents:d.gross_cents,reversed_cents:d.allocated_cents,reversal_id:'trr_'+d.id.replaceAll('-',''),refund_id:'re_'+d.id.replaceAll('-',''),refund_ids:['re_'+d.id.replaceAll('-','')]})]);
}
test('Mexico City calendar includes start, excludes end, never filters by latest support date',async()=>{
 await db.query('update public.dopmi_rescue_records set reimbursable_cents=50000 where id=$1',[expense]);
 await finance({at:'2026-09-01T05:59:59.999Z'});
 await finance({at:'2026-09-01T06:00:00Z'});
 await finance({at:'2026-10-01T05:59:59.999Z'});
 await finance({at:'2026-10-01T06:00:00Z'});
 await setActor();const september=await personal('2026-09-01');
 assert.equal(september.allocated_cents,18400);assert.equal(september.cases_supported,1);assert.deepEqual(september.case_ids,[caseId]);
 assert.equal(new Date(september.period_start).toISOString(),'2026-09-01T06:00:00.000Z');
 assert.equal(new Date(september.period_end).toISOString(),'2026-10-01T06:00:00.000Z');
 assert.equal((await personal('2026-10-01')).allocated_cents,9200);
 assert.equal((await community('2026-09-01')).cases_supported,1);
});
test('personal projection derives actor from Auth, hides other donors and denies suspended accounts',async()=>{
 await finance({actor:other});await setActor();assert.equal((await personal()).allocated_cents,0);
 await db.query("update auth.users set raw_user_meta_data=raw_user_meta_data||'{\"role\":\"admin\"}' where id=$1",[donor]);
 assert.equal((await personal()).allocated_cents,0);
 await setActor(other);assert.equal((await personal()).allocated_cents,9200);
 await db.query("update public.profiles set account_status='suspended' where id=$1",[other]);
 await rejected(()=>personal(),/Sesión activa/);
});
test('reservations and unconfirmed payments count zero and no-urgent cases never create an achievement',async()=>{
 await call('prepare',payload);await setActor();assert.equal((await personal()).allocated_cents,0);
 assert.equal((await community()).cases_supported,0);assert.equal((await community()).urgent_cases_covered,0);
 await call('bind',{payment_intent_id:'pi_reserved'});
 assert.equal((await personal()).allocated_cents,0);
 assert.equal((await db.query('select count(*)::int n from private.dopmi_urgent_coverage_events')).rows[0].n,0);
});
test('urgent coverage is emitted once in the financial transaction; new need preserves previous achievement',async()=>{
 await urgent();const paid=await finance();
 assert.equal((await community()).urgent_cases_covered,1);
 await db.query('select private.dopmi_refresh_urgent_coverage($1,true)',[caseId]);
 await db.query('select private.dopmi_refresh_urgent_coverage($1,true)',[caseId]);
 assert.equal((await db.query('select count(*)::int n from private.dopmi_urgent_coverage_events')).rows[0].n,1);
 await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents,urgent)
 values($1,$2,'expense','approved','{"title":"Nueva necesidad"}',$3,9200,true)`,[second,rescuer,caseId]);
 assert.equal((await community()).urgent_cases_covered,1);
 await finance({expenseId:second});
 assert.equal((await db.query('select count(*)::int n from private.dopmi_urgent_coverage_events')).rows[0].n,2);
 assert.equal((await community()).urgent_cases_covered,1,'Distinct cases, not events');
 await reverse(paid);assert.equal((await community()).urgent_cases_covered,0,'Original supporting funds were reversed');
});
test('later reversal corrects original support month and original coverage event, never the reversal month',async()=>{
 await urgent();const paid=await finance({at:'2026-09-01T06:00:00Z'});
 // Only this disposable fixture moves the clock evidence to an earlier month.
 await db.exec("update private.dopmi_impact_tracking set started_at='2026-09-01T06:00:00Z';update private.dopmi_urgent_coverage_events set covered_at='2026-09-12T12:00:00Z'");
 await setActor();assert.equal((await personal('2026-09-01')).allocated_cents,9200);
 assert.equal((await community('2026-09-01')).urgent_cases_covered,1);
 await reverse(paid);
 assert.equal((await personal('2026-09-01')).allocated_cents,0);assert.equal((await personal('2026-10-01')).allocated_cents,0);
 assert.equal((await community('2026-09-01')).urgent_cases_covered,0);
 assert.ok((await db.query('select invalidated_at from private.dopmi_urgent_coverage_events')).rows[0].invalidated_at);
});
test('community exposes only aggregate counts, with real start and honest unmeasured/partial periods',async()=>{
 await db.exec("update private.dopmi_impact_tracking set started_at='2026-09-15T06:00:00Z'");
 const before=await community('2026-08-01');assert.equal(before.measurement_status,'not_measured');assert.equal(before.urgent_cases_covered,null);
 const first=await community('2026-09-01');assert.equal(first.measurement_status,'partial');assert.equal(first.urgent_cases_covered,0);assert.equal(first.measurement_started_on,'2026-09-15');
 await db.exec("update private.dopmi_impact_tracking set started_at='2026-09-15T05:59:59Z'");
 assert.equal((await community('2026-09-01')).measurement_started_on,'2026-09-14','Calendar date is CDMX, independent of phone timezone');
 assert.equal((await community('2026-10-01')).measurement_status,'complete');
 assert.deepEqual(Object.keys(first).sort(),['month','timezone','period_start','period_end','cases_supported','urgent_cases_covered','measurement_started_at','measurement_started_on','measurement_status'].sort());
 await db.exec('set local role anon');assert.equal((await community()).cases_supported,0);
 await rejected(()=>personal(),/permission denied/);
 await rejected(()=>db.query('select * from private.dopmi_urgent_coverage_events'),/permission denied/);
 await rejected(()=>db.query('select * from private.dopmi_impact_support'),/permission denied/);
 await db.exec('reset role');
});
test('financial history remains counted after public snapshot withdrawal; dates and invalid months are checked',async()=>{
 await finance();await db.query("update public.dopmi_rescue_records set status='changes_requested',approved_snapshot=null where id=$1",[caseId]);
 await setActor();assert.equal((await personal()).allocated_cents,9200);assert.equal((await community()).cases_supported,1);
 await rejected(()=>personal('2026-09-02'),/Mes inválido/);await rejected(()=>community('infinity'),/Mes inválido/);
});
async function guardianSupport(at=null){
 const k=randomUUID(),suffix=k.replaceAll('-','');
 const cycle=(await db.query('select public.dopmi_guardian_reserve($1,$2,10000) value',[donor,k])).rows[0].value;
 assert.equal(cycle.status,'reserved');
 await db.query(`insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,charge_id,invoice_payment_id,gross_cents,stripe_fee_cents,platform_fee_cents,allocated_cents,refund_cents,evidence,created_at)
 values($1,$2,$3,$4,$5,10000,0,200,9800,0,'{}',coalesce($6::timestamptz,now()))`,[cycle.id,'in_'+suffix,'pi_'+suffix,'ch_'+suffix,'inpay_'+suffix,at]);
 await db.query('update private.dopmi_guardian_allocations set allocated_cents=amount_cents where cycle_id=$1',[cycle.id]);
 await db.query("update private.dopmi_guardian_cycles set status='allocated',reserved_cents=0 where id=$1",[cycle.id]);
 return cycle;
}
test('expense history, case split and Guardian contribute exactly once to personal and community metrics',async()=>{
 await db.query('update public.dopmi_rescue_records set reimbursable_cents=50000 where id=$1',[expense]);
 await finance({at:'2026-09-03T12:00:00Z'});
 const d=await call('prepare',payload);await call('bind',{payment_intent_id:'pi_caseImpact'});
 await db.query("select public.dopmi_payment_server('settle',$1::jsonb)",[JSON.stringify({donation_id:d.id,currency:'mxn',gross_cents:10000,stripe_fee_cents:600,charge_id:'ch_caseImpact',payment_intent_id:'pi_caseImpact'})]);
 await db.query("update public.dopmi_donations set processed_at='2026-09-04T12:00:00Z' where id=$1",[d.id]);
 await guardianSupport('2026-09-05T12:00:00Z');
 await setActor();const result=await personal('2026-09-01');
 assert.equal(result.allocated_cents,28200);assert.equal(result.cases_supported,1);assert.deepEqual(result.case_ids,[caseId]);
 assert.equal((await community('2026-09-01')).cases_supported,1);
 assert.equal((await db.query('select public.dopmi_personal_impact() value')).rows[0].value[0].allocated_cents,28200);
});
test('Guardian coverage and original month are corrected only by confirmed reversed allocations',async()=>{
 await urgent(9800);const c=await guardianSupport('2026-09-05T12:00:00Z');
 await setActor();assert.equal((await personal('2026-09-01')).allocated_cents,9800);
 assert.equal((await community()).urgent_cases_covered,1);
 await db.query('update private.dopmi_guardian_allocations set reversed_cents=allocated_cents where cycle_id=$1',[c.id]);
 assert.equal((await community()).urgent_cases_covered,0);assert.equal((await personal('2026-09-01')).allocated_cents,0);
});
test('case split covers approved urgent need and full reversal invalidates its original support snapshot',async()=>{
 await urgent(4200);
 await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents)
 values($1,$2,'expense','approved','{"title":"Alimento"}',$3,10000)`,[second,rescuer,caseId]);
 const d=await call('prepare',payload);await call('bind',{payment_intent_id:'pi_caseSplit'});
 const paid=(await db.query("select public.dopmi_payment_server('settle',$1::jsonb) value",[JSON.stringify({donation_id:d.id,currency:'mxn',gross_cents:10000,stripe_fee_cents:600,charge_id:'ch_caseSplit',payment_intent_id:'pi_caseSplit'})])).rows[0].value;
 assert.equal((await community()).urgent_cases_covered,1);
 const snapshot=(await db.query('select urgent_snapshot,funding_snapshot from private.dopmi_urgent_coverage_events')).rows[0];
 assert.equal(snapshot.urgent_snapshot.length,1);assert.equal(snapshot.funding_snapshot.length,1);assert.equal(snapshot.funding_snapshot[0].amount_cents,4200);
 await reverse(paid);assert.equal((await community()).urgent_cases_covered,0);
});
test('instrumentation starts at actual migration and never invents events for preexisting coverage',async()=>{
 const existing=db;let isolated;
 try{
  if(real){
   const name=`dopmi_impact_baseline_${randomUUID().replaceAll('-','')}`;
   await admin.query(`create database "${name}" template template0`);
   isolated=new pg.Client({...config,database:name});await isolated.connect();
   db={query:(q,p)=>isolated.query(q,p),exec:q=>isolated.query(q)};db.baselineName=name;
  }else {isolated=new PGlite();db=isolated;}
  await bootstrap(db,{instrument:false});await urgent();await finance();
  const before=(await db.query('select clock_timestamp() t')).rows[0].t;
  await db.exec(await readFile(new URL('../../supabase/migrations/20261017162026_monthly_impact_coverage.sql',import.meta.url),'utf8'));
  const started=(await db.query('select started_at from private.dopmi_impact_tracking')).rows[0].started_at;
  assert.ok(new Date(started)>=new Date(before));
  assert.equal((await db.query('select complete from private.dopmi_urgent_coverage_state where case_id=$1',[caseId])).rows[0].complete,true);
  assert.equal((await db.query('select count(*)::int n from private.dopmi_urgent_coverage_events')).rows[0].n,0);
  await db.query('select private.dopmi_refresh_urgent_coverage($1,true)',[caseId]);
  assert.equal((await db.query('select count(*)::int n from private.dopmi_urgent_coverage_events')).rows[0].n,0);
 }finally{
  const name=db.baselineName;db=existing;
  if(real){await isolated?.end();if(name)await admin.query(`drop database "${name}"`);}else await isolated?.close();
 }
});
test('coverage event and allocation roll back atomically, with no ghost achievement',async()=>{
 await urgent();await db.exec('savepoint financial_action');await finance();
 assert.equal((await community()).urgent_cases_covered,1);
 await db.exec('rollback to savepoint financial_action');
 assert.equal((await community()).urgent_cases_covered,0);
 assert.equal((await db.query('select count(*)::int n from public.dopmi_donations')).rows[0].n,0);
});
test('real PostgreSQL concurrent settlement replay emits one coverage event under the shared owner lock',{skip:!real},async()=>{
 const a=new pg.Client({...config,database}),b=new pg.Client({...config,database});await Promise.all([a.connect(),b.connect()]);
 try{
  const target=randomUUID(),bill=randomUUID(),k=randomUUID(),suffix=k.replaceAll('-','');
  await a.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents,urgent) values
  ($1,$3,'case','approved','{"pet_name":"Concurrente"}',null,0,false),($2,$3,'expense','approved','{"title":"Urgencia"}',$1,9800,true)`,[target,bill,rescuer]);
  const d=(await a.query("select public.dopmi_oneoff_case_server('prepare',$1::jsonb) value",[JSON.stringify({actor:donor,key:k,case_id:target,gross_cents:10000,consent:true,consent_version:payload.consent_version})])).rows[0].value;
  await a.query("select public.dopmi_oneoff_case_server('bind',$1::jsonb)",[JSON.stringify({actor:donor,key:k,payment_intent_id:'pi_'+suffix})]);
  const proof=JSON.stringify({donation_id:d.id,currency:'mxn',gross_cents:10000,stripe_fee_cents:0,charge_id:'ch_'+suffix,payment_intent_id:'pi_'+suffix});
  await a.query('begin');await b.query('begin');
  const first=(await a.query("select public.dopmi_payment_server('settle',$1::jsonb) value",[proof])).rows[0].value;
  const replay=b.query("select public.dopmi_payment_server('settle',$1::jsonb) value",[proof]).finally(()=>b.query('rollback'));
  let waits=false;const deadline=Date.now()+3000;
  do{waits=(await admin.query("select wait_event_type='Lock' waiting from pg_stat_activity where pid=$1",[b.processID])).rows[0]?.waiting===true;if(waits)break;await new Promise(r=>setTimeout(r,20));}while(Date.now()<deadline);
  assert.equal(waits,true);await a.query('commit');assert.equal((await replay).rows[0].value.id,first.id);
  assert.equal((await a.query('select count(*)::int n from private.dopmi_urgent_coverage_events where case_id=$1',[target])).rows[0].n,1);
 }finally{await Promise.allSettled([a.query('rollback'),b.query('rollback')]);await Promise.all([a.end(),b.end()]);}
});
test('real PostgreSQL refund job completion and native status cannot invert row and owner locks',{skip:!real},async()=>{
 const a=new pg.Client({...config,database}),b=new pg.Client({...config,database});await Promise.all([a.connect(),b.connect()]);
 let reading;
 try{
  const target=randomUUID(),bill=randomUUID(),k=randomUUID(),suffix=k.replaceAll('-','');
  await a.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents,urgent) values
   ($1,$3,'case','approved','{"pet_name":"Refund concurrente"}',null,0,false),($2,$3,'expense','approved','{"title":"Urgencia"}',$1,9800,true)`,[target,bill,rescuer]);
  const identity={actor:donor,key:k};
  const d=(await a.query("select public.dopmi_oneoff_case_server('prepare',$1::jsonb) value",[JSON.stringify({...identity,case_id:target,gross_cents:10000,consent:true,consent_version:payload.consent_version})])).rows[0].value;
  await a.query("select public.dopmi_oneoff_case_server('bind',$1::jsonb)",[JSON.stringify({...identity,payment_intent_id:'pi_'+suffix})]);
  await a.query("update public.dopmi_rescue_records set status='changes_requested' where id=$1",[bill]);
  await a.query("select public.dopmi_payment_server('settle',$1::jsonb)",[JSON.stringify({donation_id:d.id,currency:'mxn',gross_cents:10000,stripe_fee_cents:600,charge_id:'ch_'+suffix,payment_intent_id:'pi_'+suffix})]);
  const job=(await a.query('select public.dopmi_payment_job_claim($1) value',['refund:'+d.id])).rows[0].value;
  const confirmation=JSON.stringify({job_id:job.id,lease:job.lease,result_id:'re_'+suffix});
  await a.query('begin');await b.query('begin');
  await a.query('select id from public.dopmi_donations where id=$1 for update',[d.id]);
  reading=b.query("select public.dopmi_oneoff_native_server('get',$1::jsonb) value",[JSON.stringify(identity)]).then(value=>({value}),error=>({error})).finally(()=>b.query('rollback'));
  let waiting=false;const deadline=Date.now()+3000;
  do{waiting=(await admin.query("select wait_event_type='Lock' waiting from pg_stat_activity where pid=$1",[b.processID])).rows[0]?.waiting===true;if(waiting)break;await new Promise(r=>setTimeout(r,20));}while(Date.now()<deadline);
  assert.equal(waiting,true,'Native status owns owner lock and waits for donation row');
  await a.query('select public.dopmi_payment_job_finish($1::jsonb)',[confirmation]);
  await a.query('commit');const read=await reading;
  assert.equal(read.error,undefined);assert.equal(read.value.rows[0].value.payment_status,'refunded');
  assert.equal((await a.query('select private.dopmi_case_occupied($1) n',[bill])).rows[0].n,0);
  assert.equal((await a.query('select count(*)::int n from private.dopmi_urgent_coverage_events where case_id=$1',[target])).rows[0].n,0);
  await a.query('select public.dopmi_payment_job_finish($1::jsonb)',[confirmation]);
  assert.equal((await a.query('select status from private.dopmi_payment_jobs where id=$1',[job.id])).rows[0].status,'done');
 }finally{
  await a.query('rollback');if(reading)await reading;
  await b.query('rollback');await Promise.all([a.end(),b.end()]);
 }
});

test('historical selection always includes current month from the authoritative Mexico City calendar',async()=>{
 await setActor();
 const expected=(await db.query("select date_trunc('month',timezone('America/Mexico_City',now()))::date::text as calendar_month")).rows[0].calendar_month;
 const result=await personal('2026-09-01');
 assert.equal(result.month,'2026-09-01');assert.equal(result.current_month,expected);
 assert.equal((await personal()).current_month,expected);
 const future=(await db.query("select (date_trunc('month',timezone('America/Mexico_City',now()))+interval '1 month')::date::text as calendar_month")).rows[0].calendar_month;
 await rejected(()=>personal(future),/Mes inv.lido/);
});
