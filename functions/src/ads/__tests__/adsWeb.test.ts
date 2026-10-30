import { BANNER_SIZES, bannerKeyOf, cleanPhone, daysLeft, displayStatus, mediaUrlPattern, occupiesFreeSlot, safeHttpsUrl, validateAdInput, DAY_MICROS } from "../adsWeb_logic";

const B = "afrolooki.appspot.com";
const img = (n = "a1") => `https://firebasestorage.googleapis.com/v0/b/${B}/o/ad_images%2F${n}.jpg?alt=media&token=1a2b3c4d-1111-2222-3333-444455556666`;
const vid = "https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_videos%2Fv1.mp4?alt=media&token=1a2b3c4d-1111-2222-3333-444455556666";
const ok = { category: "commerce", kind: "site", title: "Kofi Studio", text: "Ton site web professionnel en 7 jours.", mediaType: "image", images: [img()], action: "visit", link: "https://kofistudio.com", countries: ["TG", "CI"] };

describe("annonce déposée depuis le site", () => {
  test("annonce complète : acceptée et normalisée", () => {
    const r = validateAdInput(ok, B);
    expect(r.ok).toBe(true);
    if (r.ok) { expect(r.value.actionUrl).toBe("https://kofistudio.com/"); expect(r.value.countries).toEqual(["TG", "CI"]); }
  });
  test("titre ou texte trop courts, type inconnu", () => {
    expect(validateAdInput({ ...ok, title: "K" }, B).ok).toBe(false);
    expect(validateAdInput({ ...ok, text: "court" }, B).ok).toBe(false);
    expect(validateAdInput({ ...ok, kind: "casino" }, B).ok).toBe(false);
  });
  test("le balisage et les caractères de contrôle sont retirés du texte", () => {
    const r = validateAdInput({ ...ok, text: "<script>alert(1)</script>Offre spéciale pour tous\u0007" }, B);
    expect(r.ok && r.value.text).toBe("alert(1)Offre spéciale pour tous");
  });
  test("médias : seuls les fichiers de notre stockage sont acceptés", () => {
    expect(validateAdInput({ ...ok, images: ["https://evil.com/x.jpg"] }, B).ok).toBe(false);
    expect(validateAdInput({ ...ok, images: [] }, B).ok).toBe(false);
    expect(validateAdInput({ ...ok, images: [1, 2, 3, 4, 5, 6].map((i) => img("i" + i)) }, B).ok).toBe(false);
    expect(validateAdInput({ ...ok, images: [vid] }, B).ok).toBe(false); // une vidéo n'est pas une image
    expect(validateAdInput({ ...ok, mediaType: "video", images: [], videoUrl: vid, videoDuration: 12 }, B).ok).toBe(true);
  });
  test("liens : https public seulement", () => {
    for (const bad of ["http://site.com", "javascript:alert(1)", "https://localhost/x", "https://192.168.1.2/", "https://user:pw@site.com", "https://site", "ftp://site.com"]) {
      expect(validateAdInput({ ...ok, link: bad }, B).ok).toBe(false);
    }
    expect(safeHttpsUrl("https://app.exemple.com/page?x=1")).toBe("https://app.exemple.com/page?x=1");
  });
  test("WhatsApp et Appeler : numéro obligatoire, adresse construite par le serveur", () => {
    const w = validateAdInput({ ...ok, action: "whatsapp", link: undefined, phone: "+228 90 12 34 56" }, B);
    expect(w.ok && w.value.actionUrl).toBe("https://wa.me/22890123456");
    const c = validateAdInput({ ...ok, action: "call", link: undefined, phone: "90123456" }, B);
    expect(c.ok && c.value.actionUrl).toBe("tel:+90123456");
    expect(validateAdInput({ ...ok, action: "call", link: undefined, phone: "abc" }, B).ok).toBe(false);
    expect(cleanPhone("12")).toBeNull();
  });
  test("pays : « ALL » ou liste de codes à deux lettres", () => {
    const all = validateAdInput({ ...ok, countries: ["TG", "all"] }, B);
    expect(all.ok && all.value.countries).toEqual(["ALL"]);
    expect(validateAdInput({ ...ok, countries: [] }, B).ok && true).toBe(true);
    expect(validateAdInput({ ...ok, countries: ["TOGO"] }, B).ok).toBe(false);
  });
  test("motif de l'adresse de stockage", () => {
    expect(mediaUrlPattern(B).test(img())).toBe(true);
    expect(mediaUrlPattern("autre.appspot.com").test(img())).toBe(false);
  });
});

