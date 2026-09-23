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
const rpc = async (operation,data) => {
  if (operation === 'refund_begin' || operation === 'refund_finish') return (await db.query('select public.dopmi_refund_adjustment($1,$2::jsonb) as value',[operation === 'refund_begin' ? 'begin' : 'finish',JSON.stringify(data)])).rows[0].value;
  if (operation === 'finish_job') return (await db.query('select public.dopmi_payment_job_finish($1::jsonb) as value',[JSON.stringify(data)])).rows[0].value;
  if (operation === 'claim') return (await db.query('select public.dopmi_payment_job_claim($1) as value',[data.job_key ?? null])).rows[0].value;
  if (operation === 'replay_get') return (await db.query('select public.dopmi_payment_replay_get($1) as value',[data.donation_id])).rows[0].value;
  if (operation === 'connect_status') return (await db.query('select public.dopmi_connect_status($1) as value',[data.actor])).rows[0].value;
  return (await db.query('select public.dopmi_payment_server($1,$2::jsonb) as value',[operation,JSON.stringify(data)])).rows[0].value;
};
const prepare = (overrides={}) => rpc('prepare',{actor:donor,expense_id:expense,key,gross_cents:10000,...overrides});
const settle = (id,overrides={}) => rpc('settle',{donation_id:id,currency:'mxn',gross_cents:10000,charge_id:'ch_one',payment_intent_id:'pi_one',stripe_fee_cents:600,...overrides});
const transferResult = (d,id,amount=9200) => ({id,amount,destination:'acct_test',currency:'mxn',source_transaction:'ch_one',transfer_group:`dopmi_${d.id}`,reversed:false,amount_reversed:0});
function stripeFixture(d, overrides={}) {
  const calls=[];
  return { calls, stripe:async (path,body,idempotency,account) => {
    calls.push({path,body,idempotency,account});
    if (Object.hasOwn(overrides,path)) return overrides[path](body,idempotency,account);
    if (path === 'events/evt_intent') return {livemode:false,type:'payment_intent.succeeded',data:{object:{id:'pi_one'}}};
    if (path === 'events/evt_session') return {livemode:false,type:'checkout.session.completed',data:{object:{id:'cs_one'}}};
    if (path === 'checkout/sessions/cs_one') return {metadata:{dopmi_donation:d.id},payment_status:'paid',payment_intent:'pi_one'};
    if (path.startsWith('payment_intents/pi_one')) return {id:'pi_one',status:'succeeded',metadata:{dopmi_donation:d.id},amount_received:10000,currency:'mxn',latest_charge:{id:'ch_one',paid:true,captured:true,disputed:false,amount:10000,currency:'mxn',amount_refunded:0,balance_transaction:{amount:10000,currency:'mxn',fee:600}}};
    if (path === 'accounts/acct_test') return {id:'acct_test',payouts_enabled:true,details_submitted:true,capabilities:{transfers:'active'}};
    if (path === 'charges/ch_one') return {disputed:false,amount_refunded:0};
    if (path === 'transfers') return transferResult(d,'tr_fixture');
    if (path === 'payouts?limit=10') return {data:[]};
    throw new Error(`unexpected Stripe path ${path}`);
  }};
}
const serviceFor = (stripe, overrideRpc=rpc) => paymentService({rpc:overrideRpc,stripe,returnUrl:'https://example.test/return',logger:{}});
test('unsuccessful payment does not confirm, allocate or transfer funds',async () => {
  const d=await prepare();
  const fixture=stripeFixture(d,{
    'payment_intents/pi_one?expand[]=latest_charge.balance_transaction':async ()=>({id:'pi_one',status:'requires_payment_method',metadata:{dopmi_donation:d.id}}),
  });
  assert.equal(await serviceFor(fixture.stripe).settleIntent('pi_one',d.id),null);
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.payment_status,'pending');
  assert.equal(result.allocated_cents,0);
  assert.equal(fixture.calls.some(c=>c.path==='transfers'),false);
});
test('expired unpaid checkout releases reservation and never transfers',async () => {
  const d=await prepare();
  const fixture=stripeFixture(d,{
    'events/evt_expired':async ()=>({livemode:false,type:'checkout.session.expired',data:{object:{id:'cs_one'}}}),
    'checkout/sessions/cs_one':async ()=>({metadata:{dopmi_donation:d.id},status:'expired',payment_status:'unpaid'}),
  });
  await serviceFor(fixture.stripe).handleWebhook('evt_expired');
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.payment_status,'canceled');
  assert.equal(result.reserved_cents,0);
  assert.equal(result.allocated_cents,0);
  assert.equal(fixture.calls.some(c=>c.path==='transfers'),false);
});
test('unassignable payment refund completes once and replay does not create another refund',async () => {
  const d=await prepare();
  await db.query("update public.dopmi_rescue_records set status='changes_requested' where id=$1",[expense]);
  await settle(d.id);
  const fixture=stripeFixture(d,{refunds:async body => {
    assert.equal(body.amount,10000);
    assert.equal(body.charge,'ch_one');
    return {id:'re_full',status:'succeeded'};
  }});
  const service=serviceFor(fixture.stripe);
  const result=await service.reprocessDonation(d.id);
  assert.equal(result.payment_status,'refunded');
  assert.equal(result.refund_status,'refunded');
  assert.equal(result.stripe_refund_id,'re_full');
  await service.reprocessDonation(d.id);
  assert.equal(fixture.calls.filter(c=>c.path==='refunds').length,1);
  assert.equal(fixture.calls.filter(c=>c.path==='transfers').length,0);
});
test('refund lost response retries with the same idempotency key and amount',async () => {
  const d=await prepare();
  await db.query("update public.dopmi_rescue_records set status='changes_requested' where id=$1",[expense]);
  await settle(d.id);
  let attempts=0;
  const fixture=stripeFixture(d,{refunds:async () => {
    if (++attempts===1) throw new Error('response lost after Stripe accepted refund');
    return {id:'re_recovered',status:'succeeded'};
  }});
  const service=serviceFor(fixture.stripe);
  await assert.rejects(()=>service.reprocessDonation(d.id),/processor_unavailable/);
  await db.exec('update private.dopmi_payment_jobs set available_at=now()');
  assert.equal((await service.reprocessDonation(d.id)).stripe_refund_id,'re_recovered');
  const calls=fixture.calls.filter(c=>c.path==='refunds');
  assert.equal(calls.length,2);
  assert.equal(calls[0].idempotency,calls[1].idempotency);
  assert.deepEqual(calls[0].body,calls[1].body);
});
test('pending processor refund is not reported as refunded',async () => {
  const d=await prepare();
  await db.query("update public.dopmi_rescue_records set status='changes_requested' where id=$1",[expense]);
  await settle(d.id);
  const fixture=stripeFixture(d,{
    refunds:async ()=>({id:'re_pending',status:'pending'}),
    'refunds/re_pending':async ()=>({id:'re_pending',status:'pending'}),
  });
  await assert.rejects(()=>serviceFor(fixture.stripe).reprocessDonation(d.id),/refund_not_complete/);
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.refund_status,'pending');
  assert.equal(result.stripe_refund_id,null);
});
function refundFixture(d, overrides={}) {
  let reversed=false;
  const reversal={id:'trr_full',transfer:'tr_fixture',amount:9200,currency:'mxn'};
  return stripeFixture(d,{
    'events/evt_external_refund':async ()=>({livemode:false,type:'charge.refunded',data:{object:{id:'ch_one',metadata:{dopmi_donation:d.id}}}}),
    'charges/ch_one':async ()=>({id:'ch_one',payment_intent:'pi_one',amount:10000,currency:'mxn',disputed:false,amount_refunded:10000}),
    'refunds?charge=ch_one&limit=100':async ()=>({has_more:false,data:[{id:'re_external',charge:'ch_one',currency:'mxn',amount:10000,status:'succeeded'}]}),
    'transfers/tr_fixture':async ()=>({...transferResult(d,'tr_fixture'),reversed,amount_reversed:reversed?9200:0}),
    'transfers/tr_fixture/reversals':async body=>{assert.equal(body.amount,9200);reversed=true;return reversal;},
    'transfers/tr_fixture/reversals?limit=100':async ()=>({has_more:false,data:reversed?[reversal]:[]}),
    ...overrides,
  });
}
async function transferredDonation() {
  const d=await prepare(); await settle(d.id);
  await serviceFor(stripeFixture(d).stripe).reprocessDonation(d.id);
  return d;
}
test('full refund reverses once, preserves audit evidence and frees the expense assignment',async () => {
  const d=await transferredDonation();
  const fixture=refundFixture(d); const service=serviceFor(fixture.stripe);
  await service.handleWebhook('evt_external_refund');
  await service.handleWebhook('evt_external_refund');
  await service.reprocessDonation(d.id);
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.transfer_status,'reversed');
  assert.equal(result.payment_status,'refunded');
  assert.equal(result.refund_status,'refunded');
  assert.equal(result.allocated_cents,0);
  assert.equal(result.refund_cents,10000);
  assert.equal(result.platform_fee_cents,0);
  assert.equal(result.platform_loss_cents,600);
  assert.equal(result.stripe_reversal_id,'trr_full');
  assert.equal(result.stripe_transfer_id,'tr_fixture');
  assert.equal(fixture.calls.filter(c=>c.path==='transfers/tr_fixture/reversals').length,1);
  assert.equal(fixture.calls.filter(c=>c.path==='transfers' || c.path==='refunds').length,0);
  const audit=(await db.query('select before_state,completed_at from private.dopmi_refund_adjustments where donation_id=$1',[d.id])).rows[0];
  assert.equal(audit.before_state.allocated_cents,9200);
  assert.ok(audit.completed_at);
  const funding=(await db.query('select public.dopmi_expense_funding($1) as f',[expense])).rows[0].f;
  assert.equal(funding.funded_cents,0); assert.equal(funding.transferred_cents,0);
  assert.equal(funding.available_cents,12000);
});
test('lost reversal response recovers by reading Stripe without reversing twice',async () => {
  const d=await transferredDonation(); const fixture=refundFixture(d); let lost=true;
  const stripe=async (path,...args)=>{
    const result=await fixture.stripe(path,...args);
    if(path==='transfers/tr_fixture/reversals' && lost){lost=false;throw new Error('lost response');}
    return result;
  };
  const service=serviceFor(stripe);
  await assert.rejects(()=>service.handleWebhook('evt_external_refund'),/processor_unavailable/);
  assert.equal((await rpc('get',{donation_id:d.id})).allocated_cents,9200);
  await db.exec('update private.dopmi_payment_jobs set available_at=now()');
  await service.handleWebhook('evt_external_refund');
  assert.equal((await rpc('get',{donation_id:d.id})).transfer_status,'reversed');
  assert.equal(fixture.calls.filter(c=>c.path==='transfers/tr_fixture/reversals').length,1);
});
test('insufficient reversal balance keeps the event retryable and allocation reserved',async () => {
  const d=await transferredDonation(); const fixture=refundFixture(d,{
    'transfers/tr_fixture/reversals':async ()=>{throw new Error('insufficient balance');},
  });
  await assert.rejects(()=>serviceFor(fixture.stripe).handleWebhook('evt_external_refund'),/processor_unavailable/);
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.external_refund_pending,true);
  assert.equal(result.allocated_cents,9200);
  assert.equal(result.refund_status,'pending');
  assert.equal(result.stripe_reversal_id,null);
  assert.equal((await db.query("select status from private.dopmi_payment_jobs where job_key='evt_external_refund'")).rows[0].status,'ready');
});
test('refund reconciliation cannot race an in-flight transfer',async () => {
  const d=await prepare(); await settle(d.id);
  await rpc('claim',{job_key:`transfer:${d.id}`});
  await rejected(()=>rpc('refund_begin',{donation_id:d.id}),/pendiente/);
  assert.equal((await rpc('get',{donation_id:d.id})).external_refund_pending,false);
});
test('lost database acknowledgement after refund reconciliation preserves final state',async () => {
  const d=await transferredDonation(); const fixture=refundFixture(d); let lost=true;
  const unreliableRpc=async (op,data)=>{
    const result=await rpc(op,data);
    if(op==='refund_finish' && lost){lost=false;throw new Error('database response lost');}
    return result;
  };
  await assert.rejects(()=>serviceFor(fixture.stripe,unreliableRpc).handleWebhook('evt_external_refund'),/processor_unavailable/);
  await db.exec('update private.dopmi_payment_jobs set available_at=now()');
  await serviceFor(fixture.stripe).handleWebhook('evt_external_refund');
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.transfer_status,'reversed'); assert.equal(result.allocated_cents,0);
  assert.equal(fixture.calls.filter(c=>c.path==='transfers/tr_fixture/reversals').length,1);
});
test('wrong Stripe destination cannot reverse funds or clear the assignment',async () => {
  const d=await transferredDonation(); const fixture=refundFixture(d,{
    'transfers/tr_fixture':async ()=>({...transferResult(d,'tr_fixture'),destination:'acct_wrong'}),
  });
  await assert.rejects(()=>serviceFor(fixture.stripe).handleWebhook('evt_external_refund'),/transfer_mismatch/);
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.allocated_cents,9200); assert.equal(result.refund_status,'attention');
  assert.equal(fixture.calls.some(c=>c.path==='transfers/tr_fixture/reversals'),false);
});
test('pending external refund never triggers reversal or releases the assignment',async () => {
  const d=await transferredDonation(); const fixture=refundFixture(d,{
    'refunds?charge=ch_one&limit=100':async ()=>({has_more:false,data:[{id:'re_pending',charge:'ch_one',currency:'mxn',amount:10000,status:'pending'}]}),
  });
  await assert.rejects(()=>serviceFor(fixture.stripe).handleWebhook('evt_external_refund'),/refund_not_complete/);
  assert.equal((await rpc('get',{donation_id:d.id})).allocated_cents,9200);
  assert.equal(fixture.calls.some(c=>c.path==='transfers/tr_fixture/reversals'),false);
});
test('reversal RPC and audit evidence are inaccessible to clients including administrators',async () => {
  for(const actor of [donor,rescuer,staff]){
    await role(actor);
    await rejected(()=>rpc('refund_begin',{donation_id:key}),/permission denied/);
    await rejected(()=>db.query('select * from private.dopmi_refund_adjustments'),/permission denied/);
    await db.exec('reset role');
  }
});
test('partial external refund requests review and never automatically reverses the whole transfer',async () => {
  const d=await transferredDonation(); const fixture=refundFixture(d,{
    'charges/ch_one':async ()=>({payment_intent:'pi_one',amount_refunded:1000}),
  });
  await assert.rejects(()=>serviceFor(fixture.stripe).handleWebhook('evt_external_refund'),/partial_refund_review/);
  assert.equal(fixture.calls.some(c=>c.path.includes('/reversals')),false);
  assert.equal((await rpc('get',{donation_id:d.id})).allocated_cents,9200);
});

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
    return transferResult(d,'tr_one');
  };
  const service=paymentService({rpc,stripe,returnUrl:'https://example.test/return'});
  await service.work();
  await db.exec('update private.dopmi_payment_jobs set available_at=now()');
  await service.work();
  assert.equal(calls.length,2); assert.equal(calls[0].idempotency,calls[1].idempotency);
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.stripe_transfer_id,'tr_one'); assert.equal(result.transfer_status,'transferred');
});
test('webhook finishes its transfer before acknowledging and duplicate events stay idempotent',async () => {
  const d=await prepare();
  const calls=[];
  const stripe=async (path,body,idempotency) => {
    calls.push({path,body,idempotency});
    if (path === 'events/evt_paid' || path === 'events/evt_checkout') return {livemode:false,type:path.endsWith('paid')?'payment_intent.succeeded':'checkout.session.completed',data:{object:path.endsWith('paid')?{id:'pi_one'}:{id:'cs_one'}}};
    if (path === 'checkout/sessions/cs_one') return {metadata:{dopmi_donation:d.id},payment_status:'paid',payment_intent:'pi_one'};
    if (path.startsWith('payment_intents/pi_one')) return {id:'pi_one',status:'succeeded',metadata:{dopmi_donation:d.id},amount_received:10000,currency:'mxn',latest_charge:{id:'ch_one',paid:true,captured:true,disputed:false,amount:10000,currency:'mxn',amount_refunded:0,balance_transaction:{amount:10000,currency:'mxn',fee:600}}};
    if (path === 'accounts/acct_test') return {id:'acct_test',payouts_enabled:true,details_submitted:true,capabilities:{transfers:'active'}};
    if (path === 'charges/ch_one') return {disputed:false,amount_refunded:0};
    if (path === 'transfers') return transferResult(d,'tr_webhook');
    throw new Error(`unexpected Stripe path ${path}`);
  };
  const service=paymentService({rpc,stripe,returnUrl:'https://example.test/return'});
  assert.deepEqual(await service.handleWebhook('evt_paid'),{received:true});
  assert.deepEqual(await service.handleWebhook('evt_paid'),{received:true,duplicate:true});
  assert.deepEqual(await service.handleWebhook('evt_checkout'),{received:true});
  const result=await rpc('get',{donation_id:d.id});
  assert.equal(result.stripe_transfer_id,'tr_webhook');
  assert.equal(result.transfer_status,'transferred');
  assert.equal(calls.filter(call => call.path === 'transfers').length,1);
  assert.equal((await db.query("select count(*)::int n from private.dopmi_payment_jobs where kind='event' and status='done'")).rows[0].n,2);
});
test('webhook returns a retryable failure and leaves its event unfinished when transfer fails',async () => {
  const d=await prepare(); let fail=true;
  const stripe=async (path) => {
    if (path === 'events/evt_retry') return {livemode:false,type:'payment_intent.succeeded',data:{object:{id:'pi_one'}}};
    if (path.startsWith('payment_intents/pi_one')) return {id:'pi_one',status:'succeeded',metadata:{dopmi_donation:d.id},amount_received:10000,currency:'mxn',latest_charge:{id:'ch_one',paid:true,captured:true,disputed:false,amount:10000,currency:'mxn',amount_refunded:0,balance_transaction:{amount:10000,currency:'mxn',fee:600}}};
    if (path === 'accounts/acct_test') return {id:'acct_test',payouts_enabled:true,details_submitted:true,capabilities:{transfers:'active'}};
    if (path === 'charges/ch_one') return {disputed:false,amount_refunded:0};
    if (path === 'transfers') { if (fail) { fail=false; throw new Error('Stripe unavailable'); } return transferResult(d,'tr_retry'); }
    throw new Error(`unexpected Stripe path ${path}`);
  };
  const logs=[];
  const service=paymentService({rpc,stripe,returnUrl:'https://example.test/return',logger:{info:(message)=>logs.push(JSON.parse(message))}});
  await assert.rejects(() => service.handleWebhook('evt_retry'),/processor_unavailable/);
  assert.equal((await db.query("select status from private.dopmi_payment_jobs where job_key='evt_retry'")).rows[0].status,'ready');
  assert.equal(logs.some(log => log.event === 'payment_job_failed' && !JSON.stringify(log).includes('sk_test')),true);
  assert.equal((await rpc('get',{donation_id:d.id})).transfer_status,'pending');
  await db.exec('update private.dopmi_payment_jobs set available_at=now()');
  assert.deepEqual(await service.handleWebhook('evt_retry'),{received:true});
  assert.equal((await rpc('get',{donation_id:d.id})).stripe_transfer_id,'tr_retry');
});
test('an existing confirmed donation can be replayed without creating a checkout or charge',async () => {
  const d=await prepare(); await settle(d.id);
  const calls=[];
  const stripe=async (path,body,idempotency) => {
    calls.push({path,body,idempotency});
    if (path === 'charges/ch_one') return {disputed:false,amount_refunded:0};
    if (path === 'transfers') return transferResult(d,'tr_replay');
    throw new Error(`unexpected Stripe path ${path}`);
  };
  const service=paymentService({rpc,stripe,returnUrl:'https://example.test/return'});
  const result=await service.reprocessDonation(d.id);
  assert.equal(result.stripe_transfer_id,'tr_replay');
  assert.equal(calls.filter(call => call.path === 'transfers').length,1);
  assert.equal(calls.some(call => call.path === 'checkout/sessions'),false);
  assert.equal((await service.reprocessDonation(d.id)).stripe_transfer_id,'tr_replay');
  assert.equal(calls.filter(call => call.path === 'transfers').length,1);
});

