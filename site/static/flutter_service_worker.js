// Ancien service worker de l'application web (qui était à la racine du domaine).
// L'application vit maintenant sous /app/ : ce fichier remplace l'ancien chez les visiteurs de retour,
// vide ses caches et se désinscrit, pour qu'ils voient le site et non une vieille copie de l'application.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try { for (const k of await caches.keys()) await caches.delete(k); } catch (e) {}
    try { await self.registration.unregister(); } catch (e) {}
    try { for (const c of await self.clients.matchAll({ type: 'window' })) c.navigate(c.url); } catch (e) {}
  })());
});
