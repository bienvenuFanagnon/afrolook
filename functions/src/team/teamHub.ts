import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const db = () => getFirestore();

// Widgets disponibles
const ALL_WIDGETS = ["stats_inscriptions"] as const;
type WidgetId = (typeof ALL_WIDGETS)[number];

// ─── Helpers ────────────────────────────────────────────────────────────────

function startOfDay(d: Date) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

function fmt(d: Date, mode: "day" | "month") {
  if (mode === "month") {
    return d.toLocaleDateString("fr-FR", { month: "short", year: "2-digit" });
  }
  return d.toLocaleDateString("fr-FR", { weekday: "short", day: "numeric" });
}

async function countUsers(from: number, to: number): Promise<number> {
  const snap = await db()
    .collection("Users")
    .where("createdAt", ">=", from)
    .where("createdAt", "<=", to)
    .count()
    .get();
  return snap.data().count;
}

// ─── Calcul stats inscriptions ───────────────────────────────────────────────

async function buildInscriptionStats(period: string) {
  const now = new Date();
  const points: { label: string; count: number }[] = [];

  if (period === "today") {
    const dayStart = startOfDay(now);
    // 24 tranches horaires
    const tasks = Array.from({ length: 24 }, (_, h) => {
      const from = dayStart + h * 3600000;
      const to = from + 3599999;
      return countUsers(from, Math.min(to, now.getTime())).then((c) => ({
        label: `${h}h`,
        count: c,
      }));
    });
    points.push(...(await Promise.all(tasks)));
    const total = points.reduce((s, p) => s + p.count, 0);
    return { period, points, total };
  }

  if (period === "yesterday") {
    const yDay = new Date(now.getTime() - 86400000);
    const dayStart = startOfDay(yDay);
    const tasks = Array.from({ length: 24 }, (_, h) => {
      const from = dayStart + h * 3600000;
      const to = from + 3599999;
      return countUsers(from, to).then((c) => ({ label: `${h}h`, count: c }));
    });
    points.push(...(await Promise.all(tasks)));
    const total = points.reduce((s, p) => s + p.count, 0);
    return { period, points, total };
  }

  if (period === "week") {
    // 7 jours (aujourd'hui inclus)
    const tasks = Array.from({ length: 7 }, (_, i) => {
      const d = new Date(now.getTime() - (6 - i) * 86400000);
      const from = startOfDay(d);
      const to = from + 86399999;
      return countUsers(from, Math.min(to, now.getTime())).then((c) => ({
        label: fmt(d, "day"),
        count: c,
      }));
    });
    points.push(...(await Promise.all(tasks)));
    const total = points.reduce((s, p) => s + p.count, 0);
    return { period, points, total };
  }

  if (period === "month") {
    // Ce mois-ci, groupé par semaine
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    const weeks: { from: number; to: number; label: string }[] = [];
    for (let day = 1; day <= daysInMonth; day += 7) {
      const from = monthStart + (day - 1) * 86400000;
      const endDay = Math.min(day + 6, daysInMonth);
      const to = monthStart + (endDay - 1) * 86400000 + 86399999;
      weeks.push({ from, to: Math.min(to, now.getTime()), label: `${day}-${endDay}` });
    }
    const tasks = weeks.map((w) =>
      countUsers(w.from, w.to).then((c) => ({ label: w.label, count: c }))
    );
    points.push(...(await Promise.all(tasks)));
    const total = points.reduce((s, p) => s + p.count, 0);
    return { period, points, total };
  }

  // 3, 6, 12 mois → groupé par mois
  const monthsMap: Record<string, number> = {
    "3months": 3,
    "6months": 6,
    "12months": 12,
  };
  const nMonths = monthsMap[period] ?? 3;
  const tasks = Array.from({ length: nMonths }, (_, i) => {
    const idx = nMonths - 1 - i;
    const d = new Date(now.getFullYear(), now.getMonth() - idx, 1);
    const from = d.getTime();
    const to = new Date(d.getFullYear(), d.getMonth() + 1, 0, 23, 59, 59, 999).getTime();
    return countUsers(from, Math.min(to, now.getTime())).then((c) => ({
      label: fmt(d, "month"),
      count: c,
    }));
  });
  points.push(...(await Promise.all(tasks)));
  const total = points.reduce((s, p) => s + p.count, 0);
  return { period, points, total };
}

// ─── CF publiques (appelées par l'app) ───────────────────────────────────────

export const getTeamHubData = onCall(
  { timeoutSeconds: 30, region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "auth_required");

    const memberSnap = await db().collection("TeamMembers").doc(uid).get();
    if (!memberSnap.exists) throw new HttpsError("permission-denied", "not_a_member");

    const member = memberSnap.data()!;
    const profileId: string = member.profileId;
    const profileSnap = await db().collection("TeamProfiles").doc(profileId).get();
    if (!profileSnap.exists) throw new HttpsError("not-found", "profile_not_found");

    const profile = profileSnap.data()!;
    const widgets: WidgetId[] = (profile.widgets || []) as WidgetId[];
    const period: string = (request.data as any)?.period || "week";

    const result: Record<string, unknown> = {};

    if (widgets.includes("stats_inscriptions")) {
      result.stats_inscriptions = await buildInscriptionStats(period);
    }

    return {
      profile: { name: profile.name, widgets },
      widgets: result,
    };
  }
);

