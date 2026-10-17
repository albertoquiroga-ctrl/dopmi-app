import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { paymentService } from '../../supabase/functions/_shared/payments.mjs';

let db, admin, client;
const real = process.env.DOPMI_CASE_POSTGRES_TEST === 'true';
const database = `dopmi_case_test_${randomUUID().replaceAll('-', '')}`;
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

async function splitExpenses() {
 await db.query('update public.dopmi_rescue_records set reimbursable_cents=5000,urgent=true where id=$1',[expense]);
 await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents)
 values($1,$2,'expense','approved','{"title":"Alimento"}',$3,8000)`,[second,rescuer,caseId]);
}
async function settle(d,fee=600) {
 await call('bind',{payment_intent_id:'pi_case'});
 return (await db.query('select public.dopmi_payment_server($1,$2::jsonb) value',['settle',JSON.stringify({donation_id:d.id,currency:'mxn',gross_cents:10000,charge_id:'ch_case',payment_intent_id:'pi_case',stripe_fee_cents:fee})])).rows[0].value;
}
test('case preparation reserves ordered multiple expenses atomically and retries same parent',async()=>{
 await splitExpenses(); const d=await call('prepare',payload);
 assert.equal(d.expense_id,null);assert.equal(d.case_id,caseId);assert.equal(d.contribution_scope,'case');
 assert.deepEqual(await call('prepare',payload),d);
 assert.deepEqual((await db.query('select expense_id,reserved_cents from private.dopmi_case_allocations order by expense_id')).rows,
 [{expense_id:expense,reserved_cents:5000},{expense_id:second,reserved_cents:4800}]);
 await rejected(()=>call('prepare',{...payload,case_id:other}),/otros datos/);
 await rejected(()=>call('prepare',{...payload,key:other}),/asignarse completo/);
 assert.equal((await db.query('select count(*)::int n from public.dopmi_donations')).rows[0].n,1);
 assert.equal(await call('get',{actor:other}),null);
});
test('actual fees produce 9200 across two expenses, one transfer and owner receipt',async()=>{
 await splitExpenses();const d=await call('prepare',payload);const paid=await settle(d);
 assert.equal(paid.allocated_cents,9200);assert.equal(paid.refund_cents,0);
 assert.deepEqual((await db.query('select expense_id,reserved_cents,allocated_cents from private.dopmi_case_allocations order by expense_id')).rows,
 [{expense_id:expense,reserved_cents:0,allocated_cents:5000},{expense_id:second,reserved_cents:0,allocated_cents:4200}]);
 assert.equal((await db.query("select count(*)::int n from private.dopmi_payment_jobs where kind='transfer' and donation_id=$1",[d.id])).rows[0].n,1);
 assert.equal((await db.query('select public.dopmi_expense_funding($1) value',[expense])).rows[0].value.funded_cents,5000);
 await db.exec(`select set_config('request.jwt.claim.sub','${donor}',true)`);
 const history=(await db.query('select public.dopmi_payment_activity() value')).rows[0].value;
 assert.equal(history.items[0].id,d.id);assert.equal(history.items[0].allocation_count,2);
 assert.equal((await db.query('select public.dopmi_case_payment_allocations($1) value',[d.id])).rows[0].value.length,2);
 await rejected(()=>db.query('update public.dopmi_rescue_records set reimbursable_cents=4000 where id=$1',[expense]),/aportaciones asignadas/);
});
test('capacity loss refunds full gross and keeps holds until confirmed refund',async()=>{
 await splitExpenses();const d=await call('prepare',payload);
 await db.query("update public.dopmi_rescue_records set status='rejected' where id=$1",[second]);
 const paid=await settle(d);assert.equal(paid.allocated_cents,0);assert.equal(paid.refund_cents,10000);
 assert.equal(paid.reserved_cents,9800);assert.equal(paid.platform_fee_cents,0);assert.equal(paid.platform_loss_cents,600);
 assert.equal((await db.query("select count(*)::int n from private.dopmi_payment_jobs where kind='transfer' and donation_id=$1",[d.id])).rows[0].n,0);
 await db.query("update public.dopmi_donations set refund_status='refunded',payment_status='refunded',stripe_refund_id='re_case' where id=$1",[d.id]);
 assert.equal((await db.query('select sum(reserved_cents)::int n from private.dopmi_case_allocations')).rows[0].n,0);
});
test('case holds consume Guardian capacity once; confirmed cancellation releases them',async()=>{
 await splitExpenses();await call('prepare',payload);
 const g=(await db.query('select public.dopmi_guardian_reserve($1,$2,10000) value',[other,other])).rows[0].value;
 assert.equal(g.status,'skipped');
 await call('bind',{payment_intent_id:'pi_case'});await call('canceled',{payment_intent_id:'pi_case'});
 assert.equal((await db.query('select private.dopmi_shared_occupied($1) value',[expense])).rows[0].value,0);
});
test('new gateway and private ledger deny clients; breakdown denies another donor',async()=>{
 await splitExpenses();const d=await call('prepare',payload);
 for(const role of ['anon','authenticated']) {
 await db.exec(`set local role ${role}`);
 await rejected(()=>call('get'),/permission denied/);
 await rejected(()=>db.query('select * from private.dopmi_case_allocations'),/permission denied/);
 await db.exec('reset role');
 }
 await db.exec(`select set_config('request.jwt.claim.sub','${other}',true)`);
 await rejected(()=>db.query('select public.dopmi_case_payment_allocations($1)',[d.id]),/no disponible/);
});

test('real PostgreSQL: parallel case keys serialize against expense and Guardian capacity', {skip:!real}, async()=>{
 const a=new pg.Client({...config,database}),b=new pg.Client({...config,database}),c=new pg.Client({...config,database}),same=new pg.Client({...config,database});
 await Promise.all([a.connect(),b.connect(),c.connect(),same.connect()]);
 try {
  await Promise.all([a.query('begin'),b.query('begin'),c.query('begin'),same.query('begin')]);
  await a.query('set local statement_timeout=5000');await b.query('set local statement_timeout=5000');
  const request={actor:donor,key, ...payload,gross_cents:10000};
  const first=(await a.query('select public.dopmi_oneoff_case_server($1,$2::jsonb) value',['prepare',JSON.stringify(request)])).rows[0].value;
  const pending=b.query('select public.dopmi_guardian_reserve($1,$2,10000) value',[other,other]).finally(()=>b.query('rollback'));
  const oldExpense=c.query('select public.dopmi_oneoff_native_server($1,$2::jsonb) value',['prepare',JSON.stringify({actor:other,key:other,expense_id:expense,gross_cents:10000,consent:true,consent_version:payload.consent_version})]).then(value=>({value}),error=>({error})).finally(()=>c.query('rollback'));
  const duplicate=same.query('select public.dopmi_oneoff_case_server($1,$2::jsonb) value',['prepare',JSON.stringify(request)]).finally(()=>same.query('rollback'));
  const pids=[b.processID,c.processID,same.processID];
  const deadline=Date.now()+3000;let waiting=0;
  do {
   waiting=(await admin.query("select count(*)::int n from pg_stat_activity where pid=any($1::int[]) and wait_event_type='Lock'",[pids])).rows[0].n;
   if(waiting===3)break;
   await new Promise(resolve=>setTimeout(resolve,20));
  }while(Date.now()<deadline);
  assert.equal(waiting,3,'All competing requests must wait on shared transaction locks');
  await a.query('commit');
  assert.equal((await duplicate).rows[0].value.id,first.id);await same.query('rollback');
  assert.match((await oldExpense).error?.message??'',/asignarse completo/);await c.query('rollback');
  assert.equal((await pending).rows[0].value.status,'skipped');await b.query('rollback');
  const replay=(await a.query('select public.dopmi_oneoff_case_server($1,$2::jsonb) value',['prepare',JSON.stringify(request)])).rows[0].value;
  assert.equal(replay.id,first.id);
  await a.query('begin');
  await a.query('delete from private.dopmi_case_allocations where donation_id=$1',[first.id]);
  await a.query('delete from private.dopmi_checkouts where donation_id=$1',[first.id]);
  await a.query('delete from public.dopmi_donations where id=$1',[first.id]);
  await a.query('commit');
  // Fixture is confined to this fresh database, which teardown drops entirely.
 }finally{await Promise.allSettled([a.query('rollback'),b.query('rollback'),c.query('rollback'),same.query('rollback')]);await Promise.all([a.end(),b.end(),c.end(),same.end()]);}
});

test('expense/case key collision cannot move an existing attempt to another target',async()=>{
 const d=await call('prepare',payload);
 await rejected(()=>db.query('select public.dopmi_oneoff_native_server($1,$2::jsonb) value',['prepare',JSON.stringify({actor:donor,key,expense_id:expense,gross_cents:10000,consent:true,consent_version:payload.consent_version})]),/otros datos/);
 assert.equal((await call('get')).id,d.id);
});
test('allocation stays occupied through external refund review until full reversal is confirmed',async()=>{
 await splitExpenses();const d=await call('prepare',payload);await settle(d);
 await db.query("update public.dopmi_donations set transfer_status='transferred',stripe_transfer_id='tr_case' where id=$1",[d.id]);
 await db.query("update private.dopmi_payment_jobs set status='done' where donation_id=$1 and kind='transfer'",[d.id]);
 await db.query("select public.dopmi_refund_adjustment('begin',$1::jsonb)",[JSON.stringify({donation_id:d.id})]);
 assert.equal((await db.query('select private.dopmi_case_occupied($1) n',[expense])).rows[0].n,5000);
 const job=(await db.query('select public.dopmi_payment_job_claim($1) value',['reversal:'+d.id])).rows[0].value;
 const proof={job_id:job.id,lease:job.lease,charge_id:'ch_case',transfer_id:'tr_case',refund_cents:10000,reversed_cents:9200,reversal_id:'trr_case',refund_id:'re_case',refund_ids:['re_case']};
 await rejected(()=>db.query("select public.dopmi_refund_adjustment('finish',$1::jsonb)",[JSON.stringify({...proof,reversed_cents:9199})]),/no coincide/);
 assert.equal((await db.query('select private.dopmi_case_occupied($1) n',[expense])).rows[0].n,5000);
 await db.query("select public.dopmi_refund_adjustment('finish',$1::jsonb)",[JSON.stringify(proof)]);
 const totals=(await db.query('select sum(allocated_cents)::int allocated,sum(reversed_cents)::int reversed from private.dopmi_case_allocations where donation_id=$1',[d.id])).rows[0];
 assert.deepEqual(totals,{allocated:9200,reversed:9200});
 assert.equal((await db.query('select private.dopmi_case_occupied($1) n',[expense])).rows[0].n,0);
});
test('case checkout denies suspended donor and supporting own case before a reservation',async()=>{
 await rejected(()=>call('prepare',{...payload,actor:rescuer}),/no disponible/);
 await db.query("update public.profiles set account_status='suspended' where id=$1",[donor]);
 await rejected(()=>call('prepare',payload),/activa y confirmada/);
 assert.equal((await db.query('select count(*)::int n from private.dopmi_case_allocations')).rows[0].n,0);
});
test('case full-refund worker retries response loss with same request, releasing holds only on confirmed result',async()=>{
 await splitExpenses();const d=await call('prepare',payload);
 await db.query("update public.dopmi_rescue_records set status='rejected' where id=$1",[second]);
 await settle(d);let lost=true;const calls=[];
 const service=paymentService({returnUrl:'https://example.test/return',logger:{info(){},error(){}},
 rpc:async(op,data)=>{
 const query=op==='claim'?'select public.dopmi_payment_job_claim($1) value':
 op==='finish_job'?'select public.dopmi_payment_job_finish($1::jsonb) value':
 op==='replay_get'?'select public.dopmi_payment_replay_get($1::uuid) value':
 'select public.dopmi_payment_server($1,$2::jsonb) value';
 const args=op==='claim'?[data.job_key]:op==='finish_job'?[JSON.stringify(data)]:op==='replay_get'?[data.donation_id]:[op,JSON.stringify(data)];
 return (await db.query(query,args)).rows[0].value;
 },stripe:async(path,body,key)=>{
 assert.equal(path,'refunds');assert.equal(body.amount,10000);assert.equal(body.charge,'ch_case');calls.push({body,key});
 if(lost){lost=false;throw Error('lost after accepted');}return {id:'re_worker',status:'succeeded'};
 }});
 await assert.rejects(()=>service.reprocessDonation(d.id),/processor_unavailable/);
 assert.equal((await db.query('select private.dopmi_case_occupied($1) n',[expense])).rows[0].n,5000);
 await db.exec('update private.dopmi_payment_jobs set available_at=now()');
 const done=await service.reprocessDonation(d.id);assert.equal(done.payment_status,'refunded');
 assert.equal(done.refund_cents,10000);assert.deepEqual(calls[0],calls[1]);
 assert.equal((await db.query('select private.dopmi_case_occupied($1) n',[expense])).rows[0].n,0);
});
test('oldest approval wins first; equal approval timestamps break ties by stable expense id',async()=>{
 await splitExpenses();
 const third='95000000-0000-4000-8000-000000000005';
 await db.query(`update public.dopmi_rescue_records set urgent=false,approved_at='2026-10-15T12:00:00Z' where id=$1`,[expense]);
 await db.query(`update public.dopmi_rescue_records set reimbursable_cents=5000,approved_at='2026-10-14T12:00:00Z' where id=$1`,[second]);
 await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents,approved_at)
 values($1,$2,'expense','approved','{"title":"Consulta"}',$3,5000,'2026-10-14T12:00:00Z')`,[third,rescuer,caseId]);
 const d=await call('prepare',payload);
 assert.deepEqual((await db.query('select expense_id,reserved_cents from private.dopmi_case_allocations where donation_id=$1 order by expense_id',[d.id])).rows,
 [{expense_id:second,reserved_cents:5000},{expense_id:third,reserved_cents:4800}]);
 await settle(d);
 assert.deepEqual((await db.query('select expense_id,allocated_cents from private.dopmi_case_allocations where donation_id=$1 order by expense_id',[d.id])).rows,
 [{expense_id:second,allocated_cents:5000},{expense_id:third,allocated_cents:4200}]);
});
test('exact ten-peso minimum is accepted and lower gross has no financial reservation',async()=>{
 await rejected(()=>call('prepare',{...payload,gross_cents:999}),/Elige de/);
 const d=await call('prepare',{...payload,gross_cents:1000});
 assert.equal(d.gross_cents,1000);assert.equal(d.reserved_cents,980);
 assert.equal((await db.query('select sum(reserved_cents)::int n from private.dopmi_case_allocations')).rows[0].n,980);
});
test('own paid receipt and private allocation titles survive withdrawal of public case snapshot',async()=>{
 await splitExpenses();const d=await call('prepare',payload);await settle(d);
 await db.query("update public.dopmi_rescue_records set status='changes_requested',approved_snapshot=null where id=$1",[caseId]);
 await db.exec(`select set_config('request.jwt.claim.sub','${donor}',true)`);
 const history=(await db.query('select public.dopmi_payment_activity() value')).rows[0].value;
 assert.equal(history.items[0].id,d.id);assert.equal(history.items[0].assigned_cents,9200);assert.equal(history.items[0].case_name,null);
 const receipt=(await db.query('select public.dopmi_case_payment_allocations($1) value',[d.id])).rows[0].value;
 assert.equal(receipt.length,2);assert.equal(receipt[0].title,'Medicamentos');assert.equal(receipt[1].title,'Alimento');
});
