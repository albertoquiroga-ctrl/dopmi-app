import { test } from 'node:test';
import assert from 'node:assert/strict';
import { socialCallback, socialHandler } from '../../supabase/functions/_shared/social-verification.mjs';
const env = (enabled = 'false', project = 'ohqxranynackjignryep') => key => ({
  SUPABASE_URL: `https://${project}.supabase.co`, SOCIAL_VERIFICATION_ENABLED: enabled,
  SOCIAL_FACEBOOK_CLIENT_ID: '123', SOCIAL_FACEBOOK_CLIENT_SECRET: 'private-test',
  SOCIAL_INSTAGRAM_CLIENT_ID: '456', SOCIAL_INSTAGRAM_CLIENT_SECRET: 'private-test',
  SOCIAL_VERIFICATION_CALLBACK_URL: `https://${project}.supabase.co/functions/v1/social-verification-callback`,
})[key];
const req = body => new Request('https://test', { method: 'POST', headers: { Authorization: 'Bearer verified' }, body: JSON.stringify(body) });
const actor = { id: 'server-owner', session_id: 'server-session' };

test('denial-only positive callback never exchanges a token or writes a proof, even with global flag enabled', async () => {
  const failures = []; let externalCalls = 0, proofs = 0;
  const response = await socialCallback({ env: env('true'),
    consume: async () => ({ id: 'attempt', provider: 'facebook', purpose: 'denial_only' }),
    fail: async (...args) => failures.push(args),
    fetcher: async () => { externalCalls++; return new Response(JSON.stringify({ access_token: 'x', id: '42', name: 'Synthetic' })); },
    finish: async () => { proofs++; },
  })(new Request('https://test?state=local-state&code=positive-code'));
  assert.equal(response.status, 400);
  assert.deepEqual(failures, [['attempt', 'failed']]);
  assert.equal(externalCalls, 0); assert.equal(proofs, 0);
});

test('DEV exception uses only the verified actor/session and exposes only Facebook without changing the flag', async () => {
  const calls = [];
  const runtime = { env: env(), authenticate: async () => actor, list: async () => [],
    denialAvailable: async (...args) => { calls.push(args); return true; },
    startDenial: async (...args) => { calls.push(args); return { id: 'one-attempt' }; },
    start: async () => assert.fail('normal start forbidden'),
  };
  const handler = socialHandler(runtime);
  assert.deepEqual(await (await handler(req({ operation: 'list', owner: 'attacker', user_metadata: { admin: true } }))).json(),
    { accounts: [], available_providers: ['facebook'] });
  const response = await handler(req({ operation: 'start', provider: 'facebook', owner: 'attacker', session_id: 'other', mode: 'admin' }));
  assert.equal(response.status, 200);
  const body = await response.json(); assert.equal(body.attempt_id, 'one-attempt');
  const url = new URL(body.authorization_url);
  assert.equal(url.hostname, 'www.facebook.com'); assert.equal(url.searchParams.has('client_secret'), false);
  assert.equal(url.searchParams.get('scope'), 'public_profile');
  assert.deepEqual(calls.slice(0, 2), [[actor.id, actor.session_id], [actor.id, actor.session_id]]);
  assert.deepEqual(calls[2].slice(0, 3), [actor.id, actor.session_id, 'facebook']);
  assert.match(calls[2][3], /^[0-9a-f]{64}$/);
});

test('absent, invalid, foreign-project or mismatched callback configuration stays closed without reading grants', async () => {
  for (const changed of [
    { SOCIAL_VERIFICATION_ENABLED: undefined }, { SOCIAL_VERIFICATION_ENABLED: 'TRUE' },
    { SUPABASE_URL: 'https://otherproject.supabase.co' },
    { SOCIAL_VERIFICATION_CALLBACK_URL: 'https://otherproject.supabase.co/functions/v1/social-verification-callback' },
    { SOCIAL_FACEBOOK_CLIENT_SECRET: undefined },
  ]) {
    const handler = socialHandler({ env: key => Object.hasOwn(changed, key) ? changed[key] : env()(key),
      authenticate: async () => actor, list: async () => [],
      denialAvailable: async () => assert.fail('closed config must not read permission'),
      startDenial: async () => assert.fail('must not create attempt'),
    });
    assert.deepEqual((await (await handler(req({ operation: 'list' }))).json()).available_providers, []);
    assert.equal((await handler(req({ operation: 'start', provider: 'facebook' }))).status, 503);
  }
});

test('other actors, missing session, failed permission reads and Instagram direct calls cannot start', async () => {
  for (const grant of [async () => false, async () => { throw new Error('unavailable'); }, async () => 'true']) {
    const handler = socialHandler({ env: env(), authenticate: async () => actor, list: async () => [], denialAvailable: grant,
      startDenial: async () => assert.fail('must remain unavailable') });
    assert.deepEqual((await (await handler(req({ operation: 'list' }))).json()).available_providers, []);
    assert.equal((await handler(req({ operation: 'start', provider: 'facebook' }))).status, 503);
    assert.equal((await handler(req({ operation: 'start', provider: 'instagram' }))).status, 503);
  }
  for (const authenticated of [null, { id: actor.id }]) {
    const handler = socialHandler({ env: env(), authenticate: async () => authenticated,
      denialAvailable: async () => assert.fail('must authenticate first') });
    assert.equal((await handler(req({ operation: 'start', provider: 'facebook', session_id: actor.session_id }))).status, 401);
  }
});

test('global normal operation never consults or consumes a denial grant', async () => {
  let starts = 0;
  const handler = socialHandler({ env: env('true', 'ordinaryproject'), authenticate: async () => actor, list: async () => [],
    denialAvailable: async () => assert.fail('normal flow must not consult exception'),
    startDenial: async () => assert.fail('normal flow must not consume exception'),
    start: async () => { starts++; return { id: 'ordinary' }; },
  });
  assert.deepEqual((await (await handler(req({ operation: 'list' }))).json()).available_providers, ['facebook', 'instagram']);
  for (const provider of ['facebook', 'instagram']) assert.equal((await handler(req({ operation: 'start', provider }))).status, 200);
  assert.equal(starts, 2);
});

test('consumed real-state denial returns existing feedback without provider or proof calls', async () => {
  let failure;
  const handler = socialCallback({ consume: async () => ({ id: 'denial', purpose: 'denial_only' }),
    fail: async (...args) => { failure = args; }, env: () => assert.fail('denial needs no token configuration'),
    fetcher: () => assert.fail('denial must not contact provider'), finish: () => assert.fail('denial must not finish'),
  });
  const response = await handler(new Request('https://test?state=local-state&error=access_denied&code=unexpected'));
  assert.equal(response.status, 200); assert.deepEqual(failure, ['denial', 'denied']);
  assert.match(await response.text(), /Vuelve a Dopmi/);
});

test('expired or replayed callback states cannot cause even a failed/denied mutation', async () => {
  const handler = socialCallback({ consume: async () => null,
    fail: () => assert.fail('invalid state must not write'), finish: () => assert.fail('no proof'), fetcher: () => assert.fail('no network') });
  for (const query of ['error=access_denied', 'code=positive'])
    assert.equal((await handler(new Request(`https://test?state=expired&${query}`))).status, 400);
});
