import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHmac,randomUUID} from 'node:crypto';
import {VIDEO_LIMITS,VideoError,validateUpload,streamProvider,verifyStreamWebhook,createVideoHandler,drainVideoDeletionQueue} from '../../supabase/functions/_shared/video-media.mjs';
const input=()=>({id:randomUUID(),parent_id:randomUUID(),parent_version:1,purpose:'thanks',request_key:randomUUID(),bytes:1024});
const account='a'.repeat(32),id='b'.repeat(32);
const response=(value)=>new Response(JSON.stringify({success:true,result:value}),{status:200});
test('server upload size and purposes fail closed',()=>{validateUpload(input());for(const extra of [{bytes:0},{bytes:VIDEO_LIMITS.bytes+1},{parent_version:0},{purpose:'receipt_public'},{parent_id:'unknown'}])assert.throws(()=>validateUpload({...input(),...extra}));});
test('real TUS adapter sends duration/signed policy and never forwards user metadata',async()=>{let observed;const provider=streamProvider({accountId:account,apiToken:'server-only',fetcher:async(url,init)=>{observed={url,init};return new Response(null,{status:201,headers:{Location:'https://upload.videodelivery.net/secret-capability','stream-media-id':id}});}});assert.equal((await provider.create(input())).provider_id,id);assert.equal(observed.init.headers['Upload-Length'],'1024');assert.match(observed.init.headers['Upload-Metadata'],/maxDurationSeconds NjA=/);assert.match(observed.init.headers['Upload-Metadata'],/requiresignedurls/);assert.equal(observed.init.redirect,'error');});
test('provider never accepts unsafe playback or overlong processed video',async()=>{for(const item of [{uid:id,requireSignedURLs:false},{uid:id,requireSignedURLs:true,readyToStream:true,status:{state:'ready'},duration:61}]){const p=streamProvider({accountId:account,apiToken:'x',fetcher:async()=>response(item)});if(!item.requireSignedURLs)await assert.rejects(p.inspect(id));else assert.equal((await p.inspect(id)).state,'failed');}});
test('provider upload capability is limited to HTTPS Stream upload host',async()=>{for(const location of ['http://upload.videodelivery.net/a','https://attacker.test/a','https://evil@upload.videodelivery.net/a']){const p=streamProvider({accountId:account,apiToken:'x',fetcher:async()=>new Response(null,{status:201,headers:{Location:location,'stream-media-id':id}})});await assert.rejects(p.create(input()));}});
test('webhook verifies exact bytes, rejects tampering and timestamps outside 5minutes',async()=>{const raw=JSON.stringify({uid:id,readyToStream:true}),time=1000,secret='hook-secret';const sig=createHmac('sha256',secret).update(`${time}.${raw}`).digest('hex');const header=`time=${time},sig1=${sig}`;assert.equal(await verifyStreamWebhook(raw,header,secret,1000),id);await assert.rejects(verifyStreamWebhook(raw+' ',header,secret,1000));await assert.rejects(verifyStreamWebhook(raw,header,secret,1301));await assert.rejects(verifyStreamWebhook(raw,header,secret,699));});
function runtime(overrides={}){return {env:(key)=>key==='DOPMI_VIDEO_ENABLED'?'true':null,provider:()=>({}),user:async()=>({}),service:async()=>({}),...overrides};}
const request=(data)=>new Request('https://dopmi.test/video-media',{method:'POST',headers:{Authorization:'Bearer user-session'},body:JSON.stringify(data)});
test('disabled feature and unauthenticated requests make no provider calls',async()=>{let calls=0;const handler=createVideoHandler(runtime({env:()=>undefined,provider:()=>{calls++;}}));assert.equal((await handler(request({action:'begin',...input()}))).status,503);assert.equal(calls,0);});
test('lost create response is not automatically repeated; claimed pending replies 202',async()=>{let creates=0;const a=input();const handler=createVideoHandler(runtime({user:async()=>({id:a.id}),service:async()=>({claimed:false}),provider:()=>({create:async()=>{creates++;}})}));const res=await handler(request({action:'begin',...a}));assert.equal(res.status,202);assert.equal((await res.json()).upload_state,'provisioning_unknown');assert.equal(creates,0);});
test('playback rechecks authorization after provider I/O and does not issue token after withdrawal',async()=>{let auth=0,tokens=0;const handler=createVideoHandler(runtime({user:async()=>{if(++auth===2)throw new Error('withdrawn');return {id:'asset',provider_id:id,technical_state:'ready'};},provider:()=>({inspect:async()=>({state:'ready'}),playback:async()=>{tokens++;return {};}})}));assert.equal((await handler(request({action:'playback',id:randomUUID()}))).status,500);assert.equal(tokens,0);});
test('webhook trusts server readback, not signed delivery status; replay is idempotent database refresh',async()=>{const raw=JSON.stringify({uid:id,readyToStream:true,duration:40}),time=Math.floor(Date.now()/1000),secret='hook',signature=createHmac('sha256',secret).update(`${time}.${raw}`).digest('hex');let applied;const handler=createVideoHandler(runtime({env:key=>key==='DOPMI_VIDEO_ENABLED'?'true':secret,provider:()=>({inspect:async()=>({state:'failed',duration:null})}),service:async(data)=>{applied=data;}}));for(let i=0;i<2;i++)assert.equal((await handler(new Request('https://dopmi.test/video-media/webhook',{method:'POST',headers:{'Webhook-Signature':`time=${time},sig1=${signature}`},body:raw}))).status,200);assert.equal(applied.state,'failed');});

