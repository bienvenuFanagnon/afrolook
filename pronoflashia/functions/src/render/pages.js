'use strict';
// Pages publiques, en français ou en anglais (rc.lang). Chaque fonction renvoie { title, description, path, alternates, body, ld?, active } ;
// le routeur l'enveloppe avec le gabarit.

const C = require('./components');
const coupon = require('../shared/coupon');
const labels = require('../shared/labels');
const { esc, fr, dateLongue, dateCourte } = require('../util/format');
const { isoWeek } = require('../jobs/helpers');
const { summarize } = require('../engine/bilan');
const { summarizeCoupons } = require('../jobs/coupons');

const { matchCard, crest, adSlot, adResponsive, aflCard, partnerCard, channelBanner, listWithAds, listEnd, sideColumn, timeEl, pct, colon, leagueName, pickLabel, betLabel, famLabel } = C;

const FAMILLES_ORDRE = ['Résultat', 'Buts', 'Mi-temps', 'Handicap', 'Score', 'Corners', 'Tirs', 'Cartons & fautes', 'Joueurs', 'Spéciaux'];
const lvlClass = (p) => (p >= 75 ? 's' : p >= 60 ? 'e' : 'r');
const FIAB_CLS = { haute: 'g', moyenne: 'y', faible: 'r' };

/** Adresses de la même page dans les deux langues (hreflang, bouton de langue). */
const alts = (rc, name, arg) => ({ fr: rc.pathIn('fr', name, arg), en: rc.pathIn('en', name, arg) });
const titleOf = (m) => `${m.domicile.nomCourt} – ${m.exterieur.nomCourt}`;

/** Les 3 pronostics les plus confiants parmi les matchs à venir (hors confiance basse). */
function topFlash(matches) {
  return matches.filter((m) => m.statut === 'prevu' && m.prono && m.prono.visible !== false && !m.prono.principal.basseConfiance)
    .sort((a, b) => b.prono.principal.confiance - a.prono.principal.confiance).slice(0, 3);
}

function flashBlock(rc, matches) {
  const top = topFlash(matches);
  if (!top.length) return '';
  return `<div class="lbl">${rc.t.flash}</div><div class="top3">${top.map((m) => `<a class="t3" href="${rc.u('match', m)}"><div><small>${timeEl(rc, m.coupDEnvoi)} · ${esc(leagueName(rc, m))}</small><b>${esc(titleOf(m))}</b></div><div class="pk">${esc(pickLabel(rc, m))}<span class="num">${pct(rc, m.prono.principal.confiance)}</span></div><span class="more">${rc.t.moreDetails} <i aria-hidden="true">›</i></span></a>`).join('')}</div>`;
}

/** Liste de cartes groupées par jour quand elle couvre plusieurs jours. */
function groupedCards(rc, matches, insert) {
  const multi = new Set(matches.map((m) => m.jour)).size > 1;
  // l'intitulé du jour voyage avec sa première carte : les pubs s'insèrent entre les cartes, jamais entre un titre et son match
  const cards = matches.map((m, i) => (multi && (i === 0 || matches[i - 1].jour !== m.jour) ? `<h2 class="dayh">${esc(dateLongue(m.jour + 'T12:00:00Z', rc.lang))}</h2>` : '') + matchCard(rc, m));
  if (insert) cards.splice(Math.min(4, cards.length), 0, insert);
  return listWithAds(rc, cards);
}

/** Un bilan n'est mis en avant que s'il est bon : assez de pronostics et un taux qui rassure. La page Bilan, elle, reste toujours complète. */
const BILAN_MIN_N = 30, BILAN_MIN_RATE = 55;
const bilanGood = (b) => !!(b && b.taux != null && b.n >= BILAN_MIN_N && b.taux >= BILAN_MIN_RATE);

/** En-tête de l'accueil : le bilan en grand, pour donner confiance dès l'arrivée. */
function bilanHero(rc, b) {
  if (!bilanGood(b)) return '';
  const t = rc.t;
  return `<a class="bhero" href="${rc.u('bilan')}"><span class="big num">${pct(rc, b.taux)}</span><span class="bht"><b>${t.bilanHeroT}</b><small>${esc(t.bilanBox(b.taux, b.n))}</small></span><i aria-hidden="true">→</i></a>`;
}

const bilanBox = (rc, b) => (b && b.taux != null ? `<div class="box bil"><div class="big num">${pct(rc, b.taux)}</div><div><p>${rc.t.bilanBox(b.taux, b.n)}</p><a href="${rc.u('bilan')}">${rc.t.seeBilan}</a></div></div>` : '');
const emptyDay = (rc) => `<div class="box"><p><b>${rc.t.emptyDayB}</b></p><p class="note" style="margin-top:6px">${rc.t.emptyDayP}</p></div>`;

/** Accueil : pronos du jour (ou des prochains jours s'il n'y a rien aujourd'hui). */
/** Coupons flash : les coupons prêts à l'emploi, mis en avant sur l'accueil. */
/** Titres d'actualité de la langue de la page d'abord, puis de l'autre langue ; jamais deux articles du même titre. */
function pickNews(rc, items, n, teamIds) {
  let list = items || [];
  if (teamIds) list = list.filter((x) => (x.teamIds || []).some((id) => teamIds.includes(id)));
  const seen = new Set();
  list = list.filter((x) => { const k = x.titre.toLowerCase().slice(0, 60); if (seen.has(k)) return false; seen.add(k); return true; });
  const same = list.filter((x) => x.lang === rc.lang), other = list.filter((x) => x.lang !== rc.lang);
  return same.concat(other).slice(0, n);
}

const newsLink = (rc, x) => {
  const thumb = x.image ? `<span class="nwi${x.video ? ' vid' : ''}"><img src="${esc(x.image)}" alt="" width="72" height="72" loading="lazy" decoding="async" referrerpolicy="no-referrer"></span>` : '';
  return `<a class="nw${x.image ? ' has' : ''}" href="${esc(x.lien)}" target="_blank" rel="nofollow noopener noreferrer">${thumb}<span class="nwt"><small>${x.video ? '▶ ' : ''}${esc(x.source)} · ${esc(timeAgo(rc, x.date))}</small><span>${esc(x.titre)}</span></span></a>`;
};

