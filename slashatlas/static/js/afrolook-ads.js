(function () {
  'use strict';
  var L = (document.body && document.body.dataset.lang) || 'fr';
  var fr = L !== 'en';
  var IOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
  var AND = /Android/.test(navigator.userAgent);
  var STORE_IOS = 'https://apps.apple.com/gh/app/afrolook/id6811423047';
  var STORE_AND = 'https://play.google.com/store/apps/details?id=com.afrotok.afrotok';

  var PHOTOS = [
    '/img/afl/intro1.jpg', '/img/afl/intro2.jpg', '/img/afl/intro3.jpg',
    '/img/afl/intro4.jpg', '/img/afl/intro5.jpg', '/img/afl/intro6.jpg', '/img/afl/intro7.jpg'
  ];

  var MFR = [
    'Tu postes des vidéos ? Afrolook te paie tes vues',
    'Des vues sur TikTok sans rémunération ? Essaie Afrolook',
    'Instagram ne te paie pas tes vues. Afrolook, oui.',
    'Chaque vue sur Afrolook = une pièce de plus',
    'Monétisation sans seuil, dès ta première vue. Gratuit.',
    'Chacune de tes vues a de la valeur sur Afrolook',
    'Afrolook transforme tes vues en revenus réels',
    'Tu postes sur Instagram. Tu gagnes sur Afrolook.',
    'Afrolook te paie dès tes premières vues',
    'Tu filmes déjà. Autant être payé pour ça.',
    'Toutes tes vues sur Afrolook = pièces dans ton portefeuille',
    'Poste comme sur TikTok. Gagne comme nulle part.',
    'Tes likes = de vraies pièces sur Afrolook',
    '100 likes sur Afrolook = 100 pièces dans ton compte',
    'Chaque like sur Afrolook = une pièce de plus',
    'Likes + vues = argent réel sur Afrolook',
    'Sur Afrolook, tes abonnés te font vraiment gagner',
    'Tes likes ne disparaissent pas. Ils deviennent tes gains.',
    'Afrolook : le réseau qui dit merci à tes likes',
    'Crée ta carte créateur sur Afrolook',
    'Ta carte Afrolook : ton identité de créateur, vendable',
    'Les créateurs pro ont une carte. La tienne est prête.',
    'Afrolook : crée et vends ta carte de créateur numérique',
    'Ta carte créateur Afrolook = ta marque personnelle',
    'Partage ta carte créateur. Développe ton audience.',
    'Afrolook : le réseau social qui paie ses créateurs',
    'Crée ton compte Afrolook. Commence à gagner.',
    'Rejoins des milliers de créateurs rémunérés',
    'Partage. Crée. Gagne. C’est Afrolook.',
    'Afrolook, c’est TikTok mais tes vues sont payées.',
    'Instagram, TikTok : tes vues ne t’enrichissent pas. Afrolook, si.',
    'Créateur de contenu ? Afrolook est fait pour toi.',
    'Afrolook : monétise ton contenu dès le premier jour',
    'Télécharge Afrolook. Poste. Encaisse.',
    'Rejoins Afrolook et transforme ta créativité en argent',
    'Sur Afrolook, chaque création vaut quelque chose',
    'Ton talent mérite d’être rémunéré. C’est Afrolook.',
    'Commence à monétiser sur Afrolook dès aujourd’hui',
    'Afrolook : le réseau africain des créateurs',
    'Exprime-toi. Monétise. Grandis. Sur Afrolook.',
    'Ta créativité a une valeur. Afrolook te la paie.',
    'Rejoins la communauté Afrolook et commence à gagner',
    'Afrolook : crée, partage et gagne de l’argent réel',
    'Sur Afrolook, vues, likes et cartes = revenus',
    'Afrolook récompense chaque créateur',
    'Poste tes vidéos sur Afrolook. Tes vues te paient.',
    'Sois payé pour ce que tu crées. Télécharge Afrolook.',
    'Afrolook : plus qu’un réseau, une source de revenus',
    'Créateur débutant ou pro ? Afrolook te rémunère.',
    'Sur Afrolook, tes followers valent de l’argent.',
    'Lance-toi sur Afrolook : zéro abonné requis',
    'Afrolook : la monétisation accessible à tous',
    'Tes vidéos ont de la valeur. Rejoins Afrolook.',
    'Afrolook : vues + likes + cartes = pièces dans ton compte',
    'Monétise sur Afrolook. Pas de minimum requis.',
    'Afrolook : le réseau social où créer, c’est gagner',
    'Afrolook : la plateforme africaine des créateurs',
    'Sois payé pour tes vues. Télécharge Afrolook.'
  ];

  var MEN = [
    'Post videos? Afrolook pays you for every view',
    'Views on TikTok with nothing? Try Afrolook',
    "Instagram doesn't pay your views. Afrolook does.",
    'Every view on Afrolook = one more coin',
    'Earn from day one, no threshold. Free to join.',
    'Every single view is worth something on Afrolook',
    'Afrolook turns your views into real income',
    'Post on Instagram. Earn on Afrolook.',
    'Afrolook pays you from your very first views',
    "You're already filming. Might as well get paid.",
    'All your views on Afrolook = coins in your wallet',
    'Post like TikTok. Earn like nowhere else.',
    'Your likes = real coins on Afrolook',
    '100 likes on Afrolook = 100 coins in your account',
    'Every like on Afrolook = one more coin',
    'Likes + views = real money on Afrolook',
    'On Afrolook, your followers actually make you money',
    "Your likes don't disappear. They become earnings.",
    'Afrolook: the network that rewards your likes',
    'Create your creator card on Afrolook',
    'Your Afrolook card: your creator identity, sellable',
    'Pro creators have a card. Yours is ready.',
    'Afrolook: create and sell your digital creator card',
    'Your Afrolook creator card = your personal brand',
    'Share your creator card. Grow your audience.',
    'Afrolook: the social network that pays its creators',
    'Create your Afrolook account. Start earning.',
    'Join thousands of paid creators',
    "Share. Create. Earn. That's Afrolook.",
    'Afrolook is like TikTok, but your views are paid.',
    "Instagram, TikTok: your views don't pay you. Afrolook does.",
    'Content creator? Afrolook is made for you.',
    'Afrolook: monetize your content from day one',
    'Download Afrolook. Post. Cash out.',
    'Join Afrolook and turn your creativity into money',
    'On Afrolook, every creation is worth something',
    "Your talent deserves to be paid. That's Afrolook.",
    'Start monetizing on Afrolook today',
    'Afrolook: the African network for creators',
    'Express yourself. Monetize. Grow. On Afrolook.',
    'Your creativity has value. Afrolook pays you for it.',
    'Join the Afrolook community and start earning',
    'Afrolook: create, share and earn real money',
    'On Afrolook, views, likes and cards = revenue',
    'Afrolook rewards every creator',
    'Post your videos on Afrolook. Your views pay you.',
    'Get paid for what you create. Download Afrolook.',
    'Afrolook: more than a network, a source of income',
    'Beginner or pro creator? Afrolook pays you.',
    'On Afrolook, your followers are worth money.',
    'Start on Afrolook: zero followers needed',
    'Afrolook: monetization accessible to all',
    'Your videos have value. Join Afrolook.',
    'Afrolook: views + likes + cards = coins in your account',
    'Monetize on Afrolook. No minimum required.',
    'Afrolook: the social network where creating means earning',
    'Afrolook: the African platform for creators',
    'Get paid for your views. Download Afrolook.'
  ];

  var _idx = Math.floor(Math.random() * MFR.length);
  function nextMsg(isFr) { _idx = (_idx + 1) % MFR.length; return (isFr ? MFR : MEN)[_idx]; }
  function pickPhoto() { return PHOTOS[Math.floor(Math.random() * PHOTOS.length)]; }
  function storeUrl() { return IOS ? STORE_IOS : STORE_AND; }
  function ctaTxt(isFr) { return isFr ? 'Télécharger Afrolook' : 'Download Afrolook'; }
  function storeLbl(isFr) {
    if (IOS) return isFr ? 'Disponible sur l’App Store' : 'Available on the App Store';
    return isFr ? 'Disponible sur Google Play' : 'Available on Google Play';
  }
  function track(fmt, type) { try { window.saTrack && window.saTrack('afl_' + type, { fmt: fmt }); } catch (e) {} }

  function buildRect(isFr) {
    var msg = nextMsg(isFr), photo = pickPhoto(), url = storeUrl();
    return '<a class="afl-banner afl-rect" href="' + url + '" target="_blank" rel="noopener sponsored" data-afl="rect">' +
      '<span class="afl-spon">' + (isFr ? 'Sponsorisé' : 'Sponsored') + '</span>' +
      '<div class="afl-r-img" style="background-image:url(' + photo + ')"></div>' +
      '<div class="afl-r-body">' +
        '<span class="afl-badge">Afrolook</span>' +
        '<p class="afl-msg">' + msg + '</p>' +
        '<span class="afl-store">' + storeLbl(isFr) + '</span>' +
        '<span class="afl-cta">' + ctaTxt(isFr) + '</span>' +
      '</div>' +
    '</a>';
  }

  function buildLb(isFr) {
    var msg = nextMsg(isFr), photo = pickPhoto(), url = storeUrl();
    return '<a class="afl-banner afl-lb" href="' + url + '" target="_blank" rel="noopener sponsored" data-afl="lb">' +
      '<span class="afl-spon">' + (isFr ? 'Sponsorisé' : 'Sponsored') + '</span>' +
      '<div class="afl-lb-img" style="background-image:url(' + photo + ')"></div>' +
      '<div class="afl-lb-body">' +
        '<span class="afl-badge">Afrolook</span>' +
        '<p class="afl-msg">' + msg + '</p>' +
        '<span class="afl-store">' + storeLbl(isFr) + '</span>' +
      '</div>' +
      '<span class="afl-cta afl-cta-lb">' + ctaTxt(isFr) + '</span>' +
    '</a>';
  }

  function buildNativeCard(isFr) {
    var url = storeUrl(), photo = pickPhoto(), msg = nextMsg(isFr);
    return '<a class="cl" href="' + url + '" target="_blank" rel="noopener sponsored" data-afl="native">' +
      '<div class="poster img" style="--ar:4/5">' +
        '<img src="' + photo + '" alt="" loading="lazy" decoding="async">' +
        '<span class="tag">' + (isFr ? 'Sponsorisé' : 'Sponsored') + '</span>' +
        '<img class="afl-app-logo" src="/img/afl/logo.png" alt="Afrolook">' +
      '</div>' +
    '</a>' +
    '<div class="cb">' +
      '<div class="code">Afrolook <span class="afl-native-spon">' + (isFr ? 'Sponsorisé' : 'Sponsored') + '</span></div>' +
      '<h3><a href="' + url + '" target="_blank" rel="noopener sponsored" data-afl="native">' + msg + '</a></h3>' +
      '<div class="meta"><span>' + storeLbl(isFr) + '</span></div>' +
      '<div class="acts"><a class="btn afl-btn-dl sm" href="' + url + '" target="_blank" rel="noopener sponsored" data-afl="native">' + ctaTxt(isFr) + '</a></div>' +
    '</div>';
  }

  function buildLoad(isFr) {
    var msg = nextMsg(isFr), photo = pickPhoto(), url = storeUrl();
    return '<a class="afl-banner afl-load" href="' + url + '" target="_blank" rel="noopener sponsored" data-afl="load">' +
      '<span class="afl-spon">' + (isFr ? 'Sponsorisé' : 'Sponsored') + '</span>' +
      '<div class="afl-l-img" style="background-image:url(' + photo + ')"><img class="afl-app-logo afl-app-logo-sm" src="/img/afl/logo.png" alt=""></div>' +
      '<div class="afl-l-body">' +
        '<span class="afl-badge afl-badge-sm">' + (isFr ? 'Afrolook · Publicité' : 'Afrolook · Ad') + '</span>' +
        '<p class="afl-msg afl-msg-sm">' + msg + '</p>' +
        '<span class="afl-cta afl-cta-sm">' + ctaTxt(isFr) + ' →</span>' +
      '</div>' +
    '</a>';
  }

  // ───────── Annonces des annonceurs (moteur Afrolook Ads) ─────────
  // Le moteur d'Afrolook CHOISIT l'annonce (catégories acceptées par SlashAtlas, ciblage de l'annonceur), la SIGNE et COMPTE les vues et les clics :
  // ce script se contente de l'afficher. La vue part avec le jeton une fois l'annonce visible à moitié pendant la durée du format ; le clic passe
  // par le lien d'Afrolook (adsGo). L'annonceur retrouve ses chiffres dans son espace sur afrolookmedia.com, quelle que soit la plateforme.
  var API = 'https://us-central1-afrolooki.cloudfunctions.net';
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
  var ENGINE_FMT = { native: 'native', rect: 'banner', lb: 'banner', load: 'banner' };
  var _slotN = 0;
  // taille standard de l'emplacement (comme AdMob) : si l'annonce a une bannière prête à cette taille, le moteur la renvoie
  function sizeOf(fmt) { return fmt === 'lb' ? (window.innerWidth >= 760 ? '728x90' : '320x100') : fmt === 'rect' ? '300x250' : fmt === 'load' ? '320x100' : ''; }
  function serveAd(fmt) {
    return new Promise(function (res) {
      var done = false;
      function end(ad) { if (done) return; done = true; res(ad); }
      setTimeout(function () { end(null); }, 6000);
      var q = 'pub=slashatlas&fmt=' + (ENGINE_FMT[fmt] || 'banner') + '&slot=' + encodeURIComponent('sa-' + fmt + (_slotN++)) + '&vid=' + encodeURIComponent(VID) + '&lang=' + (fr ? 'fr' : 'en') + (sizeOf(fmt) ? '&size=' + sizeOf(fmt) : '');
      fetch(API + '/adsServe?' + q, { cache: 'no-store' }).then(function (r) { return r.json(); })
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
  function renderWeb(el, fmt, a) {
    el.innerHTML = webBuild(fmt, a, fr); el.hidden = false;
    if (fmt === 'native') el.removeAttribute('aria-hidden');
    track('web_' + fmt, 'imp');
    var links = el.querySelectorAll('[data-web]');
    for (var i = 0; i < links.length; i++) links[i].addEventListener('click', function () { track('web_' + fmt, 'click'); }); // le clic d'annonceur est compté par le lien d'Afrolook lui-même
    watchView(el, a);
  }
  // Annonces d'annonceurs : jusqu'à 6 encarts par session, à chaque visite, sur les pages clés (1 par page)
  var MAX_WEB = 6;
  function allowedWeb() {
    if (!KEY_PAGE || pageShown) return false;
    try { return parseInt(sessionStorage.getItem('sa_web_n') || '0', 10) < MAX_WEB; } catch (e) { return true; }
  }
  function countedWeb() { pageShown = true; try { sessionStorage.setItem('sa_web_n', String(parseInt(sessionStorage.getItem('sa_web_n') || '0', 10) + 1)); } catch (e) {} }

  // Afrolook reste discret : seulement lors de la toute première visite (session), sur les pages clés
  // (accueil, fiche commande, page Générer), 1 encart par page et 3 au maximum sur la session. Ensuite plus rien.
  var MAX_SESSION = 3, pageShown = false;
  var KEY_PAGE = /^\/(en\/)?(c\/[^\/]+\/|generer\/|generate\/)?$/.test(location.pathname);
  function allowed() {
    if (!KEY_PAGE || pageShown) return false;
    try {
      if (!localStorage.getItem('sa_afl_first')) { localStorage.setItem('sa_afl_first', String(Date.now())); sessionStorage.setItem('sa_afl_sess', '1'); }
      else if (sessionStorage.getItem('sa_afl_sess') !== '1') return false;
      return parseInt(sessionStorage.getItem('sa_afl_n') || '0', 10) < MAX_SESSION;
    } catch (e) { return false; }
  }
  function counted() { pageShown = true; try { sessionStorage.setItem('sa_afl_n', String(parseInt(sessionStorage.getItem('sa_afl_n') || '0', 10) + 1)); } catch (e) {} }

  function renderIn(el, buildFn) {
    el.innerHTML = buildFn(fr);
    el.hidden = false;
    var a = el.querySelector('[data-afl]');
    if (a) {
      var fmt = a.dataset.afl;
      track(fmt, 'imp');
      a.addEventListener('click', function () { track(fmt, 'click'); }, { once: true });
    }
  }

  // Un annonceur d'abord ; à défaut, la pub maison Afrolook (avec sa discrétion habituelle). Renvoie une promesse : true si un encart a été affiché.
  function showPromo(el, fmt) {
    if (!allowed()) return false;
    counted();
    if (fmt === 'native') { renderIn(el, buildNativeCard); el.removeAttribute('aria-hidden'); return true; }
    if (fmt === 'load') { renderIn(el, buildLoad); return true; }
    renderIn(el, fmt === 'lb' ? buildLb : buildRect);
    return true;
  }
  // les emplacements d'une page passent l'un après l'autre : un seul encart par page, donc inutile de demander une annonce (et un jeton) pour les suivants
  var _queue = Promise.resolve();
  function show(el, fmt) {
    var p = _queue.then(function () {
      if (!allowedWeb()) return showPromo(el, fmt);
      return serveAd(fmt).then(function (ad) {
        if (ad && allowedWeb()) { countedWeb(); renderWeb(el, fmt, ad); return true; }
        return showPromo(el, fmt);
      });
    });
    _queue = p.catch(function () {});
    return p;
  }

  window.saAfrolookAds = {
    fill: function (el) {
      show(el, el.dataset.ad).then(function (ok) { if (!ok) { el.hidden = true; el.innerHTML = ''; } });
    },
    showCopyToast: function () {}
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

