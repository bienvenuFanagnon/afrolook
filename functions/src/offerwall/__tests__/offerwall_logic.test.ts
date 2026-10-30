import { createHash } from "crypto";
import {
  DEFAULT_OFFERWALL_CONFIG, blockReason, capDecision, dayOf, eventId, lastSevenDays, parseCoins, readOfferwallConfig, safeEqualHex, splitCoins, tapjoyVerifier,
} from "../offerwall_logic";

describe("signature Tapjoy", () => {
  test("MD5 de « id:snuid:currency:clé »", () => {
    const expected = createHash("md5").update("abc123:uid42:750:secret").digest("hex");
    expect(tapjoyVerifier("abc123", "uid42", "750", "secret")).toBe(expected);
    expect(tapjoyVerifier("abc123", "uid42", "750", "secret")).toMatch(/^[0-9a-f]{32}$/);
  });
  test("toute modification change la signature (id, utilisateur, montant, clé)", () => {
    const base = tapjoyVerifier("a", "u", "10", "k");
    expect(tapjoyVerifier("b", "u", "10", "k")).not.toBe(base);
    expect(tapjoyVerifier("a", "v", "10", "k")).not.toBe(base);
    expect(tapjoyVerifier("a", "u", "11", "k")).not.toBe(base);
    expect(tapjoyVerifier("a", "u", "10", "z")).not.toBe(base);
  });
  test("comparaison de signatures : égales, différentes, longueurs différentes, vides", () => {
    expect(safeEqualHex("abcdef", "abcdef")).toBe(true);
    expect(safeEqualHex("abcdef", "abcdee")).toBe(false);
    expect(safeEqualHex("abc", "abcdef")).toBe(false);
    expect(safeEqualHex("", "")).toBe(false);
  });
});

describe("pièces : toujours des entiers", () => {
  const MAX = 100000;
  test("entiers acceptés", () => {
    expect(parseCoins("750", MAX)).toEqual({ ok: true, coins: 750 });
    expect(parseCoins(" 5 ", MAX)).toEqual({ ok: true, coins: 5 });
  });
  test("décimaux arrondis par le bas, jamais de pièce fractionnaire", () => {
    expect(parseCoins("74.7", MAX)).toEqual({ ok: true, coins: 74 });
    expect(parseCoins("750.999", MAX)).toEqual({ ok: true, coins: 750 });
    expect(Number.isInteger((parseCoins("12.5", MAX) as { coins: number }).coins)).toBe(true);
  });
  test("refus : vide, négatif, texte, notation scientifique, nul, trop grand", () => {
    for (const bad of ["", "-5", "abc", "1e3", "NaN", "Infinity", "0", "0.9", "100001", "5,5", " ", null, undefined]) {
      expect(parseCoins(bad as never, MAX).ok).toBe(false);
    }
  });
  test("très grands nombres : refusés sans erreur", () => {
    expect(parseCoins("99999999999999999999", MAX).ok).toBe(false);
  });
});

describe("répartition 50 % utilisateur / 10 % parrain / Studio", () => {
  test("1 $ = 750 pièces : avec parrain 750 / 150 / 600 ; sans parrain 750 / 0 / 750", () => {
    expect(splitCoins(750, 20, true)).toEqual({ user: 750, sponsor: 150, studio: 600 });
    expect(splitCoins(750, 20, false)).toEqual({ user: 750, sponsor: 0, studio: 750 });
  });
  test("0,30 $ = 225 pièces → parrain 45", () => {
    expect(splitCoins(225, 20, true)).toEqual({ user: 225, sponsor: 45, studio: 180 });
  });
  test("petits montants : le parrain reçoit ⌊20 %⌋ (7 → 1, 4 → 0, 1 → 0)", () => {
    expect(splitCoins(7, 20, true).sponsor).toBe(1);
    expect(splitCoins(4, 20, true).sponsor).toBe(0);
    expect(splitCoins(1, 20, true).sponsor).toBe(0);
  });
  test("tout est entier et le total est conservé (parrain + Studio = pièces de l'utilisateur)", () => {
    for (let c = 1; c <= 3000; c += 7) {
      const s = splitCoins(c, 20, true);
      expect(Number.isInteger(s.user) && Number.isInteger(s.sponsor) && Number.isInteger(s.studio)).toBe(true);
      expect(s.sponsor + s.studio).toBe(s.user);
      expect(s.studio).toBeGreaterThanOrEqual(0);
    }
  });
  test("le parrain ne dépasse jamais 100 % même mal réglé", () => {
    expect(splitCoins(10, 100, true).studio).toBe(0);
  });
});

