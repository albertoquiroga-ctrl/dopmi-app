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

const { guardianActivationService, guardianInitialEvidence, guardianConsentVersion } = await import('../../supabase/functions/_shared/guardian-activation.mjs');
const activationRpc = async (operation,data={}) =>
  (await db.query('select public.dopmi_guardian_activation_server($1,$2::jsonb) as value',[operation,JSON.stringify(data)])).rows[0].value;
const initialInput = {key,gross_cents:5000,consent:true,consent_version:guardianConsentVersion};
const activationPrepare = overrides => activationRpc('prepare',{donor_id:donor,...initialInput,return_url:'https://example.test/return',...overrides});
function initialFixture(rpcOverride=activationRpc) {
  const f=guardianStripeFixture(), sessions=new Map(), creations=[];
  f.charge.id='ch_initial'; f.charge.payment_intent='pi_initial'; f.charge.customer='cus_initial';
  Object.assign(f.charge.balance_transaction,{source:f.charge.id,net:4414});
  const intent={id:'pi_initial',livemode:false,status:'succeeded',customer:'cus_initial',payment_method:'pm_initial',
    amount:5000,amount_received:5000,currency:'mxn',setup_future_usage:'off_session',latest_charge:f.charge};
  f.stripe.paymentIntents.retrieve=async()=>structuredClone(intent);
  f.stripe.checkout={sessions:{create:async(fields,options)=>{
    creations.push({fields:structuredClone(fields),options});
    if(!sessions.has(options.idempotencyKey)) sessions.set(options.idempotencyKey,{id:`cs_test_initial${sessions.size+1}`,
      livemode:false,mode:fields.mode,client_reference_id:fields.client_reference_id,amount_total:5000,amount_subtotal:5000,
      currency:'mxn',expires_at:fields.expires_at,customer_creation:fields.customer_creation,automatic_tax:fields.automatic_tax,
      total_details:{amount_tax:0,amount_shipping:0,amount_discount:0},status:'open',payment_status:'unpaid',
      customer:'cus_initial',payment_intent:'pi_initial',url:'https://checkout.stripe.com/c/pay/initial'});
    return structuredClone(sessions.get(options.idempotencyKey));},
    retrieve:async sessionId=>structuredClone([...sessions.values()].find(s=>s.id===sessionId))}};
  f.stripe.events={retrieve:async()=>({id:'evt_initial',livemode:false,type:'checkout.session.completed',data:{object:{id:'cs_test_initial1'}}})};
  const service=guardianActivationService({stripe:f.stripe,rpc:rpcOverride,settle:guardianSettlement,returnUrl:'https://example.test/return',logger:{}});
  const paid=()=>Object.assign([...sessions.values()][0],{status:'complete',payment_status:'paid'});
  return {...f,sessions,creations,intent,initial:service,paid};
}

test('Guardian initial consent and full capacity are required before any Stripe write',async()=>{
  const f=initialFixture();
  await assert.rejects(f.initial.checkout(donor,{...initialInput,consent:false}),/guardian_consent_required/);
  await rejected(()=>activationPrepare({consent_version:'old'}),/Autorización/);
  await db.query('update public.dopmi_rescue_records set reimbursable_cents=1000 where id=$1',[expense]);
  const result=await f.initial.checkout(donor,initialInput);
  assert.equal(result.status,'no_capacity');assert.equal(result.checkout_url,null);assert.equal(f.creations.length,0);
  assert.equal((await db.query('select count(*)::integer n from private.dopmi_guardian_allocations')).rows[0].n,0);
});

