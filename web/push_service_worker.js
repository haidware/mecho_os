self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch {
    payload = { body: event.data ? event.data.text() : '' };
  }

  const title = payload.title || 'Mecho OS';
  const options = {
    body: payload.body || 'You have a new spare-parts marketplace update.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.id || `mecho-${Date.now()}`,
    renotify: true,
    silent: false,
    vibrate: [180, 90, 180],
    data: { url: payload.url || '/notifications' }
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(
    event.notification.data?.url || '/notifications',
    self.location.origin
  ).href;
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      const existing = windows.find((client) => client.url.startsWith(self.location.origin));
      if (existing) return existing.navigate(target).then(() => existing.focus());
      return clients.openWindow(target);
    })
  );
});
