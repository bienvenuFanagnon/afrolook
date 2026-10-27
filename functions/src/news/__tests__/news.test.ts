jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: () => ({}) }));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: {}, FieldPath: {} }));

import { CONTINENT_OF, continentOf, scopeKey, scopesForUser } from "../geo";
import { AGENT_OF_CATEGORY, NEWS_AGENTS, agentUserId } from "../agents";
import { DAY_MS, buildFeedItem, buildNewsPostDoc, cleanNewsInput, cleanUrl, decideExpiry, lifespanDays, mergeFeedItems, popularityBonus, MAX_FEED_ITEMS } from "../model";
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
  test("les 8 agents : 6 de départ, puis la mode et les événements importants", () => {
    expect(NEWS_AGENTS.map((a) => a.pseudo)).toEqual(["AfroSport", "AfroPolitik", "AfroCulture", "AfroBeat", "AfroTech", "AfroVoyage", "AfroMode", "AfroInfo"]);
    expect(NEWS_AGENTS.every((a) => AGENT_OF_CATEGORY[a.category] === a.key)).toBe(true); // chaque domaine a son agent
    expect(lifespanDays("mode")).toBe(14);
    expect(lifespanDays("evenement")).toBe(5);
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
    const T0 = Date.parse("2026-10-21T12:00:00Z");
    let list: ReturnType<typeof mergeFeedItems> = [];
    for (let i = 0; i < 40; i++) list = mergeFeedItems(list, buildFeedItem(r.value, `id${i}`, T0 + i), T0 + i);
    expect(list).toHaveLength(MAX_FEED_ITEMS);
    expect(list[0].id).toBe("id39");
    const again = mergeFeedItems(list, buildFeedItem(r.value, "id20", T0 + 99), T0 + 99);
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

describe("durée de vie des articles", () => {
  const NOW = Date.parse("2026-10-21T12:00:00Z");
  const make = (extra: Record<string, unknown> = {}) => {
    const r = cleanNewsInput({ ...base, ...extra });
    if (!r.ok) throw new Error(r.error);
    return r.value;
  };
  test("durée selon le domaine, ou imposée par l'administrateur (1 à 45 jours)", () => {
    expect([lifespanDays("sport"), lifespanDays("politique"), lifespanDays("voyage"), lifespanDays("inconnu")]).toEqual([4, 7, 21, 7]);
    const doc = buildNewsPostDoc(make(), "news_a1", NOW);
    expect(doc["expiresAt"]).toBe(NOW + 4 * DAY_MS);
    expect(buildNewsPostDoc(make({ lifeDays: 10 }), "news_a2", NOW)["expiresAt"]).toBe(NOW + 10 * DAY_MS);
    expect(buildNewsPostDoc(make({ lifeDays: 99 }), "news_a3", NOW)["expiresAt"]).toBe(NOW + 4 * DAY_MS); // hors limites : durée du domaine
    expect(buildFeedItem(make(), "news_a1", NOW).exp).toBe(NOW + 4 * DAY_MS);
  });
  test("l'index du fil écarte les articles périmés", () => {
    const fresh = buildFeedItem(make(), "frais", NOW);
    const stale = { ...buildFeedItem(make(), "vieux", NOW - 10 * DAY_MS) };
    const list = mergeFeedItems([stale, { ...fresh, id: "autre" }], buildFeedItem(make(), "nouveau", NOW), NOW);
    expect(list.map((i) => i.id)).toEqual(["nouveau", "autre"]);
  });
  test("bonus de popularité : ×1,5 dès 50 points, ×2 dès 200", () => {
    expect(popularityBonus({ loves: 10, comments: 2, giftCount: 1 })).toBe(1);
    expect(popularityBonus({ loves: 30, comments: 10 })).toBe(1.5);
    expect(popularityBonus({ loves: 100, comments: 50, giftCount: 5 })).toBe(2);
  });
  test("à l'échéance : garder, prolonger une fois par palier, supprimer ; garde-fou à 45 jours", () => {
    const created = NOW - 5 * DAY_MS;
    const post = (o: Record<string, unknown> = {}) => ({ created_at: created * 1000, expiresAt: created + 4 * DAY_MS, news: { category: "sport" }, ...o });
    expect(decideExpiry(post({ expiresAt: NOW + DAY_MS }), NOW)).toEqual({ action: "keep" });
    expect(decideExpiry(post(), NOW)).toEqual({ action: "delete" });
    // très aimé : prolongé à 6 jours (4 × 1,5) depuis la création, donc encore vivant
    expect(decideExpiry(post({ loves: 60 }), NOW)).toEqual({ action: "extend", expiresAt: created + 6 * DAY_MS, tier: 1.5 });
    // déjà prolongé à ce palier : supprimé à la nouvelle échéance
    expect(decideExpiry(post({ loves: 60, extendedTier: 1.5, expiresAt: created + 6 * DAY_MS - 1 }), NOW + 2 * DAY_MS)).toEqual({ action: "delete" });
    // palier supérieur : prolongé encore (21 j × 2 = 42 j depuis la création)
    const c2 = NOW - 33 * DAY_MS;
    expect(decideExpiry({ created_at: c2 * 1000, expiresAt: c2 + 31.5 * DAY_MS, extendedTier: 1.5, loves: 300, news: { category: "voyage" } }, NOW)).toEqual({ action: "extend", expiresAt: c2 + 42 * DAY_MS, tier: 2 });
    // jamais au-delà de 45 jours depuis la création
    const c3 = NOW - 40 * DAY_MS;
    expect(decideExpiry({ created_at: c3 * 1000, expiresAt: c3 + 30 * DAY_MS, loves: 300, news: { category: "voyage", lifeDays: 30 } }, NOW)).toEqual({ action: "extend", expiresAt: c3 + 45 * DAY_MS, tier: 2 });
    expect(decideExpiry({ created_at: (NOW - 46 * DAY_MS) * 1000, expiresAt: NOW + 5 * DAY_MS, news: { category: "voyage" } }, NOW)).toEqual({ action: "delete" });
    // ancien article sans date de fin : calculée d'après son domaine
    expect(decideExpiry({ created_at: created * 1000, news: { category: "voyage" } }, NOW)).toEqual({ action: "keep" });
  });
});
