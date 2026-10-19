import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { randomUUID } from 'node:crypto';

// Disposable local PostgreSQL engine only; never a remote URL, Auth or Stripe.
let db;
const owner=randomUUID(), donor=randomUUID();
before(async()=>{
  db=new PGlite();
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

  if (process.env.DOPMI_PUBLIC_PROFILE_PREPARED_SQL === 'true') {
    await db.exec(await readFile(new URL('../../.tools/integral20d21-20261018/sql/public-profile.sql',import.meta.url),'utf8'));
  }
  for(const id of [owner,donor]) await db.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[id,id+'@example.test']);
  await db.query(`insert into public.dopmi_rescue_records(owner_id,kind,status,approved_snapshot) values($1,'verification','approved','{"public_name":"Public snapshot","private_phone":"never project"}')`,[owner]);
  await db.query(`insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled) values($1,'acct_synthetic_public_profile',true,true)`,[owner]);
},{timeout:120000});
after(async()=>db?.close());
beforeEach(async()=>db.exec('begin'));
afterEach(async()=>db.exec('rollback'));
async function publicProfile(){return (await db.query('select public.dopmi_rescuer_public($1) value',[owner])).rows[0].value;}
async function metrics(){return (await db.query('select public.dopmi_rescuer_public_metrics($1) value',[owner])).rows[0].value;}
async function caseFixture(status='approved',snapshot=true){
 const id=randomUUID();
 await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,private_data) values($1,$2,'case',$3,$4::jsonb,'{"phone":"private-case-secret"}')`,[id,owner,status,snapshot?JSON.stringify({pet_name:'Approved public pet'}):null]);
 return id;
}
async function expense(caseId,{status='approved',target=9200,snapshot=true}={}){
 const id=randomUUID();
 await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values($1,$2,'expense',$3,$4::jsonb,$5,$6)`,[id,owner,status,snapshot?JSON.stringify({title:'Public need'}):null,caseId,target]);
 return id;
}
async function assertEligible(expected){
 const profile=await publicProfile(), count=(await metrics()).active_donation_cases;
 assert.deepEqual(profile.cases.filter(row=>row.accepts_support===true).map(row=>row.id).sort(),[...expected].sort());
 assert.equal(count,expected.length);
 for(const row of profile.cases) assert.equal(typeof row.accepts_support,'boolean');
 return profile;
}

test('zero cases and approved case without expenses expose zero support cards',async()=>{
 await assertEligible([]);
 const id=await caseFixture();
 const profile=await assertEligible([]);
 assert.equal(profile.cases.find(row=>row.id===id).accepts_support,false);
 assert.equal(profile.cases.length,1,'public historical snapshot remains');
});
test('one approved public expense enables its case and multiple expenses do not duplicate it',async()=>{
 const id=await caseFixture(); await expense(id); await assertEligible([id]);
 await expense(id); await assertEligible([id]);
 const other=await caseFixture(); await expense(other); await assertEligible([id,other]);
});
test('covered expense removes support eligibility but preserves public case history',async()=>{
 const id=await caseFixture(), need=await expense(id);
 const prepared=(await db.query(`select public.dopmi_payment_server('prepare',$1::jsonb) value`,[JSON.stringify({actor:donor,key:randomUUID(),expense_id:need,gross_cents:10000})])).rows[0].value;
 await db.query(`select public.dopmi_payment_server('settle',$1::jsonb)`,[JSON.stringify({donation_id:prepared.id,currency:'mxn',gross_cents:10000,stripe_fee_cents:600,charge_id:'ch_synthetic_profile',payment_intent_id:'pi_synthetic_profile'})]);
 assert.equal((await db.query('select public.dopmi_expense_funding($1) value',[need])).rows[0].value.funded_cents,9200);
 const profile=await assertEligible([]);
 assert.equal(profile.cases.length,1);
});
test('closed, withdrawn and nonpublic expenses cannot enable support',async()=>{
 const id=await caseFixture();
 await expense(id,{status:'closed'});
 await expense(id,{status:'changes_requested',snapshot:false});
 await expense(id,{snapshot:false});
 await assertEligible([]);
});
test('closed or withdrawn cases cannot accept support despite an approved expense',async()=>{
 const closed=await caseFixture('closed'); await expense(closed);
 const withdrawn=await caseFixture('changes_requested',false); await expense(withdrawn);
 const profile=await assertEligible([]);
 assert.equal(profile.cases.some(row=>row.id===closed),true,'closed historical snapshot remains');
 assert.equal(profile.cases.some(row=>row.id===withdrawn),false,'withdrawn unpublished case stays private');
});
test('profile privacy, contacts consent and public visibility remain enforced',async()=>{
 const id=await caseFixture(); await expense(id);
 await db.query(`insert into public.dopmi_rescuer_profiles(owner_id,display_name,bio,approved_snapshot,contact_consent,contact_publication_enabled) values($1,'UNREVIEWED NAME','UNREVIEWED BIO',$2::jsonb,false,false)`,[owner,JSON.stringify({display_name:'Approved rescuer',bio:'Approved public biography',contact_consent:true,public_email:'approved@example.test',public_phone:'+525555555555',public_address:'Approved address',website_url:'https://example.test'})]);
 const profile=await assertEligible([id]);
 assert.equal(profile.name,'Approved rescuer');
 assert.equal(profile.public_email,''); assert.equal(profile.public_phone,''); assert.equal(profile.public_address,''); assert.equal(profile.website_url,'');
 assert.equal(JSON.stringify(profile).includes('private-case-secret'),false);
 assert.equal(JSON.stringify(profile).includes('private_phone'),false);
 assert.equal(JSON.stringify(profile).includes('UNREVIEWED'),false);
 await db.query(`update public.profiles set account_status='suspended' where id=$1`,[owner]);
 assert.equal(await publicProfile(),null); assert.equal(await metrics(),null);
});