test('Guardian initial Checkout persists consent and one stable request per donor',async()=>{
  const f=initialFixture();const result=await f.initial.checkout(donor,initialInput);
  assert.equal(result.status,'pending');assert.match(result.checkout_url,/^https:\/\/checkout.stripe.com\//);
  assert.deepEqual(await f.initial.checkout(donor,initialInput),result);assert.equal(f.creations.length,1);
  const a=await activationRpc('get',{cycle_id:result.cycle_id});
  assert.equal(a.consent_version,guardianConsentVersion);assert.ok(a.consent_at);
  assert.ok(Date.parse(a.hold_expires_at)>Date.parse(a.checkout_expires_at));
  const {fields,options}=f.creations[0];
  assert.equal(fields.mode,'payment');assert.equal(fields.payment_intent_data.setup_future_usage,'off_session');
  assert.equal(fields.payment_method_types,undefined);assert.match(fields.integration_identifier,/_[a-z]{8}$/);
  assert.equal(options.idempotencyKey,`guardian-checkout:${a.cycle_id}`);
  await rejected(()=>activationPrepare({key:'72000000-0000-4000-8000-000000000002'}),/ya tiene/);
  await rejected(()=>activationPrepare({gross_cents:2000}),/ya utilizado/);
});

test('Guardian lost Checkout response retries same request and creates one session',async()=>{
  const f=initialFixture();const create=f.stripe.checkout.sessions.create;let lost=true;
  f.stripe.checkout.sessions.create=async(...args)=>{const s=await create(...args);if(lost){lost=false;throw Error('lost_response');}return s;};
  await assert.rejects(f.initial.checkout(donor,initialInput),/lost_response/);
  assert.equal((await f.initial.reconcile()).failed,0);
  assert.equal(f.sessions.size,1);assert.equal(f.creations.length,2);assert.deepEqual(f.creations[0],f.creations[1]);
  assert.equal((await f.initial.checkout(donor,initialInput)).status,'pending');
});

test('Guardian lost database acknowledgment does not create a second Checkout',async()=>{
  let lost=true;
  const f=initialFixture(async(op,data)=>{const result=await activationRpc(op,data);if(op==='save_checkout'&&lost){lost=false;throw Error('db_lost');}return result;});
  await assert.rejects(f.initial.checkout(donor,initialInput),/db_lost/);
  assert.ok((await f.initial.checkout(donor,initialInput)).checkout_url);assert.equal(f.creations.length,1);
});

test('Guardian lease and retry window prevent duplicate or very late Checkout writes',async()=>{
  const a=await activationPrepare();const f=initialFixture();
  const claim=await activationRpc('claim_checkout',{cycle_id:a.cycle_id});assert.ok(claim.lease);
  assert.equal((await f.initial.checkout(donor,initialInput)).checkout_url,null);assert.equal(f.creations.length,0);
  await db.exec("update private.dopmi_guardian_activations set lease_until=now()-interval '1 second',first_attempt_at=now()-interval '24 hours'");
  assert.equal((await f.initial.checkout(donor,initialInput)).status,'attention');assert.equal(f.creations.length,0);
});

test('Guardian stale unstarted activation expires without opening Checkout',async()=>{
  await activationPrepare();const f=initialFixture();
  await db.exec("update private.dopmi_guardian_activations set checkout_expires_at=now()+interval '20 minutes'");
  assert.equal((await f.initial.checkout(donor,initialInput)).status,'expired');assert.equal(f.creations.length,0);
  assert.equal((await db.query('select reserved_cents from private.dopmi_guardian_cycles')).rows[0].reserved_cents,0);
});

test('Guardian initial paid Checkout assigns actual net and recovers webhook duplicates',async()=>{
  const f=initialFixture();const a=await f.initial.checkout(donor,initialInput);f.paid();
  assert.deepEqual(await f.initial.handleWebhook('evt_initial'),{received:true,guardian:true});
  const settled=await guardianSettlement('get',{cycle_id:a.cycle_id});
  assert.equal(settled.allocated_cents,4314);assert.equal(settled.checkout_session_id,'cs_test_initial1');
  assert.equal(settled.invoice_id,null);assert.equal(settled.invoice_payment_id,null);
  assert.equal((await f.service().work()).processed,1);
  await f.initial.handleWebhook('evt_initial');assert.equal((await f.service().work()).processed,0);assert.equal(f.transfers.size,1);
  const state=await f.initial.checkout(donor,initialInput);assert.equal(state.status,'funded_pending_schedule');assert.equal(state.checkout_url,null);
  assert.equal((await db.query('select count(*)::integer n from private.dopmi_guardian_subscriptions')).rows[0].n,0);
});

test('Guardian expired unpaid Checkout releases capacity, and any late payment gets a full refund',async()=>{
  const f=initialFixture();const a=await f.initial.checkout(donor,initialInput);
  [...f.sessions.values()][0].status='expired';await f.initial.reconcileSession('cs_test_initial1');
  assert.equal((await activationRpc('get',{cycle_id:a.cycle_id})).status,'expired');
  await activationPrepare({key:'72000000-0000-4000-8000-000000000002'});
  f.paid();const settled=await f.initial.reconcileSession('cs_test_initial1');assert.equal(settled.refund_cents,5000);
  assert.equal(settled.allocated_cents,0);assert.equal(settled.platform_fee_cents,0);assert.equal(settled.platform_loss_cents,586);
  assert.equal((await f.service().work()).processed,1);assert.equal(f.refunds.length,1);assert.equal(f.transfers.size,0);
  assert.equal((await activationRpc('get',{cycle_id:a.cycle_id})).status,'refunded');
});

test('Guardian paid initial payment with invalidated eligibility refunds instead of assigning partially',async()=>{
  const f=initialFixture();await f.initial.checkout(donor,initialInput);f.paid();
  await db.query("update public.dopmi_rescue_records set status='changes_requested' where id=$1",[expense]);
  assert.equal((await f.initial.reconcileSession('cs_test_initial1')).refund_cents,5000);
  assert.equal((await f.service().work()).processed,1);assert.equal(f.transfers.size,0);
});

test('Guardian initial evidence rejects another customer, live mode, unknown fee and reused charge',async()=>{
  const f=initialFixture();const result=await f.initial.checkout(donor,initialInput);f.paid();
  const a=await activationRpc('get',{cycle_id:result.cycle_id}),s=[...f.sessions.values()][0];
  for(const intent of [{...f.intent,customer:'cus_other'},{...f.intent,livemode:true},
    {...f.intent,latest_charge:{...f.charge,balance_transaction:null}}, {...f.intent,setup_future_usage:null}])
    assert.throws(()=>guardianInitialEvidence(s,intent,a),/mismatch|processor_fee_not_ready/);
  assert.throws(()=>guardianInitialEvidence({...s,id:'cs_test_other'},f.intent,a),/mismatch/);
  const d=await prepare({gross_cents:2000});await settle(d.id,{gross_cents:2000,payment_intent_id:'pi_initial',charge_id:'ch_initial'});
  await rejected(()=>guardianSettlement('settle_initial',guardianInitialEvidence(s,f.intent,a)),/ya utilizado/);
});

test('Guardian initial settlement rejects missing binding, invoice masquerading and foreign donor',async()=>{
  const f=initialFixture();const result=await f.initial.checkout(donor,initialInput);f.paid();
  const a=await activationRpc('get',{cycle_id:result.cycle_id});const evidence=guardianInitialEvidence([...f.sessions.values()][0],f.intent,a);
  await rejected(()=>guardianSettlement('settle_initial',{...evidence,checkout_session_id:'cs_test_unknown'}),/sin vínculo/);
  await rejected(()=>guardianSettlement('settle_initial',{...evidence,invoice_id:'in_fake'}),/sin vínculo/);
  await rejected(()=>guardianSettlement('settle_initial',{...evidence,donor_id:other}),/no coincide/);
  await guardianSettlement('settle_initial',evidence);
  await rejected(()=>guardianSettlement('settle_initial',{...evidence,payment_method_id:'pm_different'}),/otra evidencia/);
});

test('Guardian ownership hints and asynchronous unpaid completion cannot allocate',async()=>{
  const f=initialFixture();await f.initial.checkout(donor,initialInput);
  const session=[...f.sessions.values()][0];session.status='complete';
  assert.equal(await f.initial.reconcileSession(session.id),null);assert.equal((await f.service().work()).processed,0);
  f.stripe.events.retrieve=async()=>({livemode:false,type:'checkout.session.async_payment_succeeded',data:{object:{id:'cs_test_foreign',metadata:{dopmi_guardian_cycle:session.client_reference_id}}}});
  assert.equal(await f.initial.handleWebhook('evt_foreign'),null);
  f.stripe.events.retrieve=async()=>({livemode:true,type:'checkout.session.completed',data:{object:{id:session.id}}});
  await assert.rejects(f.initial.handleWebhook('evt_live'),/guardian_event_invalid/);
});

test('Guardian activation rows and mutation RPC are inaccessible to clients and administrators',async()=>{
  for(const [user,asRole] of [[donor,'anon'],[donor,'authenticated'],[staff,'authenticated']]){
    await role(user,asRole);await rejected(()=>activationPrepare(),/permission denied/);
    await rejected(()=>db.query('select * from private.dopmi_guardian_activations'),/permission denied/);
  }
  await role('','service_role');assert.deepEqual(await activationRpc('candidates'),[]);
});

test('Guardian asynchronous failure frees the initial hold; delayed success cannot consume a new reservation',async()=>{
  const f=initialFixture();const a=await f.initial.checkout(donor,initialInput);
  [...f.sessions.values()][0].status='complete';f.intent.status='requires_payment_method';f.intent.amount_received=0;
  await f.initial.reconcileSession('cs_test_initial1');
  assert.equal((await activationRpc('get',{cycle_id:a.cycle_id})).status,'failed');
  await activationPrepare({key:'72000000-0000-4000-8000-000000000002'});
  f.intent.status='succeeded';f.intent.amount_received=5000;f.paid();
  assert.equal((await f.initial.reconcileSession('cs_test_initial1')).refund_cents,5000);
});

test('Guardian expired lease cannot bind a different Checkout and failed reads leave payment pending',async()=>{
  const f=initialFixture();const a=await activationPrepare();const claim=await activationRpc('claim_checkout',{cycle_id:a.cycle_id});
  await rejected(()=>activationRpc('save_checkout',{cycle_id:a.cycle_id,lease:crypto.randomUUID(),session_id:'cs_test_wrong'}),/vencido/);
  await activationRpc('checkout_failed',{cycle_id:a.cycle_id,lease:claim.lease});
  await f.initial.checkout(donor,initialInput);f.paid();
  f.stripe.paymentIntents.retrieve=async()=>{throw Error('Stripe temporarily unavailable');};
  await assert.rejects(f.initial.reconcileSession('cs_test_initial1'),/temporarily unavailable/);
  assert.equal((await activationRpc('get',{cycle_id:a.cycle_id})).settlement,null);
});

test('Guardian changed Checkout amount, reference or hosted URL never reaches a donor',async()=>{
  const f=initialFixture();await f.initial.checkout(donor,initialInput);const s=[...f.sessions.values()][0];
  s.url='https://example.test/phishing';await assert.rejects(f.initial.checkout(donor,initialInput),/guardian_checkout_url_invalid/);
  s.url='https://checkout.stripe.com/c/pay/initial';s.amount_total=6000;
  await assert.rejects(f.initial.checkout(donor,initialInput),/guardian_checkout_mismatch/);
  s.amount_total=5000;s.client_reference_id=crypto.randomUUID();
  await assert.rejects(f.initial.reconcileSession(s.id),/guardian_checkout_mismatch/);
});

const { guardianScheduleService, guardianMonthlyAnchor } = await import('../../supabase/functions/_shared/guardian-schedule.mjs');
const scheduleRpc=async(operation,data={})=>(await db.query('select public.dopmi_guardian_schedule_server($1,$2::jsonb) as value',[operation,JSON.stringify(data)])).rows[0].value;
async function scheduleFixture() {
  const f=initialFixture();const opened=await f.initial.checkout(donor,initialInput);f.paid();
  await f.initial.reconcileSession('cs_test_initial1');await f.service().work();
  f.charge.created=Math.floor(Date.now()/1000)-60;
  const prices=new Map(),subscriptions=new Map(),scheduleCalls=[];
  f.stripe.customers={retrieve:async()=>({id:'cus_initial',livemode:false,balance:0})};
  f.stripe.paymentMethods={retrieve:async()=>({id:'pm_initial',livemode:false,customer:'cus_initial'})};
  f.stripe.prices={create:async(fields,options)=>{
    scheduleCalls.push({kind:'price',fields:structuredClone(fields),options});
    if(!prices.has(options.idempotencyKey)) prices.set(options.idempotencyKey,{id:'price_schedule1',livemode:false,active:true,
      ...fields,recurring:{...fields.recurring,usage_type:'licensed'},billing_scheme:'per_unit'});
    return structuredClone(prices.get(options.idempotencyKey));},retrieve:async()=>structuredClone([...prices.values()][0])};
  f.stripe.subscriptions={create:async(fields,options)=>{
    scheduleCalls.push({kind:'subscription',fields:structuredClone(fields),options});
    if(!subscriptions.has(options.idempotencyKey)) subscriptions.set(options.idempotencyKey,{id:'sub_schedule1',livemode:false,status:'active',
      ...fields,items:{has_more:false,data:[{quantity:1,price:{id:fields.items[0].price},current_period_end:guardianMonthlyAnchor(f.charge.created).next}]},
      cancel_at:null,discounts:[],default_tax_rates:[],pause_collection:null,latest_invoice:null});
    return structuredClone(subscriptions.get(options.idempotencyKey));},
    retrieve:async()=>structuredClone([...subscriptions.values()][0]),
    update:async(subId,fields,options)=>{scheduleCalls.push({kind:'pause',subId,fields:structuredClone(fields),options});
      Object.assign([...subscriptions.values()][0],fields);return structuredClone([...subscriptions.values()][0]);}};
  const service=(override=scheduleRpc)=>guardianScheduleService({stripe:f.stripe,rpc:override,logger:{}});
  return {...f,cycleId:opened.cycle_id,prices,subscriptions,scheduleCalls,scheduler:service};
}

test('Guardian monthly anchor preserves end-of-month day and UTC time across leap years',()=>{
  for(const [from,to] of [['2027-01-31T15:20:01Z','2027-02-28T15:20:01Z'],['2028-01-31T15:20:01Z','2028-02-29T15:20:01Z'],['2026-12-24T05:01:02Z','2027-01-24T05:01:02Z']]){
    const result=guardianMonthlyAnchor(Date.parse(from)/1000);assert.equal(result.next,Date.parse(to)/1000);
    assert.equal(result.config.day_of_month,new Date(from).getUTCDate());
  }
  assert.throws(()=>guardianMonthlyAnchor(NaN),/invalid/);
});

test('Guardian schedule requires delivered initial funds, not an unpaid or merely allocated Checkout',async()=>{
  const f=initialFixture();const a=await f.initial.checkout(donor,initialInput);
  await rejected(()=>scheduleRpc('prepare',{cycle_id:a.cycle_id,charge_created:Math.floor(Date.now()/1000)}),/no entregado/);
  f.paid();await f.initial.reconcileSession('cs_test_initial1');assert.deepEqual(await scheduleRpc('candidates'),[]);
  await f.service().work();assert.deepEqual(await scheduleRpc('candidates'),[{cycle_id:a.cycle_id}]);
});

test('Guardian creates guarded monthly Billing, verifies pause and registers exact initial charge once',async()=>{
  const f=await scheduleFixture();const job=await f.scheduler().run(f.cycleId);
  assert.equal(job.status,'ready');assert.equal(f.prices.size,1);assert.equal(f.subscriptions.size,1);
  const creation=f.scheduleCalls.find(c=>c.kind==='subscription').fields;
  assert.equal(creation.collection_method,'send_invoice');assert.equal(creation.cancel_at_period_end,true);
  assert.equal(creation.proration_behavior,'none');assert.equal(creation.payment_settings,undefined);
  const pause=f.scheduleCalls.find(c=>c.kind==='pause').fields;
  assert.deepEqual(pause.pause_collection,{behavior:'keep_as_draft'});assert.equal(pause.cancel_at_period_end,false);
  const registry=await guardianRegistry('lookup',{stripe_subscription_id:'sub_schedule1'});
  assert.equal(registry.donor_id,donor);assert.equal(registry.gross_cents,5000);assert.equal(registry.status,'active');
  const stored=(await db.query('select initial_charge_id,initial_payment_intent_id from private.dopmi_guardian_subscriptions')).rows[0];
  assert.deepEqual(stored,{initial_charge_id:'ch_initial',initial_payment_intent_id:'pi_initial'});
  await f.scheduler().run(f.cycleId);assert.equal(f.scheduleCalls.length,3);
  assert.equal((await f.initial.checkout(donor,initialInput)).status,'active');
});

test('Guardian lost subscription response recovers one subscription using the same request',async()=>{
  const f=await scheduleFixture();const create=f.stripe.subscriptions.create;let lost=true;
  f.stripe.subscriptions.create=async(...args)=>{const result=await create(...args);if(lost){lost=false;throw Error('lost_sub');}return result;};
  await assert.rejects(f.scheduler().run(f.cycleId),/lost_sub/);
  assert.equal([...f.subscriptions.values()][0].cancel_at_period_end,true);
  await db.exec('update private.dopmi_guardian_schedule_jobs set available_at=now()');
  assert.equal((await f.scheduler().run(f.cycleId)).status,'ready');assert.equal(f.subscriptions.size,1);
  const writes=f.scheduleCalls.filter(c=>c.kind==='subscription');assert.deepEqual(writes[0],writes[1]);
});

test('Guardian lost pause response is recovered by authoritative read without undoing the guard',async()=>{
  const f=await scheduleFixture();const update=f.stripe.subscriptions.update;let lost=true;
  f.stripe.subscriptions.update=async(...args)=>{const result=await update(...args);if(lost){lost=false;throw Error('lost_pause');}return result;};
  await assert.rejects(f.scheduler().run(f.cycleId),/lost_pause/);
  assert.equal(await guardianRegistry('lookup',{stripe_subscription_id:'sub_schedule1'}),null);
  await db.exec('update private.dopmi_guardian_schedule_jobs set available_at=now()');
  assert.equal((await f.scheduler().run(f.cycleId)).status,'ready');assert.equal(f.scheduleCalls.filter(c=>c.kind==='pause').length,1);
});

test('Guardian lost ready acknowledgment cannot downgrade or duplicate a registered schedule',async()=>{
  const f=await scheduleFixture();let lost=true;
  const scheduler=f.scheduler(async(op,data)=>{const result=await scheduleRpc(op,data);if(op==='ready'&&lost){lost=false;throw Error('db_lost');}return result;});
  await assert.rejects(scheduler.run(f.cycleId),/db_lost/);
  assert.equal((await scheduleRpc('get',{cycle_id:f.cycleId})).status,'ready');
  assert.equal((await scheduler.run(f.cycleId)).status,'ready');assert.equal(f.scheduleCalls.length,3);
});

test('Guardian pause failure leaves cancellation guard, and old retry window makes no new writes',async()=>{
  const f=await scheduleFixture();f.stripe.subscriptions.update=async()=>{throw Error('offline');};
  await assert.rejects(f.scheduler().run(f.cycleId),/offline/);
  assert.equal([...f.subscriptions.values()][0].cancel_at_period_end,true);
  await db.exec("update private.dopmi_guardian_schedule_jobs set available_at=now(),first_attempt_at=now()-interval '24 hours'");
  const before=f.scheduleCalls.length;assert.equal((await f.scheduler().run(f.cycleId)).status,'attention');
  assert.equal(f.scheduleCalls.length,before);assert.equal(await guardianRegistry('lookup',{stripe_subscription_id:'sub_schedule1'}),null);
});

test('Guardian detached payment method, refunded charge and wrong subscription block registration',async()=>{
  const f=await scheduleFixture();f.charge.amount_refunded=5000;
  await assert.rejects(f.scheduler().run(f.cycleId),/charge_mismatch/);assert.equal(f.scheduleCalls.length,0);
  f.charge.amount_refunded=0;f.stripe.paymentMethods.retrieve=async()=>({id:'pm_initial',customer:'cus_other',livemode:false});
  await assert.rejects(f.scheduler().run(f.cycleId),/customer_mismatch/);assert.equal(f.scheduleCalls.length,0);
  f.stripe.paymentMethods.retrieve=async()=>({id:'pm_initial',customer:'cus_initial',livemode:false});
  const create=f.stripe.subscriptions.create;f.stripe.subscriptions.create=async(...args)=>({...await create(...args),collection_method:'charge_automatically'});
  await assert.rejects(f.scheduler().run(f.cycleId),/subscription_mismatch/);
  assert.equal(await guardianRegistry('lookup',{stripe_subscription_id:'sub_schedule1'}),null);
});

test('Guardian too-old initial payment is held for review without opening a late calendar',async()=>{
  const f=await scheduleFixture();f.charge.created=Math.floor(Date.now()/1000)-40*86400;
  assert.equal((await f.scheduler().run(f.cycleId)).status,'attention');assert.equal(f.scheduleCalls.length,0);
});

test('Guardian subscription cancellation and configuration drift synchronize from fresh Stripe reads',async()=>{
  const f=await scheduleFixture();await f.scheduler().run(f.cycleId);
  f.stripe.events.retrieve=async()=>({livemode:false,type:'customer.subscription.updated',data:{object:{id:'sub_schedule1'}}});
  [...f.subscriptions.values()][0].pause_collection=null;
  await assert.rejects(f.scheduler().handleWebhook('evt_changed'),/pause_unconfirmed/);
  assert.equal((await scheduleRpc('get',{cycle_id:f.cycleId})).status,'attention');
  [...f.subscriptions.values()][0].status='canceled';
  await f.scheduler().handleWebhook('evt_canceled');
  assert.equal((await guardianRegistry('lookup',{stripe_subscription_id:'sub_schedule1'})).status,'canceled');
  assert.equal((await f.initial.checkout(donor,initialInput)).status,'canceled');
});

test('Guardian schedule mutation and internal state remain unavailable to clients and admins',async()=>{
  for(const [user,asRole] of [[donor,'anon'],[donor,'authenticated'],[staff,'authenticated']]){
    await role(user,asRole);await rejected(()=>scheduleRpc('candidates'),/permission denied/);
    await rejected(()=>db.query('select * from private.dopmi_guardian_schedule_jobs'),/permission denied/);
  }
  await role('','service_role');assert.deepEqual(await scheduleRpc('candidates'),[]);
});

test('Guardian lost Price reply retries an identical key and payload without a second Price',async()=>{
  const f=await scheduleFixture();const create=f.stripe.prices.create;let lost=true;
  f.stripe.prices.create=async(...args)=>{const result=await create(...args);if(lost){lost=false;throw Error('price_lost');}return result;};
  await assert.rejects(f.scheduler().run(f.cycleId),/price_lost/);
  await db.exec('update private.dopmi_guardian_schedule_jobs set available_at=now()');
  assert.equal((await f.scheduler().run(f.cycleId)).status,'ready');assert.equal(f.prices.size,1);
  const calls=f.scheduleCalls.filter(c=>c.kind==='price');assert.deepEqual(calls[0],calls[1]);
});

test('Guardian subscription must retain cancellation guard until its pause is verified',async()=>{
  const f=await scheduleFixture();const create=f.stripe.subscriptions.create;
  f.stripe.subscriptions.create=async(...args)=>({...await create(...args),cancel_at_period_end:false});
  await assert.rejects(f.scheduler().run(f.cycleId),/missing_guard/);
  assert.equal(f.scheduleCalls.some(c=>c.kind==='pause'),false);
  assert.equal(await guardianRegistry('lookup',{stripe_subscription_id:'sub_schedule1'}),null);
});

test('Guardian periodic monitoring repairs a missed cancellation webhook without new Stripe writes',async()=>{
  const f=await scheduleFixture();await f.scheduler().run(f.cycleId);[...f.subscriptions.values()][0].status='canceled';
  const before=f.scheduleCalls.length;assert.equal((await f.scheduler().reconcile()).failed,0);
  assert.equal((await guardianRegistry('lookup',{stripe_subscription_id:'sub_schedule1'})).status,'canceled');
  assert.equal(f.scheduleCalls.length,before);assert.deepEqual(await scheduleRpc('monitor'),[]);
});

test('Guardian schedule respects a sandbox clock and does not schedule while it advances',async()=>{
  const f=await scheduleFixture();f.stripe.customers.retrieve=async()=>({id:'cus_initial',livemode:false,balance:0,test_clock:'clock_guardian'});
  f.stripe.testHelpers={testClocks:{retrieve:async()=>({id:'clock_guardian',status:'advancing',frozen_time:f.charge.created})}};
  await assert.rejects(f.scheduler().run(f.cycleId),/clock_unavailable/);assert.equal(f.scheduleCalls.length,0);
  f.stripe.testHelpers.testClocks.retrieve=async()=>({id:'clock_guardian',status:'ready',frozen_time:f.charge.created+10});
  assert.equal((await f.scheduler().run(f.cycleId)).status,'ready');
});

test('Guardian unexpected scheduled resume cannot remove the initial cancellation guard',async()=>{
  const f=await scheduleFixture();const create=f.stripe.subscriptions.create;
  f.stripe.subscriptions.create=async(...args)=>({...await create(...args),pause_collection:{behavior:'keep_as_draft',resumes_at:2000000000}});
  await assert.rejects(f.scheduler().run(f.cycleId),/pause_changed/);
  assert.equal(f.scheduleCalls.some(c=>c.kind==='pause'),false);
  assert.equal(await guardianRegistry('lookup',{stripe_subscription_id:'sub_schedule1'}),null);
});

test('Guardian failed source verification advances retry ordering without creating Billing resources',async()=>{
  const f=await scheduleFixture();f.charge.amount_refunded=5000;
  await db.query("update private.dopmi_guardian_activations set checked_at=now()-interval '1 day' where cycle_id=$1",[f.cycleId]);
  assert.equal((await f.scheduler().reconcile()).failed,1);assert.equal(f.scheduleCalls.length,0);
  assert.equal((await db.query('select checked_at=now() as checked from private.dopmi_guardian_activations where cycle_id=$1',[f.cycleId])).rows[0].checked,true);
  assert.equal(await scheduleRpc('get',{cycle_id:f.cycleId}),null);
});

const { guardianCollectionService } = await import('../../supabase/functions/_shared/guardian-collection.mjs');
const recoveryRpc=async(operation,data={})=>(await db.query('select public.dopmi_guardian_recovery_server($1,$2::jsonb) as value',[operation,JSON.stringify(data)])).rows[0].value;
const collectionRpc=async(operation,data={})=>(await db.query('select public.dopmi_guardian_collection_server($1,$2::jsonb) as value',[operation,JSON.stringify(data)])).rows[0].value;
async function collectionFixture() {
  const calendar=await scheduleFixture();await calendar.scheduler().run(calendar.cycleId);
  const f=guardianStripeFixture(),invoice=f.invoice,subscription=[...calendar.subscriptions.values()][0];
  Object.assign(invoice,{automatic_tax:{enabled:false},status:'draft',created:Math.floor(Date.now()/1000)-1,customer:'cus_initial',amount_paid:0,amount_remaining:5000,attempt_count:0,attempted:false,
    parent:{subscription_details:{subscription:'sub_schedule1'}}});
  Object.assign(invoice.lines.data[0],{pricing:{price_details:{price:'price_schedule1'}},parent:{subscription_item_details:{subscription:'sub_schedule1'}},
    period:{start:invoice.created,end:invoice.created+30*86400}});
  const intent=f.stripe.paymentIntents.retrieve;f.stripe.paymentIntents.retrieve=async()=>f.invoice.status==='paid'
    ? {...await intent(),customer:'cus_initial'}
    : {id:'pi_guardianRenewal1',livemode:false,customer:'cus_initial',currency:'mxn',amount:5000,amount_received:0,amount_capturable:0,
      payment_method:'pm_initial',status:f.invoice.status==='void'?'canceled':'requires_confirmation',latest_charge:null};
  const payment=f.invoice.payments.data[0];Object.assign(payment,{status:'open',amount_paid:null,livemode:false,currency:'mxn',is_default:true});
  f.stripe.invoicePayments={list:async()=>structuredClone(f.invoice.payments)};
  f.stripe.subscriptions=calendar.stripe.subscriptions;f.stripe.customers=calendar.stripe.customers;f.stripe.paymentMethods=calendar.stripe.paymentMethods;
  f.stripe.invoices.list=async()=>({has_more:false,data:[structuredClone(invoice)]});
  f.stripe.invoices.finalizeInvoice=async(id,fields,options)=>{f.calls.push({kind:'finalize',id,fields,options});invoice.status='open';return structuredClone(invoice);};
  f.stripe.invoices.voidInvoice=async(id,fields,options)=>{f.calls.push({kind:'void',id,fields,options});invoice.status='void';payment.status='canceled';return structuredClone(invoice);};
  f.stripe.invoices.pay=async(id,fields,options)=>{f.calls.push({kind:'pay',id,fields,options});Object.assign(invoice,{status:'paid',amount_paid:5000,amount_remaining:0,attempt_count:1,attempted:true});Object.assign(payment,{status:'paid',amount_paid:5000});return structuredClone(invoice);};
  const collector=(rpc=collectionRpc,recovery=recoveryRpc)=>guardianCollectionService({stripe:f.stripe,rpc,recoveryRpc:recovery,reconcileInvoice:f.service().reconcileInvoice,logger:{}});
  const prepare=()=>collectionRpc('prepare',{invoice_id:invoice.id,subscription_id:subscription.id,cycle_key:guardianKey,
    period_start:invoice.lines.data[0].period.start,period_end:invoice.lines.data[0].period.end,fresh:true});
  return {...f,subscription,calendar,collector,prepare};
}
const collectionDue=()=>db.exec('update private.dopmi_guardian_collection_jobs set available_at=now()');

test('Guardian monthly collection reserves before one off-session pay and settles actual net',async()=>{
  const f=await collectionFixture(),pay=f.stripe.invoices.pay;
  f.stripe.invoices.pay=async(...args)=>{
    const j=await collectionRpc('get',{invoice_id:f.invoice.id});assert.ok(j.pay_requested_at);assert.equal(j.cycle_status,'reserved');
    assert.equal((await guardianSettlement('lookup_invoice',{invoice_id:f.invoice.id})).cycle_id,j.cycle_id);return pay(...args);};
  const j=await f.collector().run(f.invoice.id);assert.equal(j.status,'paid');
  assert.equal((await guardianSettlement('get',{cycle_id:j.cycle_id})).allocated_cents,4314);
  await f.collector().run(f.invoice.id);assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
  assert.deepEqual(f.calls.find(c=>c.kind==='pay').fields,{payment_method:'pm_initial',off_session:true});
  assert.deepEqual(f.calls.find(c=>c.kind==='finalize').fields,{auto_advance:false});
});
test('Guardian insufficient capacity voids one invoice without payment or debt',async()=>{
  const f=await collectionFixture();await prepare({gross_cents:7000});
  const j=await f.collector().run(f.invoice.id);assert.equal(j.status,'skipped');assert.equal(j.decision,'skip');
  assert.equal(f.invoice.status,'void');assert.equal(f.invoice.amount_remaining,5000);assert.equal(f.invoice.payments.data[0].status,'canceled');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
  assert.equal(await guardianSettlement('get',{cycle_id:j.cycle_id}),null);
  await f.collector().run(f.invoice.id);assert.equal(f.calls.filter(c=>c.kind==='void').length,1);
});
test('Guardian lost finalize reply resumes the same invoice and reservation',async()=>{
  const f=await collectionFixture(),finalize=f.stripe.invoices.finalizeInvoice;let lost=true;
  f.stripe.invoices.finalizeInvoice=async(...args)=>{const result=await finalize(...args);if(lost){lost=false;throw Error('finalize_lost');}return result;};
  await assert.rejects(f.collector().run(f.invoice.id),/finalize_lost/);
  const before=await collectionRpc('get',{invoice_id:f.invoice.id});await collectionDue();
  const after=await f.collector().run(f.invoice.id);assert.equal(after.cycle_id,before.cycle_id);assert.equal(after.status,'paid');
  assert.equal(f.calls.filter(c=>c.kind==='finalize').length,1);assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});
test('Guardian lost pay response reconciles without a second pay invocation',async()=>{
  const f=await collectionFixture(),pay=f.stripe.invoices.pay;
  f.stripe.invoices.pay=async(...args)=>{await pay(...args);throw Error('pay_lost');};
  await assert.rejects(f.collector().run(f.invoice.id),/pay_lost/);
  assert.equal((await collectionRpc('get',{invoice_id:f.invoice.id})).status,'attention');
  assert.equal((await f.collector().run(f.invoice.id)).status,'paid');assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});
test('Guardian lost authorization response never retries uncertain payment or opens another cycle',async()=>{
  const f=await collectionFixture();let lost=true;
  const faulty=async(op,data)=>{const result=await collectionRpc(op,data);if(op==='authorize_pay'&&lost){lost=false;throw Error('authorize_lost');}return result;};
  await assert.rejects(f.collector(faulty).run(f.invoice.id),/authorize_lost/);
  assert.equal((await f.collector().run(f.invoice.id)).status,'attention');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
  f.invoice.id='in_future';f.invoice.status='draft';f.invoice.lines.data[0].period.start++;
  await rejected(()=>f.collector().run(f.invoice.id),/pendiente de conciliación/);
});
test('Guardian expired reservation never authorizes a monthly charge',async()=>{
  const f=await collectionFixture(),finalize=f.stripe.invoices.finalizeInvoice;
  f.stripe.invoices.finalizeInvoice=async(...args)=>{const result=await finalize(...args);
    await db.exec("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 minute' where status='reserved'");return result;};
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
});
test('Guardian donor suspension during finalization causes void instead of pay',async()=>{
  const f=await collectionFixture(),finalize=f.stripe.invoices.finalizeInvoice;
  f.stripe.invoices.finalizeInvoice=async(...args)=>{const result=await finalize(...args);await db.query("update public.profiles set account_status='suspended' where id=$1",[donor]);return result;};
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
});
test('Guardian cancellation after reservation prevents pay and preserves history',async()=>{
  const f=await collectionFixture(),finalize=f.stripe.invoices.finalizeInvoice;
  f.stripe.invoices.finalizeInvoice=async(...args)=>{const result=await finalize(...args);f.subscription.status='canceled';return result;};
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
});
test('Guardian changed amount or resumed billing never reserves or mutates invoice',async()=>{
  const f=await collectionFixture();f.invoice.total=6000;
  await assert.rejects(f.collector().run(f.invoice.id),/amount_mismatch/);f.invoice.total=5000;f.subscription.pause_collection=null;
  await assert.rejects(f.collector().run(f.invoice.id),/billing_not_fail_closed/);
  assert.equal(await collectionRpc('get',{invoice_id:f.invoice.id}),null);assert.equal(f.calls.length,0);
});
test('Guardian saved method belonging to another customer never authorizes collection',async()=>{
  const f=await collectionFixture();f.stripe.paymentMethods.retrieve=async()=>({id:'pm_initial',livemode:false,customer:'cus_wrong'});
  await assert.rejects(f.collector().run(f.invoice.id),/customer_mismatch/);
  assert.equal(f.calls.some(c=>c.kind==='pay'),false);assert.equal((await collectionRpc('get',{invoice_id:f.invoice.id})).pay_requested_at,null);
});
test('Guardian lost void response is recovered by reading the terminal invoice',async()=>{
  const f=await collectionFixture();await prepare({gross_cents:7000});const voidInvoice=f.stripe.invoices.voidInvoice;
  f.stripe.invoices.voidInvoice=async(...args)=>{await voidInvoice(...args);throw Error('void_lost');};
  await assert.rejects(f.collector().run(f.invoice.id),/void_lost/);await collectionDue();
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.filter(c=>c.kind==='void').length,1);
});
test('Guardian lost completion response cannot downgrade paid collection',async()=>{
  const f=await collectionFixture();let lost=true;
  const faulty=async(op,data)=>{const result=await collectionRpc(op,data);if(op==='paid'&&lost){lost=false;throw Error('paid_lost');}return result;};
  await assert.rejects(f.collector(faulty).run(f.invoice.id),/paid_lost/);
  assert.equal((await collectionRpc('get',{invoice_id:f.invoice.id})).status,'paid');assert.equal((await f.collector().run(f.invoice.id)).status,'paid');
  assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});
