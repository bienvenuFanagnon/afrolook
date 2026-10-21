import { COUNTRY_KEYWORDS, strip } from "./cluster";

/**
 * Garde-fous d'un résumé écrit par l'IA (portés de PronoFlash) : il n'est publié que s'il passe TOUTES ces vérifications.
 *  - JSON conforme, tailles raisonnables, français ;
 *  - aucun chiffre qui ne figure pas dans les sources ;
 *  - aucun nom propre (personne, lieu, organisation) qui ne figure pas dans les sources ;
 *  - aucune reprise mot pour mot d'un titre ou d'un extrait (8 mots d'affilée) : on reformule, on ne recopie pas ;
 *  - aucune promesse ni formule racoleuse.
 */
export interface SummaryOut {
  titre: string;
  chapo: string;
  sections: Array<{ titre: string; texte: string }>;
  retenir: string[];
  notif: { titre: string; corps: string };
}

const MONTHS_DAYS = /^(?:lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre|afrolook)$/i;
const WORD = /\p{Lu}[\p{L}'’-]{3,}/gu;
const FR_WORDS = /(?<!\p{L})(?:le|la|les|un|une|des|de|du|et|en|à|au|aux|est|sont|avec|pour|sur|dans|qui|que|ne|pas|plus|se|son|sa|ses|ont|a)(?!\p{L})/giu;
const EN_WORDS = /(?<!\p{L})(?:the|and|with|their|have|has|are|is|will|this|that|from|of|to|in|a|an|at|for|by)(?!\p{L})/giu;
const CLICKBAIT = /(?<!\p{L})(?:incroyable|choquant|vous n'?allez pas croire|exclusif|scandale|bombe|urgent)(?!\p{L})/giu;

/**
 * Noms de lieux qu'une source en anglais ne peut pas contenir sous cette forme : l'IA traduit « South Africa » en « Afrique du Sud ». Les pays et leurs
 * capitales (tous ceux que connaît cluster.ts), les continents et les points cardinaux ne sont donc jamais pris pour des noms inventés.
 */
const GEO_ALLOW = new Set<string>([
  ...Object.values(COUNTRY_KEYWORDS).flat().flatMap((k) => k.split(" ")),
  "afrique", "europe", "asie", "amerique", "oceanie", "orient", "occident", "nord", "sud", "est", "ouest", "etats", "unis", "royaume", "uni", "cap", "vert",
  "oriental", "orientale", "occidental", "occidentale", "central", "centrale", "septentrional", "meridional",
  "ivoire", "cote", "sao", "tome", "principe", "leone", "sierra", "bissau", "equatoriale", "centrafricaine", "democratique", "republique", "congo",
]);

/** Premier objet JSON d'un texte (tolère les balises ```json). */
export function extractJson(raw: unknown): Record<string, unknown> | null {
  if (raw && typeof raw === "object") return raw as Record<string, unknown>;
  let s = String(raw ?? "").trim();
  s = s.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/i, "").trim();
  const a = s.indexOf("{");
  const b = s.lastIndexOf("}");
  if (a < 0 || b <= a) return null;
  try { return JSON.parse(s.slice(a, b + 1)) as Record<string, unknown>; } catch { return null; }
}

const numbersIn = (t: string) => [...String(t).matchAll(/\d+(?:[.,]\d+)?/g)].map((m) => ({ raw: m[0], v: parseFloat(m[0].replace(",", ".")), idx: m.index ?? 0 }));

/** Nombres refusés : un nombre du texte est accepté s'il figure dans les sources, ou s'il s'agit d'un petit entier (jusqu'à 20) ou d'une année. */
export function inventedNumbers(out: string, sourcesText: string): string[] {
  const allowed = new Set(numbersIn(sourcesText).map((n) => n.v));
  const bad: string[] = [];
  for (const n of numbersIn(out)) {
    if (allowed.has(n.v)) continue;
    const isPct = /^\s*%/.test(out.slice(n.idx + n.raw.length, n.idx + n.raw.length + 3));
    const isDecimal = /[.,]/.test(n.raw);
    if (n.v >= 1990 && n.v <= 2100) continue;
    if (!isPct && !isDecimal && n.v <= 20) continue;
    bad.push(n.raw);
  }
  return bad;
}

/** Noms propres du texte (mots en majuscule qui ne commencent pas une phrase) absents des sources. */
export function unknownNames(out: string, corpusNorm: string, allow?: Set<string>): string[] {
  const bad: string[] = [];
  for (const m of out.matchAll(WORD)) {
    const idx = m.index ?? 0;
    const before = out.slice(0, idx).replace(/[\s«“"(\[]+$/u, "");
    if (!before.length || /[.!?…:;—–-]$/.test(before)) continue; // début de phrase : la majuscule est normale
    const w = m[0].replace(/['’-]+$/, "");
    if (MONTHS_DAYS.test(w)) continue;
    const parts = w.split(/['’-]/).filter((x) => x.length >= 3);
    if (parts.every((p) => corpusNorm.includes(strip(p)) || (allow?.has(strip(p)) ?? false))) continue;
    bad.push(w);
  }
  return bad;
}

/** Formule racoleuse absente des sources (un mot comme « scandale » est légitime quand la source le dit). */
export function clickbait(out: string, corpusNorm: string): boolean {
  for (const m of out.matchAll(CLICKBAIT)) if (!corpusNorm.includes(strip(m[0]))) return true;
  return false;
}

/** Titre ramené à 130 caractères au plus, coupé entre deux mots : un titre un peu long n'est pas une raison de refuser un résumé. */
export function fitTitle(t: string, max = 130): string {
  if (t.length <= max) return t;
  const cut = t.slice(0, max);
  return cut.slice(0, Math.max(cut.lastIndexOf(" "), max - 25)).replace(/[\s,;:.\-–—]+$/, "");
}

/** Première suite de `n` mots identique entre le texte et l'un des textes de référence (titres, extraits), sinon null. */
export function copiedRun(out: string, refs: string[], n = 8): string | null {
  const words = (s: string) => strip(s).split(" ").filter(Boolean);
  const ow = words(out);
  const grams = new Set<string>();
  for (const r of refs) { const w = words(r); for (let i = 0; i + n <= w.length; i++) grams.add(w.slice(i, i + n).join(" ")); }
  for (let i = 0; i + n <= ow.length; i++) if (grams.has(ow.slice(i, i + n).join(" "))) return ow.slice(i, i + n).join(" ");
  return null;
}

const str = (v: unknown, min: number, max: number): boolean => typeof v === "string" && v.trim().length >= min && v.trim().length <= max;

/** `raw` : réponse brute de l'IA ; `ctx` : textes des sources (pour les chiffres et les noms) et références à ne pas recopier. */
export function validateSummary(raw: unknown, ctx: { sourcesText: string; refs: string[] }): { ok: true; value: SummaryOut } | { ok: false; errors: string[] } {
  const errors: string[] = [];
  const j = extractJson(raw);
  if (!j) return { ok: false, errors: ["json_invalide"] };
  const titre = typeof j["titre"] === "string" ? fitTitle(j["titre"].trim()) : "";
  const chapo = typeof j["chapo"] === "string" ? j["chapo"].trim() : "";
  const sections = (Array.isArray(j["sections"]) ? j["sections"] : []).filter((s) => s && typeof s === "object")
    .map((s) => ({ titre: String((s as Record<string, unknown>)["titre"] ?? "").trim(), texte: String((s as Record<string, unknown>)["texte"] ?? "").trim() }));
  const retenir = (Array.isArray(j["retenir"]) ? j["retenir"] : []).filter((x) => typeof x === "string").map((x) => String(x).trim()).filter(Boolean);
  const notifRaw = (j["notif"] && typeof j["notif"] === "object" ? j["notif"] : null) as Record<string, unknown> | null;
  const notif = notifRaw ? { titre: String(notifRaw["titre"] ?? "").trim(), corps: String(notifRaw["corps"] ?? "").trim() } : null;

  if (!str(titre, 25, 130)) errors.push("titre_longueur");
  if (!str(chapo, 60, 300)) errors.push("chapo_longueur");
  if (sections.length < 2 || sections.length > 4) errors.push("sections_nombre");
  if (sections.some((s) => !str(s.titre, 3, 70) || !str(s.texte, 120, 750))) errors.push("section_longueur");
  if (retenir.length < 3) errors.push("retenir_nombre");
  if (retenir.some((x) => x.length > 160)) errors.push("retenir_longueur");
  if (!notif || !str(notif.titre, 8, 60) || !str(notif.corps, 20, 120)) errors.push("notif_longueur");
  if (errors.length || !notif) return { ok: false, errors };

  const all = [titre, chapo, ...sections.flatMap((s) => [s.titre, s.texte]), ...retenir, notif.titre, notif.corps].join(" . ");
  const fr = (all.match(FR_WORDS) ?? []).length;
  const en = (all.match(EN_WORDS) ?? []).length;
  if (fr < 20 || en > fr / 2) errors.push("pas_en_francais");
  const corpusNorm = ` ${strip(ctx.sourcesText)} `;
  if (clickbait(all, corpusNorm)) errors.push("formule_racoleuse");
  const nums = inventedNumbers(all, ctx.sourcesText);
  if (nums.length) errors.push("chiffre_invente:" + nums.slice(0, 3).join(","));
  const names = unknownNames(all, corpusNorm, GEO_ALLOW);
  if (names.length) errors.push("nom_invente:" + names.slice(0, 3).join(","));
  const copy = copiedRun(all, ctx.refs, 10); // 10 mots d'affilée : une info d'une seule ligne se résume souvent avec quelques mots communs
  if (copy) errors.push("texte_recopie:" + copy);
  if (errors.length) return { ok: false, errors };
  return { ok: true, value: { titre, chapo, sections, retenir: retenir.slice(0, 4), notif } };
}
