/* PronoFlash IA : service worker minimal.
   Rend le site installable et affiche une page claire quand le téléphone n'a pas de réseau.
   Les pages de pronostics ne sont jamais gardées en mémoire : elles changent toute la journée. */
const VERSION = 'pf-sw-3';
const OFFLINE = '/offline';

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.add(OFFLINE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== VERSION).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  if (e.request.mode !== 'navigate') return;
  e.respondWith(fetch(e.request).catch(() => caches.match(OFFLINE)));
});

/* Notifications : le serveur envoie { t: titre, b: texte, u: adresse, g: étiquette, i: image (adresse de notre site) }. Aucun contenu n'est gardé en mémoire. */
self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch { d = { t: 'PronoFlash IA', b: e.data ? e.data.text() : '' }; }
  e.waitUntil(self.registration.showNotification(d.t || 'PronoFlash IA', {
    body: d.b || '', image: typeof d.i === 'string' && d.i.startsWith('/api/img/') ? d.i : undefined, icon: '/img/icon-192.png', badge: '/img/badge-96.png', tag: d.g || 'pf', renotify: false,
    data: { u: typeof d.u === 'string' && d.u.startsWith('/') ? d.u : '/' },
  }));
});
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.u) || '/';
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const c of list) { if (c.url.startsWith(self.location.origin) && 'focus' in c) { c.navigate(url); return c.focus(); } }
    return self.clients.openWindow(url);
  }));
});
