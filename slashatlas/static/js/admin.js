(function () {
  'use strict';
  import('/js/auth.js');
  var $ = function (s) { return document.querySelector(s); };
  var days = 14, root = $('#adm'), tab = 'over'; try { tab = sessionStorage.getItem('sa_admtab') || 'over'; } catch (e) {}
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
  function fmtN(n) { return String(n || 0).replace(/\B(?=(\d{3})+(?!\d))/g, ' '); }
  function kpi(n, l, sub) { return '<div class="kpi"><b>' + n + '</b><span>' + l + '</span>' + (sub ? '<small>' + sub + '</small>' : '') + '</div>'; }
  function render(d) {
    var r = d.stats, pv = sum(r, 'pv'), cp = sum(r, 'copies');
    var maxPv = Math.max.apply(null, r.map(function (x) { return x.pv || 0; }).concat([1]));
    var rate = pv ? (100 * cp / pv).toFixed(1).replace('.', ',') + ' % des vues' : '';
    var head = '<div class="adm-top"><div class="seg">' + [7, 14, 30, 90].map(function (n) { return '<button type="button" data-d="' + n + '"' + (n === d.days ? ' class="on"' : '') + '>' + n + ' j</button>'; }).join('') + '</div><button class="btn gl sm" type="button" data-logout>Se déconnecter</button></div>';
    var kpAud = '<div class="kpis">' + kpi(pv, 'Pages vues') + kpi(sum(r, 'sessions'), 'Visites', sum(r, 'returning') + ' retours') + kpi(cp, 'Commandes copiées', rate) + kpi(sum(r, 'tries'), 'Clics « Générer ici »', 'sur la plateforme') + kpi(sum(r, 'tests'), 'Clics ChatGPT/Gemini') + kpi(d.subscribers.total, 'Inscrits liste', sum(r, 'signups') + ' sur la période') + '</div>';
    var kpStu = '<div class="kpis">' + kpi(d.studioUsers || 0, 'Comptes Studio', sum(r, 'accounts') + ' sur la période') + kpi(sum(r, 'generations'), 'Générations', sum(r, 'edits') + ' corrections') + kpi(sum(r, 'orders'), 'Achats de crédits', fmtN(sum(r, 'revenueXof')) + ' FCFA') + kpi(sum(r, 'cardwish'), 'Demandes « carte »', 'clics sur Carte bancaire (bientôt)') + '</div>';
    var kpAds = '<div class="kpis">' + kpi(sum(r, 'adviews'), 'Pubs affichées', 'blocs vus à l’écran') + kpi(pv ? (100 * sum(r, 'adviews') / pv).toFixed(1).replace('.', ',') + ' %' : '—', 'Pubs / pages vues') + '</div>';
    var tbl = '<div class="adm-card"><h3>Par jour</h3><div class="tw"><table><thead><tr><th>Jour</th><th>Vues</th><th></th><th>Visites</th><th>Copies</th><th>Tests</th><th>Inscrits</th></tr></thead><tbody>' + r.slice().reverse().map(function (x) { return '<tr><td>' + x.id.slice(5) + '</td><td>' + (x.pv || 0) + '</td><td><span class="bt"><i style="width:' + Math.round(100 * (x.pv || 0) / maxPv) + '%"></i></span></td><td>' + (x.sessions || 0) + '</td><td>' + (x.copies || 0) + '</td><td>' + (x.tests || 0) + '</td><td>' + (x.signups || 0) + '</td></tr>'; }).join('') + '</tbody></table></div></div>';
    var cols = '<div class="adm-grid">' + list('Pages les plus vues', merge(r, 'pages')) + list('Commandes copiées', merge(r, 'cmd')) + list('Commandes à générer (clics)', merge(r, 'try')) + list('Commandes générées', merge(r, 'gen')) + list('Outils ouverts', merge(r, 'tool')) + list('Sources', merge(r, 'ref')) + list('Langues', merge(r, 'lang')) + list('Appareils', merge(r, 'dev').map(function (p) { return [{ m: 'mobile', d: 'ordinateur', t: 'tablette' }[p[0]] || p[0], p[1]]; })) + '</div>';
    var subs = '<div class="adm-card"><h3>Dernières inscriptions (' + d.subscribers.total + ')</h3><div class="tw"><table><thead><tr><th>E-mail</th><th>Type</th><th>Langue</th><th>Page</th><th>Note</th><th>Date</th></tr></thead><tbody>' + (d.subscribers.items.map(function (x) { return '<tr><td>' + esc(x.email) + '</td><td>' + esc((x.kinds || []).join(', ')) + '</td><td>' + esc(x.lang) + '</td><td>' + esc(x.page) + '</td><td>' + esc(x.note) + '</td><td>' + fmt(x.at) + '</td></tr>'; }).join('') || '<tr><td colspan="6">Aucune inscription.</td></tr>') + '</tbody></table></div><button class="btn gl sm" type="button" id="csv-s">Exporter en CSV</button></div>';
    var ords = '<div class="adm-card"><h3>Dernières commandes</h3><div class="tw"><table><thead><tr><th>Date</th><th>E-mail</th><th>Pack</th><th>Total</th><th>Moyen</th><th>Statut</th><th>CGV</th><th></th></tr></thead><tbody>' + ((d.orders || []).map(function (x) { return '<tr><td>' + fmt(x.at) + '</td><td>' + esc(x.email) + '</td><td>' + esc(x.credits) + ' cr.</td><td>' + fmtN(x.total) + '</td><td>' + esc(x.operator) + '</td><td>' + esc(x.status) + '</td><td>' + esc(x.terms || '—') + '</td><td><button class="btn gl sm" type="button" data-ev="' + esc(x.id) + '">Preuves</button></td></tr>'; }).join('') || '<tr><td colspan="8">Aucune commande.</td></tr>') + '</tbody></table></div><p class="hint">« Preuves » télécharge le dossier de litige : commande, acceptation des conditions (version, date, IP, navigateur), crédits et images générées.</p></div>';
    var usr = '<div class="adm-card"><h3>Offrir ou retirer des crédits</h3><form class="adm-form" id="grant-f"><input id="g-email" type="email" required placeholder="E-mail du compte Studio" autocomplete="off"><input id="g-n" type="number" required min="-500" max="500" step="1" placeholder="Crédits (ex. 5 ou -5)"><input id="g-note" type="text" maxlength="120" placeholder="Motif (ex. geste commercial)"><button class="btn pri sm" type="submit">Appliquer</button></form><p class="fmsg" id="g-msg" role="status" aria-live="polite"></p></div>' +
      '<div class="adm-card"><h3>Derniers comptes Studio (' + (d.studioUsers || 0) + ')</h3><div class="tw"><table><thead><tr><th>E-mail</th><th>Nom</th><th>Crédits</th><th>Inscrit</th><th>Dernière visite</th></tr></thead><tbody>' + ((d.users || []).map(function (x) { return '<tr><td>' + esc(x.email) + '</td><td>' + esc(x.name) + '</td><td>' + esc(x.credits) + '</td><td>' + fmt(x.at) + '</td><td>' + fmt(x.seen) + '</td></tr>'; }).join('') || '<tr><td colspan="5">Aucun compte.</td></tr>') + '</tbody></table></div></div>';
    var A = d.ads || {}, adv = '<div class="adm-card"><h3>Publicité Google AdSense</h3><p class="hint">Quand elle est activée, les blocs apparaissent sur l’accueil, le tutoriel et les packs (jamais sur « Générer ici », ni près d’un bouton). Aucun redéploiement nécessaire.</p><form class="adm-form" id="ads-f"><label class="chk"><input type="checkbox" id="a-on"' + (A.enabled ? ' checked' : '') + '> Publicité activée</label><input id="a-client" placeholder="ID éditeur : ca-pub-1234567890123456" value="' + esc(A.client) + '"><input id="a-lb" placeholder="ID du bloc « bandeau » (chiffres)" value="' + esc((A.slots || {}).lb) + '"><input id="a-rect" placeholder="ID du bloc « rectangle » (chiffres)" value="' + esc((A.slots || {}).rect) + '"><button class="btn pri sm" type="submit">Enregistrer</button></form><p class="fmsg" id="a-msg" role="status" aria-live="polite"></p></div>' +
      '<div class="adm-card"><h3>Avant d’activer</h3><ul class="adm-list"><li>Compte AdSense créé et site ajouté (domaine propre, par exemple slashatlas.com).</li><li>Site en ligne et indexable (<code>indexable: true</code> dans la configuration) avec le contenu complet.</li><li>Le fichier <a href="/ads.txt" target="_blank" rel="noopener">/ads.txt</a> s’affiche quand la publicité est active.</li><li>Dans AdSense, « Confidentialité et messagerie » : message de consentement européen activé et publié.</li><li>Créer deux blocs adaptatifs (bandeau, rectangle) et coller leurs identifiants ci-dessus.</li></ul></div>';
    var tools = '<div class="adm-card"><h3>Outils</h3><ul class="adm-list">' + [['Console Firebase', 'https://console.firebase.google.com/project/slashatlas-studio/overview'], ['Base de données', 'https://console.firebase.google.com/project/slashatlas-studio/firestore'], ['Comptes (Authentication)', 'https://console.firebase.google.com/project/slashatlas-studio/authentication/users'], ['Journaux des fonctions', 'https://console.cloud.google.com/logs/query?project=slashatlas-studio'], ['Facturation Gemini (AI Studio)', 'https://aistudio.google.com/usage'], ['Tableau de bord FeexPay', 'https://app.feexpay.me'], ['Google AdSense', 'https://adsense.google.com'], ['Google Search Console', 'https://search.google.com/search-console']].map(function (x) { return '<li><a href="' + x[1] + '" target="_blank" rel="noopener">' + x[0] + '</a></li>'; }).join('') + '</ul></div>';
    var TABS = [['over', 'Vue d’ensemble', kpAud + tbl + cols], ['studio', 'Studio', kpStu + ords + usr + list('Commandes générées', merge(r, 'gen')) + list('Packs demandés par carte (bientôt)', merge(r, 'cardwish_pack'))], ['subs', 'Inscrits', subs], ['ads', 'Publicité', kpAds + adv + list('Affichages par bloc', merge(r, 'ad'))], ['tools', 'Outils', tools]];
    var tabNav = '<div class="seg adm-tabs" role="tablist">' + TABS.map(function (t) { return '<button type="button" role="tab" data-tab="' + t[0] + '"' + (t[0] === tab ? ' class="on" aria-selected="true"' : '') + '>' + t[1] + '</button>'; }).join('') + '</div>';
    root.innerHTML = head + tabNav + TABS.filter(function (t) { return t[0] === tab; }).map(function (t) { return t[2]; }).join('');
    Array.prototype.forEach.call(root.querySelectorAll('[data-tab]'), function (b) { b.addEventListener('click', function () { tab = b.dataset.tab; try { sessionStorage.setItem('sa_admtab', tab); } catch (e) {} render(d); }); });
    var gf = $('#grant-f'); if (gf) gf.addEventListener('submit', function (e) {
      e.preventDefault(); var m = $('#g-msg'); m.textContent = '…'; m.className = 'fmsg';
      window.slashAuth.call('admin/grant', { email: $('#g-email').value, credits: +$('#g-n').value, note: $('#g-note').value }).then(function (r) {
        if (r.status === 200) { m.textContent = 'Fait. Nouveau solde : ' + r.data.credits + ' crédits.'; m.className = 'fmsg ok'; $('#g-n').value = ''; }
        else { m.textContent = r.data && r.data.error === 'no_user' ? 'Aucun compte Studio avec cet e-mail.' : 'Échec (' + (r.data && r.data.error) + ').'; m.className = 'fmsg'; }
      });
    });
    var af = $('#ads-f'); if (af) af.addEventListener('submit', function (e) {
      e.preventDefault(); var m = $('#a-msg'); m.textContent = '…'; m.className = 'fmsg';
      window.slashAuth.call('admin/ads', { enabled: $('#a-on').checked, client: $('#a-client').value.trim(), slots: { lb: $('#a-lb').value.trim(), rect: $('#a-rect').value.trim() } }).then(function (r) {
        if (r.status === 200) { m.textContent = 'Enregistré. Actif sur le site sous une minute si le compte et les blocs sont valides.'; m.className = 'fmsg ok'; }
        else m.textContent = r.data && r.data.error === 'bad_client' ? 'ID éditeur invalide (format ca-pub-…).' : 'Identifiant de bloc invalide (chiffres seulement).';
      });
    });
    Array.prototype.forEach.call(root.querySelectorAll('[data-ev]'), function (b) { b.addEventListener('click', function () {
      b.disabled = true;
      window.slashAuth.call('admin/evidence', { orderId: b.dataset.ev }).then(function (r) {
        b.disabled = false; if (r.status !== 200) return;
        var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([JSON.stringify(r.data, null, 2)], { type: 'application/json' })); a.download = 'preuves-' + b.dataset.ev + '.json'; a.click();
      }).catch(function () { b.disabled = false; });
    }); });
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
