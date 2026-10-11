(function () {
  'use strict';
  import('/js/auth.js');
  var $ = function (s) { return document.querySelector(s); };
  var days = 14, root = $('#adm');
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var sum = function (rows, k) { return rows.reduce(function (n, r) { return n + (r[k] || 0); }, 0); };
  function merge(rows, k) { var o = {}; rows.forEach(function (r) { var m = r[k] || {}; Object.keys(m).forEach(function (a) { o[a] = (o[a] || 0) + m[a]; }); }); return Object.keys(o).map(function (a) { return [a, o[a]]; }).sort(function (a, b) { return b[1] - a[1]; }); }
  function list(title, pairs, unit) {
    pairs = pairs.slice(0, 10);
    if (!pairs.length) return '<div class="adm-card"><h3>' + title + '</h3><p class="hint">Pas encore de données.</p></div>';
    var max = pairs[0][1];
    return '<div class="adm-card"><h3>' + title + '</h3>' + pairs.map(function (p) { return '<div class="bar"><span class="bl">' + esc(p[0].replace(/_/g, ' ')) + '</span><span class="bt"><i style="width:' + Math.max(3, Math.round(100 * p[1] / max)) + '%"></i></span><b>' + p[1] + '</b></div>'; }).join('') + '</div>';
  }
  var fmt = function (iso) { return iso ? new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—'; };
  function kpi(n, l, sub) { return '<div class="kpi"><b>' + n + '</b><span>' + l + '</span>' + (sub ? '<small>' + sub + '</small>' : '') + '</div>'; }
  function render(d) {
    var r = d.stats, pv = sum(r, 'pv'), cp = sum(r, 'copies');
    var maxPv = Math.max.apply(null, r.map(function (x) { return x.pv || 0; }).concat([1]));
    var rate = pv ? (100 * cp / pv).toFixed(1).replace('.', ',') + ' % des vues' : '';
    var head = '<div class="adm-top"><div class="seg">' + [7, 14, 30, 90].map(function (n) { return '<button type="button" data-d="' + n + '"' + (n === d.days ? ' class="on"' : '') + '>' + n + ' j</button>'; }).join('') + '</div><button class="btn gl sm" type="button" data-logout>Se déconnecter</button></div>';
    var kp = '<div class="kpis">' + kpi(pv, 'Pages vues') + kpi(sum(r, 'sessions'), 'Visites', sum(r, 'returning') + ' retours') + kpi(cp, 'Commandes copiées', rate) + kpi(sum(r, 'tries'), 'Clics « Tester »', 'sur la plateforme') + kpi(sum(r, 'tests'), 'Clics ChatGPT/Gemini') + kpi(d.subscribers.total, 'Inscrits liste', sum(r, 'signups') + ' sur la période') + '</div>';
    var tbl = '<div class="adm-card"><h3>Par jour</h3><div class="tw"><table><thead><tr><th>Jour</th><th>Vues</th><th></th><th>Visites</th><th>Copies</th><th>Tests</th><th>Inscrits</th></tr></thead><tbody>' + r.slice().reverse().map(function (x) { return '<tr><td>' + x.id.slice(5) + '</td><td>' + (x.pv || 0) + '</td><td><span class="bt"><i style="width:' + Math.round(100 * (x.pv || 0) / maxPv) + '%"></i></span></td><td>' + (x.sessions || 0) + '</td><td>' + (x.copies || 0) + '</td><td>' + (x.tests || 0) + '</td><td>' + (x.signups || 0) + '</td></tr>'; }).join('') + '</tbody></table></div></div>';
    var cols = '<div class="adm-grid">' + list('Pages les plus vues', merge(r, 'pages')) + list('Commandes copiées', merge(r, 'cmd')) + list('Commandes à tester', merge(r, 'try')) + list('Outils ouverts', merge(r, 'tool')) + list('Sources', merge(r, 'ref')) + list('Langues', merge(r, 'lang')) + list('Appareils', merge(r, 'dev').map(function (p) { return [{ m: 'mobile', d: 'ordinateur', t: 'tablette' }[p[0]] || p[0], p[1]]; })) + '</div>';
    var subs = '<div class="adm-card"><h3>Dernières inscriptions (' + d.subscribers.total + ')</h3><div class="tw"><table><thead><tr><th>E-mail</th><th>Type</th><th>Langue</th><th>Page</th><th>Note</th><th>Date</th></tr></thead><tbody>' + (d.subscribers.items.map(function (x) { return '<tr><td>' + esc(x.email) + '</td><td>' + esc((x.kinds || []).join(', ')) + '</td><td>' + esc(x.lang) + '</td><td>' + esc(x.page) + '</td><td>' + esc(x.note) + '</td><td>' + fmt(x.at) + '</td></tr>'; }).join('') || '<tr><td colspan="6">Aucune inscription.</td></tr>') + '</tbody></table></div><button class="btn gl sm" type="button" id="csv-s">Exporter en CSV</button></div>';
    root.innerHTML = head + kp + tbl + cols + subs;
    Array.prototype.forEach.call(root.querySelectorAll('[data-d]'), function (b) { b.addEventListener('click', function () { days = +b.dataset.d; load(); }); });
    var csv = $('#csv-s'); if (csv) csv.addEventListener('click', function () {
      var rows = [['email', 'type', 'langue', 'page', 'note', 'date']].concat(d.subscribers.items.map(function (x) { return [x.email, (x.kinds || []).join('+'), x.lang, x.page, x.note, x.at || '']; }));
      var t = rows.map(function (r) { return r.map(function (c) { c = String(c == null ? '' : c); if (/^[=+\-@]/.test(c)) c = "'" + c; return '"' + c.replace(/"/g, '""') + '"'; }).join(','); }).join('\n');
      var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['﻿' + t], { type: 'text/csv' })); a.download = 'slashatlas-inscrits.csv'; a.click();
    });
  }
  function load() {
    root.hidden = false; root.innerHTML = '<p class="hint">Chargement…</p>';
    window.slashAuth.call('admin', { days: days }).then(function (r) {
      if (r.status === 200) { $('#adm-no').hidden = true; render(r.data); }
      else { root.hidden = true; $('#adm-no').hidden = false; }
    }).catch(function () { root.innerHTML = '<p class="hint">Erreur de chargement.</p>'; });
  }
  document.addEventListener('sa:auth', function (e) {
    var u = e.detail.user;
    $('#adm-out').hidden = !!u;
    if (!u) { root.hidden = true; $('#adm-no').hidden = true; return; }
    load();
  });
})();
