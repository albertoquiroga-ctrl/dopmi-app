import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';

assert.equal(process.argv[2], '--execute-dev-fixture');
const configPath=process.argv[3];
const config=JSON.parse(await readFile(configPath,'utf8'));
assert.equal(config.url,'https://ohqxranynackjignryep.supabase.co');
assert.equal(config.accounts.length,3);
for(const account of config.accounts) {
  assert.match(account.id,/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(account.email,`parity-report-338-${account.id}@example.invalid`);
}
if(!config.key.startsWith('sb_publishable_')) assert.equal(JSON.parse(Buffer.from(config.key.split('.')[1],'base64url')).role,'anon');
const journal={stage:'login',passed:[],receipts:[],logout:false};
const sessions=[];
async function call(endpoint,body,token,method='POST') {
  return fetch(config.url+endpoint,{method,signal:AbortSignal.timeout(20000),headers:{apikey:config.key,...(token?{Authorization:`Bearer ${token}`} : {}),'Content-Type':'application/json'},...(method==='GET'?{}:{body:JSON.stringify(body)})});
}
async function rpc(name,body,token) {
  const response=await call('/rest/v1/rpc/'+name,body,token);
  assert.equal(response.ok,true,`${name}: HTTP ${response.status}`);
  return response.json();
}
try {
  for(const account of config.accounts.slice(0,2)) {
    const response=await call('/auth/v1/token?grant_type=password',{email:account.email,password:account.password});
    assert.equal(response.ok,true,`fixture login: HTTP ${response.status}`);
    const session=await response.json();
    assert.equal(session.user.id,account.id);
    sessions.push(session.access_token);
  }
  journal.passed.push('two-real-auth-sessions');
  journal.stage='reports';
  for(const [type,id] of [['adoption',config.post],['rescuer',config.accounts[2].id]]) {
    const payload={target_type:type,target_id:id,reason:'other',details:'  Motivo sintético de aceptación 338  '};
    const first=await rpc('dopmi_report_content',payload,sessions[0]);
    assert.match(first,/^[0-9a-f-]{36}$/);
    assert.equal(await rpc('dopmi_report_content',payload,sessions[0]),first);
    const peer=await rpc('dopmi_report_content',payload,sessions[1]);
    assert.notEqual(peer,first);
    journal.receipts.push({type,id,first,peer});
  }
  journal.passed.push('adoption-and-rescuer-uuid-idempotent-retry-peer-isolated');
  journal.stage='privacy';
  for(const token of [...sessions,undefined]) {
    const response=await call(`/rest/v1/dopmi_content_reports?select=id&target_id=eq.${config.post}`,undefined,token,'GET');
    assert.equal(response.ok,false,'direct report read must fail');
    assert.ok([401,403].includes(response.status));
  }
  for(const token of sessions) {
    const response=await call('/rest/v1/rpc/dopmi_admin_reports',{},token);
    assert.equal(response.ok,false,'ordinary actor cannot inspect moderation inbox');
    assert.equal(response.status,403);
  }
  const direct=await call('/rest/v1/dopmi_content_reports',{reporter_id:config.accounts[0].id,target_type:'adoption',target_id:config.post,reason:'other',details:'attempt direct'},sessions[0]);
  assert.equal(direct.ok,false);
  const anonymous=await call('/rest/v1/rpc/dopmi_report_content',{target_type:'adoption',target_id:config.post,reason:'other',details:'anonymous attempt'});
  assert.equal(anonymous.ok,false);
  journal.passed.push('reporter-peer-anon-direct-read-write-and-nonadmin-inbox-denied');
  journal.stage='validation';
  for(const payload of [
    {target_type:'adoption',target_id:config.unavailable,reason:'other',details:'unavailable target'},
    {target_type:'adoption',target_id:config.post,reason:'other',details:'x'.repeat(1001)},
    {target_type:'adoption',target_id:config.post,reason:'invalid',details:'invalid reason'},
  ]) {
    const response=await call('/rest/v1/rpc/dopmi_report_content',payload,sessions[0]);
    assert.equal(response.status,400);
    assert.equal((await response.json()).code,'22023');
  }
  journal.passed.push('unavailable-content-overlimit-and-invalid-reason-rejected');
  journal.stage='complete';
} finally {
  let loggedOut=true;
  for(const token of sessions) {
    const response=await call('/auth/v1/logout?scope=global',{},token);
    loggedOut &&= response.ok;
  }
  journal.logout=loggedOut;
  await writeFile(`${configPath}.state.json`,JSON.stringify(journal,null,2));
  console.log(JSON.stringify(journal));
}
