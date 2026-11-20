import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { expect, test, vi } from 'vitest';
import { queueFromUrl } from './adminPushRoutes';

test('public service worker permits only panel queues and does not copy external or private payload fields', async () => {
  const handlers = new Map();
  const showNotification = vi.fn().mockResolvedValue(undefined);
  const openWindow = vi.fn().mockResolvedValue(undefined);
  const scope = 'https://admin.example.test';
  const self = {
    location: { origin: scope },
    registration: { showNotification },
    clients: { matchAll: async () => [], openWindow },
    addEventListener: (name, handler) => handlers.set(name, handler),
  };
  runInNewContext(readFileSync('public/admin-push-sw.js', 'utf8'), { self, URL });
  const waitUntil = vi.fn();
  const push = handlers.get('push');
  push({ data: { json: () => ({ queue: 'https://outside.example/steal' }) }, waitUntil });
  expect(showNotification).not.toHaveBeenCalled();

  for (const queue of ['adoptions', 'rescues', 'verification', 'reports', 'updates', 'profiles', 'videos', 'support']) {
    push({ data: { json: () => ({ queue, body: 'Private case details', url: 'https://outside.example/steal' }) }, waitUntil });
    const notification = showNotification.mock.lastCall[1];
    expect(notification.body).toBe('Hay una tarea pendiente en el panel.');
    expect(notification.data).toEqual({ queue });
    handlers.get('notificationclick')({ notification: { close: vi.fn(), data: notification.data }, waitUntil });
    await waitUntil.mock.lastCall[0];
    expect(openWindow).toHaveBeenLastCalledWith(scope + '/?queue=' + queue);
    expect(queueFromUrl(openWindow.mock.lastCall[0])).toBe(queue);
  }
  handlers.get('notificationclick')({ notification: { close: vi.fn(), data: { queue: 'constructor' } }, waitUntil });
  expect(openWindow).toHaveBeenCalledTimes(8);
  expect(queueFromUrl(scope + '/?queue=reports&queue=support')).toBeNull();
});