function timeAgo(rc, iso) {
  const h = Math.max(0, Math.round((new Date(rc.now).getTime() - new Date(iso).getTime()) / 3600e3));
  return h < 1 ? rc.t.newsNow : h < 24 ? rc.t.newsHours(h) : rc.t.newsDays(Math.round(h / 24));
}

/** Accueil : une ligne de cartes à balayer (≈ 90 px de haut) insérée entre les pronostics, liens vers les sites d'origine. */
function newsStrip(rc, items) {
  const list = pickNews(rc, items, 8);
  if (list.length < 3) return '';
  return `<div class="nwb"><div class="lbl">${rc.t.newsTitle}</div><div class="nws" role="list">${list.map((x) => `<div role="listitem">${newsLink(rc, x)}</div>`).join('')}</div></div>`;
}

/** Fiche d'un match : jusqu'à 3 titres qui parlent d'une des deux équipes. */
function matchNews(rc, items, m) {
  const ids = [m.domicile.teamId, m.exterieur.teamId].filter((x) => x != null).map(String);
  const list = pickNews(rc, items, 3, ids);
  if (!list.length) return '';
  return `<div class="box"><div class="lbl">${rc.t.newsTeams}</div><div class="nwl">${list.map((x) => newsLink(rc, x)).join('')}</div><p class="note" style="margin-top:8px">${rc.t.newsNote}</p></div>`;
}

function flashCoupons(rc, pool) {
  if (!pool || pool.length < 2) return '';
  const sugg = suggestions(rc, pool, true);
  if (!sugg) return '';
  const t = rc.t;
  return `<div class="lbl" style="margin-top:6px">${t.flashCoupons}</div><div class="box"><p class="note" style="margin:0 0 8px">${t.flashCouponsP}</p><div class="sg">${sugg}</div><a class="more-btn" href="${rc.u('coupon')}">${t.flashCouponsBtn} <i aria-hidden="true">→</i></a></div>`;
}

function home(rc, { matches, bilan, pool: couponPool, coupons, news }) {
  const t = rc.t;
  const pool = matches.filter((m) => (m.prono && m.prono.visible !== false) || m.statut !== 'prevu');
  const body = `<div class="wrap">${C.sportTabs(rc)}${C.dayRail(rc, null)}${C.leagueRail(rc, null)}` +
    `<div class="layout"><div class="col"><div class="hero"><h1>${t.heroH1}</h1><p>${t.heroP}</p></div>` +
    `${bilanHero(rc, bilan)}${exploitsBox(rc, coupons)}${channelBanner(rc, 'accueil')}${adResponsive(rc, 'haut', 'ad-top')}${flashBlock(rc, pool)}${flashCoupons(rc, couponPool)}<h2 class="lbl" style="margin-top:6px">${t.theMatches}</h2>${pool.length ? groupedCards(rc, pool, newsStrip(rc, news)) + listEnd(rc, 'accueil-fin') : emptyDay(rc)}` +
    `</div>${sideColumn(rc, { bilan })}</div></div>`;
  return {
    title: t.homeTitle, description: t.homeDesc, path: rc.u('home'), alternates: alts(rc, 'home'), body, active: 'football',
    ld: { '@context': 'https://schema.org', '@type': 'WebSite', name: rc.site.nom, url: C.url(rc, rc.u('home')), inLanguage: rc.lang },
  };
}

/** Page d'un jour (/football/aujourdhui, /en/football/today, /football/2026-10-18…). */
function day(rc, { jour, matches, bilan }) {
  const t = rc.t;
  const label = jour === rc.today ? t.dayLabelToday : jour === rc.tomorrow ? t.dayLabelTomorrow : t.dayLabelOther;
  const slug = rc.dayAliases[jour] || jour;
  const date = dateLongue(jour + 'T12:00:00Z', rc.lang);
  const body = `<div class="wrap">${C.sportTabs(rc)}${C.dayRail(rc, jour)}${C.leagueRail(rc, null)}<div class="layout"><div class="col"><div class="hero"><h1>${t.dayH1(esc(label))}</h1><p>${esc(t.dayP(date, matches.length))}</p></div>` +
    `${adResponsive(rc, 'haut', 'ad-top')}${matches.length ? listWithAds(rc, matches.map((m) => matchCard(rc, m))) + listEnd(rc, 'jour-fin') : emptyDay(rc)}</div>${sideColumn(rc, { bilan })}</div></div>`;
  return { title: t.dayTitle(label, date), description: t.dayDesc(date, matches.length), path: rc.u('day', slug), alternates: alts(rc, 'day', slug), body, active: 'football' };
}

/** Page d'un championnat. */
function league(rc, { league: lg, matches, results, bilanLigue }) {
  const t = rc.t;
  const nom = C.leagueLabel(rc, lg);
  const body = `<div class="wrap">${C.sportTabs(rc)}${C.leagueRail(rc, lg.slug)}<div class="layout"><div class="col"><div class="hero"><h1>${t.leagueH1(esc(nom))}</h1><p>${esc(t.leagueP(lg.pays || ''))}</p></div>` +
    `${adResponsive(rc, 'haut', 'ad-top')}${bilanLigue && bilanLigue.taux != null ? `<div class="box bil"><div class="big num">${pct(rc, bilanLigue.taux)}</div><div><p>${esc(t.leagueBilan(nom, bilanLigue.n))}</p></div></div>` : ''}` +
    `<h2 class="lbl">${t.upcoming}</h2>${matches.length ? groupedCards(rc, matches) : emptyDay(rc)}` +
    `${results.length ? `<h2 class="lbl" style="margin-top:8px">${t.lastResults}</h2>${results.map((m) => matchCard(rc, m)).join('')}` : ''}</div>${sideColumn(rc, {})}</div></div>`;
  return { title: t.leagueTitle(nom), description: t.leagueDesc(nom), path: rc.u('league', lg.slug), alternates: alts(rc, 'league', lg.slug), body, active: 'football' };
}

