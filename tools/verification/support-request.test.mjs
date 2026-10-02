import {test} from 'node:test';
import assert from 'node:assert/strict';
import {parseSupportRequest, supportRequestHandler, SupportRequestError} from '../../supabase/functions/_shared/support-request.mjs';
const id = '00000000-0000-4000-8000-000000000001';
const payload = {request_id:id, topic:'guardian', case_name:' Luna & Sol ', message:' Ayuda en México + información. '};
const request = body => new Request('https://example.test/support', {method:'POST', body:JSON.stringify(body)});
test('support preserves authored accents and rejects identity injection, unsupported topics and oversized text', () => {
  assert.equal(parseSupportRequest(payload).message, 'Ayuda en México + información.');
  assert.equal(parseSupportRequest(payload).case_name, 'Luna & Sol');
  for (const input of [null, [], {...payload,owner_id:id}, {...payload,topic:'shop'},
    {...payload,request_id:'random'}, {...payload,message:' '}, {...payload,message:'a'.repeat(4001)},
    {...payload,case_name:'a'.repeat(121)}, {...payload,message:'secret\u0000'}]) {
    assert.throws(() => parseSupportRequest(input), SupportRequestError);
  }
});
test('support acknowledges only a matching durable receipt and does not leak private failures', async () => {
  let called = 0;
  const handler = supportRequestHandler({authorize:async()=>id,receive:async(actor, data)=>{
    called++; assert.equal(actor,id); assert.equal(data.message,'Ayuda en México + información.');
    return {request_id:id,status:'received',internal_secret:'never returned'};
  }});
  const result = await handler(request(payload));
  assert.equal(result.status,200);
  assert.deepEqual(await result.json(),{request_id:id,status:'received'});
  assert.equal(called,1);
  for (const receipt of [null,{request_id:id,status:'pending'},{request_id:'other',status:'received'}]) {
    const response = await supportRequestHandler({authorize:async()=>id,receive:async()=>receipt})(request(payload));
    assert.equal(response.status,503);
  }
  const response = await supportRequestHandler({authorize:async()=>id,receive:async()=>{throw Error('PRIVATE MESSAGE');}})(request(payload));
  assert.deepEqual(await response.json(),{error:'support_unavailable'});
});
test('anonymous, malformed, oversized and non-POST requests never persist', async () => {
  let writes = 0;
  const receive=async()=>{writes++;};
  assert.equal((await supportRequestHandler({authorize:async()=>null,receive})(request(payload))).status,401);
  const handler = supportRequestHandler({authorize:async()=>id,receive});
  assert.equal((await handler(new Request('https://example.test',{method:'POST',body:'{'}))).status,400);
  assert.equal((await handler(request({...payload,message:'a'.repeat(18001)}))).status,413);
  assert.equal((await handler(new Request('https://example.test'))).status,405);
  assert.equal((await handler(new Request('https://example.test',{method:'OPTIONS'}))).status,204);
  assert.equal(writes,0);
});
