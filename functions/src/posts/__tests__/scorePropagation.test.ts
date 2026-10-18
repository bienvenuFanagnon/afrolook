import { shouldPropagate } from "../scorePropagation";

describe("score du créateur : quand propager", () => {
  it("propage la première fois (aucune valeur déjà propagée)", () => {
    expect(shouldPropagate(undefined, 3)).toBe(true);
    expect(shouldPropagate(null, 0)).toBe(true);
    expect(shouldPropagate(Number.NaN, 1)).toBe(true);
  });
  it("ne propage pas une petite variation (une vue de plus)", () => {
    expect(shouldPropagate(10, 10.2)).toBe(false); // < 0,25 et < 10 %
    expect(shouldPropagate(1, 1.2)).toBe(false);
    expect(shouldPropagate(0, 0.2)).toBe(false);
  });
  it("propage dès que l'écart est visible : 0,25 point et 10 % de la dernière valeur propagée", () => {
    expect(shouldPropagate(1, 1.3)).toBe(true); // +0,3 ≥ max(0,25 ; 0,1)
    expect(shouldPropagate(10, 11)).toBe(true); // +1 ≥ 10 % de 10
    expect(shouldPropagate(10, 10.9)).toBe(false); // +0,9 < 1
    expect(shouldPropagate(10, 9)).toBe(true); // vers le bas aussi
  });
  it("accumule : de petites variations successives finissent par se propager", () => {
    let last = 5;
    let propagations = 0;
    let score = 5;
    for (let i = 0; i < 40; i++) {
      score += 0.1; // une vue
      if (shouldPropagate(last, score)) {
        last = score;
        propagations++;
      }
    }
    expect(propagations).toBeGreaterThan(0);
    expect(propagations).toBeLessThan(40);
  });
});