function probRows(rc, p) {
  const t = rc.t;
  const row = (l, v, c) => `<div class="row"><span>${l}</span><div class="tk"><i style="width:${v}%;background:${c}"></i></div><b class="num">${pct(rc, v)}</b></div>`;
  return row(t.pHome, p.probas['1'], 'var(--flash)') + row(t.pDraw, p.probas.N, '#6b7899') + row(t.pAway, p.probas['2'], 'var(--cy)') + row(t.pOver, p.plus25, 'var(--cy)') + row(t.pBtts, p.bttsOui, 'var(--cy)');
}

/** Texte rédigé dans la langue de la page (null si l'analyse anglaise n'existe pas encore). */
const textOf = (rc, p) => (p ? (rc.lang === 'en' ? p.texteEn || null : p.texte) : null);
const textSource = (rc, p) => (rc.lang === 'en' ? p.sourceTexteEn : p.sourceTexte);

/** Balisage SportsEvent (schema.org). */
function sportsEvent(rc, m) {
  const ev = {
    '@context': 'https://schema.org', '@type': 'SportsEvent', inLanguage: rc.lang,
    name: `${m.domicile.nom} – ${m.exterieur.nom}`, startDate: m.coupDEnvoi,
    eventStatus: m.statut === 'reporte' ? 'https://schema.org/EventPostponed' : 'https://schema.org/EventScheduled',
    sport: 'Football', url: C.url(rc, rc.u('match', m)),
    homeTeam: { '@type': 'SportsTeam', name: m.domicile.nom }, awayTeam: { '@type': 'SportsTeam', name: m.exterieur.nom },
    competitor: [{ '@type': 'SportsTeam', name: m.domicile.nom }, { '@type': 'SportsTeam', name: m.exterieur.nom }],
    organizer: { '@type': 'SportsOrganization', name: leagueName(rc, m) },
    location: { '@type': 'Place', name: (m.lieu && m.lieu.nom) || m.domicile.nom, address: (m.lieu && m.lieu.ville) || m.pays || '' },
  };
  const tx = textOf(rc, m.prono);
  if (tx) ev.description = tx.resume;
  return ev;
}

/** Données du match pour le navigateur (coupons) : marchés, libellés dans la langue de la page, matrice de scores. */
function matchJson(rc, m) {
  const p = m.prono;
  return {
    id: m.id, nom: titleOf(m), ligue: leagueName(rc, m), t: m.coupDEnvoi, u: rc.u('analysis', m),
    marches: p.marches.map((x) => ({ k: x.cle, l: betLabel(rc, m, x), f: famLabel(rc, x.famille), p: x.pct, r: x.fiabilite[0] })), matrice: p.matrice,
  };
}
const jsonScript = (id, obj) => `<script type="application/json" id="${id}">${JSON.stringify(obj).replace(/</g, '\\u003c')}</script>`;

const addBtn = (rc, m, mk) => `<button type="button" class="add" data-add="${esc(m.id)}|${esc(mk.cle)}" aria-pressed="false" aria-label="${esc(rc.t.addAria(betLabel(rc, m, mk)))}">＋</button>`;

/**
 * Plus de pronostics sur un match : les meilleurs paris de chaque famille (jusqu'à n), hors pronostic principal,
 * fiabilité moyenne ou haute et probabilité utile (ni douteuse, ni évidente). Classés par groupe d'affichage.
 */
const GROUPS = [['gMain', ['Résultat', 'Buts']], ['gHalf', ['Mi-temps', 'Handicap', 'Score']], ['gOther', ['Corners', 'Tirs', 'Cartons & fautes', 'Joueurs', 'Spéciaux']]];
function moreMarkets(p, n = 3) {
  const main = p.principal && p.principal.cle;
  const byFam = {};
  for (const x of p.marches || []) {
    if (x.cle === main || x.fiabilite === 'faible' || x.pct < 55 || x.pct >= coupon.MAX_USEFUL_PCT) continue;
    (byFam[x.famille] = byFam[x.famille] || []).push(x);
  }
  return GROUPS.map(([key, fams]) => ({ key, items: fams.filter((f) => byFam[f]).flatMap((f) => byFam[f].sort((a, b) => b.pct - a.pct).slice(0, n)) })).filter((g) => g.items.length);
}

/** Marchés solides à proposer d'un clic. */
function solidMarkets(p, n = 3) {
  const fam = new Set();
  const out = [];
  for (const m of p.marches.filter((x) => x.fiabilite !== 'faible' && x.pct >= 65 && x.pct < coupon.MAX_USEFUL_PCT).sort((a, b) => b.pct - a.pct)) {
    if (fam.has(m.famille)) continue;
    fam.add(m.famille); out.push(m);
    if (out.length === n) break;
  }
  return out;
}

function h2hTable(rc, h2h) {
  const t = rc.t;
  return `<div class="tw"><table class="t"><thead><tr><th>${t.date}</th><th>${t.fixture}</th><th>${t.score}</th></tr></thead><tbody>${h2h.map((x) => `<tr><td>${esc(x.date)}</td><td>${esc(x.dom)} – ${esc(x.ext)}</td><td class="num">${x.sd}-${x.se}</td></tr>`).join('')}</tbody></table></div>`;
}