test('overlapping Checkout and PaymentIntent handlers claim only one transfer and do not acknowledge unfinished events',async () => {
  const d=await prepare();
  let entered, release;
  const started=new Promise(resolve => {entered=resolve;});
  const blocked=new Promise(resolve => {release=resolve;});
  const fixture=stripeFixture(d,{transfers:async () => {entered(); await blocked; return transferResult(d,'tr_concurrent');}});
  const service=serviceFor(fixture.stripe);
  const first=service.handleWebhook('evt_intent');
  await started;
  try {
    await assert.rejects(() => service.handleWebhook('evt_session'),/processor_busy/);
    await assert.rejects(() => service.handleWebhook('evt_intent'),/processor_busy/);
    const unfinished=await db.query("select count(*)::int n from private.dopmi_payment_jobs where kind='event' and status='done'");
    assert.equal(unfinished.rows[0].n,0);
    assert.equal(fixture.calls.filter(call => call.path === 'transfers').length,1);
  } finally { release(); await first; }
  await db.exec('update private.dopmi_payment_jobs set available_at=now()');
  assert.deepEqual(await service.handleWebhook('evt_session'),{received:true});
  assert.equal(fixture.calls.filter(call => call.path === 'transfers').length,1);
  const paid=await rpc('get',{donation_id:d.id});
  assert.equal(paid.allocated_cents,9200);
  assert.equal(paid.stripe_transfer_id,'tr_concurrent');
});

