import { randomBytes } from "crypto";
import { HLL_M, compareAudience, hllAdd, hllCount, hllFromB64, hllMerge, hllNew, hllToB64 } from "../adsHll";

const ids = (n: number): string[] => Array.from({ length: n }, () => randomBytes(12).toString("hex"));
const fill = (list: string[]) => { const r = hllNew(); list.forEach((x) => hllAdd(r, x)); return r; };
const err = (est: number, real: number) => Math.abs(est - real) / real;

describe("visiteurs uniques (HyperLogLog)", () => {
  test("vide", () => expect(hllCount(hllNew())).toBe(0));
  test("précis à quelques % près, du petit au grand", () => {
    for (const n of [50, 1000, 20000, 200000]) expect(err(hllCount(fill(ids(n))), n)).toBeLessThan(n <= 50 ? 0.1 : 0.04);
  });
  test("un même visiteur n'est compté qu'une fois", () => {
    const a = ids(2000);
    expect(err(hllCount(fill([...a, ...a, ...a])), 2000)).toBeLessThan(0.04);
  });
  test("fusion de plusieurs jours : les visiteurs qui reviennent ne comptent qu'une fois", () => {
    const base = ids(5000), j1 = [...base, ...ids(1000)], j2 = [...base.slice(0, 3000), ...ids(2000)]; // 5000 + 1000 + 2000 = 8000 personnes différentes
    const m = hllNew(); hllMerge(m, fill(j1)); hllMerge(m, fill(j2));
    expect(err(hllCount(m), 8000)).toBeLessThan(0.04);
  });
  test("enregistrement compact et relecture identique", () => {
    const r = fill(ids(3000)); const s = hllToB64(r);
    expect(Buffer.from(s, "base64").length).toBe(HLL_M);
    expect(hllCount(hllFromB64(s))).toBe(hllCount(r));
    expect(hllCount(hllFromB64(undefined))).toBe(0);
    expect(hllCount(hllFromB64("pas du base64 valide !!!"))).toBeGreaterThanOrEqual(0);
  });
});

describe("audience mesurée comparée à l'audience déclarée", () => {
  test("pas de conclusion avant 7 jours de mesure", () => expect(compareAudience(10000, 100, 100, 10, 3).status).toBe("no_data"));
  test("conforme, en dessous, très en dessous, au-dessus", () => {
    expect(compareAudience(10000, 8000, 12000, 300, 30).status).toBe("conform");
    expect(compareAudience(10000, 5000, 7000, 200, 30).status).toBe("below");
    expect(compareAudience(10000, 1000, 1500, 40, 30).status).toBe("far_below");
    expect(compareAudience(10000, 13000, 20000, 500, 30).status).toBe("above");
  });
  test("rapport arrondi, audience déclarée nulle", () => {
    expect(compareAudience(10000, 6666, 9000, 200, 30).ratio).toBe(0.67);
    expect(compareAudience(0, 100, 100, 5, 30).status).toBe("no_data");
  });
});
