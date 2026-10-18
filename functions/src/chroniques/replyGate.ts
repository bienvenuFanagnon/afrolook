/**
 * Règles de la réponse privée à une chronique : le premier message est une invitation, on n'écrit à personne qui n'a pas accepté.
 * Fonction pure (testable) : le serveur lui donne l'état lu dans Firestore.
 */
export const REPLY_MAX_CHARS = 200;
export const REPLY_PER_DAY = 10;
export const REFUSAL_COOLDOWN_DAYS = 7;
const DAY_MS = 24 * 3600 * 1000;

export interface ReplyState {
  isFriend: boolean;
  /** Invitation de moi vers elle, en attente. */
  pendingOut: boolean;
  /** Invitation d'elle vers moi, en attente. */
  pendingIn: boolean;
  /** Date (ms) du dernier refus d'une invitation de moi vers elle, 0 si aucun. */
  lastRefusedAt: number;
  /** Invitations avec message déjà envoyées aujourd'hui par moi. */
  sentToday: number;
  blocked: boolean;
  now: number;
}

export type ReplyDecision =
  | { kind: "send" }
  | { kind: "friends" }
  | { kind: "pending" }
  | { kind: "incoming" }
  | { kind: "blocked" }
  | { kind: "cooldown"; daysLeft: number }
  | { kind: "limit" };

export function decideReply(s: ReplyState): ReplyDecision {
  if (s.blocked) return { kind: "blocked" };
  if (s.isFriend) return { kind: "friends" };
  if (s.pendingOut) return { kind: "pending" };
  if (s.pendingIn) return { kind: "incoming" };
  if (s.lastRefusedAt > 0) {
    const left = s.lastRefusedAt + REFUSAL_COOLDOWN_DAYS * DAY_MS - s.now;
    if (left > 0) return { kind: "cooldown", daysLeft: Math.ceil(left / DAY_MS) };
  }
  if (s.sentToday >= REPLY_PER_DAY) return { kind: "limit" };
  return { kind: "send" };
}

/** Message nettoyé (espaces), ou null s'il est vide ou trop long. */
export function cleanReply(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const t = raw.replace(/\s+/g, " ").trim();
  if (t.length < 1 || t.length > REPLY_MAX_CHARS) return null;
  return t;
}

export const dayKey = (ms: number) => new Date(ms).toISOString().slice(0, 10).replace(/-/g, "");
