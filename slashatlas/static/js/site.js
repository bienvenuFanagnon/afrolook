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
    try {
      var b = new Blob([JSON.stringify(d)], { type: 'application/json' });
      if (!navigator.sendBeacon || !navigator.sendBeacon('/api/event', b)) fetch('/api/event', { method: 'POST', body: JSON.stringify(d), keepalive: true, headers: { 'content-type': 'application/json' } });
    } catch (e) {}
  }
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
      var data = { email: email, kind: f.dataset.form, note: f.elements.note ? f.elements.note.value : '', lang: f.dataset.lang, website: f.elements.website ? f.elements.website.value : '', page: page };
      fetch('/api/subscribe', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(data) })
        .then(function (r) { if (!r.ok) throw new Error(r.status); say(f.dataset.ok); f.reset(); })
        .catch(function () { say(f.dataset.err, true); });
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

// Vidéo YouTube : le lecteur n'est chargé qu'au clic (domaine sans cookie youtube-nocookie.com).
(function () {
  document.addEventListener('click', function (e) {
    var f = e.target.closest('.vfacade'); if (!f) return;
    var id = f.dataset.yt; if (!/^[\w-]{6,20}$/.test(id)) return;
    var i = document.createElement('iframe');
    i.src = 'https://www.youtube-nocookie.com/embed/' + id + '?autoplay=1&rel=0&modestbranding=1&playsinline=1&enablejsapi=1&origin=' + encodeURIComponent(location.origin);
    i.title = f.dataset.title || 'Video'; i.allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen'; i.allowFullscreen = true; i.setAttribute('loading', 'lazy');
    // Le clic autorise le son ; on baisse le volume à 50 % dès que le lecteur répond (API YouTube par messages).
    i.addEventListener('load', function () {
      var send = function (func, args) { try { i.contentWindow.postMessage(JSON.stringify({ event: 'command', func: func, args: args || [] }), '*'); } catch (e) {} };
      try { i.contentWindow.postMessage(JSON.stringify({ event: 'listening', id: 1 }), '*'); } catch (e) {}
      [400, 1200, 2500].forEach(function (ms) { setTimeout(function () { send('setVolume', [50]); }, ms); });
    });
    f.replaceWith(i);
    if (window.saTrack) window.saTrack('video', { n: id });
  });
})();
