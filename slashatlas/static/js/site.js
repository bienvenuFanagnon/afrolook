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
  track('pv', { n: n, r: n === 1 ? refClass() : 'internal', ret: returning ? 1 : 0, tz: tz, uid: n === 1 ? uid : '', s: n === 1 ? 1 : 0 });
  // page de détails d'une commande : visite comptée (une fois par visite et par commande), pour savoir quelles commandes attirent
  if (page === 'cmd') { var cc = document.getElementById('cmd-cnt'), sl = cc && cc.dataset.slug; if (sl && !sstore('sa_v_' + sl)) { sstore('sa_v_' + sl, '1'); track('view', { s: sl }); } }

  // ── Bouton « Se connecter » de l'en-tête : connexion Google directe (Studio) ou depuis n'importe quelle page, puis retour au Studio ──
  (function () {
    var btns = $$('[data-signin]'); if (!btns.length) return;
    var named = ''; try { named = localStorage.getItem('sa_u') || ''; } catch (e) {}
    var balWrap = document.getElementById('hd-bal-wrap');
    var balEl = document.getElementById('hd-bal');
    var buyBtn = document.getElementById('hd-buy-btn');
    // solde affiché en affiches (1 affiche = coût d'une génération, mémorisé par le Studio)
    function applyBal(n) {
      if (!balWrap || !balEl || n === null || n === '') return;
      var nb = parseInt(n, 10); if (isNaN(nb)) return;
      var gc = 6; try { gc = parseInt(localStorage.getItem('sa_gc') || '6', 10) || 6; } catch (e) {}
      var p = Math.floor(nb / gc);
      balEl.textContent = p + ' ' + (lang === 'en' ? (p === 1 ? 'poster' : 'posters') : (p === 1 ? 'affiche' : 'affiches'));
      balWrap.title = nb + (lang === 'en' ? ' credits' : ' crédits');
      balWrap.hidden = false;
    }
    function applyUser(n) {
      if (!n) return;
      named = n;
      btns.forEach(function (b) { b.textContent = b.dataset.in; b.classList.remove('pri'); b.classList.add('gl'); if (b.dataset.inHref) b.href = b.dataset.inHref; });
      document.body.classList.add('signed');
      try { applyBal(localStorage.getItem('sa_bal')); } catch (e) {}
    }
    window.addEventListener('sa:credits', function (ev) { if (named) applyBal(ev.detail); });
    if (buyBtn) buyBtn.addEventListener('click', function () {
      var studioEl = document.getElementById('studio');
      if (studioEl && window.slashStudio && window.slashStudio.openBuy) { window.slashStudio.openBuy('header'); }
      else { location.href = (lang === 'en' ? '/en/generate/' : '/generer/') + '#account'; }
    });
    applyUser(named);
    // Charger auth.js en arrière-plan pour mettre à jour le bouton si la session Firebase est active
    // (cas où localStorage a été effacé mais la session Firebase persiste)
    if (!named) {
      setTimeout(function () {
        import('/js/auth.js').then(function () {
          document.addEventListener('sa:auth', function h(ev) {
            document.removeEventListener('sa:auth', h);
            if (ev.detail && ev.detail.user) {
              try { applyUser(localStorage.getItem('sa_u') || (ev.detail.user.displayName || '')); } catch (e) {}
            }
          });
        }).catch(function () {});
      }, 300);
    }
    btns.forEach(function (b) {
      b.addEventListener('click', function (e) {
        if (named) { e.preventDefault(); location.href = b.dataset.inHref || b.getAttribute('href'); return; }
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
      var old = el.innerHTML;
      var done = function () { el.innerHTML = (window.saIcon ? window.saIcon('check') : '') + '<span>' + (lang === 'fr' ? 'Copié' : 'Copied') + '</span>'; if (el.dataset.after) { var a = $('#after'); if (a) a.classList.add('on'); window.saAds && window.saAds.late(); } else { window.saAfrolookAds && window.saAfrolookAds.showCopyToast && window.saAfrolookAds.showCopyToast(lang); } window.saWaToast && window.saWaToast(); setTimeout(function () { el.innerHTML = old; }, 1800); track('copy', { s: el.dataset.slug || '' }); };
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
  // Moteur : static/js/sasearch.js (sans accents ni pluriels, synonymes FR/EN, fautes de frappe, classement par pertinence).
  var S = window.SASearch;
  var nq = S ? S.nq : function (s) { return String(s).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, ' ').trim(); };
  var q = $('#q');
  if (q) {
    var cat = '', box = $('#list'), adEl = $('#list .card-ad'), adNext = adEl ? adEl.nextElementSibling : null, list = [], items = [], none = $('#none'), more = $('#more'), STEP = 24, limit = STEP, dirty = false, counter = 0;
    var sel = $('#catsel'), reset = $('#catreset'), fcount = $('#fcount'), fhint = $('#fhint'), sugg = $('#sugg');
    // une fiche = un élément cherchable ; data-o garde l'ordre d'origine (la liste est reclassée quand on cherche, puis remise en ordre)
    var build = function () {
      list = $$('#list .card:not(.card-ad)');
      items = list.map(function (card) {
        if (card.dataset.o == null) card.dataset.o = counter++;
        var code = card.querySelector('.code');
        return { el: card, t: card.dataset.t || '', k: card.dataset.k || '', c: nq(code ? code.textContent : ''), a: card.dataset.search || '', cat: card.dataset.cat, isNew: card.dataset.new === '1', o: +card.dataset.o };
      });
    };
    var apply = function (keep) {
      if (keep !== true) limit = STEP;
      var raw = q.value, searching = !!(S ? S.nq(raw) : nq(raw)), filtering = !!(cat || searching);
      $$('#list .card-ad').forEach(function (a) { a.hidden = filtering; });
      var pool = items.filter(function (it) { return !cat || (cat === '__new' ? it.isNew : it.cat === cat); });
      var res = searching && S ? S.search(pool, raw) : null, ordered;
      if (res) ordered = res.list.map(function (x) { return x.it; });
      else ordered = pool.slice().sort(function (a, b) { return a.o - b.o; });
      if (searching && !S) { var w = nq(raw); ordered = ordered.filter(function (it) { return it.a.indexOf(w) > -1; }); }
      var show = {}, c = ordered.length;
      ordered.slice(0, limit).forEach(function (it) { show[it.o] = 1; });
      items.forEach(function (it) { it.el.hidden = !show[it.o]; });
      // pendant une recherche, les meilleures réponses passent en tête ; sans recherche, l'ordre d'origine revient
      if (res) { ordered.slice(0, limit).reverse().forEach(function (it) { box.insertBefore(it.el, box.firstChild); }); dirty = true; }
      else if (dirty) { items.slice().sort(function (a, b) { return a.o - b.o; }).forEach(function (it) { box.appendChild(it.el); }); if (adEl && adNext) box.insertBefore(adEl, adNext); dirty = false; } // la pub native retrouve sa place
      if (none) none.hidden = c > 0;
      if (sugg) sugg.hidden = c > 0;
      // la liste montre la catégorie choisie, le nombre de résultats, et dit quand les réponses sont seulement proches
      if (sel) { sel.value = cat; sel.classList.toggle('on', !!cat); }
      if (reset) reset.hidden = !filtering;
      if (fcount) fcount.textContent = filtering ? c + (lang === 'fr' ? ' commande' : ' command') + (c > 1 ? 's' : '') : '';
      if (fhint) {
        var near = res && c > 0 && (res.mode === 'fuzzy' || res.mode === 'or');
        fhint.hidden = !near;
        if (near) fhint.textContent = res.mode === 'or' ? (lang === 'fr' ? 'Aucune commande ne contient tous ces mots : voici celles qui en contiennent certains.' : 'No command has all these words: here are the ones that have some of them.') : (lang === 'fr' ? 'Aucun résultat exact : voici les commandes les plus proches de « ' + raw.trim() + ' ».' : 'No exact result: here are the closest commands to “' + raw.trim() + '”.');
      }
      if (more) { more.hidden = c <= limit; more.textContent = (lang === 'fr' ? 'Voir plus (' : 'Show more (') + (c - limit) + ')'; }
    };
    window.saReorder = function () { build(); apply(true); };
    build();
    if (more) more.addEventListener('click', function () { limit += STEP; apply(true); });
    apply();
    q.addEventListener('input', function () { apply(); });
    if (sel) sel.addEventListener('change', function () { cat = sel.value; apply(); try { var u = new URL(location.href); if (cat) u.searchParams.set('cat', cat); else u.searchParams.delete('cat'); history.replaceState(null, '', u); } catch (e) {} });
    if (reset) reset.addEventListener('click', function () { cat = ''; q.value = ''; apply(); try { history.replaceState(null, '', location.pathname); } catch (e) {} });
    // mots proposés quand rien ne correspond
    if (sugg) sugg.addEventListener('click', function (e) { var b = e.target.closest('button[data-w]'); if (b) { q.value = b.dataset.w; apply(); q.focus(); } });
    // /commandes/?cat=... : la catégorie est déjà choisie à l'arrivée
    var mc = /[?&]cat=([a-z0-9_]+)/.exec(location.search); if (mc && sel) { sel.value = mc[1]; if (sel.value === mc[1]) { cat = mc[1]; apply(); } }
    // /commandes/?q=... depuis les liens internes
    var m = /[?&]q=([^&]+)/.exec(location.search); if (m) { q.value = decodeURIComponent(m[1].replace(/\+/g, ' ')); apply(); }
  }

  // ── Propositions instantanées sous le champ de recherche de l'accueil : les meilleures commandes apparaissent pendant la frappe ──
  var hq = $('.hsearch input[name="q"]');
  if (hq && S && document.body.dataset.idx) {
    var hform = hq.form, hbox = document.createElement('div'), hitems = null, hsel = -1, hlist = [];
    hbox.className = 'qsugg'; hbox.setAttribute('role', 'listbox'); hbox.hidden = true;
    hform.style.position = hform.style.position || 'relative'; hform.appendChild(hbox);
    var esc2 = function (t) { return String(t).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
    var base = lang === 'en' ? '/en/c/' : '/c/';
    var load = function () { if (!hitems) hitems = fetch(document.body.dataset.idx).then(function (r) { return r.json(); }).then(function (a) { return a.map(function (c, i) { return { t: c.tt, k: c.kk, c: S.nq(c.c), a: c.q, s: c.s, title: c.t, code: c.c, cat: c.k, o: i }; }); }).catch(function () { return []; }); return hitems; };
    var hide = function () { hbox.hidden = true; hsel = -1; };
    var render = function () {
      var raw = hq.value;
      if (!S.nq(raw)) { hide(); return; }
      load().then(function (all) {
        if (hq.value !== raw) return;
        var r = S.search(all, raw); hlist = r.list.slice(0, 6).map(function (x) { return x.it; });
        if (!hlist.length) { hbox.innerHTML = '<div class="qs-none">' + (lang === 'fr' ? 'Aucune commande pour cette recherche. Essayez un autre mot.' : 'No command for this search. Try another word.') + '</div>'; hbox.hidden = false; return; }
        hbox.innerHTML = hlist.map(function (it, i) { return '<a class="qs" role="option" href="' + base + it.s + '/" data-i="' + i + '"><b>' + esc2(it.title) + '</b><small>' + esc2(it.cat) + ' · <code>' + esc2(it.code) + '</code></small></a>'; }).join('') + '<a class="qs qs-all" href="' + (lang === 'en' ? '/en/commands/' : '/commandes/') + '?q=' + encodeURIComponent(raw.trim()) + '">' + (lang === 'fr' ? 'Voir les ' + r.list.length + ' résultats' : 'See all ' + r.list.length + ' results') + ' ›</a>';
        hbox.hidden = false; hsel = -1;
      });
    };
    hq.addEventListener('input', render);
    hq.addEventListener('focus', function () { load(); if (hq.value.trim()) render(); });
    hq.addEventListener('keydown', function (e) {
      var links = $$('.qs', hbox);
      if (e.key === 'Escape') { hide(); return; }
      if ((e.key === 'ArrowDown' || e.key === 'ArrowUp') && links.length && !hbox.hidden) {
        e.preventDefault(); hsel = (hsel + (e.key === 'ArrowDown' ? 1 : -1) + links.length) % links.length;
        links.forEach(function (a, i) { a.classList.toggle('on', i === hsel); });
      } else if (e.key === 'Enter' && hsel >= 0 && links[hsel]) { e.preventDefault(); location.href = links[hsel].href; }
    });
    document.addEventListener('click', function (e) { if (!hform.contains(e.target)) hide(); });
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
  
  // ── Réglages de l'affiche de vente (prix, contact, QR…) : ils servent seulement à « Générer ici ».
  // Ils sont gardés dans localStorage « sa_sale_v1 », partagé avec le Studio ; la commande copiée reste toujours la commande de base.
  $$('.salebox').forEach(function (sb) {
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
    $$('input,select', sb).forEach(function (i) { i.addEventListener('input', save); i.addEventListener('change', save); });
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
    var cp = v[0] || 0, tr = v[1] || 0, vi = v[2] || 0;
    if (full) {
      var out = [];
      if (cp) out.push(cw(cp));
      if (tr) out.push(tw(tr));
      if (vi) out.push(vw(vi));
      return out.join(' · ');
    }
    // Cartes (téléphone, tablette, ordinateur) : juste le nombre de copies
    if (cp) return cw(cp);
    if (tr) return tw(tr);
    return '';
  };
  var show = function (el, slug, full) { if (!el) return; var v = C(slug); if (v[0] + v[1] + (v[2] || 0) >= MIN) { el.textContent = label(v, full); el.title = cw(v[0]) + ' · ' + tw(v[1]) + ' · ' + vw(v[2] || 0); el.hidden = false; } };
  function paint() {
    Array.prototype.forEach.call(cards, function (c) { show(c.querySelector('.cnt'), c.dataset.slug, false); });
    if (one) show(one, one.dataset.slug, true);
  }
  function esc(t) { return String(t == null ? '' : t).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function genLbl(k) { var gc = 6, vc = 40, tc = 2; try { gc = parseInt(localStorage.getItem('sa_gc') || '6', 10) || 6; vc = parseInt(localStorage.getItem('sa_vc') || '40', 10) || 40; tc = parseInt(localStorage.getItem('sa_tc') || '2', 10) || 2; } catch (e) {} var t = { fr: { img: 'Générer ici', vid: 'Créer une vidéo', txt: 'Générer le texte' }, en: { img: 'Generate here', vid: 'Create a video', txt: 'Generate the text' } }[lang]; k = k || 'img'; return window.saIcon(k === 'vid' ? 'video' : k === 'txt' ? 'edit' : 'sparkle') + '<span>' + t[k] + '</span><small>· ' + (k === 'vid' ? vc : k === 'txt' ? tc : gc) + ' cr</small>'; }
  function copyLbl() { return window.saIcon('copy') + '<span>' + (lang === 'fr' ? 'Copier' : 'Copy') + '</span><small>· ' + (lang === 'fr' ? 'gratuit' : 'free') + '</small>'; }
  function railCard(r) {
    var poster = r.img ? '<div class="poster img' + (r.ratio === '16:9' ? ' ls' : '') + '" style="--ar:' + String(r.ratio || '4:5').replace(':', '/') + '"><img src="/img/c/' + r.slug + '-t.webp" alt="" loading="lazy" decoding="async"><span class="tag">' + esc(r.cat) + '</span></div>'
      : '<div class="poster" style="--x:' + esc(r.x) + ';--y:' + esc(r.y) + ';--r:' + esc(r.r) + '"><span class="tag">' + esc(r.cat) + '</span><span class="shape"></span><b>' + esc(r.poster) + '</b><small>' + esc(r.code) + '</small></div>';
    var href = (lang === 'en' ? '/en/c/' : '/c/') + r.slug + '/';
    var gen = r.can ? '<a class="btn pri copy" href="' + (lang === 'en' ? '/en/generate/' : '/generer/') + '?c=' + r.slug + '" data-try="' + r.slug + '">' + genLbl() + '</a>' : '';
    return '<article class="rc" data-slug="' + r.slug + '" data-search="' + esc(r.code) + '"><a class="rp" href="' + href + '" aria-label="' + esc(r.title) + '">' + poster + '</a><div class="rb"><div class="chead"><code>' + esc(r.code) + '</code><button class="fav" type="button" data-fav="' + r.slug + '" aria-pressed="false" aria-label="' + (lang === 'fr' ? 'Ajouter aux favoris' : 'Add to favorites') + '">' + window.saIcon('heart') + '</button></div><span class="rt">' + esc(r.title) + '</span><span class="cnt" title="' + esc(cw(r.copies) + ' · ' + tw(r.tries)) + '">' + label([r.copies, r.tries], false) + '</span><div class="acts">' + gen + '<button class="btn ' + (r.can ? 'gl' : 'pri') + ' copy" type="button" data-copy="#pp-' + r.slug + '" data-slug="' + r.slug + '">' + copyLbl() + '</button></div><pre id="pp-' + r.slug + '" hidden>' + esc(r.full) + '</pre></div></article>';
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
    pool.forEach(function (r) { if (picked.length < 7 && picked.indexOf(r) < 0 && (per[r.catId] || 0) < 2) take(r); });
    picked.sort(function (a, b) { return b.score - a.score; });
    var have = {}; picked.forEach(function (r) { have[r.slug] = 1; });
    var base = Array.prototype.filter.call(rail.children, function (c) { return c.dataset.slug && !have[c.dataset.slug]; });
    rail.innerHTML = picked.map(railCard).join('');
    if (window.saLib) window.saLib.paint(rail);
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
    var adCard = list.querySelector('.card-ad');
    if (adCard) adCard.remove();
    var items = Array.prototype.slice.call(list.children);
    if (items.filter(function (c) { return score(c.dataset.slug) >= MIN; }).length < 3) {
      if (adCard) { var ref8 = list.children[8]; if (ref8) list.insertBefore(adCard, ref8); else list.appendChild(adCard); }
      return;
    }
    items.map(function (c, i) { return [c, i]; }).sort(function (a, b) { return score(b[0].dataset.slug) - score(a[0].dataset.slug) || a[1] - b[1]; }).forEach(function (x) { list.appendChild(x[0]); });
    if (adCard) { var ref9 = list.children[8]; if (ref9) list.insertBefore(adCard, ref9); else list.appendChild(adCard); }
    if (window.saReorder) window.saReorder();
  }
  function animStat(el, n) {
    if (!el || !n) return;
    var dur = 1400, t0 = performance.now();
    var fmt = function (v) { return Math.round(v).toLocaleString(lang === 'fr' ? 'fr-FR' : 'en-US'); };
    (function step(ts) {
      var p = Math.min((ts - t0) / dur, 1), ease = 1 - Math.pow(1 - p, 3);
      el.textContent = fmt(n * ease);
      if (p < 1) requestAnimationFrame(step); else el.textContent = fmt(n);
    })(t0);
  }
  function showHeroStats(pv, cp, gn) {
    var hs = document.getElementById('hero-stats');
    if (!hs || (!pv && !cp && !gn)) return;
    hs.removeAttribute('hidden');
    animStat(document.getElementById('hstat-pv'), pv || 0);
    animStat(document.getElementById('hstat-cp'), cp || 0);
    var g = document.getElementById('hstat-gn'), gw = g && g.parentNode;
    if (g && gn) { gw.removeAttribute('hidden'); animStat(g, gn); }
  }
  var STATS_KEY = 'sa_hstats', STATS_TTL = 300000; // 5 min
  try {
    var cached = JSON.parse(localStorage.getItem(STATS_KEY) || 'null');
    if (cached && Date.now() - cached.at < STATS_TTL && (cached.pv || cached.cp)) showHeroStats(cached.pv, cached.cp, cached.gn);
  } catch (e) {}
  fetch('/api/popular?l=' + lang).then(function (r) { return r.json(); }).then(function (d) {
    counts = d.counts || {}; paint(); railFill(d.top || []); sortList(counts);
    if (d.globalPv || d.globalCopies || d.globalGens) {
      try { localStorage.setItem(STATS_KEY, JSON.stringify({ at: Date.now(), pv: d.globalPv || 0, cp: d.globalCopies || 0, gn: d.globalGens || 0 })); } catch (e) {}
      showHeroStats(d.globalPv || 0, d.globalCopies || 0, d.globalGens || 0);
    }
  }).catch(function () {});
  window.saPopRefresh = function () { cards = document.querySelectorAll('.card[data-slug], .rc[data-slug]'); paint(); sortList(counts); };
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
        var a = c && c.ads; if (!a || (!a.enabled && !a.afrolook)) return null;
        if (a.enabled) {
          var s = document.createElement('script'); s.async = true; s.crossOrigin = 'anonymous';
          s.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=' + encodeURIComponent(a.client); document.head.appendChild(s);
          var p = document.querySelector('[data-adprefs]'); if (p) { p.hidden = false; p.addEventListener('click', function (e) { e.preventDefault(); try { window.googlefc = window.googlefc || {}; googlefc.callbackQueue = googlefc.callbackQueue || []; googlefc.callbackQueue.push(googlefc.showRevocationMessage); } catch (x) {} }); }
        }
        var _adTimers = {};
        io = 'IntersectionObserver' in window ? new IntersectionObserver(function (es) {
          es.forEach(function (en) {
            var k = en.target.dataset.ad;
            if (en.isIntersecting) {
              window.saTrack && window.saTrack('adview', { n: k, p: window.location.pathname });
              _adTimers[k] = _adTimers[k] || setTimeout(function () { window.saTrack && window.saTrack('ad_engaged', { n: k, p: window.location.pathname }); }, 3000);
            } else {
              clearTimeout(_adTimers[k]); delete _adTimers[k];
            }
          });
        }, { threshold: 0.5 }) : null;
        return a;
      }).catch(function () { return null; }));
    }
    function fill(el, a) {
      if (el.dataset.filled) return;
      var id = a.slots && a.slots[el.dataset.ad];
      if (!id) {
        // Pas de slot AdSense : utiliser la pub Afrolook si activée
        if (a.afrolook && window.saAfrolookAds) { el.dataset.filled = '1'; window.saAfrolookAds.fill(el); }
        else { el.hidden = true; }
        return;
      }
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
      var r = im.getAttribute('data-r'); var src = (kind === 'img' ? '/img/c/' + id + '-' + r + '.webp' : '/img/video/' + r + '-' + id + '.webp') + ((document.body && document.body.dataset.imgv) ? '?v=' + document.body.dataset.imgv : '');
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
    if ('MutationObserver' in window) new MutationObserver(function () { requestAnimationFrame(sync); }).observe(r, { attributes: true, attributeFilter: ['hidden'], childList: true });
    if ('ResizeObserver' in window) new ResizeObserver(sync).observe(r);
    sync(); setTimeout(sync, 400); setTimeout(sync, 1200); setTimeout(sync, 3000); window.addEventListener('load', sync);
  });
  document.addEventListener('keydown', function (e) {
    if ((e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') || e.altKey || e.ctrlKey || e.metaKey) return;
    var t = e.target; if (t && (/^(INPUT|TEXTAREA|SELECT|VIDEO)$/.test(t.tagName) || t.isContentEditable)) return;
    var target = null; Array.prototype.forEach.call(rails, function (r) { if (!r.hidden && r.scrollWidth > r.clientWidth + 4 && (r === document.activeElement || r.contains(document.activeElement) || r.matches(':hover'))) target = r; });
    if (!target) return; e.preventDefault(); var c = target.querySelector('.rc,.vexc,.card'); var w = (c ? c.getBoundingClientRect().width : 240) + 12; target.scrollBy({ left: (e.key === 'ArrowRight' ? 1 : -1) * w * 1.5, behavior: 'smooth' });
  });
})();

// Filtres catégories (.chips2) : drag-to-scroll + boutons prev/next sur desktop
(function () {
  var c2 = document.querySelector('.chips2'); if (!c2) return;
  var fine = window.matchMedia && window.matchMedia('(min-width:720px)').matches;
  var fr = document.body && document.body.dataset.lang !== 'en';
  // Drag-to-scroll souris (tous écrans)
  var down = false, sx = 0, sl = 0, moved = 0;
  c2.addEventListener('pointerdown', function (e) { if (e.pointerType !== 'mouse' || e.button !== 0) return; down = true; sx = e.clientX; sl = c2.scrollLeft; moved = 0; try { c2.setPointerCapture(e.pointerId); } catch (x) {} });
  c2.addEventListener('pointermove', function (e) { if (!down) return; var dx = e.clientX - sx; moved = Math.max(moved, Math.abs(dx)); if (moved > 4) { c2.scrollLeft = sl - dx; } });
  c2.addEventListener('pointerup', function () { down = false; });
  c2.addEventListener('click', function (e) { if (moved > 6) { e.preventDefault(); e.stopPropagation(); } }, { capture: true });
  // Boutons prev/next sur desktop
  if (!fine) return;
  var wrap = document.createElement('div'); wrap.className = 'railwrap'; c2.parentNode.insertBefore(wrap, c2); wrap.appendChild(c2);
  var prev = document.createElement('button'); prev.type = 'button'; prev.className = 'rnav prev'; prev.setAttribute('aria-label', fr ? 'Précédent' : 'Previous'); prev.textContent = '‹';
  var next = document.createElement('button'); next.type = 'button'; next.className = 'rnav next'; next.setAttribute('aria-label', fr ? 'Suivant' : 'Next'); next.textContent = '›';
  wrap.appendChild(prev); wrap.appendChild(next);
  function sync2() { prev.disabled = c2.scrollLeft <= 2; next.disabled = c2.scrollLeft >= c2.scrollWidth - c2.clientWidth - 2; }
  prev.addEventListener('click', function () { c2.scrollBy({ left: -300, behavior: 'smooth' }); });
  next.addEventListener('click', function () { c2.scrollBy({ left: 300, behavior: 'smooth' }); });
  c2.addEventListener('scroll', sync2, { passive: true }); window.addEventListener('resize', sync2);
  if ('ResizeObserver' in window) new ResizeObserver(sync2).observe(c2);
  sync2(); setTimeout(sync2, 400);
})();

// « Gagnez du temps » : le lien de la boutique est confié au Studio (mémoire du navigateur, pas l'adresse) puis devient le QR code de l'affiche
(function () {
  Array.prototype.forEach.call(document.querySelectorAll('form[data-tsaver]'), function (f) {
    f.addEventListener('submit', function (e) {
      e.preventDefault();
      var v = (f.elements.shop.value || '').trim();
      if (v) { try { var k = 'sa_sale_v1', d = JSON.parse(localStorage.getItem(k) || '{}'); d.qrV = v; d.qr = true; localStorage.setItem(k, JSON.stringify(d)); } catch (err) {} }
      try { window.saTrack && window.saTrack('tsaver', { s: v ? 1 : 0 }); } catch (err) {}
      location.href = f.getAttribute('action');
    });
  });
})();

// Hero : rotation fluide des propositions de la deuxième ligne du titre
(function () {
  var el = document.querySelector('.hrot');
  if (!el) return;
  var texts; try { texts = JSON.parse(el.dataset.hrot); } catch (e) { return; }
  if (!texts || texts.length < 2) return;
  var i = 0;
  setInterval(function () {
    el.classList.add('hout');
    setTimeout(function () {
      i = (i + 1) % texts.length;
      el.classList.remove('hout');
      el.classList.add('hin');
      el.textContent = texts[i];
      requestAnimationFrame(function () { requestAnimationFrame(function () { el.classList.remove('hin'); }); });
    }, 390);
  }, 3800);
})();

// Carousel de démos Studio Film & Série + lightbox
(function () {
  // Lightbox partagée
  var overlay = null;
  function buildOverlay() {
    if (overlay) return;
    overlay = document.createElement('div');
    overlay.className = 'fdm-overlay';
    overlay.innerHTML = '<div class="fdm-inner"><button class="fdm-close" aria-label="Fermer">✕</button><video class="fdm-vid" controls playsinline></video></div>';
    document.body.appendChild(overlay);
    overlay.querySelector('.fdm-close').addEventListener('click', closeOverlay);
    overlay.addEventListener('click', function (e) { if (e.target === overlay) closeOverlay(); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeOverlay(); });
  }
  function openOverlay(src) {
    buildOverlay();
    var v = overlay.querySelector('.fdm-vid');
    v.src = src;
    v.currentTime = 0;
    overlay.classList.add('open');
    v.play().catch(function () {});
    document.body.style.overflow = 'hidden';
  }
  function closeOverlay() {
    if (!overlay) return;
    overlay.classList.remove('open');
    var v = overlay.querySelector('.fdm-vid');
    v.pause(); v.src = '';
    document.body.style.overflow = '';
  }

  var reels = document.querySelectorAll('.film-demo-reel');
  if (!reels.length) return;
  reels.forEach(function (reel) {
    var vids = reel.querySelectorAll('.film-demo-vid');
    var dots = reel.querySelectorAll('.fdd');
    var lbl = reel.querySelector('.film-demo-lbl');
    var names; try { names = JSON.parse(reel.dataset.names || '[]'); } catch (e) { names = []; }
    var cur = 0;
    var timer = null;

    // Pré-charger + forcer muted pour débloquer l'autoplay
    Array.prototype.forEach.call(vids, function (v) {
      v.muted = true; v.preload = 'auto'; v.load();
    });

    function show(i) {
      var prev = cur;
      cur = (i + vids.length) % vids.length;
      if (prev !== cur) {
        vids[prev].pause();
        vids[prev].classList.remove('active');
        dots[prev] && dots[prev].classList.remove('active');
      }
      vids[cur].classList.add('active');
      dots[cur] && dots[cur].classList.add('active');
      if (lbl && names[cur]) lbl.textContent = names[cur];
      vids[cur].currentTime = 0;
      vids[cur].play().catch(function () {});
    }

    function startTimer() {
      stopTimer();
      timer = setInterval(function () { show(cur + 1); }, 5500);
    }
    function stopTimer() { if (timer) { clearInterval(timer); timer = null; } }

    // Initialiser la première vidéo
    show(0);
    startTimer();

    // Points de navigation
    dots.forEach(function (d) {
      d.addEventListener('click', function (e) {
        e.stopPropagation();
        stopTimer(); show(+d.dataset.i); startTimer();
      });
    });

    // Clic sur la zone vidéo = lightbox
    reel.addEventListener('click', function (e) {
      if (e.target.classList.contains('fdd')) return;
      var src = vids[cur] && vids[cur].src;
      if (src) openOverlay(src);
    });
    reel.style.cursor = 'pointer';

    // Pause au survol (desktop)
    reel.addEventListener('mouseenter', stopTimer);
    reel.addEventListener('mouseleave', startTimer);
  });
})();

// ── Barre d'onglets : sur la page Générer, l'onglet actif suit l'ancre (#creations, #account) ──
(function () {
  var bar = document.querySelector('.tabbar'); if (!bar || document.body.dataset.page !== 'try') return;
  function sync() {
    var k = location.hash === '#account' ? 'acc' : location.hash === '#creations' ? 'crea' : 'gen';
    Array.prototype.forEach.call(bar.querySelectorAll('a'), function (a) { var on = a.dataset.tab === k; a.classList.toggle('on', on); if (on) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current'); });
  }
  sync(); window.addEventListener('hashchange', sync); window.addEventListener('popstate', sync);
  // l'onglet « Générer » touché depuis Compte ou Créations : retour à la vue Studio sans recharger la page
  var g = bar.querySelector('[data-tab=gen]');
  if (g) g.addEventListener('click', function (e) { if (location.hash) { e.preventDefault(); history.pushState(null, '', location.pathname + location.search); window.dispatchEvent(new HashChangeEvent('hashchange')); } });
})();

// ── Fiche commande (téléphone) : « Copier » et « Générer » collés en bas tant que les boutons de la commande ne sont pas à l'écran ──
(function () {
  var bar = document.querySelector('.fixacts'), inl = document.querySelector('.cmd .acts.big');
  if (!bar || !inl || !('IntersectionObserver' in window)) return;
  new IntersectionObserver(function (es) { bar.hidden = es[0].isIntersecting; }, { rootMargin: '0px 0px -70px 0px' }).observe(inl);
})();
