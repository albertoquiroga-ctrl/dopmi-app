import type { SupabaseClient } from '@supabase/supabase-js';

const workerPath = '/admin-push-sw.js';
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class AdminPushKeyChanged extends Error {}

export type AdminPushApi = {
  publicKey: Uint8Array<ArrayBuffer>;
  sessionId: () => Promise<string | null>;
  isRegistered: (endpoint: string, expectedSessionId: string, signal?: AbortSignal) => Promise<boolean>;
  register: (subscription: PushSubscription, expectedSessionId: string, signal?: AbortSignal) => Promise<void>;
  unregister: (endpoint: string, expectedSessionId: string, signal?: AbortSignal) => Promise<void>;
};

function base64UrlBytes(value: string): string {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  return atob(base64.padEnd(Math.ceil(base64.length / 4) * 4, '='));
}

function publicKeyBytes(key: string | undefined): Uint8Array<ArrayBuffer> | null {
  if (!key || !/^[\w-]{87}$/.test(key)) return null;
  try {
    const bytes = Uint8Array.from(base64UrlBytes(key), char => char.charCodeAt(0));
    return bytes.length === 65 && bytes[0] === 4 ? bytes : null;
  } catch {
    return null;
  }
}

export function createAdminPushApi(client: SupabaseClient, key: string | undefined): AdminPushApi | undefined {
  const publicKey = publicKeyBytes(key?.trim());
  if (!publicKey) return undefined;
  return {
    publicKey,
    async sessionId() {
      const { data, error } = await client.auth.getSession();
      if (error) throw error;
      const payload = data.session?.access_token.split('.')[1];
      if (!payload) return null;
      try {
        // The database authenticates this value against the signed request JWT.
        const { session_id: id } = JSON.parse(base64UrlBytes(payload));
        return typeof id === 'string' && uuidPattern.test(id) ? id : null;
      } catch {
        return null;
      }
    },
    async isRegistered(endpoint, expectedSessionId, signal) {
      const request = client.rpc('dopmi_admin_push_is_registered', { p_endpoint: endpoint, p_expected_session_id: expectedSessionId });
      const { data, error } = await (signal ? request.abortSignal(signal) : request);
      if (error) throw error;
      return data === true;
    },
    async register(subscription, expectedSessionId, signal) {
      const { keys } = subscription.toJSON();
      if (!keys?.p256dh || !keys.auth) throw new Error('Missing push keys');
      const request = client.rpc('dopmi_admin_push_register', {
        p_endpoint: subscription.endpoint,
        p_p256dh: keys.p256dh,
        p_auth: keys.auth,
        p_expected_session_id: expectedSessionId,
      });
      const { error } = await (signal ? request.abortSignal(signal) : request);
      if (error) throw error;
    },
    async unregister(endpoint, expectedSessionId, signal) {
      const request = client.rpc('dopmi_admin_push_unregister', { p_endpoint: endpoint, p_expected_session_id: expectedSessionId });
      const { error } = await (signal ? request.abortSignal(signal) : request);
      if (error) throw error;
    },
  };
}

export function supportsAdminPush(): boolean {
  return window.isSecureContext && 'serviceWorker' in navigator
    && 'PushManager' in window && 'Notification' in window;
}

function ownsWorker(registration: ServiceWorkerRegistration): boolean {
  const worker = registration.active ?? registration.waiting ?? registration.installing;
  return worker?.scriptURL === new URL(workerPath, window.location.origin).href;
}

async function currentRegistration(): Promise<ServiceWorkerRegistration | undefined> {
  const registration = await navigator.serviceWorker.getRegistration('/');
  if (registration && ownsWorker(registration)) return registration;
  return undefined;
}

async function registerWorker(): Promise<ServiceWorkerRegistration> {
  const existing = await navigator.serviceWorker.getRegistration('/');
  if (existing && !ownsWorker(existing)) throw new Error('Another service worker controls the panel');
  const registration = await navigator.serviceWorker.register(workerPath, { scope: '/', updateViaCache: 'none' });
  let timer: ReturnType<typeof setTimeout> | undefined;
  const active = registration.active ? registration : await Promise.race([
    navigator.serviceWorker.ready,
    new Promise<null>(resolve => { timer = setTimeout(() => resolve(null), 8000); }),
  ]).finally(() => clearTimeout(timer));
  if (!active || !ownsWorker(active)) throw new Error('Push service worker is not active');
  return active;
}

async function currentSubscription(): Promise<PushSubscription | null | undefined> {
  const registration = await currentRegistration();
  return registration?.pushManager.getSubscription();
}

export async function adminPushEnabled(api: AdminPushApi, sessionId: string, signal?: AbortSignal): Promise<boolean> {
  if (!supportsAdminPush() || Notification.permission !== 'granted') return false;
  const subscription = await currentSubscription();
  signal?.throwIfAborted();
  return subscription ? api.isRegistered(subscription.endpoint, sessionId, signal) : false;
}

export async function enableAdminPush(api: AdminPushApi, sessionId: string, signal: AbortSignal): Promise<boolean> {
  const permission = await Notification.requestPermission();
  signal.throwIfAborted();
  if (permission !== 'granted') return false;
  const registration = await registerWorker();
  signal.throwIfAborted();
  const existing = await registration.pushManager.getSubscription();
  if (existing) {
    const key = existing.options.applicationServerKey;
    const previousKey = key ? new Uint8Array(key) : null;
    if (!previousKey || previousKey.length !== api.publicKey.length || previousKey.some((byte, i) => byte !== api.publicKey[i])) {
      throw new AdminPushKeyChanged();
    }
  }
  signal.throwIfAborted();
  const subscription = existing ?? await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: api.publicKey,
  });
  signal.throwIfAborted();
  // A browser subscription is shared across tabs. Only the signed-in session
  // can bind it to a server row, and another session may have already used it.
  await api.register(subscription, sessionId, signal);
  return true;
}

export async function disableAdminPush(api: AdminPushApi, sessionId: string, signal: AbortSignal): Promise<void> {
  if (!supportsAdminPush()) return;
  const subscription = await currentSubscription();
  signal.throwIfAborted();
  if (subscription) await api.unregister(subscription.endpoint, sessionId, signal);
}

export async function revokeAdminPushOnLogout(api: AdminPushApi): Promise<void> {
  if (!supportsAdminPush()) return;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 3000);
  const revoke = async () => {
    const sessionId = await api.sessionId();
    if (sessionId) await disableAdminPush(api, sessionId, controller.signal);
  };
  try {
    await Promise.race([
      revoke().catch(() => undefined),
      new Promise<void>(resolve => controller.signal.addEventListener('abort', () => resolve(), { once: true })),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
