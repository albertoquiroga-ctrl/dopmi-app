import { createClient } from '@supabase/supabase-js';
import { afterEach, expect, test, vi } from 'vitest';
import { configuredApi, createAdminApi, type RescuerPublicProfile } from './api';
import type { AuthChangeEvent, Session } from '@supabase/supabase-js';

afterEach(() => { vi.unstubAllEnvs(); window.history.replaceState({}, '', '/'); });

function authWatcher() {
  let emit!: (event: AuthChangeEvent, session: Session | null) => void;
  const unsubscribe = vi.fn();
  const client = { auth: { onAuthStateChange: (callback: typeof emit) => {
    emit = callback; return { data: { subscription: { unsubscribe } } };
  } } } as unknown as Parameters<typeof createAdminApi>[0];
  const onChange = vi.fn();
  const stop = createAdminApi(client).watch(onChange);
  const session = { user: { id: 'reviewer-fixture' }, access_token: 'synthetic-session-one' } as Session;
  return { emit: (event: AuthChangeEvent, value: Session | null = session) => emit(event, value), session, onChange, stop, unsubscribe };
}

test('only an identical SIGNED_IN confirmation is redundant; missing credentials and a new token or actor recheck access', () => {
  const watcher = authWatcher();
  watcher.emit('INITIAL_SESSION');
  watcher.emit('SIGNED_IN');
  expect(watcher.onChange).toHaveBeenCalledTimes(1);
  watcher.emit('SIGNED_IN', { ...watcher.session, access_token: 'synthetic-session-two' });
  watcher.emit('SIGNED_IN', { ...watcher.session, user: { ...watcher.session.user, id: 'different-reviewer' } });
  watcher.emit('SIGNED_IN', null);
  expect(watcher.onChange).toHaveBeenCalledTimes(4);
  watcher.emit('SIGNED_IN', { ...watcher.session, access_token: '' });
  watcher.emit('SIGNED_IN');
  expect(watcher.onChange).toHaveBeenCalledTimes(6);
  watcher.stop();
  watcher.emit('SIGNED_IN');
  expect(watcher.onChange).toHaveBeenCalledTimes(6);
  expect(watcher.unsubscribe).toHaveBeenCalledTimes(1);
});

test.each<AuthChangeEvent>(['SIGNED_OUT', 'TOKEN_REFRESHED', 'USER_UPDATED', 'PASSWORD_RECOVERY'])('%s still rechecks access even with the same session data', event => {
  const watcher = authWatcher();
  watcher.emit('INITIAL_SESSION');
  watcher.emit(event, watcher.session);
  expect(watcher.onChange).toHaveBeenCalledTimes(2);
  if (event === 'SIGNED_OUT') {
    watcher.emit('SIGNED_IN');
    expect(watcher.onChange).toHaveBeenCalledTimes(3);
  }
  watcher.stop();
});

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
  expect(configure('test', `https://${testProject}.supabase.co`)?.loginWithGoogle).toBeUndefined();
  expect(configure('production', `https://${productionProject}.supabase.co`, anonKey(productionProject))?.environment).toBe('production');
  expect(configure('production', `https://${productionProject}.supabase.co`, anonKey(productionProject))?.loginWithGoogle).toBeTypeOf('function');
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

test('Google sign-in always returns to this origin root, never an input redirect', async () => {
  window.history.replaceState({}, '', '/?next=https://untrusted.example/path#users');
  const signInWithOAuth = vi.fn().mockResolvedValue({ data: {}, error: null });
  const api = createAdminApi({ auth: { signInWithOAuth } } as unknown as Parameters<typeof createAdminApi>[0], 'production');
  await api.loginWithGoogle!();
  expect(signInWithOAuth).toHaveBeenCalledWith({ provider: 'google', options: { redirectTo: `${window.location.origin}/` } });
});

test('Google initiation errors are safe application errors, not provider details', async () => {
  const signInWithOAuth = vi.fn().mockResolvedValue({ error: { message: 'provider_token=private-fixture', code: 'provider_disabled' } });
  const api = createAdminApi({ auth: { signInWithOAuth } } as unknown as Parameters<typeof createAdminApi>[0], 'production');
  await expect(api.loginWithGoogle!()).rejects.toMatchObject({ code: 'google_sign_in_failed', message: 'Google sign-in failed' });
});

