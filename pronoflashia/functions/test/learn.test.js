'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { matchDelta, summarize, mergeDelta, rateByKey } = require('../src/engine/bilan');
const { buildCalibration, makeCalibration, trackRecord, describe, MIN_TOTAL } = require('../src/engine/learn');
const { predictMatch } = require('../src/engine/model');
const { buildFacts } = require('../src/jobs/buildPredictions');
const { createAdmin } = require('../src/http/admin');
const { FakeDb } = require('./helpers/fakeDb');

/** Un match terminé : tous les paris listés avec leur probabilité brute et leur issue réelle. */
function played({ over25 = 70, overHit, res1 = 55, res1Hit = true, pctAff, lamD = 1.5, lamE = 1.1, scoreD = 2, scoreE = 1 }) {
  const marches = [
    { cle: 'buts:over:2.5', famille: 'Buts', pct: pctAff == null ? over25 : pctAff, pctBrut: over25, fiabilite: 'haute' },
    { cle: 'res:1', famille: 'Résultat', pct: res1, pctBrut: res1, fiabilite: 'haute' },
  ];
  return matchDelta({ leagueId: '61', prono: { principal: { cle: 'res:1', confiance: res1 }, marches, lamBrutHome: lamD, lamBrutAway: lamE },
    resultat: { reussi: res1Hit, marches: { 'buts:over:2.5': overHit, 'res:1': res1Hit }, scoreDom: scoreD, scoreExt: scoreE } });
}
const many = (n, f) => Array.from({ length: n }, (_, i) => f(i));

test('bilan : probabilité brute (calibrage) et affichée (public) séparées ; buts prévus contre réels enregistrés', () => {
  const d = played({ over25: 70, pctAff: 62, overHit: true });
  assert.equal(d.parCle.buts_over_2_5.sum, 70); assert.equal(d.parCle.buts_over_2_5.aff, 62);
  assert.deepEqual(d.buts, { n: 1, pd: 1.5, pe: 1.1, rd: 2, re: 1 });
  const s = summarize([d, d]);
  assert.equal(s.parFamille.Buts.annonce, 62, 'le public voit la probabilité affichée');
  assert.equal(s.cal.cles.buts_over_2_5.brut, 70, 'l\'apprentissage voit la probabilité brute');
  assert.equal(s.cal.buts.n, 2);
  assert.equal(rateByKey([d, d], 1).buts_over_2_5.annonce, 62);
  // anciens enregistrements (sans valeur affichée) : repli sur la valeur brute
  const old = { matches: 1, principal: { n: 1, ok: 1 }, parLigue: {}, parConfiance: {}, parFamille: { Buts: { n: 1, ok: 1, sum: 66 } }, parBin: {}, parCle: {} };
  assert.equal(summarize([old]).parFamille.Buts.annonce, 66);
  assert.equal(mergeDelta(old, d).parFamille.Buts.n, 2);
});

test('apprentissage : sous 60 pronostics terminés, aucune correction', () => {
  assert.equal(buildCalibration(summarize(many(MIN_TOTAL - 1, () => played({ overHit: false })))), null);
  assert.equal(buildCalibration(null), null);
  assert.ok(buildCalibration(summarize(many(MIN_TOTAL, () => played({ overHit: false })))));
});

test('apprentissage : un pari surestimé est corrigé à la baisse, plafonné, sans toucher aux paris bien calibrés', () => {
  // « plus de 2,5 buts » annoncé à 70 % mais réussi 40 % du temps ; « victoire domicile » annoncée 55 %, réussie 55 %
  const days = many(200, (i) => played({ over25: 70, overHit: i % 5 < 2, res1: 55, res1Hit: i % 20 < 11 }));
  const cal = buildCalibration(summarize(days));
  const f = makeCalibration(cal);
  const over = f.market('buts:over:2.5', 'Buts', 70);
  assert.ok(over < 70 && over >= 55, `70 → ${over} (plafonné à 15 points)`);
  const win = f.market('res:1', 'Résultat', 55);
  assert.ok(Math.abs(win - 55) <= 4, `bien calibré : 55 → ${win}`);
  // un pari sans historique reste proche de sa valeur brute
  assert.ok(Math.abs(f.market('hand:home:-1.5', 'Handicap', 40) - 40) <= 15);
  const d = describe(cal);
  assert.equal(d.actif, true);
  assert.ok(d.familles.some((x) => x.nom === 'Buts' && x.ecart < 0), JSON.stringify(d.familles));
  assert.ok(d.paris.some((x) => x.cle === 'buts_over_2_5' && x.reel === 40 && x.brut === 70));
});

