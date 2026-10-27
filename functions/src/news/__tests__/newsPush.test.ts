const store: Record<string, Record<string, unknown>> = {};
jest.mock("../../shared/firebase", () => ({
  db: { collection: (c: string) => ({ doc: (id: string) => ({ get: async () => ({ data: () => store[`${c}/${id}`] }) }) }) },
}));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: { increment: (n: number) => n } }));
jest.mock("firebase-functions/params", () => ({ defineSecret: () => ({ value: () => "[]" }) }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: () => ({}) }));

import { FLASH_MIN_SCORE, NewsPushSource, newsKindFor, pickStory, storyPlan, weekPlan, weekdayOf } from "../newsPush";
import { NewsFeedItem } from "../model";
import { chooseReminder, shouldStoreInApp, typeNotifFor } from "../../notifications/policy_logic";

const H = 3_600_000;
// mercredi 21 octobre 2026, 08 h 30 UTC
const NOW = Date.parse("2026-10-21T08:30:00Z");

const item = (id: string, o: Partial<NewsFeedItem> = {}): NewsFeedItem => ({
  id, agentKey: "sport", category: "sport", level: "country", country: "TG", continent: "AF", title: `Titre ${id}`, chapo: `Chapô de l'article ${id}`, image: "https://img.exemple.fr/a.jpg",
  sourceCount: 2, sourceNames: ["RFI"], at: NOW - 3 * H, score: 10, notif: null, exp: NOW + 3 * 24 * H, ...o,
});

describe("quel créneau porte quelle actualité", () => {
  test("lundi matin : semaine ; les autres matins : article ; soir : alerte ; midi : rien", () => {
    expect(newsKindFor(0, 1)).toBe("newsweek");
    for (const d of [0, 2, 3, 4, 5, 6]) expect(newsKindFor(0, d)).toBe("news");
    expect(newsKindFor(2, 4)).toBe("newsflash");
    expect(newsKindFor(1, 3)).toBeNull();
  });
  test("jour de la semaine à l'heure locale de la personne", () => {
    expect(weekdayOf(NOW, 0)).toBe(3); // mercredi
    expect(weekdayOf(Date.parse("2026-10-21T23:30:00Z"), 120)).toBe(4); // jeudi à l'est de Greenwich
    expect(weekdayOf(Date.parse("2026-10-21T00:30:00Z"), -60)).toBe(2); // mardi à l'ouest
  });
});

describe("choix de l'article", () => {
  test("journal : le plus important des 30 dernières heures, jamais celui déjà envoyé", () => {
    const items = [item("a", { score: 8 }), item("b", { score: 14 }), item("c", { score: 20, at: NOW - 40 * H }), item("d", { score: 12 })];
    expect(pickStory(items, { nowMs: NOW, kind: "news" })?.id).toBe("b"); // c est trop ancien
    expect(pickStory(items, { nowMs: NOW, kind: "news", lastId: "b" })?.id).toBe("d");
    expect(pickStory([item("x", { exp: NOW - 1 })], { nowMs: NOW, kind: "news" })).toBeNull(); // périmé
  });
  test("alerte : seulement une info forte (score et 3 sources) sortie dans les 8 dernières heures", () => {
    expect(FLASH_MIN_SCORE).toBe(16);
    const strong = item("s", { score: 19, sourceCount: 3, at: NOW - 2 * H });
    expect(pickStory([strong], { nowMs: NOW, kind: "newsflash" })?.id).toBe("s");
    expect(pickStory([item("w", { score: 19, sourceCount: 2 })], { nowMs: NOW, kind: "newsflash" })).toBeNull();
    expect(pickStory([item("w", { score: 12, sourceCount: 4 })], { nowMs: NOW, kind: "newsflash" })).toBeNull();
    expect(pickStory([item("w", { score: 19, sourceCount: 3, at: NOW - 10 * H })], { nowMs: NOW, kind: "newsflash" })).toBeNull();
    expect(pickStory([item("w", { score: 12, sourceCount: 4 })], { nowMs: NOW, kind: "newsflash", minScore: 10 })?.id).toBe("w"); // seuil réglable
  });
});

describe("texte et clic des notifications", () => {
  test("article : le texte de l'IA, l'aperçu, un clic qui ouvre l'article ; alerte préfixée", () => {
    const it = item("a1", { notif: { title: "Éperviers : la liste est tombée", body: "Trois absents et un match samedi à Lomé : le point complet." } });
    const p = storyPlan("news", it);
    expect(p).toMatchObject({ kind: "news", storyId: "a1", title: "Éperviers : la liste est tombée", image: "https://img.exemple.fr/a.jpg" });
    expect(p.data).toEqual({ type_notif: "NEWS", post_id: "a1", post_type: "NEWS", send_user_id: "news_agent_sport" });
    expect(storyPlan("newsflash", it).title).toBe("🔴 Éperviers : la liste est tombée");
    // sans texte d'IA : titre et chapô de l'article, coupés
    const plain = storyPlan("news", item("a2", { title: "T".repeat(90), chapo: "C".repeat(200) }));
    expect(plain.title.length).toBeLessThanOrEqual(58);
    expect(plain.body.length).toBeLessThanOrEqual(110);
  });
  test("semaine : titre dans la langue de la personne, ouvre Mon journal", () => {
    const items = [{ title: "La plus grosse info de la semaine", image: "https://img.exemple.fr/w.jpg" }, { title: "b", image: "" }, { title: "c", image: "" }];
    const fr = weekPlan("2026-W42", items, "fr");
    expect(fr.title).toBe("🗞️ La semaine en 3 infos");
    expect(fr.data).toEqual({ type_notif: "RAPPEL_JOURNAL" });
    expect(fr.storyId).toBe("week:2026-W42");
    expect(weekPlan("2026-W42", items, "en").title).toBe("🗞️ Your week in 3 stories");
    expect(weekPlan("2026-W42", Array.from({ length: 7 }, () => items[0]), "fr").title).toContain("5 infos");
  });
});

