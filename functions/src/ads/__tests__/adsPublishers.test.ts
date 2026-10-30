import {
  BASE_AUDIENCE, audienceEstimate, cleanAppleUrl, cleanPlayUrl, cleanSiteUrl, countedAudience, hostOf, isPropertyId, newPropertyId, newVerifyToken, originsOf, pageHasToken,
  playPackage, validateProfile, validateProperty,
} from "../adsPublishers_logic";

const profile = { type: "company", name: "Kofi Média", country: "tg", city: "Lomé", phone: "+228 90 12 34 56", website: "https://kofimedia.com", about: "Un site d'actualités sportives pour l'Afrique de l'Ouest.", acceptTerms: true };
const site = { kind: "site", name: "Kofi Sport", url: "https://www.kofisport.com/accueil#haut", category: "sport", countries: ["tg", "bj", "tg"], languages: ["fr"], audienceMonthly: 120000, sessionsMonthly: 400000, description: "Résultats, analyses et actualités du football africain." };
const app = { kind: "app", name: "Kofi App", androidUrl: "https://play.google.com/store/apps/details?id=com.kofi.app&hl=fr", category: "sport", countries: ["TG"], audienceMonthly: 5000, description: "Application mobile de résultats en direct pour les supporters." };

describe("profil diffuseur", () => {
  test("valide et normalisé", () => {
    const v = validateProfile(profile);
    expect(v.ok).toBe(true);
    if (v.ok) { expect(v.value.country).toBe("TG"); expect(v.value.phone).toBe("+22890123456"); expect(v.value.website).toBe("https://kofimedia.com/"); }
  });
  test("refus : conditions, nom, téléphone, présentation, site non https", () => {
    expect(validateProfile({ ...profile, acceptTerms: false })).toEqual({ ok: false, error: "conditions à accepter" });
    expect(validateProfile({ ...profile, name: "K" }).ok).toBe(false);
    expect(validateProfile({ ...profile, phone: "12" }).ok).toBe(false);
    expect(validateProfile({ ...profile, about: "trop court" }).ok).toBe(false);
    expect(validateProfile({ ...profile, website: "http://x.com" }).ok).toBe(false);
    expect(validateProfile({ ...profile, type: "autre" }).ok).toBe(false);
    expect(validateProfile({ ...profile, country: "Togo" }).ok).toBe(false);
  });
  test("le site du profil est facultatif", () => expect(validateProfile({ ...profile, website: "" }).ok).toBe(true));
});

describe("site ou application", () => {
  test("site valide : fragment retiré, pays dédoublonnés en majuscules", () => {
    const v = validateProperty(site);
    expect(v.ok).toBe(true);
    if (v.ok) { expect(v.value.url).toBe("https://www.kofisport.com/accueil"); expect(v.value.countries).toEqual(["TG", "BJ"]); }
  });
  test("application valide : paquet lu dans le lien Google Play", () => {
    const v = validateProperty(app);
    expect(v.ok).toBe(true);
    if (v.ok) { expect(v.value.packageName).toBe("com.kofi.app"); expect(v.value.androidUrl).toBe("https://play.google.com/store/apps/details?id=com.kofi.app"); }
  });
  test("une application doit être en ligne : un lien de magasin est obligatoire", () => {
    expect(validateProperty({ ...app, androidUrl: "" }).ok).toBe(false);
    expect(validateProperty({ ...app, androidUrl: "https://exemple.com/app.apk" }).ok).toBe(false);
    expect(validateProperty({ ...app, androidUrl: "", iosUrl: "https://apps.apple.com/fr/app/kofi/id1234567890" }).ok).toBe(true);
  });
  test("refus : site hors ligne par nature (http, IP, localhost, port, identifiants)", () => {
    for (const url of ["http://kofi.com", "https://127.0.0.1", "https://localhost", "https://kofi.com:8443", "https://u:p@kofi.com", "https://intranet", "https://10.0.0.1/x", "javascript:alert(1)", ""]) {
      expect(validateProperty({ ...site, url }).ok).toBe(false);
    }
  });
  test("refus : catégorie, pays, audience, description", () => {
    expect(validateProperty({ ...site, category: "adulte" }).ok).toBe(false);
    expect(validateProperty({ ...site, category: "constructor" }).ok).toBe(false);
    expect(validateProperty({ ...site, countries: [] }).ok).toBe(false);
    expect(validateProperty({ ...site, audienceMonthly: 10 }).ok).toBe(false);
    expect(validateProperty({ ...site, audienceMonthly: 5e9 }).ok).toBe(false);
    expect(validateProperty({ ...site, description: "court" }).ok).toBe(false);
    expect(validateProperty({ ...site, kind: "autre" }).ok).toBe(false);
  });
});

