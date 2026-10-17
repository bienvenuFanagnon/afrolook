'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const F = require('../src/recap/facts');
const { validateRecap, unknownNames, copiedRun } = require('../src/recap/validate');
const { buildDailyRecap } = require('../src/recap/build');
const { buildRecaps } = require('../src/jobs/buildRecaps');
const { buildSample } = require('../dev/sample');
const { route } = require('../src/render/router');
const D = require('../src/render/data');
const { submitNewUrls } = require('../src/jobs/indexNow');

const NOW = new Date('2026-10-16T20:10:00Z');
const team = (id, nom, court) => ({ teamId: id, nom, nomCourt: court, couleurs: ['#123456', '#0a0a0a'] });
const base = (id, h, d, e, extra) => Object.assign({
  id, slug: `${d.court}-${e.court}-2026-10-16`.toLowerCase(), leagueSlug: 'ligue-1', leagueNom: 'Ligue 1', jour: '2026-10-16',
  domicile: team(d.id, d.nom, d.court), exterieur: team(e.id, e.nom, e.court), coupDEnvoi: `2026-10-16T${h}:00:00.000Z`,
}, extra);
const prono = (cle, libelle, conf) => ({ visible: true, principal: { cle, libelle, confiance: conf }, marches: [] });
const M = {
  om: { id: 81, nom: 'Olympique De Marseille', court: 'Marseille' }, ol: { id: 80, nom: 'Olympique Lyonnais', court: 'Lyon' },
  psg: { id: 85, nom: 'Paris Saint Germain', court: 'PSG' }, asm: { id: 91, nom: 'AS Monaco', court: 'Monaco' },
  nice: { id: 84, nom: 'OGC Nice', court: 'Nice' }, lens: { id: 98, nom: 'RC Lens', court: 'Lens' },
};

async function world(opts = {}) {
  const db = new FakeDb();
  await db.seed('matches', 'r1', base('r1', '15', M.om, M.ol, { statut: 'termine', resultat: { scoreDom: 2, scoreExt: 1, reussi: true, marches: {} }, prono: prono('res:1', '1N · Marseille ou nul', 66) }));
  await db.seed('matches', 'r2', base('r2', '17', M.psg, M.asm, { statut: 'termine', resultat: { scoreDom: 0, scoreExt: 0, reussi: false, marches: {} }, prono: prono('res:1', '1N · PSG ou nul', 72) }));
  await db.seed('matches', 'a1', base('a1', '21', M.nice, M.lens, { statut: 'prevu', prono: prono('res:1', '1N · Nice ou nul', 64) }));
  await db.seed('matches', 'a2', base('a2', '22', M.lens, M.om, { statut: 'prevu', prono: Object.assign(prono('res:2', '2 · Marseille', 58), { fragile: { raisons: ['echantillon'] } }) }));
  const mk = (i, titre, extra) => db.seed('news', `n${i}`, Object.assign({ id: `n${i}`, titre, lien: `https://exemple.invalid/n${i}`, source: i % 2 ? 'Foot Mercato' : 'Afrik-Foot', sourceId: 's', lang: 'fr', date: `2026-10-16T${String(10 + i).padStart(2, '0')}:00:00.000Z`, teamIds: [] }, extra));
  await mk(1, 'Marseille prépare la réception de Lens après la victoire contre Lyon', { fait: { equipeId: '81', equipe: 'Marseille', type: 'absence', joueur: 'Jean Dupont', certitude: 'confirme', methode: 'ia' } });
  await mk(2, 'Nice espère retrouver son attaquant pour affronter Lens');
  await mk(3, 'Monaco et le PSG se quittent sur un nul sans but au Parc');
  if (opts.few) { /* peu de matière */ }
  return db;
}

