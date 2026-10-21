/**
 * Règles pures de l'envoi des notifications push (sans accès à Firebase ni au réseau : testables telles quelles).
 * Utilisées par shared/push.ts.
 */

/** Identifiant d'abonné OneSignal (UUID). OneSignal rejette tout le lot dès qu'un seul identifiant est mal formé. */
export const ONESIGNAL_ID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Découpe une liste en lots de taille donnée. */
export function chunk<T>(list: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

/** FCM n'accepte que des valeurs texte dans `data` : tout est converti, les valeurs vides ou absentes sont retirées. */
export function stringifyData(data?: Record<string, unknown>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(data ?? {})) {
    if (v === undefined || v === null) continue;
    out[k] = typeof v === "string" ? v : typeof v === "object" ? JSON.stringify(v) : String(v);
  }
  return out;
}

/** Jetons FCM d'un profil (tableau `fcmTokens`) : uniquement des textes non vides, sans doublon. */
export function tokensOf(userData: Record<string, unknown> | undefined): string[] {
  const raw = userData?.["fcmTokens"];
  if (!Array.isArray(raw)) return [];
  return [...new Set(raw.filter((t): t is string => typeof t === "string" && t.length > 20))];
}

/** Code d'erreur FCM signifiant que le jeton ne sert plus (application désinstallée, jeton renouvelé) : à supprimer du profil. */
export function isDeadTokenCode(code?: string): boolean {
  return code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token" ||
    code === "messaging/invalid-argument";
}

/**
 * La réponse de OneSignal indique-t-elle un quota ou un abonnement épuisé ? (alors inutile de réessayer avant plusieurs heures :
 * on ouvre le coupe-circuit au lieu de multiplier les appels qui échouent).
 */
export function isQuotaError(status?: number, body?: unknown): boolean {
  if (status === 402 || status === 429) return true;
  if (status !== 400 && status !== 403) return false;
  let text = "";
  try {
    text = (typeof body === "string" ? body : JSON.stringify(body ?? "")).toLowerCase();
  } catch {
    return false;
  }
  return /quota|exceeded|billing|payment|subscription|upgrade|monthly|over the limit|limit reached/.test(text);
}
