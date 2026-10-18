import { cleanReply, dayKey, decideReply, REPLY_PER_DAY, ReplyState } from "../replyGate";

const DAY = 24 * 3600 * 1000;
const base: ReplyState = { isFriend: false, pendingOut: false, pendingIn: false, lastRefusedAt: 0, sentToday: 0, blocked: false, now: 1_800_000_000_000 };

describe("decideReply", () => {
  it("envoie l'invitation quand rien ne l'empêche", () => {
    expect(decideReply(base)).toEqual({ kind: "send" });
  });
  it("déjà amis : la discussion s'ouvre, aucune invitation", () => {
    expect(decideReply({ ...base, isFriend: true }).kind).toBe("friends");
  });
  it("invitation déjà en attente : aucun nouveau message", () => {
    expect(decideReply({ ...base, pendingOut: true }).kind).toBe("pending");
  });
  it("la personne m'a déjà invité : j'accepte plutôt que d'inviter", () => {
    expect(decideReply({ ...base, pendingIn: true }).kind).toBe("incoming");
  });
  it("blocage : refus, même si amis ou invitation en attente", () => {
    expect(decideReply({ ...base, blocked: true, isFriend: true }).kind).toBe("blocked");
  });
  it("après un refus : 7 jours d'attente, puis c'est permis", () => {
    const d = decideReply({ ...base, lastRefusedAt: base.now - 2 * DAY });
    expect(d).toEqual({ kind: "cooldown", daysLeft: 5 });
    expect(decideReply({ ...base, lastRefusedAt: base.now - 8 * DAY }).kind).toBe("send");
  });
  it("plafond de 10 invitations par jour", () => {
    expect(decideReply({ ...base, sentToday: REPLY_PER_DAY - 1 }).kind).toBe("send");
    expect(decideReply({ ...base, sentToday: REPLY_PER_DAY }).kind).toBe("limit");
  });
});

describe("cleanReply", () => {
  it("nettoie les espaces et refuse le vide ou le trop long", () => {
    expect(cleanReply("  Bonjour   Kofi \n ")).toBe("Bonjour Kofi");
    expect(cleanReply("   ")).toBeNull();
    expect(cleanReply(42)).toBeNull();
    expect(cleanReply("a".repeat(200))).toHaveLength(200);
    expect(cleanReply("a".repeat(201))).toBeNull();
  });
});

describe("dayKey", () => {
  it("clé du jour en UTC", () => {
    expect(dayKey(Date.UTC(2026, 9, 18, 23, 59))).toBe("20261018");
  });
});
