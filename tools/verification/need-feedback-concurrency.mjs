import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import pg from 'pg';

// Only the disposable Supabase PostgreSQL started by CI. All connection fields
// are fixed: PGHOST, PGPORT, DATABASE_URL and other remote configuration are unused.
assert.ok(process.env.PGPASSWORD === 'postgres', 'This local-only runner requires the disposable CI PGPASSWORD');
const config = {
  host: '127.0.0.1', port: 54322, database: 'postgres', user: 'postgres',
  password: process.env.PGPASSWORD, ssl: false, connectionTimeoutMillis: 5000,
  options: '-c timezone=UTC -c statement_timeout=30000 -c lock_timeout=25000',
};
const suffix = randomUUID().slice(0, 8);
const control = new pg.Client({ ...config, application_name: `need_feedback_control_${suffix}` });
const first = new pg.Client({ ...config, application_name: `need_feedback_first_${suffix}` });
const second = new pg.Client({ ...config, application_name: `need_feedback_second_${suffix}` });
const clients = [control, first, second];
const owner = randomUUID(), reviewer = randomUUID();
const caseIds = [randomUUID(), randomUUID()], expenseIds = [randomUUID(), randomUUID()];
const requests = [randomUUID(), randomUUID()];
const connected = new Set();
let seeded = false, pending;

async function beginAsReviewer(client) {
  await client.query('begin');
  await client.query("select set_config('request.jwt.claim.sub',$1,true)", [reviewer]);
  await client.query('set local role authenticated');
}
const input = index => [{
  target_kind: 'expense', target_id: expenseIds[index], target_version: 2,
  body: 'Aclara el desglose de esta consulta sintética',
}];
const comment = (client, index) => client.query(
  'select public.dopmi_comment_case_needs($1,4,$2::jsonb,$3) value',
  [caseIds[index], JSON.stringify(input(index)), requests[index]],
);
const settled = promise => promise.then(result => ({ status: 'fulfilled', result }), error => ({ status: 'rejected', error }));

