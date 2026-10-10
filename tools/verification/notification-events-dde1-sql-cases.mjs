import { test } from 'node:test';
import assert from 'node:assert/strict';

export function registerNotificationEventsSqlCases(getDb, { donor, rescuer, other, staff, expense }) {
  const role = async (db, actor, name = 'authenticated') => {
    await db.exec('reset role'); await db.query("select set_config('request.jwt.claim.sub',$1,true)", [actor]); await db.exec(`set local role ${name}`);
  };
  const denied = async (db, operation, pattern) => {
    await db.exec('savepoint notification_error');
    try { await assert.rejects(operation, pattern); } finally { await db.exec('rollback to savepoint notification_error; release savepoint notification_error'); }
  };
  const enroll = async (db, ...actors) => {
    for (const actor of actors) await db.query("insert into private.dopmi_notification_candidate_cohort(user_id,enabled,enabled_at) values($1,true,now())", [actor]);
  };
  const list = async db => (await db.query('select public.dopmi_notification_activity() value')).rows[0].value;
  test('dde1 financial notification cohort is default-off and cannot be self-enabled', async () => {
    const db = getDb(); const id = 'da079000-0000-4000-8000-000000000001';
    await db.query("insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,reserved_cents,payment_status,allocated_cents) values($1,$2,$3,$4,'Consulta','acct_test',$1,1011,20,0,'confirmed',900)", [id,donor,rescuer,expense]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind in ('contribution','guardian')")).rows[0].count, 0);
    for (const actor of [donor, rescuer, staff]) {
      await role(db, actor);
      await denied(db, () => db.query("insert into private.dopmi_notification_candidate_cohort(user_id,enabled,enabled_at) values($1,true,now())", [actor]), /permission denied/);
    }
    await db.exec('reset role');
    await enroll(db, donor);
    await db.query("update public.dopmi_donations set transfer_status='transferred',payment_status=payment_status where id=$1", [id]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='contribution'")).rows[0].count, 0);
    // Enrollment itself produces no replay of the already consumed event.
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='contribution'")).rows[0].count, 0);
    await db.query("update public.dopmi_donations set refund_status='pending' where id=$1", [id]);
    const notices = (await db.query("select user_id,target_kind from public.dopmi_notifications where kind='contribution'")).rows;
    assert.deepEqual(notices, [{user_id: donor, target_kind: 'history'}]);
    await db.query("update private.dopmi_notification_candidate_cohort set enabled=false where user_id=$1", [donor]);
    await db.query("update public.dopmi_donations set refund_status='refunded' where id=$1", [id]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='contribution'")).rows[0].count, 1);
    assert.equal((await db.query("select payment_status,refund_status from public.dopmi_donations where id=$1", [id])).rows[0].refund_status, 'refunded');
  });
  test('dde1 contribution notification producers are real, idempotent and own readable', async () => {
    const db = getDb(); await enroll(db, donor, rescuer); const donation = 'da070000-0000-4000-8000-000000000001';
    await db.query("insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,reserved_cents) values($1,$2,$3,$4,'Consulta','acct_test',$1,1011,20,991)", [donation, donor, rescuer, expense]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='contribution'")).rows[0].count, 0);
    await db.query("update public.dopmi_donations set payment_status='confirmed',allocated_cents=900 where id=$1", [donation]);
    await db.query("update public.dopmi_donations set payment_status='confirmed',allocated_cents=900 where id=$1", [donation]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='contribution'")).rows[0].count, 2);
    await role(db, donor); const sent = (await list(db)).items;
    assert.equal(sent.length, 1); assert.equal(sent[0].tone, 'positive'); assert.equal(sent[0].target_kind, 'history');
    const id = sent[0].id;
    const opened = (await db.query('select public.dopmi_notification_open($1) value', [id])).rows[0].value;
    assert.ok(opened.read_at); assert.equal(opened.available, true);
    for (const actor of [other, staff, rescuer]) {
      await role(db, actor);
      await denied(db, () => db.query('select public.dopmi_notification_open($1)', [id]), /Notificación no disponible/);
      assert.equal((await list(db)).items.some(n => n.id === id), false);
    }
    await role(db, rescuer); const received = (await list(db)).items[0];
    assert.equal(received.target_kind, 'received_history'); assert.equal(received.tone, 'pending');
    await role(db, '', 'anon'); await denied(db, () => list(db), /permission denied/);
  });
  test('dde1 real refund finish notifies receiver reversal after assignment becomes zero, once', async () => {
    const db = getDb(); await enroll(db,donor,rescuer);
    const donation = 'da077000-0000-4000-8000-000000000001';
    const job = 'da077000-0000-4000-8000-000000000002';
    const lease = 'da077000-0000-4000-8000-000000000003';
    await db.query("insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,stripe_fee_cents,net_cents,reserved_cents,payment_status,allocated_cents,transfer_status,stripe_transfer_id,stripe_charge_id) values($1,$2,$3,$4,'Consulta','acct_test',$1,1011,20,91,900,0,'confirmed',900,'transferred','tr_notificationFinish','ch_notificationFinish')", [donation,donor,rescuer,expense]);
    await db.query("insert into private.dopmi_payment_jobs(job_key,kind,donation_id,status) values($1,'transfer',$2,'done')", ['transfer:'+donation,donation]);
    await db.query("select public.dopmi_refund_adjustment('begin',$1::jsonb)", [JSON.stringify({donation_id:donation})]);
    await db.query("update private.dopmi_payment_jobs set id=$1,status='running',lease=$2,lease_until=now()+interval '5 minutes' where job_key=$3", [job,lease,'reversal:'+donation]);
    const finish = {job_id:job,lease,charge_id:'ch_notificationFinish',transfer_id:'tr_notificationFinish',refund_cents:1011,reversed_cents:900,reversal_id:'trr_notificationFinish',refund_id:'re_notificationFinish',refund_ids:['re_notificationFinish']};
    await db.query("select public.dopmi_refund_adjustment('finish',$1::jsonb)", [JSON.stringify(finish)]);
    await db.query("select public.dopmi_refund_adjustment('finish',$1::jsonb)", [JSON.stringify(finish)]);
    // A repeated processor-state update must not duplicate the reversal event.
    await db.query("update public.dopmi_donations set allocated_cents=0,payment_status='refunded',transfer_status='reversed' where id=$1", [donation]);
    assert.equal((await db.query('select allocated_cents from public.dopmi_donations where id=$1',[donation])).rows[0].allocated_cents, 0);
    await role(db,rescuer);
    const notices = (await list(db)).items.filter(n => n.title==='Una transferencia de +Apoyo fue revertida');
    assert.equal(notices.length,1); assert.equal(notices[0].tone,'negative');
    assert.equal(notices[0].target_kind,'received_history');
    assert.equal(notices[0].body,'Se revirtió una transferencia de $9.00 MXN. Consulta su estado en tu historial.');
  });
  test('dde1 own notification thumbnails and destinations are rechecked after withdrawal', async () => {
    const db = getDb(); const post = 'da070000-0000-4000-8000-000000000002'; const source = 'da070000-0000-4000-8000-000000000003';
    await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status,photos) values($1,$2,'Luna','published',array['approved/photo'])", [post, rescuer]);
    await db.query("insert into public.dopmi_notifications(user_id,kind,source_id,post_id,title) values($1,'review',$2,$3,'Aprobada')", [rescuer, source, post]);
    await role(db, rescuer); let item = (await list(db)).items[0];
    assert.equal(item.photo_path, 'approved/photo'); assert.equal(item.photo_purpose, 'adoption'); assert.equal(item.tone, 'positive');
    await db.exec('reset role'); await db.query("update public.dopmi_adoptions set status='draft',photos=array['private/new'] where id=$1", [post]);
    await role(db, rescuer); item = (await list(db)).items[0];
    assert.equal(item.photo_path, null); assert.equal(item.target_kind, 'post');
    await db.exec('reset role'); await db.query("update public.dopmi_notifications set target_kind='thread',target_id=$1 where id=$2", [post, item.id]);
    await role(db, rescuer); item = (await db.query('select public.dopmi_notification_open($1) value', [item.id])).rows[0].value;
    assert.equal(item.available, false); assert.equal(item.target_id, null);
  });
  test('dde1 Guardian notifications use actual settlement and owner allocations without synthetic scheduled charges', async () => {
    const db = getDb(); await enroll(db, donor, rescuer); const cycle = 'da070000-0000-4000-8000-000000000004';
    await db.query("insert into private.dopmi_guardian_cycles(id,donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at) values($1,$2,$1,2000,1960,'allocated',now())", [cycle, donor]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='guardian'")).rows[0].count, 0);
    await db.query("insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,charge_id,invoice_payment_id,gross_cents,stripe_fee_cents,platform_fee_cents,allocated_cents,refund_cents,evidence) values($1,'in_notif','pi_notif','ch_notif','inpay_notif',2000,100,40,1860,0,'{}')", [cycle]);
    await db.query("insert into private.dopmi_guardian_allocations(cycle_id,expense_id,amount_cents,allocated_cents) values($1,$2,1860,1860)", [cycle, expense]);
    await db.query("update private.dopmi_guardian_allocations set allocated_cents=1860 where cycle_id=$1", [cycle]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='guardian'")).rows[0].count, 2);
    await role(db, donor); const donorNotice = (await list(db)).items[0];
    assert.equal(donorNotice.title, 'Tu pago Guardián fue confirmado'); assert.equal(donorNotice.thumb_style, 'brand');
    await role(db, rescuer); assert.equal((await list(db)).items[0].target_kind, 'received_history');
    await role(db, staff); assert.equal((await list(db)).total, 0);
  });
  test('dde1 message decoration resolves published photo without alias ambiguity and denies outsiders', async () => {
    const db = getDb();
    const post = 'da078000-0000-4000-8000-000000000001';
    const thread = 'da078000-0000-4000-8000-000000000002';
    const message = 'da078000-0000-4000-8000-000000000003';
    await db.query("insert into public.dopmi_adoptions(id,owner_id,pet_name,status,photos) values($1,$2,'Luna','published',array['approved/chat-photo'])", [post,rescuer]);
    await db.query("insert into public.dopmi_threads(id,post_id,owner_id,adopter_id,pet_name) values($1,$2,$3,$4,'Luna')", [thread,post,rescuer,donor]);
    await db.query("insert into public.dopmi_messages(id,thread_id,sender_id,body) values($1,$2,$3,'Mensaje real de QA')", [message,thread,donor]);
    await db.query("insert into public.dopmi_notifications(user_id,kind,source_id,thread_id,title) values($1,'message',$2,$3,'Nuevo mensaje') on conflict(user_id,kind,source_id) do nothing", [rescuer,message,thread]);
    await role(db,rescuer);
    const notice = (await list(db)).items.find(n => n.thread_id === thread);
    assert.ok(notice); assert.equal(notice.body,'Mensaje real de QA');
    assert.equal(notice.photo_path,'approved/chat-photo'); assert.equal(notice.available,true);
    await role(db,staff);
    await denied(db, () => db.query('select public.dopmi_notification_open($1)',[notice.id]), /Notificación no disponible/);
    await db.exec('reset role');
    await db.query("insert into public.dopmi_notifications(user_id,kind,source_id,thread_id,title) values($1,'message',$2,$3,'No autorizado')", [other,message,thread]);
    await role(db,other);
    const unavailable = (await list(db)).items[0];
    assert.equal(unavailable.available,false); assert.equal(unavailable.photo_path,null);
    assert.equal(unavailable.body,''); assert.equal(unavailable.target_id,null);
  });
  test('dde1 Guardian enrollment cannot replay consumed states; future transfer still notifies', async () => {
    const db = getDb(); const cycle = 'da076000-0000-4000-8000-000000000001';
    await db.query("insert into private.dopmi_guardian_cycles(id,donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at) values($1,$2,$1,2000,1960,'allocated',now())", [cycle,donor]);
    await db.query("insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,charge_id,invoice_payment_id,gross_cents,stripe_fee_cents,platform_fee_cents,allocated_cents,refund_cents,evidence) values($1,'in_gate','pi_gate','ch_gate','inpay_gate',2000,100,40,1860,0,'{}')", [cycle]);
    await db.query("insert into private.dopmi_guardian_allocations(cycle_id,expense_id,amount_cents,allocated_cents) values($1,$2,1860,1860)", [cycle,expense]);
    await db.query("insert into private.dopmi_guardian_refund_adjustments(cycle_id,before_state,status) values($1,'{}','review')",[cycle]);
    await enroll(db,donor,rescuer);
    await db.query("update private.dopmi_guardian_settlements set refund_cents=refund_cents where cycle_id=$1",[cycle]);
    await db.query("update private.dopmi_guardian_allocations set allocated_cents=allocated_cents where cycle_id=$1",[cycle]);
    await db.query("update private.dopmi_guardian_refund_adjustments set status=status where cycle_id=$1",[cycle]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='guardian'")).rows[0].count,0);
    await db.query("update private.dopmi_guardian_allocations set stripe_transfer_id='tr_gateFuture',transferred_at=now() where cycle_id=$1",[cycle]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='guardian' and user_id=$1",[rescuer])).rows[0].count,1);
    await db.query("update private.dopmi_notification_candidate_cohort set enabled=false where user_id=$1",[donor]);
    await db.query("update private.dopmi_guardian_refund_adjustments set status='pending' where cycle_id=$1",[cycle]);
    await db.query("update private.dopmi_notification_candidate_cohort set enabled=true where user_id=$1",[donor]);
    await db.query("update private.dopmi_guardian_refund_adjustments set status='review' where cycle_id=$1",[cycle]);
    await db.query("update private.dopmi_guardian_refund_adjustments set status='pending' where cycle_id=$1",[cycle]);
    assert.equal((await db.query("select count(*)::int count from public.dopmi_notifications where kind='guardian' and user_id=$1",[donor])).rows[0].count,0);
  });
  test('dde1 profile review upsert updates semantic tone; read marking preserves the event', async () => {
    const db = getDb();
    await db.query("insert into public.dopmi_rescuer_profiles(owner_id,status,review_feedback) values($1,'published','Aprobado')", [rescuer]);
    const notify = async title => db.query("insert into public.dopmi_notifications(user_id,kind,source_id,title) values($1,'review',$1,$2) on conflict(user_id,kind,source_id) do update set title=excluded.title,read_at=null", [rescuer, title]);
    await notify('Tu perfil público fue aprobado');
    await role(db, rescuer); let item = (await list(db)).items[0];
    assert.equal(item.tone, 'positive'); assert.equal(item.target_kind, 'profile');
    await db.exec('reset role'); await db.query("update public.dopmi_rescuer_profiles set status='changes_requested',review_feedback='Corrige la biografía' where owner_id=$1", [rescuer]);
    await role(db, rescuer); item = (await db.query('select public.dopmi_notification_open($1) value', [item.id])).rows[0].value;
    assert.equal(item.tone, 'positive');
    await db.exec('reset role'); await notify('Tu perfil público necesita atención');
    await role(db, rescuer); item = (await list(db)).items[0];
    assert.equal(item.tone, 'negative'); assert.equal(item.body, 'Corrige la biografía'); assert.equal(item.read_at, null);
  });
}
