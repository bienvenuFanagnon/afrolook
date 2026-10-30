import { AD_CATEGORIES, INTERNAL_ACCEPT, SENSITIVE_KEYS, STANDARD_KEYS, categoryAllowed, cleanAccepted, isCategory, isSensitive } from "../adsCategories";

describe("catégories d'annonces", () => {
  test("standard et sensibles", () => {
    expect(STANDARD_KEYS.length).toBeGreaterThanOrEqual(12);
    for (const k of ["finance", "paris_jeux", "alcool_tabac", "medicaments", "rencontres", "sensuel", "politique", "religion", "loterie", "crypto"]) expect(isSensitive(k)).toBe(true);
    for (const k of ["commerce", "restauration", "mode_beaute", "technologie", "sport"]) expect(isSensitive(k)).toBe(false);
    expect(STANDARD_KEYS.length + SENSITIVE_KEYS.length).toBe(Object.keys(AD_CATEGORIES).length);
    expect(AD_CATEGORIES["sensuel"].hint).toMatch(/explicite/);
  });
  test("catégories valides seulement (pas de clés héritées de l'objet)", () => {
    expect(isCategory("finance")).toBe(true);
    expect(isCategory("adulte")).toBe(false);
    expect(isCategory("constructor")).toBe(false);
    expect(isCategory("toString")).toBe(false);
    expect(isCategory(undefined)).toBe(false);
  });
  test("choix du diffuseur : par défaut les catégories standard, les sensibles seulement si cochées", () => {
    expect(cleanAccepted(undefined)).toEqual(STANDARD_KEYS);
    expect(cleanAccepted([])).toEqual(STANDARD_KEYS);
    expect(cleanAccepted(["nimporte", 5])).toEqual(STANDARD_KEYS);
    expect(cleanAccepted(["sport", "finance", "sport", "armes"])).toEqual(["sport", "finance"]);
    expect(cleanAccepted(STANDARD_KEYS)).not.toContain("sensuel");
  });
  test("diffusion : seulement ce que le diffuseur accepte", () => {
    const accept = new Set(["commerce", "sport"]);
    expect(categoryAllowed("commerce", accept, false)).toBe(true);
    expect(categoryAllowed("sensuel", accept, false)).toBe(false);
    expect(categoryAllowed("finance", accept, false)).toBe(false);
    expect(categoryAllowed("", accept, false)).toBe(false); // sans catégorie : jamais chez un diffuseur externe
    expect(categoryAllowed("", accept, true)).toBe(true); // anciennes annonces de l'application : nos plateformes seulement
  });
  test("nos plateformes : aucune ne reçoit de contenu sensuel, d'alcool ou de médicaments par défaut", () => {
    for (const [pub, list] of Object.entries(INTERNAL_ACCEPT)) for (const k of ["sensuel", "alcool_tabac", "medicaments", "rencontres", "politique"]) expect([pub, list.includes(k)]).toEqual([pub, false]);
    expect(INTERNAL_ACCEPT["pronoflash"]).toContain("paris_jeux");
    expect(INTERNAL_ACCEPT["epargneplus"]).toContain("finance");
    expect(INTERNAL_ACCEPT["slashatlas"]).not.toContain("paris_jeux");
  });
});
