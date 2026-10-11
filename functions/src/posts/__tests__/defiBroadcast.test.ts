import { inTargetCountry, targetCountries } from "../defiBroadcast";

describe("annonce d'un DÉFI : pays visés", () => {
  test("aucun pays ou ALL : tous les pays", () => {
    expect(targetCountries({})).toEqual([]);
    expect(targetCountries({ availableCountries: ["ALL"] })).toEqual([]);
    expect(targetCountries({ availableCountries: [] })).toEqual([]);
  });
  test("liste de pays en majuscules", () => {
    expect(targetCountries({ availableCountries: ["tg", "SN"] })).toEqual(["TG", "SN"]);
  });
  test("un compte hors des pays visés n'est pas notifié, sauf si le post ne cible aucun pays", () => {
    const tg = { countryData: { countryCode: "tg" } };
    expect(inTargetCountry(tg, ["TG", "SN"])).toBe(true);
    expect(inTargetCountry({ countryData: { countryCode: "FR" } }, ["TG"])).toBe(false);
    expect(inTargetCountry({}, ["TG"])).toBe(false);
    expect(inTargetCountry({}, [])).toBe(true);
  });
});
