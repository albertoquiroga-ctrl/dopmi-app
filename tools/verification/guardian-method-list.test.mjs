import test from 'node:test';
import assert from 'node:assert/strict';
import { guardianMethodListService } from '../../supabase/functions/_shared/guardian-method-list.mjs';
import { guardianClientHandler } from '../../supabase/functions/_shared/guardian-client.mjs';

function fixture() {
  const calls = [];
  const card = { id: 'pm_one', customer: 'cus_owner', livemode: false, type: 'card',
    card: { brand: 'visa', last4: '4242', exp_month: 12, exp_year: 2030,
      fingerprint: 'private', wallet: { type: 'google_pay', dynamic_last4: '1234' } },
    billing_details: { email: 'private@example.invalid' }, metadata: { private: true } };
  const state = { link: { customer_id: 'cus_owner', subscription_id: 'sub_owner' },
    customer: { id: 'cus_owner', livemode: false },
    sub: { id: 'sub_owner', customer: 'cus_owner', livemode: false, default_payment_method: 'pm_one' },
    pages: [{ data: [card], has_more: false }] };
  const read = guardianMethodListService({
    lookup: async actor => { calls.push(['lookup', actor]); return state.link; },
    stripe: {
      customers: { retrieve: async key => { calls.push(['customer', key]); return state.customer; } },
      subscriptions: { retrieve: async key => { calls.push(['subscription', key]); return state.sub; } },
      paymentMethods: { list: async params => { calls.push(['list', params]); return state.pages.shift(); } },
    },
  });
  return { read, state, calls, card };
}

test('only minimized owner card details leave the provider boundary', async () => {
  const f = fixture();
  assert.deepEqual(await f.read('authenticated-owner'), { items: [{ id: 'pm_one', brand: 'visa',
    last4: '4242', exp_month: 12, exp_year: 2030, wallet: 'google_pay', default: true }] });
  assert.deepEqual(f.calls[0], ['lookup', 'authenticated-owner']);
  assert.deepEqual(f.calls.at(-1)[1], { customer: 'cus_owner', type: 'card', limit: 100 });
});
test('no registry means no provider call and an empty list', async () => {
  const f = fixture(); f.state.link = null;
  assert.deepEqual(await f.read('owner'), { items: [] });
  assert.equal(f.calls.length, 1);
});
for (const [name, change] of [
  ['live customer', f => { f.state.customer.livemode = true; }],
  ['deleted customer', f => { f.state.customer.deleted = true; }],
  ['foreign subscription', f => { f.state.sub.customer = 'cus_peer'; }],
  ['live subscription', f => { f.state.sub.livemode = true; }],
  ['foreign card', f => { f.card.customer = 'cus_peer'; }],
  ['live card', f => { f.card.livemode = true; }],
  ['malformed card', f => { f.card.card.last4 = 'private-data'; }],
  ['broken pagination', f => { f.state.pages = [{ data: [], has_more: true }]; }],
]) test(`rejects ${name} instead of publishing false card state`, async () => {
  const f = fixture(); change(f);
  await assert.rejects(f.read('owner'), { code: 'guardian_methods_unavailable' });
});
test('pagination retains the complete inventory and uses server cursors', async () => {
  const f = fixture();
  f.state.pages = [{ data: [f.card], has_more: true },
    { data: [{ ...f.card, id: 'pm_two' }], has_more: false }];
  assert.equal((await f.read('owner')).items.length, 2);
  assert.equal(f.calls.at(-1)[1].starting_after, 'pm_one');
});

