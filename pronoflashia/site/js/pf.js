/* PronoFlash IA : script du navigateur. Rien n'est nécessaire pour lire les pronostics ; ce script ajoute
   l'heure locale, le consentement, la mesure sans cookie, les publicités et le compositeur de coupon. */
(function () {
  'use strict';
  var d = document, w = window;
  var $ = function (s, r) { return (r || d).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || d).querySelectorAll(s)); };
  var store = {
    get: function (k) { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } },
    set: function (k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* stockage bloqué */ } },
    sget: function (k) { try { return sessionStorage.getItem(k); } catch (e) { return null; } },
    sset: function (k, v) { try { sessionStorage.setItem(k, v); } catch (e) { /* stockage bloqué */ } }
  };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var tz = ''; try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch (e) { /* vieux navigateur */ }
  var path = location.pathname.replace(/\/$/, '') || '/';
  var UA = navigator.userAgent || '';
  var IOS = /iPad|iPhone|iPod/.test(UA);
  var EN = d.documentElement.lang === 'en', LANG = EN ? 'en' : 'fr', LOC = EN ? 'en-GB' : 'fr-FR';
  var L = EN ? {
    tzTitle: 'Local time', tzYou: 'your time zone', tzNote: 'Times shown in your time zone: ',
    cmp: '<p><b>Advertising</b><br>This site is free thanks to advertising. Our partners\' ads may use cookies to choose and measure ads. You can accept or refuse; the predictions stay the same. <a href="/en/privacy" style="color:var(--cy)">Learn more</a></p><div class="row"><button class="btn" type="button" data-c="1">Accept</button><button class="btn sec" type="button" data-c="0">Refuse</button></div>',
    msg: ['Football debates on Afrolook: share your take on the match', 'Share your tips with friends on Afrolook', 'Your likes turn into coins on Afrolook', 'Post videos? Afrolook pays you for your views', 'Afrolook: the African creators network'],
    sponsored: 'Sponsored', aflCta: 'Download for free', adTitle: 'Advertisement', copied: 'Link copied', all: 'All',
    myCoupon: 'My slip', sel: function (n) { return n > 1 ? 'selections' : 'selection'; }, view: 'View my slip', clearAria: 'Clear my slip', max5: 'A slip holds 5 selections at most',
    analysis: 'See details ›', choose: 'Pick your bets', remove: 'Remove',
    empty: 'Pick 2 to 5 bets. You can take several in the same match: the calculation accounts for it.',
    replace: function (a, b) { return 'Replace “' + a + '” with “' + b + '”'; }, moves: function (a, b) { return 'The slip goes from ' + a + '% to ' + b + '%'; },
    share: function (pc) { return 'My PronoFlash IA slip (' + pc + '% chance that everything wins):'; },
    probAll: 'Probability that everything wins', out100: function (pc) { return 'Out of 100 identical slips, about ' + pc + ' would win'; },
    wa: 'Share on WhatsApp', clear: 'Clear',
    followOn: function (n) { return '🔔 ' + n + ' followed'; }, followOff: function (n) { return '🔔 Follow ' + n; },
    pushT: "Get today's slips as notifications", pushS: 'One in the morning, one at noon, one in the evening. Turn them off any time.', pushBtn: 'Turn on',
    pushOkT: 'Notifications on: slips of the day, morning, noon and evening.', pushOffT: 'Notifications turned off.', pushBlocked: 'Notifications are blocked in your browser settings.', pushErr: 'Could not turn notifications on. Try again later.',
    teamOn: function (n) { return 'You will get an alert before ' + n + ' play.'; }, teamOff: function (n) { return 'Alerts for ' + n + ' turned off.'; },
    pwaT: 'Install PronoFlash IA on your phone', pwaS: 'One tap access, nothing to download from a store', pwaBtn: 'Install', pwaClose: 'Not now',
    pwaIosBtn: 'How?', pwaIos: 'Tap the Share button <b>⎙</b>, then “Add to Home Screen”.',
    ibxOpen: 'My notifications', ibxNone: 'Turn on notifications to get slips, big matches and football news here.', ibxEnable: 'Turn on notifications', ibxEmpty: 'No notification yet. They will appear here as soon as the next one is sent.',
    ibxMore: 'Show 10 more', ibxAll: 'Mark all as read', ibxOff: 'Turn notifications off', ibxUnread: function (n) { return n > 9 ? '9+ unread' : n + (n > 1 ? ' unread' : ' unread'); }, ibxErr: 'Could not load your notifications. Try again later.', ibxDenied: 'Notifications are blocked in your browser settings.', ibxNoSupport: 'This browser cannot receive notifications. On iPhone, add the site to your home screen first.', ibxRead: 'Read', ibxNew: 'New',
    wmT: 'Never miss the football news that matters', wmS: 'Turn on notifications and we tell you when something happens. Free, and you can switch them off any time.', wmEx: 'Examples of notifications', wmNow: 'now',
    wmN1t: "⚡ Today's slips: Arsenal – Chelsea", wmN1b: 'Cautious 2 matches 76% · Balanced 3 matches 58% chance that everything wins.',
    wmN2t: '⚔️ Classico: Real Madrid – FC Barcelona', wmN2b: 'Our pick and the latest news are inside.',
    wmN3t: '🌟 A rising talent is making noise', wmN3b: 'The press is talking about it. Our summary and the source link are inside.',
    wmBtn: 'Turn on notifications', wmInst: 'Install the app', wmLater: 'Maybe later', wmIosBtn: 'How to install?', wmIosNote: 'On iPhone, notifications work once the site is added to your home screen.',
    disclaimer: 'PronoFlash IA takes no bets, shows no odds and promises no winnings. 18+ · Play responsibly.', pct: '%'
  } : {
    tzTitle: 'Heure locale', tzYou: 'ton fuseau', tzNote: 'Heures affichées dans ton fuseau horaire : ',
    cmp: '<p><b>Publicités</b><br>Ce site est gratuit grâce à la publicité. Les publicités de nos partenaires peuvent utiliser des cookies pour choisir et mesurer les annonces. Tu peux accepter ou refuser ; les pronostics restent les mêmes. <a href="/confidentialite" style="color:var(--cy)">En savoir plus</a></p><div class="row"><button class="btn" type="button" data-c="1">Accepter</button><button class="btn sec" type="button" data-c="0">Refuser</button></div>',
    msg: ['Débats foot sur Afrolook : donne ton avis sur le match', 'Partage tes pronos entre amis sur Afrolook', 'Tes likes deviennent des pièces sur Afrolook', 'Tu postes des vidéos ? Afrolook te paie tes vues', 'Afrolook : le réseau africain des créateurs'],
    sponsored: 'Sponsorisé', aflCta: 'Télécharger gratuitement', adTitle: 'Publicité', copied: 'Lien copié', all: 'Tous',
    myCoupon: 'Mon coupon', sel: function (n) { return n > 1 ? 'sélections' : 'sélection'; }, view: 'Voir mon coupon', clearAria: 'Vider mon coupon', max5: 'Un coupon contient 5 sélections au plus',
    analysis: 'Voir détails ›', choose: 'Choisis tes paris', remove: 'Retirer',
    empty: 'Choisis 2 à 5 paris. Tu peux en prendre plusieurs dans un même match : le calcul en tient compte.',
    replace: function (a, b) { return 'Remplacer « ' + a + ' » par « ' + b + ' »'; }, moves: function (a, b) { return 'Le coupon passe de ' + a + ' % à ' + b + ' %'; },
    share: function (pc) { return 'Mon coupon PronoFlash IA (' + pc + ' % de chances que tout passe) :'; },
    probAll: 'Probabilité que tout passe', out100: function (pc) { return 'Sur 100 coupons identiques, environ ' + pc + ' passeraient'; },
    wa: 'Partager sur WhatsApp', clear: 'Vider',
    followOn: function (n) { return '🔔 ' + n + ' suivi'; }, followOff: function (n) { return '🔔 Suivre ' + n; },
    pushT: 'Reçois les coupons du jour en notification', pushS: 'Un le matin, un à midi, un le soir. Tu peux couper quand tu veux.', pushBtn: 'Activer',
    pushOkT: 'Notifications activées : coupons du jour, matin, midi et soir.', pushOffT: 'Notifications coupées.', pushBlocked: 'Les notifications sont bloquées dans les réglages de ton navigateur.', pushErr: "Impossible d'activer les notifications. Réessaie plus tard.",
    teamOn: function (n) { return 'Tu recevras une alerte avant les matchs de ' + n + '.'; }, teamOff: function (n) { return 'Alertes coupées pour ' + n + '.'; },
    pwaT: 'Installe PronoFlash IA sur ton téléphone', pwaS: 'Accès en un clic, rien à télécharger sur un store', pwaBtn: 'Installer', pwaClose: 'Plus tard',
    pwaIosBtn: 'Comment ?', pwaIos: 'Touche le bouton Partager <b>⎙</b>, puis « Sur l\'écran d\'accueil ».',
    ibxOpen: 'Mes notifications', ibxNone: 'Active les notifications pour recevoir ici les coupons, les gros matchs et les actus du football.', ibxEnable: 'Activer les notifications', ibxEmpty: 'Aucune notification pour le moment. Elles apparaîtront ici dès la prochaine.',
    ibxMore: 'Voir 10 de plus', ibxAll: 'Tout marquer comme lu', ibxOff: 'Désactiver les notifications', ibxUnread: function (n) { return n > 9 ? '9+ non lues' : n + (n > 1 ? ' non lues' : ' non lue'); }, ibxErr: 'Impossible de charger tes notifications. Réessaie plus tard.', ibxDenied: 'Les notifications sont bloquées dans les réglages de ton navigateur.', ibxNoSupport: "Ce navigateur ne peut pas recevoir de notifications. Sur iPhone, ajoute d'abord le site à l'écran d'accueil.", ibxRead: 'Lue', ibxNew: 'Nouveau',
    wmT: 'Ne rate plus les infos foot qui comptent', wmS: "Active les notifications : on te prévient quand ça bouge. Gratuit, et tu coupes quand tu veux.", wmEx: 'Exemples de notifications', wmNow: 'maintenant',
    wmN1t: '⚡ Coupons du jour : Arsenal – Chelsea', wmN1b: 'Prudent 2 matchs 76 % · Équilibré 3 matchs 58 % de chances que tout passe.',
    wmN2t: '⚔️ Classico : Real Madrid – FC Barcelone', wmN2b: "Notre pronostic et les dernières infos sont à l'intérieur.",
    wmN3t: '🌟 Une pépite fait parler', wmN3b: "La presse en parle. Notre résumé et le lien de la source sont à l'intérieur.",
    wmBtn: 'Activer les notifications', wmInst: "Installer l'appli", wmLater: 'Plus tard', wmIosBtn: 'Comment installer ?', wmIosNote: "Sur iPhone, les notifications fonctionnent une fois le site ajouté à l'écran d'accueil.",
    disclaimer: 'PronoFlash IA ne prend aucun pari, n\'affiche aucune cote et ne promet aucun gain. 18+ · Jouez de façon responsable.', pct: ' %'
  };
  var couponPath = (w.PF && w.PF.coupon) || (EN ? '/en/coupon' : '/coupon');

  /* ---------- heure locale ---------- */
  $$('time[data-t="hm"]').forEach(function (t) {
    var dt = new Date(t.getAttribute('datetime'));
    if (isNaN(dt)) return;
    t.textContent = dt.toLocaleTimeString(LOC, { hour: '2-digit', minute: '2-digit' });
    t.title = L.tzTitle + ' (' + (tz || L.tzYou) + ')';
  });
  $$('.tznote').forEach(function (n) { if (tz) n.textContent = L.tzNote + tz.replace(/_/g, ' ') + '.'; });

  /* ---------- consentement (UE et Royaume-Uni) ---------- */
  var NON_UE = /^Europe\/(Moscow|Istanbul|Minsk|Kiev|Kyiv|Chisinau|Belgrade|Skopje|Sarajevo|Tirane|Podgorica|Zurich|Simferopol|Volgograd|Samara|Kaliningrad|Saratov|Astrakhan|Ulyanovsk|Kirov)$/;
  var needsConsent = /^Europe\//.test(tz) && !NON_UE.test(tz);
  var consent = store.get('pf_consent');
  /* navigateur de l'administrateur : pubs tierces masquées (aucun affichage ni clic de soi-même, que les réseaux sanctionnent) */
  var ownerBrowser = store.get('pf_noads') === 1;
  var adsAllowed = function () { return !ownerBrowser && (!needsConsent || !!(consent && consent.ads === true)); };
  var cmp = $('#pf-cmp');
  function showCmp(force) {
    if (!cmp) return;
    cmp.innerHTML = L.cmp;
    cmp.hidden = false;
  }
  if (cmp) {
    cmp.addEventListener('click', function (e) {
      var b = e.target.closest('[data-c]'); if (!b) return;
      consent = { v: 1, ads: b.getAttribute('data-c') === '1', t: Date.now() };
      store.set('pf_consent', consent); cmp.hidden = true;
      if (consent.ads) loadAds(true);
    });
  }
  var prefs = $('#pf-prefs'); if (prefs) prefs.addEventListener('click', function () { showCmp(true); });
  if (needsConsent && !consent) showCmp();

  /* ---------- mesure sans cookie ---------- */
  function pageType() {
    var q = EN ? (path.replace(/^\/en(?=\/|$)/, '') || '/') : path;
    if (q === '/') return 'accueil';
    if (q === '/bilan' || q === '/track-record') return 'bilan';
    if (q === '/coupon') return 'coupon';
    if (/^\/football\/[^/]+\/[^/]+\/(analyse|analysis)$/.test(q)) return 'analyse';
    if (/^\/football\/[^/]+\/[^/]+$/.test(q)) return 'match';
    if (/^\/football\/(aujourdhui|demain|today|tomorrow|\d{4}-\d{2}-\d{2})$/.test(q)) return 'jour';
    if (/^\/football\/[^/]+$/.test(q)) return 'ligue';
    return 'autre';
  }
  function source() {
    var r = d.referrer, q = location.search;
    if (/utm_source=afrolook/.test(q)) return 'afrolook';
    if (!r) return 'direct';
    try { var h = new URL(r).hostname; } catch (e) { return 'autre'; }
    if (h === location.hostname) return 'interne';
    if (/google\.|bing\.|duckduckgo\.|yahoo\.|qwant\.|ecosia\./.test(h)) return 'moteur';
    if (/facebook\.|instagram\.|t\.co|twitter\.|x\.com|tiktok\.|whatsapp\.|wa\.me|telegram\.|t\.me|youtube\./.test(h)) return 'social';
    if (/afrolook/.test(h)) return 'afrolook';
    return 'autre';
  }
  var DNT = navigator.doNotTrack === '1' || w.doNotTrack === '1';
  function send(o) {
    if (DNT) return;
    o.tz = tz; var body = JSON.stringify(o);
    try { if (navigator.sendBeacon && navigator.sendBeacon('/api/event', new Blob([body], { type: 'application/json' }))) return; } catch (e) { /* repli */ }
    try { fetch('/api/event', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: body, keepalive: true }); } catch (e) { /* tant pis */ }
  }
  var mj = $('#pf-match'); var mdata = null; try { mdata = mj ? JSON.parse(mj.textContent) : null; } catch (e) { mdata = null; }
  var first = !store.sget('pf_s'); store.sset('pf_s', '1');
  send({ t: 'pv', p: pageType(), m: mdata ? mdata.id : undefined, d: /Mobi|Android|iPhone/.test(UA) ? 'm' : (/iPad|Tablet/.test(UA) ? 't' : 'd'), r: source(), s: first ? 1 : 0, l: LANG });

  /* ---------- encarts Afrolook ---------- */
  var MSG = L.msg;
  var STORE_IOS = 'https://apps.apple.com/gh/app/afrolook/id6811423047';
  function aflInit(a) {
    var slot = a.getAttribute('data-afl') || 'x';
    if (IOS) a.href = STORE_IOS + '?' + 'utm_source=pronoflashia&utm_campaign=' + encodeURIComponent(slot);
    var p = $('p', a); if (p && !a.getAttribute('data-r')) { var i = (parseInt(a.getAttribute('data-i'), 10) + Math.floor(Math.random() * MSG.length)) % MSG.length; p.textContent = MSG[i]; a.setAttribute('data-r', '1'); }
    var seen = false;
    if ('IntersectionObserver' in w) new IntersectionObserver(function (es, o) { es.forEach(function (e) { if (e.isIntersecting && !seen) { seen = true; send({ t: 'afl_imp', fmt: slot }); o.disconnect(); } }); }).observe(a);
    a.addEventListener('click', function () { send({ t: 'afl_click', fmt: slot }); });
  }
  $$('a.afl').forEach(aflInit);
  /* canal WhatsApp : clics comptés */
  $$('a[data-chn]').forEach(function (a) { a.addEventListener('click', function () { send({ t: 'chan_click', n: a.getAttribute('data-chn') || 'x' }); }); });
  /* offre partenaire (Smartlink) : mesure des affichages et des clics */
  $$('a.ptn').forEach(function (a) {
    var slot = a.getAttribute('data-ptn') || 'x', seen = false;
    if ('IntersectionObserver' in w) new IntersectionObserver(function (es, o) { es.forEach(function (e) { if (e.isIntersecting && !seen) { seen = true; send({ t: 'ptn_imp', fmt: slot }); o.disconnect(); } }); }).observe(a);
    a.addEventListener('click', function () { send({ t: 'ptn_click', fmt: slot }); });
  });
  function aflNode(slot, i) {
    var a = d.createElement('a'); a.className = 'afl'; a.target = '_blank'; a.rel = 'noopener sponsored'; a.setAttribute('data-afl', slot); a.setAttribute('data-i', String(i || 0));
    a.href = 'https://play.google.com/store/apps/details?id=com.afrotok.afrotok&utm_source=pronoflashia&utm_campaign=' + encodeURIComponent(slot);
    a.innerHTML = '<span class="sp2">' + L.sponsored + '</span><div class="im" style="background-image:url(/img/afl1.jpg)"></div><div class="bd"><span class="bg"><img src="/img/afrolook.png" alt="" width="12" height="12">AFROLOOK</span><p></p><span class="cta">' + L.aflCta + '</span></div>';
    aflInit(a); return a;
  }

  /* ---------- publicités : chargement paresseux, repli Adsterra → Monetag → Afrolook ---------- */
  var cfg = null, cfgP = null;
  function getCfg() { if (!cfgP) cfgP = fetch('/api/config').then(function (r) { return r.json(); }).catch(function () { return null; }); return cfgP; }
  function runScripts(host, html) {
    var doc = new DOMParser().parseFromString(html, 'text/html');
    Array.prototype.slice.call(doc.body.childNodes).forEach(function (n) {
      if (n.nodeName === 'SCRIPT') { var s = d.createElement('script'); Array.prototype.slice.call(n.attributes).forEach(function (at) { s.setAttribute(at.name, at.value); }); s.text = n.textContent; host.appendChild(s); }
      else host.appendChild(n.cloneNode(true));
    });
  }
  function frameFill(el, code, wd, ht) {
    var f = d.createElement('iframe'); f.width = wd; f.height = ht; f.scrolling = 'no'; f.setAttribute('loading', 'lazy'); f.title = L.adTitle;
    f.srcdoc = '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:transparent;overflow:hidden}</style></head><body>' + code + '</body></html>';
    el.appendChild(f); return f;
  }
  /* « rempli » : l'iframe contient une annonce (image, iframe, lien ou élément ins) ; sinon on passe au réseau suivant */
  function filled(f) { try { var b = f.contentDocument && f.contentDocument.body; return !!(b && b.querySelector('iframe,img,ins,a,video,canvas') && b.scrollHeight > 20); } catch (e) { return true; } }
  function fill(el, c) {
    var id = el.getAttribute('data-ad'); var e = c && c.emplacements && c.emplacements[id];
    if (el.getAttribute('data-done')) return; el.setAttribute('data-done', '1');
    var wd = +el.getAttribute('data-w'), ht = +el.getAttribute('data-h'); var mobile = el.getAttribute('data-v') === 'mo';
    var nets = (e && e.reseaux || []).filter(function (r) { return (mobile && r.codeMobile ? r.codeMobile : r.code); });
    var afl = c && c.afrolook; var aflFirst = afl && afl.actif && Math.random() * 100 < (afl.part || 0);
    function afrolook() { if ((afl && !afl.actif) || el.getAttribute('data-nofb')) { el.hidden = true; return; } el.innerHTML = ''; el.style.minHeight = '0'; el.appendChild(aflNode('pub-' + id, parseInt(el.getAttribute('data-k'), 10) || 0)); el.style.width = '100%'; }
    if (!c || !c.actif || !adsAllowed() || !nets.length || aflFirst) return afrolook();
    var k = 0;
    (function next() {
      if (k >= nets.length) return afrolook();
      var r = nets[k++]; el.innerHTML = '';
      var code = mobile && r.codeMobile ? r.codeMobile : r.code;
      var f = frameFill(el, code, wd, ht);
      send({ t: 'adview', n: id + ':' + r.reseau });
      setTimeout(function () { if (!filled(f)) next(); }, 5000);
    })();
  }
  function loadAds(retry) {
    var slots = $$('.ad[data-ad]').filter(function (s) { return s.offsetParent !== null && (retry || !s.getAttribute('data-done')); });
    if (!slots.length) return;
    getCfg().then(function (c) {
      cfg = c; if (!c) { slots.forEach(function (s) { s.hidden = true; }); return; }
      if (!('IntersectionObserver' in w)) { slots.forEach(function (s) { fill(s, c); }); return; }
      var io = new IntersectionObserver(function (es) { es.forEach(function (en) { if (en.isIntersecting) { io.unobserve(en.target); fill(en.target, c); } }); }, { rootMargin: '300px' });
      slots.forEach(function (s) { if (retry) { s.removeAttribute('data-done'); s.innerHTML = ''; s.style.minHeight = (s.getAttribute('data-h') || 0) + 'px'; s.style.width = ''; } io.observe(s); });
    });
  }
  /* bannière collante : fermable, reste fermée pendant la visite */
  var stk = $('#pf-stk');
  if (stk) { if (store.sget('pf_stk_x')) stk.remove(); else $('button', stk).addEventListener('click', function () { store.sset('pf_stk_x', '1'); stk.remove(); d.body.classList.remove('hasstk'); }); }
  if (w.PF && w.PF.ads) {
    loadAds(false);
    /* Social Bar : une fois par visite, après le délai */
    getCfg().then(function (c) {
      var sb = c && c.actif && c.emplacements && c.emplacements.socialbar; if (!sb || !sb.actif || !sb.reseaux.length || store.sget('pf_sb')) return;
      setTimeout(function () { if (!adsAllowed() || store.sget('pf_sb')) return; store.sset('pf_sb', '1'); runScripts(d.body, sb.reseaux[0].code); send({ t: 'adview', n: 'socialbar' }); }, (sb.delaiSec || 20) * 1000);
    });
    /* Pop-under : coupé par défaut ; si l'admin l'active, au plus une fois par période, au premier clic */
    getCfg().then(function (c) {
      var po = c && c.actif && c.emplacements && c.emplacements.popunder; if (!po || !po.actif || !po.reseaux.length) return;
      var last = store.get('pf_po') || 0; if (Date.now() - last < (po.parJours || 1) * 864e5) return;
      d.addEventListener('click', function once() { d.removeEventListener('click', once); if (!adsAllowed()) return; store.set('pf_po', Date.now()); runScripts(d.body, po.reseaux[0].code); }, { once: true });
    });
  }

  /* ---------- paris avancés : l'annonce du haut du bloc ne se charge qu'à l'ouverture ---------- */
  var adv = $('#pf-adv');
  if (adv) adv.addEventListener('toggle', function () { if (adv.open) loadAds(false); });

  /* ---------- clics de partage ---------- */
  $$('[data-copy]').forEach(function (b) { b.addEventListener('click', function () { var u = b.getAttribute('data-copy'); var done = function () { var o = b.textContent; b.textContent = L.copied; setTimeout(function () { b.textContent = o; }, 1800); }; try { navigator.clipboard.writeText(u).then(done, function () { }); } catch (e) { /* pas de presse-papiers */ } }); });
  $$('a.wa').forEach(function (a) { a.addEventListener('click', function () { send({ t: 'wa', n: pageType() }); }); });

  /* ---------- liste « toutes les familles » de la page d'analyse ---------- */
  var fams = $('#pf-fams');
  if (fams) {
    var secs = $$('.fam'); fams.innerHTML = '<button type="button" aria-pressed="true" data-f="">' + esc(L.all) + '</button>' + secs.map(function (s) { return '<button type="button" aria-pressed="false" data-f="' + esc(s.getAttribute('data-fam')) + '">' + esc(s.getAttribute('data-fam')) + '</button>'; }).join(''); fams.hidden = false;
    fams.addEventListener('click', function (e) { var b = e.target.closest('button'); if (!b) return; $$('button', fams).forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); }); secs.forEach(function (s) { s.hidden = !!b.getAttribute('data-f') && s.getAttribute('data-fam') !== b.getAttribute('data-f'); }); var shown = secs.filter(function (s) { return !s.hidden; }); if (adv && !adv.open && shown.length && shown.every(function (s) { return adv.contains(s); })) adv.open = true; });
  }

  /* ---------- coupon ---------- */
  var PFc = w.PF || {};
  var sel = store.get('pf_coupon') || []; if (!Array.isArray(sel)) sel = [];
  function saveSel() { store.set('pf_coupon', sel); chrome(); }
  var level = function (p) { return p >= 75 ? 's' : p >= 60 ? 'e' : 'r'; };
  function selForCalc() { return sel.map(function (s) { return { matchId: s.m, key: s.k, pct: s.p, famille: s.f, fiabilite: s.r === 'h' ? 'haute' : s.r === 'm' ? 'moyenne' : 'faible' }; }); }
  function matrices() { var o = {}; sel.forEach(function (s) { if (s.x) o[s.m] = s.x; }); return o; }
  function calc() { return PFc.couponProbability ? PFc.couponProbability(selForCalc(), matrices()) : { prob: 0, approx: false }; }
  function chrome() {
    var n = sel.length; var cpn = $('#pf-cpn'), bar = $('#pf-cbar');
    if (cpn) { cpn.hidden = !n || path === couponPath; cpn.textContent = L.myCoupon + ' (' + n + ')'; }
    if (bar) { if (!n || path === couponPath) bar.hidden = true; else { var r = calc(); bar.hidden = false; bar.innerHTML = '<span><b class="num">' + n + '</b> ' + L.sel(n) + (n > 1 ? ' · <b class="num">' + Math.round(r.prob * 100) + L.pct + '</b>' : '') + '</span><button type="button" class="bclr" data-bclr="1" aria-label="' + L.clearAria + '" title="' + L.clearAria + '">✕</button><a href="' + esc(couponPath) + '">' + L.view + '</a>'; } }
    $$('[data-add]').forEach(function (b) { var p = b.getAttribute('data-add').split('|'); b.setAttribute('aria-pressed', String(sel.some(function (s) { return s.m === p[0] && s.k === p[1]; }))); });
  }
  function toggle(m, k, info) {
    var i = -1; sel.forEach(function (s, j) { if (s.m === m && s.k === k) i = j; });
    if (i >= 0) sel.splice(i, 1);
    else { if (sel.length >= 5) return false; sel.push({ m: m, k: k, l: info.l, f: info.f, p: info.p, r: info.r, n: info.n, u: info.u, x: info.x }); }
    saveSel(); send({ t: 'coupon_add', n: pageType() }); return true;
  }
  /* boutons « ＋ » des pages match et analyse */
  if (mdata) {
    var by = {}; mdata.marches.forEach(function (x) { by[x.k] = x; });
    d.addEventListener('click', function (e) {
      var b = e.target.closest('[data-add]'); if (!b) return;
      var p = b.getAttribute('data-add').split('|'); var x = by[p[1]]; if (!x) return;
      if (!toggle(p[0], p[1], { l: x.l, f: x.f, p: x.p, r: x.r, n: mdata.nom, u: mdata.u, x: mdata.matrice })) b.title = L.max5;
    });
  }
  chrome();
  /* vider le coupon depuis la barre du bas (sur toutes les pages) */
  d.addEventListener('click', function (e) { var c = e.target.closest('[data-bclr]'); if (!c) return; sel = []; saveSel(); });

  var root = $('#pf-coupon'), pool = null;
  if (root) {
    try { pool = JSON.parse($('#pf-pool').textContent); } catch (e) { pool = []; }
    /* familles tirées des données de la page (déjà dans la langue de la page), dans leur ordre d'apparition */
    var fam = L.all; var FAMS = [L.all];
    pool.forEach(function (m) { m.marches.forEach(function (x) { if (FAMS.indexOf(x.f) < 0) FAMS.push(x.f); }); });
    /* un lien de coupon proposé (#id|clé,id|clé) charge ses sélections, au chargement et à chaque changement de lien */
    var applyHash = function () {
      var hash = decodeURIComponent((location.hash || '').slice(1));
      if (!hash || !/\|/.test(hash)) return false;
      var nsel = [];
      hash.split(',').forEach(function (h) { var p = h.split('|'); var m = pool.filter(function (x) { return x.id === p[0]; })[0]; var x = m && m.marches.filter(function (y) { return y.k === p[1]; })[0]; if (x) nsel.push({ m: m.id, k: x.k, l: x.l, f: x.f, p: x.p, r: x.r, n: m.nom, u: m.slug, x: m.matrice }); });
      if (!nsel.length) return false;
      sel = nsel.slice(0, 5); store.set('pf_coupon', sel); return true;
    };
    applyHash();
    var panel = $('#pf-cpanel');
    var mq = w.matchMedia ? w.matchMedia('(min-width:900px)') : null;
    var placePanel = function () { if (!panel) return; if (mq && !mq.matches) root.appendChild(panel); else { var side = $('.side .sticky'); if (side) side.insertBefore(panel, side.firstChild); } };
    if (mq && mq.addEventListener) mq.addEventListener('change', placePanel); placePanel();
    /* La liste est un squelette construit une seule fois (un conteneur par match) : seuls les contenus changent à chaque clic.
       Les bannières insérées entre les conteneurs ne sont donc jamais rechargées (pas d'affichages publicitaires en double). */
    var matchBlock = function (m) {
      var opts = m.marches.filter(function (x) { return fam === L.all ? x.p < 92 : x.f === fam; }).sort(function (a, b) { return b.p - a.p; });
      if (!opts.length) return '';
      return '<div class="cm" style="margin-top:10px"><div class="hd"><b>' + esc(m.nom) + '</b><span>' + esc(new Date(m.t).toLocaleTimeString(LOC, { hour: '2-digit', minute: '2-digit' })) + ' · ' + esc(m.ligue) + ' · <a href="' + esc(m.slug) + '" style="color:var(--cy)">' + L.analysis + '</a></span></div><div class="opts">' +
        opts.slice(0, fam === L.all ? 8 : 24).map(function (x) { var on = sel.some(function (s) { return s.m === m.id && s.k === x.k; }); return '<button type="button" class="op ' + level(x.p) + '" data-pk="' + esc(m.id) + '|' + esc(x.k) + '" aria-pressed="' + on + '"><span>' + esc(x.l) + '<small>' + esc(x.f) + '</small></span><b class="num">' + x.p + L.pct + '</b></button>'; }).join('') + '</div></div>';
    };
    var render = function () {
      var pk = $('#pf-picker');
      if (!pk) {
        pk = d.createElement('div'); pk.id = 'pf-picker';
        pk.innerHTML = '<div class="lbl" style="margin-top:6px">' + L.choose + '</div><div class="mk" id="pf-fk" style="margin-top:8px"></div>' + pool.map(function (m) { return '<div class="cmb" data-m="' + esc(m.id) + '"></div>'; }).join('');
        root.insertBefore(pk, root.firstChild);
      }
      $('#pf-fk', pk).innerHTML = FAMS.map(function (f) { return '<button type="button" data-fk="' + esc(f) + '" aria-pressed="' + (f === fam) + '">' + esc(f) + '</button>'; }).join('');
      var blocks = $$('.cmb', pk);
      pool.forEach(function (m, i) { blocks[i].innerHTML = matchBlock(m); });
      if (panel) panel.innerHTML = panelHtml();
      chrome();
    };
    /* Pubs dans la liste « Choisis tes paris » : une après chaque 3e match (3, 6, 9…), cinq au plus. Elles prennent les codes de l'emplacement
       « Bannières dans la liste du coupon » ; s'il n'est pas réglé, ceux d'un autre emplacement actif (haut, fin, native) ; à défaut, un encart Afrolook.
       Le squelette de la liste ne change jamais : les pubs ne se rechargent pas aux clics. */
    var insertPickerAds = function () {
      getCfg().then(function (c) {
        if (!c) return;
        var E = c.emplacements || {}, id = 'coupon_liste';
        if (c.actif) { ['coupon_liste', 'haut', 'fin', 'native'].some(function (k) { var e = E[k]; if (e && e.actif && (e.reseaux || []).length) { id = k; return true; } return false; }); }
        var every = Math.max(2, (E.coupon_liste && E.coupon_liste.every) || 3), blocks = $$('#pf-picker .cmb'), put = 0;
        blocks.forEach(function (b, i) {
          var n = i + 1; if (put >= 5 || n % every !== 0 || n >= blocks.length) return;
          var mk = function (v, wd, ht) { var x = d.createElement('div'); x.className = 'ad ad-end ' + v; x.setAttribute('data-ad', id); x.setAttribute('data-v', v); x.setAttribute('data-w', wd); x.setAttribute('data-h', ht); x.setAttribute('data-k', String(put)); x.style.minHeight = ht + 'px'; return x; };
          b.parentNode.insertBefore(mk('mo', 320, 100), b.nextSibling);
          b.parentNode.insertBefore(mk('dk', 728, 90), b.nextSibling);
          put++;
        });
        loadAds(false);
      });
    };
    var panelHtml = function () {
      var n = sel.length, r = calc(), pc = Math.round(r.prob * 100), risk = PFc.riskLevel ? PFc.riskLevel(r.prob, LANG) : { label: '' };
      var col = r.prob >= .55 ? 'var(--ok)' : r.prob >= .35 ? 'var(--flash)' : r.prob >= .2 ? '#ff9f43' : 'var(--ko)';
      var rows = sel.map(function (s) { return '<div class="sel"><small>' + (/^\/[a-z0-9\/_-]+$/i.test(s.u || '') ? '<a href="' + esc(s.u) + '" style="color:var(--cy)">' + esc(s.n) + ' ›</a>' : esc(s.n)) + ' · ' + esc(s.f) + '</small><span>' + esc(s.l) + '</span><b class="num">' + s.p + L.pct + '</b><button type="button" data-rm="' + esc(s.m) + '|' + esc(s.k) + '" aria-label="' + L.remove + '">✕</button></div>'; }).join('') || '<p class="note" style="margin-top:8px">' + L.empty + '</p>';
      var warns = (PFc.warnings ? PFc.warnings(selForCalc(), r, LANG) : []).map(function (x) { return '<div class="' + (x.type === 'info' ? 'i' : '') + '"><span>' + (x.type === 'info' ? 'ℹ️' : '⚠️') + '</span><span>' + esc(x.text) + '</span></div>'; }).join('');
      var swap = '';
      if (n >= 2 && PFc.weakestSwap) {
        var poolMap = {}; pool.forEach(function (m) { poolMap[m.id] = m.marches.map(function (x) { return { key: x.k, libelle: x.l, famille: x.f, pct: x.p, fiabilite: x.r === 'h' ? 'haute' : x.r === 'm' ? 'moyenne' : 'faible' }; }); });
        var sw = PFc.weakestSwap(selForCalc(), poolMap);
        if (sw) { var np = r.prob / (sw.weak.pct / 100) * (sw.better.pct / 100); swap = '<button type="button" class="op" data-swap="' + esc(sw.weak.matchId + '|' + sw.weak.key + '|' + sw.better.key) + '" style="margin-top:8px;width:100%"><span>' + esc(L.replace(sel.filter(function (s) { return s.k === sw.weak.key && s.m === sw.weak.matchId; })[0].l, sw.better.libelle)) + '<small>' + L.moves(pc, Math.round(np * 100)) + '</small></span><b class="num" style="color:var(--ok)">+' + (Math.round(np * 100) - pc) + '</b></button>'; }
      }
      var txt = encodeURIComponent(L.share(pc) + '\n' + sel.map(function (s) { return '• ' + s.n + (EN ? ': ' : ' : ') + s.l + ' (' + s.p + L.pct + ')'; }).join('\n') + '\n' + location.origin + couponPath);
      return '<div class="box rk"><div class="lbl">' + L.myCoupon + ' · ' + n + '/5</div>' + rows +
        (n ? '<div style="margin-top:10px"><small class="note">' + L.probAll + '</small><div class="big num" style="color:' + col + '">' + pc + L.pct + '</div><div class="meter"><i style="left:calc(' + Math.min(pc, 99) + '% - 2px)"></i></div><div style="display:flex;justify-content:space-between;gap:12px;font-size:12px;color:var(--mut);margin-top:6px"><b style="color:' + col + '">' + esc(risk.label) + '</b><span>' + L.out100(pc) + '</span></div></div>' : '') +
        '<div class="wr">' + warns + '</div>' + swap + (n ? '<div class="sh" style="margin-top:10px"><a class="wa" href="https://wa.me/?text=' + txt + '" target="_blank" rel="noopener">' + L.wa + '</a><button type="button" data-clr="1">' + L.clear + '</button></div>' : '') + '</div>' +
        '<p class="note">' + L.disclaimer + '</p>';
    };
    d.addEventListener('click', function (e) {
      var t = e.target.closest('[data-fk],[data-pk],[data-rm],[data-clr],[data-swap]'); if (!t || !(root.contains(t) || (panel && panel.contains(t)))) return;
      if (t.getAttribute('data-fk')) fam = t.getAttribute('data-fk');
      else if (t.getAttribute('data-pk')) { var p = t.getAttribute('data-pk').split('|'); var m = pool.filter(function (x) { return x.id === p[0]; })[0]; var x = m.marches.filter(function (y) { return y.k === p[1]; })[0]; toggle(p[0], p[1], { l: x.l, f: x.f, p: x.p, r: x.r, n: m.nom, u: m.slug, x: m.matrice }); }
      else if (t.getAttribute('data-rm')) { var q = t.getAttribute('data-rm').split('|'); sel = sel.filter(function (s) { return !(s.m === q[0] && s.k === q[1]); }); saveSel(); }
      else if (t.getAttribute('data-clr')) { sel = []; saveSel(); }
      else if (t.getAttribute('data-swap')) { var sp = t.getAttribute('data-swap').split('|'); var mm = pool.filter(function (y) { return y.id === sp[0]; })[0]; var nx = mm && mm.marches.filter(function (y) { return y.k === sp[2]; })[0]; if (nx) { sel = sel.filter(function (s) { return !(s.m === sp[0] && s.k === sp[1]); }); sel.push({ m: mm.id, k: nx.k, l: nx.l, f: nx.f, p: nx.p, r: nx.r, n: mm.nom, u: mm.slug, x: mm.matrice }); saveSel(); } }
      render();
    });
    w.addEventListener('hashchange', function () { if (applyHash()) render(); });
    render();
    insertPickerAds();
  }
  /* miniature d'actualité qui ne charge pas : on la retire, le titre reste */
  d.addEventListener('error', function (e) { var t = e.target; if (t && t.tagName === 'IMG' && t.closest) { var w = t.closest('.nwi, .nbi'); if (w) w.style.display = 'none'; } }, true);

  /* ---------- application installable (PWA) ---------- */
  if ('serviceWorker' in navigator) { w.addEventListener('load', function () { navigator.serviceWorker.register('/sw.js').catch(function () { /* pas grave : le site marche sans */ }); }); }
  (function pwa() {
    var standalone = (w.matchMedia && w.matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true;
    var mobile = /Android|iPhone|iPad|iPod/.test(UA);
    var inApp = /FBAN|FBAV|FB_IAB|Instagram|Line\/|TikTok|Snapchat|; wv\)/.test(UA);
    var st = store.get('pf_pwa') || {};
    if (standalone || !mobile || inApp || st.ok) return;
    if (st.no && Date.now() - st.no < 14 * 864e5) return;
    var deferred = null, box = null, shown = false;
    w.__pf = w.__pf || {};
    w.__pf.canInstall = function () { return !!deferred; };
    w.__pf.install = function () {
      if (!deferred) return Promise.resolve(false);
      var p = deferred; deferred = null; p.prompt(); send({ t: 'pwa', n: 'clic' });
      return p.userChoice ? p.userChoice.then(function (c) { var ok = !!(c && c.outcome === 'accepted'); if (ok) { st.ok = 1; store.set('pf_pwa', st); close(false); } return ok; }) : Promise.resolve(false);
    };
    var iosSafari = IOS && /Safari/.test(UA) && !/CriOS|FxiOS|EdgiOS/.test(UA);
    function close(remember) { if (box) box.hidden = true; if (remember) { st.no = Date.now(); store.set('pf_pwa', st); } }
    function show() {
      if (shown || (!deferred && !iosSafari)) return;
      shown = true;
      box = d.createElement('div'); box.className = 'pwa'; box.setAttribute('role', 'dialog'); box.setAttribute('aria-label', L.pwaT);
      box.innerHTML = '<img src="/img/icon-192.png" alt="" width="44" height="44"><b>' + L.pwaT + '</b><small>' + L.pwaS + '</small>' +
        '<button class="btn" type="button" data-i="1">' + (deferred ? L.pwaBtn : L.pwaIosBtn) + '</button><button class="pwa-x" type="button" aria-label="' + esc(L.pwaClose) + '" data-x="1">✕</button>';
      d.body.appendChild(box);
      send({ t: 'pwa', n: deferred ? 'vu' : 'ios' });
      box.addEventListener('click', function (e) {
        var t = e.target;
        if (t.closest('[data-x]')) { close(true); return; }
        if (!t.closest('[data-i]')) return;
        send({ t: 'pwa', n: 'clic' });
        if (deferred) {
          var p = deferred; deferred = null;
          p.prompt();
          if (p.userChoice) p.userChoice.then(function (c) { if (c && c.outcome === 'accepted') { st.ok = 1; store.set('pf_pwa', st); close(false); } else close(true); });
        } else if (!$('.pwa-how', box)) {
          var how = d.createElement('div'); how.className = 'pwa-how'; how.innerHTML = L.pwaIos; box.appendChild(how);
        }
      });
    }
    w.addEventListener('beforeinstallprompt', function (e) { e.preventDefault(); deferred = e; setTimeout(show, 4000); });
    w.addEventListener('appinstalled', function () { send({ t: 'pwa', n: 'ok' }); st.ok = 1; store.set('pf_pwa', st); close(false); });
    if (iosSafari) setTimeout(show, 6000);
  })();
  /* ---------- notifications (coupons du jour, alertes des équipes suivies) ---------- */
  (function push() {
    if (!('serviceWorker' in navigator) || !('PushManager' in w) || !('Notification' in w)) { var nb = $('#pf-inbox'); if (nb) nb.innerHTML = '<div class="box"><p>' + L.ibxNoSupport + '</p></div>'; return; }
    var bell = $('#pf-bell');
    var inboxPath = EN ? '/en/notifications' : '/notifications';
    var st = store.get('pf_push') || {};
    var teams = store.get('pf_teams') || [];
    var key = null;
    function toast(text) {
      var t = d.createElement('div'); t.className = 'ptoast'; t.setAttribute('role', 'status'); t.textContent = text; d.body.appendChild(t);
      setTimeout(function () { if (t.parentNode) t.parentNode.removeChild(t); }, 4500);
    }
    function post(path, body) { return fetch(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).then(function (r) { return r.json(); }); }
    function u8(b64) { var p = '='.repeat((4 - b64.length % 4) % 4), s2 = (b64 + p).replace(/-/g, '+').replace(/_/g, '/'), r = atob(s2), a = new Uint8Array(r.length); for (var i = 0; i < r.length; i++) a[i] = r.charCodeAt(i); return a; }
    function current() { return navigator.serviceWorker.ready.then(function (r) { return r.pushManager.getSubscription(); }); }
    function badge(n) {
      if (!bell) return;
      var b = $('.bellbadge', bell);
      if (!n) { if (b) b.remove(); return; }
      if (!b) { b = d.createElement('span'); b.className = 'bellbadge'; bell.appendChild(b); }
      b.textContent = n > 9 ? '9+' : String(n);
    }
    /* nombre de notifications non lues (une demande par minute au plus et par navigateur) */
    function refreshCount(force) {
      current().then(function (sub) {
        if (!sub) { badge(0); return; }
        var c = store.sget('pf_nl'); c = c ? c.split('|') : null;
        if (!force && c && Date.now() - Number(c[1]) < 60000) { badge(Number(c[0])); return; }
        return post('/api/push/compte', { endpoint: sub.endpoint }).then(function (j) { var n = (j && j.nonLus) || 0; store.sset('pf_nl', n + '|' + Date.now()); badge(n); });
      }).catch(function () { /* le compteur n'est pas essentiel */ });
    }
    function paint(on) {
      if (bell) { bell.hidden = false; bell.setAttribute('aria-pressed', on ? 'true' : 'false'); if (on) { bell.setAttribute('aria-label', L.ibxOpen); bell.title = L.ibxOpen; } }
      $$('.follow').forEach(function (f) { f.hidden = !on && Notification.permission === 'denied'; });
      $$('.follow button').forEach(function (b) { var on2 = teams.indexOf(b.getAttribute('data-t')) >= 0; b.setAttribute('aria-pressed', on && on2 ? 'true' : 'false'); b.textContent = (on && on2 ? L.followOn : L.followOff)(b.getAttribute('data-n')); });
    }
    function enable() {
      if (Notification.permission === 'denied') { toast(L.pushBlocked); return Promise.resolve(false); }
      return Notification.requestPermission().then(function (perm) {
        if (perm !== 'granted') { if (perm === 'denied') toast(L.pushBlocked); return false; }
        return (key ? Promise.resolve(key) : fetch('/api/push/key').then(function (r) { return r.json(); }).then(function (j) { key = j.publicKey; return key; })).then(function (k) {
          return navigator.serviceWorker.ready.then(function (reg) { return reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: u8(k) }); });
        }).then(function (sub) { return post('/api/push/subscribe', { subscription: sub.toJSON(), lang: LANG, equipes: teams, tzo: new Date().getTimezoneOffset() }); })
          .then(function (j) { if (j && j.erreur) throw new Error(j.erreur); send({ t: 'push', n: 'on' }); st.on = 1; store.set('pf_push', st); return true; });
      }).catch(function () { toast(L.pushErr); return false; });
    }
    function disable() {
      return current().then(function (sub) {
        if (!sub) return;
        var ep = sub.endpoint;
        return sub.unsubscribe().then(function () { return post('/api/push/unsubscribe', { endpoint: ep }); });
      }).then(function () { send({ t: 'push', n: 'off' }); st.on = 0; store.set('pf_push', st); });
    }
    function toggle() {
      return current().then(function (sub) {
        if (sub) { if (location.pathname !== inboxPath) location.href = inboxPath; else w.scrollTo(0, 0); return; }
        return enable().then(function (ok) { paint(ok); if (ok) toast(L.pushOkT); });
      });
    }
    if (bell) bell.addEventListener('click', toggle);

    /* équipes suivies (fiche d'un match) */
    $$('.follow').forEach(function (f) {
      var ids = f.getAttribute('data-follow').split('|'), names = f.getAttribute('data-names').split('|');
      ids.forEach(function (id, i) { var b = d.createElement('button'); b.type = 'button'; b.setAttribute('data-t', id); b.setAttribute('data-n', names[i]); b.setAttribute('aria-pressed', 'false'); f.appendChild(b); });
      f.addEventListener('click', function (e) {
        var b = e.target.closest('button[data-t]'); if (!b) return;
        var id = b.getAttribute('data-t'), name = b.getAttribute('data-n'), has = teams.indexOf(id) >= 0;
        current().then(function (sub) {
          if (has && sub) {
            teams = teams.filter(function (x) { return x !== id; }); store.set('pf_teams', teams);
            return post('/api/push/equipe', { endpoint: sub.endpoint, equipe: id, action: 'remove' }).then(function () { paint(true); toast(L.teamOff(name)); });
          }
          if (teams.indexOf(id) < 0) teams.push(id);
          store.set('pf_teams', teams);
          if (sub) return post('/api/push/equipe', { endpoint: sub.endpoint, equipe: id, action: 'add' }).then(function () { send({ t: 'push', n: 'equipe' }); paint(true); toast(L.teamOn(name)); });
          return enable().then(function (ok) { paint(ok); if (ok) toast(L.teamOn(name)); else { teams = teams.filter(function (x) { return x !== id; }); store.set('pf_teams', teams); } });
        });
      });
    });

    w.__pf = w.__pf || {};
    w.__pf.push = { enable: enable, disable: disable, paint: paint, toast: toast, current: current, post: post };
    /* page « Mes notifications » : liste par 10, non lues en évidence */
    var ibx = $('#pf-inbox');
    function inboxPage() {
      var offset = 0, endpoint = null;
      function when(iso) { try { return new Date(iso).toLocaleString(LOC, { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }); } catch (e) { return ''; } }
      function empty(msg, withBtn) { ibx.innerHTML = '<div class="box"><p>' + msg + '</p>' + (withBtn ? '<button class="btn" type="button" data-a="on">' + L.ibxEnable + '</button>' : '') + '</div>'; }
      function item(x) {
        var href = typeof x.url === 'string' && x.url.charAt(0) === '/' && x.url.charAt(1) !== '/' ? x.url : '/';
        var img = x.image && /^\/api\/img\/[a-z0-9]+\.(png|jpg)$/.test(x.image) ? '<img src="' + esc(x.image) + '" alt="" loading="lazy" width="96" height="48">' : '';
        return '<a class="ibi' + (x.lu ? '' : ' nl') + '" href="' + esc(href) + '" data-n="' + esc(x.id) + '">' + img + '<span class="ibt"><small>' + (x.lu ? '' : '<i class="ibd" aria-hidden="true"></i><em>' + L.ibxNew + '</em> · ') + esc(when(x.au)) + '</small><b>' + esc(x.titre) + '</b><span>' + esc(x.corps) + '</span></span></a>';
      }
      function start() {
        offset = 0;
        current().then(function (sub) {
          if (!sub) { empty(Notification.permission === 'denied' ? L.ibxDenied : L.ibxNone, Notification.permission !== 'denied'); return; }
          endpoint = sub.endpoint;
          return post('/api/push/inbox', { endpoint: endpoint, offset: 0 }).then(function (j) {
            if (j.erreur) { empty(L.ibxNone, true); return; }
            store.sset('pf_nl', j.nonLus + '|' + Date.now()); badge(j.nonLus);
            offset = j.items.length;
            ibx.innerHTML = '<div class="ibh"><b>' + (j.nonLus ? L.ibxUnread(j.nonLus) : '') + '</b>' + (j.nonLus ? '<button class="btn sec sm" type="button" data-a="all">' + L.ibxAll + '</button>' : '') + '</div>' +
              (j.items.length ? '<div class="ibl">' + j.items.map(item).join('') + '</div>' : '<div class="box"><p>' + L.ibxEmpty + '</p></div>') +
              (j.suite ? '<button class="btn sec ibm" type="button" data-a="more">' + L.ibxMore + '</button>' : '') + '<p class="ibo"><button type="button" class="wml" data-a="off">' + L.ibxOff + '</button></p>';
          });
        }).catch(function () { empty(L.ibxErr, false); });
      }
      function more() {
        post('/api/push/inbox', { endpoint: endpoint, offset: offset }).then(function (j) {
          offset += j.items.length;
          $('.ibl', ibx).insertAdjacentHTML('beforeend', j.items.map(item).join(''));
          var m = $('.ibm', ibx); if (m && !j.suite) m.remove();
        }).catch(function () { toast(L.ibxErr); });
      }
      ibx.addEventListener('click', function (e) {
        var it = e.target.closest('.ibi'), a = e.target.closest('[data-a]');
        if (it) { if (endpoint) post('/api/push/lu', { endpoint: endpoint, id: it.getAttribute('data-n') }); return; } /* le lien s'ouvre ensuite */
        if (!a) return;
        var act = a.getAttribute('data-a');
        if (act === 'on') enable().then(function (ok) { paint(ok); if (ok) start(); });
        else if (act === 'more') more();
        else if (act === 'all') post('/api/push/lu', { endpoint: endpoint, tous: true }).then(start);
        else if (act === 'off') disable().then(function () { paint(false); badge(0); toast(L.pushOffT); start(); });
      });
      start();
    }
    if (ibx) inboxPage();
    /* ouvrir une notification (lien avec n=…) la marque comme lue */
    var nParam = /[?&]n=([a-f0-9]{8,16})/.exec(location.search);
    current().then(function (sub) {
      paint(!!sub);
      if (sub && nParam) { post('/api/push/lu', { endpoint: sub.endpoint, id: nParam[1] }).then(function (j) { store.sset('pf_nl', ((j && j.nonLus) || 0) + '|' + Date.now()); badge((j && j.nonLus) || 0); }).catch(function () { /* pas grave */ }); }
      else if (sub) refreshCount(false);
      if (!sub) st.on = 0;
      var visits = (store.get('pf_visits') || 0);
      if (!store.sget('pf_vs')) { store.sset('pf_vs', '1'); visits++; store.set('pf_visits', visits); }
    });
  })();
  /* ---------- rappel : fenêtre avec des exemples de notifications ----------
     Pour le visiteur qui revient (2e visite ou plus) et n'a ni activé les notifications ni installé le site. Jamais à l'arrivée sur la page :
     après 12 secondes et un geste (défilement, toucher). Une fois par session ; refus : on attend 7 jours, 3 refus au plus. */
  (function welcome() {
    if (!store.sget('pf_vs')) { store.sset('pf_vs', '1'); store.set('pf_visits', (store.get('pf_visits') || 0) + 1); }
    var canPush = 'serviceWorker' in navigator && 'PushManager' in w && 'Notification' in w;
    var standalone = (w.matchMedia && w.matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true;
    var iosTab = IOS && /Safari/.test(UA) && !/CriOS|FxiOS|EdgiOS/.test(UA) && !standalone;
    var inApp = /FBAN|FBAV|FB_IAB|Instagram|Line\/|TikTok|Snapchat|; wv\)/.test(UA);
    if (inApp || (!canPush && !iosTab) || (canPush && Notification.permission === 'denied')) return;
    var st = store.get('pf_wm') || {};
    if ((st.n || 0) >= 3 || (st.no && Date.now() - st.no < 7 * 864e5) || store.sget('pf_wm')) return;
    var touched = false, due = false, tries = 0;
    ['scroll', 'touchstart', 'click'].forEach(function (ev) { w.addEventListener(ev, function () { touched = true; }, { once: true, passive: true }); });
    setTimeout(function () { due = true; }, 12000);
    function ready() { return canPush ? navigator.serviceWorker.ready.then(function (r) { return r.pushManager.getSubscription(); }).then(function (sub) { return !sub; }) : Promise.resolve(true); }
    function open() {
      var box = d.createElement('div'); box.className = 'wm'; box.setAttribute('role', 'dialog'); box.setAttribute('aria-modal', 'true'); box.setAttribute('aria-label', L.wmT);
      function ex(t, b) { return '<div class="wmn"><img src="/img/icon-192.png" alt="" width="34" height="34"><div><small>PronoFlash IA · ' + L.wmNow + '</small><b>' + esc(t) + '</b><span>' + esc(b) + '</span></div></div>'; }
      var canInst = !standalone && (iosTab || (w.__pf && w.__pf.canInstall && w.__pf.canInstall()));
      var primary = canPush ? '<button class="btn" type="button" data-a="on">' + L.wmBtn + '</button>' : '<button class="btn" type="button" data-a="how">' + L.wmIosBtn + '</button>';
      var second = canPush && canInst ? '<button class="btn sec" type="button" data-a="' + (iosTab ? 'how' : 'inst') + '">' + (iosTab ? L.wmIosBtn : L.wmInst) + '</button>' : '';
      box.innerHTML = '<div class="wmc"><button class="wm-x" type="button" data-a="x" aria-label="' + esc(L.pwaClose) + '">✕</button><h2>' + L.wmT + '</h2><p>' + L.wmS + '</p><div class="lbl">' + L.wmEx + '</div>' +
        ex(L.wmN1t, L.wmN1b) + ex(L.wmN2t, L.wmN2b) + ex(L.wmN3t, L.wmN3b) + (!canPush ? '<p class="wmnote">' + L.wmIosNote + '</p>' : '') +
        '<div class="wma">' + primary + second + '</div><div class="pwa-how" hidden></div><button class="wml" type="button" data-a="later">' + L.wmLater + '</button></div>';
      d.body.appendChild(box);
      d.documentElement.style.overflow = 'hidden';
      store.sset('pf_wm', '1');
      send({ t: 'push', n: 'mvu' });
      var first = box.querySelector('.btn'); if (first) first.focus();
      function close(refused) {
        d.documentElement.style.overflow = ''; d.removeEventListener('keydown', onKey); if (box.parentNode) box.parentNode.removeChild(box);
        if (refused) { st.no = Date.now(); st.n = (st.n || 0) + 1; store.set('pf_wm', st); send({ t: 'push', n: 'mno' }); }
      }
      function onKey(e) { if (e.key === 'Escape') close(true); }
      d.addEventListener('keydown', onKey);
      box.addEventListener('click', function (e) {
        var a = e.target.closest('[data-a]');
        if (!a) { if (e.target === box) close(true); return; }
        var act = a.getAttribute('data-a');
        if (act === 'x' || act === 'later') close(true);
        else if (act === 'on') { var P = w.__pf && w.__pf.push; if (!P) { close(true); return; } P.enable().then(function (ok) { P.paint(ok); if (ok) { close(false); P.toast(L.pushOkT); } }); }
        else if (act === 'inst') { w.__pf.install().then(function (ok) { if (ok) close(false); }); }
        else if (act === 'how') { var how = $('.pwa-how', box); how.innerHTML = L.pwaIos; how.hidden = false; }
      });
    }
    function tick() {
      if ((store.get('pf_visits') || 0) < 2 && !standalone) return;
      if (!(touched && due)) { if (++tries < 40) setTimeout(tick, 3000); return; }
      var busy = ($('.pwa') && !$('.pwa').hidden) || (cmp && !cmp.hidden);
      if (busy) { if (++tries < 40) setTimeout(tick, 4000); return; }
      ready().then(function (ok) { if (ok && !$('.wm')) open(); });
    }
    setTimeout(tick, 3000);
  })();
})();
