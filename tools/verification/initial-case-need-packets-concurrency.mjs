import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import pg from 'pg';

// A fixed, disposable local Supabase PostgreSQL only. Remote environment URLs,
// PGHOST and PGPORT are deliberately ignored, matching existing race harnesses.
assert.equal(process.env.PGPASSWORD, 'postgres', 'This local-only runner requires disposable CI PGPASSWORD');
const config = { host: '127.0.0.1', port: 54322, database: 'postgres', user: 'postgres',
  password: process.env.PGPASSWORD, ssl: false, connectionTimeoutMillis: 5000,
  options: '-c timezone=UTC -c statement_timeout=30000 -c lock_timeout=25000' };
const suffix = randomUUID().slice(0, 8);
const clients = ['control', 'first', 'second'].map(name => new pg.Client({ ...config, application_name: `initial_packet_${name}_${suffix}` }));
const [control, first, second] = clients, connected = new Set();
const owner = randomUUID(), reviewer = randomUUID();
const caseIds = [randomUUID(), randomUUID(), randomUUID()], expenseIds = [randomUUID(), randomUUID(), randomUUID()];
const submissions = [], requests = [randomUUID(), randomUUID()], paths = [];
let seeded = false, pending;
const settled = promise => promise.then(result => ({ status: 'fulfilled', result }), error => ({ status: 'rejected', error }));
async function beginReviewer(client) {
  await client.query('begin');
  await client.query("select set_config('request.jwt.claim.sub',$1,true)", [reviewer]);
  await client.query('set local role authenticated');
}
const approve = (client, index) => client.query(`select public.dopmi_review_initial_case_packet($1,2,$2,'approved',
  'Revisión concurrente sintética',true,$3::jsonb,$4) value`, [caseIds[index], submissions[index], JSON.stringify([{
  expense_id: expenseIds[index], expense_version: 1, amount_cents: 7000,
  is_urgent: false, urgency_note: '', publish_content: true,
}]), requests[index]]);
async function blockedBy(firstPid, secondPid) {
  const deadline = Date.now() + 20000;
  while (Date.now() < deadline) {
    if ((await control.query(`select exists(select 1 from pg_stat_activity s where s.pid=$2
      and s.wait_event_type='Lock' and $1=any(pg_blocking_pids(s.pid))) blocked`, [firstPid, secondPid])).rows[0].blocked) return;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  assert.fail('The second real backend was not observed blocked on the first owner transaction');
}
const approvals = async index => Number((await control.query(`select count(*) total from private.dopmi_rescue_history
  where record_id=$1 and action='approved'`, [caseIds[index]])).rows[0].total);
try {
  const connections = await Promise.allSettled(clients.map(async client => { await client.connect(); connected.add(client); }));
  for (const connection of connections) if (connection.status === 'rejected') throw connection.reason;
  const firstPid = (await first.query('select pg_backend_pid() pid')).rows[0].pid;
  const secondPid = (await second.query('select pg_backend_pid() pid')).rows[0].pid;
  assert.notEqual(firstPid, secondPid);
  await control.query('begin');
  await control.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    select id::uuid,id||'@example.test',now(),'{"display_name":"Paquete CI","terms_accepted":true,"terms_version":"development-2026-09-13"}'::jsonb from unnest($1::text[]) id`, [[owner, reviewer]]);
  await control.query('insert into private.admin_memberships(user_id) values($1)', [reviewer]);
  await control.query('select private.dopmi_rescue_lock($1)', [owner]);
  for (let index = 0; index < 3; index++) {
    const casePath = `${owner}/${caseIds[index]}/${randomUUID()}.jpg`;
    const receiptPath = `${owner}/${expenseIds[index]}/${randomUUID()}.pdf`;
    const proofPath = `${owner}/${expenseIds[index]}/${randomUUID()}.jpg`;
    paths.push(casePath, receiptPath, proofPath);
    await control.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,version,public_data,files,video_thanks_required)
      values($1,$2,'case',$5,$6,$3::jsonb,$4::jsonb,false)`, [caseIds[index], owner, JSON.stringify({
      pet_name: 'Caso sintético de concurrencia', species: 'dog', sex: 'unknown', age: 'Dos años',
      story: 'Historia sintética para prueba local', city: 'Monterrey', state: 'Nuevo León',
    }), JSON.stringify([{ role: 'public', path: casePath }]), index === 2 ? 'draft' : 'submitted', index === 2 ? 1 : 2]);
    await control.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,public_data,private_data,files)
      values($1,$2,'expense',$3,'{"title":"Consulta pagada sintética","description":"Gasto pagado sintético","category":"veterinary"}',
      $4::jsonb,$5::jsonb)`, [expenseIds[index], owner, caseIds[index], JSON.stringify({ paid_on: '2026-09-01', vendor: 'Proveedor sintético',
      amount_cents: '10000', receipt_reference: expenseIds[index] }), JSON.stringify([{ role: 'receipt', path: receiptPath }, { role: 'proof', path: proofPath }])]);
    for (const path of [casePath, receiptPath, proofPath]) await control.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)", [path]);
    if (index < 2) {
      await control.query('select private.dopmi_initial_case_capture(r) from public.dopmi_rescue_records r where id=$1', [caseIds[index]]);
      submissions.push((await control.query('select id from private.dopmi_case_need_submissions where case_id=$1', [caseIds[index]])).rows[0].id);
    }
  }
  await control.query('commit'); seeded = true;
  await beginReviewer(first);
  const result = (await approve(first, 0)).rows[0].value;
  await beginReviewer(second); pending = settled(approve(second, 0));
  await blockedBy(firstPid, secondPid);
  await first.query('commit'); const replay = await pending; pending = undefined;
  assert.equal(replay.status, 'fulfilled'); assert.deepEqual(replay.result.rows[0].value, result);
  await second.query('commit'); assert.equal(await approvals(0), 1);
  assert.equal(result.expenses[0].reimbursable_cents, 7000);
  console.log('Initial packet: observed overlapping PostgreSQL sessions replay one exact case/expense approval');

  await first.query('begin'); await first.query('select private.dopmi_rescue_lock($1)', [owner]);
  await beginReviewer(second); pending = settled(approve(second, 1));
  await blockedBy(firstPid, secondPid);
  await control.query('update private.admin_memberships set active=false where user_id=$1', [reviewer]);
  await first.query('commit'); const revoked = await pending; pending = undefined;
  assert.equal(revoked.status, 'rejected'); assert.equal(revoked.error.code, '42501');
  await second.query('rollback'); assert.equal(await approvals(1), 0);
  assert.equal((await control.query('select status from public.dopmi_rescue_records where id=$1', [caseIds[1]])).rows[0].status, 'submitted');
  assert.equal((await control.query('select status from public.dopmi_rescue_records where id=$1', [expenseIds[1]])).rows[0].status, 'draft');
  console.log('Initial packet: revocation while demonstrably waiting rejects approval without a partial parent/child decision');

  // A new Storage read/signature grant must serialize against withdrawal too.
  // This does not claim immediate revocation of an already-issued signed URL.
  await control.query('update private.admin_memberships set active=true where user_id=$1', [reviewer]);
  await first.query('begin');
  await first.query("select set_config('request.jwt.claim.sub',$1,true)", [owner]);
  await first.query('set local role authenticated');
  await first.query("select public.dopmi_transition_rescue($1,2,'withdraw')", [caseIds[1]]);
  await beginReviewer(second);
  const receipt = paths.find(path => path.startsWith(`${owner}/${expenseIds[1]}/`) && path.endsWith('.pdf'));
  pending = settled(second.query("select name from storage.objects where bucket_id='dopmi-rescue-evidence' and name=$1", [receipt]));
  await blockedBy(firstPid, secondPid);
  await first.query('commit'); const withdrawnRead = await pending; pending = undefined;
  assert.equal(withdrawnRead.status, 'fulfilled'); assert.deepEqual(withdrawnRead.result.rows, []);
  await second.query('commit');
  console.log('Initial packet: actual Storage RLS read waits for withdrawal then denies the released snapshot path');

  await first.query('begin');
  await first.query("select set_config('request.jwt.claim.sub',$1,true)", [owner]);
  await first.query('set local role authenticated');
  const pendingCase = (await first.query("select public.dopmi_transition_rescue($1,1,'submit') value", [caseIds[2]])).rows[0].value;
  assert.equal(pendingCase.status, 'pending_stripe');
  await second.query('begin');
  await second.query("select set_config('request.jwt.claim.sub',$1,true)", [owner]);
  await second.query('set local role authenticated');
  pending = settled(second.query('select public.dopmi_remove_draft_expense($1,1)', [expenseIds[2]]));
  await blockedBy(firstPid, secondPid);
  await first.query('commit'); const removed = await pending; pending = undefined;
  assert.equal(removed.status, 'rejected'); assert.equal(removed.error.code, '22023');
  await second.query('rollback');
  assert.equal(Number((await control.query(`select count(*) total from private.dopmi_case_need_submission_expenses e
    join private.dopmi_case_need_submissions s on s.id=e.submission_id where s.case_id=$1 and e.expense_id=$2`, [caseIds[2], expenseIds[2]])).rows[0].total), 1);
  console.log('Initial packet: draft removal waits on actual submission, then cannot erase consented manifest membership');
} finally {
  try {
    await Promise.allSettled([...connected].map(client => client.query('rollback')));
    if (pending) await pending;
    if (seeded) {
      await control.query('begin');
      try {
        // Local fixture cleanup follows the Storage API transaction protocol;
        // this control connection never changes the authenticated RLS scenarios.
        await control.query("select set_config('storage.allow_delete_query','true',true)");
        await control.query("delete from storage.objects where bucket_id='dopmi-rescue-evidence' and name=any($1::text[])", [paths]);
        await control.query('delete from public.dopmi_rescue_records where id=any($1::uuid[])', [expenseIds]);
        await control.query('delete from private.dopmi_urgent_coverage_state where case_id=any($1::uuid[])', [caseIds]);
        await control.query('delete from public.dopmi_rescue_records where id=any($1::uuid[])', [caseIds]);
        await control.query('delete from auth.users where id=any($1::uuid[])', [[owner, reviewer]]);
        await control.query('commit');
      } catch (error) { await control.query('rollback'); throw error; }
    }
  } finally { await Promise.allSettled(clients.map(client => client.end())); }
}
