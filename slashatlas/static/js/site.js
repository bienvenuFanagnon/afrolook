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
  function refClass() {
    var r = document.referrer; if (!r) return 'direct';
    var h; try { h = new URL(r).hostname; } catch (e) { return 'other'; }
    if (h === location.hostname) return 'internal';
    if (/google\.|bing\.|duckduckgo\.|yahoo\.|ecosia\.|qwant\./.test(h)) return 'search';
    if (/tiktok\.|instagram\.|facebook\.|youtube\.|t\.co|x\.com|twitter\.|pinterest\.|reddit\.|linkedin\.|whatsapp\.|threads\./.test(h)) return 'social';
    return 'other';
  }
  var n = parseInt(sstore('sa_n') || '0', 10) + 1; sstore('sa_n', String(n));
  var returning = store('sa_seen') === '1'; store('sa_seen', '1');
  track('pv', { n: n, r: n === 1 ? refClass() : 'internal', ret: returning ? 1 : 0 });

  // ── Langue : à la première visite, selon le navigateur ──
  $$('[data-lang-switch]').forEach(function (a) { a.addEventListener('click', function () { store('sa_lang', a.dataset.langSwitch); }); });
  if (!isBot && (location.pathname === '/' || location.pathname === '/en/') && !store('sa_lang') && !location.search) {
    var want = (navigator.language || 'fr').toLowerCase().indexOf('fr') === 0 ? 'fr' : 'en';
    store('sa_lang', want);
    if (want !== lang) { var a = $('[data-lang-switch]'); if (a) location.replace(a.getAttribute('href')); }
  }

  // ── Copier ──
  function fallbackCopy(txt, done) { var ta = document.createElement('textarea'); ta.value = txt; ta.style.cssText = 'position:fixed;opacity:0'; document.body.appendChild(ta); ta.select(); try { document.execCommand('copy'); } catch (e) {} ta.remove(); done(); }
  document.addEventListener('click', function (e) {
    var el = e.target.closest('[data-copy]');
    if (el) {
      var src = $(el.dataset.copy); if (!src) return;
      var old = el.textContent;
      var done = function () { el.textContent = lang === 'fr' ? 'Copié ✓' : 'Copied ✓'; if (el.dataset.after) { var a = $('#after'); if (a) a.classList.add('on'); } setTimeout(function () { el.textContent = old; }, 1800); track('copy', { s: el.dataset.slug || '' }); };
      var txt = src.textContent;
      try { navigator.clipboard.writeText(txt).then(done, function () { fallbackCopy(txt, done); }); } catch (err) { fallbackCopy(txt, done); }
      return;
    }
    var t = e.target.closest('[data-test]'); if (t) track('test', { tool: t.dataset.test });
  });

  // ── Recherche et filtre ──
  var q = $('#q');
  if (q) {
    var cat = '', list = $$('#list .card'), none = $('#none');
    var apply = function () {
      var v = q.value.trim().toLowerCase(), c = 0;
      list.forEach(function (card) { var hit = (!cat || card.dataset.cat === cat) && (!v || card.dataset.search.indexOf(v) > -1); card.hidden = !hit; if (hit) c++; });
      if (none) none.hidden = c > 0;
    };
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

  // ── Compte Google facultatif : le SDK se charge au clic ou si la personne est déjà connectée ──
  (function () {
    var loaded = false;
    function load() { if (loaded) return Promise.resolve(); loaded = true; return import('/js/auth.js').catch(function () { loaded = false; }); }
    document.addEventListener('click', function (e) {
      var b = e.target.closest && e.target.closest('[data-auth]');
      if (b && !loaded) { e.preventDefault(); e.stopImmediatePropagation(); load().then(function () { b.click(); }); }
    }, true);
    if (store('sa_in') === '1' || page === 'account' || page === 'admin') load();
    else {
      // préchargement dès qu'on approche du bouton, pour que la fenêtre Google s'ouvre sans blocage
      var warm = function (e) { if (e.target.closest && e.target.closest('[data-auth],[data-login]')) { load(); document.removeEventListener('pointerover', warm); document.removeEventListener('focusin', warm); } };
      document.addEventListener('pointerover', warm); document.addEventListener('focusin', warm);
    }
  })();
})();