// Same observation used by adoption-contact-concurrency: do not infer overlap
// from a sleep. The second backend must actually wait on the first backend.
async function observeBlocked(firstPid, secondPid) {
  const deadline = Date.now() + 20000;
  while (Date.now() < deadline) {
    const result = await control.query(`select exists(select 1 from pg_stat_activity s
      where s.pid=$2 and s.wait_event_type='Lock' and $1=any(pg_blocking_pids(s.pid))) blocked`,
    [firstPid, secondPid]);
    if (result.rows[0].blocked) return;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  assert.fail('Second comment backend was not observed blocked by the first transaction');
}

async function inventory() {
  const result = {};
  result.records = (await control.query(`select to_jsonb(r) value from public.dopmi_rescue_records r
    where id=any($1::uuid[]) order by id`, [[...caseIds, ...expenseIds]])).rows;
  for (const table of ['public.dopmi_donations', 'private.dopmi_case_allocations',
    'private.dopmi_connect_accounts', 'private.dopmi_payment_environment',
    'private.dopmi_video_settings', 'private.dopmi_store_settings']) {
    result[table] = (await control.query(`select to_jsonb(t) value from ${table} t order by to_jsonb(t)::text`)).rows;
  }
  return result;
}
const eventCount = async index => Number((await control.query(`select count(*) total
  from private.dopmi_rescue_history where record_id=$1 and action='need_comments'`, [caseIds[index]])).rows[0].total);

try {
  const connections = await Promise.allSettled(clients.map(async client => {
    await client.connect(); connected.add(client);
  }));
  for (const connection of connections) if (connection.status === 'rejected') throw connection.reason;
  for (const client of clients) {
    assert.equal(client.connectionParameters.host, '127.0.0.1');
    assert.equal(client.connectionParameters.port, 54322);
    assert.equal(client.connectionParameters.database, 'postgres');
  }
  const firstPid = (await first.query('select pg_backend_pid() pid')).rows[0].pid;
  const secondPid = (await second.query('select pg_backend_pid() pid')).rows[0].pid;
  assert.notEqual(firstPid, secondPid, 'Concurrency requires two separate PostgreSQL sessions');

  await control.query('begin');
  await control.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    select id::uuid,id||'@example.test',now(),'{"display_name":"Comentarios CI"}'::jsonb
    from unnest($1::text[]) id`, [[owner, reviewer]]);
  await control.query('insert into private.admin_memberships(user_id) values($1)', [reviewer]);
  for (let index = 0; index < 2; index++) {
    await control.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,version,public_data,video_thanks_required)
      values($1,$2,'case','submitted',4,'{"pet_name":"Caso de concurrencia sintético"}',false)`, [caseIds[index], owner]);
    await control.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,status,version,public_data,private_data)
      values($1,$2,'expense',$3,'submitted',2,'{"title":"Consulta pagada sintética"}',
        '{"amount_cents":"30000","vendor":"Proveedor sintético"}')`, [expenseIds[index], owner, caseIds[index]]);
  }
  await control.query('commit');
  seeded = true;
  const baseline = await inventory();

  // First response is available while its transaction still owns the rescue
  // lock. A second session sends exactly the same intent before the commit.
  await beginAsReviewer(first);
  const initial = (await comment(first, 0)).rows[0].value;
  await beginAsReviewer(second);
  pending = settled(comment(second, 0));
  await observeBlocked(firstPid, secondPid);
  await first.query('commit');
  const retry = await pending;
  pending = undefined;
  assert.equal(retry.status, 'fulfilled', 'Identical concurrent retry must reconcile after the first commit');
  assert.deepEqual(retry.result.rows[0].value, initial, 'Both sessions must receive the exact stored response');
  await second.query('commit');
  assert.equal(await eventCount(0), 1, 'Concurrent duplicate creates exactly one comment event');
  assert.deepEqual(await inventory(), baseline, 'Comment and retry change no record or financial state');
  console.log('Need comments: observed overlapping sessions return the same response and one history event');

  // Hold the same owner lock without creating a comment. The second RPC has
  // passed its entry authorization when it waits; revocation must be checked
  // again after that wait, before either replay or a new history insertion.
  await first.query('begin');
  await first.query('select private.dopmi_rescue_lock($1)', [owner]);
  await beginAsReviewer(second);
  pending = settled(comment(second, 1));
  await observeBlocked(firstPid, secondPid);
  await control.query('update private.admin_memberships set active=false where user_id=$1', [reviewer]);
  assert.equal(await eventCount(1), 0, 'Blocked request has not written a comment');
  await first.query('commit');
  const revoked = await pending;
  pending = undefined;
  assert.equal(revoked.status, 'rejected', 'Revoked reviewer must be rejected after owner lock release');
  assert.equal(revoked.error.code, '42501', 'Revoked reviewer must fail with an authorization error');
  await second.query('rollback');
  assert.equal(await eventCount(1), 0, 'Revoked waiter creates no comment');
  assert.deepEqual(await inventory(), baseline, 'Rejected waiter changes no status, version, publication, files or finances');
  console.log('Need comments: revoking a demonstrably blocked reviewer rejects its write with no comment or record/finance delta');
} finally {
  // Release only this harness's transactions, then remove its exact synthetic
  // fixture once. No global history deletion, server flags or payment cleanup.
  try {
    await Promise.allSettled([...connected].map(client => client.query('rollback')));
    if (pending) await pending;
    if (seeded) {
      await control.query('begin');
      try {
        await control.query('delete from public.dopmi_rescue_records where id=any($1::uuid[])', [expenseIds]);
        await control.query('delete from private.dopmi_urgent_coverage_state where case_id=any($1::uuid[])', [caseIds]);
        await control.query('delete from public.dopmi_rescue_records where id=any($1::uuid[])', [caseIds]);
        await control.query('delete from auth.users where id=any($1::uuid[])', [[owner, reviewer]]);
        await control.query('commit');
      } catch (error) {
        await control.query('rollback');
        throw error;
      }
    }
  } finally { await Promise.allSettled(clients.map(client => client.end())); }
}
