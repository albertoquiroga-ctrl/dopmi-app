import assert from 'node:assert/strict';
import {execFileSync,spawn} from 'node:child_process';
import {randomUUID} from 'node:crypto';

// Ownership: video backend verification. CI invokes this only after local
// Supabase db start/test db. No URL, token, provider, payment or remote DB input.
// Docker must itself use a local socket; a remote Docker context is rejected.
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

const runId=randomUUID().replaceAll('-',''),owner=randomUUID(),cases=[],photos=[],sessions=new Set(),children=new Set(),transactions=[];
const priorEnabled=query('select enabled from private.dopmi_video_settings where singleton;');
assert.ok(['t','f'].includes(priorEnabled),'Expected one existing local video setting');
let seeded=false;
const literal=value=>"'"+String(value).replaceAll("'","''")+"'";
const json=value=>literal(JSON.stringify(value))+'::jsonb';
const auth=`set local role authenticated;select set_config('request.jwt.claim.sub','${owner}',true);`;
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
try{
 query(`begin;insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values('${owner}','video-urgency-${runId}@example.test','{"display_name":"Synthetic urgency CI","terms_version":"development-2026-09-13","terms_accepted":true}',now());update private.dopmi_video_settings set enabled=true where singleton;commit;`);seeded=true;
 await race('video wins against concurrent photo','video','photo');
 await race('photo wins against concurrent video','photo','video');
 await race('two distinct videos produce one active asset','video','video');
 await race('same request resumes the identical asset after blocked response','video','video',{sameKey:true});
 await race('rolled-back video leaves photo free to commit','video','photo',{rollbackFirst:true});
 await race('rolled-back photo leaves video free to commit','photo','video',{rollbackFirst:true});
 console.log('Urgency concurrency: 6 real PostgreSQL overlap scenarios passed on disposable local fixtures');
}finally{
 // Terminate only this run's sessions before removing exact synthetic IDs. Never
 // alter preexisting financial rows, snapshots, provider assets or user fixtures.
 if(sessions.size)query(`select pg_terminate_backend(pid) from pg_stat_activity where application_name in(${[...sessions].map(literal).join(',')});`);
 for(const child of children)child.stdin.destroy();
 await Promise.allSettled(transactions);
 if(seeded){
  const ids=cases.map(id=>literal(id)+'::uuid').join(',');
  query(`begin;${cases.length?`delete from private.dopmi_video_assets where parent_id in(${ids});delete from private.dopmi_urgent_coverage_state where case_id in(${ids});delete from private.dopmi_rescue_history where record_id in(${ids});delete from public.dopmi_rescue_records where id in(${ids});`:''}
  ${photos.length?`delete from storage.objects where bucket_id='dopmi-rescue-evidence' and name in(${photos.map(literal).join(',')});`:''}
  delete from private.dopmi_consents where owner_id='${owner}';delete from auth.users where id='${owner}';delete from public.profiles where id='${owner}';update private.dopmi_video_settings set enabled=${priorEnabled==='t'?'true':'false'} where singleton;commit;`);
 }
}
