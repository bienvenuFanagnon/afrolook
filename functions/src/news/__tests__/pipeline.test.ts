jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: { increment: (n: number) => n } }));
jest.mock("firebase-functions/params", () => ({ defineSecret: () => ({ value: () => "[]" }) }));

import { parseFeed } from "../rss";
import { parsePreview, publicHttps } from "../pagePreview";
import { RawItem, Topic, buildTopics, classify, clusterItems, detectCountry, linkHash, scopeOf, titleTokens, similar } from "../cluster";
import { copiedRun, inventedNumbers, unknownNames, validateSummary } from "../validate";
import { fixHint, summarizeTopic } from "../summarize";
import { chooseModel, planSelection, readPipelineConfig, readSource, topicKey } from "../pipeline";
import { activeSources, DEFAULT_SOURCES } from "../sources";
import { cleanNewsInput } from "../model";

const NOW = Date.parse("2026-10-21T12:00:00Z");
const hoursAgo = (h: number) => new Date(NOW - h * 3_600_000).toISOString();

const item = (o: Partial<RawItem> & { titre: string }): RawItem => ({
  sourceId: "rfi_afrique", sourceName: "RFI", lang: "fr", region: "africa", categoryHint: null, lien: `https://exemple.fr/${Math.abs(o.titre.length * 7 + (o.sourceName ?? "x").length)}-${o.titre.slice(0, 6)}`,
  date: hoursAgo(2), resume: "Un extrait suffisamment long pour servir de matière au résumé de cet article, avec des détails et des faits précis.", corps: "", image: null, ...o,
});

describe("lecture des flux", () => {
  const RSS = `<?xml version="1.0"?><rss xmlns:media="http://search.yahoo.com/mrss/" xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel>
  <item><title><![CDATA[Le Togo &amp; le Bénin se préparent]]></title><link>https://exemple.fr/a?utm=1</link><pubDate>Wed, 21 Oct 2026 10:00:00 GMT</pubDate>
  <description><![CDATA[<p>Un extrait [...]</p>]]></description><content:encoded><![CDATA[<p>Contenu complet de l'article avec <b>plusieurs</b> détails.</p>]]></content:encoded>
  <media:content url="http://img.exemple.fr/a.jpg" medium="image"/></item>
  <item><title>Sans date</title><link>https://exemple.fr/b</link></item>
  <item><title>Lien non web</title><link>javascript:alert(1)</link><pubDate>Wed, 21 Oct 2026 10:00:00 GMT</pubDate></item></channel></rss>`;
  test("RSS : titre décodé, lien, date, extrait propre, image en https ; éléments incomplets ignorés", () => {
    const l = parseFeed(RSS);
    expect(l).toHaveLength(1);
    expect(l[0].titre).toBe("Le Togo & le Bénin se préparent");
    expect(l[0].resume).toBe("Un extrait");
    expect(l[0].corps).toContain("plusieurs détails");
    expect(l[0].image).toBe("https://img.exemple.fr/a.jpg");
    expect(l[0].date).toBe("2026-10-21T10:00:00.000Z");
  });
  test("Atom", () => {
    const l = parseFeed(`<feed><entry><title>Titre atom</title><link href="https://exemple.fr/x"/><updated>2026-10-21T09:00:00Z</updated><summary>Résumé atom</summary></entry></feed>`);
    expect(l).toHaveLength(1);
    expect(l[0].lien).toBe("https://exemple.fr/x");
  });
  test("aperçu de page : image og, adresses internes refusées", () => {
    expect(parsePreview(`<meta property="og:image" content="/img/a.jpg"><meta property="og:description" content="${"d".repeat(60)}">`, "https://exemple.fr/p").image).toBe("https://exemple.fr/img/a.jpg");
    expect(publicHttps("https://exemple.fr/a")).toBe(true);
    expect(publicHttps("http://exemple.fr/a")).toBe(false);
    expect(publicHttps("https://127.0.0.1/a")).toBe(false);
    expect(publicHttps("https://localhost/a")).toBe(false);
  });
  test("une source en panne ne lève pas d'exception", async () => {
    const down = jest.fn(async () => ({ ok: false, status: 503, text: async () => "" }) as unknown as Response);
    const r = await readSource(DEFAULT_SOURCES[0], down as unknown as typeof fetch);
    expect(r.status.ok).toBe(false);
    expect(r.status.error).toBe("HTTP 503");
    const up = jest.fn(async () => ({ ok: true, status: 200, text: async () => RSS }) as unknown as Response);
    const ok = await readSource(DEFAULT_SOURCES[0], up as unknown as typeof fetch);
    expect(ok.status.ok).toBe(true);
    expect(ok.items).toHaveLength(1);
  });
});