describe("places gratuites et statuts", () => {
  const now = 1_000 * DAY_MICROS;
  test("en attente et en ligne occupent une place, pas les autres", () => {
    expect(occupiesFreeSlot({ status: "pending" }, now)).toBe(true);
    expect(occupiesFreeSlot({ status: "active", endDate: now + DAY_MICROS }, now)).toBe(true);
    expect(occupiesFreeSlot({ status: "active", endDate: now - 1 }, now)).toBe(false);
    for (const s of ["rejected", "cancelled", "expired"]) expect(occupiesFreeSlot({ status: s }, now)).toBe(false);
  });
  test("statut affiché à l'annonceur", () => {
    expect(displayStatus({ status: "pending" }, now)).toBe("validation");
    expect(displayStatus({ status: "active", endDate: now + 5 * DAY_MICROS }, now)).toBe("ligne");
    expect(displayStatus({ status: "active", endDate: now - 5 }, now)).toBe("terminee");
    expect(displayStatus({ status: "rejected" }, now)).toBe("refusee");
    expect(displayStatus({ status: "cancelled" }, now)).toBe("arretee");
  });
  test("jours restants arrondis au-dessus", () => {
    expect(daysLeft(now + 9 * DAY_MICROS - 1, now)).toBe(9);
    expect(daysLeft(now - 1, now)).toBe(0);
  });
});

import { countsAsFree, readAdsWebConfig, renewalDecision, viewMilestone } from "../adsWeb_logic";

describe("gratuité : 3 annonces au total, un renouvellement gratuit, puis paiement", () => {
  test("seules les annonces gratuites du site non refusées comptent", () => {
    expect(countsAsFree({ source: "web", freeOffer: true, status: "pending" })).toBe(true);
    expect(countsAsFree({ source: "web", freeOffer: true, status: "cancelled" })).toBe(true); // arrêtée : la place est consommée
    expect(countsAsFree({ source: "web", freeOffer: true, status: "rejected" })).toBe(false); // refusée : on peut la corriger et la redéposer
    expect(countsAsFree({ source: "app", status: "active" })).toBe(false);
  });
  test("réglages par défaut et suppression de la gratuité", () => {
    expect(readAdsWebConfig(undefined)).toEqual({ enabled: true, freeAds: 3, freePeriods: 2, freeDays: 14 });
    expect(readAdsWebConfig({ freeAds: 0 }).freeAds).toBe(0);
    expect(readAdsWebConfig({ freeAds: "n'importe quoi", freeDays: 9999 })).toEqual({ enabled: true, freeAds: 3, freePeriods: 2, freeDays: 14 });
  });
  const now = 5_000 * DAY_MICROS;
  const cfg = { freePeriods: 2 };
  test("renouvellement : seulement une annonce terminée ; 1er renouvellement gratuit, le suivant payant", () => {
    expect(renewalDecision({ status: "active", endDate: now + 1, renewalCount: 0 }, cfg, now)).toBe("not_ended");
    expect(renewalDecision({ status: "pending", endDate: now - 1 }, cfg, now)).toBe("not_renewable");
    expect(renewalDecision({ status: "active", endDate: now - 1, renewalCount: 0 }, cfg, now)).toBe("ok");
    expect(renewalDecision({ status: "active", endDate: now - 1, renewalCount: 1 }, cfg, now)).toBe("payment_required");
    expect(renewalDecision({ status: "active", endDate: now - 1, renewalCount: 1 }, { freePeriods: 3 }, now)).toBe("ok");
  });
});

