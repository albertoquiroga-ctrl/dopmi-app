import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile,readdir } from 'node:fs/promises';
import { randomUUID,createHash } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';
import { paymentService } from '../../supabase/functions/_shared/payments.mjs';
let db; const sources=[];
before(async()=>{db=new PGlite();
  await db.exec(`do $$begin
    if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
    if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
    if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
    end$$;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  await db.exec(`create function auth.jwt() returns jsonb language sql stable as $$ select jsonb_build_object('role',current_setting('request.jwt.claim.role',true)) $$;`);
  const path = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(path)).filter(x => x.endsWith('.sql')).sort()) {
    const bytes = await readFile(new URL(file, path));
    await db.exec(bytes.toString('utf8'));
    sources.push({ file, sha256: createHash('sha256').update(bytes).digest('hex') });
  }

 assert.ok(sources.some(x=>x.file==='20261019041400_integral_video_store_foundation.sql'), 'Video is verified from the tracked migration');
 await db.exec('update private.dopmi_video_settings set enabled=true');
},{timeout:120000});
after(async()=>await db?.close());
async function actor(id,role='authenticated') {await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claim.role',$2,false)",[id,role]);}
async function fixture(kind='case') {
 const owner=randomUUID(), other=randomUUID(),staff=randomUUID(),parent=randomUUID();
 for(const id of [owner,other,staff])await db.query("insert into auth.users(id,email_confirmed_at,raw_user_meta_data) values($1,now(),$2::jsonb)",[id,JSON.stringify({display_name:'Synthetic video test',terms_accepted:true,terms_version:'development-2026-09-13'})]);
 await db.query('insert into private.admin_memberships(user_id) values($1)',[staff]);
 await db.query("insert into public.dopmi_rescue_records(owner_id,kind,status) values($1,'verification','approved')",[owner]);
 await db.query("insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled) values($1,$2,true,true)",[owner,`acct_synthetic_${owner.replaceAll('-','')}`]);
 await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,status) values($1,$2,$3,'draft')",[parent,owner,kind]);
 return {owner,other,staff,parent};
}
async function action(f,data,who=f.owner){await actor(who);return (await db.query('select public.dopmi_video_action($1::jsonb) v',[JSON.stringify(data)])).rows[0].v;}
async function service(data){await actor('','service_role');return (await db.query('select public.dopmi_video_service($1::jsonb) v',[JSON.stringify(data)])).rows[0].v;}
const begin=(f,extra={})=>({action:'begin',parent_id:f.parent,parent_version:1,purpose:'thanks',request_key:randomUUID(),bytes:1024,...extra});
async function ready(a){await service({action:'claim',id:a.id});await service({action:'bind',id:a.id,provider_id:randomUUID().replaceAll('-',''),upload_url:'https://upload.videodelivery.net/test'});const row=(await db.query('select provider_id from private.dopmi_video_assets where id=$1',[a.id])).rows[0];await service({action:'refresh',provider_id:row.provider_id,state:'ready',duration:59});return row;}
test('idempotency and parent ownership/version are enforced in PostgreSQL',async()=>{const f=await fixture(),data=begin(f);const a=await action(f,data);assert.equal((await action(f,data)).id,a.id);await assert.rejects(action(f,{...data,bytes:2048}));await assert.rejects(action(f,begin(f),f.other));await assert.rejects(action(f,begin(f,{parent_version:2})));assert.equal((await service({action:'claim',id:a.id})).claimed,true);assert.equal((await service({action:'claim',id:a.id})).claimed,false);});
test('cancellation and late hooks never resurrect an asset',async()=>{const f=await fixture(),a=await action(f,begin(f)),p=await ready(a);await action(f,{action:'cancel',id:a.id});await service({action:'refresh',provider_id:p.provider_id,state:'ready',duration:59});assert.equal((await action(f,{action:'status',id:a.id})).technical_state,'canceled');await assert.rejects(action(f,{action:'playback',id:a.id},f.other));});
test('new case needs ready thanks; old cases retain grandfathered submission',async()=>{const f=await fixture();await assert.rejects(db.query("update public.dopmi_rescue_records set status='submitted' where id=$1",[f.parent]));const a=await action(f,begin(f));await ready(a);await db.query("update public.dopmi_rescue_records set status='submitted',version=2 where id=$1",[f.parent]);await assert.rejects(db.query("update public.dopmi_rescue_records set status='approved' where id=$1",[f.parent]));await action(f,{action:'review',id:a.id,parent_version:2,decision:'approved'},f.staff);await db.query("update public.dopmi_rescue_records set status='approved',approved_snapshot='{}',version=3 where id=$1",[f.parent]);assert.equal((await action(f,{action:'playback',id:a.id},f.other)).technical_state,'ready');});
test('stale content cannot be reviewed; metadata does not grant staff',async()=>{const f=await fixture(),a=await action(f,begin(f));await ready(a);await db.query("update public.dopmi_rescue_records set status='submitted',version=2 where id=$1",[f.parent]);await assert.rejects(action(f,{action:'review',id:a.id,parent_version:2,decision:'approved'},f.other));await db.query("update public.dopmi_rescue_records set status='draft',public_data='{\"title\":\"edited\"}',version=3 where id=$1",[f.parent]);await assert.rejects(action(f,{action:'review',id:a.id,parent_version:2,decision:'approved'},f.staff));});

test('anonymous public playback/list preserve parent visibility and reject drafts/private actions',async()=>{
 const f=await fixture(), a=await action(f,begin(f));await ready(a);
 await actor('','anon');await db.exec('set role anon');
 try{await assert.rejects(db.query('select public.dopmi_video_action($1::jsonb)',[JSON.stringify({action:'playback',id:a.id})]));await assert.rejects(db.query('select public.dopmi_video_action($1::jsonb)',[JSON.stringify(begin(f))]));await assert.rejects(db.exec('select * from private.dopmi_video_assets'));}finally{await db.exec('reset role');}
 await db.query("update public.dopmi_rescue_records set status='submitted',version=2 where id=$1",[f.parent]);
 await action(f,{action:'review',id:a.id,parent_version:2,decision:'approved'},f.staff);
 await db.query("update public.dopmi_rescue_records set status='approved',approved_snapshot='{}',version=3 where id=$1",[f.parent]);
 await actor('','anon');await db.exec('set role anon');
 try{const publicRead=(await db.query('select public.dopmi_video_action($1::jsonb) v',[JSON.stringify({action:'playback',id:a.id})])).rows[0].v;assert.equal(publicRead.upload_url,null);const list=(await db.query('select public.dopmi_video_action($1::jsonb) v',[JSON.stringify({action:'public_list',parent_id:f.parent})])).rows[0].v;assert.equal(list.items.length,1);await assert.rejects(db.query('select public.dopmi_video_action($1::jsonb)',[JSON.stringify({action:'status',id:a.id})]));}finally{await db.exec('reset role');}
 await db.query("update public.dopmi_rescue_records set status='rejected' where id=$1",[f.parent]);
 await actor('','anon');await assert.rejects(db.query('select public.dopmi_video_action($1::jsonb)',[JSON.stringify({action:'playback',id:a.id})]));
});
test('financial evidence remains private after video and expense approval; null duration cannot become ready',async()=>{
 const f=await fixture(), expense=randomUUID();
 await db.query("update public.dopmi_rescue_records set video_thanks_required=false,status='approved',approved_snapshot='{}' where id=$1",[f.parent]);
 await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,status,approved_snapshot) values($1,$2,'expense',$3,'approved','{}')",[expense,f.owner,f.parent]);
 const a=await action(f,{...begin(f),parent_id:expense,purpose:'expense_evidence'});const p=await ready(a);
 await action(f,{action:'review',id:a.id,parent_version:1,decision:'approved'},f.staff);
 await assert.rejects(action(f,{action:'playback',id:a.id},f.other));assert.equal((await action(f,{action:'public_list',parent_id:expense},f.other)).items.length,0);
 await assert.rejects(service({action:'refresh',provider_id:p.provider_id,state:'ready',duration:null}));
 assert.equal((await db.query('select count(*)::int n from private.dopmi_video_reviews where asset_id=$1',[a.id])).rows[0].n,1);
});
test('legacy draft with grandfather flag submits without thanks; module default-off preparation has no new published requirement',async()=>{const f=await fixture();await db.query("update public.dopmi_rescue_records set video_thanks_required=false,status='submitted' where id=$1",[f.parent]);assert.equal((await db.query('select status from public.dopmi_rescue_records where id=$1',[f.parent])).rows[0].status,'submitted');});

test('parent deletion preserves durable provider cleanup without blocking existing lifecycle',async()=>{const f=await fixture(),a=await action(f,begin(f));const p=await ready(a);await assert.rejects(db.query('delete from public.dopmi_rescue_records where id=$1',[f.parent]));await db.query('delete from private.dopmi_urgent_coverage_state where case_id=$1',[f.parent]);await db.query('delete from public.dopmi_rescue_records where id=$1',[f.parent]);const queue=await service({action:'cleanup_list'});assert.ok(queue.items.includes(p.provider_id));assert.equal((await db.query('select count(*)::int n from private.dopmi_video_assets where id=$1',[a.id])).rows[0].n,0);await service({action:'cleanup_done',provider_id:p.provider_id});assert.ok(!(await service({action:'cleanup_list'})).items.includes(p.provider_id));});

test('owner policy restores asset metadata without upload capabilities or private provider IDs',async()=>{const f=await fixture(),data=begin(f,{file_fingerprint:'a'.repeat(64)}),a=await action(f,data);await ready(a);await actor(f.owner);const value=(await db.query('select public.dopmi_video_policy($1) v',[f.parent])).rows[0].v;assert.equal(value.enabled,true);assert.equal(value.thanks_required,true);assert.equal(value.assets[0].request_key,data.request_key);assert.equal(value.assets[0].file_fingerprint,'a'.repeat(64));assert.equal(value.assets[0].provider_id,undefined);assert.equal(value.assets[0].upload_url,undefined);await actor(f.other);await assert.rejects(db.query('select public.dopmi_video_policy($1)',[f.parent]));});
test('waiting for upload preserves capability; bind readback recognizes committed binding and canceled orphan remains queued',async()=>{const f=await fixture(),a=await action(f,begin(f)),provider=randomUUID().replaceAll('-','');await service({action:'claim',id:a.id});await service({action:'created',id:a.id,provider_id:provider});await service({action:'bind',id:a.id,provider_id:provider,upload_url:'https://upload.videodelivery.net/resume'});await service({action:'refresh',provider_id:provider,state:'uploading',duration:null});assert.equal((await action(f,{action:'status',id:a.id})).upload_url,'https://upload.videodelivery.net/resume');assert.equal((await service({action:'binding',id:a.id,provider_id:provider})).bound,true);await action(f,{action:'cancel',id:a.id});assert.ok((await service({action:'cleanup_list'})).items.includes(provider));await service({action:'refresh',provider_id:provider,state:'ready',duration:10});assert.equal((await action(f,{action:'status',id:a.id})).technical_state,'canceled');});
test('cases submitted while feature was off remain grandfathered when enabled',async()=>{await db.exec('update private.dopmi_video_settings set enabled=false');const f=await fixture();await db.query("update public.dopmi_rescue_records set status='submitted',version=2 where id=$1",[f.parent]);await db.exec('update private.dopmi_video_settings set enabled=true');await db.query("update public.dopmi_rescue_records set status='approved',approved_snapshot='{}',version=3 where id=$1",[f.parent]);assert.equal((await db.query('select video_thanks_required from public.dopmi_rescue_records where id=$1',[f.parent])).rows[0].video_thanks_required,false);});
test('account deletion status withdraws retained public videos but preserves private expense evidence',async()=>{const f=await fixture(),publicAsset=await action(f,begin(f)),publicProvider=await ready(publicAsset),expense=randomUUID();await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,status,approved_snapshot) values($1,$2,'expense',$3,'approved','{}')",[expense,f.owner,f.parent]);const privateAsset=await action(f,{...begin(f),parent_id:expense,purpose:'expense_evidence'}),privateProvider=await ready(privateAsset);await db.query("update public.profiles set account_status='deletion_requested' where id=$1",[f.owner]);assert.equal((await db.query('select count(*)::int n from private.dopmi_video_assets where id=$1',[publicAsset.id])).rows[0].n,0);assert.equal((await db.query('select technical_state from private.dopmi_video_assets where id=$1',[privateAsset.id])).rows[0].technical_state,'ready');const queue=await service({action:'cleanup_list'});assert.ok(queue.items.includes(publicProvider.provider_id));assert.ok(!queue.items.includes(privateProvider.provider_id));});

// End-to-end lifecycle uses the established fresh local financial fixture pattern.
// No UPDATE of profile.account_status substitutes for request/finalize here.
for(const presentationState of ['ready','processing'])test('real account deletion request/finalize and retries preserve financial video while withdrawing '+presentationState+' presentation',async()=>{
 const f=await fixture(),expense=randomUUID(),paymentKey=randomUUID(),deleteKey=randomUUID(),suffix=randomUUID().replaceAll('-','');
 await db.query("update public.dopmi_rescue_records set video_thanks_required=false,status='approved',approved_snapshot='{\"pet_name\":\"Synthetic\"}' where id=$1",[f.parent]);
 const details={public_data:{title:'Synthetic medicines'},private_data:{invoice:'synthetic-private-only'},files:[{path:'synthetic/financial-proof.pdf'}]};
 await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,status,approved_snapshot,reimbursable_cents,public_data,private_data,files) values($1,$2,'expense',$3,'approved','{\"title\":\"Synthetic medicines\"}',12000,$4,$5,$6)",[expense,f.owner,f.parent,JSON.stringify(details.public_data),JSON.stringify(details.private_data),JSON.stringify(details.files)]);
 await db.query('update private.dopmi_connect_accounts set account_id=$2 where owner_id=$1',[f.owner,'acct_'+suffix]);
 await db.query("update public.dopmi_rescue_records set public_data=$2 where id=$1",[f.parent,JSON.stringify({need_items:[{id:randomUUID(),type:'medicine',title:'Synthetic urgent medicine',amount_cents:1000,detail:'Synthetic fixture',urgent:true}]})]);
 const presentation=await action(f,begin(f,{purpose:'public_update'})),presentationProvider=await ready(presentation);
 if(presentationState==='processing')await service({action:'refresh',provider_id:presentationProvider.provider_id,state:'processing',duration:null});
 // The production service ignores ready->processing regression, so create a separate
 // actual processing upload for that scenario rather than forcing technical state.
 let presented=presentation,presentedProvider=presentationProvider;
 if(presentationState==='processing'){
   presented=await action(f,begin(f,{purpose:'urgency'}));const provider_id=randomUUID().replaceAll('-','');
   await service({action:'claim',id:presented.id});await service({action:'created',id:presented.id,provider_id});await service({action:'bind',id:presented.id,provider_id,upload_url:'https://upload.videodelivery.net/synthetic-processing'});await service({action:'refresh',provider_id,state:'processing',duration:null});presentedProvider={provider_id};
 }
 const financial=await action(f,{...begin(f),parent_id:expense,purpose:'expense_evidence'}),financialProvider=await ready(financial);
 const donation=(await db.query("select public.dopmi_oneoff_case_server('prepare',$1::jsonb) value",[JSON.stringify({actor:f.other,key:paymentKey,case_id:f.parent,gross_cents:10000,consent:true,consent_version:'oneoff-test-2026-10-15'})])).rows[0].value;
 await db.query("select public.dopmi_oneoff_case_server('bind',$1::jsonb)",[JSON.stringify({actor:f.other,key:paymentKey,payment_intent_id:'pi_'+suffix})]);
 await db.query("select public.dopmi_payment_server('settle',$1::jsonb)",[JSON.stringify({donation_id:donation.id,currency:'mxn',gross_cents:10000,stripe_fee_cents:600,charge_id:'ch_'+suffix,payment_intent_id:'pi_'+suffix})]);
 await db.query("update public.dopmi_donations set transfer_status='transferred',stripe_transfer_id=$2 where id=$1",[donation.id,'tr_'+suffix]);
 await db.query("update private.dopmi_payment_jobs set status='done' where donation_id=$1 and kind='transfer'",[donation.id]);
 assert.ok((await db.query('select count(*)::int n from private.dopmi_case_allocations where expense_id=$1',[expense])).rows[0].n>0);
 const financialTables=['public.dopmi_donations','private.dopmi_case_allocations','private.dopmi_guardian_allocations','private.dopmi_guardian_settlements'];
 async function financialEvidence(){const result={};for(const table of financialTables)result[table]=(await db.query('select to_jsonb(t) value from '+table+' t order by to_jsonb(t)::text')).rows;return result;}
 const before=await financialEvidence();
 await actor('','service_role');
 const deletion=async operation=>(await db.query('select public.dopmi_account_deletion_server($1,$2::jsonb) value',[operation,JSON.stringify({owner_id:f.owner,request_key:deleteKey})])).rows[0].value;
 assert.equal((await deletion('request')).status,'procesando');assert.equal((await deletion('request')).status,'procesando');
 assert.equal((await db.query('select count(*)::int n from private.dopmi_video_assets where id=$1',[presented.id])).rows[0].n,0);
 assert.equal((await deletion('finalize')).status,'completado');assert.equal((await deletion('finalize')).status,'completado');assert.equal((await deletion('request')).status,'completado');
 assert.deepEqual(await financialEvidence(),before);
 const retained=(await db.query('select technical_state,provider_id,purpose from private.dopmi_video_assets where id=$1',[financial.id])).rows[0];
 assert.deepEqual(retained,{technical_state:'ready',provider_id:financialProvider.provider_id,purpose:'expense_evidence'});
 const parent=(await db.query('select status,public_data,private_data,files from public.dopmi_rescue_records where id=$1',[expense])).rows[0];
 assert.equal(parent.status,'approved');assert.deepEqual(parent.public_data,details.public_data);assert.deepEqual(parent.private_data,details.private_data);assert.deepEqual(parent.files,details.files);
 assert.equal((await db.query('select account_status from public.profiles where id=$1',[f.owner])).rows[0].account_status,'deleted');
 const queue=await service({action:'cleanup_list'});assert.ok(queue.items.includes(presentedProvider.provider_id));assert.ok(queue.items.includes(presentationProvider.provider_id));assert.ok(!queue.items.includes(financialProvider.provider_id));
 await actor('','anon');await assert.rejects(db.query('select public.dopmi_video_action($1::jsonb)',[JSON.stringify({action:'playback',id:financial.id})]));
});

test('a late failure rolls back the entire combined migration, including video/store/profile changes',async()=>{
 const isolated=new PGlite();
 try{
  await isolated.exec(`create role anon;create role authenticated;create role service_role;
    create schema auth;create schema storage;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create function auth.jwt() returns jsonb language sql stable as $$ select jsonb_build_object('role',current_setting('request.jwt.claim.role',true)) $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;grant select,insert,update,delete on storage.objects to authenticated;`);
  const migration='20261019041400_integral_video_store_foundation.sql',path=new URL('../../supabase/migrations/',import.meta.url);
  for(const file of (await readdir(path)).filter(name=>name.endsWith('.sql')&&name<migration).sort())await isolated.exec(await readFile(new URL(file,path),'utf8'));
  async function catalog(){return (await isolated.query(`select n.nspname,p.proname,pg_get_functiondef(p.oid) definition from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') order by n.nspname,p.proname,p.oid`)).rows;}
  const baseline=await catalog(),source=await readFile(new URL(migration,path),'utf8');
  assert.equal((source.match(/^\s*begin;\s*$/gmi)??[]).length,1);assert.equal((source.match(/^\s*commit;\s*$/gmi)??[]).length,1);
  const failed=source.replace(/commit;\s*$/i,"select 1/0 as deliberately_injected_late_failure;\ncommit;");assert.notEqual(failed,source);
  await assert.rejects(isolated.exec(failed),error=>error.code==='22012');await isolated.exec('rollback;');
  assert.deepEqual(await catalog(),baseline,'late error must preserve all prior function bodies, including public profile and financial lifecycle');
  const objects=(await isolated.query(`select to_regclass('private.dopmi_video_assets') video,to_regclass('private.dopmi_video_deletion_queue') cleanup,to_regclass('private.dopmi_store_products') store,exists(select 1 from information_schema.columns where table_schema='public' and table_name='dopmi_rescue_records' and column_name='video_thanks_required') added_column`)).rows[0];
  assert.deepEqual(objects,{video:null,cleanup:null,store:null,added_column:false});
 }finally{await isolated.close();}
},{timeout:120000});