test('Guardian old monthly draft is skipped instead of collected as accumulated debt',async()=>{
  const f=await collectionFixture();f.invoice.created-=4*86400;f.invoice.lines.data[0].period.start-=4*86400;
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
});
test('Guardian period cannot be substituted after invoice binding',async()=>{
  const f=await collectionFixture();await f.prepare();f.invoice.lines.data[0].period.end++;
  await assert.rejects(f.collector().run(f.invoice.id),/period_changed/);assert.equal(f.calls.length,0);
});
test('Guardian collection leases and one-pay marker remain server-only',async()=>{
  const f=await collectionFixture(),j=await f.prepare();
  await rejected(()=>collectionRpc('authorize_pay',{invoice_id:j.invoice_id}),/vencido/);
  const claim=await collectionRpc('claim',{invoice_id:j.invoice_id});assert.equal(await collectionRpc('claim',{invoice_id:j.invoice_id}),null);
  await rejected(()=>collectionRpc('authorize_pay',{invoice_id:j.invoice_id,lease:crypto.randomUUID()}),/vencido/);
  assert.ok((await collectionRpc('authorize_pay',{invoice_id:j.invoice_id,lease:claim.lease})).pay_requested_at);
  assert.equal(await collectionRpc('authorize_pay',{invoice_id:j.invoice_id,lease:claim.lease}),null);
  for(const actor of [donor,staff,'']){await role(actor,actor?'authenticated':'anon');
    await rejected(()=>collectionRpc('sources'),/permission denied/);await rejected(()=>db.query('select * from private.dopmi_guardian_collection_jobs'),/permission denied/);}
});
test('Guardian retry exhaustion is read-only and late payment refunds expired capacity',async()=>{
  const f=await collectionFixture();await f.prepare();await db.exec('update private.dopmi_guardian_collection_jobs set attempts=8');
  assert.equal((await f.collector().run(f.invoice.id)).status,'attention');assert.equal(f.calls.length,0);
  Object.assign(f.invoice,{status:'paid',amount_paid:5000,amount_remaining:0,attempt_count:1,attempted:true});Object.assign(f.invoice.payments.data[0],{status:'paid',amount_paid:5000});
  await db.exec("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 minute' where status='reserved'");
  const j=await f.collector().run(f.invoice.id);assert.equal(j.status,'paid');assert.equal((await guardianSettlement('get',{cycle_id:j.cycle_id})).refund_cents,5000);
});
test('Guardian periodic discovery recovers missing webhook and duplicate event cannot charge twice',async()=>{
  const f=await collectionFixture();assert.equal((await f.collector().reconcile()).failed,0);
  f.stripe.events={retrieve:async()=>({livemode:false,type:'invoice.paid',data:{object:{id:f.invoice.id,customer:'untrusted'}}})};
  assert.equal((await f.collector().handleWebhook('evt_monthly')).guardian_collection,true);assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});

