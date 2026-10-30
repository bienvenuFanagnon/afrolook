import * as fs from "fs";
import * as path from "path";
import { AD_CATEGORIES, FORBIDDEN_CONTENT } from "../adsCategories";
import { PUBLISHER_RULES, PUBLISHER_RULES_VERSION } from "../adsRules";

/**
 * Le site (pages Règles des diffuseurs, formulaires) lit des copies JSON des règles et des catégories.
 * Si ce test échoue : relancer « node functions/scripts/sync-ads-site.cjs » après avoir compilé (npm run build) pour régénérer site/src/ads_rules.json et ads_categories.json.
 */
const site = (f: string) => JSON.parse(fs.readFileSync(path.resolve(__dirname, "../../../../site/src", f), "utf8"));

describe("le site reprend exactement les règles et les catégories du serveur", () => {
  test("règles des diffuseurs (version et texte)", () => {
    const j = site("ads_rules.json");
    expect(j.version).toBe(PUBLISHER_RULES_VERSION);
    expect(j.blocks).toEqual(PUBLISHER_RULES);
  });
  test("catégories d'annonces", () => {
    const j = site("ads_categories.json");
    expect(j.categories).toEqual(AD_CATEGORIES);
    expect(j.forbidden).toEqual(FORBIDDEN_CONTENT);
  });
});
