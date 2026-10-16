'use strict';
// Pages publiques. Chaque fonction renvoie { title, description, path, body, ld?, active } ; le routeur l'enveloppe avec le gabarit.

const C = require('./components');
const coupon = require('../shared/coupon');
const { esc, fr, dateLongue, dateCourte, heure } = require('../util/format');
const { isoWeek } = require('../jobs/helpers');
const { summarize } = require('../engine/bilan');

const { matchCard, crest, adSlot, adResponsive, aflCard, listWithAds, sideColumn, matchPath, timeEl } = C;

const FAMILLES_ORDRE = ['Résultat', 'Buts', 'Mi-temps', 'Handicap', 'Score', 'Corners', 'Tirs', 'Cartons & fautes', 'Joueurs', 'Spéciaux'];
const lvlClass = (pct) => (pct >= 75 ? 's' : pct >= 60 ? 'e' : 'r');
const FIAB = { haute: ['Haute', 'g'], moyenne: ['Moyenne', 'y'], faible: ['Faible', 'r'] };

/** Les 3 pronostics les plus confiants parmi les matchs à venir (hors confiance basse). */
function topFlash(matches) {
  return matches.filter((m) => m.statut === 'prevu' && m.prono && m.prono.visible !== false && !m.prono.principal.basseConfiance)
    .sort((a, b) => b.prono.principal.confiance - a.prono.principal.confiance).slice(0, 3);
}

function flashBlock(matches) {
  const top = topFlash(matches);
  if (!top.length) return '';
  return `<div class="lbl">Flash du jour · les 3 plus confiants</div><div class="top3">${top.map((m) => `<a class="t3" href="${matchPath(m)}"><div><small>${timeEl(m.coupDEnvoi)} · ${esc(m.leagueNom)}</small><b>${esc(m.domicile.nomCourt)} – ${esc(m.exterieur.nomCourt)}</b></div><div class="pk">${esc(m.prono.principal.libelle)}<span class="num">${m.prono.principal.confiance} %</span></div></a>`).join('')}</div>`;
}

/** Liste de cartes groupées par jour quand elle couvre plusieurs jours. */
function groupedCards(rc, matches) {
  const days = [...new Set(matches.map((m) => m.jour))];
  if (days.length <= 1) return listWithAds(rc, matches.map(matchCard));
  let html = '';
  let all = [];
  for (const d of days) {
    html += `<h2 class="dayh">${esc(dateLongue(d + 'T12:00:00Z'))}</h2>`;
    const cards = matches.filter((m) => m.jour === d).map(matchCard);
    html += cards.join('');
    all = all.concat(cards);
  }
  return html;
}

const bilanBox = (b) => (b && b.taux != null ? `<div class="box bil"><div class="big num">${b.taux} %</div><div><p>de réussite sur les 30 derniers jours, ${b.n} pronostics.</p><a href="/bilan">Voir le bilan complet →</a></div></div>` : '');

function emptyDay() {
  return `<div class="box"><p><b>Aucun match suivi ce jour-là.</b></p><p class="note" style="margin-top:6px">Les pronostics sont publiés dès que les matchs sont connus. Essaie un autre jour dans la barre ci-dessus.</p></div>`;
}

/** Accueil : pronos du jour (ou des prochains jours s'il n'y a rien aujourd'hui). */
function home(rc, { matches, bilan }) {
  const pool = matches.filter((m) => m.prono && m.prono.visible !== false || m.statut !== 'prevu');
  const body = `<div class="wrap"><div class="rail" role="navigation" aria-label="Sports"><a class="sport" href="/football/aujourdhui" aria-current="page">⚽ Football</a><span class="sport off">🏀 Basketball <i>bientôt</i></span><span class="sport off">🎾 Tennis <i>bientôt</i></span></div>${C.dayRail(rc, null)}${C.leagueRail(rc, null)}` +
    `<div class="layout"><div class="col"><div class="hero"><h1>Les pronos foot du jour, <b>gratuits</b></h1><p>Un calcul statistique, une analyse rédigée par l'IA. Pas de compte, pas de clic pour voir le pronostic. Football africain et grands championnats.</p></div>` +
    `${adResponsive(rc, 'haut', 'ad-top')}${flashBlock(pool)}<h2 class="lbl" style="margin-top:6px">Les matchs</h2>${pool.length ? groupedCards(rc, pool) : emptyDay()}` +
    `<div class="mob-only box">${bilanBox(bilan)}</div></div>${sideColumn(rc, { bilan })}</div></div>`;
  return {
    title: 'Pronostics foot gratuits du jour · PronoFlash IA',
    description: 'Pronostics football gratuits, sans inscription : victoire, buts, corners, cartons, handicap. Calcul statistique et analyse IA, mis à jour chaque jour.',
    path: '/', body, active: 'football',
    ld: { '@context': 'https://schema.org', '@type': 'WebSite', name: rc.site.nom, url: rc.site.origine },
  };
}

