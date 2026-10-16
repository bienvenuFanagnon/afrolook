'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { buildPrompt } = require('../src/ai/prompt');
const { validateOutput, extractJson, checkNumbers, allowedNumbers } = require('../src/ai/validate');
const { fallbackText } = require('../src/ai/fallback');
const { generateText } = require('../src/ai/generate');
const { cloudflareProvider, geminiProvider } = require('../src/ai/providers');

const ctx = {
  competition: 'Ligue 1', dateTexte: 'dimanche 18 octobre 2026 à 20:45', domicile: 'Paris SG', exterieur: 'Marseille',
  formeDom: 'VVNVV', formeExt: 'NVVDV', probas: { '1': 62, N: 21, '2': 17 }, plus25: 62, bttsOui: 58, scoreProbable: '2-1',
  principal: { libelle: '1 · Paris', confiance: 68 }, extras: ['Paris a marqué 2,4 buts par match à domicile.'], h2h: [],
};
const GOOD = {
  analyse: 'Paris a gagné quatre de ses cinq derniers matchs et marque en moyenne 2,4 buts par match à domicile. Marseille alterne les bons résultats et les défaites, avec une forme plus irrégulière. Le calcul donne 62 % de chances de victoire à Paris, contre 21 % pour le nul. Le score le plus probable est 2-1 et les deux équipes marquent dans 58 % des cas. Rien n\'est garanti : un seul but peut tout changer.',
  pointsCles: ['Paris : 4 victoires sur 5', 'Marseille : forme irrégulière', 'Les 2 équipes marquent : 58 %'],
  resume: 'Paris est favori à 62 %, avec un score probable de 2-1.',
};

