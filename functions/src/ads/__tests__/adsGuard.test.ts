import { GUARD, LAUNCH_DISCOUNT, MIN_PAYOUT_FCFA, priceAfterDiscount, PACING_MARGIN, PAYOUT_HOLD_DAYS, deliveryAllowed, detectAdAnomalies, detectPubAnomalies, earningFcfa, payable, releaseDay, worse } from "../adsGuard";

const base = { valid: 500, invalid: 10, clicks: 5, foreign: 0, baselineValid: 480 };
const types = (m: Parameters<typeof detectPubAnomalies>[0]) => detectPubAnomalies(m).map((a) => a.type);

describe("anomalies d'une plateforme", () => {
  test("un jour normal ne déclenche rien", () => { expect(detectPubAnomalies(base)).toEqual([]); });
  test("pic de vues : 4 fois la moyenne = moyenne, 10 fois = haute", () => {
    const a = detectPubAnomalies({ ...base, valid: 2000, baselineValid: 480 }); expect(a[0]).toMatchObject({ type: "spike", severity: "medium" });
    const b = detectPubAnomalies({ ...base, valid: 6000, baselineValid: 480 }); expect(b.find((x) => x.type === "spike")?.severity).toBe("high");
  });
  test("pic sans historique : seulement à partir de 1 000 vues, haute à partir de 5 000", () => {
    expect(types({ ...base, valid: 900, baselineValid: 0 })).not.toContain("spike");
    expect(detectPubAnomalies({ ...base, valid: 1200, baselineValid: 0 }).find((x) => x.type === "spike")?.severity).toBe("medium");
    expect(detectPubAnomalies({ ...base, valid: 5200, baselineValid: 0, clicks: 5 }).find((x) => x.type === "spike")?.severity).toBe("high");
  });
  test("petit volume : pas de pic même en proportion", () => { expect(types({ ...base, valid: GUARD.spikeMinViews - 1, baselineValid: 5 })).not.toContain("spike"); });
  test("part de clics anormale : > 8 % moyenne, > 15 % haute, jamais sous 300 vues", () => {
    expect(detectPubAnomalies({ ...base, valid: 1000, clicks: 100, baselineValid: 900 }).find((x) => x.type === "ctr_high")?.severity).toBe("medium");
    expect(detectPubAnomalies({ ...base, valid: 1000, clicks: 200, baselineValid: 900 }).find((x) => x.type === "ctr_high")?.severity).toBe("high");
    expect(types({ ...base, valid: 250, clicks: 100, baselineValid: 240 })).not.toContain("ctr_high");
  });
  test("plus de clics que de vues valides : haute", () => {
    const a = detectPubAnomalies({ ...base, valid: 10, clicks: 40, baselineValid: 10 }); expect(a.find((x) => x.type === "clicks_no_views")?.severity).toBe("high");
    expect(types({ ...base, valid: 10, clicks: 5, baselineValid: 10 })).not.toContain("clicks_no_views");
  });
  test("trafic invalide : 10 % moyenne, 25 % haute, mini 200 affichages", () => {
    expect(detectPubAnomalies({ ...base, valid: 800, invalid: 120, baselineValid: 800 }).find((x) => x.type === "invalid_rate")?.severity).toBe("medium");
    expect(detectPubAnomalies({ ...base, valid: 600, invalid: 300, baselineValid: 600 }).find((x) => x.type === "invalid_rate")?.severity).toBe("high");
    expect(types({ ...base, valid: 100, invalid: 50, baselineValid: 100 })).not.toContain("invalid_rate");
  });
  test("appels depuis un autre domaine : 50 moyenne, 500 haute", () => {
    expect(detectPubAnomalies({ ...base, foreign: 60 }).find((x) => x.type === "foreign_calls")?.severity).toBe("medium");
    expect(detectPubAnomalies({ ...base, foreign: 900 }).find((x) => x.type === "foreign_calls")?.severity).toBe("high");
    expect(types({ ...base, foreign: 10 })).not.toContain("foreign_calls");
  });
  test("plus de personnes différentes en un jour que l'audience mensuelle déclarée : haute", () => {
    expect(detectPubAnomalies({ ...base, declaredMonthly: 1000, uniquesYesterday: 1500 }).find((x) => x.type === "audience_over")?.severity).toBe("high");
    expect(types({ ...base, declaredMonthly: 1000, uniquesYesterday: 300 })).not.toContain("audience_over");
    expect(types({ ...base, uniquesYesterday: 300 })).not.toContain("audience_over"); // plateforme interne : pas d'audience déclarée
  });
  test("plusieurs anomalies à la fois sont toutes remontées", () => {
    const t = types({ valid: 3000, invalid: 1500, clicks: 600, foreign: 700, baselineValid: 300 });
    expect(t).toEqual(expect.arrayContaining(["spike", "ctr_high", "invalid_rate", "foreign_calls"]));
  });
});

