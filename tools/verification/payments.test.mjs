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
test('scheduled reconciliation finds pending checkouts without an ambiguous SQL alias',async () => {
  const d=await prepare();
  await rpc('checkout_save',{donation_id:d.id,session_id:'cs_pending',url:'https://example.test/checkout'});
  const candidates=await rpc('reconcile_candidates',{});
  assert.deepEqual(candidates,[{id:d.id,session_id:'cs_pending'}]);
});
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
const guardianKey = '73000000-0000-4000-8000-000000000001';
const guardian = async (gross=10000,key=guardianKey,actor=donor) =>
  (await db.query('select public.dopmi_guardian_reserve($1,$2,$3) as value',[actor,key,gross])).rows[0].value;
const releaseGuardian = async (key=guardianKey) =>
  (await db.query('select public.dopmi_guardian_release($1,$2) as value',[donor,key])).rows[0].value;
const guardianRegistry = async (operation,data) =>
  (await db.query('select public.dopmi_guardian_subscription_server($1,$2::jsonb) as value',
    [operation,JSON.stringify(data)])).rows[0].value;
const guardianPlan = { donor_id: donor, stripe_customer_id: 'cus_guardian1',
  stripe_subscription_id: 'sub_guardian1', stripe_price_id: 'price_guardian1', gross_cents: 5000,
  initial_payment_intent_id: 'pi_guardianInitial1', initial_charge_id: 'ch_guardianInitial1' };

test('Guardian stores a trusted subscription and binds each invoice to one full-cycle hold',async () => {
  const first=await guardianRegistry('register',guardianPlan);
  assert.equal(first.stripe_subscription_id,guardianPlan.stripe_subscription_id);
  assert.deepEqual(await guardianRegistry('register',guardianPlan),first);
  assert.equal((await guardianRegistry('lookup',{
    stripe_subscription_id:guardianPlan.stripe_subscription_id })).donor_id,donor);
  assert.equal(await guardianRegistry('lookup',{stripe_subscription_id:'sub_missing'}),null);
  const reserved=await guardian(5000);
  assert.equal(reserved.status,'reserved');
  const binding={ stripe_subscription_id:guardianPlan.stripe_subscription_id,
    stripe_invoice_id:'in_guardian1', cycle_id:reserved.id };
  const linked=await guardianRegistry('bind_invoice',binding);
  assert.equal(linked.cycle_id,reserved.id);
  assert.equal(linked.stripe_invoice_id,binding.stripe_invoice_id);
  assert.deepEqual(await guardianRegistry('bind_invoice',binding),linked);
  await rejected(()=>guardianRegistry('bind_invoice',{...binding,stripe_invoice_id:'in_other'}),
    /ya vinculado/);
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_invoice_cycles')).rows[0].n,1);
});

test('Guardian rejects mismatched donor, amount, initial charge and cross-account invoice',async () => {
  await guardianRegistry('register',guardianPlan);
  for (const changed of [{ gross_cents: 20000 }, { initial_charge_id: 'ch_other' },
    { donor_id: other, initial_payment_intent_id: guardianPlan.initial_payment_intent_id }])
    await rejected(()=>guardianRegistry('register',{...guardianPlan,...changed}));
  const reserved=await guardian(5000);
  const wrongDonor=await guardian(5000,'73000000-0000-4000-8000-000000000002',other);
  assert.equal(wrongDonor.status,'reserved');
  await rejected(()=>guardianRegistry('bind_invoice',{stripe_subscription_id:guardianPlan.stripe_subscription_id,
    stripe_invoice_id:'in_foreign',cycle_id:wrongDonor.id}),/no coincide/);
  await rejected(()=>guardianRegistry('bind_invoice',{stripe_subscription_id:'sub_unregistered',
    stripe_invoice_id:'in_unknown',cycle_id:reserved.id}),/no disponible/);
  await rejected(()=>guardianRegistry('bind_invoice',{stripe_subscription_id:guardianPlan.stripe_subscription_id,
    stripe_invoice_id:'in_invalid',cycle_id:'bad'}));
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_invoice_cycles')).rows[0].n,0);
});

