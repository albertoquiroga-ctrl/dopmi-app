import { test } from 'node:test';
import assert from 'node:assert/strict';

export function registerAdoptionUpdateSqlCases(getDb, { donor, rescuer, other }) {
  test('889 case size is explicit, persists for old clients, and stays private until approval',async()=>{
    const db=getDb(); await actor(db,rescuer);
    const saved=await value(db,"select dopmi_save_rescue('case','{\"pet_name\":\"Luna\",\"size\":\"small\"}','{}','[]') as value");
    assert.equal(saved.public_data.size,'small');
    const legacy=await value(db,"select dopmi_save_rescue('case','{\"pet_name\":\"Luna\"}','{}','[]',$1,$2) as value",[saved.id,saved.version]);
    assert.equal(legacy.public_data.size,'small');
    await db.exec('savepoint invalid_size');
    await assert.rejects(db.query("select dopmi_save_rescue('case','{\"size\":\"tiny\"}','{}','[]')"),e=>e.code==='22023');
    await db.exec('rollback to savepoint invalid_size');
    await actor(db,other); await assert.rejects(db.query('select dopmi_rescue_detail($1)',[saved.id]),e=>e.code==='42501');
  });
  const post = '89000000-0000-4000-8000-000000000001';
  const actor = async (db, id) => {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);
    await db.exec('set local role authenticated');
  };
  const value = async (db, sql, params=[]) => (await db.query(sql,params)).rows[0].value;
  const seed = async db => db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status,sex,personality) values($1,$2,'Luna','published','female',array['calm'])",[post,rescuer]);

  test('889 contact confirms exactly one real introduction and notification across retries',async()=>{
    const db=getDb(); await seed(db); await actor(db,donor);
    const first=await value(db,'select dopmi_start_adoption_contact($1) as value',[post]);
    assert.equal(await value(db,'select dopmi_start_adoption_contact($1) as value',[post]),first);
    const detail=await value(db,'select dopmi_thread_detail($1) as value',[first]);
    assert.equal(detail.participant_name,'Prueba');
    assert.equal(detail.case_id,null);
    assert.equal((await db.query('select body from dopmi_messages where thread_id=$1',[first])).rows[0].body,
      '¡Hola! 👋 Me encantó Luna, me gustaría saber un poquito más sobre ella 🐾');
    await db.exec('reset role');
    assert.equal((await db.query('select count(*)::int n from dopmi_messages where thread_id=$1',[first])).rows[0].n,1);
    assert.equal((await db.query('select count(*)::int n from dopmi_notifications where thread_id=$1',[first])).rows[0].n,1);
  });
  test('889 existing conversation never receives a historical introduction',async()=>{
    const db=getDb(); await seed(db); await actor(db,donor);
    const id=await value(db,'select dopmi_start_thread($1) as value',[post]);
    assert.equal(await value(db,'select dopmi_start_adoption_contact($1) as value',[post]),id);
    assert.equal((await db.query('select count(*)::int n from dopmi_messages where thread_id=$1',[id])).rows[0].n,0);
  });
  test('889 private thread detail rejects third parties and owner self contact',async()=>{
    const db=getDb(); await seed(db); await actor(db,donor);
    const id=await value(db,'select dopmi_start_adoption_contact($1) as value',[post]);
    await actor(db,other);
    await db.exec('savepoint denied');
    await assert.rejects(db.query('select dopmi_thread_detail($1)',[id]),e=>e.code==='42501');
    await db.exec('rollback to savepoint denied'); await actor(db,rescuer);
    await assert.rejects(db.query('select dopmi_start_adoption_contact($1)',[post]),e=>e.code==='22023');
  });
  test('889 new adoption fields persist, old clients preserve them, and six photos are private',async()=>{
    const db=getDb(); await seed(db); await actor(db,rescuer);
    const photos=Array.from({length:6},(_,i)=>`${rescuer}/${post}/${i}.jpg`);
    const payload={personality:['dormilon','protector','obediente'],age_band:'adult',coexistence:['children','pets','apartment','yard','first_time','experienced'],photos};
    const saved=await value(db,'select dopmi_save_adoption($1::jsonb,$2,1) as value',[JSON.stringify(payload),post]);
    assert.equal(saved.photos.length,6); assert.equal(saved.age_band,'adult'); assert.equal(saved.coexistence.length,6);
    const old=await value(db,"select dopmi_save_adoption('{}',$1,2) as value",[post]);
    assert.equal(old.age_band,'adult'); assert.deepEqual(old.coexistence,saved.coexistence); assert.deepEqual(old.personality,saved.personality);
    await db.exec('reset role; set local role anon');
    assert.equal((await value(db,"select dopmi_discovery('{}') as value")).total,0);
    await db.exec('reset role'); await actor(db,rescuer);
    await assert.rejects(db.query('select dopmi_save_adoption($1::jsonb,$2,3)',[JSON.stringify({...payload,photos:[...photos,`${rescuer}/${post}/7.jpg`]}),post]),e=>e.code==='23514');
  });
  test('889 calm alias discovery remains compatible and validation rejects invented home data',async()=>{
    const db=getDb(); await seed(db); await db.exec('set local role anon');
    assert.equal((await value(db,"select dopmi_discovery('{\"personality\":[\"tranquilo\"]}') as value")).total,1);
    await actor(db,rescuer);
    await assert.rejects(db.query("select dopmi_save_adoption('{\"coexistence\":[\"inventado\"]}',$1,1)",[post]),e=>e.code==='22023');
  });
  test('889 inbox totals precede group and conversation pagination, with zero-chat groups and private history',async()=>{
    const db=getDb(); await seed(db);
    await db.query(`insert into dopmi_adoptions(owner_id,pet_name,status)
      select $1,'Mascota '||i,'published' from generate_series(1,24) i`,[rescuer]);
    await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      select ('89100000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'adopter'||i||'@example.test',now(),
      '{"display_name":"Adoptante","terms_accepted":true,"terms_version":"development-2026-09-13"}' from generate_series(1,24) i`);
    await db.query(`insert into dopmi_threads(post_id,owner_id,adopter_id,pet_name)
      select $1,$2,('89100000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'Luna' from generate_series(1,24) i`,[post,rescuer]);
    await actor(db,rescuer);
    const inbox=await value(db,'select dopmi_rescuer_inbox() as value');
    assert.equal(inbox.total,25); assert.equal(inbox.items.length,20);
    const luna=inbox.items.find(g=>g.id===post); assert.equal(luna.thread_count,24); assert.equal(luna.threads.length,20);
    const next=await value(db,'select dopmi_rescuer_group_threads($1,2) as value',[post]); assert.equal(next.total,24); assert.equal(next.items.length,4);
    const last=await value(db,'select dopmi_rescuer_inbox(2) as value'); assert.equal(last.items.length,5);
    assert.equal(new Set([...inbox.items,...last.items].map(g=>g.id)).size,25);
    await db.exec('reset role'); await db.query("update dopmi_threads set status='closed' where post_id=$1",[post]);
    await actor(db,rescuer);
    const history=await value(db,'select dopmi_rescuer_inbox(1,20,true) as value'); assert.equal(history.total,1); assert.equal(history.items[0].thread_count,24);
    await actor(db,other); assert.equal((await value(db,'select dopmi_rescuer_inbox() as value')).total,0);
    await assert.rejects(db.query('select dopmi_rescuer_group_threads($1)',[post]),e=>e.code==='42501');
  });
  test('889 removing expense draft rejects reviewed records and keeps receipts out of the case',async()=>{
    const db=getDb(); await actor(db,rescuer);
    const parent=await value(db,"select dopmi_save_rescue('case','{\"pet_name\":\"Luna\"}','{}','[]') as value");
    const expense=await value(db,"select dopmi_save_rescue('expense','{\"title\":\"Consulta\"}','{\"amount_cents\":\"12000\",\"vendor\":\"Vet\",\"paid_on\":\"2026-10-01\",\"receipt_reference\":\"A1\"}','[]',null,null,$1) as value",[parent.id]);
    assert.equal(expense.parent_id,parent.id);
    await db.query('select dopmi_remove_draft_expense($1,$2)',[expense.id,expense.version]);
    assert.equal((await db.query('select count(*)::int n from dopmi_rescue_records where id=$1',[expense.id])).rows[0].n,0);
    assert.deepEqual(parent.private_data,{});
    const approved='71000000-0000-4000-8000-000000000003';
    assert.equal((await db.query('select status from dopmi_rescue_records where id=$1',[approved])).rows[0].status,'approved');
    await assert.rejects(db.query('select dopmi_remove_draft_expense($1,1)',[approved]),/borrador/);
  });
}
