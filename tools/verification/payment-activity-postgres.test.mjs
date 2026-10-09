import { before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import pg from 'pg';
import { registerPaymentActivitySqlCases } from './payment-activity-dde1-sql-cases.mjs';

// Explicit opt-in: only the isolated local stack, never DEV or the prior stack.
const connectionString = process.env.DOPMI_LOCAL_DATABASE_URL;
assert.ok(connectionString, 'DOPMI_LOCAL_DATABASE_URL is required');
const url = new URL(connectionString);
assert.ok(['postgres:', 'postgresql:'].includes(url.protocol));
assert.equal(url.hostname, '127.0.0.1');
assert.equal(url.port, '54382');
const client = new pg.Client({ connectionString });
// pg accepts query-string host/port overrides. Validate its effective destination.
assert.equal(client.connectionParameters.host, '127.0.0.1');
assert.equal(client.connectionParameters.port, 54382);
const db = {
  query: (sql, values) => client.query(sql, values),
  exec: sql => client.query(sql),
};
const donor = randomUUID(), rescuer = randomUUID(), other = randomUUID(), staff = randomUUID();
const verification = randomUUID(), supportCase = randomUUID(), expense = randomUUID();
let transaction = false;

before(async () => {
  await client.connect();
  await client.query('set statement_timeout=15000');
  const result = await client.query("select to_regprocedure('public.dopmi_payment_activity(boolean,timestamp with time zone,text,uuid,integer)') is not null as present");
  assert.equal(result.rows[0].present, true);
});

beforeEach(async () => {
  await client.query('begin');
  transaction = true;
  for (const id of [donor, rescuer, other, staff]) {
    await client.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      values($1,$2,now(),$3::jsonb)`, [id, `dde1-ledger-${id}@example.invalid`, JSON.stringify({
      display_name: 'Prueba QA', terms_accepted: true, terms_version: 'development-2026-09-13',
    })]);
    await client.query('update public.profiles set terms_accepted_at=now() where id=$1', [id]);
  }
  await client.query('insert into private.admin_memberships(user_id) values($1)', [staff]);
  await client.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) values
    ($1,$4,'verification','approved','{"public_name":"Refugio QA"}',null,0),
    ($2,$4,'case','approved','{"pet_name":"Luna QA"}',null,0),
    ($3,$4,'expense','approved','{"title":"Medicamentos QA"}',$2,12000)`, [verification, supportCase, expense, rescuer]);
  await client.query(`insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
    values($1,'acct_dde1_local_qa',true,true)`, [rescuer]);
});

afterEach(async () => {
  if (transaction) {
    await client.query('rollback');
    transaction = false;
  }
});

after(async () => {
  try {
    if (transaction) await client.query('rollback');
    const result = await client.query('select count(*)::int as remaining from auth.users where id=any($1::uuid[])', [[donor, rescuer, other, staff]]);
    assert.equal(result.rows[0].remaining, 0, 'Every fixture must roll back');
  } finally {
    await client.end();
  }
});

registerPaymentActivitySqlCases(() => db, { donor, rescuer, other, staff, expense });
