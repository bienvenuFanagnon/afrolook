// Page Parrainage : lien personnel, compteurs (amis inscrits, acheteurs, crédits gagnés) et liste des amis.
(function () {
  'use strict';
  var root = document.getElementById('ref'); if (!root) return;
  var T = {}; try { T = JSON.parse(root.dataset.t); } catch (e) {}
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var state = { checking: true, user: null, data: null, error: false };
  function link(code) { return 'https://slashatlas.com/' + (T.locale === 'en' ? 'en/' : '') + '?ref=' + code; }
  function render() {
    if (state.checking) { root.innerHTML = '<div class="sbox sload"><span class="spin" aria-label="…"></span></div>'; return; }
    if (!state.user) { root.innerHTML = '<div class="sbox"><p class="hint">' + esc(T.loginNote) + '</p><button class="btn pri big" type="button" data-login>' + esc(T.login) + '</button><p class="fmsg" id="auth-msg" role="status" aria-live="polite"></p></div>'; return; }
    var d = state.data; if (!d) { root.innerHTML = '<div class="sbox"><p class="hint">' + (state.error ? '…' : '') + '</p></div>'; return; }
    var url = link(d.code), txt = T.shareText + ' ' + url;
    var rows = d.items.length ? d.items.map(function (x) { return '<li><span>' + esc(x.name) + '</span><small>' + (x.at ? new Date(x.at).toLocaleDateString(T.locale === 'en' ? 'en-GB' : 'fr-FR', { day: 'numeric', month: 'short' }) : '') + '</small><b class="' + (x.bought ? 'ok' : '') + '">' + (x.bought ? esc(T.bought) + ' · +' + x.earned : esc(T.joined)) + '</b></li>'; }).join('') : '<li class="none">' + esc(T.none) + '</li>';
    root.innerHTML = '<div class="sbox refbox"><label class="reflink"><small>' + esc(T.link) + '</small><input id="r-url" type="text" readonly value="' + esc(url) + '"></label>' +
      '<div class="acts"><button class="btn pri" type="button" id="r-copy">' + esc(T.copy) + '</button><a class="btn gl" target="_blank" rel="noopener" href="https://wa.me/?text=' + encodeURIComponent(txt) + '">' + esc(T.wa) + '</a>' + (navigator.share ? '<button class="btn gl" type="button" id="r-share">' + esc(T.share) + '</button>' : '') + '</div></div>' +
      '<div class="refnums"><div><b>' + d.count + '</b><small>' + esc(T.n1) + '</small></div><div><b>' + d.buyers + '</b><small>' + esc(T.n2) + '</small></div><div><b>' + d.credits + '</b><small>' + esc(T.n3) + '</small></div></div>' +
      '<h2 class="refh">' + esc(T.listH) + '</h2><ul class="reflist">' + rows + '</ul><a class="btn gl big" href="' + T.tryUrl + '">' + esc(T.gen) + '</a>';
    var c = document.getElementById('r-copy'), i = document.getElementById('r-url');
    if (c) c.onclick = function () { var done = function () { c.textContent = T.copied; setTimeout(function () { c.textContent = T.copy; }, 1800); try { window.saTrack && window.saTrack('refcopy', {}); } catch (e) {} }; try { navigator.clipboard.writeText(url).then(done, function () { i.select(); document.execCommand('copy'); done(); }); } catch (e) { i.select(); document.execCommand('copy'); done(); } };
    var sh = document.getElementById('r-share'); if (sh) sh.onclick = function () { navigator.share({ text: T.shareText, url: url }).catch(function () {}); };
  }
  import('/js/auth.js');
  document.addEventListener('sa:auth', function (e) {
    state.user = e.detail.user; state.checking = false; state.data = null;
    if (!state.user) { render(); return; }
    render();
    window.slashAuth.call('referrals').then(function (r) { if (r.status === 200) state.data = r.data; else state.error = true; render(); });
  });
  render();
})();