/** Page d'un jour (/football/aujourdhui, /football/demain, /football/2026-10-18). */
function day(rc, { jour, label, matches, bilan }) {
  const body = `<div class="wrap">${C.sportTabs(rc)}${C.dayRail(rc, jour)}${C.leagueRail(rc, null)}<div class="layout"><div class="col"><div class="hero"><h1>Pronos foot <b>${esc(label)}</b></h1><p>${esc(dateLongue(jour + 'T12:00:00Z'))} : ${matches.length} match${matches.length > 1 ? 's' : ''} suivi${matches.length > 1 ? 's' : ''}, pronostic visible sur chaque carte.</p></div>` +
    `${adResponsive(rc, 'haut', 'ad-top')}${matches.length ? listWithAds(rc, matches.map(matchCard)) : emptyDay()}</div>${sideColumn(rc, { bilan })}</div></div>`;
  return {
    title: `Pronostics foot ${label} · ${dateLongue(jour + 'T12:00:00Z')} · PronoFlash IA`,
    description: `Pronostics football du ${dateLongue(jour + 'T12:00:00Z')} : ${matches.length} matchs analysés avec probabilités, buts, corners et handicap. Gratuit, sans inscription.`,
    path: `/football/${rc.dayAliases[jour] || jour}`, body, active: 'football',
  };
}

/** Page d'un championnat. */
function league(rc, { league: lg, matches, results, bilanLigue }) {
  const body = `<div class="wrap">${C.sportTabs(rc)}${C.leagueRail(rc, lg.slug)}<div class="layout"><div class="col"><div class="hero"><h1>Pronostics <b>${esc(lg.nom)}</b></h1><p>${esc(lg.pays || '')} · matchs à venir de la semaine, avec le bilan de nos pronostics sur ce championnat.</p></div>` +
    `${adResponsive(rc, 'haut', 'ad-top')}${bilanLigue && bilanLigue.taux != null ? `<div class="box bil"><div class="big num">${bilanLigue.taux} %</div><div><p>de réussite sur ${esc(lg.nom)} (${bilanLigue.n} pronostics, 30 jours).</p></div></div>` : ''}` +
    `<h2 class="lbl">Matchs à venir</h2>${matches.length ? groupedCards(rc, matches) : emptyDay()}` +
    `${results.length ? `<h2 class="lbl" style="margin-top:8px">Derniers résultats</h2>${results.map(matchCard).join('')}` : ''}</div>${sideColumn(rc, {})}</div></div>`;
  return {
    title: `Pronostics ${lg.nom} · matchs de la semaine · PronoFlash IA`,
    description: `Pronostics ${lg.nom} gratuits : probabilités, buts, corners, handicap et analyse de chaque match à venir.`,
    path: `/football/${lg.slug}`, body, active: 'football',
  };
}

function probRows(p) {
  const row = (l, v, c) => `<div class="row"><span>${l}</span><div class="tk"><i style="width:${v}%;background:${c}"></i></div><b class="num">${v} %</b></div>`;
  return row('Victoire dom. (1)', p.probas['1'], 'var(--flash)') + row('Match nul (N)', p.probas.N, '#6b7899') + row('Victoire ext. (2)', p.probas['2'], 'var(--cy)') + row('+2,5 buts', p.plus25, 'var(--cy)') + row('Les 2 marquent', p.bttsOui, 'var(--cy)');
}

/** Balisage SportsEvent (schema.org). */
function sportsEvent(rc, m) {
  const ev = {
    '@context': 'https://schema.org', '@type': 'SportsEvent',
    name: `${m.domicile.nom} – ${m.exterieur.nom}`, startDate: m.coupDEnvoi,
    eventStatus: m.statut === 'reporte' ? 'https://schema.org/EventPostponed' : 'https://schema.org/EventScheduled',
    sport: 'Football', url: C.url(rc, matchPath(m)),
    homeTeam: { '@type': 'SportsTeam', name: m.domicile.nom }, awayTeam: { '@type': 'SportsTeam', name: m.exterieur.nom },
    competitor: [{ '@type': 'SportsTeam', name: m.domicile.nom }, { '@type': 'SportsTeam', name: m.exterieur.nom }],
    organizer: { '@type': 'SportsOrganization', name: m.leagueNom },
    location: { '@type': 'Place', name: (m.lieu && m.lieu.nom) || m.domicile.nom, address: (m.lieu && m.lieu.ville) || m.pays || '' },
  };
  if (m.prono) ev.description = m.prono.texte && m.prono.texte.resume;
  return ev;
}

