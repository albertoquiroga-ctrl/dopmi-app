import { test } from 'node:test';
import assert from 'node:assert/strict';

export function registerPaymentActivitySqlCases(getDb, { donor, rescuer, other, staff, expense }) {
  const role = async (db, actor, name = 'authenticated') => {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub',$1,true)", [actor]);
    await db.exec(`set local role ${name}`);
  };
  const denied = async (db, operation, pattern) => {
    await db.exec('savepoint activity_expected_error');
    try { await assert.rejects(operation, pattern); } finally { await db.exec('rollback to savepoint activity_expected_error; release savepoint activity_expected_error'); }
  };
  const page = async (db, received = false, cursor = null, size = 7) => (await db.query(
    'select public.dopmi_payment_activity($1,$2,$3,$4,$5) value',
    [received, cursor?.created_at ?? null, cursor?.kind ?? null, cursor?.id ?? null, size],
  )).rows[0].value;
  test('dde1 history merges before keyset pagination, including ties and more than 50 cycles', async () => {
    const db = getDb();
    const date = '2026-10-08T12:00:00Z';
    for (let n = 1; n <= 55; n++) {
      const id = `da060000-0000-4000-8000-${String(n).padStart(12, '0')}`;
      await db.query("insert into private.dopmi_guardian_cycles(id,donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at,created_at) values($1,$2,$1,2000,0,'skipped',now(),$3)", [id, donor, date]);
    }
    for (let n = 1; n <= 9; n++) {
      const id = `da061000-0000-4000-8000-${String(n).padStart(12, '0')}`;
      await db.query("insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,reserved_cents,created_at) values($1,$2,$3,$4,'Medicamentos','acct_test',$1,1011,20,991,$5)", [id, donor, rescuer, expense, date]);
    }
    await role(db, donor);
    const rows = [];
    let cursor = null;
    do {
      const result = await page(db, false, cursor);
      rows.push(...result.items); cursor = result.next_cursor;
    } while (cursor);
    assert.equal(rows.length, 64);
    assert.equal(new Set(rows.map(r => `${r.kind}:${r.id}`)).size, 64);
    assert.equal(rows.filter(r => r.kind === 'guardian').length, 55);
    assert.equal(rows[0].kind, 'guardian');
    assert.equal(rows.at(-1).amount_cents, 1011);
    assert.equal(rows.some(r => JSON.stringify(r).includes('acct_test')), false);
    assert.equal(rows.some(r => r.method_label || r.donor_id), false);
    for (const actor of [other, staff]) {
      await role(db, actor); assert.equal((await page(db)).items.length, 0);
    }
    await role(db, '', 'anon');
    await denied(db, () => page(db), /permission denied/);
  });

  test('dde1 Guardian received grouping and allocation pages expose only the expense owner net', async () => {
    const db = getDb();
    const cycle = 'da062000-0000-4000-8000-000000000001';
    const second = 'da062000-0000-4000-8000-000000000002';
    await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot) values('da062000-0000-4000-8000-000000000003',$1,'case','approved','{\"pet_name\":\"Otra mascota\"}')", [other]);
    await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,reimbursable_cents,parent_id) values($1,$2,'expense','approved','{\"title\":\"Otro gasto privado\"}',860,'da062000-0000-4000-8000-000000000003')", [second, other]);
    await db.query("insert into private.dopmi_guardian_cycles(id,donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at) values($1,$2,$1,2000,1960,'allocated',now())", [cycle, donor]);
    await db.query("insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,charge_id,invoice_payment_id,gross_cents,stripe_fee_cents,platform_fee_cents,allocated_cents,refund_cents,evidence) values($1,'in_activity','pi_activity','ch_activity','inpay_activity',2000,100,40,1860,0,'{}')", [cycle]);
    await db.query("insert into private.dopmi_guardian_allocations(cycle_id,expense_id,amount_cents,allocated_cents,reversed_cents) values($1,$2,1000,1000,200),($1,$3,860,860,0)", [cycle, expense, second]);
    await db.query("update private.dopmi_guardian_allocations set stripe_transfer_id='tr_activityOwn',transferred_at=now() where cycle_id=$1 and expense_id=$2",[cycle,expense]);
    await role(db, rescuer);
    const received = (await page(db, true)).items;
    assert.equal(received.length, 1);
    assert.equal(received[0].allocation_count, 1);
    assert.equal(received[0].assigned_cents, 1000);
    assert.equal(received[0].reversed_cents, 200);
    assert.equal(received[0].authorized_cents, null);
    const allocations = async received => (await db.query('select public.dopmi_payment_activity_allocations($1,$2,null,1) value', [cycle, received])).rows[0].value;
    const ownAllocation=(await allocations(true)).items[0];
    assert.deepEqual((await allocations(true)).items.map(a => a.expense_id), [expense]);
    assert.equal(ownAllocation.status,'partial_reversal'); assert.equal(ownAllocation.remaining_cents,800); assert.equal(ownAllocation.transferred_cents,800);
    await denied(db, () => allocations(false), /Ciclo no disponible/);
    await role(db, other);
    assert.equal((await page(db, true)).items[0].assigned_cents, 860);
    await db.exec('reset role');
    await db.query("insert into private.dopmi_guardian_refund_adjustments(cycle_id,before_state,status,confirmed_refund_cents) values($1,'{}','pending',200)", [cycle]);
    await role(db, other);
    assert.equal((await page(db, true)).items[0].status, 'assigned');
    await role(db, rescuer);
    assert.equal((await page(db, true)).items[0].status, 'partial_reversal');
    await db.exec('reset role');
    await db.query("update private.dopmi_guardian_refund_adjustments set status='review' where cycle_id=$1", [cycle]);
    await role(db, other);
    assert.equal((await page(db, true)).items[0].status, 'assigned');
    await role(db, donor);
    const sent = (await page(db)).items[0];
    assert.equal(sent.allocation_count, 2);
    assert.equal(sent.amount_cents, 2000);
    const ordered = [expense, second].sort();
    const firstPage = await allocations(false);
    assert.deepEqual(firstPage.items.map(a => a.expense_id), [ordered[0]]);
    assert.equal(firstPage.next_cursor, ordered[0]);
    const secondPage = (await db.query('select public.dopmi_payment_activity_allocations($1,false,$2,1) value', [cycle, firstPage.next_cursor])).rows[0].value;
    assert.deepEqual(secondPage.items.map(a => a.expense_id), [ordered[1]]);
    assert.equal(secondPage.next_cursor, null);
    await role(db, staff);
    assert.equal((await page(db, true)).items.length, 0);
    await denied(db, () => allocations(true), /Ciclo no disponible/);
  });
  test('dde1 confirmed direct refund is never still presented as pending', async () => {
    const db = getDb();
    const id = 'da063000-0000-4000-8000-000000000001';
    await db.query("insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,reserved_cents,refund_cents,refund_status,payment_status) values($1,$2,$3,$4,'Consulta','acct_test',$1,1000,20,0,1000,'refunded','refunded')", [id,donor,rescuer,expense]);
    await role(db, donor);
    const row = (await page(db,false,null,50)).items.find(r => r.id === id);
    assert.equal(row.status, 'refunded');
    assert.equal(row.refund_cents, 0);
    assert.equal(row.refunded_cents, 1000);
  });
  test('dde1 private history retains processed fees and pending stable intent only for its donor', async () => {
    const db = getDb(); const id='da064000-0000-4000-8000-000000000001';
    await db.query("insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,reserved_cents) values($1,$2,$3,$4,'Consulta','acct_test',$1,1011,20,991)",[id,donor,rescuer,expense]);
    await role(db,donor); let row=(await page(db,false,null,50)).items.find(r=>r.id===id);
    assert.equal(row.idempotency_key,id); assert.equal(row.gross_cents,1011);
    await role(db,rescuer); row=(await page(db,true,null,50)).items.find(r=>r.id===id);
    assert.equal(row.idempotency_key,null); assert.equal(row.gross_cents,null); assert.equal(row.platform_fee_cents,null);
    await db.exec('reset role');
    await db.query("update public.dopmi_donations set payment_status='confirmed',allocated_cents=900,reserved_cents=0,stripe_fee_cents=91,net_cents=900,processed_at=now() where id=$1",[id]);
    await role(db,donor); row=(await page(db,false,null,50)).items.find(r=>r.id===id);
    assert.ok(row.processed_at); assert.equal(row.platform_fee_cents,20); assert.equal(row.stripe_fee_cents,91); assert.equal(row.net_cents,900); assert.equal(row.idempotency_key,null);
    await role(db,rescuer); row=(await page(db,true,null,50)).items.find(r=>r.id===id);
    assert.equal(row.net_cents,900); assert.equal(row.stripe_fee_cents,null); assert.equal(row.platform_fee_cents,null);
  });
  test('dde1 confirmed partial contribution refund preserves actual refund amount and label',async()=>{
    const db=getDb();const id='da065000-0000-4000-8000-000000000001';
    await db.query("insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,reserved_cents,payment_status,allocated_cents,refund_status,refund_cents) values($1,$2,$3,$4,'Consulta','acct_test',$1,2000,40,0,'confirmed',1500,'refunded',200)",[id,donor,rescuer,expense]);
    await role(db,donor);const row=(await page(db,false,null,50)).items.find(r=>r.id===id);
    assert.equal(row.status,'partial_refund');assert.equal(row.refunded_cents,200);assert.equal(row.refund_cents,0);
  });
  test('received ledger receipt acknowledges only rows presented before later contribution and same-cycle allocation', async () => {
    const db = getDb();
    const donationA = 'fa690001-0000-4000-8000-000000000001';
    const donationB = 'fa690001-0000-4000-8000-000000000002';
    const cycle = 'fa690001-0000-4000-8000-000000000003';
    const laterExpense = 'fa690001-0000-4000-8000-000000000004';
    const addDonation = id => db.query("insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,stripe_fee_cents,net_cents,reserved_cents,allocated_cents,payment_status) values($1,$2,$3,$4,'Gasto TEST','acct_test',$1,1000,20,80,900,0,900,'confirmed')", [id, donor, rescuer, expense]);
    await addDonation(donationA);
    await db.query("insert into private.dopmi_guardian_cycles(id,donor_id,cycle_key,gross_cents,reserved_cents,status,expires_at) values($1,$2,$1,2000,1960,'allocated',now())", [cycle, donor]);
    await db.query("insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,charge_id,invoice_payment_id,gross_cents,stripe_fee_cents,platform_fee_cents,allocated_cents,refund_cents,evidence) values($1,'in_receipt','pi_receipt','ch_receipt','inpay_receipt',2000,100,40,1860,0,'{}')", [cycle]);
    await db.query('insert into private.dopmi_guardian_allocations(cycle_id,expense_id,amount_cents,allocated_cents) values($1,$2,1000,1000)', [cycle, expense]);
    const unseen = async () => {
      await db.exec('reset role');
      await db.query("select set_config('request.jwt.claim.sub',$1,true)", [rescuer]);
      return (await db.query('select activity.id from private.dopmi_rescuer_activity_rows($1) activity where not exists(select 1 from private.dopmi_rescuer_activity_seen seen where seen.owner_id=$1 and seen.event_id=activity.id) order by activity.id', [rescuer])).rows.map(row => row.id);
    };
    const finances = async () => {
      await db.exec('reset role');
      return (await db.query("select jsonb_build_object('donations',(select jsonb_agg(to_jsonb(d) order by id) from public.dopmi_donations d),'allocations',(select jsonb_agg(to_jsonb(a) order by cycle_id,expense_id) from private.dopmi_guardian_allocations a),'settlements',(select jsonb_agg(to_jsonb(s) order by cycle_id) from private.dopmi_guardian_settlements s)) value")).rows[0].value;
    };
    assert.equal((await unseen()).length, 2);
    await role(db, rescuer);
    const shownA = await page(db, true, null, 50);
    assert.equal(shownA.next_cursor, null);
    assert.equal(shownA.items.length, 2);
    for (const entry of shownA.items) {
      assert.match(entry.presented_cursor, /^[0-9a-f-]{36}$/);
      assert.equal(entry.payment_method, null);
      assert.equal('event_ids' in entry, false);
      assert.equal('donor_id' in entry, false);
    }
    assert.deepEqual((await page(db, true, null, 50)).items.map(row => row.presented_cursor), shownA.items.map(row => row.presented_cursor));
    assert.equal((await unseen()).length, 2, 'reading is not acknowledgement');
    assert.equal((await db.query('select count(*)::int n from private.dopmi_rescuer_activity_receipts where owner_id=$1', [rescuer])).rows[0].n, 2);

    // These two events arrive after A was presented. In particular, the
    // Guardian event shares the already-presented cycle but a different expense.
    await addDonation(donationB);
    await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot,parent_id,reimbursable_cents) select $1,$2,'expense','approved','{\"title\":\"Otro gasto TEST\"}',parent_id,860 from public.dopmi_rescue_records where id=$3", [laterExpense, rescuer, expense]);
    await db.query('insert into private.dopmi_guardian_allocations(cycle_id,expense_id,amount_cents,allocated_cents) values($1,$2,860,860)', [cycle, laterExpense]);
    const financialBeforeAck = await finances();
    await role(db, other);
    await denied(db, () => db.query('select public.dopmi_acknowledge_rescuer_payments($1)', [shownA.items[0].presented_cursor]), error => error.code === '42501');
    await role(db, rescuer);
    for (const row of shownA.items) {
      await db.query('select public.dopmi_acknowledge_rescuer_payments($1)', [row.presented_cursor]);
      await db.query('select public.dopmi_acknowledge_rescuer_payments($1)', [row.presented_cursor]);
    }
    assert.deepEqual(await unseen(), [`guardian:${cycle}:${laterExpense}`, `individual:${donationB}`]);
    assert.deepEqual(await finances(), financialBeforeAck);
    await role(db, rescuer);
    const shownB = await page(db, true, null, 50);
    assert.equal(shownB.items.find(row => row.id === donationA).presented_cursor, shownA.items.find(row => row.id === donationA).presented_cursor);
    assert.notEqual(shownB.items.find(row => row.id === cycle).presented_cursor, shownA.items.find(row => row.id === cycle).presented_cursor);
    await denied(db, () => db.query('select private.dopmi_payment_activity_before_received_receipts()'), /permission denied/);
    await db.exec('reset role');
    const receiptCount = (await db.query('select count(*)::int n from private.dopmi_rescuer_activity_receipts')).rows[0].n;
    await role(db, donor);
    assert.equal((await page(db, false, null, 50)).items.some(row => row.presented_cursor != null), false);
    await db.exec('reset role');
    assert.equal((await db.query('select count(*)::int n from private.dopmi_rescuer_activity_receipts')).rows[0].n, receiptCount);
    assert.equal((await db.query("select provolatile from pg_proc where oid='public.dopmi_payment_activity(boolean,timestamptz,text,uuid,integer)'::regprocedure")).rows[0].provolatile, 'v');
  });
  test('dde1 activity rejects partial and unsupported keyset cursors', async () => {
    const db = getDb(); await role(db, donor);
    await denied(db, () => db.query("select public.dopmi_payment_activity(false,now(),null,null,20)"), /Página inválida/);
    await denied(db, () => db.query("select public.dopmi_payment_activity(false,now(),'shop',$1,20)", [donor]), /Página inválida/);
    await denied(db, () => db.query("select public.dopmi_payment_activity(false,null,null,null,51)"), /Página inválida/);
  });
}