describe("pays, domaines et sujets", () => {
  test("pays : titre pesant plus que l'extrait, expressions à plusieurs mots, ambiguïtés", () => {
    expect(detectCountry("Le Togo adopte une nouvelle mesure", "")).toBe("TG");
    expect(detectCountry("Football : le Sénégal bat le Mali", "")).toBeNull(); // deux pays à égalité
    expect(detectCountry("Élections en Afrique du Sud", "")).toBe("ZA");
    expect(detectCountry("Visite en Guinée équatoriale", "")).toBe("GQ");
    expect(detectCountry("Coup d'État en Guinée", "Conakry est calme")).toBe("GN");
    expect(detectCountry("Ivory Coast hosts the summit", "")).toBe("CI");
    expect(detectCountry("Une décision européenne", "rien sur l'Afrique")).toBeNull();
    expect(detectCountry("Nigeria et Niger signent un accord", "")).toBeNull();
  });
  test("domaine : indice du flux, musique avant culture, mots-clés pour les flux généraux", () => {
    expect(classify({ titre: "Sans rapport", resume: "", categoryHint: "tech" })).toBe("tech");
    expect(classify({ titre: "Le rappeur sort son album et annonce un concert", resume: "", categoryHint: "culture" })).toBe("musique");
    expect(classify({ titre: "Le match de football entre les deux équipes", resume: "le joueur marque", categoryHint: null })).toBe("sport");
    expect(classify({ titre: "Le président annonce une réforme au parlement", resume: "", categoryHint: null })).toBe("politique");
    expect(classify({ titre: "Une journée ordinaire", resume: "", categoryHint: null })).toBeNull();
  });
  test("regroupement : même sujet, médias différents ; sujets distincts séparés", () => {
    expect(similar(titleTokens("Le Togo adopte une loi sur les jeunes entrepreneurs"), titleTokens("Togo : une loi pour les jeunes entrepreneurs adoptée"))).toBe(true);
    expect(similar(titleTokens("Le Togo adopte une loi sur les jeunes entrepreneurs"), titleTokens("Festival de musique à Dakar ce week-end"))).toBe(false);
    const g = clusterItems([
      item({ titre: "Le Togo adopte une loi sur les jeunes entrepreneurs", sourceName: "RFI" }),
      item({ titre: "Togo : une loi pour les jeunes entrepreneurs adoptée", sourceName: "Africanews", date: hoursAgo(3) }),
      item({ titre: "Festival de musique à Dakar ce week-end", sourceName: "RFI" }),
    ]);
    expect(g).toHaveLength(2);
    expect(g[0]).toHaveLength(2);
  });
  test("niveau : pays configuré, autre pays africain → continent, flux mondial → monde", () => {
    expect(scopeOf("TG", ["TG"], "africa")).toEqual({ level: "country", country: "TG" });
    expect(scopeOf("KE", ["TG"], "africa")).toEqual({ level: "continent", country: null });
    expect(scopeOf(null, ["TG"], "africa")).toEqual({ level: "continent", country: null });
    expect(scopeOf(null, ["TG"], "world")).toEqual({ level: "world", country: null });
  });
  test("sujets : anciens, sans domaine ou sans matière écartés ; score qui favorise les sources multiples", () => {
    const items = [
      item({ titre: "Le Togo adopte une loi sur les jeunes entrepreneurs", sourceName: "RFI", categoryHint: "politique" }),
      item({ titre: "Togo : une loi pour les jeunes entrepreneurs adoptée", sourceName: "Africanews", categoryHint: "politique", date: hoursAgo(3) }),
      item({ titre: "Match de football : victoire de l'équipe nationale ce soir", sourceName: "RFI", categoryHint: "sport", region: "world", corps: "x".repeat(250) }),
      item({ titre: "Vieille histoire de football entre deux équipes", sourceName: "RFI", categoryHint: "sport", date: hoursAgo(80) }),
      item({ titre: "Une journée ordinaire sans domaine", sourceName: "RFI" }),
      item({ titre: "Voyage : une destination mise en avant pour les vacances", sourceName: "Le Monde", categoryHint: "voyage", region: "world", resume: "court", corps: "" }),
    ];
    const t = buildTopics(items, ["TG"], NOW);
    expect(t.map((x) => x.category)).toEqual(["politique", "sport"]);
    expect(t[0]).toMatchObject({ level: "country", country: "TG", distinctSources: 2 });
    expect(t[1].level).toBe("world");
    expect(t[0].score).toBeGreaterThan(t[1].score);
  });
});