function urgentFields(type='medicine',urgent=true){return {pet_name:'Luna',species:'dog',sex:'female',age:'Dos años',story:'Historia de prueba',city:'Ciudad de prueba',state:'Estado de prueba',need:'Atención de prueba',need_items:[{id:randomUUID(),type,title:'Necesidad de prueba',amount_cents:1000,detail:'Detalle de prueba',urgent}]};}
async function saveCase(f,fields,files,version){await actor(f.owner);return (await db.query("select public.dopmi_save_rescue('case',$1::jsonb,'{}'::jsonb,$2::jsonb,$3,$4,null) v",[JSON.stringify(fields),JSON.stringify(files),f.parent,version])).rows[0].v;}
async function uploadSyntheticPhoto(f,owner=f.owner){const path=owner+'/'+f.parent+'/'+randomUUID()+'.jpg';await db.query("insert into storage.objects(bucket_id,name,owner_id) values('dopmi-rescue-evidence',$1,$2)",[path,owner]);return path;}

test('urgency complement is one owned public photo OR one active video and approved snapshot keeps the photo',async()=>{
 const f=await fixture(),fields=urgentFields(),photo=await uploadSyntheticPhoto(f),files=[{path:photo,role:'public'}];
 await db.query('update public.dopmi_rescue_records set video_thanks_required=false where id=$1',[f.parent]);
 const withPhoto=await saveCase(f,{...fields,urgency_photo_path:photo},files,1);assert.equal(withPhoto.public_data.urgency_photo_path,photo);
 await assert.rejects(action(f,begin(f,{parent_version:2,purpose:'urgency'})));
 await saveCase(f,fields,files,2);const payload=begin(f,{parent_version:3,purpose:'urgency'}),video=await action(f,payload);
 assert.equal((await action(f,payload)).id,video.id);await assert.rejects(action(f,begin(f,{parent_version:3,purpose:'urgency'})));
 await assert.rejects(saveCase(f,{...fields,urgency_photo_path:photo},files,3));
 await action(f,{action:'cancel',id:video.id});await saveCase(f,{...fields,urgency_photo_path:photo},files,3);
 await actor(f.owner);await db.query("select public.dopmi_transition_rescue($1,4,'submit')",[f.parent]);
 await actor(f.staff);const approved=(await db.query("select public.dopmi_review_rescue($1,5,'approved','Revision sintetica completa',0,false,'',true) v",[f.parent])).rows[0].v;
 assert.equal(approved.approved_snapshot.urgency_photo_path,photo);assert.ok(approved.approved_snapshot.photos.includes(photo));
 const history=(await db.query("select snapshot from private.dopmi_rescue_history where record_id=$1 and action='approved' order by created_at desc limit 1",[f.parent])).rows[0].snapshot;
 assert.equal(history.approved_snapshot.urgency_photo_path,photo);
});
test('urgency media requires a medical/veterinary urgent CASE and rejects foreign, missing or extra-key photo attachments',async()=>{
 const f=await fixture(),photo=await uploadSyntheticPhoto(f),foreign=await uploadSyntheticPhoto(f,f.other),fields=urgentFields();
 await assert.rejects(saveCase(f,{...fields,urgency_photo_path:photo},[],1));
 await assert.rejects(saveCase(f,{...fields,urgency_photo_path:foreign},[{path:foreign,role:'public'}],1));
 await assert.rejects(saveCase(f,{...fields,urgency_photo_path:photo},[{path:photo,role:'receipt'}],1));
 await assert.rejects(saveCase(f,{...fields,urgency_photo_path:photo},[{path:photo,role:'public',urgency:true}],1));
 const missing=f.owner+'/'+f.parent+'/'+randomUUID()+'.jpg';await assert.rejects(saveCase(f,{...fields,urgency_photo_path:missing},[{path:missing,role:'public'}],1));
 for(const [type,urgent] of [['food',true],['medicine',false]]){
  const invalid=urgentFields(type,urgent);await assert.rejects(saveCase(f,{...invalid,urgency_photo_path:photo},[{path:photo,role:'public'}],1));
 }
 await saveCase(f,urgentFields('food',true),[{path:photo,role:'public'}],1);await assert.rejects(action(f,begin(f,{parent_version:2,purpose:'urgency'})));
 const expense=randomUUID();await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,public_data,private_data) values($1,$2,'expense',$3,'{\"category\":\"medicine\"}','{\"urgency_reason\":\"Urgencia declarada\"}')",[expense,f.owner,f.parent]);
 await assert.rejects(action(f,{...begin(f),parent_id:expense,purpose:'urgency'}));
 await actor(f.owner);assert.equal((await db.query('select public.dopmi_video_policy($1) v',[f.parent])).rows[0].v.urgency_allowed,true);
});
test('policy marks old processed video irrelevant after a saved content change',async()=>{
 const f=await fixture(),fields=urgentFields();await saveCase(f,fields,[],1);const media=await action(f,begin(f,{parent_version:2}));await ready(media);
 await actor(f.owner);assert.equal((await db.query('select public.dopmi_video_policy($1) v',[f.parent])).rows[0].v.assets[0].matches_current_content,true);
 await saveCase(f,{...fields,story:'Historia corregida por su titular'},[],2);await actor(f.owner);
 const stale=(await db.query('select public.dopmi_video_policy($1) v',[f.parent])).rows[0].v.assets[0];assert.equal(stale.technical_state,'ready');assert.equal(stale.matches_current_content,false);assert.equal(stale.moderation_state,'stale');
});