test('anonymous playback reaches only database authorization, no client actor is invented',async()=>{let authorization;const handler=createVideoHandler(runtime({user:async(token)=>{authorization=token;return {id:'public',provider_id:id,technical_state:'ready'};},provider:()=>({inspect:async()=>({state:'ready'}),playback:async()=>({hls:'signed'})})}));const res=await handler(new Request('https://dopmi.test/video-media',{method:'POST',body:JSON.stringify({action:'playback',id:randomUUID()})}));assert.equal(res.status,200);assert.equal(authorization,null);});

test('provider deletion tolerates lost reply then already-absent without creating another asset',async()=>{const p=streamProvider({accountId:account,apiToken:'x',fetcher:async()=>new Response(null,{status:404})});await p.remove(id);});

test('server cleanup acknowledges only successful deletion and retains failed work',async()=>{const done=[];const result=await drainVideoDeletionQueue({provider:()=>({remove:async id=>{if(id==='failed')throw new Error('unavailable');}}),service:async data=>{if(data.action==='cleanup_list')return {items:['ok','failed']};done.push(data.provider_id);}});assert.deepEqual(result,{removed:1,failed:1});assert.deepEqual(done,['ok']);});

test('pendingupload readback remains resumable instead of processing',async()=>{const p=streamProvider({accountId:account,apiToken:'x',fetcher:async()=>response({uid:id,requireSignedURLs:true,status:{state:'pendingupload'},readyToStream:false})});assert.deepEqual(await p.inspect(id),{state:'uploading',duration:null});});

test('unfinished provider duration is nullable and never violates nonnegative SQL contract',async()=>{
 for(const [providerState,expectedState] of [['pendingupload','uploading'],['queued','processing'],['inprogress','processing']]) {
  const provider=streamProvider({accountId:account,apiToken:'synthetic',fetcher:async()=>response({uid:id,requireSignedURLs:true,status:{state:providerState},readyToStream:false,duration:-1})});
  assert.deepEqual(await provider.inspect(id),{state:expectedState,duration:null});
 }
});

test('handler failure emits only controlled action code status and preserves response',async(t)=>{
 const logs=[];t.mock.method(console,'warn',value=>logs.push(value));
 const handler=createVideoHandler(runtime({user:async()=>{throw new VideoError('video_provider_unavailable',502);}}));
 const result=await handler(request({action:'status',id:randomUUID(),private_text:'NEVER_LOG_PRIVATE_BODY'}));
 assert.equal(result.status,502);assert.deepEqual(await result.json(),{error:'video_provider_unavailable'});
 assert.deepEqual(logs,[{event:'video_request_failed',action:'status',code:'video_provider_unavailable',status:502}]);
 assert.ok(!JSON.stringify(logs).includes('NEVER_LOG_PRIVATE_BODY'));
});

