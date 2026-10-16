'use strict';
// Textes des notifications, construits uniquement à partir des chiffres du site (aucune IA, aucune promesse de gain).

const coupon = require('../shared/coupon');
const { pathFor } = require('../render/i18n');
const { pickLabel } = require('../render/components');
const { isFragile } = require('../engine/fragility');

const NB = ' ';
const pc = (lang, v) => (lang === 'en' ? `${v}%` : `${v}${NB}%`);
const titreOf = (m) => `${m.domicile.nomCourt} – ${m.exterieur.nomCourt}`;
const withSource = (url, slot) => `${url}${url.includes('?') ? '&' : '?'}source=push&slot=${slot}`;
const LEVEL = { fr: { prudent: 'Prudent', equilibre: 'Équilibré', audacieux: 'Audacieux' }, en: { prudent: 'Cautious', equilibre: 'Balanced', audacieux: 'Bold' } };

/** Matin : les coupons archivés du jour. coupons : documents coupons_flash du jour. */
function matin(coupons, lang) {
  const list = coupons.filter((c) => c.statut === 'ouvert').sort((a, b) => a.n - b.n);
  if (!list.length) return null;
  const parts = list.map((c) => `${LEVEL[lang][c.nom]} ${pc(lang, Math.round(c.prob * 100))}`).join(' · ');
  return lang === 'en'
    ? { titre: "⚡ Today's slips", corps: `${parts} chance that everything wins.`, url: withSource(pathFor('en', 'coupon'), 'matin'), tag: 'pf-matin' }
    : { titre: '⚡ Coupons du jour', corps: `${parts} de chances que tout passe.`, url: withSource(pathFor('fr', 'coupon'), 'matin'), tag: 'pf-matin' };
}

/** Midi : le pronostic le plus confiant parmi les matchs à venir. */
function midi(matches, lang) {
  const top = matches.filter((m) => m.statut === 'prevu' && m.prono && m.prono.visible !== false && m.prono.principal && !m.prono.principal.basseConfiance && !isFragile(m))
    .sort((a, b) => b.prono.principal.confiance - a.prono.principal.confiance)[0];
  if (!top) return null;
  const pick = pickLabel({ lang }, top);
  const conf = pc(lang, top.prono.principal.confiance);
  return lang === 'en'
    ? { titre: '🔥 Most confident pick today', corps: `${titreOf(top)}: ${pick} (${conf}).`, url: withSource(pathFor('en', 'match', top), 'midi'), tag: 'pf-midi' }
    : { titre: '🔥 Pronostic le plus confiant du jour', corps: `${titreOf(top)} : ${pick} (${conf}).`, url: withSource(pathFor('fr', 'match', top), 'midi'), tag: 'pf-midi' };
}

/** Soir : un coupon construit avec les matchs qui restent à jouer. */
function soir(matches, lang) {
  const live = matches.filter((m) => m.statut === 'prevu' && m.prono && m.prono.visible !== false && m.prono.marches && !isFragile(m));
  const poolMap = {};
  for (const m of live) poolMap[m.id] = m.prono.marches.map((mk) => ({ key: mk.cle, libelle: mk.libelle, famille: mk.famille, pct: mk.pct, fiabilite: mk.fiabilite }));
  const sel = coupon.suggest(poolMap, 3);
  if (sel.length < 2) return null;
  const prob = Math.round(coupon.couponProbability(sel.map((s) => ({ matchId: s.matchId, key: s.key, pct: s.pct })), null).prob * 100);
  return lang === 'en'
    ? { titre: "🌙 Tonight's slip", corps: `${sel.length} bets on tonight's matches: ${pc(lang, prob)} chance that everything wins.`, url: withSource(pathFor('en', 'coupon'), 'soir'), tag: 'pf-soir' }
    : { titre: '🌙 Coupon du soir', corps: `${sel.length} paris sur les matchs de ce soir : ${pc(lang, prob)} de chances que tout passe.`, url: withSource(pathFor('fr', 'coupon'), 'soir'), tag: 'pf-soir' };
}

/** Alerte avant un match d'une équipe suivie. */
function equipe(m, lang) {
  const p = m.prono && m.prono.principal;
  const pick = p ? pickLabel({ lang }, m) : null;
  const base = lang === 'en'
    ? { titre: '🔔 Match of your teams', corps: `${titreOf(m)} starts soon.${pick ? ` Our pick: ${pick} (${pc(lang, p.confiance)}).` : ''}` }
    : { titre: '🔔 Match de vos équipes', corps: `${titreOf(m)} commence bientôt.${pick ? ` Notre pronostic : ${pick} (${pc(lang, p.confiance)}).` : ''}` };
  return Object.assign(base, { url: withSource(pathFor(lang, 'match', m), 'equipe'), tag: `pf-eq-${m.id}` });
}

module.exports = { matin, midi, soir, equipe };
