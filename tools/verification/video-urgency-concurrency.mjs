import assert from 'node:assert/strict';
import {execFileSync,spawn} from 'node:child_process';
import {randomUUID} from 'node:crypto';

// Ownership: video backend verification. CI invokes this only after local
// Supabase db start/test db. No URL, token, provider, payment or remote DB input.
// Docker must itself use a local socket; a remote Docker context is rejected.
// Storage API is not started in this job. SQL-created metadata and its synthetic
// owner remain until the GitHub-hosted runner (including its containers) is
// destroyed. Do not run against persistent/self-hosted/local Docker installations.
function assertDisposableRunner(env){
 assert.equal(env.GITHUB_ACTIONS,'true','Requires an ephemeral GitHub Actions runner');
 assert.equal(env.RUNNER_ENVIRONMENT,'github-hosted','Requires GitHub-hosted disposal of retained Storage fixtures');
}
if(process.argv.includes('--probe-cleanup-contract')){
 assert.throws(()=>assertDisposableRunner({}),/ephemeral/);
 assert.throws(()=>assertDisposableRunner({GITHUB_ACTIONS:'true',RUNNER_ENVIRONMENT:'self-hosted'}),/GitHub-hosted/);
 assertDisposableRunner({GITHUB_ACTIONS:'true',RUNNER_ENVIRONMENT:'github-hosted'});
 console.log('PASS: persistent and self-hosted runners rejected; GitHub-hosted disposal accepted; no Docker invoked');
 process.exit(0);
}
assertDisposableRunner(process.env);
const dockerHost=process.env.DOCKER_HOST??execFileSync('docker',['context','inspect','--format','{{.Endpoints.docker.Host}}'],{encoding:'utf8'}).trim();
const localWindowsPipe=/^npipe:\/{4}\.\/pipe\/[^/]+$/i.test(dockerHost.replaceAll('\\','/'));
assert.ok(dockerHost.startsWith('unix:///')||localWindowsPipe,'Only a local Docker socket is authorized');
const containers=execFileSync('docker',['ps','--filter','name=supabase_db_','--format','{{.ID}}'],{encoding:'utf8'}).trim().split(/\r?\n/).filter(Boolean);
assert.equal(containers.length,1,'Expected exactly one disposable local Supabase PostgreSQL container');
const container=containers[0];assert.match(container,/^[a-f0-9]+$/);
assert.equal(execFileSync('docker',['inspect','--format','{{.Name}}',container],{encoding:'utf8'}).trim(),'/supabase_db_dopmi','Use only this repository local Supabase project');
const base=['exec','-i',container,'psql','-X','-q','-t','-A','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-U','postgres','-d','postgres'];
const query=sql=>execFileSync('docker',base,{input:sql,encoding:'utf8',timeout:30000}).trim();
assert.equal(query("select current_database()||'|'||coalesce(inet_server_addr()::text,'unix');"),'postgres|unix','PostgreSQL connection must use the container local socket');
assert.equal(query("select to_regprocedure('public.dopmi_video_policy(uuid)') is not null and to_regclass('private.dopmi_video_assets') is not null;"),'t','Apply the actual candidate migration before running concurrency verification');
assert.equal(query("select to_regprocedure('public.dopmi_payment_server_before_pending_stripe(text,jsonb)') is not null;"),'t','Apply the pending Stripe candidate migration before running concurrency verification');

