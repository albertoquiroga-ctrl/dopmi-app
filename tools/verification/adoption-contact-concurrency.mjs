import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';

// Only a disposable local PostgreSQL container; no remote credentials or data.
const containers=execFileSync('docker',['ps','--filter','name=supabase_db_','--format','{{.ID}}'],{encoding:'utf8'}).trim().split('\n').filter(Boolean);
assert.equal(containers.length,1,'Expected one disposable local Supabase database');
const base=['exec','-i',containers[0],'psql','-X','-q','-t','-A','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres'];
const query=sql=>execFileSync('docker',base,{input:sql,encoding:'utf8'}).trim();
const owner='89200000-0000-4000-8000-000000000001';
const adopter='89200000-0000-4000-8000-000000000002';
const post='89200000-0000-4000-8000-000000000003';
const concurrent=(sql,notify=()=>{},hold=false)=>{
  const p=spawn('docker',base);let out='',err='';
  const done=new Promise((resolve,reject)=>{
  p.stdout.on('data',s=>{out+=s;notify(out);});p.stderr.on('data',s=>err+=s);
  p.on('error',reject);p.on('close',code=>code===0?resolve(out.trim()):reject(new Error(err)));
});
  // Keep failures handled even while another session is being inspected.
  done.catch(()=>{});
  if(hold)p.stdin.write(sql);else p.stdin.end(sql);
  return {p,done};
};
const firstName='dopmi_contact_first_889',secondName='dopmi_contact_second_889';
const begin=`begin; set local role authenticated; select set_config('request.jwt.claim.sub','${adopter}',true);`;
let first,second;
try {
query(`begin; insert into auth.users(id,email,raw_user_meta_data,email_confirmed_at) values
  ('${owner}','contact-owner@example.test','{"display_name":"Contacto CI","terms_version":"development-2026-09-13","terms_accepted":true}',now()),
  ('${adopter}','contact-adopter@example.test','{"display_name":"Adoptante CI","terms_version":"development-2026-09-13","terms_accepted":true}',now());
  insert into public.dopmi_adoptions(id,owner_id,pet_name,status) values('${post}','${owner}','Luna','published'); commit;`);
  let ready;const contactReady=new Promise(r=>ready=r);
  first=concurrent(`set application_name='${firstName}'; ${begin} select dopmi_start_adoption_contact('${post}');\n\\echo contact-ready\n`,out=>{if(out.includes('contact-ready'))ready();},true);
  let readyTimer;
  try {
    await Promise.race([contactReady,first.done.then(()=>{throw new Error('First transaction ended before overlap');}),new Promise((_,reject)=>{readyTimer=setTimeout(()=>reject(new Error('Contact lock acquisition timed out')),20000);})]);
  } finally {clearTimeout(readyTimer);}
  second=concurrent(`set application_name='${secondName}'; ${begin} select dopmi_start_adoption_contact('${post}'); commit;`);
  let blocked=false;
  const deadline=Date.now()+20000;
  while(Date.now()<deadline){
    blocked=query(`select exists(select 1 from pg_stat_activity s where s.application_name='${secondName}' and s.wait_event_type='Lock' and exists(select 1 from pg_stat_activity f where f.application_name='${firstName}' and f.pid=any(pg_blocking_pids(s.pid))));`)==='t';
    if(blocked)break;
    await new Promise(resolve=>setTimeout(resolve,250));
  }
  assert.ok(blocked,'Second device must be observed blocked by the first uncommitted contact');
  first.p.stdin.end('commit;\n');
  await Promise.all([first.done,second.done]);
  // Discard both response values, then retry on a fresh connection as after restart.
  query(`${begin} select dopmi_start_adoption_contact('${post}'); commit;`);
  assert.equal(query(`select (select count(*) from dopmi_threads where post_id='${post}'),
    (select count(*) from dopmi_messages m join dopmi_threads t on t.id=m.thread_id where t.post_id='${post}'),
    (select count(*) from dopmi_notifications where post_id='${post}' and kind='message');`),'1|1|1');
  console.log('Adoption contact: proven overlapping devices and discarded-response retry create one thread, one greeting, one notification');
} finally {
  // Terminate only this harness's sessions before deleting its exact fixture IDs.
  query(`select pg_terminate_backend(pid) from pg_stat_activity where application_name in('${firstName}','${secondName}');`);
  if(first)first.p.stdin.destroy();
  await Promise.allSettled([first?.done,second?.done].filter(Boolean));
  query(`delete from auth.users where id in('${owner}','${adopter}');`);
}