test('lost database acknowledgement cannot downgrade a completed transfer or cause another Stripe call',async () => {
  const d=await prepare(); await settle(d.id);
  const fixture=stripeFixture(d);
  let fail=true;
  const delayedRpc=async (op,data) => {
    const result=await rpc(op,data);
    if (op === 'finish_job' && data.result_id && fail) {fail=false; throw new Error('lost database response');}
    return result;
  };
  const service=serviceFor(fixture.stripe,delayedRpc);
  await assert.rejects(() => service.reprocessDonation(d.id),/processor_unavailable/);
  assert.equal((await rpc('get',{donation_id:d.id})).transfer_status,'transferred');
  assert.equal((await db.query('select status from private.dopmi_payment_jobs')).rows[0].status,'done');
  assert.equal((await service.reprocessDonation(d.id)).stripe_transfer_id,'tr_fixture');
  assert.equal(fixture.calls.filter(call => call.path === 'transfers').length,1);
});

test('unavailable actual fees keep the event retryable without allocating or transferring',async () => {
  const d=await prepare();
  const fixture=stripeFixture(d);
  let pending=true;
  const stripe=async (...args) => {
    const result=await fixture.stripe(...args);
    if (args[0].startsWith('payment_intents/') && pending) result.latest_charge.balance_transaction=null;
    return result;
  };
  const service=serviceFor(stripe);
  await assert.rejects(() => service.handleWebhook('evt_intent'),/fee_not_ready/);
  assert.equal((await rpc('get',{donation_id:d.id})).processed_at,null);
  assert.equal(fixture.calls.some(call => call.path === 'transfers'),false);
  assert.equal((await db.query('select status from private.dopmi_payment_jobs')).rows[0].status,'ready');
  pending=false;
  await db.exec('update private.dopmi_payment_jobs set available_at=now()');
  await service.handleWebhook('evt_intent');
  assert.equal((await rpc('get',{donation_id:d.id})).transfer_status,'transferred');
});

