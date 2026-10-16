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

  /* ---------- heure locale ---------- */
  $$('time[data-t="hm"]').forEach(function (t) {
    var dt = new Date(t.getAttribute('datetime'));
    if (isNaN(dt)) return;
    t.textContent = dt.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
    t.title = 'Heure locale (' + (tz || 'ton fuseau') + ')';
  });
  $$('.tznote').forEach(function (n) { if (tz) n.textContent = 'Heures affichées dans ton fuseau horaire : ' + tz.replace(/_/g, ' ') + '.'; });

  /* ---------- consentement (UE et Royaume-Uni) ---------- */
  var NON_UE = /^Europe\/(Moscow|Istanbul|Minsk|Kiev|Kyiv|Chisinau|Belgrade|Skopje|Sarajevo|Tirane|Podgorica|Zurich|Simferopol|Volgograd|Samara|Kaliningrad|Saratov|Astrakhan|Ulyanovsk|Kirov)$/;
  var needsConsent = /^Europe\//.test(tz) && !NON_UE.test(tz);
  var consent = store.get('pf_consent');
  var adsAllowed = function () { return !needsConsent || !!(consent && consent.ads === true); };
  var cmp = $('#pf-cmp');
  function showCmp(force) {
    if (!cmp) return;
    cmp.innerHTML = '<p><b>Publicités</b><br>Ce site est gratuit grâce à la publicité. Les publicités de nos partenaires peuvent utiliser des cookies pour choisir et mesurer les annonces. Tu peux accepter ou refuser ; les pronostics restent les mêmes. <a href="/confidentialite" style="color:var(--cy)">En savoir plus</a></p><div class="row"><button class="btn" type="button" data-c="1">Accepter</button><button class="btn sec" type="button" data-c="0">Refuser</button></div>';
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
    if (path === '/') return 'accueil';
    if (path === '/bilan') return 'bilan';
    if (path === '/coupon') return 'coupon';
    if (/^\/football\/[^/]+\/[^/]+\/analyse$/.test(path)) return 'analyse';
    if (/^\/football\/[^/]+\/[^/]+$/.test(path)) return 'match';
    if (/^\/football\/(aujourdhui|demain|\d{4}-\d{2}-\d{2})$/.test(path)) return 'jour';
    if (/^\/football\/[^/]+$/.test(path)) return 'ligue';
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
  send({ t: 'pv', p: pageType(), m: mdata ? mdata.id : undefined, d: /Mobi|Android|iPhone/.test(UA) ? 'm' : (/iPad|Tablet/.test(UA) ? 't' : 'd'), r: source(), s: first ? 1 : 0, l: 'fr' });

  /* ---------- encarts Afrolook ---------- */
  var MSG = ['Débats foot sur Afrolook : donne ton avis sur le match', 'Partage tes pronos entre amis sur Afrolook', 'Tes likes deviennent des pièces sur Afrolook', 'Tu postes des vidéos ? Afrolook te paie tes vues', 'Afrolook : le réseau africain des créateurs'];
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
  function aflNode(slot, i) {
    var a = d.createElement('a'); a.className = 'afl'; a.target = '_blank'; a.rel = 'noopener sponsored'; a.setAttribute('data-afl', slot); a.setAttribute('data-i', String(i || 0));
    a.href = 'https://play.google.com/store/apps/details?id=com.afrotok.afrotok&utm_source=pronoflashia&utm_campaign=' + encodeURIComponent(slot);
    a.innerHTML = '<span class="sp2">Sponsorisé</span><div class="im" style="background-image:url(/img/afl1.jpg)"></div><div class="bd"><span class="bg"><img src="/img/afrolook.png" alt="" width="12" height="12">AFROLOOK</span><p></p><span class="cta">Télécharger gratuitement</span></div>';
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
    var f = d.createElement('iframe'); f.width = wd; f.height = ht; f.scrolling = 'no'; f.setAttribute('loading', 'lazy'); f.title = 'Publicité';
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
    function afrolook() { if (afl && !afl.actif) { el.hidden = true; return; } el.innerHTML = ''; el.style.minHeight = '0'; el.appendChild(aflNode('pub-' + id, 0)); el.style.width = '100%'; }
    if (!adsAllowed() || !nets.length || aflFirst) return afrolook();
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
      cfg = c; if (!c || !c.actif) { slots.forEach(function (s) { s.hidden = true; }); return; }
      if (!('IntersectionObserver' in w)) { slots.forEach(function (s) { fill(s, c); }); return; }
      var io = new IntersectionObserver(function (es) { es.forEach(function (en) { if (en.isIntersecting) { io.unobserve(en.target); fill(en.target, c); } }); }, { rootMargin: '300px' });
      slots.forEach(function (s) { if (retry) { s.removeAttribute('data-done'); s.innerHTML = ''; } io.observe(s); });
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

  /* ---------- clics de partage ---------- */
  $$('[data-copy]').forEach(function (b) { b.addEventListener('click', function () { var u = b.getAttribute('data-copy'); var done = function () { var o = b.textContent; b.textContent = 'Lien copié'; setTimeout(function () { b.textContent = o; }, 1800); }; try { navigator.clipboard.writeText(u).then(done, function () { }); } catch (e) { /* pas de presse-papiers */ } }); });
  $$('a.wa').forEach(function (a) { a.addEventListener('click', function () { send({ t: 'wa', n: pageType() }); }); });

  /* ---------- liste « toutes les familles » de la page d'analyse ---------- */
  var fams = $('#pf-fams');
  if (fams) {
    var secs = $$('.fam'); fams.innerHTML = '<button type="button" aria-pressed="true" data-f="">Tous</button>' + secs.map(function (s) { return '<button type="button" aria-pressed="false" data-f="' + esc(s.getAttribute('data-fam')) + '">' + esc(s.getAttribute('data-fam')) + '</button>'; }).join(''); fams.hidden = false;
    fams.addEventListener('click', function (e) { var b = e.target.closest('button'); if (!b) return; $$('button', fams).forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); }); secs.forEach(function (s) { s.hidden = !!b.getAttribute('data-f') && s.getAttribute('data-fam') !== b.getAttribute('data-f'); }); });
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
    if (cpn) { cpn.hidden = !n || path === '/coupon'; cpn.textContent = 'Mon coupon (' + n + ')'; }
    if (bar) { if (!n || path === '/coupon') bar.hidden = true; else { var r = calc(); bar.hidden = false; bar.innerHTML = '<span>Mon coupon · <b class="num">' + n + '</b> sélection' + (n > 1 ? 's' : '') + (n > 1 ? ' · <b class="num">' + Math.round(r.prob * 100) + ' %</b>' : '') + '</span><a href="/coupon">Voir</a>'; } }
    $$('[data-add]').forEach(function (b) { var p = b.getAttribute('data-add').split('|'); b.setAttribute('aria-pressed', String(sel.some(function (s) { return s.m === p[0] && s.k === p[1]; }))); });
  }
  function toggle(m, k, info) {
    var i = -1; sel.forEach(function (s, j) { if (s.m === m && s.k === k) i = j; });
    if (i >= 0) sel.splice(i, 1);
    else { if (sel.length >= 5) return false; sel.push({ m: m, k: k, l: info.l, f: info.f, p: info.p, r: info.r, n: info.n, x: info.x }); }
    saveSel(); send({ t: 'coupon_add', n: pageType() }); return true;
  }
  /* boutons « ＋ » des pages match et analyse */
  if (mdata) {
    var by = {}; mdata.marches.forEach(function (x) { by[x.k] = x; });
    d.addEventListener('click', function (e) {
      var b = e.target.closest('[data-add]'); if (!b) return;
      var p = b.getAttribute('data-add').split('|'); var x = by[p[1]]; if (!x) return;
      if (!toggle(p[0], p[1], { l: x.l, f: x.f, p: x.p, r: x.r, n: mdata.nom, x: mdata.matrice })) b.title = 'Un coupon contient 5 sélections au plus';
    });
  }
  chrome();

  var root = $('#pf-coupon'), pool = null;
  if (root) {
    try { pool = JSON.parse($('#pf-pool').textContent); } catch (e) { pool = []; }
    var fam = 'Tous'; var FAMS = ['Tous', 'Résultat', 'Buts', 'Mi-temps', 'Handicap', 'Corners', 'Tirs', 'Cartons & fautes', 'Spéciaux'];
    /* un lien de coupon proposé (#id|clé,id|clé) charge ses sélections */
    var hash = decodeURIComponent((location.hash || '').slice(1));
    if (hash && /\|/.test(hash)) { var nsel = []; hash.split(',').forEach(function (h) { var p = h.split('|'); var m = pool.filter(function (x) { return x.id === p[0]; })[0]; var x = m && m.marches.filter(function (y) { return y.k === p[1]; })[0]; if (x) nsel.push({ m: m.id, k: x.k, l: x.l, f: x.f, p: x.p, r: x.r, n: m.nom, x: m.matrice }); }); if (nsel.length) { sel = nsel.slice(0, 5); store.set('pf_coupon', sel); } }
    var panel = $('#pf-cpanel');
    var mq = w.matchMedia ? w.matchMedia('(min-width:900px)') : null;
    var placePanel = function () { if (!panel) return; if (mq && !mq.matches) root.appendChild(panel); else { var side = $('.side .sticky'); if (side) side.insertBefore(panel, side.firstChild); } };
    if (mq && mq.addEventListener) mq.addEventListener('change', placePanel); placePanel();
    var render = function () {
      var html = '<div class="mk" id="pf-fk" style="margin-top:8px">' + FAMS.map(function (f) { return '<button type="button" data-fk="' + esc(f) + '" aria-pressed="' + (f === fam) + '">' + esc(f) + '</button>'; }).join('') + '</div>';
      pool.forEach(function (m) {
        var opts = m.marches.filter(function (x) { return fam === 'Tous' || x.f === fam; }).sort(function (a, b) { return b.p - a.p; });
        if (!opts.length) return;
        html += '<div class="cm" style="margin-top:10px"><div class="hd"><b>' + esc(m.nom) + '</b><span>' + esc(new Date(m.t).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })) + ' · ' + esc(m.ligue) + ' · <a href="' + esc(m.slug) + '/analyse" style="color:var(--cy)">analyse</a></span></div><div class="opts">' +
          opts.slice(0, fam === 'Tous' ? 8 : 24).map(function (x) { var on = sel.some(function (s) { return s.m === m.id && s.k === x.k; }); return '<button type="button" class="op ' + level(x.p) + '" data-pk="' + esc(m.id) + '|' + esc(x.k) + '" aria-pressed="' + on + '"><span>' + esc(x.l) + '<small>' + esc(x.f) + '</small></span><b class="num">' + x.p + ' %</b></button>'; }).join('') + '</div></div>';
      });
      var pk = $('#pf-picker'); if (!pk) { pk = d.createElement('div'); pk.id = 'pf-picker'; root.insertBefore(pk, root.firstChild); }
      pk.innerHTML = '<div class="lbl" style="margin-top:6px">Choisis tes paris</div>' + html;
      if (panel) panel.innerHTML = panelHtml();
      chrome();
    };
    var panelHtml = function () {
      var n = sel.length, r = calc(), pc = Math.round(r.prob * 100), risk = PFc.riskLevel ? PFc.riskLevel(r.prob) : { label: '' };
      var col = r.prob >= .55 ? 'var(--ok)' : r.prob >= .35 ? 'var(--flash)' : r.prob >= .2 ? '#ff9f43' : 'var(--ko)';
      var rows = sel.map(function (s) { return '<div class="sel"><small>' + esc(s.n) + ' · ' + esc(s.f) + '</small><span>' + esc(s.l) + '</span><b class="num">' + s.p + ' %</b><button type="button" data-rm="' + esc(s.m) + '|' + esc(s.k) + '" aria-label="Retirer">✕</button></div>'; }).join('') || '<p class="note" style="margin-top:8px">Choisis 2 à 5 paris. Tu peux en prendre plusieurs dans un même match : le calcul en tient compte.</p>';
      var warns = (PFc.warnings ? PFc.warnings(selForCalc(), r) : []).map(function (x) { return '<div class="' + (x.type === 'info' ? 'i' : '') + '"><span>' + (x.type === 'info' ? 'ℹ️' : '⚠️') + '</span><span>' + esc(x.text) + '</span></div>'; }).join('');
      var swap = '';
      if (n >= 2 && PFc.weakestSwap) {
        var poolMap = {}; pool.forEach(function (m) { poolMap[m.id] = m.marches.map(function (x) { return { key: x.k, libelle: x.l, famille: x.f, pct: x.p, fiabilite: x.r === 'h' ? 'haute' : x.r === 'm' ? 'moyenne' : 'faible' }; }); });
        var sw = PFc.weakestSwap(selForCalc(), poolMap);
        if (sw) { var np = r.prob / (sw.weak.pct / 100) * (sw.better.pct / 100); swap = '<button type="button" class="op" data-swap="' + esc(sw.weak.matchId + '|' + sw.weak.key + '|' + sw.better.key) + '" style="margin-top:8px;width:100%"><span>Remplacer « ' + esc(sw.weak.key && sel.filter(function (s) { return s.k === sw.weak.key && s.m === sw.weak.matchId; })[0].l) + ' » par « ' + esc(sw.better.libelle) + ' »<small>Le coupon passe de ' + pc + ' % à ' + Math.round(np * 100) + ' %</small></span><b class="num" style="color:var(--ok)">+' + (Math.round(np * 100) - pc) + '</b></button>'; }
      }
      var txt = encodeURIComponent('Mon coupon PronoFlash IA (' + pc + ' % de chances que tout passe) :\n' + sel.map(function (s) { return '• ' + s.n + ' : ' + s.l + ' (' + s.p + ' %)'; }).join('\n') + '\n' + location.origin + '/coupon');
      return '<div class="box rk"><div class="lbl">Mon coupon · ' + n + '/5</div>' + rows +
        (n ? '<div style="margin-top:10px"><small class="note">Probabilité que tout passe</small><div class="big num" style="color:' + col + '">' + pc + ' %</div><div class="meter"><i style="left:calc(' + Math.min(pc, 99) + '% - 2px)"></i></div><div style="display:flex;justify-content:space-between;gap:12px;font-size:12px;color:var(--mut);margin-top:6px"><b style="color:' + col + '">' + esc(risk.label) + '</b><span>Sur 100 coupons identiques, environ ' + pc + ' passeraient</span></div></div>' : '') +
        '<div class="wr">' + warns + '</div>' + swap + (n ? '<div class="sh" style="margin-top:10px"><a class="wa" href="https://wa.me/?text=' + txt + '" target="_blank" rel="noopener">Partager sur WhatsApp</a><button type="button" data-clr="1">Vider</button></div>' : '') + '</div>' +
        '<p class="note">PronoFlash IA ne prend aucun pari, n\'affiche aucune cote et ne promet aucun gain. 18+ · Jouez de façon responsable.</p>';
    };
    d.addEventListener('click', function (e) {
      var t = e.target.closest('[data-fk],[data-pk],[data-rm],[data-clr],[data-swap]'); if (!t || !(root.contains(t) || (panel && panel.contains(t)))) return;
      if (t.getAttribute('data-fk')) fam = t.getAttribute('data-fk');
      else if (t.getAttribute('data-pk')) { var p = t.getAttribute('data-pk').split('|'); var m = pool.filter(function (x) { return x.id === p[0]; })[0]; var x = m.marches.filter(function (y) { return y.k === p[1]; })[0]; toggle(p[0], p[1], { l: x.l, f: x.f, p: x.p, r: x.r, n: m.nom, x: m.matrice }); }
      else if (t.getAttribute('data-rm')) { var q = t.getAttribute('data-rm').split('|'); sel = sel.filter(function (s) { return !(s.m === q[0] && s.k === q[1]); }); saveSel(); }
      else if (t.getAttribute('data-clr')) { sel = []; saveSel(); }
      else if (t.getAttribute('data-swap')) { var sp = t.getAttribute('data-swap').split('|'); var mm = pool.filter(function (y) { return y.id === sp[0]; })[0]; var nx = mm && mm.marches.filter(function (y) { return y.k === sp[2]; })[0]; if (nx) { sel = sel.filter(function (s) { return !(s.m === sp[0] && s.k === sp[1]); }); sel.push({ m: mm.id, k: nx.k, l: nx.l, f: nx.f, p: nx.p, r: nx.r, n: mm.nom, x: mm.matrice }); saveSel(); } }
      render();
    });
    render();
  }
})();