/** Données du match pour le navigateur (coupons) : marchés fiables et matrice de scores. */
function matchJson(m) {
  const p = m.prono;
  return {
    id: m.id, nom: `${m.domicile.nomCourt} – ${m.exterieur.nomCourt}`, ligue: m.leagueNom, t: m.coupDEnvoi,
    marches: p.marches.map((x) => ({ k: x.cle, l: x.libelle, f: x.famille, p: x.pct, r: x.fiabilite[0] })), matrice: p.matrice,
  };
}
const jsonScript = (id, obj) => `<script type="application/json" id="${id}">${JSON.stringify(obj).replace(/</g, '\\u003c')}</script>`;

function addBtn(m, mk) {
  return `<button type="button" class="add" data-add="${esc(m.id)}|${esc(mk.cle)}" aria-pressed="false" aria-label="Ajouter « ${esc(mk.libelle)} » au coupon">＋</button>`;
}

/** Marchés solides à proposer d'un clic. */
function solidMarkets(p, n = 3) {
  const fam = new Set();
  const out = [];
  for (const m of p.marches.filter((x) => x.fiabilite !== 'faible' && x.pct >= 65 && x.pct < 96).sort((a, b) => b.pct - a.pct)) {
    if (fam.has(m.famille)) continue;
    fam.add(m.famille); out.push(m);
    if (out.length === n) break;
  }
  return out;
}

/** Fiche match : verdict visible tout de suite, résumé du pronostic. */
function match(rc, { m, same, h2h }) {
  const p = m.prono;
  const path = matchPath(m);
  const done = m.statut === 'termine' && m.resultat;
  const titre = `${m.domicile.nomCourt} – ${m.exterieur.nomCourt}`;
  const verdict = p && p.visible !== false
    ? `<div class="big"><small>Notre pronostic</small><b>${esc(p.principal.libelle)}</b></div><div><div class="gauge" role="img" aria-label="Confiance ${p.principal.confiance} %"><i style="width:${p.principal.confiance}%"></i></div><div class="gl"><span>Niveau de confiance${p.principal.basseConfiance ? ' (match très ouvert)' : ''}</span><b class="num">${p.principal.confiance} %</b></div></div>`
    : `<div class="big"><small>Pronostic</small><b>En préparation</b></div>`;
  const result = done ? `<div class="score num">${m.resultat.scoreDom} - ${m.resultat.scoreExt} ${m.resultat.reussi === true ? '<span class="badge-ok">✅ Réussi</span>' : m.resultat.reussi === false ? '<span class="badge-ko">❌ Raté</span>' : ''}</div>` : '';
  const aiBadge = p && p.sourceTexte === 'secours' ? 'Analyse automatique à partir des chiffres calculés' : '✦ Rédigée par l\'IA à partir des chiffres ci-dessus';
  const analyse = p && p.texte ? `<div class="box an"><div class="lbl">Analyse</div><span class="ai">${aiBadge}</span><p>${esc(p.texte.analyse)}</p><ul class="kp">${p.texte.pointsCles.map((x) => `<li>${esc(x)}</li>`).join('')}</ul></div>` : '';
  const h2hHtml = h2h && h2h.length ? `<div class="box"><div class="lbl">Face-à-face</div><div class="tw"><table class="t"><thead><tr><th>Date</th><th>Rencontre</th><th>Score</th></tr></thead><tbody>${h2h.map((x) => `<tr><td>${esc(x.date)}</td><td>${esc(x.dom)} – ${esc(x.ext)}</td><td class="num">${x.sd}-${x.se}</td></tr>`).join('')}</tbody></table></div></div>` : '';
  const solid = p ? solidMarkets(p) : [];
  const addBox = solid.length ? `<div class="box"><div class="lbl">Ajouter à mon coupon</div><div class="opts">${solid.map((x) => `<div class="op ${lvlClass(x.pct)}"><span>${esc(x.libelle)}<small>${esc(x.famille)}</small></span><b class="num">${x.pct} %</b>${addBtn(m, x)}</div>`).join('')}</div></div>` : '';
  const otherMatches = same.filter((x) => x.id !== m.id).slice(0, 4);
  const side = sideColumn(rc, {
    afl: 'fiche',
    extra: otherMatches.length ? `<div class="box"><div class="lbl">Autres matchs</div><div style="display:grid;gap:8px;margin-top:10px">${otherMatches.map((x) => `<a href="${matchPath(x)}" style="text-decoration:none;font-size:13px;border-bottom:1px solid var(--line);padding-bottom:8px"><b style="font-family:var(--fd);font-size:16px">${esc(x.domicile.nomCourt)} – ${esc(x.exterieur.nomCourt)}</b><br><span style="color:var(--flash)">${esc(x.prono ? x.prono.principal.libelle : 'En préparation')}</span></a>`).join('')}</div></div>` : '',
  });
  const wa = `https://wa.me/?text=${encodeURIComponent(`${titre} : ${p ? p.principal.libelle + ' (' + p.principal.confiance + ' %)' : 'pronostic'} ${C.url(rc, path)}`)}`;
  const body = `<div class="wrap"><nav class="crumb" aria-label="Fil d'Ariane"><a href="/football/aujourdhui">Football</a> › <a href="/football/${esc(m.leagueSlug)}">${esc(m.leagueNom)}</a> › ${esc(titre)}</nav>` +
    `<div class="layout"><div class="col"><div class="vd"><h1>${crest(m.domicile, true)}<span>${esc(m.domicile.nom)}</span><span class="vs">contre</span><span>${esc(m.exterieur.nom)}</span>${crest(m.exterieur, true)}</h1>` +
    `<div class="meta">${esc(m.leagueNom)}${m.journee ? ` · ${m.journee}e journée` : ''} · ${esc(dateLongue(m.coupDEnvoi))} · ${timeEl(m.coupDEnvoi)}</div>${result}${verdict}</div>` +
    `${adResponsive(rc, 'verdict', 'ad-verdict')}` +
    (p ? `<a class="det" href="${path}/analyse"><div><b>Voir l'analyse complète</b><span>${p.marches.length} paris calculés · forme · comparatif · face-à-face · coupons prêts à l'emploi</span></div><i>→</i></a>` : '') +
    (p && p.visible !== false ? `<div class="box"><div class="lbl">Probabilités calculées</div><div class="pb">${probRows(p)}</div><p class="note" style="margin-top:12px">Score le plus probable : <b style="color:var(--tx)">${esc(p.scoreProbable)}</b></p></div>` : '') +
    `${analyse}${adSlot(rc, 'fiche_native', { cls: 'ad-nat' })}${h2hHtml}${aflCard(rc, 'fiche', 0)}${addBox}` +
    `<div class="sh"><a class="wa" href="${wa}" target="_blank" rel="noopener">Partager sur WhatsApp</a><button type="button" data-copy="${esc(C.url(rc, path))}">Copier le lien</button></div>` +
    `<p class="note">Pronostic d'aide à la décision : on n'engage rien, aucun gain n'est garanti. PronoFlash IA ne prend aucun pari. 18+ · Jouez de façon responsable.</p></div>${side}</div></div>` +
    (p ? jsonScript('pf-match', matchJson(m)) : '');
  return {
    title: `${titre} : pronostic ${m.leagueNom} · ${dateCourte(m.coupDEnvoi)} · PronoFlash IA`,
    description: p && p.texte ? `${p.texte.resume} Probabilités, analyse et paris sûrs pour ${titre}.` : `Pronostic ${titre}, ${m.leagueNom}, ${dateLongue(m.coupDEnvoi)}.`,
    path, body, ld: sportsEvent(rc, m), active: 'football',
  };
}

