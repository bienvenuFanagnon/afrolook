import {
  DAILY_BUDGET, SOCIAL_MAX, categoryOf, categoryOfData, chooseReminder, consume, copyFor, daysInactive, decide, inQuietHours, localDay, localMinutes,
  reminderGapMs, tzForSlot, typeNotifFor, SLOTS_MIN,
} from "../policy_logic";

const H = 3600 * 1000;
// 2026-10-21 12:00 UTC (mercredi)
const NOON = Date.UTC(2026, 9, 21, 12, 0, 0);

describe("catégories", () => {
  test("messages et événements importants sont directs, le reste est social", () => {
    expect(categoryOf("MESSAGE")).toBe("direct");
    expect(categoryOf("COMPTE_OFFICIEL")).toBe("direct");
    expect(categoryOf("WEEKLY_REWARD")).toBe("direct");
    expect(categoryOf("LIKE")).toBe("social");
    expect(categoryOf("POST")).toBe("social");
    expect(categoryOf("MUSIC")).toBe("social");
    expect(categoryOf("RAPPEL_QUIZ")).toBe("reminder");
    expect(categoryOf(undefined)).toBe("direct");
    expect(categoryOfData({ type: "streak_reminder" })).toBe("reminder");
    expect(categoryOfData({ type_notif: "COMMENT" })).toBe("social");
  });
});

describe("heure locale et heures calmes", () => {
  test("localMinutes / localDay tiennent compte du fuseau", () => {
    expect(localMinutes(NOON, 0)).toBe(12 * 60);
    expect(localMinutes(NOON, 60)).toBe(13 * 60);
    expect(localMinutes(NOON, -300)).toBe(7 * 60);
    expect(localDay(Date.UTC(2026, 9, 21, 23, 30), 60)).toBe("2026-10-22");
  });
  test("22 h – 7 h 30 sont calmes", () => {
    expect(inQuietHours(Date.UTC(2026, 9, 21, 22, 0), 0)).toBe(true);
    expect(inQuietHours(Date.UTC(2026, 9, 21, 3, 0), 0)).toBe(true);
    expect(inQuietHours(Date.UTC(2026, 9, 21, 7, 29), 0)).toBe(true);
    expect(inQuietHours(Date.UTC(2026, 9, 21, 7, 30), 0)).toBe(false);
    expect(inQuietHours(Date.UTC(2026, 9, 21, 21, 59), 0)).toBe(false);
    expect(inQuietHours(Date.UTC(2026, 9, 21, 21, 30), 60)).toBe(true); // 22 h 30 à UTC+1
  });
});

describe("décision d'envoi", () => {
  test("un message direct passe toujours, même la nuit, budget épuisé ou préférences coupées", () => {
    const night = Date.UTC(2026, 9, 21, 2, 0);
    expect(decide("direct", { nowMs: night, prefs: { activity: false, reminders: false }, budget: { day: "2026-10-21", count: 99, social: 99 } }).allow).toBe(true);
  });
  test("social : bloqué la nuit, par les préférences et par son plafond", () => {
    expect(decide("social", { nowMs: NOON }).allow).toBe(true);
    expect(decide("social", { nowMs: Date.UTC(2026, 9, 21, 23, 0) })).toEqual({ allow: false, reason: "quiet" });
    expect(decide("social", { nowMs: NOON, prefs: { activity: false } })).toEqual({ allow: false, reason: "prefs" });
    const b = { day: "2026-10-21", count: SOCIAL_MAX, social: SOCIAL_MAX, lastReminderAt: 0 };
    expect(decide("social", { nowMs: NOON, budget: b })).toEqual({ allow: false, reason: "budget" });
    // il reste de la place pour un rappel quand le social a atteint son plafond
    expect(decide("reminder", { nowMs: NOON, budget: b }).allow).toBe(true);
  });
  test("le budget du jour se remet à zéro le lendemain", () => {
    const yesterday = { day: "2026-10-20", count: DAILY_BUDGET, social: SOCIAL_MAX, lastReminderAt: 0 };
    expect(decide("social", { nowMs: NOON, budget: yesterday }).allow).toBe(true);
  });
  test("rappel : pas si la personne est active, ni trop près d'un autre rappel, ni budget plein", () => {
    expect(decide("reminder", { nowMs: NOON, lastActiveMs: NOON - 30 * 60000 })).toEqual({ allow: false, reason: "active" });
    expect(decide("reminder", { nowMs: NOON, lastActiveMs: NOON - 5 * H }).allow).toBe(true);
    expect(decide("reminder", { nowMs: NOON, budget: { day: "2026-10-21", count: 0, social: 0, lastReminderAt: NOON - H } })).toEqual({ allow: false, reason: "gap" });
    expect(decide("reminder", { nowMs: NOON, budget: { day: "2026-10-21", count: DAILY_BUDGET, social: 0, lastReminderAt: 0 } })).toEqual({ allow: false, reason: "budget" });
    expect(decide("reminder", { nowMs: NOON, prefs: { reminders: false } })).toEqual({ allow: false, reason: "prefs" });
  });
  test("consume compte les envois", () => {
    let b = consume("social", undefined, NOON);
    expect(b).toMatchObject({ count: 1, social: 1 });
    b = consume("reminder", b, NOON);
    expect(b).toMatchObject({ count: 2, social: 1, lastReminderAt: NOON });
    expect(consume("direct", b, NOON)).toMatchObject({ count: 2 });
  });
});

