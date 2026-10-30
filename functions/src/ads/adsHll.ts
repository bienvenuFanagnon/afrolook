/**
 * Comptage de visiteurs UNIQUES sur de longues périodes (60 jours) sans garder une trace par visiteur : HyperLogLog (précision ≈ 1,6 %).
 * Chaque jour, le travail quotidien résume les visiteurs d'un site dans un petit tableau (4 096 octets) ; l'audience sur 30 ou 60 jours se calcule
 * en fusionnant les tableaux des jours concernés (un visiteur qui revient plusieurs jours n'est compté qu'une fois).
 * L'identifiant de visiteur utilisé est celui de l'empreinte propre à chaque site (visitorHash) : aucune donnée personnelle.
 */
export const HLL_P = 12;
export const HLL_M = 1 << HLL_P; // 4096 registres

export const hllNew = (): Uint8Array => new Uint8Array(HLL_M);

/** Ajoute un identifiant haché (hexadécimal, 8 caractères au moins) au tableau. */
export function hllAdd(regs: Uint8Array, hashHex: string): void {
  const h = hashHex.padEnd(16, "0");
  const x = parseInt(h.slice(0, 8), 16) >>> 0; // 32 bits : les 12 premiers pour le registre, les 20 suivants pour le rang
  const idx = x >>> (32 - HLL_P);
  const rest = ((x << HLL_P) >>> 0) | (parseInt(h.slice(8, 16), 16) >>> (32 - HLL_P)); // complète avec les bits suivants pour éviter un rang trop faible
  let rank = 1;
  let w = rest >>> 0;
  if (w === 0) rank = 32 - HLL_P + 1;
  else { while ((w & 0x80000000) === 0) { rank++; w = (w << 1) >>> 0; } }
  if (rank > regs[idx]) regs[idx] = rank;
}

export function hllMerge(into: Uint8Array, other: Uint8Array): void {
  for (let i = 0; i < HLL_M; i++) if (other[i] > into[i]) into[i] = other[i];
}

export function hllCount(regs: Uint8Array): number {
  const alpha = 0.7213 / (1 + 1.079 / HLL_M);
  let sum = 0, zeros = 0;
  for (let i = 0; i < HLL_M; i++) { sum += Math.pow(2, -regs[i]); if (regs[i] === 0) zeros++; }
  let est = (alpha * HLL_M * HLL_M) / sum;
  if (est <= 2.5 * HLL_M && zeros > 0) est = HLL_M * Math.log(HLL_M / zeros); // petite audience : comptage linéaire
  return Math.round(est);
}

export const hllToB64 = (regs: Uint8Array): string => Buffer.from(regs).toString("base64");
export function hllFromB64(s: unknown): Uint8Array {
  const out = hllNew();
  if (typeof s !== "string" || !s) return out;
  const b = Buffer.from(s, "base64");
  for (let i = 0; i < Math.min(b.length, HLL_M); i++) out[i] = b[i];
  return out;
}

// ─── Comparaison audience mesurée / déclarée ────────────────────────────────────────────────────────────────────────

export type Gap = "no_data" | "conform" | "below" | "far_below" | "above";
export interface AudienceReport {
  declared: number;
  /** personnes différentes sur les 30 derniers jours (tous jours confondus) */ u30: number;
  /** personnes différentes sur les 60 derniers jours */ u60: number;
  /** moyenne de visiteurs différents par jour sur les 7 derniers jours */ perDay7: number;
  /** rapport u30 / audience déclarée (0 à plus de 1) */ ratio: number;
  status: Gap;
  daysWithData: number;
}

/**
 * Compare l'audience mesurée par Afrolook à l'audience déclarée (mensuelle, personnes différentes). Mesurée = personnes pour qui la balise ou le composant a été chargé.
 *  - moins de 7 jours de mesure : pas encore de conclusion ;
 *  - 70 % de la déclarée ou plus : conforme ; 30 à 70 % : en dessous ; moins de 30 % : très en dessous (à examiner) ; plus de 120 % : au-dessus (l'audience retenue peut monter).
 */
export function compareAudience(declared: number, u30: number, u60: number, perDay7: number, daysWithData: number): AudienceReport {
  const dcl = Math.max(0, Math.floor(declared) || 0);
  const ratio = dcl > 0 ? u30 / dcl : 0;
  let status: Gap = "no_data";
  if (daysWithData >= 7 && dcl > 0) status = ratio >= 1.2 ? "above" : ratio >= 0.7 ? "conform" : ratio >= 0.3 ? "below" : "far_below";
  return { declared: dcl, u30, u60, perDay7, ratio: Math.round(ratio * 100) / 100, status, daysWithData };
}
