jest.mock("firebase-functions/v2/https", () => ({ onCall: jest.fn(() => ({})), HttpsError: class extends Error {} }));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: { increment: jest.fn() } }));
jest.mock("../../shared/firebase", () => ({ db: {} }));

import { cleanTags, safeTag, dayKey, MAX_TAGS, MAX_COUNT } from "../readStats";

describe("mesure des lectures : nettoyage des compteurs reçus", () => {
  it("transforme un nom de fichier en clé de champ sûre", () => {
    expect(safeTag("postProvider.dart:601")).toBe("postProvider_dart_601");
    expect(safeTag("a.b/c d")).toBe("a_b_c_d");
    expect(safeTag("x".repeat(200)).length).toBe(70);
  });
  it("garde seulement les compteurs entiers positifs", () => {
    expect(cleanTags({ "a.dart:1": 12, "b.dart:2": 0, "c.dart:3": -4, "d.dart:4": "x", "e.dart:5": 3.9 })).toEqual({ a_dart_1: 12, e_dart_5: 3 });
  });
  it("plafonne une valeur trop grande et additionne deux clés devenues identiques", () => {
    expect(cleanTags({ "a:1": 10 ** 9 }).a_1).toBe(MAX_COUNT);
    expect(cleanTags({ "a.b": 2, "a:b": 3 })).toEqual({ a_b: 5 });
  });
  it("accepte au plus 80 sources et ignore tout ce qui n'est pas un objet", () => {
    const many: Record<string, number> = {};
    for (let i = 0; i < 200; i++) many[`f${i}.dart:1`] = 1;
    expect(Object.keys(cleanTags(many)).length).toBe(MAX_TAGS);
    expect(cleanTags(null)).toEqual({});
    expect(cleanTags("texte")).toEqual({});
  });
  it("jour au format AAAAMMJJ (UTC)", () => {
    expect(dayKey(Date.UTC(2026, 9, 18, 23, 59))).toBe("20261018");
  });
});
