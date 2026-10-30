import { DEFAULT_AUDIENCE_PRICE_PER_1000, MAX_TARGET_AUDIENCE, MIN_TARGET_AUDIENCE, audiencePricing, campaignOpen, DEFAULT_USER_PCT, MIN_CPC_FCFA, SHARE_RULES, SHARE_RULES_VERSION, campaignOpenForNewSharers, declaredReach, pricingOf, remainingClicks, validateSharerProfile } from "../adsShare_campaign";

describe("tarif et budget d'une campagne WhatsApp", () => {
  test("le partageur reçoit 60 % du prix du clic", () => {
    expect(DEFAULT_USER_PCT).toBe(60);
    expect(pricingOf({ cpcFcfa: 10, budgetFcfa: 10000 })).toEqual({ cpcFcfa: 10, userFcfa: 6, budgetFcfa: 10000 });
    expect(pricingOf({ cpcFcfa: 8.33, budgetFcfa: 1 }).userFcfa).toBe(4.99);
    expect(pricingOf({ cpcFcfa: 10, budgetFcfa: 1, userFcfa: 5 }).userFcfa).toBe(5);
    expect(MIN_CPC_FCFA).toBe(8);
  });
  test("clics encore finançables", () => {
    expect(remainingClicks(10000, 0, 10)).toBe(1000); expect(remainingClicks(10000, 9995, 10)).toBe(0); expect(remainingClicks(10000, 9990, 10)).toBe(1); expect(remainingClicks(10, 0, 0)).toBe(0);
  });
  test("contrôle de l'audience : fermé quand l'audience engagée suffit à épuiser le budget (marge 50 %)", () => {
    // 1 000 clics à financer ; avec 2 % de clics il faut 50 000 personnes ; marge de 50 % : fermeture à 75 000
    expect(campaignOpenForNewSharers(0, 1000)).toBe(true);
    expect(campaignOpenForNewSharers(70_000, 1000)).toBe(true);
    expect(campaignOpenForNewSharers(75_000, 1000)).toBe(false);
    expect(campaignOpenForNewSharers(10, 0)).toBe(false); // budget épuisé : fermé
  });
  test("un petit budget n'accepte que peu de partageurs", () => {
    const remaining = remainingClicks(5000, 0, 10); // 500 clics → 25 000 personnes → fermeture à 37 500
    expect(campaignOpenForNewSharers(30_000, remaining)).toBe(true); expect(campaignOpenForNewSharers(40_000, remaining)).toBe(false);
  });
});

describe("profil du partageur", () => {
  const ok = { whatsapp: "+228 90 12 34 56", country: "tg", city: "Lomé", statusAudience: 300, groups: [{ name: "Quartier Bè", members: 200 }], about: "Contacts de mon quartier et groupe de ventes en ligne.", acceptTerms: true, rulesVersion: SHARE_RULES_VERSION };
  test("profil complet : normalisé", () => {
    const r = validateSharerProfile(ok); expect(r.ok).toBe(true);
    if (r.ok) { expect(r.value.whatsapp).toBe("+22890123456"); expect(r.value.country).toBe("TG"); expect(declaredReach(r.value)).toBe(500); }
  });
  test("refus : numéro, pays, audience, groupes, présentation, règles", () => {
    expect(validateSharerProfile({ ...ok, whatsapp: "90123456" }).ok).toBe(false);
    expect(validateSharerProfile({ ...ok, country: "TOGO" }).ok).toBe(false);
    expect(validateSharerProfile({ ...ok, statusAudience: -1 }).ok).toBe(false);
    expect(validateSharerProfile({ ...ok, statusAudience: 0, groups: [] }).ok).toBe(false); // moins de 20 personnes
    expect(validateSharerProfile({ ...ok, groups: [{ name: "x", members: 5000 }] }).ok).toBe(false);
    expect(validateSharerProfile({ ...ok, groups: [{ name: "", members: 10 }] }).ok).toBe(false);
    expect(validateSharerProfile({ ...ok, about: "court" }).ok).toBe(false);
    expect(validateSharerProfile({ ...ok, acceptTerms: false }).ok).toBe(false);
    expect(validateSharerProfile({ ...ok, rulesVersion: "2020-01-01" }).ok).toBe(false);
  });
  test("balisage retiré des champs libres, au plus 15 groupes", () => {
    const r = validateSharerProfile({ ...ok, about: "<b>Mon</b> audience : amis et famille du quartier.", groups: Array.from({ length: 30 }, (_, i) => ({ name: "G" + i, members: 20 })) });
    expect(r.ok && r.value.about).toBe("Mon audience : amis et famille du quartier."); expect(r.ok && r.value.groups.length).toBe(15);
  });
  test("règles : version et blocs", () => { expect(SHARE_RULES_VERSION).toMatch(/^\d{4}-\d{2}-\d{2}$/); expect(SHARE_RULES.length).toBeGreaterThanOrEqual(4); });
});

describe("vente à l'audience", () => {
  test("prix = audience × tarif pour 1 000 ; gains plafonnés à 60 % du prix", () => {
    expect(DEFAULT_AUDIENCE_PRICE_PER_1000).toBe(500);
    expect(audiencePricing(50_000, 500, 60, 5)).toEqual({ priceFcfa: 25_000, payoutBudgetFcfa: 15_000, maxClicks: 3000 });
    expect(audiencePricing(1000, 500, 60, 5)).toEqual({ priceFcfa: 500, payoutBudgetFcfa: 300, maxClicks: 60 });
    expect(audiencePricing(0, 500, 60, 5)).toEqual({ priceFcfa: 0, payoutBudgetFcfa: 0, maxClicks: 0 });
    expect(MIN_TARGET_AUDIENCE).toBe(1000); expect(MAX_TARGET_AUDIENCE).toBe(5_000_000);
  });
  test("le plafond de gains reste très au-dessus des clics attendus (2 % de clics)", () => {
    const p = audiencePricing(50_000, 500, 60, 5); expect(50_000 * 0.02).toBeLessThan(p.maxClicks); // 1 000 clics attendus pour 3 000 payables
  });
  test("campagne ouverte tant que l'audience engagée n'a pas atteint l'audience achetée", () => {
    expect(campaignOpen(0, 50_000, 3000)).toBe(true); expect(campaignOpen(49_999, 50_000, 3000)).toBe(true);
    expect(campaignOpen(50_000, 50_000, 3000)).toBe(false); expect(campaignOpen(10, 50_000, 0)).toBe(false); expect(campaignOpen(0, 0, 100)).toBe(false);
  });
});
