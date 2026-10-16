// Administration PronoFlash IA : connexion Google (Firebase Auth), puis appels à /api/admin/* qui vérifient l'accès côté serveur.
// L'interface ne décide jamais de l'accès : si le serveur répond 403, rien ne s'affiche.

import { firebaseConfig } from './firebase-config.js';

const $ = (s, r = document) => r.querySelector(s);
const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const nf = (n) => String(Math.round(n || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
const fdate = (iso) => (iso ? new Date(iso).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '–');
const DEV = location.hostname === 'localhost' && new URLSearchParams(location.search).has('dev');

let auth = null;
let user = null;
let tab = 'vue';

/* ---------- connexion ---------- */
async function initAuth() {
  if (DEV) { user = { email: 'dev@local', getIdToken: async () => 'dev' }; return start(); }
  if (/REMPLACER/.test(firebaseConfig.projectId)) { $('#login-msg').textContent = 'Configuration Firebase manquante : renseigne site/admin/firebase-config.js.'; return; }
  const { initializeApp } = await import('https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js');
  const m = await import('https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js');
  auth = m.getAuth(initializeApp(firebaseConfig));
  auth.languageCode = 'fr';
  $('#btn-login').addEventListener('click', async () => {
    $('#login-msg').textContent = '';
    try { await m.signInWithPopup(auth, new m.GoogleAuthProvider()); } catch (e) {
      const c = (e && e.code) || '';
      $('#login-msg').textContent = c === 'auth/popup-closed-by-user' ? 'Fenêtre fermée avant la fin de la connexion.' : c === 'auth/unauthorized-domain' ? 'Ce domaine n\'est pas autorisé dans Firebase Authentication.' : 'Connexion impossible. Réessaie.';
    }
  });
  $('#btn-out').addEventListener('click', () => m.signOut(auth));
  m.onAuthStateChanged(auth, (u) => { user = u; if (u) start(); else { $('#app').hidden = true; $('#login').hidden = false; } });
}

async function api(action, body) {
  const token = await user.getIdToken();
  const r = await fetch('/api/admin/' + action, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token }, body: JSON.stringify(body || {}) });
  let j = {}; try { j = await r.json(); } catch { /* corps vide */ }
  if (!r.ok) { const e = new Error(j.erreur || 'Erreur ' + r.status); e.status = r.status; throw e; }
  return j;
}

async function start() {
  try { const me = await api('me'); $('#who').textContent = me.email; } catch (e) {
    $('#login').hidden = false; $('#app').hidden = true; $('#login-msg').textContent = e.status === 403 ? e.message : 'Erreur : ' + e.message;
    if (auth) { const m = await import('https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js'); m.signOut(auth); }
    return;
  }
  $('#login').hidden = true; $('#app').hidden = false;
  // l'administrateur ne doit jamais voir (ni cliquer) les pubs tierces de son propre site : les réseaux sanctionnent les clics sur ses propres pubs
  try { if (localStorage.getItem('pf_noads') === null) localStorage.setItem('pf_noads', '1'); } catch { /* stockage bloqué */ }
  if (DEV) $('#btn-out').hidden = true;
  renderTabs(); show(tab);
}

const TABS = [['vue', "Vue d'ensemble"], ['connexions', 'Connexions'], ['fonctionnement', 'Fonctionnement'], ['semaines', 'Semaines'], ['ia', 'IA et tâches'], ['pronos', 'Pronostics'], ['bilan', 'Bilan'], ['pubs', 'Publicités'], ['reglages', 'Réglages'], ['journal', 'Journal']];
function renderTabs() {
  $('#tabs').innerHTML = TABS.map(([k, l]) => `<button class="tab" role="tab" data-t="${k}" aria-selected="${k === tab}">${l}</button>`).join('');
  $('#tabs').onclick = (e) => { const b = e.target.closest('.tab'); if (b) show(b.dataset.t); };
}
async function show(t) {
  tab = t;
  document.querySelectorAll('.tab').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.t === t)));
  const main = $('#main');
  main.innerHTML = '<p class="note">Chargement…</p>';
  try { main.innerHTML = await VIEWS[t](); if (AFTER[t]) AFTER[t](); } catch (e) { main.innerHTML = `<div class="warn">${esc(e.message)}</div>`; }
}

/* ---------- éléments communs ---------- */
function bars(pairs, fmt) {
  pairs = pairs.slice(0, 12);
  if (!pairs.length) return '<p class="note">Pas encore de données.</p>';
  const max = Math.max(...pairs.map((p) => p.v), 1);
  return pairs.map((p) => `<div class="bar"><span>${esc(fmt ? fmt(p.k) : p.k)}</span><span class="t"><i style="width:${Math.max(3, Math.round((100 * p.v) / max))}%"></i></span><b>${nf(p.v)}</b></div>`).join('');
}
const flag = (cc) => (cc && cc.length === 2 && cc !== '??' ? String.fromCodePoint(127397 + cc.charCodeAt(0), 127397 + cc.charCodeAt(1)) + ' ' : '');
function country(cc) { let n = cc; try { n = new Intl.DisplayNames(['fr'], { type: 'region' }).of(cc) || cc; } catch { /* navigateur ancien */ } return cc === '??' ? 'Inconnu' : flag(cc) + n; }
const kpi = (n, l, s) => `<div class="kpi"><b>${n}</b><span>${l}</span>${s ? `<small>${s}</small>` : ''}</div>`;
const csv = (rows) => rows.map((r) => r.map((c) => `"${String(c == null ? '' : c).replace(/"/g, '""')}"`).join(';')).join('\n');
function download(name, text) { const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['﻿' + text], { type: 'text/csv' })); a.download = name; document.body.appendChild(a); a.click(); a.remove(); }
const msg = (id, text, err) => { const el = $(id); if (el) { el.textContent = text; el.className = 'msg' + (err ? ' err' : ''); } };

