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

  // Real PostgreSQL RPC/RLS cases share the established transactional harness.
  // Only this new prefix is selected for the focused location verification run.
  const rejectedCoarse = async (db, operation, code='22023') => {
    await db.exec('savepoint coarse_invalid');
    await assert.rejects(operation,e=>e.code===code);
    await db.exec('rollback to savepoint coarse_invalid; release savepoint coarse_invalid');
  };
  const saveCoarseAdoption = (db,payload,id=null,version=null) => value(db,
    'select dopmi_save_adoption($1::jsonb,$2,$3) value',[JSON.stringify(payload),id,version]);
  const saveCoarseCase = (db,payload,id=null,version=null) => value(db,
    "select dopmi_save_rescue('case',$1::jsonb,'{}','[]',$2,$3) value",[JSON.stringify(payload),id,version]);
  const coarseDiscovery = (db,filters,page=1,size=12) => value(db,
    'select dopmi_discovery($1::jsonb,$2,$3) value',[JSON.stringify(filters),page,size]);
  const noPublicCoordinates = value => assert.doesNotMatch(JSON.stringify(value),/approximate_latitude|approximate_longitude/);

  test('coarse draft choices survive save/reopen without defaults and block submission while legacy age zero stays valid',async()=>{
    const db=getDb(); await actor(db,rescuer);
    let saved=await saveCoarseAdoption(db,{species:null,sex:null,size:null,age_band:null});
    const photo=`${rescuer}/${saved.id}/00000000-0000-4000-8000-000000000001.jpg`;
    const fields={species:null,sex:null,size:null,age_band:null,photos:[photo],pet_name:'Luna',city:'Monterrey',region:'Nuevo León',
      story:'Historia suficiente para revisar la adopción.',publisher_name:'Refugio',breed:'Mestiza',age_months:0,
      publisher_bio:'Historia anterior de quien publica.',special_care:'Tratamiento anterior',social_cats:true};
    saved=await saveCoarseAdoption(db,fields,saved.id,saved.version);
    const reopened=(await db.query('select * from dopmi_adoptions where id=$1',[saved.id])).rows[0];
    for(const key of ['species','sex','size','age_band']) assert.equal(reopened[key],null,key);
    assert.deepEqual(reopened.photos,[photo]); assert.equal(reopened.breed,'Mestiza');
    assert.equal(reopened.publisher_bio,fields.publisher_bio); assert.equal(reopened.special_care,fields.special_care);
    assert.equal(reopened.social_cats,true); assert.equal(reopened.age_months,0);
    await db.exec('reset role');
    await db.query("insert into storage.objects(bucket_id,name) values('dopmi-adoption-photos',$1)",[photo]);
    await actor(db,rescuer);
    await rejectedCoarse(db,()=>db.query("select dopmi_transition_adoption($1,$2,'submit')",[saved.id,saved.version]));
    // Old clients omit the new optional age band and keep valid historical age=0.
    const selected={...fields,species:'cat',sex:'female',size:'medium'}; delete selected.age_band;
    saved=await saveCoarseAdoption(db,selected,saved.id,saved.version);
    assert.equal(saved.age_band,null); assert.equal(saved.age_months,0);
    const submitted=await value(db,"select dopmi_transition_adoption($1,$2,'submit') value",[saved.id,saved.version]);
    assert.equal(submitted.status,'submitted');
    await rejectedCoarse(db,()=>saveCoarseAdoption(db,fields,saved.id,submitted.version));
    const defaults=await saveCoarseAdoption(db,{});
    assert.equal(defaults.species,'dog'); assert.equal(defaults.sex,'female'); assert.equal(defaults.size,'medium');
    const oldUpdate=await saveCoarseAdoption(db,{pet_name:'Luna'},defaults.id,defaults.version);
    assert.equal(oldUpdate.species,'dog'); assert.equal(oldUpdate.sex,'female'); assert.equal(oldUpdate.size,'medium');
    const incomplete=await saveCoarseAdoption(db,{species:null,sex:null,size:null});
    assert.equal((await value(db,"select dopmi_transition_adoption($1,$2,'archive') value",[incomplete.id,incomplete.version])).status,'archived');
  });
  test('coarse adoption location rounds before persistence, preserves omission, and explicitly clears both coordinates',async()=>{
    const db=getDb(); await actor(db,rescuer);
    let saved=await saveCoarseAdoption(db,{approximate_latitude:25.686614,approximate_longitude:-100.316113});
    assert.equal(Number(saved.approximate_latitude),25.69); assert.equal(Number(saved.approximate_longitude),-100.32);
    saved=await saveCoarseAdoption(db,{},saved.id,saved.version);
    const reopened=(await db.query('select approximate_latitude,approximate_longitude from dopmi_adoptions where id=$1',[saved.id])).rows[0];
    assert.equal(Number(reopened.approximate_latitude),25.69); assert.equal(Number(reopened.approximate_longitude),-100.32);
    saved=await saveCoarseAdoption(db,{approximate_latitude:null,approximate_longitude:null},saved.id,saved.version);
    assert.equal(saved.approximate_latitude,null); assert.equal(saved.approximate_longitude,null);
    saved=await saveCoarseAdoption(db,{approximate_latitude:-90,approximate_longitude:180},saved.id,saved.version);
    assert.equal(Number(saved.approximate_latitude),-90); assert.equal(Number(saved.approximate_longitude),180);
  });
  test('coarse save rejects partial, nonnumeric, out-of-range locations and invalid category values without changing a draft',async()=>{
    const db=getDb(); await actor(db,rescuer);
    const saved=await saveCoarseAdoption(db,{species:null,sex:null,size:null});
    for(const payload of [
      {approximate_latitude:25.69},{approximate_longitude:-100.32},
      {approximate_latitude:null,approximate_longitude:0},{approximate_latitude:0,approximate_longitude:null},
      {approximate_latitude:'25.69',approximate_longitude:-100.32},{approximate_latitude:0,approximate_longitude:'0'},
      {approximate_latitude:true,approximate_longitude:0},{approximate_latitude:[],approximate_longitude:{}},
      {approximate_latitude:90.001,approximate_longitude:0},{approximate_latitude:0,approximate_longitude:-180.001},
      {species:''},{species:'rabbit'},{sex:'unknown'},{sex:1},{size:'tiny'},{size:false},{age_band:'juvenile'},
    ]) await rejectedCoarse(db,()=>saveCoarseAdoption(db,payload,saved.id,saved.version));
    const unchanged=(await db.query('select * from dopmi_adoptions where id=$1',[saved.id])).rows[0];
    assert.equal(unchanged.version,saved.version); assert.equal(unchanged.approximate_latitude,null); assert.equal(unchanged.species,null);
  });
  test('coarse case location stays in the private record and preserves historical needs, files, expense metadata and ownership',async()=>{
    const db=getDb(); await actor(db,rescuer);
    let saved=await saveCoarseCase(db,{pet_name:'Luna'});
    const photo=`${rescuer}/${saved.id}/00000000-0000-4000-8000-000000000002.jpg`;
    const need={id:'00000000-0000-4000-8000-000000000003',type:'veterinary',title:'Tratamiento histórico',amount_cents:1,detail:'Detalle conservado',urgent:false};
    const fields={pet_name:'Luna',size:'small',need_items:[need],approximate_latitude:25.686614,approximate_longitude:-100.316113};
    saved=await value(db,"select dopmi_save_rescue('case',$1::jsonb,'{}',$2::jsonb,$3,$4) value",
      [JSON.stringify(fields),JSON.stringify([{path:photo,role:'public'}]),saved.id,saved.version]);
    assert.equal(Number(saved.approximate_latitude),25.69); assert.equal(Number(saved.approximate_longitude),-100.32);
    noPublicCoordinates(saved.public_data); noPublicCoordinates(saved.private_data);
    assert.deepEqual(saved.public_data.need_items,[need]); assert.equal(saved.public_data.size,'small');
    const preserved=await value(db,"select dopmi_save_rescue('case',$1::jsonb,'{}',$2::jsonb,$3,$4) value",
      [JSON.stringify(saved.public_data),JSON.stringify(saved.files),saved.id,saved.version]);
    assert.equal(Number(preserved.approximate_latitude),25.69); assert.deepEqual(preserved.files,saved.files);
    assert.deepEqual(preserved.public_data.need_items,[need]);
    const detail=await value(db,'select dopmi_rescue_detail($1) value',[saved.id]);
    assert.equal(Number(detail.record.approximate_longitude),-100.32);
    const expense=await value(db,"select dopmi_save_rescue('expense','{\"title\":\"Consulta\"}','{\"amount_cents\":\"1\",\"vendor\":\"Vet\",\"paid_on\":\"2026-11-01\",\"receipt_reference\":\"A1\"}','[]',null,null,$1) value",[saved.id]);
    assert.equal(expense.private_data.amount_cents,'1'); assert.equal(expense.private_data.receipt_reference,'A1');
    for(const kind of ['expense','verification']) await rejectedCoarse(db,()=>db.query(
      'select dopmi_save_rescue($1,$2::jsonb,\'{}\',\'[]\',null,null,$3)',
      [kind,JSON.stringify({approximate_latitude:0,approximate_longitude:0}),kind==='expense'?saved.id:null]));
    await actor(db,other);
    assert.equal((await db.query('select approximate_latitude from dopmi_rescue_records where id=$1',[saved.id])).rows.length,0);
    await rejectedCoarse(db,()=>db.query('select dopmi_rescue_detail($1)',[saved.id]),'42501');
    await rejectedCoarse(db,()=>saveCoarseCase(db,fields,saved.id,preserved.version),'42501');
    await actor(db,rescuer);
    const cleared=await saveCoarseCase(db,{...preserved.public_data,approximate_latitude:null,approximate_longitude:null},saved.id,preserved.version);
    assert.equal(cleared.approximate_latitude,null); assert.equal(cleared.approximate_longitude,null);
  });
  test('coarse case save rejects malformed pairs and public views expose neither case nor adoption coordinates',async()=>{
    const db=getDb(); await actor(db,rescuer);
    for(const payload of [{approximate_latitude:1},{approximate_latitude:'1',approximate_longitude:1},
      {approximate_latitude:91,approximate_longitude:0},{approximate_latitude:0,approximate_longitude:null}])
      await rejectedCoarse(db,()=>saveCoarseCase(db,payload));
    const saved=await saveCoarseCase(db,{pet_name:'Luna',approximate_latitude:25.69,approximate_longitude:-100.32});
    await db.exec('reset role');
    await db.query("update dopmi_rescue_records set status='approved',approved_snapshot=public_data where id=$1",[saved.id]);
    await db.query("insert into dopmi_adoptions(id,owner_id,pet_name,status,approximate_latitude,approximate_longitude) values($1,$2,'Luna','published',25.69,-100.32)",[post,rescuer]);
    await actor(db,other);
    assert.equal((await db.query('select approximate_latitude from dopmi_adoptions where id=$1',[post])).rows.length,0);
    await rejectedCoarse(db,()=>saveCoarseAdoption(db,{approximate_latitude:0,approximate_longitude:0},post,1),'42501');
    await db.exec('reset role; set local role anon');
    const support=await value(db,'select dopmi_rescue_public($1) value',[saved.id]);
    assert.equal(support.items.length,1); noPublicCoordinates(support);
    noPublicCoordinates(await value(db,'select dopmi_adoption_detail($1) value',[post]));
    noPublicCoordinates(await coarseDiscovery(db,{latitude:25.69,longitude:-100.32,radius_km:20}));
    noPublicCoordinates(await value(db,"select dopmi_catalog('{}') value"));
    await rejectedCoarse(db,()=>db.query('select approximate_latitude from dopmi_adoptions'),'42501');
    await rejectedCoarse(db,()=>db.query('select approximate_latitude from dopmi_rescue_records'),'42501');
  });
  test('coarse discovery orders nearest first with deterministic pagination and rounds the origin before measuring',async()=>{
    const db=getDb();
    const ids=[1,2,3,4].map(n=>`89200000-0000-4000-8000-${String(n).padStart(12,'0')}`);
    for(const [i,id] of ids.entries()) await db.query(`insert into dopmi_adoptions(id,owner_id,pet_name,status,published_at,
      approximate_latitude,approximate_longitude) values($1,$2,$3,'published',$4,$5,0)`,
      [id,rescuer,`Mascota ${i}`,i<2?'2026-10-01T00:00:00Z':'2026-11-01T00:00:00Z',i<2?0.01:i===2?0.17:0.18]);
    await db.exec('set local role anon');
    const filters={latitude:0.0049,longitude:0.0049,radius_km:20};
    const all=await coarseDiscovery(db,filters);
    assert.equal(all.total,3); assert.deepEqual(all.items.map(x=>x.id),ids.slice(0,3));
    assert.equal(all.items[0].distance_km,1.1); assert.equal(all.items[2].distance_km,18.9);
    const pages=await Promise.all([1,2,3,4].map(n=>coarseDiscovery(db,filters,n,1)));
    assert.deepEqual(pages.flatMap(p=>p.items.map(x=>x.id)),ids.slice(0,3));
    assert.ok(pages.every(p=>p.total===3)); noPublicCoordinates(all);
    // No origin preserves the existing newest-first order and includes all rows.
    const old=await coarseDiscovery(db,{});
    assert.deepEqual(old.items.map(x=>x.id),[ids[2],ids[3],ids[0],ids[1]]);
    const strings=await coarseDiscovery(db,{latitude:'0.0049',longitude:'0.0049',radius_km:'20'});
    assert.deepEqual(strings,all);
  });
  test('coarse discovery uses an inclusive raw radius without rounded expansion and keeps published actor and trait guards',async()=>{
    const db=getDb();
    const target='89300000-0000-4000-8000-000000000001';
    await db.query(`insert into dopmi_adoptions(id,owner_id,pet_name,status,approximate_latitude,approximate_longitude,personality)
      values($1,$2,'Luna','published',0.1,0,array['calm'])`,[target,rescuer]);
    // Same PostgreSQL distance expression yields the exact inclusive boundary.
    const radius=(await db.query('select (6371*acos(cos(radians(0.1::double precision))))::numeric distance')).rows[0].distance;
    await db.exec('set local role anon');
    assert.equal((await coarseDiscovery(db,{latitude:0,longitude:0,radius_km:radius})).total,1);
    assert.equal((await coarseDiscovery(db,{latitude:0,longitude:0,radius_km:Number(radius)-0.00001})).total,0);
    assert.equal((await coarseDiscovery(db,{latitude:0,longitude:0,radius_km:20,personality:['tranquilo']})).total,1);
    assert.equal((await coarseDiscovery(db,{latitude:0,longitude:0,radius_km:20,personality:['playful']})).total,0);
    await db.exec('reset role');
    await db.query('update dopmi_adoptions set approximate_latitude=0.18 where id=$1',[target]);
    await db.exec('set local role anon');
    assert.equal((await coarseDiscovery(db,{latitude:0,longitude:0,radius_km:20})).total,0); // 20.015 km displays 20.0
    await db.exec('reset role');
    await db.query('update dopmi_adoptions set approximate_latitude=null,approximate_longitude=null where id=$1',[target]);
    await db.exec('set local role anon');
    assert.equal((await coarseDiscovery(db,{latitude:0,longitude:0,radius_km:20})).total,0);
    await db.exec('reset role');
    await db.query('update dopmi_adoptions set approximate_latitude=0.1,approximate_longitude=0,status=\'draft\' where id=$1',[target]);
    await db.exec('set local role anon');
    assert.equal((await coarseDiscovery(db,{latitude:0,longitude:0,radius_km:20})).total,0);
    await db.exec('reset role');
    await db.query("update dopmi_adoptions set status='published' where id=$1",[target]);
    await db.query("update profiles set account_status='suspended' where id=$1",[rescuer]);
    await db.exec('set local role anon');
    assert.equal((await coarseDiscovery(db,{latitude:0,longitude:0,radius_km:20})).total,0);
  });
  test('coarse discovery rejects malformed origins and pair constraints and helper ACLs remain server-enforced',async()=>{
    const db=getDb(); await db.exec('set local role anon');
    for(const filters of [
      {latitude:0,longitude:0},{latitude:null,longitude:0,radius_km:20},
      {latitude:90.001,longitude:0,radius_km:20},{latitude:0,longitude:-180.001,radius_km:20},
      {latitude:0,longitude:0,radius_km:0.99},{latitude:0,longitude:0,radius_km:101},
      {latitude:'NaN',longitude:0,radius_km:20},{latitude:0,longitude:0,radius_km:true},
      {latitude:0,longitude:0,radius_km:20,personality:['invented']},
    ]) await rejectedCoarse(db,()=>coarseDiscovery(db,filters));
    await db.exec('reset role');
    for(const role of ['anon','authenticated','service_role']) assert.equal(
      (await db.query("select has_function_privilege($1,'private.dopmi_coarse_pet_location(jsonb)','EXECUTE') permitted",[role])).rows[0].permitted,false);
    await rejectedCoarse(db,()=>db.query('insert into dopmi_adoptions(owner_id,approximate_latitude) values($1,0)',[rescuer]),'23514');
    await rejectedCoarse(db,()=>db.query("insert into dopmi_rescue_records(owner_id,kind,approximate_longitude) values($1,'case',0)",[rescuer]),'23514');
    await rejectedCoarse(db,()=>db.query("insert into dopmi_rescue_records(owner_id,kind,approximate_latitude,approximate_longitude) values($1,'expense',0,0)",[rescuer]),'23514');
    await rejectedCoarse(db,()=>db.query("insert into dopmi_adoptions(owner_id,status,species) values($1,'published',null)",[rescuer]),'23514');
  });
}
