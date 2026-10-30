import {
  FORMATS, SHARDS, TokenPayload, TOKEN_TTL_VIEW_MS, adFitsFormat, clickDecision, completeDecision, ctrSuspicious, ipHash, isBotAgent, newNonce, pickAd, publisherHealth,
  shardId, shardOf, signToken, validFormat, validPubId, validSlot, validVid, verifyToken, viewDecision, visitorHash,
} from "../adsEngine_logic";

const KEY = "k".repeat(64);
const T0 = 1_700_000_000_000;
const payload = (over: Partial<TokenPayload> = {}): TokenPayload => ({ v: 1, a: "AbCdEfGhIj12", p: "slashatlas", s: "main", f: "native", t: T0, n: "nonce1234567", ...over });

describe("jeton signé", () => {
  test("aller-retour, falsification et mauvaise clé", () => {
    const tok = signToken(payload(), KEY);
    expect(verifyToken(tok, KEY)).toEqual(payload());
    expect(verifyToken(tok, "autre-cle".repeat(8))).toBeNull();
    const [body, sig] = tok.split(".");
    // changer le contenu (ex. l'annonce) casse la signature
    const forged = Buffer.from(JSON.stringify(payload({ a: "ZzZzZzZzZz99" }))).toString("base64url");
    expect(verifyToken(`${forged}.${sig}`, KEY)).toBeNull();
    expect(verifyToken(`${body}.${sig}x`, KEY)).toBeNull();
    expect(verifyToken(`${body}`, KEY)).toBeNull();
    expect(verifyToken(`${body}.${sig}.extra`, KEY)).toBeNull();
    expect(verifyToken(undefined, KEY)).toBeNull();
    expect(verifyToken("x".repeat(700), KEY)).toBeNull();
  });
  test("contenu invalide même bien signé", () => {
    expect(verifyToken(signToken(payload({ f: "banane" as never }), KEY), KEY)).toBeNull();
    expect(verifyToken(signToken(payload({ a: "../etc" }), KEY), KEY)).toBeNull();
  });
  test("numéros uniques", () => {
    const s = new Set(Array.from({ length: 200 }, () => newNonce()));
    expect(s.size).toBe(200);
    expect(newNonce()).toMatch(/^[A-Za-z0-9_-]{12}$/);
  });
});

describe("formats et compatibilité", () => {
  test("catalogue", () => {
    expect(validFormat("native")).toBe("native");
    expect(validFormat("constructor")).toBeNull();
    expect(validFormat("toString")).toBeNull();
    expect(FORMATS.rewarded.cpm).toBe(3500);
    expect(FORMATS.banner.cpm).toBe(1000);
  });
  test("une annonce ne va que dans les formats qui lui conviennent", () => {
    const img = { video: false, images: 1 }, multi = { video: false, images: 3 }, vid = { video: true, images: 0 };
    expect(adFitsFormat(img, "banner")).toBe(true);
    expect(adFitsFormat(img, "carousel")).toBe(false);
    expect(adFitsFormat(multi, "carousel")).toBe(true);
    expect(adFitsFormat(vid, "banner")).toBe(false);
    expect(adFitsFormat(vid, "rewarded")).toBe(true);
    expect(adFitsFormat(img, "rewarded")).toBe(false);
    expect(adFitsFormat(img, "native")).toBe(true);
    expect(adFitsFormat(vid, "native")).toBe(true);
    expect(adFitsFormat(img, "notification")).toBe(false);
  });
  test("identifiants", () => {
    expect(validPubId("slashatlas")).toBe("slashatlas");
    expect(validPubId("ap_k3j9x2m8qz")).toBe("ap_k3j9x2m8qz");
    expect(validPubId("../x")).toBeNull();
    expect(validPubId("A")).toBeNull();
    expect(validSlot("fil-principal")).toBe("fil-principal");
    expect(validSlot("<script>")).toBe("main");
    expect(validVid("a1b2c3d4-e5f6-7890")).toBe(true);
    expect(validVid("court")).toBe(false);
  });
});

