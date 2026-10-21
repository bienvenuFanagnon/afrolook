jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: () => ({}) }));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: {}, FieldPath: {} }));

import { CONTINENT_OF, continentOf, scopeKey, scopesForUser } from "../geo";
import { NEWS_AGENTS, agentUserId } from "../agents";
import { buildFeedItem, buildNewsPostDoc, cleanNewsInput, cleanUrl, mergeFeedItems, MAX_FEED_ITEMS } from "../model";
import { commentMessage, likeMessage, milestoneMessage, newMilestone, shouldPushComment, shouldPushLike } from "../engagement";
import { postGiftShares } from "../../payments/coinShares";

const base = {
  agentKey: "sport", level: "country", country: "tg",
  title: "Les Éperviers préparent leur match de qualification",
  chapo: "Le sélectionneur a dévoilé sa liste de 24 joueurs ; trois absents sont à signaler avant le déplacement.",
  sections: [{ titre: "La liste", texte: "Le sélectionneur a retenu vingt-quatre joueurs pour la double confrontation, avec trois absents confirmés par la fédération." }],
  retenir: ["Liste de 24 joueurs", "Trois absents", "Match samedi"],
  sources: [{ name: "Africanews", url: "https://www.africanews.com/a" }, { name: "RFI Sport", url: "https://www.rfi.fr/b" }],
  image: "https://cdn.afrolookmedia.com/media/a.jpg",
};

describe("géographie des actualités", () => {
  test("continent d'un pays et clé de périmètre", () => {
    expect(continentOf("tg")).toBe("AF");
    expect(continentOf("FR")).toBe("EU");
    expect(continentOf("BR")).toBe("SA");
    expect(continentOf("XX")).toBeNull();
    expect(scopeKey("country", "tg")).toBe("country_TG");
    expect(scopeKey("continent", undefined, "af")).toBe("continent_AF");
    expect(scopeKey("world")).toBe("world");
    expect(scopeKey("country", "togo")).toBeNull();
  });
  test("périmètres d'une personne : pays, continent, monde", () => {
    expect(scopesForUser("TG")).toEqual(["country_TG", "continent_AF", "world"]);
    expect(scopesForUser(undefined)).toEqual(["world"]);
  });
  test("aucun pays n'est classé dans deux continents", () => {
    expect(Object.keys(CONTINENT_OF).length).toBeGreaterThan(230);
  });
});

describe("agents", () => {
  test("les 6 agents de départ", () => {
    expect(NEWS_AGENTS.map((a) => a.pseudo)).toEqual(["AfroSport", "AfroPolitik", "AfroCulture", "AfroBeat", "AfroTech", "AfroVoyage"]);
    expect(agentUserId("sport")).toBe("news_agent_sport");
  });
});

describe("validation et construction d'un article", () => {
  test("article valide : normalisé, continent déduit, périmètre calculé", () => {
    const r = cleanNewsInput(base);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.value.country).toBe("TG");
    expect(r.value.continent).toBe("AF");
    expect(r.value.scope).toBe("country_TG");
    expect(r.value.category).toBe("sport");
    expect(r.value.sources).toHaveLength(2);
  });
  test("refus : agent inconnu, source manquante, lien non sûr, texte trop court", () => {
    expect(cleanNewsInput({ ...base, agentKey: "zz" }).ok).toBe(false);
    expect(cleanNewsInput({ ...base, sources: [] }).ok).toBe(false);
    expect(cleanNewsInput({ ...base, sources: [{ name: "Site", url: "http://exemple.com/a" }] }).ok).toBe(false);
    expect(cleanNewsInput({ ...base, title: "Court" }).ok).toBe(false);
    expect(cleanNewsInput({ ...base, level: "country", country: "" }).ok).toBe(false);
    expect(cleanNewsInput({ ...base, level: "continent", country: undefined, continent: "" }).ok).toBe(false);
    expect(cleanNewsInput({ ...base, sections: [{ titre: "x", texte: "trop court" }] }).ok).toBe(false);
  });
  test("liens : https seulement, sans identifiants", () => {
    expect(cleanUrl("https://www.rfi.fr/a")).toBe("https://www.rfi.fr/a");
    expect(cleanUrl("https://user:pw@rfi.fr/a")).toBe("");
    expect(cleanUrl("javascript:alert(1)")).toBe("");
    expect(cleanUrl("https://localhost/a")).toBe("");
  });
  test("document du post : compatible avec les posts, jamais monétisé, type NEWS", () => {
    const r = cleanNewsInput({ ...base, level: "world", country: undefined });
    if (!r.ok) throw new Error(r.error);
    const doc = buildNewsPostDoc(r.value, "abc12345", 1_700_000_000_000);
    expect(doc["type"]).toBe("NEWS");
    expect(doc["user_id"]).toBe("news_agent_sport");
    expect(doc["monetized"]).toBe(false);
    expect(doc["created_at"]).toBe(1_700_000_000_000_000);
    expect(doc["availableCountries"]).toEqual(["ALL"]);
    expect(doc["images"]).toEqual([base.image]);
    expect((doc["news"] as Record<string, unknown>)["scope"]).toBe("world");
  });
  test("index du fil : plus récent en tête, sans doublon, 30 au plus", () => {
    const r = cleanNewsInput(base);
    if (!r.ok) throw new Error(r.error);
    let list: ReturnType<typeof mergeFeedItems> = [];
    for (let i = 0; i < 40; i++) list = mergeFeedItems(list, buildFeedItem(r.value, `id${i}`, i));
    expect(list).toHaveLength(MAX_FEED_ITEMS);
    expect(list[0].id).toBe("id39");
    const again = mergeFeedItems(list, buildFeedItem(r.value, "id20", 99));
    expect(again[0].id).toBe("id20");
    expect(again.filter((x) => x.id === "id20")).toHaveLength(1);
  });
});

