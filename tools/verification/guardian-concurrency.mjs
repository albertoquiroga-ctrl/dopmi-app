import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';

// This test runs only against the disposable local Supabase database in CI.
// Each docker exec opens a distinct PostgreSQL connection.
const containers = execFileSync('docker', ['ps', '--filter', 'name=supabase_db_', '--format', '{{.ID}}'], { encoding: 'utf8' }).trim().split('\n').filter(Boolean);
assert.equal(containers.length, 1, 'Expected exactly one disposable Supabase PostgreSQL container');
const container = containers[0];
const donorA = '74000000-0000-4000-8000-000000000001';
const donorB = '74000000-0000-4000-8000-000000000002';
const owner = '74000000-0000-4000-8000-000000000003';
const expense = '74100000-0000-4000-8000-000000000003';
const key = '74200000-0000-4000-8000-000000000001';

function query(sql) {
  return execFileSync('docker', ['exec', '-i', container, 'psql', '-X', '-q', '-t', '-A', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres'], { input: sql, encoding: 'utf8' }).trim();
}
function concurrentQuery(sql, onOutput = () => {}) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', ['exec', '-i', container, 'psql', '-X', '-q', '-t', '-A', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres']);
    let stdout = ''; let stderr = '';
    child.stdout.on('data', chunk => { stdout += chunk; onOutput(stdout); });
    child.stderr.on('data', chunk => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve(stdout.trim()) : reject(new Error(`PostgreSQL exited ${code}: ${stderr}`)));
    child.stdin.end(sql);
  });
}

query(`
insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at)
select ('74000000-0000-4000-8000-00000000000'||n)::uuid,'guardian-concurrency-'||n||'@example.test',
'{"display_name":"Guardian CI","terms_version":"development-2026-09-13","terms_accepted":true}',now()
from generate_series(1,3) n;
insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
('74100000-0000-4000-8000-000000000001','${owner}','verification','approved','{"public_name":"Guardian CI"}',null,0),
('74100000-0000-4000-8000-000000000002','${owner}','case','approved','{"pet_name":"Guardian CI"}',null,0),
('${expense}','${owner}','expense','approved','{"title":"Guardian CI"}','74100000-0000-4000-8000-000000000002',1960);
insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
values('${owner}','acct_guardian_concurrency',true,true);
`);

// The first transaction retains its per-rescuer lock after reserving. The
// second request must wait for that transaction to commit, then see its hold.
let ready;
const reserved = new Promise(resolve => { ready = resolve; });
const first = concurrentQuery(`begin;
select public.dopmi_guardian_reserve('${donorA}','${key}',2000);
select pg_sleep(2);
commit;`, output => { if (output.includes('"status"') && output.includes('reserved')) ready(); });
await Promise.race([reserved, first.then(() => { throw new Error('Reservation did not report a hold'); })]);
const second = concurrentQuery(`select public.dopmi_guardian_reserve('${donorB}','${key}',2000);`);
const [firstResult, secondResult] = await Promise.all([first, second]);
assert.match(firstResult, /"status": "reserved"|"status":"reserved"/);
assert.match(secondResult, /"status": "skipped"|"status":"skipped"/);
const result = query(`select (select count(*) from private.dopmi_guardian_cycles where status='reserved' and expires_at>now()),
  (select coalesce(sum(amount_cents),0) from private.dopmi_guardian_allocations where expense_id='${expense}'),
  (public.dopmi_expense_funding('${expense}')->>'available_cents')::bigint;`);
assert.equal(result, '1|1960|0', `Concurrent holds exceeded expense capacity: ${result}`);
console.log('Guardian concurrent reservations: one reserved, one skipped, capacity zero');

