import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { createHmac } from 'node:crypto';
import { verifySignature, requireTestKey, paymentService, stripeApi } from '../../supabase/functions/_shared/payments.mjs';

let db;
const donor = '70000000-0000-4000-8000-000000000001';
const rescuer = '70000000-0000-4000-8000-000000000002';
const staff = '70000000-0000-4000-8000-000000000003';
const other = '70000000-0000-4000-8000-000000000004';
const expense = '71000000-0000-4000-8000-000000000003';
const key = '72000000-0000-4000-8000-000000000001';
before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;`);
  const path = new URL('../../supabase/migrations/',import.meta.url);
  for (const file of (await readdir(path)).filter(v => v.endsWith('.sql')).sort()) await db.exec(await readFile(new URL(file,path),'utf8'));
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    select id::uuid,id||'@example.test',now(),'{"display_name":"Prueba","terms_accepted":true,"terms_version":"development-2026-09-13"}' from unnest($1::text[]) id`,[[donor,rescuer,staff,other]]);
  await db.query('insert into private.admin_memberships(user_id) values($1)',[staff]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
    ('71000000-0000-4000-8000-000000000001',$1,'verification','approved','{"public_name":"Refugio"}',null,0),
    ('71000000-0000-4000-8000-000000000002',$1,'case','approved','{"pet_name":"Luna"}',null,0),
    ($2,$1,'expense','approved','{"title":"Medicamentos"}','71000000-0000-4000-8000-000000000002',12000)`,[rescuer,expense]);
  await db.query(`insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled) values($1,'acct_test',true,true)`,[rescuer]);
});
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));
const rpc = async (operation,data) => (await db.query('select public.dopmi_payment_server($1,$2::jsonb) as value',[operation,JSON.stringify(data)])).rows[0].value;
const prepare = (overrides={}) => rpc('prepare',{actor:donor,expense_id:expense,key,gross_cents:10000,...overrides});
const settle = (id,overrides={}) => rpc('settle',{donation_id:id,currency:'mxn',gross_cents:10000,charge_id:'ch_one',payment_intent_id:'pi_one',stripe_fee_cents:600,...overrides});
async function rejected(fn,pattern) {
  await db.exec('savepoint expected_failure');
  await assert.rejects(fn,pattern);
  await db.exec('rollback to savepoint expected_failure');
}
async function role(id,name='authenticated') {
  await db.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);
  await db.exec(`set local role ${name}`);
}
test('payment writes are service-only, including for administrators',async () => {
  for (const actor of [donor,staff]) {
    await role(actor);
    await rejected(() => prepare(),/permission denied/);
    await rejected(() => db.exec("update public.dopmi_donations set payment_status='confirmed'"),/permission denied/);
    await db.exec('reset role');
  }
  await role('', 'service_role');
  assert.equal((await prepare()).payment_status,'pending');
});
test('2% of gross and actual processor fee leave exactly the rescuer net',async () => {
  const d=await prepare();
  const paid=await settle(d.id);
  assert.equal(paid.platform_fee_cents,200);
  assert.equal(paid.stripe_fee_cents,600);
  assert.equal(paid.allocated_cents,9200);
  assert.equal(paid.transfer_status,'pending');
  assert.equal(paid.payment_status,'confirmed');
  assert.equal(paid.reserved_cents,0);
  assert.equal(paid.refund_cents,0);
});
test('same intent and different event IDs cannot allocate or transfer twice',async () => {
  const d=await prepare(); await settle(d.id); await settle(d.id);
  await rpc('enqueue',{event_id:'evt_a'}); await rpc('enqueue',{event_id:'evt_a'});
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_payment_jobs')).rows[0].n,2);
  assert.equal((await prepare()).id,d.id);
  await rejected(() => prepare({gross_cents:11000}),/otros datos/);
  await rejected(() => settle(d.id,{charge_id:'ch_other'}),/distinto/);
});
test('reservations prevent overbooking and settled payments never exceed the selected expense',async () => {
  const first=await prepare();
  const second=await prepare({actor:other,key:'72000000-0000-4000-8000-000000000002'});
  await rejected(() => prepare({key:'72000000-0000-4000-8000-000000000003'}),/cubierto/);
  await settle(second.id,{charge_id:'ch_two',payment_intent_id:'pi_two'});
  const paid=await settle(first.id);
  assert.equal(paid.allocated_cents,2800);
  assert.equal(paid.refund_cents,6400);
  assert.equal(paid.gross_cents,paid.platform_fee_cents+paid.stripe_fee_cents+paid.allocated_cents+paid.refund_cents);
  assert.equal((await db.query('select sum(allocated_cents)::int as n from public.dopmi_donations')).rows[0].n,12000);
});
test('approval revoked after checkout causes full refund with processor loss absorbed',async () => {
  const d=await prepare();
  await db.query("update public.dopmi_rescue_records set status='changes_requested' where id=$1",[expense]);
  const paid=await settle(d.id);
  assert.equal(paid.refund_cents,10000); assert.equal(paid.allocated_cents,0);
  assert.equal(paid.platform_fee_cents,0); assert.equal(paid.platform_loss_cents,600);
  assert.equal((await db.query("select count(*)::int as n from private.dopmi_payment_jobs where kind='transfer'")).rows[0].n,0);
});
test('unsupported currency, amount mismatch and unknown fee never settle',async () => {
  const d=await prepare();
  await rejected(() => settle(d.id,{currency:'usd'}),/coincide/);
  await rejected(() => settle(d.id,{gross_cents:9999}),/coincide/);
  await rejected(() => settle(d.id,{stripe_fee_cents:null}),/pendiente/);
  assert.equal((await rpc('get',{donation_id:d.id})).payment_status,'pending');
});
test('suspended and unverified rescuers and disabled Connect accounts cannot receive payments',async () => {
  await db.query("update public.profiles set account_status='suspended' where id=$1",[rescuer]);
  await rejected(() => prepare(),/disponible/);
  await db.query("update public.profiles set account_status='active' where id=$1",[rescuer]);
  await db.exec("update private.dopmi_connect_accounts set transfers_enabled=false");
  await rejected(() => prepare(),/disponible/);
  await db.exec("update private.dopmi_connect_accounts set transfers_enabled=true");
  await db.exec("update public.dopmi_rescue_records set status='changes_requested' where kind='verification'");
  await rejected(() => prepare(),/disponible/);
});
test('financial history remains private and funded approvals cannot be erased',async () => {
  const d=await prepare(); await settle(d.id);
  await rejected(() => db.query('update public.dopmi_rescue_records set reimbursable_cents=0 where id=$1',[expense]),/ya tiene aportaciones/);
  await role(other);
  assert.equal((await db.query('select * from public.dopmi_donations')).rows.length,0);
  await rejected(() => db.exec('select public.dopmi_admin_donations()'),/administrativo/);
  await role(donor);
  assert.equal((await db.query('select * from public.dopmi_donations')).rows.length,1);
  await role('', 'anon');
  await rejected(() => db.exec('select * from public.dopmi_donations'),/permission denied/);
  const funding=(await db.query('select public.dopmi_expense_funding($1) as value',[expense])).rows[0].value;
  assert.equal(funding.funded_cents,9200); assert.equal(funding.donor_id,undefined);
});
test('job leases reject stale workers and stop retries outside Stripe retention',async () => {
  const d=await prepare(); await settle(d.id);
  const job=await rpc('claim',{}); assert.equal(await rpc('claim',{}),null);
  await rejected(() => rpc('finish_job',{job_id:job.id,lease:key,result_id:'tr_forged'}),/vencido/);
  await rpc('finish_job',{job_id:job.id,lease:job.lease,error_code:'timeout'});
  await db.exec("update private.dopmi_payment_jobs set available_at=now(),first_attempt_at=now()-interval '25 hours'");
  assert.equal((await rpc('claim',{})).skipped,true);
  assert.equal((await rpc('get',{donation_id:d.id})).transfer_status,'attention');
});
test('Stripe signature requires unchanged body, fresh timestamp and test event',async () => {
  const secret='whsec_test_fixture'; const now=Date.now(); const stamp=Math.floor(now/1000);
  const body=JSON.stringify({id:'evt_test',livemode:false});
  const sig=createHmac('sha256',secret).update(`${stamp}.${body}`).digest('hex');
  assert.equal((await verifySignature(body,`t=${stamp},v1=${sig}`,secret,now)).id,'evt_test');
  await assert.rejects(() => verifySignature(body+' ',`t=${stamp},v1=${sig}`,secret,now),/invalid_signature/);
  await assert.rejects(() => verifySignature(body,`t=${stamp},v1=${sig}`,secret,now+301000),/invalid_signature/);
  assert.throws(() => requireTestKey('sk_live_fixture'),/payments_not_configured/);
});
test('Stripe requests retain the same idempotency key and refuse live objects',async () => {
  let captured;
  const stripe=stripeApi('sk_test_fixture',async (url,request) => { captured={url,request}; return new Response(JSON.stringify({id:'tr_test',livemode:false})); });
  await stripe('transfers',{amount:9200,source_transaction:'ch_one'},'dopmi-transfer-one');
  assert.equal(captured.request.headers['Idempotency-Key'],'dopmi-transfer-one');
  assert.equal(captured.request.body.get('source_transaction'),'ch_one');
  await assert.rejects(() => stripeApi('sk_test_fixture',async () => new Response('{"livemode":true}'))('events/evt_one'),/live_mode_rejected/);
});
test('Connect onboarding is resumable and payout status is read from the connected account',async () => {
  await db.exec('delete from private.dopmi_connect_accounts');
  const calls=[];
  const stripe=async (path,body,idempotency,account) => {
    calls.push({path,body,idempotency,account});
    if (path === 'accounts') return {id:'acct_new',livemode:false};
    if (path === 'accounts/acct_new') return {id:'acct_new',livemode:false,details_submitted:true,
      payouts_enabled:true,capabilities:{transfers:'active'}};
    if (path === 'account_links') return {url:'https://connect.stripe.com/setup/test'};
    if (path === 'payouts?limit=10') return {data:[{id:'po_one',amount:8000,currency:'mxn',status:'paid',arrival_date:1800000000}]};
    throw new Error(`unexpected Stripe path ${path}`);
  };
  const service=paymentService({rpc,stripe,returnUrl:'https://example.test/return'});
  assert.equal((await service.connect(rescuer,'onboard')).url,'https://connect.stripe.com/setup/test');
  const create=calls.find(call => call.path === 'accounts');
  assert.equal(create.idempotency,`dopmi-account-${rescuer}`);
  assert.equal(create.body.country,'MX');
  assert.equal(create.body['capabilities[transfers][requested]'],true);
  const status=await service.connect(rescuer,'status');
  assert.equal(status.ready,true);
  assert.equal(status.details_submitted,true);
  assert.deepEqual(status.payouts,[{id:'po_one',amount:8000,currency:'mxn',status:'paid',arrival_date:1800000000}]);
  assert.equal(calls.find(call => call.path === 'payouts?limit=10').account,'acct_new');
  assert.equal(calls.filter(call => call.path === 'accounts').length,1);
});
test('worker retries a lost Stripe response without creating a second transfer',async () => {
  const d=await prepare(); await settle(d.id);
  const calls=[]; let fail=true;
  const stripe=async (path,body,idempotency) => {
    if (path.startsWith('charges/')) return {disputed:false,amount_refunded:0};
    calls.push({path,body,idempotency});
    if (fail) { fail=false; throw new Error('lost response'); }
    return {id:'tr_one',amount:9200,destination:'acct_test'};
  };
  const service=paymentService({rpc,stripe,returnUrl:'https://example.test/return'});
  await service.work();
  await db.exec('update private.dopmi_payment_jobs set available_at=now()');
  await service.work();
  assert.equal(calls.length,2); assert.equal(calls[0].idempotency,calls[1].idempotency);
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.stripe_transfer_id,'tr_one'); assert.equal(result.transfer_status,'transferred');
});