function cmpRow(r) {
  const max = Math.max(r.dom, r.ext, 0.01) * 1.15;
  const w = (v) => Math.round((v / max) * 100);
  const f = (v) => (Number.isInteger(v) ? String(v) : fr(v, 1));
  return `<div class="cmp"><span class="n">${esc(r.label)}</span><b class="num">${f(r.dom)}</b><div class="dual"><span><i style="width:${w(r.dom)}%;background:var(--flash)"></i></span><span><i style="width:${w(r.ext)}%;background:var(--cy)"></i></span></div><b class="num">${f(r.ext)}</b></div>`;
}

function formList(recent) {
  const rows = recent.slice().sort((a, b) => (a.date < b.date ? 1 : -1)).slice(0, 5);
  if (!rows.length) return '<p class="note">Historique indisponible.</p>';
  return `<div class="fl">${rows.map((e) => { const r = e.gf > e.ga ? 'V' : e.gf === e.ga ? 'N' : 'D'; return `<div><i class="${r}">${r}</i><span>${e.venue === 'home' ? 'Dom.' : 'Ext.'} vs ${esc(e.opp)} : ${e.gf}-${e.ga}</span><em>${esc(e.date.slice(0, 10))}</em></div>`; }).join('')}</div>`;
}

/** Page « analyse complète » : tout pour préparer un coupon. */
function details(rc, { m, formH, formA, h2h, rates, pool }) {
  const p = m.prono;
  const path = `${matchPath(m)}/analyse`;
  const titre = `${m.domicile.nomCourt} – ${m.exterieur.nomCourt}`;
  const byFam = {};
  for (const x of p.marches) (byFam[x.famille] = byFam[x.famille] || []).push(x);
  const fams = FAMILLES_ORDRE.filter((f) => byFam[f]);
  const famHtml = fams.map((f) => `<section class="fam" data-fam="${esc(f)}"><h3>${esc(f)}</h3>${byFam[f].sort((a, b) => b.pct - a.pct).map((x) => { const fi = FIAB[x.fiabilite]; const rate = rates && rates[x.cle.replace(/[.:]/g, '_')]; return `<div class="fr"><span>${esc(x.libelle)}${rate ? ` <small class="note">(réel ${rate.reel} % sur ${rate.n})</small>` : ''}</span><b class="num ${lvlClass(x.pct)}">${x.pct} %</b><span class="pill ${fi[1]}">${fi[0]}</span>${addBtn(m, x)}</div>`; }).join('')}</section>`).join('');
  const toc = [['resume', 'Résumé'], ['paris', 'Tous les paris'], ['stats', 'Comparatif'], ['forme', 'Forme et séries'], ['h2h', 'Face-à-face'], ['fiab', 'Nos résultats'], ['coupon', 'Coupons prêts'], ['avant', 'Avant de valider']];
  const tocLinks = toc.map(([id, l]) => `<a href="#d-${id}">${l}</a>`).join('');
  const tocm = toc.map(([id, l]) => `<a class="chip" href="#d-${id}">${l}</a>`).join('');
  // coupons prêts : meilleur choix par match, en variant les types de pari, en incluant ce match
  const poolMap = {};
  for (const x of pool) poolMap[x.id] = x.prono.marches.map((mk) => ({ key: mk.cle, libelle: mk.libelle, famille: mk.famille, pct: mk.pct, fiabilite: mk.fiabilite }));
  const sugg = [[2, 'Prudent'], [3, 'Équilibré'], [5, 'Audacieux']].map(([n, nom]) => {
    const sel = coupon.suggest(poolMap, n);
    if (sel.length < 2) return '';
    const pr = coupon.couponProbability(sel.map((s) => ({ matchId: s.matchId, key: s.key, pct: s.pct })), null).prob;
    return `<a href="/coupon#${esc(sel.map((s) => s.matchId + '|' + s.key).join(','))}"><b>${nom} · ${sel.length} sélections</b><span>${esc(sel.map((s) => s.libelle).join(' · '))}</span><em class="num">${Math.round(pr * 100)} %</em></a>`;
  }).join('');
  const ratesRows = Object.entries(rates || {}).slice(0, 0);
  void ratesRows;
  const cal = p.marches.filter((x) => rates && rates[x.cle.replace(/[.:]/g, '_')]).slice(0, 6);
  const calHtml = cal.length ? `<div class="tw"><table class="t"><thead><tr><th>Pari</th><th>Annoncé</th><th>Réel</th><th>Matchs</th></tr></thead><tbody>${cal.map((x) => { const r = rates[x.cle.replace(/[.:]/g, '_')]; return `<tr><td>${esc(x.libelle)}</td><td class="num">${r.annonce} %</td><td class="num">${r.reel} %</td><td class="num">${r.n}</td></tr>`; }).join('')}</tbody></table></div>` : `<p class="note" style="margin-top:8px">Pas encore assez de matchs terminés pour comparer ces paris. Le bilan se remplit automatiquement au fil des résultats : voir la page <a href="/bilan" style="color:var(--cy)">Bilan</a>.</p>`;
  const sec = (id, title, inner) => `<div class="box dsec" id="d-${id}"><div class="lbl">${title}</div>${inner}</div>`;
  const body = `<div class="wrap"><nav class="crumb" aria-label="Fil d'Ariane"><a href="/football/aujourdhui">Football</a> › <a href="/football/${esc(m.leagueSlug)}">${esc(m.leagueNom)}</a> › <a href="${matchPath(m)}">${esc(titre)}</a> › Analyse complète</nav>` +
    `<div class="layout"><div class="col"><div class="tocm" aria-label="Sommaire">${tocm}</div>` +
    `<div class="dh dsec" id="d-resume"><h1>${esc(titre)} : <b>l'analyse complète</b></h1><div class="strip"><div><span class="k">Pronostic</span><b style="color:var(--flash)">${esc(p.principal.libelle)}</b></div><div><span class="k">Confiance</span><b class="num" style="color:var(--ok)">${p.principal.confiance} %</b></div><div><span class="k">Score probable</span><b class="num">${esc(p.scoreProbable)}</b></div><div><span class="k">Coup d'envoi</span><b class="num">${esc(dateCourte(m.coupDEnvoi))} · ${timeEl(m.coupDEnvoi)}</b></div></div>` +
    `<p class="note" style="margin-top:8px">Tout ce qu'il faut pour préparer ton coupon avec ce match. Les chiffres sont recalculés régulièrement jusqu'au coup d'envoi.</p></div>` +
    `${adResponsive(rc, 'verdict', 'ad-verdict')}` +
    sec('paris', 'Tous les paris du match', `<p class="note" style="margin:8px 0 10px">Les paris que proposent les plateformes, pas seulement le résultat et les buts. Chaque ligne indique notre probabilité et la fiabilité de la donnée.</p><div class="mk" id="pf-fams" hidden></div>${famHtml}<p class="note" style="margin-top:10px">Fiabilité : Haute = beaucoup de données et un modèle éprouvé. Faible = événement rare ou peu de données, donné à titre indicatif et jamais utilisé dans les coupons proposés.</p>`) +
    adSlot(rc, 'fiche_native', { cls: 'ad-nat' }) +
    (p.comparatif && p.comparatif.length ? sec('stats', 'Comparatif des deux équipes', `<p class="note" style="margin:8px 0 2px">Moyennes récentes. <b style="color:var(--flash)">${esc(m.domicile.nomCourt)}</b> à gauche, <b style="color:var(--cy)">${esc(m.exterieur.nomCourt)}</b> à droite.</p>${p.comparatif.map(cmpRow).join('')}`) : '') +
    sec('forme', 'Forme et séries', `<div class="two"><div><b style="font-family:var(--fd);font-size:18px">${esc(m.domicile.nomCourt)} · 5 derniers</b>${formList(formH)}</div><div><b style="font-family:var(--fd);font-size:18px">${esc(m.exterieur.nomCourt)} · 5 derniers</b>${formList(formA)}</div></div>`) +
    aflCard(rc, 'details', 0) +
    (h2h && h2h.length ? sec('h2h', 'Face-à-face', `<div class="tw"><table class="t"><thead><tr><th>Date</th><th>Rencontre</th><th>Score</th></tr></thead><tbody>${h2h.map((x) => `<tr><td>${esc(x.date)}</td><td>${esc(x.dom)} – ${esc(x.ext)}</td><td class="num">${x.sd}-${x.se}</td></tr>`).join('')}</tbody></table></div>`) : '') +
    sec('fiab', 'Nos résultats sur ce type de pari', `<p class="note" style="margin:8px 0">Ce que nos pronostics ont donné sur les matchs terminés des 90 derniers jours. L'écart entre « annoncé » et « réel » montre si le modèle est fiable.</p>${calHtml}`) +
    `${adResponsive(rc, 'haut', 'ad-top')}` +
    (sugg ? sec('coupon', 'Coupons prêts avec ce match', `<div class="sg">${sugg}</div><p class="note" style="margin-top:8px">Un clic ouvre le coupon, où tu peux le modifier.</p>`) : '') +
    sec('avant', 'Avant de valider ton coupon', `<ul class="ck"><li>Vérifie les compositions 1 h avant le coup d'envoi : une absence change les chiffres.</li><li>Garde les paris au-dessus de 60 % : un seul maillon faible tire tout le coupon vers le bas.</li><li>Varie les types de pari (buts, corners, handicap…) pour ne pas dépendre d'un seul scénario.</li><li>Reste à 2 ou 3 sélections : au-delà, la probabilité chute vite.</li><li>Ne joue que ce que tu peux te permettre de perdre. 18+ · <a href="/jeu-responsable" style="color:var(--cy)">Jeu responsable</a>.</li></ul>`) +
    `<div class="sh"><a class="wa" href="https://wa.me/?text=${encodeURIComponent(`Analyse ${titre} : ${C.url(rc, path)}`)}" target="_blank" rel="noopener">Partager l'analyse sur WhatsApp</a><button type="button" data-copy="${esc(C.url(rc, path))}">Copier le lien</button></div>` +
    `<p class="note">Analyse d'aide à la préparation. On n'engage rien : aucun gain n'est garanti ni promis, et PronoFlash IA ne prend aucun pari.</p></div>` +
    `<aside class="side"><div class="sticky"><div class="box toc"><div class="lbl">Sommaire</div><div style="margin-top:8px">${tocLinks}</div></div>${adSlot(rc, 'colonne_rect', { cls: 'ad-rect', variant: 'dk' })}${adSlot(rc, 'colonne_tall', { cls: 'ad-tall', variant: 'dk' })}</div></aside></div></div>` +
    jsonScript('pf-match', matchJson(m));
  return {
    title: `${titre} : analyse complète, tous les paris · PronoFlash IA`,
    description: `Analyse complète de ${titre} (${m.leagueNom}) : ${p.marches.length} paris calculés (résultat, buts, corners, cartons, handicap), forme, comparatif et coupons prêts à l'emploi.`,
    path, body, ld: sportsEvent(rc, m), active: 'football',
  };
}