test('apprentissage : peu de données = presque pas de correction (rétrécissement)', () => {
  const few = many(MIN_TOTAL, (i) => played({ over25: 70, overHit: i % 5 < 3 }));       // 60 matchs, 60 % réussis (annoncé 70 %)
  const lots = many(600, (i) => played({ over25: 70, overHit: i % 5 < 3 }));            // même bilan, 10 fois plus de données
  const a = makeCalibration(buildCalibration(summarize(few))).market('buts:over:2.5', 'Buts', 70);
  const b = makeCalibration(buildCalibration(summarize(lots))).market('buts:over:2.5', 'Buts', 70);
  assert.ok(a > b, `${a} (60 matchs) doit être plus prudent que ${b} (600 matchs)`);
  assert.ok(b < 70 && b >= 60, `avec beaucoup de données la correction s'approche de l'écart réel (≈ −10 points) : ${b}`);
});

test('apprentissage : échelle de buts domicile / extérieur, plafonnée à ±10 %', () => {
  const days = many(300, () => played({ overHit: true, lamD: 2.0, lamE: 1.0, scoreD: 1, scoreE: 1 })); // réel : 1 but à domicile pour 2,0 prévus ; 1 pour 1,0
  const g = buildCalibration(summarize(days)).goalScale;
  assert.equal(g.home, 0.9, 'plafonnée à −10 %'); assert.ok(Math.abs(g.away - 1) < 0.01);
  const mild = buildCalibration(summarize(many(300, () => played({ overHit: true, lamD: 1.5, lamE: 1.0, scoreD: 1, scoreE: 1 })))).goalScale; // 1,5 prévu, 1 réel : −33 % → plafond aussi
  assert.equal(mild.home, 0.9);
  const near = buildCalibration(summarize(many(300, (i) => played({ overHit: true, lamD: 1.5, lamE: 1.0, scoreD: i % 10 < 4 ? 2 : 1, scoreE: 1 })))).goalScale; // réel ≈ 1,4 pour 1,5
  assert.ok(near.home < 1 && near.home > 0.9);
  // anciens enregistrements sans estimation de buts : pas d'échelle
  const noLam = many(MIN_TOTAL, () => { const d = played({ overHit: true }); delete d.buts; return d; });
  assert.equal(buildCalibration(summarize(noLam)).goalScale, null);
  // échantillon de buts inférieur à 40 : pas d'échelle
  const some = many(MIN_TOTAL, (i) => { const d = played({ overHit: true }); if (i >= 30) delete d.buts; return d; });
  assert.equal(buildCalibration(summarize(some)).goalScale, null);
});

test('modèle : sans bilan, probabilité = brute ; avec bilan, probabilités corrigées, cohérentes et valeurs brutes conservées', () => {
  const stats = { home: { home: { games: 8, gf: 21, ga: 6 }, all: { games: 16, gf: 38, ga: 14 } }, away: { away: { games: 8, gf: 10, ga: 12 }, all: { games: 16, gf: 25, ga: 24 } } };
  const input = { home: { nom: 'Paris SG', nomCourt: 'Paris' }, away: { nom: 'Marseille', nomCourt: 'Marseille' }, stats, league: { avgHome: 1.5, avgAway: 1.2, counts: {} } };
  const raw = predictMatch(input);
  assert.equal(raw.calibre, false);
  assert.ok(raw.marches.every((m) => m.pct === m.pctBrut));
  const days = many(300, (i) => played({ over25: 70, overHit: i % 5 < 2, lamD: 2.0, lamE: 1.0, scoreD: 1, scoreE: 1 }));
  const cal = buildCalibration(summarize(days));
  const out = predictMatch(Object.assign({}, input, { calibration: cal }));
  assert.equal(out.calibre, true);
  assert.equal(out.probas['1'] + out.probas.N + out.probas['2'], 100);
  assert.equal(out.lamBrutHome, raw.lamBrutHome, 'l\'estimation brute ne dépend pas du bilan');
  assert.ok(out.lamHome < raw.lamHome, 'le niveau de buts à domicile est corrigé à la baisse');
  const over = out.marches.find((m) => m.cle === 'buts:over:2.5');
  assert.equal(out.plus25, over.pct); assert.ok(over.pctBrut !== over.pct || over.pct === raw.marches.find((m) => m.cle === 'buts:over:2.5').pct);
  assert.ok(out.marches.every((m) => m.pct >= 1 && m.pct <= 99 && Math.abs(m.pct - m.pctBrut) <= 15 + 8), 'corrections bornées (pari + niveau de buts)');
  assert.ok(out.principal.confiance >= 1 && out.principal.confiance <= 99);
});