test('ready classification keeps positive duration and signed UID guards after normalization',async()=>{
 for(const [duration,state,stored] of [[-1,'failed',null],[0,'failed',0],[1,'ready',1],[60,'ready',60],[61,'failed',61]]) {
  const provider=streamProvider({accountId:account,apiToken:'synthetic',fetcher:async()=>response({uid:id,requireSignedURLs:true,status:{state:'ready'},readyToStream:true,duration})});
  assert.deepEqual(await provider.inspect(id),{state,duration:stored});
 }
 for(const extra of [{requireSignedURLs:false},{uid:'c'.repeat(32)}]) {
  const provider=streamProvider({accountId:account,apiToken:'synthetic',fetcher:async()=>response({uid:id,requireSignedURLs:true,status:{state:'ready'},readyToStream:true,duration:1,...extra})});
  await assert.rejects(provider.inspect(id),{message:'unsafe_provider_asset'});
 }
});

test('failure diagnostics never copy arbitrary action error or webhook material',async(t)=>{
 const logs=[];t.mock.method(console,'warn',value=>logs.push(value));
 const sentinel='NEVER_LOG_TOKEN_BODY_ID_URL_STACK';
 const invalidAction=await createVideoHandler(runtime())(request({action:sentinel,id:sentinel}));
 assert.equal(invalidAction.status,400);assert.deepEqual(await invalidAction.json(),{error:'invalid_action'});
 const raw=JSON.stringify({uid:id,private_text:sentinel}),time=Math.floor(Date.now()/1000),secret='synthetic-signing-secret';
 const signature=createHmac('sha256',secret).update(`${time}.${raw}`).digest('hex');
 const handler=createVideoHandler(runtime({env:key=>key==='DOPMI_VIDEO_ENABLED'?'true':secret,provider:()=>({inspect:async()=>{throw new Error(sentinel);}})}));
 const result=await handler(new Request(`https://dopmi.test/video-media/webhook?private=${sentinel}`,{method:'POST',headers:{'Webhook-Signature':`time=${time},sig1=${signature}`,'Authorization':`Bearer ${sentinel}`},body:raw}));
 assert.equal(result.status,500);assert.deepEqual(await result.json(),{error:'video_request_failed'});
 assert.deepEqual(logs,[
  {event:'video_request_failed',action:'unknown',code:'invalid_action',status:400},
  {event:'video_request_failed',action:'webhook',code:'video_request_failed',status:500},
 ]);
 for(const forbidden of [sentinel,secret,signature,id,'https://','stack'])assert.ok(!JSON.stringify(logs).includes(forbidden));
});

test('diagnostic sink failure cannot replace existing HTTP error response',async(t)=>{
 t.mock.method(console,'warn',()=>{throw new Error('synthetic sink unavailable');});
 const result=await createVideoHandler(runtime({user:async()=>{throw new VideoError('video_conflict',409);}}))(request({action:'status'}));
 assert.equal(result.status,409);assert.deepEqual(await result.json(),{error:'video_conflict'});
});

test('upstream failure diagnostics distinguish inspect from signing without copying provider data',async(t)=>{
 const logs=[];t.mock.method(console,'warn',value=>logs.push(value));
 const sentinel='PRIVATE_PROVIDER_BODY_TOKEN_URL';
 for(const [operation,status] of [['inspect',403],['playback',429]]) {
  const calls=[];
  const provider=streamProvider({accountId:account,apiToken:sentinel,fetcher:async(url)=>{
   calls.push(url.endsWith('/token')?'playback':'inspect');
   if(operation==='playback'&&!url.endsWith('/token'))return response({uid:id,requireSignedURLs:true,readyToStream:true,status:{state:'ready'},duration:20});
   return new Response(sentinel,{status});
  }});
  const handler=createVideoHandler(runtime({user:async()=>({id:'asset',provider_id:id,technical_state:'ready'}),provider:()=>provider}));
  const result=await handler(request({action:'playback',id:randomUUID()}));
  assert.equal(result.status,502);assert.deepEqual(await result.json(),{error:'video_provider_unavailable'});
  assert.deepEqual(logs.at(-1),{event:'video_request_failed',action:'playback',code:'video_provider_unavailable',status:502,provider_operation:operation,provider_status:status});
  assert.deepEqual(calls,operation==='inspect'?['inspect']:['inspect','playback']);
 }
 for(const forbidden of [sentinel,account,id,'https://','Authorization','stack'])assert.ok(!JSON.stringify(logs).includes(forbidden));
});

