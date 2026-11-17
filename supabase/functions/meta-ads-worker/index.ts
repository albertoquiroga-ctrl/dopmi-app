import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { createMetaAdsWorkerHandler } from './handler.mjs';

Deno.serve(createMetaAdsWorkerHandler({
  env: (name: string) => Deno.env.get(name),
  createDb: () => createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  ),
}));
