import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { guardianRuntime } from '../_shared/guardian-runtime.ts';
import { guardianClientEnabled, guardianClientHandler } from '../_shared/guardian-client.mjs';

Deno.serve(guardianClientHandler({
  enabled: () => guardianClientEnabled((name: string) => Deno.env.get(name)),
  authenticate: async (token: string) => {
    const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false } });
    const { data, error } = await db.auth.getUser(token);
    return error ? null : data.user;
  },
  checkout: (actor: string, input: unknown) => guardianRuntime().initial.checkout(actor, input),
}));
