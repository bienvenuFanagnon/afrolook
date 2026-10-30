import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { notifyAdminsAll, notifyByEmail } from "../shared/user_notify";
import { requireGoogle } from "./adsWeb";
import { requireAdmin } from "./adsPublishers";
import { SECTORS, nextLogoStatus, selectPartners, validateAdvertiser } from "./adsAdvertisers_logic";

/**
 * Afrolook Ads : profil annonceur (nom de la marque, secteur, pays, contact et LOGO). Le logo est obligatoire pour publier ; une fois validé par
 * l'administration, il est affiché comme celui d'un partenaire (avec l'accord de l'annonceur).
 *  Annonceur (connexion Google) : adsAdvMe, adsAdvSaveProfile
 *  Administration : adsAdvAdminList, adsAdvAdminReview
 *  Public : adsPartners (logos des annonceurs validés ayant une annonce en ligne)
 */
const OPTS = { region: "us-central1" as const, timeoutSeconds: 30, memory: "256MiB" as const };
const BUCKET = "afrolooki.appspot.com";
const SPACE_URL = "https://afrolookmedia.com/ads/espace/";
const now = (): number => Date.now();
const ref = (uid: string) => db.collection("AdAdvertiserProfiles").doc(uid);

const out = (p: Record<string, unknown>) => ({
  brandName: p["brandName"], sector: p["sector"], country: p["country"], city: p["city"], website: p["website"] ?? "", whatsapp: p["whatsapp"] ?? "", about: p["about"] ?? "",
  logoUrl: p["logoUrl"], logoStatus: p["logoStatus"], logoReason: p["logoReason"] ?? "", partnerConsent: p["partnerConsent"] === true,
});

export const adsAdvMe = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const p = (await ref(me.uid).get()).data();
  return { profile: p ? out(p) : null, sectors: SECTORS, email: me.email, name: me.name };
});

export const adsAdvSaveProfile = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const v = validateAdvertiser(request.data, me.uid, BUCKET);
  if (!v.ok) throw new HttpsError("invalid-argument", v.error);
  const r = ref(me.uid);
  const cur = (await r.get()).data();
  const logoStatus = nextLogoStatus(cur?.["logoUrl"], cur?.["logoStatus"], v.value.logoUrl, cur?.["brandName"] === v.value.brandName);
  const t = now();
  await r.set({ ...v.value, uid: me.uid, email: me.email, googleName: me.name, logoStatus, logoReason: logoStatus === "pending" ? "" : cur?.["logoReason"] ?? "", createdAt: cur?.["createdAt"] ?? t, updatedAt: t }, { merge: true });
  if (logoStatus === "pending" && (!cur || cur["logoStatus"] !== "pending" || cur["logoUrl"] !== v.value.logoUrl || cur["brandName"] !== v.value.brandName)) {
    await notifyAdminsAll({
      title: "🏷️ Profil annonceur à valider", message: `${v.value.brandName} (${v.value.country}) a rempli son profil annonceur (marque, contact, logo). Ouvre la validation des annonceurs.`, target: "ADMIN_ADS", refId: me.uid,
      email: { subject: "Profil annonceur à valider", heading: "Nouveau profil annonceur", icon: "🏷️", intro: "Un annonceur a rempli son profil (marque, contact, logo). Une fois le profil validé, son logo est affiché comme partenaire sur Afrolook Ads.", rows: [["Marque", v.value.brandName], ["Pays", v.value.country], ["E-mail", me.email]], tone: "info" },
    });
  }
  return { ok: true, logoStatus };
});