test('pending Stripe keeps ready thanks private from reviewers and only current content follows automatic submission',async()=>{
 const f=await fixture(),photo=await uploadSyntheticPhoto(f);
 await db.query('update private.dopmi_connect_accounts set transfers_enabled=false,payouts_enabled=false,details_submitted=true where owner_id=$1',[f.owner]);
 const saved=await saveCase(f,urgentFields(),[{path:photo,role:'public'}],1);
 await actor(f.owner);
 await assert.rejects(db.query("select public.dopmi_transition_rescue($1,$2,'submit')",[f.parent,saved.version]),/Agradecimiento requerido/);
 const thanks=await action(f,begin(f,{parent_version:saved.version}));await ready(thanks);
 await actor(f.owner);
 const pending=(await db.query("select public.dopmi_transition_rescue($1,$2,'submit') v",[f.parent,saved.version])).rows[0].v;
 assert.equal(pending.status,'pending_stripe');assert.equal(pending.video_thanks_required,true);
 for(const op of ['status','playback','review']) await assert.rejects(action(f,{action:op,id:thanks.id,parent_version:pending.version,decision:'approved'},f.staff));
 assert.ok(!(await action(f,{action:'list'},f.staff)).items.some(x=>x.id===thanks.id));
 assert.equal((await action(f,{action:'status',id:thanks.id})).technical_state,'ready');
 assert.equal((await action(f,{action:'playback',id:thanks.id})).technical_state,'ready');
 assert.equal((await action(f,{action:'public_list',parent_id:f.parent},f.other)).items.length,0);
 await assert.rejects(action(f,begin(f,{parent_version:pending.version,request_key:randomUUID()})),/Parent not editable/);
 const before=(await db.query('select content_snapshot,parent_version,moderation_state,approved_parent_snapshot from private.dopmi_video_assets where id=$1',[thanks.id])).rows[0];
 await actor('','service_role');
 const data={actor:f.owner,account_id:`acct_synthetic_${f.owner.replaceAll('-','')}`,transfers_enabled:true,payouts_enabled:true,details_submitted:false};
 await db.query("select public.dopmi_payment_server('connect_save',$1::jsonb)",[JSON.stringify(data)]);
 const submitted=(await db.query('select * from public.dopmi_rescue_records where id=$1',[f.parent])).rows[0];
 assert.equal(submitted.status,'submitted');assert.equal(submitted.version,pending.version+1);assert.equal(submitted.approved_snapshot,null);
 assert.deepEqual((await db.query('select content_snapshot,parent_version,moderation_state,approved_parent_snapshot from private.dopmi_video_assets where id=$1',[thanks.id])).rows[0],before);
 await assert.rejects(action(f,{action:'review',id:thanks.id,parent_version:pending.version,decision:'approved'},f.staff),/Stale parent/);
 await action(f,{action:'review',id:thanks.id,parent_version:submitted.version,decision:'approved'},f.staff);
 await assert.rejects(action(f,{action:'playback',id:thanks.id},f.other));
 await actor(f.staff);
 const approved=(await db.query("select public.dopmi_review_rescue($1,$2,'approved','Revision sintetica completa',0,false,'',true) v",[f.parent,submitted.version])).rows[0].v;
 assert.equal(approved.status,'approved');assert.equal((await action(f,{action:'playback',id:thanks.id},f.other)).technical_state,'ready');
});

