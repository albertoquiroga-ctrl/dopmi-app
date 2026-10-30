import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

let db, original;
const owner = '51000000-0000-4000-8000-000000000001';
const other = '51000000-0000-4000-8000-000000000002';
const legacy = `dopmi-account-${owner}`;
const key = () => `${legacy}-retry-${randomUUID()}`;
async function rejected(action, pattern) {
  await db.exec('savepoint expected_failure');
  await assert.rejects(action(), pattern);
  await db.exec('rollback to savepoint expected_failure');
}
async function audit(retryKey, { previous = legacy, stale = false, failure = 'platform_profile_incomplete' } = {}) {
  await db.query(`insert into private.dopmi_connect_creation_recoveries
    (owner_id,previous_key,previous_started_at,retry_key,retry_started_at,failed_request_id,
     failure_code,non_creation_verified_at,evidence_sha256,authorization_reference)
    select owner_id,$2,create_started_at,$3,now(),'req_synthetic',
      $5,now()-$4::interval,repeat('a',64),'synthetic-approved-operation'
    from private.dopmi_connect_accounts where owner_id=$1`, [owner, previous, retryKey, stale ? '6 minutes' : '0 seconds', failure]);
}
async function rotate(retryKey) {
  await db.query(`update private.dopmi_connect_accounts set create_idempotency_key=$2,
    create_started_at=now() where owner_id=$1`, [owner,retryKey]);
}
before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema private; create table public.profiles(id uuid primary key);
    create table private.dopmi_connect_accounts (
      owner_id uuid primary key references public.profiles(id) on delete restrict,
      account_id text unique, transfers_enabled boolean not null default false,
      payouts_enabled boolean not null default false, details_submitted boolean not null default false,
      created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
      create_started_at timestamptz);
    alter table private.dopmi_connect_accounts enable row level security;`);
  await db.query('insert into public.profiles(id) values($1),($2)', [owner,other]);
  await db.query("insert into private.dopmi_connect_accounts(owner_id,create_started_at) values($1,now()-interval '10 minutes')", [owner]);
  original = (await db.query('select to_jsonb(a) value from private.dopmi_connect_accounts a')).rows[0].value;
  await db.exec(await readFile(new URL('../../supabase/migrations/20261030215241_connect_creation_recovery.sql',import.meta.url),'utf8'));
});
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

test('migration is inert and preserves legacy row, rights and creation state', async () => {
  const row = (await db.query('select to_jsonb(a) value from private.dopmi_connect_accounts a')).rows[0].value;
  assert.equal(row.create_idempotency_key,null);
  delete row.create_idempotency_key; assert.deepEqual(row,original);
  assert.equal((await db.query('select count(*) n from private.dopmi_connect_creation_recoveries')).rows[0].n,0);
});
test('new legacy accounts still start normally but cannot insert a recovery key', async () => {
  await rejected(()=>db.query('insert into private.dopmi_connect_accounts(owner_id,create_idempotency_key) values($1,$2)',
    [other,`dopmi-account-${other}-retry-${randomUUID()}`]), /clave original/);
  await db.query('insert into private.dopmi_connect_accounts(owner_id) values($1)',[other]);
  await db.query('update private.dopmi_connect_accounts set create_started_at=now() where owner_id=$1',[other]);
});
test('key rotation or time reset without reconciliation history aborts', async () => {
  await rejected(()=>rotate(key()),/sin conciliar/);
  await rejected(()=>db.query('update private.dopmi_connect_accounts set create_started_at=now() where owner_id=$1',[owner]),/sin recuperación auditada/);
});
test('one audited recovery preserves the original key/time and makes the new key durable', async () => {
  const retryKey=key(); await audit(retryKey); await rotate(retryKey);
  const h=(await db.query('select previous_key,previous_started_at,retry_key from private.dopmi_connect_creation_recoveries')).rows[0];
  assert.equal(h.previous_key,legacy); assert.equal(h.previous_started_at.toISOString(),new Date(original.create_started_at).toISOString());
  assert.equal(h.retry_key,retryKey);
  assert.equal((await db.query('select create_idempotency_key k from private.dopmi_connect_accounts')).rows[0].k,retryKey);
  await db.query('update private.dopmi_connect_accounts set create_started_at=create_started_at where owner_id=$1',[owner]);
  await rejected(()=>audit(key()),/unique constraint/);
});
test('a mismatched previous key, stale reconciliation and uncertain failure cannot authorize rotation', async () => {
  const retryKey=key(); await audit(retryKey,{previous:'another-attempt'});
  await rejected(()=>rotate(retryKey),/sin conciliar/);
  await rejected(()=>audit(key(),{stale:true}),/check constraint/);
  await rejected(()=>audit(key(),{failure:'uncertain'}),/check constraint/);
});
test('cross-actor keys and activation with changed financial fields are rejected', async () => {
  await rejected(()=>audit(`dopmi-account-${other}-retry-${randomUUID()}`),/check constraint/);
  const retryKey=key(); await audit(retryKey);
  await rejected(()=>db.query(`update private.dopmi_connect_accounts set create_idempotency_key=$2,
    create_started_at=now(),details_submitted=true where owner_id=$1`,[owner,retryKey]),/sin conciliar/);
});
test('binding after recovery works and a bound account cannot recover again', async () => {
  const retryKey=key(); await audit(retryKey); await rotate(retryKey);
  await db.query("update private.dopmi_connect_accounts set account_id='acct_synthetic',details_submitted=true where owner_id=$1",[owner]);
  const second=key(); await audit(second,{previous:retryKey});
  await rejected(()=>rotate(second),/sin conciliar/);
});
test('history is immutable and inaccessible to client and service roles', async () => {
  await audit(key());
  await rejected(()=>db.exec('delete from private.dopmi_connect_creation_recoveries'),/historial/);
  for(const role of ['anon','authenticated','service_role']) {
    await db.exec(`set local role ${role}`);
    await rejected(()=>db.exec('select * from private.dopmi_connect_creation_recoveries'),/permission denied/);
    await rejected(()=>db.query('update private.dopmi_connect_accounts set create_idempotency_key=$1',[key()]),/permission denied/);
    await db.exec('reset role');
  }
});