const runId=randomUUID().replaceAll('-',''),owner=randomUUID(),pendingOwner=randomUUID(),pendingVerification=randomUUID(),pendingAccount=`acct_pending_${runId}`,cases=[],photos=[],sessions=new Set(),children=new Set(),transactions=[];
const priorEnabled=query('select enabled from private.dopmi_video_settings where singleton;');
assert.ok(['t','f'].includes(priorEnabled),'Expected one existing local video setting');
let seeded=false,pendingSeeded=false;
const literal=value=>"'"+String(value).replaceAll("'","''")+"'";
const json=value=>literal(JSON.stringify(value))+'::jsonb';
const auth=`set local role authenticated;select set_config('request.jwt.claim.sub','${owner}',true);`;
const pendingAuth=`set local role authenticated;select set_config('request.jwt.claim.sub','${pendingOwner}',true),set_config('request.jwt.claim.role','authenticated',true),set_config('request.jwt.claims',${json({sub:pendingOwner,role:'authenticated'})}::text,true);`;
const pendingService=`set local role service_role;select set_config('request.jwt.claim.sub','',true),set_config('request.jwt.claim.role','service_role',true),set_config('request.jwt.claims','{"role":"service_role"}',true);`;
function concurrent(sql,name,onOutput=()=>{},hold=false){
 sessions.add(name);const child=spawn('docker',base);children.add(child);let stdout='',stderr='';
 const done=new Promise((resolve,reject)=>{child.stdout.on('data',chunk=>{stdout+=chunk;onOutput(stdout);});child.stderr.on('data',chunk=>{stderr+=chunk;});child.on('error',reject);child.on('close',code=>{children.delete(child);code===0?resolve(stdout.trim()):reject(new Error(`Local PostgreSQL transaction failed (${code}): ${stderr}`));});});
 done.catch(()=>{});transactions.push(done);child.stdin.on('error',()=>{});const input=`set application_name='${name}';set statement_timeout='25s';${sql}`;
 if(hold)child.stdin.write(input);else child.stdin.end(input);
 return {child,done};
}
async function observedBlock(firstName,secondName){
 const deadline=Date.now()+20000;
 while(Date.now()<deadline){
  if(query(`select exists(select 1 from pg_stat_activity s where s.application_name='${secondName}' and s.wait_event_type='Lock' and exists(select 1 from pg_stat_activity f where f.application_name='${firstName}' and f.pid=any(pg_blocking_pids(s.pid))));`)==='t')return;
  await new Promise(resolve=>setTimeout(resolve,100));
 }
 throw new Error('The competing transaction was not observed blocked by the first connection');
}
function fixture(label){
 const id=randomUUID(),photo=`${owner}/${id}/${randomUUID()}.jpg`;
 const fields={pet_name:'Synthetic urgency',species:'dog',sex:'female',age:'Adulto',story:'Synthetic concurrent case',city:'Synthetic city',state:'Synthetic state',need:'Synthetic medical need',need_items:[{id:randomUUID(),type:'medicine',title:'Synthetic medicine',amount_cents:1000,detail:'Synthetic detail',urgent:true}]};
 const snapshot={source:'immutable approved snapshot',scenario:label,photos:['synthetic-prior-approved.jpg']};
 query(`begin;insert into public.dopmi_rescue_records(id,owner_id,kind,status,public_data,files,approved_snapshot,video_thanks_required) values('${id}','${owner}','case','draft',${json(fields)},${json([{path:photo,role:'public'}])},${json(snapshot)},false);
 insert into storage.objects(bucket_id,name,owner_id) values('dopmi-rescue-evidence',${literal(photo)},'${owner}');commit;`);
 cases.push(id);photos.push(photo);return {id,photo,fields,snapshot};
}
const video=(f,key)=>`select public.dopmi_video_action(${json({action:'begin',parent_id:f.id,parent_version:1,purpose:'urgency',request_key:key,bytes:1024,file_fingerprint:'a'.repeat(64)})})->>'id';`;
const photo=f=>`select public.dopmi_save_rescue('case',${json({...f.fields,urgency_photo_path:f.photo})},'{}'::jsonb,${json([{path:f.photo,role:'public'}])},'${f.id}',1,null)->>'id';`;
function result(f){return JSON.parse(query(`select jsonb_build_object('version',r.version,'photo',coalesce(r.public_data->>'urgency_photo_path',''),'snapshot',r.approved_snapshot,'videos',(select count(*) from private.dopmi_video_assets a where a.parent_id=r.id and a.purpose='urgency' and a.technical_state not in ('canceled','deleted')),'all_assets',(select count(*) from private.dopmi_video_assets a where a.parent_id=r.id),'asset_ids',(select coalesce(jsonb_agg(a.id),'[]'::jsonb) from private.dopmi_video_assets a where a.parent_id=r.id)) from public.dopmi_rescue_records r where id='${f.id}';`));}
async function race(label,firstKind,secondKind,{sameKey=false,rollbackFirst=false}={}){
 const f=fixture(label),firstName=`vurg_${runId.slice(0,12)}_${cases.length}_a`,secondName=`vurg_${runId.slice(0,12)}_${cases.length}_b`,key=randomUUID();
 const firstSql=firstKind==='video'?video(f,key):photo(f),secondSql=secondKind==='video'?video(f,sameKey?key:randomUUID()):photo(f);
 let notify;const locked=new Promise(resolve=>{notify=resolve;});
 const first=concurrent(`begin;${auth}${firstSql}\n\\echo fixture-parent-locked\n`,firstName,out=>{if(out.includes('fixture-parent-locked'))notify();},true);
 let timer;
 try{
  await Promise.race([locked,first.done.then(()=>{throw new Error('First transaction exited before observed overlap');}),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('First lock acquisition timed out')),20000);})]);
 }finally{clearTimeout(timer);}
 const second=concurrent(`begin;${auth}${secondSql}commit;`,secondName);
 await observedBlock(firstName,secondName);
 first.child.stdin.end(rollbackFirst?'rollback;\n':'commit;\n');
 const [a,b]=await Promise.allSettled([first.done,second.done]);assert.equal(a.status,'fulfilled');
 const expectedSecond=rollbackFirst||sameKey?'fulfilled':'rejected';assert.equal(b.status,expectedSecond,`${label}: unexpected competing transaction outcome`);
 if(b.status==='rejected'){assert.match(b.reason.message,/ERROR:\s+(22023|23505):/,'Expected media validation or uniqueness SQLSTATE');assert.match(b.reason.message,/Elige una foto p.blica propia o un video|El complemento de urgencia requiere|dopmi_one_active_urgency_video/,'Failure must come from the exact media exclusion or uniqueness guard');}
 const state=result(f);assert.deepEqual(state.snapshot,f.snapshot,'The concurrent attempt must preserve the prior approved snapshot');
 const winner=rollbackFirst?secondKind:firstKind;
 assert.equal(state.videos,winner==='video'?1:0);assert.equal(state.all_assets,winner==='video'?1:0,'A rolled-back losing transaction must leave no asset');assert.equal(state.photo,winner==='photo'?f.photo:'');assert.equal(state.version,winner==='photo'?2:1,'A rolled-back photo save must not consume a parent version');
 if(sameKey){const id=state.asset_ids[0];assert.ok(a.value.split(/\r?\n/).includes(id));assert.ok(b.value.split(/\r?\n/).includes(id));}
 console.log(JSON.stringify({scenario:label,blocked:true,first:rollbackFirst?'rolled_back':'committed',second:b.status,singleWinner:winner,snapshotPreserved:true}));
}
// New support fixtures exercise only lifecycle concurrency. The explicit false
// video requirement represents an already grandfathered synthetic draft; no
// flag, production guard or approved/public snapshot is changed for these cases.
function pendingFixture(label){
 const id=randomUUID(),photo=`${pendingOwner}/${id}/${randomUUID()}.jpg`;
 const fields={pet_name:'Synthetic pending Stripe',species:'dog',sex:'unknown',age:'Adulto',story:`Synthetic concurrency ${label}`,city:'Synthetic city',state:'Synthetic state',need_items:[]};
 const files=[{path:photo,role:'public'}];
 query(`begin;update private.dopmi_connect_accounts set transfers_enabled=false,payouts_enabled=false where owner_id='${pendingOwner}' and account_id=${literal(pendingAccount)};
 insert into public.dopmi_rescue_records(id,owner_id,kind,status,public_data,files,video_thanks_required) values('${id}','${pendingOwner}','case','draft',${json(fields)},${json(files)},false);
 insert into storage.objects(bucket_id,name,owner_id) values('dopmi-rescue-evidence',${literal(photo)},'${pendingOwner}');commit;`);
 cases.push(id);photos.push(photo);return {id,photo,fields,files};
}
const pendingTransition=(f,version,action)=>`select 'pending-result:'||public.dopmi_transition_rescue('${f.id}',${version},${literal(action)})::text;`;
const pendingConnect=()=>`select 'pending-result:'||public.dopmi_payment_server('connect_save',${json({actor:pendingOwner,account_id:pendingAccount,transfers_enabled:true,payouts_enabled:true,details_submitted:false})})::text;`;
function pendingOutput(output){
 const lines=output.split(/\r?\n/).filter(line=>line.startsWith('pending-result:'));
 assert.equal(lines.length,1,'Each transaction must return exactly one actual lifecycle result');return JSON.parse(lines[0].slice('pending-result:'.length));
}
function pendingState(f){
 return JSON.parse(query(`select jsonb_build_object('record',to_jsonb(r),
 'history',(select coalesce(jsonb_agg(jsonb_build_object('action',h.action,'version',h.version,'actor_id',h.actor_id,'actor_type',h.actor_type,'source',h.source,'previous_status',h.previous_status,'status',h.snapshot->>'status') order by h.version,h.created_at,h.id),'[]'::jsonb) from private.dopmi_rescue_history h where h.record_id=r.id),
 'photo_count',(select count(*) from storage.objects where bucket_id='dopmi-rescue-evidence' and name=${literal(f.photo)}),
 'ready',(select account_id=${literal(pendingAccount)} and transfers_enabled and payouts_enabled from private.dopmi_connect_accounts where owner_id='${pendingOwner}'),
 'expenses',(select count(*) from public.dopmi_rescue_records e where e.parent_id=r.id),
 'donations',(select count(*) from public.dopmi_donations d where d.rescuer_id='${pendingOwner}'),
 'payment_snapshots',(select count(*) from private.dopmi_payment_method_snapshots m where m.owner_id='${pendingOwner}'))
 from public.dopmi_rescue_records r where r.id='${f.id}';`));
}
function assertPendingContents(f,state){
 const r=state.record;
 assert.equal(r.id,f.id);assert.equal(r.owner_id,pendingOwner);assert.equal(r.kind,'case');assert.equal(r.parent_id,null);
 assert.deepEqual(r.public_data,f.fields);assert.deepEqual(r.private_data,{});assert.deepEqual(r.files,f.files);
 assert.equal(r.approved_snapshot,null);assert.equal(r.approved_at,null);assert.equal(r.reimbursable_cents,0);assert.equal(r.urgent,false);assert.equal(r.priority_reason,'');
 assert.equal(state.photo_count,1);assert.equal(state.ready,true);assert.equal(state.expenses,0);assert.equal(state.donations,0);assert.equal(state.payment_snapshots,0);
}
async function pendingRace(label,order){
 const f=pendingFixture(label),firstName=`pstripe_${runId.slice(0,12)}_${cases.length}_a`,secondName=`pstripe_${runId.slice(0,12)}_${cases.length}_b`;
 if(order==='withdraw_first'){
  const submitted=pendingOutput(query(`begin;${pendingAuth}${pendingTransition(f,1,'submit')}commit;`));
  assert.equal(submitted.status,'pending_stripe');assert.equal(submitted.version,2);assert.equal(submitted.submitted_at,null);
 }
 const firstAuth=order==='ready_first'?pendingService:pendingAuth,secondAuth=order==='ready_first'?pendingAuth:pendingService;
 const firstSql=order==='ready_first'?pendingConnect():pendingTransition(f,order==='withdraw_first'?2:1,order==='withdraw_first'?'withdraw':'submit');
 const secondSql=order==='ready_first'?pendingTransition(f,1,'submit'):pendingConnect();
 let notify;const locked=new Promise(resolve=>{notify=resolve;});
 const first=concurrent(`begin;${firstAuth}${firstSql}\n\\echo pending-owner-locked\n`,firstName,out=>{if(out.includes('pending-owner-locked'))notify();},true);
 let timer;
 try{
  await Promise.race([locked,first.done.then(()=>{throw new Error('First pending Stripe transaction exited before observed overlap');}),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('First pending Stripe lock acquisition timed out')),20000);})]);
 }finally{clearTimeout(timer);}
 const second=concurrent(`begin;${secondAuth}${secondSql}commit;`,secondName);
 await observedBlock(firstName,secondName);first.child.stdin.end('commit;\n');
 const [a,b]=await Promise.allSettled([first.done,second.done]);
 assert.equal(a.status,'fulfilled',a.reason?.message);assert.equal(b.status,'fulfilled',b.reason?.message);
 const firstResult=pendingOutput(a.value),secondResult=pendingOutput(b.value),connection=order==='ready_first'?firstResult:secondResult;
 assert.equal(connection.transfers_enabled,true);assert.equal(connection.payouts_enabled,true);
 assert.deepEqual(connection.pending_stripe_sync,{source:'stripe_connect_ready',promoted_count:order==='submit_first'?1:0,deferred_count:0,deferred:[]});
 const state=pendingState(f);assertPendingContents(f,state);
 assert.equal(state.record.status,order==='withdraw_first'?'draft':'submitted');assert.equal(state.record.version,order==='ready_first'?2:3);
 assert.equal(state.record.submitted_at===null,order==='withdraw_first');
 const human=state.history.filter(h=>h.action==='submit'),system=state.history.filter(h=>h.action==='stripe_ready'),withdraw=state.history.filter(h=>h.action==='withdraw');
 assert.equal(human.length,1);assert.equal(human[0].actor_id,pendingOwner);assert.equal(human[0].actor_type,'user');assert.equal(human[0].source,'user');assert.equal(human[0].version,2);
 assert.equal(human[0].status,order==='ready_first'?'submitted':'pending_stripe');
 assert.equal(system.length,order==='submit_first'?1:0);assert.equal(withdraw.length,order==='withdraw_first'?1:0);
 assert.equal(state.history.length,order==='ready_first'?1:2,'Exactly the expected transitions may be audited');
 if(order==='submit_first'){
  assert.equal(firstResult.status,'pending_stripe');assert.equal(firstResult.version,2);assert.equal(firstResult.submitted_at,null);
  assert.deepEqual(system[0],{action:'stripe_ready',version:3,actor_id:null,actor_type:'system',source:'stripe_connect_ready',previous_status:'pending_stripe',status:'submitted'});
  assert.throws(()=>query(`begin;${pendingAuth}${pendingTransition(f,2,'withdraw')}commit;`),/ERROR:\s+40001:/,'Withdrawal using the old pending version must fail after promotion');
 }else if(order==='ready_first'){
  assert.equal(secondResult.status,'submitted');assert.equal(secondResult.version,2);
 }else{
  assert.equal(firstResult.status,'draft');assert.equal(firstResult.version,3);assert.equal(withdraw[0].actor_id,pendingOwner);assert.equal(withdraw[0].actor_type,'user');assert.equal(withdraw[0].version,3);
 }
 const replay=pendingOutput(query(`begin;${pendingService}${pendingConnect()}commit;`));
 assert.equal(replay.pending_stripe_sync.promoted_count,0);assert.equal(replay.pending_stripe_sync.deferred_count,0);
 assert.deepEqual(pendingState(f),state,'Repeated readiness must preserve case content, version, audit, photos and zero financial state');
 console.log(JSON.stringify({scenario:label,blocked:true,first:'committed',second:'fulfilled',status:state.record.status,version:state.record.version,humanSubmissions:human.length,stripePromotions:system.length,replayUnchanged:true}));
}
try{
 query(`begin;insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values('${owner}','video-urgency-${runId}@example.test','{"display_name":"Synthetic urgency CI","terms_version":"development-2026-09-13","terms_accepted":true}',now());update private.dopmi_video_settings set enabled=true where singleton;commit;`);seeded=true;
 await race('video wins against concurrent photo','video','photo');
 await race('photo wins against concurrent video','photo','video');
 await race('two distinct videos produce one active asset','video','video');
 await race('same request resumes the identical asset after blocked response','video','video',{sameKey:true});
 await race('rolled-back video leaves photo free to commit','video','photo',{rollbackFirst:true});
 await race('rolled-back photo leaves video free to commit','photo','video',{rollbackFirst:true});
 console.log('Urgency concurrency: 6 real PostgreSQL overlap scenarios passed on disposable local fixtures');
 query(`begin;insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values('${pendingOwner}','pending-stripe-${runId}@example.test','{"display_name":"Synthetic pending Stripe CI","terms_version":"development-2026-09-13","terms_accepted":true}',now());
 insert into public.dopmi_rescue_records(id,owner_id,kind,status,approved_snapshot) values('${pendingVerification}','${pendingOwner}','verification','approved','{}');
 insert into private.dopmi_connect_accounts(owner_id,account_id,transfers_enabled,payouts_enabled) values('${pendingOwner}',${literal(pendingAccount)},false,false);commit;`);pendingSeeded=true;
 await pendingRace('submit waits privately before concurrent Stripe readiness','submit_first');
 await pendingRace('Stripe readiness wins before concurrent submit','ready_first');
 await pendingRace('withdrawal wins before concurrent Stripe readiness','withdraw_first');
 console.log('Pending Stripe concurrency: 3 real PostgreSQL overlap scenarios passed on disposable local fixtures');
}finally{
 // Terminate only this run's sessions before removing exact synthetic IDs. Never
 // alter preexisting financial rows, snapshots, provider assets or user fixtures.
 if(sessions.size)query(`select pg_terminate_backend(pid) from pg_stat_activity where application_name in(${[...sessions].map(literal).join(',')});`);
 for(const child of children)child.stdin.destroy();
 await Promise.allSettled(transactions);
 if(seeded){
  const domainIds=pendingSeeded?[...cases,pendingVerification]:cases,ids=domainIds.map(id=>literal(id)+'::uuid').join(',');
  query(`begin;${domainIds.length?`delete from private.dopmi_video_assets where parent_id in(${ids});delete from private.dopmi_urgent_coverage_state where case_id in(${ids});delete from private.dopmi_rescue_history where record_id in(${ids});delete from public.dopmi_rescue_records where id in(${ids});`:''}
  ${pendingSeeded?`delete from private.dopmi_connect_accounts where owner_id='${pendingOwner}' and account_id=${literal(pendingAccount)};`:''}
  update private.dopmi_video_settings set enabled=${priorEnabled==='t'?'true':'false'} where singleton;commit;`);
  // Storage's deletion protection remains enabled. Retain the exact synthetic
  // owner/consents as well, avoiding owner FK/cascade paths into storage.objects.
  const retainedMetadata=photos.length?Number(query(`select count(*) from storage.objects where bucket_id='dopmi-rescue-evidence' and name in(${photos.map(literal).join(',')});`)):0;
  assert.equal(retainedMetadata,photos.length,'All SQL-only Storage fixtures must be accounted for');
  assert.equal(query('select enabled from private.dopmi_video_settings where singleton;'),priorEnabled,'Restore the original video flag');
  if(domainIds.length){
   assert.equal(query(`select count(*) from public.dopmi_rescue_records where id in(${ids});`),'0','Remove this run synthetic domain records');
   assert.equal(query(`select count(*) from private.dopmi_rescue_history where record_id in(${ids});`),'0','Remove this run exact synthetic audit records');
  }
  if(pendingSeeded)assert.equal(query(`select count(*) from private.dopmi_connect_accounts where owner_id='${pendingOwner}' and account_id=${literal(pendingAccount)};`),'0','Remove this run synthetic Connect linkage');
  console.log(JSON.stringify({cleanup:'domain removed; original flag restored',retainedStorageMetadata:retainedMetadata,retainedSyntheticOwners:pendingSeeded?2:1,uploadedBlobs:0,disposition:'Retained metadata and synthetic owners require destruction of this ephemeral GitHub-hosted runner and its local containers; no Storage API deletion or total cleanup claimed'}));
 }
}
