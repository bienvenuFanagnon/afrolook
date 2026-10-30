/* Afrolook Ads : balise d'affichage pour sites web (version 1).
   Documentation : https://afrolookmedia.com/ads/diffuseur/documentation/
   Usage : <ins class="afl-ad" data-pub="ap_xxxxxxxxxx" data-slot="fil" data-format="native"></ins>
           <script async src="https://afrolookmedia.com/ads/tag.js"></script>
   Formats pris en charge : banner, native, poster, sticky. Une seule annonce par emplacement et par chargement de page ; 3 emplacements au plus par page.
   Les annonces sont choisies, signées et comptées par les serveurs d'Afrolook : cette balise ne décide de rien, elle affiche. */
(function () {
  'use strict';
  if (window.__aflAds) return; window.__aflAds = true;
  var API = window.AFL_ADS_API || 'https://us-central1-afrolooki.cloudfunctions.net';
  var MAX_SLOTS = 3;
  var FORMATS = { banner: 1, native: 1, poster: 1, sticky: 1 };
  var DNT = navigator.doNotTrack === '1' || navigator.globalPrivacyControl === true;

  // identifiant anonyme du navigateur (propre à ce site) : sert aux plafonds d'affichage ; avec « Ne pas suivre », il ne dure que le temps de la visite
  function visitorId() {
    var mk = function () { return ((window.crypto && crypto.randomUUID) ? crypto.randomUUID() : Math.random().toString(36).slice(2) + Date.now().toString(36)).replace(/[^A-Za-z0-9-]/g, ''); };
    try {
      var s = DNT ? window.sessionStorage : window.localStorage; var v = s.getItem('aflv');
      if (!v) { v = mk(); s.setItem('aflv', v); }
      return v;
    } catch (e) { return mk(); }
  }
  var VID = visitorId();

  function css() {
    if (document.getElementById('afl-ads-css')) return;
    var s = document.createElement('style'); s.id = 'afl-ads-css';
    s.textContent = '.afl-ad{display:block;max-width:100%}.afl-c{position:relative;display:block;text-decoration:none;color:#14201a;background:#fff;border:1px solid #dbe3dc;border-radius:14px;overflow:hidden;font:14px/1.4 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}' +
      '.afl-c:hover{border-color:#2ecc71}.afl-tag{position:absolute;left:8px;top:8px;background:rgba(0,0,0,.65);color:#fff;font:700 11px/1 system-ui,sans-serif;padding:4px 8px;border-radius:99px;z-index:1}' +
      '.afl-i{display:block;width:100%;aspect-ratio:16/9;object-fit:cover;background:#eef3ee}.afl-poster .afl-i{aspect-ratio:4/5}.afl-b{padding:12px 14px;display:grid;gap:6px}.afl-t{font-weight:800;font-size:15px}.afl-x{color:#56645b;font-size:13px}' +
      '.afl-go{justify-self:start;background:#12804a;color:#fff;font-weight:800;border-radius:99px;padding:8px 16px;font-size:13px}' +
      '.afl-banner .afl-c{display:flex;align-items:center;gap:12px;padding:8px 12px 8px 8px;min-height:64px}.afl-banner .afl-i{width:72px;height:48px;aspect-ratio:auto;border-radius:10px;flex:none}.afl-banner .afl-b{padding:0;flex:1;min-width:0}.afl-banner .afl-t,.afl-banner .afl-x{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.afl-banner .afl-x{display:none}.afl-banner .afl-tag{position:static;align-self:flex-start;background:#eef3ee;color:#56645b}' +
      '.afl-sticky{position:fixed;left:0;right:0;bottom:0;z-index:2147483000;padding:8px;background:rgba(255,255,255,.96);box-shadow:0 -4px 20px rgba(0,0,0,.15)}.afl-sticky .afl-c{max-width:728px;margin:0 auto;display:flex;align-items:center;gap:12px;padding:8px 40px 8px 8px}.afl-sticky .afl-i{width:72px;height:48px;aspect-ratio:auto;border-radius:10px;flex:none}.afl-sticky .afl-b{padding:0;flex:1;min-width:0}.afl-sticky .afl-x{display:none}.afl-sticky .afl-tag{position:static}.afl-sticky .afl-t{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
      '.afl-close{position:absolute;right:12px;top:12px;width:28px;height:28px;border:0;border-radius:50%;background:#eef3ee;color:#14201a;font:700 16px/1 system-ui;cursor:pointer;z-index:2}' +
      '@media (prefers-color-scheme:dark){.afl-c{background:#16241b;color:#eaf3ec;border-color:#22352a}.afl-x{color:#9bb0a2}.afl-sticky{background:rgba(10,18,14,.96)}.afl-close{background:#22352a;color:#eaf3ec}}';
    document.head.appendChild(s);
  }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text) e.textContent = text; return e; }
  function httpsOnly(u) { try { var x = new URL(u); return x.protocol === 'https:' ? x.href : ''; } catch (e) { return ''; } }

  function post(url, body) {
    if (DNT) return; // « Ne pas suivre » : ni vue ni clic ne sont enregistrés pour ce visiteur
    try { fetch(url, { method: 'POST', body: JSON.stringify(body), headers: { 'Content-Type': 'text/plain' }, keepalive: true }).catch(function () {}); } catch (e) { /* le comptage ne doit jamais gêner la page */ }
  }

  // une vue = l'annonce est visible à moitié au moins, sans interruption, pendant la durée du format (mesurée ici ; le serveur la recoupe)
  function watch(node, ad) {
    var timer = 0, sent = false;
    function fire() { if (sent) return; sent = true; post(ad.event, { t: ad.token, e: 'view', ms: ad.viewMs + 50, vid: VID }); if (io) io.disconnect(); }
    if (!('IntersectionObserver' in window)) { timer = setTimeout(fire, ad.viewMs + 100); return; }
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        clearTimeout(timer);
        if (e.isIntersecting && e.intersectionRatio >= 0.5 && document.visibilityState === 'visible') timer = setTimeout(function () { if (document.visibilityState === 'visible') fire(); }, ad.viewMs + 50);
      });
    }, { threshold: [0, 0.5, 1] });
    io.observe(node);
    document.addEventListener('visibilitychange', function () { if (document.visibilityState !== 'visible') clearTimeout(timer); });
  }

  function render(host, ad, fmt) {
    var url = ad.click ? httpsOnly(ad.click) : '';
    var wrap = el(url ? 'a' : 'div', 'afl-c');
    if (url) { wrap.href = url; wrap.target = '_blank'; wrap.rel = 'sponsored nofollow noopener'; }
    wrap.appendChild(el('span', 'afl-tag', ad.label || 'Annonce'));
    var img = httpsOnly(ad.media && (ad.media.thumb || ad.media.url));
    if (img) { var i = el('img', 'afl-i'); i.src = img; i.alt = ''; i.loading = 'lazy'; wrap.appendChild(i); }
    var b = el('div', 'afl-b');
    b.appendChild(el('div', 'afl-t', ad.title));
    if (ad.text) b.appendChild(el('div', 'afl-x', ad.text));
    if (ad.cta && url) b.appendChild(el('span', 'afl-go', ad.cta));
    wrap.appendChild(b);
    host.textContent = '';
    host.className = 'afl-ad afl-' + fmt;
    host.appendChild(wrap);
    if (fmt === 'sticky') {
      var x = el('button', 'afl-close', '×'); x.type = 'button'; x.setAttribute('aria-label', 'Fermer');
      x.addEventListener('click', function (e) { e.preventDefault(); e.stopPropagation(); host.remove(); try { sessionStorage.setItem('afl_sticky_closed', '1'); } catch (er) { /* tant pis */ } });
      wrap.appendChild(x);
    }
    watch(wrap, ad);
  }

  function load(host) {
    var pub = host.getAttribute('data-pub') || '', fmt = host.getAttribute('data-format') || 'native', slot = host.getAttribute('data-slot') || 'main';
    if (!/^ap_[a-z0-9]{10}$/.test(pub) && !/^[a-z0-9_]{2,24}$/.test(pub)) { host.hidden = true; return; }
    if (!FORMATS[fmt]) { host.hidden = true; return; }
    if (fmt === 'sticky') { try { if (sessionStorage.getItem('afl_sticky_closed')) { host.hidden = true; return; } } catch (e) { /* tant pis */ } }
    var q = 'pub=' + encodeURIComponent(pub) + '&fmt=' + encodeURIComponent(fmt) + '&slot=' + encodeURIComponent(slot) + '&vid=' + encodeURIComponent(VID) + '&lang=' + encodeURIComponent((navigator.language || '').slice(0, 2));
    fetch(API + '/adsServe?' + q, { cache: 'no-store' }).then(function (r) { return r.json(); }).then(function (j) {
      if (!j || !j.ok || !j.ad) { host.hidden = true; return; } // aucune annonce pour ce visiteur : l'emplacement reste vide
      css(); render(host, j.ad, fmt);
    }).catch(function () { host.hidden = true; });
  }

  function init() {
    var hosts = Array.prototype.slice.call(document.querySelectorAll('ins.afl-ad'));
    hosts.slice(0, MAX_SLOTS).forEach(load);
    hosts.slice(MAX_SLOTS).forEach(function (h) { h.hidden = true; }); // règle : 3 emplacements au plus par page
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