// Settlement and individual Checkout must serialize on the same owner lock.
const cycleId = query(`select id from private.dopmi_guardian_cycles where donor_id='${donorA}' and cycle_key='${key}';`);
query(`select public.dopmi_guardian_subscription_server('register',jsonb_build_object(
'donor_id','${donorA}','stripe_customer_id','cus_guardianCI','stripe_subscription_id','sub_guardianCI',
'stripe_price_id','price_guardianCI','gross_cents',2000,'initial_payment_intent_id','pi_guardianInitialCI','initial_charge_id','ch_guardianInitialCI'));
select public.dopmi_guardian_subscription_server('bind_invoice',jsonb_build_object(
'stripe_subscription_id','sub_guardianCI','stripe_invoice_id','in_guardianCI','cycle_id','${cycleId}'));`);
const evidence = JSON.stringify({donor_id:donorA,subscription_id:'sub_guardianCI',invoice_id:'in_guardianCI',
  payment_intent_id:'pi_guardianRenewalCI',charge_id:'ch_guardianRenewalCI',invoice_payment_id:'inpay_guardianCI',
  gross_cents:2000,platform_fee_cents:40,stripe_fee_cents:60,net_cents:1900});
let settlementReady;
const settled = new Promise(resolve => { settlementReady = resolve; });
const settlement = concurrentQuery(`begin;
select public.dopmi_guardian_settlement_server('settle','${evidence}'::jsonb);
select pg_sleep(2);
commit;`, output => { if (output.includes('allocated_cents')) settlementReady(); });
await Promise.race([settled, settlement.then(() => { throw new Error('Settlement did not report'); })]);
const individual = concurrentQuery(`select public.dopmi_payment_server('prepare',jsonb_build_object(
'actor','${donorB}','expense_id','${expense}','key','${key}','gross_cents',1000));`);
await Promise.all([settlement, individual]);
const balanced = query(`select private.dopmi_guardian_funded('${expense}'),
(select sum(reserved_cents) from public.dopmi_donations where expense_id='${expense}'),
(public.dopmi_expense_funding('${expense}')->>'available_cents')::bigint;`);
assert.equal(balanced,'1900|60|0',`Settlement and Checkout overbooked expense: ${balanced}`);
console.log('Guardian settlement vs individual Checkout: assigned 1900, reserved 60, capacity zero');

