import { AFRICA, declaredShare, deviceOf, geoAllowed, geoMatch, langOf, profileMatches, targetingOf } from "../adsTargeting";

const only = (countries: string[], extra: Record<string, unknown> = {}) => targetingOf(extra, countries);

describe("ciblage défini par l'annonceur", () => {
  test("monde entier : aucune contrainte de pays", () => {
    const t = targetingOf({}, ["ALL"]);
    expect(t.countries).toEqual(["ALL"]);
    expect(geoMatch(t, "FR")).toBe("any");
    expect(geoMatch(t, null)).toBe("any");
    expect(geoAllowed("any", { in: 0, out: 0, unknown: 0 })).toBe(true);
    expect(targetingOf({}, []).countries).toEqual(["ALL"]); // rien de précisé = partout
    expect(targetingOf({}, undefined).countries).toEqual(["ALL"]);
  });
  test("pays précis : dans, hors, inconnu", () => {
    const t = only(["TG", "BJ"]);
    expect(geoMatch(t, "TG")).toBe("in");
    expect(geoMatch(t, "FR")).toBe("out");
    expect(geoMatch(t, null)).toBe("unknown");
  });
  test("toute l'Afrique = la liste des pays d'Afrique", () => {
    const t = only(AFRICA);
    expect(AFRICA).toHaveLength(54);
    expect(geoMatch(t, "NG")).toBe("in");
    expect(geoMatch(t, "TG")).toBe("in");
    expect(geoMatch(t, "FR")).toBe("out");
    expect(geoMatch(t, "US")).toBe("out");
  });
});

describe("au plus 40 % de vues hors cible", () => {
  test("dans la cible : toujours diffusé", () => expect(geoAllowed("in", { in: 0, out: 500, unknown: 0 })).toBe(true));
  test("annonce neuve : jamais lancée hors cible", () => {
    expect(geoAllowed("out", { in: 0, out: 0, unknown: 0 })).toBe(false);
    expect(geoAllowed("out", { in: 10, out: 0, unknown: 0 })).toBe(false); // moins de 20 vues : trop tôt
  });
  test("hors cible autorisé tant que la part reste sous 35 % (marge sous la limite de 40 %)", () => {
    expect(geoAllowed("out", { in: 100, out: 20, unknown: 0 })).toBe(true); // 21/121 = 17 %
    expect(geoAllowed("out", { in: 100, out: 40, unknown: 0 })).toBe(true); // 41/141 = 29 %
    expect(geoAllowed("out", { in: 100, out: 53, unknown: 0 })).toBe(false); // 54/154 = 35,06 %
    expect(geoAllowed("out", { in: 60, out: 40, unknown: 0 })).toBe(false); // 41/101 = 40,6 %
  });
  test("pays inconnu compte comme hors cible", () => expect(geoAllowed("unknown", { in: 100, out: 30, unknown: 30 })).toBe(false));
  test("simulation : la part finale ne dépasse jamais 40 %", () => {
    // 10 000 visiteurs, 50 % seulement dans la cible : la diffusion hors cible se bloque d'elle-même
    const c = { in: 40, out: 0, unknown: 0 }; // départ : 40 vues ciblées déjà obtenues
    for (let i = 0; i < 10000; i++) {
      const inside = i % 2 === 0;
      if (inside) c.in++; else if (geoAllowed("out", c)) c.out++;
    }
    const share = c.out / (c.in + c.out);
    expect(share).toBeLessThanOrEqual(0.4);
    expect(share).toBeGreaterThan(0.2); // elle utilise bien la marge autorisée
  });
});

describe("langues, appareils, types de sites", () => {
  const ctx = (over = {}) => ({ lang: "fr", device: "mobile" as const, category: "sport", ...over });
  test("sans critère : tout le monde", () => expect(profileMatches(targetingOf({}, ["ALL"]), ctx())).toBe(true));
  test("langue", () => {
    const t = targetingOf({ targetLanguages: ["fr"] }, ["ALL"]);
    expect(profileMatches(t, ctx())).toBe(true);
    expect(profileMatches(t, ctx({ lang: "en" }))).toBe(false);
    expect(profileMatches(t, ctx({ lang: "" }))).toBe(true); // langue inconnue : pas d'exclusion sans preuve
  });
  test("appareil", () => {
    const t = targetingOf({ targetDevices: ["desktop"] }, ["ALL"]);
    expect(profileMatches(t, ctx())).toBe(false);
    expect(profileMatches(t, ctx({ device: "desktop" }))).toBe(true);
    expect(targetingOf({ targetDevices: ["tablette", "mobile"] }, ["ALL"]).devices).toEqual(["mobile"]);
  });
  test("type de site", () => {
    const t = targetingOf({ targetCategories: ["sport", "actualites"] }, ["ALL"]);
    expect(profileMatches(t, ctx())).toBe(true);
    expect(profileMatches(t, ctx({ category: "finance" }))).toBe(false);
    expect(profileMatches(t, ctx({ category: "" }))).toBe(true);
  });
  test("détection de l'appareil et de la langue", () => {
    expect(deviceOf("Mozilla/5.0 (Linux; Android 14) Mobile Safari")).toBe("mobile");
    expect(deviceOf("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")).toBe("desktop");
    expect(langOf("EN-us", "fr-FR")).toBe("en");
    expect(langOf("zz9", "fr-FR,fr;q=0.9")).toBe("fr");
    expect(langOf("", "")).toBe("");
  });
});

describe("cohérence du diffuseur : d'où viennent vraiment ses visiteurs", () => {
  test("part des visiteurs dans les pays annoncés", () => {
    expect(declaredShare({ TG: 600, BJ: 200, IN: 200 }, ["TG", "BJ"])).toEqual({ share: 0.8, total: 1000 });
    expect(declaredShare({ IN: 900, US: 100 }, ["TG"])).toEqual({ share: 0, total: 1000 });
    expect(declaredShare({}, ["TG"])).toEqual({ share: 0, total: 0 });
  });
});
