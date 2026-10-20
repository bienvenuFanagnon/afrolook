(function () {
  'use strict';
  import('/js/auth.js');
  var $ = function (s) { return document.querySelector(s); };
  var days = 14, root = $('#adm'), tab = 'over'; try { tab = sessionStorage.getItem('sa_admtab') || 'over'; } catch (e) {}
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var payStt = function (o) { var extra = o.status === 'paid' ? '' : (o.failure || o.lastStatus || ''); return esc(o.status === 'chargeback' ? 'contesté' : o.status) + (extra ? ' <small title="' + esc(extra) + '">(' + esc(String(extra).slice(0, 40)) + ')</small>' : ''); };
    var payMoyen = function (o) { return o.provider === 'feexpay_card' || o.operator === 'card' ? window.saIcon('card') + ' carte' : esc(o.operator); };
    var cbBtn = function (o) { return (o.status === 'paid' && (o.provider === 'feexpay_card' || o.operator === 'card')) ? ' <button class="btn gl sm" type="button" data-cb="' + esc(o.id) + '">Contestation</button>' : ''; };
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
      var prev = i ? steps[i - 1][1] : 0, rate = i && prev ? Math.round(100 * s[1] / prev) + ' % de l\'étape précédente' : (i ? '—' : 'point de départ');
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
    var uniqVisitors = sum(r, 'visitors');
    var kpAud = '<div class="kpis">' + kpi(uniqVisitors, 'Visiteurs uniques', 'personnes différentes — chaque appareil est compté une seule fois, indépendamment du nombre de visites') + kpi(pv, 'Pages vues', 'nombre de pages ouvertes en tout (une personne qui lit 5 pages = 5 vues)') + kpi(sum(r, 'sessions'), 'Visites', 'nombre de passages sur le site (une personne qui revient plus tard = une nouvelle visite) · dont ' + sum(r, 'returning') + ' venues d\'un appareil déjà connu') + kpi(cp, 'Commandes copiées', 'clics sur « Copier » · ' + rate) + kpi(sum(r, 'tries'), 'Clics « Générer ici »', 'sur la plateforme') + kpi(sum(r, 'tests'), 'Clics ChatGPT/Gemini') + kpi(sum(r, 'videoplays'), 'Vidéo lue', 'clics sur « lire » (accueil)') + kpi(d.subscribers.total, 'Inscrits liste', sum(r, 'signups') + ' sur la période') + '</div>';
    var kpStu = '<div class="kpis">' + kpi(d.studioUsers || 0, 'Comptes Studio', sum(r, 'accounts') + ' sur la période') + kpi(sum(r, 'generations'), 'Générations', sum(r, 'edits') + ' corrections') + kpi(sum(r, 'orders'), 'Achats de crédits', fmtN(sum(r, 'revenueXof')) + ' FCFA') + kpi(sum(r, 'shares'), 'Partages', 'visuels partagés ou copiés') + kpi(sum(r, 'qrs'), 'QR codes', 'ajoutés sur des affiches') + kpi(sum(r, 'wa'), 'Clics canal WhatsApp', 'invitations cliquées') + kpi(sum(r, 'cardwish'), 'Demandes « carte »', 'clics sur Carte bancaire avant son activation') + '</div>';
    var aflImps = sum(r, 'afl_imps'), aflClicks = sum(r, 'afl_clicks');
    var kpAds = '<div class="kpis">' + kpi(sum(r, 'adviews'), 'Pubs AdSense affichées', 'blocs vus à l\'écran') + kpi(pv ? (100 * sum(r, 'adviews') / pv).toFixed(1).replace('.', ',') + ' %' : '—', 'AdSense / pages vues') + kpi(aflImps, 'Pubs Afrolook affichées') + kpi(aflClicks, 'Clics Afrolook') + (aflImps ? kpi((100 * aflClicks / aflImps).toFixed(1).replace('.', ',') + ' %', 'CTR Afrolook') : '') + '</div>';
    var tbl = '<div class="adm-card"><h3>Par jour</h3><div class="tw"><table><thead><tr><th>Jour</th><th>Visiteurs uniques</th><th>Vues</th><th></th><th>Visites</th><th>Copies</th><th>Tests</th><th>Inscrits</th></tr></thead><tbody>' + r.slice().reverse().map(function (x) { return '<tr><td>' + x.id.slice(5) + '</td><td>' + (x.visitors || 0) + '</td><td>' + (x.pv || 0) + '</td><td><span class="bt"><i style="width:' + Math.round(100 * (x.pv || 0) / maxPv) + '%"></i></span></td><td>' + (x.sessions || 0) + '</td><td>' + (x.copies || 0) + '</td><td>' + (x.tests || 0) + '</td><td>' + (x.signups || 0) + '</td></tr>'; }).join('') + '</tbody></table></div></div>';
    var cols = '<div class="adm-grid">' + list('Pages les plus vues', merge(r, 'pages')) + list('Commandes visitées (page de détails)', merge(r, 'view')) + list('Commandes copiées', merge(r, 'cmd')) + list('Commandes à générer (clics)', merge(r, 'try')) + list('Commandes générées', merge(r, 'gen')) + list('Installation de l\'app (écran d\'accueil)', merge(r, 'pwa')) + list('Outils ouverts', merge(r, 'tool')) + list('Sources', merge(r, 'ref')) + list('Langues', merge(r, 'lang')) + list('Appareils', merge(r, 'dev').map(function (p) { return [{ m: 'mobile', d: 'ordinateur', t: 'tablette' }[p[0]] || p[0], p[1]]; })) + '</div>';
    var subs = '<div class="adm-card"><h3>Dernières inscriptions (' + d.subscribers.total + ')</h3><div class="tw"><table><thead><tr><th>E-mail</th><th>Type</th><th>Langue</th><th>Page</th><th>Note</th><th>Date</th></tr></thead><tbody>' + (d.subscribers.items.map(function (x) { return '<tr><td>' + esc(x.email) + '</td><td>' + esc((x.kinds || []).join(', ')) + '</td><td>' + esc(x.lang) + '</td><td>' + esc(x.page) + '</td><td>' + esc(x.note) + '</td><td>' + fmt(x.at) + '</td></tr>'; }).join('') || '<tr><td colspan="6">Aucune inscription.</td></tr>') + '</tbody></table></div><button class="btn gl sm" type="button" id="csv-s">Exporter en CSV</button></div>';
var ords = '<div class="adm-card"><h3>Dernières commandes (période)</h3><div class="tw"><table><thead><tr><th>Date</th><th>E-mail</th><th>Pack</th><th>Total</th><th>Moyen</th><th>Statut</th><th>CGV</th><th></th></tr></thead><tbody>' + ((d.orders || []).map(function (x) { return '<tr><td>' + fmt(x.at) + '</td><td>' + esc(x.email) + '</td><td>' + esc(x.credits) + ' cr.</td><td>' + fmtN(x.total) + '</td><td>' + esc(x.operator) + '</td><td>' + esc(x.status) + '</td><td>' + esc(x.terms || '—') + '</td><td><button class="btn gl sm" type="button" data-ev="' + esc(x.id) + '">Preuves</button></td></tr>'; }).join('') || '<tr><td colspan="8">Aucune commande.</td></tr>') + '</tbody></table></div><p class="hint">« Preuves » télécharge le dossier de litige.</p></div>' +
      '<div class="adm-card" id="adm-allords"><h3>Toutes les transactions <small id="adm-ords-count" style="font-weight:400;font-size:13px;margin-left:6px;color:var(--mut)"></small></h3><button class="btn gl sm" type="button" id="adm-load-ords">Charger les transactions</button><div id="adm-ords-tbl" style="margin-top:12px"></div></div>';
    var usr = '<div class="adm-card"><h3>Offrir ou retirer des crédits</h3><form class="adm-form" id="grant-f"><input id="g-email" type="email" required placeholder="E-mail du compte Studio" autocomplete="off"><input id="g-n" type="number" required min="-500" max="500" step="1" placeholder="Crédits (ex. 5 ou -5)"><input id="g-note" type="text" maxlength="120" placeholder="Motif (ex. geste commercial)"><button class="btn pri sm" type="submit">Appliquer</button></form><p class="fmsg" id="g-msg" role="status" aria-live="polite"></p></div>' +
      '<div class="adm-card" id="adm-usr-search"><h3>Profil utilisateur</h3><form class="adm-form" id="usr-search-f"><input id="usr-q" type="text" placeholder="E-mail ou UID" autocomplete="off" style="flex:1"><button class="btn gl sm" type="submit">Rechercher</button></form><div id="usr-detail"></div></div>' +
      '<div class="adm-card"><h3>Derniers comptes Studio (' + (d.studioUsers || 0) + ')</h3><div class="tw"><table><thead><tr><th>E-mail</th><th>Nom</th><th>Crédits</th><th>Inscrit</th><th>Dernière visite</th></tr></thead><tbody>' + ((d.users || []).map(function (x) { return '<tr><td>' + esc(x.email) + '</td><td>' + esc(x.name) + '</td><td>' + esc(x.credits) + '</td><td>' + fmt(x.at) + '</td><td>' + fmt(x.seen) + '</td></tr>'; }).join('') || '<tr><td colspan="5">Aucun compte.</td></tr>') + '</tbody></table></div></div>';
    var A = d.ads || {}, adv = '<div class="adm-card"><h3>Publicité Google AdSense</h3><p class="hint">Quand elle est activée, les blocs apparaissent sur l\'accueil, le tutoriel, les packs et, sous le bouton « Copier » (le bloc « rectangle »), seulement après la copie d\'une commande (jamais sur « Générer ici »). Les détenteurs du pass sans pub n\'en voient aucun. Aucun redéploiement nécessaire.</p><form class="adm-form" id="ads-f"><label class="chk"><input type="checkbox" id="a-on"' + (A.enabled ? ' checked' : '') + '> Publicité AdSense activée</label><label class="chk"><input type="checkbox" id="a-afl"' + (A.afrolook ? ' checked' : '') + '> Publicité Afrolook activée (remplace AdSense si aucun bloc configuré)</label><input id="a-client" placeholder="ID éditeur : ca-pub-1234567890123456" value="' + esc(A.client) + '"><input id="a-lb" placeholder="ID du bloc « bandeau » (chiffres)" value="' + esc((A.slots || {}).lb) + '"><input id="a-rect" placeholder="ID du bloc « rectangle » (chiffres)" value="' + esc((A.slots || {}).rect) + '"><button class="btn pri sm" type="submit">Enregistrer</button></form><p class="fmsg" id="a-msg" role="status" aria-live="polite"></p></div>' +
      '<div class="adm-card"><h3>Avant d\'activer</h3><ul class="adm-list"><li>Compte AdSense créé et site ajouté (domaine propre, par exemple slashatlas.com).</li><li>Site en ligne et indexable (<code>indexable: true</code> dans la configuration) avec le contenu complet.</li><li>Le fichier <a href="/ads.txt" target="_blank" rel="noopener">/ads.txt</a> s\'affiche quand la publicité est active.</li><li>Dans AdSense, « Confidentialité et messagerie » : message de consentement européen activé et publié.</li><li>Créer deux blocs adaptatifs (bandeau, rectangle) et coller leurs identifiants ci-dessus.</li></ul></div>';
    var _svcs = [{id:'elevenlabs',name:'ElevenLabs',desc:'Synthèse vocale',url:'https://elevenlabs.io/subscription'},{id:'cloudflare',name:'Cloudflare Workers AI',desc:'Génération d\'images',url:'https://dash.cloudflare.com'},{id:'claude',name:'Claude API',desc:'IA de génération de texte',url:'https://console.anthropic.com'},{id:'firebase',name:'Firebase',desc:'Base de données et fonctions',url:'https://console.firebase.google.com/project/slashatlas-studio/usage'},{id:'gemini',name:'Gemini API',desc:'IA supplémentaire',url:'https://aistudio.google.com/usage'},{id:'gtts',name:'gTTS',desc:'Texte en parole (Google)',url:'https://console.cloud.google.com/apis/api/texttospeech.googleapis.com'}];
    var tools = '<div class="adm-card"><h3>Surveillance des services</h3><p class="hint">Suit les abonnements et quotas pour éviter les coupures de service.</p><button class="btn gl sm" type="button" id="refresh-usage" style="margin-top:6px">Actualiser</button><div id="usage-grid" class="svc-grid" style="margin-top:12px">' + _svcs.map(function(s){return '<div class="svc-card" id="svc-'+s.id+'"><div class="svc-top"><span class="svc-dot" id="dot-'+s.id+'"></span><b>'+esc(s.name)+'</b><a href="'+s.url+'" target="_blank" rel="noopener" class="svc-ext">&#8599;</a></div><p class="svc-desc">'+esc(s.desc)+'</p><div class="svc-bar" id="bar-'+s.id+'" style="display:none"><div class="svc-fill" id="fill-'+s.id+'"></div></div><div class="svc-info" id="info-'+s.id+'"><span class="hint">—</span></div></div>';}).join('') + '</div></div>' +
      '<div class="adm-card"><h3>Consoles et tableaux de bord</h3><ul class="adm-list">' + [['Console Firebase', 'https://console.firebase.google.com/project/slashatlas-studio/overview'], ['Base de données', 'https://console.firebase.google.com/project/slashatlas-studio/firestore'], ['Comptes (Authentication)', 'https://console.firebase.google.com/project/slashatlas-studio/authentication/users'], ['Journaux des fonctions', 'https://console.cloud.google.com/logs/query?project=slashatlas-studio'], ['Facturation Gemini (AI Studio)', 'https://aistudio.google.com/usage'], ['Tableau de bord FeexPay', 'https://app.feexpay.me'], ['Google AdSense', 'https://adsense.google.com'], ['Google Search Console', 'https://search.google.com/search-console']].map(function (x) { return '<li><a href="' + x[1] + '" target="_blank" rel="noopener">' + x[0] + '</a></li>'; }).join('') + '</ul></div>';
    var tzp = mapPairs(r, 'tz', function (z) { return z.replace(/_/g, ' '); });
    var fun = funnel('Parcours d\'un visiteur, de la visite au paiement', [['Visites', sum(r, 'sessions')], ['Clics « Générer ici »', sum(r, 'tries')], ['Comptes créés', sum(r, 'accounts')], ['Images générées', sum(r, 'generations')], ['Fenêtre d\'achat ouverte', sum(r, 'buyopen')], ['Clic sur le bouton « Payer »', sum(r, 'paytry')], ['… avec formulaire complet', sum(r, 'paytry_valid')], ['Commande envoyée à FeexPay', sum(r, 'orders_created')], ['Achats payés', sum(r, 'orders')]]);
    var opN = function (o) { return o.replace(/_/g, ' '); };
    var funDet = '<div class="adm-grid">' + list('Clics « Payer » par pack', mapPairs(r, 'paytry_pack')) + list('Clics « Payer » par opérateur', mapPairs(r, 'paytry_op', opN)) + list('Commandes créées par opérateur', mapPairs(r, 'orders_created_op', opN)) + list('Achats payés par opérateur', mapPairs(r, 'orders_paid_op', opN)) + list('Où l\'achat a été ouvert', mapPairs(r, 'buyopen_from')) + list('Clics « Carte bancaire » avant activation, par pack', mapPairs(r, 'cardwish_pack')) + '</div>';
    var probs = '<div class="kpis">' + kpi(sum(r, 'orders_failed'), 'Paiements échoués', 'refusés ou annulés') + kpi(sum(r, 'genfails'), 'Générations échouées', 'crédit rendu') + kpi(sum(r, 'cardwish'), 'Intérêt carte bancaire', 'clics avant l’activation') + '</div>';
    var proPv = 0; r.forEach(function (x) { var p = x.pages || {}; proPv += (p['_pro_'] || 0) + (p['_en_pro_'] || 0); });
    var np = sum(r, 'nopub'), wl = r.reduce(function (n, x) { return n + ((x.signupKind || {}).waitlist || 0); }, 0);
    var nopub = '<div class="kpis">' + kpi(np, 'Clics vers « Sans pub »', pv ? (100 * np / pv).toFixed(1).replace('.', ',') + ' % des vues' : '') + kpi(proPv, 'Vues de la page « Sans pub »') + kpi(wl, 'Inscrits à l\'offre sans pub', proPv ? (100 * wl / proPv).toFixed(1).replace('.', ',') + ' % des vues de la page' : '') + '</div>' + list('Clics « Sans pub » depuis quelle page', mapPairs(r, 'nopub_from', function (p) { var q = p.replace(/^_|_$/g, '').replace(/_/g, '/'); return q === '' ? 'accueil' : q === 'en' ? 'accueil (EN)' : q; }));
    var TABS = [['over', 'Vue d\'ensemble', kpAud + tbl + (function () { var cp2 = countryPairs(r); return cp2 ? list('Pays des visiteurs (d\'après le fuseau horaire)', cp2) : '<div class="adm-card"><h3>Pays des visiteurs</h3><p class="hint">Chargement…</p></div>'; })() + cols + list('Fuseaux horaires (détail)', tzp)], ['funnel', 'Parcours', fun + probs + funDet], ['nopub', 'Sans pub', nopub], ['studio', 'Studio', kpStu + ords + usr + list('Commandes générées', merge(r, 'gen')) + list('Packs demandés par carte (avant activation)', merge(r, 'cardwish_pack'))], ['subs', 'Inscrits', subs], ['ads', 'Publicité', kpAds + adv + list('Affichages par bloc', merge(r, 'ad'))], ['errors', 'Erreurs', '<div class="adm-card"><h3>Erreurs de génération</h3><p class="hint">Chaque erreur est expliquée : ce qui s’est passé et ce qu’il faut faire. Les clients sont toujours remboursés automatiquement.</p><button class="btn gl sm" type="button" id="load-gen-errors">Actualiser</button><div id="gen-errors-sum" style="margin-top:14px"></div><div id="gen-errors-tbl" style="margin-top:14px"></div></div>'], ['tools', 'Outils', tools]];
    var tabNav = '<div class="seg adm-tabs" role="tablist">' + TABS.map(function (t) { return '<button type="button" role="tab" data-tab="' + t[0] + '"' + (t[0] === tab ? ' class="on" aria-selected="true"' : '') + '>' + t[1] + '</button>'; }).join('') + '</div>';
    root.innerHTML = head + tabNav + TABS.filter(function (t) { return t[0] === tab; }).map(function (t) { return t[2]; }).join('');
    showAlerts();
    if (tab === 'tools') { var _rb = document.getElementById('refresh-usage'); if (_rb) _rb.addEventListener('click', loadUsageStats); loadUsageStats(); }
    if (tab === 'errors') {
      var _lge = document.getElementById('load-gen-errors');
      if (_lge) {
        var loadGenErrors = function (force) {
          _lge.disabled = true; _lge.textContent = 'Chargement…';
          fetchGenErrors(force).then(function (g) {
            _lge.disabled = false; _lge.textContent = 'Actualiser';
            var sumBox = document.getElementById('gen-errors-sum'), tbl = document.getElementById('gen-errors-tbl');
            if (!sumBox || !tbl) return;
            if (!g) { tbl.innerHTML = '<p class="hint">Impossible de charger les erreurs.</p>'; return; }
            var errs = g.errors || [], res = g.resume || [];
            var head = (g.alerts || []).map(alertHtml).join('');
            head += '<p class="hint" style="margin:8px 0">' + (g.lastImageOk ? window.saIcon('check') + ' Dernière image réussie : ' + esc(when(g.lastImageOk)) : 'Aucune image réussie récemment.') + '</p>';
            head += res.length
              ? '<h4 style="margin:14px 0 8px">Résumé des 7 derniers jours</h4>' + res.map(function (r) {
                  var c = GRAV[r.gravite] || GRAV.attention;
                  var types = Object.keys(r.types || {}).map(function (k) { return k + ' ×' + r.types[k]; }).join(', ');
                  return '<div style="border:1px solid ' + c[1] + '55;border-left:4px solid ' + c[1] + ';background:' + c[0] + ';border-radius:10px;padding:10px 12px;margin-bottom:8px">' +
                    '<div style="display:flex;flex-wrap:wrap;gap:6px 12px;align-items:baseline"><b style="color:' + c[1] + '">' + c[2] + ' ' + esc(r.titre) + '</b><span class="hint">' + r.nombre + ' fois · dernière : ' + esc(when(r.dernier)) + ' · ' + esc(types) + '</span></div>' +
                    '<p style="margin:6px 0 4px">' + esc(r.quoi) + '</p>' +
                    '<p style="margin:0"><b>À faire :</b> ' + esc(r.action) + (r.lien ? ' <a href="' + esc(r.lien) + '" target="_blank" rel="noopener">Ouvrir ↗</a>' : '') + '</p></div>';
                }).join('')
              : '<p class="hint">Aucune erreur ces 7 derniers jours.</p>';
            sumBox.innerHTML = head;
            if (!errs.length) { tbl.innerHTML = ''; return; }
            var rows = errs.map(function (e) {
              var c = GRAV[e.gravite] || GRAV.attention;
              return '<tr><td style="white-space:nowrap">' + esc(when(e.at)) + '</td><td>' + esc(e.type || '') + (e.genre ? ' <small>(' + esc(e.genre) + ')</small>' : '') + '</td>' +
                '<td><b style="color:' + c[1] + '">' + c[2] + ' ' + esc(e.titre || e.code) + '</b></td>' +
                '<td style="max-width:360px;word-break:break-word"><small class="hint">' + esc(e.technique || e.code || '') + '</small></td><td><small>' + esc(e.uid || '') + '</small></td></tr>';
            }).join('');
            tbl.innerHTML = '<h4 style="margin:4px 0 8px">Dernières erreurs</h4><div class="tw"><table><thead><tr><th>Date</th><th>Création</th><th>Problème</th><th>Détail technique</th><th>Utilisateur</th></tr></thead><tbody>' + rows + '</tbody></table></div>';
          }).catch(function () { _lge.disabled = false; _lge.textContent = 'Réessayer'; });
        };
        _lge.addEventListener('click', function () { loadGenErrors(true); });
        loadGenErrors(false);
      }
    }
    // Transactions paginées
    var _aob = document.getElementById('adm-load-ords');
    if (_aob) {
      var _admCursor = null, _admTotal = 0;
      function loadAdmOrders(cursor) {
        _aob.disabled = true; _aob.textContent = '…';
        window.slashAuth.call('admin/orders', { cursor: cursor || null }).then(function (r) {
          _aob.disabled = false;
          if (r.status !== 200) { _aob.textContent = 'Erreur'; return; }
          var orders = (r.data && r.data.orders) || [];
          var nc = r.data && r.data.nextCursor;
          _admTotal += orders.length;
          var ct = document.getElementById('adm-ords-count'); if (ct) ct.textContent = '(' + _admTotal + ' chargées)';
          var tbl = document.getElementById('adm-ords-tbl');
          if (tbl) {
            var rows = orders.map(function (o) {
              return '<tr><td>' + fmt(o.createdAt) + '</td><td>' + esc(o.email) + '</td><td>' + (o.days ? o.days + 'j' : o.credits + ' cr.') + '</td><td>' + fmtN(o.amount) + '</td><td>' + payMoyen(o) + '</td><td>' + esc(o.phone) + '</td><td>' + payStt(o) + '</td><td><button class="btn gl sm" type="button" data-ev="' + esc(o.id) + '">Preuves</button>' + cbBtn(o) + '</td></tr>';
            }).join('');
            if (!cursor) {
              tbl.innerHTML = '<div class="tw"><table><thead><tr><th>Date</th><th>E-mail</th><th>Pack</th><th>Total</th><th>Opérateur</th><th>Téléphone</th><th>Statut</th><th></th></tr></thead><tbody id="adm-ords-body">' + rows + '</tbody></table></div>';
            } else {
              var tbody = document.getElementById('adm-ords-body');
              if (tbody) tbody.insertAdjacentHTML('beforeend', rows);
            }
            // Rebind evidence buttons
            Array.prototype.forEach.call(tbl.querySelectorAll('[data-ev]'), function (btn) {
              if (!btn._evBound) { btn._evBound = true; btn.addEventListener('click', function () { btn.disabled = true; window.slashAuth.call('admin/evidence', { orderId: btn.dataset.ev }).then(function (r2) { btn.disabled = false; if (r2.status !== 200) return; var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([JSON.stringify(r2.data, null, 2)], { type: 'application/json' })); a.download = 'preuves-' + btn.dataset.ev + '.json'; a.click(); }).catch(function () { btn.disabled = false; }); }); }
            });
          }
          _admCursor = nc;
          _aob.textContent = nc ? 'Charger 20 suivantes' : 'Tout chargé';
          _aob.disabled = !nc;
        }).catch(function () { _aob.disabled = false; _aob.textContent = 'Réessayer'; });
      }
      _aob.addEventListener('click', function () { loadAdmOrders(_admCursor); });
    }
    Array.prototype.forEach.call(root.querySelectorAll('[data-tab]'), function (b) { b.addEventListener('click', function () { tab = b.dataset.tab; try { sessionStorage.setItem('sa_admtab', tab); } catch (e) {} render(d); if (tab === 'tools') { var rb2 = document.getElementById('refresh-usage'); if (rb2) rb2.addEventListener('click', loadUsageStats); loadUsageStats(); } }); });
    var gf = $('#grant-f'); if (gf) gf.addEventListener('submit', function (e) {
      e.preventDefault(); var m = $('#g-msg'); m.textContent = '…'; m.className = 'fmsg';
      window.slashAuth.call('admin/grant', { email: $('#g-email').value, credits: +$('#g-n').value, note: $('#g-note').value }).then(function (r) {
        if (r.status === 200) { m.textContent = 'Fait. Nouveau solde : ' + r.data.credits + ' crédits.'; m.className = 'fmsg ok'; $('#g-n').value = ''; }
        else { m.textContent = r.data && r.data.error === 'no_user' ? 'Aucun compte Studio avec cet e-mail.' : 'Échec (' + (r.data && r.data.error) + ').'; m.className = 'fmsg'; }
      });
    });
    var usf = $('#usr-search-f'); if (usf) usf.addEventListener('submit', function (e) {
      e.preventDefault();
      var q = ($('#usr-q') || {}).value || ''; if (!q) return;
      var det = $('#usr-detail'); if (!det) return;
      det.innerHTML = '<p class="hint">Chargement…</p>';
      window.slashAuth.call('admin/user-detail', { q: q }).then(function (r) {
        if (r.status !== 200) { det.innerHTML = '<p class="hint">' + esc((r.data && r.data.error) || 'Erreur') + '</p>'; return; }
        var u = r.data;
        var ldgHtml = (u.ledger || []).map(function (l) {
          var sign = l.delta > 0 ? '<span class="txn-ok">+' + l.delta + '</span>' : '<span class="txn-err">' + l.delta + '</span>';
          var badge = { purchase: '' + window.saIcon('card') + 'Achat', grant: '' + window.saIcon('gift') + 'Don', refund: '' + window.saIcon('receipt') + 'Remboursement', generation: '' + window.saIcon('image') + 'Génération', adfree: '' + window.saIcon('bell') + 'Sans-pub' }[l.type] || l.type;
          return '<tr><td class="txn-date">' + fmt(l.at ? new Date(l.at).getTime() : null) + '</td><td>' + sign + '</td><td>' + (/^<svg/.test(badge) ? badge : esc(badge)) + '</td><td class="txn-mut">' + esc(l.ref) + '</td><td class="txn-mut">' + esc(l.note) + '</td></tr>';
        }).join('') || '<tr><td colspan="5">Aucune entrée.</td></tr>';
        var ordsHtml = (u.orders || []).map(function (o) {
          return '<tr><td class="txn-date">' + fmt(o.createdAt ? new Date(o.createdAt).getTime() : null) + '</td><td>' + esc(o.credits) + ' cr.</td><td>' + fmtN(o.amount) + ' ' + esc(o.currency) + '</td><td>' + esc(o.operator) + '</td><td>' + esc(o.phone) + '</td><td>' + esc(o.status) + '</td></tr>';
        }).join('') || '<tr><td colspan="6">Aucune commande.</td></tr>';
        var genHtml = (u.generations || []).slice(0, 10).map(function (g) {
          return '<tr><td class="txn-date">' + fmt(g.at ? new Date(g.at).getTime() : null) + '</td><td>' + esc(g.type) + '</td><td>' + esc(g.status) + '</td><td class="txn-mut">' + esc(g.instruction) + '</td></tr>';
        }).join('') || '<tr><td colspan="4">Aucune génération.</td></tr>';
        var filmHtml = (u.films || []).map(function (f) {
          return '<tr><td class="txn-date">' + fmt(f.at ? new Date(f.at).getTime() : null) + '</td><td>' + esc(f.title) + '</td><td>' + esc(f.duration) + 'min / ' + esc(f.lang) + '</td><td>' + esc(f.cost) + ' cr.</td><td>' + esc(f.status) + '</td><td>' + esc(f.error) + '</td></tr>';
        }).join('') || '<tr><td colspan="6">Aucun film.</td></tr>';
        det.innerHTML =
          '<div style="margin-top:12px;padding:10px 0;border-top:1px solid var(--sep)">' +
          '<b>' + esc(u.email) + '</b> &nbsp;<span class="hint">uid: ' + esc(u.uid) + '</span><br>' +
          '<span style="font-size:22px;font-weight:700;margin-top:4px;display:inline-block">' + (u.credits || 0) + ' crédits</span>' +
          (u.adFreeUntil ? ' &nbsp;<span class="hint">Sans-pub jusqu\'au ' + fmt(new Date(u.adFreeUntil).getTime()) + '</span>' : '') +
          '</div>' +
          '<h4 style="margin:14px 0 6px">Ledger — toutes opérations (' + (u.ledger || []).length + ')</h4>' +
          '<div class="tw"><table><thead><tr><th>Date</th><th>Δ</th><th>Type</th><th>Réf.</th><th>Note</th></tr></thead><tbody>' + ldgHtml + '</tbody></table></div>' +
          '<h4 style="margin:14px 0 6px">Achats (' + (u.orders || []).length + ')</h4>' +
          '<div class="tw"><table><thead><tr><th>Date</th><th>Crédits</th><th>Montant</th><th>Opérateur</th><th>Tél.</th><th>Statut</th></tr></thead><tbody>' + ordsHtml + '</tbody></table></div>' +
          '<h4 style="margin:14px 0 6px">Générations (' + (u.generations || []).length + ')</h4>' +
          '<div class="tw"><table><thead><tr><th>Date</th><th>Type</th><th>Statut</th><th>Instruction</th></tr></thead><tbody>' + genHtml + '</tbody></table></div>' +
          (u.films && u.films.length ? '<h4 style="margin:14px 0 6px">Films (' + u.films.length + ')</h4><div class="tw"><table><thead><tr><th>Date</th><th>Titre</th><th>Durée/Langue</th><th>Coût</th><th>Statut</th><th>Erreur</th></tr></thead><tbody>' + filmHtml + '</tbody></table></div>' : '');
      }).catch(function () { det.innerHTML = '<p class="hint">Erreur réseau.</p>'; });
    });
    var af = $('#ads-f'); if (af) af.addEventListener('submit', function (e) {
      e.preventDefault(); var m = $('#a-msg'); m.textContent = '…'; m.className = 'fmsg';
      window.slashAuth.call('admin/ads', { enabled: $('#a-on').checked, afrolook: $('#a-afl').checked, client: $('#a-client').value.trim(), slots: { lb: $('#a-lb').value.trim(), rect: $('#a-rect').value.trim() } }).then(function (r) {
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
  // Erreurs de génération expliquées (cache 5 min) + bandeau d'alerte commun à tous les onglets
  var GRAV = { critique: ['#3a1416', '#ff8a8a', window.saIcon('dot')], attention: ['#3a2f12', '#ffd27a', window.saIcon('dot')], info: ['#13283a', '#8cc8ff', window.saIcon('dot')] };
  var genErr = null, genErrAt = 0;
  function when(iso) { if (!iso) return '—'; var d = new Date(iso); return isNaN(d) ? String(iso) : d.toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }); }
  function fetchGenErrors(force) {
    if (!force && genErr && Date.now() - genErrAt < 300000) return Promise.resolve(genErr);
    return window.slashAuth.call('admin/gen-errors', {}).then(function (r) { if (r.status === 200) { genErr = r.data || {}; genErrAt = Date.now(); } return genErr; });
  }
  function alertHtml(a) {
    return '<div role="alert" style="border:1px solid #ff8a8a77;border-left:5px solid #ff5a5f;background:#3a1416;color:#ffe4e4;border-radius:12px;padding:12px 14px;margin:0 0 12px">' +
      '<b style="font-size:15px">' + window.saIcon('dot') + ' ' + esc(a.titre) + '</b> <span style="opacity:.8">— ' + a.nombre + ' échec' + (a.nombre > 1 ? 's' : '') + ' depuis ' + esc(when(a.depuis)) + '</span>' +
      '<p style="margin:6px 0 4px">' + esc(a.quoi) + '</p>' +
      '<p style="margin:0"><b>À faire :</b> ' + esc(a.action) + '</p>' +
      '<div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:8px">' + (a.lien ? '<a class="btn gl sm" href="' + esc(a.lien) + '" target="_blank" rel="noopener">Ouvrir ↗</a>' : '') +
      '<button class="btn gl sm" type="button" data-goerr>Voir les erreurs</button></div></div>';
  }
  function showAlerts() {
    fetchGenErrors().then(function (g) {
      if (!root || !g) return;
      var box = document.getElementById('adm-alerts');
      if (!box) { box = document.createElement('div'); box.id = 'adm-alerts'; root.insertBefore(box, root.firstChild); }
      box.innerHTML = tab === 'errors' ? '' : (g.alerts || []).map(alertHtml).join('');
      Array.prototype.forEach.call(box.querySelectorAll('[data-goerr]'), function (b) { b.addEventListener('click', function () { var t = root.querySelector('[data-tab="errors"]'); if (t) t.click(); }); });
    }).catch(function () {});
  }
  function setService(id, res) {
    var dot = document.getElementById('dot-' + id);
    var info = document.getElementById('info-' + id);
    var bar = document.getElementById('bar-' + id);
    var fill = document.getElementById('fill-' + id);
    if (dot) dot.className = 'svc-dot' + (res.dot ? ' svc-' + res.dot : '');
    if (info) info.innerHTML = '<span>' + esc(res.info || '—') + '</span>';
    if (bar && fill && res.bar != null) {
      bar.style.display = 'block';
      fill.style.width = Math.min(100, res.bar) + '%';
      fill.className = 'svc-fill' + (res.bar >= 90 ? ' svc-fill-err' : res.bar >= 70 ? ' svc-fill-warn' : '');
    }
  }
  function loadUsageStats() {
    var grid = document.getElementById('usage-grid');
    if (!grid) return;
    var btn = document.getElementById('refresh-usage');
    if (btn) { btn.disabled = true; btn.textContent = '…'; }
    window.slashAuth.call('admin/usage-stats', {}).then(function(r) {
      if (btn) { btn.disabled = false; btn.textContent = 'Actualiser'; }
      if (r.status !== 200) return;
      var d = r.data || {};
      var el = d.elevenlabs || {};
      if (el.error) {
        setService('elevenlabs', { dot: 'err', info: el.error === 'no_config' ? 'Clé non configurée' : 'Erreur : ' + el.error });
      } else {
        var pct = el.character_limit ? Math.round(100 * el.character_count / el.character_limit) : 0;
        setService('elevenlabs', { dot: pct >= 90 ? 'err' : pct >= 70 ? 'warn' : 'ok', bar: pct, info: fmtN(el.character_count) + ' / ' + fmtN(el.character_limit) + ' caractères' + (el.next_reset ? ' — reset ' + fmt(el.next_reset) : '') });
      }
      var cf = d.cloudflare || {};
      if (cf.error) {
        setService('cloudflare', { dot: cf.error === 'no_config' ? 'warn' : 'err', info: cf.error === 'no_config' ? 'Token non configuré' : 'Erreur : ' + cf.error });
      } else {
        setService('cloudflare', { dot: 'ok', info: 'API joignable' });
      }
      var cl = d.claude || {};
      if (cl.error) {
        setService('claude', { dot: 'warn', info: 'Aucune donnée Firestore' });
      } else {
        var cost = (+( cl.cost_usd || 0)).toFixed(2);
        setService('claude', { dot: cost > 50 ? 'warn' : 'ok', info: fmtN(cl.tokens_this_month || 0) + ' tokens ce mois · ' + cost + ' $' });
      }
      setService('firebase', { dot: 'ok', info: 'Actif (vous êtes connecté)' });
      fetchGenErrors().then(function (g) {
        var a = ((g && g.alerts) || []).filter(function (x) { return /^gemini/.test(x.cause); })[0];
        if (a) setService('gemini', { dot: 'err', info: a.titre + ' depuis ' + when(a.depuis) });
        else if (g && g.lastImageOk) setService('gemini', { dot: 'ok', info: 'Dernière image réussie : ' + when(g.lastImageOk) });
        else setService('gemini', { dot: 'warn', info: 'Aucune image récente : vérifier dans AI Studio ↗' });
      }).catch(function () { setService('gemini', { dot: '', info: 'Vérifier dans AI Studio ↗' }); });
      setService('gtts', { dot: '', info: 'Vérifier dans Google Cloud ↗' });
    }).catch(function() {
      if (btn) { btn.disabled = false; btn.textContent = 'Actualiser'; }
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

// Contestation de paiement par carte (rétrofacturation) : à déclarer quand FeexPay signale un litige sur la commande.
document.addEventListener('click', function (e) {
  var b = e.target && e.target.closest ? e.target.closest('[data-cb]') : null;
  if (!b || !window.slashAuth) return;
  var id = b.getAttribute('data-cb');
  if (!window.confirm('Déclarer une contestation sur la commande ' + id + ' ?\n\nLes crédits achetés seront retirés, le pass sans pub coupé et le paiement par carte bloqué pour ce compte.')) return;
  var note = window.prompt('Note (numéro du litige, motif…) :', '') || '';
  b.disabled = true;
  window.slashAuth.call('admin/chargeback', { orderId: id, note: note }).then(function (r) {
    window.alert(r.status === 200 ? 'Contestation enregistrée.' : 'Erreur : ' + ((r.data && r.data.error) || r.status));
    if (r.status === 200) location.reload(); else b.disabled = false;
  }).catch(function () { b.disabled = false; });
});
