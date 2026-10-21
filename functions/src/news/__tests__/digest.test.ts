const store: Record<string, Record<string, unknown>> = {};
let postDocs: Array<{ id: string; data: () => Record<string, unknown> }> = [];

jest.mock("../../shared/firebase", () => {
  const ref = (col: string, id: string) => ({ id, set: async (d: Record<string, unknown>) => { store[`${col}/${id}`] = d; }, get: async () => ({ id, exists: !!store[`${col}/${id}`], data: () => store[`${col}/${id}`] }) });
  const q = () => { const o: Record<string, unknown> = {}; o["where"] = () => o; o["limit"] = () => o; o["get"] = async () => ({ docs: postDocs, empty: !postDocs.length, size: postDocs.length }); return o; };
  return {
    db: {
      collection: (col: string) => ({
        doc: (id: string) => ref(col, id),
        where: q,
        get: async () => ({ docs: col === "NewsFeed" ? [{ id: "country_TG" }, { id: "world" }] : [] }),
        add: async () => ({}),
      }),
      getAll: async (...refs: Array<{ id: string; _col?: string }>) => refs.map((r) => ({ id: r.id, exists: !!store[`NewsDigests/${r.id}`], data: () => store[`NewsDigests/${r.id}`] })),
    },
  };
});
jest.mock("firebase-admin/firestore", () => ({ FieldValue: { increment: (n: number) => n } }));
jest.mock("firebase-functions/params", () => ({ defineSecret: () => ({ value: () => "[]" }) }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: () => ({}) }));

import { DigestItem, TOP_N, buildDayDigests, buildDigestDoc, buildPeriodDigests, dayKeyOf, digestId, monthDayKeys, monthKeyOf, rankOf, snapshotItem, templateIntro, topItems, validateIntro, weekDayKeys, weekKeyOf } from "../digest";

const DAY = 86_400_000;
const NOW = Date.parse("2026-10-21T21:10:00Z"); // mercredi

const post = (id: string, o: Record<string, unknown> = {}, news: Record<string, unknown> = {}) => ({
  id,
  data: () => ({
    created_at: Date.parse("2026-10-21T08:00:00Z") * 1000, url_media: "https://img.exemple.fr/a.jpg", loves: 0, comments: 0, vues: 0, giftCount: 0,
    news: { scope: "country_TG", agentKey: "sport", category: "sport", title: `Titre ${id}`, chapo: `Chapô ${id}`, score: 10, sourceCount: 2, sources: [{ name: "RFI", url: "https://rfi.fr/a" }], ...news }, ...o,
  }),
});

describe("clés de période", () => {
  test("jour, semaine ISO (lundi à dimanche) et mois, en UTC", () => {
    expect(dayKeyOf(NOW)).toBe("2026-10-21");
    expect(monthKeyOf(NOW)).toBe("2026-10");
    expect(weekKeyOf(NOW)).toBe("2026-W43");
    expect(weekDayKeys(NOW)).toEqual(["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25"]);
    // fins d'année : la semaine du 31 décembre 2024 est la semaine 1 de 2025
    expect(weekKeyOf(Date.parse("2024-12-31T12:00:00Z"))).toBe("2025-W01");
    expect(weekKeyOf(Date.parse("2027-01-01T12:00:00Z"))).toBe("2026-W53");
    expect(monthDayKeys("2026-02")).toHaveLength(28);
    expect(monthDayKeys("2028-02")).toHaveLength(29);
    expect(digestId("country_TG", "week", "2026-W43")).toBe("country_TG_week_2026-W43");
  });
  test("bornes d'un résumé : jour, semaine et mois", () => {
    const d = buildDigestDoc("world", "day", "2026-10-21", [], "x", NOW);
    expect([d.from, d.to]).toEqual([Date.parse("2026-10-21T00:00:00Z"), Date.parse("2026-10-22T00:00:00Z")]);
    const w = buildDigestDoc("world", "week", "2026-W43", [], "x", NOW);
    expect([w.from, w.to]).toEqual([Date.parse("2026-10-19T00:00:00Z"), Date.parse("2026-10-26T00:00:00Z")]);
    const m = buildDigestDoc("world", "month", "2026-10", [], "x", NOW);
    expect([m.from, m.to]).toEqual([Date.parse("2026-10-01T00:00:00Z"), Date.parse("2026-11-01T00:00:00Z")]);
    expect(m.expireAt).toBe(NOW + 400 * DAY);
    expect(d.expireAt).toBe(NOW + 40 * DAY);
  });
});