test('pending Stripe cancellation cannot publish a missing thanks or erase the saved Stripe readiness',async()=>{
 const f=await fixture(),photo=await uploadSyntheticPhoto(f);
 await db.query('update private.dopmi_connect_accounts set transfers_enabled=false,payouts_enabled=false where owner_id=$1',[f.owner]);
 const saved=await saveCase(f,urgentFields(),[{path:photo,role:'public'}],1),thanks=await action(f,begin(f,{parent_version:2}));await ready(thanks);await actor(f.owner);
 const pending=(await db.query("select public.dopmi_transition_rescue($1,$2,'submit') v",[f.parent,saved.version])).rows[0].v;
 await action(f,{action:'cancel',id:thanks.id});await actor('','service_role');
 await db.query("select public.dopmi_payment_server('connect_save',$1::jsonb)",[JSON.stringify({actor:f.owner,account_id:`acct_synthetic_${f.owner.replaceAll('-','')}`,transfers_enabled:true,payouts_enabled:true,details_submitted:true})]);
 const actual=(await db.query('select status,version,approved_snapshot from public.dopmi_rescue_records where id=$1',[f.parent])).rows[0];
 assert.deepEqual(actual,{status:'pending_stripe',version:pending.version,approved_snapshot:null});
 assert.equal((await db.query('select transfers_enabled and payouts_enabled ready from private.dopmi_connect_accounts where owner_id=$1',[f.owner])).rows[0].ready,true);
 await actor(f.owner);
 const draft=(await db.query("select public.dopmi_transition_rescue($1,$2,'withdraw') v",[f.parent,pending.version])).rows[0].v;
 assert.equal(draft.status,'draft');
});