test('le prompt contient les faits et interdit d\'inventer', () => {
  const { messages, faits } = buildPrompt(ctx);
  assert.equal(messages[0].role, 'system');
  assert.match(messages[0].content, /N'utilise QUE les chiffres/);
  assert.ok(faits.some((f) => f.includes('62 %')));
  assert.match(messages[1].content, /Pronostic retenu : 1 · Paris, confiance 68 %/);
});

test('une sortie valide est acceptée, avec ou sans balises json', () => {
  const { faits } = buildPrompt(ctx);
  const a = validateOutput(JSON.stringify(GOOD), faits);
  assert.ok(a.ok, a.errors.join());
  const b = validateOutput('```json\n' + JSON.stringify(GOOD) + '\n```', faits);
  assert.ok(b.ok, b.errors.join());
  assert.equal(extractJson('bla {"a":1} bla').a, 1);
});

test('refuse : JSON cassé, promesse de gain, chiffre inventé, texte anglais, format', () => {
  const { faits } = buildPrompt(ctx);
  assert.deepEqual(validateOutput('pas du json', faits).errors, ['json_invalide']);
  const promise = { ...GOOD, analyse: GOOD.analyse + ' Ce pari est un gain garanti pour tous.' };
  assert.ok(validateOutput(promise, faits).errors.includes('promesse_interdite'));
  const invented = { ...GOOD, analyse: GOOD.analyse.replace('62 %', '81 %') };
  assert.ok(validateOutput(invented, faits).errors.some((e) => e.startsWith('chiffre_invente')));
  const en = { analyse: 'Paris SG are the favourites with the best form and the team will have the ball. The match should be open and the goals are likely from both sides. The result is not guaranteed at all, but the model likes the home team.', pointsCles: ['Home team form is good', 'Away team form is poor', 'The goals will come'], resume: 'Paris are favourites in this game with the best form.' };
  assert.ok(validateOutput(en, faits).errors.includes('pas_en_francais'));
  const short = { ...GOOD, analyse: 'Trop court.' };
  assert.ok(validateOutput(short, faits).errors.includes('analyse_longueur'));
  assert.ok(validateOutput({ ...GOOD, pointsCles: ['un'] }, faits).errors.includes('points_cles'));
});

test('nombres : petits entiers et années tolérés, pourcentages inventés refusés', () => {
  const allowed = allowedNumbers(['Probabilité 62 %', 'Score 2-1', 'Moyenne 2,4']);
  assert.deepEqual(checkNumbers('Paris a gagné 4 matchs en 2026 avec 62 % et 2,4 buts', allowed), []);
  assert.deepEqual(checkNumbers('Paris à 71 % et 3,7 buts de moyenne', allowed), ['71', '3,7']);
});

test('texte de secours : valide pour le validateur lui-même', () => {
  const { faits } = buildPrompt(ctx);
  const fb = fallbackText(ctx);
  const v = validateOutput(fb, faits);
  assert.ok(v.ok, v.errors.join());
});

test('chaîne : le premier fournisseur valide gagne', async () => {
  const p1 = { name: 'workers-ai', call: async () => JSON.stringify(GOOD) };
  const p2 = { name: 'gemini', call: async () => { throw new Error('ne doit pas être appelé'); } };
  const r = await generateText(ctx, [p1, p2]);
  assert.equal(r.sourceTexte, 'workers-ai');
  assert.equal(r.erreurs.length, 0);
});

test('chaîne : sortie invalide → une relance → fournisseur suivant', async () => {
  let n = 0;
  const p1 = { name: 'workers-ai', call: async () => { n++; return '{"analyse":"vide"}'; } };
  const p2 = { name: 'gemini', call: async () => JSON.stringify(GOOD) };
  const r = await generateText(ctx, [p1, p2]);
  assert.equal(n, 2);
  assert.equal(r.sourceTexte, 'gemini');
  assert.equal(r.erreurs.filter((e) => e.provider === 'workers-ai').length, 2);
});

test('chaîne : quota → on passe directement au suivant sans relance', async () => {
  let n = 0;
  const quota = Object.assign(new Error('workers-ai 429 quota'), { status: 429, retryable: true });
  const p1 = { name: 'workers-ai', call: async () => { n++; throw quota; } };
  const p2 = { name: 'gemini', call: async () => JSON.stringify(GOOD) };
  const r = await generateText(ctx, [p1, p2]);
  assert.equal(n, 1);
  assert.equal(r.sourceTexte, 'gemini');
});

test('chaîne : tout échoue → texte de secours, jamais de match sans texte', async () => {
  const boom = { name: 'workers-ai', call: async () => { throw new Error('réseau'); } };
  const r = await generateText(ctx, [boom, { ...boom, name: 'gemini' }]);
  assert.equal(r.sourceTexte, 'secours');
  assert.ok(r.texte.analyse.length > 100);
  assert.equal(r.erreurs.length, 4); // une relance par fournisseur après une panne réseau
});

test('Workers AI : requête et lecture de la réponse', async () => {
  let seen;
  const fetchImpl = async (url, init) => { seen = { url, init }; return { status: 200, ok: true, text: async () => JSON.stringify({ success: true, result: { response: '{"a":1}' } }) }; };
  const p = cloudflareProvider({ accountId: 'ACC', token: 'TOK', fetchImpl });
  const out = await p.call([{ role: 'user', content: 'x' }]);
  assert.equal(out, '{"a":1}');
  assert.match(seen.url, /accounts\/ACC\/ai\/run\/@cf\//);
  assert.equal(seen.init.headers.Authorization, 'Bearer TOK');
  const quota = cloudflareProvider({ accountId: 'A', token: 'T', fetchImpl: async () => ({ status: 429, ok: false, text: async () => '{"success":false}' }) });
  await assert.rejects(() => quota.call([]), (e) => e.retryable === true && e.status === 429);
});

test('Gemini : passe au modèle suivant sur 404, s\'arrête sur une erreur de clé', async () => {
  const calls = [];
  const fetchImpl = async (url) => {
    calls.push(url);
    if (calls.length === 1) return { status: 404, ok: false, text: async () => '{}' };
    return { status: 200, ok: true, text: async () => JSON.stringify({ candidates: [{ content: { parts: [{ text: '{"ok":1}' }] } }] }) };
  };
  const p = geminiProvider({ apiKey: 'K', models: ['m1', 'm2'], fetchImpl });
  assert.equal(await p.call([{ role: 'system', content: 's' }, { role: 'user', content: 'u' }]), '{"ok":1}');
  assert.equal(calls.length, 2);
  const bad = geminiProvider({ apiKey: 'K', models: ['m1', 'm2'], fetchImpl: async () => ({ status: 403, ok: false, text: async () => '{}' }) });
  await assert.rejects(() => bad.call([]), (e) => e.status === 403);
});

test('« garanti » : refusé en promesse, accepté en avertissement', () => {
  const { hasUnnegatedPromise } = require('../src/ai/validate');
  assert.equal(hasUnnegatedPromise('Cette victoire est garantie pour Paris.'), true);
  assert.equal(hasUnnegatedPromise('Un résultat assuré, selon nous.'), true);
  assert.equal(hasUnnegatedPromise('Rien n\'est garanti dans ce match.'), false);
  assert.equal(hasUnnegatedPromise('Aucun résultat n\'est assuré.'), false);
  assert.equal(hasUnnegatedPromise('Le match est serré. Paris est garanti de gagner.'), true);
});

test('Workers AI : les deux formats de réponse (response et choices) sont lus', async () => {
  const mk = (result) => async () => ({ status: 200, ok: true, text: async () => JSON.stringify({ success: true, result }) });
  const a = cloudflareProvider({ accountId: 'A', token: 'T', fetchImpl: mk({ response: '{"x":1}' }) });
  assert.equal(await a.call([]), '{"x":1}');
  const b = cloudflareProvider({ accountId: 'A', token: 'T', fetchImpl: mk({ choices: [{ message: { role: 'assistant', content: '{"y":2}' } }] }) });
  assert.equal(await b.call([]), '{"y":2}');
  const c = cloudflareProvider({ accountId: 'A', token: 'T', fetchImpl: mk({ choices: [{ message: { content: null } }] }) });
  await assert.rejects(() => c.call([]), /réponse vide/);
});
