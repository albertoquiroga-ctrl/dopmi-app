import type { SupabaseClient } from '@supabase/supabase-js';
import { afterEach, expect, test, vi } from 'vitest';
import { AdminPushKeyChanged, adminPushEnabled, createAdminPushApi, disableAdminPush, enableAdminPush, revokeAdminPushOnLogout, type AdminPushApi } from './adminPush';

const firstSession = '10000000-0000-4000-8000-000000000001';
const otherSession = '10000000-0000-4000-8000-000000000002';

afterEach(() => vi.unstubAllGlobals());

function browserFixture({ existing = false, permission = 'granted', rotated = false }: { existing?: boolean; permission?: NotificationPermission; rotated?: boolean } = {}) {
  const publicKey = new Uint8Array(65);
  publicKey[0] = 4;
  const subscriptionKey = publicKey.slice();
  if (rotated) subscriptionKey[1] = 1;
  const subscription = {
    endpoint: 'https://fcm.googleapis.com/fcm/send/fixture',
    options: { applicationServerKey: subscriptionKey.buffer },
    unsubscribe: vi.fn(async () => true),
    toJSON: () => ({ keys: { p256dh: 'fixture-key', auth: 'fixture-auth' } }),
  } as unknown as PushSubscription;
  const pushManager = {
    getSubscription: vi.fn<() => Promise<PushSubscription | null>>(async () => existing ? subscription : null),
    subscribe: vi.fn(async () => subscription),
  };
  const registration = { active: { scriptURL: new URL('/admin-push-sw.js', location.origin).href }, pushManager };
  const requestPermission = vi.fn(async () => permission);
  const registerWorker = vi.fn(async () => registration);
  vi.stubGlobal('isSecureContext', true);
  vi.stubGlobal('PushManager', class {});
  vi.stubGlobal('Notification', { permission, requestPermission });
  vi.stubGlobal('navigator', { serviceWorker: { getRegistration: async () => existing ? registration : undefined, register: registerWorker } });
  const api = {
    publicKey,
    sessionId: vi.fn(async () => firstSession),
    isRegistered: vi.fn<AdminPushApi['isRegistered']>(async () => false),
    register: vi.fn<AdminPushApi['register']>(async () => {}),
    unregister: vi.fn<AdminPushApi['unregister']>(async () => {}),
  } satisfies AdminPushApi;
  return { api, requestPermission, registerWorker, pushManager, subscription };
}

test('a pre-existing device subscription does not opt a new admin session in until requested', async () => {
  const { api, requestPermission, pushManager, subscription } = browserFixture({ existing: true });
  const signal = new AbortController().signal;
  expect(await adminPushEnabled(api, firstSession)).toBe(false);
  expect(api.isRegistered).toHaveBeenCalledWith(subscription.endpoint, firstSession, undefined);
  expect(api.register).not.toHaveBeenCalled();
  expect(requestPermission).not.toHaveBeenCalled();

  expect(await enableAdminPush(api, firstSession, signal)).toBe(true);
  expect(api.register).toHaveBeenCalledWith(subscription, firstSession, signal);
  expect(pushManager.subscribe).not.toHaveBeenCalled();
});

test('denied browser permission does not create a subscription or call the server', async () => {
  const { api, registerWorker, pushManager } = browserFixture({ permission: 'denied' });
  expect(await enableAdminPush(api, firstSession, new AbortController().signal)).toBe(false);
  expect(registerWorker).not.toHaveBeenCalled();
  expect(pushManager.subscribe).not.toHaveBeenCalled();
  expect(api.register).not.toHaveBeenCalled();
});

test('enrollment still pins the original session if the account changes while permission is open', async () => {
  const { api, requestPermission, subscription } = browserFixture();
  let grantPermission: (permission: NotificationPermission) => void = () => {};
  requestPermission.mockImplementationOnce(() => new Promise(resolve => { grantPermission = resolve; }));
  api.register.mockImplementationOnce(async (_subscription, expectedSession) => {
    if (expectedSession !== await api.sessionId()) throw new Error('session changed');
  });
  const signal = new AbortController().signal;
  const enrollment = enableAdminPush(api, firstSession, signal);
  api.sessionId.mockResolvedValue(otherSession);
  grantPermission('granted');
  await expect(enrollment).rejects.toThrow('session changed');
  expect(api.register).toHaveBeenCalledWith(subscription, firstSession, signal);
  expect(subscription.unsubscribe).not.toHaveBeenCalled();
});

test('an old VAPID key never removes another tab’s browser subscription', async () => {
  const { api, subscription, pushManager } = browserFixture({ existing: true, rotated: true });
  await expect(enableAdminPush(api, firstSession, new AbortController().signal)).rejects.toBeInstanceOf(AdminPushKeyChanged);
  expect(subscription.unsubscribe).not.toHaveBeenCalled();
  expect(pushManager.subscribe).not.toHaveBeenCalled();
  expect(api.unregister).not.toHaveBeenCalled();
  expect(api.register).not.toHaveBeenCalled();
});

test('opt-out revokes only the pinned server session', async () => {
  const { api, subscription } = browserFixture({ existing: true });
  const signal = new AbortController().signal;
  await disableAdminPush(api, firstSession, signal);
  expect(api.unregister).toHaveBeenCalledWith(subscription.endpoint, firstSession, signal);
  expect(subscription.unsubscribe).not.toHaveBeenCalled();
});

test('logout preserves the session pinned before browser work', async () => {
  const { api, subscription, pushManager } = browserFixture({ existing: true });
  let releaseSubscription: (subscription: PushSubscription) => void = () => {};
  pushManager.getSubscription.mockImplementationOnce(() => new Promise(resolve => { releaseSubscription = resolve; }));
  const logout = revokeAdminPushOnLogout(api);
  await vi.waitFor(() => expect(pushManager.getSubscription).toHaveBeenCalled());
  api.sessionId.mockResolvedValue(otherSession);
  releaseSubscription(subscription);
  await logout;
  expect(api.unregister).toHaveBeenCalledWith(subscription.endpoint, firstSession, expect.any(AbortSignal));
  expect(subscription.unsubscribe).not.toHaveBeenCalled();
});

test('the three RPCs pass the original session claim for server-side verification', async () => {
  const { api: fixture, subscription } = browserFixture();
  const token = 'header.' + btoa(JSON.stringify({ session_id: firstSession })).replace(/=+$/, '') + '.signature';
  const key = btoa(String.fromCharCode(...fixture.publicKey)).replace(/=+$/, '');
  const rpc = vi.fn(async () => ({ data: true, error: null }));
  const client = { auth: { getSession: async () => ({ data: { session: { access_token: token } }, error: null }) }, rpc } as unknown as SupabaseClient;
  const api = createAdminPushApi(client, key)!;
  expect(await api.sessionId()).toBe(firstSession);
  await api.isRegistered(subscription.endpoint, firstSession);
  await api.register(subscription, firstSession);
  await api.unregister(subscription.endpoint, firstSession);
  const request = { p_endpoint: subscription.endpoint, p_expected_session_id: firstSession };
  expect(rpc).toHaveBeenNthCalledWith(1, 'dopmi_admin_push_is_registered', request);
  expect(rpc).toHaveBeenNthCalledWith(2, 'dopmi_admin_push_register', { ...request, p_p256dh: 'fixture-key', p_auth: 'fixture-auth' });
  expect(rpc).toHaveBeenNthCalledWith(3, 'dopmi_admin_push_unregister', request);
});