/** Bilan public : taux de réussite automatique. */
function bilan(rc, { s30, weeks, recent, leagues, familles }) {
  const W = 560, H = 140;
  const pts = weeks.map((w) => w.taux);
  let svg = '';
  if (pts.length >= 2) {
    const lo = Math.max(0, Math.min(...pts, 50) - 5), hi = Math.min(100, Math.max(...pts, 70) + 5);
    const x = (i) => 30 + (i * (W - 60)) / (pts.length - 1);
    const y = (v) => H - 22 - ((v - lo) / (hi - lo)) * (H - 44);
    const path = pts.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(' ');
    svg = `<svg class="spark" viewBox="0 0 ${W} ${H}" role="img" aria-label="Taux de réussite par semaine"><path d="${path} L${x(pts.length - 1)} ${H - 22} L${x(0)} ${H - 22} Z" fill="rgba(43,213,118,.12)"/><path d="${path}" fill="none" stroke="#2BD576" stroke-width="2.5" stroke-linejoin="round"/>` +
      pts.map((v, i) => `<circle cx="${x(i)}" cy="${y(v)}" r="${i === pts.length - 1 ? 5 : 3}" fill="${i === pts.length - 1 ? '#2BD576' : '#0F1626'}" stroke="#2BD576" stroke-width="2"/>`).join('') +
      weeks.map((w, i) => `<text x="${x(i)}" y="${H - 4}" text-anchor="middle" fill="#8E9AB8" font-size="11">${esc(w.label)}</text>`).join('') +
      `<text x="${x(pts.length - 1)}" y="${y(pts[pts.length - 1]) - 10}" text-anchor="middle" fill="#2BD576" font-size="13" font-weight="700">${pts[pts.length - 1]}%</text></svg>`;
  }
  const row = (l, v, n) => `<div class="row"><span>${esc(l)}</span><div class="tk"><i style="width:${v == null ? 0 : v}%"></i></div><span class="num">${v == null ? '–' : v + ' %'} · ${n}</span></div>`;
  const empty = !s30 || !s30.n;
  const body = `<div class="wrap"><div class="layout"><div class="col"><div class="hero"><h1>Le <b>bilan</b> en toute transparence</h1><p>Chaque pronostic est enregistré avant le coup d'envoi, puis marqué ✅ ou ❌ automatiquement après le match. Les ratés restent affichés.</p></div>` +
    (empty ? `<div class="box"><p><b>Le bilan se construit.</b></p><p class="note" style="margin-top:6px">Les premiers résultats apparaissent dès que les premiers matchs suivis sont terminés.</p></div>` :
      `<div class="kpis"><div class="kpi"><small>Réussite 30 jours</small><b class="g num">${s30.taux} %</b></div><div class="kpi"><small>Pronostics</small><b class="num">${s30.n}</b></div><div class="kpi"><small>Réussis</small><b class="g num">${s30.ok}</b></div><div class="kpi"><small>Ratés</small><b class="r num">${s30.ko}</b></div></div>` +
      (svg ? `<div class="box"><div class="lbl">Réussite par semaine</div>${svg}</div>` : '') + adResponsive(rc, 'haut', 'ad-top') +
      (s30.parConfiance.length ? `<div class="box"><div class="lbl">Par niveau de confiance</div><div class="hb">${s30.parConfiance.map((r) => row(`${r.k} à ${+r.k + 9} %`, r.taux, r.n)).join('')}</div><p class="note" style="margin-top:10px">Plus la confiance annoncée est haute, plus le taux réel devrait monter : c'est ce qui prouve que le modèle est calibré.</p></div>` : '') +
      (leagues.length ? `<div class="box"><div class="lbl">Par championnat</div><div class="hb">${leagues.map((l) => row(l.nom, l.taux, l.n)).join('')}</div></div>` : '') +
      (familles.length ? `<div class="box"><div class="lbl">Par type de pari : annoncé contre réel</div><div class="hb">${familles.map((f) => `<div class="row"><span>${esc(f.k.replace(/_/g, ' '))}</span><div class="tk"><i style="width:${f.taux == null ? 0 : f.taux}%"></i></div><span class="num">réel ${f.taux} % · annoncé ${f.annonce} %</span></div>`).join('')}</div><p class="note" style="margin-top:10px">Tous les paris calculés à fiabilité haute ou moyenne, pas seulement le pronostic principal. « Annoncé » est la probabilité moyenne que nous avions calculée ; « réel » est le taux observé. Plus les deux sont proches, plus le modèle est fiable.</p></div>` : '')) +
    (recent.length ? `<div class="box"><div class="lbl">Derniers résultats</div><div class="rl">${recent.map((m) => `<a href="${matchPath(m)}"><span>${m.resultat.reussi === true ? '✅' : m.resultat.reussi === false ? '❌' : '•'}</span><span>${esc(m.domicile.nomCourt)} ${m.resultat.scoreDom}-${m.resultat.scoreExt} ${esc(m.exterieur.nomCourt)}<br><em>Pronostic : ${esc(m.prono ? m.prono.principal.libelle : '–')}</em></span><em>${esc(dateCourte(m.coupDEnvoi))}</em></a>`).join('')}</div></div>` : '') +
    `</div>${sideColumn(rc, {})}</div></div>`;
  return {
    title: 'Bilan des pronostics : taux de réussite en toute transparence · PronoFlash IA',
    description: 'Taux de réussite de nos pronostics football calculé automatiquement : par semaine, par championnat, par niveau de confiance et par type de pari.',
    path: '/bilan', body, active: 'bilan',
  };
}