// Two devices cannot open distinct initial Checkouts for one donor, even when
// the expense has enough capacity for both requests.
query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents)
values('74100000-0000-4000-8000-000000000004','${owner}','expense','approved','{"title":"Activation CI"}',
'74100000-0000-4000-8000-000000000002',4000);`);
const activationData = {donor_id:donorB,key:'74200000-0000-4000-8000-000000000004',gross_cents:2000,
  consent:true,consent_version:'guardian-2026-09-24',return_url:'https://example.test/return'};
let activationReady;
const activationStarted = new Promise(resolve => { activationReady=resolve; });
const activation = concurrentQuery(`begin;
select public.dopmi_guardian_activation_server('prepare','${JSON.stringify(activationData)}'::jsonb);
select pg_sleep(2);commit;`, output=>{if(output.includes('pending'))activationReady();});
await Promise.race([activationStarted,activation.then(()=>{throw Error('Activation did not report');})]);
const duplicateActivation = concurrentQuery(`select public.dopmi_guardian_activation_server('prepare',
'${JSON.stringify({...activationData,key:'74200000-0000-4000-8000-000000000005'})}'::jsonb);`);
const activationResults=await Promise.allSettled([activation,duplicateActivation]);
assert.equal(activationResults[0].status,'fulfilled');assert.equal(activationResults[1].status,'rejected');
assert.match(activationResults[1].reason.message,/ya tiene un alta/);
assert.equal(query(`select count(*) from private.dopmi_guardian_activations where donor_id='${donorB}';`),'1');
console.log('Guardian concurrent activation: one pending Checkout request per donor');

const activationId=query(`select cycle_id from private.dopmi_guardian_activations where donor_id='${donorB}';`);
let leaseReady;
const leaseStarted=new Promise(resolve=>{leaseReady=resolve;});
const firstLease=concurrentQuery(`begin;
select public.dopmi_guardian_activation_server('claim_checkout','{"cycle_id":"${activationId}"}');
select pg_sleep(2);commit;`,output=>{if(output.includes('lease_until'))leaseReady();});
await Promise.race([leaseStarted,firstLease.then(()=>{throw Error('Lease did not report');})]);
const otherLease=concurrentQuery(`select public.dopmi_guardian_activation_server('claim_checkout','{"cycle_id":"${activationId}"}') is null;`);
const leaseResults=await Promise.all([firstLease,otherLease]);assert.equal(leaseResults[1],'t');
assert.equal(query(`select attempts from private.dopmi_guardian_activations where cycle_id='${activationId}';`),'1');
console.log('Guardian concurrent Checkout creation: one active lease and one attempt');

// A delivered initial payment becomes eligible for one leased Billing job.
const activationLease=query(`select lease from private.dopmi_guardian_activations where cycle_id='${activationId}';`);
query(`select public.dopmi_guardian_activation_server('save_checkout',jsonb_build_object(
'cycle_id','${activationId}','lease','${activationLease}','session_id','cs_test_scheduleCI'));
select public.dopmi_guardian_settlement_server('settle_initial',jsonb_build_object(
'donor_id','${donorB}','checkout_session_id','cs_test_scheduleCI','customer_id','cus_scheduleCI','payment_method_id','pm_scheduleCI',
'payment_intent_id','pi_scheduleCI','charge_id','ch_scheduleCI','gross_cents',2000,'platform_fee_cents',40,'stripe_fee_cents',60,'net_cents',1900));`);
const transferJob=JSON.parse(query(`select public.dopmi_guardian_settlement_server('claim','{"cycle_id":"${activationId}"}');`));
query(`select public.dopmi_guardian_settlement_server('finish','${JSON.stringify({job_id:transferJob.id,lease:transferJob.lease,result_id:'tr_scheduleCI'})}');
select public.dopmi_guardian_schedule_server('prepare',jsonb_build_object('cycle_id','${activationId}','charge_created',extract(epoch from now())::bigint));`);
let scheduleReady;
const scheduleStarted=new Promise(resolve=>{scheduleReady=resolve;});
const scheduleClaim=concurrentQuery(`begin;
select public.dopmi_guardian_schedule_server('claim','{"cycle_id":"${activationId}"}');
select pg_sleep(2);commit;`,output=>{if(output.includes('lease_until'))scheduleReady();});
await Promise.race([scheduleStarted,scheduleClaim.then(()=>{throw Error('Schedule lease did not report');})]);
const competingSchedule=concurrentQuery(`select public.dopmi_guardian_schedule_server('claim','{"cycle_id":"${activationId}"}') is null;`);
const scheduleResults=await Promise.all([scheduleClaim,competingSchedule]);assert.equal(scheduleResults[1],'t');
assert.equal(query(`select attempts from private.dopmi_guardian_schedule_jobs where cycle_id='${activationId}';`),'1');
console.log('Guardian concurrent Billing setup: one active lease and one attempt');

// Finish the synthetic schedule and race two monthly workers. No Stripe is
// called by this database test; the response must grant only one pay marker.
const scheduleLease=query(`select lease from private.dopmi_guardian_schedule_jobs where cycle_id='${activationId}';`);
for(const [operation,fields] of [['price',{price_id:'price_collectionCI'}],['subscription',{subscription_id:'sub_collectionCI'}],['ready',{}]])
  query(`select public.dopmi_guardian_schedule_server('${operation}','${JSON.stringify({cycle_id:activationId,lease:scheduleLease,...fields})}');`);
query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents)
values('74100000-0000-4000-8000-000000000005','${owner}','expense','approved','{"title":"Collection CI"}',
'74100000-0000-4000-8000-000000000002',4000);`);
const collectionData={invoice_id:'in_collectionCI',subscription_id:'sub_collectionCI',cycle_key:'74200000-0000-4000-8000-000000000006',
  period_start:Math.floor(Date.now()/1000)-1,period_end:Math.floor(Date.now()/1000)+30*86400,fresh:true};