/** Fiche match : verdict visible tout de suite, résumé du pronostic. */
function match(rc, { m, same, h2h, news }) {
  const t = rc.t;
  const p = m.prono;
  const path = rc.u('match', m);
  const done = m.statut === 'termine' && m.resultat;
  const titre = titleOf(m);
  const lgName = leagueName(rc, m);
  const verdict = p && p.visible !== false
    ? `<div class="big"><small>${t.ourPrediction}</small><b>${esc(pickLabel(rc, m))}</b></div><div><div class="gauge" role="img" aria-label="${esc(t.confLevel)} ${pct(rc, p.principal.confiance)}"><i style="width:${p.principal.confiance}%"></i></div><div class="gl"><span>${t.confLevel}${p.principal.basseConfiance ? t.lowConf : ''}</span><b class="num">${pct(rc, p.principal.confiance)}</b></div></div>`
    : `<div class="big"><small>${t.prediction}</small><b>${t.inPrep}</b></div>`;
  const result = done ? `<div class="score num">${m.resultat.scoreDom} - ${m.resultat.scoreExt} ${m.resultat.reussi === true ? `<span class="badge-ok">${t.success}</span>` : m.resultat.reussi === false ? `<span class="badge-ko">${t.failed}</span>` : ''}</div>` : '';
  const tx = textOf(rc, p);
  const analyse = tx ? `<div class="box an"><div class="lbl">${t.analysis}</div><span class="ai">${textSource(rc, p) === 'secours' ? t.aiFallback : t.aiBadge}</span><p>${esc(tx.analyse)}</p><ul class="kp">${tx.pointsCles.map((x) => `<li>${esc(x)}</li>`).join('')}</ul></div>` : '';
  const h2hHtml = h2h && h2h.length ? `<div class="box"><div class="lbl">${t.h2h}</div>${h2hTable(rc, h2h)}</div>` : '';
  const solid = p ? solidMarkets(p) : [];
  const moreGroups = p && p.visible !== false ? moreMarkets(p) : [];
  const opt = (x) => `<div class="op ${lvlClass(x.pct)}"><span>${esc(betLabel(rc, m, x))}<small>${esc(famLabel(rc, x.famille))}</small></span><b class="num">${pct(rc, x.pct)}</b>${addBtn(rc, m, x)}</div>`;
  // les groupes sont séparés par des annonces : native après le premier, bannière après le deuxième
  const between = [adSlot(rc, 'native', { cls: 'ad-nat' }), adResponsive(rc, 'fin', 'ad-end')];
  const morePronos = moreGroups.length ? `<div class="box moreb"><div class="lbl">${t.morePronos}</div><p class="note" style="margin:6px 0 4px">${t.morePronosP}</p>` +
    moreGroups.map((g, i) => `<h3 class="gh">${t[g.key]}</h3><div class="opts">${g.items.map(opt).join('')}</div>${i < moreGroups.length - 1 ? between[i] || '' : ''}`).join('') +
    `<a class="more-btn" href="${rc.u('analysis', m)}">${t.moreAnalysisBtn} <i aria-hidden="true">→</i></a></div>` : '';
  const addBox = morePronos;
  const others = same.filter((x) => x.id !== m.id).slice(0, 4);
  const side = sideColumn(rc, {
    afl: 'fiche',
    extra: others.length ? `<div class="box"><div class="lbl">${t.otherMatches}</div><div class="oml">${others.map((x) => `<a class="om" href="${rc.u('match', x)}"><b>${esc(titleOf(x))}</b><span class="pk">${esc(x.prono ? pickLabel(rc, x) : t.inPrep)}</span><span class="more sm">${t.moreDetails} <i aria-hidden="true">›</i></span></a>`).join('')}</div></div>` : '',
  });
  const wa = `https://wa.me/?text=${encodeURIComponent(`${t.waMatch(titre, p ? `${pickLabel(rc, m)} (${pct(rc, p.principal.confiance)})` : t.prediction)} ${C.url(rc, path)}`)}`;
  const body = `<div class="wrap"><nav class="crumb" aria-label="${esc(t.crumb)}"><a href="${rc.u('day', 'aujourdhui')}">Football</a> › <a href="${rc.u('league', m.leagueSlug)}">${esc(lgName)}</a> › ${esc(titre)}</nav>` +
    `<div class="layout"><div class="col"><div class="vd"><h1>${crest(m.domicile, true)}<span>${esc(m.domicile.nom)}</span><span class="vs">${t.vs}</span><span>${esc(m.exterieur.nom)}</span>${crest(m.exterieur, true)}</h1>` +
    `<div class="meta">${esc(lgName)}${m.journee ? ` · ${esc(t.matchday(m.journee))}` : ''} · ${esc(dateLongue(m.coupDEnvoi, rc.lang))} · ${timeEl(rc, m.coupDEnvoi)}</div>${result}${verdict}</div>` +
    `<div class="follow" data-follow="${esc(m.domicile.teamId)}|${esc(m.exterieur.teamId)}" data-names="${esc(m.domicile.nomCourt)}|${esc(m.exterieur.nomCourt)}" hidden><small>${t.followLbl}</small></div>` +
    `${adResponsive(rc, 'verdict', 'ad-verdict')}` +
    (p ? `<a class="det" href="${rc.u('analysis', m)}"><div><b>${t.seeAnalysis}</b><span>${esc(t.seeAnalysisSub(p.marches.length))}</span></div><i>→</i></a>` : '') +
    (p && p.visible !== false ? `<div class="box"><div class="lbl">${t.probsTitle}</div><div class="pb">${probRows(rc, p)}</div><p class="note" style="margin-top:12px">${t.likelyScore}${colon(rc)} <b style="color:var(--tx)">${esc(p.scoreProbable)}</b></p></div>` : '') +
    `${analyse}${adSlot(rc, 'fiche_native', { cls: 'ad-nat' })}${h2hHtml}${aflCard(rc, 'fiche', 0)}${addBox}${matchNews(rc, news, m)}${partnerCard(rc, 'fiche')}` +
    `<div class="sh"><a class="wa" href="${wa}" target="_blank" rel="noopener">${t.shareWa}</a><button type="button" data-copy="${esc(C.url(rc, path))}">${t.copyLink}</button></div>` +
    `<p class="note">${t.matchDisclaimer}</p></div>${side}</div></div>` +
    (p ? jsonScript('pf-match', matchJson(rc, m)) : '');
  return {
    title: t.matchTitle(titre, lgName, dateCourte(m.coupDEnvoi, rc.lang)),
    description: tx ? t.matchDescIa(tx.resume, titre) : t.matchDesc(titre, lgName, dateLongue(m.coupDEnvoi, rc.lang)),
    path, alternates: alts(rc, 'match', m), body, ld: sportsEvent(rc, m), active: 'football',
  };
}