test('Guardian subscription registry cannot be read or changed by a client or administrator',async () => {
  await guardianRegistry('register',guardianPlan);
  for (const actor of [donor,staff]) {
    await role(actor);
    await rejected(()=>guardianRegistry('lookup',{stripe_subscription_id:guardianPlan.stripe_subscription_id}),
      /permission denied/);
    await rejected(()=>db.query('select * from private.dopmi_guardian_subscriptions'),/permission denied/);
    await rejected(()=>db.query('select * from private.dopmi_guardian_invoice_cycles'),/permission denied/);
    await db.exec('reset role');
  }
});
test('Guardian cancellation is idempotent and blocks future invoice bindings',async () => {
  await guardianRegistry('register',guardianPlan);
  const held=await guardian(5000);
  await rejected(()=>guardianRegistry('cancel',{donor_id:other,
    stripe_subscription_id:guardianPlan.stripe_subscription_id}),/no disponible/);
  const cancel={donor_id:donor,stripe_subscription_id:guardianPlan.stripe_subscription_id};
  const first=await guardianRegistry('cancel',cancel);
  assert.equal(first.status,'canceled');
  assert.deepEqual(await guardianRegistry('cancel',cancel),first);
  await rejected(()=>guardianRegistry('register',guardianPlan),/ya vinculado/);
  await rejected(()=>guardianRegistry('bind_invoice',{
    stripe_subscription_id:guardianPlan.stripe_subscription_id,
    stripe_invoice_id:'in_afterCancellation',cycle_id:held.id }),/no disponible/);
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_invoice_cycles')).rows[0].n,0);
});
test('Guardian activation preview is authenticated, read only and respects pending holds',async () => {
  await role(donor);
  const preview=async amount=>(await db.query('select public.dopmi_guardian_capacity_preview($1) as value',[amount])).rows[0].value;
  assert.deepEqual(await preview(5000),{gross_cents:5000,required_cents:4900,can_activate:true});
  await rejected(()=>preview(999),/Importe de Guardián inválido/);
  await db.exec('reset role');
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_cycles')).rows[0].n,0);
  await guardian(10000);
  await role(other);
  assert.equal((await preview(4000)).can_activate,false);
  await db.exec('reset role');
  await role(donor,'anon');
  await rejected(()=>preview(5000),/permission denied/);
  await db.exec('reset role');
});
test('Guardian holds the entire upper net, shares single-payment capacity and releases it',async () => {
  const held=await guardian();
  assert.equal(held.status,'reserved');
  assert.equal(held.reserved_cents,9800);
  assert.deepEqual(held.allocations,[{expense_id:expense,amount_cents:9800}]);
  assert.equal((await guardian()).id,held.id);
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_cycles')).rows[0].n,1);
  await rejected(() => guardian(11000),/otro importe/);
  assert.equal((await rpc('prepare',{actor:other,expense_id:expense,key,gross_cents:10000})).reserved_cents,2200);
  const funded=(await db.query('select public.dopmi_expense_funding($1) as value',[expense])).rows[0].value;
  assert.equal(funded.available_cents,0);
  assert.equal(funded.funded_cents,0);
  assert.equal((await releaseGuardian()).status,'released');
  assert.equal((await releaseGuardian()).status,'released');
  assert.equal((await db.query('select private.dopmi_guardian_reserved($1)::int as n',[expense])).rows[0].n,0);
  assert.equal((await db.query('select public.dopmi_expense_funding($1) as value',[expense])).rows[0].value.available_cents,9800);
});
test('Guardian skips a cycle instead of holding a partial amount or charging anything',async () => {
  const one=await guardian(15000);
  assert.equal(one.status,'skipped');
  assert.equal(one.reserved_cents,0);
  assert.deepEqual(one.allocations,[]);
  assert.equal((await guardian(15000)).id,one.id);
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_allocations')).rows[0].n,0);
  assert.equal((await db.query('select count(*)::int as n from public.dopmi_donations')).rows[0].n,0);
});
test('Guardian cannot borrow capacity already reserved by an individual Checkout',async () => {
  await prepare();
  const cycle=await guardian(4000);
  assert.equal(cycle.status,'skipped');
  assert.deepEqual(cycle.allocations,[]);
  assert.equal((await db.query('select private.dopmi_guardian_reserved($1)::int as n',[expense])).rows[0].n,0);
});
test('Guardian orders multiple eligible expenses and subtracts pending donations before planning',async () => {
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents,urgent,approved_at)
    values('71000000-0000-4000-8000-000000000004',$1,'expense','approved','{"title":"Prioridad"}',
      '71000000-0000-4000-8000-000000000002',5000,true,now())`,[rescuer]);
  await db.query('update public.dopmi_rescue_records set approved_at=now()-interval \'1 day\' where id=$1',[expense]);
  const pending=await prepare({gross_cents:10000});
  assert.equal(pending.reserved_cents,9800);
  const held=await guardian(7000,'73000000-0000-4000-8000-000000000002',other);
  assert.equal(held.status,'reserved');
  assert.deepEqual(held.allocations,[
    {expense_id:'71000000-0000-4000-8000-000000000004',amount_cents:5000},
    {expense_id:expense,amount_cents:1860},
  ]);
  const settled=await settle(pending.id);
  assert.equal(settled.allocated_cents,9200);
  assert.equal(settled.refund_cents,0);
});
test('expired Guardian holds are not counted and same key cannot create a new cycle',async () => {
  const held=await guardian();
  await db.query('update private.dopmi_guardian_cycles set expires_at=now()-interval \'1 minute\' where id=$1',[held.id]);
  assert.equal((await db.query('select private.dopmi_guardian_reserved($1)::int as n',[expense])).rows[0].n,0);
  assert.equal((await guardian()).status,'expired');
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_cycles')).rows[0].n,1);
});
test('Guardian holds and private allocation records cannot be created by clients or administrators',async () => {
  for(const actor of [donor,staff]){
    await role(actor);
    await rejected(() => guardian(),/permission denied/);
    await rejected(() => releaseGuardian(),/permission denied/);
    await rejected(() => db.query('select * from private.dopmi_guardian_allocations'),/permission denied/);
    await db.exec('reset role');
  }
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

const guardianSettlement = async (operation,data={}) =>
  (await db.query('select public.dopmi_guardian_settlement_server($1,$2::jsonb) as value',[operation,JSON.stringify(data)])).rows[0].value;
const guardianEvidence = { donor_id:donor, invoice_id:'in_guardian1', subscription_id:'sub_guardian1',
  invoice_payment_id:'inpay_guardian1', payment_intent_id:'pi_guardianRenewal1', charge_id:'ch_guardianRenewal1',
  gross_cents:5000, platform_fee_cents:100, stripe_fee_cents:586, net_cents:4314 };
async function boundGuardian() {
  await guardianRegistry('register',guardianPlan);
  const cycle=await guardian(5000);
  await guardianRegistry('bind_invoice',{stripe_subscription_id:'sub_guardian1',stripe_invoice_id:'in_guardian1',cycle_id:cycle.id});
  return cycle;
}
test('Guardian settles full net atomically, frees only fee surplus and keeps capacity occupied after expiry',async () => {
  const cycle=await boundGuardian();
  const result=await guardianSettlement('settle',guardianEvidence);
  assert.equal(result.status,'allocated'); assert.equal(result.allocated_cents,4314);
  assert.equal(result.refund_cents,0); assert.equal(result.allocations[0].destination,'acct_test');
  assert.deepEqual(await guardianSettlement('settle',guardianEvidence),result);
  await db.query("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 hour' where id=$1",[cycle.id]);
  await releaseGuardian();
  const funding=(await db.query('select public.dopmi_expense_funding($1) as v',[expense])).rows[0].v;
  assert.equal(funding.funded_cents,4314); assert.equal(funding.available_cents,7686); assert.equal(funding.transferred_cents,0);
  const next=await prepare(); assert.equal(next.reserved_cents,7686);
  const second=await settle(next.id); assert.equal(second.allocated_cents,7686);
  await rejected(()=>db.query("update public.dopmi_rescue_records set status='changes_requested' where id=$1",[expense]),/aportaciones asignadas/);
  const publicCase=(await db.query('select public.dopmi_rescue_public($1) as v',['71000000-0000-4000-8000-000000000002'])).rows[0].v;
  assert.equal(publicCase.items.find(r=>r.kind==='case').funded_cents,12000);
  assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_jobs')).rows[0].n,1);
});
test('Guardian trims several held expenses to exact net without partial settlement when a required expense is revoked',async () => {
  await db.query('update public.dopmi_rescue_records set reimbursable_cents=2500,urgent=true where id=$1',[expense]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents)
    values('71000000-0000-4000-8000-000000000004',$1,'expense','approved','{"title":"Comida"}','71000000-0000-4000-8000-000000000002',5000)`,[rescuer]);
  await boundGuardian();
  const result=await guardianSettlement('settle',guardianEvidence);
  assert.deepEqual(result.allocations.map(a=>a.amount_cents),[2500,1814]);
  assert.equal((await db.query('select sum(allocated_cents)::int n from private.dopmi_guardian_allocations')).rows[0].n,4314);
});
test('expired or released Guardian reservations require a full refund and never allocate another expense',async () => {
  const cycle=await boundGuardian(); await releaseGuardian();
  const result=await guardianSettlement('settle',guardianEvidence);
  assert.equal(result.status,'refund_pending'); assert.equal(result.refund_cents,5000);
  assert.equal(result.platform_fee_cents,0); assert.equal(result.platform_loss_cents,586);
  assert.equal(result.allocated_cents,0); assert.deepEqual(result.allocations,[]);
  assert.equal(result.cycle_id,cycle.id);
  const job=await guardianSettlement('claim'); assert.equal(job.kind,'refund');
  await guardianSettlement('finish',{job_id:job.id,lease:job.lease,result_id:'re_guardian1'});
  assert.equal((await guardianSettlement('get',{cycle_id:cycle.id})).status,'refunded');
});
test('one revoked destination refunds the whole Guardian charge and leaves all allocations zero',async () => {
  await db.query('update public.dopmi_rescue_records set reimbursable_cents=2500,urgent=true where id=$1',[expense]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents)
    values('71000000-0000-4000-8000-000000000004',$1,'expense','approved','{"title":"Comida"}','71000000-0000-4000-8000-000000000002',5000)`,[rescuer]);
  await boundGuardian();
  await db.exec("update public.dopmi_rescue_records set status='changes_requested' where id='71000000-0000-4000-8000-000000000004'");
  const result=await guardianSettlement('settle',guardianEvidence);
  assert.equal(result.refund_cents,5000); assert.deepEqual(result.allocations,[]);
  assert.equal((await db.query('select sum(allocated_cents)::int n from private.dopmi_guardian_allocations')).rows[0].n,0);
});
test('Guardian rejects missing binding, mismatched evidence and double use of payment identifiers',async () => {
  await rejected(()=>guardianSettlement('settle',guardianEvidence),/sin reserva/);
  await boundGuardian();
  for(const patch of [{donor_id:other},{subscription_id:'sub_other'},{gross_cents:4000},{stripe_fee_cents:null},{net_cents:4315},
    {payment_intent_id:'pi_guardianInitial1'},{charge_id:null}])
    await rejected(()=>guardianSettlement('settle',{...guardianEvidence,...patch}));
  await guardianSettlement('settle',guardianEvidence);
  await rejected(()=>guardianSettlement('settle',{...guardianEvidence,payment_intent_id:'pi_other'}),/otra evidencia/);
});
test('Guardian finalization is lease-protected, atomic and cannot be downgraded after a lost acknowledgement',async () => {
  const cycle=await boundGuardian(); await guardianSettlement('settle',guardianEvidence);
  const job=await guardianSettlement('claim'); assert.equal(job.kind,'transfer');
  assert.equal(await guardianSettlement('claim'),null);
  await rejected(()=>guardianSettlement('finish',{job_id:job.id,lease:'00000000-0000-4000-8000-000000000001',result_id:'tr_test'}),/vencido/);
  await guardianSettlement('finish',{job_id:job.id,lease:job.lease,result_id:'tr_guardian1'});
  await guardianSettlement('finish',{job_id:job.id,lease:job.lease,error_code:'lost_response'});
  const result=await guardianSettlement('get',{cycle_id:cycle.id}); assert.equal(result.allocations[0].stripe_transfer_id,'tr_guardian1');
  assert.equal((await db.query("select status from private.dopmi_guardian_jobs")).rows[0].status,'done');
  assert.equal((await db.query('select public.dopmi_expense_funding($1) as v',[expense])).rows[0].v.transferred_cents,4314);
});
test('Guardian settlement RPC, jobs and evidence are inaccessible to clients including admins',async () => {
  for(const actor of [donor,staff,'']) {
    await role(actor,actor?'authenticated':'anon');
    await rejected(()=>guardianSettlement('candidates'),/permission denied/);
    await rejected(()=>db.query('select * from private.dopmi_guardian_settlements'),/permission denied/);
    await rejected(()=>db.query('select * from private.dopmi_guardian_jobs'),/permission denied/);
  }
  await role('','service_role'); assert.deepEqual(await guardianSettlement('candidates'),[]);
});

const { guardianService } = await import('../../supabase/functions/_shared/guardian-service.mjs');
function guardianStripeFixture() {
  const calls=[]; const transfers=new Map(); const refunds=[];
  const charge={id:'ch_guardianRenewal1',livemode:false,payment_intent:'pi_guardianRenewal1',currency:'mxn',amount:5000,
    amount_refunded:0,paid:true,captured:true,disputed:false,balance_transaction:{amount:5000,currency:'mxn',fee:586}};
  const subscription={id:'sub_guardian1',customer:'cus_guardian1',livemode:false,status:'active',collection_method:'send_invoice',
    pause_collection:{behavior:'keep_as_draft',resumes_at:null}};
  const invoice={id:'in_guardian1',parent:{subscription_details:{subscription:subscription.id}},customer:'cus_guardian1',livemode:false,
    billing_reason:'subscription_cycle',status:'paid',auto_advance:false,collection_method:'send_invoice',currency:'mxn',
    amount_paid:5000,amount_remaining:0,amount_due:5000,total:5000,attempt_count:1,attempted:true,starting_balance:0,
    total_taxes:[],total_discount_amounts:[],lines:{has_more:false,total_count:1,data:[{amount:5000,currency:'mxn',quantity:1,
      pricing:{price_details:{price:'price_guardian1'}},parent:{subscription_item_details:{subscription:subscription.id}},taxes:[],discount_amounts:[]}]},
    payments:{has_more:false,data:[{id:'inpay_guardian1',invoice:'in_guardian1',status:'paid',amount_paid:5000,amount_requested:5000,
      payment:{type:'payment_intent',payment_intent:'pi_guardianRenewal1'}}]}};
  const stripe={invoices:{retrieve:async()=>structuredClone(invoice)},subscriptions:{retrieve:async()=>structuredClone(subscription)},
    paymentIntents:{retrieve:async()=>({id:'pi_guardianRenewal1',livemode:false,customer:'cus_guardian1',currency:'mxn',status:'succeeded',amount_received:5000,latest_charge:structuredClone(charge)})},
    charges:{retrieve:async()=>structuredClone(charge)},accounts:{retrieve:async id=>({id,capabilities:{transfers:'active'},payouts_enabled:true})},
    transfers:{create:async(fields,options)=>{calls.push({kind:'transfer',fields,options});
      if(!transfers.has(options.idempotencyKey)) transfers.set(options.idempotencyKey,{id:`tr_guardian${transfers.size+1}`,livemode:false,...fields,reversed:false,amount_reversed:0});
      return structuredClone(transfers.get(options.idempotencyKey));}},
    refunds:{list:async()=>({has_more:false,data:structuredClone(refunds)}),create:async(fields,options)=>{
      calls.push({kind:'refund',fields,options}); const refund={id:'re_guardian1',...fields,currency:'mxn',status:'succeeded'};
      refunds.push(refund);charge.amount_refunded=fields.amount;return structuredClone(refund);}}};
  const service=rpcOverride=>guardianService({stripe,rpc:rpcOverride??guardianSettlement,
    lookupSubscription:stripe_subscription_id=>guardianRegistry('lookup',{stripe_subscription_id}),logger:{}});
  return {stripe,calls,charge,invoice,subscription,transfers,refunds,service};
}
test('Guardian worker reconciles confirmed invoice, transfers exact net and repeated runs perform no new payment',async () => {
  const cycle=await boundGuardian();const f=guardianStripeFixture();
  assert.deepEqual(await f.service().reconcile(),{reconciled:1,processed:1,failed:0});
  assert.deepEqual(await f.service().reconcile(),{reconciled:0,processed:0,failed:0});
  const result=await f.service().reconcileInvoice('in_guardian1');
  assert.equal(result.allocations[0].stripe_transfer_id,'tr_guardian1');
  assert.equal(f.calls.length,1);assert.equal(f.calls[0].fields.amount,4314);
  assert.equal(f.calls[0].fields.source_transaction,'ch_guardianRenewal1');
  assert.equal(f.calls[0].fields.transfer_group,`dopmi_guardian_${cycle.id}`);
});
test('Guardian lost Stripe response retries the same transfer key and records one processor effect',async () => {
  await boundGuardian();const f=guardianStripeFixture();const create=f.stripe.transfers.create;let lost=true;
  f.stripe.transfers.create=async(...args)=>{const result=await create(...args);if(lost){lost=false;throw Error('lost response');}return result;};
  assert.equal((await f.service().reconcile()).failed,1);
  await db.exec('update private.dopmi_guardian_jobs set available_at=now()');
  assert.equal((await f.service().reconcile()).processed,1);
  assert.equal(f.transfers.size,1);assert.equal(f.calls.length,2);
  assert.deepEqual(f.calls[0],f.calls[1]);
});
test('Guardian lost database acknowledgement never downgrades or repeats a completed transfer',async () => {
  const cycle=await boundGuardian();const f=guardianStripeFixture();let lost=true;
  const rpc=async(op,data)=>{const result=await guardianSettlement(op,data);
    if(op==='finish' && data.result_id && lost){lost=false;throw Error('lost database response');}return result;};
  await f.service(rpc).reconcile(); await f.service().reconcile();
  assert.equal(f.calls.length,1);
  assert.equal((await guardianSettlement('get',{cycle_id:cycle.id})).allocations[0].stripe_transfer_id,'tr_guardian1');
});
test('Guardian worker fully refunds expired reservation and recovers a lost refund response without a second refund',async () => {
  const cycle=await boundGuardian();await db.query("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 minute' where id=$1",[cycle.id]);
  const f=guardianStripeFixture();const create=f.stripe.refunds.create;let lost=true;
  f.stripe.refunds.create=async(...args)=>{const result=await create(...args);if(lost){lost=false;throw Error('lost refund response');}return result;};
  assert.equal((await f.service().reconcile()).failed,1);
  await db.exec('update private.dopmi_guardian_jobs set available_at=now()');
  assert.equal((await f.service().reconcile()).processed,1);
  const result=await guardianSettlement('get',{cycle_id:cycle.id});assert.equal(result.status,'refunded');assert.equal(result.refund_cents,5000);
  assert.equal(f.calls.length,1);assert.equal(f.calls[0].kind,'refund');assert.equal(f.calls[0].fields.amount,5000);
});
test('Guardian pending refund remains retryable and is never reported as completed',async () => {
  const cycle=await boundGuardian();await releaseGuardian();const f=guardianStripeFixture();const create=f.stripe.refunds.create;
  f.stripe.refunds.create=async(...args)=>{const result=await create(...args);f.refunds[0].status='pending';return {...result,status:'pending'};};
  assert.equal((await f.service().reconcile()).failed,1);
  assert.equal((await guardianSettlement('get',{cycle_id:cycle.id})).status,'refund_pending');
  await db.exec('update private.dopmi_guardian_jobs set available_at=now()');f.refunds[0].status='succeeded';
  assert.equal((await f.service().reconcile()).processed,1);assert.equal(f.calls.length,1);
});
test('Guardian live-mode charge cannot complete a job',async () => {
  await boundGuardian();const f=guardianStripeFixture();await f.service().reconcileInvoice('in_guardian1');
  f.charge.livemode=true;
  assert.equal((await f.service().work()).failed,1);assert.equal(f.calls.length,0);
  assert.equal((await db.query('select status from private.dopmi_guardian_jobs')).rows[0].status,'attention');
});
test('Guardian work does not duplicate a leased transfer and stops writes outside idempotency window',async () => {
  await boundGuardian();const f=guardianStripeFixture();await f.service().reconcileInvoice('in_guardian1');
  const job=await guardianSettlement('claim');assert.ok(job.lease);
  assert.deepEqual(await f.service().work(),{processed:0,failed:0});assert.equal(f.calls.length,0);
  await db.exec("update private.dopmi_guardian_jobs set lease_until=now()-interval '1 minute',first_attempt_at=now()-interval '24 hours'");
  assert.equal((await f.service().work()).failed,1);assert.equal(f.calls.length,0);
});
test('Guardian canceled subscription permits reconciliation of a bound earlier paid invoice',async () => {
  await boundGuardian();await guardianRegistry('cancel',{donor_id:donor,stripe_subscription_id:'sub_guardian1'});
  const f=guardianStripeFixture();f.subscription.status='canceled';
  assert.equal((await f.service().reconcile()).processed,1);
});

test('Guardian destination changed after settlement prevents transfer to another account',async () => {
  await boundGuardian();const f=guardianStripeFixture();await f.service().reconcileInvoice('in_guardian1');
  await db.query("update private.dopmi_connect_accounts set account_id='acct_other' where owner_id=$1",[rescuer]);
  assert.equal((await f.service().work()).failed,1);assert.equal(f.calls.length,0);
  assert.equal((await db.query('select error_code from private.dopmi_guardian_jobs')).rows[0].error_code,'guardian_destination_mismatch');
});
test('Guardian processor transfer with wrong amount stays unconfirmed and requires attention',async () => {
  const cycle=await boundGuardian();const f=guardianStripeFixture();const create=f.stripe.transfers.create;
  f.stripe.transfers.create=async(...args)=>({...await create(...args),amount:1});
  assert.equal((await f.service().reconcile()).failed,1);
  assert.equal((await guardianSettlement('get',{cycle_id:cycle.id})).allocations[0].stripe_transfer_id,null);
  assert.equal((await db.query('select status from private.dopmi_guardian_jobs')).rows[0].status,'attention');
});
test('Guardian existing partial refund is not followed by another full refund',async () => {
  const cycle=await boundGuardian();await releaseGuardian();const f=guardianStripeFixture();
  f.refunds.push({id:'re_partial',charge:'ch_guardianRenewal1',amount:1000,currency:'mxn',status:'succeeded'});
  // Evidence was verified before the separate refund appeared.
  await f.service().reconcileInvoice('in_guardian1');f.charge.amount_refunded=1000;
  assert.equal((await f.service().work()).failed,1);assert.equal(f.calls.length,0);
  assert.equal((await guardianSettlement('get',{cycle_id:cycle.id})).status,'refund_pending');
});
test('Guardian worker transfers the sum of multiple allocations and exposes only that confirmed net',async () => {
  await db.query('update public.dopmi_rescue_records set reimbursable_cents=2500,urgent=true where id=$1',[expense]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents)
    values('71000000-0000-4000-8000-000000000004',$1,'expense','approved','{"title":"Comida"}','71000000-0000-4000-8000-000000000002',5000)`,[rescuer]);
  const cycle=await boundGuardian();const f=guardianStripeFixture();assert.equal((await f.service().reconcile()).processed,2);
  assert.equal(f.calls.reduce((n,c)=>n+c.fields.amount,0),4314);
  const settled=await guardianSettlement('get',{cycle_id:cycle.id});assert.equal(settled.allocations.filter(a=>a.stripe_transfer_id).length,2);
  const page=(await db.query('select public.dopmi_rescue_public($1) as v',['71000000-0000-4000-8000-000000000002'])).rows[0].v;
  assert.equal(page.items.find(r=>r.kind==='case').transferred_cents,4314);
});
