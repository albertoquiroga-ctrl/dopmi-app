import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

// Disposable PostgreSQL/WASM only. No Auth service, provider or remote connection.
const migration = '20261102192629_fixed_case_need_units.sql';
const sessions = new Map();
let baselineAcl, fundedGuard;
const owner = randomUUID(), reviewer = randomUUID(), other = randomUUID();
let db, priorOids;
const value = async (sql, args = []) => (await db.query(sql, args)).rows[0]?.value;
async function actor(id = reviewer, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,true)", [id ?? '']);
  await db.query("select set_config('request.jwt.claim.session_id',$1,true)", [sessions.get(id) ?? '']);
  await db.exec(`set local role ${role}`);
}
async function rejected(action, code) {
  await db.exec('savepoint rejection');
  await assert.rejects(action, { code });
  await db.exec('rollback to savepoint rejection');
}
const transition = (id, version = 1, action = 'submit') => value(
  'select public.dopmi_transition_rescue($1,$2,$3) value', [id, version, action]);
const packet = (id, page = 1) => value('select public.dopmi_admin_rescue_packet($1,$2) value', [id, page]);
const decide = (f, reviews = f.reviews, request = randomUUID(), decision = 'approved', version = f.version) => value(
  'select public.dopmi_review_initial_case_packet($1,$2,$3,$4,$5,true,$6::jsonb,$7) value',
  [f.id, version, f.submission, decision, 'Revisión sintética completa', JSON.stringify(reviews), request]);
