import {
  extractHashtags,
  extractInterestsManually,
  HASHTAG_TO_CATEGORY,
  CATEGORY_IDS,
} from "../commentSuggestions";

// ─── extractHashtags ──────────────────────────────────────────────────────────

describe("extractHashtags", () => {
  it("extrait les hashtags simples en minuscule", () => {
    expect(extractHashtags("Super post #Mode #Humour")).toEqual(["mode", "humour"]);
  });

  it("retourne [] si pas de hashtag", () => {
    expect(extractHashtags("Aucun hashtag ici")).toEqual([]);
  });

  it("déduplique les hashtags", () => {
    const result = extractHashtags("#look #look #mode");
    expect(result).toEqual(["look", "mode"]);
  });

  it("limite à 20 hashtags", () => {
    const input = Array.from({ length: 25 }, (_, i) => `#tag${i}`).join(" ");
    expect(extractHashtags(input)).toHaveLength(20);
  });

  it("s'arrête à l'accent (\\w ne couvre pas les caractères accentués)", () => {
    const result = extractHashtags("#Beauté #mode");
    expect(result[0]).toBe("beaut"); // s'arrête avant é
    expect(result[1]).toBe("mode");
  });

  it("retourne [] pour texte vide", () => {
    expect(extractHashtags("")).toEqual([]);
  });
});

// ─── extractInterestsManually ────────────────────────────────────────────────

describe("extractInterestsManually", () => {
  it("mappe #mode → fashion", () => {
    expect(extractInterestsManually(["mode"])).toContain("fashion");
  });

  it("mappe #sport → sport", () => {
    expect(extractInterestsManually(["sport"])).toContain("sport");
  });

  it("utilise typeTabbar LOOKS → fashion si aucun hashtag ne matche", () => {
    expect(extractInterestsManually([], "LOOKS")).toEqual(["fashion"]);
  });

  it("utilise typeTabbar SPORT → sport", () => {
    expect(extractInterestsManually([], "SPORT")).toEqual(["sport"]);
  });

  it("combine hashtags + typeTabbar (sans doublons)", () => {
    const result = extractInterestsManually(["mode", "look"], "LOOKS");
    expect(result).toEqual(["fashion"]); // fashion apparaît une seule fois
  });

  it("retourne ['lifestyle'] si rien ne matche", () => {
    expect(extractInterestsManually([], "")).toEqual(["lifestyle"]);
    expect(extractInterestsManually(["zzzzinconnu"], "")).toEqual(["lifestyle"]);
  });

  it("limite à 3 catégories", () => {
    const hashtags = ["music", "sport", "fashion", "food", "gaming"];
    const result = extractInterestsManually(hashtags);
    expect(result.length).toBeLessThanOrEqual(3);
  });

  it("toutes les valeurs retournées sont des CATEGORY_IDS valides", () => {
    const result = extractInterestsManually(["afrobeat", "foot", "wax", "cuisine"], "SPORT");
    for (const cat of result) {
      expect(CATEGORY_IDS).toContain(cat);
    }
  });
});

// ─── HASHTAG_TO_CATEGORY ─────────────────────────────────────────────────────

describe("HASHTAG_TO_CATEGORY", () => {
  it("toutes les valeurs sont des CATEGORY_IDS valides", () => {
    const values = Object.values(HASHTAG_TO_CATEGORY);
    for (const v of values) {
      expect(CATEGORY_IDS).toContain(v);
    }
  });

  it("les clés courantes existent", () => {
    expect(HASHTAG_TO_CATEGORY["music"]).toBe("music");
    expect(HASHTAG_TO_CATEGORY["afrobeat"]).toBe("music");
    expect(HASHTAG_TO_CATEGORY["football"]).toBe("sport");
    expect(HASHTAG_TO_CATEGORY["looks"]).toBe("fashion");
    expect(HASHTAG_TO_CATEGORY["mode"]).toBe("fashion");
    expect(HASHTAG_TO_CATEGORY["business"]).toBe("business");
  });
});