describe("plafonds", () => {
  const cfg = { dailyCapCoins: 2000, weeklyCapCoins: 10000 };
  test("dans les plafonds → ok", () => expect(capDecision(0, 0, 750, cfg)).toBe("ok"));
  test("pile au plafond du jour → ok ; au-delà → revue (jamais refusé)", () => {
    expect(capDecision(1250, 1250, 750, cfg)).toBe("ok");
    expect(capDecision(1251, 1251, 750, cfg)).toBe("revue");
  });
  test("plafond de la semaine", () => {
    expect(capDecision(0, 9500, 750, cfg)).toBe("revue");
    expect(capDecision(0, 9250, 750, cfg)).toBe("ok");
  });
});

describe("compte et réglages", () => {
  const NOW = Date.parse("2026-10-27T12:00:00Z");
  const ok = { exists: true, deleted: false, pendingDeletion: false, createdAt: NOW - 10 * 86_400_000, emailVerified: true, blockedFromOffers: false };
  const cfg = { minAccountAgeDays: 3, requireVerifiedEmail: true };
  test("compte conforme → aucune raison de bloquer", () => expect(blockReason(ok, cfg, NOW)).toBeNull());
  test("raisons de blocage", () => {
    expect(blockReason({ ...ok, exists: false }, cfg, NOW)).toBe("compte inconnu");
    expect(blockReason({ ...ok, deleted: true }, cfg, NOW)).toMatch(/suppression/);
    expect(blockReason({ ...ok, pendingDeletion: true }, cfg, NOW)).toMatch(/suppression/);
    expect(blockReason({ ...ok, blockedFromOffers: true }, cfg, NOW)).toMatch(/suspendu/);
    expect(blockReason({ ...ok, createdAt: NOW - 86_400_000 }, cfg, NOW)).toBe("compte trop récent");
    expect(blockReason({ ...ok, createdAt: 0 }, cfg, NOW)).toBe("compte trop récent");
    expect(blockReason({ ...ok, emailVerified: false }, cfg, NOW)).toBe("e-mail non vérifié");
    expect(blockReason({ ...ok, emailVerified: false }, { ...cfg, requireVerifiedEmail: false }, NOW)).toBeNull();
  });
  test("réglages : valeurs par défaut, bornes, valeurs absurdes ignorées", () => {
    expect(readOfferwallConfig(undefined)).toEqual(DEFAULT_OFFERWALL_CONFIG);
    expect(readOfferwallConfig({ holdHours: 24, dailyCapCoins: 5000, sponsorPct: 10 })).toMatchObject({ holdHours: 24, dailyCapCoins: 5000, sponsorPct: 10 });
    expect(readOfferwallConfig({ holdHours: -5, sponsorPct: 400, dailyCapCoins: "abc" })).toMatchObject({ holdHours: 48, sponsorPct: 20, dailyCapCoins: 2000 });
    expect(readOfferwallConfig({ enabled: false }).enabled).toBe(false);
  });
});

describe("événements et jours", () => {
  test("identifiant d'événement stable et propre à la régie", () => {
    expect(eventId("tapjoy", "req-1")).toBe(eventId("tapjoy", "req-1"));
    expect(eventId("tapjoy", "req-1")).not.toBe(eventId("tapjoy", "req-2"));
    expect(eventId("tapjoy", "req-1")).not.toBe(eventId("ayet", "req-1"));
    expect(eventId("tapjoy", "../../x")).toMatch(/^tapjoy_[0-9a-f]{40}$/);
  });
  test("les 7 derniers jours (aujourd'hui inclus)", () => {
    const d = lastSevenDays(Date.parse("2026-10-27T12:00:00Z"));
    expect(d).toHaveLength(7);
    expect(d[0]).toBe("2026-10-27");
    expect(d[6]).toBe("2026-10-21");
    expect(dayOf(Date.parse("2026-10-27T23:59:59Z"))).toBe("2026-10-27");
  });
});
