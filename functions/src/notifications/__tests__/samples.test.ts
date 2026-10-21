jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: () => ({}) }));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: {} }));

import { buildSamples } from "../samples";
import { LANGS, TIPS } from "../tips_library";

// types de notification que l'application sait ouvrir (PushService.storeNavigationFromPush et la page Notifications)
const KNOWN = new Set(["POST", "CHRONIQUE", "MESSAGE", "INVITATION", "ABONNER", "MUSIC", "GAIN", "WEEKLY_REWARD", "LIVE", "NEWS", "COMPTE_OFFICIEL"]);

describe("exemples de notifications pour les administrateurs", () => {
  const ctx = { lang: "fr" as const, adminId: "admin1", rate: 1, post: { id: "p1234567", type: "IMAGE", image: "https://cdn.exemple.com/p.jpg", text: "Mon premier post" },
    chronique: { id: "c1234567", image: "https://cdn.exemple.com/c.jpg" }, sound: { id: "s1234567", image: "https://cdn.exemple.com/s.jpg" },
    news: { id: "news_abc12345", agentKey: "sport", title: "Les Éperviers préparent leur match", chapo: "Un point complet sur la liste.", image: "https://cdn.exemple.com/n.jpg", notif: { title: "Éperviers : la liste est tombée", body: "Trois absents, un match samedi : le point complet." } } };

  test("un exemple par cas : rappels, tous les sujets pédagogiques, activité", () => {
    const s = buildSamples(ctx);
    const ids = s.map((x) => x.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(s.filter((x) => x.group === "pedagogiques")).toHaveLength(TIPS.length);
    expect(s.filter((x) => x.group === "rappels").length).toBeGreaterThanOrEqual(7);
    expect(s.filter((x) => x.group === "activite").length).toBeGreaterThanOrEqual(12);
    for (const x of s) {
      expect(x.title.startsWith("🧪 TEST")).toBe(true);
      expect(x.message.length).toBeGreaterThan(3);
      expect(x.data["type_notif"]).toBeTruthy();
    }
  });

  test("chaque cas a une action au clic connue", () => {
    for (const x of buildSamples(ctx)) {
      const t = x.data["type_notif"];
      expect(KNOWN.has(t) || t.startsWith("RAPPEL_")).toBe(true);
    }
  });

  test("les contenus visuels portent l'image d'aperçu, les messages restent en texte", () => {
    const by = Object.fromEntries(buildSamples(ctx).map((x) => [x.id, x]));
    for (const id of ["act_like", "act_commentaire", "act_post_abonne", "rappel_createur", "rappel_pub"]) expect(by[id].image).toBe("https://cdn.exemple.com/p.jpg");
    expect(by["act_chronique"].image).toBe("https://cdn.exemple.com/c.jpg");
    expect(by["rappel_news"].image).toBe("https://cdn.exemple.com/n.jpg");
    expect(by["rappel_news"].data).toMatchObject({ type_notif: "NEWS", post_id: "news_abc12345", post_type: "NEWS" });
    expect(by["rappel_newsflash"].title).toContain("🔴");
    expect(by["rappel_newsweek"].data["type_notif"]).toBe("RAPPEL_JOURNAL");
    expect(by["act_musique"].image).toBe("https://cdn.exemple.com/s.jpg");
    for (const id of ["act_message", "act_invitation", "act_gain", "rappel_quiz", "tip_earn"]) expect(by[id].image).toBeUndefined();
  });

  test("sans contexte (base vide), tout fonctionne sans image", () => {
    const s = buildSamples({ lang: "en", adminId: "a", rate: 0.8 });
    expect(s.length).toBeGreaterThan(30);
    expect(s.every((x) => !x.image)).toBe(true);
  });

  test("langues : les textes suivent la langue de l'administrateur", () => {
    for (const lang of LANGS) {
      const s = buildSamples({ ...ctx, lang });
      expect(s.find((x) => x.id === "tip_earn")!.message.length).toBeGreaterThan(10);
    }
    expect(buildSamples({ ...ctx, lang: "en" }).find((x) => x.id === "tip_estimate")!.message).toContain("1\u202f000");
  });
});
