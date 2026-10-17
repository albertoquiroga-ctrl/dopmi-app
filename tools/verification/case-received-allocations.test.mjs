import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { nativeSavedCardService } from '../../supabase/functions/_shared/native-saved-card.mjs';

let db, admin, client;
const real = process.env.DOPMI_RECEIVED_POSTGRES_TEST === 'true';
const database = `dopmi_received_case_test_${randomUUID().replaceAll('-', '')}`;
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
const caseId='95000000-0000-4000-8000-000000000002';
const secondCase='95000000-0000-4000-8000-000000000004';
const secondExpense='95000000-0000-4000-8000-000000000005';
async function paid(){
 const data={actor:donor,key,case_id:caseId,gross_cents:10000,consent:true,consent_version:'oneoff-test-2026-10-15'};
 const d=(await db.query("select public.dopmi_oneoff_case_server('prepare',$1::jsonb) value",[JSON.stringify(data)])).rows[0].value;
 await db.query("select public.dopmi_oneoff_case_server('bind',$1::jsonb)",[JSON.stringify({actor:donor,key,payment_intent_id:'pi_received'})]);
 await db.query("select public.dopmi_payment_server('settle',$1::jsonb)",[JSON.stringify({donation_id:d.id,currency:'mxn',gross_cents:10000,stripe_fee_cents:600,charge_id:'ch_received',payment_intent_id:'pi_received'})]);
 await db.query("update public.dopmi_donations set transfer_status='transferred',stripe_transfer_id='tr_received' where id=$1",[d.id]);
 return d.id;
}
async function actor(id=rescuer){await db.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);}
const received=id=>db.query('select public.dopmi_case_received_allocations($1) value',[id]).then(r=>r.rows[0].value);
async function rejected(fn,regex){await db.exec('savepoint denied');await assert.rejects(fn,regex);await db.exec('rollback to savepoint denied');}
async function ledger(){return(await db.query('select to_jsonb(d) parent,(select jsonb_agg(to_jsonb(a) order by a.expense_id) from private.dopmi_case_allocations a where a.donation_id=d.id) allocations from public.dopmi_donations d order by d.id')).rows;}
test('receiver reads only their settled case allocation without mutation or private donor/reservation fields',async()=>{
 const id=await paid();await actor();await db.exec('set local role authenticated');
 const rows=await received(id);assert.deepEqual(rows,[{expense_id:expense,title:'Medicamentos',allocated_cents:9200,reversed_cents:0,remaining_cents:9200}]);
 assert.equal(JSON.stringify(rows).includes('reserved'),false);assert.equal(JSON.stringify(rows).includes('donor'),false);
 await db.exec('reset role');const before=await ledger();await received(id);assert.deepEqual(await ledger(),before);
});
test('donor, other actor, forged metadata admin, anonymous and service role cannot read received case allocations',async()=>{
 const id=await paid();
 for(const person of [donor,other]){await actor(person);await db.exec('set local role authenticated');await rejected(()=>received(id),/Aportación no disponible/);await db.exec('reset role');}
 await db.query(`update auth.users set raw_user_meta_data='{"role":"admin","is_admin":true,"active_mode":"rescuer"}' where id=$1`,[other]);
 await actor(other);await db.exec('set local role authenticated');await rejected(()=>received(id),/Aportación no disponible/);await db.exec('reset role');
 await actor(null);await db.exec('set local role anon');await rejected(()=>received(id),/permission denied/);await db.exec('reset role');
 await db.exec('set local role service_role');await rejected(()=>received(id),/permission denied/);await db.exec('reset role');
});
test('receiver can read historical full reversal after snapshot withdrawal with generic title',async()=>{
 const id=await paid();
 await db.query(`update public.dopmi_donations set payment_status='refunded',refund_status='refunded',transfer_status='reversed',
 allocated_cents=0,refund_cents=10000,net_cents=10000,platform_loss_cents=800,
 stripe_reversal_id='trr_received',stripe_refund_id='re_received' where id=$1`,[id]);
 await db.query('update public.dopmi_rescue_records set approved_snapshot=null where id=$1',[expense]);
 await db.query("update public.dopmi_rescue_records set status='closed' where id=$1",[caseId]);
 await actor();await db.exec('set local role authenticated');
 assert.deepEqual(await received(id),[{expense_id:expense,title:'Gasto aprobado',allocated_cents:9200,reversed_cents:9200,remaining_cents:0}]);
});
test('pending reservations are unavailable and suspended receivers retain existing account guard',async()=>{
 const pending=(await db.query("select public.dopmi_oneoff_case_server('prepare',$1::jsonb) value",[JSON.stringify({actor:donor,key,case_id:caseId,gross_cents:10000,consent:true,consent_version:'oneoff-test-2026-10-15'})])).rows[0].value;
 await actor();await rejected(()=>received(pending.id),/Aportación no disponible/);
 const id=await paid();await db.query("update public.profiles set account_status='suspended' where id=$1",[rescuer]);
 await rejected(()=>received(id),{code:'42501'});
});
test('allocations from a different case are excluded even for the same receiver',async()=>{
 const id=await paid();
 await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
 ($1,$3,'case','approved','{"pet_name":"Otro caso"}',null,0),($2,$3,'expense','approved','{"title":"No pertenece"}',$1,5000)`,[secondCase,secondExpense,rescuer]);
 // Deliberately inconsistent private fixture verifies the read boundary itself.
 await db.query(`insert into private.dopmi_case_allocations(donation_id,expense_id,expense_title,allocated_cents,allocated_at) values($1,$2,'Private other case',1000,now())`,[id,secondExpense]);
 await actor();const rows=await received(id);assert.equal(rows.length,1);assert.equal(rows[0].expense_id,expense);
});