let collectionReady;
const collectionStarted=new Promise(resolve=>{collectionReady=resolve;});
const collectionPrepare=concurrentQuery(`begin;
select public.dopmi_guardian_collection_server('prepare','${JSON.stringify(collectionData)}');
select pg_sleep(2);commit;`,output=>{if(output.includes('invoice_id'))collectionReady();});
await Promise.race([collectionStarted,collectionPrepare.then(()=>{throw Error('Collection did not report');})]);
const competingPrepare=concurrentQuery(`select public.dopmi_guardian_collection_server('prepare','${JSON.stringify(collectionData)}');`);
await Promise.all([collectionPrepare,competingPrepare]);
assert.equal(query("select count(*) from private.dopmi_guardian_collection_jobs where invoice_id='in_collectionCI';"),'1');
const collectionClaim=JSON.parse(query(`select public.dopmi_guardian_collection_server('claim','{"invoice_id":"in_collectionCI"}');`));
const paymentData=JSON.stringify({invoice_id:'in_collectionCI',lease:collectionClaim.lease});
let paymentReady;
const paymentStarted=new Promise(resolve=>{paymentReady=resolve;});
const firstPayment=concurrentQuery(`begin;
select public.dopmi_guardian_collection_server('authorize_pay','${paymentData}');
select pg_sleep(2);commit;`,output=>{if(output.includes('pay_requested_at'))paymentReady();});
await Promise.race([paymentStarted,firstPayment.then(()=>{throw Error('Pay authorization did not report');})]);
const competingPayment=concurrentQuery(`select public.dopmi_guardian_collection_server('authorize_pay','${paymentData}') is null;`);
const paymentResults=await Promise.all([firstPayment,competingPayment]);assert.equal(paymentResults[1],'t');
assert.equal(JSON.parse(paymentResults[0]).decision,'collect');
console.log('Guardian concurrent monthly collection: one invoice reservation and one pay authorization');

// A crashed collector's lease expires before recovery can take over. Two
// recovery workers share that same lease; only one may authorize voiding.
query(`update private.dopmi_guardian_collection_jobs set status='attention',lease_until=now()-interval '1 second',available_at=now()
where invoice_id='in_collectionCI';`);
let recoveryReady;
const recoveryStarted=new Promise(resolve=>{recoveryReady=resolve;});
const recovering=concurrentQuery(`begin;
select public.dopmi_guardian_recovery_server('claim','{"invoice_id":"in_collectionCI"}');
select pg_sleep(2);commit;`,output=>{if(output.includes('lease_until'))recoveryReady();});
await Promise.race([recoveryStarted,recovering.then(()=>{throw Error('Recovery lease did not report');})]);
const competingRecovery=concurrentQuery(`select public.dopmi_guardian_recovery_server('claim','{"invoice_id":"in_collectionCI"}') is null;`);
const recoveryResults=await Promise.all([recovering,competingRecovery]);assert.equal(recoveryResults[1],'t');
const recoveryClaim=JSON.parse(recoveryResults[0]);assert.notEqual(recoveryClaim.lease,collectionClaim.lease);
const recoveryData={invoice_id:'in_collectionCI',lease:recoveryClaim.lease};
query(`select public.dopmi_guardian_recovery_server('observe','${JSON.stringify({...recoveryData,state:'requires_payment_method',intent_id:'pi_recoveryCI',invoice_payment_id:'inpay_recoveryCI'})}');`);
let voidReady;
const voidStarted=new Promise(resolve=>{voidReady=resolve;});
const firstVoid=concurrentQuery(`begin;
select public.dopmi_guardian_recovery_server('authorize_void','${JSON.stringify(recoveryData)}');
select pg_sleep(2);commit;`,output=>{if(output.includes('void_pending'))voidReady();});
await Promise.race([voidStarted,firstVoid.then(()=>{throw Error('Void authorization did not report');})]);
const competingVoid=concurrentQuery(`select public.dopmi_guardian_recovery_server('authorize_void','${JSON.stringify(recoveryData)}');`);
const voidResults=await Promise.allSettled([firstVoid,competingVoid]);assert.equal(voidResults[0].status,'fulfilled');assert.equal(voidResults[1].status,'rejected');
assert.match(voidResults[1].reason.message,/Pago no cancelable confirmado/);
assert.equal(query("select recovery_attempts from private.dopmi_guardian_collection_jobs where invoice_id='in_collectionCI';"),'1');
console.log('Guardian concurrent payment recovery: one recovery lease and one void authorization');

// Complete the disposable failed payment before preparing the next cycle.
query(`select public.dopmi_guardian_recovery_server('voided','${JSON.stringify({...recoveryData,intent_id:'pi_recoveryCI',invoice_payment_id:'inpay_recoveryCI',
  invoice_status:'void',intent_status:'canceled',invoice_payment_status:'canceled',amount_received:0,amount_capturable:0,amount_paid:0,amount_remaining:2000})}');`);
