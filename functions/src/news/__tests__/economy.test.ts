const sets: Array<{ col: string; id: string; data: Record<string, unknown> }> = [];
const store: Record<string, Record<string, unknown>> = {};
let genCount = 0;

jest.mock("../../shared/firebase", () => {
  const ref = (col: string, id?: string) => {
    const rid = id ?? `gen${++genCount}`;
    return {
      id: rid,
      set: async (data: Record<string, unknown>) => { sets.push({ col, id: rid, data }); store[`${col}/${rid}`] = data; },
      get: async () => ({ id: rid, exists: !!store[`${col}/${rid}`], data: () => store[`${col}/${rid}`] }),
    };
  };
  const query = () => { const q: Record<string, unknown> = {}; q["where"] = () => q; q["limit"] = () => q; q["get"] = async () => ({ empty: true, size: 0, docs: [] }); return q; };
  return {
    db: {
      collection: (col: string) => ({ doc: (id?: string) => ref(col, id), add: async () => ({}), where: query, orderBy: query, get: async () => ({ empty: true, size: 0, docs: [] }) }),
      runTransaction: async (fn: (tx: unknown) => Promise<unknown>) => fn({
        get: async (r: { id: string }) => ({ exists: false, data: () => store[`NewsRuns/${r.id}`] ?? store[`NewsFeed/${r.id}`] }),
        set: (r: { id: string }, data: Record<string, unknown>) => { store[`NewsRuns/${r.id}`] = data; sets.push({ col: "tx", id: r.id, data }); },
      }),
      batch: () => ({ delete: () => undefined, set: () => undefined, commit: async () => undefined }),
    },
  };
});
jest.mock("firebase-admin/firestore", () => ({ FieldValue: { increment: (n: number) => n, arrayUnion: (...a: unknown[]) => a } }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: () => ({}) }));
jest.mock("firebase-functions/params", () => ({ defineSecret: () => ({ value: () => "[]" }) }));

import { Topic, entityTokens, sameStory } from "../cluster";
import { cleanNewsInput } from "../model";
import { NEWS_ID_PREFIX, publishNews } from "../publish";
import { acquireRunLock, planSelection, releaseRunLock } from "../pipeline";
import { runNewsCleanup } from "../cleanup";

const NOW = Date.parse("2026-10-21T12:00:00Z");
const topic = (titre: string, link: string, cat: Topic["category"] = "sport", country: string | null = "TG"): Topic => ({
  items: [{ sourceId: "s", sourceName: "RFI", lang: "fr", region: "africa", categoryHint: cat, titre, lien: `https://exemple.fr/${link}`, date: new Date(NOW - 3_600_000).toISOString(), resume: "r".repeat(200), corps: "", image: null }],
  category: cat, level: country ? "country" : "world", country, distinctSources: 2, score: 10,
});
const cfg = { dailyCap: 60, perRun: 5, perKeyDaily: 2 };

describe("doublons : même événement, autre langue ou autres sources", () => {
  test("noms propres et nombres reconnus, pays et mots généraux ignorés", () => {
    expect([...entityTokens("Togo : Paulo Duarte dévoile 24 joueurs pour 2026")].sort()).toEqual(["24", "duarte", "paulo"]);
    expect(entityTokens("Football en Afrique : RFI et Africanews").size).toBe(0);
  });
  test("deux langues, mêmes personnes et mêmes nombres = même événement ; un seul nom commun = non", () => {
    expect(sameStory("Togo : le sélectionneur Paulo Duarte dévoile 24 joueurs", "Togo coach Paulo Duarte names 24 players for qualifier")).toBe(true);
    expect(sameStory("Paulo Duarte critique l'arbitrage après la défaite", "Paulo Duarte lance un festival de musique à Lomé")).toBe(false);
    expect(sameStory("Le Togo adopte une loi sur les jeunes entrepreneurs", "Togo : une loi pour les jeunes entrepreneurs adoptée")).toBe(true);
  });
  test("un sujet déjà raconté récemment est écarté, même avec d'autres sources", () => {
    const t = [topic("Togo coach Paulo Duarte names 24 players for qualifier", "a")];
    expect(planSelection(t, { published: 0, byKey: {} }, cfg, new Map(), NOW, [])).toHaveLength(1);
    expect(planSelection(t, { published: 0, byKey: {} }, cfg, new Map(), NOW, ["Togo : le sélectionneur Paulo Duarte dévoile 24 joueurs"])).toHaveLength(0);
  });
  test("pendant un passage : un seul sujet par agent et périmètre, et jamais deux fois le même événement", () => {
    const t = [
      topic("Togo : le sélectionneur Paulo Duarte dévoile 24 joueurs", "a"),
      topic("Éperviers : un autre sujet de sport très différent à Lomé", "b"),
      topic("Culture : Paulo Duarte dévoile 24 œuvres exposées", "c", "culture"),
      topic("Politique : un projet de loi sur le numérique au parlement", "d", "politique", null),
    ];
    const plan = planSelection(t, { published: 0, byKey: {} }, cfg, new Map(), NOW);
    expect(plan.map((x) => x.items[0].lien.split("/").pop())).toEqual(["a", "d"]); // b = même agent et périmètre que a ; c = même événement que a
  });
});

describe("économie de lectures et d'écritures", () => {
  test("article : identifiant « news_… » (les commentaires des autres posts ne coûtent aucune lecture)", async () => {
    const clean = cleanNewsInput({
      agentKey: "sport", level: "world", title: "Un titre d'article suffisamment long", chapo: "Un chapô de quarante caractères au moins pour passer la validation.",
      sections: [{ titre: "Section", texte: "Un texte de section assez long pour passer la validation du modèle d'article d'actualité." }], sources: [{ name: "RFI", url: "https://www.rfi.fr/a" }],
    });
    if (!clean.ok) throw new Error(clean.error);
    const r = await publishNews(clean.value, { nowMs: NOW });
    expect(r.id.startsWith(NEWS_ID_PREFIX)).toBe(true);
    expect(sets.some((s) => s.col === "Posts" && s.id === r.id)).toBe(true);
  });
  test("verrou : un seul passage à la fois", async () => {
    expect(await acquireRunLock(NOW)).toBe(true);
    expect(await acquireRunLock(NOW + 1000)).toBe(false);
    expect(await acquireRunLock(NOW + 10 * 60 * 1000)).toBe(true); // verrou expiré
    await releaseRunLock();
    expect(await acquireRunLock(NOW + 11 * 60 * 1000)).toBe(true);
  });
  test("nettoyage : sans document ancien, rien n'est supprimé", async () => {
    const r = await runNewsCleanup(NOW);
    expect(Object.values(r).every((n) => n === 0)).toBe(true);
  });
});
