/* PronoFlash IA : service worker minimal.
   Rend le site installable et affiche une page claire quand le téléphone n'a pas de réseau.
   Les pages de pronostics ne sont jamais gardées en mémoire : elles changent toute la journée. */
const VERSION = 'pf-sw-1';
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
