import { appleRuntime } from '../_shared/apple-runtime.ts';
import { AppleCredentialError } from '../_shared/apple-credentials.mjs';

const headers = {'Content-Type':'application/json','Cache-Control':'no-store',
  'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply = (value: unknown, status = 200) => new Response(JSON.stringify(value),{status,headers});
Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response(null,{headers});
  if (request.method !== 'POST') return reply({error:'method_not_allowed'},405);
  const token = request.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) return reply({error:'sign_in_required'},401);
  try {
    const runtime = await appleRuntime();
    const actor = await runtime.actor(token);
    const body = await request.text();
    if (body.length > 8192) return reply({error:'invalid_request'},400);
    let input; try {input=JSON.parse(body);} catch {return reply({error:'invalid_request'},400);}
    // Caller cannot select another owner, audience, endpoint or revocation action.
    if (!input || Object.keys(input).some(key=>!['code','nonce'].includes(key))) return reply({error:'invalid_request'},400);
    return reply(await runtime.service.register(actor,{code:input.code,nonce:input.nonce}));
  } catch (error) {
    return reply({error:error instanceof AppleCredentialError ? error.code : 'identity_unavailable'},
      error instanceof AppleCredentialError ? error.status : 503);
  }
});
