import { test } from 'node:test';
import assert from 'node:assert/strict';

export function registerInboxSelectorSqlCases(getDb, { donor, rescuer, other }) {
  test('dde1 active selector metadata preserves retired conversations and owner isolation', async () => {
    const db = getDb();
    const post = 'dd010000-0000-4000-8000-000000000001';
    const draft = 'dd010000-0000-4000-8000-000000000002';
    await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Luna','published')", [post, rescuer]);
    await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values($1,$2,'Borrador','draft')", [draft, rescuer]);
    await db.query("insert into public.dopmi_threads(post_id,owner_id,adopter_id,pet_name) values($1,$2,$3,'Luna')", [post, rescuer, donor]);
    const actor = async id => {
      await db.exec('reset role');
      await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id]);
      await db.exec('set local role authenticated');
    };
    const inbox = async history => (await db.query('select public.dopmi_rescuer_inbox(1,20,$1) value', [history])).rows[0].value;
    await actor(rescuer);
    assert.equal((await inbox(false)).items.find(p => p.id === post).selector_active, true);
    assert.equal((await inbox(false)).items.find(p => p.id === draft).selector_active, false);
    await db.exec('reset role');
    await db.query("update public.dopmi_adoptions set status='archived' where id=$1", [post]);
    await actor(rescuer);
    assert.equal((await inbox(false)).items.some(p => p.id === post), false);
    const retired = (await inbox(true)).items.find(p => p.id === post);
    assert.equal(retired.selector_active, false);
    assert.equal(retired.thread_count, 1);
    assert.equal(retired.threads.length, 1);
    await db.exec('reset role');
    await db.query("update public.dopmi_threads set status='closed' where post_id=$1", [post]);
    await actor(rescuer);
    assert.equal((await inbox(true)).items.find(p => p.id === post).selector_active, false);
    await actor(other);
    assert.equal((await inbox(true)).items.some(p => p.id === post), false);
  });
}