describe("paliers d'inactivité", () => {
  test("écart croissant puis arrêt à 90 jours", () => {
    expect(reminderGapMs(0)).toBe(0);
    expect(reminderGapMs(5)).toBe(20 * H);
    expect(reminderGapMs(20)).toBe(44 * H);
    expect(reminderGapMs(60)).toBe(164 * H);
    expect(reminderGapMs(120)).toBe(Infinity);
  });
  test("daysInactive", () => {
    expect(daysInactive(NOON, NOON - 3 * 86400000 - 1000)).toBe(3);
    expect(daysInactive(NOON, undefined)).toBe(0);
  });
});

describe("choix du contenu", () => {
  const base = { dayIndex: 100, streak: 0, streakDoneToday: true, unseenPosts: 0, daysInactive: 0 };
  test("quiz, étude et conte tournent : les trois créneaux d'un jour sont différents", () => {
    const kinds = [0, 1, 2].map((slot) => chooseReminder({ ...base, slot }));
    expect(new Set(kinds).size).toBe(3);
    expect(kinds.every((k) => ["quiz", "etude", "conte"].includes(k))).toBe(true);
  });
  test("nouveaux posts avant le quiz le matin et le soir, pas à midi", () => {
    expect(chooseReminder({ ...base, slot: 0, unseenPosts: 4 })).toBe("feed");
    expect(chooseReminder({ ...base, slot: 2, unseenPosts: 4 })).toBe("feed");
    expect(["quiz", "etude", "conte"]).toContain(chooseReminder({ ...base, slot: 1, unseenPosts: 4 }));
  });
  test("retour pour un inactif depuis 7 jours, à midi", () => {
    expect(chooseReminder({ ...base, slot: 1, daysInactive: 8 })).toBe("comeback");
  });
  test("textes et ouverture directe", () => {
    expect(copyFor("quiz", 0).title.length).toBeGreaterThan(5);
    expect(copyFor("feed", 1, 0, 12).body).toContain("9+");
    expect(copyFor("streak", 0, 7).title).toContain("7");
    expect(typeNotifFor("conte")).toBe("RAPPEL_CONTE");
    expect(categoryOf(typeNotifFor("etude"))).toBe("reminder");
  });
});

describe("créneaux", () => {
  test("tzForSlot : le fuseau dont l'heure locale tombe sur le créneau maintenant", () => {
    // 8 h 30 locale quand il est 7 h 30 UTC → UTC+1
    expect(tzForSlot(Date.UTC(2026, 9, 21, 7, 30), SLOTS_MIN[0])).toBe(60);
    // 13 h 00 locale à 13 h 00 UTC → UTC+0 (Togo)
    expect(tzForSlot(Date.UTC(2026, 9, 21, 13, 0), SLOTS_MIN[1])).toBe(0);
    // 19 h 30 locale à 22 h 30 UTC → UTC-3
    expect(tzForSlot(Date.UTC(2026, 9, 21, 22, 30), SLOTS_MIN[2])).toBe(-180);
  });
});
