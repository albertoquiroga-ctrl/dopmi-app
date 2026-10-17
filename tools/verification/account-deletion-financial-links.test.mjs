import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { nativeSavedCardService } from '../../supabase/functions/_shared/native-saved-card.mjs';

let db, admin, client;
const real = process.env.DOPMI_DELETION_POSTGRES_TEST === 'true';
const database = `dopmi_deletion_links_test_${randomUUID().replaceAll('-', '')}`;
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
const unfunded='95000000-0000-4000-8000-000000000004';
const deletion=(operation)=>db.query('select public.dopmi_account_deletion_server($1,$2::jsonb) value',[operation,JSON.stringify({owner_id:rescuer,request_key:key})]).then(r=>r.rows[0].value);
async function fixture(kind,{reversed=false}={}){
 const details={public_data:{title:'Medicamentos'},private_data:{invoice:'private-fixture'},files:[{path:'private/invoice-fixture.pdf'}]};
 await db.query('update public.dopmi_rescue_records set public_data=$2,private_data=$3,files=$4 where id=$1',[expense,JSON.stringify(details.public_data),JSON.stringify(details.private_data),JSON.stringify(details.files)]);
 await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,parent_id,public_data,private_data,files) values($1,$2,'expense','draft',$3,'{"title":"Borrador"}','{"note":"private"}','[{"path":"draft"}]')`,[unfunded,rescuer,caseId]);
 await db.query(`insert into storage.objects(bucket_id,name,owner_id,metadata) values('rescue-private','private/invoice-fixture.pdf',$1,'{"financial":true}')`,[rescuer]);
 if(kind==='case'){
  const d=(await db.query(`select public.dopmi_oneoff_case_server('prepare',$1::jsonb) value`,[JSON.stringify({actor:donor,key,case_id:caseId,gross_cents:10000,consent:true,consent_version:'oneoff-test-2026-10-15'})])).rows[0].value;
  await db.query(`select public.dopmi_oneoff_case_server('bind',$1::jsonb)`,[JSON.stringify({actor:donor,key,payment_intent_id:'pi_deletion'})]);
  await db.query(`select public.dopmi_payment_server('settle',$1::jsonb)`,[JSON.stringify({donation_id:d.id,currency:'mxn',gross_cents:10000,stripe_fee_cents:600,charge_id:'ch_deletion',payment_intent_id:'pi_deletion'})]);
  await db.query("update public.dopmi_donations set transfer_status='transferred',stripe_transfer_id='tr_deletion' where id=$1",[d.id]);
  await db.query("update private.dopmi_payment_jobs set status='done' where donation_id=$1 and kind='transfer'",[d.id]);
  if(reversed)await db.query('update private.dopmi_case_allocations set reversed_cents=allocated_cents,reversed_at=now() where donation_id=$1',[d.id]);
 }else{
  const cycle=(await db.query('select public.dopmi_guardian_reserve($1,$2,10000) value',[donor,key])).rows[0].value;
  assert.equal(cycle.status,'reserved');
  await db.query(`insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,charge_id,invoice_payment_id,gross_cents,stripe_fee_cents,platform_fee_cents,allocated_cents,refund_cents,evidence)
   values($1,'in_deletion','pi_deletion','ch_deletion','inpay_deletion',10000,0,200,9800,0,'{}')`,[cycle.id]);
  await db.query(`update private.dopmi_guardian_allocations set allocated_cents=amount_cents,stripe_transfer_id='tr_deletion',transferred_at=now(),destination='acct_synthetic',reversed_cents=case when $2 then amount_cents else 0 end where cycle_id=$1`,[cycle.id,reversed]);
  await db.query("update private.dopmi_guardian_cycles set status='allocated',reserved_cents=0 where id=$1",[cycle.id]);
 }
 return details;
}
async function evidence(){
 const tables=['public.dopmi_donations','private.dopmi_case_allocations','private.dopmi_guardian_cycles','private.dopmi_guardian_allocations','private.dopmi_guardian_settlements','storage.objects'];
 const result={};for(const table of tables)result[table]=(await db.query('select to_jsonb(t) value from '+table+' t order by to_jsonb(t)::text')).rows;
 return result;
}
for(const kind of ['case','guardian'])for(const reversed of [false,true])test('deletion preserves '+kind+' historical financial links '+(reversed?'after reversal':'after transfer')+' and completes idempotently',async()=>{
 const details=await fixture(kind,{reversed});const before=await evidence();
 assert.equal((await deletion('request')).status,'procesando');
 assert.equal((await deletion('finalize')).status,'completado');
 assert.equal((await deletion('finalize')).status,'completado');assert.equal((await deletion('request')).status,'completado');
 assert.deepEqual(await evidence(),before);
 const record=(await db.query('select status,public_data,private_data,files,approved_snapshot from public.dopmi_rescue_records where id=$1',[expense])).rows[0];
 assert.equal(record.status,'approved');assert.deepEqual(record.public_data,details.public_data);assert.deepEqual(record.private_data,details.private_data);assert.deepEqual(record.files,details.files);
 const draft=(await db.query('select status,public_data,private_data,files from public.dopmi_rescue_records where id=$1',[unfunded])).rows[0];
 assert.deepEqual(draft,{status:'closed',public_data:{},private_data:{},files:[]});
 assert.equal((await db.query('select account_status from public.profiles where id=$1',[rescuer])).rows[0].account_status,'deleted');
 assert.equal((await db.query('select private.dopmi_rescue_public_visible(r) visible from public.dopmi_rescue_records r where id=$1',[expense])).rows[0].visible,false);
 assert.equal((await db.query('select private.dopmi_rescue_public_visible(r) visible from public.dopmi_rescue_records r where id=$1',[caseId])).rows[0].visible,false);
});