const SOURCES_TEXT = "Les Éperviers du Togo préparent le match de qualification contre le Bénin. Le sélectionneur Paulo Duarte a dévoilé une liste de 24 joueurs. Trois joueurs sont absents. Le match aura lieu samedi à Lomé devant 20000 spectateurs attendus.";
const GOOD = {
  titre: "Les Éperviers dévoilent leur groupe pour affronter le Bénin",
  chapo: "Le sélectionneur a retenu 24 joueurs pour la rencontre de samedi à Lomé, avec trois absents confirmés avant ce rendez-vous important.",
  sections: [
    { titre: "La liste", texte: "Le sélectionneur Paulo Duarte a retenu 24 joueurs pour préparer cette rencontre de qualification. Le groupe se retrouve dès demain afin de peaufiner les derniers réglages avant le coup d'envoi." },
    { titre: "Les absents", texte: "Trois joueurs manqueront ce rendez-vous, selon les informations rapportées par les sources. Le staff devra donc adapter son dispositif pour affronter le Bénin devant près de 20000 spectateurs à Lomé." },
  ],
  retenir: ["Liste de 24 joueurs dévoilée", "Trois absents confirmés", "Match samedi à Lomé"],
  notif: { titre: "Éperviers : la liste est tombée", corps: "Trois absents et un match samedi à Lomé : le point complet." },
};
const ctx = { sourcesText: SOURCES_TEXT, refs: ["Les Éperviers du Togo préparent le match de qualification contre le Bénin", "Le match aura lieu samedi à Lomé devant 20000 spectateurs attendus"] };

describe("garde-fous du résumé de l'IA", () => {
  test("un bon résumé passe, y compris entouré de balises ```json", () => {
    expect(validateSummary(GOOD, ctx).ok).toBe(true);
    expect(validateSummary("```json\n" + JSON.stringify(GOOD) + "\n```", ctx).ok).toBe(true);
  });
  test("refus : JSON invalide, chiffre inventé, nom inventé, texte recopié, anglais, longueurs", () => {
    expect(validateSummary("pas du json", ctx)).toEqual({ ok: false, errors: ["json_invalide"] });
    const bad = (patch: Record<string, unknown>) => validateSummary({ ...GOOD, ...patch }, ctx);
    const r1 = bad({ chapo: GOOD.chapo.replace("24", "37") });
    expect(r1.ok === false && r1.errors.join()).toContain("chiffre_invente:37");
    const r2 = bad({ chapo: GOOD.chapo + " Karim Benzema sera présent selon une rumeur." });
    expect(r2.ok === false && r2.errors.join()).toContain("nom_invente");
    const r3 = bad({ sections: [{ titre: "Copie", texte: "Le match aura lieu samedi à Lomé devant 20000 spectateurs attendus et le public sera nombreux pour cette rencontre de qualification, que les supporters suivent avec beaucoup d'attention depuis plusieurs jours." }, GOOD.sections[1]] });
    expect(r3.ok === false && r3.errors.join()).toContain("texte_recopie");
    const r4 = bad({ titre: "The team announces its squad for the next game against Benin", chapo: "The coach has selected twenty four players for the game that will take place on Saturday in the capital city." });
    expect(r4.ok).toBe(false);
    expect(bad({ titre: "Court" }).ok).toBe(false);
    expect(bad({ retenir: ["un"] }).ok).toBe(false);
  });
  test("fonctions de contrôle", () => {
    expect(inventedNumbers("Il y a 24 joueurs et 37 absents, soit 12,5 %", "24 joueurs")).toEqual(["37", "12,5"]);
    expect(unknownNames("Le Paulo sera là. Selon Karim Benzema, ça marche", " paulo ")).toEqual(["Karim", "Benzema"]);
    expect(copiedRun("un deux trois quatre cinq six sept huit neuf", ["quatre cinq six sept huit neuf dix onze"], 6)).toBe("quatre cinq six sept huit neuf");
  });
});

