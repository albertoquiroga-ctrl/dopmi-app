import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import test from 'node:test';
import assert from 'node:assert/strict';

const admin='00000000-0000-0000-0000-000000000001';
const tester='00000000-0000-0000-0000-000000000002';
const ordinary='00000000-0000-0000-0000-000000000003';
const disabled={enabled:false,preview:true,items:[]};
async function database() {
 const db=new PGlite();
 await db.exec(`create role anon; create role authenticated; create schema private; create schema auth;
   create table auth.users(id uuid primary key,email_confirmed_at timestamptz,raw_user_meta_data jsonb default '{}');
   create table public.profiles(id uuid primary key references auth.users(id),account_status text default 'active',active_mode text default 'donor');
   insert into auth.users(id,email_confirmed_at) values('${admin}',now()),('${tester}',now()),('${ordinary}',now());
   insert into public.profiles(id) select id from auth.users;
   create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
   create function public.dopmi_is_admin() returns boolean language sql as $$ select auth.uid()='${admin}'::uuid $$;`);
 const commercial=await readFile(new URL('../../supabase/migrations/20261019041400_integral_video_store_foundation.sql',import.meta.url),'utf8');
 await db.exec(commercial.match(/-- BEGIN DOPMI STORE CATALOG([\s\S]*?)-- END DOPMI STORE CATALOG/)[1]);
 await db.exec(await readFile(new URL('../../supabase/migrations/20261023013846_store_private_test_preview.sql',import.meta.url),'utf8'));
 return db;
}
async function asUser(db,id) {
 await db.exec(`reset role; select set_config('request.jwt.claim.sub','${id ?? ''}',false); set role ${id?'authenticated':'anon'};`);
}
async function catalog(db,filters={}) {
 return (await db.query('select public.dopmi_store_preview_catalog($1) data',[filters])).rows[0].data;
}
async function enableFixture(db) {
 await db.exec(`reset role;
  update private.dopmi_store_preview_settings set enabled=true,activation_reference='Local authorized TEST fixture';
  insert into private.dopmi_store_preview_grants(user_id,expires_at,authorization_reference)
    values('${tester}',now()+interval '1 hour','Local tester explicitly selected');
  insert into private.dopmi_store_preview_products(id,name,brand,species,age,size,weight_kg,position,enabled) values
   ('10000000-0000-0000-0000-000000000001','Alimento TEST adulto','Marca TEST Uno','dog','adult','small',10,2,true),
   ('10000000-0000-0000-0000-000000000002','Alimento TEST cachorro','Marca TEST Uno','dog','puppy','medium',2,1,true),
   ('10000000-0000-0000-0000-000000000003','Alimento TEST gato','Marca TEST Dos','cat','senior','large',3,0,true),
   ('10000000-0000-0000-0000-000000000004','Oculto TEST','Marca TEST Dos','cat','adult','large',1,0,false);`);
}
const first='10000000-0000-0000-0000-000000000001';
async function link(db,id=first) {
 return (await db.query('select public.dopmi_store_preview_product_link($1) url',[id])).rows[0].url;
}

test('private TEST preview starts closed with no account grants and leaves the commercial gate exact',async()=>{
 const db=await database();
 try {
  assert.equal((await db.query('select count(*)::int n from private.dopmi_store_preview_grants')).rows[0].n,0);
  assert.equal((await db.query('select count(*)::int n from private.dopmi_store_preview_products')).rows[0].n,0);
  for(const id of [tester,ordinary,admin]) {
   await asUser(db,id);
   assert.deepEqual(await catalog(db),disabled);
   assert.deepEqual((await db.query('select public.dopmi_store_catalog() data')).rows[0].data,{enabled:false,items:[]});
   assert.equal((await db.query('select public.dopmi_store_preview_product_link($1) url',[tester])).rows[0].url,null);
  }
  await asUser(db,null);
  await assert.rejects(catalog(db),/permission denied/);
 } finally {await db.close();}
});

