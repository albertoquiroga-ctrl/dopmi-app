import { cors, failure, json, runtime } from '../_shared/runtime.ts';
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  try {
    const { service, actor } = runtime();
    const id = await actor(req);
    const input = await req.json();
    if (input.action === 'checkout') return json(await service.checkout(id, input));
    if (input.action === 'connect_status') return json(await service.connect(id, 'status'));
    if (input.action === 'connect_onboard') return json(await service.connect(id, 'onboard'));
    return json({ error: 'invalid_action' }, 400);
  } catch (error) { return failure(error); }
});
