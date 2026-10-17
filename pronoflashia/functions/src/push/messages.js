'use strict';
// Textes des notifications, construits uniquement à partir des chiffres du site (aucune IA, aucune promesse de gain).

const coupon = require('../shared/coupon');
const { pathFor } = require('../render/i18n');
const { pickLabel } = require('../render/components');
const { isFragile } = require('../engine/fragility');
const CL = require('../engine/couponLearn');

const NB = ' ';
const pc = (lang, v) => (lang === 'en' ? `${v}%` : `${v}${NB}%`);
const titreOf = (m) => `${m.domicile.nomCourt} – ${m.exterieur.nomCourt}`;
const withSource = (url, slot) => `${url}${url.includes('?') ? '&' : '?'}source=push&slot=${slot}`;
const LEVEL = { fr: { prudent: 'Prudent', equilibre: 'Équilibré', audacieux: 'Audacieux' }, en: { prudent: 'Cautious', equilibre: 'Balanced', audacieux: 'Bold' } };

/** Match mis en avant dans un coupon : celui dont la sélection est la plus probable. */
function vedette(sels) {
  const best = (sels || []).slice().sort((a, b) => (b.pct || 0) - (a.pct || 0))[0];
  return best ? (best.titre || (best.dom && best.ext ? `${best.dom} – ${best.ext}` : null)) : null;
}

/** Matin : les coupons archivés du jour. coupons : documents coupons_flash du jour. */
function matin(coupons, lang) {
  const list = coupons.filter((c) => c.statut === 'ouvert').sort((a, b) => a.n - b.n);
  if (!list.length) return null;
  const en = lang === 'en';
  const parts = list.map((c) => `${LEVEL[lang][c.nom]} ${c.n} ${en ? 'matches' : 'matchs'} ${pc(lang, Math.round(c.prob * 100))}`).join(' · ');
  const star = vedette(list[0].selections);
  const carte = { badge: en ? "Today's slips" : 'Coupons du jour', titre: star || '', lignes: list.map((c) => ({ l: `${LEVEL[lang][c.nom]} · ${c.n} ${en ? 'matches' : 'matchs'}`, v: pc(lang, Math.round(c.prob * 100)) })) };
  return en
    ? { carte, titre: `⚡ Today's slips${star ? `: ${star}` : ''}`, corps: `${parts} chance that everything wins.`, url: withSource(pathFor('en', 'coupon'), 'matin'), tag: 'pf-matin' }
    : { carte, titre: `⚡ Coupons du jour${star ? ` : ${star}` : ''}`, corps: `${parts} de chances que tout passe.`, url: withSource(pathFor('fr', 'coupon'), 'matin'), tag: 'pf-matin' };
}

/** Midi : le pronostic le plus confiant parmi les matchs à venir. */
function midi(matches, lang) {
  const top = matches.filter((m) => m.statut === 'prevu' && m.prono && m.prono.visible !== false && m.prono.principal && !m.prono.principal.basseConfiance && !isFragile(m))
    .sort((a, b) => b.prono.principal.confiance - a.prono.principal.confiance)[0];
  if (!top) return null;
  const pick = pickLabel({ lang }, top);
  const conf = pc(lang, top.prono.principal.confiance);
  const carte = { badge: lang === 'en' ? 'Pick of the day' : 'Pronostic du jour', titre: titreOf(top), lignes: [{ l: pick, v: conf }] };
  return lang === 'en'
    ? { carte, titre: '🔥 Most confident pick today', corps: `${titreOf(top)}: ${pick} (${conf}).`, url: withSource(pathFor('en', 'match', top), 'midi'), tag: 'pf-midi' }
    : { carte, titre: '🔥 Pronostic le plus confiant du jour', corps: `${titreOf(top)} : ${pick} (${conf}).`, url: withSource(pathFor('fr', 'match', top), 'midi'), tag: 'pf-midi' };
}