describe("courriel à chaque palier de 100 vues", () => {
  test("palier franchi : 100, 200, 300…", () => {
    expect(viewMilestone(99, 100, 0)).toBe(100);
    expect(viewMilestone(180, 205, 100)).toBe(200);
    expect(viewMilestone(290, 301, 200)).toBe(300);
  });
  test("pas de palier : pas de courriel", () => {
    expect(viewMilestone(100, 150, 100)).toBeNull();
    expect(viewMilestone(0, 40, 0)).toBeNull();
    expect(viewMilestone(120, 120, 100)).toBeNull();
  });
  test("jamais deux fois le même palier", () => {
    expect(viewMilestone(199, 200, 200)).toBeNull();
  });
  test("plusieurs paliers d'un coup : le plus haut est annoncé une seule fois", () => {
    expect(viewMilestone(90, 340, 0)).toBe(300);
  });
});

describe("vidéo de 15 secondes maximum", () => {
  const base = { category: "commerce", kind: "site", title: "Kofi Studio", text: "Ton site web professionnel en 7 jours.", mediaType: "video", images: [], videoUrl: vid, action: "visit", link: "https://kofistudio.com", countries: ["ALL"] };
  test("15 secondes : acceptée, durée gardée", () => {
    const r = validateAdInput({ ...base, videoDuration: 14.96 }, B);
    expect(r.ok && r.value.videoDuration).toBe(15);
  });
  test("plus de 15 secondes, durée absente ou illisible : refusée", () => {
    expect(validateAdInput({ ...base, videoDuration: 22 }, B).ok).toBe(false);
    expect(validateAdInput({ ...base, videoDuration: 16 }, B).ok).toBe(false);
    expect(validateAdInput({ ...base }, B).ok).toBe(false);
    expect(validateAdInput({ ...base, videoDuration: "abc" }, B).ok).toBe(false);
    expect(validateAdInput({ ...base, videoDuration: 0 }, B).ok).toBe(false);
  });
  test("une annonce image n'a pas de durée", () => {
    const r = validateAdInput({ ...ok }, B);
    expect(r.ok && r.value.videoDuration).toBe(0);
  });
});

import { isBot, trackDecision, validPlacement, validVisitorId } from "../adsWeb_logic";

describe("vues et clics de la plateforme", () => {
  test("une vue et un clic par visiteur, annonce et jour", () => {
    expect(trackDecision(undefined, "view", "2026-10-29")).toEqual({ count: true, unique: true });
    expect(trackDecision({ viewed: true, lastViewDay: "2026-10-29" }, "view", "2026-10-29")).toEqual({ count: false, unique: false });
    expect(trackDecision({ viewed: true, lastViewDay: "2026-10-28" }, "view", "2026-10-29")).toEqual({ count: true, unique: false }); // le lendemain : compté, mais plus « unique »
    expect(trackDecision({ viewed: true, lastViewDay: "2026-10-29" }, "click", "2026-10-29")).toEqual({ count: true, unique: true }); // la vue n'empêche pas le clic
    expect(trackDecision({ clicked: true, lastClickDay: "2026-10-29" }, "click", "2026-10-29").count).toBe(false);
  });
  test("robots, identifiants et plateformes", () => {
    expect(isBot("Mozilla/5.0 (compatible; Googlebot/2.1)")).toBe(true);
    expect(isBot("facebookexternalhit/1.1")).toBe(true);
    expect(isBot("Mozilla/5.0 (Linux; Android 14) Chrome/120 Mobile Safari/537.36")).toBe(false);
    expect(validVisitorId("a1b2c3d4-e5f6-7890")).toBe(true);
    expect(validVisitorId("court")).toBe(false);
    expect(validVisitorId("x".repeat(80))).toBe(false);
    expect(validPlacement("slashatlas")).toBe("slashatlas");
    expect(validPlacement("<script>")).toBe("site");
    expect(validPlacement(undefined)).toBe("site");
  });
});