test('upstream create diagnostic retains one attempt and no retry',async(t)=>{
 const logs=[];t.mock.method(console,'warn',value=>logs.push(value));let calls=0;
 const provider=streamProvider({accountId:account,apiToken:'synthetic',fetcher:async()=>{calls++;return new Response(null,{status:503});}});
 const handler=createVideoHandler(runtime({user:async()=>({id:'asset',technical_state:'reserved'}),service:async()=>({claimed:true}),provider:()=>provider}));
 const result=await handler(request({action:'begin',...input()}));
 assert.equal(result.status,502);assert.equal(calls,1);
 assert.deepEqual(await result.json(),{error:'video_provider_unavailable'});
 assert.deepEqual(logs,[{event:'video_request_failed',action:'begin',code:'video_provider_unavailable',status:502,provider_operation:'create',provider_status:503}]);
});

test('invalid upstream status cannot become diagnostic material',async(t)=>{
 const logs=[];t.mock.method(console,'warn',value=>logs.push(value));
 for(const status of ['403',NaN,99,600]) {
  const provider=streamProvider({accountId:account,apiToken:'synthetic',fetcher:async()=>({ok:false,status})});
  const handler=createVideoHandler(runtime({user:async()=>({provider_id:id,technical_state:'ready'}),provider:()=>provider}));
  assert.equal((await handler(request({action:'playback',id:randomUUID()}))).status,502);
  assert.deepEqual(logs.at(-1),{event:'video_request_failed',action:'playback',code:'video_provider_unavailable',status:502});
 }
});
test('a committed bind with a lost response is read back, never deleted',async()=>{let deletes=0;const handler=createVideoHandler(runtime({user:async()=>({id:'asset',technical_state:'reserved'}),provider:()=>({create:async()=>({provider_id:id,upload_url:'https://upload.videodelivery.net/cap'}),remove:async()=>{deletes++;}}),service:async data=>{if(data.action==='claim')return {claimed:true};if(data.action==='created')return {technical_state:'provisioning_unknown'};if(data.action==='bind')throw new Error('lost_reply');if(data.action==='binding')return {bound:true,id:'asset',technical_state:'uploading',upload_url:'https://upload.videodelivery.net/cap'};throw new Error('unexpected');}}));const result=await handler(request({action:'begin',...input()}));assert.equal(result.status,200);assert.equal((await result.json()).technical_state,'uploading');assert.equal(deletes,0);});
test('uncommitted bind queues known upstream orphan durably rather than deleting blindly',async()=>{const operations=[];const handler=createVideoHandler(runtime({user:async()=>({id:'asset'}),provider:()=>({create:async()=>({provider_id:id,upload_url:'https://upload.videodelivery.net/cap'})}),service:async data=>{operations.push(data.action);if(data.action==='claim')return {claimed:true};if(data.action==='created')return {technical_state:'provisioning_unknown'};if(data.action==='bind')throw new Error('write_failed');if(data.action==='binding')return {bound:false};return {queued:true};}}));assert.equal((await handler(request({action:'begin',...input()}))).status,500);assert.deepEqual(operations,['claim','created','bind','binding','orphan_enqueue']);});
test('withdrawal during token mint never returns a signed lease',async()=>{let calls=0;const handler=createVideoHandler(runtime({user:async()=>{if(++calls===3)throw new Error('withdrawn');return {id:'asset',provider_id:id,technical_state:'ready'};},provider:()=>({inspect:async()=>({state:'ready'}),playback:async()=>({hls:'private-signed-lease'})})}));const result=await handler(request({action:'playback',id:randomUUID()}));assert.equal(result.status,500);assert.ok(!(await result.text()).includes('private-signed-lease'));});
test('intentionally disabled public video list is empty without touching provider or secrets',async()=>{let calls=0;const handler=createVideoHandler(runtime({env:()=>undefined,provider:()=>{calls++;throw new Error('not configured');}}));const result=await handler(request({action:'public_list',parent_id:randomUUID()}));assert.equal(result.status,200);assert.deepEqual(await result.json(),{items:[],enabled:false});assert.equal(calls,0);});
