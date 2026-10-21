// Notifications « commande du jour » : invitation douce après une 1re copie, choix des thèmes, abonnement Web Push, réglages dans Compte.
// iPhone : les notifications ne marchent que si le site est installé sur l'écran d'accueil (iOS 16.4+) : on propose d'abord l'installation (pwa.js).
(function () {
  'use strict';
  var body = document.body, lang = body.dataset.lang === 'en' ? 'en' : 'fr', page = body.dataset.page, VAPID = body.dataset.vapid || '';
  if (page === 'admin') return;
  var get = function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } };
  var set = function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} };
  var del = function (k) { try { localStorage.removeItem(k); } catch (e) {} };
  var ic = function (n) { return window.saIcon ? window.saIcon(n) : ''; };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var track = function (n, d) { try { window.saTrack && window.saTrack(n, d || {}); } catch (e) {} };
  var ua = navigator.userAgent, ios = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var standalone = (window.matchMedia && matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true;
  var THEMES = ['beaute', 'cheveux', 'mode', 'cadeaux', 'douceurs'];
  var T = {
    fr: { row: 'Commande du jour', on: 'Activée', off: 'Désactivée', iosNeed: 'Installez l’app d’abord', title: 'Des commandes illustrées, matin et soir', text: 'Une idée d’affiche illustrée pour vos produits, avec son image. Deux par jour au maximum, désactivable à tout moment.',
      themes: { beaute: 'Beauté & soins', cheveux: 'Cheveux', mode: 'Mode & accessoires', cadeaux: 'Cadeaux & fait main', douceurs: 'Douceurs' }, later: 'Plus tard', enable: 'Activer', save: 'Enregistrer', stop: 'Désactiver les notifications',
      denied: 'Les notifications sont bloquées dans votre navigateur : autorisez-les dans les réglages du site, puis réessayez.', fail: 'Activation impossible pour le moment. Réessayez.', done: 'Notifications activées', saved: 'Thèmes enregistrés', stopped: 'Notifications désactivées',
      hdr: 'Mes thèmes', ios1: 'Sur iPhone, les notifications demandent d’installer SlashAtlas sur l’écran d’accueil.', iosGo: 'Voir comment faire' },
    en: { row: 'Command of the day', on: 'On', off: 'Off', iosNeed: 'Install the app first', title: 'Illustrated commands, morning and evening', text: 'An illustrated poster idea for your products, with its picture. Two a day at most, and you can turn it off at any time.',
      themes: { beaute: 'Beauty & care', cheveux: 'Hair', mode: 'Fashion & accessories', cadeaux: 'Gifts & handmade', douceurs: 'Treats' }, later: 'Later', enable: 'Turn on', save: 'Save', stop: 'Turn off notifications',
      denied: 'Notifications are blocked in your browser: allow them in the site settings, then try again.', fail: 'Could not turn on right now. Please try again.', done: 'Notifications on', saved: 'Themes saved', stopped: 'Notifications off',
      hdr: 'My themes', ios1: 'On iPhone, notifications need SlashAtlas installed on your home screen.', iosGo: 'See how' },
  }[lang];

  var capable = 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  var needInstall = ios && !standalone; // iPhone : pas de notifications tant que l'app n'est pas installée
  function supported() { return !!VAPID && (capable || needInstall); }
  function state() { try { return JSON.parse(get('sa_push') || 'null'); } catch (e) { return null; } }
  function isOn() { var s = state(); return !!(s && s.on && capable && Notification.permission === 'granted'); }
  function status() { return needInstall ? T.iosNeed : isOn() ? T.on + ' · ' + (state().themes || THEMES).length + '/5' : T.off; }

  function b64(s) { var p = '='.repeat((4 - s.length % 4) % 4), r = (s + p).replace(/-/g, '+').replace(/_/g, '/'), raw = atob(r), a = new Uint8Array(raw.length); for (var i = 0; i < raw.length; i++) a[i] = raw.charCodeAt(i); return a; }
  function api(path, data) { return fetch('/api/push/' + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(data) }).then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { return { ok: r.ok, data: j }; }); }); }
  function subscribe(themes, welcome) {
    return navigator.serviceWorker.ready.then(function (reg) {
      return reg.pushManager.getSubscription().then(function (sub) { return sub || reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64(VAPID) }); });
    }).then(function (sub) { return api('sub', { sub: sub.toJSON(), themes: themes, lang: lang, tz: new Date().getTimezoneOffset(), welcome: welcome ? 1 : 0 }); })
      .then(function (r) { if (!r.ok) throw new Error('sub'); set('sa_push', JSON.stringify({ on: 1, themes: themes, at: Date.now() })); return true; });
  }
  function unsubscribe() {
    return navigator.serviceWorker.ready.then(function (reg) { return reg.pushManager.getSubscription(); }).then(function (sub) {
      if (!sub) return null; var ep = sub.endpoint; return sub.unsubscribe().then(function () { return api('unsub', { endpoint: ep }); });
    }).then(function () { del('sa_push'); });
  }

  // ── fenêtre du bas ──
  var box = null;
  function close() { if (box) { box.remove(); box = null; } document.body.style.overflow = ''; }
  function sheet(html, settings) {
    close();
    box = document.createElement('div'); box.className = 'smodal'; box.setAttribute('role', 'dialog'); box.setAttribute('aria-modal', 'true');
    box.innerHTML = '<div class="sheet nsheet">' + html + '</div>';
    document.body.appendChild(box); document.body.style.overflow = 'hidden';
    box.addEventListener('click', function (e) { if (e.target === box) { if (!settings) snooze(); close(); } });
    return box.querySelector('.sheet');
  }
  function snooze() { set('sa_push_snooze', String(Date.now() + 7 * 86400000)); track('push_later'); }
  function chips(sel) { return '<div class="nthemes">' + THEMES.map(function (k) { return '<button type="button" class="nchip" data-th="' + k + '" aria-pressed="' + (sel.indexOf(k) >= 0) + '">' + ic('check') + '<span>' + esc(T.themes[k]) + '</span></button>'; }).join('') + '</div>'; }
  function readThemes(el) { var a = []; Array.prototype.forEach.call(el.querySelectorAll('.nchip[aria-pressed=true]'), function (b) { a.push(b.dataset.th); }); return a.length ? a : THEMES.slice(); }
  function bindChips(el) { Array.prototype.forEach.call(el.querySelectorAll('.nchip'), function (b) { b.addEventListener('click', function () { b.setAttribute('aria-pressed', String(b.getAttribute('aria-pressed') !== 'true')); }); }); }
  function msg(el, t, ok) { var m = el.querySelector('.nmsg'); if (m) { m.textContent = t || ''; m.className = 'fmsg nmsg' + (ok ? ' ok' : ''); } }

  function enable(el, welcome) {
    var themes = readThemes(el), btn = el.querySelector('[data-go]'); if (btn) btn.disabled = true;
    Notification.requestPermission().then(function (p) {
      if (p !== 'granted') { msg(el, p === 'denied' ? T.denied : T.fail); track('push_' + p); if (btn) btn.disabled = false; return; }
      return subscribe(themes, welcome).then(function () { track('push_on', { n: themes.length }); msg(el, T.done, true); setTimeout(close, 900); refreshRow(); });
    }).catch(function () { msg(el, T.fail); if (btn) btn.disabled = false; });
  }
  // invitation douce (après une 1re copie ou génération) : ouvre le choix des thèmes, puis la demande du téléphone
  function invite() {
    if (!supported() || sessionStorage.getItem('sa_push_shown') === '1') return;
    if (isOn() || Date.now() < (parseInt(get('sa_push_snooze') || '0', 10) || 0) || document.querySelector('.smodal')) return;
    if (capable && Notification.permission === 'denied') return;
    try { sessionStorage.setItem('sa_push_shown', '1'); } catch (e) {}
    if (needInstall) { if (window.saPwa && !window.saPwa.installed() && window.saPwa.available()) { track('push_ios_guide'); window.saPwa.show(); } return; }
    track('push_invite');
    var s = sheet('<div class="nhead">' + ic('bell') + '<div><b>' + T.title + '</b><span>' + T.text + '</span></div></div>' + chips(THEMES) + '<p class="fmsg nmsg" role="status" aria-live="polite"></p><button class="btn pri big" type="button" data-go>' + ic('bell') + ' ' + T.enable + '</button><button class="btn gl" type="button" data-later>' + T.later + '</button>');
    bindChips(s);
    s.querySelector('[data-go]').addEventListener('click', function () { enable(s, true); });
    s.querySelector('[data-later]').addEventListener('click', function () { snooze(); close(); });
  }
  // réglages (écran Compte)
  function settings() {
    if (!supported()) return;
    if (needInstall) {
      var g = sheet('<div class="nhead">' + ic('bell') + '<div><b>' + T.row + '</b><span>' + T.ios1 + '</span></div></div><button class="btn pri big" type="button" data-go>' + T.iosGo + '</button><button class="btn gl" type="button" data-later>' + (lang === 'fr' ? 'Fermer' : 'Close') + '</button>', true);
      g.querySelector('[data-go]').addEventListener('click', function () { close(); if (window.saPwa) window.saPwa.show(); }); g.querySelector('[data-later]').addEventListener('click', close); return;
    }
    var on = isOn(), cur = on ? (state().themes || THEMES) : THEMES;
    var s = sheet('<div class="nhead">' + ic('bell') + '<div><b>' + T.row + '</b><span>' + T.text + '</span></div></div><p class="nlbl">' + T.hdr + '</p>' + chips(cur) + '<p class="fmsg nmsg" role="status" aria-live="polite"></p><button class="btn pri big" type="button" data-go>' + (on ? T.save : T.enable) + '</button>' + (on ? '<button class="btn gl" type="button" data-stop>' + T.stop + '</button>' : '<button class="btn gl" type="button" data-later>' + (lang === 'fr' ? 'Fermer' : 'Close') + '</button>'), true);
    bindChips(s);
    s.querySelector('[data-go]').addEventListener('click', function () {
      if (on) { var th = readThemes(s); subscribe(th, false).then(function () { track('push_themes', { n: th.length }); msg(s, T.saved, true); refreshRow(); setTimeout(close, 800); }).catch(function () { msg(s, T.fail); }); }
      else enable(s, true);
    });
    var st = s.querySelector('[data-stop]'); if (st) st.addEventListener('click', function () { unsubscribe().then(function () { track('push_off'); refreshRow(); close(); }).catch(function () { close(); }); });
    var lt = s.querySelector('[data-later]'); if (lt) lt.addEventListener('click', close);
  }
  function refreshRow() { var r = document.querySelector('[data-notif-settings] small'); if (r) r.textContent = status(); }

  window.saNotif = { supported: supported, status: status, settings: settings, invite: invite, T: T };

  // synchronise le fuseau et la langue quand ils changent (voyage, changement de langue) ; sans rien redemander
  if (isOn() && Date.now() - ((state() || {}).at || 0) > 7 * 86400000) subscribe((state() || {}).themes || THEMES, false).catch(function () {});

  // invitation douce : 3 s après une 1re copie d'une commande ou une génération réussie (jamais à l'ouverture de la page)
  document.addEventListener('click', function (e) { if (e.target.closest('[data-copy]')) setTimeout(invite, 3200); });
  window.addEventListener('sa:generated', function () { setTimeout(invite, 2500); });
})();
