(function () {
  'use strict';
  var $ = function (s) { return document.querySelector(s); };
  var ask = false;
  document.addEventListener('sa:auth', function (e) {
    var u = e.detail.user;
    $('#acc-out').hidden = !!u; $('#acc-in').hidden = !u;
    if (!u) return;
    $('#acc-name').textContent = u.displayName || '';
    $('#acc-mail').textContent = u.email || '';
    var pic = $('#acc-pic'); if (u.photoURL) pic.src = u.photoURL; else pic.hidden = true;
  });
  var del = $('#acc-del'), box = $('#acc');
  if (del) del.addEventListener('click', function () {
    if (!ask) { ask = true; del.textContent = box.dataset.delAsk; del.classList.add('warn'); return; }
    del.disabled = true;
    window.slashAuth.call('account/delete').then(function (r) {
      if (r.status === 200) { try { localStorage.setItem('sa_in', '0'); } catch (e) {} window.slashAuth.signOut(); $('#auth-msg').textContent = box.dataset.delOk; }
      else { del.disabled = false; $('#auth-msg').textContent = '…'; }
    });
  });
})();
