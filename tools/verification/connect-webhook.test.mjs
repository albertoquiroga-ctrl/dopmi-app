import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { PaymentError, paymentService } from '../../supabase/functions/_shared/payments.mjs';

let db, dispatcherBefore;
let savepoint = 0;
const rescuer = '96000000-0000-4000-8000-000000000001';
const other = '96000000-0000-4000-8000-000000000002';
const accountId = 'acct_connectOwner';
const secondAccount = 'acct_connectOther';
const eventId = 'evt_ConnectAccountReady';
const scope = 'connect_account_updated';
const context = (event = eventId, account = accountId) => ({ event_id: event, event_account: account, event_scope: scope });

before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  const migrations = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(migrations)).filter(name => name.endsWith('.sql')).sort()) {
    if (file === '20261029012454_connect_account_webhook_context.sql') dispatcherBefore =
      (await db.query(`select oid,proowner,proacl::text acl from pg_proc
        where oid='public.dopmi_payment_server(text,jsonb)'::regprocedure`)).rows[0];
    await db.exec(await readFile(new URL(file, migrations), 'utf8'));
  }
  await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    select id::uuid,id||'@example.test',now(),$2::jsonb from unnest($1::text[]) id`,
  [[rescuer, other], JSON.stringify({ display_name: 'Prueba', terms_accepted: true, terms_version: 'development-2026-09-13' })]);
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,reimbursable_cents)
    values('97000000-0000-4000-8000-000000000001',$1,'verification','approved','{"public_name":"Refugio sintético"}',0)`, [rescuer]);
  await db.query(`insert into private.dopmi_connect_accounts(owner_id,account_id)
    values($1,$2),($3,$4)`, [rescuer, accountId, other, secondAccount]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

async function asRole(role, actor, sql, values = []) {
  assert.ok(['anon', 'authenticated', 'service_role'].includes(role));
  const point = `connect_port_${++savepoint}`;
  await db.exec(`savepoint ${point}`);
  try {
    await db.exec(`set local role ${role}`);
    await db.query("select set_config('request.jwt.claim.sub',$1,true)", [actor ?? '']);
    const result = await db.query(sql, values);
    await db.exec(`reset role; release savepoint ${point}`);
    return result;
  } catch (error) {
    await db.exec(`rollback to savepoint ${point}; release savepoint ${point}`);
    throw error;
  }
}
async function rpc(operation, data = {}) {
  const sql = operation === 'claim' ? 'select public.dopmi_payment_job_claim($1) value'
    : operation === 'finish_job' ? 'select public.dopmi_payment_job_finish($1::jsonb) value'
      : 'select public.dopmi_payment_server($1,$2::jsonb) value';
  const args = operation === 'claim' ? [data.job_key ?? null]
    : operation === 'finish_job' ? [JSON.stringify(data)] : [operation, JSON.stringify(data)];
  return (await asRole('service_role', '', sql, args)).rows[0].value;
}
async function rejectedQuery(action, pattern) {
  const point = `connect_reject_${++savepoint}`;
  await db.exec(`savepoint ${point}`);
  await assert.rejects(action(), pattern);
  await db.exec(`rollback to savepoint ${point}; release savepoint ${point}`);
}
const job = async (id = eventId) => (await db.query(
  'select to_jsonb(j) value from private.dopmi_payment_jobs j where job_key=$1', [id])).rows[0]?.value;
const account = async () => (await db.query(
  'select to_jsonb(a) value from private.dopmi_connect_accounts a where owner_id=$1', [rescuer])).rows[0].value;
const record = async id => (await db.query(
  'select to_jsonb(r) value from public.dopmi_rescue_records r where id=$1', [id])).rows[0].value;
const financialState = async () => (await db.query(`select
  (select count(*)::int from public.dopmi_donations) donations,
  (select count(*)::int from private.dopmi_payment_jobs where kind<>'event') financial_jobs,
  (select count(*)::int from private.dopmi_payment_method_snapshots) method_snapshots`)).rows[0];
async function readyForRetry(id = eventId) {
  await db.query('update private.dopmi_payment_jobs set available_at=now() where job_key=$1', [id]);
}
async function pendingCase() {
  const data = { pet_name: 'Caso sintético Connect', species: 'dog', sex: 'unknown', age: '3 años',
    story: 'Historia de prueba sin datos reales', city: 'Monterrey', state: 'Nuevo León', need_items: [] };
  let row = (await asRole('authenticated', rescuer,
    "select public.dopmi_save_rescue('case',$1::jsonb,'{}','[]') value", [JSON.stringify(data)])).rows[0].value;
  const path = `${rescuer}/${row.id}/97000000-0000-4000-8000-000000000003.jpg`;
  await db.query("insert into storage.objects(bucket_id,name,owner_id) values('dopmi-rescue-evidence',$1,$2)", [path, rescuer]);
  row = (await asRole('authenticated', rescuer,
    "select public.dopmi_save_rescue('case',$1::jsonb,'{}',$2::jsonb,$3,$4) value",
    [JSON.stringify(data), JSON.stringify([{ role: 'public', path }]), row.id, row.version])).rows[0].value;
  const pending = (await asRole('authenticated', rescuer,
    "select public.dopmi_transition_rescue($1,$2,'submit') value", [row.id, row.version])).rows[0].value;
  assert.equal(pending.status, 'pending_stripe');
  return pending;
}
function serviceFixture({ live = true, failure = null } = {}) {
  const state = { failure, ready: true, stripe: [], operations: [], logs: [], accounts: [], mutate: value => value };
  const ports = {
    expectedLivemode: live, logger: { info: value => state.logs.push(value) },
    rpc: async (operation, data) => {
      state.operations.push({ operation, data: structuredClone(data) });
      const result = await rpc(operation, data);
      if (operation === 'connect_save') state.accounts.push(result);
      if (state.failure === 'save' && operation === 'connect_save') {
        state.failure = null; throw new Error('synthetic lost save response');
      }
      if (state.failure === 'finish' && operation === 'finish_job' && !data.error_code) {
        state.failure = null; throw new Error('synthetic lost finish response');
      }
      return result;
    },
    stripe: async (path, fields, key, connectedAccount) => {
      state.stripe.push({ path, fields, key, connectedAccount });
      assert.equal(fields, undefined);
      assert.equal(key, undefined);
      assert.equal(connectedAccount, undefined);
      assert.equal(path, `accounts/${accountId}`, 'Connect context must use a platform Account GET, never Events or a financial endpoint');
      if (state.failure === 'read') { state.failure = null; throw new Error('synthetic lost account read'); }
      return state.mutate({ object: 'account', id: accountId,
        capabilities: { transfers: state.ready ? 'active' : 'inactive' },
        payouts_enabled: state.ready, details_submitted: true,
        email: 'private_account_sentinel@example.test', business_profile: { name: 'private_account_sentinel' } });
    },
  };
  return { state, service: paymentService(ports), restart: () => paymentService(ports) };
}

test('Connect enqueue persists one immutable minimal event job and preserves the current dispatcher identity and ACL', async () => {
  const after = (await db.query(`select oid,proowner,proacl::text acl from pg_proc
    where oid='public.dopmi_payment_server(text,jsonb)'::regprocedure`)).rows[0];
  assert.deepEqual(after, dispatcherBefore);
  await rpc('connect_event_enqueue', { event_id: eventId, event_account: accountId });
  const first = await job();
  assert.equal(first.kind, 'event');
  assert.equal(first.donation_id, null);
  assert.equal(first.status, 'ready');
  assert.deepEqual(first.payload, context());
  await rpc('connect_event_enqueue', { event_id: eventId, event_account: accountId });
  assert.deepEqual(await job(), first);
  assert.deepEqual(await financialState(), { donations: 0, financial_jobs: 0, method_snapshots: 0 });
  const privileges = (await db.query(`select role,
    has_function_privilege(role,'public.dopmi_payment_server(text,jsonb)','execute') wrapper,
    has_function_privilege(role,'private.dopmi_connect_account_event_enqueue(jsonb)','execute') helper
    from unnest(array['anon','authenticated','service_role']) role order by role`)).rows;
  assert.deepEqual(privileges, [
    { role: 'anon', wrapper: false, helper: false },
    { role: 'authenticated', wrapper: false, helper: false },
    { role: 'service_role', wrapper: true, helper: false },
  ]);
  for (const role of ['anon', 'authenticated', 'service_role']) {
    await assert.rejects(asRole(role, rescuer,
      'select private.dopmi_connect_account_event_enqueue($1::jsonb)',
      [JSON.stringify({ event_id: 'evt_DirectPrivate', event_account: accountId })]), /permission denied/);
    if (role !== 'service_role') await assert.rejects(asRole(role, rescuer,
      "select public.dopmi_payment_server('connect_event_enqueue',$1::jsonb)",
      [JSON.stringify({ event_id: 'evt_DeniedClient', event_account: accountId })]), /permission denied/);
  }
  assert.equal(await job('evt_DirectPrivate'), undefined);
  assert.equal(await job('evt_DeniedClient'), undefined);
});

test('SQL and Node reject malformed identifiers, extra context and oversized IDs before admitting jobs', async () => {
  const f = serviceFixture();
  for (const [event, account] of [[null, accountId], [123, accountId], [[], accountId], ['', accountId],
    ['evt_bad_suffix', accountId], ['evt_' + 'a'.repeat(157), accountId], [eventId, null],
    [eventId, {}], [eventId, 'acct_bad_suffix'], [eventId, 'acct_' + 'a'.repeat(156)]]) {
    await assert.rejects(f.service.handleConnectWebhook(event, account), { code: 'connect_event_invalid', status: 400 });
    await assert.rejects(rpc('connect_event_enqueue', { event_id: event, event_account: account }), /Contexto de evento Connect inválido/);
  }
  for (const data of [null, [], {}, { event_id: eventId }, { event_account: accountId },
    { event_id: eventId, event_account: accountId, event_scope: scope },
    { event_id: eventId, event_account: accountId, private_body: 'never_persist' }])
    await assert.rejects(rpc('connect_event_enqueue', data), /Contexto de evento Connect inválido/);
  assert.equal(f.state.operations.length, 0);
  assert.equal(f.state.stripe.length, 0);
  assert.equal((await db.query('select count(*)::int count from private.dopmi_payment_jobs')).rows[0].count, 0);
  const longestEvent = 'evt_' + 'a'.repeat(156), longestAccount = 'acct_' + 'a'.repeat(155);
  await rpc('connect_event_enqueue', { event_id: longestEvent, event_account: longestAccount });
  assert.deepEqual((await job(longestEvent)).payload, context(longestEvent, longestAccount));
  assert.deepEqual(await f.service.handleConnectWebhook(longestEvent, longestAccount), { received: true });
  assert.equal((await job(longestEvent)).status, 'done');
  assert.deepEqual(f.state.stripe, []);
});

test('Connect and legacy enqueue collisions cannot replace account, scope, kind or existing payload', async () => {
  await rpc('connect_event_enqueue', { event_id: eventId, event_account: accountId });
  const original = await job();
  for (const account of [secondAccount, 'acct_unknown'])
    await assert.rejects(rpc('connect_event_enqueue', { event_id: eventId, event_account: account }), /Contexto de evento Connect distinto/);
  await assert.rejects(rpc('enqueue', { event_id: eventId }), /Contexto de evento Connect distinto/);
  await assert.rejects(rpc('enqueue', context('evt_ForbiddenLegacyContext')), /Contexto de evento Connect inválido/);
  assert.deepEqual(await job(), original);
  await rpc('enqueue', { event_id: 'evt_LegacyFirst' });
  const legacy = await job('evt_LegacyFirst');
  await assert.rejects(rpc('connect_event_enqueue', { event_id: legacy.job_key, event_account: accountId }), /Contexto de evento Connect distinto/);
  assert.deepEqual(await job(legacy.job_key), legacy);
  for (const [id, kind, payload] of [
    ['evt_ForeignScope', 'event', { ...context('evt_ForeignScope'), event_scope: 'payment_intent_succeeded' }],
    ['evt_ForeignKind', 'transfer', {}],
  ]) {
    await db.query('insert into private.dopmi_payment_jobs(job_key,kind,payload) values($1,$2,$3::jsonb)', [id, kind, JSON.stringify(payload)]);
    const before = await job(id);
    await assert.rejects(rpc('connect_event_enqueue', { event_id: id, event_account: accountId }), /Contexto de evento Connect distinto/);
    assert.deepEqual(await job(id), before);
  }
});

test('Connect context refreshes current Account readiness and promotes PendingStripe once without Events or financial writes', async () => {
  const pending = await pendingCase();
  const f = serviceFixture();
  f.state.ready = false;
  assert.deepEqual(await f.service.handleConnectWebhook(eventId, accountId), { received: true });
  assert.equal((await record(pending.id)).status, 'pending_stripe');
  const first = await job();
  assert.equal(first.status, 'done');
  assert.equal(first.attempts, 1);
  f.state.ready = true;
  assert.deepEqual(await f.restart().handleConnectWebhook(eventId, accountId), { received: true, duplicate: true });
  const submitted = await record(pending.id);
  assert.equal(submitted.status, 'submitted');
  assert.equal(submitted.version, pending.version + 1);
  assert.deepEqual(submitted.public_data, pending.public_data);
  assert.deepEqual(submitted.files, pending.files);
  const audits = (await db.query(`select actor_id,actor_type,source,previous_status,action,version
    from private.dopmi_rescue_history where record_id=$1 and action='stripe_ready'`, [pending.id])).rows;
  assert.deepEqual(audits, [{ actor_id: null, actor_type: 'system', source: 'stripe_connect_ready',
    previous_status: 'pending_stripe', action: 'stripe_ready', version: submitted.version }]);
  assert.deepEqual(f.state.accounts.at(-1).pending_stripe_sync,
    { source: 'stripe_connect_ready', promoted_count: 1, deferred_count: 0, deferred: [] });
  const completed = await job();
  assert.equal(completed.id, first.id);
  assert.equal(completed.attempts, 1);
  assert.deepEqual(completed.payload, context());
  assert.equal(f.state.stripe.length, 2);
  assert.equal(f.state.operations.filter(call => call.operation === 'connect_save').length, 2);
  assert.deepEqual(f.state.operations.filter(call => call.operation === 'connect_save').at(-1).data,
    { actor: rescuer, account_id: accountId, transfers_enabled: true, payouts_enabled: true, details_submitted: true });
  assert.equal(JSON.stringify({ job: completed, logs: f.state.logs }).includes('private_account_sentinel'), false);
  assert.deepEqual(await financialState(), { donations: 0, financial_jobs: 0, method_snapshots: 0 });
});

for (const failure of ['read', 'save', 'finish']) {
  test(`Connect recovers a lost ${failure} response with a persisted context and no duplicate promotion`, async () => {
    const pending = await pendingCase();
    const f = serviceFixture({ failure });
    await assert.rejects(f.service.handleConnectWebhook(eventId, accountId), { code: 'processor_unavailable' });
    const first = await job();
    assert.deepEqual(first.payload, context());
    assert.equal(first.status, failure === 'finish' ? 'done' : 'ready');
    assert.equal((await record(pending.id)).status, failure === 'read' ? 'pending_stripe' : 'submitted');
    if (failure !== 'finish') await readyForRetry();
    const result = await f.restart().handleConnectWebhook(eventId, accountId);
    assert.equal(result.received, true);
    assert.equal(result.duplicate, failure === 'finish' ? true : undefined);
    const last = await job();
    assert.equal(last.id, first.id);
    assert.equal(last.status, 'done');
    assert.equal(last.attempts, failure === 'finish' ? 1 : 2);
    assert.deepEqual(last.payload, context());
    assert.equal((await record(pending.id)).version, pending.version + 1);
    assert.equal((await db.query("select count(*)::int count from private.dopmi_rescue_history where record_id=$1 and action='stripe_ready'", [pending.id])).rows[0].count, 1);
    assert.deepEqual(await financialState(), { donations: 0, financial_jobs: 0, method_snapshots: 0 });
    assert.ok(f.state.stripe.every(call => call.path === `accounts/${accountId}`));
  });
}

test('a fresh worker resumes an enqueued context or an expired lease using the same durable job', async () => {
  for (const claimed of [false, true]) {
    const id = claimed ? 'evt_RestartClaimed' : 'evt_RestartEnqueued';
    await rpc('connect_event_enqueue', { event_id: id, event_account: accountId });
    if (claimed) {
      const lease = await rpc('claim', { job_key: id });
      assert.equal(lease.status, 'running');
      await db.query("update private.dopmi_payment_jobs set lease_until=now()-interval '1 second' where id=$1", [lease.id]);
    }
    const first = await job(id);
    const f = serviceFixture();
    assert.deepEqual(await f.restart().work(1), { processed: 1, failed: 0 });
    const last = await job(id);
    assert.equal(last.id, first.id);
    assert.equal(last.status, 'done');
    assert.equal(last.attempts, claimed ? 2 : 1);
    assert.deepEqual(last.payload, context(id));
    assert.deepEqual(f.state.stripe.map(call => call.path), [`accounts/${accountId}`]);
  }
  assert.deepEqual(await financialState(), { donations: 0, financial_jobs: 0, method_snapshots: 0 });
});

test('an unknown account is a completed harmless event without any Stripe read or Connect save', async () => {
  const before = await account();
  const f = serviceFixture();
  assert.deepEqual(await f.service.handleConnectWebhook(eventId, 'acct_unknown'), { received: true });
  assert.equal((await job()).status, 'done');
  assert.deepEqual(f.state.stripe, []);
  assert.equal(f.state.operations.some(call => call.operation === 'connect_save'), false);
  assert.deepEqual(await account(), before);
  assert.deepEqual(await financialState(), { donations: 0, financial_jobs: 0, method_snapshots: 0 });
});

test('malformed durable contexts and forged claimed payloads never reach Events or financial ports', async () => {
  const f = serviceFixture();
  for (const payload of [
    { event_id: eventId, event_scope: scope }, { event_account: accountId, event_scope: scope },
    { ...context(), event_scope: 'payment_intent_succeeded' },
    { ...context(), event_id: null }, { ...context(), event_account: 123 },
    { ...context(), type: 'payment_intent.succeeded' },
  ]) await assert.rejects(f.service.processEvent(payload), PaymentError);
  assert.deepEqual(f.state.operations, []);
  assert.deepEqual(f.state.stripe, []);
  for (const patch of [{ kind: 'transfer' }, { payload: { ...context(), event_account: secondAccount } },
    { payload: { ...context(), extra: 'forged' } }, { payload: { event_id: eventId } }]) {
    const calls = [];
    const service = paymentService({ expectedLivemode: true, logger: {},
      rpc: async (operation, data) => {
        calls.push({ operation, data });
        if (operation === 'connect_event_enqueue') return {};
        assert.equal(operation, 'claim'); return { kind: 'event', payload: context(), ...patch };
      }, stripe: () => assert.fail('forged context cannot reach Stripe'),
    });
    await assert.rejects(service.handleConnectWebhook(eventId, accountId), { code: 'connect_event_context_invalid' });
    assert.deepEqual(calls.map(call => call.operation), ['connect_event_enqueue', 'claim']);
  }
});

test('an inconsistent server-owned lookup cannot redirect an Account read or save another owner', async () => {
  for (const binding of [{}, { account_id: secondAccount, owner_id: rescuer },
    { account_id: accountId, owner_id: null }, { account_id: accountId, owner_id: 'editable-user-metadata' }]) {
    const operations = [];
    const service = paymentService({ expectedLivemode: true, logger: {},
      rpc: async (operation, data) => {
        operations.push(operation); assert.equal(operation, 'lookup_account');
        assert.deepEqual(data, { account_id: accountId }); return binding;
      }, stripe: () => assert.fail('inconsistent lookup cannot reach Stripe'),
    });
    await assert.rejects(service.processEvent(context()), { code: 'connect_account_mismatch' });
    assert.deepEqual(operations, ['lookup_account']);
  }
});

test('Connect current Account evidence requires the exact identity and optional strict financial mode before saving', async () => {
  for (const live of [false, true]) {
    for (const patch of [{ object: 'customer' }, { id: secondAccount }, { livemode: !live },
      { livemode: 'true' }, { livemode: null }]) {
      const before = await account();
      const f = serviceFixture({ live });
      f.state.mutate = value => ({ ...value, ...patch });
      await assert.rejects(f.service.processEvent(context()), { code: 'connect_account_mismatch' });
      assert.equal(f.state.operations.some(call => call.operation === 'connect_save'), false);
      assert.deepEqual(await account(), before);
    }
    const f = serviceFixture({ live });
    f.state.mutate = value => ({ ...value, livemode: live });
    assert.deepEqual(await f.service.processEvent(context()), []);
    assert.equal(f.state.operations.filter(call => call.operation === 'connect_save').length, 1);
    await db.query('update private.dopmi_connect_accounts set transfers_enabled=false,payouts_enabled=false,details_submitted=false where owner_id=$1', [rescuer]);
  }
});

test('the legacy event-only route keeps its Events GET and existing Account refresh behavior', async () => {
  const paths = [], operations = [];
  const service = paymentService({ expectedLivemode: true, logger: {},
    rpc: async (operation, data) => { operations.push(operation); return rpc(operation, data); },
    stripe: async path => {
      paths.push(path);
      if (path === `events/${eventId}`) return { id: eventId, livemode: true,
        type: 'account.updated', data: { object: { id: accountId } } };
      assert.equal(path, `accounts/${accountId}`);
      return { object: 'account', id: accountId, capabilities: { transfers: 'active' }, payouts_enabled: true, details_submitted: true };
    },
  });
  assert.deepEqual(await service.handleWebhook(eventId), { received: true });
  assert.deepEqual((await job()).payload, { event_id: eventId });
  assert.deepEqual(paths, [`events/${eventId}`, `accounts/${accountId}`]);
  assert.equal(operations.includes('enqueue'), true);
  assert.equal(operations.includes('connect_event_enqueue'), false);
  assert.deepEqual(await financialState(), { donations: 0, financial_jobs: 0, method_snapshots: 0 });
});