describe("contenu des résumés", () => {
  test("importance : score de départ, puis ce que les lecteurs en font", () => {
    expect(rankOf({ news: { score: 10 }, loves: 5, comments: 2, giftCount: 1, vues: 100 })).toBe(10 + 10 + 6 + 5 + 5);
    expect(rankOf({})).toBe(0);
  });
  test("copie d'un article : titre, chapô, image, 3 sources au plus", () => {
    const it = snapshotItem("a1", post("a1", {}, { sources: [1, 2, 3, 4].map((i) => ({ name: `S${i}`, url: `https://s${i}.fr/` })) }).data());
    expect(it).toMatchObject({ id: "a1", title: "Titre a1", chapo: "Chapô a1", image: "https://img.exemple.fr/a.jpg", agentKey: "sport", at: Date.parse("2026-10-21T08:00:00Z") });
    expect(it.sources).toHaveLength(3);
  });
  test("les meilleurs, un agent différent d'abord, sans doublon d'article", () => {
    const mk = (id: string, agentKey: string, rank: number): DigestItem => ({ id, agentKey, category: "sport", title: id, chapo: "", image: "", sources: [], sourceCount: 1, at: 1, rank });
    const top = topItems([mk("a", "sport", 50), mk("b", "sport", 40), mk("c", "tech", 5), mk("a", "sport", 60), mk("d", "voyage", 3)], 3);
    expect(top.map((i) => i.id)).toEqual(["a", "c", "d"]); // b (même agent que a) passe après les autres agents ; a gardé à son meilleur rang (60)
    expect(top[0].rank).toBe(60);
    expect(topItems([mk("a", "sport", 1)], 5)).toHaveLength(1);
  });
  test("introduction type : les domaines qui dominent", () => {
    const mk = (category: string): DigestItem => ({ id: category + Math.random(), agentKey: "x", category, title: "", chapo: "", image: "", sources: [], sourceCount: 1, at: 1, rank: 1 });
    expect(templateIntro("week", [mk("sport"), mk("sport"), mk("politique"), mk("tech")])).toBe("Les 4 infos qui ont marqué la semaine, avec le sport, la politique et la technologie en tête.");
  });
  test("introduction de l'IA : courte, sans chiffre ni nom inventés", () => {
    const titles = ["Le Togo adopte une loi pour les jeunes entrepreneurs", "Dakar accueille le sommet de l'Union africaine"];
    expect(validateIntro("Cette semaine, la loi togolaise sur les jeunes entrepreneurs et le sommet de Dakar ont retenu l'attention.", titles)).not.toBeNull();
    expect(validateIntro("Court.", titles)).toBeNull();
    expect(validateIntro("Cette semaine, Karim Benzema a visité Dakar pour le sommet, selon plusieurs observateurs du continent.", titles)).toBeNull();
    expect(validateIntro("Cette semaine, 4500 personnes ont assisté au sommet de Dakar d'après les sources disponibles ici.", titles)).toBeNull();
  });
});

describe("construction", () => {
  beforeEach(() => { for (const k of Object.keys(store)) delete store[k]; });

  test("jour : un résumé par périmètre, 5 éléments au plus, classés par importance", async () => {
    postDocs = [
      ...Array.from({ length: 7 }, (_, i) => post(`t${i}`, { loves: i * 10 }, { scope: "country_TG", agentKey: ["sport", "politik", "culture", "beat", "tech", "voyage", "sport"][i] })),
      post("w1", {}, { scope: "world", agentKey: "tech", category: "tech" }),
    ];
    expect(await buildDayDigests("2026-10-21", NOW)).toBe(2);
    const tg = store["NewsDigests/country_TG_day_2026-10-21"] as unknown as { items: DigestItem[]; intro: string };
    expect(tg.items).toHaveLength(TOP_N.day);
    expect(tg.items[0].id).toBe("t6"); // le plus aimé en tête
    expect(tg.intro).toContain("infos");
    expect(store["NewsDigests/world_day_2026-10-21"]).toBeDefined();
  });

  test("semaine : à partir des résumés du jour, avec introduction de l'IA ou, à défaut, introduction type", async () => {
    const day = (key: string, ids: string[]) => {
      const items: DigestItem[] = ids.map((id, i) => ({ id, agentKey: "sport", category: "sport", title: `Titre ${id}`, chapo: "", image: "", sources: [], sourceCount: 1, at: 1, rank: 10 - i }));
      store[`NewsDigests/country_TG_day_${key}`] = { items };
    };
    day("2026-10-19", ["a", "b"]);
    day("2026-10-21", ["b", "c"]); // b revient : un seul exemplaire dans la semaine
    const ai = jest.fn(async () => ({ text: "Cette semaine, plusieurs titres ont retenu l'attention du public dans le pays et au-delà de ses frontières.", neurons: 3, accountId: "x", model: "m", ms: 1 }));
    expect(await buildPeriodDigests("week", "2026-W43", weekDayKeys(NOW), NOW, ai as never)).toBe(1); // « world » n'a aucun résumé du jour : ignoré
    const w = store["NewsDigests/country_TG_week_2026-W43"] as unknown as { items: DigestItem[]; intro: string };
    expect(w.items.map((i) => i.id).sort()).toEqual(["a", "b", "c"]);
    expect(w.intro).toContain("Cette semaine");

    const down = jest.fn(async () => { throw new Error("quota"); });
    await buildPeriodDigests("week", "2026-W43", weekDayKeys(NOW), NOW, down as never);
    expect((store["NewsDigests/country_TG_week_2026-W43"] as unknown as { intro: string }).intro).toContain("Les 3 infos");
  });
});