describe("vue valide", () => {
  const ok = () => viewDecision(payload(), T0 + 3000, 1500, undefined, 0, false);
  test("cas normal", () => expect(ok()).toEqual({ valid: true }));
  test("rejeu du jeton", () => expect(viewDecision(payload(), T0 + 3000, 1500, undefined, 0, true)).toEqual({ valid: false, reason: "replay" }));
  test("jeton expiré ou venu du futur", () => {
    expect(viewDecision(payload(), T0 + TOKEN_TTL_VIEW_MS + 1, 1500, undefined, 0, false).reason).toBe("expired");
    expect(viewDecision(payload(), T0 - 10, 1500, undefined, 0, false).reason).toBe("expired");
  });
  test("pas assez visible", () => expect(viewDecision(payload(), T0 + 3000, 400, undefined, 0, false).reason).toBe("not_visible"));
  test("la vidéo exige 2 s", () => {
    expect(viewDecision(payload({ f: "video" }), T0 + 5000, 1500, undefined, 0, false).reason).toBe("not_visible");
    expect(viewDecision(payload({ f: "video" }), T0 + 5000, 2000, undefined, 0, false).valid).toBe(true);
  });
  test("visible plus longtemps que le jeton n'existe : fraude", () => expect(viewDecision(payload(), T0 + 1200, 20000, undefined, 0, false).reason).toBe("too_fast"));
  test("intervalle minimum par emplacement", () => {
    const dev = { slotLast: { main: T0 + 1000 } };
    expect(viewDecision(payload(), T0 + 5000, 1500, dev, 0, false).reason).toBe("interval"); // 4 s après la précédente (native : 20 s)
    expect(viewDecision(payload(), T0 + 30000, 1500, dev, 0, false).valid).toBe(true);
    expect(viewDecision(payload({ s: "autre" }), T0 + 5000, 1500, dev, 0, false).valid).toBe(true); // un autre emplacement n'est pas concerné
  });
  test("interstitiel : une fois toutes les 10 minutes", () => {
    const dev = { slotLast: { main: T0 - 300_000 } };
    expect(viewDecision(payload({ f: "interstitial", t: T0 }), T0 + 3000, 1500, dev, 0, false).reason).toBe("interval");
  });
  test("3 vues par annonce, appareil et jour", () => {
    expect(viewDecision(payload(), T0 + 3000, 1500, { adViews: { AbCdEfGhIj12: 3 } }, 0, false).reason).toBe("ad_cap");
    expect(viewDecision(payload(), T0 + 3000, 1500, { adViews: { AbCdEfGhIj12: 2 } }, 0, false).valid).toBe(true);
  });
  test("plafonds par appareil et par adresse", () => {
    expect(viewDecision(payload(), T0 + 3000, 1500, { total: 300 }, 0, false).reason).toBe("device_cap");
    expect(viewDecision(payload(), T0 + 3000, 1500, undefined, 2000, false).reason).toBe("ip_cap");
  });
});

describe("clic valide", () => {
  test("cas normal", () => expect(clickDecision(payload(), T0 + 2500, false, false, 0)).toEqual({ valid: true }));
  test("trop rapide : un robot clique avant qu'un humain ait pu voir", () => expect(clickDecision(payload(), T0 + 300, false, false, 0).reason).toBe("too_fast"));
  test("un seul clic par jeton et par jour", () => {
    expect(clickDecision(payload(), T0 + 2500, true, false, 0).reason).toBe("dup_click");
    expect(clickDecision(payload(), T0 + 2500, false, true, 0).reason).toBe("dup_click");
  });
  test("jeton trop ancien ou adresse saturée", () => {
    expect(clickDecision(payload(), T0 + 3 * 3600_000, false, false, 0).reason).toBe("expired");
    expect(clickDecision(payload(), T0 + 2500, false, false, 5000).reason).toBe("ip_cap");
  });
});

