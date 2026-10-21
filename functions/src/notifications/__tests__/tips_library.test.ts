import { LANGS, TIPS, fmt, hashId, langOf, reminderText, tipText, topicIndex, Lang } from "../tips_library";
import { categoryOf } from "../policy_logic";

const VARS = { views: "1 000", amount: "1 000", min: "1 000" };

describe("bibliothèque des notifications pédagogiques", () => {
  test("chaque sujet existe dans les 8 langues, avec des textes de longueur raisonnable", () => {
    for (const tip of TIPS) {
      for (const lang of LANGS) {
        const t = tip.texts[lang];
        expect(t).toBeDefined();
        expect(t.title.trim().length).toBeGreaterThan(3);
        expect(t.body.trim().length).toBeGreaterThan(10);
        expect(t.title.length).toBeLessThanOrEqual(70);
        expect(t.body.length).toBeLessThanOrEqual(190);
      }
    }
  });

  test("chaque sujet ouvre une page d'action et reste classé comme rappel", () => {
    for (const tip of TIPS) {
      expect(tip.target).toMatch(/^RAPPEL_[A-Z]+$/);
      expect(categoryOf(tip.target)).toBe("reminder");
    }
  });

  test("toutes les variables sont remplacées", () => {
    for (const tip of TIPS) {
      for (const lang of LANGS) {
        const t = tipText(tip, lang, VARS);
        expect(`${t.title} ${t.body}`).not.toMatch(/\{\w+\}/);
      }
    }
  });

  test("règle du propriétaire : jamais la part de l'application (25 %), seulement les 75 % du parrain", () => {
    for (const tip of TIPS) {
      for (const lang of LANGS) {
        const t = tip.texts[lang];
        expect(`${t.title} ${t.body}`).not.toMatch(/\b25\s?%/);
      }
    }
    const referral = TIPS.find((t) => t.topic === "referral")!;
    for (const lang of LANGS) expect(referral.texts[lang].body + referral.texts[lang].title).toMatch(/75/);
  });

  test("l'estimation utilise les variables du barème", () => {
    const est = TIPS.find((t) => t.topic === "estimate")!;
    for (const lang of LANGS) {
      const raw = est.texts[lang];
      expect(raw.body).toContain("{amount}");
      expect(tipText(est, lang, { views: "1 000", amount: "800", min: "1 000" }).body).toContain("800");
    }
  });

  test("les sujets couvrent ce qui a été demandé", () => {
    const topics = TIPS.map((t) => t.topic);
    for (const t of ["earn", "estimate", "creator", "referral", "live", "sellLive", "channel", "group", "shop", "comment", "flame", "musicUpload", "musicEarn", "weekly"]) {
      expect(topics).toContain(t);
    }
  });

  test("langOf : langue connue, sinon français", () => {
    expect(langOf("en")).toBe("en");
    expect(langOf("SW")).toBe("sw");
    expect(langOf("pt-BR")).toBe("pt");
    expect(langOf("xx")).toBe("fr");
    expect(langOf(undefined)).toBe("fr");
  });

  test("le sujet du jour tourne et diffère d'une personne à l'autre", () => {
    const a = topicIndex(100, hashId("alice")), b = topicIndex(101, hashId("alice"));
    expect(b).toBe((a + 1) % TIPS.length);
    const idx = new Set(["u1", "u2", "u3", "u4", "u5", "u6", "u7", "u8"].map((u) => topicIndex(100, hashId(u))));
    expect(idx.size).toBeGreaterThan(3);
    for (let d = 0; d < 40; d++) expect(topicIndex(d, hashId("x"))).toBeGreaterThanOrEqual(0);
  });

  test("rappels d'engagement dans chaque langue", () => {
    for (const lang of LANGS as Lang[]) {
      for (const kind of ["quiz", "etude", "conte", "feed", "comeback"] as const) {
        const t = reminderText(kind, lang, 3, 4);
        expect(t.title.length).toBeGreaterThan(3);
        expect(t.body.length).toBeGreaterThan(8);
      }
    }
    expect(reminderText("quiz", "en", 0).title).toMatch(/quiz/i);
    expect(reminderText("feed", "fr", 0, 3).body).toContain("3");
  });

  test("fmt : milliers séparés", () => {
    expect(fmt(1000)).toBe("1 000");
    expect(fmt(800)).toBe("800");
  });
});
