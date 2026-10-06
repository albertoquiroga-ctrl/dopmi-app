import {test} from 'node:test';
import assert from 'node:assert/strict';

export function registerRescuerUpdateSqlCases(getDb,{donor,rescuer,other}) {
  const actor=async(db,id)=>{await db.exec('reset role'); await db.query("select set_config('request.jwt.claim.sub',$1,true)",[id]);await db.exec('set local role authenticated');};
  const value=async(db,sql,args=[]) => (await db.query(sql,args)).rows[0].value;
  const post='bc000000-0000-4000-8000-000000000001';
  const seed=async db=>db.query("insert into dopmi_adoptions(id,owner_id,pet_name,status)values($1,$2,'Luna','published')",[post,rescuer]);
  test('bccd dashboard and owned pages expose complete real counts with no historical views',async()=>{
    const db=getDb();await seed(db);
    await db.query("insert into dopmi_adoptions(owner_id,pet_name,status)select $1,'Mascota '||n,'draft' from generate_series(1,25)n",[rescuer]);
    await actor(db,rescuer);
    const page=await value(db,"select dopmi_owned_cases('adoption',array['draft'],false,1)as value");
    assert.equal(page.total,25);assert.equal(page.items.length,20);
    const dashboard=await value(db,'select dopmi_rescuer_dashboard_v2()as value');
    assert.equal(dashboard.adoption_counts.draft,25);assert.equal(dashboard.adoption_metrics.unique_viewers,0);
    await actor(db,other);assert.equal((await value(db,"select dopmi_owned_cases()as value")).total,0);
  });
  test('bccd unique viewers require consent and exclude owner and repeated devices',async()=>{
    const db=getDb();await seed(db);await actor(db,donor);
    await db.query('select dopmi_record_adoption_view($1,true)',[post]);
    await db.query('select dopmi_set_adoption_measurement(true)');
    await db.query('select dopmi_record_adoption_view($1,false)',[post]);
    await db.query('select dopmi_record_adoption_view($1,true)',[post]);
    await db.query('select dopmi_record_adoption_view($1,true)',[post]);
    await actor(db,rescuer);await db.query('select dopmi_set_adoption_measurement(true)');await db.query('select dopmi_record_adoption_view($1,true)',[post]);
    assert.equal((await value(db,'select dopmi_rescuer_dashboard_v2()as value')).adoption_metrics.unique_viewers,1);
    await db.exec('reset role');assert.equal((await db.query('select count(*)::int n from private.dopmi_adoption_views')).rows[0].n,1);
  });
  test('bccd inbox stays flat and pending response is independent from read state',async()=>{
    const db=getDb();await seed(db);await actor(db,donor);
    const first=await value(db,'select dopmi_start_adoption_contact($1)as value',[post]);
    await actor(db,other);await value(db,'select dopmi_start_adoption_contact($1)as value',[post]);
    await actor(db,rescuer);const inbox=await value(db,'select dopmi_rescuer_threads_page(1,$1,false,false)as value',[post]);
    assert.equal(inbox.total,2);assert.equal(new Set(inbox.items.map(t=>t.id)).size,2);
    assert.equal((await value(db,'select dopmi_rescuer_dashboard_v2()as value')).unanswered_conversations,2);
    await db.query('select dopmi_read_thread($1)',[first]);
    assert.equal((await value(db,'select dopmi_rescuer_dashboard_v2()as value')).unanswered_conversations,2);
  });
  const uuid=(prefix,n)=>`${prefix}-0000-4000-8000-${String(n).padStart(12,'0')}`;
  const expense='71000000-0000-4000-8000-000000000003';
  const supportCase='71000000-0000-4000-8000-000000000002';
  const rejected=async(db,sql,args=[],code='22023')=>{
    await db.exec('savepoint bccd_rejected');
    try { await assert.rejects(db.query(sql,args),error=>error.code===code); }
    finally { await db.exec('rollback to savepoint bccd_rejected; release savepoint bccd_rejected'); }
  };
  // Synthetic settled records obey both financial equations. Their state is a
  // read-model fixture; no Stripe transport or live collection is involved.
  const donation=async(db,n,{payment='confirmed',created='2026-10-06T10:00:00Z'}={})=>{
    const id=uuid('bc300000',n),refunded=payment==='refunded',confirmed=payment==='confirmed';
    await db.query(`insert into public.dopmi_donations(id,donor_id,rescuer_id,expense_id,
      expense_title,destination,idempotency_key,gross_cents,platform_fee_cents,stripe_fee_cents,
      net_cents,allocated_cents,refund_cents,platform_loss_cents,reserved_cents,status,
      payment_status,transfer_status,refund_status,processed_at,created_at,
      stripe_payment_intent_id,stripe_charge_id)
      values($1,$2,$3,$4,'Medicamentos','acct_test',$5,1000,$6,$7,$8,$9,$10,$11,0,
        $12,$13,$14,$15,case when $16 then now() else null end,$17::timestamptz,$18,$19)`,
      [id,donor,rescuer,expense,uuid('bc310000',n),refunded?0:20,
        confirmed||refunded?50:null,refunded?1000:confirmed?930:null,
        confirmed?930:0,refunded?1000:0,refunded?50:0,
        refunded?'refunded':confirmed?'allocated':payment==='canceled'?'canceled':'pending',
        payment,refunded?'reversed':confirmed?'pending':'not_started',
        refunded?'refunded':'none',confirmed||refunded,created,
        confirmed||refunded?`pi_bccdi${n}`:null,confirmed||refunded?`ch_bccdi${n}`:null]);
    return id;
  };
  const guardian=async(db,n,{settled=true,attention=false,transferred=false}={})=>{
    const cycle=uuid('bc400000',n);
    await db.query(`insert into private.dopmi_guardian_cycles(id,donor_id,cycle_key,gross_cents,
      reserved_cents,status,expires_at)values($1,$2,$3,2000,1960,$4,now()+interval '2 minutes')`,
      [cycle,donor,uuid('bc410000',n),settled?'allocated':'reserved']);
    await db.query(`insert into private.dopmi_guardian_allocations(cycle_id,expense_id,amount_cents,
      allocated_cents,destination,stripe_transfer_id,transferred_at)
      values($1,$2,1960,$3,'acct_test',$4,case when $5 then now() else null end)`,
      [cycle,expense,settled?1930:0,transferred?`tr_bccdg${n}`:null,transferred]);
    if(settled) {
      await db.query(`insert into private.dopmi_guardian_settlements(cycle_id,invoice_id,payment_intent_id,
        charge_id,invoice_payment_id,gross_cents,stripe_fee_cents,platform_fee_cents,
        allocated_cents,refund_cents,evidence)values($1,$2,$3,$4,$5,2000,30,40,1930,0,'{}')`,
        [cycle,`in_bccdg${n}`,`pi_bccdg${n}`,`ch_bccdg${n}`,`inpay_bccdg${n}`]);
      if(attention) await db.query(`insert into private.dopmi_guardian_jobs(job_key,cycle_id,
        expense_id,kind,status,error_code)values($1,$2,$3,'transfer','attention','fixture_unavailable')`,
        [`bccd-transfer-${n}`,cycle,expense]);
    }
    return cycle;
  };

  test('bccd adoption closure rollback, invalid reasons, stale versions and third parties preserve all state',async()=>{
    const db=getDb();await seed(db);await actor(db,rescuer);
    const before=(await db.query('select to_jsonb(a) value from dopmi_adoptions a where id=$1',[post])).rows[0].value;
    await db.exec('savepoint bccd_cancelled_transaction');
    const closed=await value(db,"select dopmi_close_adoption($1,1,'other',null,'  Otro motivo  ')as value",[post]);
    assert.equal(closed.status,'archived');
    await db.exec('rollback to savepoint bccd_cancelled_transaction; release savepoint bccd_cancelled_transaction');
    assert.deepEqual((await db.query('select to_jsonb(a) value from dopmi_adoptions a where id=$1',[post])).rows[0].value,before);
    await rejected(db,"select dopmi_close_adoption($1,99,'other',null,'')",[post],'PT409');
    for(const [reason,support,description]of [['adopted',null,''],['other',true,''],['invented',null,''],['other',null,'x'.repeat(1001)]]) {
      await rejected(db,'select dopmi_close_adoption($1,1,$2,$3,$4)',[post,reason,support,description]);
    }
    await actor(db,other);
    await rejected(db,"select dopmi_close_adoption($1,1,'other',null,'')",[post],'42501');
    await db.exec('reset role');
    assert.deepEqual((await db.query('select to_jsonb(a) value from dopmi_adoptions a where id=$1',[post])).rows[0].value,before);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_adoption_closures where post_id=$1',[post])).rows[0].n,0);
  });

  test('bccd adopted closure persists explicit support answer and reactivation retains identity photos and fields until review',async()=>{
    const db=getDb();await seed(db);
    const photos=Array.from({length:6},(_,n)=>`${rescuer}/${post}/${uuid('bc500000',n+1)}.jpg`);
    const fields={pet_name:'Luna',species:'cat',sex:'female',age_months:36,size:'small',breed:'Criolla',
      city:'Monterrey',region:'Nuevo León',story:'Una historia completa y suficientemente larga.',
      special_care:'Revisión veterinaria',publisher_name:'Refugio de prueba',publisher_bio:'Cuidamos mascotas.',
      vaccinated:true,sterilized:true,social_dogs:false,social_cats:true,social_children:true,
      photos,age_band:'adult',coexistence:['children','apartment'],personality:['alegre','playful']};
    await db.query(`update dopmi_adoptions set species='cat',age_months=36,size='small',breed='Criolla',
      city='Monterrey',region='Nuevo León',story=$2,special_care=$3,publisher_name=$4,publisher_bio=$5,
      vaccinated=true,sterilized=true,social_dogs=false,social_cats=true,social_children=true,
      photos=$6,age_band='adult',coexistence=array['children','apartment'],personality=array['alegre','playful'] where id=$1`,
      [post,fields.story,fields.special_care,fields.publisher_name,fields.publisher_bio,photos]);
    await db.query(`insert into storage.objects(bucket_id,name,metadata)
      select 'dopmi-adoption-photos',path,'{"mimetype":"image/jpeg","size":100}' from unnest($1::text[])path`,[photos]);
    await actor(db,rescuer);
    const closed=await value(db,"select dopmi_close_adoption($1,1,'adopted',false,'  Adoptada por fuera  ')as value",[post]);
    assert.equal(closed.status,'adopted');assert.equal(closed.version,2);
    const archive=await value(db,"select dopmi_owned_cases('adoption','{}',true)as value");
    assert.equal(archive.total,1);assert.equal(archive.items[0].close_reason,'adopted');
    assert.equal(archive.items[0].adopted_with_dopmi_support,false);
    assert.equal(archive.items[0].close_reason_description,'Adoptada por fuera');
    await rejected(db,"select dopmi_close_adoption($1,1,'adopted',true,'')",[post],'PT409');
    const reopened=await value(db,'select dopmi_save_adoption($1::jsonb,$2,$3)as value',[JSON.stringify(fields),post,closed.version]);
    assert.equal(reopened.id,post);assert.equal(reopened.status,'draft');assert.equal(reopened.version,3);
    for(const [key,expected]of Object.entries(fields)) {
      if(key==='coexistence'||key==='personality') assert.deepEqual(new Set(reopened[key]),new Set(expected));
      else assert.deepEqual(reopened[key],expected,key);
    }
    await db.exec('reset role;set local role anon');
    assert.equal(await value(db,'select dopmi_adoption_detail($1)as value',[post]),null);
    await actor(db,rescuer);
    const submitted=await value(db,"select dopmi_transition_adoption($1,$2,'submit')as value",[post,reopened.version]);
    assert.equal(submitted.status,'submitted');assert.equal(submitted.id,post);
    await db.exec('reset role;set local role anon');
    assert.equal(await value(db,'select dopmi_adoption_detail($1)as value',[post]),null);
    await db.exec('reset role');
    assert.equal((await db.query('select count(*)::int n from dopmi_adoptions where owner_id=$1',[rescuer])).rows[0].n,1);
    assert.equal((await db.query('select count(*)::int n from private.dopmi_adoption_closures where post_id=$1',[post])).rows[0].n,1);
  });

  test('bccd support archive blocks review and approved edits while closing preserves financial evidence and owned records',async()=>{
    const db=getDb();await actor(db,rescuer);
    const draft=await value(db,"select dopmi_save_rescue('case','{\"pet_name\":\"Mora\"}','{}','[]')as value");
    await db.exec('reset role');await db.query("update dopmi_rescue_records set status='submitted',submitted_at=now()where id=$1",[draft.id]);
    await actor(db,rescuer);
    await rejected(db,'select dopmi_archive_support_case($1,$2)',[draft.id,draft.version]);
    await rejected(db,'select dopmi_archive_support_case($1,99)',[draft.id],'PT409');
    await rejected(db,'select dopmi_archive_support_case($1,1)',[supportCase]);
    await rejected(db,"select dopmi_save_rescue('case','{}','{}','[]',$1,1)",[supportCase]);
    await rejected(db,"select dopmi_save_rescue('expense','{}','{}','[]',$1,1,$2)",[expense,supportCase]);
    await db.exec('reset role');const paid=await donation(db,1);
    const before=(await db.query('select to_jsonb(e) value from dopmi_rescue_records e where id=$1',[expense])).rows[0].value;
    await actor(db,rescuer);
    await rejected(db,'select dopmi_archive_support_case($1,1)',[supportCase]);
    const closed=await value(db,"select dopmi_transition_rescue($1,1,'close')as value",[supportCase]);
    assert.equal(closed.status,'closed');
    await db.query('select dopmi_archive_support_case($1,$2)',[supportCase,closed.version]);
    const archived=await value(db,"select dopmi_owned_cases('support','{}',true)as value");
    const item=archived.items.find(e=>e.id===supportCase);
    assert.equal(item.archived,true);assert.equal(item.funded_cents,930);
    assert.equal(item.target_cents,12000);
    await db.exec('reset role');
    assert.deepEqual((await db.query('select to_jsonb(e) value from dopmi_rescue_records e where id=$1',[expense])).rows[0].value,before);
    assert.equal((await db.query('select allocated_cents from dopmi_donations where id=$1',[paid])).rows[0].allocated_cents,930);
    const archiveVersion=(await db.query('select version from dopmi_rescue_records where id=$1',[supportCase])).rows[0].version;
    await actor(db,other);await rejected(db,'select dopmi_archive_support_case($1,$2)',[supportCase,archiveVersion],'42501');
    assert.equal((await value(db,"select dopmi_owned_cases('support','{}',true)as value")).total,0);
  });

  test('bccd flat inbox combines filters before total and paging and excludes third parties and unrelated staff',async()=>{
    const db=getDb();await seed(db);const second=uuid('bc000000',2);
    await db.query("insert into dopmi_adoptions(id,owner_id,pet_name,status)values($1,$2,'Mora','published')",[second,rescuer]);
    await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
      select ('bc110000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'bccd-adopter'||n||'@example.test',now(),
      jsonb_build_object('display_name','Persona '||lpad(n::text,2,'0'),'terms_accepted',true,
        'terms_version','development-2026-09-13')from generate_series(1,24)n`);
    await db.query(`insert into dopmi_threads(id,post_id,owner_id,adopter_id,pet_name)
      select ('bc120000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,$1,$2,
        ('bc110000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Luna'from generate_series(1,24)n`,[post,rescuer]);
    await db.query(`insert into dopmi_messages(id,thread_id,sender_id,body)
      select ('bc140000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
        ('bc120000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
        ('bc110000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Mensaje de prueba'from generate_series(1,24)n`);
    await db.query(`insert into dopmi_notifications(user_id,kind,post_id,thread_id,source_id,title)
      select $1,'message',$2,('bc120000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
        ('bc140000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Mensaje de prueba'from generate_series(1,22)n`,[rescuer,post]);
    const staff=(await db.query('select user_id from private.admin_memberships limit 1')).rows[0].user_id;
    await actor(db,donor);await value(db,'select dopmi_start_adoption_contact($1)as value',[second]);
    await actor(db,rescuer);
    const first=await value(db,'select dopmi_rescuer_threads_page(1,$1,true,false)as value',[post]);
    const last=await value(db,'select dopmi_rescuer_threads_page(2,$1,true,false)as value',[post]);
    assert.equal(first.total,22);assert.equal(first.items.length,20);
    assert.equal(last.total,22);assert.equal(last.items.length,2);
    assert.equal(new Set([...first.items,...last.items].map(e=>e.id)).size,22);
    assert.ok([...first.items,...last.items].every(e=>e.group_id===post&&e.unread_count===1));
    assert.equal((await value(db,'select dopmi_rescuer_threads_page()as value')).total,25);
    assert.equal((await value(db,'select dopmi_rescuer_threads_page(1,$1,false,false)as value',[second])).total,1);
    const groups=await value(db,'select dopmi_rescuer_inbox()as value');
    assert.equal(groups.items.find(e=>e.id===post).unread_count,22);
    await db.query('select dopmi_read_thread($1)',[uuid('bc120000',1)]);
    assert.equal((await value(db,'select dopmi_rescuer_threads_page(1,$1,true,false)as value',[post])).total,21);
    await db.query('select dopmi_close_thread($1)',[uuid('bc120000',1)]);
    assert.equal((await value(db,'select dopmi_rescuer_threads_page(1,$1,false,true)as value',[post])).total,1);
    await rejected(db,'select dopmi_rescuer_threads_page(0)',[]);
    await rejected(db,'select dopmi_rescuer_threads_page(1,null,null)',[]);
    for(const person of [other,staff]) {
      await actor(db,person);
      assert.equal((await value(db,'select dopmi_rescuer_threads_page()as value')).total,0);
      await rejected(db,'select dopmi_rescuer_threads_page(1,$1)',[post],'42501');
      await rejected(db,'select dopmi_thread_messages($1)',[uuid('bc120000',2)],'42501');
      assert.equal((await db.query('select count(*)::int n from dopmi_messages')).rows[0].n,0);
    }
    await db.exec('reset role;set local role anon');
    await rejected(db,'select dopmi_rescuer_threads_page()',[],'42501');
  });

  test('bccd payment activity includes settled individual and Guardian net on closed cases and removes completed reversals',async()=>{
    const db=getDb();
    await db.query("update dopmi_rescue_records set public_data='{\"pet_name\":\"Luna\"}'where id=$1",[supportCase]);
    const individual=await donation(db,1);
    await donation(db,2,{payment:'pending'});await donation(db,3,{payment:'refunded'});
    const cycle=await guardian(db,1,{attention:true});await guardian(db,2,{settled:false});
    await actor(db,rescuer);
    const before=await value(db,'select dopmi_rescuer_activity()as value');
    assert.equal(before.total,2);
    assert.equal(before.items.find(e=>e.id===`individual:${individual}`).net_cents,930);
    const guardianItem=before.items.find(e=>e.id===`guardian:${cycle}:${expense}`);
    assert.equal(guardianItem.net_cents,1930);assert.equal(guardianItem.transfer_status,'attention');
    assert.ok(before.items.every(e=>e.case_id===supportCase&&e.expense_id===expense));
    await value(db,"select dopmi_transition_rescue($1,1,'close')as value",[supportCase]);
    const closed=await value(db,'select dopmi_rescuer_activity()as value');
    assert.deepEqual(new Set(closed.items.map(e=>e.id)),new Set(before.items.map(e=>e.id)));
    await db.exec('reset role');
    // Mirror the durable completed-reversal states, including both accounting equations.
    await db.query(`update dopmi_donations set payment_status='refunded',status='refunded',
      transfer_status='reversed',refund_status='refunded',allocated_cents=0,net_cents=gross_cents,
      refund_cents=gross_cents,platform_fee_cents=0,platform_loss_cents=stripe_fee_cents where id=$1`,[individual]);
    await db.query('update private.dopmi_guardian_allocations set reversed_cents=allocated_cents where cycle_id=$1',[cycle]);
    await db.query(`update private.dopmi_guardian_settlements set allocated_cents=0,refund_cents=gross_cents,
      platform_fee_cents=0,platform_loss_cents=stripe_fee_cents,refunded_at=now()where cycle_id=$1`,[cycle]);
    await db.query("update private.dopmi_guardian_cycles set status='refunded'where id=$1",[cycle]);
    await actor(db,rescuer);
    assert.equal((await value(db,'select dopmi_rescuer_activity()as value')).total,0);
    assert.equal((await value(db,'select dopmi_rescuer_dashboard_v2()as value')).payments_unseen_count,0);
    await actor(db,other);assert.equal((await value(db,'select dopmi_rescuer_activity()as value')).total,0);
  });

  test('bccd activity acknowledges exactly the presented receipt idempotently without losing a new arrival',async()=>{
    const db=getDb();await db.query('update dopmi_rescue_records set reimbursable_cents=100000 where id=$1',[expense]);
    for(let n=1;n<=25;n++)await donation(db,n,{created:`2026-10-06T10:${String(n).padStart(2,'0')}:00Z`});
    await actor(db,rescuer);
    const p1=await value(db,'select dopmi_rescuer_activity(1)as value');
    const p2=await value(db,'select dopmi_rescuer_activity(2)as value');
    assert.equal(p1.total,25);assert.equal(p1.items.length,20);assert.equal(p2.items.length,5);
    assert.equal(new Set([...p1.items,...p2.items].map(e=>e.id)).size,25);
    const dashboard=await value(db,'select dopmi_rescuer_dashboard_v2()as value');
    assert.equal(dashboard.recent_activity.length,6);assert.equal(dashboard.payments_unseen_count,25);
    const presented=dashboard.recent_activity.map(e=>e.id);
    await db.exec('reset role');const arrival=await donation(db,26,{created:'2026-10-06T11:00:00Z'});
    const staff=(await db.query('select user_id from private.admin_memberships limit 1')).rows[0].user_id;
    for(const person of [other,staff]) {
      await actor(db,person);
      await rejected(db,'select dopmi_acknowledge_rescuer_payments($1)',[dashboard.payments_cursor],'42501');
      assert.equal((await value(db,'select dopmi_rescuer_activity()as value')).total,0);
    }
    await actor(db,rescuer);
    await db.query('select dopmi_acknowledge_rescuer_payments($1)',[dashboard.payments_cursor]);
    await db.query('select dopmi_acknowledge_rescuer_payments($1)',[dashboard.payments_cursor]);
    await rejected(db,'select dopmi_acknowledge_rescuer_payments($1)',[uuid('bc990000',1)],'42501');
    const after=await value(db,'select dopmi_rescuer_dashboard_v2()as value');
    assert.equal(after.payments_unseen_count,20);
    assert.equal(after.recent_activity[0].id,`individual:${arrival}`);
    await db.exec('reset role');
    const seen=(await db.query('select event_id from private.dopmi_rescuer_activity_seen where owner_id=$1',[rescuer])).rows.map(e=>e.event_id);
    assert.deepEqual(new Set(seen),new Set(presented));
    assert.ok(!seen.includes(`individual:${arrival}`));
    await actor(db,rescuer);
    await rejected(db,'select *from private.dopmi_rescuer_activity_receipts',[],'42501');
  });

  test('bccd evidence progress checks real required fields valid dates and uploaded Storage objects',async()=>{
    const db=getDb();await actor(db,rescuer);
    let record=await value(db,"select dopmi_save_rescue('expense','{\"title\":\"Consulta\"}','{}','[]',null,null,$1)as value",[supportCase]);
    const receipt=`${rescuer}/${record.id}/${uuid('bc600000',1)}.jpg`;
    const proof=`${rescuer}/${record.id}/${uuid('bc600000',2)}.jpg`;
    const files=[{path:receipt,role:'receipt'},{path:proof,role:'proof'}];
    const pub={title:'Consulta',description:'Atención veterinaria',category:'veterinary'};
    const priv={paid_on:'2026-10-01',vendor:'Veterinaria',amount_cents:'25000',receipt_reference:'BCCDA1'};
    const save=async(publicFields=pub,privateFields=priv)=>{
      record=await value(db,'select dopmi_save_rescue($1,$2::jsonb,$3::jsonb,$4::jsonb,$5,$6,$7)as value',
        ['expense',JSON.stringify(publicFields),JSON.stringify(privateFields),JSON.stringify(files),record.id,record.version,supportCase]);
    };
    const progress=async()=>{
      const dashboard=await value(db,'select dopmi_rescuer_dashboard_v2()as value');
      return dashboard.pending_evidence.find(e=>e.expense_id===record.id).progress_percent;
    };
    await save();assert.equal(await progress(),77);
    await db.exec('reset role');
    await db.query("insert into storage.objects(bucket_id,name,metadata)values('dopmi-rescue-evidence',$1,'{\"mimetype\":\"image/jpeg\",\"size\":100}')",[receipt]);
    await actor(db,rescuer);assert.equal(await progress(),88);
    await db.exec('reset role');
    await db.query("insert into storage.objects(bucket_id,name,metadata)values('dopmi-rescue-evidence',$1,'{\"mimetype\":\"image/jpeg\",\"size\":100}')",[proof]);
    await actor(db,rescuer);assert.equal(await progress(),100);
    await save(pub,{...priv,paid_on:'2999-01-01'});assert.equal(await progress(),88);
    await save(pub,{...priv,paid_on:'2026-02-30'});assert.equal(await progress(),88);
    await save(pub,{...priv,amount_cents:'0'});assert.equal(await progress(),88);
    await save({...pub,category:'invented'});assert.equal(await progress(),88);
    await save({...pub,category:'food'});assert.equal(await progress(),90);
    await save({...pub,category:'food',round_label:'Octubre primera ronda'});assert.equal(await progress(),100);
    await actor(db,other);
    assert.ok(!(await value(db,'select dopmi_rescuer_dashboard_v2()as value')).pending_evidence.some(e=>e.expense_id===record.id));
  });

}