function cmpRow(rc, r) {
  const max = Math.max(r.dom, r.ext, 0.01) * 1.15;
  const w = (v) => Math.round((v / max) * 100);
  const f = (v) => (Number.isInteger(v) ? String(v) : fr(v, 1, rc.lang));
  return `<div class="cmp"><span class="n">${esc(rc.t.cmp[r.cle] || r.label)}</span><b class="num">${f(r.dom)}</b><div class="dual"><span><i style="width:${w(r.dom)}%;background:var(--flash)"></i></span><span><i style="width:${w(r.ext)}%;background:var(--cy)"></i></span></div><b class="num">${f(r.ext)}</b></div>`;
}

function formList(rc, recent) {
  const t = rc.t;
  const rows = recent.slice().sort((a, b) => (a.date < b.date ? 1 : -1)).slice(0, 5);
  if (!rows.length) return `<p class="note">${t.noHistory}</p>`;
  const map = rc.lang === 'en' ? { V: 'W', N: 'D', D: 'L' } : { V: 'V', N: 'N', D: 'D' };
  return `<div class="fl">${rows.map((e) => { const r = e.gf > e.ga ? 'V' : e.gf === e.ga ? 'N' : 'D'; return `<div><i class="${r}">${map[r]}</i><span>${e.venue === 'home' ? t.homeShort : t.awayShort} vs ${esc(e.opp)}${colon(rc)} ${e.gf}-${e.ga}</span><em>${esc(e.date.slice(0, 10))}</em></div>`; }).join('')}</div>`;
}

/** Coupons proposés (Prudent 2, Équilibré 3, Audacieux 5) à partir d'un ensemble de matchs. */
function suggestions(rc, pool, withNames) {
  const t = rc.t;
  const poolMap = {};
  const byId = {};
  for (const x of pool) { byId[x.id] = x; poolMap[x.id] = x.prono.marches.map((mk) => ({ key: mk.cle, libelle: mk.libelle, famille: mk.famille, pct: mk.pct, fiabilite: mk.fiabilite })); }
  return [[2, t.prudent], [3, t.balanced], [5, t.bold]].map(([n, nom]) => {
    const sel = coupon.suggest(poolMap, n);
    if (sel.length < 2) return '';
    const pr = coupon.couponProbability(sel.map((s) => ({ matchId: s.matchId, key: s.key, pct: s.pct })), null).prob;
    const lab = (s) => { const m = byId[s.matchId]; const l = betLabel(rc, m, { cle: s.key, libelle: s.libelle }); return withNames ? `${titleOf(m)}${colon(rc)} ${l}` : l; };
    const hash = esc(sel.map((s) => s.matchId + '|' + s.key).join(','));
    const ids = [...new Set(sel.map((x) => x.matchId))];
    const details = ids.map((id) => `<a href="${rc.u('analysis', byId[id])}">${esc(titleOf(byId[id]))} <i aria-hidden="true">›</i></a>`).join('');
    return `<div class="sgi"><a href="${rc.u('coupon')}#${hash}" data-sug="${hash}"><b>${nom} · ${sel.length} ${t.selections}</b><span>${esc(sel.map(lab).join(' · '))}</span><em class="num">${pct(rc, Math.round(pr * 100))}</em></a><div class="sgd"><small>${t.moreDetails}${colon(rc)}</small>${details}</div></div>`;
  }).join('');
}