describe("anomalies d'une annonce", () => {
  test("normal", () => { expect(detectAdAnomalies({ views: 1000, clicks: 12 })).toEqual([]); });
  test("clics > vues : haute", () => { expect(detectAdAnomalies({ views: 10, clicks: 50 })[0]).toMatchObject({ type: "ad_clicks_no_views", severity: "high" }); });
  test("part de clics anormale", () => { expect(detectAdAnomalies({ views: 400, clicks: 100 })[0]).toMatchObject({ type: "ad_ctr_high", severity: "medium" }); });
  test("peu de clics : rien, même avec une forte part", () => { expect(detectAdAnomalies({ views: 100, clicks: 10 })).toEqual([]); });
  test("worse garde la gravité la plus forte", () => { expect(worse("medium", "high")).toBe("high"); expect(worse("medium", "medium")).toBe("medium"); });
});

describe("livraison maîtrisée", () => {
  const D = 86_400_000, t0 = Date.UTC(2026, 9, 1);
  test("sans budget (offre gratuite) : toujours livrable", () => { expect(deliveryAllowed({ viewsTotal: 1e6, viewsToday: 1e6 })).toBe(true); });
  test("le budget total atteint arrête la livraison", () => {
    expect(deliveryAllowed({ budgetViews: 1000, viewsTotal: 999, viewsToday: 0 })).toBe(true);
    expect(deliveryAllowed({ budgetViews: 1000, viewsTotal: 1000, viewsToday: 0 })).toBe(false);
  });
  test("lissage : 1 000 vues sur 10 jours = au plus 125 par jour", () => {
    const d = { budgetViews: 1000, startMs: t0, endMs: t0 + 10 * D, viewsTotal: 0 };
    expect(Math.ceil((1000 / 10) * PACING_MARGIN)).toBe(125);
    expect(deliveryAllowed({ ...d, viewsToday: 124 })).toBe(true);
    expect(deliveryAllowed({ ...d, viewsToday: 125 })).toBe(false);
  });
  test("1 000 personnes connectées en même temps ne vident pas une annonce de 1 000 vues sur 7 jours", () => {
    const d = { budgetViews: 1000, startMs: t0, endMs: t0 + 7 * D, viewsTotal: 0 };
    let served = 0; for (let i = 0; i < 1000; i++) if (deliveryAllowed({ ...d, viewsToday: served })) served++;
    expect(served).toBe(Math.ceil((1000 / 7) * PACING_MARGIN)); // 179 le premier jour
    expect(served).toBeLessThan(200);
  });
  test("une campagne d'un jour peut livrer tout son budget (avec la marge)", () => {
    expect(deliveryAllowed({ budgetViews: 100, startMs: t0, endMs: t0 + D, viewsTotal: 99, viewsToday: 99 })).toBe(true);
  });
});