describe("résumé d'un sujet", () => {
  const topic = (): Topic => ({
    items: [item({ titre: "Les Éperviers du Togo préparent le match de qualification contre le Bénin", sourceName: "Africanews", categoryHint: "sport", corps: SOURCES_TEXT, image: "https://img.exemple.fr/a.jpg", lien: "https://exemple.fr/1" }),
      item({ titre: "Togo : la liste de 24 joueurs est connue", sourceName: "RFI", categoryHint: "sport", corps: "Le sélectionneur Paulo Duarte a dévoilé la liste.", lien: "https://exemple.fr/2" })],
    category: "sport", level: "country", country: "TG", distinctSources: 2, score: 10,
  });
  const ai = (text: string) => jest.fn(async () => ({ text, neurons: 150, accountId: "a".repeat(32), model: "m", ms: 5 }));

  test("succès : entrée prête pour la publication, agent du domaine, sources citées, image conservée", async () => {
    const run = ai(JSON.stringify(GOOD));
    const r = await summarizeTopic(topic(), { run: run as never, nowMs: NOW });
    expect(r.ok).toBe(true);
    const clean = cleanNewsInput(r.input);
    expect(clean.ok).toBe(true);
    if (!clean.ok) return;
    expect(clean.value.agentKey).toBe("sport");
    expect(clean.value.scope).toBe("country_TG");
    expect(clean.value.sources.map((s) => s.name)).toEqual(["Africanews", "RFI"]);
    expect(clean.value.image).toBe("https://img.exemple.fr/a.jpg");
    expect(clean.value.notif?.title).toBe("Éperviers : la liste est tombée");
    expect((run.mock.calls[0] as unknown as unknown[])[0]).toEqual(expect.arrayContaining([expect.objectContaining({ role: "system" })]));
  });
  test("texte refusé deux fois : erreurs renvoyées, rien à publier, les deux appels comptés", async () => {
    const run = ai("n'importe quoi");
    const r = await summarizeTopic(topic(), { run: run as never });
    expect(r.ok).toBe(false);
    expect(r.errors).toEqual(["json_invalide"]);
    expect(r.retried).toBe(true);
    expect(run).toHaveBeenCalledTimes(2);
    expect(r.neurons).toBe(300);
  });
  test("premier texte refusé : un second essai guidé par l'erreur le rattrape", async () => {
    const run = jest.fn()
      .mockResolvedValueOnce({ text: '{"titre": "coupé', neurons: 100, accountId: "a".repeat(32), model: "m", ms: 5 })
      .mockResolvedValueOnce({ text: JSON.stringify(GOOD), neurons: 120, accountId: "a".repeat(32), model: "m", ms: 5 });
    const r = await summarizeTopic(topic(), { run: run as never });
    expect(r.ok).toBe(true);
    expect(r.retried).toBe(true);
    expect(r.neurons).toBe(220);
    const secondCall = (run.mock.calls[1] as unknown as [Array<{ role: string; content: string }>])[0];
    expect(secondCall.slice(-2).map((m) => m.role)).toEqual(["assistant", "user"]);
    expect(secondCall[secondCall.length - 1].content).toContain("json_invalide");
  });
  test("consigne de correction : une phrase par erreur", () => {
    expect(fixHint(["texte_recopie:a b c", "nom_invente:Karim,Zidane", "titre_longueur"])).toMatch(/Reformule entièrement.*Retire les noms.*Karim,Zidane.*40 et 100/);
  });
  test("une erreur de l'IA n'entraîne pas de second essai", async () => {
    const run = jest.fn(async () => { throw new Error("réseau"); });
    const r = await summarizeTopic(topic(), { run: run as never });
    expect(r.ok).toBe(false);
    expect(run).toHaveBeenCalledTimes(1);
  });
  test("quota : le passage est signalé comme arrêté", async () => {
    const quota = Object.assign(new Error("plafond"), { code: "quota" });
    const flag = { hit: false };
    const r = await summarizeTopic(topic(), { run: jest.fn(async () => { throw quota; }) as never, quotaFlag: flag });
    expect(r.ok).toBe(false);
    expect(flag.hit).toBe(true);
  });
});