/** Fournisseur factice qui n'écrit que ce que les faits contiennent (noms et chiffres pris dans les lignes R et A). */
const smartProvider = (calls = []) => ({ name: 'workers-ai', call: async (messages) => {
  calls.push(messages);
  const en = /Facts:/.test(messages[1].content);
  const L = messages[1].content.split('\n');
  const r = /^R1\) (.+?) (\d+)-(\d+) (.+?) \((.+?)\)/.exec(L.find((x) => x.startsWith('R1)')));
  const a = /^A1\) (.+?) – (.+?) \((.+?),/.exec(L.find((x) => x.startsWith('A1)')));
  const j = en
    ? { titre: 'The football day: results and the matches to follow tonight', chapo: 'A busy day of football: here is what to remember from the results, from our predictions and from the matches that are coming up.',
      sections: [{ titre: 'The results', texte: `${r[1]} and ${r[4]} met in ${r[5]} and the final score was ${r[2]}-${r[3]}. It is a result we followed closely with our prediction, and it will keep supporters of these clubs talking for a while.` },
        { titre: 'Matches to follow', texte: `On the programme: ${a[1]} against ${a[2]} in ${a[3]}. Our prediction is a probability and never a certainty, and the press information remains to be confirmed on the match page of each team.` }],
      retenir: ['Every prediction is a probability, never a certainty.', 'The full track record is public on the site.', 'Press information is credited to its source.'], notif: { titre: 'The football day in a few lines', corps: 'Results, matches to follow and our predictions of the day: tap to read the roundup.' } }
    : { titre: 'Le point foot : les résultats du jour et les matchs à suivre ce soir', chapo: "Une journée de football bien remplie : voici ce qu'il faut retenir des résultats, de nos pronostics et des matchs qui arrivent.",
      sections: [{ titre: 'Les résultats', texte: `${r[1]} et ${r[4]} se sont affrontés en ${r[5]} et le score final est de ${r[2]}-${r[3]}. C'est un résultat que nous avons suivi de près avec notre pronostic, et il fera parler les supporters de ces clubs pendant un moment.` },
        { titre: 'Les matchs à suivre', texte: `Au programme : ${a[1]} reçoit ${a[2]} en ${a[3]}. Notre pronostic est une probabilité, jamais une certitude, et les informations de presse restent à confirmer sur la fiche du match de chaque équipe.` }],
      retenir: ['Un pronostic est une probabilité, jamais une certitude.', 'Le bilan complet est public sur le site.', 'Les informations de presse sont attribuées à leur source.'], notif: { titre: 'La journée foot en quelques lignes', corps: 'Résultats, matchs à suivre et nos pronostics du jour : touchez pour lire le point foot.' } };
  return JSON.stringify(j);
} });

test('faits : résultats, matchs à venir (fiables d\'abord), actualité dédoublonnée, bilan ; contenu suffisant ou non', async () => {
  const db = await world();
  const f = await F.gatherFacts(db, NOW);
  assert.equal(f.results.length, 2);
  assert.equal(f.upcoming.length, 2);
  assert.equal(f.upcoming[0].id, 'a1', 'le match à données limitées passe après');
  assert.deepEqual(f.bilan, { n: 2, ok: 1 });
  assert.equal(f.news.length, 3);
  assert.ok(F.enough(f));
  assert.equal(F.enough({ news: [], results: [{}], upcoming: [] }), false);
  const lines = F.factLines(f, 'fr');
  assert.ok(lines.some((l) => l.startsWith('R2) Marseille 2-1 Lyon (Ligue 1)') && l.includes('réussi')));
  assert.ok(lines.some((l) => l.startsWith('A1) Nice – Lens') && l.includes('confiance 64 %')));
  assert.ok(!lines.some((l) => l.startsWith('B)')), 'pas de bilan chiffré sous 3 matchs jugés');
  assert.ok(F.factLines(Object.assign({}, f, { bilan: { n: 3, ok: 2 } }), 'fr').some((l) => l.startsWith('B) Notre bilan sur ces matchs : 2 réussis sur 3')));
  assert.ok(lines.some((l) => l.includes('absence de Jean Dupont côté Marseille (selon Foot Mercato)')));
  assert.ok(lines.some((l) => l.startsWith('P1) [')));
  assert.match(F.factLines(f, 'en').join('\n'), /our prediction “1N · Marseille or draw”|our prediction “/);
  assert.equal(F.sourcesOf(f).length, 3);
});