async function draft(kind = 'case', parent = null, who = owner) {
  const id = randomUUID();
  const publicData = kind === 'case'
    ? { pet_name: 'Caso sintético', species: 'dog', sex: 'female', age: '2 años', story: 'Rescate sintético para pruebas locales', city: 'Monterrey', state: 'Nuevo León', need_items: [] }
    : { title: 'Medicamento pagado', description: 'Gasto sintético ya pagado', category: 'medicine' };
  const privateData = kind === 'case' ? {} : { paid_on: '2026-09-01', vendor: 'Proveedor sintético', amount_cents: '10000', receipt_reference: id };
  const files = (kind === 'case' ? ['public'] : ['receipt', 'proof']).map(role => ({ role, path: `${who}/${id}/${randomUUID()}.${role === 'receipt' ? 'pdf' : 'jpg'}` }));
  await db.exec('reset role');
  await db.query(`insert into public.dopmi_rescue_records(id,owner_id,kind,parent_id,public_data,private_data,files,video_thanks_required)
    values($1,$2,$3,$4,$5::jsonb,$6::jsonb,$7::jsonb,false)`, [id, who, kind, parent, JSON.stringify(publicData), JSON.stringify(privateData), JSON.stringify(files)]);
  for (const file of files) await db.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)", [file.path]);
  return { id, files, publicData, privateData };
}
async function ready() {
  await db.exec('reset role');
  await db.query(`insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled)
    values($1,'acct_initial_packet_synthetic',true,true) on conflict(owner_id) do update set transfers_enabled=true,payouts_enabled=true`, [owner]);
}
async function fixture(count = 2, stripeReady = true) {
  const f = await draft(); f.children = [];
  for (let i = 0; i < count; i++) f.children.push(await draft('expense', f.id));
  if (stripeReady) await ready();
  await actor(owner); const submitted = await transition(f.id); f.version = submitted.version;
  await db.exec('reset role');
  f.submission = await value('select id value from private.dopmi_case_need_submissions where case_id=$1', [f.id]);
  f.reviews = f.children.map(c => ({ expense_id: c.id, expense_version: 1, amount_cents: 10000, is_urgent: false, urgency_note: '', publish_content: true }));
  await actor(); return f;
}
async function inventory(f) {
  await db.exec('reset role');
  return (await db.query(`select to_jsonb(r) value from public.dopmi_rescue_records r
    where id=$1 or parent_id=$1 order by id`, [f.id])).rows;
}
async function oids() {
  return (await db.query(`select p.proname,p.oid::text value from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=any($1::text[]) order by p.proname`, [[
    'dopmi_transition_rescue', 'dopmi_review_rescue', 'dopmi_admin_rescue_packet', 'dopmi_rescue_file_access',
  ]])).rows;
}
before(async () => {
  db = new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.identities(user_id uuid,provider text,provider_id text);
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',email_confirmed_at timestamptz,last_sign_in_at timestamptz,phone text,phone_confirmed_at timestamptz);
    create table auth.sessions(id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,not_after timestamptz);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('role',current_setting('role',true))$$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text,metadata jsonb);
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;`);
  const directory = new URL('../../supabase/migrations/', import.meta.url);
  for (const file of (await readdir(directory)).filter(f => f.endsWith('.sql')).sort()) {
    if (file === migration) { priorOids = await oids(); baselineAcl = await acl(); fundedGuard = await value("select pg_get_functiondef('private.dopmi_guard_funded_expense()'::regprocedure) value"); }
    try { await db.exec(await readFile(new URL(file, directory), 'utf8')); }
    catch (error) { throw new Error(`Migration ${file}: ${error.code}: ${error.message}`); }
  }
  for (const id of [owner, reviewer, other]) await db.query(`insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
    values($1,$2,now(),'{"display_name":"Nombre privado","is_admin":true,"terms_version":"terms-2026-10-17","privacy_version":"privacy-2026-10-17","adult_confirmed":true}')`, [id, `${id}@example.test`]);
  for (const id of [owner, reviewer, other]) { const session = randomUUID(); sessions.set(id, session); await db.query('insert into auth.sessions(id,user_id) values($1,$2)', [session,id]); }
  await db.query('insert into private.admin_memberships(user_id) values($1)', [reviewer]);
}, { timeout: 120000 });
after(async () => db?.close());
beforeEach(async () => db.exec('begin'));
afterEach(async () => db.exec('rollback'));

async function acl() {
  return (await db.query(`select oid::text,proname,proacl::text from pg_proc where oid=any(array[
    'public.dopmi_save_rescue(text,jsonb,jsonb,jsonb,uuid,integer,uuid)'::regprocedure,
    'public.dopmi_transition_rescue(uuid,integer,text)'::regprocedure,'public.dopmi_review_rescue(uuid,integer,text,text,bigint,boolean,text,boolean)'::regprocedure,
    'public.dopmi_rescue_file_access(text,boolean)'::regprocedure,'public.dopmi_rescue_detail(uuid)'::regprocedure,
    'public.dopmi_admin_rescue(text,text,integer)'::regprocedure,'public.dopmi_remove_draft_expense(uuid,integer)'::regprocedure]) order by proname`)).rows;
}
const getRevision = id => value('select public.dopmi_case_revision($1) value', [id]);
const start = (f, request = randomUUID()) => value('select public.dopmi_start_case_revision($1,$2,$3) value', [f.id, f.approvedVersion, request]);
const fields = r => ({ public_data: r.public_data, private_data: r.private_data, files: r.files });
async function published(count = 2) {
  const f = await fixture(count); const approved = await decide(f); f.approvedVersion = approved.record.version;
  await actor(owner); return f;
}
const save = (p, change = {}, expenses = p.expenses.items.map(e => ({ id: e.id, ...fields(e) })), request = randomUUID(), reason = 'Corrijo la historia del rescate') => value(
  'select public.dopmi_save_case_revision($1,$2,$3,$4::jsonb,$5::jsonb,$6) value',
  [p.revision.id,p.revision.version,reason,JSON.stringify({ ...fields(p.record), ...change }),JSON.stringify(expenses),request]);
const reviseTransition = (p, action = 'submit', request = randomUUID()) => value(
  'select public.dopmi_transition_case_revision($1,$2,$3,$4) value',[p.revision.id,p.revision.version,action,request]);
const reviewChoices = p => p.expenses.items.map(e => ({ expense_id: e.id, expense_version: e.version,
  amount_cents: e.review_amount_cents,is_urgent: e.urgent,urgency_note: e.priority_reason,publish_content: true }));
const review = (p, choices = reviewChoices(p), decision = 'approved', request = randomUUID()) => value(
  'select public.dopmi_review_case_revision($1,$2,$3,$4,true,$5::jsonb,$6) value',
  [p.revision.id,p.revision.version,decision,'Revisión conjunta del caso completo',JSON.stringify(choices),request]);
const fileIntent = (p, record = p.record.id, role = 'public', extension = 'jpg', request = randomUUID()) => value(
  'select public.dopmi_case_revision_file($1,$2,$3,$4,$5,$6) value',[p.revision.id,p.revision.version,record,role,extension,request]);
async function linked(expense, allocated = 0) {
  await db.exec('reset role');
  await db.query(`insert into public.dopmi_donations(donor_id,rescuer_id,expense_id,expense_title,destination,idempotency_key,
    gross_cents,platform_fee_cents,reserved_cents,allocated_cents) values($1,$2,$3,'Sintético','Prueba local',$4,1000,0,$5,$6)`,
  [other,owner,expense,randomUUID(), allocated ? 0 : 100,allocated]);
  await actor(owner);
}

test('all existing OIDs/ACLs and funded guards survive; new private state and delegates have no role grants', async () => {
  assert.deepEqual(await acl(),baselineAcl);
  assert.equal(await value("select pg_get_functiondef('private.dopmi_guard_funded_expense()'::regprocedure) value"),fundedGuard);
  for (const table of ['dopmi_case_revisions','dopmi_case_revision_files','dopmi_case_revision_requests']) {
    assert.equal(await value('select relrowsecurity value from pg_class where oid=$1::regclass',[`private.${table}`]),true);
    for (const role of ['anon','authenticated','service_role']) assert.equal(await value("select has_table_privilege($1,$2,'select,insert,update,delete') value",[role,`private.${table}`]),false);
  }
  const funcs = (await db.query(`select p.oid::regprocedure::text name,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname like '%case_revision%' or p.proname like '%before_fixed_case'`)).rows;
  for (const f of funcs) {
    for (const role of ['anon','service_role']) assert.equal(await value("select has_function_privilege($1,$2,'execute') value",[role,f.name]),false,f.name);
    if (f.nspname==='private' || f.name.includes('before_fixed_case')) assert.equal(await value("select has_function_privilege('authenticated',$1,'execute') value",[f.name]),false,f.name);
  }
});

test('fixed set stays sealed after moderator withdrawal; old expense submit/review routes fail', async () => {
  const f=await published(1); const child=f.children[0];
  await rejected(()=>value('select public.dopmi_save_rescue($1,$2::jsonb,$3::jsonb,$4::jsonb,null,null,$5) value',
    ['expense',JSON.stringify(child.publicData),JSON.stringify(child.privateData),'[]',f.id]),'22023');
  await rejected(()=>transition(child.id,3),'22023');
  await actor(); await rejected(()=>value("select public.dopmi_review_rescue($1,3,'approved','No hay revisión individual',10000,false,'',true) value",[child.id]),'22023');
  await value("select public.dopmi_review_rescue($1,$2,'changes_requested','Retirada de contenido por privacidad',0,false,'',false) value",[f.id,f.approvedVersion]);
  await actor(owner);
  await rejected(()=>value('select public.dopmi_save_rescue($1,$2::jsonb,$3::jsonb,$4::jsonb,null,null,$5) value',
    ['expense',JSON.stringify(child.publicData),JSON.stringify(child.privateData),'[]',f.id]),'22023');
  const detail=await value('select public.dopmi_rescue_detail($1) value',[f.id]);
  assert.equal(detail.case_unit.ever_approved,true); assert.equal(detail.case_unit.can_add_needs,false);
});

test('owner DTO gives exact manifest membership, null legacy and explicit empty; pending children cannot change',async()=>{
  const f=await fixture(1,false); await actor(owner);
  let d=await value('select public.dopmi_rescue_detail($1) value',[f.children[0].id]);
  assert.deepEqual(d.case_unit.expense_ids,[f.children[0].id]); assert.equal(d.case_unit.needs_editable,false);
  const legacy=await draft(); await db.query("update public.dopmi_rescue_records set status='submitted' where id=$1",[legacy.id]);
  await actor(owner); d=await value('select public.dopmi_rescue_detail($1) value',[legacy.id]); assert.equal(d.case_unit.expense_ids,null);
  const empty=await fixture(0,false); await actor(owner); d=await value('select public.dopmi_rescue_detail($1) value',[empty.id]); assert.deepEqual(d.case_unit.expense_ids,[]);
});

test('private save/submit/withdraw never change public or financial records; reason and exact set are required',async()=>{
  const f=await published(); const before=await inventory(f); await actor(owner);
  let p=await start(f); await rejected(()=>save(p,{},[],randomUUID()),'22023');
  await rejected(()=>save(p,{},undefined,randomUUID(),'hola'),'22023');
  p=await save(p,{public_data:{...p.record.public_data,story:'Historia privada corregida'}});
  assert.equal(p.record.public_data.story,'Historia privada corregida'); assert.deepEqual(await inventory(f),before); await actor(owner);
  p=await reviseTransition(p); assert.equal(p.revision.status,'submitted'); assert.deepEqual(await inventory(f),before); await actor(owner);
  await rejected(()=>save(p),'40001'); p=await reviseTransition(p,'withdraw'); assert.equal(p.revision.status,'draft'); assert.deepEqual(await inventory(f),before);
});

test('one admin decision replaces the whole proposal and exact replay writes nothing',async()=>{
  const f=await published(2); let p=await start(f);
  p=await save(p,{public_data:{...p.record.public_data,story:'Historia aprobada nueva'}});
  p=await reviseTransition(p); const submitted=p; await actor();
  const queue=await value("select public.dopmi_admin_rescue('case','submitted',1) value");
  const row=queue.items.find(x=>x.id===f.id); assert.equal(row.review_kind,'revision'); assert.equal(row.revision_id,p.revision.id);
  const packet=await value('select public.dopmi_admin_case_revision_packet($1,1) value',[p.revision.id]); assert.equal(packet.revision.reason,p.revision.reason);
  const request=randomUUID(); const result=await review(p,reviewChoices(p),'approved',request); assert.equal(result.revision.status,'approved');
  const after=await inventory(f); assert.equal(after.find(x=>x.value.id===f.id).value.approved_snapshot.story,'Historia aprobada nueva'); await actor();
  assert.deepEqual(await review(submitted,reviewChoices(submitted),'approved',request),result); assert.deepEqual(await inventory(f),after);
  assert.equal(await value("select count(*)::int value from private.dopmi_rescue_history where record_id=$1 and action='case_revision_approved'",[f.id]),1);
});

test('partial review, stale child or an invalid last need rolls back every proposed publication',async()=>{
  const f=await published(2); let p=await start(f); p=await save(p); p=await reviseTransition(p); const before=await inventory(f); await actor();
  await rejected(()=>review(p,reviewChoices(p).slice(0,1)),'40001');
  await rejected(()=>review(p,reviewChoices(p).map((x,i)=>i?{...x,amount_cents:5000}:x)),'22023');
  await db.exec('reset role'); await db.query('update public.dopmi_rescue_records set version=version+1 where id=$1',[f.children[1].id]); await actor();
  await rejected(()=>review(p),'40001');
  await db.exec('reset role'); await db.query('update public.dopmi_rescue_records set version=version-1 where id=$1',[f.children[1].id]);
  assert.deepEqual(await inventory(f),before);
});

test('financial links arriving during a draft are rechecked; text edits retain historical partial authorization',async()=>{
  const f=await published(1); await db.exec('reset role');
  // Reproduce an existing historical partial approval without changing paid evidence.
  await db.query('update public.dopmi_rescue_records set reimbursable_cents=7000 where id=$1',[f.children[0].id]); await actor(owner);
  let p=await start(f); assert.equal(p.expenses.items[0].review_amount_cents,7000);
  p=await save(p,{},p.expenses.items.map(e=>({id:e.id,...fields(e),private_data:{...e.private_data,amount_cents:'010000'}})));
  assert.equal(p.expenses.items[0].review_amount_cents,7000,'numeric paid equality preserves the legacy cap despite formatting');
  const changed=p.expenses.items.map(e=>({id:e.id,...fields(e),private_data:{...e.private_data,amount_cents:'12000'}}));
  p=await save(p,{},changed); await linked(f.children[0].id,0);
  await rejected(()=>reviseTransition(p),'22023');
  p=await save(p,{},p.expenses.items.map(e=>({id:e.id,...fields(e),private_data:{...e.private_data,amount_cents:'10000'}})));
  assert.equal(p.expenses.items[0].financial_locked,true); assert.equal(p.expenses.items[0].review_amount_cents,7000);
  p=await reviseTransition(p); await actor(); await review(p); await db.exec('reset role');
  assert.equal(await value('select reimbursable_cents value from public.dopmi_rescue_records where id=$1',[f.children[0].id]),7000);
});

test('registered file paths stay private until submitted and only exact draft intents can write',async()=>{
  const f=await published(1); let p=await start(f); const intent=await fileIntent(p);
  assert.equal((await getRevision(f.id)).revision.version,p.revision.version);
  await db.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)",[intent.path]);
  assert.equal(await value('select public.dopmi_rescue_file_access($1,true) value',[intent.path]),true);
  assert.equal(await value('select public.dopmi_rescue_file_access($1,true) value',[p.record.files[0].path]),false);
  await rejected(()=>fileIntent(p,randomUUID()),'22023'); await actor();
  assert.equal(await value('select public.dopmi_rescue_file_access($1) value',[intent.path]),false);
  await rejected(()=>value('select public.dopmi_admin_case_revision_packet($1,1) value',[p.revision.id]),'42501'); await actor(owner);
  p=await save(p,{files:[{path:intent.path,role:'public'}]}); p=await reviseTransition(p);
  assert.equal((await db.query('delete from storage.objects where name=$1 returning name',[intent.path])).rows.length,0);
  await actor(); assert.equal(await value('select public.dopmi_rescue_file_access($1) value',[intent.path]),true);
  await review(p,[],'changes_requested');
  assert.equal(await value('select public.dopmi_rescue_file_access($1) value',[intent.path]),false);
});

test('close, moderation withdrawal, expired sessions, role revocation and foreign/self review cannot replay',async()=>{
  const f=await published(1); let p=await start(f); p=await save(p); p=await reviseTransition(p); await actor();
  const request=randomUUID(); const denied=await review(p,[],'changes_requested',request);
  assert.equal(denied.revision.status,'changes_requested');
  await db.exec('reset role'); await db.query('update private.admin_memberships set active=false where user_id=$1',[reviewer]); await actor();
  await rejected(()=>review(p,[],'changes_requested',request),'42501');
  await db.exec('reset role'); await db.query('update private.admin_memberships set active=true where user_id=$1',[reviewer]);
  await db.query('update auth.sessions set not_after=now()-interval \'1 second\' where id=$1',[sessions.get(reviewer)]); await actor();
  await rejected(()=>review(p,[],'changes_requested',request),'42501');
  await actor(other); await rejected(()=>save(denied),'42501');
  await actor(owner); await transition(f.id,f.approvedVersion,'close');
  await rejected(()=>save(denied),'40001'); assert.equal((await getRevision(f.id)).revision.status,'invalidated');
});

async function media(f, state='approved', queue=false) {
  await db.exec('reset role'); const id=randomUUID(), provider=randomUUID().replaceAll('-','');
  await db.query(`insert into private.dopmi_video_assets(id,owner_id,parent_id,parent_version,purpose,request_key,bytes,
    content_snapshot,technical_state,moderation_state,provider_id,file_fingerprint,approved_parent_snapshot)
    select $1,owner_id,id,version,'thanks',$2,1000,private.dopmi_video_content(r),'ready',$3,$4,$5,approved_snapshot
    from public.dopmi_rescue_records r where id=$6`,[id,randomUUID(),state,provider,'a'.repeat(64),f.id]);
  if(queue) await db.query('insert into private.dopmi_video_deletion_queue(provider_id) values($1)',[provider]);
  await actor(owner); return {id,provider};
}
test('approved media survives text edits with an audited unchanged asset; pending/stale/queued media is never promoted',async()=>{
  const f=await published(1); const good=await media(f), pending=await media(f,'pending'), stale=await media(f,'stale'), queued=await media(f,'approved',true);
  let p=await start(f); p=await save(p,{public_data:{...p.record.public_data,story:'Texto nuevo conserva video aprobado'}}); p=await reviseTransition(p);
  await actor(); await review(p); await db.exec('reset role');
  const assets=(await db.query('select id,moderation_state,provider_id,bytes,parent_version from private.dopmi_video_assets where parent_id=$1',[f.id])).rows;
  assert.equal(assets.find(x=>x.id===good.id).moderation_state,'approved');
  assert.equal(assets.find(x=>x.id===good.id).provider_id,good.provider); assert.equal(assets.find(x=>x.id===good.id).bytes,1000);
  for(const a of [pending,stale,queued]) assert.notEqual(assets.find(x=>x.id===a.id).moderation_state,'approved');
  const audit=await value('select snapshot value from private.dopmi_video_reviews where asset_id=$1',[good.id]);
  assert.equal(audit.case_revision_id,p.revision.id); assert.equal(audit.preserved_approved_asset,true); assert.notDeepEqual(audit.old_content,audit.content);
  // The unchanged job2 deletion list still includes the pre-existing queued
  // asset, and cannot delete the approved asset preserved by this transaction.
  await actor(null,'service_role'); const queue=await value("select public.dopmi_video_service('{\"action\":\"cleanup_list\"}'::jsonb) value");
  assert.ok(queue.items.includes(queued.provider)); assert.ok(!queue.items.includes(good.provider));
});

test('media cancellation or evidence metadata changes after submission abort the entire decision',async()=>{
  const f=await published(1); const good=await media(f); let p=await start(f); p=await save(p); p=await reviseTransition(p);
  await db.exec('reset role'); await db.query("update private.dopmi_video_assets set technical_state='canceled' where id=$1",[good.id]);
  await actor(); await rejected(()=>review(p),'40001');
  await db.exec('reset role'); await db.query("update private.dopmi_video_assets set technical_state='ready' where id=$1",[good.id]);
  await db.query("update storage.objects set metadata='{\"size\":123}' where name=$1",[f.children[0].files[0].path]);
  await actor(); await rejected(()=>review(p),'40001');
  await db.exec('reset role'); assert.equal(await value('select version value from public.dopmi_rescue_records where id=$1',[f.id]),f.approvedVersion);
});

test('private precise coordinates move only upon approval and never enter public_data',async()=>{
  const f=await published(1); let p=await start(f);
  p=await save(p,{public_data:{...p.record.public_data,approximate_latitude:25.678901,approximate_longitude:-100.123456,location_precision_version:1}});
  assert.equal(p.record.approximate_latitude,25.678901); assert.equal(p.record.public_data.approximate_latitude,undefined);
  await db.exec('reset role'); assert.equal(await value('select approximate_latitude value from public.dopmi_rescue_records where id=$1',[f.id]),null);
  await actor(owner); p=await reviseTransition(p); await actor(); await review(p); await db.exec('reset role');
  assert.equal(await value('select approximate_latitude value from public.dopmi_rescue_records where id=$1',[f.id]),'25.678901');
  assert.equal(await value("select approved_snapshot ? 'approximate_latitude' value from public.dopmi_rescue_records where id=$1",[f.id]),false);
});

test('revision comments name exact frozen needs and a whole-case return preserves the old public snapshot',async()=>{
  const f=await published(1); let p=await start(f); p=await save(p); p=await reviseTransition(p); const before=await inventory(f); await actor();
  const request=randomUUID(), comments=[{target_kind:'expense',target_id:p.expenses.items[0].id,target_version:p.expenses.items[0].version,body:'Aclara el comprobante de esta necesidad'}];
  const result=await value('select public.dopmi_comment_case_revision_needs($1,$2,$3::jsonb,$4) value',[p.revision.id,p.revision.version,JSON.stringify(comments),request]);
  assert.equal(result.comments[0].target_title,p.expenses.items[0].public_data.title);
  await review(p,[],'changes_requested'); assert.deepEqual(await inventory(f),before); await actor(owner);
  const own=await getRevision(f.id); assert.equal(own.need_comments[0].body,comments[0].body);
});

test('begin freezes approved manifest plus legitimate historical approved children, excluding never-approved late drafts',async()=>{
  const f=await fixture(1); const old=await draft('expense',f.id), privateDraft=await draft('expense',f.id);
  await actor(); await decide(f); f.approvedVersion=3;
  // Privileged disposable reproduction of the legacy pre-seal state. No new
  // authenticated path receives this historical delegate capability.
  await db.exec('reset role'); await db.query("update public.dopmi_rescue_records set status='submitted',version=2 where id=$1",[old.id]);
  await value("select public.dopmi_review_rescue_before_initial_packet($1,2,'approved','Aprobación histórica sintética',7000,false,'',true) value",[old.id]);
  await actor(owner); const p=await start(f);
  assert.deepEqual(p.expense_ids,[f.children[0].id,old.id].sort()); assert.ok(!p.expense_ids.includes(privateDraft.id));
  assert.equal(p.expenses.items.find(e=>e.id===old.id).review_amount_cents,7000);
});

test('legacy submitted expense can be withdrawn privately, but cannot be resubmitted or separately approved',async()=>{
  const f=await fixture(0); const e=await draft('expense',f.id);
  await db.exec('reset role'); await db.query("update public.dopmi_rescue_records set status='submitted',version=2 where id=$1",[e.id]);
  await actor(owner); const withdrawn=await transition(e.id,2,'withdraw'); assert.equal(withdrawn.status,'draft');
  await rejected(()=>transition(e.id,3,'submit'),'22023');
  await actor(); await rejected(()=>value("select public.dopmi_review_rescue($1,3,'approved','No aprobación independiente',10000,false,'',true) value",[e.id]),'22023');
});

test('a previously withdrawn legacy need stays inactive after a complete text edit and cannot restore unsafe content or capacity',async()=>{
  const f=await published(1); await actor(); await db.exec('reset role');
  await value("select public.dopmi_review_rescue_before_initial_packet($1,3,'changes_requested','Retirada histórica por privacidad',0,false,'',false) value",[f.children[0].id]);
  const before=await value('select to_jsonb(r) value from public.dopmi_rescue_records r where id=$1',[f.children[0].id]);
  await actor(owner); let p=await start(f); assert.equal(p.expenses.items[0].financial_inactive,true); assert.equal(p.expenses.items[0].review_amount_cents,0);
  const es=p.expenses.items.map(e=>({id:e.id,...fields(e),private_data:{...e.private_data,amount_cents:'12000'},public_data:{...e.public_data,description:'Aclaración privada de la necesidad'}}));
  p=await save(p,{public_data:{...p.record.public_data,story:'Historia corregida sin reactivar necesidad'}},es); p=await reviseTransition(p); await actor(); await review(p);
  await db.exec('reset role'); const after=await value('select to_jsonb(r) value from public.dopmi_rescue_records r where id=$1',[f.children[0].id]);
  for(const key of ['status','reimbursable_cents','approved_snapshot','approved_at','urgent','priority_reason']) assert.deepEqual(after[key],before[key],key);
  assert.equal(after.private_data.amount_cents,'12000');
  assert.equal(await value('select private.dopmi_rescue_public_visible(r) value from public.dopmi_rescue_records r where id=$1',[f.children[0].id]),false);
});

test('unused registered paths remain private after approval and revoked sessions lose new scoped Storage capabilities',async()=>{
  const f=await published(0); let p=await start(f); const included=await fileIntent(p), unused=await fileIntent(p);
  for(const file of [included,unused]) await db.query("insert into storage.objects(bucket_id,name) values('dopmi-rescue-evidence',$1)",[file.path]);
  await db.exec('reset role'); await db.query('update auth.sessions set not_after=now()-interval \'1 second\' where id=$1',[sessions.get(owner)]); await actor(owner);
  assert.equal(await value('select public.dopmi_rescue_file_access($1,true) value',[included.path]),false);
  await db.exec('reset role'); await db.query('update auth.sessions set not_after=null where id=$1',[sessions.get(owner)]); await actor(owner);
  p=await save(p,{files:[{path:included.path,role:'public'}]}); p=await reviseTransition(p); await actor(); await review(p);
  assert.equal(await value('select public.dopmi_rescue_file_access($1) value',[included.path]),true);
  assert.equal(await value('select public.dopmi_rescue_file_access($1) value',[unused.path]),false);
  await actor(null,'anon');
  assert.equal(await value('select public.dopmi_rescue_file_access($1) value',[included.path]),true);
  assert.equal(await value('select public.dopmi_rescue_file_access($1) value',[unused.path]),false);
});

test('moderator correction has a private complete recovery; approved thanks is retained and stale thanks cannot pass the real guard',async()=>{
  const f=await published(1); const thanks=await media(f); await db.exec('reset role');
  await db.query('update private.dopmi_video_settings set enabled=true');
  await db.query('update public.dopmi_rescue_records set video_thanks_required=true where id=$1',[f.id]);
  await actor(); await value("select public.dopmi_review_rescue($1,3,'changes_requested','Corrige información privada publicada',0,false,'',false) value",[f.id]);
  f.approvedVersion=4; await db.exec('reset role'); await db.exec('savepoint missing_approved_thanks');
  await db.query("update private.dopmi_video_assets set moderation_state='stale' where id=$1",[thanks.id]); await actor(owner);
  let p=await start(f); assert.equal(p.public_version_visible,false); assert.equal(p.case_unit.revision_recovery,true); assert.equal(p.case_unit.can_start_revision,true);
  assert.deepEqual(p.publication_blockers,['approved_thanks_required']); p=await save(p); p=await reviseTransition(p); await actor();
  await rejected(()=>review(p),'23514');
  assert.equal((await value('select public.dopmi_rescue_public($1) value',[f.id])).total,0);
  await db.exec('reset role'); await db.exec('rollback to savepoint missing_approved_thanks'); await actor(owner);
  p=await start(f); assert.deepEqual(p.publication_blockers,[]);
  p=await save(p,{public_data:{...p.record.public_data,story:'Historia corregida con privacidad revisada'}}); p=await reviseTransition(p);
  assert.equal((await value('select public.dopmi_rescue_public($1) value',[f.id])).total,0,'old unsafe version stays hidden throughout review');
  await actor(); const result=await review(p); assert.equal(result.record.status,'approved'); assert.equal(result.record.version,5); assert.equal(result.public_version_visible,true);
  assert.equal(result.record.approved_snapshot.story,'Historia corregida con privacidad revisada');
  await db.exec('reset role'); assert.equal(await value('select moderation_state value from private.dopmi_video_assets where id=$1',[thanks.id]),'approved');
  assert.equal(await value('select count(*)::int value from private.dopmi_video_reviews where asset_id=$1',[thanks.id]),1,'one conservation audit without a second media decision');
});