test('safe replay settles an existing Checkout, and refuses a Checkout for another donation',async () => {
  const d=await prepare();
  await rpc('checkout_save',{donation_id:d.id,session_id:'cs_one',url:'https://checkout.stripe.com/test'});
  const fixture=stripeFixture(d);
  const result=await serviceFor(fixture.stripe).reprocessDonation(d.id);
  assert.equal(result.stripe_transfer_id,'tr_fixture');
  assert.equal(fixture.calls.some(call => call.path === 'checkout/sessions'),false);
  const second=await prepare({actor:other,key:'72000000-0000-4000-8000-000000000002'});
  await rpc('checkout_save',{donation_id:second.id,session_id:'cs_wrong',url:'https://checkout.stripe.com/test2'});
  const mismatch=serviceFor(async () => ({metadata:{dopmi_donation:d.id},payment_status:'paid',payment_intent:'pi_one'}));
  await assert.rejects(() => mismatch.reprocessDonation(second.id),/charge_mismatch/);
  assert.equal((await rpc('get',{donation_id:second.id})).processed_at,null);
});

test('replay outside the idempotency window requires manual reconciliation and never calls Stripe',async () => {
  const d=await prepare(); await settle(d.id);
  await db.exec("update private.dopmi_payment_jobs set first_attempt_at=now()-interval '25 hours'");
  let calls=0;
  const service=serviceFor(async () => {calls++; throw new Error('must not call Stripe');});
  await assert.rejects(() => service.reprocessDonation(d.id),/manual_reconciliation_required/);
  await assert.rejects(() => service.reprocessDonation(d.id),/manual_reconciliation_required/);
  assert.equal(calls,0);
  assert.equal((await rpc('get',{donation_id:d.id})).transfer_status,'attention');
});

