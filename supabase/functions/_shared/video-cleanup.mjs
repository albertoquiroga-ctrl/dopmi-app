import { drainVideoDeletionQueue } from './video-media.mjs';

// Separate from payment workers. No app token authorizes provider deletion.
export function createVideoCleanupHandler({ env, runtime }) {
  const reply = (value, status = 200) => new Response(JSON.stringify(value), {
    status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });
  return async (request) => {
    if (request.method !== 'POST') return reply({error: 'method_not_allowed'}, 405);
    const secret = env('DOPMI_VIDEO_WORKER_SECRET');
    const supplied = request.headers.get('authorization');
    if (!secret || secret.length < 32 || !supplied || supplied.length > 1024) return reply({error: 'access_denied'}, 401);
    const encoder = new TextEncoder();
    const [expected, actual] = await Promise.all([`Bearer ${secret}`, supplied].map(async value =>
      new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)))));
    let different = 0;
    for (let i = 0; i < expected.length; i++) different |= expected[i] ^ actual[i];
    if (different) return reply({error: 'access_denied'}, 401);
    if (env('DOPMI_VIDEO_CLEANUP_ENABLED') !== 'true') return reply({error: 'cleanup_disabled'}, 503);
    try {
      const result = await drainVideoDeletionQueue(runtime());
      return reply(result, result.failed > 0 ? 503 : 200);
    } catch { return reply({error: 'cleanup_unavailable'}, 503); }
  };
}