test('pending Stripe cancellation during the UPDATE guard isolates one case, saves readiness and retries without duplicate audit',async()=>{
 const first=await fixture(),second={...first,parent:randomUUID()};
 await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,status) values($1,$2,'case','draft')",[second.parent,first.owner]);
 await db.query('update private.dopmi_connect_accounts set transfers_enabled=false,payouts_enabled=false where owner_id=$1',[first.owner]);
 const [invalid,valid]=[first,second].sort((a,b)=>a.parent.localeCompare(b.parent));
 for(const f of [invalid,valid]) {
  const photo=await uploadSyntheticPhoto(f),saved=await saveCase(f,urgentFields(),[{path:photo,role:'public'}],1);
  const thanks=await action(f,begin(f,{parent_version:saved.version}));await ready(thanks);await actor(f.owner);
  f.pending=(await db.query("select public.dopmi_transition_rescue($1,$2,'submit') v",[f.parent,saved.version])).rows[0].v;
 }
 const money=async()=>({donations:(await db.query('select to_jsonb(d) v from public.dopmi_donations d order by id')).rows,
  snapshots:(await db.query('select to_jsonb(s) v from private.dopmi_payment_method_snapshots s order by kind,payment_id')).rows,
  customers:(await db.query('select to_jsonb(c) v from private.dopmi_saved_card_customers c order by owner_id')).rows});
 const beforeMoney=await money();
 // Local-only injection occurs after rescue validation, immediately before the
 // actual video guard. It models readiness becoming invalid at the UPDATE, which
 // the former precheck could not protect. The trigger is always removed below.
 await db.exec(`create function private.dopmi_test_pending_cancel_during_update() returns trigger language plpgsql as $$begin
  if new.id='${invalid.parent}'::uuid and old.status='pending_stripe' and new.status='submitted' then
   update private.dopmi_video_assets set technical_state='canceled' where parent_id=new.id and purpose='thanks';
  end if;return new;end;$$;
  create trigger aaa_test_pending_cancel_during_update before update on public.dopmi_rescue_records for each row execute function private.dopmi_test_pending_cancel_during_update();`);
 try {
  await actor('','service_role');
  const data={actor:first.owner,account_id:`acct_synthetic_${first.owner.replaceAll('-','')}`,transfers_enabled:true,payouts_enabled:true,details_submitted:true};
  const rpc=async(op,payload)=>(await db.query('select public.dopmi_payment_server($1,$2::jsonb) v',[op,JSON.stringify(payload)])).rows[0].v;
  const result=await rpc('connect_save',data);
  assert.equal(result.transfers_enabled,true);assert.equal(result.payouts_enabled,true);
  assert.deepEqual(result.pending_stripe_sync,{source:'stripe_connect_ready',promoted_count:1,deferred_count:1,deferred:[{record_id:invalid.parent,phase:'transition',sqlstate:'23514',reason:'thanks_not_ready'}]});
  const read=async(id)=>(await db.query('select to_jsonb(r) v from public.dopmi_rescue_records r where id=$1',[id])).rows[0].v;
  assert.deepEqual(await read(invalid.parent),invalid.pending,'failed case UPDATE, version and timestamps all roll back');
  const good=await read(valid.parent);assert.equal(good.status,'submitted');assert.equal(good.version,valid.pending.version+1);assert.equal(good.approved_snapshot,null);
  const audits=async(id)=>(await db.query("select count(*)::int n from private.dopmi_rescue_history where record_id=$1 and action='stripe_ready'",[id])).rows[0].n;
  assert.equal(await audits(invalid.parent),0);assert.equal(await audits(valid.parent),1);
  const repeat=await rpc('connect_save',data);assert.equal(repeat.pending_stripe_sync.promoted_count,0);assert.equal(repeat.pending_stripe_sync.deferred_count,1);
  const stripe=async(path,fields)=>{
   assert.equal(fields,undefined);if(path==='events/evt_pending_guard_replay')return {livemode:false,type:'account.updated',data:{object:{id:data.account_id}}};
   assert.equal(path,`accounts/${data.account_id}`);return {id:data.account_id,payouts_enabled:true,capabilities:{transfers:'active'},details_submitted:true};
  };
  await paymentService({rpc,stripe,returnUrl:'https://example.test/return'}).processEvent({event_id:'evt_pending_guard_replay'});
  assert.deepEqual(await read(invalid.parent),invalid.pending);assert.deepEqual(await read(valid.parent),good);
  assert.equal(await audits(invalid.parent),0);assert.equal(await audits(valid.parent),1);assert.deepEqual(await money(),beforeMoney);
  await actor(first.owner);
  assert.equal((await db.query("select public.dopmi_transition_rescue($1,$2,'withdraw') v",[invalid.parent,invalid.pending.version])).rows[0].v.status,'draft');
 } finally {
  await db.exec('drop trigger aaa_test_pending_cancel_during_update on public.dopmi_rescue_records;drop function private.dopmi_test_pending_cancel_during_update();');
 }
});

