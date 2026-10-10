import { test } from 'node:test';
import assert from 'node:assert/strict';

export function registerChatPhotoSqlCases(getDb, { donor, rescuer, other, staff }) {
  async function role(db, id, name = 'authenticated') {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id]);
    await db.exec(`set local role ${name}`);
  }
  async function fixture(db) {
    const post = 'dd080000-0000-4000-8000-000000000001';
    const thread = 'dd080000-0000-4000-8000-000000000002';
    const message = 'dd080000-0000-4000-8000-000000000003';
    const path = `${donor}/${thread}/${message}.jpg`;
    await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Prueba','published')", [post, rescuer]);
    await db.query('insert into public.dopmi_threads(id,post_id,owner_id,adopter_id,pet_name) values($1,$2,$3,$4,$5)', [thread, post, rescuer, donor, 'Prueba']);
    return { thread, message, path };
  }
  async function send(db, f, body = '') {
    return (await db.query('select public.dopmi_send_message_v2($1,$2,$3,$4) value', [f.thread, f.message, body, f.path])).rows[0].value;
  }
  async function rejected(db, action, pattern) {
    await db.exec('savepoint chat_negative');
    try { await assert.rejects(action, pattern); }
    finally { await db.exec('rollback to chat_negative; release chat_negative'); }
  }
  async function access(db, path, operation = 'read') {
    return (await db.query('select public.dopmi_chat_photo_access($1,$2) value', [path, operation])).rows[0].value;
  }
  test('dde1 chat pending photos are private; published photos remain participant-only and immutable', async () => {
    const db = getDb(), f = await fixture(db);
    await role(db, donor);
    await db.query("insert into storage.objects(bucket_id,name,owner_id) values('dopmi-chat-photos',$1,$2)", [f.path, donor]);
    assert.equal(await access(db, f.path), true);
    await role(db, rescuer);
    assert.equal(await access(db, f.path), false);
    assert.equal((await db.query("select count(*)::int n from storage.objects where bucket_id='dopmi-chat-photos'")).rows[0].n, 0);
    await role(db, donor);
    const message = await send(db, f);
    assert.equal(message.attachment_path, f.path);
    assert.equal(message.body, '');
    assert.deepEqual(await send(db, f), message);
    assert.equal(await access(db, f.path, 'delete'), false);
    assert.equal(await access(db, f.path, 'insert'), false);
    await rejected(db, () => send(db, f, 'Contenido distinto'), /identificador/);
    await db.query("delete from storage.objects where bucket_id='dopmi-chat-photos' and name=$1", [f.path]);
    assert.equal((await db.query('select count(*)::int n from storage.objects where name=$1', [f.path])).rows[0].n, 1);
    for (const actor of [rescuer, other, staff]) {
      await role(db, actor);
      assert.equal(await access(db, f.path), actor === rescuer);
      assert.equal((await db.query('select count(*)::int n from public.dopmi_messages where id=$1', [f.message])).rows[0].n, actor === rescuer ? 1 : 0);
      if (actor !== rescuer) await rejected(db, () => send(db, f), /disponible/);
    }
    await role(db, '', 'anon');
    await rejected(db, () => send(db, f), /permission denied/);
  });
  test('dde1 chat validates exact uploaded path; closed threads allow reading and stable retries only', async () => {
    const db = getDb(), f = await fixture(db);
    await role(db, donor);
    await rejected(db, () => send(db, f), /foto/);
    await db.query("insert into storage.objects(bucket_id,name,owner_id) values('dopmi-chat-photos',$1,$2)", [f.path, donor]);
    await rejected(db, () => send(db, { ...f, path: f.path.replace(donor, rescuer) }), /foto/);
    const first = await send(db, f, 'Foto de prueba');
    await db.exec('reset role');
    await db.query("update public.dopmi_threads set status='closed' where id=$1", [f.thread]);
    await role(db, donor);
    assert.deepEqual(await send(db, f, 'Foto de prueba'), first);
    const next = { ...f, message: 'dd080000-0000-4000-8000-000000000004' };
    await rejected(db, () => send(db, next, 'Nuevo mensaje'), /cerrada/);
    await role(db, rescuer);
    assert.equal(await access(db, f.path), true);
    const history = (await db.query('select public.dopmi_thread_messages($1) value', [f.thread])).rows[0].value;
    assert.equal(history[0].attachment_path, f.path);
  });
}