/* ---------- vues ---------- */
let days = 14;
const ETATS = { ok: ['ok', 'En service'], attention: ['lent', 'Quota bientôt atteint'], panne: ['panne', 'En erreur'], non_configure: ['', 'Non configuré'], inactif: ['', 'Coupé'], jamais: ['lent', 'Jamais utilisé'] };
const until = (iso) => { if (!iso) return ''; const m = Math.round((new Date(iso) - Date.now()) / 60000); if (m < 1) return 'imminent'; if (m < 60) return `dans ${m} min`; const h = Math.floor(m / 60); return h < 48 ? `dans ${h} h ${String(m % 60).padStart(2, '0')}` : `dans ${Math.round(h / 24)} jours`; };
function miniBars(hist, key) {
  if (!hist || !hist.length) return '';
  const max = Math.max(...hist.map((h) => h[key] || 0), 1);
  return `<div style="display:flex;gap:3px;align-items:flex-end;height:38px;margin-top:10px" title="14 derniers jours">${hist.map((h) => `<i title="${esc(h.jour)} : ${nf(h[key])}" style="flex:1;display:block;background:var(--cy);border-radius:2px;height:${Math.max(2, Math.round((36 * (h[key] || 0)) / max))}px"></i>`).join('')}</div><div class="note">${key === 'neurons' ? 'neurons' : 'appels'} sur les 14 derniers jours</div>`;
}