describe("cadeaux : les agents ne gardent rien", () => {
  test("créateur normal : 70 % ; agent d'actualités : 0, tout à l'app après les parrains", () => {
    expect(postGiftShares(100, 5, false)).toEqual({ receiverCoins: 70, appCoins: 25 });
    expect(postGiftShares(100, 5, true)).toEqual({ receiverCoins: 0, appCoins: 95 });
    expect(postGiftShares(100, 0, true)).toEqual({ receiverCoins: 0, appCoins: 100 });
  });
});

describe("notifications d'engagement", () => {
  test("paliers : une seule fois, le plus haut franchi", () => {
    expect(newMilestone("views", 90, 110, [])).toBe(100);
    expect(newMilestone("views", 90, 110, ["views_100"])).toBeNull();
    expect(newMilestone("views", 90, 1200, [])).toBe(1000);
    expect(newMilestone("views", 100, 120, [])).toBeNull();
    expect(newMilestone("loves", 9, 10, [])).toBe(10);
    expect(newMilestone("comments", 4, 5, [])).toBe(5);
  });
  test("textes courts et fidèles", () => {
    const m = milestoneMessage("views", 1000, "Les Éperviers préparent leur match de qualification contre le Bénin demain soir");
    expect(m.title).toContain("1 000");
    expect(m.title.length).toBeLessThanOrEqual(80);
    const c = commentMessage("Aïcha", "Les Éperviers préparent leur match", "Super résumé, j'attendais ça depuis ce matin !");
    expect(c.body).toBe("Super résumé, j'attendais ça depuis ce matin !");
    expect(likeMessage("Koffi", "Titre").title).toBe("❤️ @Koffi a aimé");
  });
  test("commentaire : assez long, jamais automatique, plafonds par article", () => {
    const t0 = Date.parse("2026-10-21T10:00:00Z");
    const long = "Super résumé, merci beaucoup pour l'info";
    expect(shouldPushComment(long, false, undefined, t0)).toBe(true);
    expect(shouldPushComment("Bravo !", false, undefined, t0)).toBe(false);
    expect(shouldPushComment(long, true, undefined, t0)).toBe(false);
    expect(shouldPushComment(long, false, { commentAt: t0 - 10 * 60 * 1000 }, t0)).toBe(false);
    expect(shouldPushComment(long, false, { commentAt: t0 - 40 * 60 * 1000, commentDay: "2026-10-21", commentN: 1 }, t0)).toBe(true);
    expect(shouldPushComment(long, false, { commentAt: t0 - 40 * 60 * 1000, commentDay: "2026-10-21", commentN: 2 }, t0)).toBe(false);
    expect(shouldPushComment(long, false, { commentAt: t0 - 40 * 60 * 1000, commentDay: "2026-10-20", commentN: 2 }, t0)).toBe(true);
  });
  test("j'aime : seulement d'une personne suivie, au plus 1 par heure", () => {
    const t0 = Date.parse("2026-10-21T10:00:00Z");
    expect(shouldPushLike(5, undefined, t0)).toBe(false);
    expect(shouldPushLike(25, undefined, t0)).toBe(true);
    expect(shouldPushLike(25, { likeAt: t0 - 30 * 60 * 1000 }, t0)).toBe(false);
    expect(shouldPushLike(25, { likeAt: t0 - 2 * 3600 * 1000, likeDay: "2026-10-21", likeN: 2 }, t0)).toBe(false);
  });
});