test('Guardian rejects a second invoice for the same monthly period atomically',async()=>{
  const f=await collectionFixture();await f.prepare();
  const count=(await db.query('select count(*)::int n from private.dopmi_guardian_cycles')).rows[0].n;
  await rejected(()=>collectionRpc('prepare',{invoice_id:'in_duplicate',subscription_id:f.subscription.id,cycle_key:crypto.randomUUID(),
    period_start:f.invoice.lines.data[0].period.start,period_end:f.invoice.lines.data[0].period.end,fresh:true}),/unique/);
  assert.equal((await db.query('select count(*)::int n from private.dopmi_guardian_cycles')).rows[0].n,count);
});
test('Guardian rescuer suspension between reservation and payment voids the invoice',async()=>{
  const f=await collectionFixture(),finalize=f.stripe.invoices.finalizeInvoice;
  f.stripe.invoices.finalizeInvoice=async(...args)=>{const result=await finalize(...args);await db.query("update public.profiles set account_status='suspended' where id=$1",[rescuer]);return result;};
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
});
test('Guardian declined or asynchronous payment remains attention without another pay or premature void',async()=>{
  const f=await collectionFixture();f.stripe.invoices.pay=async()=>{f.calls.push({kind:'pay'});f.invoice.attempt_count=1;f.invoice.attempted=true;throw Error('declined_or_pending');};
  await assert.rejects(f.collector().run(f.invoice.id),/declined_or_pending/);
  assert.equal((await f.collector().run(f.invoice.id)).status,'attention');assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
  assert.equal(f.calls.some(c=>c.kind==='void'),false);
});
test('Guardian invoice discovery persists pagination and advances fairness after a failed source',async()=>{
  const f=await collectionFixture();const calls=[];
  f.stripe.invoices.list=async fields=>{calls.push(fields);return {has_more:!fields.starting_after,data:[structuredClone(f.invoice)]};};
  assert.equal((await f.collector().reconcile()).failed,0);assert.equal((await collectionRpc('sources'))[0].cursor,f.invoice.id);
  assert.equal((await f.collector().reconcile()).failed,0);assert.equal(calls[1].starting_after,f.invoice.id);assert.equal((await collectionRpc('sources'))[0].cursor,null);
  f.stripe.invoices.list=async()=>{throw Error('network');};assert.equal((await f.collector().reconcile()).failed,1);
  assert.ok((await db.query("select collection_checked_at from private.dopmi_guardian_subscriptions")).rows[0].collection_checked_at);
});
test('Guardian test clock controls freshness and an advancing clock cannot authorize payment',async()=>{
  const f=await collectionFixture();f.stripe.customers.retrieve=async()=>({id:'cus_initial',livemode:false,balance:0,test_clock:'clock_collection'});
  f.stripe.testHelpers={testClocks:{retrieve:async()=>({id:'clock_collection',status:'advancing',frozen_time:f.invoice.created+1})}};
  await assert.rejects(f.collector().run(f.invoice.id),/clock_unavailable/);assert.equal(f.calls.length,0);
  f.stripe.testHelpers.testClocks.retrieve=async()=>({id:'clock_collection',status:'ready',frozen_time:f.invoice.created+4*86400});
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
});


