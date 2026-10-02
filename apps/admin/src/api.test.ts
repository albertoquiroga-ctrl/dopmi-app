import { createClient } from '@supabase/supabase-js';
import { expect, test, vi } from 'vitest';
import { createAdminApi, type RescuerPublicProfile } from './api';

test('profile moderation sends the actual PostgREST owner parameter and version', async () => {
  const fetcher = vi.fn(async () => new Response(JSON.stringify({ owner_id: 'owner', version: 5 }), { headers: { 'Content-Type': 'application/json' } }));
  const client = createClient('http://127.0.0.1:54321', 'test-key', { global: { fetch: fetcher }, auth: { persistSession: false, autoRefreshToken: false } });
  const api = createAdminApi(client);
  await api.reviewRescuerProfile!({ owner_id: 'owner', version: 4 } as RescuerPublicProfile, 'published', 'Revisado');
  expect(fetcher).toHaveBeenCalledTimes(1);
  const [url, request] = fetcher.mock.calls[0] as unknown as [string, RequestInit];
  expect(String(url)).toContain('/rest/v1/rpc/dopmi_review_rescuer_profile');
  expect(JSON.parse(request.body as string)).toEqual({ profile_owner: 'owner', expected_version: 4, decision: 'published', feedback: 'Revisado' });
});
