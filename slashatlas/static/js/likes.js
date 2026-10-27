// « J'aime » sur les commandes : compteurs affichés partout où une commande apparaît (liste, rangées, favoris, page de détail, communauté, profils).
// Un bouton = [data-like="<commande>"] ; un compteur en lecture seule = [data-likecount="<commande>"].
// On peut aimer SANS compte : l'appareil reçoit un identifiant anonyme (localStorage) ; connecté, le J'aime suit le compte. Un seul J'aime par commande.
// À ne pas confondre avec le cœur « Favori », qui est privé et reste dans le navigateur.
(function () {
  'use strict';
  var lang = document.body.dataset.lang === 'en' ? 'en' : 'fr';
  var T = {
    fr: { err: 'Impossible pour le moment. Réessayez.', one: ' J’aime', many: ' J’aime', ask: 'Cette commande vous a plu ?', yes: 'J’aime', no: 'Plus tard' },
    en: { err: 'Not possible right now. Please try again.', one: ' like', many: ' likes', ask: 'Did you like this command?', yes: 'Like', no: 'Later' },
  }[lang];
  var counts = {}, mine = {}, ready = false, mineLoaded = false;

  // identifiant anonyme de l'appareil (aucune donnée personnelle)
  function anonId() {
    try {
      var id = localStorage.getItem('sa_aid');
      if (!/^a[a-z0-9]{15,40}$/.test(id || '')) {
        var a = new Uint8Array(12); (window.crypto || window.msCrypto).getRandomValues(a);
        id = 'a' + Array.prototype.map.call(a, function (x) { return ('0' + x.toString(16)).slice(-2); }).join('');
        localStorage.setItem('sa_aid', id);
      }
      return id;
    } catch (e) { return 'a' + Math.random().toString(36).slice(2, 18) + Math.random().toString(36).slice(2, 10); }
  }

  // appel à l'API : avec le jeton si un compte est connecté, sinon anonyme
  function api(path, body) {
    body = body || {}; body.anon = anonId();
    if (window.slashAuth && window.slashAuth.user) return window.slashAuth.call(path, body);
    return fetch('/api/' + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })
      .then(function (r) { return r.json().catch(function () { return {}; }).then(function (d) { return { status: r.status, data: d }; }); });
  }

  function fmt(n) { return n >= 10000 ? Math.round(n / 1000) + 'k' : n >= 1000 ? (Math.round(n / 100) / 10) + 'k' : String(n); }
  function paintBtn(b) {
    var s = b.dataset.like, n = counts[s] || 0, on = !!mine[s], c = b.querySelector('b');
    b.classList.toggle('on', on); b.setAttribute('aria-pressed', String(on));
    if (c) { c.textContent = n > 0 ? fmt(n) : ''; c.hidden = n <= 0; }
  }
  function paint(root) {
    Array.prototype.forEach.call((root || document).querySelectorAll('[data-like]'), paintBtn);
    Array.prototype.forEach.call((root || document).querySelectorAll('[data-likecount]'), function (e) {
      var n = counts[e.dataset.likecount] || 0; e.hidden = n <= 0; e.textContent = n > 0 ? '· ' + fmt(n) + (n > 1 ? T.many : T.one) : '';
    });
  }
  function repaintSlug(s) { Array.prototype.forEach.call(document.querySelectorAll('[data-like="' + s + '"]'), paintBtn); }

  // totaux publics : une seule lecture, gardée 3 minutes dans le navigateur
  function loadCounts() {
    var cached = null; try { cached = JSON.parse(sessionStorage.getItem('sa_likes') || 'null'); } catch (e) {}
    if (cached && Date.now() - cached.at < 180000) { counts = cached.n || {}; ready = true; paint(); return; }
    fetch('/api/likes').then(function (r) { return r.ok ? r.json() : { n: {} }; }).then(function (j) {
      counts = j.n || {}; ready = true; try { sessionStorage.setItem('sa_likes', JSON.stringify({ at: Date.now(), n: counts })); } catch (e) {} paint();
    }).catch(function () { ready = true; });
  }
  loadCounts();

  // cartes ajoutées plus tard (liste complète, communauté, favoris) : repeintes dès leur arrivée
  var t = null;
  new MutationObserver(function () { clearTimeout(t); t = setTimeout(function () { if (ready) paint(); }, 120); }).observe(document.body, { childList: true, subtree: true });

  // mes J'aime (cet appareil et, si connecté, le compte)
  function loadMine(force) {
    if (mineLoaded && !force) return Promise.resolve();
    mineLoaded = true;
    return api('likes/mine').then(function (r) {
      if (r.status !== 200) { mineLoaded = false; return; }
      mine = {}; (r.data.slugs || []).forEach(function (s) { mine[s] = 1; }); paint();
    }).catch(function () { mineLoaded = false; });
  }
  loadMine();
  document.addEventListener('sa:auth', function () { loadMine(true); }); // connexion ou déconnexion : la liste suit le compte

  // si un compte est connu sur cet appareil, on laisse sa session se rétablir (au plus un instant) avant le premier appel
  var known = false; try { known = !!localStorage.getItem('sa_u'); } catch (e) {}
  if (known && !window.slashAuth) import('/js/auth.js').catch(function () {});

  var toastEl = null, toastT = null;
  function toast(m) {
    if (!toastEl) { toastEl = document.createElement('div'); toastEl.className = 'libtoast'; toastEl.setAttribute('role', 'status'); document.body.appendChild(toastEl); }
    toastEl.textContent = m; toastEl.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(function () { toastEl.classList.remove('on'); }, 2200);
  }

  function doLike(slug) {
    var was = !!mine[slug], n0 = counts[slug] || 0;
    if (was) delete mine[slug]; else mine[slug] = 1;
    counts[slug] = Math.max(0, n0 + (was ? -1 : 1)); repaintSlug(slug); // affichage immédiat, confirmé ensuite par le serveur
    api('likes/toggle', { slug: slug, on: !was }).then(function (r) {
      if (r.status !== 200) throw new Error('x');
      if (r.data.liked) mine[slug] = 1; else delete mine[slug];
      counts[slug] = r.data.count; repaintSlug(slug);
      try { var c = JSON.parse(sessionStorage.getItem('sa_likes') || 'null'); if (c) { c.n[slug] = r.data.count; sessionStorage.setItem('sa_likes', JSON.stringify(c)); } } catch (e) {}
    }).catch(function () {
      if (was) mine[slug] = 1; else delete mine[slug]; counts[slug] = n0; repaintSlug(slug); toast(T.err);
    });
  }
  document.addEventListener('click', function (e) {
    var b = e.target.closest ? e.target.closest('[data-like]') : null; if (!b) return;
    e.preventDefault(); e.stopPropagation();
    doLike(b.dataset.like);
  }, true);

  // Après une copie : « Cette commande vous a plu ? » (une seule fois par commande et par appareil, jamais si elle est déjà aimée)
  var ASK = 'sa_likeask';
  function wasAsked(s) { try { return (JSON.parse(localStorage.getItem(ASK) || '[]')).indexOf(s) > -1; } catch (e) { return false; } }
  function markAsked(s) { try { var a = JSON.parse(localStorage.getItem(ASK) || '[]'); if (a.indexOf(s) < 0) { a.push(s); localStorage.setItem(ASK, JSON.stringify(a.slice(-400))); } } catch (e) {} }
  function closeAsk() { var el = document.getElementById('likeask'); if (el) el.remove(); }
  function ask(slug) {
    if (!slug || mine[slug] || wasAsked(slug) || document.getElementById('likeask')) return;
    markAsked(slug);
    var el = document.createElement('div'); el.id = 'likeask'; el.className = 'likeask'; el.setAttribute('role', 'dialog'); el.setAttribute('aria-label', T.ask);
    el.innerHTML = '<span>' + T.ask + '</span><button type="button" class="btn pri sm" data-y>' + T.yes + '</button><button type="button" class="btn gl sm" data-n>' + T.no + '</button>';
    document.body.appendChild(el);
    el.querySelector('[data-y]').onclick = function () { closeAsk(); doLike(slug); };
    el.querySelector('[data-n]').onclick = closeAsk;
    setTimeout(closeAsk, 12000);
  }
  function askLater(slug) { setTimeout(function () { if (!mine[slug]) ask(slug); }, 1500); } // laisse le temps au message « Copié » et au chargement de mes J'aime
  document.addEventListener('click', function (e) { var c = e.target.closest ? e.target.closest('[data-copy][data-slug]') : null; if (c) askLater(c.dataset.slug); });
  document.addEventListener('sa:copied', function (e) { askLater(e.detail && e.detail.slug); }); // copies faites par les pages de la communauté
})();
