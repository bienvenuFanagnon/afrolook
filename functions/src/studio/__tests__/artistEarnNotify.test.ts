jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: () => ({}) }));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: {} }));

import { EARN_GAP_MS, earnMessage, foldEarning } from "../artistEarnNotify";
import { EARN_TEXT, LANGS } from "../../notifications/tips_library";

const gain = (coins: number, kind: "sale" | "use" = "use") => ({ coins, soundId: "s1234567", title: "Mon titre", kind });

describe("alerte de gain d'un artiste", () => {
  test("premier gain : envoyé tout de suite", () => {
    const r = foldEarning(undefined, gain(3), 1_700_000_000_000);
    expect(r.send).toEqual({ coins: 3, count: 1, soundId: "s1234567", title: "Mon titre", kind: "use" });
    expect(r.next).toMatchObject({ coins: 0, count: 0, lastAt: 1_700_000_000_000 });
  });

  test("gains rapprochés : mis en attente puis regroupés dans la prochaine alerte", () => {
    const t0 = 1_700_000_000_000;
    const first = foldEarning(undefined, gain(3), t0);
    const second = foldEarning(first.next, gain(3), t0 + 60_000);
    expect(second.send).toBeNull();
    const third = foldEarning(second.next, gain(18, "sale"), t0 + 120_000);
    expect(third.send).toBeNull();
    expect(third.next).toMatchObject({ coins: 21, count: 2, lastAt: t0 });
    const later = foldEarning(third.next, gain(3), t0 + EARN_GAP_MS + 1);
    expect(later.send).toMatchObject({ coins: 24, count: 3 });
    expect(later.next).toMatchObject({ coins: 0, count: 0 });
  });

  test("les textes existent dans les 8 langues, sans variable oubliée", () => {
    for (const lang of LANGS) {
      for (const [kind, n] of [["sale", 1], ["use", 1], ["use", 4]] as const) {
        const m = earnMessage(lang, { coins: 1200, count: n, soundId: "s", title: "Titre", kind });
        expect(`${m.title} ${m.body}`).not.toMatch(/\{\w+\}/);
        expect(m.title.length).toBeLessThanOrEqual(70);
        expect(m.body.length).toBeLessThanOrEqual(190);
        if (n === 1) expect(m.body).toContain("Titre");
        if (n > 1) expect(m.body).toContain("4");
        expect(EARN_TEXT[lang].title).toBe(m.title);
      }
    }
  });
});
