import { db } from "../shared/firebase";
import { AudienceReport, compareAudience, hllCount, hllFromB64, hllMerge, hllNew } from "./adsHll";
import { declaredShare } from "./adsTargeting";

/**
 * Audience MESURÉE d'un site ou d'une application sur 60 jours (jours complets), comparée à l'audience déclarée.
 * Sources : AdsHll/{pub}_{jour} (visiteurs différents du jour, résumé compact écrit chaque nuit) et AdsPubDaily/{pub}_{jour} (affichages valides, trafic invalide,
 * clics, appels depuis un autre domaine).
 */
export const dayStr = (t: number): string => new Date(t).toISOString().slice(0, 10);

export interface DayPoint { day: string; uniques: number; valid: number; invalid: number; clicks: number; foreign: number }
export interface Measure {
  report: AudienceReport;
  series: DayPoint[]; // du plus ancien au plus récent
  totals: { impressions60: number; invalid60: number; foreign60: number; clicks60: number; invalidRate: number };
  /** d'où viennent les visiteurs (30 derniers jours) : pays, nombre de visiteurs-jours, part */ geo: Array<{ cc: string; n: number; share: number }>;
  /** part des visiteurs venant des pays annoncés par le diffuseur (null si aucun pays annoncé) */ declaredGeo: { share: number; total: number } | null;
}

export async function measure(pub: string, declared: number, days = 60, now = Date.now(), declaredCountries: string[] = []): Promise<Measure> {
  const list = Array.from({ length: days }, (_, i) => dayStr(now - (i + 1) * 86_400_000)); // hier, avant-hier, …
  const [hs, ps] = await Promise.all([
    db.getAll(...list.map((d) => db.collection("AdsHll").doc(`${pub}_${d}`))),
    db.getAll(...list.map((d) => db.collection("AdsPubDaily").doc(`${pub}_${d}`))),
  ]);
  const m30 = hllNew(), m60 = hllNew();
  const series: DayPoint[] = [];
  let sum7 = 0, n7 = 0, withData = 0, valid = 0, invalid = 0, foreign = 0, clicks = 0;
  const geo30: Record<string, number> = {};
  list.forEach((day, i) => {
    const h = hs[i].data(), p = ps[i].data();
    if (h) { const r = hllFromB64(h["regs"]); hllMerge(m60, r); if (i < 30) hllMerge(m30, r); withData++; if (i < 7) { sum7 += Number(h["n"]) || 0; n7++; } if (i < 30) for (const [cc, n] of Object.entries((h["geo"] ?? {}) as Record<string, number>)) geo30[cc] = (geo30[cc] ?? 0) + (Number(n) || 0); }
    const v = Number(p?.["valid"]) || 0, bad = Number(p?.["invalid"]) || 0, c = Number(p?.["clicks"]) || 0, f = Number(p?.["foreign"]) || 0;
    valid += v; invalid += bad; clicks += c; foreign += f;
    series.push({ day, uniques: Number(h?.["n"]) || 0, valid: v, invalid: bad, clicks: c, foreign: f });
  });
  series.reverse();
  const report = compareAudience(declared, hllCount(m30), hllCount(m60), n7 ? Math.round(sum7 / n7) : 0, withData);
  const tot = valid + invalid;
  const gtot = Object.values(geo30).reduce((a, b) => a + b, 0);
  const geo = Object.entries(geo30).sort((a, b) => b[1] - a[1]).slice(0, 8).map(([cc, n]) => ({ cc, n, share: gtot ? Math.round((n / gtot) * 1000) / 1000 : 0 }));
  return { geo, declaredGeo: declaredCountries.length ? declaredShare(geo30, declaredCountries) : null, report, series, totals: { impressions60: valid, invalid60: invalid, foreign60: foreign, clicks60: clicks, invalidRate: tot ? Math.round((invalid / tot) * 1000) / 1000 : 0 } };
}

/** Résumé gardé sur la fiche du site (liste d'administration sans relire 60 jours à chaque ouverture). */
export const summaryOf = (m: Measure): Record<string, unknown> => ({
  u30: m.report.u30, u60: m.report.u60, perDay7: m.report.perDay7, ratio: m.report.ratio, status: m.report.status, daysWithData: m.report.daysWithData,
  impressions60: m.totals.impressions60, invalid60: m.totals.invalid60, foreign60: m.totals.foreign60, invalidRate: m.totals.invalidRate,
  geo: m.geo.slice(0, 5), inDeclared: m.declaredGeo ? m.declaredGeo.share : null, geoFlag: !!m.declaredGeo && m.declaredGeo.total >= 200 && m.declaredGeo.share < 0.6, at: Date.now(),
});