/** Page coupon : composition côté navigateur, avec coupons proposés rendus côté serveur. */
function couponPage(rc, { pool }) {
  const poolMap = {};
  for (const x of pool) poolMap[x.id] = x.prono.marches.map((mk) => ({ key: mk.cle, libelle: mk.libelle, famille: mk.famille, pct: mk.pct, fiabilite: mk.fiabilite }));
  const sugg = [[2, 'Prudent'], [3, 'Équilibré'], [5, 'Audacieux']].map(([n, nom]) => {
    const sel = coupon.suggest(poolMap, n);
    if (sel.length < 2) return '';
    const pr = coupon.couponProbability(sel.map((s) => ({ matchId: s.matchId, key: s.key, pct: s.pct })), null).prob;
    const names = Object.fromEntries(pool.map((x) => [x.id, `${x.domicile.nomCourt} – ${x.exterieur.nomCourt}`]));
    return `<a href="#${esc(sel.map((s) => s.matchId + '|' + s.key).join(','))}" data-sug="${esc(sel.map((s) => s.matchId + '|' + s.key).join(','))}"><b>${nom} · ${sel.length} sélections</b><span>${esc(sel.map((s) => `${names[s.matchId]} : ${s.libelle}`).join(' · '))}</span><em class="num">${Math.round(pr * 100)} %</em></a>`;
  }).join('');
  const data = pool.slice(0, 16).map((m) => ({
    id: m.id, nom: `${m.domicile.nomCourt} – ${m.exterieur.nomCourt}`, ligue: m.leagueNom, t: m.coupDEnvoi, slug: matchPath(m),
    marches: m.prono.marches.filter((x) => x.fiabilite !== 'faible' && x.pct >= 50 && x.pct < 97).map((x) => ({ k: x.cle, l: x.libelle, f: x.famille, p: x.pct, r: x.fiabilite[0] })),
    matrice: m.prono.matrice,
  }));
  const body = `<div class="wrap"><div class="layout"><div class="col"><div class="hero"><h1>Compose ton <b>coupon</b>, sans engagement</h1><p>Combine 2 à 5 matchs et mélange les types de pari : résultat, buts, handicap, corners, tirs, cartons. Le site calcule la probabilité que le coupon passe en entier. Aucune mise, aucune cote, aucun gain promis.</p></div>${adResponsive(rc, 'haut', 'ad-top')}` +
    `<div class="box"><div class="lbl">Coupons proposés par le calcul</div><div class="sg">${sugg || '<p class="note">Les coupons proposés apparaissent dès que plusieurs matchs ont un pronostic.</p>'}</div><p class="note" style="margin-top:8px">Les paris à fiabilité faible ne sont jamais proposés.</p></div>` +
    `<div id="pf-coupon"><noscript><div class="box"><p>Le compositeur de coupon demande JavaScript. Les coupons proposés ci-dessus restent consultables.</p></div></noscript></div>` +
    `<p class="note">PronoFlash IA ne prend aucun pari, n'affiche aucune cote et ne promet aucun gain. Les probabilités sont calculées et ne garantissent rien. 18+ · Jouez de façon responsable.</p></div>` +
    `<aside class="side"><div class="sticky"><div class="cp" id="pf-cpanel"></div>${adSlot(rc, 'colonne_rect', { cls: 'ad-rect', variant: 'dk' })}${aflCard(rc, 'coupon', 0)}</div></aside></div></div>${jsonScript('pf-pool', data)}`;
  return {
    title: 'Coupon de paris : compose ta combinaison, sans engagement · PronoFlash IA',
    description: 'Compose un coupon de 2 à 5 sélections (résultat, buts, handicap, corners, tirs, cartons) et vois la probabilité que tout passe. Sans mise, sans cote, sans compte.',
    path: '/coupon', body, active: 'coupon',
  };
}