test('IA : le bilan récent du pari retenu entre dans les faits (français et anglais), seulement avec assez de données', () => {
  const match = { domicile: { nomCourt: 'Lens', apiId: 1 }, exterieur: { nomCourt: 'Lyon', apiId: 2 } };
  const gs = { home: { games: 5, gf: 8, ga: 4 }, away: { games: 5, gf: 6, ga: 7 } };
  const fr = buildFacts(match, gs, gs, null, 'fr', { libelle: '+2,5 buts', n: 42, reel: 61 });
  assert.ok(fr.extras.includes('Notre bilan récent sur ce type de pari (+2,5 buts) : 61 % de réussite sur 42 pronostics.'));
  const en = buildFacts(match, gs, gs, null, 'en', { libelle: 'Over 2.5 goals', n: 42, reel: 61 });
  assert.ok(en.extras.includes('Our recent track record on this type of bet (Over 2.5 goals): 61% successful over 42 predictions.'));
  assert.ok(!buildFacts(match, gs, gs, null, 'fr', { libelle: 'x', n: 5, reel: 80 }).extras.some((l) => /bilan/.test(l)), 'échantillon trop faible : pas cité');
  assert.ok(!buildFacts(match, gs, gs, null, 'fr').extras.some((l) => /bilan/.test(l)));
  const cal = buildCalibration(summarize(many(100, (i) => played({ over25: 70, overHit: i % 5 < 3 }))));
  assert.deepEqual(trackRecord(cal, 'buts:over:2.5', 'Buts'), { niveau: 'pari', n: 100, reel: 60 });
  assert.equal(trackRecord(cal, 'inconnu:cle', 'X'), null);
  assert.equal(trackRecord(null, 'res:1', 'Résultat'), null);
});

test('admin : auto-diagnostic dans le bilan (en observation puis actif)', async () => {
  const NOW = new Date('2026-10-16T12:00:00Z');
  const db = new FakeDb();
  const admin = createAdmin({ db, bootstrap: ['boss@example.com'], now: () => NOW, verifyToken: async () => ({ email: 'boss@example.com', email_verified: true }), clearCache() {} });
  const call = (action, body) => admin.handle({ action, body: body || {}, authorization: 'Bearer t' });
  let r = await call('bilan', { days: 30 });
  assert.equal(r.status, 200); assert.equal(r.json.diagnostic.actif, false); assert.equal(r.json.diagnostic.seuil, MIN_TOTAL); assert.equal(r.json.diagnostic.suivis, 0);
  assert.equal(r.json.cal, undefined, 'les données brutes ne sortent pas de l\'API');
  for (let i = 0; i < 70; i++) {
    const jour = new Date(NOW.getTime() - (i % 20) * 864e5).toISOString().slice(0, 10);
    const cur = (db.read('bilan_days', jour) || {}).delta || null;
    await db.seed('bilan_days', jour, { jour, delta: mergeDelta(cur, played({ over25: 70, overHit: i % 5 < 2 })) });
  }
  r = await call('bilan', { days: 7 });
  assert.equal(r.json.diagnostic.actif, true); assert.equal(r.json.diagnostic.suivis, 70);
  assert.ok(r.json.n < 70, 'la période affichée (7 jours) est plus courte que celle de l\'apprentissage (90 jours)');
  assert.ok(r.json.diagnostic.familles.some((f) => f.nom === 'Buts'));
});

test('page Bilan publique : section « Ce que l\'IA a appris » (en observation, puis corrections en clair), français et anglais', async () => {
  const { buildSample } = require('../dev/sample');
  const { route } = require('../src/render/router');
  const D = require('../src/render/data');
  const NOW = new Date('2026-10-16T08:00:00Z');
  const db = await buildSample(NOW); D.clearCache();
  const fr = (await route(db, '/bilan', NOW)).body;
  assert.match(fr, /Ce que l(?:'|&#39;)IA a appris/);
  assert.match(fr, /(commence à se corriger dès 60|nos probabilités étaient|aucune correction)/);
  assert.match((await route(db, '/en/track-record', NOW)).body, /What the AI has learned/);
  // avec un bilan suffisant et une famille surestimée, la correction est expliquée en langage simple
  for (let i = 0; i < 80; i++) {
    const jour = new Date(NOW.getTime() - (i % 30) * 864e5).toISOString().slice(0, 10);
    const cur = (db.read('bilan_days', jour) || {}).delta || null;
    await db.seed('bilan_days', jour, { jour, delta: mergeDelta(cur, played({ over25: 70, overHit: i % 5 < 2 })) });
  }
  D.clearCache();
  const html = (await route(db, '/bilan', NOW)).body;
  assert.match(html, /Buts[^<]*: nos probabilités étaient trop élevées d(?:'|&#39;)environ \d+ points\. Elles sont maintenant corrigées\./);
  const en = (await route(db, '/en/track-record', NOW)).body;
  assert.match(en, /our probabilities were about \d+ points too high\. They are now corrected\./);
});