test('Guardian customer balance or automatic tax cannot be consumed by finalization',async()=>{
  const f=await collectionFixture();f.invoice.automatic_tax.enabled=true;
  await assert.rejects(f.collector().run(f.invoice.id),/tax_changed/);assert.equal(f.calls.length,0);
  f.invoice.automatic_tax.enabled=false;await f.prepare();
  f.stripe.customers.retrieve=async()=>({id:'cus_initial',livemode:false,balance:-5000});
  await assert.rejects(f.collector().run(f.invoice.id),/customer_mismatch/);assert.equal(f.calls.length,0);
});

async function recoveryFixture(status='requires_payment_method') {
  const f=await collectionFixture();const normalIntent=f.stripe.paymentIntents.retrieve;
  const intent={id:'pi_guardianRenewal1',livemode:false,customer:'cus_initial',currency:'mxn',amount:5000,amount_received:0,amount_capturable:0,
    payment_method:'pm_initial',status,latest_charge:null};
  f.stripe.paymentIntents.retrieve=async()=>f.invoice.status==='paid'?normalIntent():structuredClone(intent);
  const voidInvoice=f.stripe.invoices.voidInvoice;
  f.stripe.invoices.voidInvoice=async(...args)=>{const value=await voidInvoice(...args);intent.status='canceled';return value;};
  f.stripe.invoices.pay=async()=>{f.calls.push({kind:'pay'});f.invoice.attempt_count=1;f.invoice.attempted=true;throw Error('payment_unresolved');};
  await assert.rejects(f.collector().run(f.invoice.id),/payment_unresolved/);await collectionDue();
  const markPaid=()=>{Object.assign(f.invoice,{status:'paid',amount_paid:5000,amount_remaining:0});Object.assign(f.invoice.payments.data[0],{status:'paid',amount_paid:5000});};
  return {...f,intent,markPaid};
}

test('Guardian declined invoice closes only after invoice, default payment and intent are canceled',async()=>{
  const f=await recoveryFixture();const j=await f.collector().run(f.invoice.id);
  assert.equal(j.status,'skipped');assert.equal(j.recovery_state,'voided');assert.equal(j.recovery_reason,'payment_failed');
  assert.ok(j.pay_requested_at);assert.equal(j.cycle_status,'released');assert.equal(f.invoice.amount_remaining,5000);
  assert.equal(f.invoice.payments.data[0].status,'canceled');assert.equal(f.intent.status,'canceled');
  await f.collector().run(f.invoice.id);assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);assert.equal(f.calls.filter(c=>c.kind==='void').length,1);
});
test('Guardian additional authentication closes without exposing a client secret or confirming payment',async()=>{
  const f=await recoveryFixture('requires_action');f.intent.client_secret='secret_test_only';
  const j=await f.collector().run(f.invoice.id);assert.equal(j.status,'skipped');assert.equal(j.recovery_reason,'authentication_required');
  assert.equal(JSON.stringify(j).includes('secret_test_only'),false);assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});
test('Guardian unconfirmed authorization is closed without a replacement payment',async()=>{
  const f=await recoveryFixture('requires_confirmation');const j=await f.collector().run(f.invoice.id);
  assert.equal(j.status,'skipped');assert.equal(j.recovery_reason,'not_attempted');assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});
test('Guardian processing payment stays pending and later settles once within the original hold',async()=>{
  const f=await recoveryFixture('processing');const j=await f.collector().run(f.invoice.id);
  assert.equal(j.status,'attention');assert.equal(j.recovery_state,'processing');assert.equal(j.cycle_status,'reserved');
  assert.equal(f.calls.some(c=>c.kind==='void'),false);f.markPaid();
  const paid=await f.collector().run(f.invoice.id);assert.equal(paid.status,'paid');assert.equal(paid.recovery_state,'succeeded');
  assert.equal((await guardianSettlement('get',{cycle_id:j.cycle_id})).allocated_cents,4314);assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});
test('Guardian asynchronous success after expiration refunds instead of consuming another hold',async()=>{
  const f=await recoveryFixture('processing');const j=await f.collector().run(f.invoice.id);
  await db.exec("update private.dopmi_guardian_cycles set expires_at=now()-interval '1 minute' where status='reserved'");f.markPaid();
  await f.collector().run(f.invoice.id);assert.equal((await guardianSettlement('get',{cycle_id:j.cycle_id})).refund_cents,5000);
  assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);assert.equal(f.calls.some(c=>c.kind==='void'),false);
});
test('Guardian succeeded intent with invoice still open waits for authoritative paid invoice',async()=>{
  const f=await recoveryFixture('succeeded');f.intent.amount_received=5000;
  const j=await f.collector().run(f.invoice.id);assert.equal(j.recovery_state,'succeeded');assert.equal(j.status,'attention');
  assert.equal(f.calls.some(c=>c.kind==='void'),false);f.markPaid();assert.equal((await f.collector().run(f.invoice.id)).status,'paid');
});
test('Guardian processing may later fail and closes without renewed payment',async()=>{
  const f=await recoveryFixture('processing');await f.collector().run(f.invoice.id);await collectionDue();f.intent.status='requires_payment_method';
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});
test('Guardian unexpected capture state remains unresolved with no mutation',async()=>{
  const f=await recoveryFixture('requires_capture');f.intent.amount_capturable=5000;
  const j=await f.collector().run(f.invoice.id);assert.equal(j.recovery_state,'unknown');assert.equal(j.status,'attention');
  assert.equal(f.calls.some(c=>c.kind==='void'),false);
});
for(const [name,mutate] of [
  ['foreign invoice',f=>{f.invoice.payments.data[0].invoice='in_foreign';}],
  ['live payment',f=>{f.invoice.payments.data[0].livemode=true;}],
  ['nondefault payment',f=>{f.invoice.payments.data[0].is_default=false;}],
  ['multiple payments',f=>{f.invoice.payments.data.push({...f.invoice.payments.data[0],id:'inpay_second'});}],
  ['partial payment',f=>{f.invoice.payments.data[0].amount_paid=100;}],
  ['incomplete pagination',f=>{f.invoice.payments.has_more=true;}],
  ['foreign customer',f=>{f.intent.customer='cus_foreign';}],
  ['received money',f=>{f.intent.amount_received=100;}],
  ['paid charge',f=>{f.intent.latest_charge={id:'ch_wrong',paid:true};}],
]) test(`Guardian recovery rejects ${name} without voiding`,async()=>{
  const f=await recoveryFixture();mutate(f);await assert.rejects(f.collector().run(f.invoice.id),/guardian_recovery/);
  assert.equal(f.calls.some(c=>c.kind==='void'),false);assert.equal((await collectionRpc('get',{invoice_id:f.invoice.id})).status,'attention');
});
test('Guardian lost cancellation response recovers terminal Stripe state without another void',async()=>{
  const f=await recoveryFixture(),cancel=f.stripe.invoices.voidInvoice;
  f.stripe.invoices.voidInvoice=async(...args)=>{await cancel(...args);throw Error('void_response_lost');};
  await assert.rejects(f.collector().run(f.invoice.id),/void_response_lost/);await collectionDue();
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.filter(c=>c.kind==='void').length,1);
});
test('Guardian lost recovery completion response cannot reopen a skipped invoice',async()=>{
  const f=await recoveryFixture();let lose=true;
  const faulty=async(op,data)=>{const result=await recoveryRpc(op,data);if(op==='voided'&&lose){lose=false;throw Error('completion_lost');}return result;};
  await assert.rejects(f.collector(collectionRpc,faulty).run(f.invoice.id),/completion_lost/);
  assert.equal((await collectionRpc('get',{invoice_id:f.invoice.id})).status,'skipped');assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');
});
test('Guardian processing race after cancel authorization prevents the void write',async()=>{
  const f=await recoveryFixture();const read=f.stripe.paymentIntents.retrieve;let reads=0;
  f.stripe.paymentIntents.retrieve=async(...args)=>{if(++reads===2)f.intent.status='processing';return read(...args);};
  const j=await f.collector().run(f.invoice.id);assert.equal(j.recovery_state,'processing');assert.equal(f.calls.some(c=>c.kind==='void'),false);
});
test('Guardian payment winning the void race is reconciled without marking it skipped',async()=>{
  const f=await recoveryFixture();f.stripe.invoices.voidInvoice=async()=>{f.markPaid();throw Error('invoice_already_paid');};
  await assert.rejects(f.collector().run(f.invoice.id),/invoice_already_paid/);
  assert.equal((await f.collector().run(f.invoice.id)).status,'paid');assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});
