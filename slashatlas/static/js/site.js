(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var body = document.body, page = body.dataset.page, lang = body.dataset.lang;
  var store = function (k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } };
  var sstore = function (k, v) { try { if (v === undefined) return sessionStorage.getItem(k); sessionStorage.setItem(k, v); } catch (e) { return null; } };
  var isBot = /bot|crawl|spider|headless|lighthouse/i.test(navigator.userAgent);
  var dnt = navigator.doNotTrack === '1' || navigator.globalPrivacyControl === true;

  // ── Mesure sans cookie ni identifiant : agrégée par jour côté serveur ──
  function track(t, extra) {
    if (isBot || dnt) return;
    var d = { t: t, p: page, l: lang, d: matchMedia('(max-width:719px)').matches ? 'm' : 'd' };
    for (var k in extra) d[k] = extra[k];
    toGa(t, d);
    try {
      var b = new Blob([JSON.stringify(d)], { type: 'application/json' });
      if (!navigator.sendBeacon || !navigator.sendBeacon('/api/event', b)) fetch('/api/event', { method: 'POST', body: JSON.stringify(d), keepalive: true, headers: { 'content-type': 'application/json' } });
    } catch (e) {}
  }
  // Les mêmes événements partent aussi vers Google Analytics (si présent) : copie, essai, outil, achat…
  var GA = { copy: 'copy_command', try: 'try_generate', test: 'open_tool', nopub: 'click_no_ads', video: 'video_play', buyopen: 'begin_checkout', paytry: 'add_payment_info', cardwish: 'card_wish' };
  function toGa(t, d) { try { if (window.gtag && GA[t]) window.gtag('event', GA[t], { command: d.s || d.n || '', tool: d.tool || '', method: d.m || '', page_type: d.p || '' }); } catch (e) {} }
  window.saTrack = track;
  function refClass() {
    // liens des publicités : ?utm_source=youtube&utm_campaign=… → compté sous « ad_source_campagne » dans l'administration
    try { var q = new URLSearchParams(location.search), us = q.get('utm_source'); if (us) return ('ad_' + us + '_' + (q.get('utm_campaign') || '')).toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 40); } catch (e) {}
    var r = document.referrer; if (!r) return 'direct';
    var h; try { h = new URL(r).hostname; } catch (e) { return 'other'; }
    if (h === location.hostname) return 'internal';
    if (/google\.|bing\.|duckduckgo\.|yahoo\.|ecosia\.|qwant\./.test(h)) return 'search';
    if (/tiktok\.|instagram\.|facebook\.|youtube\.|t\.co|x\.com|twitter\.|pinterest\.|reddit\.|linkedin\.|whatsapp\.|threads\./.test(h)) return 'social';
    return 'other';
  }
  var n = parseInt(sstore('sa_n') || '0', 10) + 1; sstore('sa_n', String(n));
  var returning = store('sa_seen') === '1'; store('sa_seen', '1');
  var tz = ''; try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch (e) {}
  track('pv', { n: n, r: n === 1 ? refClass() : 'internal', ret: returning ? 1 : 0, tz: tz });

  // ── Langue : l'accueil suit la langue du téléphone (script en tête de page) ; seul un choix explicite est mémorisé ──
  $$('[data-lang-switch]').forEach(function (a) { a.addEventListener('click', function () { store('sa_lang_choice', a.dataset.langSwitch); }); });

  // ── Copier ──
  function fallbackCopy(txt, done) { var ta = document.createElement('textarea'); ta.value = txt; ta.style.cssText = 'position:fixed;opacity:0'; document.body.appendChild(ta); ta.select(); try { document.execCommand('copy'); } catch (e) {} ta.remove(); done(); }
  document.addEventListener('click', function (e) {
    var el = e.target.closest('[data-copy]');
    if (el) {
      var src = $(el.dataset.copy); if (!src) return;
      var old = el.textContent;
      var done = function () { el.textContent = lang === 'fr' ? 'Copié ✓' : 'Copied ✓'; if (el.dataset.after) { var a = $('#after'); if (a) a.classList.add('on'); window.saAds && window.saAds.late(); } setTimeout(function () { el.textContent = old; }, 1800); track('copy', { s: el.dataset.slug || '' }); };
      var txt = src.textContent;
      try { navigator.clipboard.writeText(txt).then(done, function () { fallbackCopy(txt, done); }); } catch (err) { fallbackCopy(txt, done); }
      return;
    }
    var t = e.target.closest('[data-test]'); if (t) track('test', { tool: t.dataset.test });
    var u = e.target.closest('[data-try]'); if (u) track('try', { n: u.dataset.try });
    var np = e.target.closest('a[href$="/pro/"]'); if (np) track('nopub', {});
  });

  // Copie par sélection + clic droit (ou Ctrl+C) dans la commande : même effet que le bouton « Copier ».
  document.addEventListener('copy', function () {
    try {
      var sel = window.getSelection(), nd = sel && sel.anchorNode; if (!nd) return;
      var pre = (nd.nodeType === 1 ? nd : nd.parentElement).closest('.cmd pre'); if (!pre) return;
      var a = $('#after'); if (a) a.classList.add('on');
      window.saAds && window.saAds.late();
      track('copy', { s: pre.id.replace(/^p-/, ''), via: 'sel' });
    } catch (e) {}
  });

  // ── Recherche et filtre ──
  var q = $('#q');
  if (q) {
    var cat = '', list = $$('#list .card'), none = $('#none'), more = $('#more'), STEP = 24, limit = STEP;
    window.saReorder = function () { list = $$('#list .card'); apply(); };
    var apply = function (keep) {
      if (keep !== true) limit = STEP;
      var v = q.value.trim().toLowerCase(), c = 0, shown = 0;
      list.forEach(function (card) {
        var hit = (!cat || card.dataset.cat === cat) && (!v || card.dataset.search.indexOf(v) > -1);
        if (hit) { c++; if (shown < limit) { shown++; card.hidden = false; } else card.hidden = true; } else card.hidden = true;
      });
      if (none) none.hidden = c > 0;
      if (more) { more.hidden = c <= limit; more.textContent = (lang === 'fr' ? 'Voir plus (' : 'Show more (') + (c - limit) + ')'; }
    };
    if (more) more.addEventListener('click', function () { limit += STEP; apply(true); });
    apply();
    q.addEventListener('input', apply);
    $$('.chips2 .chip').forEach(function (b) { b.addEventListener('click', function () { cat = b.dataset.cat; $$('.chips2 .chip').forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); }); apply(); }); });
    // /commandes/?q=... depuis les liens internes
    var m = /[?&]q=([^&]+)/.exec(location.search); if (m) { q.value = decodeURIComponent(m[1]); apply(); }
  }

  // ── Formulaires (liste d'attente, prévenez-moi, demande de commande) ──
  $$('form[data-form]').forEach(function (f) {
    f.addEventListener('submit', function (e) {
      e.preventDefault();
      var msg = $('.fmsg', f), email = f.elements.email.value.trim();
      var say = function (t, err) { msg.textContent = t; msg.className = 'fmsg' + (err ? ' err' : ''); };
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) { say(f.dataset.invalid, true); return; }
      say(f.dataset.sending);
      var sb = f.querySelector('button[type="submit"]'); if (sb) { sb.disabled = true; sb.classList.add('loading'); }
      var data = { email: email, kind: f.dataset.form, note: f.elements.note ? f.elements.note.value : '', lang: f.dataset.lang, website: f.elements.website ? f.elements.website.value : '', page: page };
      fetch('/api/subscribe', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(data) })
        .then(function (r) { if (!r.ok) throw new Error(r.status); say(f.dataset.ok); f.reset(); })
        .catch(function () { say(f.dataset.err, true); })
        .then(function () { if (sb) { sb.disabled = false; sb.classList.remove('loading'); } });
    });
  });

  // ── Tutoriel animé ──
  var demo = $('#demo');
  if (demo) {
    var step = 0, tTimer = null, typeTimer = null, toastTimer = null, touched = false;
    var stop = function () { clearInterval(tTimer); clearInterval(typeTimer); clearTimeout(toastTimer); };
    var show = function (i) {
      step = i;
      $$('.pane', demo).forEach(function (p) { p.classList.toggle('on', +p.dataset.p === i); });
      $$('.ts').forEach(function (b) { b.classList.toggle('on', +b.dataset.tstep === i); });
      $$('#dots i').forEach(function (d, k) { d.classList.toggle('on', k === i); });
      clearInterval(typeTimer); clearTimeout(toastTimer);
      var toast = $('#ttoast'); toast.classList.remove('on');
      if (i === 0) toastTimer = setTimeout(function () { toast.classList.add('on'); }, 1500);
      var ty = $('#typed'); ty.textContent = '';
      if (i === 1) {
        var full = ty.dataset.text, c = 0;
        typeTimer = setInterval(function () { c += 3; ty.textContent = full.slice(0, c); var cur = document.createElement('i'); ty.appendChild(cur); if (c >= full.length) clearInterval(typeTimer); }, 40);
      }
    };
    var start = function () {
      stop(); show(0);
      if ((matchMedia('(prefers-reduced-motion:reduce)').matches) || touched) return;
      tTimer = setInterval(function () { show((step + 1) % 3); }, 4600);
    };
    $$('.ts').forEach(function (b) { b.addEventListener('click', function () { touched = true; stop(); show(+b.dataset.tstep); }); });
    $('#replay').addEventListener('click', function () { touched = false; start(); });
    start();
  }

  // ── Adapter la commande au produit : texte libre + un ou plusieurs éléments ──
  $$('.adapt').forEach(function (box) {
    var pre = document.getElementById(box.dataset.for), input = $('input', box), mode = '1';
    function build() {
      var type = input.value.trim().replace(/[()]/g, '');
      var clause = (mode === 'n' ? box.dataset.cn : box.dataset.c1).replace('{T}', type ? ' (' + type + ')' : '');
      if (pre) pre.textContent = box.dataset.code + ' : ' + box.dataset.base + ' ' + clause;
    }
    input.addEventListener('input', build);
    $$('.seg2 button', box).forEach(function (b) { b.addEventListener('click', function () { mode = b.dataset.n; $$('.seg2 button', box).forEach(function (x) { x.setAttribute('aria-pressed', x === b ? 'true' : 'false'); }); build(); }); });
  });
})();

