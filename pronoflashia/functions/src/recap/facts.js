'use strict';
// « Le point foot » : les faits donnés à l'IA. Rien d'autre n'a le droit d'apparaître dans l'article.
// Deux sources légitimes : NOS données (résultats, pronostics, bilan, matchs à venir) et les informations de presse
// réduites à ce que nous avons le droit de reprendre (nom du site, lien, informations factuelles déjà extraites : absence, suspension, retour, entraîneur).
// Les titres de presse servent de contexte, jamais de texte à recopier.

const { pickLabel } = require('../render/components');
const { dateLongue, heure } = require('../util/format');
const { isFragile } = require('../engine/fragility');

const titleOf = (m) => `${m.domicile.nomCourt} – ${m.exterieur.nomCourt}`;

/**
 * Rassemble les faits de la dernière journée. window : heures de recul pour les résultats et l'actualité (30 par défaut).
 * Renvoie { jour, results[], upcoming[], news[], bilan:{n, ok}, sources[] }.
 */
async function gatherFacts(db, now, hours = 30) {
  const from = new Date(now.getTime() - hours * 3600e3).toISOString();
  const to = new Date(now.getTime() + hours * 3600e3).toISOString();
  const snap = await db.collection('matches').where('coupDEnvoi', '>=', from).where('coupDEnvoi', '<=', to).get();
  const all = snap.docs.map((d) => d.data()).filter((m) => m.statut !== 'reporte');
  const nowIso = now.toISOString();
  const results = all.filter((m) => m.statut === 'termine' && m.resultat && m.coupDEnvoi <= nowIso)
    .sort((a, b) => (a.coupDEnvoi < b.coupDEnvoi ? 1 : -1)).slice(0, 10);
  const upcoming = all.filter((m) => m.statut === 'prevu' && m.coupDEnvoi > nowIso && m.prono && m.prono.visible !== false && m.prono.principal)
    .sort((a, b) => (isFragile(a) - isFragile(b)) || (b.prono.principal.confiance - a.prono.principal.confiance)).slice(0, 6)
    .sort((a, b) => (a.coupDEnvoi < b.coupDEnvoi ? -1 : 1));
  const ns = (await db.collection('news').where('date', '>=', from).get()).docs.map((d) => d.data()).sort((a, b) => (a.date < b.date ? 1 : -1));
  const seen = new Set();
  const news = [];
  for (const n of ns) {
    const k = n.titre.toLowerCase().slice(0, 50);
    if (seen.has(k)) continue;
    seen.add(k);
    news.push(n);
    if (news.length >= 14) break;
  }
  const judged = results.filter((m) => m.resultat.reussi != null && m.prono && m.prono.principal);
  return { jour: now.toISOString().slice(0, 10), now, results, upcoming, news, bilan: { n: judged.length, ok: judged.filter((m) => m.resultat.reussi === true).length } };
}

/** Le contenu est-il suffisant pour publier un article honnête ? */
const enough = (f) => f.news.length >= 3 || f.results.length + f.upcoming.length >= 4;

/**
 * Lignes de faits (texte brut) pour la langue demandée. `corpus` = tout ce que l'article a le droit de nommer.
 */