test('only the chosen account sees synthetic TEST inventory, real filters and deterministic order',async()=>{
 const db=await database();
 try {
  await enableFixture(db);
  for(const id of [ordinary,admin]) {await asUser(db,id);assert.deepEqual(await catalog(db),disabled);}
  await asUser(db,tester);
  const all=await catalog(db);
  assert.equal(all.enabled,true);
  assert.equal(all.preview,true);
  assert.equal(all.external_links_enabled,false);
  assert.ok(Date.parse(all.expires_at)>Date.now());
  assert.deepEqual(all.items.map(p=>p.name),['Alimento TEST gato','Alimento TEST cachorro','Alimento TEST adulto']);
  assert.ok(all.items.every(p=>p.asset_key==='croquetas-banner-pet' && p.merchant_name==='Dopmi TEST'));
  assert.ok(all.items.every(p=>!('external_url' in p) && !('image_url' in p) && !('destination_id' in p)));
  assert.deepEqual((await catalog(db,{sort:'weight_asc'})).items.map(p=>p.weight_kg),[2,3,10]);
  assert.deepEqual((await catalog(db,{sort:'weight_desc'})).items.map(p=>p.weight_kg),[10,3,2]);
  for(const [filter,value,expected] of [['species','cat','Alimento TEST gato'],['age','puppy','Alimento TEST cachorro'],['size','small','Alimento TEST adulto']]) {
   assert.deepEqual((await catalog(db,{[filter]:value})).items.map(p=>p.name),[expected]);
  }
  assert.equal((await catalog(db,{brand:'Marca TEST Uno'})).items.length,2);
  assert.deepEqual((await catalog(db,{species:'cat',age:'puppy'})).items,[]);
  await assert.rejects(catalog(db,[]),/Filtros de prueba inválidos/);
  await assert.rejects(catalog(db,{brand:'x'.repeat(2100)}),/Filtros de prueba inválidos/);
  await assert.rejects(db.query('select public.dopmi_admin_store_catalog()'),/administrativo/);
  assert.equal(await link(db),null);
  await db.exec(`reset role;update auth.users set raw_user_meta_data='{"admin":true,"store_preview":true}' where id='${ordinary}';
   update public.profiles set active_mode='rescuer' where id='${ordinary}';`);
  await asUser(db,ordinary);assert.deepEqual(await catalog(db),disabled);
 } finally {await db.close();}
});

test('expiry, revocation, future grants, suspension and unconfirmed email close both RPC immediately',async()=>{
 const db=await database();
 try {
  await enableFixture(db);
  await db.exec(`insert into private.dopmi_store_preview_destinations(id,exact_url,enabled,authorization_reference)
   values('${ordinary}','https://qa.example/approved-test',true,'Local exact QA target reviewed');
   update private.dopmi_store_preview_products set destination_id='${ordinary}' where id='${first}';
   update private.dopmi_store_preview_settings set external_links_enabled=true;`);
  await asUser(db,tester);assert.equal(await link(db),'https://qa.example/approved-test');
  const changes=[
   [`update private.dopmi_store_preview_grants set granted_at=now()-interval '2 hours',expires_at=now()-interval '1 hour'`,
    `update private.dopmi_store_preview_grants set granted_at=now(),expires_at=now()+interval '1 hour'`],
   [`update private.dopmi_store_preview_grants set revoked_at=now()`, `update private.dopmi_store_preview_grants set revoked_at=null`],
   [`update private.dopmi_store_preview_grants set granted_at=now()+interval '10 minutes'`, `update private.dopmi_store_preview_grants set granted_at=now()`],
   [`update public.profiles set account_status='suspended' where id='${tester}'`, `update public.profiles set account_status='active' where id='${tester}'`],
   [`update auth.users set email_confirmed_at=null where id='${tester}'`, `update auth.users set email_confirmed_at=now() where id='${tester}'`],
   [`update private.dopmi_store_preview_settings set enabled=false`, `update private.dopmi_store_preview_settings set enabled=true`],
  ];
  for(const [close,restore] of changes) {
   await db.exec(`reset role;${close};`);await asUser(db,tester);
   assert.deepEqual(await catalog(db),disabled,close);
   assert.equal(await link(db),null,close);
   await db.exec(`reset role;${restore};`);await asUser(db,tester);
   assert.equal((await catalog(db)).enabled,true,restore);
   assert.equal(await link(db),'https://qa.example/approved-test',restore);
  }
  await asUser(db,ordinary);assert.equal(await link(db),null);
  await db.exec('reset role;delete from private.dopmi_store_preview_grants;');
  await asUser(db,tester);assert.deepEqual(await catalog(db),disabled);assert.equal(await link(db),null);
  await db.exec('reset role;');assert.equal((await db.query('select count(*)::int n from auth.users')).rows[0].n,3);
 } finally {await db.close();}
});

