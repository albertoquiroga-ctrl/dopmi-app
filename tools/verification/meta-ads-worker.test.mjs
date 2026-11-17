import assert from 'node:assert/strict';
import test from 'node:test';
import { createMetaAdsWorkerHandler } from '../../supabase/functions/meta-ads-worker/handler.mjs';

const eventId = '9bf74037-a756-44f7-88b1-bdec26137a17';
const leaseToken = '9d26fac2-27e5-45fd-8f85-5e6ce3dfe009';
const advertisingId = '99516daa-b64d-44e1-a8d5-04a907a36425';
const workerSecret = 'synthetic-worker-secret-at-least-32-characters';
const metaAccessToken = 'synthetic-meta-access-token';
const datasetId = '123456789012345';
const event = {
  event_id: eventId,
  lease_token: leaseToken,
  event_name: 'Contact',
  event_time: 1794848400,
  advertising_id: advertisingId,
  os_version: '16',
  app_version: '2.3.5',
  app_build: 401,
};

function fixture({ settings = {}, rows = [event], allow = true, fetchImpl, rpcError, complete = true } = {}) {
  const effects = [];
  const meta = [];
  const env = {
    DOPMI_META_ADS_ENABLED: 'true',
    DOPMI_META_ADS_WORKER_SECRET: workerSecret,
    DOPMI_META_ADS_DATASET_ID: datasetId,
    DOPMI_META_ADS_ACCESS_TOKEN: metaAccessToken,
    ...settings,
  };
  const handler = createMetaAdsWorkerHandler({
    env: (name) => env[name],
    createDb: () => ({
      async rpc(name, input) {
        effects.push([name, input]);
        if (name === rpcError) return { error: { message: 'private backend failure' } };
        if (name === 'dopmi_claim_meta_ads_events') return { data: rows };
        if (name === 'dopmi_meta_ads_event_allowed') return { data: allow };
        return { data: complete };
      },
    }),
    now: () => Date.parse('2026-11-16T17:05:00Z'),
    fetchImpl: async (url, init) => {
      effects.push(['fetch']);
      meta.push({ url, init });
      return fetchImpl ? fetchImpl() : Response.json({ events_received: 1, fbtrace_id: 'private-trace' });
    },
  });
  const invoke = ({ method = 'POST', authorization = 'Bearer ' + workerSecret } = {}) =>
    handler(new Request('https://dopmi.example/functions/v1/meta-ads-worker', {
      method,
      headers: { authorization },
    }));
  return { invoke, effects, meta };
}

test('private worker requires POST and its independent scheduler secret before claiming', async () => {
  const { invoke, effects } = fixture();
  assert.equal((await invoke({ method: 'GET' })).status, 405);
  assert.equal((await invoke({ authorization: 'Bearer signed-user-token' })).status, 401);
  assert.equal((await invoke({ authorization: '' })).status, 401);
  assert.deepEqual(effects, []);
});

test('disabled or unconfigured dispatch leaves the outbox untouched', async () => {
  for (const settings of [
    { DOPMI_META_ADS_ENABLED: undefined },
    { DOPMI_META_ADS_DATASET_ID: 'not-a-dataset-id' },
    { DOPMI_META_ADS_ACCESS_TOKEN: undefined },
  ]) {
    const { invoke, effects } = fixture({ settings });
    assert.equal((await invoke()).status, 503);
    assert.deepEqual(effects, []);
  }
});

