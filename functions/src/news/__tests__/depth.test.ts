jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: { increment: (n: number) => n } }));
jest.mock("firebase-functions/params", () => ({ defineSecret: () => ({ value: () => "[]" }) }));

import { extractArticleText, fetchArticleText } from "../pagePreview";
import { RawItem, Topic } from "../cluster";
import { deepRead } from "../pipeline";
import { buildMessages } from "../summarize";
import { validateSummary } from "../validate";

/** Texte réel d'une page Africanews (21/10/2026), tel que l'extraction le rend : sert de jeu d'essai pour juger la profondeur d'un article. */
const BURUNDI = "Le Burundi a commémoré, mercredi 21 octobre, le 33e anniversaire de l’assassinat de Melchior Ndadaye, premier président démocratiquement élu du pays. À Bujumbura, les cérémonies ont été marquées par des dépôts de gerbes et des appels à renforcer la démocratie. Sur la place des Héros de la démocratie, à Bujumbura, le président Évariste Ndayishimiye a rendu hommage à Melchior Ndadaye et à ses proches collaborateurs, tués lors du coup d’État d’octobre 1993. Le chef de l’État a déposé des couronnes de fleurs en leur mémoire. Une messe a également été célébrée en hommage aux victimes, avant que les familles et les représentants des partis politiques ne procèdent à leur tour à des dépôts de gerbes. Cette commémoration a aussi été l’occasion pour plusieurs responsables politiques de dresser un bilan de l’évolution démocratique du Burundi, plus de trois décennies après la disparition de Melchior Ndadaye. Pour Olivier Nkurunziza, président de l’Union pour le progrès national (UPRONA), la paix retrouvée ne suffit pas à garantir une démocratie effective. « Bien sûr, la paix règne, mais la démocratie au Burundi doit véritablement devenir une réalité », a-t-il déclaré, mettant en garde contre un éventuel retour au système de parti unique, contraire aux idéaux de multipartisme défendus par Melchior Ndadaye. Gabriel Banzawitonde, président du parti APDER, partage ces inquiétudes. Tout en reconnaissant les avancées réalisées depuis 2005, notamment l'organisation de plusieurs élections, il dénonce un recul démocratique et accuse le parti au pouvoir de monopoliser la vie politique. Une analyse que ne partage pas entièrement Jean De Dieu Mutabazi, président du parti RADEBU. Selon lui, la démocratie et le pluralisme politique existent au Burundi, même si leur application demeure imparfaite. Il souligne que le respect intégral des principes démocratiques reste difficile à atteindre, y compris dans d’autres pays. Premier président démocratiquement élu du Burundi, Melchior Ndadaye a été assassiné le 21 octobre 1993, trois mois seulement après son entrée en fonction. Sa mort, accompagnée de celle de plusieurs de ses proches collaborateurs, a précipité le pays dans une période de violences interethniques et de guerre civile. Le conflit a fait des milliers de morts et contraint de nombreux Burundais à l’exil. Trente-trois ans après ces événements, la mémoire de Melchior Ndadaye reste étroitement liée à l’histoire de la démocratie burundaise, tandis que son héritage continue d’alimenter le débat politique national.";

const para = BURUNDI.split(/(?<=\.)\s+/);
const PAGE = `<html><head><title>x</title><script>var p="<p>${"a".repeat(100)}</p>";</script></head><body>
<nav><p>${"Menu du site ".repeat(10)}</p></nav>
<header><p>${"Bandeau d'en-tête du site ".repeat(6)}</p></header>
<article><h1>Titre</h1>
<p>Courte légende.</p>
${para.map((p) => `<p class="x">${p}</p>`).join("\n")}
<p>Lire aussi : un autre article du site à ne surtout pas reprendre dans le texte extrait ici.</p>
<p>Abonnez-vous à notre newsletter pour recevoir toute l'actualité chaque matin dans votre boîte.</p>
</article>
<footer><p>${"Tous droits réservés, mentions légales du site. ".repeat(4)}</p></footer></body></html>`;