test('account grants cannot be read or self-assigned, all private tables use RLS, RPC ACL excludes anon',async()=>{
 const db=await database();
 try {
  await enableFixture(db);
  const tables=['settings','grants','products','destinations'];
  for(const role of [tester,ordinary,null]) {
   await asUser(db,role);
   for(const suffix of tables) {
    await assert.rejects(db.query(`select * from private.dopmi_store_preview_${suffix}`),/permission denied/);
    await assert.rejects(db.query(`delete from private.dopmi_store_preview_${suffix}`),/permission denied/);
   }
   await assert.rejects(db.query(`insert into private.dopmi_store_preview_grants(user_id,expires_at,authorization_reference) values('${ordinary}',now()+interval '1 hour','Forged self-service grant')`),/permission denied/);
   await assert.rejects(db.query('select private.dopmi_store_preview_expires_at()'),/permission denied/);
  }
  await asUser(db,null);await assert.rejects(link(db),/permission denied/);
  await db.exec('reset role;');
  const rls=(await db.query("select relname,relrowsecurity from pg_class join pg_namespace n on n.oid=relnamespace where n.nspname='private' and relname like 'dopmi_store_preview_%'")).rows;
  assert.equal(rls.filter(r=>tables.some(t=>r.relname===`dopmi_store_preview_${t}`)).length,4);
  assert.ok(rls.filter(r=>tables.some(t=>r.relname===`dopmi_store_preview_${t}`)).every(r=>r.relrowsecurity));
  await db.exec(`update private.dopmi_store_preview_grants set expires_at='infinity'` ).then(()=>assert.fail('unbounded grant accepted'),e=>assert.match(e.message,/check constraint/));
 } finally {await db.close();}
});

test('outbound preview links require exact separately authorized destinations and recheck current availability',async()=>{
 const db=await database();
 try {
  await enableFixture(db);
  for(const exact_url of ['http://qa.example/test','https://user@qa.example/test','https://qa.example:8443/test','https://qa.example/test?token=private','https://qa.example/test#fragment','https://qa.example/%2fredirect','https://qa.example/redirect']) {
   await assert.rejects(db.query('insert into private.dopmi_store_preview_destinations(exact_url,authorization_reference) values($1,$2)',[exact_url,'Local destination validation']),/check constraint/);
  }
  await db.exec(`insert into private.dopmi_store_preview_destinations(id,exact_url,enabled,authorization_reference) values('${ordinary}','https://qa.example/approved-test',true,'Local exact QA target reviewed');
   update private.dopmi_store_preview_products set destination_id='${ordinary}' where id='${first}';`);
  await asUser(db,tester);assert.equal(await link(db),null,'external gate stays closed even with a destination');
  await db.exec('reset role;update private.dopmi_store_preview_settings set external_links_enabled=true;');
  await asUser(db,tester);assert.equal(await link(db),'https://qa.example/approved-test');
  assert.equal(await link(db,ordinary),null,'no arbitrary product identifier can become a link');
  for(const table of ['products','destinations']) {
   await db.exec(`reset role;update private.dopmi_store_preview_${table} set enabled=false;`);await asUser(db,tester);
   assert.equal(await link(db),null);
   await db.exec(`reset role;update private.dopmi_store_preview_${table} set enabled=true;`);
  }
 } finally {await db.close();}
});

test('commercial RPC never leaks preview products, and preview never includes pending or approved commercial inventory',async()=>{
 const db=await database();
 try {
  await enableFixture(db);
  await asUser(db,admin);
  const merchant=(await db.query('select public.dopmi_admin_save_store($1,$2,$3,$4,$5) data',['merchant',null,0,{name:'Commercial pending',domain:'shop.example',enabled:false,permission_reviewed:false,rights_reviewed:false,links_reviewed:false,approval_reference:''},null])).rows[0].data;
  await db.query('select public.dopmi_admin_save_store($1,$2,$3,$4,$5)',['product',null,0,{name:'Commercial draft',brand:'Commercial brand',species:'dog',age:'adult',size:'small',weight_kg:5,position:0,image_url:'https://shop.example/image.jpg',image_rights_reference:'Local image permission',external_url:'https://shop.example/product',published:false},merchant.id]);
  await asUser(db,tester);
  assert.equal((await catalog(db)).items.length,3);
  assert.deepEqual((await db.query('select public.dopmi_store_catalog() data')).rows[0].data,{enabled:false,items:[]});
  await db.exec(`reset role;update private.dopmi_store_settings set enabled=true,activation_reference='Local commercial test only';`);
  await asUser(db,tester);
  assert.deepEqual((await db.query('select public.dopmi_store_catalog() data')).rows[0].data,{enabled:true,items:[]});
  await db.exec(`reset role;update private.dopmi_store_merchants set data=data||'{"enabled":true,"permission_reviewed":true,"rights_reviewed":true,"links_reviewed":true,"approval_reference":"Local commerce authorized"}'::jsonb;
   update private.dopmi_store_products set data=data||'{"published":true}'::jsonb;`);
  await asUser(db,tester);
  const commercial=(await db.query('select public.dopmi_store_catalog() data')).rows[0].data;
  assert.deepEqual(commercial.items.map(p=>p.name),['Commercial draft']);
  assert.ok((await catalog(db)).items.every(p=>p.name.includes('TEST')));
  assert.equal(await link(db,commercial.items[0].id),null);
 } finally {await db.close();}
});
