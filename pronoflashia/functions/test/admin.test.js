'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const { createAdmin, sanitizeAdsTxt, sanitizeVerification, sanitizeSite, sanitizeAds } = require('../src/http/admin');

const NOW = new Date('2026-10-16T12:00:00Z');
function setup(extra = {}) {
  const db = new FakeDb();
  const tokens = { owner: { email: 'Boss@Example.com', email_verified: true }, other: { email: 'autre@example.com', email_verified: true }, adm: { email: 'adm@example.com', email_verified: true }, unv: { email: 'boss@example.com', email_verified: false } };
  const admin = createAdmin({ db, bootstrap: ['boss@example.com'], now: () => NOW, verifyToken: async (t) => { if (!tokens[t]) throw new Error('jeton invalide'); return tokens[t]; }, clearCache() {}, ...extra });
  const call = (action, body, tok = 'owner') => admin.handle({ action, body, authorization: tok ? `Bearer ${tok}` : undefined });
  return { db, call };
}

test('accès : connexion requise, adresse vérifiée, liste des administrateurs', async () => {
  const { db, call } = setup();
  assert.equal((await call('me', {}, null)).status, 401);
  assert.equal((await call('me', {}, 'faux')).status, 401);
  assert.equal((await call('me', {}, 'unv')).status, 403);
  assert.equal((await call('me', {}, 'other')).status, 403);
  const ok = await call('me', {}, 'owner');
  assert.equal(ok.status, 200); assert.equal(ok.json.email, 'boss@example.com'); assert.equal(ok.json.bootstrap, true);
  await db.seed('admins', 'adm@example.com', {});
  assert.equal((await call('me', {}, 'adm')).status, 200);
  assert.equal((await call('actioninconnue', {})).status, 404);
});

test('ajouter et retirer un administrateur, sans pouvoir se retirer soi-même', async () => {
  const { db, call } = setup();
  assert.equal((await call('admin-ajouter', { email: 'pas-un-mail' })).status, 400);
  assert.equal((await call('admin-ajouter', { email: 'Adm@Example.com' })).status, 200);
  assert.ok(db.read('admins', 'adm@example.com'));
  assert.equal((await call('admin-retirer', { email: 'boss@example.com' })).status, 400);
  assert.equal((await call('admin-retirer', { email: 'adm@example.com' })).status, 200);
  assert.equal(db.read('admins', 'adm@example.com'), null);
  assert.ok(db.all('admin_log').length >= 2, 'actions journalisées');
});

test('ads.txt : lignes valides acceptées, ligne invalide refusée avec message', () => {
  const good = '# Adsterra\nadsterra.com, 1234567, DIRECT, abcdef1234567890\ngoogle.com, pub-123, RESELLER, f08c47fec0942fa0\nCONTACT=mail@x.com';
  assert.equal(sanitizeAdsTxt(good).split('\n').length, 4);
  assert.throws(() => sanitizeAdsTxt('adsterra.com 1234 DIRECT'), /ads\.txt invalide/);
  assert.throws(() => sanitizeAdsTxt('<script>alert(1)</script>'), /invalide/);
  assert.equal(sanitizeAdsTxt(''), '');
});

test('balise de vérification : meta seulement', () => {
  assert.equal(sanitizeVerification('<meta name="adsterra-verification" content="abc123">'), '<meta name="adsterra-verification" content="abc123">');
  assert.throws(() => sanitizeVerification('<script>x()</script>'), /invalide/);
  assert.throws(() => sanitizeVerification('<meta name="a" content="b" onload="x()">'), /invalide/);
});

test('config : champs filtrés, valeurs bornées, codes plafonnés', () => {
  assert.deepEqual(sanitizeSite({ editeur: 'Jean', pirate: 'x', indexable: 0, email: 'a@b.co' }), { editeur: 'Jean', indexable: false, email: 'a@b.co' });
  assert.throws(() => sanitizeSite({ email: 'faux' }), /e-mail/);
  assert.throws(() => sanitizeSite({ origine: 'http://x.com' }), /Origine/);
  const a = sanitizeAds({ actif: 1, afrolook: { actif: 1, every: 99, part: 500 }, emplacements: { haut: { actif: true, reseaux: [{ reseau: 'adsterra', code: '<script>1</script>', codeMobile: '' }, { reseau: 'pirate', code: 'x' }] }, inconnu: { actif: true }, native: { actif: 1, every: 1 } } });
  assert.equal(a.actif, true); assert.equal(a.afrolook.every, 30); assert.equal(a.afrolook.part, 100);
  assert.equal(a.emplacements.haut.reseaux.length, 1); assert.equal(a.emplacements.inconnu, undefined); assert.equal(a.emplacements.native.every, 2);
  assert.throws(() => sanitizeAds({ emplacements: { haut: { actif: true, reseaux: [{ reseau: 'adsterra', code: 'x'.repeat(4001) }] } } }), /trop long/);
});