test('TEST and default admin clients cannot initiate Google OAuth', () => {
  const signInWithOAuth = vi.fn();
  const client = { auth: { signInWithOAuth } } as unknown as Parameters<typeof createAdminApi>[0];
  expect(createAdminApi(client).loginWithGoogle).toBeUndefined();
  expect(createAdminApi(client, 'test').loginWithGoogle).toBeUndefined();
  expect(signInWithOAuth).not.toHaveBeenCalled();
});

test('real SDK PKCE callback exchanges once, clears the URL and still asks the server for membership', async () => {
  window.history.replaceState({}, '', '/?code=fixture-code&next=https://untrusted.example/#users');
  const storageValues = new Map([['admin-callback-fixture-code-verifier', JSON.stringify('fixture-verifier')]]);
  const storage = { getItem: (key: string) => storageValues.get(key) ?? null, setItem: (key: string, value: string) => { storageValues.set(key, value); }, removeItem: (key: string) => { storageValues.delete(key); } };
  const accessToken = `e30.${btoa(JSON.stringify({ sub: 'fixture-user', aud: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 }))}.fixture`;
  const fetcher = vi.fn(async (input: RequestInfo | URL) => {
    const url = String(input);
    if (url.includes('/auth/v1/token')) return new Response(JSON.stringify({ access_token: accessToken, refresh_token: 'fixture-refresh', expires_in: 3600, token_type: 'bearer', user: { id: 'fixture-user', aud: 'authenticated', created_at: '2026-10-29T00:00:00Z', app_metadata: { provider: 'google' }, user_metadata: { is_admin: true } } }), { headers: { 'Content-Type': 'application/json' } });
    if (url.includes('/rest/v1/rpc/dopmi_is_admin')) return new Response('false', { headers: { 'Content-Type': 'application/json' } });
    throw new Error('Unexpected test request');
  });
  const client = createClient('http://127.0.0.1:54321', 'test-key', { global: { fetch: fetcher }, auth: { flowType: 'pkce', storage, storageKey: 'admin-callback-fixture', autoRefreshToken: false, detectSessionInUrl: true } });
  const api = createAdminApi(client, 'production');
  expect(await api.session()).toBe(true);
  expect(await api.isAdmin()).toBe(false);
  const tokenCalls = fetcher.mock.calls.filter(([url]) => String(url).includes('/auth/v1/token'));
  expect(tokenCalls).toHaveLength(1);
  const [, request] = tokenCalls[0] as unknown as [string, RequestInit];
  expect(JSON.parse(request.body as string)).toMatchObject({ auth_code: 'fixture-code', code_verifier: 'fixture-verifier' });
  expect(fetcher.mock.calls.some(([url]) => String(url).includes('/rest/v1/rpc/dopmi_is_admin'))).toBe(true);
  expect(window.location.href).toBe(`${window.location.origin}/`);
});

test('failed OAuth callback clears secrets and remains retryable without accepting URL claims', async () => {
  window.history.replaceState({}, '', '/?error=access_denied&error_description=private-fixture#provider_token=private-fixture');
  const client = createClient('http://127.0.0.1:54321', 'test-key', { auth: { flowType: 'pkce', storageKey: 'admin-error-fixture', persistSession: false, autoRefreshToken: false } });
  const api = createAdminApi(client, 'production');
  await expect(api.session()).rejects.toMatchObject({ code: 'google_sign_in_failed' });
  expect(window.location.href).toBe(`${window.location.origin}/`);
  const passwordLogin = vi.spyOn(client.auth, 'signInWithPassword').mockRejectedValue({ code: 'invalid_credentials' });
  await expect(api.login('fixture@example.test', 'private-fixture')).rejects.toMatchObject({ code: 'invalid_credentials' });
  expect(passwordLogin).toHaveBeenCalledTimes(1);
  expect(await api.session()).toBe(false);
});
