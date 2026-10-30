import { activityFromEvents, riskOf } from "../offerwall_fraud";

const NOW = Date.parse("2026-10-27T12:00:00Z");
const H = 3_600_000;
const ev = (coins: number, hoursAgo: number, status = "pending") => ({ coins, createdAt: NOW - hoursAgo * H, status });

describe("activité", () => {
  test("totaux, 24 h, revues et refus ; les refus ne comptent pas dans les gains", () => {
    const a = activityFromEvents([ev(100, 1), ev(200, 30), ev(50, 2, "validee"), ev(70, 3, "en_revue"), ev(10, 1, "refusee")], NOW, NOW - 3 * 86_400_000);
    expect(a.coins).toBe(100 + 200 + 50 + 70);
    expect(a.events).toBe(4);
    expect(a.eventsLast24h).toBe(3);
    expect(a.coinsLast24h).toBe(100 + 50 + 70);
    expect(a.reviewCount).toBe(1);
    expect(a.refusedCount).toBe(1);
    expect(a.accountAgeDays).toBe(3);
  });
  test("aucun événement : tout à zéro", () => {
    const a = activityFromEvents([], NOW, null);
    expect(a).toMatchObject({ events: 0, coins: 0, eventsLast24h: 0, reviewCount: 0, topSameAmountCount: 0, accountAgeDays: null });
  });
  test("montant le plus fréquent", () => {
    expect(activityFromEvents([ev(75, 1), ev(75, 2), ev(75, 3), ev(10, 4)], NOW, null).topSameAmountCount).toBe(3);
  });
});

describe("risque", () => {
  const cfg = { dailyCapCoins: 2000 };
  const calm = { events: 3, coins: 300, eventsLast24h: 1, coinsLast24h: 100, reviewCount: 0, refusedCount: 0, accountAgeDays: 40, topSameAmountCount: 1 };
  test("comportement normal → faible, sans signal", () => {
    expect(riskOf(calm, cfg)).toEqual({ score: 0, level: "faible", flags: [] });
  });
  test("rafale + plafond atteint → élevé avec explications", () => {
    const r = riskOf({ ...calm, eventsLast24h: 12, coinsLast24h: 1900 }, cfg);
    expect(r.level).toBe("élevé");
    expect(r.flags.join(" ")).toMatch(/Rafale/);
    expect(r.flags.join(" ")).toMatch(/Plafond/);
  });
  test("compte récent avec gains élevés → moyen", () => {
    expect(riskOf({ ...calm, accountAgeDays: 2, coins: 800 }, cfg).level).toBe("moyen");
  });
  test("mêmes gains répétés et revues multiples", () => {
    const r = riskOf({ ...calm, topSameAmountCount: 6, reviewCount: 2 }, cfg);
    expect(r.score).toBe(4);
    expect(r.level).toBe("moyen");
  });
});
