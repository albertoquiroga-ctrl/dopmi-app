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