test('config : enregistrement fusionné et journalisé ; incomplétude des mentions légales signalée', async () => {
  const { db, call } = setup();
  let r = await call('config', {});
  assert.deepEqual(r.json.legalIncomplet.sort(), ['adresse', 'editeur', 'email', 'loi', 'statutJuridique']);
  assert.equal(r.json.ads.actif, false, 'publicité coupée par défaut');
  r = await call('config-save', { site: { editeur: 'Éditeur X', email: 'c@x.com' }, ads: { actif: true, emplacements: { haut: { actif: true, reseaux: [{ reseau: 'adsterra', code: '<div>ad</div>' }] } } } });
  assert.equal(r.status, 200);
  r = await call('config', {});
  assert.equal(r.json.site.editeur, 'Éditeur X'); assert.equal(r.json.ads.actif, true); assert.equal(r.json.ads.emplacements.haut.reseaux[0].code, '<div>ad</div>');
  assert.ok(r.json.legalIncomplet.includes('adresse'));
  assert.equal((await call('config-save', { ads: { adsTxt: 'ligne invalide' } })).status, 400);
  assert.equal(db.all('admin_log').filter((l) => l.action === 'config-save').length, 1);
});

test('pronostics : masquer, republier, regénérer, corriger un libellé (tout est journalisé)', async () => {
  const { db, call } = setup();
  await db.seed('matches', 'm1', { id: 'm1', slug: 'a-b', leagueId: '61', leagueNom: 'Ligue 1', leagueSlug: 'ligue-1', coupDEnvoi: '2026-10-17T18:00:00.000Z', statut: 'prevu', domicile: { nomCourt: 'A' }, exterieur: { nomCourt: 'B' }, prono: { visible: true, principal: { libelle: '1 · A', confiance: 66 }, sourceTexte: 'workers-ai', calculeLe: '2026-10-16T05:00:00Z' } });
  let r = await call('pronos', {});
  assert.equal(r.json.matchs.length, 1); assert.equal(r.json.matchs[0].confiance, 66);
  assert.equal((await call('prono-action', { id: 'm1', action: 'masquer' })).status, 200);
  assert.equal(db.read('matches', 'm1').prono.visible, false);
  assert.equal(db.read('matches', 'm1').prono.principal.confiance, 66, 'le reste du pronostic est conservé');
  await call('prono-action', { id: 'm1', action: 'republier' });
  assert.equal(db.read('matches', 'm1').prono.visible, true);
  await call('prono-action', { id: 'm1', action: 'regenerer' });
  assert.equal(db.read('matches', 'm1').prono.aRecalculer, true);
  await call('prono-action', { id: 'm1', action: 'libelle', libelle: '1N · A ou nul' });
  assert.equal(db.read('matches', 'm1').prono.principal.libelle, '1N · A ou nul');
  assert.equal(db.read('matches', 'm1').prono.principal.confiance, 66);
  assert.equal((await call('prono-action', { id: 'nope', action: 'masquer' })).status, 404);
  assert.equal((await call('prono-action', { id: 'm1', action: 'libelle', libelle: ' ' })).status, 400);
  assert.equal((await call('prono-action', { id: 'm1', action: 'supprimer' })).status, 400);
  assert.equal(db.all('admin_log').length, 4);
  r = await call('pronos', { confMin: 80 });
  assert.equal(r.json.matchs.length, 0);
});

test('statistiques : visites, visiteurs, pays, pages, matchs les plus vus', async () => {
  const { db, call } = setup();
  await db.seed('matches', 'm1', { id: 'm1', domicile: { nomCourt: 'Paris SG' }, exterieur: { nomCourt: 'Marseille' } });
  await db.seed('stats_days', '2026-10-15', { jour: '2026-10-15', visites: 100, pv: 250, hllEst: { 0: 40, 1: 38 }, pays: { CI: 60, FR: 40 }, pages: { match: 120, accueil: 80 }, matchs: { m1: 90 }, clicsAfrolook: 4 });
  await db.seed('stats_days', '2026-10-16', { jour: '2026-10-16', visites: 50, pv: 100, hllEst: { 0: 20 }, pays: { CI: 30 }, matchs: { m1: 10 } });
  const r = (await call('overview', { days: 7 })).json;
  assert.equal(r.aujourdhui.visites, 50); assert.equal(r.sept.visites, 150);
  assert.equal(r.jours[0].visiteurs, 78);
  assert.deepEqual(r.pays[0], { k: 'CI', v: 90 });
  assert.equal(r.matchsTop[0].nom, 'Paris SG – Marseille'); assert.equal(r.matchsTop[0].v, 100);
  assert.equal(r.periode.clicsAfrolook, 4);
});

test('semaines : comparaison avec la semaine précédente', async () => {
  const { db, call } = setup();
  await db.seed('stats_weeks', '2026-W41', { semaine: '2026-W41', visites: 120, pagesVues: 300, tauxReussite: 60 });
  await db.seed('stats_weeks', '2026-W40', { semaine: '2026-W40', visites: 100, pagesVues: 300, tauxReussite: 64 });
  const r = (await call('weeks', {})).json.semaines;
  assert.equal(r[0].vsPrecedente.visites, 20); assert.equal(r[0].vsPrecedente.pagesVues, 0); assert.equal(r[0].vsPrecedente.taux, -4);
  assert.equal(r[1].vsPrecedente, null);
});

