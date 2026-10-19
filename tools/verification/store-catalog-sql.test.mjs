import {PGlite} from '@electric-sql/pglite';
import {readFile,readdir} from 'node:fs/promises';
import test from 'node:test';
import assert from 'node:assert/strict';

const admin='00000000-0000-0000-0000-000000000001';
const reader='00000000-0000-0000-0000-000000000002';
async function database() {
  const db=new PGlite();
  await db.exec(`create role anon; create role authenticated; create schema private; create schema auth;
    create table auth.users(id uuid primary key); insert into auth.users values('${admin}'),('${reader}');
    create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create function public.dopmi_is_admin() returns boolean language sql as $$ select auth.uid()='${admin}'::uuid $$;`);
  const dir=new URL('../../supabase/migrations/',import.meta.url);
  let sql='';
  if(process.env.DOPMI_STORE_SQL_FILE) sql=await readFile(process.env.DOPMI_STORE_SQL_FILE,'utf8');
  for(const file of sql?[]:(await readdir(dir)).sort().reverse()) {
    const candidate=await readFile(new URL(file,dir),'utf8');
    if(candidate.includes('create table private.dopmi_store_settings')) {
      sql=candidate.match(/-- BEGIN DOPMI STORE CATALOG([\s\S]*?)-- END DOPMI STORE CATALOG/)?.[1] ?? candidate;
      break;
    }
  }
  assert.ok(sql, 'Store is verified from the tracked migration');
  await db.exec(sql);
  return db;
}
async function asUser(db,id) {await db.exec(`reset role; select set_config('request.jwt.claim.sub','${id}',false); set role authenticated;`);}
const merchant={name:'Comercio de prueba',domain:'shop.example',enabled:true,permission_reviewed:true,rights_reviewed:true,links_reviewed:true,approval_reference:'Permiso test documentado'};
const product={name:'Alimento prueba',brand:'Marca real',species:'dog',age:'adult',size:'small',weight_kg:10,position:0,image_url:'https://shop.example/image.jpg',image_rights_reference:'Licencia test documentada',external_url:'https://shop.example/alimento',published:true};
async function save(db,entity,payload,merchantId=null,id=null,version=0) {
 return (await db.query('select public.dopmi_admin_save_store($1,$2,$3,$4,$5) result',[entity,id,version,payload,merchantId])).rows[0].result;
}
test('PostgreSQL protects catalog, validates publication and serves exact current links only after server gate',async()=>{
 const db=await database();
 try {
  await asUser(db,reader);
  await assert.rejects(db.query('select public.dopmi_admin_store_catalog()'),/administrativo/);
  await assert.rejects(save(db,'merchant',merchant),/administrativo/);
  await assert.rejects(db.query('select * from private.dopmi_store_products'),/permission denied/);
  await asUser(db,admin);
  await assert.rejects(save(db,'merchant',{...merchant,permission_reviewed:false}),/Falta revisión/);
  const m=await save(db,'merchant',merchant);
  const requestId='00000000-0000-0000-0000-000000000099';
  const created=await save(db,'merchant',merchant,null,requestId,0);
  const retried=await save(db,'merchant',merchant,null,requestId,0);
  assert.deepEqual(retried,created);
  await assert.rejects(save(db,'merchant',{...merchant,name:'Different payload'},null,requestId,0),/registro cambió/);
  await db.exec(`reset role; create or replace function public.dopmi_is_admin() returns boolean language sql as $$ select auth.uid() in ('${admin}'::uuid,'${reader}'::uuid) $$;`);
  await asUser(db,reader);
  await assert.rejects(save(db,'merchant',merchant,null,requestId,0),/registro cambió/);
  await db.exec(`reset role; create or replace function public.dopmi_is_admin() returns boolean language sql as $$ select auth.uid()='${admin}'::uuid $$;`);
  await asUser(db,admin);
  await save(db,'merchant',merchant,null,requestId,1);
  await assert.rejects(save(db,'merchant',merchant,null,requestId,0),/registro cambió/);
  for(const external_url of ['http://shop.example/item','https://shop.example.evil/item','https://user@shop.example/item','https://shop.example:8443/item','https://shop.example/redirect?url=https://evil.test']) {
   await assert.rejects(save(db,'product',{...product,external_url},m.id),/dominio autorizado/);
  }
  await assert.rejects(save(db,'product',{...product,brand:''},m.id),/inválida/);
  await assert.rejects(save(db,'product',{...product,age:'all'},m.id),/inválida/);
  await assert.rejects(save(db,'product',{...product,size:'all'},m.id),/inválida/);
  await assert.rejects(save(db,'product',{...product,image_url:'https://cdn.example/photo.jpg'},m.id),/derechos/);
  const cdnMerchant=await save(db,'merchant',{...merchant,image_domain:'cdn.example'});
  const cdnProduct=await save(db,'product',{...product,image_url:'https://cdn.example/photo.jpg'},cdnMerchant.id);
  await save(db,'product',{...product,image_url:'https://cdn.example/photo.jpg',published:false},cdnMerchant.id,cdnProduct.id,cdnProduct.version);
  await assert.rejects(save(db,'product',{...product,image_url:'https://evil.example/photo.jpg'},cdnMerchant.id),/derechos/);
  const p=await save(db,'product',product,m.id);
  const productRequest='00000000-0000-0000-0000-000000000098';
  const idempotentProduct=await save(db,'product',{...product,published:false},m.id,productRequest,0);
  assert.deepEqual(await save(db,'product',{...product,published:false},m.id,productRequest,0),idempotentProduct);
  await assert.rejects(save(db,'product',{...product,published:false},cdnMerchant.id,productRequest,0),/registro cambió/);
  const q=await save(db,'product',{...product,weight_kg:2},m.id);
  await assert.rejects(save(db,'product',product,m.id,p.id,999),/registro cambió/);
  const preview=(await db.query('select public.dopmi_admin_store_catalog() data')).rows[0].data;
  assert.equal(preview.products.length,4);
  await asUser(db,reader);
  assert.deepEqual((await db.query('select public.dopmi_store_catalog() data')).rows[0].data,{enabled:false,items:[]});
  assert.equal((await db.query('select public.dopmi_store_product_link($1) url',[p.id])).rows[0].url,null);
  await db.exec("reset role; set role anon;");
  assert.deepEqual((await db.query('select public.dopmi_store_catalog() data')).rows[0].data,{enabled:false,items:[]});
  await assert.rejects(db.query('select public.dopmi_admin_store_catalog()'),/permission denied/);
  await db.exec("reset role; update private.dopmi_store_settings set enabled=true,activation_reference='Prueba local autorizada'; set role authenticated;");
  const visible=(await db.query('select public.dopmi_store_catalog($1) data',[{brand:'Marca real',sort:'weight_asc'}])).rows[0].data;
  assert.deepEqual(visible.items.map(item=>item.id),[q.id,p.id]);
  assert.equal('external_url' in visible.items[0],false);
  assert.equal((await db.query('select public.dopmi_store_catalog($1) data',[{species:'cat'}])).rows[0].data.items.length,0);
  assert.equal((await db.query('select public.dopmi_store_product_link($1) url',[p.id])).rows[0].url,product.external_url);
  await asUser(db,admin);
  await save(db,'merchant',{...merchant,enabled:false},null,m.id,m.version);
  await asUser(db,reader);
  assert.equal((await db.query('select public.dopmi_store_catalog() data')).rows[0].data.items.length,0);
  assert.equal((await db.query('select public.dopmi_store_product_link($1) url',[p.id])).rows[0].url,null);
  await assert.rejects(db.query('select public.dopmi_admin_delete_store($1,$2,$3)',['product',p.id,p.version]),/administrativo/);
  await asUser(db,admin);
  await db.query('select public.dopmi_admin_delete_store($1,$2,$3)',['product',p.id,p.version]);
  assert.equal((await db.query('select public.dopmi_admin_store_catalog() data')).rows[0].data.products.length,3);
 }finally{await db.close();}
});
