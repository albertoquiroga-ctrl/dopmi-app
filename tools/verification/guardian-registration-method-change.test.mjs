import { test } from 'node:test';
import assert from 'node:assert/strict';
import { guardianRegistrationMethodChange } from '../../supabase/functions/_shared/guardian-registration-method-change.mjs';
const input = { id: 'registration', key: 'stable-key', revision: 2,
  consent: true, consent_version: 'saved-cards-2026-10-03' };
function fixture() {
  const calls = [];
  const job = { id: 'change-job', registration_id: input.id, owner_id: 'owner',
    request_key: input.key, registration_revision: 2, status: 'pending', customer_id: 'private' };
  let ready = false, lost = false;
  return { calls, job, confirm: () => { ready = true; }, lose: () => { lost = true; },
    service: guardianRegistrationMethodChange({
      rpc: async (op, data) => { calls.push({ op, data });
        if (op === 'reconcile' && ready && job.status === 'pending') job.status = 'applied';
        return { ...job }; },
      savedNativeCard: {
        submit: async (actor, data) => { calls.push({ op: 'setup', actor, data });
          if (lost) { lost = false; throw Error('lost response'); } },
        status: async () => ({ method_status: ready ? 'saved' : 'requires_payment_method', setup_client_secret: 'ephemeral' }),
      },
    }) };
}
test('method change requires consent before storage or setup', async () => {
  const f = fixture();
  await assert.rejects(f.service.submit('owner', { ...input, consent: false }), /consent_required/);
  assert.equal(f.calls.length, 0);
});
test('lost response recovers the same setup; successful observation has no secret or private IDs', async () => {
  const f = fixture(); f.lose();
  await assert.rejects(f.service.submit('owner', input), /lost response/);
  assert.equal((await f.service.submit('owner', input)).status, 'pending');
  assert.deepEqual(f.calls.filter(c => c.op === 'setup').map(c => c.data.key), ['change-job', 'change-job']);
  f.confirm(); const result = await f.service.status('owner', input);
  assert.equal(result.status, 'applied'); assert.equal(result.setup_client_secret, null);
  assert.equal(Object.hasOwn(result, 'customer_id'), false);
});
test('cancellation wins and cannot be presented as saved', async () => {
  const f = fixture(); f.job.status = 'canceled'; f.confirm();
  assert.equal((await f.service.submit('owner', input)).status, 'canceled');
  assert.equal(f.calls.some(c => c.op === 'setup'), false);
});

test('method endpoint filters ownership, job IDs, secret fields, consent and stale malformed revision', async () => {
 const { guardianClientHandler } = await import('../../supabase/functions/_shared/guardian-client.mjs');
 const calls=[]; const handler=guardianClientHandler({enabled:()=>true,
 authenticate:async()=>({id:'owner',email_confirmed_at:'today'}),
 registrationMethod:async(actor,input)=>{calls.push({actor,input});return {status:'pending'};}});
 const body={action:'registration_method',id:'98000000-0000-4000-8000-000000000001',
 key:'98000000-0000-4000-8000-000000000002',revision:1,consent:true,consent_version:'saved-cards-2026-10-03'};
 const request=body=>handler(new Request('https://example.test',{method:'POST',headers:{Authorization:'Bearer synthetic'},body:JSON.stringify(body)}));
 for(const delta of [{owner_id:'other'},{method_job_id:body.id},{payment_method_id:'pm_injected'},{setup_client_secret:'injected'},
 {revision:-1},{consent:false},{consent_version:'old'}]) assert.equal((await request({...body,...delta})).status,400);
 assert.equal(calls.length,0);assert.equal((await request(body)).status,200);assert.equal(calls[0].actor,'owner');
 assert.equal((await request({action:'registration_method_status',id:body.id,key:body.key})).status,200);
 assert.equal((await request({action:'registration_method_status',id:body.id,key:body.key,consent:true})).status,400);
});