test('Guardian void invoice with an uncanceled intent never releases a reservation',async()=>{
  const f=await recoveryFixture();f.stripe.invoices.voidInvoice=async()=>{f.invoice.status='void';f.invoice.payments.data[0].status='canceled';return f.invoice;};
  await assert.rejects(f.collector().run(f.invoice.id),/void_unconfirmed/);
  const j=await collectionRpc('get',{invoice_id:f.invoice.id});assert.equal(j.status,'attention');assert.equal(j.cycle_status,'reserved');
});
test('Guardian recovery retry budget limits writes but permits later terminal reads',async()=>{
  const f=await recoveryFixture();await db.exec('update private.dopmi_guardian_collection_jobs set recovery_attempts=8');
  const j=await f.collector().run(f.invoice.id);assert.equal(j.error_code,'recovery_retry_limit');assert.equal(f.calls.some(c=>c.kind==='void'),false);
  f.invoice.status='void';f.invoice.payments.data[0].status='canceled';f.intent.status='canceled';await collectionDue();
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');
});
test('Guardian only closes after immutable recovery linkage and complete cancellation evidence',async()=>{
  const f=await recoveryFixture(),claim=await recoveryRpc('claim',{invoice_id:f.invoice.id});
  assert.equal(await recoveryRpc('claim',{invoice_id:f.invoice.id}),null);
  await rejected(()=>recoveryRpc('authorize_void',{invoice_id:f.invoice.id,lease:claim.lease}),/cancelable/);
  await rejected(()=>recoveryRpc('observe',{invoice_id:f.invoice.id,lease:crypto.randomUUID(),state:'canceled',intent_id:f.intent.id,invoice_payment_id:'inpay_guardian1'}),/vencido/);
  await recoveryRpc('observe',{invoice_id:f.invoice.id,lease:claim.lease,state:'processing',intent_id:f.intent.id,invoice_payment_id:'inpay_guardian1'});
  await rejected(()=>recoveryRpc('authorize_void',{invoice_id:f.invoice.id,lease:claim.lease}),/cancelable/);
  await rejected(()=>recoveryRpc('observe',{invoice_id:f.invoice.id,lease:claim.lease,state:'canceled',intent_id:'pi_different',invoice_payment_id:'inpay_guardian1'}),/no coincide/);
  await rejected(()=>recoveryRpc('voided',{invoice_id:f.invoice.id,lease:claim.lease}),/no confirmada/);
});
test('Guardian recovery remains unavailable to clients and administrators',async()=>{
  const f=await recoveryFixture();for(const actor of [donor,staff,'']){await role(actor,actor?'authenticated':'anon');
    await rejected(()=>recoveryRpc('get',{invoice_id:f.invoice.id}),/permission denied/);}
  await role('','service_role');assert.equal((await recoveryRpc('get',{invoice_id:f.invoice.id})).invoice_id,f.invoice.id);
});
test('Guardian cancellation recovery unblocks the next month without clearing payment history',async()=>{
  const f=await recoveryFixture();const closed=await f.collector().run(f.invoice.id);
  const next=await collectionRpc('prepare',{invoice_id:'in_nextMonthly',subscription_id:'sub_schedule1',cycle_key:crypto.randomUUID(),
    period_start:f.invoice.lines.data[0].period.end,period_end:f.invoice.lines.data[0].period.end+30*86400,fresh:true});
  assert.equal(next.status,'pending');assert.notEqual(next.cycle_id,closed.cycle_id);
  assert.ok((await collectionRpc('get',{invoice_id:f.invoice.id})).pay_requested_at);
});
test('Guardian authentication webhook uses fresh invoice evidence before closing the cycle',async()=>{
  const f=await recoveryFixture('requires_action');f.stripe.events={retrieve:async()=>({livemode:false,type:'invoice.payment_action_required',data:{object:{id:f.invoice.id}}})};
  assert.equal((await f.collector().handleWebhook('evt_action')).guardian_collection,true);assert.equal((await collectionRpc('get',{invoice_id:f.invoice.id})).status,'skipped');
});
test('Guardian processing webhook is acknowledged without scheduling another charge',async()=>{
  const f=await recoveryFixture('processing');f.stripe.events={retrieve:async()=>({livemode:false,type:'invoice.payment_failed',data:{object:{id:f.invoice.id}}})};
  assert.equal((await f.collector().handleWebhook('evt_processing')).received,true);f.markPaid();
  f.stripe.events.retrieve=async()=>({livemode:false,type:'invoice_payment.paid',data:{object:{id:'inpay_guardian1',invoice:f.invoice.id}}});
  assert.equal((await f.collector().handleWebhook('evt_paid')).received,true);assert.equal((await collectionRpc('get',{invoice_id:f.invoice.id})).status,'paid');
});

test('Guardian a verified failed charge permits cancellation while preserving the original intent',async()=>{
  const f=await recoveryFixture();f.intent.latest_charge={id:'ch_declined',livemode:false,payment_intent:f.intent.id,customer:'cus_initial',currency:'mxn',amount:5000,paid:false,status:'failed'};
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});


test('Guardian recovery can close an overdue subscription without granting payment authority',async()=>{
  const f=await recoveryFixture();f.subscription.status='past_due';
  assert.equal((await f.collector().run(f.invoice.id)).status,'skipped');assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
});

const ownerPlan=async()=>(await db.query('select public.dopmi_guardian_plan() as value')).rows[0].value;
const requestKey='75000000-0000-4000-8000-000000000001';
const nextRequestKey='75000000-0000-4000-8000-000000000002';
const ownerRequest=async(kind='amount',revision=0,gross=20000,requestId=requestKey,consent='guardian-2026-09-24')=>
  (await db.query('select public.dopmi_guardian_request($1,$2::uuid,$3::bigint,$4::bigint,$5) as value',
    [kind,requestId,revision,gross,consent])).rows[0].value;
const ownerCancel=(revision=0,requestId=requestKey)=>ownerRequest('cancel',revision,null,requestId,null);

test('Guardian owner reads only their safe plan projection; staff do not inherit ownership',async()=>{
  await collectionFixture();
  for(const actor of [other,staff]){await role(actor);assert.equal(await ownerPlan(),null);
    await rejected(()=>ownerCancel(),/No tienes un plan/);await db.exec('reset role');}
  await role(donor);const p=await ownerPlan();assert.equal(p.gross_cents,5000);assert.equal(p.revision,0);
  assert.deepEqual(p.requests,[]);assert.equal(p.pending_request,null);assert.equal(p.payment_in_flight,false);
  assert.deepEqual(Object.keys(p).sort(),['cancellation_requested_at','currency','gross_cents','payment_in_flight','pending_request','requests','revision','status']);
  assert.doesNotMatch(JSON.stringify(p),/cus_|sub_|price_|pi_|lease|secret/);
});
test('Guardian amount intent records consent without changing price or the current allocation',async()=>{
  const f=await collectionFixture();const before=await guardianSettlement('get',{cycle_id:f.calendar.cycleId});
  await role(donor);const result=await ownerRequest();assert.equal(result.request.kind,'amount');
  assert.equal(result.request.status,'pending');assert.equal(result.request.new_gross_cents,20000);
  assert.equal(result.plan.gross_cents,5000);assert.equal(result.plan.revision,1);await db.exec('reset role');
  const p=await guardianRegistry('lookup',{stripe_subscription_id:'sub_schedule1'});assert.equal(p.gross_cents,5000);assert.equal(p.stripe_price_id,'price_schedule1');
  assert.deepEqual(await guardianSettlement('get',{cycle_id:f.calendar.cycleId}),before);
  assert.equal((await db.query('select consent_version from private.dopmi_guardian_requests')).rows[0].consent_version,'guardian-2026-09-24');
  assert.equal(f.calls.some(c=>c.kind==='pay'),false);
});
test('Guardian identical owner request after a lost response returns one intent and one revision',async()=>{
  await collectionFixture();await role(donor);const first=await ownerRequest();
  assert.deepEqual(await ownerRequest(),first);assert.equal((await ownerPlan()).requests.length,1);
  await rejected(()=>ownerRequest('amount',0,50000),/ya se usó con otros datos/);
  await rejected(()=>ownerRequest('amount',1,20000),/ya se usó con otros datos/);
  await rejected(()=>ownerCancel(),/ya se usó con otros datos/);
});
test('Guardian stale devices cannot overwrite a pending amount request',async()=>{
  await collectionFixture();await role(donor);await ownerRequest();
  await rejected(()=>ownerRequest('amount',0,50000,nextRequestKey),/Tu plan cambió/);
  await rejected(()=>ownerRequest('amount',1,50000,nextRequestKey),/solicitud pendiente/);
  assert.equal((await ownerPlan()).revision,1);
});
test('Guardian cancellation supersedes an unprocessed amount intent and preserves its audit',async()=>{
  await collectionFixture();await role(donor);const amount=await ownerRequest();const cancel=await ownerCancel(1,nextRequestKey);
  assert.equal(cancel.plan.status,'cancel_requested');assert.equal(cancel.plan.revision,2);assert.ok(cancel.plan.cancellation_requested_at);
  assert.equal(cancel.request.status,'pending');assert.equal(cancel.request.kind,'cancel');
  assert.deepEqual(cancel.plan.requests.map(r=>[r.kind,r.status]),[['cancel','pending'],['amount','superseded']]);
  const replay=await ownerRequest();assert.equal(replay.request.id,amount.request.id);assert.equal(replay.request.status,'superseded');
  assert.equal(replay.plan.revision,2);assert.equal((await ownerCancel(1,nextRequestKey)).request.id,cancel.request.id);
  await rejected(()=>ownerRequest('amount',2,50000,'75000000-0000-4000-8000-000000000003'),/cancelación pendiente/);
});
for(const [label,kind,gross,consent] of [['missing consent','amount',20000,null],['old consent','amount',20000,'old'],
  ['too small','amount',999,'guardian-2026-09-24'],['too large','amount',1000001,'guardian-2026-09-24'],
  ['missing amount','amount',null,'guardian-2026-09-24'],['cancel with amount','cancel',5000,null],['unsupported action','apply',null,null]]){
  test(`Guardian owner request rejects ${label}`,async()=>{
    await collectionFixture();await role(donor);await rejected(()=>ownerRequest(kind,0,gross,requestKey,consent),/Solicitud Guardián inválida/);
    assert.equal((await ownerPlan()).revision,0);assert.deepEqual((await ownerPlan()).requests,[]);
  });
}
test('Guardian no-op amount and missing revision cannot create owner intents',async()=>{
  await collectionFixture();await role(donor);await rejected(()=>ownerRequest('amount',0,5000),/debe ser diferente/);
  await rejected(()=>ownerRequest('amount',null,20000),/Solicitud Guardián inválida/);
  await rejected(()=>ownerRequest('amount',0,20000,null),/Solicitud Guardián inválida/);
});
for(const [label,sql] of [['suspended',`update public.profiles set account_status='suspended' where id='${donor}'`],
  ['unconfirmed',`update auth.users set email_confirmed_at=null where id='${donor}'`]]){
  test(`Guardian ${label} owner may cancel but cannot expand payment authorization`,async()=>{
    await collectionFixture();await db.exec(sql);await role(donor);
    await rejected(()=>ownerRequest(),/Cuenta activa y confirmada requerida/);
    assert.equal((await ownerCancel()).plan.status,'cancel_requested');
  });
}
test('Guardian owner endpoints require a session and private intent writes remain denied',async()=>{
  await collectionFixture();
  for(const name of ['anon','service_role']){await role('',name);await rejected(()=>ownerPlan(),/permission denied/);
    await rejected(()=>ownerCancel(),/permission denied/);await db.exec('reset role');}
  await role('');await rejected(()=>ownerPlan(),/Inicia sesión/);await rejected(()=>ownerCancel(),/Inicia sesión/);await db.exec('reset role');
  for(const actor of [donor,staff]){await role(actor);
    await rejected(()=>db.exec('select * from private.dopmi_guardian_requests'),/permission denied/);
    await rejected(()=>db.exec("update private.dopmi_guardian_requests set status='applied',applied_at=now()"),/permission denied/);
    await rejected(()=>db.query('select private.dopmi_guardian_plan_view($1)',[donor]),/permission denied/);await db.exec('reset role');}
});
test('Guardian a pending change blocks discovery and fresh reservations even from stale source reads',async()=>{
  const f=await collectionFixture();assert.ok(await collectionRpc('source',{subscription_id:'sub_schedule1'}));
  await role(donor);await ownerRequest();await db.exec('reset role');
  assert.equal(await collectionRpc('source',{subscription_id:'sub_schedule1'}),null);assert.deepEqual(await collectionRpc('sources'),[]);
  await rejected(()=>f.prepare(),/Solicitud Guardián pendiente/);
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_collection_jobs')).rows[0].n,0);
});
test('Guardian cancellation that wins before pay authorization releases the hold without a charge',async()=>{
  const f=await collectionFixture();const j=await f.prepare();const claim=await collectionRpc('claim',{invoice_id:j.invoice_id});
  await role(donor);assert.equal((await ownerCancel()).plan.payment_in_flight,false);await db.exec('reset role');
  const stopped=await collectionRpc('authorize_pay',{invoice_id:j.invoice_id,lease:claim.lease});
  assert.equal(stopped.pay_requested_at,null);assert.equal(stopped.decision,'skip');assert.equal(stopped.cycle_status,'released');
  await db.exec("update private.dopmi_guardian_collection_jobs set lease_until=null,available_at=now()");
  assert.equal((await f.collector().run(j.invoice_id)).status,'skipped');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
  assert.equal(f.invoice.status,'void');
});
test('Guardian a payment authorized before cancellation still reconciles once and preserves delivered funds',async()=>{
  const f=await collectionFixture();const wrapped=async(op,data)=>{
    const result=await collectionRpc(op,data);
    if(op==='authorize_pay'){await role(donor);const canceled=await ownerCancel();
      assert.equal(canceled.plan.payment_in_flight,true);await db.exec('reset role');}
    return result;
  };
  const j=await f.collector(wrapped).run(f.invoice.id);assert.equal(j.status,'paid');assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
  assert.equal((await guardianSettlement('get',{cycle_id:j.cycle_id})).allocated_cents,4314);
  await role(donor);const p=await ownerPlan();assert.equal(p.status,'cancel_requested');assert.equal(p.payment_in_flight,false);
  assert.equal(p.gross_cents,5000);
});
test('Guardian amount intent preserves a prepared current cycle while stopping new cycle preparation',async()=>{
  const f=await collectionFixture();const j=await f.prepare();await role(donor);await ownerRequest();await db.exec('reset role');
  assert.equal((await f.collector().run(j.invoice_id)).status,'paid');assert.equal(f.calls.filter(c=>c.kind==='pay').length,1);
  f.invoice.id='in_afterRequest';f.invoice.lines.data[0].period.start++;
  await rejected(()=>f.prepare(),/Solicitud Guardián pendiente/);
  assert.equal((await collectionRpc('get',{invoice_id:j.invoice_id})).gross_cents,5000);
});
test('Guardian canceled registry remains readable but cannot accept a fresh owner request',async()=>{
  await collectionFixture();await guardianRegistry('cancel',{donor_id:donor,stripe_subscription_id:'sub_schedule1'});
  await role(donor);assert.equal((await ownerPlan()).status,'canceled');
  await rejected(()=>ownerCancel(),/ya está cancelado/);await rejected(()=>ownerRequest(),/ya está cancelado/);
});