const CTX = async () => { const f = await F.gatherFacts(await world(), NOW); const lines = F.factLines(f, 'fr'); return { lines, corpus: F.corpusOf(f, lines), titles: f.news.map((n) => n.titre), lang: 'fr' }; };
const GOOD = () => JSON.parse(JSON.stringify({ titre: 'Le point foot : les résultats du jour et les matchs à suivre ce soir', chapo: "Une journée de football bien remplie : voici ce qu'il faut retenir des résultats, de nos pronostics et des matchs qui arrivent.",
  sections: [{ titre: 'Les résultats', texte: "Marseille et Lyon se sont affrontés en Ligue 1 et le score final est de 2-1. C'est un résultat que nous avons suivi de près avec notre pronostic, et il fera parler les supporters de ces clubs." },
    { titre: 'Les matchs à suivre', texte: "Au programme : Nice reçoit Lens en Ligue 1. Notre pronostic est une probabilité, jamais une certitude, et les informations de presse restent à confirmer sur chaque fiche de match." }],
  retenir: ['Un pronostic est une probabilité, jamais une certitude.', 'Le bilan complet est public.', 'La presse est citée avec ses sources.'], notif: { titre: 'La journée foot en quelques lignes', corps: 'Résultats, matchs à suivre et nos pronostics du jour : touchez pour lire.' } }));

test('contrôle de l\'article de l\'IA : accepte un texte fidèle, refuse chiffre inventé, nom inventé, promesse, conseil de pari, titre recopié, mauvaise langue, structure', async () => {
  const ctx = await CTX();
  assert.equal(validateRecap(JSON.stringify(GOOD()), ctx).ok, true);
  const bad = (mut) => { const j = GOOD(); mut(j); return validateRecap(JSON.stringify(j), ctx); };
  assert.match(bad((j) => { j.sections[0].texte = j.sections[0].texte.replace('2-1', '5-3 et 78 %'); }).errors.join(), /chiffre_invente/);
  assert.match(bad((j) => { j.sections[0].texte += ' Kylian Mbappé a marqué un doublé.'; }).errors.join(), /nom_invente/);
  assert.match(bad((j) => { j.sections[1].texte += ' Ce coup est un gain garanti pour tous.'; }).errors.join(), /promesse_interdite/);
  assert.match(bad((j) => { j.sections[1].texte += ' Pariez sur Nice dès maintenant.'; }).errors.join(), /promesse|conseil_de_pari/);
  assert.match(bad((j) => { j.sections[1].texte = 'Marseille prépare la réception de Lens après la victoire contre Lyon et rien ne change vraiment pour la suite de la saison ici.'; }).errors.join(), /titre_recopie/);
  assert.match(bad((j) => { j.titre = 'The football day: results and the matches to follow tonight in detail'; j.chapo = 'A busy day of football with the results, our predictions and the matches that are coming up for fans.'; j.sections.forEach((s) => { s.texte = 'The match was played with the teams of the league and the score was seen by the fans of the clubs in the stadium during the game.'; s.titre = 'The match'; }); j.retenir = ['The team will play.', 'The match is on.', 'The fans are in.']; j.notif = { titre: 'The football day in a few lines', corps: 'The results and the matches of the day with our predictions: tap to read.' }; }).errors.join(), /pas_en_francais/);
  assert.match(bad((j) => { j.sections = [j.sections[0]]; }).errors.join(), /sections_nombre/);
  assert.match(bad((j) => { j.titre = 'Court'; }).errors.join(), /titre_longueur/);
  assert.match(bad((j) => { delete j.notif; }).errors.join(), /notif_longueur/);
  assert.equal(validateRecap('pas du json', ctx).errors[0], 'json_invalide');
  assert.deepEqual(unknownNames('Le match de Marseille contre Lens.', ' marseille lens '), []);
  assert.deepEqual(unknownNames('Le match de Marseille contre Zorglub.', ' marseille '), ['Zorglub']);
  assert.equal(copiedRun('Marseille prépare la réception de Lens après la victoire contre Lyon', ['Marseille prépare la réception de Lens après la victoire contre Lyon']) != null, true);
  assert.equal(copiedRun('Marseille reçoit Lens ce soir', ['Marseille prépare la réception de Lens après la victoire contre Lyon']), null);
});

