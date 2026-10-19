import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createVideoCleanupHandler} from '../../supabase/functions/_shared/video-cleanup.mjs';
const secret='separate-video-worker-secret-32-characters';
function setup({enabled=true,remove=async()=>{}}={}) {
 let constructed=0; const marked=[];
 const handler=createVideoCleanupHandler({env:name=>name==='DOPMI_VIDEO_WORKER_SECRET'?secret:name==='DOPMI_VIDEO_CLEANUP_ENABLED'?String(enabled):undefined,runtime:()=>{
  constructed++;return {provider:()=>({remove}),service:async data=>data.action==='cleanup_list'?{items:['provider-only-id']}:marked.push(data)};
 }});
 const call=(token=secret,method='POST')=>handler(new Request('https://example.test/cleanup',{method,headers:{authorization:`Bearer ${token}`}}));
 return {call,marked,constructed:()=>constructed};
}
test('cleanup rejects app credentials and GET before constructing privileged runtime',async()=>{
 const state=setup();assert.equal((await state.call('app-token')).status,401);assert.equal((await state.call(secret,'GET')).status,405);assert.equal(state.constructed(),0);
});
test('cleanup independent operational flag defaults closed',async()=>{
 const state=setup({enabled:false});assert.equal((await state.call()).status,503);assert.equal(state.constructed(),0);
});
test('cleanup only drains durable IDs and returns counters, never IDs',async()=>{
 const state=setup();const result=await state.call();assert.equal(result.status,200);assert.deepEqual(await result.json(),{removed:1,failed:0});assert.deepEqual(state.marked,[{action:'cleanup_done',provider_id:'provider-only-id'}]);
});
test('provider failure retains outbox item for retry and returns operational failure',async()=>{
 const state=setup({remove:async()=>{throw new Error('private-provider-detail');}});const result=await state.call();assert.equal(result.status,503);assert.deepEqual(await result.json(),{removed:0,failed:1});assert.deepEqual(state.marked,[]);
});
