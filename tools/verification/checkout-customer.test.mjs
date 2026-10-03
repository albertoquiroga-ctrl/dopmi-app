import { test } from 'node:test';
import assert from 'node:assert/strict';
import { paymentService } from '../../supabase/functions/_shared/payments.mjs';
const actor='70000000-0000-4000-8000-000000000001';
const input={expense_id:'71000000-0000-4000-8000-000000000003',key:'72000000-0000-4000-8000-000000000001',gross_cents:10000,customer:'cus_foreign'};
function fixture(owner, customer={id:'cus_owned',livemode:false}) {
  const calls=[], sessions=new Map(); let sessionId;
  const createdAt=new Date().toISOString();
  const state={owner,loseProviderResponse:false,loseSaveResponse:false};
  const service=paymentService({returnUrl:'https://example.test/return',
    lookupCustomer:async id=>{assert.equal(id,actor);return state.owner;},
    rpc:async(operation,data)=>{
      if(operation==='prepare')return {id:'donation-one',payment_status:'pending',session_id:sessionId,created_at:createdAt,gross_cents:10000,expense_title:'Medicamento'};
      assert.equal(operation,'checkout_save');
      if(state.loseSaveResponse){state.loseSaveResponse=false;throw Error('lost database checkpoint');}
      sessionId=data.session_id;
    },
    stripe:async(path,body,key)=>{
      calls.push({path,body,key});
      if(path==='customers/cus_owned')return customer;
      if(path==='checkout/sessions'){
        if(sessions.has(key))assert.deepEqual(body,sessions.get(key).body,'provider rejects changed idempotent parameters');
        else sessions.set(key,{body:structuredClone(body),session:{id:'cs_one',url:'https://checkout.stripe.com/test'}});
        if(state.loseProviderResponse){state.loseProviderResponse=false;throw Error('lost processor response');}
        return structuredClone(sessions.get(key).session);
      }
      if(path==='checkout/sessions/cs_one')return {id:'cs_one',status:'open',payment_status:'unpaid',metadata:{dopmi_donation:'donation-one'},url:'https://checkout.stripe.com/test'};
      throw Error(path);
    }});
  return {service,calls,state,sessions};
}
test('punctual checkout uses only server-owned test customer and does not add saving consent',async()=>{
  const f=fixture({customer_id:'cus_owned'});await f.service.checkout(actor,input);
  const c=f.calls.find(c=>c.path==='checkout/sessions');
  assert.equal(c.body.customer,'cus_owned');assert.equal(c.key,'dopmi-checkout-donation-one');
  assert.equal(c.body['payment_intent_data[setup_future_usage]'],undefined);
  assert.equal(c.body['saved_payment_method_options[payment_method_save]'],undefined);
  await f.service.checkout(actor,input);
  assert.equal(f.calls.filter(c=>c.path==='checkout/sessions').length,1);
});
test('customerless payer remains customerless despite client-supplied customer',async()=>{
  const f=fixture(null);await f.service.checkout(actor,input);
  assert.equal(f.calls[0].body.customer,undefined);
});
for(const customer of [{id:'cus_other',livemode:false},{id:'cus_owned',deleted:true,livemode:false},{id:'cus_owned',livemode:true},{id:'cus_owned'}]) {
  test(`unsafe processor customer rejected ${JSON.stringify(customer)}`,async()=>{
    const f=fixture({customer_id:'cus_owned'},customer);
    await assert.rejects(f.service.checkout(actor,input),{code:'saved_card_customer_mismatch'});
    assert.equal(f.calls.some(c=>c.path==='checkout/sessions'),false);
  });
}
test('invalid private linkage is rejected before any processor request',async()=>{
  const f=fixture({customer_id:'invalid'});await assert.rejects(f.service.checkout(actor,input),{code:'saved_card_customer_mismatch'});assert.equal(f.calls.length,0);
});

for(const failure of ['loseProviderResponse','loseSaveResponse'])test(`checkout recovers ${failure} with the same provider request`,async()=>{
  const f=fixture({customer_id:'cus_owned'});f.state[failure]=true;
  await assert.rejects(f.service.checkout(actor,input),/lost/);
  const recovered=await f.service.checkout(actor,input);
  assert.equal(recovered.url,'https://checkout.stripe.com/test');
  assert.equal(f.sessions.size,1);
  const creates=f.calls.filter(c=>c.path==='checkout/sessions');
  assert.equal(creates.length,2);assert.deepEqual(creates[0],creates[1]);
  await f.service.checkout(actor,input);
  assert.equal(f.calls.filter(c=>c.path==='checkout/sessions').length,2);
});

test('changed customer binding after a lost response cannot create another checkout',async()=>{
  const f=fixture({customer_id:'cus_owned'});f.state.loseSaveResponse=true;
  await assert.rejects(f.service.checkout(actor,input),/lost database checkpoint/);
  f.state.owner=null;
  await assert.rejects(f.service.checkout(actor,input),/provider rejects changed idempotent parameters/);
  assert.equal(f.sessions.size,1);
  assert.equal(new Set(f.calls.filter(c=>c.path==='checkout/sessions').map(c=>c.key)).size,1);
  f.state.owner={customer_id:'cus_owned'};
  assert.equal((await f.service.checkout(actor,input)).url,'https://checkout.stripe.com/test');
  assert.equal(f.sessions.size,1);
});