const VIEWS = {
  async connexions() {
    const d = await api('connexions');
    const card = (t) => {
      const e = ETATS[t.etat] || ['', t.etat];
      const q = t.quota;
      const qp = q && q.limite ? Math.min(100, Math.round((100 * q.utilise) / q.limite)) : null;
      return `<div class="card" style="margin-top:0"><div style="display:flex;justify-content:space-between;gap:8px;align-items:flex-start"><div><h3 style="margin:0">${esc(t.nom)}</h3><span class="note">${esc(t.role)}</span></div><span class="pill ${t.etat === 'ok' ? 'g' : t.etat === 'panne' ? 'r' : t.etat === 'attention' || t.etat === 'jamais' ? 'y' : ''}" style="white-space:nowrap">${e[0] ? `<span class="dot ${e[0]}" style="width:9px;height:9px;margin-right:5px;vertical-align:0"></span>` : ''}${e[1]}</span></div>
        ${q ? `<div style="margin-top:12px"><div class="bar" style="grid-template-columns:1fr auto"><span class="t"><i style="width:${qp == null ? 0 : qp}%;background:${qp >= 80 ? 'var(--ko)' : qp >= 50 ? 'var(--flash)' : 'var(--ok)'}"></i></span><b>${qp == null ? '–' : qp + ' %'}</b></div><div class="note">${nf(q.utilise)} / ${nf(q.limite)} ${esc(q.unite)} aujourd'hui</div></div>` : ''}
        <div class="row" style="gap:16px;margin-top:10px">${t.appelsJour != null ? `<span><b>${nf(t.appelsJour)}</b> <span class="note">${esc(t.unite || "appels aujourd'hui")}</span></span>` : ''}${t.erreursJour ? `<span class="err"><b>${nf(t.erreursJour)}</b> erreur(s)</span>` : ''}${t.clicsJour != null ? `<span><b>${nf(t.clicsJour)}</b> <span class="note">clics</span></span>` : ''}${t.latenceMs ? `<span class="note">${nf(t.latenceMs)} ms</span>` : ''}</div>
        <p class="note" style="margin-top:8px">Dernière réussite : ${fdate(t.dernierSucces)}</p>${t.derniereErreur ? `<div class="warn" style="margin-top:6px">${fdate(t.derniereErreurLe)} : ${esc(t.derniereErreur)}</div>` : ''}
        ${!t.configure && t.secret ? `<p class="note" style="margin-top:8px">À configurer : <code>firebase functions:secrets:set ${esc(t.secret.split(' ')[0])}</code>${t.secret.includes('+') ? ' et <code>' + esc(t.secret.split('+ ')[1]) + '</code>' : ''}, puis redéployer.</p>` : ''}
        ${!t.configure && !t.secret && /Adsterra|Monetag/.test(t.nom) ? '<p class="note" style="margin-top:8px">Coller les codes du réseau dans l\'onglet Publicités.</p>' : ''}
        ${miniBars(t.historique, t.id === 'workersAi' ? 'neurons' : 'appels')}</div>`;
    };
    return `<h2>Outils connectés</h2><p class="note">État en direct de chaque service utilisé par le site. Les clés secrètes ne sont jamais affichées : seule leur présence est vérifiée.</p><div class="grid" style="margin-top:14px">${d.outils.map(card).join('')}</div>`;
  },

  async fonctionnement() {
    const d = await api('planning');
    const local = (iso) => (iso ? new Date(iso).toLocaleString('fr-FR', { weekday: 'short', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '–');
    return `<h2>Fonctionnement</h2>
    <div class="card"><h3>Comment un pronostic est produit</h3><ol class="note" style="font-size:13.5px;line-height:1.7;padding-left:18px;margin:0">
      <li><b style="color:var(--tx)">Les données arrivent</b> : chaque matin, le fournisseur de données (football-data.org ou API-Football) fournit les matchs des 7 prochains jours et les résultats de la saison.</li>
      <li><b style="color:var(--tx)">Le calcul fait le pronostic</b> : un modèle statistique (buts attendus, loi de Poisson corrigée, cotes à moins de 48 h) donne la probabilité de plus de 100 paris par match et choisit le pronostic principal. L'IA ne touche jamais aux chiffres.</li>
      <li><b style="color:var(--tx)">L'IA rédige</b> : Workers AI reçoit les chiffres et écrit l'analyse en français et en anglais. Un contrôle refuse tout chiffre inventé, toute promesse de gain ou toute erreur de langue ; ensuite Gemini, puis un texte de secours.</li>
      <li><b style="color:var(--tx)">Publication</b> : le pronostic est enregistré et visible sur le site en moins de 5 minutes.</li>
      <li><b style="color:var(--tx)">Après le match</b> : le score est relevé, chaque pari est marqué ✅ ou ❌ et le bilan se met à jour tout seul.</li></ol></div>
    <h3 style="margin-top:18px">Tâches automatiques</h3><p class="note">Heures affichées dans ton fuseau horaire. Les tâches tournent dans Firebase (Cloud Functions), sans serveur à gérer.</p>
    <div class="tw"><table><thead><tr><th>Tâche</th><th>Cadence</th><th>Rôle</th><th>Dernier passage</th><th>Prochain passage</th><th></th></tr></thead><tbody>${d.taches.map((x) => `<tr><td><b>${esc(x.nom)}</b></td><td>${esc(x.frequence)}<br><code class="note">${esc(x.cron)}</code></td><td class="note" style="max-width:360px">${esc(x.role)}</td><td>${x.dernier ? `${local(x.dernier.debut)}<br>${x.dernier.ok ? '<span class="pill g">OK</span>' : '<span class="pill r">erreur</span>'} <span class="note">${nf(x.dernier.traites)} traité(s)</span>` : '<span class="note">jamais</span>'}</td><td>${local(x.prochain)}<br><span class="note">${until(x.prochain)}</span></td><td><button class="btn sec sm" data-run="${esc(x.nom)}">Lancer maintenant</button></td></tr>`).join('')}</tbody></table></div><p class="msg" id="m-run"></p>`;
  },
  async vue() {
    const d = await api('overview', { days });
    const p = d.periode;
    const sources = { ...d.paysSource };
    const paysNote = sources.entete ? '' : '<p class="note">Pays déduits du fuseau horaire du navigateur (aucun en-tête de pays fourni par l\'infrastructure). Un VPN ou un appareil réglé sur un autre fuseau fausse un peu.</p>';
    return `<h2>Vue d'ensemble</h2><div class="row"><span class="note">Période :</span>${[7, 14, 30, 90].map((n) => `<button class="btn ${n === days ? '' : 'sec'} sm" data-days="${n}">${n} j</button>`).join('')}</div>
    <div class="kpis">${kpi(nf(d.aujourdhui.visiteurs), "Visiteurs aujourd'hui", nf(d.aujourdhui.pv) + ' pages vues')}${kpi(nf(d.sept.visiteurs), 'Visiteurs 7 jours', nf(d.sept.pv) + ' pages vues')}${kpi(nf(p.visiteurs), `Visiteurs ${days} jours`, 'somme des visiteurs uniques de chaque jour')}${kpi(nf(p.visites), 'Visites', 'une visite = un passage')}${kpi(nf(p.pv), 'Pages vues')}${kpi(nf(p.clicsAfrolook), 'Clics Afrolook', nf(p.aflImps) + ' affichages')}${kpi(nf(p.pubVues), 'Pubs affichées', 'réseaux publicitaires')}${kpi(nf(p.couponAjouts), 'Ajouts au coupon')}${kpi(nf(p.partagesWa), 'Partages WhatsApp')}${kpi(nf(p.pwaInstalles), 'Installations de l\'app', nf(p.pwaVus) + ' invitations vues · ' + nf(p.pwaClics) + ' clics')}</div>
    <div class="grid"><div class="card"><h3>Visiteurs par pays</h3>${bars(d.pays, country)}${paysNote}</div><div class="card"><h3>Pages les plus vues</h3>${bars(d.pages)}</div><div class="card"><h3>Matchs les plus vus</h3>${bars(d.matchsTop.map((m) => ({ k: m.nom, v: m.v })))}</div><div class="card"><h3>Sources</h3>${bars(d.sources)}</div><div class="card"><h3>Langue des pages vues</h3>${bars(Object.entries(d.langues || {}).map(([k, v]) => ({ k: { fr: 'Français', en: 'English' }[k] || k, v })))}</div><div class="card"><h3>Appareils</h3>${bars(Object.entries(d.appareils).map(([k, v]) => ({ k: { m: 'Téléphone', d: 'Ordinateur', t: 'Tablette', x: 'Autre' }[k] || k, v })))}</div><div class="card"><h3>Heures de pointe (UTC)</h3>${bars(Object.entries(d.heures).map(([k, v]) => ({ k: k.padStart(2, '0') + ' h', v })).sort((a, b) => b.v - a.v))}</div><div class="card"><h3>Publicités affichées par emplacement</h3>${bars(d.pub)}</div><div class="card"><h3>Encarts Afrolook (affichages / clics)</h3>${bars(d.afl)}<div style="height:8px"></div>${bars(d.aflClics)}</div></div>
    <div class="card"><h3>Par jour</h3><div class="tw"><table><thead><tr><th>Jour</th><th>Visiteurs</th><th>Visites</th><th>Pages vues</th></tr></thead><tbody>${d.jours.slice().reverse().map((r) => `<tr><td>${r.jour}</td><td>${nf(r.visiteurs)}</td><td>${nf(r.visites)}</td><td>${nf(r.pv)}</td></tr>`).join('') || '<tr><td colspan="4">Aucune donnée.</td></tr>'}</tbody></table></div></div>`;
  },

  async semaines() {
    const d = await api('weeks');
    const ar = (v, unit = ' %') => (v == null ? '–' : `<span class="${v > 0 ? 'pill g' : v < 0 ? 'pill r' : 'pill'}">${v > 0 ? '↑ +' : v < 0 ? '↓ ' : ''}${v}${unit}</span>`);
    return `<h2>Historique par semaine</h2><p class="note">Chaque lundi, le bilan de la semaine passée est figé (lundi → dimanche).</p><div class="row"><button class="btn sec sm" id="csv-w">Exporter en CSV</button></div>
    <div class="tw"><table><thead><tr><th>Semaine</th><th>Visiteurs</th><th>Visites</th><th>Pages vues</th><th>Top 5 pays</th><th>Top 5 matchs</th><th>Pronostics</th><th>Réussite</th><th>Clics Afrolook</th><th>IA (pannes)</th></tr></thead><tbody>${d.semaines.map((s) => `<tr><td><b>${esc(s.semaine)}</b><br><span class="note">${esc(s.du)} → ${esc(s.au)}</span></td><td>${nf(s.visiteurs)}</td><td>${nf(s.visites)}<br>${ar(s.vsPrecedente && s.vsPrecedente.visites)}</td><td>${nf(s.pagesVues)}<br>${ar(s.vsPrecedente && s.vsPrecedente.pagesVues)}</td><td>${(s.pays || []).slice(0, 5).map((p) => `${esc(country(p.k))} ${nf(p.v)}`).join('<br>')}</td><td>${(s.matchsTop || []).slice(0, 5).map((m) => `${esc(m.k)} ${nf(m.v)}`).join('<br>')}</td><td>${s.reussis}/${s.pronostics}</td><td>${s.tauxReussite == null ? '–' : s.tauxReussite + ' %'}<br>${ar(s.vsPrecedente && s.vsPrecedente.taux, ' pt')}</td><td>${nf(s.clicsAfrolook)}</td><td>${(s.ia && s.ia.pannes) || 0}</td></tr>`).join('') || '<tr><td colspan="10">Aucune semaine figée pour l\'instant.</td></tr>'}</tbody></table></div>`;
  },

  async ia() {
    const [ia, t] = await Promise.all([api('ia'), api('taches')]);
    const s = ia.etat || {};
    const etat = s.etat || 'panne';
    const lib = { ok: 'En service', lent: 'Lent', panne: 'En panne' }[etat];
    return `<h2>État de l'IA</h2><div class="card"><div style="font-size:20px"><span class="dot ${etat}"></span><b>${lib}</b> <span class="note">· fournisseur actif : ${esc(s.fournisseur || 'aucun')}</span></div>
    <div class="kpis">${kpi(s.latenceMs != null ? nf(s.latenceMs) + ' ms' : '–', 'Temps de réponse', 'dernier test')}${kpi(fdate(s.dernierTestOk), 'Dernier test réussi')}${kpi(nf(s.generesAujourdhui), "Textes générés aujourd'hui")}${kpi(nf(s.secoursAujourdhui), 'Textes de secours', 'IA indisponible ou refusée')}${kpi(nf(s.quotaUtilise), 'Appels Workers AI du jour', 'quota gratuit quotidien')}</div>
    ${s.derniereErreur ? `<div class="warn">Dernière erreur (${fdate(s.derniereErreurLe)}) : ${esc(s.derniereErreur)}</div>` : ''}
    <div class="row"><button class="btn" data-run="aiHealthCheck">Tester maintenant</button><span class="msg" id="m-ia"></span></div>
    <div class="tw"><table><thead><tr><th>Heure</th><th>État</th><th>Fournisseur</th><th>Latence</th></tr></thead><tbody>${ia.historique.map((h) => `<tr><td>${fdate(h.le)}</td><td>${esc(h.etat)}</td><td>${esc(h.fournisseur || '–')}</td><td>${h.latenceMs == null ? '–' : nf(h.latenceMs) + ' ms'}</td></tr>`).join('') || '<tr><td colspan="4">Aucun test enregistré.</td></tr>'}</tbody></table></div></div>
    <h2 style="margin-top:22px">Tâches automatiques</h2><p class="note">Quota restant aujourd'hui chez le fournisseur de données : <b>${t.quotaApi == null ? 'inconnu' : nf(t.quotaApi)}</b></p>
    <div class="tw"><table><thead><tr><th>Tâche</th><th>Dernier passage</th><th>Durée</th><th>Traités</th><th>Résultat</th><th></th></tr></thead><tbody>${t.taches.map((x) => { const d = x.dernier; return `<tr><td><b>${esc(x.nom)}</b></td><td>${d ? fdate(d.debut) : 'jamais'}</td><td>${d ? nf(d.dureeMs / 1000) + ' s' : '–'}</td><td>${d ? nf(d.traites) : '–'}</td><td>${d ? (d.ok ? '<span class="pill g">OK</span>' : `<span class="pill r">erreur</span><br><span class="note">${esc((d.erreurs || []).slice(0, 2).join(' | '))}</span>`) : '–'}</td><td><button class="btn sec sm" data-run="${esc(x.nom)}">Relancer</button></td></tr>`; }).join('')}</tbody></table></div><p class="msg" id="m-run"></p>`;
  },

  async pronos() {
    const [l] = await Promise.all([api('ligues')]);
    const f = VIEWS._f || (VIEWS._f = { jour: '', ligue: '', statut: '', confMin: '' });
    const d = await api('pronos', f);
    return `<h2>Pronostics</h2><div class="row"><label class="f" style="margin:0">Jour<input type="date" id="f-jour" value="${esc(f.jour)}"></label><label class="f" style="margin:0">Championnat<select id="f-ligue"><option value="">Tous</option>${l.ligues.map((x) => `<option value="${x.apiId}"${String(x.apiId) === f.ligue ? ' selected' : ''}>${esc(x.nom)}</option>`).join('')}</select></label><label class="f" style="margin:0">Statut<select id="f-statut">${['', 'prevu', 'en_cours', 'termine', 'reporte'].map((s) => `<option value="${s}"${s === f.statut ? ' selected' : ''}>${s || 'Tous'}</option>`).join('')}</select></label><label class="f" style="margin:0">Confiance min.<input type="number" id="f-conf" min="0" max="99" style="width:90px" value="${esc(f.confMin)}"></label><button class="btn sec sm" id="f-go">Filtrer</button></div>
    <p class="note">${d.matchs.length} match(s). Toute modification manuelle est notée dans le journal.</p><div class="tw"><table><thead><tr><th>Match</th><th>Quand</th><th>Pronostic</th><th>Confiance</th><th>Texte</th><th>Résultat</th><th>Actions</th></tr></thead><tbody>${d.matchs.map((m) => `<tr><td><a href="/football/${esc(m.leagueSlug)}/${esc(m.slug)}" target="_blank" rel="noopener">${esc(m.domicile)} – ${esc(m.exterieur)}</a><br><span class="note">${esc(m.ligue)}</span></td><td>${fdate(m.coupDEnvoi)}<br><span class="note">${esc(m.statut)}</span></td><td>${m.principal ? esc(m.principal) : '–'}${m.visible ? '' : ' <span class="pill r">masqué</span>'}</td><td>${m.confiance == null ? '–' : m.confiance + ' %'}</td><td>${esc(m.source || '–')}<br><span class="note">${fdate(m.calculeLe)}</span></td><td>${m.score ? esc(m.score) + (m.reussi === true ? ' ✅' : m.reussi === false ? ' ❌' : '') : '–'}</td><td><div class="row" style="margin:0"><button class="btn sec sm" data-pa="${m.visible ? 'masquer' : 'republier'}" data-id="${esc(m.id)}">${m.visible ? 'Masquer' : 'Republier'}</button><button class="btn sec sm" data-pa="regenerer" data-id="${esc(m.id)}">Regénérer</button><button class="btn sec sm" data-edit="${esc(m.id)}" data-lib="${esc(m.principal || '')}">Libellé</button></div></td></tr>`).join('') || '<tr><td colspan="7">Aucun match.</td></tr>'}</tbody></table></div><p class="msg" id="m-p"></p>`;
  },

  async bilan() {
    const pk = (k) => String(k).replace(/(\d)_(\d)/g, '$1.$2').replace(/_/g, ':');
    const sgn = (x) => (x > 0 ? '+' : '') + x;
    const diagCard = (g) => {
      if (!g) return '';
      if (!g.actif) return `<div class="card"><h3>Auto-diagnostic de l'IA</h3><p class="note">En observation : <b>${nf(g.suivis)}</b> pronostic(s) terminé(s) sur ${g.seuil} nécessaires. À partir de ${g.seuil}, l'IA compare ses probabilités aux résultats réels et se corrige toute seule (par pari, par famille de paris et sur le niveau de buts).</p></div>`;
      const fam = g.familles.map((f) => `<tr><td>${esc(f.nom.replace(/_/g, ' '))}</td><td class="num">${f.n}</td><td class="num">${sgn(f.ecart)} pts</td><td>${f.ecart < 0 ? 'surestimait : probabilités baissées' : 'sous-estimait : probabilités relevées'}</td></tr>`).join('');
      const par = g.paris.map((f) => `<tr><td>${esc(pk(f.cle))}</td><td class="num">${f.n}</td><td class="num">${sgn(f.ecart)} pts</td><td class="num">annoncé ${f.brut} % · réel ${f.reel} %</td></tr>`).join('');
      return `<div class="card"><h3>Auto-diagnostic de l'IA</h3><p class="note">Elle apprend de ses <b>${nf(g.n)}</b> derniers pronostics terminés (90 jours). Chaque correction est plafonnée et prudente : peu de données = presque pas de changement. Écart global moyen : <b>${sgn(g.global)} pt</b>.</p>` +
        (g.buts ? `<p>Niveau de buts corrigé : <b>${sgn(g.buts.domicile)} %</b> à domicile, <b>${sgn(g.buts.exterieur)} %</b> à l'extérieur (sur ${nf(g.buts.n)} matchs).</p>` : '<p class="note">Niveau de buts : aucune correction nécessaire.</p>') +
        (fam ? `<h4 style="margin:12px 0 4px">Familles de paris corrigées</h4><div class="tw"><table><thead><tr><th>Famille</th><th>Paris</th><th>Écart</th><th>Effet</th></tr></thead><tbody>${fam}</tbody></table></div>` : '<p class="note">Aucune famille de paris ne s\'écarte de plus de 3 points : les probabilités sont bien calibrées.</p>') +
        (par ? `<h4 style="margin:12px 0 4px">Paris les plus corrigés</h4><div class="tw"><table><thead><tr><th>Pari</th><th>Paris</th><th>Écart</th><th>Détail</th></tr></thead><tbody>${par}</tbody></table></div>` : '') + '</div>';
    };
    const n = VIEWS._bd || 30;
    const d = await api('bilan', { days: n });
    const row = (k, v, sub) => `<div class="bar"><span>${esc(k)}</span><span class="t"><i style="width:${v || 0}%"></i></span><b>${v == null ? '–' : v + ' %'}</b></div>${sub ? `<div class="note" style="text-align:right">${sub}</div>` : ''}`;
    return `<h2>Bilan</h2><div class="row">${[7, 30, 90].map((x) => `<button class="btn ${x === n ? '' : 'sec'} sm" data-bd="${x}">${x} j</button>`).join('')}</div>
    <div class="kpis">${kpi(d.taux == null ? '–' : d.taux + ' %', 'Réussite (pronostic principal)')}${kpi(nf(d.n), 'Pronostics')}${kpi(nf(d.ok), 'Réussis')}${kpi(nf(d.ko), 'Ratés')}</div>
    ${diagCard(d.diagnostic)}
    <div class="grid"><div class="card"><h3>Par championnat</h3>${Object.entries(d.parLigue || {}).map(([k, v]) => row(k, v.taux, v.n + ' pronostics')).join('') || '<p class="note">Pas de données.</p>'}</div><div class="card"><h3>Par niveau de confiance</h3>${(d.parConfiance || []).map((r) => row(`${r.k} à ${+r.k + 9} %`, r.taux, r.n + ' pronostics')).join('') || '<p class="note">Pas de données.</p>'}</div><div class="card"><h3>Par type de pari (réel · annoncé)</h3>${Object.values(d.parFamille || {}).map((r) => row(r.k.replace(/_/g, ' '), r.taux, `annoncé ${r.annonce} % · ${nf(r.n)} paris`)).join('') || '<p class="note">Pas de données.</p>'}</div></div>`;
  },

  async pubs() {
    const c = await api('config');
    const a = c.ads;
    const SL = [['haut', 'Bannière haut', 'sous l\'en-tête · 728×90 / 320×50'], ['native', 'Native dans la liste', 'toutes les N cartes'], ['verdict', 'Bannière sous le verdict (fiche)', '728×90 / 320×100'], ['fiche_native', 'Native après l\'analyse (fiche)', ''], ['smartlink', 'Offre partenaire (Smartlink Adsterra)', 'carte « Sponsorisé » dans la liste et sous la fiche, lien ouvert par un clic volontaire'], ['coupon_liste', 'Bannières dans la liste du coupon', 'jusqu\'à 4 : après le 2e match puis toutes les N ; 728×90 / 320×50'], ['avance', 'Encart avant les paris avancés (fiche d\'analyse)', 'le plus regardé : 300×250 ou Native, votre meilleure annonce'], ['fin', 'Bannière en fin de liste de matchs', '728×90 / 320×100'], ['colonne_rect', 'Pavé colonne (ordinateur)', '300×250'], ['colonne_tall', 'Grand format collant (ordinateur)', '300×600'], ['collante', 'Bannière collante bas (téléphone)', '320×50, fermable'], ['socialbar', 'Social Bar', 'une fois par visite après un délai'], ['popunder', 'Pop-under', 'coupé au lancement ; au plus une fois par période']];
    const slot = ([id, nom, sub]) => { const e = a.emplacements[id]; const r = (e.reseaux || []); const code = (net, k) => ((r.find((x) => x.reseau === net) || {})[k] || ''); return `<div class="slot" data-slot="${id}"><label class="c"><input type="checkbox" data-f="actif" ${e.actif ? 'checked' : ''}><b>${esc(nom)}</b> <span class="note">${esc(sub)}</span></label>
      ${e.every !== undefined ? `<label class="f">Fréquence (une toutes les N cartes)<input type="number" data-f="every" min="2" max="12" value="${e.every}" style="width:100px"></label>` : ''}${e.delaiSec !== undefined ? `<label class="f">Délai avant affichage (secondes)<input type="number" data-f="delaiSec" min="5" max="120" value="${e.delaiSec}" style="width:100px"></label>` : ''}${e.parJours !== undefined ? `<label class="f">Au plus une fois tous les N jours<input type="number" data-f="parJours" min="1" max="30" value="${e.parJours}" style="width:100px"></label>` : ''}
      ${id === 'smartlink' ? `<label class="f">Adresse du Smartlink (https://…)<input data-f="url" value="${esc(e.url || '')}" placeholder="https://…" style="width:100%"></label><label class="f">Titre affiché (facultatif)<input data-f="titre" value="${esc(e.titre || '')}" maxlength="90" placeholder="Découvrez l'offre de notre partenaire" style="width:100%"></label><label class="f">Texte du bouton (facultatif)<input data-f="bouton" value="${esc(e.bouton || '')}" maxlength="30" placeholder="Voir l'offre" style="width:220px"></label>` : ['adsterra', 'monetag'].map((net) => `<label class="f">Code ${net === 'adsterra' ? 'Adsterra (réseau principal)' : 'Monetag (secours)'}<textarea data-net="${net}" data-k="code" placeholder="Colle ici le code fourni par le réseau">${esc(code(net, 'code'))}</textarea></label><label class="f">Code ${net} pour téléphone (facultatif)<textarea data-net="${net}" data-k="codeMobile" style="min-height:50px">${esc(code(net, 'codeMobile'))}</textarea></label>`).join('')}</div>`; };
    return `<h2>Publicités</h2><div class="card" id="rev-card"><h3>Revenus Adsterra · 14 derniers jours</h3><p class="note">Chargement…</p></div><div class="card"><label class="c"><input type="checkbox" id="noads">Masquer les pubs tierces dans ce navigateur (recommandé pour l'administrateur)</label><p class="note">Les réseaux comme Adsterra sanctionnent les clics et affichages que le propriétaire génère sur son propre site : ne cliquez jamais sur vos pubs. Cette case est propre à ce navigateur ; les encarts Afrolook restent visibles.</p></div><p class="note">Rien ne s'affiche tant que l'interrupteur général est coupé. Si un réseau ne renvoie rien, le suivant est essayé (Adsterra → Monetag), puis un encart Afrolook : jamais de vide. Aucune republication nécessaire.</p>
    <div class="card"><label class="c"><input type="checkbox" id="ads-on" ${a.actif ? 'checked' : ''}><b>Publicités activées (interrupteur général)</b></label>
    <h3 style="margin-top:14px">Encarts Afrolook</h3><label class="c"><input type="checkbox" id="afl-on" ${a.afrolook.actif ? 'checked' : ''}>Encarts Afrolook activés</label><div class="row"><label class="f" style="margin:0">Un encart toutes les N cartes<input type="number" id="afl-every" min="3" max="30" value="${a.afrolook.every}" style="width:100px"></label><label class="f" style="margin:0">Part d'Afrolook (%) : emplacements où Afrolook passe en premier<input type="number" id="afl-part" min="0" max="100" value="${a.afrolook.part}" style="width:100px"></label></div></div>
    <div class="card"><h3>Emplacements</h3>${SL.map(slot).join('')}</div>
    <div class="card"><h3>ads.txt</h3><p class="note">Lignes fournies par chaque réseau (Adsterra, Monetag). Servi sur /ads.txt.</p><textarea id="ads-txt" style="min-height:120px">${esc(a.adsTxt)}</textarea><p class="note"><a href="/ads.txt" target="_blank" rel="noopener">Voir /ads.txt</a></p></div>
    <div class="card"><h3>Vérification de propriété</h3><p class="note">Balises <code>&lt;meta …&gt;</code> demandées par les réseaux, une par ligne.</p><textarea id="ads-ver" style="min-height:70px">${esc((a.verifications || []).join('\n'))}</textarea></div>
    <div class="row"><button class="btn" id="ads-save">Enregistrer</button><span class="msg" id="m-ads" role="status"></span></div>
    <div class="card"><h3>Avant de demander l'inscription chez Adsterra et Monetag</h3><ul class="note"><li>Domaine propre en HTTPS, site rapide.</li><li>Au moins 2 à 3 semaines de pronostics publiés et une page Bilan alimentée.</li><li>Pages légales complètes (voir l'onglet Réglages : aucune mention « à renseigner »).</li><li>ads.txt et balises de vérification en place.</li><li>Le bandeau de consentement fonctionne pour l'Union européenne et le Royaume-Uni.</li></ul></div>`;
  },

  async reglages() {
    const [c, l, ad, nw] = await Promise.all([api('config'), api('ligues'), api('admins'), api('actus')]);
    const s = c.site;
    const fld = (k, label, ph) => `<label class="f">${label}<input data-site="${k}" value="${esc(s[k])}" placeholder="${esc(ph || '')}"></label>`;
    return `<h2>Réglages</h2>${c.legalIncomplet.length ? `<div class="warn">Pages légales incomplètes : ${c.legalIncomplet.map((k) => esc(k)).join(', ')}. Les réseaux publicitaires exigent des mentions légales renseignées.</div>` : ''}
    <div class="card"><h3>Informations légales et contact</h3><div class="grid">${fld('editeur', 'Éditeur (nom ou raison sociale)')}${fld('statutJuridique', 'Statut juridique')}${fld('adresse', 'Adresse')}${fld('email', 'Adresse e-mail de contact public')}${fld('loi', 'Pays dont le droit s\'applique')}${fld('hebergeur', 'Hébergeur')}${fld('whatsapp', 'Lien canal WhatsApp (facultatif)')}${fld('telegram', 'Lien canal Telegram (facultatif)')}${fld('googleVerification', 'Code de vérification Google Search Console (balise HTML)', 'collez la balise meta ou la valeur de content')}</div><label class="c"><input type="checkbox" id="site-idx" ${s.indexable ? 'checked' : ''}>Site indexable par les moteurs de recherche (décocher pendant les tests)</label><div class="row"><button class="btn" id="site-save">Enregistrer</button><span class="msg" id="m-site"></span></div></div>
    <div class="card"><h3>Actualités foot</h3><p class="note">Une bande « Actus foot » (titres, nom du site et lien vers l'article) sur l'accueil et les fiches de match. Rien de l'article n'est copié. Mise à jour toutes les 2 heures. Une source qui refuse nos robots affiche son erreur : décochez-la ou réessayez plus tard.</p><label class="c"><input type="checkbox" id="nw-on" ${nw.actif ? 'checked' : ''}>Afficher les actualités sur le site</label><div class="tw"><table><thead><tr><th>Actif</th><th>Source</th><th>Langue</th><th>Dernier essai</th><th>État</th></tr></thead><tbody>${nw.sources.map((x) => `<tr><td><input type="checkbox" data-nw="${esc(x.id)}" ${x.actif ? 'checked' : ''}></td><td>${esc(x.nom)}</td><td>${esc(x.lang)}</td><td>${x.essaiLe ? fdate(x.essaiLe) : '–'}</td><td>${x.ok == null ? '<span class="pill">pas encore essayée</span>' : x.ok ? `<span class="pill g">${x.articles} articles</span>` : `<span class="pill r">${esc(x.erreur || 'erreur')}</span>`}</td></tr>`).join('')}</tbody></table></div><div class="row"><button class="btn" id="nw-save">Enregistrer</button><span class="msg" id="m-nw"></span></div></div>
    <div class="card"><h3>Championnats suivis</h3><div class="tw"><table><thead><tr><th>Championnat</th><th>Nom FR</th><th>Name EN</th><th>Pays</th><th>Saison</th><th>Ordre</th><th>Suivi</th></tr></thead><tbody>${l.ligues.map((x) => `<tr><td>${esc(x.nom)} <span class="note">#${x.apiId}</span></td><td><input type="text" data-lg="${x.apiId}" data-k="nomfr" value="${esc((x.noms && x.noms.fr) || '')}" placeholder="${esc(x.nom)}" style="width:150px"></td><td><input type="text" data-lg="${x.apiId}" data-k="nomen" value="${esc((x.noms && x.noms.en) || '')}" placeholder="${esc(x.nom)}" style="width:150px"></td><td>${esc(x.pays || '')}</td><td><input type="number" data-lg="${x.apiId}" data-k="saison" value="${x.saison}" style="width:80px"></td><td><input type="number" data-lg="${x.apiId}" data-k="ordre" value="${x.ordre}" style="width:70px"></td><td><input type="checkbox" data-lg="${x.apiId}" data-k="suivi" ${x.suivi ? 'checked' : ''}></td></tr>`).join('') || '<tr><td colspan="7">Aucun championnat.</td></tr>'}</tbody></table></div><div class="row"><button class="btn sec sm" id="lg-save">Enregistrer les championnats</button><input type="number" id="lg-new" placeholder="Identifiant du championnat" style="width:200px"><button class="btn sm" id="lg-add">Ajouter</button><span class="msg" id="m-lg"></span></div><p class="note">L'ajout vérifie l'identifiant auprès du fournisseur de données (nom, pays, saison en cours). football-data.org (gratuit) : 2015 Ligue 1, 2021 Premier League, 2014 Liga, 2019 Serie A, 2002 Bundesliga, 2001 Ligue des champions. API-Football (payant) : 61 Ligue 1, 39 Premier League, 12 Ligue des champions CAF.</p></div>
    <div class="card"><h3>Administrateurs</h3><div class="tw"><table><thead><tr><th>Adresse Google</th><th></th></tr></thead><tbody>${ad.bootstrap.map((e) => `<tr><td>${esc(e)} <span class="pill">propriétaire</span></td><td></td></tr>`).join('')}${ad.admins.map((x) => `<tr><td>${esc(x.email)}</td><td><button class="btn sec sm" data-adrm="${esc(x.email)}">Retirer</button></td></tr>`).join('')}</tbody></table></div><div class="row"><input type="email" id="ad-new" placeholder="adresse@gmail.com" style="width:260px"><button class="btn sm" id="ad-add">Ajouter</button><span class="msg" id="m-ad"></span></div></div>`;
  },

  async journal() {
    const d = await api('journal');
    return `<h2>Journal des actions</h2><div class="tw"><table><thead><tr><th>Quand</th><th>Qui</th><th>Action</th><th>Détail</th></tr></thead><tbody>${d.journal.map((j) => `<tr><td>${fdate(j.le)}</td><td>${esc(j.par)}</td><td>${esc(j.action)}</td><td class="note">${esc(JSON.stringify(j.detail || ''))}</td></tr>`).join('') || '<tr><td colspan="4">Aucune action enregistrée.</td></tr>'}</tbody></table></div>`;
  },
};

/* ---------- actions après affichage ---------- */
const AFTER = {
  fonctionnement() { AFTER.ia(); },
  vue() { document.querySelectorAll('[data-days]').forEach((b) => b.addEventListener('click', () => { days = +b.dataset.days; show('vue'); })); },
  semaines() {
    $('#csv-w').addEventListener('click', async () => {
      const d = await api('weeks');
      download('semaines-pronoflashia.csv', csv([['Semaine', 'Du', 'Au', 'Visiteurs', 'Visites', 'Pages vues', 'Pronostics', 'Réussis', 'Taux %', 'Clics Afrolook'], ...d.semaines.map((s) => [s.semaine, s.du, s.au, s.visiteurs, s.visites, s.pagesVues, s.pronostics, s.reussis, s.tauxReussite, s.clicsAfrolook])]));
    });
  },
  ia() {
    document.querySelectorAll('[data-run]').forEach((b) => b.addEventListener('click', async () => {
      b.disabled = true; msg('#m-run', 'Tâche en cours…');
      try { const r = await api('tache-lancer', { nom: b.dataset.run }); const cur = tab; await show(cur); msg('#m-run', `Tâche « ${b.dataset.run} » terminée : ${nf(r.rapport && r.rapport.traites)} traité(s).`); } catch (e) { msg('#m-run', e.message, true); b.disabled = false; }
    }));
  },
  pronos() {
    const F = VIEWS._f;
    $('#f-go').addEventListener('click', () => { F.jour = $('#f-jour').value; F.ligue = $('#f-ligue').value; F.statut = $('#f-statut').value; F.confMin = $('#f-conf').value; show('pronos'); });
    document.querySelectorAll('[data-pa]').forEach((b) => b.addEventListener('click', async () => { try { await api('prono-action', { id: b.dataset.id, action: b.dataset.pa }); show('pronos'); } catch (e) { msg('#m-p', e.message, true); } }));
    document.querySelectorAll('[data-edit]').forEach((b) => b.addEventListener('click', () => {
      const cell = b.closest('td');
      cell.innerHTML = `<div class="row" style="margin:0"><input id="lib-in" value="${esc(b.dataset.lib)}" maxlength="80" style="width:200px"><button class="btn sm" id="lib-ok">OK</button></div>`;
      $('#lib-ok').addEventListener('click', async () => { try { await api('prono-action', { id: b.dataset.edit, action: 'libelle', libelle: $('#lib-in').value }); show('pronos'); } catch (e) { msg('#m-p', e.message, true); } });
    }));
  },
  bilan() { document.querySelectorAll('[data-bd]').forEach((b) => b.addEventListener('click', () => { VIEWS._bd = +b.dataset.bd; show('bilan'); })); },
  pubs() {
    (async () => {
      const box = $('#rev-card'); if (!box) return;
      const usd = (n) => '$ ' + (+n || 0).toFixed(2);
      try {
        const r = await api('revenus');
        if (!r.connecte) { box.innerHTML = '<h3>Revenus Adsterra</h3><p class="note">Statistiques non connectées. Ajoutez <code>ADSTERRA_API_TOKEN=…</code> dans <code>functions/.env</code> (jeton créé dans Adsterra, Paramètres, API) puis redéployez les fonctions.</p>'; return; }
        const t = r.totaux;
        box.innerHTML = `<h3>Revenus Adsterra · ${esc(r.periode.debut)} → ${esc(r.periode.fin)}</h3><div class="grid"><div><span class="note">Revenus</span><div class="big num">${usd(t.revenu)}</div></div><div><span class="note">Impressions</span><div class="big num">${nf(t.impressions)}</div></div><div><span class="note">CPM moyen</span><div class="big num">${usd(t.cpm)}</div></div><div><span class="note">Clics</span><div class="big num">${nf(t.clics)}</div></div></div>` +
          (r.jours.length ? `<div class="tw"><table><thead><tr><th>Jour</th><th>Impressions</th><th>Clics</th><th>Revenus</th></tr></thead><tbody>${r.jours.map((j) => `<tr><td>${esc(j.cle)}</td><td class="num">${nf(j.impressions)}</td><td class="num">${nf(j.clics)}</td><td class="num">${usd(j.revenu)}</td></tr>`).join('')}</tbody></table></div>` : '<p class="note">Aucune donnée pour le moment : les statistiques apparaissent quand les premières pubs sont affichées (les chiffres Adsterra peuvent avoir quelques heures de retard).</p>') +
          (r.emplacements.length ? `<h3 style="margin-top:14px">Par emplacement</h3><div class="tw"><table><thead><tr><th>Emplacement</th><th>Impressions</th><th>Revenus</th></tr></thead><tbody>${r.emplacements.map((e) => `<tr><td>${esc(e.nom)}</td><td class="num">${nf(e.impressions)}</td><td class="num">${usd(e.revenu)}</td></tr>`).join('')}</tbody></table></div>` : '');
      } catch (e) { box.innerHTML = `<h3>Revenus Adsterra</h3><p class="msg err">${esc(e.message)}</p>`; }
    })();
    (() => {
      const c = $('#noads'); if (!c) return;
      try { c.checked = localStorage.getItem('pf_noads') === '1'; } catch { /* stockage bloqué */ }
      c.addEventListener('change', () => { try { if (c.checked) localStorage.setItem('pf_noads', '1'); else localStorage.removeItem('pf_noads'); } catch { /* stockage bloqué */ } });
    })();
    $('#ads-save').addEventListener('click', async () => {
      const emplacements = {};
      document.querySelectorAll('.slot').forEach((el) => {
        const e = { actif: el.querySelector('[data-f=actif]').checked };
        ['every', 'delaiSec', 'parJours'].forEach((k) => { const i = el.querySelector(`[data-f=${k}]`); if (i) e[k] = +i.value; });
        ['url', 'titre', 'bouton'].forEach((k) => { const i = el.querySelector(`[data-f=${k}]`); if (i) e[k] = i.value; });
        const nets = {};
        el.querySelectorAll('textarea[data-net]').forEach((t) => { (nets[t.dataset.net] = nets[t.dataset.net] || { reseau: t.dataset.net })[t.dataset.k] = t.value; });
        e.reseaux = Object.values(nets).filter((n) => (n.code || '').trim());
        emplacements[el.dataset.slot] = e;
      });
      const ads = { actif: $('#ads-on').checked, afrolook: { actif: $('#afl-on').checked, every: +$('#afl-every').value, part: +$('#afl-part').value }, emplacements, adsTxt: $('#ads-txt').value, verifications: $('#ads-ver').value.split('\n').map((x) => x.trim()).filter(Boolean) };
      try { await api('config-save', { ads }); msg('#m-ads', 'Enregistré.'); } catch (e) { msg('#m-ads', e.message, true); }
    });
  },
  reglages() {
    $('#site-save').addEventListener('click', async () => {
      const site = { indexable: $('#site-idx').checked };
      document.querySelectorAll('[data-site]').forEach((i) => { site[i.dataset.site] = i.value; });
      try { await api('config-save', { site }); msg('#m-site', 'Enregistré.'); } catch (e) { msg('#m-site', e.message, true); }
    });
    $('#nw-save').addEventListener('click', async () => {
      const sources = {};
      document.querySelectorAll('[data-nw]').forEach((i) => { sources[i.dataset.nw] = i.checked; });
      try { await api('actus-save', { actif: $('#nw-on').checked, sources }); msg('#m-nw', 'Enregistré.'); } catch (e) { msg('#m-nw', e.message, true); }
    });
    $('#lg-save').addEventListener('click', async () => {
      const by = {};
      document.querySelectorAll('[data-lg]').forEach((i) => { const o = (by[i.dataset.lg] = by[i.dataset.lg] || {}); const k = i.dataset.k; if (k === 'nomfr' || k === 'nomen') { o.noms = o.noms || {}; o.noms[k === 'nomfr' ? 'fr' : 'en'] = i.value; } else o[k] = i.type === 'checkbox' ? i.checked : +i.value; });
      try { for (const [id, v] of Object.entries(by)) await api('ligue-maj', { apiId: id, ...v }); msg('#m-lg', 'Enregistré.'); } catch (e) { msg('#m-lg', e.message, true); }
    });
    $('#lg-add').addEventListener('click', async () => { try { const r = await api('ligue-ajouter', { apiId: $('#lg-new').value }); msg('#m-lg', `Ajouté : ${r.ligue.nom}`); show('reglages'); } catch (e) { msg('#m-lg', e.message, true); } });
    $('#ad-add').addEventListener('click', async () => { try { await api('admin-ajouter', { email: $('#ad-new').value }); show('reglages'); } catch (e) { msg('#m-ad', e.message, true); } });
    document.querySelectorAll('[data-adrm]').forEach((b) => b.addEventListener('click', async () => { try { await api('admin-retirer', { email: b.dataset.adrm }); show('reglages'); } catch (e) { msg('#m-ad', e.message, true); } }));
  },
};

initAuth();
