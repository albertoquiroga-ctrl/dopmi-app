import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from 'npm:jose@6.1.3';
import { AppleCredentialError, appleCredentialService, appleIdentityVerifier, appleTokenApi, credentialCipher } from './apple-credentials.mjs';

const jwks = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
export async function appleRuntime() {
  if (Deno.env.get('DOPMI_APPLE_CREDENTIALS_ENABLED') !== 'true') throw new AppleCredentialError('identity_not_configured');
  const clientId = Deno.env.get('APPLE_NATIVE_CLIENT_ID');
  const team = Deno.env.get('APPLE_TEAM_ID');
  const keyId = Deno.env.get('APPLE_KEY_ID');
  const signingKey = Deno.env.get('APPLE_PRIVATE_KEY');
  if (clientId !== 'com.mycompany.dopmi' || !team || !keyId || !signingKey) throw new AppleCredentialError('identity_not_configured');
  const key = await importPKCS8(signingKey.replaceAll('\\n', '\n'), 'ES256');
  const cipher = await credentialCipher(Deno.env.get('DOPMI_IDENTITY_ENCRYPTION_KEY'), Deno.env.get('DOPMI_IDENTITY_ENCRYPTION_KEY_ID'));
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {auth:{persistSession:false}});
  const rpc = async (operation: string, owner: string, data: Record<string, unknown> = {}) => {
    const result = await db.rpc('dopmi_apple_credential_server', {operation, owner, ...data});
    if (result.error) throw new AppleCredentialError('credential_unavailable');
    return result.data;
  };
  const hash = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))), b => b.toString(16).padStart(2,'0')).join('');
  const service = appleCredentialService({
    hash, cipher,
    api: appleTokenApi({clientId, clientSecret: () => new SignJWT({})
      .setProtectedHeader({alg:'ES256',kid:keyId}).setIssuer(team)
      .setAudience('https://appleid.apple.com').setSubject(clientId)
      .setIssuedAt().setExpirationTime('5m').sign(key)}),
    verifyToken: appleIdentityVerifier({jwtVerify, keys:jwks, audience:clientId}),
    store: {
      get: (owner: string) => rpc('get',owner),
      requireActive: (owner: string, subject: string) => rpc('require_active',owner,{apple_subject:subject}),
      save: (owner: string, row: {subject: string; request_hash: string; envelope: unknown}) => rpc('save',owner,{apple_subject:row.subject,request_hash:row.request_hash,envelope:row.envelope}),
      remove: (owner: string, requestHash: string) => rpc('remove',owner,{request_hash:requestHash}),
    },
  });
  return {
    service,
    async actor(token: string) {
      const {data,error} = await db.auth.getUser(token);
      const identity = data.user?.identities?.find(i => i.provider === 'apple');
      const subject = identity?.identity_data?.sub;
      if (error || !data.user || typeof subject !== 'string') throw new AppleCredentialError('apple_identity_required',403);
      return {id:data.user.id,appleSubject:subject};
    },
  };
}