const nextCycle={...collectionData,invoice_id:'in_ownerCI',cycle_key:'74200000-0000-4000-8000-000000000007',period_start:collectionData.period_start+1};
query(`select public.dopmi_guardian_collection_server('prepare','${JSON.stringify(nextCycle)}');`);
const ownerClaim=JSON.parse(query(`select public.dopmi_guardian_collection_server('claim','{"invoice_id":"in_ownerCI"}');`));
const amountRequest=`select public.dopmi_guardian_request('amount','75000000-0000-4000-8000-000000000001',0,5000,'guardian-2026-09-24');`;
const asOwner=`set local role authenticated;select set_config('request.jwt.claim.sub','${donorB}',true);`;
let requestReady;
const requestStarted=new Promise(resolve=>{requestReady=resolve;});
const firstRequest=concurrentQuery(`begin;${asOwner}${amountRequest}select pg_sleep(2);commit;`,output=>{if(output.includes('pending_request'))requestReady();});
await Promise.race([requestStarted,firstRequest.then(()=>{throw Error('Owner request did not report');})]);
const sameRequest=concurrentQuery(`begin;${asOwner}${amountRequest}commit;`);
const nextPreparation=concurrentQuery(`select public.dopmi_guardian_collection_server('prepare','${JSON.stringify({...nextCycle,
  invoice_id:'in_blockedOwnerCI',cycle_key:'74200000-0000-4000-8000-000000000008',period_start:nextCycle.period_start+1})}');`);
const requestResults=await Promise.allSettled([firstRequest,sameRequest,nextPreparation]);
assert.equal(requestResults[0].status,'fulfilled');assert.equal(requestResults[1].status,'fulfilled');
assert.equal(requestResults[2].status,'rejected');assert.match(requestResults[2].reason.message,/Solicitud Guardián pendiente/);
assert.equal(query(`select count(*),max(revision) from private.dopmi_guardian_requests where donor_id='${donorB}';`),'1|1');
assert.equal(query("select count(*) from private.dopmi_guardian_collection_jobs where invoice_id='in_blockedOwnerCI';"),'0');
console.log('Guardian concurrent owner requests: one intent, one revision, new cycle blocked');

// Stage an amount write whose Stripe response arrives after owner cancellation.
// Synthetic processor evidence exercises SQL only; no Stripe request is made.
const amountId=query(`select id from private.dopmi_guardian_requests where donor_id='${donorB}' and kind='amount';`);
const amountClaim=JSON.parse(query(`select public.dopmi_guardian_change_server('claim','{"request_id":"${amountId}"}');`));
const amountData={request_id:amountId,lease:amountClaim.lease};
for(const [operation,fields] of [
  ['snapshot',{item_id:'si_changeCI',period_start:collectionData.period_start,effective_from:collectionData.period_end,
    billing_anchor:collectionData.period_end,latest_invoice_id:null}],
  ['write',{}],['price',{price_id:'price_changeCI'}],['mutation',{}],
]) query(`select public.dopmi_guardian_change_server('${operation}','${JSON.stringify({...amountData,...fields})}');`);

// Cancellation holds the same subscription row as authorize_pay. The waiting
// worker must see the committed intent before persisting its one-shot marker.
let cancelReady;
const cancelStarted=new Promise(resolve=>{cancelReady=resolve;});
const cancelRequest=concurrentQuery(`begin;${asOwner}
select public.dopmi_guardian_request('cancel','75000000-0000-4000-8000-000000000002',1);
select pg_sleep(2);commit;`,output=>{if(output.includes('cancel_requested'))cancelReady();});
await Promise.race([cancelStarted,cancelRequest.then(()=>{throw Error('Cancellation did not report');})]);
const waitingPayment=concurrentQuery(`select public.dopmi_guardian_collection_server('authorize_pay','${JSON.stringify({invoice_id:'in_ownerCI',lease:ownerClaim.lease})}');`);
const lateAmount=concurrentQuery(`select public.dopmi_guardian_change_server('applied','${JSON.stringify({...amountData,
  subscription_id:'sub_collectionCI',customer_id:'cus_scheduleCI',price_id:'price_changeCI',item_id:'si_changeCI',
  effective_from:collectionData.period_end,gross_cents:5000})}');`);
