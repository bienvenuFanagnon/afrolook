import { chunk, isDeadTokenCode, isQuotaError, ONESIGNAL_ID_REGEX, stringifyData, tokensOf } from "../push_logic";

describe("push_logic", () => {
  test("chunk découpe en lots", () => {
    expect(chunk([1, 2, 3, 4, 5], 2)).toEqual([[1, 2], [3, 4], [5]]);
    expect(chunk([], 3)).toEqual([]);
  });

  test("stringifyData convertit tout en texte et retire les valeurs absentes", () => {
    expect(stringifyData({ a: "x", b: 3, c: true, d: null, e: undefined, f: { k: 1 } })).toEqual({ a: "x", b: "3", c: "true", f: "{\"k\":1}" });
    expect(stringifyData(undefined)).toEqual({});
  });

  test("tokensOf ne garde que des jetons plausibles, sans doublon", () => {
    const t = "a".repeat(40);
    expect(tokensOf({ fcmTokens: [t, t, "", 5, "court"] })).toEqual([t]);
    expect(tokensOf({})).toEqual([]);
    expect(tokensOf(undefined)).toEqual([]);
  });

  test("isDeadTokenCode reconnaît les jetons à supprimer", () => {
    expect(isDeadTokenCode("messaging/registration-token-not-registered")).toBe(true);
    expect(isDeadTokenCode("messaging/invalid-registration-token")).toBe(true);
    expect(isDeadTokenCode("messaging/internal-error")).toBe(false);
    expect(isDeadTokenCode(undefined)).toBe(false);
  });

  test("isQuotaError : quota épuisé ou simple erreur", () => {
    expect(isQuotaError(402)).toBe(true);
    expect(isQuotaError(429)).toBe(true);
    expect(isQuotaError(400, { errors: ["Monthly quota exceeded for your plan"] })).toBe(true);
    expect(isQuotaError(403, "Please upgrade your subscription")).toBe(true);
    expect(isQuotaError(400, { errors: ["include_player_ids must be an array"] })).toBe(false);
    expect(isQuotaError(500, "quota")).toBe(false);
    expect(isQuotaError(undefined)).toBe(false);
  });

  test("ONESIGNAL_ID_REGEX", () => {
    expect(ONESIGNAL_ID_REGEX.test("b1b8e6b8-b9f4-4c48-b5ac-6ccae1423c98")).toBe(true);
    expect(ONESIGNAL_ID_REGEX.test("pas-un-uuid")).toBe(false);
  });
});