describe("lecture du texte d'une page d'article", () => {
  test("seuls les vrais paragraphes de l'article sont gardés (pas de menu, d'en-tête, de pied de page, de script ni de formule de site)", () => {
    const t = extractArticleText(PAGE);
    expect(t).toContain("Melchior Ndadaye");
    expect(t).toContain("Évariste Ndayishimiye");
    expect(t).not.toMatch(/Menu du site|Bandeau|Lire aussi|newsletter|Tous droits|Courte légende/);
    expect(t.length).toBeLessThanOrEqual(3500);
  });
  test("texte trop long : coupé proprement à 3 500 caractères sans mot tronqué", () => {
    const big = `<article>${Array.from({ length: 80 }, (_, i) => `<p>Phrase numéro ${i} qui raconte un fait précis et suffisamment long pour compter.</p>`).join("")}</article>`;
    const t = extractArticleText(big);
    expect(t.length).toBeLessThanOrEqual(3500);
    expect(t).toMatch(/compter\.$/);
  });
  test("liens http (flux Africanews) lus en https ; page refusée, non HTML ou trop courte : chaîne vide, jamais d'exception", async () => {
    const asked: string[] = [];
    const ok = (async (u: string) => { asked.push(u); return { ok: true, url: u, headers: { get: () => "text/html; charset=utf-8" }, text: async () => PAGE }; }) as unknown as typeof fetch;
    expect((await fetchArticleText("http://fr.africanews.com/2026/10/21/burundi/", ok)).length).toBeGreaterThan(1500);
    expect(asked[0]).toBe("https://fr.africanews.com/2026/10/21/burundi/");
    const refused = (async () => ({ ok: false, status: 403, headers: { get: () => "text/html" }, text: async () => "" })) as unknown as typeof fetch;
    expect(await fetchArticleText("https://exemple.fr/a", refused)).toBe("");
    const pdf = (async (u: string) => ({ ok: true, url: u, headers: { get: () => "application/pdf" }, text: async () => PAGE })) as unknown as typeof fetch;
    expect(await fetchArticleText("https://exemple.fr/a", pdf)).toBe("");
    const antiBot = (async (u: string) => ({ ok: true, url: u, headers: { get: () => "text/html" }, text: async () => "<html><body><p>Veuillez patienter.</p></body></html>" })) as unknown as typeof fetch;
    expect(await fetchArticleText("https://exemple.fr/a", antiBot)).toBe("");
    const boom = (async () => { throw new Error("réseau"); }) as unknown as typeof fetch;
    expect(await fetchArticleText("https://exemple.fr/a", boom)).toBe("");
    expect(await fetchArticleText("http://localhost/a", ok)).toBe("");
  });
});

const item = (o: Partial<RawItem> & { titre: string; sourceName: string }): RawItem => ({
  sourceId: "x", lang: "fr", region: "africa", categoryHint: "politique", lien: `https://exemple.fr/${o.sourceName}`, date: "2026-10-21T08:00:00.000Z",
  resume: "Le Burundi a commémoré le 33e anniversaire de l’assassinat de Melchior Ndadaye, premier président démocratiquement élu.", corps: "", image: null, ...o,
});

describe("lecture approfondie", () => {
  const topic = (): Topic => ({
    items: [item({ titre: "Burundi : hommage à Ndadaye", sourceName: "Africanews", lien: "https://a.fr/1" }), item({ titre: "Burundi : on célèbre Ndadaye", sourceName: "Africanews", lien: "https://a.fr/2" }),
      item({ titre: "Burundi : mémoire de Ndadaye", sourceName: "RFI", lien: "https://b.fr/1" }), item({ titre: "Burundi : 21 octobre", sourceName: "Le Monde", lien: "https://c.fr/1" })],
    category: "politique", level: "country", country: "BI", distinctSources: 3, score: 12,
  });
  test("au plus un article par média, 2 médias lus ; le texte de la page remplace l'extrait", async () => {
    const t = topic();
    const asked: string[] = [];
    const n = await deepRead(t, async (u) => { asked.push(u); return BURUNDI; });
    expect(n).toBe(2);
    expect(asked).toEqual(["https://a.fr/1", "https://b.fr/1"]);
    expect(t.items[0].corps).toBe(BURUNDI);
    expect(t.items[2].corps).toBe(BURUNDI);
    expect(t.items[3].corps).toBe("");
  });
  test("page illisible ou pas plus riche que l'extrait : l'extrait du flux est gardé", async () => {
    const t = topic();
    expect(await deepRead(t, async () => "")).toBe(0);
    expect(t.items[0].corps).toBe("");
    t.items[0].corps = BURUNDI;
    expect(await deepRead(t, async () => "Texte plus court que ce que le flux donnait déjà.")).toBe(0);
    expect(t.items[0].corps).toBe(BURUNDI);
  });
  test("le prompt donne à l'IA le texte développé et demande 3 à 4 sections", () => {
    const t = topic();
    t.items[0].corps = BURUNDI;
    const msgs = buildMessages(t, "Burundi", "mercredi 21 octobre 2026");
    const all = msgs.map((m) => m.content).join("\n");
    expect(all).toContain("Gabriel Banzawitonde");
    expect(all).toContain("250 à 550");
    expect(all).toMatch(/3 à 4 objets/);
  });
});