const cancelResults=await Promise.all([cancelRequest,waitingPayment,lateAmount]);const stopped=JSON.parse(cancelResults[1]);
assert.equal(stopped.pay_requested_at,null);assert.equal(stopped.decision,'skip');assert.equal(stopped.cycle_status,'released');
assert.equal(query(`select count(*) from private.dopmi_guardian_requests where donor_id='${donorB}' and status='pending' and kind='cancel';`),'1');
console.log('Guardian cancellation vs pay: cancellation commits first, no payment authorization');
assert.equal(JSON.parse(cancelResults[2]).status,'superseded');
assert.equal(query("select count(*) from private.dopmi_guardian_prices where subscription_id='sub_collectionCI';"),'1');
assert.equal(query("select stripe_price_id from private.dopmi_guardian_subscriptions where stripe_subscription_id='sub_collectionCI';"),'price_collectionCI');
console.log('Guardian cancellation vs amount confirmation: superseded result cannot replace price history');

const cancelId=query(`select id from private.dopmi_guardian_requests where donor_id='${donorB}' and kind='cancel';`);
let changeReady;
const changeStarted=new Promise(resolve=>{changeReady=resolve;});
const firstChange=concurrentQuery(`begin;
select public.dopmi_guardian_change_server('claim','{"request_id":"${cancelId}"}');
select pg_sleep(2);commit;`,output=>{if(output.includes('lease_until'))changeReady();});
await Promise.race([changeStarted,firstChange.then(()=>{throw Error('Change lease did not report');})]);
const secondChange=concurrentQuery(`select public.dopmi_guardian_change_server('claim','{"request_id":"${cancelId}"}') is null;`);
const changeResults=await Promise.all([firstChange,secondChange]);assert.equal(changeResults[1],'t');
const cancelClaim=JSON.parse(changeResults[0]);const cancelData={request_id:cancelId,lease:cancelClaim.lease};
let writeReady;
const writeStarted=new Promise(resolve=>{writeReady=resolve;});
const firstWrite=concurrentQuery(`begin;
select public.dopmi_guardian_change_server('write','${JSON.stringify(cancelData)}');
select pg_sleep(2);commit;`,output=>{if(output.includes('first_attempt_at'))writeReady();});
await Promise.race([writeStarted,firstWrite.then(()=>{throw Error('Change write did not report');})]);
const secondWrite=concurrentQuery(`select public.dopmi_guardian_change_server('write','${JSON.stringify(cancelData)}');`);
const writes=await Promise.all([firstWrite,secondWrite]);
assert.equal(JSON.parse(writes[0]).attempts,1);assert.equal(JSON.parse(writes[1]).attempts,1);
query(`select public.dopmi_guardian_change_server('mutation','${JSON.stringify(cancelData)}');
select public.dopmi_guardian_change_server('canceled','${JSON.stringify({...cancelData,
  subscription_id:'sub_collectionCI',customer_id:'cus_scheduleCI',status:'canceled'})}');`);
assert.equal(query(`select status from private.dopmi_guardian_requests where id='${cancelId}';`),'applied');
assert.equal(query("select status from private.dopmi_guardian_subscriptions where stripe_subscription_id='sub_collectionCI';"),'canceled');
console.log('Guardian concurrent change processing: one lease, one counted write attempt, cancellation confirmed');

// Owner cancellation and Checkout claim must serialize on the activation row.
const stoppingOwner='74000000-0000-4000-8000-000000000009';
query(`insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
('${stoppingOwner}','guardian-stop@example.test','{"display_name":"Guardian CI","terms_version":"development-2026-09-13","terms_accepted":true}',now());
insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents,urgent)
values('74100000-0000-4000-8000-000000000009','${owner}','expense','approved','{"title":"Cancelación CI"}',
'74100000-0000-4000-8000-000000000002',100000,true);`);
const stoppingInput={...activationData,donor_id:stoppingOwner,key:crypto.randomUUID()};
const stopping=JSON.parse(query(`select public.dopmi_guardian_activation_server('prepare','${JSON.stringify(stoppingInput)}');`));
let stopReady;const stopStarted=new Promise(resolve=>{stopReady=resolve;});
const stopActivation=concurrentQuery(`begin;set local role authenticated;
select set_config('request.jwt.claim.sub','${stoppingOwner}',true);
select public.dopmi_guardian_cancel_activation('${stoppingInput.key}');select pg_sleep(2);commit;`,output=>{
 if(output.includes('"cancellation_status": "stopped"'))stopReady();
});
await Promise.race([stopStarted,stopActivation.then(()=>{throw Error('Activation stop did not report');})]);
const blockedCheckout=concurrentQuery(`select public.dopmi_guardian_activation_server('claim_checkout','{"cycle_id":"${stopping.cycle_id}"}') is null;`);
assert.equal((await Promise.all([stopActivation,blockedCheckout]))[1],'t');
assert.equal(query(`select attempts from private.dopmi_guardian_activations where cycle_id='${stopping.cycle_id}';`),'0');
console.log('Guardian activation cancellation wins before Checkout claim: no Stripe creation authorized');

