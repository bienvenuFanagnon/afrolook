// Installation de SlashAtlas sur l'écran d'accueil (PWA). Android/Chrome : un seul bouton « Installer » (invite native).
// iPhone/iPad : l'installation passe par le menu Partager de Safari, on montre les deux gestes à faire.
// Fenêtre proposée une fois sur téléphone après quelques secondes ; refus mémorisé 7 jours, puis 30 jours.
(function () {
  'use strict';
  if ('serviceWorker' in navigator) window.addEventListener('load', function () { navigator.serviceWorker.register('/sw.js').catch(function () {}); });
  var body = document.body, lang = body.dataset.lang === 'en' ? 'en' : 'fr', page = body.dataset.page;
  var get = function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } };
  var set = function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} };
  var standalone = (window.matchMedia && matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true;
  if (standalone) { set('sa_pwa', '1'); return; }
  var ua = navigator.userAgent, ios = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var phone = matchMedia('(max-width: 820px)').matches && (matchMedia('(pointer: coarse)').matches || ios);
  var T = {
    fr: { title: 'Installer SlashAtlas', text: 'Retrouvez les commandes en un clic depuis votre écran d’accueil, sans rien télécharger.', go: 'Installer', later: 'Plus tard', ok: 'J’ai compris', menu: 'Installer l’app',
      s1: 'Touchez le bouton Partager', s1b: 'en bas ou en haut de Safari (un carré avec une flèche vers le haut).', s2: 'Choisissez « Sur l’écran d’accueil »', s2b: 'puis touchez Ajouter.' },
    en: { title: 'Install SlashAtlas', text: 'Get the commands in one tap from your home screen, with nothing to download.', go: 'Install', later: 'Later', ok: 'Got it', menu: 'Install the app',
      s1: 'Tap the Share button', s1b: 'at the bottom or top of Safari (a square with an arrow pointing up).', s2: 'Choose “Add to Home Screen”', s2b: 'then tap Add.' },
  }[lang];
  var deferred = null, shown = false, box = null;
  var track = function (n) { try { window.saTrack && window.saTrack('pwa', { n: n }); } catch (e) {} };
  var installed = function () { return get('sa_pwa') === '1'; };
  var available = function () { return !!deferred || ios; };
  window.addEventListener('beforeinstallprompt', function (e) { e.preventDefault(); deferred = e; addMenu(); });
  window.addEventListener('appinstalled', function () { set('sa_pwa', '1'); track('installed'); close(); var m = document.querySelector('[data-install]'); if (m) m.remove(); });
  function snoozed() { return Date.now() < (parseInt(get('sa_pwa_snooze') || '0', 10) || 0); }
  function snooze() { var n = (parseInt(get('sa_pwa_n') || '0', 10) || 0) + 1; set('sa_pwa_n', String(n)); set('sa_pwa_snooze', String(Date.now() + (n >= 2 ? 30 : 7) * 86400000)); }
  function close() { if (box) { box.remove(); box = null; } document.body.style.overflow = ''; }
  function show() {
    if (shown || box) return; shown = true; track('shown');
    box = document.createElement('div'); box.className = 'pwa'; box.setAttribute('role', 'dialog'); box.setAttribute('aria-modal', 'true'); box.setAttribute('aria-labelledby', 'pwa-t');
    var steps = ios && !deferred ? '<ol class="pwa-steps"><li><span class="pwa-n">1</span><div><b>' + T.s1 + '</b><small>' + T.s1b + '</small></div></li><li><span class="pwa-n">2</span><div><b>' + T.s2 + '</b><small>' + T.s2b + '</small></div></li></ol>' : '';
    box.innerHTML = '<div class="pwa-sheet"><div class="pwa-head"><img src="/icons/icon-192.png" width="56" height="56" alt=""><div><b id="pwa-t">' + T.title + '</b><span>' + T.text + '</span></div></div>' + steps +
      '<button class="btn pri big" type="button" data-go>' + (steps ? T.ok : T.go) + '</button>' + (steps ? '' : '<button class="btn gl" type="button" data-later>' + T.later + '</button>') + '</div>';
    document.body.appendChild(box);
    box.addEventListener('click', function (e) {
      if (e.target === box) { snooze(); track('dismiss'); close(); return; }
      if (e.target.closest('[data-later]')) { snooze(); track('dismiss'); close(); return; }
      if (e.target.closest('[data-go]')) {
        if (steps) { snooze(); track('ios_seen'); close(); return; }
        if (!deferred) { close(); return; }
        var d = deferred; deferred = null; close(); d.prompt();
        d.userChoice.then(function (c) { if (c && c.outcome === 'accepted') { set('sa_pwa', '1'); track('accept'); } else { snooze(); track('refuse'); } });
      }
    });
  }
  // lien « Installer l'app » dans le menu du téléphone (toujours possible, même après un refus)
  function addMenu() {
    var m = document.getElementById('mnav'); if (!m || installed() || document.querySelector('[data-install]') || !available()) return;
    var a = document.createElement('a'); a.href = '#install'; a.setAttribute('data-install', ''); a.textContent = T.menu;
    a.addEventListener('click', function (e) { e.preventDefault(); shown = false; var mb = document.querySelector('.menubtn'); if (mb) mb.click(); track('menu'); show(); });
    m.appendChild(a);
  }
  addMenu();
  if (!phone || page === 'admin' || page === 'try') return;
  // quelques secondes après l'arrivée : on attend l'invite de Chrome jusqu'à 20 s au plus (sur iPhone, pas d'invite à attendre)
  var waited = 0, t = setInterval(function () {
    waited += 1;
    if (installed() || snoozed() || document.querySelector('.smodal')) { if (waited > 20) clearInterval(t); if (installed()) clearInterval(t); return; }
    if (waited >= 8 && available()) { clearInterval(t); show(); } else if (waited >= 20) clearInterval(t);
  }, 1000);
})();