test('unexpected destination or transfer response never records a completed transfer',async () => {
  const d=await prepare(); await settle(d.id);
  const fixture=stripeFixture(d,{transfers:async () => ({...transferResult(d,'tr_wrong'),destination:'acct_other'})});
  await assert.rejects(() => serviceFor(fixture.stripe).reprocessDonation(d.id),/transfer_mismatch/);
  let paid=await rpc('get',{donation_id:d.id});
  assert.equal(paid.transfer_status,'attention');
  assert.equal(paid.stripe_transfer_id,null);
  await db.exec("update private.dopmi_payment_jobs set status='ready',available_at=now()");
  await db.query('update private.dopmi_connect_accounts set owner_id=$1 where owner_id=$2',[other,rescuer]);
  await assert.rejects(() => serviceFor(fixture.stripe).reprocessDonation(d.id),/destination_mismatch/);
  paid=await rpc('get',{donation_id:d.id});
  assert.equal(paid.stripe_transfer_id,null);
  assert.equal(fixture.calls.filter(call => call.path === 'transfers').length,1);
});

test('confirmed active users can inspect Connect status but only verified rescuers may onboard',async () => {
  const fixture=stripeFixture({id:key});
  const service=serviceFor(fixture.stripe);
  assert.equal((await service.connect(other,'status')).ready,false);
  assert.equal(fixture.calls.length,0);
  await rejected(() => service.connect(other,'onboard'),/verificación de rescatista/);
  await db.exec("update public.dopmi_rescue_records set status='changes_requested' where kind='verification'");
  const status=await service.connect(rescuer,'status');
  assert.equal(status.verified,false);
  assert.equal(status.ready,false);
  assert.deepEqual(status.payouts,[]);
  await rejected(() => service.connect(rescuer,'onboard'),/verificación de rescatista/);
  await db.query("update public.profiles set account_status='suspended' where id=$1",[rescuer]);
  await rejected(() => service.connect(rescuer,'status'),/activa/);
});