describe("lecture complète", () => {
  test("seulement après une vue, une fois, et pas trop vite", () => {
    expect(completeDecision(payload({ f: "rewarded" }), T0 + 20000, false, false, 12000).reason).toBe("no_view");
    expect(completeDecision(payload({ f: "rewarded" }), T0 + 20000, true, true, 12000).reason).toBe("replay");
    expect(completeDecision(payload({ f: "rewarded" }), T0 + 4000, true, false, 12000).reason).toBe("too_fast");
    expect(completeDecision(payload({ f: "rewarded" }), T0 + 20000, true, false, 12000).valid).toBe(true);
  });
});

describe("robots", () => {
  test("agents connus", () => {
    ["Mozilla/5.0 (compatible; Googlebot/2.1)", "curl/8.4.0", "python-requests/2.31", "HeadlessChrome/120", "Go-http-client/2.0", "Java/17.0.1", "", undefined].forEach((ua) => expect(isBotAgent(ua)).toBe(true));
    ["Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", "Dart/3.3 (dart:io)"].forEach((ua) => expect(isBotAgent(ua)).toBe(false));
  });
});

describe("confidentialité", () => {
  test("l'empreinte IP change chaque jour, l'identifiant change par diffuseur", () => {
    expect(ipHash("1.2.3.4", "2026-10-29", KEY)).not.toBe(ipHash("1.2.3.4", "2026-10-30", KEY));
    expect(ipHash("1.2.3.4", "2026-10-29", KEY)).toBe(ipHash("1.2.3.4", "2026-10-29", KEY));
    expect(visitorHash("abcdefghij12", "slashatlas", KEY)).not.toBe(visitorHash("abcdefghij12", "pronoflash", KEY));
    expect(ipHash("1.2.3.4", "2026-10-29", KEY)).not.toContain("1.2.3.4");
  });
});

describe("santé d'un diffuseur", () => {
  test("barème 10 % / 25 %", () => {
    expect(publisherHealth(950, 50).status).toBe("ok");
    expect(publisherHealth(850, 150).status).toBe("alert");
    expect(publisherHealth(700, 300).status).toBe("suspend");
  });
  test("pas de décision avec trop peu d'évènements", () => expect(publisherHealth(10, 150).status).toBe("ok"));
  test("taux de clic suspect", () => {
    expect(ctrSuspicious(1000, 120)).toBe(true);
    expect(ctrSuspicious(1000, 20)).toBe(false);
    expect(ctrSuspicious(100, 50)).toBe(false);
  });
});

describe("compteurs répartis et choix d'annonce", () => {
  test("fragments stables et dans les bornes", () => {
    for (const n of ["a", "nonce1234567", newNonce(), newNonce()]) { const s = shardOf(n); expect(s).toBeGreaterThanOrEqual(0); expect(s).toBeLessThan(SHARDS); expect(shardOf(n)).toBe(s); }
    expect(shardId("AD", "2026-10-29", "site", 3)).toBe("AD_2026-10-29_site_3");
    const spread = new Set(Array.from({ length: 300 }, () => shardOf(newNonce())));
    expect(spread.size).toBeGreaterThan(5);
  });
  test("pickAd évite les annonces déjà vues et respecte le plafond", () => {
    const c = [{ id: "A" }, { id: "B" }, { id: "C" }];
    expect(pickAd([], undefined, 0.5)).toBeNull();
    expect(pickAd(c, { adViews: { A: 2, B: 1 } }, 0)?.id).toBe("C");
    expect(pickAd(c, { adViews: { A: 3, B: 3, C: 3 } }, 0.5)).toBeNull();
    expect(pickAd(c, undefined, 0.9999)?.id).toBe("C");
    expect(pickAd(c, undefined, 0)?.id).toBe("A");
  });
});
