'use strict';
// Construit l'article « Le point foot » du jour : faits → IA (avec contrôle strict) → article de secours si l'IA échoue → enregistrement.

const F = require('./facts');
const { buildMessages } = require('./prompt');
const { validateRecap } = require('./validate');
const fallback = require('./fallback');
const { dateLongue } = require('../util/format');

/** Texte d'une langue : l'IA d'abord (chaque fournisseur, une relance), sinon l'article de secours. Renvoie { value, source, erreurs[] }. */
async function writeLang(f, lang, providers) {
  const lines = F.factLines(f, lang);
  const ctx = { lines, corpus: F.corpusOf(f, lines), titles: f.news.map((n) => n.titre), lang };
  const messages = buildMessages(lines, lang, dateLongue(f.now.toISOString(), lang));
  const erreurs = [];
  for (const p of providers || []) {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const v = validateRecap(await p.call(messages), ctx);
        if (v.ok) return { value: v.value, source: p.name, erreurs };
        erreurs.push(`${p.name} : ${v.errors.join(' ')}`);
      } catch (e) {
        erreurs.push(`${p.name} : ${String(e.message || e).slice(0, 80)}`);
        if (e.retryable) break;
      }
    }
  }
  return { value: fallback.build(f, lang), source: 'modele', erreurs };
}

const COLORS = [['#1b3a8a', '#0a1f4d'], ['#0f3d2e', '#0b2a22'], ['#5a1a1a', '#2a0a0a'], ['#4a1a6b', '#1f0a30'], ['#6b4a00', '#2e2000']];

/**
 * opts : { db, providers, now, force, hours }. Renvoie { publie: bool, raison?, id?, sources? }.
 * Un seul article par jour (identifiant jour-AAAA-MM-JJ) ; `force` le remplace.
 */
async function buildDailyRecap(opts) {
  const { db, providers } = opts;
  const now = opts.now || new Date();
  const jour = now.toISOString().slice(0, 10);
  const id = `jour-${jour}`;
  if (!opts.force && (await db.collection('articles').doc(id).get()).exists) return { publie: false, raison: 'déjà publié' };
  const f = await F.gatherFacts(db, now, opts.hours || 30);
  if (!F.enough(f)) return { publie: false, raison: 'pas assez de matière' };
  const [fr, en] = await Promise.all([writeLang(f, 'fr', providers), writeLang(f, 'en', providers)]);
  const first = f.upcoming[0] || f.results[0];
  const colors = first && first.domicile.couleurs && first.domicile.couleurs.length >= 2 ? first.domicile.couleurs.slice(0, 2) : COLORS[new Date(jour).getUTCDate() % COLORS.length];
  const doc = {
    id, slug: `point-foot-${jour}`, type: 'jour', jour, creeLe: now.toISOString(),
    source: { fr: fr.source, en: en.source }, fr: fr.value, en: en.value,
    sources: F.sourcesOf(f), matchs: F.matchRefs(f), resultats: F.resultRefs(f), bilan: f.bilan, couleurs: colors,
  };
  await db.collection('articles').doc(id).set(doc);
  return { publie: true, id, source: doc.source, erreurs: fr.erreurs.concat(en.erreurs), sources: doc.sources.length };
}

module.exports = { buildDailyRecap, writeLang };