/** Page « analyse complète » : tout pour préparer un coupon. */
function details(rc, { m, formH, formA, h2h, rates, pool }) {
  const t = rc.t;
  const p = m.prono;
  const path = rc.u('analysis', m);
  const titre = titleOf(m);
  const lgName = leagueName(rc, m);
  const byFam = {};
  for (const x of p.marches) (byFam[x.famille] = byFam[x.famille] || []).push(x);
  const fams = FAMILLES_ORDRE.filter((f) => byFam[f]);
  const famSection = (f) => `<section class="fam" data-fam="${esc(famLabel(rc, f))}"><h3>${esc(famLabel(rc, f))}</h3>${byFam[f].sort((a, b) => b.pct - a.pct).map((x) => { const rate = rates && rates[x.cle.replace(/[.:]/g, '_')]; return `<div class="fr"><span>${esc(betLabel(rc, m, x))}${rate ? ` <small class="note">${esc(t.realOn(rate.reel, rate.n))}</small>` : ''}</span><b class="num ${lvlClass(x.pct)}">${pct(rc, x.pct)}</b><span class="pill ${FIAB_CLS[x.fiabilite]}">${t.fiab[x.fiabilite]}</span>${addBtn(rc, m, x)}</div>`; }).join('')}</section>`;
  // résultat et buts d'abord ; le reste (mi-temps, handicap, score, corners, tirs, cartons, spéciaux) derrière « Voir les paris avancés »,
  // avec en tête l'annonce la plus rémunératrice. Le contenu reste dans la page (balise details) : lisible sans JavaScript et par les moteurs.
  const MAIN_FAMS = ['Résultat', 'Buts'];
  const mainHtml = fams.filter((f) => MAIN_FAMS.includes(f)).map(famSection).join('');
  const advFams = fams.filter((f) => !MAIN_FAMS.includes(f));
  const advHtml = advFams.length ? `<details class="adv" id="pf-adv"><summary><b>${t.advSummary}</b><small>${t.advHint}</small></summary>${adResponsive(rc, 'avance', 'ad-avance')}${advFams.map(famSection).join('')}</details>` : '';
  const famHtml = mainHtml + advHtml;
  const toc = Object.entries(t.tocItems);
  const tocLinks = toc.map(([id, l]) => `<a href="#d-${id}">${l}</a>`).join('');
  const tocm = toc.map(([id, l]) => `<a class="chip" href="#d-${id}">${l}</a>`).join('');
  const sugg = suggestions(rc, pool, false);
  const cal = p.marches.filter((x) => rates && rates[x.cle.replace(/[.:]/g, '_')]).slice(0, 6);
  const calHtml = cal.length ? `<div class="tw"><table class="t"><thead><tr><th>${t.bet}</th><th>${t.announced}</th><th>${t.real}</th><th>${t.matches}</th></tr></thead><tbody>${cal.map((x) => { const r = rates[x.cle.replace(/[.:]/g, '_')]; return `<tr><td>${esc(betLabel(rc, m, x))}</td><td class="num">${pct(rc, r.annonce)}</td><td class="num">${pct(rc, r.reel)}</td><td class="num">${r.n}</td></tr>`; }).join('')}</tbody></table></div>`
    : `<p class="note" style="margin-top:8px">${t.notEnough} <a href="${rc.u('bilan')}" style="color:var(--cy)">${t.navBilan}</a>.</p>`;
  const sec = (id, title, inner) => `<div class="box dsec" id="d-${id}"><div class="lbl">${title}</div>${inner}</div>`;
  const body = `<div class="wrap"><nav class="crumb" aria-label="${esc(t.crumb)}"><a href="${rc.u('day', 'aujourdhui')}">Football</a> › <a href="${rc.u('league', m.leagueSlug)}">${esc(lgName)}</a> › <a href="${rc.u('match', m)}">${esc(titre)}</a> › ${t.fullAnalysis}</nav>` +
    `<div class="layout"><div class="col"><div class="tocm" aria-label="${esc(t.toc)}">${tocm}</div>` +
    `<div class="dh dsec" id="d-resume"><h1>${t.detH1(esc(titre))}</h1><div class="strip"><div><span class="k">${t.prediction}</span><b style="color:var(--flash)">${esc(pickLabel(rc, m))}</b></div><div><span class="k">${t.confidence}</span><b class="num" style="color:var(--ok)">${pct(rc, p.principal.confiance)}</b></div><div><span class="k">${t.likely}</span><b class="num">${esc(p.scoreProbable)}</b></div><div><span class="k">${t.kickoff}</span><b class="num">${esc(dateCourte(m.coupDEnvoi, rc.lang))} · ${timeEl(rc, m.coupDEnvoi)}</b></div></div>` +
    `<p class="note" style="margin-top:8px">${t.detIntro}</p></div>` +
    `${adResponsive(rc, 'verdict', 'ad-verdict')}` +
    sec('paris', t.allBets, `<p class="note" style="margin:8px 0 10px">${t.allBetsP}</p><div class="mk" id="pf-fams" hidden></div>${famHtml}<p class="note" style="margin-top:10px">${t.reliabilityNote}</p>`) +
    adSlot(rc, 'fiche_native', { cls: 'ad-nat' }) +
    (p.comparatif && p.comparatif.length ? sec('stats', t.compare, `<p class="note" style="margin:8px 0 2px">${t.compareP(esc(m.domicile.nomCourt), esc(m.exterieur.nomCourt))}</p>${p.comparatif.map((r) => cmpRow(rc, r)).join('')}`) : '') +
    sec('forme', t.form, `<div class="two"><div><b style="font-family:var(--fd);font-size:18px">${esc(m.domicile.nomCourt)} · ${t.last5}</b>${formList(rc, formH)}</div><div><b style="font-family:var(--fd);font-size:18px">${esc(m.exterieur.nomCourt)} · ${t.last5}</b>${formList(rc, formA)}</div></div>`) +
    aflCard(rc, 'details', 0) +
    (h2h && h2h.length ? sec('h2h', t.h2h, h2hTable(rc, h2h)) : '') +
    sec('fiab', t.ourResults, `<p class="note" style="margin:8px 0">${t.ourResultsP}</p>${calHtml}`) +
    `${adResponsive(rc, 'haut', 'ad-top')}` +
    (sugg ? sec('coupon', t.readyCoupons, `<div class="sg">${sugg}</div><p class="note" style="margin-top:8px">${t.readyCouponsP}</p><a class="more-btn" href="${rc.u('coupon')}">${t.flashCouponsBtn} <i aria-hidden="true">→</i></a>`) : '') +
    sec('avant', t.beforeValidate, `<ul class="ck">${t.checklist.map((x) => `<li>${esc(x)}</li>`).join('')}<li>${esc(t.checklistLast)} <a href="${rc.u('legal', 'jeu-responsable')}" style="color:var(--cy)">${t.responsible}</a>.</li></ul>`) +
    `<div class="sh"><a class="wa" href="https://wa.me/?text=${encodeURIComponent(`${t.waAnalysis(titre)} ${C.url(rc, path)}`)}" target="_blank" rel="noopener">${t.shareAnalysis}</a><button type="button" data-copy="${esc(C.url(rc, path))}">${t.copyLink}</button></div>` +
    `<p class="note">${t.detDisclaimer}</p></div>` +
    `<aside class="side"><div class="sticky"><div class="box toc"><div class="lbl">${t.toc}</div><div style="margin-top:8px">${tocLinks}</div></div>${adSlot(rc, 'colonne_rect', { cls: 'ad-rect', variant: 'dk' })}${adSlot(rc, 'colonne_tall', { cls: 'ad-tall', variant: 'dk' })}</div></aside></div></div>` +
    jsonScript('pf-match', matchJson(rc, m));
  return { title: t.detTitle(titre), description: t.detDesc(titre, lgName, p.marches.length), path, alternates: alts(rc, 'analysis', m), body, ld: sportsEvent(rc, m), active: 'football' };
}

/** Bilan public : taux de réussite automatique. */
const { safeKey: learnKey } = require('../engine/learn');

/** Bloc « Ce que l'IA a appris » : corrections actuelles du moteur, en langage simple. */
function learningBox(rc, L) {
  if (!L) return '';
  const t = rc.t;
  if (!L.actif) return `<div class="box"><div class="lbl">${t.learnTitle}</div><p class="note" style="margin-top:8px">${esc(t.learnWait(L.suivis || 0, L.seuil))}</p></div>`;
  const famName = (k) => FAMILLES_ORDRE.find((f) => learnKey(f) === k) || String(k).replace(/_/g, ' ');
  const lines = L.familles.map((f) => t.learnFam(famLabel(rc, famName(f.nom)), f.ecart));
  if (L.buts) lines.push(t.learnGoals(L.buts.domicile, L.buts.exterieur));
  return `<div class="box"><div class="lbl">${t.learnTitle}</div><p class="note" style="margin:8px 0">${t.learnIntro}</p>` +
    (lines.length ? `<ul class="ck">${lines.map((x) => `<li>${esc(x)}</li>`).join('')}</ul>` : `<p>${esc(t.learnNone)}</p>`) + '</div>';
}