test('worker rechecks the active lease then sends the exact Android app event and settles it', async () => {
  const { invoke, effects, meta } = fixture();
  const response = await invoke();
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { delivered: 1, skipped: 0, failed: 0 });
  assert.deepEqual(effects, [
    ['dopmi_claim_meta_ads_events', { batch_size: 10 }],
    ['dopmi_meta_ads_event_allowed', { event_id: eventId, lease_token: leaseToken }],
    ['fetch'],
    ['dopmi_complete_meta_ads_event', { event_id: eventId, lease_token: leaseToken, delivered: true }],
  ]);
  assert.equal(String(meta[0].url), 'https://graph.facebook.com/v27.0/' + datasetId + '/events');
  assert.equal(meta[0].init.body.get('access_token'), metaAccessToken);
  assert.equal(meta[0].init.method, 'POST');
  assert.equal(meta[0].init.redirect, 'error');
  assert.deepEqual(JSON.parse(meta[0].init.body.get('data')), [
    {
      event_id: eventId,
      event_name: 'Contact',
      event_time: 1794848400,
      action_source: 'app',
      user_data: { madid: advertisingId },
      app_data: {
        advertiser_tracking_enabled: true,
        application_tracking_enabled: true,
        extinfo: ['a2', 'com.mycompany.dopmi', '401', '2.3.5', '16', '', '', '', '', '', '', '', '', '', '', ''],
      },
    },
  ]);
});

test('withdrawal or obsolete lease skips vendor dispatch', async () => {
  const { invoke, effects, meta } = fixture({ allow: false });
  const response = await invoke();
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { delivered: 0, skipped: 1, failed: 0 });
  assert.deepEqual(meta, []);
  assert.deepEqual(effects.at(-1), [
    'dopmi_complete_meta_ads_event', { event_id: eventId, lease_token: leaseToken, delivered: false },
  ]);
});

test('unknown event, zeroed ad ID and expired timestamp never reach Meta', async () => {
  const { invoke, meta } = fixture({
    rows: [
      { ...event, event_name: 'UnapprovedEvent' },
      { ...event, advertising_id: '00000000-0000-0000-0000-000000000000' },
      { ...event, event_time: 1793552400 },
    ],
  });
  const response = await invoke();
  assert.deepEqual(await response.json(), { delivered: 0, skipped: 3, failed: 0 });
  assert.deepEqual(meta, []);
});

test('unconfirmed Meta responses are retried with the same event identity and time', async () => {
  const { invoke, effects, meta } = fixture({
    rows: [{ ...event, event_name: 'SubmitApplication' }],
    fetchImpl: () => Response.json({ events_received: 0, messages: [advertisingId] }),
  });
  for (let attempt = 0; attempt < 2; attempt++) {
    const response = await invoke();
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { delivered: 0, skipped: 0, failed: 1 });
    assert.deepEqual(effects.at(-1), [
      'dopmi_complete_meta_ads_event', { event_id: eventId, lease_token: leaseToken, delivered: false },
    ]);
  }
  assert.equal(meta[0].init.body.get('data'), meta[1].init.body.get('data'));
  assert.equal(JSON.parse(meta[0].init.body.get('data'))[0].event_name, 'SubmitApplication');
});

test('a failed consent recheck cannot dispatch or leak internal errors', async () => {
  const { invoke, effects, meta } = fixture({ rpcError: 'dopmi_meta_ads_event_allowed' });
  const response = await invoke();
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { delivered: 0, skipped: 0, failed: 1 });
  assert.deepEqual(effects.at(-1), [
    'dopmi_complete_meta_ads_event', { event_id: eventId, lease_token: leaseToken, delivered: false },
  ]);
  assert.deepEqual(meta, []);
});

test('Meta ingestion without a current lease acknowledgment reports an unsettled delivery', async () => {
  const { invoke, meta } = fixture({ complete: false });
  const response = await invoke();
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { delivered: 0, skipped: 0, failed: 1 });
  assert.equal(meta.length, 1);
});

test('an HTTP rejection does not return provider response details', async () => {
  const { invoke, effects } = fixture({
    fetchImpl: () => Response.json({
      error: { message: 'private details ' + advertisingId },
    }, { status: 429 }),
  });
  const response = await invoke();
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { delivered: 0, skipped: 0, failed: 1 });
  assert.deepEqual(effects.at(-1), [
    'dopmi_complete_meta_ads_event', { event_id: eventId, lease_token: leaseToken, delivered: false },
  ]);
});
