import type { DashboardDestination } from './Dashboard';

const destinations = {
  adoptions: { section: 'adoptions' },
  rescues: { section: 'rescues', kind: 'case' },
  verification: { section: 'rescues', kind: 'verification' },
  reports: { section: 'moderation', view: 'reports' },
  updates: { section: 'moderation', view: 'updates' },
  profiles: { section: 'moderation', view: 'profiles' },
  videos: { section: 'videos' },
  support: { section: 'moderation', view: 'support' },
} as const satisfies Record<string, DashboardDestination>;

export type AdminPushQueue = keyof typeof destinations;
const returnQueueKey = 'dopmi-admin-oauth-return-queue';

function parseQueue(value: string | null): AdminPushQueue | null {
  return value && Object.hasOwn(destinations, value) ? value as AdminPushQueue : null;
}

export function queueFromUrl(href: string): AdminPushQueue | null {
  const url = new URL(href);
  const values = url.searchParams.getAll('queue');
  return url.pathname === '/' && values.length === 1 ? parseQueue(values[0]) : null;
}

export function destinationForQueue(queue: AdminPushQueue): DashboardDestination {
  return destinations[queue];
}

export function storeOAuthQueue(queue: AdminPushQueue | null): void {
  try {
    if (queue) sessionStorage.setItem(returnQueueKey, queue);
    else sessionStorage.removeItem(returnQueueKey);
  } catch {
    // OAuth still works in browsers that do not allow session storage.
  }
}

export function takeOAuthQueue(): AdminPushQueue | null {
  try {
    const queue = parseQueue(sessionStorage.getItem(returnQueueKey));
    sessionStorage.removeItem(returnQueueKey);
    return queue;
  } catch {
    return null;
  }
}

export function adminQueueUrl(origin: string, queue: AdminPushQueue | null): URL {
  const url = new URL('/', origin);
  if (queue) url.searchParams.set('queue', queue);
  return url;
}