/** Liste des annonceurs pour l'administration : « all » = tous. Chaque ligne porte ses chiffres (annonces, en ligne, vues, clics). */
export const adsAdvAdminList = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const status = String((request.data as { status?: unknown } | undefined)?.status ?? "pending");
  const wanted = ["pending", "approved", "rejected", "all"].includes(status) ? status : "pending";
  const base = db.collection("AdAdvertiserProfiles");
  const [snap, ads] = await Promise.all([
    (wanted === "all" ? base.orderBy("createdAt", "desc") : base.where("logoStatus", "==", wanted)).limit(200).get(),
    db.collection("Advertisements").where("source", "==", "web").limit(1500).get(),
  ]);
  const t = Date.now() * 1000;
  const st = new Map<string, { ads: number; active: number; views: number; clicks: number }>();
  for (const d of ads.docs) {
    const a = d.data(), u = String(a["createdBy"] ?? "");
    const s = st.get(u) ?? { ads: 0, active: 0, views: 0, clicks: 0 };
    if (a["hidden"] !== true) s.ads++;
    if (a["status"] === "active" && Number(a["endDate"]) > t) s.active++;
    s.views += Number(a["views"]) || 0; s.clicks += Number(a["clicks"]) || 0;
    st.set(u, s);
  }
  return { items: snap.docs.map((d) => ({ uid: d.id, email: d.data()["email"], createdAt: d.data()["createdAt"] ?? 0, ...out(d.data()), stats: st.get(d.id) ?? { ads: 0, active: 0, views: 0, clicks: 0 } })) };
});

export const adsAdvAdminReview = onCall(OPTS, async (request) => {
  const admin = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const uid = String(d["uid"] ?? "");
  const decision = d["decision"] === "approve" ? "approve" : d["decision"] === "reject" ? "reject" : "";
  const reason = String(d["reason"] ?? "").replace(/[\u0000-\u001f<>]/g, " ").trim().slice(0, 300);
  if (!uid || !decision) throw new HttpsError("invalid-argument", "demande incomplète");
  if (decision === "reject" && reason.length < 5) throw new HttpsError("invalid-argument", "motif_obligatoire");
  const r = ref(uid);
  const p = (await r.get()).data();
  if (!p) throw new HttpsError("not-found", "profil inconnu");
  const ok = decision === "approve";
  await r.update({ logoStatus: ok ? "approved" : "rejected", logoReason: ok ? "" : reason, reviewedBy: admin.uid, reviewedAt: now(), ...(ok ? { approvedAt: now() } : {}), updatedAt: now() });
  partnersCache = null;
  await db.collection("AdsAudit").add({ at: now(), by: admin.uid, target: "advertiser", id: uid, decision, reason }).catch(() => undefined);
  await notifyByEmail(String(p["email"] ?? ""), {
    subject: ok ? "Ton profil annonceur est validé" : "Ton profil annonceur n'a pas été accepté", heading: ok ? "Profil validé" : "Profil refusé", icon: ok ? "✅" : "⛔", tone: ok ? "ok" : "no",
    intro: ok ? "Ton profil annonceur est validé. Ton logo est maintenant affiché parmi nos partenaires sur Afrolook Ads dès que tu as une annonce en ligne." : `Ton profil n'a pas pu être accepté. Motif : ${reason}. Corrige-le dans ton espace annonceur puis renvoie-le.`,
    button: { label: "Ouvrir mon espace annonceur", url: SPACE_URL },
  }).catch((e) => console.error("[adsAdv] mail", e));
  return { ok: true };
});

let partnersCache: { at: number; items: ReturnType<typeof selectPartners> } | null = null;
export const adsPartners = onRequest({ ...OPTS, cors: true, timeoutSeconds: 15 }, async (req, res) => {
  if (req.method !== "GET") { res.status(405).send("Method Not Allowed"); return; }
  try {
    if (!partnersCache || Date.now() - partnersCache.at > 300_000) {
      const t = Date.now() * 1000;
      const ads = await db.collection("Advertisements").where("status", "==", "active").where("endDate", ">", t).limit(200).get();
      const uids = new Set(ads.docs.filter((d) => d.data()["source"] === "web" && d.data()["hidden"] !== true).map((d) => String(d.data()["createdBy"])));
      const list = [...uids].slice(0, 120);
      const docs = list.length ? await db.getAll(...list.map((u) => ref(u))) : [];
      const profiles = docs.filter((d) => d.exists).map((d) => ({ uid: d.id, ...(d.data() as Record<string, unknown>) })) as Parameters<typeof selectPartners>[0];
      partnersCache = { at: Date.now(), items: selectPartners(profiles, uids, 40) };
    }
    res.set("Cache-Control", "public, max-age=300, s-maxage=300");
    res.json({ items: partnersCache.items });
  } catch (e) {
    console.error("[adsPartners]", e);
    res.json({ items: [] });
  }
});
