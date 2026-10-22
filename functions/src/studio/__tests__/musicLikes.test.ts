jest.mock("../../shared/firebase", () => ({ db: {} }));

import { nextLikeState } from "../musicLikes";

describe("j'aime sur les musiques", () => {
  test("premier j'aime : +1, la personne est enregistrée", () => {
    expect(nextLikeState(false, 4, true)).toEqual({ liked: true, count: 5, change: "add" });
  });
  test("retirer son j'aime : -1", () => {
    expect(nextLikeState(true, 5, false)).toEqual({ liked: false, count: 4, change: "remove" });
  });
  test("sans état voulu : on inverse", () => {
    expect(nextLikeState(false, 0, undefined)).toEqual({ liked: true, count: 1, change: "add" });
    expect(nextLikeState(true, 1, undefined)).toEqual({ liked: false, count: 0, change: "remove" });
  });
  test("double appui : jamais deux fois la même personne, rien ne change", () => {
    expect(nextLikeState(true, 5, true)).toEqual({ liked: true, count: 5, change: "none" });
    expect(nextLikeState(false, 5, false)).toEqual({ liked: false, count: 5, change: "none" });
  });
  test("le compteur ne descend jamais sous 0 et ignore les valeurs absurdes", () => {
    expect(nextLikeState(true, 0, false).count).toBe(0);
    expect(nextLikeState(false, -3, true).count).toBe(1);
    expect(nextLikeState(false, NaN, true).count).toBe(1);
  });
});
