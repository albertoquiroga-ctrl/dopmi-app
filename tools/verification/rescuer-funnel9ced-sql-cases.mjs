import {test} from 'node:test';
import assert from 'node:assert/strict';

export function registerRescuerFunnelSqlCases(getDb, {donor, rescuer, other}) {
  const post='9ce00000-0000-4000-8000-000000000001';
  const expense='71000000-0000-4000-8000-000000000003';
  const actor=async(db,id,role='authenticated')=>{
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);
    await db.exec(`set local role ${role}`);
  };
  const funnel=async(db,period='month')=>(await db.query('select dopmi_rescuer_funnel($1) value',[period])).rows[0].value;
  const seed=async db=>db.query("insert into dopmi_adoptions(id,owner_id,pet_name,status)values($1,$2,'Luna 9ced','published')",[post,rescuer]);
  const rejected=async(db,sql,args,code)=>{
    await db.exec('savepoint rejected_9ced');
    try { await assert.rejects(db.query(sql,args),e=>e.code===code); }
    finally { await db.exec('rollback to savepoint rejected_9ced; release savepoint rejected_9ced'); }
  };

  test('9ced periods use Mexico City civil midnight, Monday and month start',async()=>{
    const db=getDb();
    const result=async(p,t)=>{
      const row=(await db.query('select * from private.dopmi_funnel_period($1,$2)',[p,t])).rows[0];
      return {period_start:new Date(row.period_start).toISOString(),period_end:new Date(row.period_end).toISOString()};
    };
    const yesterday=await result('yesterday','2026-10-07T03:00:00Z');
    assert.equal(yesterday.period_start,'2026-10-05T06:00:00.000Z');
    assert.equal(yesterday.period_end,'2026-10-06T06:00:00.000Z');
    assert.equal((await result('week','2026-10-07T03:00:00Z')).period_start,'2026-10-05T06:00:00.000Z');
    assert.equal((await result('month','2026-10-07T03:00:00Z')).period_start,'2026-10-01T06:00:00.000Z');
    assert.equal((await result('month','2026-11-01T05:59:59Z')).period_start,'2026-10-01T06:00:00.000Z');
    assert.equal((await result('month','2026-11-01T06:00:00Z')).period_start,'2026-11-01T06:00:00.000Z');
  });

  test('9ced daily observations require consent, retain lifetime evidence and deduplicate revisits',async()=>{
    const db=getDb();await seed(db);
    const start=(await db.query('select started_at from private.dopmi_adoption_measurement_start')).rows[0].started_at;
    await actor(db,donor);
    await db.query('select dopmi_record_adoption_view($1,true)',[post]);
    await db.exec('reset role');
    assert.equal((await db.query('select count(*)::int n from private.dopmi_adoption_view_days')).rows[0].n,0);
    await actor(db,donor);await db.query('select dopmi_set_adoption_measurement(true)');
    await db.query('select dopmi_record_adoption_view($1,true)',[post]);
    await db.query('select dopmi_record_adoption_view($1,true)',[post]);
    await actor(db,rescuer);await db.query('select dopmi_set_adoption_measurement(true)');
    await db.query('select dopmi_record_adoption_view($1,true)',[post]);
    await db.exec('reset role');
    assert.equal((await db.query('select count(*)::int n from private.dopmi_adoption_view_days')).rows[0].n,1);
    await db.query("insert into private.dopmi_adoption_view_days values($1,$2,timezone('America/Mexico_City',now())::date-1)",[post,donor]);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_adoption_views')).rows[0].n,1);
    assert.deepEqual((await db.query('select started_at from private.dopmi_adoption_measurement_start')).rows[0].started_at,start);
    await actor(db,rescuer);
    assert.equal((await funnel(db)).adoption.views,1);
    assert.equal((await funnel(db,'yesterday')).adoption.views,1);
    await rejected(db,'select * from private.dopmi_adoption_view_days',[],'42501');
    await actor(db,other);assert.equal((await funnel(db)).adoption.views,0);
  });

  test('9ced favorites and inbound people use real timestamps independently of thread reads',async()=>{
    const db=getDb();await seed(db);await actor(db,donor);
    const thread=(await db.query('select dopmi_start_adoption_contact($1) id',[post])).rows[0].id;
    await db.exec('reset role');
    await db.query("update dopmi_messages set created_at=now()-interval '1 second' where thread_id=$1",[thread]);
    await db.query("insert into dopmi_favorites(user_id,post_id,created_at) values($1,$2,now()-interval '1 second')",[donor,post]);
    await actor(db,rescuer);
    const before=await funnel(db);assert.equal(before.adoption.messages,1);assert.equal(before.adoption.favorites,1);
    const dashboard=(await db.query('select dopmi_rescuer_dashboard_v2() v')).rows[0].v;
    await db.query('select dopmi_read_thread($1)',[thread]);
    assert.deepEqual((await funnel(db)).adoption,before.adoption);
    assert.equal((await db.query('select dopmi_rescuer_dashboard_v2() v')).rows[0].v.unanswered_conversations,dashboard.unanswered_conversations);
    await db.exec('reset role');await db.query('delete from dopmi_favorites where user_id=$1 and post_id=$2',[donor,post]);
    await actor(db,rescuer);assert.equal((await funnel(db)).adoption.favorites,0);
  });

  test('9ced only adopted latest closures count, excluding other closures and reactivation',async()=>{
    const db=getDb();await seed(db);await actor(db,rescuer);
    await db.query("select dopmi_close_adoption($1,1,'adopted',false,'')",[post]);
    await db.exec('reset role');
    await db.query("update private.dopmi_adoption_closures set created_at=now()-interval '1 second' where post_id=$1",[post]);
    await actor(db,rescuer);assert.equal((await funnel(db)).adoption.adoptions,1);
    await db.exec('reset role');await db.query("update dopmi_adoptions set status='submitted' where id=$1",[post]);
    await actor(db,rescuer);assert.equal((await funnel(db)).adoption.adoptions,0);
    await db.exec('reset role');await db.query("update dopmi_adoptions set status='archived' where id=$1",[post]);
    await db.query("update private.dopmi_adoption_closures set reason='other',dopmi_support=null where post_id=$1",[post]);
    await actor(db,rescuer);assert.equal((await funnel(db)).adoption.adoptions,0);
  });

  test('9ced financial aggregates deduplicate donors, subtract reversals and exclude refunded support',async()=>{
    const db=getDb();
    const donation='9ce10000-0000-4000-8000-000000000001';
    await db.query(`insert into dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,
      gross_cents,platform_fee_cents,stripe_fee_cents,net_cents,allocated_cents,refund_cents,platform_loss_cents,reserved_cents,
      status,payment_status,transfer_status,refund_status,processed_at,stripe_payment_intent_id,stripe_charge_id)
      values($1,$2,$3,$4,'Medicina','acct_test','9ce20000-0000-4000-8000-000000000001',
      1000,20,50,930,930,0,0,0,'allocated','confirmed','pending','none',now()-interval '1 second','pi_9ced','ch_9ced')`,[donation,donor,rescuer,expense]);
    const cycle='9ce30000-0000-4000-8000-000000000001';
    await db.query(`insert into private.dopmi_guardian_cycles(id,donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at)
      values($1,$2,'9ce40000-0000-4000-8000-000000000001',2000,1960,'allocated',now()+interval '2 minutes')`,[cycle,donor]);
    await db.query(`insert into private.dopmi_guardian_allocations(cycle_id,expense_id,amount_cents,allocated_cents,reversed_cents,destination)
      values($1,$2,1960,1930,200,'acct_test')`,[cycle,expense]);
    await db.query(`insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,charge_id,invoice_payment_id,
      gross_cents,stripe_fee_cents,platform_fee_cents,allocated_cents,refund_cents,evidence,created_at)
      values($1,'in_9ced','pi_9cedg','ch_9cedg','inpay_9ced',2000,30,40,1930,0,'{}',now()-interval '1 second')`,[cycle]);
    await actor(db,rescuer);
    const summary=await funnel(db);assert.equal(summary.support.donors,1);assert.equal(summary.support.raised_cents,2660);
    assert.equal((await funnel(db,'yesterday')).support.raised_cents,0);
    assert.equal((await funnel(db,'yesterday')).support.active,summary.support.active);
    await db.exec('reset role');
    await db.query(`update dopmi_donations set status='refunded',payment_status='refunded',transfer_status='reversed',refund_status='refunded',
      allocated_cents=0,refund_cents=1000,platform_fee_cents=0,net_cents=1000,platform_loss_cents=50 where id=$1`,[donation]);
    await db.query('update private.dopmi_guardian_allocations set reversed_cents=allocated_cents where cycle_id=$1',[cycle]);
    await actor(db,rescuer);assert.equal((await funnel(db)).support.donors,0);assert.equal((await funnel(db)).support.raised_cents,0);
  });

  test('9ced funnel rejects invalid periods, anonymous and suspended accounts without exposing daily records',async()=>{
    const db=getDb();await actor(db,rescuer);
    await rejected(db,'select dopmi_rescuer_funnel($1)',['rolling'],'22023');
    await rejected(db,'select dopmi_rescuer_funnel($1)',[null],'22023');
    await rejected(db,'select * from private.dopmi_adoption_view_day_start',[],'42501');
    await actor(db,'','anon');await rejected(db,'select dopmi_rescuer_funnel()',[],'42501');
    await db.exec('reset role');await db.query("update profiles set account_status='suspended' where id=$1",[rescuer]);
    await actor(db,rescuer);await rejected(db,'select dopmi_rescuer_funnel()',[],'42501');
  });
}