function notFound(rc) {
  const body = `<div class="wrap"><div class="layout"><div class="col"><div class="hero"><h1>Page <b>introuvable</b></h1><p>Cette page n'existe pas ou le match n'est plus affiché.</p></div><div class="sh"><a class="btn" href="/football/aujourdhui">Pronos du jour</a><a class="btn sec" href="/bilan">Bilan</a></div></div></div></div>`;
  return { title: 'Page introuvable · PronoFlash IA', description: 'Page introuvable.', path: '/404', body, noindex: true };
}

/** Regroupe les jours du bilan par semaine ISO (taux par semaine) pour le graphique. */
function weeklyRates(days) {
  const by = new Map();
  for (const d of days) {
    if (!d.delta) continue;
    const w = isoWeek(new Date(d.jour + 'T12:00:00Z'));
    by.set(w, (by.get(w) || []).concat(d.delta));
  }
  return [...by.entries()].sort().map(([w, deltas]) => { const s = summarize(deltas); return { semaine: w, label: 'S' + w.split('-W')[1], taux: s.taux, n: s.n }; }).filter((x) => x.taux != null);
}

module.exports = { home, day, league, match, details, bilan, couponPage, notFound, topFlash, weeklyRates, solidMarkets, matchJson, FAMILLES_ORDRE };
