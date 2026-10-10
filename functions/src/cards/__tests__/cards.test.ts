jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("../../payments/coinShares", () => ({ recordAppCommission: jest.fn() }));

import { costOf, planOf, monthKey, DEFAULT_PRO_STYLES, FREE_STYLES, isNationalDay, countryOf } from "../cards";

const cfg = {
  enabled: true, priceCapture: 25, pricePublish: 10, priceProStyle: 20, priceProStyleGold: 10, passPrice: 400, passDays: 30, trialCards: 1,
  quotas: { free: { captures: 0, publishes: 0 }, premium: { captures: 2, publishes: 3 }, gold: { captures: 5, publishes: 20 } },
  proStyles: ["bogolan"],
};
const base = { isAdmin: false, plan: "free" as const, passActive: false, trialLeft: 0, adCredits: 0, used: { captures: 0, publishes: 0 }, balance: 1000 };

describe("costOf", () => {
  it("un compte gratuit a 1 capture offerte par mois (partage ailleurs), puis paie", () => {
    const c = { ...cfg, trialCards: 0, quotas: { ...cfg.quotas, free: { captures: 1, publishes: 0 } } };
    expect(costOf("capture", false, base, c)).toEqual({ via: "quota", coins: 0 });
    expect(costOf("capture", false, { ...base, used: { captures: 1, publishes: 0 } }, c)).toEqual({ via: "coins", coins: 25 });
    expect(costOf("publish", false, base, c)).toEqual({ via: "coins", coins: 10 });
  });
  it("un gratuit paie en pièces : 25 la capture, 10 la publication, +20 pour un style Pro", () => {
    expect(costOf("capture", false, base, cfg)).toEqual({ via: "coins", coins: 25 });
    expect(costOf("publish", false, base, cfg)).toEqual({ via: "coins", coins: 10 });
    expect(costOf("capture", true, base, cfg)).toEqual({ via: "coins", coins: 45 });
  });
  it("Premium : 2 captures et 3 publications gratuites par mois, puis pièces", () => {
    const s = { ...base, plan: "premium" as const };
    expect(costOf("capture", false, s, cfg).via).toBe("quota");
    expect(costOf("capture", false, { ...s, used: { captures: 2, publishes: 0 } }, cfg)).toEqual({ via: "coins", coins: 25 });
    expect(costOf("publish", false, { ...s, used: { captures: 2, publishes: 2 } }, cfg).via).toBe("quota");
    expect(costOf("publish", false, { ...s, used: { captures: 0, publishes: 3 } }, cfg)).toEqual({ via: "coins", coins: 10 });
  });
  it("Gold : 5 captures et 20 publications, style Pro à prix réduit même dans le quota", () => {
    const s = { ...base, plan: "gold" as const };
    expect(costOf("publish", false, { ...s, used: { captures: 0, publishes: 19 } }, cfg).via).toBe("quota");
    expect(costOf("publish", false, { ...s, used: { captures: 0, publishes: 20 } }, cfg).via).toBe("coins");
    expect(costOf("capture", true, s, cfg)).toEqual({ via: "quota", coins: 10 });
  });
  it("la carte d'essai passe après le quota et avant les pubs", () => {
    expect(costOf("capture", false, { ...base, trialLeft: 1, adCredits: 2 }, cfg).via).toBe("trial");
  });
  it("une pub regardée offre une capture, jamais une publication", () => {
    expect(costOf("capture", false, { ...base, adCredits: 1 }, cfg)).toEqual({ via: "ad", coins: 0 });
    expect(costOf("publish", false, { ...base, adCredits: 1 }, cfg)).toEqual({ via: "coins", coins: 10 });
  });
  it("le pass rend tout gratuit, styles Pro compris ; l'admin ne paie jamais", () => {
    expect(costOf("capture", true, { ...base, passActive: true }, cfg)).toEqual({ via: "pass", coins: 0 });
    expect(costOf("publish", true, { ...base, isAdmin: true }, cfg)).toEqual({ via: "admin", coins: 0 });
  });
});

describe("planOf", () => {
  const now = Date.parse("2026-10-10T12:00:00Z");
  const ab = (type: string, extra: object = {}) => ({ abonnement: { type, dateFin: "2026-12-01T00:00:00Z", estActif: true, methodePaiement: "wave", ...extra } });
  it("reconnaît Premium et Gold payants", () => {
    expect(planOf(ab("premium"), now)).toBe("premium");
    expect(planOf(ab("gold"), now)).toBe("gold");
  });
  it("ignore un abonnement expiré, inactif ou obtenu avec des pubs", () => {
    expect(planOf(ab("gold", { dateFin: "2026-09-01T00:00:00Z" }), now)).toBe("free");
    expect(planOf(ab("gold", { estActif: false }), now)).toBe("free");
    expect(planOf(ab("premium", { methodePaiement: "pubs" }), now)).toBe("free");
    expect(planOf({}, now)).toBe("free");
  });
});

it("la clé du mois est AAAAMM en UTC", () => {
  expect(monthKey(Date.parse("2026-10-31T23:59:59Z"))).toBe("202610");
  expect(monthKey(Date.parse("2026-11-01T00:00:00Z"))).toBe("202611");
});

describe("styles Pro par défaut", () => {
  it("les styles gratuits ne sont jamais Pro, tous les autres le sont", () => {
    expect(FREE_STYLES.sort()).toEqual(["glass", "kente", "neon", "pro", "wax"]);
    expect(DEFAULT_PRO_STYLES).toHaveLength(21);
    expect(DEFAULT_PRO_STYLES).toContain("bogolan");
    expect(DEFAULT_PRO_STYLES).toContain("tarot");
    for (const f of FREE_STYLES) expect(DEFAULT_PRO_STYLES).not.toContain(f);
  });
});

describe("fête nationale", () => {
  it("le 27 avril (UTC) est la fête du Togo, pas du Sénégal", () => {
    const d = Date.UTC(2027, 3, 27, 10, 0, 0);
    expect(isNationalDay("TG", d)).toBe(true);
    expect(isNationalDay("tg", d)).toBe(true);
    expect(isNationalDay("SN", d)).toBe(false);
    expect(isNationalDay(null, d)).toBe(false);
    expect(isNationalDay("XX", d)).toBe(false);
  });
  it("lit le pays du profil", () => {
    expect(countryOf({ countryData: { countryCode: "sn" } })).toBe("SN");
    expect(countryOf({})).toBeNull();
    expect(countryOf({ countryData: { countryCode: "SEN" } })).toBeNull();
  });
});
