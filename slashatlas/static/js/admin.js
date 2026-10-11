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
  function funnel(title, steps) {
    var max = Math.max.apply(null, steps.map(function (s) { return s[1]; }).concat([1]));
    return '<div class="adm-card"><h3>' + title + '</h3>' + steps.map(function (s, i) {
      var prev = i ? steps[i - 1][1] : 0, rate = i && prev ? Math.round(100 * s[1] / prev) + ' % de l’étape précédente' : (i ? '—' : 'point de départ');
      return '<div class="bar fun"><span class="bl">' + esc(s[0]) + '<small>' + rate + '</small></span><span class="bt"><i style="width:' + Math.max(2, Math.round(100 * s[1] / max)) + '%"></i></span><b>' + fmtN(s[1]) + '</b></div>';
    }).join('') + '</div>';
  }
  function mapPairs(rows, k, nameFn) { return merge(rows, k).map(function (p) { return [nameFn ? nameFn(p[0]) : p[0], p[1]]; }); }
  // Pays des visiteurs : déduits du fuseau horaire de leur navigateur (aucune adresse IP conservée). Un VPN ou un appareil réglé sur un autre fuseau fausse un peu.
  var TZC = null, lastD = null;
  fetch('/js/tzc.json').then(function (r) { return r.json(); }).then(function (m) { TZC = m; if (lastD) render(lastD); }).catch(function () { TZC = {}; });
  function countryPairs(r) {
    if (!TZC) return null;
    var out = {};
    merge(r, 'tz').forEach(function (p) { var cc = TZC[p[0]] || '??'; out[cc] = (out[cc] || 0) + p[1]; });
    var dn; try { dn = new Intl.DisplayNames(['fr'], { type: 'region' }); } catch (e) {}
    return Object.keys(out).map(function (cc) {
      var flag = cc.length === 2 && cc !== '??' ? String.fromCodePoint(127397 + cc.charCodeAt(0), 127397 + cc.charCodeAt(1)) + ' ' : '';
      var name = cc === '??' ? 'Inconnu' : ((dn && dn.of(cc)) || cc);
      return [flag + name, out[cc]];
    }).sort(function (a, b) { return b[1] - a[1]; });
  }
  var fmt = function (iso) { return iso ? new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—'; };
  function fmtN(n) { return String(n || 0).replace(/\B(?=(\d{3})+(?!\d))/g, ' '); }
  function kpi(n, l, sub) { return '<div class="kpi"><b>' + n + '</b><span>' + l + '</span>' + (sub ? '<small>' + sub + '</small>' : '') + '</div>'; }
  function render(d) {
    lastD = d;
    var r = d.stats, pv = sum(r, 'pv'), cp = sum(r, 'copies');
    var maxPv = Math.max.apply(null, r.map(function (x) { return x.pv || 0; }).concat([1]));
    var rate = pv ? (100 * cp / pv).toFixed(1).replace('.', ',') + ' % des vues' : '';
    var head = '<div class="adm-top"><div class="seg">' + [7, 14, 30, 90].map(function (n) { return '<button type="button" data-d="' + n + '"' + (n === d.days ? ' class="on"' : '') + '>' + n + ' j</button>'; }).join('') + '</div><button class="btn gl sm" type="button" data-logout>Se déconnecter</button></div>';
    var kpAud = '<div class="kpis">' + kpi(pv, 'Pages vues', 'nombre de pages ouvertes en tout (une personne qui lit 5 pages = 5 vues)') + kpi(sum(r, 'sessions'), 'Visites', 'nombre de passages sur le site (une personne qui revient plus tard = une nouvelle visite) · dont ' + sum(r, 'returning') + ' venues d’un appareil déjà connu') + kpi(cp, 'Commandes copiées', 'clics sur « Copier » · ' + rate) + kpi(sum(r, 'tries'), 'Clics « Générer ici »', 'sur la plateforme') + kpi(sum(r, 'tests'), 'Clics ChatGPT/Gemini') + kpi(sum(r, 'videoplays'), 'Vidéo lue', 'clics sur « lire » (accueil)') + kpi(d.subscribers.total, 'Inscrits liste', sum(r, 'signups') + ' sur la période') + '</div>';
    var kpStu = '<div class="kpis">' + kpi(d.studioUsers || 0, 'Comptes Studio', sum(r, 'accounts') + ' sur la période') + kpi(sum(r, 'generations'), 'Générations', sum(r, 'edits') + ' corrections') + kpi(sum(r, 'orders'), 'Achats de crédits', fmtN(sum(r, 'revenueXof')) + ' FCFA') + kpi(sum(r, 'shares'), 'Partages', 'visuels partagés ou copiés') + kpi(sum(r, 'qrs'), 'QR codes', 'ajoutés sur des affiches') + kpi(sum(r, 'wa'), 'Clics canal WhatsApp', 'invitations cliquées') + kpi(sum(r, 'cardwish'), 'Demandes « carte »', 'clics sur Carte bancaire (bientôt)') + '</div>';
    var kpAds = '<div class="kpis">' + kpi(sum(r, 'adviews'), 'Pubs affichées', 'blocs vus à l’écran') + kpi(pv ? (100 * sum(r, 'adviews') / pv).toFixed(1).replace('.', ',') + ' %' : '—', 'Pubs / pages vues') + '</div>';
    var tbl = '<div class="adm-card"><h3>Par jour</h3><div class="tw"><table><thead><tr><th>Jour</th><th>Vues</th><th></th><th>Visites</th><th>Copies</th><th>Tests</th><th>Inscrits</th></tr></thead><tbody>' + r.slice().reverse().map(function (x) { return '<tr><td>' + x.id.slice(5) + '</td><td>' + (x.pv || 0) + '</td><td><span class="bt"><i style="width:' + Math.round(100 * (x.pv || 0) / maxPv) + '%"></i></span></td><td>' + (x.sessions || 0) + '</td><td>' + (x.copies || 0) + '</td><td>' + (x.tests || 0) + '</td><td>' + (x.signups || 0) + '</td></tr>'; }).join('') + '</tbody></table></div></div>';
    var cols = '<div class="adm-grid">' + list('Pages les plus vues', merge(r, 'pages')) + list('Commandes copiées', merge(r, 'cmd')) + list('Commandes à générer (clics)', merge(r, 'try')) + list('Commandes générées', merge(r, 'gen')) + list('Installation de l’app (écran d’accueil)', merge(r, 'pwa')) + list('Outils ouverts', merge(r, 'tool')) + list('Sources', merge(r, 'ref')) + list('Langues', merge(r, 'lang')) + list('Appareils', merge(r, 'dev').map(function (p) { return [{ m: 'mobile', d: 'ordinateur', t: 'tablette' }[p[0]] || p[0], p[1]]; })) + '</div>';
    var subs = '<div class="adm-card"><h3>Dernières inscriptions (' + d.subscribers.total + ')</h3><div class="tw"><table><thead><tr><th>E-mail</th><th>Type</th><th>Langue</th><th>Page</th><th>Note</th><th>Date</th></tr></thead><tbody>' + (d.subscribers.items.map(function (x) { return '<tr><td>' + esc(x.email) + '</td><td>' + esc((x.kinds || []).join(', ')) + '</td><td>' + esc(x.lang) + '</td><td>' + esc(x.page) + '</td><td>' + esc(x.note) + '</td><td>' + fmt(x.at) + '</td></tr>'; }).join('') || '<tr><td colspan="6">Aucune inscription.</td></tr>') + '</tbody></table></div><button class="btn gl sm" type="button" id="csv-s">Exporter en CSV</button></div>';
    var ords = '<div class="adm-card"><h3>Dernières commandes</h3><div class="tw"><table><thead><tr><th>Date</th><th>E-mail</th><th>Pack</th><th>Total</th><th>Moyen</th><th>Statut</th><th>CGV</th><th></th></tr></thead><tbody>' + ((d.orders || []).map(function (x) { return '<tr><td>' + fmt(x.at) + '</td><td>' + esc(x.email) + '</td><td>' + esc(x.credits) + ' cr.</td><td>' + fmtN(x.total) + '</td><td>' + esc(x.operator) + '</td><td>' + esc(x.status) + '</td><td>' + esc(x.terms || '—') + '</td><td><button class="btn gl sm" type="button" data-ev="' + esc(x.id) + '">Preuves</button></td></tr>'; }).join('') || '<tr><td colspan="8">Aucune commande.</td></tr>') + '</tbody></table></div><p class="hint">« Preuves » télécharge le dossier de litige : commande, acceptation des conditions (version, date, IP, navigateur), crédits et images générées.</p></div>';
    var usr = '<div class="adm-card"><h3>Offrir ou retirer des crédits</h3><form class="adm-form" id="grant-f"><input id="g-email" type="email" required placeholder="E-mail du compte Studio" autocomplete="off"><input id="g-n" type="number" required min="-500" max="500" step="1" placeholder="Crédits (ex. 5 ou -5)"><input id="g-note" type="text" maxlength="120" placeholder="Motif (ex. geste commercial)"><button class="btn pri sm" type="submit">Appliquer</button></form><p class="fmsg" id="g-msg" role="status" aria-live="polite"></p></div>' +
      '<div class="adm-card"><h3>Derniers comptes Studio (' + (d.studioUsers || 0) + ')</h3><div class="tw"><table><thead><tr><th>E-mail</th><th>Nom</th><th>Crédits</th><th>Inscrit</th><th>Dernière visite</th></tr></thead><tbody>' + ((d.users || []).map(function (x) { return '<tr><td>' + esc(x.email) + '</td><td>' + esc(x.name) + '</td><td>' + esc(x.credits) + '</td><td>' + fmt(x.at) + '</td><td>' + fmt(x.seen) + '</td></tr>'; }).join('') || '<tr><td colspan="5">Aucun compte.</td></tr>') + '</tbody></table></div></div>';
    var A = d.ads || {}, adv = '<div class="adm-card"><h3>Publicité Google AdSense</h3><p class="hint">Quand elle est activée, les blocs apparaissent sur l’accueil, le tutoriel, les packs et, sous le bouton « Copier » (le bloc « rectangle »), seulement après la copie d’une commande (jamais sur « Générer ici »). Les détenteurs du pass sans pub n’en voient aucun. Aucun redéploiement nécessaire.</p><form class="adm-form" id="ads-f"><label class="chk"><input type="checkbox" id="a-on"' + (A.enabled ? ' checked' : '') + '> Publicité activée</label><input id="a-client" placeholder="ID éditeur : ca-pub-1234567890123456" value="' + esc(A.client) + '"><input id="a-lb" placeholder="ID du bloc « bandeau » (chiffres)" value="' + esc((A.slots || {}).lb) + '"><input id="a-rect" placeholder="ID du bloc « rectangle » (chiffres)" value="' + esc((A.slots || {}).rect) + '"><button class="btn pri sm" type="submit">Enregistrer</button></form><p class="fmsg" id="a-msg" role="status" aria-live="polite"></p></div>' +
      '<div class="adm-card"><h3>Avant d’activer</h3><ul class="adm-list"><li>Compte AdSense créé et site ajouté (domaine propre, par exemple slashatlas.com).</li><li>Site en ligne et indexable (<code>indexable: true</code> dans la configuration) avec le contenu complet.</li><li>Le fichier <a href="/ads.txt" target="_blank" rel="noopener">/ads.txt</a> s’affiche quand la publicité est active.</li><li>Dans AdSense, « Confidentialité et messagerie » : message de consentement européen activé et publié.</li><li>Créer deux blocs adaptatifs (bandeau, rectangle) et coller leurs identifiants ci-dessus.</li></ul></div>';
    var tools = '<div class="adm-card"><h3>Outils</h3><ul class="adm-list">' + [['Console Firebase', 'https://console.firebase.google.com/project/slashatlas-studio/overview'], ['Base de données', 'https://console.firebase.google.com/project/slashatlas-studio/firestore'], ['Comptes (Authentication)', 'https://console.firebase.google.com/project/slashatlas-studio/authentication/users'], ['Journaux des fonctions', 'https://console.cloud.google.com/logs/query?project=slashatlas-studio'], ['Facturation Gemini (AI Studio)', 'https://aistudio.google.com/usage'], ['Tableau de bord FeexPay', 'https://app.feexpay.me'], ['Google AdSense', 'https://adsense.google.com'], ['Google Search Console', 'https://search.google.com/search-console']].map(function (x) { return '<li><a href="' + x[1] + '" target="_blank" rel="noopener">' + x[0] + '</a></li>'; }).join('') + '</ul></div>';
    var tzp = mapPairs(r, 'tz', function (z) { return z.replace(/_/g, ' '); });
    var fun = funnel('Parcours d’un visiteur, de la visite au paiement', [['Visites', sum(r, 'sessions')], ['Clics « Générer ici »', sum(r, 'tries')], ['Comptes créés', sum(r, 'accounts')], ['Images générées', sum(r, 'generations')], ['Fenêtre d’achat ouverte', sum(r, 'buyopen')], ['Clic sur le bouton « Payer »', sum(r, 'paytry')], ['… avec formulaire complet', sum(r, 'paytry_valid')], ['Commande envoyée à FeexPay', sum(r, 'orders_created')], ['Achats payés', sum(r, 'orders')]]);
    var opN = function (o) { return o.replace(/_/g, ' '); };
    var funDet = '<div class="adm-grid">' + list('Clics « Payer » par pack', mapPairs(r, 'paytry_pack')) + list('Clics « Payer » par opérateur', mapPairs(r, 'paytry_op', opN)) + list('Commandes créées par opérateur', mapPairs(r, 'orders_created_op', opN)) + list('Achats payés par opérateur', mapPairs(r, 'orders_paid_op', opN)) + list('Où l’achat a été ouvert', mapPairs(r, 'buyopen_from')) + list('Clics « Carte bancaire (bientôt) » par pack', mapPairs(r, 'cardwish_pack')) + '</div>';
    var probs = '<div class="kpis">' + kpi(sum(r, 'orders_failed'), 'Paiements échoués', 'refusés ou annulés') + kpi(sum(r, 'genfails'), 'Générations échouées', 'crédit rendu') + kpi(sum(r, 'cardwish'), 'Intérêt carte bancaire', 'clics sur « bientôt »') + '</div>';
    var proPv = 0; r.forEach(function (x) { var p = x.pages || {}; proPv += (p['_pro_'] || 0) + (p['_en_pro_'] || 0); });
    var np = sum(r, 'nopub'), wl = r.reduce(function (n, x) { return n + ((x.signupKind || {}).waitlist || 0); }, 0);
    var nopub = '<div class="kpis">' + kpi(np, 'Clics vers « Sans pub »', pv ? (100 * np / pv).toFixed(1).replace('.', ',') + ' % des vues' : '') + kpi(proPv, 'Vues de la page « Sans pub »') + kpi(wl, 'Inscrits à l’offre sans pub', proPv ? (100 * wl / proPv).toFixed(1).replace('.', ',') + ' % des vues de la page' : '') + '</div>' + list('Clics « Sans pub » depuis quelle page', mapPairs(r, 'nopub_from', function (p) { var q = p.replace(/^_|_$/g, '').replace(/_/g, '/'); return q === '' ? 'accueil' : q === 'en' ? 'accueil (EN)' : q; }));
    var TABS = [['over', 'Vue d’ensemble', kpAud + tbl + (function () { var cp2 = countryPairs(r); return cp2 ? list('Pays des visiteurs (d’après le fuseau horaire)', cp2) : '<div class="adm-card"><h3>Pays des visiteurs</h3><p class="hint">Chargement…</p></div>'; })() + cols + list('Fuseaux horaires (détail)', tzp)], ['funnel', 'Parcours', fun + probs + funDet], ['nopub', 'Sans pub', nopub], ['studio', 'Studio', kpStu + ords + usr + list('Commandes générées', merge(r, 'gen')) + list('Packs demandés par carte (bientôt)', merge(r, 'cardwish_pack'))], ['subs', 'Inscrits', subs], ['ads', 'Publicité', kpAds + adv + list('Affichages par bloc', merge(r, 'ad'))], ['tools', 'Outils', tools]];
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
