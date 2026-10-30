import { DEFAULT_SHARE_CONFIG, ClickInput, addHundredths, captionFor, hundredthsFor, isPreviewAgent, newCode, platformOf, readShareConfig, releaseAtFor, shareClickDecision, validChannel, validCode } from "../adsShare_logic";

const cfg = { ...DEFAULT_SHARE_CONFIG, enabled: true };
const good: ClickInput = { bot: false, visitMs: 1200, active: true, sameIpAsCreator: false, sinceCreationMs: 3_600_000, firstForVisitor: true, countryOk: true, linkValidToday: 0, userEarnedTodayFcfa: 0, userPayFcfa: 5, costFcfa: 8.33, spentFcfa: 0, budgetFcfa: 20000 };
const why = (o: Partial<ClickInput>, c = cfg) => { const r = shareClickDecision({ ...good, ...o }, c); return r.valid ? "ok" : r.reason; };

describe("réglages du partage", () => {
  test("par défaut : coupé, 5 F par clic, 500 F par jour (100 clics), retenue de 72 h", () => {
    const c = readShareConfig(undefined);
    expect(c.enabled).toBe(false); expect(c.perClickFcfa).toBe(5); expect(c.dailyCapFcfa).toBe(500); expect(c.holdHours).toBe(72);
  });
  test("valeurs aberrantes ignorées, identifiants d'annonces filtrés", () => {
    const c = readShareConfig({ enabled: true, perClickFcfa: -3, dailyCapFcfa: "x", adIds: ["AbC123xyz", "a b", 7, "x".repeat(80)] });
    expect(c.enabled).toBe(true); expect(c.perClickFcfa).toBe(5); expect(c.dailyCapFcfa).toBe(500); expect(c.adIds).toEqual(["AbC123xyz"]);
  });
  test("seul « enabled: true » active le partage", () => { expect(readShareConfig({ enabled: "true" }).enabled).toBe(false); expect(readShareConfig({ enabled: 1 }).enabled).toBe(false); });
});

describe("valeur et codes", () => {
  test("5 F = 12,5 pièces = 1 250 centièmes", () => { expect(hundredthsFor(5)).toBe(1250); expect(hundredthsFor(0)).toBe(0); });
  test("2 clics : 25 pièces ; la fraction est gardée", () => {
    let r = addHundredths(0, 1250); expect(r).toEqual({ coins: 12, carry: 50 });
    r = addHundredths(r.carry, 1250); expect(r).toEqual({ coins: 13, carry: 0 });
  });
  test("code : 8 caractères, tous différents", () => {
    const s = new Set(Array.from({ length: 200 }, () => newCode()));
    expect(s.size).toBe(200); for (const c of s) expect(validCode(c)).toBe(true);
    expect(validCode("court")).toBe(false); expect(validCode("abc/defg")).toBe(false); expect(validCode(12345678)).toBe(false);
  });
  test("canaux : WhatsApp, Telegram, Facebook, TikTok, autre ; la plateforme est déduite", () => {
    expect(validChannel("whatsapp_status")).toBe("whatsapp_status"); expect(validChannel("telegram_channel")).toBe("telegram_channel"); expect(validChannel("other")).toBe("other");
    expect(validChannel("chat")).toBeNull(); expect(validChannel("status")).toBeNull(); expect(validChannel(undefined)).toBeNull();
    expect(platformOf("whatsapp_group")).toBe("whatsapp"); expect(platformOf("telegram_group")).toBe("telegram"); expect(platformOf("facebook")).toBe("facebook"); expect(platformOf("other")).toBe("other");
  });
  test("retenue : fin du jour + 72 h", () => { expect(releaseAtFor("2026-10-30", 72)).toBe(Date.parse("2026-11-03T00:00:00Z")); expect(releaseAtFor("2026-10-30", 0)).toBe(Date.parse("2026-10-31T00:00:00Z")); });
});

describe("robots et aperçus de lien", () => {
  test("l'aperçu de WhatsApp et les robots ne sont jamais des clics", () => {
    for (const ua of ["WhatsApp/2.23.20.0 A", "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)", "TelegramBot (like TwitterBot)", "Googlebot/2.1", "curl/8.0.1", "python-requests/2.31", "", "x"]) expect(isPreviewAgent(ua)).toBe(true);
  });
  test("un vrai navigateur de téléphone est accepté", () => {
    expect(isPreviewAgent("Mozilla/5.0 (Linux; Android 13; SM-A135F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")).toBe(false);
    expect(isPreviewAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1")).toBe(false);
  });
});

describe("décision sur un clic", () => {
  test("clic normal : valide", () => { expect(why({})).toBe("ok"); });
  test("robot, annonce inactive", () => { expect(why({ bot: true })).toBe("bot"); expect(why({ active: false })).toBe("inactive"); });
  test("navigateur trop rapide (pas de JavaScript réel) ou page trop ancienne", () => { expect(why({ visitMs: 200 })).toBe("too_fast"); expect(why({ visitMs: 500_000 })).toBe("stale"); });
  test("auto-clic : même adresse que le créateur, ou clic dans les 10 secondes", () => { expect(why({ sameIpAsCreator: true })).toBe("self"); expect(why({ sinceCreationMs: 4000 })).toBe("self"); });
  test("un seul clic payé par visiteur et par annonce et par jour", () => { expect(why({ firstForVisitor: false })).toBe("dup"); });
  test("pays hors campagne", () => { expect(why({ countryOk: false })).toBe("geo"); });
  test("plafonds : lien, utilisateur (500 F par jour), budget de l'annonce", () => {
    expect(why({ linkValidToday: 100 })).toBe("link_cap"); expect(why({ linkValidToday: 99 })).toBe("ok");
    expect(why({ userEarnedTodayFcfa: 495 })).toBe("ok"); expect(why({ userEarnedTodayFcfa: 500 })).toBe("user_cap"); expect(why({ userEarnedTodayFcfa: 496 })).toBe("user_cap");
    expect(why({ spentFcfa: 19_990 })).toBe("ok"); expect(why({ spentFcfa: 19_992 })).toBe("budget");
  });
  test("100 clics à 5 F = exactement le plafond de 500 F, le 101e est refusé", () => {
    let earned = 0, n = 0;
    while (why({ userEarnedTodayFcfa: earned }) === "ok") { earned += 5; n++; }
    expect(n).toBe(100); expect(earned).toBe(500);
  });
  test("budget 0 = sans limite de budget", () => { expect(why({ spentFcfa: 1e9, budgetFcfa: 0 })).toBe("ok"); });
  test("ordre des contrôles : un robot est refusé avant tout le reste", () => { expect(why({ bot: true, visitMs: 1, firstForVisitor: false })).toBe("bot"); });
});

describe("légende du partage", () => {
  test("titre, texte, lien et mention Pub obligatoire", () => {
    const c = captionFor("Boutique Kofi : mode africaine", "Vêtements modernes et accessoires, livraison à Lomé.", "https://afrolookmedia.com/p/abcd1234", "fr");
    expect(c).toContain("https://afrolookmedia.com/p/abcd1234"); expect(c.endsWith("(Pub)")).toBe(true); expect(c.split("\n").length).toBe(4);
    expect(captionFor("T", "x", "https://a.b/p/abcd1234", "en").endsWith("(Ad)")).toBe(true);
  });
  test("textes longs raccourcis", () => { const c = captionFor("t".repeat(300), "x".repeat(500), "https://a.b/p/abcd1234", "fr"); expect(c.length).toBeLessThan(330); });
});
