import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createVideoCleanupHandler} from '../../supabase/functions/_shared/video-cleanup.mjs';
import {streamProvider} from '../../supabase/functions/_shared/video-media.mjs';
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

test('fresh cleanup invocations reconcile ambiguous deletion and acknowledgement outcomes',async t=>{
 for(const failure of ['provider-lost-response','mark-before-commit','mark-after-commit'])await t.test(failure,async()=>{
  const providerId='b'.repeat(32),queue=new Set([providerId]),deletedIds=[],acknowledgedIds=[];
  let providerPresent=true,firstDelete=true,firstAcknowledgement=true;
  // The service double models the durable outbox contract covered by the SQL suite.
  // Recreate the handler and real Stream adapter on every invocation: no retry state
  // may depend on the previous worker instance surviving.
  const invoke=()=>createVideoCleanupHandler({
   env:name=>name==='DOPMI_VIDEO_WORKER_SECRET'?secret:name==='DOPMI_VIDEO_CLEANUP_ENABLED'?'true':undefined,
   runtime:()=>({
    provider:()=>streamProvider({accountId:'a'.repeat(32),apiToken:'synthetic-only',fetcher:async(url,init)=>{
     assert.equal(init.method,'DELETE');assert.equal(new URL(url).pathname.split('/').at(-1),providerId);
     deletedIds.push(providerId);
     const wasPresent=providerPresent;providerPresent=false;
     if(firstDelete&&failure==='provider-lost-response'){
      firstDelete=false;throw new Error('private-provider-lost-response');
     }
     firstDelete=false;return new Response(null,{status:wasPresent?200:404});
    }}),
    service:async data=>{
     if(data.action==='cleanup_list')return {items:[...queue]};
     assert.deepEqual(data,{action:'cleanup_done',provider_id:providerId});
     acknowledgedIds.push(data.provider_id);
     if(firstAcknowledgement&&failure==='mark-before-commit'){
      firstAcknowledgement=false;throw new Error('private-database-unavailable');
     }
     queue.delete(data.provider_id);
     if(firstAcknowledgement&&failure==='mark-after-commit'){
      firstAcknowledgement=false;throw new Error('private-acknowledgement-lost-response');
     }
     firstAcknowledgement=false;return {ok:true};
    },
   }),
  })(new Request('https://example.test/cleanup',{method:'POST',headers:{authorization:`Bearer ${secret}`}}));

  const first=await invoke();assert.equal(first.status,503);
  assert.deepEqual(await first.json(),{removed:0,failed:1});
  assert.equal(providerPresent,false);
  assert.equal(queue.has(providerId),failure!=='mark-after-commit');
  if(failure==='provider-lost-response')assert.deepEqual(acknowledgedIds,[]);

  const retried=await invoke();assert.equal(retried.status,200);
  assert.deepEqual(await retried.json(),{removed:failure==='mark-after-commit'?0:1,failed:0});
  assert.equal(queue.size,0);
  assert.deepEqual(deletedIds,failure==='mark-after-commit'?[providerId]:[providerId,providerId]);

  const drained=await invoke();assert.equal(drained.status,200);
  assert.deepEqual(await drained.json(),{removed:0,failed:0});
  assert.equal(deletedIds.length,failure==='mark-after-commit'?1:2);
  assert.deepEqual(acknowledgedIds,failure==='mark-before-commit'?[providerId,providerId]:[providerId]);
 });
});
