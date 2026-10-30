import { EMPTY_METRICS, addMetrics, clawback, detectSharerFraud } from "../adsShare_fraud";

const m = (o: Partial<typeof EMPTY_METRICS>) => ({ ...EMPTY_METRICS, ...o });

describe("détection de fraude d'un partageur", () => {
  test("activité normale : rien", () => {
    expect(detectSharerFraud(m({ total: 40, valid: 30, invalid: 10 })).level).toBe("none");
    expect(detectSharerFraud(m({ total: 10, valid: 0, invalid: 10 })).level).toBe("none"); // trop peu de clics pour conclure
  });
  test("soupçon : 60 % de clics refusés sur 30 clics, 5 auto-clics, 30 doublons → gains bloqués", () => {
    expect(detectSharerFraud(m({ total: 30, valid: 12, invalid: 18 })).level).toBe("hold");
    expect(detectSharerFraud(m({ total: 12, valid: 7, invalid: 5, self: 5 })).level).toBe("hold");
    expect(detectSharerFraud(m({ total: 80, valid: 50, invalid: 30, dup: 30 })).level).toBe("hold");
  });
  test("fraude évidente : 80 % de refus sur 50 clics, 15 auto-clics, 40 navigateurs trop rapides → gains retirés", () => {
    expect(detectSharerFraud(m({ total: 50, valid: 10, invalid: 40 })).level).toBe("severe");
    expect(detectSharerFraud(m({ total: 20, valid: 5, invalid: 15, self: 15 })).level).toBe("severe");
    expect(detectSharerFraud(m({ total: 100, valid: 40, invalid: 60, tooFast: 40 })).level).toBe("severe");
  });
  test("la gravité la plus forte l'emporte et les raisons sont expliquées", () => {
    const r = detectSharerFraud(m({ total: 60, valid: 6, invalid: 54, self: 20 }));
    expect(r.level).toBe("severe"); expect(r.reasons.length).toBeGreaterThanOrEqual(2); expect(r.reasons.join(" ")).toMatch(/90 %/);
  });
  test("cumul de plusieurs jours", () => {
    const a = addMetrics(m({ total: 20, invalid: 12, valid: 8 }), m({ total: 20, invalid: 14, valid: 6 }));
    expect(a).toEqual(m({ total: 40, invalid: 26, valid: 14 })); expect(detectSharerFraud(a).level).toBe("hold");
  });
});

describe("reprise des gains", () => {
  test("pièces reprises sur le solde, le reste devient une dette (jamais de solde négatif)", () => {
    expect(clawback(25, 100)).toEqual({ take: 25, debt: 0 });
    expect(clawback(25, 10)).toEqual({ take: 10, debt: 15 });
    expect(clawback(25, 0)).toEqual({ take: 0, debt: 25 });
    expect(clawback(-5, 100)).toEqual({ take: 0, debt: 0 });
  });
});