const setupOwner='74000000-0000-4000-8000-000000000008';
query(`insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
('${setupOwner}','guardian-stop-setup@example.test','{"display_name":"Guardian CI","terms_version":"development-2026-09-13","terms_accepted":true}',now());`);
const setupInput={...activationData,donor_id:setupOwner,key:crypto.randomUUID()};
const setup=JSON.parse(query(`select public.dopmi_guardian_activation_server('prepare','${JSON.stringify(setupInput)}');`));
const setupClaim=JSON.parse(query(`select public.dopmi_guardian_activation_server('claim_checkout','{"cycle_id":"${setup.cycle_id}"}');`));
query(`select public.dopmi_guardian_activation_server('save_checkout','${JSON.stringify({cycle_id:setup.cycle_id,lease:setupClaim.lease,session_id:'cs_test_stopCI'})}');
select public.dopmi_guardian_settlement_server('settle_initial','${JSON.stringify({donor_id:setupOwner,checkout_session_id:'cs_test_stopCI',customer_id:'cus_stopCI',payment_method_id:'pm_stopCI',payment_intent_id:'pi_stopCI',charge_id:'ch_stopCI',gross_cents:2000,platform_fee_cents:40,stripe_fee_cents:60,net_cents:1900})}');`);
const stopTransfer=JSON.parse(query(`select public.dopmi_guardian_settlement_server('claim','{"cycle_id":"${setup.cycle_id}"}');`));
query(`select public.dopmi_guardian_settlement_server('finish','${JSON.stringify({job_id:stopTransfer.id,lease:stopTransfer.lease,result_id:'tr_stopCI'})}');
select public.dopmi_guardian_schedule_server('prepare',jsonb_build_object('cycle_id','${setup.cycle_id}','charge_created',extract(epoch from now())::bigint));`);
const stopScheduleClaim=JSON.parse(query(`select public.dopmi_guardian_schedule_server('claim','{"cycle_id":"${setup.cycle_id}"}');`));
const stopScheduleData={cycle_id:setup.cycle_id,lease:stopScheduleClaim.lease};
query(`select public.dopmi_guardian_schedule_server('price','${JSON.stringify({...stopScheduleData,price_id:'price_stopCI'})}');
select public.dopmi_guardian_schedule_server('subscription','${JSON.stringify({...stopScheduleData,subscription_id:'sub_stopCI'})}');`);
let setupStopReady;const setupStopStarted=new Promise(resolve=>{setupStopReady=resolve;});
const setupStop=concurrentQuery(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','${setupOwner}',true);
select public.dopmi_guardian_cancel_activation('${setupInput.key}');select pg_sleep(2);commit;`,output=>{
 if(output.includes('"cancellation_status": "pending"'))setupStopReady();
});
await Promise.race([setupStopStarted,setupStop.then(()=>{throw Error('Setup stop did not report');})]);
const lateRegistration=concurrentQuery(`select public.dopmi_guardian_schedule_server('ready','${JSON.stringify(stopScheduleData)}');`);
const setupRace=await Promise.allSettled([setupStop,lateRegistration]);
assert.equal(setupRace[0].status,'fulfilled');assert.equal(setupRace[1].status,'rejected');
assert.match(setupRace[1].reason.message,/Cancelación de alta pendiente/);
assert.equal(query(`select count(*) from private.dopmi_guardian_subscriptions where donor_id='${setupOwner}';`),'0');
console.log('Guardian activation cancellation wins before schedule registration: no collectible subscription');