describe("paiement protégé des diffuseurs", () => {
  test("gain : 65 % du prix payé, arrondi vers le bas", () => {
    expect(earningFcfa(1000, 1000)).toBe(650);
    expect(earningFcfa(1000, 1250)).toBe(812); // 812,5 → 812 : jamais au-dessus de la part due
    expect(earningFcfa(1000, 3500)).toBe(2275); // récompensée
    expect(earningFcfa(-5, 1000)).toBe(0);
  });
  test("retenue de 30 jours", () => { expect(PAYOUT_HOLD_DAYS).toBe(30); expect(releaseDay("2026-10-01")).toBe("2026-10-31"); expect(releaseDay("2026-12-15")).toBe("2027-01-14"); });
  const e = [{ day: "2026-09-01", fcfa: 4000 }, { day: "2026-09-10", fcfa: 3000 }, { day: "2026-10-25", fcfa: 9000 }];
  test("seuls les gains arrivés à échéance sont versables", () => {
    expect(payable({ earnings: e, today: "2026-10-12", advertiserFundsFcfa: 1e6, openAlert: false, verified: true })).toBe(7000); // 09-01 et 09-10 ; pas 10-25
    expect(payable({ earnings: e, today: "2026-10-05", advertiserFundsFcfa: 1e6, openAlert: false, verified: true })).toBe(4000 >= MIN_PAYOUT_FCFA ? 4000 : 0);
  });
  test("jamais plus que l'argent réellement encaissé", () => { expect(payable({ earnings: e, today: "2026-12-01", advertiserFundsFcfa: 6000, openAlert: false, verified: true })).toBe(6000); });
  test("rien pendant une alerte ouverte ou si la plateforme n'est pas vérifiée", () => {
    expect(payable({ earnings: e, today: "2026-12-01", advertiserFundsFcfa: 1e6, openAlert: true, verified: true })).toBe(0);
    expect(payable({ earnings: e, today: "2026-12-01", advertiserFundsFcfa: 1e6, openAlert: false, verified: false })).toBe(0);
  });
  test("sous le seuil minimum : rien", () => { expect(payable({ earnings: [{ day: "2026-01-01", fcfa: MIN_PAYOUT_FCFA - 1 }], today: "2026-12-01", advertiserFundsFcfa: 1e6, openAlert: false, verified: true })).toBe(0); });
  test("ce qui a déjà été versé est déduit", () => { expect(payable({ earnings: [{ day: "2026-01-01", fcfa: 12000 }], today: "2026-12-01", advertiserFundsFcfa: 1e6, openAlert: false, verified: true, alreadyPaidFcfa: 5000 })).toBe(7000); });
});

describe("remise de lancement", () => {
  const open = Date.UTC(2027, 0, 1), D = 86_400_000;
  test("30 % de moins pendant 1 mois à partir de l'ouverture, puis prix normal", () => {
    expect(LAUNCH_DISCOUNT).toEqual({ pct: 30, days: 30 });
    expect(priceAfterDiscount(1000, open, open)).toBe(700);
    expect(priceAfterDiscount(3500, open, open + 29 * D)).toBe(2450);
    expect(priceAfterDiscount(1000, open, open + 30 * D)).toBe(1000);
    expect(priceAfterDiscount(1000, open, open + 90 * D)).toBe(1000);
  });
  test("offre pas encore ouverte ou date antérieure : prix normal", () => {
    expect(priceAfterDiscount(1000, null, open)).toBe(1000);
    expect(priceAfterDiscount(1000, open, open - D)).toBe(1000);
  });
  test("la part du diffuseur suit le prix réellement payé : 65 % de 700 F pour la bannière", () => {
    expect(earningFcfa(1000, priceAfterDiscount(1000, open, open + D))).toBe(455);
    expect(earningFcfa(1000, priceAfterDiscount(3500, open, open + D))).toBe(1592); // 2 450 × 0,65 = 1 592,5 arrondi vers le bas
  });
});
