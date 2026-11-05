(function () {
  'use strict';
  // SlashAtlas n'affiche QUE des annonces envoyées par la régie Afrolook Ads (diffuseur externe validé). Aucune pub n'est écrite dans ce script :
  // quand la régie n'a aucune annonce pour un emplacement, il reste vide et caché.
  var L = (document.body && document.body.dataset.lang) || 'fr';
  var fr = L !== 'en';

  function track(fmt, type) { try { window.saTrack && window.saTrack('afl_' + type, { fmt: fmt }); } catch (e) {} }

  // ───────── Annonces des annonceurs (moteur Afrolook Ads) ─────────
  // Le moteur d'Afrolook CHOISIT l'annonce (catégories acceptées par SlashAtlas, ciblage de l'annonceur), la SIGNE et COMPTE les vues et les clics :
  // ce script se contente de l'afficher. La vue part avec le jeton une fois l'annonce visible à moitié pendant la durée du format ; le clic passe
  // par le lien d'Afrolook (adsGo). L'annonceur retrouve ses chiffres dans son espace sur afrolookmedia.com, quelle que soit la plateforme.
  // Diffuseur externe validé de la régie (identifiant publicitaire ap_…) : les affichages sont mesurés et rémunérés sur le profil diffuseur du propriétaire.
  // Appels à la nouvelle API (comme la balise des autres sites), plus aux anciennes fonctions Firebase.
  var API = 'https://afrolookmedia.com/ads/api';
  var PUB_ID = 'ap_2a4tcdjohi';
  var DNT = navigator.doNotTrack === '1' || navigator.globalPrivacyControl === true;
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function safe(u) { try { var x = new URL(u); return x.protocol === 'https:' ? x.href : ''; } catch (e) { return ''; } }
  function cut(t, n) { t = String(t || '').replace(/\s+/g, ' ').trim(); return t.length > n ? t.slice(0, n - 1).trim() + '…' : t; }
  var VID = (function () {
    try {
      var v = localStorage.getItem('adsvid');
      if (!v) { v = (window.crypto && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2) + Date.now().toString(36)).replace(/[^A-Za-z0-9-]/g, ''); localStorage.setItem('adsvid', v); }
      return v;
    } catch (e) { return 'anon-' + Math.random().toString(36).slice(2, 12) + Date.now().toString(36); }
  })();
  // format du moteur selon l'emplacement : carte dans une liste = native ; rectangle, bandeau et chargement = bannière
  // affiche = poster, carrousel, vidéo, bandeau collant (sticky) et plein écran (inter = interstitiel) : tous les formats du moteur, chacun avec son prix et donc sa rémunération
  var ENGINE_FMT = { native: 'native', rect: 'banner', lb: 'banner', load: 'banner', poster: 'poster', carousel: 'carousel', video: 'video', sticky: 'sticky', inter: 'interstitial' };
  var _slotN = 0;
  // taille standard de l'emplacement (comme AdMob) : si l'annonce a une bannière prête à cette taille, le moteur la renvoie
  function sizeOf(fmt) { return fmt === 'lb' ? (window.innerWidth >= 760 ? '728x90' : '320x100') : fmt === 'rect' ? '300x250' : fmt === 'load' ? '320x100' : ''; }
  function serveAd(fmt) {
    return new Promise(function (res) {
      var done = false;
      function end(ad) { if (done) return; done = true; res(ad); }
      setTimeout(function () { end(null); }, 6000);
      var q = 'pub=' + PUB_ID + '&fmt=' + (ENGINE_FMT[fmt] || 'banner') + '&slot=' + encodeURIComponent('sa-' + fmt + (_slotN++)) + '&vid=' + encodeURIComponent(VID) + '&lang=' + (fr ? 'fr' : 'en') + (sizeOf(fmt) ? '&size=' + sizeOf(fmt) : '');
      fetch(API + '/serve?' + q, { cache: 'no-store' }).then(function (r) { return r.json(); })
        .then(function (j) { end(j && j.ok && j.ad && j.ad.id && j.ad.title && j.ad.token ? j.ad : null); }).catch(function () { end(null); });
    });
  }
  // Formats d'annonces d'annonceurs, comme AdMob : grande bannière (lb), rectangle moyen 300×250 (rect), carte native (native), bandeau de chargement (load).
  // L'image est TOUJOURS visible en entier (jamais rognée) : elle est posée sur une copie floutée d'elle-même, quel que soit son format (carré, paysage, portrait).
  function media(photo) {
    return photo ? '<span class="afa-bg" style="background-image:url(\'' + photo + '\')"></span><img class="afa-img" src="' + photo + '" alt="" loading="lazy" decoding="async">' : '<span class="afa-ph">Pub</span>';
  }
  // bannière prête à l'emploi : l'image dessinée par l'annonceur, en entier, cliquable (rien d'ajouté sauf la mention « Sponsorisé »)
  function bannerBuild(fmt, a, isFr) {
    var url = esc(safe(a.click) || 'https://afrolookmedia.com/ads/'), w = +a.banner.w || 0, h = +a.banner.h || 0;
    return '<a class="afa afa-bn" href="' + url + '" target="_blank" rel="noopener sponsored nofollow" data-afl="web_' + fmt + '" data-web="' + esc(a.id) + '" style="max-width:' + w + 'px"><span class="afa-spon afa-spon-bn">' + (isFr ? 'Sponsorisé' : 'Sponsored') + '</span>' +
      '<img src="' + esc(safe(a.banner.url)) + '" width="' + w + '" height="' + h + '" alt="' + esc(cut(a.title, 80)) + '" loading="lazy" decoding="async"></a>';
  }
  function webBuild(fmt, a, isFr) {
    if (fmt !== 'native' && a.banner && a.banner.url && safe(a.banner.url)) return bannerBuild(fmt, a, isFr);
    var url = esc(safe(a.click) || 'https://afrolookmedia.com/ads/'), photo = esc(safe((a.media && (a.media.thumb || a.media.url)) || '').replace(/[')"\\\s]/g, ''));
    var title = esc(cut(a.title, 90)), text = esc(cut(a.text, 140)), cta = esc(a.cta || (isFr ? 'En savoir plus' : 'Learn more')), spon = isFr ? 'Sponsorisé' : 'Sponsored', badge = isFr ? 'Annonce' : 'Ad';
    var open = function (cls) { return '<a' + (cls ? ' class="' + cls + '"' : '') + ' href="' + url + '" target="_blank" rel="noopener sponsored nofollow" data-afl="web_' + fmt + '" data-web="' + esc(a.id) + '">'; };
    if (fmt === 'native') {
      return open('cl') + '<div class="poster img" style="--ar:4/5">' + media(photo) + '<span class="tag">' + spon + '</span></div></a>' +
        '<div class="cb"><div class="code">' + badge + ' <span class="afl-native-spon">' + spon + '</span></div>' +
        '<h3>' + open('') + title + '</a></h3>' + (text ? '<div class="meta"><span>' + text + '</span></div>' : '') +
        '<div class="acts">' + open('btn afl-btn-dl sm') + cta + '</a></div></div>';
    }
    var body = '<div class="afa-body"><span class="afa-badge">' + badge + '</span><p class="afa-t">' + title + '</p>' + (text ? '<p class="afa-d">' + text + '</p>' : '') + '</div>';
    if (fmt === 'load') return open('afa afa-load') + '<span class="afa-spon">' + spon + '</span><div class="afa-media">' + media(photo) + '</div>' + body + '</a>';
    if (fmt === 'lb') return open('afa afa-lb') + '<span class="afa-spon">' + spon + '</span><div class="afa-media">' + media(photo) + '</div>' + body + '<span class="afa-cta">' + cta + '</span></a>';
    return open('afa afa-rect') + '<span class="afa-spon">' + spon + '</span><div class="afa-media">' + media(photo) + '</div>' + body + '<span class="afa-cta">' + cta + '</span></a>';
  }
  function imagesOf(a) {
    var raw = (a.media && a.media.images) || [], out = [];
    for (var i = 0; i < raw.length && out.length < 5; i++) { var u = safe(typeof raw[i] === 'string' ? raw[i] : raw[i] && raw[i].url); if (u) out.push(u); }
    if (!out.length) { var one = safe(a.media && (a.media.url || a.media.thumb)); if (one) out.push(one); }
    return out;
  }
  // nouveaux formats : affiche (4:5), carrousel (2 à 5 images à faire glisser), vidéo (15 s au plus, lancée sans son), bandeau collant, plein écran
  function richBuild(fmt, a, isFr) {
    var url = esc(safe(a.click) || 'https://afrolookmedia.com/ads/'), title = esc(cut(a.title, 90)), text = esc(cut(a.text, 140)), cta = esc(a.cta || (isFr ? 'En savoir plus' : 'Learn more'));
    var spon = isFr ? 'Sponsorisé' : 'Sponsored', badge = isFr ? 'Annonce' : 'Ad';
    var attrs = ' href="' + url + '" target="_blank" rel="noopener sponsored nofollow" data-afl="web_' + fmt + '" data-web="' + esc(a.id) + '"';
    var body = '<div class="afa-body"><span class="afa-badge">' + badge + '</span><p class="afa-t">' + title + '</p>' + (text ? '<p class="afa-d">' + text + '</p>' : '') + '</div>';
    var imgs = imagesOf(a), first = esc(imgs[0] || safe((a.media && (a.media.thumb || a.media.url)) || ''));
    if (fmt === 'video' && a.media && a.media.type === 'video' && safe(a.media.url)) {
      var dur = +a.media.duration || 0;
      return '<a class="afa afa-poster afa-vid"' + attrs + '><span class="afa-spon">' + spon + '</span><div class="afa-media afa-vmedia"><video muted playsinline preload="metadata" ' + (first ? 'poster="' + first + '" ' : '') + 'src="' + esc(safe(a.media.url)) + '"></video>' +
        (dur ? '<span class="afa-dur">0:' + (dur < 10 ? '0' : '') + dur + '</span>' : '') + '</div>' + body + '<span class="afa-cta">' + cta + '</span></a>';
    }
    if (fmt === 'carousel' && imgs.length > 1) {
      var slides = imgs.map(function (u) { return '<a class="afa-slide"' + attrs + '><span class="afa-bg" style="background-image:url(\'' + esc(u) + '\')"></span><img class="afa-img" src="' + esc(u) + '" alt="" loading="lazy" decoding="async"></a>'; }).join('');
      return '<div class="afa afa-poster afa-car"><span class="afa-spon">' + spon + '</span><div class="afa-track">' + slides + '</div>' + body + '<a class="afa-cta"' + attrs + '>' + cta + '</a></div>';
    }
    // affiche (et repli du carrousel à une seule image, de la vidéo sans fichier vidéo, du plein écran)
    var kind = fmt === 'inter' ? 'afa-inter' : fmt === 'sticky' ? 'afa-stk' : 'afa-poster';
    return '<a class="afa ' + kind + '"' + attrs + '><span class="afa-spon">' + spon + '</span><div class="afa-media">' + media(first) + '</div>' + body + '<span class="afa-cta">' + cta + '</span></a>';
  }
  // vidéo : se lance (sans son) quand elle est visible à moitié, s'arrête dès qu'elle ne l'est plus ; la lecture complète est comptée par le moteur (événement « complete »)
  function watchVideo(el, a) {
    var v = el.querySelector('video'); if (!v) return;
    var done = false;
    v.addEventListener('ended', function () {
      if (done || DNT) return; done = true;
      try { fetch(a.event, { method: 'POST', body: JSON.stringify({ t: a.token, e: 'complete', ms: Math.round((v.duration || 0) * 1000), vid: VID }), headers: { 'Content-Type': 'text/plain' }, keepalive: true }).catch(function () {}); } catch (e) {}
    });
    if (!('IntersectionObserver' in window)) return;
    new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (e.isIntersecting && e.intersectionRatio >= 0.5 && document.visibilityState === 'visible') { var p = v.play(); p && p.catch && p.catch(function () {}); } else v.pause();
      });
    }, { threshold: [0, 0.5, 1] }).observe(v);
  }
  // une vue = l'encart reste visible à moitié au moins, sans interruption, pendant la durée du format (le serveur recoupe cette durée avec l'heure d'émission du jeton)
  function watchView(el, a) {
    if (DNT) return; // « Ne pas suivre » : la vue n'est pas enregistrée pour ce visiteur
    var timer = 0, sent = false, io = null;
    function fire() {
      if (sent) return; sent = true; if (io) io.disconnect();
      try { fetch(a.event, { method: 'POST', body: JSON.stringify({ t: a.token, e: 'view', ms: a.viewMs + 50, vid: VID }), headers: { 'Content-Type': 'text/plain' }, keepalive: true }).catch(function () {}); } catch (e) {}
    }
    if (!('IntersectionObserver' in window)) { timer = setTimeout(fire, a.viewMs + 100); return; }
    io = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        clearTimeout(timer);
        if (e.isIntersecting && e.intersectionRatio >= 0.5 && document.visibilityState === 'visible') timer = setTimeout(function () { if (document.visibilityState === 'visible') fire(); }, a.viewMs + 50);
      });
    }, { threshold: [0, 0.5, 1] });
    io.observe(el);
  }
  var RICH = { poster: 1, carousel: 1, video: 1, sticky: 1, inter: 1 };
  function renderWeb(el, fmt, a) {
    el.innerHTML = RICH[fmt] ? richBuild(fmt, a, fr) : webBuild(fmt, a, fr); el.hidden = false;
    if (fmt === 'video') watchVideo(el, a);
    if (fmt === 'native') el.removeAttribute('aria-hidden');
    track('web_' + fmt, 'imp');
    var links = el.querySelectorAll('[data-web]');
    for (var i = 0; i < links.length; i++) links[i].addEventListener('click', function () { track('web_' + fmt, 'click'); }); // le clic d'annonceur est compté par le lien d'Afrolook lui-même
    watchView(el, a);
  }
  // Annonces d'annonceurs : jusqu'à 6 encarts par session, à chaque visite, sur les pages clés (1 par page)
  var MAX_WEB = 6;
  function nWeb() { try { return parseInt(sessionStorage.getItem('sa_web_n') || '0', 10); } catch (e) { return 0; } }
  // plein écran et bandeau collant : chacun une fois par session ; encart tardif (sous « Copié ») : un seul aussi ; le reste : un par page clé
  function allowedWeb(fmt, el) {
    if (fmt === 'sticky' || fmt === 'inter') { try { if (sessionStorage.getItem('sa_' + fmt) === '1') return false; } catch (e) {} return nWeb() < MAX_WEB; }
    if (el && el.hasAttribute('data-adlate')) { try { return sessionStorage.getItem('sa_late') !== '1' && nWeb() < MAX_WEB; } catch (e) { return true; } }
    if (!KEY_PAGE || pageShown) return false;
    try { return parseInt(sessionStorage.getItem('sa_web_n') || '0', 10) < MAX_WEB; } catch (e) { return true; }
  }
  function countedWeb(fmt, el) {
    if (fmt === 'sticky' || fmt === 'inter') { try { sessionStorage.setItem('sa_' + fmt, '1'); } catch (e) {} } else if (el && el.hasAttribute('data-adlate')) { try { sessionStorage.setItem('sa_late', '1'); } catch (e) {} } else pageShown = true; try { sessionStorage.setItem('sa_web_n', String(parseInt(sessionStorage.getItem('sa_web_n') || '0', 10) + 1)); } catch (e) {} }

  var pageShown = false;
  var KEY_PAGE = /^\/(en\/)?(c\/[^\/]+\/|generer\/|generate\/)?$/.test(location.pathname);   // pages clés : accueil, fiche commande, page Générer

  // les emplacements d'une page passent l'un après l'autre : un seul encart par page, donc inutile de demander une annonce (et un jeton) pour les suivants
  var _queue = Promise.resolve();
  function show(el, fmt) {
    var p = _queue.then(function () {
      if (!allowedWeb(fmt, el)) return false;   // aucune pub écrite ici : seulement ce que la régie Afrolook Ads envoie
      return serveAd(fmt).then(function (ad) {
        if (ad && allowedWeb(fmt, el)) { countedWeb(fmt, el); renderWeb(el, fmt, ad); return true; }
        return false;
      });
    });
    _queue = p.catch(function () {});
    return p;
  }

  // bandeau collant : en bas de l'écran sur les fiches de commande, fermable, une fois par session
  function mountSticky() {
    var host = document.createElement('div'); host.className = 'afa-stk-host'; host.hidden = true; document.body.appendChild(host);
    show(host, 'sticky').then(function (ok) {
      if (!ok) { host.remove(); return; }
      var x = document.createElement('button'); x.type = 'button'; x.className = 'afa-x'; x.setAttribute('aria-label', fr ? 'Fermer' : 'Close'); x.textContent = '✕';
      x.addEventListener('click', function () { host.remove(); }); host.appendChild(x);
    });
  }
  if (/^\/(en\/)?c\/[^\/]+\/$/.test(location.pathname)) setTimeout(mountSticky, 4000);
  // plein écran : au premier « Copié » de la session, fermable au bout de 3 secondes (le moteur limite à une fois toutes les 10 minutes par personne)
  var interDone = false, copies = 0;
  function showInter() {
    if (interDone) return; interDone = true;
    var host = document.createElement('div'); host.className = 'afa-inter-host'; host.hidden = true; document.body.appendChild(host);
    show(host, 'inter').then(function (ok) {
      if (!ok) { host.remove(); return; }
      var x = document.createElement('button'); x.type = 'button'; x.className = 'afa-x afa-x-inter'; x.disabled = true; host.appendChild(x);
      var n = 3; x.textContent = String(n);
      var t = setInterval(function () { n--; if (n > 0) { x.textContent = String(n); return; } clearInterval(t); x.disabled = false; x.textContent = '✕'; x.setAttribute('aria-label', fr ? 'Fermer' : 'Close'); }, 1000);
      x.addEventListener('click', function () { if (!x.disabled) host.remove(); });
    });
  }

  window.saAfrolookAds = {
    fill: function (el) {
      show(el, el.dataset.ad).then(function (ok) { if (!ok) { el.hidden = true; el.innerHTML = ''; } });
    },
    // plein écran à la 2e copie depuis une liste (jamais à la première, jamais sur la fiche où l'encart « Copié » s'affiche déjà)
    showCopyToast: function () { if (++copies >= 2) setTimeout(showInter, 2500); }
  };

  // Bannière pendant la génération : surveille #s-gen.loading
  (function () {
    var genBtn = document.getElementById('s-gen');
    var slot = document.getElementById('afl-gen-ad');
    if (!genBtn || !slot) return;
    var shown = false;
    var observer = new MutationObserver(function () {
      var busy = genBtn.classList.contains('loading');
      if (busy && !shown) {
        shown = true;
        show(slot, 'load').then(function (ok) { if (!ok) shown = false; });
      } else if (!busy && shown) {
        slot.hidden = true;
        slot.innerHTML = '';
        shown = false;
      }
    });
    observer.observe(genBtn, { attributes: true, attributeFilter: ['class'] });
  })();
})();

