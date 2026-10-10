import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.57.4';
import { appleRuntime } from '../_shared/apple-runtime.ts';

const headers = {
  'Content-Type': 'application/json',
  'Cache-Control': 'no-store',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status, headers });

const removableBuckets = [
  'avatars',
  'dopmi-adoption-photos',
  'dopmi-case-update-media',
  'dopmi-rescuer-profile-media',
  'dopmi-account-profile-media',
  'dopmi-support-media',
] as const;

async function removePrivateMedia(
  db: SupabaseClient,
  owner: string,
) {
  for (const bucket of removableBuckets) {
    const paths: string[] = [];
    const visit = async (prefix: string, depth: number) => {
      if (depth > 3) throw new Error('storage_depth_exceeded');
      for (let offset = 0; offset < 1000; offset += 100) {
        const listed = await db.storage.from(bucket).list(prefix, {
          limit: 100,
          offset,
          sortBy: { column: 'name', order: 'asc' },
        });
        if (listed.error) throw listed.error;
        for (const item of listed.data ?? []) {
          const path = prefix ? `${prefix}/${item.name}` : item.name;
          if (item.id == null) await visit(path, depth + 1);
          else paths.push(path);
        }
        if ((listed.data?.length ?? 0) < 100) break;
      }
    };
    await visit(owner, 0);
    for (let offset = 0; offset < paths.length; offset += 100) {
      const removed = await db.storage.from(bucket).remove(
        paths.slice(offset, offset + 100),
      );
      if (removed.error) throw removed.error;
    }
  }
}

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405);
  const token = request.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) return reply({ error: 'sign_in_required' }, 401);

  const url = Deno.env.get('SUPABASE_URL')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const db = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: authData, error: authError } = await db.auth.getUser(token);
  const user = authData.user;
  if (authError || !user) return reply({ error: 'sign_in_required' }, 401);

  let input: { request_key?: string; confirmation?: string };
  try {
    const raw = await request.text();
    if (raw.length > 1024) return reply({ error: 'invalid_request' }, 400);
    input = JSON.parse(raw);
  } catch {
    return reply({ error: 'invalid_request' }, 400);
  }
  if (input.confirmation !== 'ELIMINAR' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(input.request_key ?? '')) {
    return reply({ error: 'confirmation_required' }, 400);
  }
  const signedIn = Date.parse(user.last_sign_in_at ?? '');
  if (!Number.isFinite(signedIn) || Date.now() - signedIn > 15 * 60 * 1000) {
    return reply({ error: 'recent_sign_in_required' }, 403);
  }

  const call = async (operation: string, extra: Record<string, unknown> = {}) => {
    const result = await db.rpc('dopmi_account_deletion_server', {
      operation,
      data: { owner_id: user.id, ...extra },
    });
    if (result.error) throw result.error;
    return result.data;
  };

  const removeAuthAccess = async (state: Record<string, unknown>) => {
    // A previous attempt may have completed the database work but failed while
    // removing Auth. Retry that cleanup instead of treating the durable status
    // as proof that every session and identity has already been removed.
    await db.auth.admin.signOut(token, 'global');
    const removed = await db.auth.admin.deleteUser(user.id, false);
    if (removed.error && !/not found/i.test(removed.error.message)) {
      return reply({ ...state, auth_cleanup: 'pending' }, 202);
    }
    return reply(state);
  };

  try {
    let state = await call('request', { request_key: input.request_key });
    if (state?.status === 'completado') return await removeAuthAccess(state);

    const credential = await db.rpc('dopmi_apple_credential_server', {
      operation: 'get', owner: user.id, apple_subject: null,
      request_hash: null, envelope: null,
    });
    if (credential.error) throw credential.error;
    if (credential.data) {
      try {
        const runtime = await appleRuntime();
        await runtime.service.revoke(user.id);
      } catch {
        state = await call('attention', { attention_code: 'revocacion_apple_pendiente' });
        return reply(state, 409);
      }
    }

    // Public presentation media and private drafts are dispensable. Rescue
    // evidence is intentionally excluded because it may substantiate payments.
    await removePrivateMedia(db, user.id);
    state = await call('finalize');
    if (state?.status !== 'completado') return reply(state, 409);

    // Database authorization is already blocked. Global revocation closes all
    // refresh sessions before Auth is removed; the operation remains safe to retry.
    return await removeAuthAccess(state);
  } catch {
    try { await call('attention', { attention_code: 'procesamiento_incompleto' }); } catch { /* keep original failure */ }
    return reply({ error: 'deletion_unavailable' }, 503);
  }
});
