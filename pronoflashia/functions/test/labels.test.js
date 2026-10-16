'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const L = require('../src/shared/labels');
const { buildMarkets } = require('../src/engine/markets');
const { principalLabel } = require('../src/engine/pick');

const home = { nom: 'Paris SG', nomCourt: 'Paris SG' }, away = { nom: 'Marseille', nomCourt: 'Marseille' };
const counts = { corners: { muHome: 6, muAway: 4.5 }, shotsOnTarget: { muHome: 5, muAway: 3.5 }, shots: { muHome: 13, muAway: 10 }, cards: { muHome: 2, muAway: 2.5 }, fouls: { muHome: 11, muAway: 12 }, offsides: { muHome: 2, muAway: 1.8 } };

test('libellés : le français reproduit exactement le catalogue, l\'anglais couvre chaque marché', () => {
  for (const [lh, la] of [[2.1, 1.0], [1.0, 2.2], [1.3, 1.3]]) {
    const { marches } = buildMarkets({ home, away, lamHome: lh, lamAway: la, counts });
    for (const m of marches) {
      assert.equal(L.marketLabel(m.cle, 'Paris SG', 'Marseille', 'fr'), m.libelle, m.cle);
      const en = L.marketLabel(m.cle, 'Paris SG', 'Marseille', 'en');
      assert.ok(en && !/gagne|buts|mi-temps|cartons|fautes|tirs|nul\b|remboursé|encaisser|marque/.test(en), `${m.cle} → ${en}`);
      assert.ok(L.familyLabel(m.famille, 'en') !== undefined && !/é/.test(L.familyLabel(m.famille, 'en')), m.famille);
    }
  }
});

test('libellés anglais attendus', () => {
  const t = (k) => L.marketLabel(k, 'Paris SG', 'Marseille', 'en');
  assert.equal(t('res:1'), 'Paris SG to win');
  assert.equal(t('res:dnb2'), 'Marseille, draw no bet');
  assert.equal(t('buts:over:2.5'), 'Over 2.5 goals');
  assert.equal(t('buts:home:over:0.5'), 'Paris SG over 0.5 goal');
  assert.equal(t('hand:away:+1.5'), 'Marseille +1.5');
  assert.equal(t('hand:home:-1.5'), 'Paris SG −1.5');
  assert.equal(t('corners:more:away'), 'Marseille more corners than Paris SG');
  assert.equal(t('cards:total:3.5'), 'Over 3.5 cards');
  assert.equal(t('mt:htft:home'), 'Paris SG leading at half-time and wins');
  assert.equal(t('inconnu:x'), null);
  assert.equal(L.familyLabel('Cartons & fautes', 'en'), 'Cards & fouls');
  assert.equal(L.familyLabel('Cartons & fautes', 'fr'), 'Cartons & fautes');
});

test('pronostic principal : même libellé que le moteur en français, traduit en anglais', () => {
  for (const k of ['res:1', 'res:2', 'res:N', 'res:1N', 'res:N2', 'res:12', 'buts:over:2.5', 'buts:btts:oui', 'hand:home:-1.5']) {
    const m = { cle: k, libelle: L.marketLabel(k, 'Paris SG', 'Marseille', 'fr') };
    assert.equal(L.principalLabel(k, 'Paris SG', 'Marseille', 'fr'), principalLabel(m, home, away), k);
  }
  assert.equal(L.principalLabel('res:1N', 'Paris SG', 'Marseille', 'en'), '1X · Paris SG or draw');
  assert.equal(L.principalLabel('res:12', 'A', 'B', 'en'), '12 · No draw');
});

test('coupon : avertissements et niveaux de risque en anglais', () => {
  const c = require('../src/shared/coupon');
  assert.equal(c.riskLevel(0.6, 'en').label, 'Cautious');
  assert.equal(c.riskLevel(0.1).label, 'Très risqué');
  const sel = [{ pct: 55, famille: 'Goals', fiabilite: 'haute' }, { pct: 70, famille: 'Goals', fiabilite: 'faible' }, { pct: 80, famille: 'Goals' }, { pct: 80, famille: 'Goals' }];
  const en = c.warnings(sel, { prob: 0.2, approx: true }, 'en').map((w) => w.text).join(' ');
  assert.match(en, /lowers the slip/); assert.match(en, /under 60%/); assert.match(en, /low-reliability/); assert.match(en, /Tip: mixing/); assert.match(en, /may be linked/);
  assert.ok(!/é/.test(en));
  assert.match(c.warnings(sel.slice(0, 1), null).map((w) => w.text).join(' '), /deuxième sélection/);
});
