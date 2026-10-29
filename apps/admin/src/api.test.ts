import { createClient } from '@supabase/supabase-js';
import { afterEach, expect, test, vi } from 'vitest';
import { configuredApi, createAdminApi, type RescuerPublicProfile } from './api';

afterEach(() => vi.unstubAllEnvs());

const testProject = 'ohqxranynackjignryep';
const productionProject = 'ysaoeuidcvgtlmphmeyb';
const anonKey = (ref: string | null, role = 'anon') => `e30.${btoa(JSON.stringify({ role, ...(ref === null ? {} : { ref }) })).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')}.fixture`;
function configure(environment: string | undefined, url: string, key = 'sb_publishable_fixture') {
  vi.stubEnv('VITE_DOPMI_ENVIRONMENT', environment);
  vi.stubEnv('VITE_SUPABASE_URL', url);
  vi.stubEnv('VITE_SUPABASE_PUBLISHABLE_KEY', key);
  return configuredApi();
}

test('configuration defaults to TEST and requires explicit production with its registered host', () => {
  expect(configure(undefined, `https://${testProject}.supabase.co`)?.environment).toBe('test');
  expect(configure('production', `https://${productionProject}.supabase.co`, anonKey(productionProject))?.environment).toBe('production');
  expect(createAdminApi({} as Parameters<typeof createAdminApi>[0]).environment).toBe('test');
});

test('crossed, unknown or credential-bearing endpoints cannot configure an admin client', () => {
  for (const [environment, url] of [
    [undefined, `https://${productionProject}.supabase.co`],
    ['test', `https://${productionProject}.supabase.co`],
    ['production', `https://${testProject}.supabase.co`],
    ['production', 'http://localhost:54321'],
    ['staging', `https://${productionProject}.supabase.co`],
    ['production', 'https://another-project.supabase.co'],
    ['test', 'https://example.test'],
    ['production', `http://${productionProject}.supabase.co`],
    ['production', `https://user@${productionProject}.supabase.co`],
    ['production', `https://${productionProject}.supabase.co?mode=test`],
    ['production', `https://${productionProject}.supabase.co/path`],
  ]) expect(configure(environment, url!)).toBeNull();
});

test('only public credentials with the selected JWT project can configure either remote environment', () => {
  for (const [environment, project, other] of [['test', testProject, productionProject], ['production', productionProject, testProject]]) {
    const url = `https://${project}.supabase.co`;
    expect(configure(environment, url, anonKey(project))?.environment).toBe(environment);
    for (const key of [anonKey(other), anonKey(null), anonKey(project, 'service_role'), 'sb_secret_fixture', 'sk_live_fixture', 'rk_test_fixture', 'pk_live_fixture', 'not-a-client-key']) {
      expect(configure(environment, url, key)).toBeNull();
    }
  }
});

test('local Supabase acceptance is TEST only and accepts its legacy ref-less anon credential', () => {
  expect(configure('test', 'http://127.0.0.1:54321', anonKey(null))?.environment).toBe('test');
  expect(configure('test', 'http://localhost:54321', 'sb_publishable_localfixture')?.environment).toBe('test');
  expect(configure('production', 'http://127.0.0.1:54321', anonKey(null))).toBeNull();
  expect(configure('test', 'http://localhost:54321', anonKey(productionProject))).toBeNull();
});

test('profile moderation sends the actual PostgREST owner parameter and version', async () => {
  const fetcher = vi.fn(async () => new Response(JSON.stringify({ owner_id: 'owner', version: 5 }), { headers: { 'Content-Type': 'application/json' } }));
  const client = createClient('http://127.0.0.1:54321', 'test-key', { global: { fetch: fetcher }, auth: { persistSession: false, autoRefreshToken: false } });
  const api = createAdminApi(client);
  await api.reviewRescuerProfile!({ owner_id: 'owner', version: 4 } as RescuerPublicProfile, 'published', 'Revisado');
  expect(fetcher).toHaveBeenCalledTimes(1);
  const [url, request] = fetcher.mock.calls[0] as unknown as [string, RequestInit];
  expect(String(url)).toContain('/rest/v1/rpc/dopmi_review_rescuer_profile_v2');
  expect(JSON.parse(request.body as string)).toEqual({ profile_owner: 'owner', expected_version: 4, decision: 'published', feedback: 'Revisado', field_feedback: {} });
});


test('profile v2 review preserves dedicated contact field feedback without copying private identity', async () => {
  const rpc = vi.fn().mockResolvedValue({ data: { owner_id: 'owner' }, error: null });
  const api = createAdminApi({ rpc } as unknown as Parameters<typeof createAdminApi>[0]);
  await api.reviewRescuerProfile!({ owner_id: 'owner', version: 8, public_email: 'public@example.test', contact_consent: false } as RescuerPublicProfile, 'changes_requested', 'Revisa el contacto', { public_phone: 'Confirma por SMS', contact_consent: 'Elige si deseas publicar' });
  expect(rpc).toHaveBeenCalledWith('dopmi_review_rescuer_profile_v2', { profile_owner: 'owner', expected_version: 8, decision: 'changes_requested', feedback: 'Revisa el contacto', field_feedback: { public_phone: 'Confirma por SMS', contact_consent: 'Elige si deseas publicar' } });
});


test('profile field feedback checks PostgreSQL aggregate escaped JSON size before RPC', async () => {
  const rpc = vi.fn().mockResolvedValue({ data: {}, error: null });
  const api = createAdminApi({ rpc } as unknown as Parameters<typeof createAdminApi>[0]);
  const profile = { owner_id: 'owner', version: 1 } as RescuerPublicProfile;
  const fields = { display_name: 'x'.repeat(500), bio: 'x'.repeat(500), city: 'x'.repeat(500), region: 'x'.repeat(500), instagram_url: 'x'.repeat(500), facebook_url: 'x'.repeat(500), avatar_path: 'x'.repeat(500), public_email: 'x'.repeat(500), public_phone: 'x'.repeat(500), public_address: 'x'.repeat(500) };
  await expect(api.reviewRescuerProfile!(profile, 'changes_requested', 'Revisa', fields)).rejects.toThrow('5000');
  expect(rpc).not.toHaveBeenCalled();
  const escaped = Object.fromEntries(Object.keys(fields).slice(0, 5).map(key => [key, '"'.repeat(500)]));
  await expect(api.reviewRescuerProfile!(profile, 'changes_requested', 'Revisa', escaped)).rejects.toThrow('5000');
  expect(rpc).not.toHaveBeenCalled();
  await api.reviewRescuerProfile!(profile, 'changes_requested', 'Revisa', { bio: '"'.repeat(500) });
  expect(rpc).toHaveBeenCalledTimes(1);
});