/** Article tel qu'un bon modèle l'écrirait à partir du texte réel : doit passer toutes les vérifications (chiffres, noms, pas de recopie). */
const ARTICLE = {
  titre: "Burundi : hommage à Melchior Ndadaye, 33 ans après son assassinat",
  chapo: "Le Burundi a rendu hommage à Melchior Ndadaye, premier président élu démocratiquement, tué en 1993. Les cérémonies ont relancé le débat sur l'état de la démocratie.",
  sections: [
    { titre: "Une cérémonie à Bujumbura", texte: "Le président Évariste Ndayishimiye s'est recueilli à Bujumbura, au pied du monument consacré aux Héros de la démocratie, pour honorer Melchior Ndadaye et ses proches collaborateurs. Il y a déposé des couronnes de fleurs. Une messe a ensuite été célébrée pour les victimes, puis les familles et les représentants des partis politiques ont à leur tour déposé des gerbes, dans un moment de recueillement partagé." },
    { titre: "Un bilan contrasté de la démocratie", texte: "La commémoration a donné la parole à plusieurs responsables politiques. Olivier Nkurunziza, président de l'UPRONA, estime que la paix ne suffit pas : selon lui, la démocratie doit devenir une réalité, et il met en garde contre un retour au parti unique. Gabriel Banzawitonde, du parti APDER, reconnaît des avancées depuis 2005 mais dénonce un recul et un pouvoir qui monopolise la vie politique." },
    { titre: "Une lecture plus nuancée", texte: "Jean De Dieu Mutabazi, président du parti RADEBU, ne partage pas entièrement ce constat. Pour lui, la démocratie et le pluralisme existent bel et bien au Burundi, même si leur application reste imparfaite. Il rappelle que le respect complet des principes démocratiques est difficile à atteindre, y compris dans d'autres pays, ce qui invite à relativiser les critiques." },
    { titre: "Retour sur un drame fondateur", texte: "Melchior Ndadaye était le premier chef d'État choisi librement par les Burundais. Il a été tué le 21 octobre 1993, soit trois mois à peine après son arrivée au pouvoir. Sa mort et celle de plusieurs de ses proches ont plongé le pays dans des violences interethniques et une guerre civile, qui ont fait des milliers de morts et poussé de nombreux Burundais à l'exil." },
  ],
  retenir: [
    "Le Burundi a commémoré les 33 ans de l'assassinat de Melchior Ndadaye.",
    "Le président Évariste Ndayishimiye a déposé des couronnes de fleurs à Bujumbura.",
    "Les responsables politiques divergent sur l'état de la démocratie.",
    "Ndadaye a été tué en octobre 1993, trois mois après son arrivée au pouvoir.",
  ],
  notif: { titre: "Burundi : 33 ans après Ndadaye", corps: "Hommage à Bujumbura et débat sur l'état de la démocratie." },
};

describe("article de qualité média", () => {
  const ctx = { sourcesText: `Burundi hommage à Ndadaye. ${BURUNDI}`, refs: ["Burundi : hommage à Ndadaye", BURUNDI] };
  test("un article développé de 4 sections (plus de 1 500 caractères) passe toutes les vérifications", () => {
    const len = ARTICLE.sections.reduce((n, s) => n + s.texte.length, 0);
    expect(len).toBeGreaterThan(1500);
    const r = validateSummary(JSON.stringify(ARTICLE), ctx);
    expect(r.ok).toBe(true);
  });
  test("le même article avec un chiffre ou un nom inventé, ou une phrase recopiée de la page, est refusé", () => {
    const withNumber = { ...ARTICLE, retenir: [...ARTICLE.retenir.slice(0, 3), "Plus de 4000 personnes ont assisté à la cérémonie."] };
    expect(validateSummary(JSON.stringify(withNumber), ctx)).toEqual({ ok: false, errors: [expect.stringContaining("chiffre_invente")] });
    const withName = { ...ARTICLE, retenir: [...ARTICLE.retenir.slice(0, 3), "Selon Pierre Nkurunziza, rien ne change vraiment."] };
    const rn = validateSummary(JSON.stringify(withName), ctx);
    expect(rn.ok).toBe(false);
    const copied = { ...ARTICLE, sections: [{ titre: ARTICLE.sections[0].titre, texte: "Premier président démocratiquement élu du Burundi, Melchior Ndadaye a été assassiné le 21 octobre 1993, trois mois seulement après son entrée en fonction, et rien ne l'a empêché. " + ARTICLE.sections[0].texte.slice(0, 120) }, ...ARTICLE.sections.slice(1)] };
    const rc = validateSummary(JSON.stringify(copied), ctx);
    expect(rc.ok).toBe(false);
    if (!rc.ok) expect(rc.errors.join(" ")).toContain("texte_recopie");
  });
});