describe("catégorie et ciblage de l'annonce", () => {
  const okAd = { category: "commerce", kind: "site", title: "Kofi Studio", text: "Ton site web professionnel en 7 jours.", mediaType: "image", images: [img()], action: "visit", link: "https://kofistudio.com", countries: ["TG"] };
  test("la catégorie est obligatoire et doit exister (les contenus interdits n'ont pas de catégorie)", () => {
    expect(validateAdInput({ ...okAd, category: "" }, B).ok).toBe(false);
    expect(validateAdInput({ ...okAd, category: "adulte" }, B).ok).toBe(false);
    expect(validateAdInput({ ...okAd, category: "armes" }, B).ok).toBe(false);
    const r = validateAdInput({ ...okAd, category: "sensuel" }, B);
    expect(r.ok && r.value.category).toBe("sensuel");
    expect(validateAdInput({ ...okAd, category: undefined }, B)).toEqual({ ok: false, error: "catégorie de l'annonce manquante" });
  });
  test("ciblage : toute l'Afrique remplace « tous les pays » par la liste des pays d'Afrique", () => {
    const r = validateAdInput({ ...okAd, countries: ["ALL"], regions: ["AFRICA"] }, B);
    expect(r.ok && r.value.countries.length).toBe(54);
    expect(r.ok && r.value.countries).toContain("TG");
    expect(r.ok && r.value.countries).not.toContain("FR");
    const m = validateAdInput({ ...okAd, countries: ["FR"], regions: ["AFRICA"] }, B);
    expect(m.ok && m.value.countries).toContain("FR");
    expect(validateAdInput({ ...okAd, countries: ["ALL"] }, B).ok && true).toBe(true);
  });
  test("langues, appareils et types de sites : nettoyés, facultatifs", () => {
    const r = validateAdInput({ ...okAd, languages: ["FR", "en", "xyz", "fr"], devices: ["mobile", "tablette"], categories: ["sport", "inconnue"] }, B);
    expect(r.ok && r.value.languages).toEqual(["fr", "en"]);
    expect(r.ok && r.value.devices).toEqual(["mobile"]);
    expect(r.ok && r.value.categories).toEqual(["sport"]);
    const v = validateAdInput(okAd, B);
    expect(v.ok && v.value.languages).toEqual([]);
  });
});

describe("bannières prêtes à l'emploi", () => {
  test("tailles standard AdMob et clé de taille", () => {
    expect(BANNER_SIZES.b728x90).toEqual([728, 90]); expect(BANNER_SIZES.b320x50).toEqual([320, 50]); expect(BANNER_SIZES.b320x100).toEqual([320, 100]); expect(BANNER_SIZES.b300x250).toEqual([300, 250]);
    expect(bannerKeyOf("728x90")).toBe("b728x90"); expect(bannerKeyOf("320x50")).toBe("b320x50");
    expect(bannerKeyOf("999x9")).toBeNull(); expect(bannerKeyOf(undefined)).toBeNull(); expect(bannerKeyOf("__proto__")).toBeNull();
  });
  test("bannières de notre stockage : acceptées et normalisées", () => {
    const r = validateAdInput({ ...ok, banners: { b728x90: img("bn1"), b320x50: img("bn2"), inconnue: img("x") } }, B);
    expect(r.ok).toBe(true);
    if (r.ok) expect(Object.keys(r.value.bannerImages).sort()).toEqual(["b320x50", "b728x90"]);
  });
  test("sans bannière : tout reste comme avant", () => {
    const r = validateAdInput(ok, B); expect(r.ok && r.value.bannerImages).toEqual({});
  });
  test("bannière hors de notre stockage ou vidéo : refusée", () => {
    expect(validateAdInput({ ...ok, banners: { b728x90: "https://evil.com/b.jpg" } }, B).ok).toBe(false);
    expect(validateAdInput({ ...ok, banners: { b300x250: vid } }, B).ok).toBe(false);
  });
});
