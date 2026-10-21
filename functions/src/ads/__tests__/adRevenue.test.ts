jest.mock("../../shared/firebase", () => ({ db: {} }));
import { cleanRevenueItems } from "../adRevenue";

describe("revenus publicitaires : lignes reçues de l'application", () => {
  test("garde les lignes valides et ignore le reste", () => {
    const items = cleanRevenueItems([
      { p: "banner", c: "USD", m: 1234.4, n: 3 },
      { p: "interstitial", c: "usd", m: 5000, n: 1 }, // devise en minuscules : acceptée (mise en majuscules)
      { p: "Bad Name!", c: "USD", m: 1, n: 1 }, // emplacement invalide
      { p: "banner", c: "EURO", m: 1, n: 1 }, // devise invalide
      { p: "banner", c: "USD", m: -5, n: 1 }, // montant négatif
      { p: "banner", c: "USD", m: 9e12, n: 1 }, // valeur aberrante
      { p: "banner", c: "USD", m: 10, n: 99999 }, // nombre aberrant
      null,
    ]);
    expect(items).toEqual([{ p: "banner", c: "USD", m: 1234, n: 3 }, { p: "interstitial", c: "USD", m: 5000, n: 1 }]);
  });
  test("entrée qui n'est pas une liste, ou trop longue", () => {
    expect(cleanRevenueItems(undefined)).toEqual([]);
    expect(cleanRevenueItems("x")).toEqual([]);
    const many = Array.from({ length: 100 }, () => ({ p: "banner", c: "USD", m: 1, n: 1 }));
    expect(cleanRevenueItems(many)).toHaveLength(40);
  });
});
