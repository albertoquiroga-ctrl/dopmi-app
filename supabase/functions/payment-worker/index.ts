import { failure, json, runtime } from '../_shared/runtime.ts';
Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  const secret = Deno.env.get('DOPMI_WORKER_SECRET');
  if (!secret || req.headers.get('Authorization') !== `Bearer ${secret}`) return json({ error: 'access_denied' }, 401);
  try { return json(await runtime().service.reconcile()); } catch (error) { return failure(error); }
});
