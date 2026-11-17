// Documentation d'intégration d'Afrolook Ads (17/11/2026) : onglets des cadres de code, bouton « Copier » (sans les numéros de ligne), menu de la section en cours.
(function () {
  'use strict';
  document.querySelectorAll('.dcode[data-tabs]').forEach(function (box) {
    var tabs = box.querySelectorAll('.tab'), pres = box.querySelectorAll('pre');
    tabs.forEach(function (t, i) { t.addEventListener('click', function () { tabs.forEach(function (x, j) { x.classList.toggle('on', j === i); }); pres.forEach(function (p, j) { p.hidden = j !== i; }); }); });
  });
  document.querySelectorAll('.dcode .copy').forEach(function (b) {
    b.addEventListener('click', function () {
      var pre = Array.prototype.filter.call(b.closest('.dcode').querySelectorAll('pre'), function (p) { return !p.hidden; })[0];
      if (!pre) return;
      var c = pre.cloneNode(true); c.querySelectorAll('.ln').forEach(function (n) { n.remove(); });
      var txt = c.textContent;
      var done = function () { b.textContent = 'Copié'; b.classList.add('ok'); setTimeout(function () { b.textContent = 'Copier'; b.classList.remove('ok'); }, 1400); };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(txt).then(done, function () { /* copie refusée */ });
    });
  });
  // testeur d'intégration : lit une page du diffuseur par l'API (rien n'est compté ni enregistré)
  var tf = document.getElementById('dx-test'), out = document.getElementById('dx-test-out');
  if (tf && out) tf.addEventListener('submit', function (e) {
    e.preventDefault();
    var b = tf.querySelector('button'), url = tf.url.value.trim(); if (!url) return;
    var line = function (lv, t) { var li = document.createElement('li'); li.className = lv; var i = document.createElement('i'); i.textContent = lv === 'ok' ? '✓' : (lv === 'warn' ? '!' : '×'); li.appendChild(i); var s = document.createElement('span'); s.textContent = t; li.appendChild(s); out.appendChild(li); };
    out.textContent = ''; b.disabled = true; b.textContent = 'Lecture…';
    fetch(tf.getAttribute('data-api') + '/check?url=' + encodeURIComponent(url)).then(function (r) { return r.json().then(function (j) { return [r.status, j]; }); })
      .then(function (x) { var j = x[1]; if (x[0] === 429) return line('warn', 'Trop d’essais : réessaie dans une minute.'); if (!j || !j.checks) return line('error', 'Adresse invalide : écris l’adresse complète d’une page de ton site.'); j.checks.forEach(function (c) { line(c.level, c.text); }); })
      .catch(function () { line('error', 'Test impossible pour le moment : vérifie ta connexion.'); })
      .then(function () { b.disabled = false; b.textContent = 'Tester'; });
  });

  var links = document.querySelectorAll('.dx-side a');
  if (!links.length || !('IntersectionObserver' in window)) return;
  var io = new IntersectionObserver(function (es) {
    es.forEach(function (e) { if (e.isIntersecting) links.forEach(function (a) { a.classList.toggle('on', a.getAttribute('href') === '#' + e.target.id); }); });
  }, { rootMargin: '-30% 0px -60% 0px' });
  document.querySelectorAll('.dx-main > section[id]').forEach(function (s) { io.observe(s); });
})();