/** Soir : un coupon construit avec les matchs qui restent à jouer. */
function soir(matches, lang, learning) {
  const live = matches.filter((m) => m.statut === 'prevu' && m.prono && m.prono.visible !== false && m.prono.marches && !isFragile(m));
  const poolMap = {};
  for (const m of live) poolMap[m.id] = m.prono.marches.map((mk) => ({ key: mk.cle, libelle: mk.libelle, famille: mk.famille, pct: mk.pct, fiabilite: mk.fiabilite }));
  const sel = coupon.suggest(CL.applyToPool(poolMap, learning), 3); // probabilités corrigées par ce que l'IA a appris de ses coupons
  if (sel.length < 2) return null;
  const prob = Math.round(coupon.couponProbability(sel.map((s) => ({ matchId: s.matchId, key: s.key, pct: s.pct })), null).prob * 100);
  const rows = sel.map((x) => ({ pct: x.pct, titre: titreOf(live.find((m) => String(m.id) === String(x.matchId)) || live[0]) }));
  const star = vedette(rows);
  const carte = { badge: lang === 'en' ? "Tonight's slip" : 'Coupon du soir', titre: `${pc(lang, prob)} ${lang === 'en' ? 'chance that everything wins' : 'de chances que tout passe'}`, lignes: rows.map((x) => ({ l: x.titre, v: '' })) };
  return lang === 'en'
    ? { carte, titre: `🌙 Tonight's slip${star ? `: ${star}` : ''}`, corps: `${sel.length} bets on tonight's matches: ${pc(lang, prob)} chance that everything wins.`, url: withSource(pathFor('en', 'coupon'), 'soir'), tag: 'pf-soir' }
    : { carte, titre: `🌙 Coupon du soir${star ? ` : ${star}` : ''}`, corps: `${sel.length} paris sur les matchs de ce soir : ${pc(lang, prob)} de chances que tout passe.`, url: withSource(pathFor('fr', 'coupon'), 'soir'), tag: 'pf-soir' };
}

/** Alerte avant un match d'une équipe suivie. */
function equipe(m, lang) {
  const p = m.prono && m.prono.principal;
  const pick = p ? pickLabel({ lang }, m) : null;
  const base = lang === 'en'
    ? { titre: '🔔 Match of your teams', corps: `${titreOf(m)} starts soon.${pick ? ` Our pick: ${pick} (${pc(lang, p.confiance)}).` : ''}` }
    : { titre: '🔔 Match de vos équipes', corps: `${titreOf(m)} commence bientôt.${pick ? ` Notre pronostic : ${pick} (${pc(lang, p.confiance)}).` : ''}` };
  const carte = { badge: lang === 'en' ? 'Your teams' : 'Vos équipes', titre: titreOf(m), lignes: pick ? [{ l: pick, v: pc(lang, p.confiance) }] : [] };
  return Object.assign(base, { carte, url: withSource(pathFor(lang, 'match', m), 'equipe'), tag: `pf-eq-${m.id}` });
}

/** Gros match du jour (classico, choc entre grands clubs) : { m, classico }. */
function choc({ m, classico }, lang) {
  const p = m.prono && m.prono.visible !== false && m.prono.principal && !m.prono.principal.basseConfiance && !isFragile(m) ? m.prono.principal : null;
  const pick = p ? pickLabel({ lang }, m) : null;
  const en = lang === 'en';
  const carte = { badge: en ? (classico ? 'Classico' : 'Big match') : (classico ? 'Classico' : 'Gros match'), titre: titreOf(m), lignes: pick ? [{ l: pick, v: pc(lang, p.confiance) }] : [] };
  return en
    ? { carte, titre: `${classico ? '⚔️ Classico' : '🔥 Big match'}: ${titreOf(m)}`, corps: pick ? `Our pick: ${pick} (${pc(lang, p.confiance)}). Latest news and stats inside.` : 'Our analysis and the latest news are inside.', url: withSource(pathFor('en', 'match', m), 'choc'), tag: `pf-choc-${m.id}` }
    : { carte, titre: `${classico ? '⚔️ Classico' : '🔥 Gros match'} : ${titreOf(m)}`, corps: pick ? `Notre pronostic : ${pick} (${pc(lang, p.confiance)}). Les dernières infos et statistiques sont à l'intérieur.` : "Notre analyse et les dernières infos sont à l'intérieur.", url: withSource(pathFor('fr', 'match', m), 'choc'), tag: `pf-choc-${m.id}` };
}

/** Actu à la une : le texte vient de buzz.buildHook ; la page ouverte est la nôtre (extrait, source et lien). */
function actu(hook, news, lang) {
  return Object.assign({}, hook, { url: withSource(pathFor(lang, 'article', { slug: `info-${news.id}` }), 'actu') });
}

module.exports = { matin, midi, soir, equipe, choc, actu };
