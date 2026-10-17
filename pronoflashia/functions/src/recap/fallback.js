'use strict';
// Article de secours « Le point foot » : construit sans IA, uniquement avec NOS données (résultats, pronostics, bilan) et les informations
// de presse déjà extraites (jamais les titres). Toujours exact ; moins vivant qu'un texte rédigé. Publié quand l'IA est indisponible ou refusée.

const { pickLabel } = require('../render/components');
const { dateLongue, heure } = require('../util/format');
const { isFragile } = require('../engine/fragility');

const pc = (lang, v) => (lang === 'en' ? `${v}%` : `${v} %`);

function build(f, lang) {
  const en = lang === 'en';
  const rc = { lang };
  const date = dateLongue(f.now.toISOString(), lang);
  const sections = [];
  const res = f.results.filter((m) => m.resultat);
  if (res.length) {
    const lines = res.slice(0, 6).map((m) => {
      const base = `${m.domicile.nomCourt} ${m.resultat.scoreDom}-${m.resultat.scoreExt} ${m.exterieur.nomCourt}`;
      if (m.resultat.reussi == null || !(m.prono && m.prono.principal)) return `${base}.`;
      const pick = pickLabel(rc, m);
      return en ? `${base} (our prediction “${pick}”: ${m.resultat.reussi ? 'succeeded' : 'missed'}).` : `${base} (notre pronostic « ${pick} » : ${m.resultat.reussi ? 'réussi' : 'raté'}).`;
    });
    sections.push({ titre: en ? 'The results' : 'Les résultats', texte: lines.join('\n') });
  }
  if (f.upcoming.length) {
    const lines = f.upcoming.slice(0, 5).map((m) => {
      const p = m.prono.principal;
      return en
        ? `${m.domicile.nomCourt} – ${m.exterieur.nomCourt} (${m.leagueNom}, ${heure(m.coupDEnvoi)} UTC): our prediction “${pickLabel(rc, m)}”, confidence ${pc(lang, p.confiance)}${isFragile(m) ? ', limited data' : ''}.`
        : `${m.domicile.nomCourt} – ${m.exterieur.nomCourt} (${m.leagueNom}, ${heure(m.coupDEnvoi)} UTC) : notre pronostic « ${pickLabel(rc, m)} », confiance ${pc(lang, p.confiance)}${isFragile(m) ? ', données limitées' : ''}.`;
    });
    sections.push({ titre: en ? 'Matches to watch' : 'Les matchs à suivre', texte: lines.join('\n') });
  }
  const infos = f.news.filter((n) => n.fait).slice(0, 5);
  if (infos.length) {
    const lines = infos.map((n) => {
      const x = n.fait, who = x.joueur ? ` ${en ? 'of' : 'de'} ${x.joueur}` : '';
      const label = en
        ? { absence: `absence${who} for ${x.equipe}`, suspension: `suspension${who} for ${x.equipe}`, retour: `return${who} for ${x.equipe}`, entraineur: `coaching change at ${x.equipe}` }[x.type]
        : { absence: `Absence${who} côté ${x.equipe}`, suspension: `Suspension${who} côté ${x.equipe}`, retour: `Retour${who} côté ${x.equipe}`, entraineur: `Changement d'entraîneur chez ${x.equipe}` }[x.type];
      return en ? `${label.charAt(0).toUpperCase() + label.slice(1)} reported by ${n.source}${x.certitude === 'rumeur' ? ' (to be confirmed)' : ''}.` : `${label} signalé par ${n.source}${x.certitude === 'rumeur' ? ' (à confirmer)' : ''}.`;
    });
    sections.push({ titre: en ? 'In the news' : 'Dans l\'actualité', texte: lines.join('\n') });
  }
  if (sections.length < 2) sections.push({ titre: en ? 'Our track record' : 'Notre bilan', texte: en ? 'Every prediction is recorded before the match and marked won or lost: the full track record is public.' : 'Chaque pronostic est enregistré avant le match puis marqué réussi ou raté : le bilan complet est public.' });
  const retenir = [];
  if (f.bilan.n >= 3) retenir.push(en ? `Our predictions on these matches: ${f.bilan.ok} succeeded out of ${f.bilan.n}.` : `Nos pronostics sur ces matchs : ${f.bilan.ok} réussis sur ${f.bilan.n}.`);
  if (f.upcoming[0]) retenir.push(en ? `Next up: ${f.upcoming[0].domicile.nomCourt} – ${f.upcoming[0].exterieur.nomCourt}.` : `À suivre : ${f.upcoming[0].domicile.nomCourt} – ${f.upcoming[0].exterieur.nomCourt}.`);
  if (infos.length) retenir.push(en ? `${infos.length} piece${infos.length > 1 ? 's' : ''} of team news reported by the press.` : `${infos.length} information${infos.length > 1 ? 's' : ''} d'équipe signalée${infos.length > 1 ? 's' : ''} par la presse.`);
  while (retenir.length < 3) retenir.push(en ? 'Every prediction is a probability, never a certainty.' : 'Un pronostic est une probabilité, jamais une certitude.');
  const nRes = res.length, nUp = f.upcoming.length;
  return {
    titre: en ? `Football roundup, ${date}` : `Le point foot du ${date}`,
    chapo: en ? `${nRes} result${nRes === 1 ? '' : 's'} and ${nUp} match${nUp === 1 ? '' : 'es'} to follow: here is the football day, with our predictions and the news reported by the press.` : `${nRes} résultat${nRes > 1 ? 's' : ''} et ${nUp} match${nUp > 1 ? 's' : ''} à suivre : voici la journée de football, avec nos pronostics et les infos signalées par la presse.`,
    sections: sections.slice(0, 4),
    retenir: retenir.slice(0, 4),
    notif: en
      ? { titre: 'The football day in one minute', corps: `${nRes} result${nRes === 1 ? '' : 's'}, ${nUp} match${nUp === 1 ? '' : 'es'} to watch and our predictions: tap to read.` }
      : { titre: 'La journée foot en une minute', corps: `${nRes} résultat${nRes > 1 ? 's' : ''}, ${nUp} match${nUp > 1 ? 's' : ''} à suivre et nos pronostics : touchez pour lire.` },
  };
}

module.exports = { build };