describe("choix des sujets du passage", () => {
  const T = (cat: Topic["category"], level: Topic["level"], country: string | null, score: number, link: string): Topic => ({
    items: [item({ titre: `Sujet ${link}`, lien: `https://exemple.fr/${link}` })], category: cat, level, country, distinctSources: 2, score,
  });
  const cfg = { dailyCap: 60, perRun: 4, perKeyDaily: 2 };
  const none = new Map();

  test("un tour de table entre agents, meilleurs sujets d'abord", () => {
    const topics = [T("sport", "country", "TG", 20, "s1"), T("sport", "country", "TG", 19, "s2"), T("politique", "world", null, 15, "p1"), T("tech", "world", null, 12, "t1"), T("voyage", "world", null, 9, "v1")];
    const plan = planSelection(topics, { published: 0, byKey: {} }, cfg, none, NOW);
    expect(plan.map((t) => t.items[0].titre)).toEqual(["Sujet s1", "Sujet p1", "Sujet t1", "Sujet v1"]);
  });
  test("plafonds : par jour, par agent et périmètre ; aucun sujet déjà publié ; échec récent bloqué", () => {
    const topics = [T("sport", "country", "TG", 20, "s1"), T("sport", "country", "TG", 19, "s2"), T("sport", "country", "TG", 18, "s3")];
    expect(planSelection(topics, { published: 0, byKey: {} }, { ...cfg, perRun: 5 }, none, NOW)).toHaveLength(1); // un seul par agent et périmètre et par passage
    expect(planSelection(topics, { published: 0, byKey: { "sport|country_TG": 1 } }, { ...cfg, perRun: 5 }, none, NOW)).toHaveLength(1); // 2 par jour au plus
    expect(planSelection(topics, { published: 0, byKey: { "sport|country_TG": 2 } }, cfg, none, NOW)).toHaveLength(0);
    expect(planSelection(topics, { published: 60, byKey: {} }, cfg, none, NOW)).toHaveLength(0);
    const seen = new Map([[linkHash("https://exemple.fr/s1"), { status: "published" as const }], [linkHash("https://exemple.fr/s2"), { status: "failed" as const, retryAfter: NOW + 3600_000 }]]);
    expect(planSelection(topics, { published: 0, byKey: {} }, cfg, seen, NOW).map((t) => t.items[0].titre)).toEqual(["Sujet s3"]);
    const later = new Map([[linkHash("https://exemple.fr/s2"), { status: "failed" as const, retryAfter: NOW - 1 }]]);
    expect(planSelection([topics[1]], { published: 0, byKey: {} }, cfg, later, NOW).map((t) => t.items[0].titre)).toEqual(["Sujet s2"]); // le blocage de 12 h est levé
  });
  test("clé de plafond et modèle selon la consommation", () => {
    expect(topicKey(T("musique", "continent", null, 1, "m"))).toBe("beat|continent_AF");
    expect(topicKey(T("politique", "country", "BJ", 1, "p"))).toBe("politik|country_BJ");
    expect(chooseModel(1000)).toContain("70b");
    expect(chooseModel(12000)).toContain("8b");
  });
});

describe("réglages", () => {
  test("valeurs prudentes par défaut ; génération automatique coupée tant qu'elle n'est pas activée", () => {
    const c = readPipelineConfig(undefined);
    expect(c).toMatchObject({ enabled: true, pipelineEnabled: false, dailyCap: 60, perRun: 5, perKeyDaily: 2 });
    expect(c.countries).toEqual(["TG", "BJ", "CI", "SN", "CM"]);
    expect(readPipelineConfig({ pipelineEnabled: true, countries: ["gh", "ZZ", "ng"], perRun: 99 })).toMatchObject({ pipelineEnabled: true, countries: ["GH", "NG"], perRun: 5 });
  });
  test("sources : actives par défaut, réglages par source, sources ajoutées validées", () => {
    const ids = (c: Parameters<typeof activeSources>[0]) => activeSources(c).map((s) => s.id);
    expect(ids({})).toContain("africanews_fr");
    expect(ids({})).not.toContain("rfi_afrique"); // RFI refuse nos serveurs (403) : désactivé par défaut
    expect(ids({})).not.toContain("jeuneafrique");
    expect(ids({ sourcesOn: { jeuneafrique: true, africanews_fr: false } })).toEqual(expect.arrayContaining(["jeuneafrique"]));
    expect(ids({ sourcesOn: { africanews_fr: false } })).not.toContain("africanews_fr");
    expect(ids({ sourcesOn: { rfi_afrique: true } })).toContain("rfi_afrique");
    expect(ids({ customSources: [{ id: "togofirst", name: "Togo First", url: "https://www.togofirst.com/fr/rss", category: "politique" }, { id: "x", url: "http://non.https" }] })).toContain("togofirst");
    expect(ids({ customSources: [{ id: "x", url: "http://non.https" }] })).not.toContain("x");
  });
});