const { guardianChangeService }=await import('../../supabase/functions/_shared/guardian-changes.mjs');
const changeRpc=async(operation,data={})=>(await db.query('select public.dopmi_guardian_change_server($1,$2::jsonb) as value',[operation,JSON.stringify(data)])).rows[0].value;
const changeDue=()=>db.exec('update private.dopmi_guardian_requests set available_at=now()');
async function changeFixture() {
  const f=await collectionFixture(),sub=f.subscription,item=sub.items.data[0],calls=[];
  Object.assign(item,{id:'si_change1',current_period_start:f.calendar.charge.created,tax_rates:[],discounts:[]});
  sub.billing_cycle_anchor=item.current_period_end;
  const prices=new Map([['price_schedule1',structuredClone([...f.calendar.prices.values()][0])]]),writes=new Map();
  f.stripe.prices={retrieve:async priceId=>structuredClone(prices.get(priceId)),create:async(fields,options)=>{
    calls.push({kind:'price',fields:structuredClone(fields),options});
    if(!writes.has(options.idempotencyKey)){
      const price={id:`price_change${prices.size}`,livemode:false,active:true,billing_scheme:'per_unit',...fields,
        recurring:{...fields.recurring,usage_type:'licensed'}};
      prices.set(price.id,price);writes.set(options.idempotencyKey,price);
    }
    return structuredClone(writes.get(options.idempotencyKey));
  }};
  f.stripe.subscriptions.update=async(subscriptionId,fields,options)=>{
    calls.push({kind:'update',subscriptionId,fields:structuredClone(fields),options});
    if(sub.status==='canceled')throw Error('subscription_canceled');
    if(!writes.has(options.idempotencyKey)){
      item.price={id:fields.items[0].price};writes.set(options.idempotencyKey,structuredClone(sub));
    }
    return structuredClone(writes.get(options.idempotencyKey));
  };
  f.stripe.subscriptions.cancel=async(subscriptionId,fields,options)=>{
    calls.push({kind:'cancel',subscriptionId,fields:structuredClone(fields),options});
    sub.status='canceled';sub.cancel_at_period_end=false;sub.cancel_at=null;return structuredClone(sub);
  };
  const request=async(kind='amount',revision=0,gross=20000,requestId=requestKey)=>{
    await role(donor);const r=kind==='cancel'?await ownerCancel(revision,requestId):await ownerRequest(kind,revision,gross,requestId);
    await db.exec('reset role');return r.request.id;
  };
  const manager=(override=changeRpc)=>guardianChangeService({stripe:f.stripe,rpc:override,logger:{}});
  return {...f,item,changeCalls:calls,changePrices:prices,request,manager};
}