describe("liens et domaines", () => {
  test("Google Play et App Store", () => {
    expect(playPackage("https://play.google.com/store/apps/details?id=com.a.b")).toBe("com.a.b");
    expect(playPackage("https://evil.com/store/apps/details?id=com.a.b")).toBeNull();
    expect(playPackage("https://play.google.com/store/apps/details?id=../x")).toBeNull();
    expect(cleanPlayUrl("n'importe quoi")).toBeNull();
    expect(cleanAppleUrl("https://apps.apple.com/gh/app/afrolook/id6811423047?l=fr")).toBe("https://apps.apple.com/gh/app/afrolook/id6811423047");
    expect(cleanAppleUrl("https://apps.apple.com/gh/app/afrolook")).toBeNull();
    expect(cleanAppleUrl("http://apps.apple.com/gh/app/afrolook/id6811423047")).toBeNull();
  });
  test("origines autorisées", () => {
    expect(hostOf("https://www.kofisport.com/x")).toBe("kofisport.com");
    expect(originsOf("https://www.kofisport.com/x")).toEqual(["https://kofisport.com", "https://www.kofisport.com"]);
    expect(originsOf("pas une adresse")).toEqual([]);
  });
  test("cleanSiteUrl", () => {
    expect(cleanSiteUrl("https://Kofi.COM/a?b=1#c")).toBe("https://kofi.com/a?b=1");
    expect(cleanSiteUrl("ftp://kofi.com")).toBeNull();
  });
});

describe("identifiant publicitaire et preuve de propriété", () => {
  test("identifiants uniques et bien formés", () => {
    const ids = new Set(Array.from({ length: 300 }, () => newPropertyId()));
    expect(ids.size).toBe(300);
    for (const id of ids) expect(isPropertyId(id)).toBe(true);
    expect(isPropertyId("ap_../x")).toBe(false);
    expect(isPropertyId("slashatlas")).toBe(false);
    expect(newVerifyToken()).toMatch(/^afl-[0-9a-f]{24}$/);
  });
  test("le code doit être dans la balise meta ou être tout le fichier", () => {
    const t = "afl-abc123";
    expect(pageHasToken(`<html><head><meta name="afrolook-ads-verify" content="${t}"></head></html>`, t)).toBe(true);
    expect(pageHasToken(`<META NAME='afrolook-ads-verify' CONTENT='${t}'>`, t)).toBe(true);
    expect(pageHasToken(`${t}\n`, t)).toBe(true);
    expect(pageHasToken(`<p>${t}</p>`, t)).toBe(false); // le code dans le texte d'une page ne prouve rien
    expect(pageHasToken(`<meta name="autre" content="${t}">`, t)).toBe(false);
    expect(pageHasToken("", t)).toBe(false);
  });
});

describe("audience du réseau : 50 000 + audience retenue des validés", () => {
  test("base seule", () => expect(audienceEstimate([])).toEqual({ base: BASE_AUDIENCE, partners: 0, total: 50000, count: 0 }));
  test("seuls les sites et applications validés comptent", () => {
    const e = audienceEstimate([
      { status: "active", audienceCounted: 120000 }, { status: "active", audienceCounted: 30000 }, { status: "pending", audienceCounted: 999999 },
      { status: "refused", audienceCounted: 50000 }, { status: "suspended", audienceCounted: 70000 }, { status: "active", audienceCounted: 0 }, { status: "active", audienceCounted: -5 },
    ]);
    expect(e).toEqual({ base: 50000, partners: 150000, total: 200000, count: 2 });
  });
  test("l'audience retenue ne dépasse jamais l'audience déclarée", () => {
    expect(countedAudience(100000, undefined)).toBe(100000);
    expect(countedAudience(100000, 40000)).toBe(40000);
    expect(countedAudience(100000, 900000)).toBe(100000);
    expect(countedAudience(100000, -3)).toBe(0);
    expect(countedAudience(100000, "abc")).toBe(100000);
  });
});