test('rescuer history survives pending review without granting access to another account or suspended users',async () => {
  const d=await prepare(); await settle(d.id);
  await db.exec("update public.dopmi_rescue_records set status='changes_requested' where kind='verification'");
  await role(rescuer);
  assert.equal((await db.query('select id from public.dopmi_donations')).rows[0].id,d.id);
  assert.equal((await db.query('select public.dopmi_expense_funding($1) v',[expense])).rows[0].v.funded_cents,9200);
  await role(other);
  assert.equal((await db.query('select id from public.dopmi_donations')).rows.length,0);
  await rejected(() => db.query('select public.dopmi_expense_funding($1)',[expense]),/no disponible/);
  await role('', 'anon');
  await rejected(() => db.query('select public.dopmi_expense_funding($1)',[expense]),/no disponible/);
  await db.exec('reset role');
  await db.query("update public.profiles set account_status='suspended' where id=$1",[rescuer]);
  await role(rescuer);
  assert.equal((await db.query('select id from public.dopmi_donations')).rows.length,0);
});

test('status and replay/lease RPCs remain service-only even for administrators',async () => {
  for (const id of [donor,staff]) {
    await role(id);
    for (const [op,data] of [['connect_status',{actor:rescuer}],['claim',{}],['finish_job',{}],['replay_get',{donation_id:key}]]) {
      await rejected(() => rpc(op,data),/permission denied/);
    }
    await db.exec('reset role');
  }
});

