// Favoris et commandes personnalisées. Gardés dans le navigateur (sa_lib_v1) et, quand on est connecté, sur le compte (/api/library),
// pour les retrouver sur tous ses appareils. Une commande personnalisée = la commande de base + vos « touches », texte retouché à la main possible
// (pour la copie) ; « Générer ici » ajoute seulement les touches à la commande (200 caractères au plus, comme la consigne de mise en scène).
// Ce fichier remplit aussi la suite de la page Commandes (index JSON) et la page « Mes commandes ».
(function () {
  'use strict';
  var body = document.body, lang = body.dataset.lang === 'en' ? 'en' : 'fr', page = body.dataset.page, KEY = 'sa_lib_v1', MAXC = 60, TOUCH = 200;
  var IMGQ = body.dataset.imgv ? '?v=' + body.dataset.imgv : '';
  var T = {
    fr: { fav: 'Ajouter aux favoris', unfav: 'Retirer des favoris', added: 'Ajoutée à vos favoris', removed: 'Retirée de vos favoris', saved: 'Commande enregistrée dans « Mes commandes »', deleted: 'Commande supprimée',
      perso: 'Personnaliser cette commande', persoH: 'Ma version de la commande', touch: 'Vos touches', touchPh: 'Ex. : fond rose poudré, ajoute des fleurs, style luxe', touchHint: 'Ajoutées à la fin de la commande (200 caractères au plus).',
      text: 'Texte final (modifiable)', name: 'Nom de votre version', namePh: 'Ma version de {c}', save: 'Enregistrer', update: 'Mettre à jour', copy: 'Copier ma version', gen: 'Générer avec mes touches', close: 'Fermer',
      genNote: '« Générer ici » ajoute vos touches à la commande. Le texte retouché à la main sert à la copie.', versions: 'Vos versions', use: 'Ouvrir', reset: 'Revenir à la commande de base',
      tabFav: 'Favoris', tabMine: 'Mes commandes', emptyFav: 'Touchez le cœur d’une commande pour la retrouver ici.', emptyMine: 'Ouvrez une commande, touchez « Personnaliser », ajoutez vos touches et enregistrez : elle sera ici, prête à resservir.',
      browse: 'Voir les commandes', edit: 'Modifier', del: 'Supprimer', sure: 'Confirmer ?', sync: 'Connectez-vous pour retrouver vos favoris et vos commandes sur tous vos appareils.', login: 'Se connecter', base: 'Commande de base', touches: 'Touches',
      genL: 'Générer ici', copyL: 'Copier', free: 'gratuit', copied: 'Copié', steps: 'étapes', ai: 'Généré par IA' },
    en: { fav: 'Add to favorites', unfav: 'Remove from favorites', added: 'Added to your favorites', removed: 'Removed from your favorites', saved: 'Command saved in “My commands”', deleted: 'Command deleted',
      perso: 'Customize this command', persoH: 'My version of the command', touch: 'Your touches', touchPh: 'E.g. powder pink background, add flowers, luxury style', touchHint: 'Added at the end of the command (200 characters max).',
      text: 'Final text (editable)', name: 'Name of your version', namePh: 'My version of {c}', save: 'Save', update: 'Update', copy: 'Copy my version', gen: 'Generate with my touches', close: 'Close',
      genNote: '“Generate here” adds your touches to the command. Text edited by hand is used for copying.', versions: 'Your versions', use: 'Open', reset: 'Back to the base command',
      tabFav: 'Favorites', tabMine: 'My commands', emptyFav: 'Tap the heart on a command to find it here.', emptyMine: 'Open a command, tap “Customize”, add your touches and save: it will be here, ready to reuse.',
      browse: 'See the commands', edit: 'Edit', del: 'Delete', sure: 'Confirm?', sync: 'Sign in to find your favorites and commands on all your devices.', login: 'Sign in', base: 'Base command', touches: 'Touches',
      genL: 'Generate here', copyL: 'Copy', free: 'free', copied: 'Copied', steps: 'steps', ai: 'AI-generated' },
  }[lang];
  var P = lang === 'en' ? { try: '/en/generate/', cmd: '/en/c/', cmds: '/en/commands/', mine: '/en/my-commands/' } : { try: '/generer/', cmd: '/c/', cmds: '/commandes/', mine: '/mes-commandes/' };
  var ic = function (n) { return window.saIcon ? window.saIcon(n) : ''; };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var track = function (n, d) { try { window.saTrack && window.saTrack(n, d || {}); } catch (e) {} };
  var GEN = function () { try { return parseInt(localStorage.getItem('sa_gc') || '6', 10) || 6; } catch (e) { return 6; } };

  // ── données ──
  function load() {
    try { var d = JSON.parse(localStorage.getItem(KEY) || '{}'); return { favs: Array.isArray(d.favs) ? d.favs : [], customs: Array.isArray(d.customs) ? d.customs : [], at: d.at || 0, synced: d.synced || 0 }; }
    catch (e) { return { favs: [], customs: [], at: 0, synced: 0 }; }
  }
  var lib = load();
  function store() { try { localStorage.setItem(KEY, JSON.stringify(lib)); } catch (e) {} }
  var subs = [];
  function changed() { lib.at = Date.now(); store(); paint(); schedulePush(); subs.forEach(function (f) { try { f(); } catch (e) {} }); }
  function isFav(s) { return lib.favs.indexOf(s) >= 0; }
  function toggleFav(s) { var i = lib.favs.indexOf(s); if (i >= 0) lib.favs.splice(i, 1); else lib.favs.unshift(s); track('fav', { s: s, on: i < 0 ? 1 : 0 }); changed(); return i < 0; }
  function newId() { return (Date.now().toString(36) + Math.random().toString(36).slice(2, 8)).slice(0, 20); }
  function customsOf(slug) { return lib.customs.filter(function (c) { return c.slug === slug; }); }
  function getCustom(id) { return lib.customs.filter(function (c) { return c.id === id; })[0] || null; }
  function saveCustom(c) {
    var i = -1; lib.customs.forEach(function (x, k) { if (x.id === c.id) i = k; });
    c.at = Date.now();
    if (i >= 0) lib.customs[i] = c; else { c.id = c.id || newId(); lib.customs.unshift(c); lib.customs = lib.customs.slice(0, MAXC); }
    track('custom_save', { s: c.slug }); changed(); return c;
  }
  function removeCustom(id) { lib.customs = lib.customs.filter(function (c) { return c.id !== id; }); changed(); }

  // ── synchronisation avec le compte (connexion chargée seulement quand il faut) ──
  function signedIn() { try { return !!localStorage.getItem('sa_u'); } catch (e) { return false; } }
  var authP = null;
  function auth() {
    if (window.slashAuth && window.slashAuth.user) return Promise.resolve(window.slashAuth);
    if (!authP) authP = new Promise(function (res, rej) {
      var to = setTimeout(function () { authP = null; rej(new Error('auth')); }, 15000);
      document.addEventListener('sa:auth', function h(e) { document.removeEventListener('sa:auth', h); clearTimeout(to); if (e.detail && e.detail.user) res(window.slashAuth); else { authP = null; rej(new Error('anon')); } });
      import('/js/auth.js').catch(function (e) { clearTimeout(to); authP = null; rej(e); });
    });
    return authP;
  }
  var pushT = null;
  function schedulePush() { if (!signedIn()) return; clearTimeout(pushT); pushT = setTimeout(push, 1200); }
  function push() {
    return auth().then(function (a) { return a.call('library', { save: 1, favs: lib.favs, customs: lib.customs }); })
      .then(function (r) { if (r && r.status === 200) { lib.synced = Date.now(); store(); } }).catch(function () {});
  }
  // Fusion : jamais synchronisé sur cet appareil = union des deux ; ensuite, le côté modifié le plus récemment l'emporte.
  function pull() {
    return auth().then(function (a) { return a.call('library', {}); }).then(function (r) {
      if (!r || r.status !== 200 || !r.data) return;
      var d = r.data, sf = Array.isArray(d.favs) ? d.favs : [], sc = Array.isArray(d.customs) ? d.customs : [];
      var before = JSON.stringify([lib.favs, lib.customs]), needPush = false;
      if (!lib.synced) {
        sf.forEach(function (s) { if (lib.favs.indexOf(s) < 0) lib.favs.push(s); });
        sc.forEach(function (c) { var mine = getCustom(c.id); if (!mine) lib.customs.push(c); else if ((c.at || 0) > (mine.at || 0)) lib.customs[lib.customs.indexOf(mine)] = c; });
        lib.customs.sort(function (a, b) { return (b.at || 0) - (a.at || 0); }); lib.customs = lib.customs.slice(0, MAXC);
        needPush = JSON.stringify([lib.favs, lib.customs]) !== JSON.stringify([sf, sc]);
      } else if (lib.at > lib.synced) { needPush = true; }
      else { lib.favs = sf; lib.customs = sc; }
      lib.synced = Date.now(); store();
      if (JSON.stringify([lib.favs, lib.customs]) !== before) { paint(); subs.forEach(function (f) { try { f(); } catch (e) {} }); }
      if (needPush) push();
    }).catch(function () {});
  }
  if (signedIn() && (page === 'mine' || page === 'try' || Date.now() - (lib.synced || 0) > 12 * 3600000)) setTimeout(pull, page === 'mine' ? 0 : 1500);

  // ── cœurs ──
  function paint(rootEl) {
    Array.prototype.forEach.call((rootEl || document).querySelectorAll('[data-fav]'), function (b) {
      var on = isFav(b.dataset.fav); b.setAttribute('aria-pressed', String(on)); b.setAttribute('aria-label', on ? T.unfav : T.fav); b.title = on ? T.unfav : T.fav;
    });
  }
  var toastEl = null, toastT = null;
  function toast(t) {
    if (!toastEl) { toastEl = document.createElement('div'); toastEl.className = 'libtoast'; toastEl.setAttribute('role', 'status'); document.body.appendChild(toastEl); }
    toastEl.textContent = t; toastEl.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(function () { toastEl.classList.remove('on'); }, 1900);
  }
  document.addEventListener('click', function (e) {
    var b = e.target.closest('[data-fav]'); if (!b) return;
    e.preventDefault(); e.stopPropagation();
    toast(toggleFav(b.dataset.fav) ? T.added : T.removed);
  });
  paint();

  // ── index des commandes (JSON) ──
  var idxP = null;
  function idx() {
    if (!idxP) idxP = fetch(body.dataset.idx).then(function (r) { if (!r.ok) throw new Error('idx'); return r.json(); }).then(function (a) { var m = {}; a.forEach(function (c, i) { c.ord = i; m[c.s] = c; }); return { list: a, map: m }; });
    return idxP;
  }
  function posterHtml(c) {
    var pl = c.m ? '<span class="vplay2" aria-hidden="true"></span>' : '';
    if (!c.i) return '<div class="poster" style="--x:' + esc(c.x) + ';--y:' + esc(c.y) + ';--r:' + esc(c.z) + '"><span class="tag">' + esc(c.k) + '</span><span class="shape"></span><b>' + esc(c.n) + '</b><small>' + esc(c.c) + '</small>' + pl + '</div>';
    return '<div class="poster img' + (c.r === '16:9' ? ' ls' : '') + '" style="--ar:' + String(c.r).replace(':', '/') + '"><img src="/img/c/' + c.s + '-t.webp' + IMGQ + '" alt="' + esc(c.al) + '" loading="lazy" decoding="async"><span class="tag">' + esc(c.k) + '</span><span class="ai">' + T.ai + '</span>' + (c.nw ? '<span class="nw">' + (lang === 'en' ? 'New' : 'Nouveau') + '</span>' : '') + pl + '</div>';
  }
  var VC = function () { try { return parseInt(localStorage.getItem('sa_vc') || '40', 10) || 40; } catch (e) { return 40; } }, TC = function () { try { return parseInt(localStorage.getItem('sa_tc') || '2', 10) || 2; } catch (e) { return 2; } };
  var GK = { fr: { img: 'Générer ici', vid: 'Créer une vidéo', txt: 'Générer le texte' }, en: { img: 'Generate here', vid: 'Create a video', txt: 'Generate the text' } }[lang];
  var genLbl = function (k) { k = k || 'img'; return ic(k === 'vid' ? 'video' : k === 'txt' ? 'edit' : 'sparkle') + '<span>' + GK[k] + '</span><small>· ' + (k === 'vid' ? VC() : k === 'txt' ? TC() : GEN()) + ' cr</small>'; };
  var tryHref = function (c) { return c.gk === 'vid' ? P.try + '?mode=video' : P.try + '?c=' + c.s; };
  var copyLbl = function () { return ic('copy') + '<span>' + T.copyL + '</span><small>· ' + T.free + '</small>'; };
  var favHtml = function (s) { return '<button class="fav" type="button" data-fav="' + s + '" aria-pressed="false" aria-label="' + T.fav + '">' + ic('heart') + '</button>'; };
  // même carte que card() dans build.mjs
  function cardHtml(c, pre) {
    var href = P.cmd + c.s + '/', id = (pre || 'p-') + c.s;
    return '<article class="card" data-slug="' + c.s + '" data-search="' + esc(c.q) + '" data-t="' + esc(c.tt || '') + '" data-k="' + esc(c.kk || '') + '" data-cat="' + c.a + '"' + (c.nw ? ' data-new="1"' : '') + '><a href="' + href + '" class="cl" aria-label="' + esc(c.t) + '">' + posterHtml(c) + '</a><div class="cb"><div class="chead"><div class="code">' + esc(c.c) + '</div>' + favHtml(c.s) + '</div><h3><a href="' + href + '">' + esc(c.t) + '</a></h3><div class="meta"><span>' + esc(c.k) + (c.o ? '' : ' · ' + c.r) + '</span>' + (c.st ? '<span class="stp">' + c.st + ' ' + T.steps + '</span>' : '') + '<span class="cnt" hidden></span></div><div class="acts">' +
      '<a class="btn pri sm" href="' + tryHref(c) + '" data-try="' + c.s + '">' + genLbl(c.gk) + '</a><button class="btn gl sm" type="button" data-copy="#' + id + '" data-slug="' + c.s + '">' + copyLbl() + '</button></div><pre id="' + id + '" hidden>' + esc(c.p) + '</pre></div></article>';
  }
  function railHtml(c) {
    var href = P.cmd + c.s + '/';
    return '<article class="rc" data-slug="' + c.s + '" role="listitem"><a class="rp" href="' + href + '" aria-label="' + esc(c.t) + '">' + posterHtml(c) + '</a><div class="rb"><div class="chead"><code>' + esc(c.c) + '</code>' + favHtml(c.s) + '</div><span class="rt">' + esc(c.t) + '</span><div class="acts">' +
      '<a class="btn pri copy" href="' + tryHref(c) + '" data-try="' + c.s + '">' + genLbl(c.gk) + '</a><button class="btn gl copy" type="button" data-copy="#pf-' + c.s + '" data-slug="' + c.s + '">' + copyLbl() + '</button></div><pre id="pf-' + c.s + '" hidden>' + esc(c.p) + '</pre></div></article>';
  }

  // ── page Commandes : la suite de la liste arrive de l'index (la page n'en contient que 24) ──
  var list = document.getElementById('list');
  if (list && list.dataset.lazy) {
    idx().then(function (ix) {
      var have = {}; Array.prototype.forEach.call(list.querySelectorAll('.card[data-slug]'), function (c) { have[c.dataset.slug] = 1; });
      var html = ix.list.filter(function (c) { return !have[c.s]; }).map(function (c) { return cardHtml(c); }).join('');
      var tmp = document.createElement('div'); tmp.innerHTML = html;
      var frag = document.createDocumentFragment(); Array.prototype.slice.call(tmp.children).forEach(function (n) { n.hidden = true; frag.appendChild(n); });
      list.appendChild(frag); delete list.dataset.lazy;
      paint(list);
      if (window.saPopRefresh) window.saPopRefresh();
      if (window.saReorder) window.saReorder();
    }).catch(function () {});
  }

  // ── accueil : rangée « Vos favoris » ──
  var homeFavs = document.getElementById('home-favs');
  function fillHomeFavs() {
    if (!homeFavs) return;
    if (!lib.favs.length) { homeFavs.hidden = true; return; }
    idx().then(function (ix) {
      var items = lib.favs.map(function (s) { return ix.map[s]; }).filter(Boolean).slice(0, 12);
      if (!items.length) { homeFavs.hidden = true; return; }
      var rail = document.getElementById('rail-fav'); rail.innerHTML = items.map(railHtml).join(''); paint(rail); homeFavs.hidden = false;
    }).catch(function () {});
  }
  if (homeFavs) { fillHomeFavs(); subs.push(fillHomeFavs); }

  // ── fiche commande : « Personnaliser » ──
  var perso = document.querySelector('.perso[data-perso]');
  if (perso) {
    var slug = perso.dataset.perso, code = perso.dataset.code || '/' + slug, canGen = perso.dataset.gen === '1';
    var basePre = document.getElementById('p-' + slug), baseText = basePre ? basePre.textContent : '';
    var cur = null, handEdited = false;
    var openId = (/[?&]perso=([a-z0-9]+)/.exec(location.search) || [])[1];
    var compose = function (touch) { touch = (touch || '').trim(); return touch ? baseText + ' ' + touch : baseText; };
    var drawClosed = function () {
      var vs = customsOf(slug);
      perso.innerHTML = '<button class="btn gl perso-open" type="button">' + ic('edit') + '<span>' + T.perso + '</span></button>' +
        (vs.length ? '<div class="perso-vers"><b>' + T.versions + '</b>' + vs.map(function (v) { return '<button type="button" class="chip" data-open="' + v.id + '">' + ic('bookmark') + ' ' + esc(v.name || code) + '</button>'; }).join('') + '</div>' : '');
      perso.querySelector('.perso-open').addEventListener('click', function () { cur = null; drawOpen(); track('custom_open', { s: slug }); });
      Array.prototype.forEach.call(perso.querySelectorAll('[data-open]'), function (b) { b.addEventListener('click', function () { cur = getCustom(b.dataset.open); drawOpen(); }); });
    };
    var drawOpen = function () {
      var c = cur || { slug: slug, name: '', touch: '', text: '' };
      handEdited = !!(c.text && c.text !== compose(c.touch));
      perso.innerHTML = '<div class="perso-box"><div class="perso-h"><b>' + ic('edit') + ' ' + T.persoH + '</b><button type="button" class="perso-x" aria-label="' + T.close + '">×</button></div>' +
        '<label>' + T.touch + '<textarea id="ps-touch" rows="2" maxlength="' + TOUCH + '" placeholder="' + esc(T.touchPh) + '">' + esc(c.touch) + '</textarea><small class="hint">' + T.touchHint + '</small></label>' +
        '<label>' + T.text + '<textarea id="ps-text" rows="7" maxlength="3000">' + esc(c.text || compose(c.touch)) + '</textarea></label>' +
        '<button type="button" class="link perso-reset">' + T.reset + '</button>' +
        '<label>' + T.name + '<input id="ps-name" type="text" maxlength="60" placeholder="' + esc(T.namePh.replace('{c}', code)) + '" value="' + esc(c.name) + '"></label>' +
        '<pre id="ps-copy" hidden></pre>' +
        '<div class="perso-acts"><button class="btn pri" type="button" id="ps-save">' + ic('bookmark') + '<span>' + (cur ? T.update : T.save) + '</span></button><button class="btn gl" type="button" id="ps-copybtn" data-copy="#ps-copy" data-slug="' + slug + '">' + ic('copy') + '<span>' + T.copy + '</span></button>' +
        (canGen ? '<button class="btn gl" type="button" id="ps-gen">' + ic('sparkle') + '<span>' + T.gen + '</span><small>· ' + GEN() + ' cr</small></button>' : '') + '</div>' +
        (canGen ? '<p class="hint">' + T.genNote + '</p>' : '') + '</div>';
      var tch = perso.querySelector('#ps-touch'), txt = perso.querySelector('#ps-text'), nm = perso.querySelector('#ps-name'), cp = perso.querySelector('#ps-copy');
      var sync = function () { cp.textContent = txt.value; };
      sync();
      tch.addEventListener('input', function () { if (!handEdited) { txt.value = compose(tch.value); sync(); } });
      txt.addEventListener('input', function () { handEdited = txt.value !== compose(tch.value); sync(); });
      perso.querySelector('.perso-reset').addEventListener('click', function () { handEdited = false; txt.value = compose(tch.value); sync(); });
      perso.querySelector('.perso-x').addEventListener('click', drawClosed);
      perso.querySelector('#ps-save').addEventListener('click', function () {
        cur = saveCustom({ id: cur ? cur.id : '', slug: slug, name: nm.value.trim() || T.namePh.replace('{c}', code), touch: tch.value.trim().slice(0, TOUCH), text: txt.value.trim() });
        toast(T.saved); var sb = perso.querySelector('#ps-save span'); if (sb) sb.textContent = T.update;
      });
      var g = perso.querySelector('#ps-gen');
      if (g) g.addEventListener('click', function () {
        try { sessionStorage.setItem('sa_touch', JSON.stringify({ slug: slug, touch: tch.value.trim().slice(0, TOUCH) })); } catch (e) {}
        track('custom_gen', { s: slug }); location.href = P.try + '?c=' + slug;
      });
      try { perso.scrollIntoView({ behavior: 'smooth', block: 'start' }); } catch (e) {}
    };
    if (openId && getCustom(openId)) { cur = getCustom(openId); drawOpen(); } else drawClosed();
    subs.push(function () { if (!perso.querySelector('.perso-box')) drawClosed(); });
  }

  // ── page « Mes commandes » ──
  var mine = document.getElementById('mine');
  if (mine) {
    var tab = location.hash === '#perso' ? 'mine' : 'fav';
    var draw = function () {
      var head = '<div class="mtabs2" role="tablist"><button type="button" role="tab" data-t="fav" aria-selected="' + (tab === 'fav') + '">' + ic('heart') + ' ' + T.tabFav + ' <i>' + lib.favs.length + '</i></button><button type="button" role="tab" data-t="mine" aria-selected="' + (tab === 'mine') + '">' + ic('bookmark') + ' ' + T.tabMine + ' <i>' + lib.customs.length + '</i></button></div>' +
        (signedIn() ? '' : '<p class="hint mine-sync">' + T.sync + ' <a href="' + P.try + '#account">' + T.login + ' ›</a></p>');
      if (tab === 'fav') {
        if (!lib.favs.length) { mine.innerHTML = head + '<div class="mine-empty">' + ic('heart') + '<p>' + T.emptyFav + '</p><a class="btn pri" href="' + P.cmds + '">' + T.browse + '</a></div>'; bindTabs(); return; }
        mine.innerHTML = head + '<div class="grid" id="mine-grid"><span class="spin" aria-label="…"></span></div>'; bindTabs();
        idx().then(function (ix) {
          var g = document.getElementById('mine-grid'); if (!g) return;
          g.innerHTML = lib.favs.map(function (s) { return ix.map[s]; }).filter(Boolean).map(function (c) { return cardHtml(c, 'pm-'); }).join('');
          paint(g); if (window.saPopRefresh) window.saPopRefresh();
        }).catch(function () {});
        return;
      }
      if (!lib.customs.length) { mine.innerHTML = head + '<div class="mine-empty">' + ic('bookmark') + '<p>' + T.emptyMine + '</p><a class="btn pri" href="' + P.cmds + '">' + T.browse + '</a></div>'; bindTabs(); return; }
      mine.innerHTML = head + '<div class="ccards"><span class="spin" aria-label="…"></span></div>'; bindTabs();
      idx().then(function (ix) {
        var box = mine.querySelector('.ccards'); if (!box) return;
        box.innerHTML = lib.customs.map(function (v) {
          var c = ix.map[v.slug] || { s: v.slug, c: '/' + v.slug, t: '', i: 0 };
          return '<article class="ccard" data-id="' + v.id + '">' + (c.i ? '<a class="ccard-img" href="' + P.cmd + c.s + '/?perso=' + v.id + '"><img src="/img/c/' + c.s + '-t.webp' + IMGQ + '" alt="" loading="lazy"></a>' : '') +
            '<div class="ccard-b"><b>' + esc(v.name) + '</b><small>' + T.base + ' : <a href="' + P.cmd + c.s + '/">' + esc(c.c) + '</a>' + (c.t ? ' · ' + esc(c.t) : '') + '</small>' + (v.touch ? '<small class="ccard-t">' + T.touches + ' : ' + esc(v.touch) + '</small>' : '') +
            '<p class="ccard-p">' + esc(v.text) + '</p><pre id="pc-' + v.id + '" hidden>' + esc(v.text) + '</pre>' +
            '<div class="acts"><button class="btn pri sm" type="button" data-copy="#pc-' + v.id + '" data-slug="' + v.slug + '">' + copyLbl() + '</button>' + (c.gk === 'img' ? '<button class="btn gl sm" type="button" data-cgen="' + v.id + '">' + genLbl('img') + '</button>' : '') +
            '<a class="btn gl sm" href="' + P.cmd + c.s + '/?perso=' + v.id + '">' + ic('edit') + '<span>' + T.edit + '</span></a><button class="btn gl sm ccard-del" type="button" data-del="' + v.id + '">' + ic('trash') + '<span>' + T.del + '</span></button></div></div></article>';
        }).join('');
        Array.prototype.forEach.call(box.querySelectorAll('[data-cgen]'), function (b) { b.addEventListener('click', function () { var v = getCustom(b.dataset.cgen); if (!v) return; try { sessionStorage.setItem('sa_touch', JSON.stringify({ slug: v.slug, touch: v.touch || '' })); } catch (e) {} location.href = P.try + '?c=' + v.slug; }); });
        Array.prototype.forEach.call(box.querySelectorAll('[data-del]'), function (b) { b.addEventListener('click', function () { if (b.dataset.sure) { removeCustom(b.dataset.del); toast(T.deleted); return; } b.dataset.sure = '1'; b.querySelector('span').textContent = T.sure; b.classList.add('warn'); setTimeout(function () { if (b.isConnected) { delete b.dataset.sure; b.querySelector('span').textContent = T.del; b.classList.remove('warn'); } }, 3000); }); });
      }).catch(function () {});
    };
    var bindTabs = function () { Array.prototype.forEach.call(mine.querySelectorAll('[data-t]'), function (b) { b.addEventListener('click', function () { tab = b.dataset.t; try { history.replaceState(null, '', tab === 'mine' ? '#perso' : location.pathname); } catch (e) {} draw(); }); }); };
    draw(); subs.push(draw);
  }

  window.saLib = { paint: paint, isFav: isFav, toggleFav: toggleFav, pull: pull, get favs() { return lib.favs.slice(); }, get customs() { return lib.customs.slice(); } };
})();