test('tâches : relancer une tâche connue, refuser les autres', async () => {
  let ran = 0;
  const { db, call } = setup({ tasks: { syncResults: async () => { ran++; return { traites: 2 }; } } });
  assert.equal((await call('tache-lancer', { nom: 'rm -rf' })).status, 400);
  assert.equal((await call('tache-lancer', { nom: 'syncFixtures' })).status, 501);
  const r = await call('tache-lancer', { nom: 'syncResults' });
  assert.equal(r.status, 200); assert.equal(ran, 1);
  await db.seed('jobs', '_dernier_syncResults', { ok: true, traites: 2 });
  assert.equal((await call('taches', {})).json.taches.find((t) => t.nom === 'syncResults').dernier.traites, 2);
});

test('championnats : ajout vérifié auprès de l\'API, mise à jour du suivi', async () => {
  const api = { leagues: async ({ id }) => (id === 61 ? [{ league: { id: 61, name: 'Ligue 1' }, country: { name: 'France' }, seasons: [{ year: 2025 }, { year: 2026, current: true }] }] : []) };
  const { db, call } = setup({ apiFactory: () => api });
  assert.equal((await call('ligue-ajouter', { apiId: 9999 })).status, 404);
  assert.equal((await call('ligue-ajouter', {})).status, 400);
  const r = await call('ligue-ajouter', { apiId: 61, ordre: 3 });
  assert.equal(r.json.ligue.saison, 2026); assert.equal(r.json.ligue.slug, 'ligue-1');
  assert.equal(db.read('leagues', '61').suivi, true);
  await call('ligue-maj', { apiId: 61, suivi: false });
  assert.equal(db.read('leagues', '61').suivi, false);
  await call('ligue-maj', { apiId: 61, noms: { fr: 'Ligue 1', en: ' French Ligue 1 ', de: 'x' } });
  assert.deepEqual(db.read('leagues', '61').noms, { fr: 'Ligue 1', en: 'French Ligue 1' });
  assert.equal((await call('ligue-maj', { apiId: 1 })).status, 404);
});

test('connexions : outils, état, quotas ; secrets jamais renvoyés', async () => {
  const { db, call } = setup({ secretsStatus: () => ({ apiFootball: true, cfToken: true, cfAccount: true, gemini: false, statsSalt: true }) });
  await db.seed('connexions', 'workersAi', { jour: '2026-10-16', appelsJour: 40, erreursJour: 1, neuronsJour: 8600, dernierSucces: '2026-10-16T11:00:00Z', historique: { '2026-10-16': { appels: 40, erreurs: 1, neurons: 8600 } } });
  await db.seed('connexions', 'apiFootball', { jour: '2026-10-16', appelsJour: 30, quotaRestant: 7000, quotaLimite: 7500, dernierSucces: '2026-10-16T05:00:00Z', derniereErreur: 'quota', derniereErreurLe: '2026-10-16T06:00:00Z' });
  await db.seed('config', 'ads', { actif: true, emplacements: { haut: { actif: true, reseaux: [{ reseau: 'adsterra', code: '<div>x</div>' }] } } });
  await db.seed('stats_days', '2026-10-16', { pub: { haut_adsterra: 120 }, aflImps: 50, clicsAfrolook: 3, pv: 400 });
  const r = await call('connexions', {});
  assert.equal(r.status, 200);
  const by = Object.fromEntries(r.json.outils.map((t) => [t.id, t]));
  assert.equal(by.workersAi.etat, 'attention', '86 % du quota gratuit');
  assert.equal(by.workersAi.quota.utilise, 8600); assert.equal(by.workersAi.quota.limite, 10000);
  assert.equal(by.apiFootball.etat, 'panne', 'erreur plus récente que le dernier succès');
  assert.equal(by.apiFootball.quota.utilise, 500);
  assert.equal(by.gemini.etat, 'non_configure');
  assert.equal(by.adsterra.etat, 'ok'); assert.equal(by.adsterra.appelsJour, 120);
  assert.equal(by.monetag.etat, 'non_configure');
  assert.equal(by.afrolook.clicsJour, 3);
  assert.ok(!JSON.stringify(r.json).includes('cfat_'), 'aucune valeur de secret');
});

test('planning : tâches, cadence, prochain passage', async () => {
  const { db, call } = setup();
  await db.seed('jobs', '_dernier_syncFixtures', { ok: true, debut: '2026-10-16T05:00:00Z', traites: 70 });
  const r = (await call('planning', {})).json;
  assert.equal(r.taches.length, 7);
  const sf = r.taches.find((x) => x.nom === 'syncFixtures');
  assert.equal(sf.prochain, '2026-10-17T05:00:00.000Z');
  assert.equal(sf.dernier.traites, 70);
  assert.match(sf.role, /7 prochains jours/);
});
