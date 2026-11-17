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
  var links = document.querySelectorAll('.dx-side a');
  if (!links.length || !('IntersectionObserver' in window)) return;
  var io = new IntersectionObserver(function (es) {
    es.forEach(function (e) { if (e.isIntersecting) links.forEach(function (a) { a.classList.toggle('on', a.getAttribute('href') === '#' + e.target.id); }); });
  }, { rootMargin: '-30% 0px -60% 0px' });
  document.querySelectorAll('.dx-main > section[id]').forEach(function (s) { io.observe(s); });
})();