test('case totals distinguish assigned from transferred net and contain no private payment information',async () => {
  const d=await prepare(); await settle(d.id);
  const funding=async () => (await db.query('select public.dopmi_expense_funding($1) v',[expense])).rows[0].v;
  const catalog=async () => (await db.query('select public.dopmi_rescue_public() v')).rows[0].v;
  assert.equal((await funding()).transferred_cents,0);
  assert.equal((await catalog()).items[0].funded_cents,9200);
  assert.equal((await catalog()).items[0].transferred_cents,0);
  await serviceFor(stripeFixture(d).stripe).reprocessDonation(d.id);
  await role('', 'anon');
  assert.equal((await funding()).transferred_cents,9200);
  const data=await catalog();
  assert.equal(data.items[0].transferred_cents,9200);
  assert.equal(data.items[0].funded_cents,9200);
  assert.equal(data.items[0].donor_id,undefined);
  assert.equal(JSON.stringify(data).includes('tr_fixture'),false);
  assert.equal(JSON.stringify(data).includes('ch_one'),false);
});

test('Stripe permission failures are processor configuration errors, not user-access 403s, and omit secrets',async () => {
  const stripe=stripeApi('rk_test_fixture',async () => new Response(JSON.stringify({error:{code:'permission_denied',message:'secret processor body'}}),{status:403,headers:{'Request-Id':'req_fixture'}}));
  await assert.rejects(() => stripe('payouts?limit=10',undefined,undefined,'acct_test'),error => {
    assert.equal(error.code,'stripe_permission_denied');
    assert.equal(error.status,503);
    assert.deepEqual(error.context,{source:'stripe',operation:'payouts',stripe_status:403,stripe_request_id:'req_fixture'});
    assert.equal(JSON.stringify(error).includes('secret processor body'),false);
    assert.equal(JSON.stringify(error).includes('rk_test_fixture'),false);
    return true;
  });
});

