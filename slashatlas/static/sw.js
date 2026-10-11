// Service worker SlashAtlas (version __V__) : rend le site installable et utilisable un instant sans réseau.
// Pages : réseau d'abord (toujours à jour), copie gardée pour le hors-ligne. Fichiers versionnés (css, js, polices, images) : cache d'abord.
// Jamais touchés : /api, les vidéos, les requêtes non GET.
const CACHE = 'sa-__V__';
const OFFLINE = '<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SlashAtlas hors ligne</title><style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#000;color:#f5f5f7;font:18px/1.5 system-ui,sans-serif;text-align:center;padding:24px}b{color:#2997ff}button{margin-top:18px;border:0;border-radius:999px;background:#2997ff;color:#fff;font:700 16px system-ui;padding:14px 26px}</style></head><body><div><h1><b>/</b>SlashAtlas</h1><p>Vous êtes hors ligne.<br>Reconnectez-vous pour retrouver les commandes.</p><button onclick="location.reload()">Réessayer</button></div></body></html>';
self.addEventListener('install', (e) => { self.skipWaiting(); });
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const r = e.request;
  if (r.method !== 'GET') return;
  const u = new URL(r.url);
  if (u.origin !== location.origin || u.pathname.startsWith('/api/') || /\.mp4$/.test(u.pathname) || r.headers.has('range')) return;
  if (r.mode === 'navigate') {
    e.respondWith(fetch(r).then((res) => { if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(r, copy)); } return res; })
      .catch(() => caches.match(r).then((m) => m || new Response(OFFLINE, { headers: { 'content-type': 'text/html; charset=utf-8' } }))));
    return;
  }
  // css et js : seulement les fichiers versionnés (?v=…), jamais /js/auth.js nu qui change sans changer d'adresse
  if (/\.(woff2|webp|png|svg|ico)$/.test(u.pathname) || (/\.(css|js)$/.test(u.pathname) && u.search.indexOf('v=') > -1)) {
    e.respondWith(caches.match(r).then((m) => m || fetch(r).then((res) => { if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(r, copy)); } return res; })));
  }
});
