// Tableau de bord de l'administration : consultation seule. Données : API Afrolook (/v1/admin/dashboard/...). Firebase sert uniquement à connecter la personne (Google).
const $ = (s, r = document) => r.querySelector(s);
const esc = (s) => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const nf = new Intl.NumberFormat('fr-FR');
const fmt = (n) => nf.format(Math.round(Number(n) || 0));
const F = (n) => fmt(n) + ' F';
const short = (n) => (n >= 1e6 ? (n / 1e6).toFixed(1).replace('.', ',') + ' M' : n >= 1e4 ? Math.round(n / 1e3) + ' k' : n >= 1e3 ? (n / 1e3).toFixed(1).replace('.', ',') + ' k' : String(Math.round(n)));
const MONTHS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
let REGION; try { REGION = new Intl.DisplayNames(['fr'], { type: 'region' }); } catch { REGION = null; }
const country = (c) => { if (!c || c === '??') return 'Inconnu'; try { return (REGION && REGION.of(c)) || c; } catch { return c; } };
const label = (l, unit) => (unit === 'month' ? MONTHS[Number(l.slice(5, 7)) - 1] + ' ' + l.slice(2, 4) : Number(l.slice(8, 10)) + ' ' + MONTHS[Number(l.slice(5, 7)) - 1]);
const fdate = (iso) => { if (!iso) return '—'; const d = new Date(iso); return isNaN(d) ? '—' : d.getDate() + ' ' + MONTHS[d.getMonth()] + ' ' + d.getFullYear(); };
const fdt = (iso) => { if (!iso) return '—'; const d = new Date(iso); return isNaN(d) ? '—' : d.getDate() + ' ' + MONTHS[d.getMonth()] + ', ' + String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0'); };
const sum = (a) => a.reduce((x, y) => x + y, 0);
const avgN = (a, k) => a.map((_, i) => Math.round(sum(a.slice(Math.max(0, i - k + 1), i + 1)) / Math.min(k, i + 1)));
const delta = (cur, prev) => { if (!prev) return ''; const d = (cur - prev) / prev * 100; return `<span class="${d >= 0 ? 'up' : 'down'}">${d >= 0 ? '▲' : '▼'} ${Math.abs(d).toFixed(1).replace('.', ',')} %</span> <span class="s">vs période précédente</span>`; };
const STATUS = { pending: ['En attente', 'wait'], approved: ['Validé', 'ok'], active: ['Validé', 'ok'], rejected: ['Refusé', 'bad'], suspended: ['Suspendu', 'bad'], paused: ['En pause', 'wait'], ended: ['Terminée', ''], paid: ['Payé', 'ok'], requested: ['Demandé', 'wait'] };
const badge = (s) => { const [t, c] = STATUS[s] || [s, '']; return `<span class="adm-badge ${c}">${esc(t)}</span>`; };
const OFFER = { free: 'Gratuite', network: 'Réseau', paid: 'Payante' };
const TX = { deposit: 'Dépôt', coin_purchase: 'Achat de pièces', coin_spend: 'Dépense de pièces', like: 'J’aime reçu', gift: 'Cadeau', conversion: 'Conversion', view_cashout: 'Encaissement de vues', withdrawal: 'Retrait', sponsorship: 'Parrainage', refund: 'Remboursement', chargeback: 'Rétrofacturation', opening: 'Solde d’ouverture' };
const initial = (s) => (String(s || '?').trim().charAt(0) || '?').toUpperCase();
const avatar = (url, name, sq) => `<span class="adm-av${sq ? ' sq' : ''}" ${url && /^https:\/\//.test(url) ? `style="background-image:url('${esc(url)}')"` : ''}>${url && /^https:\/\//.test(url) ? '' : esc(initial(name))}</span>`;

/* ——— Connexion Google (Firebase) et appels à l'API ——— */
const root = $('#adm');
const API_ADMIN = (root.dataset.api || '').replace(/\/+$/, '') + '/v1/admin';
const API = API_ADMIN + '/dashboard';
let auth = null;
const gateErr = (m) => { const e = $('#adm-gerr'); e.hidden = !m; e.textContent = m || ''; };

/** `path` : relatif au tableau de bord ; avec « @ » devant : un point d'API d'administration déjà utilisé par l'application (travail, quiz, étude, commissions). */
async function apiGet(path) {
  let r;
  try { r = await fetch(path.startsWith('@') ? `${API_ADMIN}/${path.slice(1)}` : `${API}/${path}`, { headers: { Accept: 'application/json', Authorization: 'Bearer ' + (await auth.currentUser.getIdToken()) } }); }
  catch { throw Object.assign(new Error('Impossible de joindre le serveur. Vérifie ta connexion puis réessaie.'), { code: 'network' }); }
  const j = await r.json().catch(() => ({}));
  if (r.ok) return j;
  if (r.status === 404 || r.status === 401) throw Object.assign(new Error('Cette page est réservée à l’équipe Afrolook. Ton compte n’a pas ce droit.'), { code: 'denied' });
  throw Object.assign(new Error((j && j.message) || 'Le serveur a répondu avec une erreur. Réessaie dans un instant.'), { code: 'server' });
}

(async function boot() {
  const V = '10.14.1', G = `https://www.gstatic.com/firebasejs/${V}`;
  let ready; const sdk = new Promise((r) => { ready = r; });
  $('#adm-in').addEventListener('click', async () => {
    gateErr(''); const b = $('#adm-in'); b.disabled = true;
    try {
      const { A, auth: au } = await Promise.race([sdk, new Promise((_, rej) => setTimeout(() => rej(new Error('lent')), 30000))]);
      const p = new A.GoogleAuthProvider();
      try { await A.signInWithPopup(au, p); } catch (e) {
        if (e.code === 'auth/popup-blocked' || e.code === 'auth/operation-not-supported-in-this-environment') return A.signInWithRedirect(au, p);
        if (e.code === 'auth/unauthorized-domain') gateErr('Ce site n’est pas encore autorisé pour la connexion Google.');
        else if (e.code !== 'auth/popup-closed-by-user' && e.code !== 'auth/cancelled-popup-request') gateErr(`Connexion impossible pour le moment (${e.code || 'erreur'}). Réessaie.`);
      }
    } catch { gateErr('La connexion met du temps à charger. Vérifie ta connexion internet puis réessaie.'); }
    finally { b.disabled = false; }
  });
  let mods;
  try { mods = await Promise.all([import(`${G}/firebase-app.js`), import(`${G}/firebase-auth.js`)]); } catch { gateErr('Impossible de charger la connexion Google (réseau). Recharge la page.'); return; }
  const [{ initializeApp }, A] = mods;
  auth = A.getAuth(initializeApp(JSON.parse($('#fbcfg').textContent)));
  ready({ A, auth });
  $('#adm-out').addEventListener('click', () => A.signOut(auth));
  A.onAuthStateChanged(auth, (u) => {
    try { u ? localStorage.setItem('afl_in', '1') : localStorage.removeItem('afl_in'); } catch { /* stockage indisponible */ }   // état lu par le bouton du haut (site.js)
    $('#adm-gate').hidden = !!u; $('#adm-app').hidden = !u; $('#adm-user').hidden = !u;
    if (u) { $('#adm-mail').textContent = u.email || ''; start(); }
  });
})();

/* ——— Graphiques SVG (barres, courbes, anneau) ——— */
const W = 640, H = 230, PL = 42, PR = 10, PT = 12, PB = 26;
function niceMax(v) { if (!v || v <= 0) return 1; const e = Math.pow(10, Math.floor(Math.log10(v))); const f = v / e; return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * e; }
function gridSvg(max) { let g = ''; for (let i = 0; i <= 4; i++) { const y = PT + (H - PT - PB) * (1 - i / 4); g += `<line x1="${PL}" x2="${W - PR}" y1="${y}" y2="${y}" stroke="var(--line)"/><text x="${PL - 6}" y="${y + 3}" text-anchor="end">${short(max * i / 4)}</text>`; } return g; }
function xl(labels, X, unit) { const n = labels.length; const step = Math.max(1, Math.ceil(n / 7)); let g = ''; labels.forEach((l, i) => { if (i % step === 0 || i === n - 1) g += `<text x="${X(i)}" y="${H - 8}" text-anchor="middle">${esc(label(l, unit))}</text>`; }); return g; }
let chartSeq = 0;
function mountChart(body, labels, unit, S, X, n, slot) {
  const id = 'c' + (++chartSeq);
  setTimeout(() => {
    const el = document.getElementById(id); if (!el) return; const svg = el.querySelector('svg'); const tip = el.querySelector('.adm-tip'); const cross = svg.querySelector('.cross');
    const move = (e) => {
      const r = svg.getBoundingClientRect(); const px = ((e.clientX - r.left) / r.width) * W;
      let i = slot ? Math.floor((px - PL) / slot) : Math.round(((px - PL) / (W - PL - PR)) * (n - 1)); i = Math.max(0, Math.min(n - 1, i));
      cross.setAttribute('x1', X(i)); cross.setAttribute('x2', X(i)); cross.style.display = '';
      tip.style.display = 'block'; tip.style.left = Math.min(Math.max(X(i) / W * r.width, 70), r.width - 70) + 'px'; tip.style.top = '4px';
      tip.innerHTML = `<b>${esc(label(labels[i], unit))}</b><br>` + S.map((s) => `${esc(s.name)} : <b>${fmt(s.data[i])}</b>`).join('<br>');
    };
    svg.addEventListener('pointermove', move); svg.addEventListener('pointerdown', move);
    svg.addEventListener('pointerleave', () => { tip.style.display = 'none'; cross.style.display = 'none'; });
  }, 0);
  return `<div class="adm-chart" id="${id}"><svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Graphique : ${esc(S.map((s) => s.name).join(', '))}">${body}<line class="cross" y1="${PT}" y2="${H - PB}" stroke="var(--muted)" stroke-dasharray="3 3" style="display:none"/></svg><div class="adm-tip"></div></div>`;
}
function lineChart(labels, unit, S) {
  const max = niceMax(Math.max(1, ...S.flatMap((s) => s.data)) * 1.02); const n = labels.length;
  const X = (i) => PL + (W - PL - PR) * (n === 1 ? .5 : i / (n - 1)); const Y = (v) => PT + (H - PT - PB) * (1 - v / max);
  let body = `<g class="axis">${gridSvg(max)}${xl(labels, X, unit)}</g>`;
  S.forEach((s) => {
    const pts = s.data.map((v, i) => `${X(i).toFixed(1)},${Y(v).toFixed(1)}`).join(' ');
    if (s.area) body += `<polygon points="${X(0)},${Y(0)} ${pts} ${X(n - 1)},${Y(0)}" fill="${s.color}" opacity=".16"/>`;
    body += `<polyline points="${pts}" fill="none" stroke="${s.color}" stroke-width="${s.w || 2.2}" stroke-linejoin="round" stroke-linecap="round" ${s.dash ? 'stroke-dasharray="5 4"' : ''}/>`;
  });
  return mountChart(body, labels, unit, S, X, n);
}
function barChart(labels, unit, data, avg, color, name) {
  const max = niceMax(Math.max(1, ...data) * 1.05); const n = data.length; const slot = (W - PL - PR) / n; const bw = Math.max(2, slot * .66);
  const X = (i) => PL + slot * (i + .5); const Y = (v) => PT + (H - PT - PB) * (1 - v / max);
  let body = `<g class="axis">${gridSvg(max)}${xl(labels, X, unit)}</g>`;
  data.forEach((v, i) => { const h = (H - PT - PB) * v / max; body += `<rect x="${PL + slot * i + (slot - bw) / 2}" y="${H - PB - h}" width="${bw}" height="${h}" rx="${Math.min(3, bw / 3)}" fill="${color}"/>`; });
  body += `<polyline points="${avg.map((v, i) => `${X(i).toFixed(1)},${Y(v).toFixed(1)}`).join(' ')}" fill="none" stroke="var(--ink)" stroke-width="2" stroke-dasharray="5 4"/>`;
  return mountChart(body, labels, unit, [{ name, data }, { name: 'Moyenne mobile 7', data: avg }], X, n, slot);
}
function donut(parts, center, sub) {
  const tot = parts.reduce((a, p) => a + p.v, 0) || 1; let a0 = -Math.PI / 2; const R = 54, r = 34;
  const arcs = parts.filter((p) => p.v > 0).map((p) => {
    const a1 = a0 + (p.v / tot) * Math.PI * 2; const big = a1 - a0 > Math.PI ? 1 : 0; const Pt = (a, rr) => `${(70 + rr * Math.cos(a)).toFixed(2)} ${(70 + rr * Math.sin(a)).toFixed(2)}`;
    const d = p.v / tot > .9999 ? `M 70 ${70 - R} A ${R} ${R} 0 1 1 69.99 ${70 - R} L 69.99 ${70 - r} A ${r} ${r} 0 1 0 70 ${70 - r} Z` : `M ${Pt(a0, R)} A ${R} ${R} 0 ${big} 1 ${Pt(a1, R)} L ${Pt(a1, r)} A ${r} ${r} 0 ${big} 0 ${Pt(a0, r)} Z`;
    a0 = a1; return `<path d="${d}" fill="${p.c}" stroke="var(--surface)" stroke-width="2"/>`;
  }).join('');
  return `<div style="display:flex;gap:16px;align-items:center;flex-wrap:wrap"><svg viewBox="0 0 140 140" style="width:140px;flex:none" role="img" aria-label="Répartition">${arcs}<text x="70" y="68" text-anchor="middle" style="font:800 15px var(--display);fill:var(--ink)">${esc(center)}</text><text x="70" y="82" text-anchor="middle" style="font:500 8px var(--body);fill:var(--muted)">${esc(sub)}</text></svg>
  <div class="adm-legend" style="flex-direction:column;gap:6px;margin:0">${parts.map((p) => `<span><i style="background:${p.c}"></i>${esc(p.n)} <b style="color:var(--ink)">${Math.round(p.v / tot * 100)} %</b> · ${fmt(p.v)}</span>`).join('')}</div></div>`;
}
const seg = (name, items, cur) => `<div class="adm-seg" role="group" aria-label="${esc(name)}">${items.map(([k, l]) => `<button type="button" data-${name}="${esc(k)}" aria-pressed="${String(cur) === String(k)}">${esc(l)}</button>`).join('')}</div>`;
const kpi = (l, v, extra) => `<div class="adm-card adm-kpi"><div class="l">${esc(l)}</div><div class="v">${v}</div>${extra || ''}</div>`;
const head = (t, s, right) => `<header class="adm-bar"><div><h2 style="font-size:28px">${esc(t)}</h2><p class="adm-lead">${esc(s)}</p></div>${right || ''}</header>`;
const periodSeg = () => seg('period', [['7', '7 jours'], ['30', '30 jours'], ['90', '90 jours'], ['12', '12 mois']], st.period);
const lock = '<span class="adm-lock">🔒 Consultation seule</span>';

/* ——— État et navigation ——— */
const TABS = [['over', 'Vue d’ensemble', 'vue'], ['users', 'Utilisateurs', 'utilisateurs'], ['act', 'Activité', 'activite'], ['posts', 'Publications', 'publications'], ['money', 'Argent', 'argent'], ['work', 'Travail', 'travail'], ['learn', 'Quiz et Étude', 'apprentissage'], ['rew', 'Récompenses', 'recompenses'], ['adv', 'Annonceurs', 'annonceurs'], ['pub', 'Diffuseurs', 'diffuseurs']];
const st = { tab: 'over', detail: null, period: '30', topBy: 'views', topWin: '30', advBy: 'views', pubBy: 'shows', evoP: '90', evo: 'views', wdays: '7', cache: {} };
const main = () => $('#adm-main');
let started = false;
let token = 0;   // une réponse tardive d'un écran quitté ne doit pas écraser l'écran courant

function start() { if (started) return; started = true; parseHash(); render(); }
function parseHash() {
  const h = location.hash.replace(/^#\/?/, '');
  const m = h.match(/^(u|a|d)\/([A-Za-z0-9_-]{1,64})$/);
  if (m) { st.detail = { k: m[1], id: m[2] }; return; }
  const t = (TABS.find((x) => x[2] === h) || [])[0];
  if (t) { st.tab = t; st.detail = null; }
}
function setHash() { const h = st.detail ? `#/${st.detail.k}/${st.detail.id}` : '#' + TABS.find((x) => x[0] === st.tab)[2]; if (location.hash !== h) history.replaceState(null, '', h); }
addEventListener('hashchange', () => { if (!started) return; const before = JSON.stringify([st.tab, st.detail]); parseHash(); if (JSON.stringify([st.tab, st.detail]) !== before) render(); });

async function render() {
  const my = ++token;
  $('#adm-tabs').innerHTML = TABS.map(([k, l]) => `<button type="button" data-tab="${k}" ${st.tab === k && !st.detail ? 'aria-current="page"' : ''}>${esc(l)}</button>`).join('');
  main().innerHTML = '<p class="adm-empty">Chargement…</p>';
  setHash();
  try {
    let html;
    if (st.detail) html = await { u: userPage, a: advPage, d: pubPage }[st.detail.k](st.detail.id);
    else html = await { over: overPage, users: usersPage, act: actPage, posts: postsPage, money: moneyPage, work: workPage, learn: learnPage, rew: rewPage, adv: advListPage, pub: pubListPage }[st.tab]();
    if (my === token) main().innerHTML = html;
  } catch (e) {
    if (my !== token) return;
    main().innerHTML = `<div class="adm-card"><p class="adm-err">${esc(e.message || 'Chargement impossible.')}</p>${e.code === 'denied' ? '' : '<button class="adm-btn" data-retry type="button">Réessayer</button>'}</div>`;
  }
}

/* ——— 1. Vue d'ensemble ——— */
async function overPage() {
  const o = (await apiGet(`overview?period=${st.period}`)).data;
  let ads = null; try { ads = (await apiGet(`ads/overview?period=${st.period}`)).data; } catch (e) { if (e.code === 'network') throw e; }   // sans le droit « régie », cette partie est simplement absente
  const unit = o.unit, labels = o.labels, u = unit === 'month' ? 'mois' : 'jour';
  const sg = o.signups.series, act = o.activity.total;
  const pf = o.platforms_30d, pfTot = pf.android + pf.ios + pf.other;
  const cc = o.countries; const ccMax = Math.max(1, ...cc.map((c) => c.n));
  let html = `<div class="adm-page">${head('Vue d’ensemble', 'Les personnes, les annonceurs et les diffuseurs de la plateforme, sur une seule page.', periodSeg())}
  <div class="adm-sec"><i></i><h3 style="font-size:20px">Utilisateurs</h3></div>
  <section class="adm-kpis">
    ${kpi('Inscriptions', fmt(o.signups.total), `<div class="d">${delta(o.signups.total, o.signups.previous_total)}</div>`)}
    ${kpi('Actifs aujourd’hui', fmt(o.activity.today), `<div class="s">hier ${fmt(o.activity.yesterday)}</div>`)}
    ${kpi('Actifs sur 30 jours', fmt(o.activity.d30), `<div class="s">personnes différentes</div>`)}
    ${kpi('Comptes au total', fmt(o.users.total), `<div class="s">dont ${fmt(o.users.suspended)} suspendus</div>`)}
    ${kpi('Reviennent après 7 jours', o.users.retention_d7 == null ? '—' : String(o.users.retention_d7).replace('.', ',') + ' %', `<div class="s">des inscrits d’il y a 7 à 14 jours</div>`)}
    ${o.views_to_cash ? kpi('Vues à encaisser', short(o.views_to_cash.views), `<div class="s">≈ ${F(o.views_to_cash.xof)} que les créateurs peuvent encore encaisser</div>`) : ''}
  </section>
  <section class="adm-grid2">
    <div class="adm-card"><h3>Inscriptions par ${u}</h3><p class="sub">Ligne pointillée : moyenne sur 7 ${u}s.</p>${barChart(labels, unit, sg, avgN(sg, 7), 'var(--c1)', 'Inscriptions')}</div>
    <div class="adm-card"><h3>Plateformes</h3><p class="sub">Où les gens se connectent (30 jours).</p>${donut([{ n: 'Android', v: pf.android, c: 'var(--c1)' }, { n: 'iPhone', v: pf.ios, c: 'var(--c2)' }, { n: 'Autres', v: pf.other, c: 'var(--c3)' }], short(pfTot), 'actifs 30 j')}
      <h3 style="margin-top:18px">Inscriptions par pays</h3><p class="sub">Sur la période choisie.</p>
      <div class="adm-hb">${cc.length ? cc.map((c) => `<div class="r"><span>${esc(country(c.code))}</span><div class="t"><i style="width:${Math.max(3, c.n / ccMax * 100)}%"></i></div><span class="n">${fmt(c.n)}</span></div>`).join('') : '<p class="adm-empty">Aucune inscription sur la période.</p>'}</div></div>
  </section>
  <section class="adm-card"><h3>Connexions : personnes différentes actives chaque ${u}</h3><p class="sub">Une personne qui se connecte plusieurs fois le même jour compte une fois. Historique conservé depuis le 02/11/2026.</p>
    <div class="adm-legend"><span><i style="background:var(--c1)"></i>Android</span><span><i style="background:var(--c2)"></i>iPhone</span><span><i style="background:var(--ink)"></i>Total</span></div>
    ${lineChart(labels, unit, [{ name: 'Android', color: 'var(--c1)', data: o.activity.android, area: true }, { name: 'iPhone', color: 'var(--c2)', data: o.activity.ios, area: true }, { name: 'Total', color: 'var(--ink)', data: act, w: 1.6, dash: true }])}
    <button class="adm-go" type="button" data-tab="users">Voir les meilleurs utilisateurs →</button></section>`;
  if (ads) {
    const a = ads.ads, p = ads.pending;
    html += `<div class="adm-sec"><i style="background:var(--yellow)"></i><h3 style="font-size:20px">Afrolook Ads : annonceurs et diffuseurs</h3></div>
    <section class="adm-kpis">
      ${kpi('Annonces actives', fmt(a.active), `<div class="s">chez ${fmt(a.advertisers_active)} annonceurs</div>`)}
      ${kpi('Affichages valides', short(ads.shows.total))}
      ${kpi('Clics valides', short(ads.clicks.total), `<div class="s">visibles ici et dans l’espace de l’annonceur seulement</div>`)}
      ${kpi('Gains des diffuseurs', F(ads.publisher_gains.total_fcfa), `<div class="s">leur part, sur la période</div>`)}
      ${kpi('À valider', fmt(p.advertisers + p.ads + p.publishers + p.properties), `<div class="s">${fmt(p.advertisers)} annonceurs · ${fmt(p.ads)} annonces · ${fmt(p.publishers)} diffuseurs · ${fmt(p.properties)} sites</div>`)}
    </section>
    <section class="adm-grid2">
      <div class="adm-card"><h3>Affichages valides et clics par ${u}</h3><p class="sub">Comptage strict : sans doublon, sans fraude.</p><div class="adm-legend"><span><i style="background:var(--c1)"></i>Affichages</span><span><i style="background:var(--c3)"></i>Clics</span></div>
        ${lineChart(labels, unit, [{ name: 'Affichages', color: 'var(--c1)', data: ads.shows.series, area: true }, { name: 'Clics', color: 'var(--c3)', data: ads.clicks.series }])}</div>
      <div class="adm-card"><h3>Annonces par offre</h3><p class="sub">Gratuite, Réseau payante, Campagne Partage.</p>${donut([{ n: 'Gratuite', v: a.free, c: 'var(--c1)' }, { n: 'Réseau', v: a.network, c: 'var(--c2)' }, { n: 'Partage', v: a.share, c: 'var(--c3)' }], fmt(a.free + a.network + a.share), 'annonces')}
        <div style="display:flex;gap:16px;flex-wrap:wrap;margin-top:8px"><button class="adm-go" type="button" data-tab="adv">Annonceurs →</button><button class="adm-go" type="button" data-tab="pub">Diffuseurs →</button></div></div>
    </section>`;
  }
  return html + '</div>';
}

/* ——— 2. Utilisateurs ——— */
async function usersPage() {
  const r = await apiGet(`top-users?by=${st.topBy}&window=${st.topWin}&limit=20`); const rows = r.data, money = r.meta.money;
  const mc = st.topWin === 'all' ? 'views_total' : 'views_30';
  return `<div class="adm-page">${head('Meilleurs utilisateurs', 'Ceux qui cumulent le plus de vues. Touchez une ligne pour ouvrir la fiche complète, en consultation seule.',
    `<div style="display:flex;gap:8px;flex-wrap:wrap">${seg('topby', [['views', 'Vues'], ['likes', 'J’aime']].concat(money ? [['earned', 'Gains'], ['cash', 'À encaisser']] : []), st.topBy)}${st.topBy === 'views' ? seg('topwin', [['30', '30 jours'], ['all', 'Depuis toujours']], st.topWin) : ''}</div>`)}
  <section class="adm-card"><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th></th><th>Utilisateur</th><th>Pays</th><th class="num">Vues${st.topBy === 'views' ? (st.topWin === 'all' ? ' (total)' : ' payantes (30 j)') : ''}</th><th class="num">Publications</th><th class="num">J’aime</th><th class="num">Abonnés</th>${money ? '<th class="num">Pièces gagnées</th><th class="num">Vues à encaisser</th>' : ''}</tr></thead><tbody>
  ${rows.map((u, i) => `<tr class="adm-row" tabindex="0" role="link" data-open="u/${esc(u.id)}" aria-label="Ouvrir la fiche de @${esc(u.username)}"><td class="adm-rk ${i < 3 ? 't3' : ''}">${i + 1}</td>
    <td><div class="adm-who">${avatar(u.avatar_url, u.username)}<div><b>@${esc(u.username)}</b> ${u.is_verified ? '<span class="adm-badge cert">Certifié</span>' : ''}<div style="font-size:12px;color:var(--muted)">${esc(u.display_name || '')}</div></div></div></td>
    <td>${esc(country(u.country))}</td><td class="num"><b>${fmt(u[mc])}</b></td><td class="num">${fmt(u.posts)}</td><td class="num">${fmt(u.likes)}</td><td class="num">${fmt(u.followers)}</td>
    ${money ? `<td class="num">${fmt(u.earned_coins)}</td><td class="num"><b>${fmt(u.pending_views)}</b> <span style="color:var(--muted)">· ${F(u.pending_xof)}</span></td>` : ''}</tr>`).join('')}</tbody></table></div>
  ${rows.length ? '' : '<p class="adm-empty">Aucun utilisateur.</p>'}</section></div>`;
}
async function userPage(id) {
  const f = (await apiGet(`users/${encodeURIComponent(id)}?period=${st.evoP}`)).data; const u = f.user, k = f.kpis, e = f.evolution, m = f.money;
  const evMap = { views: ['Vues payantes', e.views_paid, 'var(--c1)'], followers: ['Nouveaux abonnés', e.followers, 'var(--c2)'] };
  const ev = evMap[st.evo] || evMap.views; const unit = e.unit;
  const act = f.presence.active; const activeDays = act.filter(Boolean).length;
  const c = m && m.cash, w = m && m.wallet;
  const pct = c && c.paid_views ? Math.round(c.credited_views / c.paid_views * 100) : 0;
  return `<div class="adm-page"><button class="adm-back" type="button" data-back>← Retour aux meilleurs utilisateurs</button>
  <section class="adm-card"><div class="adm-prof">${avatar(u.avatar_url, u.username)}<div style="flex:1;min-width:200px"><h2>@${esc(u.username)} ${u.is_verified ? '<span class="adm-badge cert">Certifié</span>' : ''} ${u.status === 'active' ? '<span class="adm-badge ok">Actif</span>' : `<span class="adm-badge bad">${esc(({ suspended: 'Suspendu', pending_deletion: 'Suppression en cours', restore_fee_due: 'Rétablissement à payer' })[u.status] || u.status)}</span>`}</h2>
    <div class="adm-meta"><span>Nom : <b>${esc(u.display_name || '—')}</b></span><span>Pays : <b>${esc(country(u.country))}</b></span><span>Plateforme : <b>${esc(u.platform || '—')}</b></span><span>Inscrit le : <b>${fdate(u.created_at)}</b></span><span>Dernière connexion : <b>${fdt(u.last_seen_at)}</b></span><span>E-mail : <b>${esc(u.email_masked || '—')}</b> <small>(masqué)</small></span></div></div>${lock}</div></section>
  <section class="adm-kpis">${kpi('Vues (total)', short(k.views_total))}${kpi('Vues payantes (30 jours)', short(k.views_30), `<div class="s">${fmt(k.views_30 / 30)} par jour</div>`)}${kpi('Publications', fmt(k.posts))}${kpi('Abonnés', fmt(k.followers))}${kpi('J’aime reçus', fmt(k.likes), `<div class="s">${k.posts ? fmt(k.likes / k.posts) : 0} par publication</div>`)}</section>
  ${c ? `<section class="adm-card"><h3>Vues à encaisser</h3><p class="sub">Les vues de ses publications que la personne n’a pas encore converties en argent. Seul l’encaissement existe : rien ne se paie tout seul.</p>
    <div class="adm-wallet">
      <div><small>Vues disponibles</small><strong>${fmt(c.pending_views)}</strong><em>pas encore encaissées</em></div>
      <div><small>Valeur en argent</small><strong>${F(c.available_xof)}</strong><em>${c.available_xof >= c.min_cash_xof ? 'encaissable maintenant' : 'sous le minimum de ' + F(c.min_cash_xof)}</em></div>
      <div><small>Palier du créateur</small><strong>${esc(c.tier)}</strong><em>${(c.rate_milli / 1000).toString().replace('.', ',')} F par vue</em></div>
      <div><small>Vues déjà encaissées</small><strong>${fmt(c.credited_views)}</strong><em>sur ${fmt(c.paid_views)} vues payantes</em></div>
      <div><small>Total encaissé</small><strong>${F(c.cashed_total_xof)}</strong><em>dernier : ${fdate(c.last_cashed_at)}</em></div>
      <div><small>Encaissé aujourd’hui</small><strong>${F(c.cashed_today_xof)}</strong><em>plafond du jour : ${F(c.daily_cap_xof)}</em></div></div>
    <div class="adm-meter" style="margin-top:12px" role="img" aria-label="${pct} % des vues déjà encaissées"><i style="width:${pct}%"></i></div><p class="sub" style="margin:6px 0 0">${pct} % de ses vues payantes ont déjà été encaissées.</p></section>` : ''}
  ${w ? `<section class="adm-card"><h3>Soldes et argent</h3><p class="sub">Lecture du portefeuille tel qu’il est aujourd’hui. Rien ne peut être modifié ici.</p><div class="adm-wallet">
    <div><small>Pièces gagnées</small><strong>${fmt(w.earned_coins)}</strong><em>convertibles en argent</em></div><div><small>Pièces de dépôt</small><strong>${fmt(w.deposit_coins)}</strong><em>achats et abonnements</em></div>
    <div><small>Argent déposé</small><strong>${F(w.deposit_xof)}</strong><em>jamais retirable</em></div><div><small>Gains à retirer</small><strong>${F(w.payout_xof)}</strong><em>en francs CFA</em></div>
    <div><small>Dette</small><strong ${w.debt_coins ? 'style="color:var(--c4)"' : ''}>${fmt(w.debt_coins)}</strong><em>${w.debt_coins ? 'pièces à rembourser' : 'aucune'}</em></div><div><small>Total retiré</small><strong>${F(m.withdrawn_xof)}</strong><em>depuis l’inscription</em></div></div></section>` : ''}
  <section class="adm-grid2"><div class="adm-card"><div class="adm-bar"><h3>Évolution</h3><div style="display:flex;gap:8px;flex-wrap:wrap">${seg('evo', [['views', 'Vues payantes'], ['followers', 'Abonnés']], st.evo)}${seg('evop', [['30', '30 j'], ['90', '90 j'], ['12', '12 mois']], st.evoP)}</div></div>
    <p class="sub">${esc(ev[0])} par ${unit === 'month' ? 'mois' : 'jour'}.</p>${lineChart(e.labels, unit, [{ name: ev[0], color: ev[2], data: ev[1], area: true }])}</div>
    <div class="adm-card"><h3>Présence</h3><p class="sub">45 derniers jours : jours de connexion.</p><div class="adm-strip">${act.map((a) => `<i class="${a ? 'on' : ''}"></i>`).join('')}</div><p class="sub" style="margin-top:8px">${activeDays} jours actifs sur 45</p>
      <h3 style="margin-top:14px">Sécurité du compte</h3><div class="adm-list"><div class="it"><span>Signalements reçus</span><span>${fmt(f.security.reports_against)}</span></div><div class="it"><span>Bloqué par</span><span>${fmt(f.security.blocked_by)} personnes</span></div><div class="it"><span>Abonnement</span><span>${f.security.subscription ? 'Oui' : 'Aucun'}</span></div></div></div></section>
  <section class="adm-grid2"><div class="adm-card"><h3>Publications les plus vues</h3><div class="adm-list">${f.top_posts.length ? f.top_posts.map((p) => `<div class="it"><span>${esc(p.text || 'Sans texte')}</span><span>${fmt(p.views)} vues</span></div>`).join('') : '<p class="adm-empty">Aucune publication.</p>'}</div></div>
    ${m ? `<div class="adm-card"><h3>Dernières opérations du portefeuille</h3><p class="sub">Historique en lecture seule.</p><div class="adm-list">${m.transactions.length ? m.transactions.map((t) => `<div class="it"><span>${esc(TX[t.kind] || t.kind)}<br><small style="color:var(--muted)">${fdt(t.created_at)}</small></span><span>${t.coins ? (t.coins > 0 ? '+ ' : '− ') + fmt(Math.abs(t.coins)) + ' pièces' : ''}${t.coins && t.amount_xof ? '<br>' : ''}${t.amount_xof ? (t.amount_xof > 0 ? '+ ' : '− ') + F(Math.abs(t.amount_xof)) : ''}</span></div>`).join('') : '<p class="adm-empty">Aucune opération.</p>'}</div></div>` : ''}</section></div>`;
}

/* ——— 3. Annonceurs ——— */
async function advListPage() {
  const rows = (await apiGet(`ads/advertisers?by=${st.advBy}`)).data;
  return `<div class="adm-page">${head('Annonceurs', 'Les marques qui annoncent sur Afrolook Ads : ce qu’elles diffusent et ce que ça donne.', seg('advby', [['views', 'Affichages'], ['clicks', 'Clics'], ['spent', 'Dépensé']], st.advBy))}
  <section class="adm-card"><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th>Marque</th><th>Pays</th><th>Offre</th><th class="num">Annonces</th><th class="num">Affichages</th><th class="num">Clics</th><th class="num">Taux de clic</th><th class="num">Dépensé</th><th>Statut</th></tr></thead><tbody>
  ${rows.map((a) => `<tr class="adm-row" tabindex="0" role="link" data-open="a/${esc(a.id)}" aria-label="Ouvrir la fiche de ${esc(a.brand)}"><td><div class="adm-who">${avatar(a.logo_url, a.brand, true)}<b>${esc(a.brand)}</b></div></td><td>${esc(country(a.country))}</td><td>${esc(OFFER[a.offer] || a.offer)}</td><td class="num">${fmt(a.active_ads)}</td><td class="num"><b>${fmt(a.views)}</b></td><td class="num">${fmt(a.clicks)}</td><td class="num">${a.views ? (a.clicks / a.views * 100).toFixed(2).replace('.', ',') + ' %' : '—'}</td><td class="num">${a.spent_xof ? F(a.spent_xof) : '—'}</td><td>${badge(a.status)}</td></tr>`).join('')}</tbody></table></div>
  ${rows.length ? '' : '<p class="adm-empty">Aucun annonceur.</p>'}</section></div>`;
}
async function advPage(id) {
  const f = (await apiGet(`ads/advertisers/${encodeURIComponent(id)}?period=${st.evoP}`)).data; const a = f.advertiser, k = f.kpis, e = f.evolution, t = f.targeting;
  return `<div class="adm-page"><button class="adm-back" type="button" data-back>← Retour aux annonceurs</button>
  <section class="adm-card"><div class="adm-prof">${avatar(a.logo_url, a.brand, true)}<div style="flex:1;min-width:200px"><h2>${esc(a.brand)} ${badge(a.status)}</h2><div class="adm-meta"><span>Pays : <b>${esc(country(a.country))}</b></span><span>Ville : <b>${esc(a.city || '—')}</b></span><span>Offre : <b>${esc(OFFER[a.offer] || a.offer)}</b></span><span>Secteur : <b>${esc(a.sector || '—')}</b></span><span>Membre depuis : <b>${fdate(a.created_at)}</b></span></div></div>${lock}</div></section>
  <section class="adm-kpis">${kpi('Annonces actives', fmt(k.active_ads))}${kpi('Affichages', short(k.views))}${kpi('Clics', short(k.clicks), '<div class="s">jamais montrés au public</div>')}${kpi('Taux de clic', k.views ? (k.clicks / k.views * 100).toFixed(2).replace('.', ',') + ' %' : '—')}${k.spent_xof ? kpi('Dépensé', F(k.spent_xof)) : ''}</section>
  <section class="adm-grid2"><div class="adm-card"><div class="adm-bar"><h3>Évolution</h3>${seg('evop', [['30', '30 j'], ['90', '90 j'], ['12', '12 mois']], st.evoP)}</div><div class="adm-legend"><span><i style="background:var(--c1)"></i>Affichages</span><span><i style="background:var(--c3)"></i>Clics</span></div>${lineChart(e.labels, e.unit, [{ name: 'Affichages', color: 'var(--c1)', data: e.shows, area: true }, { name: 'Clics', color: 'var(--c3)', data: e.clicks }])}</div>
    <div class="adm-card"><h3>Respect du ciblage</h3><p class="sub">Part des affichages hors des pays visés (30 jours). Limite : ${t.max_pct} %.</p><div class="adm-meter" role="img" aria-label="${t.out_of_target_pct} % hors pays visés"><i style="width:${Math.min(100, t.out_of_target_pct / t.max_pct * 100)}%"></i></div>
      <p class="sub" style="margin-top:6px"><b style="color:var(--ink)">${String(t.out_of_target_pct).replace('.', ',')} %</b> hors pays visés (maximum ${t.max_pct} %)</p></div></section>
  <section class="adm-card"><h3>Ses annonces</h3><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th>Titre</th><th>Format</th><th>Statut</th><th>Pays visés</th><th class="num">Jours restants</th><th class="num">Affichages</th><th class="num">Clics</th></tr></thead><tbody>${f.ads.map((x) => `<tr><td><b>${esc(x.title)}</b></td><td>${x.format === 'video' ? 'Vidéo' : 'Carte'}${x.network ? ' · Réseau' : ''}</td><td>${badge(x.status)}</td><td>${esc((x.countries || []).map(country).join(', ') || 'Tous')}</td><td class="num">${x.days_left == null ? '—' : fmt(x.days_left)}</td><td class="num">${fmt(x.views)}</td><td class="num">${fmt(x.clicks)}</td></tr>`).join('')}</tbody></table></div>${f.ads.length ? '' : '<p class="adm-empty">Aucune annonce.</p>'}</section></div>`;
}

/* ——— 4. Diffuseurs ——— */
async function pubListPage() {
  const rows = (await apiGet(`ads/publishers?by=${st.pubBy}`)).data;
  return `<div class="adm-page">${head('Diffuseurs', 'Les sites et applications qui affichent des annonces, et ce qu’ils gagnent.', seg('pubby', [['shows', 'Affichages'], ['gains', 'Gains']], st.pubBy))}
  <section class="adm-card"><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th>Diffuseur</th><th>Type</th><th class="num">Sites et apps</th><th class="num">Affichages valides (30 j)</th><th class="num">Gains (30 j)</th><th class="num">Retenu</th><th class="num">Disponible</th><th>Statut</th></tr></thead><tbody>
  ${rows.map((d) => `<tr class="adm-row" tabindex="0" role="link" data-open="d/${esc(d.id)}" aria-label="Ouvrir la fiche de ${esc(d.name)}"><td><div class="adm-who">${avatar('', d.name, true)}<b>${esc(d.name)}</b></div></td><td>${d.kind === 'company' ? 'Entreprise' : 'Personne'}</td><td class="num">${fmt(d.properties)}</td><td class="num"><b>${fmt(d.shows_30d)}</b></td><td class="num">${F(d.gains_fcfa)}</td><td class="num">${F(d.held_fcfa)}</td><td class="num">${F(d.available_fcfa)}</td><td>${badge(d.status)}</td></tr>`).join('')}</tbody></table></div>
  ${rows.length ? '' : '<p class="adm-empty">Aucun diffuseur.</p>'}</section></div>`;
}
async function pubPage(id) {
  const f = (await apiGet(`ads/publishers/${encodeURIComponent(id)}?period=${st.evoP}`)).data; const p = f.publisher, k = f.kpis, e = f.evolution;
  return `<div class="adm-page"><button class="adm-back" type="button" data-back>← Retour aux diffuseurs</button>
  <section class="adm-card"><div class="adm-prof">${avatar('', p.name, true)}<div style="flex:1;min-width:200px"><h2>${esc(p.name)} ${badge(p.status)}</h2><div class="adm-meta"><span>Type : <b>${p.kind === 'company' ? 'Entreprise' : 'Personne'}</b></span><span>Règles acceptées : <b>version ${esc(p.rules_version || '—')}</b></span><span>Retrait minimum : <b>${F(p.min_payout_fcfa)}</b></span><span>Inscrit le : <b>${fdate(p.created_at)}</b></span></div></div>${lock}</div></section>
  <section class="adm-kpis">${kpi('Affichages valides (30 j)', short(k.shows_30d))}${kpi('Gains reçus (30 j)', F(k.gains_30d_fcfa), '<div class="s">sa part</div>')}${kpi('Retenue en cours', F(k.held_fcfa), '<div class="s">libérée après 30 jours</div>')}${kpi('Disponible au retrait', F(k.available_fcfa), `<div class="s">${k.available_fcfa >= p.min_payout_fcfa ? 'au-dessus du minimum' : 'sous le minimum'}</div>`)}</section>
  <section class="adm-grid2"><div class="adm-card"><div class="adm-bar"><h3>Évolution</h3>${seg('evop', [['30', '30 j'], ['90', '90 j'], ['12', '12 mois']], st.evoP)}</div><div class="adm-legend"><span><i style="background:var(--c1)"></i>Affichages valides</span><span><i style="background:var(--c3)"></i>Gains (F)</span></div>${lineChart(e.labels, e.unit, [{ name: 'Affichages valides', color: 'var(--c1)', data: e.shows, area: true }, { name: 'Gains (F)', color: 'var(--c3)', data: e.gains_fcfa }])}</div>
    <div class="adm-card"><h3>Sites et applications</h3><p class="sub">Preuve de propriété vérifiée ou non.</p><div class="adm-list">${f.properties.length ? f.properties.map((x) => `<div class="it"><span>${esc(x.name)}<br><small style="color:var(--muted)">${x.kind === 'app' ? 'Application' : 'Site'} · ${badge(x.status)}</small></span><span class="${x.verified ? 'up' : ''}">${x.verified ? '✓ vérifié' : 'non vérifié'}</span></div>`).join('') : '<p class="adm-empty">Aucun site.</p>'}</div>
      <h3 style="margin-top:14px">Catégories acceptées</h3><div class="adm-chips">${f.accepted_categories.length ? f.accepted_categories.map((c) => `<span>${esc(c)}</span>`).join('') : '<span>Toutes</span>'}</div></div></section>
  <section class="adm-card"><h3>Dernières demandes de retrait</h3><p class="sub">Historique en lecture seule : les décisions de paiement se prennent dans la file de retraits.</p><div class="adm-list">${f.payouts.length ? f.payouts.map((x) => `<div class="it"><span>Retrait du ${fdate(x.created_at)}<br><small style="color:var(--muted)">${esc(x.operator)}</small></span><span>${F(x.amount_fcfa)} · ${esc((STATUS[x.status] || [x.status])[0])}</span></div>`).join('') : '<p class="adm-empty">Aucune demande.</p>'}</div></section></div>`;
}

/* ——— 5. Activité : publications et montages ——— */
const dur = (s) => { s = Math.round(Number(s) || 0); if (s < 60) return s + ' s'; const m = Math.floor(s / 60); if (m < 60) return m + ' min'; return Math.floor(m / 60) + ' h ' + String(m % 60).padStart(2, '0'); };
const dayIso = (k) => (/^\d{8}$/.test(String(k)) ? `${k.slice(0, 4)}-${k.slice(4, 6)}-${k.slice(6, 8)}` : String(k));
const hbars = (rows, fmtv) => { const mx = Math.max(1, ...rows.map((r) => r[1])); return `<div class="adm-hb">${rows.map(([l, v]) => `<div class="r"><span>${esc(l)}</span><div class="t"><i style="width:${Math.max(3, v / mx * 100)}%"></i></div><span class="n">${(fmtv || fmt)(v)}</span></div>`).join('') || '<p class="adm-empty">Rien pour le moment.</p>'}</div>`; };
const windowKpis = (w, what) => `<section class="adm-kpis">${kpi('Aujourd’hui', fmt(w.today), `<div class="s">${what}</div>`)}${kpi('Hier', fmt(w.yesterday))}${kpi('3 jours', fmt(w.d3), '<div class="s">aujourd’hui compris</div>')}${kpi('7 jours', fmt(w.d7))}${kpi('30 jours', fmt(w.d30))}</section>`;
const KIND = { video: 'Vidéo', image: 'Image', text: 'Texte', audio: 'Audio', link: 'Lien', youtube: 'YouTube' };

async function actPage() {
  const a = (await apiGet(`activity?period=${st.period}`)).data; const p = a.posts, m = a.montages, u = a.unit, uu = u === 'month' ? 'mois' : 'jour';
  return `<div class="adm-page">${head('Activité', 'Ce que les gens publient et créent dans l’application.', periodSeg())}
  <div class="adm-sec"><i></i><h3 style="font-size:20px">Publications</h3></div>${windowKpis(p.windows, 'publications')}
  <section class="adm-grid2"><div class="adm-card"><h3>Publications par ${uu}</h3><p class="sub">Ligne pointillée : moyenne sur 7 ${uu}s.</p>${barChart(a.labels, u, p.series, avgN(p.series, 7), 'var(--c1)', 'Publications')}</div>
    <div class="adm-card"><h3>Par type de média</h3><p class="sub">Sur la période choisie : ${fmt(p.total)} publications.</p>${hbars(Object.entries(p.by_kind).map(([k, v]) => [KIND[k] || k, v]))}</div></section>
  <div class="adm-sec"><i style="background:var(--yellow)"></i><h3 style="font-size:20px">Montages du Studio</h3></div>${windowKpis(m.windows, 'montages publiés')}
  <section class="adm-grid2"><div class="adm-card"><h3>Montages publiés par ${uu}</h3><p class="sub">Publications faites avec un modèle du Studio.</p>${barChart(a.labels, u, m.series, avgN(m.series, 7), 'var(--c3)', 'Montages')}</div>
    <div class="adm-card"><h3>Modèles les plus utilisés</h3><p class="sub">Sur la période choisie.</p>${hbars(m.top_templates.map((t) => [t.code, t.posts]))}</div></section>
  <section class="adm-card"><h3>Autour des modèles</h3><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th></th><th class="num">Aujourd’hui</th><th class="num">Hier</th><th class="num">3 jours</th><th class="num">7 jours</th><th class="num">30 jours</th></tr></thead><tbody>
    ${[['« Essayer ce modèle » touché', m.template_tries], ['Modèles repris par quelqu’un d’autre', m.template_uses], ['Publications téléchargées', m.downloads]].map(([l, w]) => `<tr><td>${esc(l)}</td><td class="num">${fmt(w.today)}</td><td class="num">${fmt(w.yesterday)}</td><td class="num">${fmt(w.d3)}</td><td class="num">${fmt(w.d7)}</td><td class="num">${fmt(w.d30)}</td></tr>`).join('')}</tbody></table></div>
    <p class="sub" style="margin:10px 0 0">${esc(m.note)}.</p></section></div>`;
}

/* ——— 6. Argent : ce qu'on devra payer aux créateurs, et les commissions de la plateforme ——— */
const SRC = { like: 'J’aime', gift: 'Cadeaux', subscription: 'Abonnements', ads: 'Annonces', etude: 'Étude', contes: 'Contes', quiz: 'Quiz', sticker: 'Stickers', live: 'Lives', coin_sale: 'Ventes de pièces', paid_content: 'Contenus payants', share: 'Partage' };
async function moneyPage() {
  const pay = (await apiGet('payables')).data;   // sans le droit « argent », la page l'indique
  const v = pay.views_to_pay, c = pay.cashed, w = pay.withdrawals_pending, pb = pay.publishers;
  const labelsFor = await apiGet(`overview?period=${st.period}`).then((r) => r.data.labels).catch(() => []);
  const from = labelsFor.length ? (labelsFor[0].length === 7 ? labelsFor[0] + '-01' : labelsFor[0]) : '';
  let com = null; try { com = (await apiGet(`@commissions${from ? `?from=${from}&to=${new Date().toISOString().slice(0, 10)}` : ''}`)).data; } catch (e) { if (e.code === 'network') throw e; }
  let html = `<div class="adm-page">${head('Argent', 'Ce que la plateforme devra payer, et ce qu’elle gagne. Réservé à l’équipe d’argent.', periodSeg())}
  <div class="adm-sec"><i></i><h3 style="font-size:20px">À payer aux créateurs</h3></div>
  <section class="adm-kpis">
    ${kpi('Vues à encaisser', short(v.views), `<div class="s">chez ${fmt(v.creators)} créateurs</div>`)}
    ${kpi('Valeur à payer', F(v.xof), `<div class="s">si tous encaissaient (minimum ${F(v.min_cash_xof)} chacun)</div>`)}
    ${kpi('Peuvent encaisser maintenant', fmt(v.cashable_creators), `<div class="s">au-dessus du minimum</div>`)}
    ${kpi('Encaissé', F(c.d7_xof), `<div class="s">7 jours · aujourd’hui ${F(c.today_xof)} · 30 jours ${F(c.d30_xof)}</div>`)}
    ${kpi('Retraits demandés', F(w.xof), `<div class="s">${fmt(w.count)} demande${w.count > 1 ? 's' : ''} en attente</div>`)}
    ${kpi('Diffuseurs à payer', F(pb.available_fcfa), `<div class="s">${fmt(pb.payouts_requested.count)} demande${pb.payouts_requested.count > 1 ? 's' : ''} · retenue ${F(pb.held_fcfa)}</div>`)}
  </section>
  <section class="adm-grid2"><div class="adm-card"><h3>Créateurs qui ont le plus à encaisser</h3><p class="sub">Touchez une ligne pour ouvrir la fiche.</p><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th>Créateur</th><th class="num">Vues</th><th class="num">Valeur</th></tr></thead><tbody>
    ${pay.top_creators.map((t) => `<tr class="adm-row" tabindex="0" role="link" data-open="u/${esc(t.id)}"><td><div class="adm-who">${avatar(t.avatar_url, t.username)}<b>@${esc(t.username)}</b></div></td><td class="num">${fmt(t.views)}</td><td class="num"><b>${F(t.xof)}</b></td></tr>`).join('')}</tbody></table></div>${pay.top_creators.length ? '' : '<p class="adm-empty">Aucune vue à encaisser.</p>'}</div>
    <div class="adm-card"><h3>Par palier de créateur</h3><p class="sub">Plus le palier est haut, plus la vue vaut (1 F au maximum).</p><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th>Palier</th><th class="num">Créateurs</th><th class="num">Valeur</th></tr></thead><tbody>
    ${pay.tiers.map((t) => `<tr><td>${esc(t.tier)}</td><td class="num">${fmt(t.creators)}</td><td class="num">${F(t.xof)}</td></tr>`).join('')}</tbody></table></div></div></section>`;
  if (com) {
    const days = com.coins_by_day, labels = days.map((d) => String(d.day).slice(0, 10)); const dep = com.deposits, pc = com.paid_contents;
    html += `<div class="adm-sec"><i style="background:var(--yellow)"></i><h3 style="font-size:20px">Commissions de la plateforme</h3></div>
    <div class="adm-note">Ces chiffres ne sont jamais montrés aux utilisateurs. Période : du ${esc(fdate(com.from))} au ${esc(fdate(com.to))}.</div>
    <section class="adm-kpis">${kpi('Gains en pièces', fmt(com.coins_total), '<div class="s">toutes sources</div>')}${kpi('Dépôts Mobile Money', fmt(dep.count), `<div class="s">payés ${F(dep.paid_xof)}</div>`)}${kpi('Gain sur les dépôts', F(dep.gain_xof), `<div class="s">frais ${F(dep.fee_xof)} · fournisseur ${F(dep.provider_fee_xof)}</div>`)}${kpi('Contenus payants', fmt(pc.count), `<div class="s">vendus ${F(pc.paid_xof)} · plateforme ${F(pc.platform_xof)}</div>`)}</section>
    <section class="adm-grid2"><div class="adm-card"><h3>Gains en pièces par jour</h3>${labels.length ? lineChart(labels, 'day', [{ name: 'Pièces', color: 'var(--c1)', data: days.map((d) => d.coins), area: true }]) : '<p class="adm-empty">Aucun gain sur la période.</p>'}</div>
      <div class="adm-card"><h3>Par source</h3><p class="sub">D’où viennent les gains en pièces.</p>${hbars(com.coins_by_source.map((s) => [SRC[s.source] || s.source, s.coins]))}</div></section>
    <section class="adm-grid2"><div class="adm-card"><h3>Ventes de pièces</h3><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th>Devise</th><th class="num">Ventes</th><th class="num">Pièces</th><th class="num">Payé</th><th class="num">Net estimé</th></tr></thead><tbody>
      ${com.coin_sales.map((s) => `<tr><td>${esc(s.currency)}</td><td class="num">${fmt(s.sales)}</td><td class="num">${fmt(s.coins)}</td><td class="num">${fmt(s.amount)}</td><td class="num">${fmt(s.net_estimate)}</td></tr>`).join('')}</tbody></table></div>${com.coin_sales.length ? '' : '<p class="adm-empty">Aucune vente.</p>'}</div>
      <div class="adm-card"><h3>Dépôts par opérateur</h3>${hbars(com.deposits_by_operator.map((o) => [o.operator || '—', o.gain_xof]), F)}</div></section>`;
  }
  return html + '</div>';
}

/* ——— 7. Travail : page Travail et missions ——— */
async function workPage() {
  const r = (await apiGet(`@work/stats?days=${st.wdays}`)).data, t = r.totals, ac = r.actions, ad = r.ads, pg = r.pages;
  const labels = r.daily.map((d) => d.day);
  const PGN = { work: 'Page Travail', missions: 'Page Missions' };
  return `<div class="adm-page">${head('Travail', 'Les visites de la page Travail et des missions, et les pubs regardées.', seg('wdays', [['7', '7 jours'], ['30', '30 jours'], ['90', '90 jours']], st.wdays))}
  <section class="adm-kpis">${kpi('Visiteurs', fmt(t.visitors), `<div class="s">${fmt(t.returningVisitors)} reviennent</div>`)}${kpi('Visites', fmt(t.sessions), `<div class="s">${dur(t.avgSecondsPerSession)} en moyenne</div>`)}${kpi('Temps passé', dur(t.seconds), `<div class="s">${dur(t.avgSecondsPerVisitor)} par visiteur</div>`)}
    ${kpi('Pubs regardées', fmt(ad.total), `<div class="s">${String(ad.perVisitor).replace('.', ',')} par visiteur${ad.estimatedUsd != null ? ' · ≈ ' + String(ad.estimatedUsd).replace('.', ',') + ' $' : ''}</div>`)}</section>
  <section class="adm-card"><h3>Visiteurs et visites par jour</h3><div class="adm-legend"><span><i style="background:var(--c1)"></i>Visiteurs</span><span><i style="background:var(--c2)"></i>Visites</span><span><i style="background:var(--c3)"></i>Pubs</span></div>
    ${lineChart(labels, 'day', [{ name: 'Visiteurs', color: 'var(--c1)', data: r.daily.map((d) => d.visitors), area: true }, { name: 'Visites', color: 'var(--c2)', data: r.daily.map((d) => d.sessions) }, { name: 'Pubs', color: 'var(--c3)', data: r.daily.map((d) => d.ads) }])}</section>
  <section class="adm-grid2"><div class="adm-card"><h3>Par page</h3><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th>Page</th><th class="num">Visiteurs</th><th class="num">Visites</th><th class="num">Temps moyen</th></tr></thead><tbody>
    ${Object.entries(pg).map(([k, v]) => `<tr><td>${esc(PGN[k] || k)}</td><td class="num">${fmt(v.visitors)}</td><td class="num">${fmt(v.sessions)}</td><td class="num">${dur(v.avgSeconds)}</td></tr>`).join('')}</tbody></table></div></div>
    <div class="adm-card"><h3>Ce que les gens touchent</h3><p class="sub">Boutons touchés depuis la page Travail.</p>${hbars([['Missions', ac.missions.taps], ['Tâches', ac.tasks.taps], ['Partenaires', ac.partner.taps]])}
      <p class="sub" style="margin-top:8px">${fmt(ac.missions.people)} personnes sur les missions · ${fmt(ac.tasks.people)} sur les tâches · ${fmt(ac.partner.people)} sur les partenaires.</p></div></section>
  <section class="adm-card"><h3>Les plus actifs</h3><div class="adm-tblw"><table class="adm-tbl"><thead><tr><th>Utilisateur</th><th class="num">Visites</th><th class="num">Temps</th><th class="num">Touches</th><th class="num">Pubs</th></tr></thead><tbody>
    ${r.topUsers.map((u) => `<tr class="adm-row" tabindex="0" role="link" data-open="u/${esc(u.id)}"><td><b>@${esc(u.username)}</b></td><td class="num">${fmt(u.sessions)}</td><td class="num">${dur(u.seconds)}</td><td class="num">${fmt(u.taps)}</td><td class="num">${fmt(u.ads)}</td></tr>`).join('')}</tbody></table></div>${r.topUsers.length ? '' : '<p class="adm-empty">Aucune visite sur la période.</p>'}</section></div>`;
}

/* ——— 8. Quiz et Étude ——— */
async function learnPage() {
  let quiz = null, etude = null, denied = [];
  try { quiz = (await apiGet('@quiz/stats?days=14')).data; } catch (e) { if (e.code === 'network') throw e; denied.push('le quiz'); }
  try { etude = (await apiGet('@etude/overview')).data; } catch (e) { if (e.code === 'network') throw e; denied.push('l’étude'); }
  let html = `<div class="adm-page">${head('Quiz et Étude', 'Ceux qui jouent, ceux qui apprennent, et ce que ça rapporte.')}`;
  if (denied.length === 2) throw Object.assign(new Error('Cette partie est réservée à l’équipe du quiz et de l’étude. Ton compte n’a pas ce droit.'), { code: 'denied' });
  if (denied.length) html += `<div class="adm-note">Ton compte n’a pas accès à ${esc(denied.join(' et '))} : cette partie est masquée.</div>`;
  if (quiz) {
    const o = quiz.overview, rt = quiz.retention, labels = quiz.days.map((d) => dayIso(d.day)); const REG = { af: 'Afrique', eu: 'Europe', as: 'Asie', am: 'Amériques', mx: 'Autres' };
    const BK = ['Niveaux 1 à 5', '6 à 20', '21 à 50', '51 à 100', '101 à 200', 'Terminé'];
    html += `<div class="adm-sec"><i></i><h3 style="font-size:20px">Quiz</h3></div>
    <section class="adm-kpis">${kpi('Joueurs', fmt(o.total), `<div class="s">${fmt(o.played_today)} aujourd’hui</div>`)}${kpi('Défi du jour fini', fmt(o.daily_done), `<div class="s">${fmt(o.chal_players)} jouent le défi</div>`)}${kpi('Reviennent le lendemain', rt.yesterday ? Math.round(rt.back / rt.yesterday * 100) + ' %' : '—', `<div class="s">${fmt(rt.back)} sur ${fmt(rt.yesterday)} joueurs d’hier</div>`)}${kpi('Séries de 3 jours', fmt(o.streak3), `<div class="s">${fmt(o.chal_wins)} victoires au défi</div>`)}</section>
    <section class="adm-grid2"><div class="adm-card"><h3>Joueurs et niveaux par jour</h3><div class="adm-legend"><span><i style="background:var(--c1)"></i>Joueurs</span><span><i style="background:var(--c2)"></i>Niveaux joués</span><span><i style="background:var(--c3)"></i>Réussis</span></div>
      ${lineChart(labels, 'day', [{ name: 'Joueurs', color: 'var(--c1)', data: quiz.days.map((d) => d.players), area: true }, { name: 'Niveaux joués', color: 'var(--c2)', data: quiz.days.map((d) => d.levels) }, { name: 'Réussis', color: 'var(--c3)', data: quiz.days.map((d) => d.passed) }])}</div>
      <div class="adm-card"><h3>Où ils en sont</h3>${hbars(o.level_buckets.map((n, i) => [BK[i], n]))}<h3 style="margin-top:16px">Par région</h3>${hbars(Object.entries(o.by_region).map(([k, n]) => [REG[k] || k, n]))}</div></section>`;
  }
  if (etude) {
    const e = etude;
    html += `<div class="adm-sec"><i style="background:var(--yellow)"></i><h3 style="font-size:20px">Étude</h3></div>
    <section class="adm-kpis">${kpi('Apprenants', fmt(e.learners), `<div class="s">${fmt(e.active_today)} aujourd’hui · ${fmt(e.active7)} sur 7 jours</div>`)}${kpi('Réussite aux questions', e.success_rate + ' %', `<div class="s">XP moyen ${fmt(e.avg_xp)}</div>`)}${kpi('Pièces gagnées (7 jours)', fmt(e.coins7), '<div class="s">par la plateforme</div>')}${kpi('Déblocages', fmt(Object.values(e.unlocks).reduce((x, y) => x + y, 0)), `<div class="s">${fmt(e.unlocks.ch)} chapitres · ${fmt(e.unlocks.exam)} examens · ${fmt(e.unlocks.cert)} certificats</div>`)}</section>
    <section class="adm-grid2"><div class="adm-card"><h3>Chapitres les plus terminés</h3>${hbars((e.top_chapters || []).slice(0, 10).map((c) => [c.title, c.n]))}</div>
      <div class="adm-card"><h3>Parcours</h3><div class="adm-list">${(e.tracks || []).map((t) => `<div class="it"><span>${esc(t.title)}<br><small style="color:var(--muted)">${fmt(t.classes)} classes · ${fmt(t.chapters)} chapitres</small></span><span>${fmt((e.started || {})[t.id] || 0)} démarrés</span></div>`).join('') || '<p class="adm-empty">Aucun parcours.</p>'}</div></div></section>
    ${e.truncated ? '<div class="adm-note">Le total est limité aux 10 000 premiers apprenants.</div>' : ''}`;
  }
  return html + '</div>';
}

/* ——— 9. Récompenses ——— */
async function rewPage() {
  const r = (await apiGet(`rewards?period=${st.period}`)).data, u = r.unit, uu = u === 'month' ? 'mois' : 'jour';
  const OFFER = { premium: 'Premium', adfree: 'Sans pub', photos: 'Photos en plus', coins: 'Pièces' };
  return `<div class="adm-page">${head('Récompenses', 'Les pubs regardées contre des avantages, et ce qui a été obtenu.', periodSeg())}
  <section class="adm-kpis">${kpi('Pubs échangées', fmt(r.ads_exchanged.total), '<div class="s">sur la période</div>')}${kpi('Avantages obtenus', fmt(r.claims.total), '<div class="s">sur la période</div>')}${kpi('Joueurs aujourd’hui', fmt(r.today.players), `<div class="s">${fmt(r.today.ads_watched)} pubs regardées</div>`)}${kpi('Premium en cours', fmt(r.active.premium), `<div class="s">${fmt(r.active.ad_free)} sans pub</div>`)}</section>
  <section class="adm-grid2"><div class="adm-card"><h3>Pubs échangées par ${uu}</h3>${barChart(r.labels, u, r.ads_exchanged.series, avgN(r.ads_exchanged.series, 7), 'var(--c1)', 'Pubs échangées')}</div>
    <div class="adm-card"><h3>Avantages obtenus</h3><p class="sub">Par offre, sur la période.</p>${hbars(r.claims.by_offer.map((o) => [OFFER[o.offer] || o.offer, o.claims]))}</div></section>
  <section class="adm-card"><h3>Avantages obtenus par ${uu}</h3>${barChart(r.labels, u, r.claims.series, avgN(r.claims.series, 7), 'var(--c3)', 'Avantages')}</section></div>`;
}

/* ——— Événements ——— */
/* ——— Publications : liste filtrée en pages, chiffres, détail, personnes (commentaires, j'aime, partages, vues) et décisions ———
   Toutes les heures sont en UTC (heure de Lomé). Les décisions reprennent les points de modération existants (droit « modération ») ; l'argent demande le droit « finance » ; les personnes, le droit « fiches ». */
const PB_KIND = { video: 'Vidéo', image: 'Image', audio: 'Audio', text: 'Texte', link: 'Lien' };
const PB_CAT = { LOOKS: 'Looks', ACTUALITES: 'Actualités', SPORT: 'Sport', EVENEMENT: 'Événement', OFFRES: 'Offres', GAMER: 'Games story', DEFI: 'Défi' };
const PB_STATE = { valid: ['Publié', 'ok'], reported: ['Signalé', 'bad'], hidden: ['Retiré', ''] };
const PB_WAVE = { testing: ['En test', 'info'], promising: ['Prometteuse', 'wait'], viral: ['Viral', 'ok'], stopped: ['Arrêtée', ''] };
const PB_AUTH = { ok: 'Contrôlée', review: 'À vérifier', flagged: 'Douteuse' };
const PB_SRC = { captured: 'Filmé ou enregistré avec Afrolook', edited: 'Retouché dans le Studio', imported: 'Galerie' };
const PB_REPORT = { standard: 'Signalement', wrong_category: 'Mauvaise catégorie' };
const PB_IC = {
  eye: '<svg viewBox="0 0 24 24"><path d="M12 5C7 5 2.7 8.1 1 12c1.7 3.9 6 7 11 7s9.3-3.1 11-7c-1.7-3.9-6-7-11-7zm0 11.5A4.5 4.5 0 1112 7.5a4.5 4.5 0 010 9zm0-7A2.5 2.5 0 1012 14.5 2.5 2.5 0 0012 9.5z"/></svg>',
  heart: '<svg viewBox="0 0 24 24"><path d="M12 21s-7.5-4.6-9.6-9.2C.8 8.2 3 4.5 6.6 4.5c2 0 3.8 1.1 5.4 3 1.6-1.9 3.4-3 5.4-3 3.6 0 5.8 3.7 4.2 7.3C19.5 16.4 12 21 12 21z"/></svg>',
  chat: '<svg viewBox="0 0 24 24"><path d="M4 4h16a2 2 0 012 2v10a2 2 0 01-2 2H9l-5 4V6a2 2 0 012-2z"/></svg>',
  share: '<svg viewBox="0 0 24 24"><path d="M18 16a3 3 0 00-2.4 1.2L8.9 13.7a3 3 0 000-3.4l6.7-3.5A3 3 0 1015 5a3 3 0 00.1.7L8.4 9.2a3 3 0 100 5.6l6.7 3.5A3 3 0 1018 16z"/></svg>',
  play: '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>',
  mic: '<svg viewBox="0 0 24 24"><path d="M12 14a3 3 0 003-3V5a3 3 0 00-6 0v6a3 3 0 003 3zm5-3a5 5 0 01-10 0H5a7 7 0 006 6.9V21h2v-3.1A7 7 0 0019 11z"/></svg>',
  img: '<svg viewBox="0 0 24 24"><path d="M21 19V5a2 2 0 00-2-2H5a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2zM8.5 13.5l2.5 3 3.5-4.5 4.5 6H5z"/></svg>',
  link: '<svg viewBox="0 0 24 24"><path d="M3.9 12a3.1 3.1 0 013.1-3.1h4V7H7a5 5 0 000 10h4v-1.9H7A3.1 3.1 0 013.9 12zM8 13h8v-2H8zm9-6h-4v1.9h4a3.1 3.1 0 010 6.2h-4V17h4a5 5 0 000-10z"/></svg>',
  txt: '<svg viewBox="0 0 24 24"><path d="M5 4v3h5.5v12h3V7H19V4z"/></svg>',
};
const pbp = (n) => String(n).padStart(2, '0');
const pbUtc = (iso) => { if (!iso) return '—'; const d = new Date(iso); return isNaN(d) ? '—' : `${pbp(d.getUTCDate())}/${pbp(d.getUTCMonth() + 1)} ${pbp(d.getUTCHours())}:${pbp(d.getUTCMinutes())}`; };
const pbUrl = (u) => (u && /^https:\/\//.test(u) ? u : '');
const pbDur = (s) => (s == null ? '' : `${Math.floor(s / 60)}:${pbp(s % 60)}`);
const pbCat = (c) => PB_CAT[c] || c || '—';
const pbCc = (a) => (a || []).map((c) => (c === 'ALL' ? 'Monde' : c)).join(' ');
st.px = { range: '0', custom: false, d1: '', t1: '00:00', d2: '', t2: '23:59', author: '', media: '', category: '', status: '', source: '', wave: '', auth: '', sort: 'new', q: '', page: 1, per: 20 };
let pbCan = { moderate: false, people: false, money: false };
let pbSeq = 0;
let pbTimer = null;

const pbSpan = () => { const p = st.px, q = new URLSearchParams(); if (p.custom && (p.d1 || p.d2)) { if (p.d1) q.set('from', `${p.d1}T${p.t1 || '00:00'}`); if (p.d2) q.set('to', `${p.d2}T${p.t2 || '23:59'}`); } else q.set('range', p.range); return q; };
const pbQuery = () => { const p = st.px, q = pbSpan(); ['author', 'media', 'category', 'status', 'source', 'wave', 'auth', 'q', 'sort'].forEach((k) => { if (p[k]) q.set(k, p[k]); }); q.set('page', p.page); q.set('per_page', p.per); return q.toString(); };

async function apiSend(method, path, body) {
  let r;
  try { r = await fetch(`${API_ADMIN}/${path}`, { method, headers: { Accept: 'application/json', 'Content-Type': 'application/json', Authorization: 'Bearer ' + (await auth.currentUser.getIdToken()) }, body: JSON.stringify(body || {}) }); }
  catch { throw Object.assign(new Error('Impossible de joindre le serveur. Vérifie ta connexion puis réessaie.'), { code: 'network' }); }
  const j = await r.json().catch(() => ({}));
  if (r.ok) return j;
  if (r.status === 404 || r.status === 401 || r.status === 403) throw Object.assign(new Error('Ton compte n’a pas le droit de prendre cette décision.'), { code: 'denied' });
  throw Object.assign(new Error((j && (j.message || (j.error && j.error.message))) || 'Le serveur a répondu avec une erreur. Réessaie dans un instant.'), { code: 'server' });
}

async function postsPage() {
  setTimeout(pbInit, 0);
  return `<div class="adm-page">${head('Publications', 'Tout ce que les gens publient, avec la diffusion et ce qu’il faut pour modérer. Heures de Lomé (UTC).')}
  <div class="pb-kpis" id="pb-k1" role="group" aria-label="Période : un clic choisit la période"></div>
  <div class="pb-kpis k2" id="pb-k2" role="group" aria-label="Ce qui demande une décision : un clic filtre la liste"></div>
  <div class="adm-card pb-filters" id="pb-f"></div>
  <div id="pb-creator"></div>
  <div class="pb-res" id="pb-res"></div>
  <div class="pb-list" id="pb-list" aria-live="polite"><p class="adm-empty">Chargement…</p></div>
  <nav class="pb-pager" id="pb-pager" aria-label="Pages"></nav></div>
  <div class="pb-shade" id="pb-shade" hidden></div><aside class="pb-drawer" id="pb-drawer" hidden aria-label="Détails de la publication"></aside>`;
}

function pbFilters() {
  const p = st.px, o = (v, l, cur) => `<option value="${esc(v)}"${cur === v ? ' selected' : ''}>${esc(l)}</option>`;
  const sel = (id, label, cur, opts) => `<div class="pb-fld"><label for="${id}">${esc(label)}</label><select id="${id}">${opts.map(([v, l]) => o(v, l, cur)).join('')}</select></div>`;
  $('#pb-f').innerHTML = `<div class="pb-grid">
    <div class="pb-fld wide"><label for="pb-author">Créateur (pseudo, e-mail ou numéro)</label><input id="pb-author" type="search" value="${esc(p.author)}" placeholder="ex. fatou_abj" autocomplete="off"></div>
    ${sel('pb-media', 'Média', p.media, [['', 'Tous'], ...Object.entries(PB_KIND)])}
    ${sel('pb-category', 'Type de publication', p.category, [['', 'Tous'], ...Object.entries(PB_CAT)])}
    ${sel('pb-auth', 'Authenticité', p.auth, [['', 'Toutes'], ['ok', 'Contrôlée'], ['review', 'À vérifier'], ['flagged', 'Douteuse']])}
    ${sel('pb-status', 'Statut', p.status, [['', 'Tous'], ['valid', 'Publié'], ['reported', 'Signalé'], ['hidden', 'Retiré']])}
    ${sel('pb-source', 'Origine du média', p.source, [['', 'Toutes'], ['captured', 'Filmé ou enregistré'], ['edited', 'Retouché dans le Studio'], ['imported', 'Galerie'], ['none', 'Sans origine']])}
    ${sel('pb-wave', 'Diffusion', p.wave, [['', 'Toutes'], ['testing', 'En test'], ['promising', 'Prometteuse'], ['viral', 'Viral'], ['none', 'Aucune vague']])}
    ${sel('pb-sort', 'Trier par', p.sort, [['new', 'Plus récentes'], ['views', 'Plus vues'], ['rep', 'Plus signalées'], ['gain', 'Plus de vues payantes']])}
  </div>
  <div class="pb-range"${p.custom ? '' : ' hidden'} id="pb-range">
    <div class="pb-fld"><label for="pb-d1">Du</label><input id="pb-d1" type="date" value="${esc(p.d1)}"></div><div class="pb-fld"><label for="pb-t1">à</label><input id="pb-t1" type="time" value="${esc(p.t1)}"></div>
    <div class="pb-fld"><label for="pb-d2">Au</label><input id="pb-d2" type="date" value="${esc(p.d2)}"></div><div class="pb-fld"><label for="pb-t2">à</label><input id="pb-t2" type="time" value="${esc(p.t2)}"></div></div>
  <div class="pb-fbar"><span class="adm-note" style="border:0;background:none;padding:0">Recherche aussi par identifiant ou par mot de la description.</span>
    <span class="pb-fbtns"><button class="adm-btn" id="pb-custom" type="button" aria-expanded="${p.custom}">Dates et heures…</button><input id="pb-q" type="search" class="pb-q" value="${esc(p.q)}" placeholder="Mot ou identifiant" aria-label="Mot ou identifiant"><button class="adm-btn" id="pb-reset" type="button">Réinitialiser</button></span></div>`;
}

/** Branche les champs du formulaire de filtres (reconstruit à chaque remise à zéro). */
function pbBindFields() {
  const p = st.px, reload = () => { p.page = 1; pbLoad(); };
  [['pb-media', 'media'], ['pb-category', 'category'], ['pb-auth', 'auth'], ['pb-status', 'status'], ['pb-source', 'source'], ['pb-wave', 'wave'], ['pb-sort', 'sort']].forEach(([id, key]) => { const el = $('#' + id); el.addEventListener('change', () => { p[key] = el.value; reload(); }); });
  [['pb-author', 'author'], ['pb-q', 'q']].forEach(([id, key]) => { const el = $('#' + id); el.addEventListener('input', () => { clearTimeout(pbTimer); pbTimer = setTimeout(() => { p[key] = el.value.trim(); reload(); }, 350); }); });
  [['pb-d1', 'd1'], ['pb-t1', 't1'], ['pb-d2', 'd2'], ['pb-t2', 't2']].forEach(([id, key]) => { $('#' + id).addEventListener('change', () => { p[key] = $('#' + id).value; if (p.d1 || p.d2) { p.custom = true; reload(); } }); });
  $('#pb-custom').addEventListener('click', () => { p.custom = !p.custom; $('#pb-range').hidden = !p.custom; $('#pb-custom').setAttribute('aria-expanded', String(p.custom)); if (!p.custom || p.d1 || p.d2) reload(); });
  $('#pb-reset').addEventListener('click', () => { Object.assign(p, { range: '0', custom: false, d1: '', t1: '00:00', d2: '', t2: '23:59', author: '', media: '', category: '', status: '', source: '', wave: '', auth: '', sort: 'new', q: '', page: 1 }); pbFilters(); pbBindFields(); pbLoad(); });
}

function pbInit() {
  if (!$('#pb-f')) return;
  const p = st.px, reload = () => { p.page = 1; pbLoad(); };
  pbFilters(); pbBindFields();
  $('#pb-k1').addEventListener('click', (e) => { const b = e.target.closest('[data-pb-range]'); if (!b) return; p.range = b.dataset.pbRange; p.custom = false; $('#pb-range').hidden = true; $('#pb-custom').setAttribute('aria-expanded', 'false'); reload(); });
  $('#pb-k2').addEventListener('click', (e) => {
    const b = e.target.closest('[data-pb-f]'); if (!b) return; const f = b.dataset.pbF, on = b.getAttribute('aria-pressed') === 'true';
    if (f === 'sig') p.status = on ? '' : 'reported'; else if (f === 'ret') p.status = on ? '' : 'hidden'; else if (f === 'ver') p.auth = on ? '' : 'review'; else if (f === 'vir') p.wave = on ? '' : 'viral'; else if (f === 'own') p.source = on ? '' : 'captured';
    pbFilters(); pbBindFields(); reload();
  });
  $('#pb-list').addEventListener('click', pbListClick);
  $('#pb-creator').addEventListener('click', (e) => { if (e.target.closest('[data-pb-clear]')) { p.author = ''; pbFilters(); pbBindFields(); reload(); } });
  $('#pb-pager').addEventListener('click', (e) => { const b = e.target.closest('[data-pb-page]'); if (!b || b.disabled) return; p.page = Number(b.dataset.pbPage); pbLoad(); $('#pb-res').scrollIntoView({ block: 'start' }); });
  $('#pb-shade').addEventListener('click', pbClose);
  pbLoad();
}

async function pbLoad() {
  const my = ++pbSeq, p = st.px;
  const list = $('#pb-list'); if (!list) return;
  list.setAttribute('aria-busy', 'true');
  try {
    const [stats, rows] = await Promise.all([apiGet(`posts/stats?${pbSpan().toString()}`), apiGet(`posts?${pbQuery()}`)]);
    if (my !== pbSeq || !$('#pb-list')) return;
    pbCan = stats.data.can || pbCan;
    pbKpis(stats.data); pbRows(rows);
  } catch (e) {
    if (my !== pbSeq || !$('#pb-list')) return;
    let msg = e.message || 'Chargement impossible.', retry = e.code !== 'denied';
    if (e.code === 'denied') {
      // le serveur répond « introuvable » aussi bien à un compte sans droit qu'à une route pas encore en ligne : si la vue d'ensemble s'ouvre avec le même droit,
      // c'est la mise à jour du serveur qui manque, pas le compte
      try { await apiGet('overview?period=7'); msg = 'Cette partie du tableau de bord n’est pas encore disponible sur le serveur : la mise à jour de l’API doit être déployée. Ton compte a bien le droit.'; retry = true; } catch { /* vraiment sans droit */ }
      if (my !== pbSeq || !$('#pb-list')) return;
    }
    $('#pb-list').innerHTML = `<div class="adm-card"><p class="adm-err">${esc(msg)}</p>${retry ? '<button class="adm-btn" data-retry type="button">Réessayer</button>' : ''}</div>`;
  } finally { const l = $('#pb-list'); if (l) l.removeAttribute('aria-busy'); }
}

function pbKpis(s) {
  const p = st.px, w = s.windows, pr = s.period;
  const period = [['0', 'Aujourd’hui', w.today, 'publications'], ['1', 'Hier', w.yesterday, 'publications'], ['3', '3 jours', w.d3, 'aujourd’hui compris'], ['7', '7 jours', w.d7, 'publications'], ['30', '30 jours', w.d30, 'publications']];
  $('#pb-k1').innerHTML = period.map(([k, l, n, sub]) => `<button class="pb-kpi" type="button" data-pb-range="${k}" aria-pressed="${!p.custom && p.range === k}"><small>${esc(l)}</small><b>${fmt(n)}</b><span>${esc(sub)}</span></button>`).join('');
  const k2 = [['sig', 'Signalées', fmt(pr.reported_posts), `${fmt(pr.reports)} signalement${pr.reports > 1 ? 's' : ''} à traiter`, p.status === 'reported', 'bad'], ['ret', 'Retirées', fmt(pr.hidden), 'par la modération', p.status === 'hidden', ''], ['ver', 'À vérifier', fmt(pr.to_check), 'authenticité', p.auth === 'review', 'warn'],
    ['vir', 'Virales', fmt(pr.viral), 'vague 5 atteinte', p.wave === 'viral', 'good'], ['own', 'Fait sur Afrolook', `${fmt(pr.made_on_afrolook_pct)} %`, `${fmt(pr.made_on_afrolook)} sur ${fmt(pr.total)}`, p.source === 'captured', 'good']];
  $('#pb-k2').innerHTML = k2.map(([k, l, v, sub, on, cls]) => `<button class="pb-kpi ${cls}" type="button" data-pb-f="${k}" aria-pressed="${on}"><small>${esc(l)}</small><b>${v}</b><span>${esc(sub)}</span></button>`).join('');
}

function pbThumb(r) {
  const k = r.media_kind || 'text', img = pbUrl(r.thumbnail_url) || (k === 'image' ? pbUrl(r.media_url) : '');
  const play = k === 'video' || k === 'audio';
  const inner = img ? '' : (k === 'text' ? `<span>${esc((r.description || '').slice(0, 42))}</span>` : (PB_IC[{ video: 'play', audio: 'mic', image: 'img', link: 'link' }[k]] || ''));
  return `<div class="pb-thumb${img ? ' has' : ''}${k === 'text' ? ' txt' : ''}${play ? ' play' : ''}" ${img ? `style="background-image:url('${esc(img)}')"` : `data-k="${esc(k)}"`} ${play ? `data-pb-play="${esc(r.id)}" role="button" tabindex="0" aria-label="Lire"` : ''}>${play ? PB_IC.play : inner}${r.duration_sec ? `<span class="dur">${pbDur(r.duration_sec)}</span>` : ''}</div>`;
}
function pbRow(r) {
  const s = PB_STATE[r.status] || [r.status, ''], w = r.wave ? (PB_WAVE[r.wave.state] || [r.wave.state, '']) : null;
  let side = `<span class="adm-badge ${s[1]}">${esc(s[0])}</span>`;
  if (r.reports) side += `<span class="adm-badge bad">${fmt(r.reports)} signalement${r.reports > 1 ? 's' : ''}</span>`;
  else if (w) side += `<span class="adm-badge ${w[1]}">Vague ${r.wave.level}/5 · ${esc(w[0])}</span>`; else side += '<span class="adm-badge">Sans vague</span>';
  if (r.authenticity !== 'ok' && !r.reports) side += `<span class="adm-badge wait">${esc(PB_AUTH[r.authenticity])}</span>`;
  const a = r.author || {}, c = r.counts;
  return `<article class="pb-post st-${esc(r.status)}" data-pb-open="${esc(r.id)}" tabindex="0" role="button" aria-label="Détails de la publication de ${esc(a.username || '')}">${pbThumb(r)}<div class="pb-main">
    <div class="pb-l1">${avatar(a.avatar_url, a.username)}<b class="pb-who">@${esc(a.username || '—')}</b>${a.is_verified ? '<span class="adm-badge cert">Vérifié</span>' : ''}${r.source === 'captured' || r.source === 'edited' ? '<span class="adm-badge ok">Fait sur Afrolook</span>' : ''}${r.voice_effect ? '<span class="adm-badge wait">Voix modifiée</span>' : ''}${r.reply_to_id ? '<span class="adm-badge cert">Réponse</span>' : ''}<span class="pb-when">${pbUtc(r.created_at)}</span></div>
    <div class="pb-d">${esc(r.description || '(sans texte)')}</div>
    <div class="pb-l3"><span>${esc(PB_KIND[r.media_kind] || 'Texte')} · ${esc(pbCat(r.category))}</span><span>${esc(pbCc(r.countries))}</span><span class="m" title="Vues">${PB_IC.eye}${short(c.views)}</span><span class="m" title="J’aime">${PB_IC.heart}${short(c.likes)}</span><span class="m" title="Commentaires">${PB_IC.chat}${short(c.comments)}</span><span class="m" title="Partages">${PB_IC.share}${short(c.shares)}</span></div></div>
    <div class="pb-side">${side}</div></article>`;
}
function pbRows(res) {
  const p = st.px, m = res.meta, rows = res.data || [];
  $('#pb-res').innerHTML = `<span><b>${fmt(m.total)} publication${m.total > 1 ? 's' : ''}</b> du ${pbUtc(m.from)} au ${pbUtc(m.to)} (heure de Lomé)</span><span class="pb-per">Par page <select id="pb-per" aria-label="Résultats par page">${[10, 20, 50].map((n) => `<option${p.per === n ? ' selected' : ''}>${n}</option>`).join('')}</select></span>`;
  $('#pb-per').addEventListener('change', (e) => { p.per = Number(e.target.value); p.page = 1; pbLoad(); });
  const crt = $('#pb-creator');
  crt.innerHTML = p.author && rows.length ? `<div class="pb-creator"><div><b>Publications de « ${esc(p.author)} »</b><br><span class="sub">${fmt(m.total)} publication${m.total > 1 ? 's' : ''} sur la période choisie</span></div><button class="adm-btn" type="button" data-pb-clear>Effacer</button></div>` : '';
  $('#pb-list').innerHTML = rows.length ? rows.map(pbRow).join('') : '<div class="adm-empty"><b>Aucune publication pour ces filtres.</b><br>Élargis la période ou retire un filtre.</div>';
  const pages = m.pages, cur = m.page; let h = `<button data-pb-page="${cur - 1}" ${cur < 2 ? 'disabled' : ''} aria-label="Page précédente">‹</button>`;
  const show = new Set([1, pages, cur - 1, cur, cur + 1]); let last = 0;
  for (let i = 1; i <= pages; i++) { if (!show.has(i)) continue; if (i - last > 1) h += '<span class="gap">…</span>'; h += `<button data-pb-page="${i}"${i === cur ? ' aria-current="page"' : ''}>${i}</button>`; last = i; }
  h += `<button data-pb-page="${cur + 1}" ${cur >= pages ? 'disabled' : ''} aria-label="Page suivante">›</button>`;
  $('#pb-pager').innerHTML = pages > 1 ? h : '';
}

function pbListClick(e) {
  const th = e.target.closest('[data-pb-play]'); if (th) { pbOpen(th.dataset.pbPlay, true); return; }
  const row = e.target.closest('[data-pb-open]'); if (row) pbOpen(row.dataset.pbOpen);
}
document.addEventListener('keydown', (ev) => {
  if (ev.key === 'Escape' && $('#pb-drawer') && !$('#pb-drawer').hidden) pbClose();
  if ((ev.key === 'Enter' || ev.key === ' ') && ev.target.matches && ev.target.matches('.pb-post')) { ev.preventDefault(); pbOpen(ev.target.dataset.pbOpen); }
});

/* — panneau de détails — */
function pbClose() { const d = $('#pb-drawer'); if (!d) return; d.querySelectorAll('video,audio').forEach((m) => { try { m.pause(); } catch { /* sans effet */ } }); d.hidden = true; $('#pb-shade').hidden = true; document.body.style.overflow = ''; }
function pbMedia(r) {
  const url = pbUrl(r.media_url), k = r.media_kind;
  if (k === 'video' && url) return `<video class="pb-video" controls playsinline preload="metadata" src="${esc(url)}" ${pbUrl(r.thumbnail_url) ? `poster="${esc(r.thumbnail_url)}"` : ''}></video>`;
  if (k === 'audio' && url) return `<div class="pb-audio"><audio controls preload="metadata" src="${esc(url)}"></audio></div>`;
  if (k === 'image' && url) return `<img class="pb-img" src="${esc(url)}" alt="" loading="lazy">`;
  if (k === 'link') return `<div class="pb-textbig">${esc(r.description || '')}</div>`;
  if (k === 'text' || !url) return `<div class="pb-textbig">${esc(r.description || '(sans texte)')}</div>`;
  return '';
}
async function pbOpen(id, autoplay) {
  const d = $('#pb-drawer'); if (!d) return;
  d.hidden = false; $('#pb-shade').hidden = false; document.body.style.overflow = 'hidden'; d.scrollTop = 0;
  d.innerHTML = '<p class="adm-empty">Chargement…</p>';
  let r;
  try { r = (await apiGet(`posts/${encodeURIComponent(id)}`)).data; }
  catch (e) { d.innerHTML = `<div class="pb-top"><b>Publication</b><button class="pb-x" type="button" data-pb-x aria-label="Fermer">×</button></div><p class="adm-err">${esc(e.message)}</p>`; d.querySelector('[data-pb-x]').onclick = pbClose; return; }
  const s = PB_STATE[r.status] || [r.status, ''], a = r.author || {}, c = r.counts, df = r.diffusion, w = r.wave, reps = r.reports;
  const tabs = [['d', 'Détails', null], ['c', 'Commentaires', c.comments], ['l', 'J’aime', c.likes], ['s', 'Partages', c.shares + c.reposts], ['v', 'Vues', c.views]].filter(([k]) => k === 'd' || pbCan.people);
  let dots = ''; if (df) for (let i = 1; i <= df.levels; i++) dots += `<i class="${i <= df.level ? 'on' : ''}"></i>`;
  const stat = (k, v) => `<dt>${esc(k)}</dt><dd>${v}</dd>`;
  let tl = `<div><b>Publié</b><small>${pbUtc(r.created_at)} · @${esc(a.username || '')}</small></div>`;
  if (w) tl += `<div><b>Vague ${w.level} atteinte</b><small>${fmt(w.reach)} personnes hors abonnés</small></div>`;
  if (r.first_report_at) tl += `<div class="r"><b>Premier signalement</b><small>${pbUtc(r.first_report_at)} · à traiter avant ${pbUtc(r.report_due_at)}</small></div>`;
  (r.history || []).slice().reverse().forEach((h) => { tl += `<div class="r"><b>${esc({ remove: 'Retiré', restore: 'Rétabli', dismiss: 'Classé sans suite' }[h.action] || h.action)}${h.reason ? ' : ' + esc(h.reason) : ''}</b><small>${pbUtc(h.at)} · ${esc(h.by || 'équipe')}</small></div>`; });
  const money = r.money ? `<div class="adm-card pb-box"><h4>Argent</h4><dl class="pb-kv">${stat('Monétisé', r.money.monetized ? 'Oui' : 'Non')}${stat('Vues payantes', fmt(r.money.paid_views))}${stat('Vues à encaisser', fmt(r.money.pending_views))}${stat('Boost', r.money.boosted ? 'Oui' : 'Aucun')}</dl></div>` : '';
  const as = r.author_stats;
  const decisions = pbCan.moderate ? `<div class="adm-card pb-box"><h4>Décision</h4><div class="pb-acts">${r.status === 'hidden' ? '<button class="adm-btn pri" type="button" data-pb-do="restore">Rétablir</button>' : '<button class="adm-btn bad" type="button" data-pb-do="remove-form">Retirer</button>'}${reps && r.status !== 'hidden' ? '<button class="adm-btn" type="button" data-pb-do="dismiss">Classer sans suite</button>' : ''}${r.viral && !r.viral.hidden ? '<button class="adm-btn" type="button" data-pb-do="viral-off">Retirer de Viral</button>' : ''}${r.viral && r.viral.hidden ? '<button class="adm-btn" type="button" data-pb-do="viral-on">Remettre dans Viral</button>' : ''}</div>
    <div class="pb-form" id="pb-rm" hidden><label for="pb-why"><b>Motif du retrait</b> (obligatoire, 200 caractères)</label><textarea id="pb-why" maxlength="200" placeholder="ex. contenu copié d’un autre créateur"></textarea>${r.money ? '<label class="chk"><input id="pb-ce" type="checkbox"> Annuler les vues payantes pas encore encaissées (fraude confirmée)</label>' : ''}<div class="pb-acts"><button class="adm-btn bad" type="button" data-pb-do="remove">Confirmer le retrait</button><button class="adm-btn" type="button" data-pb-do="cancel">Annuler</button></div></div>
    <p class="adm-note" id="pb-msg" role="status" hidden></p></div>` : `<div class="adm-card pb-box"><p class="adm-note" style="margin:0">Les décisions (retirer, rétablir) demandent le droit de modération : ton compte consulte seulement.</p></div>`;
  d.innerHTML = `<div class="pb-top"><div><span class="pb-kick">Publication ${esc(r.id)}</span><h3>@${esc(a.username || '—')} · ${esc(PB_KIND[r.media_kind] || 'Texte')}</h3></div><button class="pb-x" type="button" data-pb-x aria-label="Fermer">×</button></div>
  <div class="adm-card pb-box">${pbMedia(r)}${r.media_kind === 'video' || r.media_kind === 'audio' || r.media_kind === 'image' ? `<p>${esc(r.description || '')}</p>` : ''}
    <div class="pb-counts"><span><b>${fmt(c.likes)}</b> j’aime</span><span><b>${fmt(c.comments)}</b> commentaires</span><span><b>${fmt(c.shares)}</b> partages</span><span><b>${fmt(c.reposts)}</b> republications</span><span><b>${fmt(c.views)}</b> vues</span></div>
    <div class="pb-tags"><span class="adm-badge ${s[1]}">${esc(s[0])}</span><span class="adm-badge">${esc(pbCat(r.category))}</span>${(r.countries || []).map((x) => `<span class="adm-badge">${esc(x === 'ALL' ? 'Monde' : x)}</span>`).join('')}${r.source === 'captured' || r.source === 'edited' ? '<span class="adm-badge ok">Fait sur Afrolook</span>' : ''}${r.voice_effect ? `<span class="adm-badge wait">Voix modifiée · ${esc(r.voice_effect)}</span>` : ''}${r.reply_to ? `<span class="adm-badge cert">En réponse à @${esc(r.reply_to.username || '')}</span>` : ''}${r.template ? `<span class="adm-badge">${esc(r.template)}</span>` : ''}</div></div>
  <div class="pb-tabs" role="tablist" aria-label="Contenu du panneau">${tabs.map(([k, l, n]) => `<button type="button" role="tab" data-pb-tab="${k}" aria-selected="${k === 'd'}">${esc(l)}${n == null ? '' : `<i>${short(n)}</i>`}</button>`).join('')}</div>
  <div id="pb-tab-d">
    <div class="adm-card pb-box"><h4>Diffusion <em>comme la carte « Diffusion » de l’application</em></h4>${df ? `<div class="pb-waves" aria-label="Vague ${df.level} sur ${df.levels}">${dots}</div><dl class="pb-kv">${stat('État', esc((PB_WAVE[df.state] || [df.state])[0]) + ` · vague ${df.level}/${df.levels}`)}${stat('Vu en tout', fmt(df.shown_total))}${stat('Montré hors abonnés', fmt(df.shown_outside))}${stat('Regardé jusqu’à la fin', df.finished_pct == null ? 'pas assez de données' : df.finished_pct + ' %')}${stat('Revu en boucle', df.loops_pct == null ? 'pas assez de données' : df.loops_pct + ' %')}${stat('Partages', fmt(df.shares))}</dl>` : '<p class="sub" style="margin:0">Pas de vague : ce type de publication (ou son état d’authenticité) ne fait pas partie de la diffusion.</p>'}</div>
    ${money}
    <div class="adm-card pb-box"><h4>Signalements <em>${reps ? fmt(reps) + ' en attente' : 'aucun'}</em></h4>${r.reports_by_type.length ? `<dl class="pb-kv">${r.reports_by_type.map((x) => stat(PB_REPORT[x.type] || x.type, fmt(x.count))).join('')}</dl>` : '<p class="sub" style="margin:0">Aucun signalement.</p>'}<dl class="pb-kv">${stat('Authenticité', esc(PB_AUTH[r.authenticity] || '—'))}${stat('Origine du média', esc(PB_SRC[r.source] || 'Non précisée'))}</dl></div>
    <div class="adm-card pb-box"><h4>Créateur <em>@${esc(a.username || '')}</em></h4>${as ? `<dl class="pb-kv">${stat('Abonnés', fmt(as.followers))}${stat('Publications', fmt(as.posts))}${stat('Retirées', fmt(as.removed))}${stat('Signalées', fmt(as.reported))}</dl>` : ''}<div class="pb-acts"><button class="adm-btn" type="button" data-pb-who="${esc(a.username || '')}">Tous ses posts</button>${pbCan.people && a.id ? `<button class="adm-btn" type="button" data-pb-user="${esc(a.id)}">Fiche du créateur</button>` : ''}</div></div>
    <div class="adm-card pb-box"><h4>Historique</h4><div class="pb-tl">${tl}</div></div>
    ${decisions}
  </div><div id="pb-tab-l" hidden></div>`;
  const m = d.querySelector('video,audio'); if (autoplay && m) { m.play().catch(() => {}); }
  d.onclick = (e) => {
    if (e.target.closest('[data-pb-x]')) { pbClose(); return; }
    const t = e.target.closest('[data-pb-tab]'); if (t) { d.querySelectorAll('[data-pb-tab]').forEach((x) => x.setAttribute('aria-selected', String(x === t))); const k = t.dataset.pbTab; $('#pb-tab-d').hidden = k !== 'd'; $('#pb-tab-l').hidden = k === 'd'; if (k !== 'd') pbPeople(r.id, k, 1); return; }
    const w2 = e.target.closest('[data-pb-who]'); if (w2) { st.px.author = w2.dataset.pbWho; st.px.page = 1; const el = $('#pb-author'); if (el) el.value = st.px.author; pbClose(); pbLoad(); return; }
    const u = e.target.closest('[data-pb-user]'); if (u) { pbClose(); st.detail = { k: 'u', id: u.dataset.pbUser }; render(); scrollTo(0, 0); return; }
    const pg = e.target.closest('[data-pb-pg]'); if (pg && !pg.disabled) { pbPeople(r.id, pg.dataset.pbKind, Number(pg.dataset.pbPg)); d.scrollTop = 0; return; }
    const doBtn = e.target.closest('[data-pb-do]'); if (doBtn) pbDo(r, doBtn.dataset.pbDo);
  };
}

const PB_PEOPLE = { c: ['comments', 'commentaire', 'commentaires'], l: ['likes', 'personne a aimé', 'personnes ont aimé'], s: ['shares', 'partage ou republication', 'partages et republications'], v: ['views', 'personne a vu', 'personnes ont vu'] };
async function pbPeople(id, k, page) {
  const box = $('#pb-tab-l'); if (!box) return; const [kind, one, many] = PB_PEOPLE[k];
  box.innerHTML = '<p class="adm-empty">Chargement…</p>';
  let res; try { res = await apiGet(`posts/${encodeURIComponent(id)}/people?kind=${kind}&page=${page}&per_page=6`); } catch (e) { box.innerHTML = `<p class="adm-err">${esc(e.message)}</p>`; return; }
  const m = res.meta;
  const row = (x) => {
    const u = x.user || {}; const who = `<button class="pb-lk" type="button" data-pb-who="${esc(u.username || '')}">@${esc(u.username || '—')}</button>`;
    let meta = '', body = '';
    if (kind === 'comments') { meta = `${x.is_reply ? 'réponse · ' : ''}${fmt(x.likes)} j’aime`; body = `<p>${esc(x.text || '')}</p>`; }
    else if (kind === 'likes') meta = x.kind === 'love' ? 'Adore' : 'J’aime';
    else if (kind === 'shares') meta = x.how === 'repost' ? 'Republication' : 'Partage';
    else meta = 'première vue';
    return `<div class="pb-pp">${avatar(u.avatar_url, u.username)}<div style="min-width:0">${who}<span class="pb-meta"> · ${esc(meta)}</span>${body}</div><span class="pb-t">${pbUtc(x.at)}</span></div>`;
  };
  box.innerHTML = `<div class="adm-card pb-box"><h4>${fmt(m.total)} ${m.total > 1 ? many : one} <em>du plus récent au plus ancien</em></h4><div>${res.data.length ? res.data.map(row).join('') : '<p class="sub" style="margin:0">Rien pour l’instant.</p>'}</div>
    <div class="pb-mini"><span>Page ${m.page} sur ${fmt(m.pages)}</span><span class="pb-acts"><button class="adm-btn" data-pb-pg="${m.page - 1}" data-pb-kind="${k}" ${m.page < 2 ? 'disabled' : ''}>‹ Précédent</button><button class="adm-btn" data-pb-pg="${m.page + 1}" data-pb-kind="${k}" ${m.page >= m.pages ? 'disabled' : ''}>Suivant ›</button></span></div>
    ${kind === 'views' ? '<p class="adm-note">Seule la date de la première vue est gardée par personne. Le temps regardé reste anonyme : voir les pourcentages dans « Diffusion ».</p>' : ''}</div>`;
}

async function pbDo(r, act) {
  const msg = (t, bad) => { const el = $('#pb-msg'); if (el) { el.hidden = !t; el.textContent = t || ''; el.style.color = bad ? 'var(--c4)' : ''; } };
  if (act === 'remove-form') { $('#pb-rm').hidden = false; $('#pb-why').focus(); return; }
  if (act === 'cancel') { $('#pb-rm').hidden = true; return; }
  // « Classer sans suite » PUBLIE la vidéo et la rend monétisable, même en attente de vérification ou marquée : on demande confirmation (appui par mégarde constaté le 13/11/2026)
  if (act === 'dismiss' && !confirm('Classer sans suite ?\n\nLes signalements seront effacés et la publication sera visible et monétisable, même si elle était en attente de vérification ou marquée (par exemple une marque d’un autre réseau).\n\nAs-tu bien regardé la publication ?')) return;
  try {
    if (act === 'remove') {
      const why = ($('#pb-why').value || '').trim(); if (why.length < 5) { msg('Écris un motif d’au moins 5 caractères.', true); return; }
      await apiSend('POST', `moderation/posts/${encodeURIComponent(r.id)}`, { action: 'remove', reason: why, ...(($('#pb-ce') || {}).checked ? { cancel_earnings: true } : {}) });
    } else if (act === 'restore') await apiSend('POST', `moderation/posts/${encodeURIComponent(r.id)}`, { action: 'restore' });
    else if (act === 'dismiss') await apiSend('POST', `moderation/posts/${encodeURIComponent(r.id)}`, { action: 'dismiss' });
    else if (act === 'viral-off') await apiSend('PUT', `viral/${encodeURIComponent(r.id)}`, { hidden: true });
    else if (act === 'viral-on') await apiSend('PUT', `viral/${encodeURIComponent(r.id)}`, { hidden: false });
  } catch (e) { msg(e.message, true); return; }
  await pbLoad(); await pbOpen(r.id);
  msg('Décision enregistrée dans le journal de modération.');
}

document.addEventListener('click', (ev) => {
  const t = ev.target.closest('[data-tab],[data-period],[data-topby],[data-topwin],[data-evo],[data-evop],[data-advby],[data-pubby],[data-wdays],[data-open],[data-back],[data-retry]'); if (!t || !root.contains(t)) return;
  const d = t.dataset; const y = scrollY;
  if (d.tab) { st.tab = d.tab; st.detail = null; render(); scrollTo(0, 0); return; }
  if (d.open) { const [k, id] = d.open.split('/'); st.detail = { k, id }; st.evo = 'views'; st.evoP = '90'; render(); scrollTo(0, 0); return; }
  if ('back' in d) { st.detail = null; render(); return; }
  if ('retry' in d) { render(); return; }
  if (d.period) st.period = d.period; else if (d.topby) st.topBy = d.topby; else if (d.topwin) st.topWin = d.topwin; else if (d.evo) st.evo = d.evo; else if (d.evop) st.evoP = d.evop; else if (d.advby) st.advBy = d.advby; else if (d.pubby) st.pubBy = d.pubby; else if (d.wdays) st.wdays = d.wdays;
  render().then(() => scrollTo(0, y));
});
document.addEventListener('keydown', (ev) => { if ((ev.key === 'Enter' || ev.key === ' ') && ev.target.matches && ev.target.matches('.adm-row')) { ev.preventDefault(); ev.target.click(); } });