function request(body) {
  return new Request('https://fixture.invalid', { method: 'POST',
    headers: { Authorization: 'Bearer fixture', 'Content-Type': 'application/json' },
    body: JSON.stringify(body) });
}
test('list endpoint derives actor and rejects caller processor identities', async () => {
  const actors = [];
  const handler = guardianClientHandler({ enabled: () => true,
    authenticate: async () => ({ id: 'owner', email_confirmed_at: 'fixture' }),
    methods: async actor => { actors.push(actor); return { items: [] }; } });
  assert.equal((await handler(request({ action: 'methods', customer_id: 'cus_peer' }))).status, 400);
  assert.equal((await handler(request({ action: 'methods' }))).status, 200);
  assert.deepEqual(actors, ['owner']);
});
test('disabled and unconfirmed list requests never reach provider', async () => {
  let calls = 0;
  const deps = { enabled: () => false, authenticate: async () => ({ id: 'owner' }),
    methods: async () => { calls++; return { items: [] }; } };
  assert.equal((await guardianClientHandler(deps)(request({ action: 'methods' }))).status, 503);
  deps.enabled = () => true;
  assert.equal((await guardianClientHandler(deps)(request({ action: 'methods' }))).status, 401);
  assert.equal(calls, 0);
});


test('saved-default endpoint requires explicit consent and server-derived actor',async()=>{
  const calls=[];
  const handler=guardianClientHandler({enabled:()=>true,
    authenticate:async()=>({id:'owner',email_confirmed_at:'fixture'}),
    defaultMethod:async(actor,input)=>{calls.push({actor,input});return {status:'pending'};}});
  const body={action:'default_method',key:'77000000-0000-4000-8000-000000000001',revision:2,
    consent:true,consent_version:'guardian-2026-09-24',payment_method_id:'pm_selected'};
  for(const invalid of [{...body,consent:false},{...body,payment_method_id:'bad'},
    {...body,donor_id:'peer'},{...body,revision:-1}])
    assert.equal((await handler(request(invalid))).status,400);
  assert.equal(calls.length,0);
  assert.equal((await handler(request(body))).status,200);
  assert.deepEqual(calls,[{actor:'owner',input:{key:body.key,revision:2,consent:true,
    consent_version:body.consent_version,selected_method_id:'pm_selected',remove_saved:false}}]);
});


test('remove endpoint requires consent, opaque target and derives owner',async()=>{
  const calls=[];
  const handler=guardianClientHandler({enabled:()=>true,
    authenticate:async()=>({id:'owner',email_confirmed_at:'fixture'}),
    removeMethod:async(actor,input)=>{calls.push({actor,input});return {status:'pending'};}});
  const body={action:'remove_method',key:'77000000-0000-4000-8000-000000000001',revision:2,
    consent:true,consent_version:'guardian-2026-09-24',payment_method_id:'pm_selected'};
  for(const invalid of [{...body,consent:false},{...body,customer_id:'cus_peer'},
    {...body,payment_method_id:'bad'},{...body,remove_saved:false}])
    assert.equal((await handler(request(invalid))).status,400);
  assert.equal(calls.length,0);
  assert.equal((await handler(request(body))).status,200);
  assert.deepEqual(calls,[{actor:'owner',input:{key:body.key,revision:2,consent:true,
    consent_version:body.consent_version,selected_method_id:'pm_selected',remove_saved:true}}]);
});


test('saved cards without subscription require only confirmed customer and return its actual default',async()=>{
  const f=fixture();f.state.link.subscription_id=null;
  f.state.customer.invoice_settings={default_payment_method:'pm_one'};
  assert.equal((await f.read('owner')).items[0].default,true);
  assert.equal(f.calls.some(c=>c[0]==='subscription'),false);
});

test('independent add-card endpoint allows explicit saving consent only and derives its owner',async()=>{
  const calls=[];
  const handler=guardianClientHandler({enabled:()=>true,
    authenticate:async()=>({id:'owner',email_confirmed_at:'fixture'}),
    addCard:async(actor,input)=>{calls.push({actor,input});return{status:'pending'};}});
  const body={action:'add_card',key:'77000000-0000-4000-8000-000000000001',consent:true,consent_version:'saved-cards-2026-10-03'};
  for(const patch of [{consent:false},{consent_version:'guardian-2026-09-24'},{key:'bad'},
    {customer_id:'cus_peer'},{owner_id:'peer'},{return_url:'https://evil.test'},{revision:1}])
    assert.equal((await handler(request({...body,...patch}))).status,400);
  assert.equal(calls.length,0);
  assert.equal((await handler(request(body))).status,200);
  assert.deepEqual(calls,[{actor:'owner',input:{key:body.key,consent:true,consent_version:body.consent_version}}]);
});
