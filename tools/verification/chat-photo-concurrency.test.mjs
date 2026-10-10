import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { setTimeout as pause } from 'node:timers/promises';
import { writeFile } from 'node:fs/promises';
import pg from 'pg';

test('chat publication and pending-photo deletion serialize in both orders on real PostgreSQL', {
  skip: !process.env.DOPMI_LOCAL_DATABASE_URL,
}, async () => {
  const connectionString = process.env.DOPMI_LOCAL_DATABASE_URL;
  const url = new URL(connectionString);
  assert.equal(url.hostname, '127.0.0.1');
  assert.equal(url.port, '54382'); // Only the isolated dde1 local stack.
  const control = new pg.Client({ connectionString });
  const sending = new pg.Client({ connectionString });
  const deleting = new pg.Client({ connectionString });
  const owner = randomUUID(), adopter = randomUUID();
  const fixtures = [];
  const journal = { environment: 'dopmi-dde1-local', actors: [owner, adopter], fixtures, cleanup: false };
  const record = async () => {
    if (process.env.DOPMI_QA_JOURNAL) await writeFile(process.env.DOPMI_QA_JOURNAL, JSON.stringify(journal));
  };
  async function actor(client) {
    await client.query('begin');
    // Storage API sets this transaction context before its metadata deletion.
    // This test exercises SQL authorization/locking, not the HTTP Storage API.
    await client.query("set local storage.allow_delete_query='true'");
    await client.query("select set_config('request.jwt.claim.sub',$1,true)", [adopter]);
    await client.query('set local role authenticated');
  }
  async function blocked(waiter, blocker) {
    const deadline = Date.now() + 10000;
    while (Date.now() < deadline) {
      const result = await control.query('select $2::int=any(pg_blocking_pids($1::int)) value', [waiter.processID, blocker.processID]);
      if (result.rows[0].value) return;
      await pause(30);
    }
    throw new Error('Expected database lock was not observed');
  }
  async function fixture() {
    const f = { post: randomUUID(), thread: randomUUID(), message: randomUUID() };
    f.path = `${adopter}/${f.thread}/${f.message}.jpg`;
    fixtures.push(f);
    await record();
    await control.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Prueba concurrente','published')", [f.post, owner]);
    await control.query("insert into public.dopmi_threads(id,post_id,owner_id,adopter_id,pet_name) values($1,$2,$3,$4,'Prueba concurrente')", [f.thread, f.post, owner, adopter]);
    await control.query("insert into storage.objects(bucket_id,name,owner_id) values('dopmi-chat-photos',$1,$2)", [f.path, adopter]);
    return f;
  }
  const send = f => sending.query('select public.dopmi_send_message_v2($1,$2,$3,$4) value', [f.thread, f.message, '', f.path]);
  const discard = f => deleting.query("delete from storage.objects where bucket_id='dopmi-chat-photos' and name=$1 returning name", [f.path]);
  try {
    await Promise.all([control.connect(), sending.connect(), deleting.connect()]);
    await control.query('set statement_timeout=15000');
    await sending.query('set statement_timeout=15000');
    await deleting.query('set statement_timeout=15000');
    const volatility = (await control.query("select provolatile from pg_proc where oid='public.dopmi_chat_photo_access(text,text)'::regprocedure")).rows[0].provolatile;
    assert.equal(volatility, 'v');
    await record();
    for (const id of [owner, adopter]) {
      await control.query("insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,now(),$3::jsonb)",
        [id, `dde1-concurrency-${id}@example.invalid`, JSON.stringify({ display_name: 'Prueba QA', terms_accepted: true, terms_version: 'development-2026-09-13' })]);
      await control.query('update public.profiles set terms_accepted_at=now() where id=$1', [id]);
    }
    const first = await fixture();
    await actor(sending);
    await send(first); // Publish but keep the thread lock uncommitted.
    await actor(deleting);
    const blockedDelete = discard(first);
    await blocked(deleting, sending);
    await sending.query('commit');
    assert.equal((await blockedDelete).rowCount, 0);
    await deleting.query('commit');
    assert.equal((await control.query('select count(*)::int n from public.dopmi_messages where id=$1', [first.message])).rows[0].n, 1);
    assert.equal((await control.query('select count(*)::int n from storage.objects where name=$1', [first.path])).rows[0].n, 1);

    const second = await fixture();
    await actor(deleting);
    assert.equal((await discard(second)).rowCount, 1); // Delete, still holding the thread lock.
    await actor(sending);
    const blockedSend = send(second).then(() => null, error => error);
    await blocked(sending, deleting);
    await deleting.query('commit');
    assert.equal((await blockedSend)?.code, '22023');
    await sending.query('rollback');
    assert.equal((await control.query('select count(*)::int n from public.dopmi_messages where id=$1', [second.message])).rows[0].n, 0);
    assert.equal((await control.query('select count(*)::int n from storage.objects where name=$1', [second.path])).rows[0].n, 0);
  } finally {
    try {
    await Promise.allSettled([sending.query('rollback'), deleting.query('rollback')]);
    await control.query("set storage.allow_delete_query='true'");
    for (const f of fixtures) {
      await control.query('delete from public.dopmi_messages where id=$1', [f.message]);
      await control.query("delete from storage.objects where bucket_id='dopmi-chat-photos' and name=$1", [f.path]);
      await control.query('delete from public.dopmi_threads where id=$1', [f.thread]);
      await control.query('delete from public.dopmi_adoptions where id=$1 and owner_id=$2', [f.post, owner]);
    }
    await control.query('delete from auth.users where id=any($1::uuid[])', [[owner, adopter]]);
    journal.cleanup = true;
    await record();
    } finally {
    await Promise.allSettled([control.end(), sending.end(), deleting.end()]);
    }
  }
});