const LEVEL_KEY = { prudent: 'prudent', equilibre: 'balanced', audacieux: 'bold' };
const STATUS_ICON = { gagne: '✅', perdu: '❌', ouvert: '•', annule: '↺' };

/** Un coupon archivé : niveau, probabilité annoncée, sélections avec leur résultat. */
function archivedCoupon(rc, c) {
  const t = rc.t;
  const stLabel = { gagne: t.couponWon, perdu: t.couponLost, ouvert: t.couponOpen, annule: t.couponVoid }[c.statut];
  const lines = c.selections.map((s) => {
    const m = { domicile: { nomCourt: s.dom }, exterieur: { nomCourt: s.ext } };
    const icon = s.ok === true ? '✅' : s.ok === false ? '❌' : '•';
    return `<li><span aria-hidden="true">${icon}</span><a href="${rc.u('match', s)}"><b>${esc(s.titre)}</b><em>${esc(betLabel(rc, m, { cle: s.key, libelle: s.libelle }))}</em></a></li>`;
  }).join('');
  return `<div class="ac ac-${c.statut}"><div class="ac-h"><b>${esc(t[LEVEL_KEY[c.nom]] || c.nom)} · ${c.selections.length} ${t.selections}</b><span class="pill ${c.statut === 'gagne' ? 'g' : c.statut === 'perdu' ? 'r' : ''}">${STATUS_ICON[c.statut]} ${esc(stLabel)}</span></div>` +
    `<small>${esc(t.couponOf(dateCourte(c.jour + 'T12:00:00Z', rc.lang)))} · ${esc(t.couponProb(Math.round(c.prob * 100)))}</small><ul class="al">${lines}</ul></div>`;
}

/** Accueil : derniers coupons gagnants, uniquement s'il y en a eu récemment, avec le taux global à côté. */
function exploitsBox(rc, coupons) {
  if (!coupons || !coupons.length) return '';
  const t = rc.t;
  const since = new Date(new Date(rc.now).getTime() - 14 * 864e5).toISOString().slice(0, 10);
  const wins = coupons.filter((c) => c.statut === 'gagne' && c.jour >= since).slice(0, 3);
  if (!wins.length) return '';
  const s = summarizeCoupons(coupons);
  return `<div class="lbl" style="margin-top:6px">${t.exploitTitle}</div><div class="box"><div class="acs">${wins.map((c) => archivedCoupon(rc, c)).join('')}</div>` +
    `<p class="note" style="margin:10px 0 8px">${esc(t.exploitP(s.gagnes, s.n, s.taux, 30))}</p><a class="more-btn" href="${rc.u('bilan')}#coupons">${t.exploitBtn} <i aria-hidden="true">→</i></a></div>`;
}

/** Bilan : résultats par niveau puis tous les coupons récents, gagnés ou perdus. */
function couponHistoryBox(rc, coupons) {
  if (!coupons || !coupons.length) return '';
  const t = rc.t;
  const s = summarizeCoupons(coupons);
  const tiers = ['prudent', 'equilibre', 'audacieux'].filter((k) => s.parNiveau[k] && s.parNiveau[k].n).map((k) => {
    const v = s.parNiveau[k];
    return `<div class="tr"><div class="row"><span>${esc(t[LEVEL_KEY[k]])}</span><div class="tk"><i style="width:${v.taux}%"></i></div><span class="num">${v.taux}\u00a0%</span></div><small>${esc(t.couponTierRow(v.gagnes, v.n, v.taux, v.annonce))}</small></div>`;
  }).join('');
  return `<div class="box" id="coupons"><div class="lbl">${t.couponHistTitle}</div><p class="note" style="margin:8px 0">${t.couponHistP}</p>` +
    (tiers ? `<div class="hb">${tiers}</div>` : `<p>${t.couponNoSettled}</p>`) + `<div class="acs" style="margin-top:12px">${coupons.slice(0, 24).map((c) => archivedCoupon(rc, c)).join('')}</div></div>`;
}