test('Guardian amount application keeps pause and calendar, disables proration and records the next-period price',async()=>{
  const f=await changeFixture(),requestId=await f.request();const anchor=f.subscription.billing_cycle_anchor,end=f.item.current_period_end;
  const done=await f.manager().run(requestId);assert.equal(done.status,'applied');assert.equal(done.effective_from,end);
  assert.equal(f.changeCalls.filter(c=>c.kind==='price').length,1);assert.equal(f.changeCalls.filter(c=>c.kind==='update').length,1);
  assert.deepEqual(f.changeCalls.find(c=>c.kind==='update').fields,{items:[{id:'si_change1',price:'price_change1',quantity:1}],billing_cycle_anchor:'unchanged',proration_behavior:'none'});
  assert.equal(f.subscription.billing_cycle_anchor,anchor);assert.equal(f.subscription.latest_invoice,null);
  assert.equal(f.subscription.pause_collection.behavior,'keep_as_draft');assert.equal(f.calls.some(c=>c.kind==='pay'),false);
  assert.equal((await guardianRegistry('lookup',{stripe_subscription_id:f.subscription.id})).gross_cents,20000);
  const prices=(await db.query('select revision,effective_from,gross_cents from private.dopmi_guardian_prices order by revision')).rows;
  assert.deepEqual(prices.map(p=>[Number(p.revision),Number(p.effective_from),Number(p.gross_cents)]),[[0,1,5000],[1,end,20000]]);
  await role(donor);const plan=await ownerPlan();assert.equal(plan.pending_request,null);assert.ok(plan.requests[0].effective_at);await db.exec('reset role');
  await f.manager().run(requestId);assert.equal(f.changeCalls.length,2);
});
test('Guardian current-period invoice discovered after a price change retains its old authorized amount',async()=>{
  const f=await changeFixture(),requestId=await f.request('amount',0,1000);await f.manager().run(requestId);
  const current=await f.collector().run(f.invoice.id);assert.equal(current.status,'paid');assert.equal(current.gross_cents,5000);assert.equal(current.price_id,'price_schedule1');
  assert.equal((await guardianSettlement('get',{cycle_id:current.cycle_id})).allocated_cents,4314);
  const next=await collectionRpc('prepare',{invoice_id:'in_nextPrice',subscription_id:f.subscription.id,cycle_key:nextRequestKey,
    period_start:f.item.current_period_end,period_end:f.item.current_period_end+30*86400,fresh:true});
  assert.equal(next.gross_cents,1000);assert.equal(next.price_id,'price_change1');
});
test('Guardian an old bound invoice reconciles after its subscription changes price and is canceled',async()=>{
  const f=await changeFixture();const old=await f.prepare();const requestId=await f.request('amount',0,1000);await f.manager().run(requestId);
  const cancelId=await f.request('cancel',1,null,nextRequestKey);await f.manager().run(cancelId);
  await f.stripe.invoices.pay(f.invoice.id,{},{});
  const settled=await f.service().reconcileInvoice(f.invoice.id);assert.equal(settled.gross_cents,5000);assert.equal(settled.allocated_cents,4314);
  assert.equal((await guardianSettlement('lookup_invoice',{invoice_id:old.invoice_id})).price_id,'price_schedule1');
});
test('Guardian paid invoice cannot substitute a different period for its stored snapshot',async()=>{
  const f=await changeFixture();await f.prepare();await f.stripe.invoices.pay(f.invoice.id,{},{});f.invoice.lines.data[0].period.start++;
  await assert.rejects(()=>f.service().reconcileInvoice(f.invoice.id),/snapshot_mismatch/);
});
test('Guardian successive amount changes before renewal retain history and choose the newest authorized price',async()=>{
  const f=await changeFixture();await f.manager().run(await f.request('amount',0,1000));
  await f.manager().run(await f.request('amount',1,2000,nextRequestKey));
  const source=await collectionRpc('source',{subscription_id:f.subscription.id,period_start:f.item.current_period_end});
  assert.equal(source.gross_cents,2000);assert.equal(source.stripe_price_id,'price_change2');
  const old=await collectionRpc('source',{subscription_id:f.subscription.id,period_start:f.item.current_period_end-1});
  assert.equal(old.gross_cents,5000);assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_prices')).rows[0].n,3);
});
test('Guardian lost price creation response reuses one idempotency key and one price',async()=>{
  const f=await changeFixture(),requestId=await f.request(),create=f.stripe.prices.create;let lost=true;
  f.stripe.prices.create=async(...args)=>{const r=await create(...args);if(lost){lost=false;throw Error('price_lost');}return r;};
  await assert.rejects(()=>f.manager().run(requestId),/price_lost/);await changeDue();
  assert.equal((await f.manager().run(requestId)).status,'applied');assert.equal(f.changePrices.size,2);
  const calls=f.changeCalls.filter(c=>c.kind==='price');assert.equal(calls.length,2);assert.deepEqual(calls[0].options,calls[1].options);
});
test('Guardian lost subscription update response is recovered by reading without a second update',async()=>{
  const f=await changeFixture(),requestId=await f.request(),update=f.stripe.subscriptions.update;
  f.stripe.subscriptions.update=async(...args)=>{await update(...args);throw Error('update_lost');};
  await assert.rejects(()=>f.manager().run(requestId),/update_lost/);await changeDue();
  const recovered=await f.manager().run(requestId);assert.equal(recovered.status,'applied');assert.equal(recovered.attempts,1);
  assert.equal(f.changeCalls.filter(c=>c.kind==='update').length,1);
});
test('Guardian lost database completion cannot reopen an applied change',async()=>{
  const f=await changeFixture(),requestId=await f.request();let lost=true;
  const faulty=async(op,data)=>{const r=await changeRpc(op,data);if(op==='applied'&&lost){lost=false;throw Error('completion_lost');}return r;};
  await assert.rejects(()=>f.manager(faulty).run(requestId),/completion_lost/);
  assert.equal((await f.manager().run(requestId)).status,'applied');assert.equal(f.changeCalls.length,2);
});
test('Guardian lost mutation checkpoint recovers the fixed request without changing its calendar',async()=>{
  const f=await changeFixture(),requestId=await f.request();let lost=true;
  const faulty=async(op,data)=>{const r=await changeRpc(op,data);if(op==='mutation'&&lost){lost=false;throw Error('mutation_lost');}return r;};
  await assert.rejects(()=>f.manager(faulty).run(requestId),/mutation_lost/);assert.equal(f.changeCalls.some(c=>c.kind==='update'),false);
  const before=await changeRpc('get',{request_id:requestId});await changeDue();const after=await f.manager().run(requestId);
  assert.equal(after.effective_from,before.effective_from);assert.equal(after.status,'applied');assert.equal(f.changeCalls.filter(c=>c.kind==='update').length,1);
});
test('Guardian amount write near renewal waits for review without mutating Stripe',async()=>{
  const f=await changeFixture(),requestId=await f.request();f.stripe.customers.retrieve=async()=>({id:'cus_initial',livemode:false,balance:0,test_clock:'clock_change'});
  f.stripe.testHelpers={testClocks:{retrieve:async()=>({id:'clock_change',status:'ready',frozen_time:f.item.current_period_end-60})}};
  await assert.rejects(()=>f.manager().run(requestId),/change_too_late/);assert.equal(f.changeCalls.length,0);
  assert.equal((await changeRpc('get',{request_id:requestId})).status,'pending');
});
test('Guardian calendar advancing after mutation authorization prevents a late price write',async()=>{
  const f=await changeFixture(),requestId=await f.request();const original=f.item.current_period_end;
  const wrapped=async(op,data)=>{const result=await changeRpc(op,data);if(op==='mutation'){f.item.current_period_start=original;f.item.current_period_end=original+30*86400;}return result;};
  await assert.rejects(()=>f.manager(wrapped).run(requestId),/calendar_changed/);assert.equal(f.changeCalls.some(c=>c.kind==='update'),false);
});
test('Guardian applied price can be recovered after renewal and retry expiry using read-only evidence',async()=>{
  const f=await changeFixture(),requestId=await f.request(),update=f.stripe.subscriptions.update;
  f.stripe.subscriptions.update=async(...args)=>{await update(...args);throw Error('update_lost');};
  await assert.rejects(()=>f.manager().run(requestId),/update_lost/);const saved=await changeRpc('get',{request_id:requestId});
  f.item.current_period_start=f.item.current_period_end;f.item.current_period_end+=30*86400;f.subscription.latest_invoice='in_later';
  await db.exec("update private.dopmi_guardian_requests set attempts=8,first_attempt_at=now()-interval '2 days',available_at=now()");
  const recovered=await f.manager().run(requestId);assert.equal(recovered.status,'applied');assert.equal(recovered.effective_from,saved.effective_from);
  assert.equal(f.changeCalls.filter(c=>c.kind==='update').length,1);
});
test('Guardian bounded change retries stop writes but leave the payment barrier in place',async()=>{
  const f=await changeFixture(),requestId=await f.request();await db.exec('update private.dopmi_guardian_requests set attempts=8');
  const j=await f.manager().run(requestId);assert.equal(j.error_code,'change_retry_limit');assert.equal(j.status,'pending');assert.equal(f.changeCalls.length,0);
  assert.deepEqual(await collectionRpc('sources'),[]);
});
test('Guardian cancellation is independently confirmed without proration, invoice or refund',async()=>{
  const f=await changeFixture(),requestId=await f.request('cancel');const before=await guardianSettlement('get',{cycle_id:f.calendar.cycleId});
  const j=await f.manager().run(requestId);assert.equal(j.status,'applied');assert.deepEqual(f.changeCalls[0].fields,{invoice_now:false,prorate:false});
  assert.equal(f.changeCalls.length,1);assert.equal(f.subscription.latest_invoice,null);assert.equal(j.plan_status,'canceled');
  assert.deepEqual(await guardianSettlement('get',{cycle_id:f.calendar.cycleId}),before);
  await role(donor);assert.equal((await ownerPlan()).status,'canceled');
});
test('Guardian cancellation can stop an externally changed configuration instead of demanding another charge',async()=>{
  const f=await changeFixture(),requestId=await f.request('cancel');f.subscription.pause_collection=null;f.subscription.collection_method='charge_automatically';
  assert.equal((await f.manager().run(requestId)).status,'applied');assert.equal(f.changeCalls[0].kind,'cancel');
});
test('Guardian lost cancellation response is reconciled without sending cancellation twice',async()=>{
  const f=await changeFixture(),requestId=await f.request('cancel'),cancel=f.stripe.subscriptions.cancel;
  f.stripe.subscriptions.cancel=async(...args)=>{await cancel(...args);throw Error('cancel_lost');};
  await assert.rejects(()=>f.manager().run(requestId),/cancel_lost/);await changeDue();
  assert.equal((await f.manager().run(requestId)).status,'applied');assert.equal(f.changeCalls.length,1);
});
test('Guardian an unconfirmed cancellation reply leaves the plan pending and never claims Stripe canceled',async()=>{
  const f=await changeFixture(),requestId=await f.request('cancel');f.stripe.subscriptions.cancel=async()=>({...f.subscription,status:'canceled'});
  await assert.rejects(()=>f.manager().run(requestId),/cancel_unconfirmed/);
  assert.equal((await changeRpc('get',{request_id:requestId})).plan_status,'active');
  await role(donor);assert.equal((await ownerPlan()).status,'cancel_requested');
});
test('Guardian cancellation during price creation supersedes the change before subscription mutation',async()=>{
  const f=await changeFixture(),requestId=await f.request(),create=f.stripe.prices.create;let cancellation;
  f.stripe.prices.create=async(...args)=>{const p=await create(...args);cancellation=await f.request('cancel',1,null,nextRequestKey);return p;};
  assert.equal((await f.manager().run(requestId)).status,'superseded');assert.equal(f.changeCalls.some(c=>c.kind==='update'),false);
  assert.equal((await f.manager().run(cancellation)).status,'applied');assert.equal(f.subscription.status,'canceled');
});
test('Guardian cancellation wins after an already authorized amount write without reviving the plan',async()=>{
  const f=await changeFixture(),requestId=await f.request(),update=f.stripe.subscriptions.update;let cancellation;
  f.stripe.subscriptions.update=async(...args)=>{cancellation=await f.request('cancel',1,null,nextRequestKey);return update(...args);};
  assert.equal((await f.manager().run(requestId)).status,'superseded');assert.equal(f.item.price.id,'price_change1');
  assert.equal((await f.manager().run(cancellation)).status,'applied');assert.equal(f.subscription.status,'canceled');
  assert.equal((await guardianRegistry('lookup',{stripe_subscription_id:f.subscription.id})).gross_cents,5000);
  assert.equal((await db.query('select count(*)::int as n from private.dopmi_guardian_prices')).rows[0].n,1);
});
test('Guardian an external cancellation supersedes an amount request using a fresh read',async()=>{
  const f=await changeFixture(),requestId=await f.request();f.subscription.status='canceled';
  const j=await f.manager().run(requestId);assert.equal(j.status,'superseded');assert.equal(j.plan_status,'canceled');assert.equal(f.changeCalls.length,0);
});
for(const [label,mutate] of [['foreign customer',s=>s.customer='cus_foreign'],['live subscription',s=>s.livemode=true],
  ['automatic collection',s=>s.collection_method='charge_automatically'],['tax',s=>s.automatic_tax.enabled=true],
  ['pause expiration',s=>s.pause_collection.resumes_at=1900000000],['extra item',s=>s.items.data.push(structuredClone(s.items.data[0]))],
  ['item tax',s=>s.items.data[0].tax_rates=['txr_other']],['another method',s=>s.default_payment_method='pm_other'],
  ['scheduled cancellation',s=>s.cancel_at_period_end=true]]){
  test(`Guardian amount processing rejects ${label} before Stripe writes`,async()=>{
    const f=await changeFixture(),requestId=await f.request();mutate(f.subscription);
    await assert.rejects(()=>f.manager().run(requestId),/change_subscription/);assert.equal(f.changeCalls.length,0);
  });
}
test('Guardian processing RPC and price history are inaccessible to clients including staff',async()=>{
  const f=await changeFixture(),requestId=await f.request();
  for(const actor of [donor,other,staff]){await role(actor);
    await rejected(()=>changeRpc('claim',{request_id:requestId}),/permission denied/);
    await rejected(()=>db.exec('select * from private.dopmi_guardian_prices'),/permission denied/);await db.exec('reset role');}
  await role('','service_role');assert.equal((await changeRpc('get',{request_id:requestId})).id,requestId);
});
test('Guardian expired processing lease cannot write and a replacement lease remains exclusive',async()=>{
  const f=await changeFixture(),requestId=await f.request();const a=await changeRpc('claim',{request_id:requestId});
  assert.equal(await changeRpc('claim',{request_id:requestId}),null);
  await db.exec("update private.dopmi_guardian_subscriptions set change_lease_until=now()-interval '1 second'");
  const b=await changeRpc('claim',{request_id:requestId});assert.notEqual(a.lease,b.lease);
  await rejected(()=>changeRpc('write',{request_id:requestId,lease:a.lease}),/Turno de cambio/);
});
test('Guardian schedule monitoring defers an owned pending change and accepts its verified replacement price',async()=>{
  const f=await changeFixture(),requestId=await f.request();
  f.stripe.events={retrieve:async()=>({livemode:false,type:'customer.subscription.updated',data:{object:{id:f.subscription.id}}})};
  await f.calendar.scheduler().handleWebhook('evt_change');assert.equal((await scheduleRpc('get',{cycle_id:f.calendar.cycleId})).status,'ready');
  assert.deepEqual(await f.manager().handleWebhook('evt_change'),{received:true,guardian_change:true});
  assert.equal((await changeRpc('get',{request_id:requestId})).status,'applied');
  await f.calendar.scheduler().handleWebhook('evt_change');assert.equal((await scheduleRpc('get',{cycle_id:f.calendar.cycleId})).status,'ready');
});
test('Guardian periodic change worker applies queued requests after a missing webhook',async()=>{
  const f=await changeFixture();await f.request();assert.deepEqual(await f.manager().reconcile(),{applied:1,failed:0});
  assert.deepEqual(await f.manager().reconcile(),{applied:0,failed:0});
});

test('Guardian duplicate write authorization counts once per processing lease',async()=>{
  const f=await changeFixture(),requestId=await f.request('cancel',0,null);
  const j=await changeRpc('claim',{request_id:requestId}),data={request_id:requestId,lease:j.lease};
  assert.equal((await changeRpc('write',data)).attempts,1);
  assert.equal((await changeRpc('write',data)).attempts,1);
});
test('Guardian a monitor that read the old price cannot flag a newly confirmed amount',async()=>{
  const f=await changeFixture(),requestId=await f.request();
  const monitorRpc=async(operation,data)=>{
    const result=await scheduleRpc(operation,data);
    if(operation==='lookup_subscription'){
      result.lifecycle_pending=false;await f.manager().run(requestId);
    }
    return result;
  };
  f.stripe.events={retrieve:async()=>({livemode:false,type:'customer.subscription.updated',data:{object:{id:f.subscription.id}}})};
  const scheduler=guardianScheduleService({stripe:f.stripe,rpc:monitorRpc,logger:{error(){}}});
  await assert.rejects(()=>scheduler.handleWebhook('evt_staleMonitor'),/guardian_/);
  assert.equal((await scheduleRpc('get',{cycle_id:f.calendar.cycleId})).status,'ready');
});
