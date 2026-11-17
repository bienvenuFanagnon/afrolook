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
  var SIZES = { '728x90': 1, '320x100': 1, '320x50': 1, '300x250': 1 };   // bannières prêtes (data-size="300x250" pour un rectangle dans le contenu)
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
    s.textContent = '.afl-ad{display:block;max-width:100%;text-decoration:none}.afl-c{position:relative;display:block;text-decoration:none;color:#14201a;background:#fff;border:1px solid #dbe3dc;border-radius:14px;overflow:hidden;font:14px/1.4 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}' +
      '.afl-c:hover{border-color:#2ecc71}.afl-tag{position:absolute;left:8px;top:8px;background:rgba(0,0,0,.65);color:#fff;font:700 11px/1 system-ui,sans-serif;padding:4px 8px;border-radius:99px;z-index:1}' +
      '.afl-m{position:relative;display:block;width:100%;aspect-ratio:16/9;overflow:hidden;background:#eef3ee}.afl-m::before{content:"";position:absolute;inset:-24px;background:var(--u) center/cover no-repeat;filter:blur(18px) brightness(.85)}' +
      '.afl-i{position:relative;display:block;width:100%;height:100%;object-fit:contain}.afl-poster .afl-m{aspect-ratio:4/5}' +
      '.afl-bn{display:block;position:relative;line-height:0;width:fit-content;max-width:100%;margin:0 auto}.afl-bn img{display:inline-block;width:100%;height:auto}.afl-ad .afl-bn .afl-tag{position:absolute;left:auto;right:4px;top:4px;line-height:1;text-decoration:none;color:#fff;background:rgba(0,0,0,.65);font-size:10px;padding:3px 6px}' +
      '.afl-h{display:flex;align-items:center;gap:8px;min-width:0}.afl-h img{width:24px;height:24px;border-radius:50%;object-fit:cover;flex:none;background:#eef3ee}.afl-h span{min-width:0;display:grid}.afl-h b{font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.afl-h small{color:#56645b;font-size:11.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
      '.afl-banner .afl-h img,.afl-sticky .afl-h img{display:none}.afl-banner .afl-h small,.afl-sticky .afl-h small{display:none}' +
      '.afl-b{padding:12px 14px;display:grid;gap:6px}.afl-t{font-weight:800;font-size:15px}.afl-x{color:#56645b;font-size:13px}' +
      '.afl-go{justify-self:start;background:#FFD21F;color:#111;font-weight:800;border-radius:99px;padding:8px 16px;font-size:13px}' +
      '.afl-banner .afl-c{display:flex;align-items:center;gap:12px;padding:8px 12px 8px 8px;min-height:64px}.afl-banner .afl-m{width:72px;height:48px;aspect-ratio:auto;border-radius:10px;flex:none}.afl-banner .afl-b{padding:0;flex:1;min-width:0}.afl-banner .afl-t,.afl-banner .afl-x{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.afl-banner .afl-x{display:none}.afl-banner .afl-c .afl-tag,.afl-sticky .afl-c .afl-tag{position:absolute;left:12px;top:12px;font-size:9px;padding:2px 5px}' +
      '.afl-sticky{position:fixed;left:0;right:0;bottom:0;z-index:2147483000;padding:8px;background:rgba(255,255,255,.96);box-shadow:0 -4px 20px rgba(0,0,0,.15)}.afl-sticky .afl-c{max-width:728px;margin:0 auto;display:flex;align-items:center;gap:12px;padding:8px 40px 8px 8px}.afl-sticky .afl-m{width:72px;height:48px;aspect-ratio:auto;border-radius:10px;flex:none}.afl-sticky .afl-bn{max-width:min(728px,calc(100% - 40px));margin:0 auto}.afl-ad.afl-sticky .afl-bn .afl-tag{right:auto;left:4px}.afl-sticky .afl-b{padding:0;flex:1;min-width:0}.afl-sticky .afl-x{display:none}.afl-sticky .afl-t{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
      '.afl-pvfs{display:flex;justify-content:center;padding:24px 16px;background:rgba(0,0,0,.82);border-radius:12px}.afl-pvfs .afl-c{width:min(100%,380px)}' +
      '.afl-close{position:absolute;right:12px;top:12px;width:28px;height:28px;border:0;border-radius:50%;background:#eef3ee;color:#14201a;font:700 16px/1 system-ui;cursor:pointer;z-index:2}' +
      '.afl-car .afl-trk{display:flex;overflow-x:auto;scroll-snap-type:x mandatory;scrollbar-width:none}.afl-car .afl-trk::-webkit-scrollbar{display:none}.afl-car .afl-m{flex:0 0 100%;scroll-snap-align:center;aspect-ratio:4/5}' +
      '.afl-video video{display:block;width:100%;aspect-ratio:9/16;max-height:70vh;object-fit:contain;background:#000}' +
      '.afl-ov{position:fixed;inset:0;z-index:2147483200;display:flex;align-items:center;justify-content:center;padding:16px;background:rgba(0,0,0,.82)}.afl-ov .afl-c{width:min(92vw,380px);max-height:92vh;overflow:auto}' +
      '.afl-ov .afl-close{position:fixed;right:14px;top:14px;width:36px;height:36px;background:rgba(255,255,255,.22);color:#fff}.afl-ov .afl-close:disabled{opacity:.7;cursor:default}' +
      '.afl-prg{height:4px;background:rgba(255,255,255,.25)}.afl-prg i{display:block;height:100%;width:0;background:#2ecc71}.afl-rw{background:#12804a;color:#fff;font:800 14px system-ui,sans-serif;border:0;border-radius:99px;padding:12px 20px;cursor:pointer}' +
      '@media (prefers-color-scheme:dark){.afl-c{background:#16241b;color:#eaf3ec;border-color:#22352a}.afl-x,.afl-h small{color:#9bb0a2}.afl-sticky{background:rgba(10,18,14,.96)}.afl-close{background:#22352a;color:#eaf3ec}}';
    document.head.appendChild(s);
  }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text) e.textContent = text; return e; }
  // PV = aperçu dans le formulaire d'Afrolook Ads (16/11/2026) : fichiers encore sur l'appareil (blob:) acceptés, rien n'est compté, le plein écran reste dans son cadre
  var PV = false;
  function httpsOnly(u) { if (!u) return ''; try { var x = new URL(u, location.href); return x.protocol === 'https:' || (PV && (x.protocol === 'blob:' || x.protocol === 'data:' || x.origin === location.origin)) ? x.href : ''; } catch (e) { return ''; } }

  function post(url, body) {
    if (DNT) return; // « Ne pas suivre » : ni vue ni clic ne sont enregistrés pour ce visiteur
    try { fetch(url, { method: 'POST', body: JSON.stringify(body), headers: { 'Content-Type': 'text/plain' }, keepalive: true }).catch(function () {}); } catch (e) { /* le comptage ne doit jamais gêner la page */ }
  }

  // une vue = l'annonce est visible à moitié au moins, sans interruption, pendant la durée du format (mesurée ici ; le serveur la recoupe)
  function watch(node, ad) {
    if (PV) return;   // aperçu : aucune vue envoyée
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

  // image montrée EN ENTIER (jamais recadrée) ; la place qui reste est remplie par la même image floutée (16/11/2026)
  function media(u) {
    var m = el('div', 'afl-m'); m.style.setProperty('--u', 'url("' + u + '")');
    var i = el('img', 'afl-i'); i.src = u; i.alt = ''; i.loading = 'lazy'; m.appendChild(i); return m;
  }

  // bannière prête déposée par l'annonceur, à la taille exacte de l'emplacement : affichée telle quelle, cliquable, sans texte ajouté
  function renderBanner(host, ad, fmt, bn) {
    var url = ad.click ? httpsOnly(ad.click) : '';
    var wrap = el(url ? 'a' : 'div', 'afl-bn');
    if (url) { wrap.href = url; wrap.target = '_blank'; wrap.rel = 'sponsored nofollow noopener'; }
    var i = el('img'); i.src = bn; i.alt = ad.title || ''; i.width = ad.banner.w; i.height = ad.banner.h; i.style.maxWidth = ad.banner.w + 'px'; wrap.appendChild(i);
    wrap.appendChild(el('span', 'afl-tag', ad.label || 'Annonce'));
    host.textContent = ''; host.className = 'afl-ad afl-' + fmt; host.appendChild(wrap);
    if (fmt === 'sticky') {
      var x = el('button', 'afl-close', '×'); x.type = 'button'; x.setAttribute('aria-label', 'Fermer');
      x.addEventListener('click', function (e) { e.preventDefault(); e.stopPropagation(); host.remove(); try { sessionStorage.setItem('afl_sticky_closed', '1'); } catch (er) { /* tant pis */ } });
      host.appendChild(x);
    }
    watch(wrap, ad);
  }

  function render(host, ad, fmt) {
    var bn = (fmt === 'banner' || fmt === 'sticky') && ad.banner ? httpsOnly(ad.banner.url) : '';
    if (bn) return renderBanner(host, ad, fmt, bn);
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
      var trk = el('div', 'afl-trk'); pics.forEach(function (u3) { trk.appendChild(media(u3)); }); wrap.appendChild(trk);
    } else if (img) { wrap.appendChild(media(img)); }
    var b = el('div', 'afl-b');
    // qui parle : logo, marque, « Sponsorisé · domaine » (16/11/2026)
    var br = ad.brand || {};
    if (br.name) {
      var h = el('div', 'afl-h'), lg = httpsOnly(br.logo || '');
      if (lg) { var li = el('img'); li.src = lg; li.alt = ''; li.loading = 'lazy'; h.appendChild(li); }
      var nm = el('span'); nm.appendChild(el('b', '', br.name)); nm.appendChild(el('small', '', 'Sponsorisé' + (br.domain ? ' · ' + br.domain : ''))); h.appendChild(nm);
      b.appendChild(h);
    }
    b.appendChild(el('div', 'afl-t', ad.title));
    if (ad.text) b.appendChild(el('div', 'afl-x', ad.text));
    if (ad.cta && url) b.appendChild(el('span', 'afl-go', ad.cta));
    wrap.appendChild(b);
    host.textContent = '';
    host.className = 'afl-ad afl-' + fmt;
    if (fmt === 'carousel' && pics.length > 1) host.className += ' afl-car';
    if ((fmt === 'interstitial' || fmt === 'rewarded') && PV) { host.className += ' afl-pvfs'; host.appendChild(wrap); return; }
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

  // l'emplacement prévient la page : rempli (afl:filled) ou vide (afl:empty), par exemple pour remettre un encart maison (17/11/2026)
  function tell(host, ev) { try { host.dispatchEvent(new CustomEvent(ev, { bubbles: true })); } catch (e) { /* ancien navigateur */ } }
  function empty(host) { host.hidden = true; tell(host, 'afl:empty'); }
  function load(host) {
    var pub = host.getAttribute('data-pub') || '', fmt = host.getAttribute('data-format') || 'native', slot = host.getAttribute('data-slot') || 'main';
    if (!/^ap_[a-z0-9]{10}$/.test(pub) && !/^[a-z0-9_]{2,24}$/.test(pub)) { empty(host); return; }
    if (!FORMATS[fmt]) { empty(host); return; }
    if (fmt === 'sticky') { try { if (sessionStorage.getItem('afl_sticky_closed')) { empty(host); return; } } catch (e) { /* tant pis */ } }
    var q = 'pub=' + encodeURIComponent(pub) + '&fmt=' + encodeURIComponent(fmt) + '&slot=' + encodeURIComponent(slot) + '&vid=' + encodeURIComponent(VID) + '&lang=' + encodeURIComponent((navigator.language || '').slice(0, 2));
    if (fmt === 'banner' || fmt === 'sticky') {
      var size = host.getAttribute('data-size') || '';
      if (!SIZES[size]) { var w = fmt === 'sticky' ? (window.innerWidth || 0) : (host.getBoundingClientRect().width || host.parentNode && host.parentNode.clientWidth || 0); size = w >= 728 ? '728x90' : (fmt === 'sticky' ? '320x50' : '320x100'); }
      q += '&size=' + size;   // une bannière prête de cette taille est préférée par le serveur
    }
    fetch(API + '/serve?' + q, { cache: 'no-store' }).then(function (r) { return r.json(); }).then(function (j) {
      if (!j || !j.ok || !j.ad) { empty(host); return; } // aucune annonce pour ce visiteur : l'emplacement reste vide
      css(); render(host, j.ad, fmt); tell(host, 'afl:filled');
    }).catch(function () { empty(host); });
  }

  // aperçu exact d'une annonce (formulaire d'Afrolook Ads) : même rendu que chez les partenaires, sans requête ni comptage
  window.AflAdsPreview = { render: function (host, ad, fmt) { css(); PV = true; try { render(host, ad, fmt); } finally { PV = false; } } };

  // remplit les emplacements pas encore traités (un emplacement n'est jamais rempli deux fois) ; 3 emplacements au plus par page.
  // Sites qui changent de page sans rechargement (React, Vue, Next.js) : appeler window.AflAds.fill() après chaque changement de page (17/11/2026).
  function init() {
    var hosts = Array.prototype.slice.call(document.querySelectorAll('ins.afl-ad')), done = 0, fresh = [];
    hosts.forEach(function (h) { if (h.getAttribute('data-afl')) done++; else fresh.push(h); });
    fresh.forEach(function (h) { h.setAttribute('data-afl', '1'); if (done < MAX_SLOTS) { done++; load(h); } else empty(h); }); // règle : 3 emplacements au plus par page
  }
  window.AflAds = { fill: init };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