// Commandes les plus copiées : compteurs publics (/api/popular), badges sur les cartes, rangée « Les plus copiées » sur l'accueil, liste triée.
(function () {
  var cards = document.querySelectorAll('.card[data-slug], .rc[data-slug]'), one = document.getElementById('cmd-cnt'), rail = document.getElementById('rail-sel');
  if (!cards.length && !one && !rail) return;
  var lang = document.body.dataset.lang === 'en' ? 'en' : 'fr', MIN = 1, counts = {};
  // counts[slug] = [copies, essais « Générer ici »] ; le total sert au classement
  var C = function (slug) { var v = counts[slug]; return v ? v : [0, 0]; };
  var score = function (slug) { var v = C(slug); return v[0] + 10 * v[1]; }; // un essai « Générer ici » vaut 10 copies
  var cw = function (n) { return n + ' ' + (n > 1 ? 'copies' : (lang === 'fr' ? 'copie' : 'copy')); };
  var tw = function (n) { return lang === 'fr' ? n + (n > 1 ? ' essais' : ' essai') : n + (n > 1 ? ' tries' : ' try'); };
  var label = function (v, full) {
    var out = [];
    if (v[0]) out.push('⧉ ' + (full ? cw(v[0]) : v[0]));
    if (v[1]) out.push('⚡ ' + (full ? tw(v[1]) : v[1]));
    return out.join(full ? ' · ' : '  ');
  };
  var show = function (el, slug, full) { if (!el) return; var v = C(slug); if (v[0] + v[1] >= MIN) { el.textContent = label(v, full); el.title = cw(v[0]) + ' · ' + tw(v[1]); el.hidden = false; } };
  function paint() {
    Array.prototype.forEach.call(cards, function (c) { show(c.querySelector('.cnt'), c.dataset.slug, false); });
    if (one) show(one, one.dataset.slug, true);
  }
  function esc(t) { return String(t == null ? '' : t).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function railCard(r) {
    var poster = r.img ? '<div class="poster img' + (r.ratio === '16:9' ? ' ls' : '') + '"><img src="/img/c/' + r.slug + '-t.webp" alt="" loading="lazy" decoding="async"><span class="tag">' + esc(r.cat) + '</span></div>'
      : '<div class="poster" style="--x:' + esc(r.x) + ';--y:' + esc(r.y) + ';--r:' + esc(r.r) + '"><span class="tag">' + esc(r.cat) + '</span><span class="shape"></span><b>' + esc(r.poster) + '</b><small>' + esc(r.code) + '</small></div>';
    var href = (lang === 'en' ? '/en/c/' : '/c/') + r.slug + '/';
    var gen = r.can ? '<a class="btn pri copy" href="' + (lang === 'en' ? '/en/generate/' : '/generer/') + '?c=' + r.slug + '" data-try="' + r.slug + '">' + (lang === 'fr' ? 'Générer ici' : 'Generate here') + '</a>' : '';
    return '<article class="rc" data-slug="' + r.slug + '" data-search="' + esc(r.code) + '"><a class="rp" href="' + href + '" aria-label="' + esc(r.title) + '">' + poster + '</a><div class="rb"><code>' + esc(r.code) + '</code><span class="rt">' + esc(r.title) + '</span><span class="cnt" title="' + esc(cw(r.copies) + ' · ' + tw(r.tries)) + '">' + label([r.copies, r.tries], false) + '</span><div class="acts">' + gen + '<button class="btn ' + (r.can ? 'gl' : 'pri') + ' copy" type="button" data-copy="#pp-' + r.slug + '" data-slug="' + r.slug + '">' + (lang === 'fr' ? 'Copier' : 'Copy') + '</button></div><pre id="pp-' + r.slug + '" hidden>' + esc(r.full) + '</pre></div></article>';
  }
  // « À la une » : les commandes les plus utilisées (copie = 1 point, essai « Générer ici » = 10 points), mélangées entre catégories :
  // d'abord la meilleure de Mode, Pub produit et Beauté, puis le reste par score avec au plus 2 par catégorie ; la sélection éditoriale complète jusqu'à 10.
  var PRI = ['mode', 'produit', 'beaute'];
  function railFill(top) {
    if (!rail) return;
    var pool = top.map(function (r) { r.score = r.copies + 10 * r.tries; return r; }).filter(function (r) { return r.score > 0; }).sort(function (a, b) { return b.score - a.score; });
    if (!pool.length) return;
    var picked = [], per = {};
    var take = function (r) { picked.push(r); per[r.catId] = (per[r.catId] || 0) + 1; };
    PRI.forEach(function (cat) { var r = pool.filter(function (x) { return x.catId === cat && picked.indexOf(x) < 0; })[0]; if (r) take(r); });
    pool.forEach(function (r) { if (picked.length < 10 && picked.indexOf(r) < 0 && (per[r.catId] || 0) < 2) take(r); });
    picked.sort(function (a, b) { return b.score - a.score; });
    var have = {}; picked.forEach(function (r) { have[r.slug] = 1; });
    var base = Array.prototype.filter.call(rail.children, function (c) { return c.dataset.slug && !have[c.dataset.slug]; });
    rail.innerHTML = picked.map(railCard).join('');
    base.slice(0, Math.max(0, 10 - picked.length)).forEach(function (c) { rail.appendChild(c); });
    Array.prototype.forEach.call(rail.querySelectorAll('.rc'), function (c) { show(c.querySelector('.cnt'), c.dataset.slug, false); });
  }
  function showRail(k) {
    ['sel', 'new'].forEach(function (n) { var r = document.getElementById('rail-' + n); if (r) { r.hidden = n !== k; if (n === k) r.scrollLeft = 0; } });
    Array.prototype.forEach.call(document.querySelectorAll('.rtab'), function (t) { var on = t.dataset.rail === k; t.classList.toggle('on', on); t.setAttribute('aria-selected', on ? 'true' : 'false'); });
  }
  Array.prototype.forEach.call(document.querySelectorAll('.rtab'), function (t) { t.addEventListener('click', function () { showRail(t.dataset.rail); }); });
  function sortList(counts) {
    var list = document.getElementById('list'); if (!list) return;
    var items = Array.prototype.slice.call(list.children);
    if (items.filter(function (c) { return score(c.dataset.slug) >= MIN; }).length < 3) return;
    items.map(function (c, i) { return [c, i]; }).sort(function (a, b) { return score(b[0].dataset.slug) - score(a[0].dataset.slug) || a[1] - b[1]; }).forEach(function (x) { list.appendChild(x[0]); });
    if (window.saReorder) window.saReorder();
  }
  fetch('/api/popular?l=' + lang).then(function (r) { return r.json(); }).then(function (d) { counts = d.counts || {}; paint(); railFill(d.top || []); sortList(counts); }).catch(function () {});
})();

// Publicité : les emplacements restent masqués tant que l'administration n'a pas activé la publicité (réglages lus via /api/config).
// Pass « sans pub » : l'échéance (ms) est mémorisée par la page Générer ici après connexion ; tant qu'elle court, aucune publicité n'est chargée.
// Les emplacements data-adlate (sous « Copié ») ne se remplissent qu'au moment de la copie, qu'elle se fasse par le bouton ou par clic droit.
(function () {
  try {
    var slots = Array.prototype.slice.call(document.querySelectorAll('[data-ad]')); if (!slots.length) return;
    var until = 0; try { until = parseInt(localStorage.getItem('sa_nopub') || '0', 10) || 0; } catch (e) {}
    if (until > Date.now()) { document.documentElement.classList.add('nopub'); return; }
    var cfgP = null, io = null;
    function loadCfg() {
      return cfgP || (cfgP = fetch('/api/config').then(function (r) { return r.json(); }).then(function (c) {
        var a = c && c.ads; if (!a || !a.enabled) return null;
        var s = document.createElement('script'); s.async = true; s.crossOrigin = 'anonymous';
        s.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=' + encodeURIComponent(a.client); document.head.appendChild(s);
        var p = document.querySelector('[data-adprefs]'); if (p) { p.hidden = false; p.addEventListener('click', function (e) { e.preventDefault(); try { window.googlefc = window.googlefc || {}; googlefc.callbackQueue = googlefc.callbackQueue || []; googlefc.callbackQueue.push(googlefc.showRevocationMessage); } catch (x) {} }); }
        io = 'IntersectionObserver' in window ? new IntersectionObserver(function (es) { es.forEach(function (en) { if (en.isIntersecting) { io.unobserve(en.target); window.saTrack && window.saTrack('adview', { n: en.target.dataset.ad }); } }); }, { threshold: 0.5 }) : null;
        return a;
      }).catch(function () { return null; }));
    }
    function fill(el, a) {
      if (el.dataset.filled) return;
      var id = a.slots && a.slots[el.dataset.ad]; if (!id) return;
      el.dataset.filled = '1';
      var ins = document.createElement('ins'); ins.className = 'adsbygoogle'; ins.style.display = 'block';
      ins.setAttribute('data-ad-client', a.client); ins.setAttribute('data-ad-slot', id); ins.setAttribute('data-ad-format', 'auto'); ins.setAttribute('data-full-width-responsive', 'true');
      el.appendChild(ins); el.hidden = false;
      try { (window.adsbygoogle = window.adsbygoogle || []).push({}); } catch (e) {}
      if (io) io.observe(el);
    }
    var early = slots.filter(function (el) { return !el.hasAttribute('data-adlate'); });
    if (early.length) loadCfg().then(function (a) { if (a) early.forEach(function (el) { fill(el, a); }); });
    window.saAds = { late: function () { loadCfg().then(function (a) { if (a) setTimeout(function () { slots.forEach(function (el) { if (el.hasAttribute('data-adlate')) fill(el, a); }); }, 60); }); } };
  } catch (e) {}
})();

// Menu du téléphone : bouton hamburger, se ferme au clic sur un lien, sur Échap ou au retour sur grand écran.
(function () {
  var b = document.querySelector('.menubtn'), m = document.getElementById('mnav'); if (!b || !m) return;
  function set(o) { b.setAttribute('aria-expanded', o ? 'true' : 'false'); m.hidden = !o; }
  b.addEventListener('click', function () { set(m.hidden); });
  m.addEventListener('click', function (e) { if (e.target.closest('a')) set(false); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') set(false); });
  matchMedia('(min-width:720px)').addEventListener && matchMedia('(min-width:720px)').addEventListener('change', function () { set(false); });
})();

// Lien « Hub » (menu téléphone + pied de page) pour l'administrateur connecté : simple confort, l'accès reste contrôlé par le serveur.
(function () {
  try {
    if (localStorage.getItem('sa_admin') !== '1') return;
    var m = document.getElementById('mnav'), f = document.querySelector('.ft');
    [m, f].forEach(function (c) { if (!c) return; var a = document.createElement('a'); a.href = '/admin/'; a.textContent = 'Hub'; if (c === m) c.appendChild(a); else c.appendChild(a); });
  } catch (e) {}
})();

// Vidéo de présentation hébergée sur le site : préchargée en arrière-plan après le chargement de la page, puis lue automatiquement AVEC le son
// (volume 40 %) quand sa section est à l'écran, et mise en pause quand on la quitte. Règle des navigateurs : le son automatique n'est autorisé
// qu'après un premier geste sur la page (toucher, clic, touche). Tant que ce geste n'a pas eu lieu, on n'affiche pas une vidéo muette : un grand
// bouton « lancer avec le son » attend le toucher ; dès le premier toucher n'importe où sur la page, les lectures suivantes démarrent seules avec le son.
(function () {
  var box = document.querySelector('[data-vid]'); if (!box) return;
  var v = box.querySelector('video'), btn = box.querySelector('.vfacade'); if (!v || !btn) return;
  var fr = document.body.dataset.lang !== 'en';
  var c = navigator.connection || {}, slow = c.saveData || /(^|-)2g$/.test(c.effectiveType || '');
  var VOL = 0.4, visible = false, userPaused = false, tracked = false;
  var cap = document.createElement('span'); cap.className = 'vcap'; cap.textContent = fr ? 'Touchez pour lancer avec le son' : 'Tap to play with sound'; btn.appendChild(cap);
  function preload() { if (slow || v.preload === 'auto') return; v.preload = 'auto'; try { v.load(); } catch (e) {} }
  function whenIdle() { if ('requestIdleCallback' in window) requestIdleCallback(preload, { timeout: 3000 }); else setTimeout(preload, 1500); }
  if (document.readyState === 'complete') whenIdle(); else window.addEventListener('load', whenIdle);
  v.volume = VOL; v.muted = false;
  function begun() { btn.hidden = true; v.controls = true; if (!tracked && window.saTrack) { tracked = true; window.saTrack('video', { n: v.dataset.yt }); } }
  function play() {
    if (userPaused || !v.paused) return;
    v.muted = false; v.volume = VOL;
    var p = v.play();
    if (p && p.then) p.then(begun, function () { btn.hidden = false; v.controls = false; }); else begun();
  }
  v.addEventListener('pause', function () { if (!btn.hidden && visible && !v.ended) userPaused = true; });
  // premier geste de l'utilisateur sur la page : le son automatique devient autorisé, on lance la vidéo si sa section est déjà visible
  ['pointerdown', 'keydown', 'touchend'].forEach(function (ev) { window.addEventListener(ev, function () { if (visible) setTimeout(play, 0); }, { once: true, passive: true }); });
  btn.addEventListener('click', function () { userPaused = false; v.muted = false; v.volume = VOL; var p = v.play(); if (p && p.then) p.then(begun, function () {}); begun(); });
  if ('IntersectionObserver' in window && !slow) {
    new IntersectionObserver(function (es) {
      es.forEach(function (en) {
        visible = en.isIntersecting && en.intersectionRatio >= 0.5;
        if (visible) { preload(); play(); } else if (!v.paused) { v.pause(); }
      });
    }, { threshold: [0, 0.5, 0.75] }).observe(box);
  }
})();
