import { test } from 'node:test';
import assert from 'node:assert/strict';

export function registerPaymentMethodSnapshotSqlCases(getDb, { donor, rescuer, other, staff, expense }) {
  const donation = 'ed240000-0000-4000-8000-000000000001';
  const cycle = 'ed240000-0000-4000-8000-000000000002';
  const method = { type: 'card', brand: 'visa', last4: '0073' };
  const proof = { kind: 'contribution', payment_id: donation,
    payment_intent_id: 'pi_historical', charge_id: 'ch_historical', payment_method: method };
  const record = data => getDb().query('select public.dopmi_payment_method_snapshot_server($1::jsonb) value', [JSON.stringify(data)]).then(r => r.rows[0].value);
  const role = async (actor, name = 'authenticated') => {
    await getDb().exec('reset role');
    await getDb().query("select set_config('request.jwt.claim.sub',$1,true)", [actor]);
    await getDb().exec(`set local role ${name}`);
  };
  const rejected = async (fn, pattern) => {
    await getDb().exec('savepoint method_snapshot_failure');
    try { await assert.rejects(fn, pattern); }
    finally { await getDb().exec('rollback to savepoint method_snapshot_failure; release savepoint method_snapshot_failure'); }
  };
  const page = async received => (await getDb().query('select public.dopmi_payment_activity($1) value', [received])).rows[0].value;
  const paidDonation = () => getDb().query(`insert into public.dopmi_donations(
    id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,
    gross_cents,platform_fee_cents,stripe_fee_cents,net_cents,reserved_cents,allocated_cents,
    payment_status,status,processed_at,stripe_payment_intent_id,stripe_charge_id)
    values($1,$2,$3,$4,'Consulta TEST','acct_test',$1,2000,40,100,1860,0,1860,
    'confirmed','allocated',now(),'pi_historical','ch_historical')`, [donation,donor,rescuer,expense]);
  const paidCycle = async () => {
    await getDb().query(`insert into private.dopmi_guardian_cycles(
    id,donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at)
    values($1,$2,$1,2000,1960,'allocated',now())`, [cycle,donor]);
    await getDb().query(`insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,
      charge_id,invoice_payment_id,gross_cents,stripe_fee_cents,platform_fee_cents,
      allocated_cents,refund_cents,evidence)
    values($1,'in_historical','pi_guardianHistorical','ch_guardianHistorical','inpay_historical',2000,100,40,1860,0,'{}')`, [cycle]);
    await getDb().query(`insert into private.dopmi_guardian_allocations(cycle_id,expense_id,amount_cents,allocated_cents)
    values($1,$2,1860,1860)`, [cycle,expense]);
  };

  test('historical card is donor-only; clients, admins and service_role cannot read the private table or bypass wrappers', async () => {
    const db = getDb(); await paidDonation(); await record(proof);
    await role(donor);
    assert.deepEqual((await page(false)).items.find(i => i.id === donation).payment_method, method);
    for (const actor of [rescuer,other,staff]) {
      await role(actor); assert.equal((await page(false)).items.length, 0);
      for (const item of (await page(true)).items) assert.equal(item.payment_method, null);
    }
    for (const name of ['anon','authenticated','service_role']) {
      await role(name === 'anon' ? '' : donor,name);
      await rejected(() => db.query('select * from private.dopmi_payment_method_snapshots'), /permission denied/);
      await rejected(() => db.query("select public.dopmi_payment_server_before_method_snapshot('get',$1::jsonb)", [JSON.stringify({donation_id:donation})]), /permission denied/);
      await rejected(() => db.query("select public.dopmi_guardian_settlement_server_before_method_snapshot('get',$1::jsonb)", [JSON.stringify({cycle_id:cycle})]), /permission denied/);
      await rejected(() => db.query('select public.dopmi_payment_activity_before_method_snapshot()'), /permission denied/);
      if (name !== 'service_role') await rejected(() => record(proof), /permission denied/);
    }
    await role('', 'service_role'); assert.deepEqual(await record(proof), method);
  });

  test('snapshot validates canonical Charge/Intent, exact payload and immutable idempotence', async () => {
    const db = getDb(); await paidDonation();
    for (const delta of [{ payment_id: other }, { payment_intent_id: 'pi_foreign' },
      { charge_id: 'ch_foreign' }, { kind: 'guardian' }, { kind: null },
      { owner_id: other }, { client_secret: 'synthetic-not-a-secret' },
      { payment_method: { ...method, number: 'synthetic-full-number' } },
      { payment_method: { ...method, brand: 'Visa' } }, { payment_method: { ...method, last4: 73 } },
      { payment_method: { ...method, brand: 'sk_test_synthetic' } },
      { payment_method: { ...method, last4: '00730' } },
    ]) await rejected(() => record({ ...proof, ...delta }), /histórico|conciliado/);
    await db.query('update public.dopmi_donations set processed_at=null where id=$1',[donation]);
    await rejected(() => record(proof), /conciliado/);
    await db.query('update public.dopmi_donations set processed_at=now() where id=$1',[donation]);
    assert.deepEqual(await record(proof), method); assert.deepEqual(await record(proof), method);
    await rejected(() => record({ ...proof, payment_method: { ...method,last4:'9999' } }), /otro método/);
    await rejected(() => db.query("update private.dopmi_payment_method_snapshots set last4='9999'"), /no se modifica/);
    await rejected(() => db.query('delete from private.dopmi_payment_method_snapshots'), /no se modifica/);
    const stored = (await db.query('select * from private.dopmi_payment_method_snapshots')).rows[0];
    assert.equal(stored.owner_id, donor); assert.equal(stored.last4, '0073');
    assert.equal((await db.query('select count(*)::int n from private.dopmi_payment_method_snapshots')).rows[0].n,1);
  });

  test('legacy and omitted movements stay null; refunds retain the same real method and page cursor', async () => {
    const db=getDb(); await paidDonation(); await paidCycle();
    await role(donor); const before=await page(false);
    assert.equal(before.items.length,2); assert.ok(before.items.every(i=>i.payment_method===null));
    await db.exec('reset role'); await record(proof);
    const guardianProof={kind:'guardian',payment_id:cycle,payment_intent_id:'pi_guardianHistorical',
      charge_id:'ch_guardianHistorical',payment_method:{type:'card',brand:'mastercard',last4:'0008'}};
    await record(guardianProof);
    // Stored card/default can be removed without rewriting the payment fact.
    await db.query("insert into private.dopmi_saved_card_customers(owner_id,stripe_customer_id) values($1,'cus_historical')",[donor]);
    await db.query('delete from private.dopmi_saved_card_customers where owner_id=$1',[donor]);
    await db.query("update public.dopmi_donations set payment_status='refunded',status='refunded',refund_status='refunded',allocated_cents=0,platform_fee_cents=0,platform_loss_cents=100,net_cents=2000,refund_cents=2000 where id=$1",[donation]);
    await db.query("update private.dopmi_guardian_cycles set status='refunded' where id=$1",[cycle]);
    await role(donor); const after=await page(false);
    assert.deepEqual(after.items.map(i=>i.id),before.items.map(i=>i.id));
    assert.deepEqual(after.next_cursor,before.next_cursor);
    assert.deepEqual(after.items.find(i=>i.id===donation).payment_method,method);
    assert.deepEqual(after.items.find(i=>i.id===cycle).payment_method,guardianProof.payment_method);
    await role(rescuer); assert.ok((await page(true)).items.every(i=>i.payment_method===null));
    await db.exec('reset role');
    const skipped='ed240000-0000-4000-8000-000000000003';
    await db.query("insert into private.dopmi_guardian_cycles(id,donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at) values($1,$2,$1,2000,0,'skipped',now())",[skipped,donor]);
    await rejected(()=>record({...guardianProof,payment_id:skipped}),/conciliado/);
    await role(donor); assert.equal((await page(false)).items.find(i=>i.id===skipped).payment_method,null);
  });
}
