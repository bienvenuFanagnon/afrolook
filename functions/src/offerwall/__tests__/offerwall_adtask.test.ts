import { addHundredths, adTaskHundredths, adTaskRefusal, readAdTaskConfig } from "../adTask_logic";

describe("valeur d'une pub regardée", () => {
  test("eCPM de 1 € : 0,001 € par vue = environ 1,64 pièce (164 centièmes)", () => {
    expect(adTaskHundredths(1)).toBe(164);
  });
  test("la valeur suit l'eCPM, jamais négative", () => {
    expect(adTaskHundredths(2)).toBe(328);
    expect(adTaskHundredths(0)).toBe(0);
    expect(adTaskHundredths(-5)).toBe(0);
    expect(adTaskHundredths(NaN)).toBe(0);
  });
});

describe("centièmes de pièce accumulés", () => {
  test("une vue à 164 centièmes : 1 pièce créditée, 64 gardés", () => {
    expect(addHundredths(0, 164)).toEqual({ coins: 1, carry: 64 });
  });
  test("la 2e vue complète le reste : 2 pièces", () => {
    expect(addHundredths(64, 164)).toEqual({ coins: 2, carry: 28 });
  });
  test("10 vues : 16 pièces en tout (10 × 1,64 = 16,4), aucune perte", () => {
    let carry = 0, coins = 0;
    for (let i = 0; i < 10; i++) { const r = addHundredths(carry, 164); coins += r.coins; carry = r.carry; }
    expect(coins).toBe(16);
    expect(carry).toBe(40);
  });
  test("à 0,0001 € par vue (16 centièmes), une pièce toutes les 7 vues environ", () => {
    let carry = 0, coins = 0;
    for (let i = 0; i < 7; i++) { const r = addHundredths(carry, 16); coins += r.coins; carry = r.carry; }
    expect(coins).toBe(1);
  });
  test("valeurs aberrantes ignorées", () => {
    expect(addHundredths(-10, NaN)).toEqual({ coins: 0, carry: 0 });
  });
});

describe("réglages et limites", () => {
  test("valeurs par défaut, hors bornes ignorées", () => {
    expect(readAdTaskConfig(undefined)).toEqual({ enabled: false, ecpmEur: 1, maxPerDay: 10, gapSec: 30, minWatchSec: 15 });
    expect(readAdTaskConfig({ ecpmEur: 9999, maxPerDay: 0, gapSec: -1, minWatchSec: 1 })).toEqual({ enabled: false, ecpmEur: 1, maxPerDay: 10, gapSec: 30, minWatchSec: 15 });
    expect(readAdTaskConfig({ enabled: false, ecpmEur: 0.5 }).enabled).toBe(false);
    expect(readAdTaskConfig({ enabled: true }).enabled).toBe(true); // il faut l'activer explicitement
  });
  const cfg = { maxPerDay: 3, gapSec: 30 };
  test("plafond du jour atteint", () => {
    expect(adTaskRefusal({ day: "2026-10-29", count: 3, lastAt: 0 }, cfg, "2026-10-29", 1_000_000)).toEqual({ reason: "limite_du_jour", waitSec: 0 });
  });
  test("le compteur repart à zéro le lendemain", () => {
    expect(adTaskRefusal({ day: "2026-10-28", count: 3, lastAt: 0 }, cfg, "2026-10-29", 1_000_000)).toBeNull();
  });
  test("écart minimum entre deux pubs", () => {
    const r = adTaskRefusal({ day: "2026-10-29", count: 1, lastAt: 1_000_000 }, cfg, "2026-10-29", 1_010_000);
    expect(r).toEqual({ reason: "trop_tot", waitSec: 20 });
    expect(adTaskRefusal({ day: "2026-10-29", count: 1, lastAt: 1_000_000 }, cfg, "2026-10-29", 1_031_000)).toBeNull();
  });
});