describe("choix pour une personne", () => {
  beforeEach(() => { for (const k of Object.keys(store)) delete store[k]; });
  const tg = { countryData: { countryCode: "TG" } };

  test("pays suivi d'abord, puis continent, puis monde ; un pays non suivi saute au continent", async () => {
    store["NewsFeed/country_TG"] = { items: [item("tg1", { score: 5 })] };
    store["NewsFeed/continent_AF"] = { items: [item("af1", { score: 30 })] };
    store["NewsFeed/world"] = { items: [item("w1", { score: 40 })] };
    const src = new NewsPushSource(NOW, ["TG", "BJ"]);
    expect(src.scopesFor("TG")).toEqual(["country_TG", "continent_AF", "world"]);
    expect(src.scopesFor("KE")).toEqual(["continent_AF", "world"]); // le Kenya n'est pas suivi
    expect(src.scopesFor("")).toEqual(["world"]);
    expect((await src.plan(tg, 0, 0, "fr"))?.storyId).toBe("tg1"); // le pays passe avant, même moins important
    expect((await src.plan({ countryData: { countryCode: "KE" } }, 0, 0, "fr"))?.storyId).toBe("af1");
    expect((await src.plan({}, 0, 0, "fr"))?.storyId).toBe("w1");
  });
  test("une seule actualité par personne et par jour, jamais deux fois la même", async () => {
    store["NewsFeed/country_TG"] = { items: [item("a", { score: 9 }), item("b", { score: 8 })] };
    const src = new NewsPushSource(NOW, ["TG"]);
    expect((await src.plan({ ...tg, newsAt: NOW - 5 * H }, 0, 0, "fr"))).toBeUndefined(); // déjà reçue aujourd'hui
    expect((await src.plan({ ...tg, newsAt: NOW - 30 * H }, 0, 0, "fr"))?.storyId).toBe("a");
    expect((await src.plan({ ...tg, newsAt: NOW - 30 * H, newsLastId: "a" }, 0, 0, "fr"))?.storyId).toBe("b");
    expect((await src.plan({ ...tg, newsAt: NOW - 30 * H, newsLastId: "b" }, 0, 0, "fr"))?.storyId).toBe("a");
  });
  test("lundi : la semaine passée, une seule fois ; sans résumé, rien", async () => {
    const monday = Date.parse("2026-10-19T08:30:00Z"); // lundi de la semaine 43 : on envoie la semaine 42
    const week = Array.from({ length: 5 }, (_, i) => ({ id: `w${i}`, title: `Info ${i}`, image: "", agentKey: "sport", category: "sport", chapo: "", sources: [], sourceCount: 1, at: 1, rank: 1 }));
    store["NewsDigests/country_TG_week_2026-W42"] = { items: week };
    const src = new NewsPushSource(monday, ["TG"]);
    const plan = await src.plan(tg, 0, 0, "fr");
    expect(plan).toMatchObject({ kind: "newsweek", storyId: "week:2026-W42" });
    expect(plan?.title).toContain("5 infos");
    expect(await new NewsPushSource(monday, ["TG"]).plan({ ...tg, newsLastId: "week:2026-W42" }, 0, 0, "fr")).toBeUndefined();
    store["NewsDigests/country_TG_week_2026-W42"] = { items: week.slice(0, 2) }; // moins de 3 infos : pas d'envoi
    expect(await new NewsPushSource(monday, ["TG"]).plan(tg, 0, 0, "fr")).toBeUndefined();
  });
  test("alerte du soir : coupée par l'administrateur", async () => {
    store["NewsFeed/world"] = { items: [item("s", { score: 19, sourceCount: 3, at: NOW - 2 * H })] };
    expect((await new NewsPushSource(NOW, []).plan({}, 2, 0, "fr", true))?.kind).toBe("newsflash");
    expect(await new NewsPushSource(NOW, []).plan({}, 2, 0, "fr", false)).toBeUndefined();
  });
});

describe("politique des rappels", () => {
  const base = { slot: 0, dayIndex: 4, streak: 0, streakDoneToday: true, unseenPosts: 3, daysInactive: 0 };
  test("le matin, la semaine ou l'article passent avant la promotion d'un créateur ; le soir, l'alerte avant la pub", () => {
    expect(chooseReminder({ ...base, creatorPromoAvailable: true, newsKind: "newsweek" })).toBe("newsweek");
    expect(chooseReminder({ ...base, creatorPromoAvailable: true, newsKind: "news" })).toBe("news");
    expect(chooseReminder({ ...base, creatorPromoAvailable: true })).toBe("creator");
    expect(chooseReminder({ ...base, slot: 2, dayIndex: 1, sponsorAvailable: true, newsKind: "newsflash" })).toBe("newsflash");
    expect(chooseReminder({ ...base, slot: 1, newsKind: "news" })).not.toBe("news"); // jamais à midi
  });
  test("clics : l'article ouvre l'article, la semaine ouvre Mon journal ; rien n'est enregistré dans la liste", () => {
    expect([typeNotifFor("news"), typeNotifFor("newsflash"), typeNotifFor("newsweek")]).toEqual(["NEWS", "NEWS", "RAPPEL_JOURNAL"]);
    expect(shouldStoreInApp("NEWS")).toBe(false);
    expect(shouldStoreInApp("RAPPEL_JOURNAL")).toBe(false);
  });
});