test('MXN 50 test payment transfers the actual 4314-cent net using its original charge',async () => {
  const d=await prepare({gross_cents:5000});
  const fixture=stripeFixture(d,{
    'payment_intents/pi_one?expand[]=latest_charge.balance_transaction':async () => ({id:'pi_one',status:'succeeded',metadata:{dopmi_donation:d.id},amount_received:5000,currency:'mxn',latest_charge:{id:'ch_one',paid:true,captured:true,disputed:false,amount:5000,currency:'mxn',amount_refunded:0,balance_transaction:{amount:5000,currency:'mxn',fee:586}}}),
    transfers:async () => transferResult(d,'tr_net',4314),
  });
  await serviceFor(fixture.stripe).handleWebhook('evt_intent');
  const paid=await rpc('get',{donation_id:d.id});
  assert.equal(paid.gross_cents,5000);
  assert.equal(paid.platform_fee_cents,100);
  assert.equal(paid.stripe_fee_cents,586);
  assert.equal(paid.allocated_cents,4314);
  assert.equal(paid.stripe_transfer_id,'tr_net');
  const call=fixture.calls.find(call => call.path === 'transfers');
  assert.equal(call.body.amount,4314);
  assert.equal(call.body.source_transaction,'ch_one');
  assert.equal(call.body.destination,'acct_test');
  assert.equal(call.idempotency,`dopmi-transfer-${d.id}`);
});

test('signed redelivery repairs legacy completed events with unfinished transfers without another charge',async () => {
  const d=await prepare(); await settle(d.id);
  await rpc('enqueue',{event_id:'evt_intent'});
  const oldJob=await rpc('claim',{job_key:'evt_intent'});
  await rpc('finish_job',{job_id:oldJob.id,lease:oldJob.lease});
  const fixture=stripeFixture(d);
  const service=serviceFor(fixture.stripe);
  assert.deepEqual(await service.handleWebhook('evt_intent'),{received:true,duplicate:true});
  assert.equal((await rpc('get',{donation_id:d.id})).stripe_transfer_id,'tr_fixture');
  await service.handleWebhook('evt_intent');
  assert.equal(fixture.calls.filter(call => call.path === 'transfers').length,1);
  assert.equal(fixture.calls.some(call => call.path === 'checkout/sessions'),false);
});
