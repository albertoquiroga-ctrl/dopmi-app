const queues = new Set([
  'adoptions', 'rescues', 'verification', 'reports',
  'updates', 'profiles', 'videos', 'support',
]);

self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));

self.addEventListener('push', event => {
  let queue;
  try { queue = event.data?.json()?.queue; } catch { return; }
  if (!queues.has(queue)) return;
  event.waitUntil(self.registration.showNotification('Dopmi · Administración', {
    body: 'Hay una tarea pendiente en el panel.',
    icon: '/admin-icon.png',
    tag: 'dopmi-admin-' + queue,
    renotify: true,
    data: { queue },
  }));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const queue = event.notification.data?.queue;
  if (!queues.has(queue)) return;
  const url = new URL('/', self.location.origin);
  url.searchParams.set('queue', queue);
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const current = windows.find(client => client.url === url.href);
    if (current) await current.focus();
    else await self.clients.openWindow(url.href);
  })());
});