test('farewell after the real case close preserves its closed snapshot and existing contributions',async()=>{
 const f=await fixture(),photo=await uploadSyntheticPhoto(f);
 const saved=await saveCase(f,urgentFields(),[{path:photo,role:'public'}],1);
 const thanks=await action(f,begin(f,{parent_version:saved.version}));
 await ready(thanks); // Provider processing is simulated; all lifecycle RPCs below are real SQL.
 await actor(f.owner);
 const submitted=(await db.query("select public.dopmi_transition_rescue($1,$2,'submit') v",[f.parent,saved.version])).rows[0].v;
 await action(f,{action:'review',id:thanks.id,parent_version:submitted.version,decision:'approved'},f.staff);
 await actor(f.staff);
 const approved=(await db.query("select public.dopmi_review_rescue($1,$2,'approved','Revision sintetica completa',0,false,'',true) v",[f.parent,submitted.version])).rows[0].v;
 assert.equal(approved.status,'approved');

 // A nonzero, entirely local financial fixture makes conservation observable.
 // No payment provider is called, and the child expense is already approved.
 const expense=randomUUID(),key=randomUUID(),suffix=randomUUID().replaceAll('-','');
 await db.query("insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,status,approved_snapshot,reimbursable_cents) values($1,$2,'expense',$3,'approved','{\"title\":\"Synthetic paid expense\"}',12000)",[expense,f.owner,f.parent]);
 await db.query('update private.dopmi_connect_accounts set account_id=$2 where owner_id=$1',[f.owner,'acct_'+suffix]);
 await actor('','service_role');
 const donation=(await db.query("select public.dopmi_oneoff_case_server('prepare',$1::jsonb) v",[JSON.stringify({actor:f.other,key,case_id:f.parent,gross_cents:10000,consent:true,consent_version:'oneoff-test-2026-10-15'})])).rows[0].v;
 await db.query("select public.dopmi_oneoff_case_server('bind',$1::jsonb)",[JSON.stringify({actor:f.other,key,payment_intent_id:'pi_'+suffix})]);
 await db.query("select public.dopmi_payment_server('settle',$1::jsonb)",[JSON.stringify({donation_id:donation.id,currency:'mxn',gross_cents:10000,stripe_fee_cents:600,charge_id:'ch_'+suffix,payment_intent_id:'pi_'+suffix})]);
 assert.ok((await db.query('select count(*)::int n from private.dopmi_case_allocations where expense_id=$1',[expense])).rows[0].n>0);
 const financialTables=['public.dopmi_donations','private.dopmi_case_allocations','private.dopmi_guardian_allocations','private.dopmi_guardian_settlements','private.dopmi_payment_jobs'];
 async function financialEvidence(){
  const rows={};
  for(const table of financialTables)rows[table]=(await db.query('select to_jsonb(t) value from '+table+' t order by to_jsonb(t)::text')).rows;
  return rows;
 }
 const finances=await financialEvidence();
 await actor(f.owner);
 const closed=(await db.query('select public.dopmi_close_support_case($1,$2) v',[f.parent,approved.version])).rows[0].v;
 assert.equal(closed.status,'closed');assert.equal(closed.version,approved.version+1);
 assert.deepEqual(closed.approved_snapshot,approved.approved_snapshot);
 const parentBeforeMedia=(await db.query('select to_jsonb(r) v from public.dopmi_rescue_records r where id=$1',[f.parent])).rows[0].v;

 await assert.rejects(action(f,begin(f,{purpose:'farewell',parent_version:closed.version}),f.other),e=>e.code==='42501');
 await assert.rejects(action(f,begin(f,{purpose:'farewell',parent_version:approved.version})),e=>e.code==='40001');
 for(const purpose of ['thanks','urgency','public_update']){
  await assert.rejects(action(f,begin(f,{purpose,parent_version:closed.version})),e=>e.code==='22023');
 }
 const farewell=await action(f,begin(f,{purpose:'farewell',parent_version:closed.version,file_fingerprint:'f'.repeat(64)}));
 await ready(farewell);
 await assert.rejects(action(f,{action:'status',id:farewell.id},f.other),e=>e.code==='42501');
 await assert.rejects(action(f,{action:'playback',id:farewell.id},f.other),e=>e.code==='42501');
 assert.ok(!(await action(f,{action:'public_list',parent_id:f.parent},f.other)).items.some(a=>a.id===farewell.id));
 await assert.rejects(action(f,{action:'review',id:farewell.id,parent_version:closed.version,decision:'approved'},f.other),e=>e.code==='42501');
 await assert.rejects(action(f,{action:'review',id:farewell.id,parent_version:approved.version,decision:'approved'},f.staff),e=>e.code==='40001');
 await action(f,{action:'review',id:farewell.id,parent_version:closed.version,decision:'approved'},f.staff);
 await actor('','anon');await db.exec('set role anon');
 try{
  const list=(await db.query('select public.dopmi_video_action($1::jsonb) v',[JSON.stringify({action:'public_list',parent_id:f.parent})])).rows[0].v;
  assert.ok(list.items.some(a=>a.id===farewell.id&&a.purpose==='farewell'));
  const playback=(await db.query('select public.dopmi_video_action($1::jsonb) v',[JSON.stringify({action:'playback',id:farewell.id})])).rows[0].v;
  assert.equal(playback.technical_state,'ready');assert.equal(playback.upload_url,null);
 }finally{await db.exec('reset role');}

 // A different published snapshot cannot reuse the approval. This injected
 // mismatch is rolled back, not an owner operation or reopening of the case.
 await db.exec('begin');
 try{
  await db.query("update public.dopmi_rescue_records set approved_snapshot=approved_snapshot||'{\"synthetic_revision\":true}'::jsonb where id=$1",[f.parent]);
  const list=await action(f,{action:'public_list',parent_id:f.parent},f.other);
  assert.ok(!list.items.some(a=>a.id===farewell.id));
  await assert.rejects(action(f,{action:'playback',id:farewell.id},f.other),e=>e.code==='42501');
 }finally{await db.exec('rollback');}
 assert.deepEqual((await db.query('select to_jsonb(r) v from public.dopmi_rescue_records r where id=$1',[f.parent])).rows[0].v,parentBeforeMedia);
 assert.deepEqual(await financialEvidence(),finances);
});
