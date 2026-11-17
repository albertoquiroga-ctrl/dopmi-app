const graphVersion = 'v27.0';
const packageName = 'com.mycompany.dopmi';
const eventNames = new Set(['Contact', 'SubmitApplication']);
const uuid = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const zeroUuid = '00000000-0000-0000-0000-000000000000';
const sevenDaysInSeconds = 7 * 24 * 60 * 60;

function reply(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });
}

async function authorized(request, secret) {
  const supplied = request.headers.get('authorization');
  if (!secret || secret.length < 32 || !supplied || supplied.length > 1024) return false;
  const encoder = new TextEncoder();
  const [expected, actual] = await Promise.all(
    ['Bearer ' + secret, supplied].map(async (value) =>
      new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)))),
  );
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= expected[i] ^ actual[i];
  return difference === 0;
}

function eventPayload(row, now) {
  const eventTime = row.event_time;
  const nowInSeconds = Math.floor(now / 1000);
  const appBuild = Number(row.app_build);
  const isVersion = (value) => typeof value === 'string' && /^[a-z0-9][a-z0-9.+_-]{0,23}$/i.test(value);
  if (!eventNames.has(row.event_name) ||
      !uuid.test(row.advertising_id) || row.advertising_id === zeroUuid ||
      !Number.isSafeInteger(eventTime) || eventTime > nowInSeconds ||
      nowInSeconds - eventTime >= sevenDaysInSeconds ||
      !isVersion(row.os_version) || !isVersion(row.app_version) ||
      !Number.isInteger(appBuild) || appBuild <= 0 || appBuild > 2_100_000_000) {
    return null;
  }

  return {
    event_id: row.event_id,
    event_name: row.event_name,
    event_time: eventTime,
    action_source: 'app',
    user_data: { madid: row.advertising_id },
    app_data: {
      advertiser_tracking_enabled: true,
      application_tracking_enabled: true,
      extinfo: [
        'a2', packageName, String(appBuild), row.app_version, row.os_version,
        // Meta's remaining eleven device fields are positions, so keep placeholders.
        '', '', '', '', '', '', '', '', '', '', '',
      ],
    },
  };
}

async function rpc(db, name, params) {
  const { data, error } = await db.rpc(name, params);
  if (error) throw new Error('meta_ads_database_unavailable');
  return data;
}

async function deliver(fetchImpl, url, token, event) {
  // Meta accepts the token as a POST form field. Do not put the secret in a URL.
  const body = new FormData();
  body.set('access_token', token);
  body.set('data', JSON.stringify([event]));
  const response = await fetchImpl(url, {
    method: 'POST',
    body,
    redirect: 'error',
    signal: AbortSignal.timeout(5_000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    return false;
  }
  const result = await response.json();
  return result?.events_received === 1 && !result.error;
}

export function createMetaAdsWorkerHandler({ env, createDb, fetchImpl = fetch, now = Date.now }) {
  return async (request) => {
    if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405);
    if (!await authorized(request, env('DOPMI_META_ADS_WORKER_SECRET'))) {
      return reply({ error: 'access_denied' }, 401);
    }
    if (env('DOPMI_META_ADS_ENABLED') !== 'true') return reply({ error: 'meta_ads_disabled' }, 503);
    const datasetId = env('DOPMI_META_ADS_DATASET_ID');
    const token = env('DOPMI_META_ADS_ACCESS_TOKEN');
    if (!/^[1-9][0-9]{0,31}$/.test(datasetId ?? '') || !token?.trim()) {
      return reply({ error: 'meta_ads_unconfigured' }, 503);
    }
    const url = 'https://graph.facebook.com/' + graphVersion + '/' + datasetId + '/events';

    try {
      const db = createDb();
      const rows = await rpc(db, 'dopmi_claim_meta_ads_events', { batch_size: 10 });
      if (!Array.isArray(rows)) return reply({ error: 'meta_ads_unavailable' }, 503);
      const result = { delivered: 0, skipped: 0, failed: 0 };
      for (const row of rows) {
        if (!uuid.test(row?.event_id) || !uuid.test(row?.lease_token)) {
          result.failed++;
          continue;
        }
        const lease = { event_id: row.event_id, lease_token: row.lease_token };
        const event = eventPayload(row, now());
        let state = 'skipped';
        try {
          if (event && await rpc(db, 'dopmi_meta_ads_event_allowed', lease) === true) {
            state = await deliver(fetchImpl, url, token, event) ? 'delivered' : 'failed';
          }
        } catch {
          state = 'failed';
        }
        try {
          const delivered = state === 'delivered';
          const settled = await rpc(db, 'dopmi_complete_meta_ads_event', { ...lease, delivered });
          if (delivered && settled !== true) state = 'failed';
        } catch {
          state = 'failed';
        }
        result[state]++;
      }
      return reply(result, result.failed > 0 ? 503 : 200);
    } catch {
      return reply({ error: 'meta_ads_unavailable' }, 503);
    }
  };
}
