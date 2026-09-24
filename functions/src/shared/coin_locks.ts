import { createHash } from "crypto";

/**
 * Pièces achetées (Apple, Mobile Money, bonus) = non convertibles en argent.
 * Seules les pièces gagnées (cadeaux, likes, récompenses, gains de DÉFI) peuvent être
 * converties puis retirées.
 *
 * Modèle : lockedCoins = pièces achetées restantes au moment du dernier achat,
 * lockedCoinsSpentBaseline = totalGiftCoinsSpent à ce moment. Toute dépense ultérieure
 * (qui incrémente totalGiftCoinsSpent) consomme d'abord les pièces achetées.
 * Les utilisateurs sans ces champs n'ont aucune pièce verrouillée : leurs pièces
 * existantes restent convertibles.
 */
function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

export function effectiveLockedCoins(user: FirebaseFirestore.DocumentData | undefined): number {
  if (!user) return 0;
  const locked = num(user["lockedCoins"]);
  if (locked <= 0) return 0;
  const spentSinceLock = Math.max(0, num(user["totalGiftCoinsSpent"]) - num(user["lockedCoinsSpentBaseline"]));
  return Math.max(0, Math.min(num(user["giftCoinsBalance"]), locked - spentSinceLock));
}

export function convertibleCoins(user: FirebaseFirestore.DocumentData | undefined): number {
  if (!user) return 0;
  return Math.max(0, Math.floor(num(user["giftCoinsBalance"]) - effectiveLockedCoins(user)));
}

/** Champs à écrire quand des pièces achetées sont ajoutées (delta > 0) ou retirées (delta < 0). */
export function lockFieldsAfterChange(
  user: FirebaseFirestore.DocumentData | undefined,
  delta: number,
): { lockedCoins: number; lockedCoinsSpentBaseline: number } {
  return {
    lockedCoins: Math.max(0, effectiveLockedCoins(user) + delta),
    lockedCoinsSpentBaseline: num(user?.["totalGiftCoinsSpent"]),
  };
}

/**
 * UUID v5 (RFC 4122, espace de noms URL) dérivé de l'uid Afrolook, passé à Apple comme
 * appAccountToken : lie chaque achat au compte qui l'a fait. Doit produire exactement la
 * même valeur que Uuid().v5(Namespace.url.value, 'afrolook:<uid>') côté Flutter.
 */
export function appAccountTokenFor(uid: string): string {
  const ns = Buffer.from("6ba7b8119dad11d180b400c04fd430c8", "hex");
  const hash = createHash("sha1").update(Buffer.concat([ns, Buffer.from(`afrolook:${uid}`, "utf8")])).digest();
  const b = Buffer.from(hash.subarray(0, 16));
  b[6] = (b[6] & 0x0f) | 0x50;
  b[8] = (b[8] & 0x3f) | 0x80;
  const h = b.toString("hex");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}