function bilan(rc, { s30, weeks, recent, leagues, familles, learning, coupons }) {
  const t = rc.t;
  const W = 560, H = 140;
  const pts = weeks.map((w) => w.taux);
  let svg = '';
  if (pts.length >= 2) {
    const lo = Math.max(0, Math.min(...pts, 50) - 5), hi = Math.min(100, Math.max(...pts, 70) + 5);
    const x = (i) => 30 + (i * (W - 60)) / (pts.length - 1);
    const y = (v) => H - 22 - ((v - lo) / (hi - lo)) * (H - 44);
    const path = pts.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(' ');
    svg = `<svg class="spark" viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(t.weeklyAria)}"><path d="${path} L${x(pts.length - 1)} ${H - 22} L${x(0)} ${H - 22} Z" fill="rgba(43,213,118,.12)"/><path d="${path}" fill="none" stroke="#2BD576" stroke-width="2.5" stroke-linejoin="round"/>` +
      pts.map((v, i) => `<circle cx="${x(i)}" cy="${y(v)}" r="${i === pts.length - 1 ? 5 : 3}" fill="${i === pts.length - 1 ? '#2BD576' : '#0F1626'}" stroke="#2BD576" stroke-width="2"/>`).join('') +
      weeks.map((w, i) => `<text x="${x(i)}" y="${H - 4}" text-anchor="middle" fill="#8E9AB8" font-size="11">${t.weekPrefix}${esc(w.semaine.split('-W')[1])}</text>`).join('') +
      `<text x="${x(pts.length - 1)}" y="${y(pts[pts.length - 1]) - 10}" text-anchor="middle" fill="#2BD576" font-size="13" font-weight="700">${pts[pts.length - 1]}%</text></svg>`;
  }
  const row = (l, v, n) => `<div class="row"><span>${esc(l)}</span><div class="tk"><i style="width:${v == null ? 0 : v}%"></i></div><span class="num">${v == null ? '–' : pct(rc, v)} · ${n}</span></div>`;
  const empty = !s30 || !s30.n;
  const body = `<div class="wrap"><div class="layout"><div class="col"><div class="hero"><h1>${t.bilanH1}</h1><p>${t.bilanP}</p></div>` +
    (empty ? `<div class="box"><p><b>${t.bilanEmptyB}</b></p><p class="note" style="margin-top:6px">${t.bilanEmptyP}</p></div>` :
      `<div class="kpis"><div class="kpi"><small>${t.kpiRate}</small><b class="g num">${pct(rc, s30.taux)}</b></div><div class="kpi"><small>${t.kpiN}</small><b class="num">${s30.n}</b></div><div class="kpi"><small>${t.kpiOk}</small><b class="g num">${s30.ok}</b></div><div class="kpi"><small>${t.kpiKo}</small><b class="r num">${s30.ko}</b></div></div>` +
      (svg ? `<div class="box"><div class="lbl">${t.weekly}</div>${svg}</div>` : '') + adResponsive(rc, 'haut', 'ad-top') +
      (s30.parConfiance.length ? `<div class="box"><div class="lbl">${t.byConf}</div><div class="hb">${s30.parConfiance.map((r) => row(t.confRange(r.k), r.taux, r.n)).join('')}</div><p class="note" style="margin-top:10px">${t.byConfNote}</p></div>` : '') +
      (leagues.length ? `<div class="box"><div class="lbl">${t.byLeague}</div><div class="hb">${leagues.map((l) => row(l.nom, l.taux, l.n)).join('')}</div></div>` : '') +
      (familles.length ? `<div class="box"><div class="lbl">${t.byFamily}</div><div class="hb">${familles.map((f) => `<div class="row"><span>${esc(famLabel(rc, f.k.replace(/_/g, ' ')))}</span><div class="tk"><i style="width:${f.taux == null ? 0 : f.taux}%"></i></div><span class="num">${esc(t.famRow(f.taux, f.annonce))}</span></div>`).join('')}</div><p class="note" style="margin-top:10px">${t.byFamilyNote}</p></div>` : '')) +
    couponHistoryBox(rc, coupons) + learningBox(rc, learning) +
    (recent.length ? `<div class="box"><div class="lbl">${t.lastResults}</div><div class="rl">${recent.map((m) => `<a href="${rc.u('match', m)}"><span>${m.resultat.reussi === true ? '✅' : m.resultat.reussi === false ? '❌' : '•'}</span><span>${esc(m.domicile.nomCourt)} ${m.resultat.scoreDom}-${m.resultat.scoreExt} ${esc(m.exterieur.nomCourt)}<br><em>${t.ourPick}${colon(rc)} ${esc(m.prono ? pickLabel(rc, m) : '–')}</em></span><em>${esc(dateCourte(m.coupDEnvoi, rc.lang))}</em><i class="chev" aria-hidden="true">›</i></a>`).join('')}</div></div>` : '') +
    `</div>${sideColumn(rc, {})}</div></div>`;
  return { title: t.bilanTitle, description: t.bilanDesc, path: rc.u('bilan'), alternates: alts(rc, 'bilan'), body, active: 'bilan' };
}

/** Page coupon : composition côté navigateur, avec coupons proposés rendus côté serveur. */
function couponPage(rc, { pool }) {
  const t = rc.t;
  const sugg = suggestions(rc, pool, true);
  const data = pool.slice(0, 16).map((m) => ({
    id: m.id, nom: titleOf(m), ligue: leagueName(rc, m), t: m.coupDEnvoi, slug: rc.u('analysis', m),
    marches: m.prono.marches.filter((x) => x.fiabilite !== 'faible' && x.pct >= 50 && x.pct < 97).map((x) => ({ k: x.cle, l: betLabel(rc, m, x), f: famLabel(rc, x.famille), p: x.pct, r: x.fiabilite[0] })),
    matrice: m.prono.matrice,
  }));
  const body = `<div class="wrap"><div class="layout"><div class="col"><div class="hero"><h1>${t.couponH1}</h1><p>${t.couponP}</p></div>${adResponsive(rc, 'haut', 'ad-top')}` +
    `<div class="box"><div class="lbl">${t.proposed}</div><div class="sg">${sugg || `<p class="note">${t.proposedEmpty}</p>`}</div><p class="note" style="margin-top:8px">${t.neverWeak}</p></div>` +
    `${adResponsive(rc, 'fin', 'ad-end')}${channelBanner(rc, 'coupon')}` +
    `<div id="pf-coupon"><noscript><div class="box"><p>${t.noJs}</p></div></noscript></div>${adSlot(rc, 'fiche_native', { cls: 'ad-nat' })}<p class="note">${t.couponDisclaimer}</p></div>` +
    `<aside class="side"><div class="sticky"><div class="cp" id="pf-cpanel"></div>${adSlot(rc, 'colonne_rect', { cls: 'ad-rect', variant: 'dk' })}${aflCard(rc, 'coupon', 0)}</div></aside></div></div>${jsonScript('pf-pool', data)}`;
  return { title: t.couponTitle, description: t.couponDesc, path: rc.u('coupon'), alternates: alts(rc, 'coupon'), body, active: 'coupon' };
}

function notFound(rc) {
  const t = rc.t;
  const body = `<div class="wrap"><div class="layout"><div class="col"><div class="hero"><h1>${t.nfH1}</h1><p>${t.nfP}</p></div><div class="sh"><a class="btn" href="${rc.u('day', 'aujourdhui')}">${t.nfToday}</a><a class="btn sec" href="${rc.u('bilan')}">${t.navBilan}</a></div></div></div></div>`;
  return { title: t.nfTitle, description: t.nfP, path: rc.u('404'), body, noindex: true };
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

module.exports = { home, day, league, match, details, bilan, couponPage, notFound, topFlash, weeklyRates, solidMarkets, moreMarkets, matchJson, FAMILLES_ORDRE, labels };