// ─── CF admin : gestion des profils ─────────────────────────────────────────

async function assertAdmin(uid: string | undefined) {
  if (!uid) throw new HttpsError("unauthenticated", "auth_required");
  const snap = await db().collection("Users").doc(uid).get();
  const role = snap.data()?.role;
  if (role !== "ADM") throw new HttpsError("permission-denied", "admin_only");
}

export const manageTeamProfile = onCall(
  { timeoutSeconds: 20, region: "us-central1" },
  async (request) => {
    await assertAdmin(request.auth?.uid);
    const { action, profileId, name, widgets } = request.data as any;

    if (action === "create") {
      if (!name || typeof name !== "string" || name.trim().length < 1) {
        throw new HttpsError("invalid-argument", "name_required");
      }
      const validWidgets = (widgets || []).filter((w: string) =>
        (ALL_WIDGETS as readonly string[]).includes(w)
      );
      const ref = await db().collection("TeamProfiles").add({
        name: name.trim(),
        widgets: validWidgets,
        createdAt: FieldValue.serverTimestamp(),
        createdBy: request.auth!.uid,
      });
      return { id: ref.id };
    }

    if (action === "update") {
      if (!profileId) throw new HttpsError("invalid-argument", "profileId_required");
      const updates: Record<string, unknown> = { updatedAt: FieldValue.serverTimestamp() };
      if (name && typeof name === "string") updates.name = name.trim();
      if (Array.isArray(widgets)) {
        updates.widgets = widgets.filter((w: string) =>
          (ALL_WIDGETS as readonly string[]).includes(w)
        );
      }
      await db().collection("TeamProfiles").doc(profileId).update(updates);
      return { ok: true };
    }

    if (action === "delete") {
      if (!profileId) throw new HttpsError("invalid-argument", "profileId_required");
      await db().collection("TeamProfiles").doc(profileId).delete();
      // Révoquer tous les membres de ce profil
      const members = await db()
        .collection("TeamMembers")
        .where("profileId", "==", profileId)
        .get();
      const batch = db().batch();
      members.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      return { ok: true };
    }

    throw new HttpsError("invalid-argument", "unknown_action");
  }
);

export const assignTeamProfile = onCall(
  { timeoutSeconds: 20, region: "us-central1" },
  async (request) => {
    await assertAdmin(request.auth?.uid);
    const { action, uid, profileId } = request.data as any;

    if (action === "assign") {
      if (!uid || !profileId) throw new HttpsError("invalid-argument", "uid_profileId_required");
      const profileSnap = await db().collection("TeamProfiles").doc(profileId).get();
      if (!profileSnap.exists) throw new HttpsError("not-found", "profile_not_found");
      await db()
        .collection("TeamMembers")
        .doc(uid)
        .set({
          profileId,
          profileName: profileSnap.data()!.name,
          widgets: profileSnap.data()!.widgets || [],
          grantedBy: request.auth!.uid,
          grantedAt: FieldValue.serverTimestamp(),
        });
      return { ok: true };
    }

    if (action === "revoke") {
      if (!uid) throw new HttpsError("invalid-argument", "uid_required");
      await db().collection("TeamMembers").doc(uid).delete();
      return { ok: true };
    }

    throw new HttpsError("invalid-argument", "unknown_action");
  }
);

export const getTeamProfiles = onCall(
  { timeoutSeconds: 15, region: "us-central1" },
  async (request) => {
    await assertAdmin(request.auth?.uid);
    const snap = await db()
      .collection("TeamProfiles")
      .orderBy("createdAt", "desc")
      .get();
    return {
      profiles: snap.docs.map((d) => ({
        id: d.id,
        name: d.data().name,
        widgets: d.data().widgets || [],
      })),
    };
  }
);

export const getTeamMembers = onCall(
  { timeoutSeconds: 15, region: "us-central1" },
  async (request) => {
    await assertAdmin(request.auth?.uid);
    const snap = await db()
      .collection("TeamMembers")
      .orderBy("grantedAt", "desc")
      .get();
    // Récupérer les infos des users en parallèle (max 50)
    const docs = snap.docs.slice(0, 50);
    const userSnaps = await Promise.all(
      docs.map((d) => db().collection("Users").doc(d.id).get())
    );
    return {
      members: docs.map((d, i) => {
        const m = d.data();
        const u = userSnaps[i].data() || {};
        return {
          uid: d.id,
          profileId: m.profileId,
          profileName: m.profileName,
          widgets: m.widgets || [],
          pseudo: u.pseudo || "",
          email: u.email || "",
          imageUrl: u.imageUrl || "",
          grantedAt: m.grantedAt?.toMillis?.() ?? null,
        };
      }),
    };
  }
);
