/* Afrolook Ads : balise d'affichage pour sites web (version 1).
   Documentation : https://afrolookmedia.com/ads/diffuseur/documentation/
   Usage : <ins class="afl-ad" data-pub="ap_xxxxxxxxxx" data-slot="fil" data-format="native"></ins>
           <script async src="https://afrolookmedia.com/ads/tag.js"></script>
   Formats pris en charge : banner, native, poster, sticky, carousel, video, interstitial, rewarded (chaque format a son prix, donc sa rémunération).
   Interstitiel : s'affiche seul après data-delay millisecondes (2500 par défaut), fermable après 3 secondes.
   Récompensée : l'emplacement montre un bouton ; quand la vidéo a été regardée en entier, l'événement « afl:reward » part de l'emplacement (à toi de donner la récompense).
   Une seule annonce par emplacement et par chargement de page ; 3 emplacements au plus par page.
   Les annonces sont choisies, signées et comptées par les serveurs d'Afrolook : cette balise ne décide de rien, elle affiche. */
(function () {
  'use strict';
  if (window.__aflAds) return; window.__aflAds = true;
  var API = window.AFL_ADS_API || '__API_BASE__/ads/api'; // remplacé à la construction du site (build.mjs, variable API_BASE)
  var MAX_SLOTS = 3;
  var FORMATS = { banner: 1, native: 1, poster: 1, sticky: 1, carousel: 1, video: 1, interstitial: 1, rewarded: 1 };
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
      '.afl-car .afl-trk{display:flex;overflow-x:auto;scroll-snap-type:x mandatory;scrollbar-width:none}.afl-car .afl-trk::-webkit-scrollbar{display:none}.afl-car .afl-i{flex:0 0 100%;scroll-snap-align:center;aspect-ratio:4/5;object-fit:contain;background:#eef3ee}' +
      '.afl-video video{display:block;width:100%;aspect-ratio:9/16;max-height:70vh;object-fit:contain;background:#000}' +
      '.afl-ov{position:fixed;inset:0;z-index:2147483200;display:flex;align-items:center;justify-content:center;padding:16px;background:rgba(0,0,0,.82)}.afl-ov .afl-c{width:min(92vw,380px);max-height:92vh;overflow:auto}' +
      '.afl-ov .afl-close{position:fixed;right:14px;top:14px;width:36px;height:36px;background:rgba(255,255,255,.22);color:#fff}.afl-ov .afl-close:disabled{opacity:.7;cursor:default}' +
      '.afl-prg{height:4px;background:rgba(255,255,255,.25)}.afl-prg i{display:block;height:100%;width:0;background:#2ecc71}.afl-rw{background:#12804a;color:#fff;font:800 14px system-ui,sans-serif;border:0;border-radius:99px;padding:12px 20px;cursor:pointer}' +
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
    var vid = (fmt === 'video' || fmt === 'rewarded') && ad.media && ad.media.type === 'video' ? httpsOnly(ad.media.url) : '';
    var pics = [];
    if (fmt === 'carousel') { var raw = (ad.media && ad.media.images) || []; for (var k = 0; k < raw.length && pics.length < 5; k++) { var u2 = httpsOnly(typeof raw[k] === 'string' ? raw[k] : raw[k] && raw[k].url); if (u2) pics.push(u2); } }
    if (vid) {
      var v = el('video'); v.muted = true; v.playsInline = true; v.preload = 'metadata'; v.src = vid; if (img) v.poster = img; if (fmt === 'rewarded') v.controls = false; wrap.appendChild(v);
    } else if (pics.length > 1) {
      var trk = el('div', 'afl-trk'); pics.forEach(function (u3) { var im = el('img', 'afl-i'); im.src = u3; im.alt = ''; im.loading = 'lazy'; trk.appendChild(im); }); wrap.appendChild(trk);
    } else if (img) { var i = el('img', 'afl-i'); i.src = img; i.alt = ''; i.loading = 'lazy'; wrap.appendChild(i); }
    var b = el('div', 'afl-b');
    b.appendChild(el('div', 'afl-t', ad.title));
    if (ad.text) b.appendChild(el('div', 'afl-x', ad.text));
    if (ad.cta && url) b.appendChild(el('span', 'afl-go', ad.cta));
    wrap.appendChild(b);
    host.textContent = '';
    host.className = 'afl-ad afl-' + fmt;
    if (fmt === 'carousel' && pics.length > 1) host.className += ' afl-car';
    if (fmt === 'interstitial' || fmt === 'rewarded') return overlay(host, wrap, ad, fmt);
    host.appendChild(wrap);
    if (vid) videoPlay(wrap.querySelector('video'), ad, false);
    if (fmt === 'sticky') {
      var x = el('button', 'afl-close', '×'); x.type = 'button'; x.setAttribute('aria-label', 'Fermer');
      x.addEventListener('click', function (e) { e.preventDefault(); e.stopPropagation(); host.remove(); try { sessionStorage.setItem('afl_sticky_closed', '1'); } catch (er) { /* tant pis */ } });
      wrap.appendChild(x);
    }
    watch(wrap, ad);
  }

  // vidéo : lancée sans son quand elle est visible à moitié, mise en pause sinon ; la lecture complète est comptée par le serveur (événement « complete »)
  function videoPlay(v, ad, forced, onEnd) {
    if (!v) return;
    var done = false;
    v.addEventListener('ended', function () {
      if (done) return; done = true;
      post(ad.event, { t: ad.token, e: 'complete', ms: Math.round((v.duration || 0) * 1000), vid: VID });
      if (onEnd) onEnd();
    });
    if (forced) { var p = v.play(); p && p.catch && p.catch(function () {}); return; }
    if (!('IntersectionObserver' in window)) return;
    new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (e.isIntersecting && e.intersectionRatio >= 0.5 && document.visibilityState === 'visible') { var p2 = v.play(); p2 && p2.catch && p2.catch(function () {}); } else v.pause();
      });
    }, { threshold: [0, 0.5, 1] }).observe(v);
  }

  // plein écran (interstitiel) et récompensée : fenêtre par-dessus la page
  function overlay(host, wrap, ad, fmt) {
    var ov = el('div', 'afl-ov'); ov.setAttribute('role', 'dialog'); ov.appendChild(wrap);
    var x = el('button', 'afl-close', '3'); x.type = 'button'; x.disabled = true; ov.appendChild(x);
    function close() { ov.remove(); }
    function open() {
      document.body.appendChild(ov); watch(wrap, ad);
      var v = wrap.querySelector('video');
      if (fmt === 'rewarded') {
        // récompensée : on ne peut pas fermer avant la fin ; à la fin, « afl:reward » part de l'emplacement
        var bar = el('div', 'afl-prg'); bar.appendChild(el('i')); wrap.insertBefore(bar, wrap.firstChild);
        if (v) { v.addEventListener('timeupdate', function () { if (v.duration) bar.firstChild.style.width = Math.min(100, v.currentTime / v.duration * 100) + '%'; }); }
        videoPlay(v, ad, true, function () { x.disabled = false; x.textContent = '✕'; x.setAttribute('aria-label', 'Fermer'); host.dispatchEvent(new CustomEvent('afl:reward', { bubbles: true, detail: { ad: ad.id } })); });
        if (!v) { x.disabled = false; x.textContent = '✕'; }
        x.addEventListener('click', function () { if (!x.disabled) close(); });
        return;
      }
      var n = 3, t = setInterval(function () { n--; if (n > 0) { x.textContent = String(n); return; } clearInterval(t); x.disabled = false; x.textContent = '✕'; x.setAttribute('aria-label', 'Fermer'); }, 1000);
      x.addEventListener('click', function () { if (!x.disabled) close(); });
    }
    if (fmt === 'rewarded') {
      var b = el('button', 'afl-rw', host.getAttribute('data-label') || 'Regarder une vidéo'); b.type = 'button';
      b.addEventListener('click', function () { b.disabled = true; open(); });
      host.appendChild(b);
    } else {
      var delay = parseInt(host.getAttribute('data-delay') || '2500', 10); setTimeout(open, isNaN(delay) ? 2500 : Math.max(0, delay));
    }
  }

  function load(host) {
    var pub = host.getAttribute('data-pub') || '', fmt = host.getAttribute('data-format') || 'native', slot = host.getAttribute('data-slot') || 'main';
    if (!/^ap_[a-z0-9]{10}$/.test(pub) && !/^[a-z0-9_]{2,24}$/.test(pub)) { host.hidden = true; return; }
    if (!FORMATS[fmt]) { host.hidden = true; return; }
    if (fmt === 'sticky') { try { if (sessionStorage.getItem('afl_sticky_closed')) { host.hidden = true; return; } } catch (e) { /* tant pis */ } }
    var q = 'pub=' + encodeURIComponent(pub) + '&fmt=' + encodeURIComponent(fmt) + '&slot=' + encodeURIComponent(slot) + '&vid=' + encodeURIComponent(VID) + '&lang=' + encodeURIComponent((navigator.language || '').slice(0, 2));
    fetch(API + '/serve?' + q, { cache: 'no-store' }).then(function (r) { return r.json(); }).then(function (j) {
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
