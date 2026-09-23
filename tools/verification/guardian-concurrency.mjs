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