test('rédaction du point foot : IA validée si fidèle, sinon article de secours exact ; un seul article par jour ; pas assez de matière → rien', async () => {
  const db = await world();
  const calls = [];
  const r = await buildDailyRecap({ db, providers: [smartProvider(calls)], now: NOW });
  assert.equal(r.publie, true);
  assert.deepEqual(r.source, { fr: 'workers-ai', en: 'workers-ai' });
  assert.equal(calls.length, 2, 'un appel par langue');
  const a = db.read('articles', 'jour-2026-10-16');
  assert.equal(a.slug, 'point-foot-2026-10-16');
  assert.match(a.fr.titre, /Le point foot/);
  assert.match(a.en.titre, /football day/);
  assert.equal(a.sources.length, 3);
  assert.ok(a.sources.every((s) => /^https:\/\//.test(s.lien) && s.nom));
  assert.equal(a.matchs[0].id, 'a1');
  assert.equal(a.resultats.length, 2);
  assert.equal(a.matchs.find((m) => m.id === 'a2').fragile, true);
  // un seul article par jour
  assert.equal((await buildDailyRecap({ db, providers: [smartProvider()], now: NOW })).raison, 'déjà publié');
  // IA qui invente : l'article de secours, exact, est publié à la place
  const db2 = await world();
  const liar = { name: 'workers-ai', call: async () => JSON.stringify(Object.assign(GOOD(), { chapo: 'Kylian Mbappé a marqué cinq buts et le PSG gagne 9-0 devant 88 000 spectateurs, un vrai exploit historique.' })) };
  const r2 = await buildDailyRecap({ db: db2, providers: [liar], now: NOW });
  assert.deepEqual(r2.source, { fr: 'modele', en: 'modele' });
  assert.ok(r2.erreurs.length >= 2);
  const b = db2.read('articles', 'jour-2026-10-16');
  assert.match(b.fr.titre, /^Le point foot du /);
  assert.ok(b.fr.sections.some((s) => s.texte.includes('Marseille 2-1 Lyon')));
  assert.ok(b.fr.sections.some((s) => s.texte.includes('PSG 0-0 Monaco')));
  assert.ok(!JSON.stringify(b).includes('Mbappé'));
  // IA en panne (quota) : repli aussi
  const down = { name: 'workers-ai', call: async () => { throw Object.assign(new Error('quota'), { retryable: true }); } };
  assert.equal((await buildDailyRecap({ db: await world(), providers: [down], now: NOW })).source.fr, 'modele');
  // pas assez de matière
  const empty = new FakeDb();
  await empty.seed('matches', 'x', base('x', '15', M.om, M.ol, { statut: 'prevu', prono: prono('res:1', '1', 60) }));
  assert.equal((await buildDailyRecap({ db: empty, providers: [], now: NOW })).raison, 'pas assez de matière');
  // la tâche respecte l'interrupteur de l'admin
  const rep = { traites: 0, erreurs: [], infos: {} };
  const db3 = await world();
  await db3.seed('config', 'news', { actif: true, recaps: false });
  await buildRecaps({ db: db3, providers: [], now: NOW }, rep);
  assert.equal(db3.read('articles', 'jour-2026-10-16'), null);
  await db3.seed('config', 'news', { actif: true, recaps: true });
  await buildRecaps({ db: db3, providers: [], now: NOW }, rep);
  assert.ok(db3.read('articles', 'jour-2026-10-16'));
  assert.equal(rep.traites, 1);
});

test('pages : liste, article (sources avec liens, pubs, balisage NewsArticle), version anglaise, carte sur l\'accueil, menu, plan du site, 404', async () => {
  const NOWR = new Date('2026-10-16T08:00:00Z');
  const db = await buildSample(NOWR);
  D.clearCache();
  const a = db.all('articles')[0];
  assert.ok(a, 'le jeu d\'exemple publie un point foot');
  const list = await route(db, '/actus', NOWR);
  assert.equal(list.status, 200);
  assert.match(list.body, /<h1>Le point foot<\/h1>/);
  assert.match(list.body, new RegExp(`href="/actus/${a.slug}"`));
  const page = await route(db, `/actus/${a.slug}`, NOWR);
  assert.equal(page.status, 200);
  assert.match(page.body, /Rédigé par l'IA de PronoFlash à partir de nos données et de sources citées/);
  assert.match(page.body, /<h1>Le point foot du /);
  assert.match(page.body, /"@type":"NewsArticle"/);
  assert.match(page.body, /Sources/);
  assert.ok(!/<script[^>]*>[^<]*gain garanti/.test(page.body));
  assert.match(page.body, /Matchs à surveiller|Les résultats et nos pronostics/);
  assert.match(page.body, /class="(?:ad|afl)/);
  const en = await route(db, `/en/news/${a.slug}`, NOWR);
  assert.equal(en.status, 200);
  assert.match(en.body, /Written by PronoFlash's AI/);
  assert.match((await route(db, '/en/news', NOWR)).body, /<h1>Football roundup<\/h1>/);
  assert.equal((await route(db, '/actus/inconnu-123', NOWR)).status, 404);
  assert.equal((await route(db, '/actus/a/b', NOWR)).status, 404);
  const home = (await route(db, '/', NOWR)).body;
  assert.match(home, new RegExp(`class="rcp" href="/actus/${a.slug}"`));
  assert.ok((home.slice(home.indexOf('class="nwb"'), home.indexOf('class="lbl" style="margin-top:6px">Les matchs')).match(/class="(?:rcp|nw)( has)?"/g) || []).length <= 2, 'deux éléments au plus sous les coupons flash');
  assert.match(home, /href="\/actus"[^>]*>Le point foot<\/a>/);
  const sm = (await route(db, '/sitemap.xml', NOWR)).body;
  assert.ok(sm.includes('/actus/' + a.slug) && sm.includes('/en/news/' + a.slug) && sm.includes('<loc>https://pronoflashia.web.app/actus</loc>'));
});

test('référencement : les nouveaux articles sont signalés une seule fois à IndexNow', async () => {
  const db = new FakeDb();
  await db.seed('articles', 'jour-2026-10-16', { id: 'jour-2026-10-16', slug: 'point-foot-2026-10-16', jour: '2026-10-16' });
  await db.seed('config', 'seo', { staticEnvoyeLe: '2026-10-01T00:00:00Z', indexNowKey: 'a'.repeat(32) });
  const sent = [];
  const fetchImpl = async (u, init) => { sent.push(JSON.parse(init.body)); return { status: 200 }; };
  const site = { indexable: true, origine: 'https://pronoflashia.web.app' };
  const r = await submitNewUrls({ db, site, now: NOW, fetchImpl });
  assert.equal(r.envoyees, 2);
  assert.deepEqual(sent[0].urlList.sort(), ['https://pronoflashia.web.app/actus/point-foot-2026-10-16', 'https://pronoflashia.web.app/en/news/point-foot-2026-10-16']);
  assert.equal((await submitNewUrls({ db, site, now: NOW, fetchImpl })).envoyees, 0);
});