function factLines(f, lang) {
  const en = lang === 'en';
  const rc = { lang };
  const lines = [];
  f.results.forEach((m, i) => {
    const pick = m.prono && m.prono.principal ? pickLabel(rc, m) : null;
    const ok = m.resultat.reussi === true ? (en ? 'succeeded' : 'réussi') : m.resultat.reussi === false ? (en ? 'missed' : 'raté') : null;
    lines.push(`R${i + 1}) ${m.domicile.nomCourt} ${m.resultat.scoreDom}-${m.resultat.scoreExt} ${m.exterieur.nomCourt} (${m.leagueNom})${pick && ok ? (en ? ` · our prediction “${pick}”: ${ok}` : ` · notre pronostic « ${pick} » : ${ok}`) : ''}.`);
  });
  f.upcoming.forEach((m, i) => {
    const p = m.prono.principal;
    lines.push(en
      ? `A${i + 1}) ${titleOf(m)} (${m.leagueNom}, ${heure(m.coupDEnvoi)} UTC) · our prediction “${pickLabel(rc, m)}” (confidence ${p.confiance}%)${isFragile(m) ? ' · limited data' : ''}.`
      : `A${i + 1}) ${titleOf(m)} (${m.leagueNom}, ${heure(m.coupDEnvoi)} UTC) · notre pronostic « ${pickLabel(rc, m)} » (confiance ${p.confiance} %)${isFragile(m) ? ' · données limitées' : ''}.`);
  });
  if (f.bilan.n >= 3) lines.push(en ? `B) Our track record on these matches: ${f.bilan.ok} succeeded out of ${f.bilan.n}.` : `B) Notre bilan sur ces matchs : ${f.bilan.ok} réussis sur ${f.bilan.n}.`);
  const infos = f.news.filter((n) => n.fait);
  infos.slice(0, 6).forEach((n, i) => {
    const x = n.fait, who = x.joueur ? ` ${en ? 'of' : 'de'} ${x.joueur}` : '';
    const label = en
      ? { absence: `absence${who} for ${x.equipe}`, suspension: `suspension${who} for ${x.equipe}`, retour: `return${who} for ${x.equipe}`, entraineur: `coaching change at ${x.equipe}` }[x.type]
      : { absence: `absence${who} côté ${x.equipe}`, suspension: `suspension${who} côté ${x.equipe}`, retour: `retour${who} côté ${x.equipe}`, entraineur: `changement d'entraîneur chez ${x.equipe}` }[x.type];
    lines.push(`I${i + 1}) ${en ? 'Reported' : 'Signalé'} : ${label} (${en ? 'according to' : 'selon'} ${n.source})${x.certitude === 'rumeur' ? (en ? ' — to be confirmed' : ' — à confirmer') : ''}.`);
  });
  // titres de presse : CONTEXTE à reformuler, jamais à recopier
  f.news.slice(0, 10).forEach((n, i) => lines.push(`P${i + 1}) [${n.source}] ${n.titre}`));
  return lines;
}

/** Sources citées en bas de l'article : site, titre (citation courte) et lien, sans doublon. */
function sourcesOf(f) {
  const seen = new Set();
  const out = [];
  for (const n of f.news.slice(0, 10)) {
    if (seen.has(n.lien)) continue;
    seen.add(n.lien);
    out.push({ nom: n.source, titre: n.titre.slice(0, 140), lien: n.lien, date: n.date });
  }
  return out;
}

/** Matchs à surveiller (calculés par nous, pas par l'IA) : les prochains matchs avec leur pronostic. */
function matchRefs(f) {
  return f.upcoming.map((m) => ({
    id: m.id, slug: m.slug, leagueSlug: m.leagueSlug, titre: titleOf(m), dom: m.domicile.nomCourt, ext: m.exterieur.nomCourt,
    cle: m.prono.principal.cle, pick: m.prono.principal.libelle, conf: m.prono.principal.confiance, coupDEnvoi: m.coupDEnvoi, fragile: isFragile(m),
  }));
}

function resultRefs(f) {
  return f.results.map((m) => ({
    id: m.id, slug: m.slug, leagueSlug: m.leagueSlug, titre: titleOf(m), dom: m.domicile.nomCourt, ext: m.exterieur.nomCourt,
    scoreDom: m.resultat.scoreDom, scoreExt: m.resultat.scoreExt, reussi: m.resultat.reussi == null ? null : m.resultat.reussi, cle: m.prono && m.prono.principal ? m.prono.principal.cle : null, pick: m.prono && m.prono.principal ? m.prono.principal.libelle : null,
  }));
}

/** Tout ce que l'article a le droit de nommer (équipes, championnats, joueurs signalés, sites). */
function corpusOf(f, lines) {
  const names = [];
  for (const m of f.results.concat(f.upcoming)) names.push(m.domicile.nom, m.domicile.nomCourt, m.exterieur.nom, m.exterieur.nomCourt, m.leagueNom);
  for (const n of f.news) names.push(n.source);
  return lines.concat(names).join(' ');
}

module.exports = { gatherFacts, enough, factLines, sourcesOf, matchRefs, resultRefs, corpusOf, titleOf, dateLongue };
