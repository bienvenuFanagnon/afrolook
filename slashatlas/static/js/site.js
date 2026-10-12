(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var body = document.body, page = body.dataset.page, lang = body.dataset.lang;
  var IMGQ = (document.body && document.body.dataset.imgv) ? '?v=' + document.body.dataset.imgv : ''; // version des images (voir build.mjs)
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
  var GA = { view: 'view_command', copy: 'copy_command', try: 'try_generate', test: 'open_tool', nopub: 'click_no_ads', video: 'video_play', pwa: 'pwa_install', buyopen: 'begin_checkout', paytry: 'add_payment_info', cardwish: 'card_wish', share: 'share', qr: 'qr_add', wa: 'join_group' };
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
  // Identifiant de visiteur anonyme (UUID persistant dans localStorage, jamais partagé cross-site)
  var uid = ''; try { uid = store('sa_uid') || ''; if (!uid) { uid = 'u' + Math.random().toString(36).slice(2, 10) + Math.random().toString(36).slice(2, 10); store('sa_uid', uid); } } catch (e) {}
  track('pv', { n: n, r: n === 1 ? refClass() : 'internal', ret: returning ? 1 : 0, tz: tz, uid: n === 1 ? uid : '' });
  // page de détails d'une commande : visite comptée (une fois par visite et par commande), pour savoir quelles commandes attirent
  if (page === 'cmd') { var cc = document.getElementById('cmd-cnt'), sl = cc && cc.dataset.slug; if (sl && !sstore('sa_v_' + sl)) { sstore('sa_v_' + sl, '1'); track('view', { s: sl }); } }

  // ── Bouton « Se connecter » de l'en-tête : connexion Google directe (Studio) ou depuis n'importe quelle page, puis retour au Studio ──
  (function () {
    var btns = $$('[data-signin]'); if (!btns.length) return;
    var named = ''; try { named = localStorage.getItem('sa_u') || ''; } catch (e) {}
    function applyUser(n) {
      if (!n) return;
      named = n;
      btns.forEach(function (b) { b.textContent = b.dataset.in; b.classList.remove('pri'); b.classList.add('gl'); if (b.dataset.inHref) b.href = b.dataset.inHref; });
    }
    applyUser(named);
    // Charger auth.js en arrière-plan pour mettre à jour le bouton si la session Firebase est active
    // (cas où localStorage a été effacé mais la session Firebase persiste)
    if (!named) {
      setTimeout(function () {
        import('/js/auth.js').then(function () {
          document.addEventListener('sa:auth', function h(ev) {
            document.removeEventListener('sa:auth', h);
            if (ev.detail && ev.detail.user) {
              try { applyUser(localStorage.getItem('sa_u') || ''); } catch (e) {}
            }
          });
        }).catch(function () {});
      }, 300);
    }
    btns.forEach(function (b) {
      b.addEventListener('click', function (e) {
        if (named) return; // déjà connecté : le lien mène au Studio
        e.preventDefault();
        var go = function () { location.href = b.getAttribute('href'); };
        if (b.dataset.busy) return; b.dataset.busy = '1'; var old = b.textContent; b.textContent = '…';
        var done = function () { delete b.dataset.busy; b.textContent = old; };
        var inStudio = !!document.getElementById('studio');
        import('/js/auth.js').then(function () {
          if (!window.slashAuth) { go(); return; }
          if (!inStudio) document.addEventListener('sa:auth', function h(ev) { if (ev.detail && ev.detail.user) { document.removeEventListener('sa:auth', h); go(); } });
          return window.slashAuth.login().then(done, done);
        }).catch(function () { done(); go(); });
      });
    });
  })();

  // ── Parrainage : le code du lien (?ref=…) est gardé 60 jours ; il est envoyé à la création du compte ──
  try {
    var rm = /[?&]ref=([A-Za-z0-9]{7})(?:&|$)/.exec(location.search);
    if (rm) localStorage.setItem('sa_ref', JSON.stringify({ c: rm[1].toUpperCase(), t: Date.now() }));
  } catch (e) {}

  // ── Langue : l'accueil suit la langue du téléphone (script en tête de page) ; seul un choix explicite est mémorisé ──
  $$('[data-lang-switch]').forEach(function (a) { a.addEventListener('click', function () { store('sa_lang_choice', a.dataset.langSwitch); }); });


  // ── Canal WhatsApp : petite invitation après une copie (une seule fois par visite ; jamais après avoir rejoint, 14 jours de pause après fermeture) ──
  var WA_KEY = 'sa_wa';
  function waGet() { try { return JSON.parse(localStorage.getItem(WA_KEY) || '{}'); } catch (e) { return {}; } }
  function waSet(o) { try { var s = waGet(); for (var k in o) s[k] = o[k]; localStorage.setItem(WA_KEY, JSON.stringify(s)); } catch (e) {} }
  window.saWaToast = function () {
    var url = document.body.dataset.wa; if (!url || document.getElementById('wa-toast') || document.getElementById('after')) return;
    var s = waGet(); if (s.j || (s.c && Date.now() - s.c < 14 * 864e5)) return;
    setTimeout(function () {
      if (document.getElementById('wa-toast') || document.querySelector('.pwa')) return;
      var fr = lang === 'fr', d = document.createElement('div'); d.id = 'wa-toast'; d.setAttribute('role', 'status');
      d.innerHTML = '<span class="waic" aria-hidden="true"></span><p>' + (fr ? 'Des surprises arrivent bientôt sur notre canal WhatsApp.' : 'Surprises are coming soon on our WhatsApp channel.') + '</p><a class="btn wa sm" href="' + url + '" target="_blank" rel="noopener" data-wa="toast">' + (fr ? 'Rejoindre' : 'Join') + '</a><button type="button" aria-label="' + (fr ? 'Fermer' : 'Close') + '">×</button>';
      d.querySelector('button').addEventListener('click', function () { waSet({ c: Date.now() }); d.remove(); });
      document.body.appendChild(d);
    }, 1200);
  };

  // ── Copier ──
  function fallbackCopy(txt, done) { var ta = document.createElement('textarea'); ta.value = txt; ta.style.cssText = 'position:fixed;opacity:0'; document.body.appendChild(ta); ta.select(); try { document.execCommand('copy'); } catch (e) {} ta.remove(); done(); }
  document.addEventListener('click', function (e) {
    var el = e.target.closest('[data-copy]');
    if (el) {
      var src = $(el.dataset.copy); if (!src) return;
      var old = el.textContent;
      var done = function () { el.textContent = lang === 'fr' ? 'Copié ✓' : 'Copied ✓'; if (el.dataset.after) { var a = $('#after'); if (a) a.classList.add('on'); window.saAds && window.saAds.late(); } window.saWaToast && window.saWaToast(); setTimeout(function () { el.textContent = old; }, 1800); track('copy', { s: el.dataset.slug || '' }); };
      var txt = src.textContent;
      try { navigator.clipboard.writeText(txt).then(done, function () { fallbackCopy(txt, done); }); } catch (err) { fallbackCopy(txt, done); }
      return;
    }
    var t = e.target.closest('[data-test]'); if (t) track('test', { tool: t.dataset.test });
    var u = e.target.closest('[data-try]'); if (u) track('try', { n: u.dataset.try });
    var np = e.target.closest('a[href$="/pro/"]'); if (np) track('nopub', {});
    var wl = e.target.closest('[data-wa]'); if (wl && wl.tagName === 'A') { track('wa', { n: wl.dataset.wa }); waSet({ j: 1 }); var wt = document.getElementById('wa-toast'); if (wt) wt.remove(); }
  });

  // Copie par sélection + clic droit (ou Ctrl+C) dans la commande : même effet que le bouton « Copier ».
  document.addEventListener('copy', function () {
    try {
      var sel = window.getSelection(), nd = sel && sel.anchorNode; if (!nd) return;
      var pre = (nd.nodeType === 1 ? nd : nd.parentElement).closest('.cmd pre'); if (!pre) return;
      var a = $('#after'); if (a) a.classList.add('on');
      window.saAds && window.saAds.late(); window.saWaToast && window.saWaToast();
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


  // ── Marque et contacts sur le visuel : 3 textes au plus, ajoutés à la commande avec une mise en page soignée ──
  window.saBrand = function (B, items) {
    var list = (items || []).filter(function (r) { return r && r.text; }).slice(0, 3);
    if (!list.length) return '';
    var names = list.map(function (r) { return B.names[r.role] + ' « ' + r.text + ' »'; }).join(' ; ');
    var lay = B.lay + list.map(function (r) { return B.place[r.role]; }).join(' ; ') + '. ' + (B.kind[B.k] || '');
    return B.intro.replace('{L}', names) + ' ' + lay + ' ' + B.outro;
  };
  window.saBrandClean = function (v, max) { return String(v || '').replace(/[«»"“”\u0000-\u001f]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max); };
  
  // ── Adapter la commande au produit : texte libre + un ou plusieurs éléments ──
  $$('.adapt').forEach(function (box) {
    var pre = document.getElementById(box.dataset.for), input = $('input', box), mode = '1';
    var bb = box.nextElementSibling && box.nextElementSibling.classList.contains('brandbox') && !box.nextElementSibling.classList.contains('salebox') ? box.nextElementSibling : null, B = bb ? JSON.parse(bb.dataset.brand) : null;
    var sb = (bb || box).nextElementSibling; sb = sb && sb.classList.contains('salebox') ? sb : null; var SL = sb ? JSON.parse(sb.dataset.sale) : null;
    // éléments de vente cochés : À VENDRE, prix et devise, ancien prix, réduction, marque, contact, place pour un QR code
    function saleExtra() {
      if (!SL) return '';
      var on = function (k) { var c = $('input[data-s="' + k + '"]', sb); return !!(c && c.checked); }, val = function (k) { var e = $('[data-sv="' + k + '"]', sb); return e ? window.saBrandClean(e.value, 40) : ''; };
      var cur = val('cur'), parts = [];
      if (on('tag')) parts.push(SL.el.tag.replace('{v}', SL.tags[val('tagv')] || SL.tags.sale));
      if (on('price') && val('price')) parts.push(SL.el.price.replace('{v}', val('price') + ' ' + cur));
      if (on('old') && val('old')) parts.push(SL.el.old.replace('{v}', val('old') + ' ' + cur));
      if (on('disc') && val('disc')) parts.push(SL.el.disc.replace('{v}', val('disc')));
      if (on('brand') && val('brand')) parts.push(SL.el.brand.replace('{v}', val('brand')));
      if (on('contact') && val('contact')) parts.push(SL.el.contact.replace('{v}', val('contact')));
      var qr = on('qr');
      if (!parts.length && !qr) return '';
      return (parts.length ? SL.intro.replace('{L}', parts.join(' ; ')) : '') + (qr ? ' ' + SL.qrClause : '') + ' ' + SL.outro;
    }
    function build() {
      var type = input.value.trim().replace(/[()]/g, '');
      var clause = (mode === 'n' ? box.dataset.cn : box.dataset.c1).replace('{T}', type ? ' (' + type + ')' : '');
      var extra = bb ? window.saBrand(B, $$('input', bb).map(function (i) { return { role: i.dataset.role, text: window.saBrandClean(i.value, +i.maxLength || 60) }; })) : '';
      var sale = saleExtra();
      if (pre) pre.textContent = box.dataset.code + ' : ' + box.dataset.base + ' ' + clause + (extra ? ' ' + extra : '') + (sale ? ' ' + sale : '');
    }
    input.addEventListener('input', build);
    if (bb) $$('input', bb).forEach(function (i) { i.addEventListener('input', build); });
    if (sb) {
      // ce qui est renseigné ici est gardé (localStorage « sa_sale_v1 ») et repris tel quel dans le Studio « Générer ici », et inversement
      var KEY = 'sa_sale_v1', load = function () { try { return JSON.parse(localStorage.getItem(KEY) || '{}'); } catch (e) { return {}; } };
      var save = function () {
        var d = load(); $$('input[data-s]', sb).forEach(function (c) { d[c.dataset.s] = c.checked; });
        $$('[data-sv]', sb).forEach(function (i) { var k = i.dataset.sv; if (k === 'tagv' || k === 'cur') d[k] = i.value; else d[k + 'V'] = i.value; });
        try { localStorage.setItem(KEY, JSON.stringify(d)); } catch (e) {}
      };
      var d0 = load();
      $$('input[data-s]', sb).forEach(function (c) { if (typeof d0[c.dataset.s] === 'boolean') c.checked = d0[c.dataset.s]; });
      $$('[data-sv]', sb).forEach(function (i) {
        var k = i.dataset.sv, v = k === 'tagv' || k === 'cur' ? d0[k] : d0[k + 'V'];
        if (v == null || v === '') return;
        if (i.tagName === 'SELECT' && !Array.prototype.some.call(i.options, function (o) { return o.value === v || o.text === v; })) { var o = document.createElement('option'); o.textContent = v; i.appendChild(o); }
        i.value = v;
      });
      $$('input,select', sb).forEach(function (i) { i.addEventListener('input', function () { save(); build(); }); i.addEventListener('change', function () { save(); build(); }); });
      build();
    }
    $$('.seg2 button', box).forEach(function (b) { b.addEventListener('click', function () { mode = b.dataset.n; $$('.seg2 button', box).forEach(function (x) { x.setAttribute('aria-pressed', x === b ? 'true' : 'false'); }); build(); }); });
  });
})();

// Commandes les plus copiées : compteurs publics (/api/popular), badges sur les cartes, rangée « Les plus copiées » sur l'accueil, liste triée.
(function () {
  var cards = document.querySelectorAll('.card[data-slug], .rc[data-slug]'), one = document.getElementById('cmd-cnt'), rail = document.getElementById('rail-sel');
  if (!cards.length && !one && !rail) return;
  var lang = document.body.dataset.lang === 'en' ? 'en' : 'fr', MIN = 1, counts = {};
  // counts[slug] = [copies, essais « Générer ici »] ; le total sert au classement
  var C = function (slug) { var v = counts[slug]; return v ? v : [0, 0, 0]; };
  var score = function (slug) { var v = C(slug); return v[0] + 10 * v[1] + 0.2 * (v[2] || 0); }; // un essai « Générer ici » vaut 10 copies, une visite de la page de détails 0,2 copie
  var cw = function (n) { return n + ' ' + (n > 1 ? 'copies' : (lang === 'fr' ? 'copie' : 'copy')); };
  var tw = function (n) { return lang === 'fr' ? n + (n > 1 ? ' essais' : ' essai') : n + (n > 1 ? ' tries' : ' try'); };
  var vw = function (n) { return lang === 'fr' ? n + (n > 1 ? ' visites' : ' visite') : n + (n > 1 ? ' visits' : ' visit'); };
  var label = function (v, full) {
    var out = [];
    if (v[0]) out.push('⧉ ' + (full ? cw(v[0]) : v[0]));
    if (v[1]) out.push('⚡ ' + (full ? tw(v[1]) : v[1]));
    if (v[2]) out.push('👁 ' + (full ? vw(v[2]) : v[2]));
    return out.join(full ? ' · ' : '  ');
  };
  var show = function (el, slug, full) { if (!el) return; var v = C(slug); if (v[0] + v[1] + (v[2] || 0) >= MIN) { el.textContent = label(v, full); el.title = cw(v[0]) + ' · ' + tw(v[1]) + ' · ' + vw(v[2] || 0); el.hidden = false; } };
  function paint() {
    Array.prototype.forEach.call(cards, function (c) { show(c.querySelector('.cnt'), c.dataset.slug, false); });
    if (one) show(one, one.dataset.slug, true);
  }
  function esc(t) { return String(t == null ? '' : t).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function railCard(r) {
    var poster = r.img ? '<div class="poster img' + (r.ratio === '16:9' ? ' ls' : '') + '" style="--ar:' + String(r.ratio || '4:5').replace(':', '/') + '"><img src="/img/c/' + r.slug + '-t.webp" alt="" loading="lazy" decoding="async"><span class="tag">' + esc(r.cat) + '</span></div>'
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
    var pool = top.map(function (r) { r.score = r.copies + 10 * r.tries + 0.2 * (r.views || 0); return r; }).filter(function (r) { return r.score > 0; }).sort(function (a, b) { return b.score - a.score; });
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
    ['sel', 'new', 'vid'].forEach(function (n) { var r = document.getElementById('rail-' + n); if (r) { r.hidden = n !== k; if (n === k) r.scrollLeft = 0; } });
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


// Visuels qui changent à chaque visite : paires avant/après de l'accueil, trio photo → détourage → vidéo, ordre des vidéos d'exemple.
(function () {
  var n = NaN; try { n = parseInt(localStorage.getItem('sa_rot') || '', 10); } catch (e) {}
  if (isNaN(n)) n = Math.floor(Math.random() * 1000); try { localStorage.setItem('sa_rot', String(n + 1)); } catch (e) {}
  var els = document.querySelectorAll('[data-rot]'); if (!els.length) return;
  Array.prototype.forEach.call(els, function (el, k) {
    var kind = el.getAttribute('data-rot');
    if (kind === 'rail') { var kids = Array.prototype.slice.call(el.children); if (kids.length < 2) return; var o = (n + k) % kids.length; kids.slice(o).concat(kids.slice(0, o)).forEach(function (c) { el.appendChild(c); }); return; }
    var ids; try { ids = JSON.parse(el.getAttribute('data-ids')); } catch (e) { return; } if (!ids || !ids.length) return;
    var id = ids[n % ids.length];
    Array.prototype.forEach.call(el.querySelectorAll('img[data-r]'), function (im) {
      var r = im.getAttribute('data-r'); var src = (kind === 'img' ? '/img/c/' + id + '-' + r + '.webp' : '/img/video/' + r + '-' + id + '.webp') + IMGQ;
      if (im.getAttribute('src') !== src) im.setAttribute('src', src);
    });
  });
})();

// Lignes horizontales (produits, vidéos) : sur ordinateur, flèches, glisser avec la souris, et touches ← → quand la souris est au-dessus
// (ou que la ligne a le focus). Sur téléphone, le défilement tactile habituel reste inchangé.
(function () {
  var rails = document.querySelectorAll('.rail'); if (!rails.length) return;
  var fine = window.matchMedia && window.matchMedia('(min-width:720px)').matches;
  var fr = document.body.dataset.lang !== 'en';
  Array.prototype.forEach.call(rails, function (r) {
    var wrap = document.createElement('div'); wrap.className = 'railwrap'; r.parentNode.insertBefore(wrap, r); wrap.appendChild(r);
    var prev = null, next = null;
    function step() { var c = r.querySelector('.rc,.vexc,.card'); return c ? c.getBoundingClientRect().width + 12 : 260; }
    function by(d) { r.scrollBy({ left: d * step() * 1.5, behavior: 'smooth' }); }
    function sync() { wrap.hidden = r.hidden; if (!prev) return; prev.disabled = r.scrollLeft <= 2; next.disabled = r.scrollLeft >= r.scrollWidth - r.clientWidth - 2; }
    if (fine) {
      prev = document.createElement('button'); prev.type = 'button'; prev.className = 'rnav prev'; prev.setAttribute('aria-label', fr ? 'Précédent' : 'Previous'); prev.textContent = '‹';
      next = document.createElement('button'); next.type = 'button'; next.className = 'rnav next'; next.setAttribute('aria-label', fr ? 'Suivant' : 'Next'); next.textContent = '›';
      wrap.appendChild(prev); wrap.appendChild(next); prev.addEventListener('click', function () { by(-1); }); next.addEventListener('click', function () { by(1); });
      // glisser avec la souris (le clic qui suit un vrai glissement est ignoré)
      var down = false, sx = 0, sl = 0, moved = 0;
      r.addEventListener('pointerdown', function (e) { if (e.pointerType !== 'mouse' || e.button !== 0 || e.target.closest('video,button,input')) return; down = true; sx = e.clientX; sl = r.scrollLeft; moved = 0; });
      window.addEventListener('pointermove', function (e) { if (!down) return; var dx = e.clientX - sx; moved = Math.max(moved, Math.abs(dx)); if (moved > 6) { r.classList.add('dragging'); r.scrollLeft = sl - dx; } });
      window.addEventListener('pointerup', function () { if (!down) return; down = false; if (moved > 6) { var stop = function (ev) { ev.preventDefault(); ev.stopPropagation(); }; r.addEventListener('click', stop, { capture: true, once: true }); setTimeout(function () { r.removeEventListener('click', stop, true); }, 0); } r.classList.remove('dragging'); sync(); });
    }
    r.addEventListener('scroll', sync, { passive: true }); window.addEventListener('resize', sync);
    if ('MutationObserver' in window) new MutationObserver(sync).observe(r, { attributes: true, attributeFilter: ['hidden'] });
    sync(); setTimeout(sync, 400); window.addEventListener('load', sync);
  });
  document.addEventListener('keydown', function (e) {
    if ((e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') || e.altKey || e.ctrlKey || e.metaKey) return;
    var t = e.target; if (t && (/^(INPUT|TEXTAREA|SELECT|VIDEO)$/.test(t.tagName) || t.isContentEditable)) return;
    var target = null; Array.prototype.forEach.call(rails, function (r) { if (!r.hidden && r.scrollWidth > r.clientWidth + 4 && (r === document.activeElement || r.contains(document.activeElement) || r.matches(':hover'))) target = r; });
    if (!target) return; e.preventDefault(); var c = target.querySelector('.rc,.vexc,.card'); var w = (c ? c.getBoundingClientRect().width : 240) + 12; target.scrollBy({ left: (e.key === 'ArrowRight' ? 1 : -1) * w * 1.5, behavior: 'smooth' });
  });
})();
