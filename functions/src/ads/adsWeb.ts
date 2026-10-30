import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { createHash } from "crypto";
import { db } from "../shared/firebase";
import { buildPreview, LinkPreview } from "../posts/linkPreview";
import { FieldValue } from "firebase-admin/firestore";
import { isSensitive } from "./adsCategories";
import { ACTION_LABEL, DAY_MICROS, MAX_PER_DAY, MAX_TRACK_PER_IP_DAY, countsAsFree, daysLeft, displayStatus, isBot, readAdsWebConfig, renewalDecision, trackDecision, validateAdInput, validPlacement, validVisitorId } from "./adsWeb_logic";

/**
 * Afrolook Ads : annonceurs sur afrolookmedia.com/ads/ (connexion Google, sans profil Afrolook). Le système de pub existant est réutilisé :
 * chaque annonce = un post (isAdvertisement) + un document Advertisements « pending » que les administrateurs valident comme aujourd'hui
 * (écran d'administration des pubs, notifications aux administrateurs et à l'annonceur, vues et clics : tout existe déjà).
 *  - adsWebCreate : dépose une annonce gratuite (3 au total par compte, 14 jours chacune) ;
 *  - adsWebRenew : renouvelle gratuitement une annonce terminée (une fois) ; ensuite, paiement des pubs Afrolook dans l'application ;
 *  - adsWebMine : mes annonces (statut, vues, clics, jours restants, possibilité de renouveler) ;
 *  - adsWebStop : arrête une de mes annonces ;
 *  - adsWebDelete : supprime une de mes annonces (retirée de la diffusion et de mes listes ; elle reste comptée dans les 3 gratuites) ;
 *  - adsWebPublic : annonces en ligne, pour la galerie du site (et, plus tard, pour SlashAtlas et Pronoflash) ;
 *  - adsWebTrack : compte une vue ou un clic d'un visiteur (une vue et un clic par visiteur, annonce et jour ; robots ignorés ; plafond par adresse IP).
 * Réglages (AppConfig/adsWeb) : enabled, freeAds (3), freePeriods (2), freeDays (14). freeAds = 0 supprime la gratuité.
 */
const OPTS = { region: "us-central1" as const, timeoutSeconds: 30, memory: "256MiB" as const };
const BUCKET = "afrolooki.appspot.com";
const micros = (): number => Date.now() * 1000;

export function requireGoogle(request: { auth?: { uid: string; token: Record<string, unknown> } }): { uid: string; name: string; email: string; photo: string } {
  const a = request.auth;
  if (!a?.uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const fb = (a.token["firebase"] ?? {}) as Record<string, unknown>;
  if (fb["sign_in_provider"] !== "google.com") throw new HttpsError("permission-denied", "Connexion avec Google requise.");
  return { uid: a.uid, name: String(a.token["name"] ?? "").slice(0, 80), email: String(a.token["email"] ?? "").slice(0, 120), photo: String(a.token["picture"] ?? "").slice(0, 300) };
}

/** Aperçu d'un lien (titre, description, image) : cache de 24 h partagé avec l'aperçu de lien de l'application (LinkPreviews). */
export async function previewOf(url: string, allowBuild: boolean): Promise<LinkPreview | null> {
  const ref = db.collection("LinkPreviews").doc(createHash("sha1").update(url).digest("hex"));
  const c = (await ref.get()).data() as { preview?: LinkPreview; at?: number } | undefined;
  if (c?.preview && c.at && Date.now() - c.at < 24 * 3600_000) return c.preview;
  if (!allowBuild) return null;
  try {
    const p = await buildPreview(url);
    if (p) await ref.set({ preview: p, at: Date.now() }).catch(() => undefined);
    return p;
  } catch { return null; }
}

const loadCfg = async () => readAdsWebConfig((await db.collection("AppConfig").doc("adsWeb").get()).data());
const myAds = async (uid: string) => (await db.collection("Advertisements").where("createdBy", "==", uid).orderBy("createdAt", "desc").limit(80).get()).docs.filter((d) => d.data()["source"] === "web");

export const adsWebCreate = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const cfg = await loadCfg();
  if (!cfg.enabled || cfg.freeAds <= 0) throw new HttpsError("failed-precondition", "gratuite_terminee");
  // profil de marque obligatoire (nom de la marque + logo) : le logo validé est affiché comme celui d'un partenaire
  const adv = (await db.collection("AdAdvertiserProfiles").doc(me.uid).get()).data();
  if (!adv || !adv["logoUrl"] || !adv["brandName"]) throw new HttpsError("failed-precondition", "profil_manquant");
  if (adv["logoStatus"] === "rejected") throw new HttpsError("failed-precondition", "logo_refuse");
  if (adv["logoStatus"] !== "approved") throw new HttpsError("failed-precondition", "profil_en_validation"); // le profil entier doit être validé avant la première annonce
  const v = validateAdInput(request.data, BUCKET);
  if (!v.ok) throw new HttpsError("invalid-argument", v.error);
  const ad = v.value;
  const now = micros();

  // 3 annonces gratuites au total (une annonce refusée ne compte pas), et un plafond de créations par jour
  const mine = (await myAds(me.uid)).map((d) => d.data());
  const used = mine.filter(countsAsFree).length;
  if (used >= cfg.freeAds) throw new HttpsError("resource-exhausted", "limite_atteinte");
  if (mine.filter((d) => Number(d["createdAt"]) > now - DAY_MICROS).length >= MAX_PER_DAY) throw new HttpsError("resource-exhausted", "limite_du_jour");

  const postRef = db.collection("Posts").doc();
  const adRef = db.collection("Advertisements").doc();
  const description = `${ad.title}\n\n${ad.text}`;
  const post: Record<string, unknown> = {
    id: postRef.id, user_id: me.uid, description, created_at: now, updated_at: now, status: "VALIDE", type: "POST",
    dataType: ad.mediaType === "image" ? "IMAGE" : "VIDEO", typeTabbar: "OFFRES", categorie: "LOOK", isAdvertisement: true, advertisementId: adRef.id,
    available_countries: ad.countries, is_available_in_all_countries: ad.countries.includes("ALL"),
    loves: 0, likes: 0, comments: 0, vues: 0, partage: 0, giftCount: 0, popularity: 1, feedScore: 0.5,
    users_like_id: [], users_love_id: [], users_republier_id: [], users_vue_id: [], source: "web",
  };
  if (ad.mediaType === "image") post["images"] = ad.images;
  else { post["url_media"] = ad.videoUrl; post["thumbnail"] = ad.thumbnailUrl; }

  const adDoc: Record<string, unknown> = {
    id: adRef.id, postId: postRef.id, description: ad.text, actionType: ad.action, actionUrl: ad.actionUrl, actionButtonText: ACTION_LABEL[ad.action],
    durationDays: cfg.freeDays, startDate: now, endDate: now + cfg.freeDays * DAY_MICROS, status: "pending", isRenewable: true, renewalCount: 0,
    createdBy: me.uid, createdAt: now, updatedAt: now, views: 0, clicks: 0, uniqueClicks: 0, uniqueViews: 0, pricePaid: 0,
    // propres aux annonces du site : offre gratuite, type d'annonce, annonceur (compte Google, sans profil Afrolook)
    source: "web", freeOffer: true, adCategory: ad.category, videoDuration: ad.videoDuration, targetRegions: ad.regions, targetLanguages: ad.languages, targetDevices: ad.devices, targetCategories: ad.categories, adKind: ad.kind, adTitle: ad.title, advertiserName: String(adv["brandName"]), advertiserEmail: me.email, advertiserPhoto: me.photo, advertiserLogo: String(adv["logoUrl"]),
    ownerName: ad.title,
    ...(Object.keys(ad.bannerImages).length ? { bannerImages: ad.bannerImages } : {}),
  };
  const batch = db.batch();
  batch.set(postRef, post);
  batch.set(adRef, adDoc); // la création déclenche les notifications aux administrateurs (notifyAdminsOnNewAd)
  await batch.commit();
  return { id: adRef.id, remaining: Math.max(0, cfg.freeAds - used - 1) };
});

export const adsWebRenew = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const cfg = await loadCfg();
  const id = String((request.data as { id?: unknown } | undefined)?.id ?? "");
  if (!/^[A-Za-z0-9]{10,40}$/.test(id)) throw new HttpsError("invalid-argument", "annonce inconnue");
  const ref = db.collection("Advertisements").doc(id);
  const now = micros();
  await db.runTransaction(async (tx) => {
    const a = (await tx.get(ref)).data();
    if (!a || a["createdBy"] !== me.uid || a["source"] !== "web") throw new HttpsError("not-found", "annonce inconnue");
    const d = renewalDecision(a, cfg, now);
    if (d === "not_ended") throw new HttpsError("failed-precondition", "pas_terminee");
    if (d === "not_renewable") throw new HttpsError("failed-precondition", "non_renouvelable");
    if (d === "payment_required") throw new HttpsError("failed-precondition", "paiement_requis");
    // contenu déjà validé : le renouvellement gratuit remet l'annonce en ligne tout de suite
    tx.update(ref, { status: "active", startDate: now, endDate: now + cfg.freeDays * DAY_MICROS, durationDays: cfg.freeDays, renewalCount: (Number(a["renewalCount"]) || 0) + 1, lastRenewedAt: now, updatedAt: now });
  });
  return { ok: true };
});

export const adsWebMine = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const cfg = await loadCfg();
  const now = micros();
  const all = await myAds(me.uid);
  const docs = all.filter((d) => d.data()["hidden"] !== true); // supprimées : cachées, mais toujours comptées dans les gratuites
  const posts = docs.length ? await db.getAll(...docs.map((d) => db.collection("Posts").doc(String(d.data()["postId"] ?? "x")))) : [];
  const items = docs.map((d, i) => {
    const a = d.data();
    const p = posts[i]?.data() ?? {};
    const images = Array.isArray(p["images"]) ? (p["images"] as string[]) : [];
    const isVideo = String(p["dataType"] ?? "").toUpperCase() === "VIDEO";
    const st = displayStatus(a, now);
    const renew = st === "terminee" && String(a["status"]) === "active" ? renewalDecision(a, cfg, now) : "no";
    return {
      id: d.id, title: String(a["adTitle"] ?? ""), kind: String(a["adKind"] ?? ""), status: st, action: String(a["actionButtonText"] ?? ""),
      days: Number(a["durationDays"]) || cfg.freeDays, daysLeft: st === "ligne" ? daysLeft(Number(a["endDate"]), now) : 0, renewals: Number(a["renewalCount"]) || 0,
      renew: renew === "ok" ? "free" : renew === "payment_required" ? "paid" : "no",
      views: Number(a["views"]) || 0, clicks: Number(a["clicks"]) || 0, reason: st === "refusee" || st === "arretee" ? String(a["rejectionReason"] ?? "").slice(0, 300) : "",
      thumb: images[0] ?? String(p["thumbnail"] ?? ""), createdAt: Math.floor(Number(a["createdAt"]) / 1000),
      video: isVideo, media: isVideo ? String(p["url_media"] ?? "") : images[0] ?? "", images: images.slice(0, 5),
      text: String(a["description"] ?? "").slice(0, 220), url: String(a["actionUrl"] ?? ""), countries: Array.isArray(p["available_countries"]) ? (p["available_countries"] as string[]) : ["ALL"],
      duration: Number(a["videoDuration"]) || 0,
    };
  });
  const used = all.map((d) => d.data()).filter(countsAsFree).length;
  return { items, used, max: cfg.freeAds, days: cfg.freeDays, open: cfg.enabled && cfg.freeAds > 0 };
});

export const adsWebStop = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const id = String((request.data as { id?: unknown } | undefined)?.id ?? "");
  if (!/^[A-Za-z0-9]{10,40}$/.test(id)) throw new HttpsError("invalid-argument", "annonce inconnue");
  const ref = db.collection("Advertisements").doc(id);
  const a = (await ref.get()).data();
  if (!a || a["createdBy"] !== me.uid || a["source"] !== "web") throw new HttpsError("not-found", "annonce inconnue");
  const st = String(a["status"]);
  if (st !== "pending" && st !== "active") return { ok: true };
  // arrêtée par l'annonceur lui-même : l'indicateur évite le courriel « arrêtée par l'équipe »
  await ref.update({ status: "cancelled", stoppedByAdvertiser: true, updatedAt: micros() });
  return { ok: true };
});

export const adsWebDelete = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const id = String((request.data as { id?: unknown } | undefined)?.id ?? "");
  if (!/^[A-Za-z0-9]{10,40}$/.test(id)) throw new HttpsError("invalid-argument", "annonce inconnue");
  const ref = db.collection("Advertisements").doc(id);
  const a = (await ref.get()).data();
  if (!a || a["createdBy"] !== me.uid || a["source"] !== "web") throw new HttpsError("not-found", "annonce inconnue");
  const st = String(a["status"]);
  // retirée de la diffusion et de ses listes ; le document reste (trace pour l'équipe) et occupe toujours une place gratuite : sans cela, on pourrait supprimer
  // et redéposer sans fin. Une annonce refusée garde son statut (elle ne comptait déjà pas).
  await ref.update({ status: st === "rejected" ? "rejected" : "cancelled", hidden: true, deletedByAdvertiser: true, stoppedByAdvertiser: true, updatedAt: micros() });
  return { ok: true };
});

/** Titre et texte d'une annonce : ceux de l'annonce du site, sinon le texte du post découpé proprement (première ligne, sans couper un mot). */
export function splitAdText(a: Record<string, unknown>, desc: string): { title: string; text: string } {
  const own = String(a["adTitle"] ?? "");
  if (own) return { title: own, text: String(a["description"] ?? "").slice(0, 220) };
  const lines = desc.split("\n").map((l) => l.trim()).filter(Boolean);
  let first = lines[0] ?? "";
  let rest = lines.slice(1).join(" ");
  if (first.length > 70) {
    const cut = first.slice(0, 70).replace(/\s+\S*$/, "");
    rest = `${first.slice(cut.length).trim()} ${rest}`.trim();
    first = `${cut}…`;
  }
  return { title: first, text: rest.slice(0, 220) };
}

/** Annonces en ligne (galerie publique du site) : données publiques seulement. Mise en cache d'une minute. */
export const adsWebPublic = onRequest({ ...OPTS, cors: true, timeoutSeconds: 20 }, async (req, res) => {
  if (req.method !== "GET") { res.status(405).send("Method Not Allowed"); return; }
  try {
    const now = micros();
    const country = String(req.query["country"] ?? "").toUpperCase();
    const snap = await db.collection("Advertisements").where("status", "==", "active").where("endDate", ">", now).limit(60).get();
    const ads = snap.docs.map((d) => ({ id: d.id, a: d.data() })).filter((x) => x.a["postId"] && !["defi", "route"].includes(String(x.a["actionType"] ?? "")));
    const posts = ads.length ? await db.getAll(...ads.map((x) => db.collection("Posts").doc(String(x.a["postId"])))) : [];
    const items = ads.map((x, i) => {
      const p = posts[i]?.data();
      if (!p) return null;
      const countries = Array.isArray(p["available_countries"]) ? (p["available_countries"] as string[]) : ["ALL"];
      if (country && !countries.includes("ALL") && !countries.includes(country)) return null;
      if (isSensitive(String(x.a["adCategory"] ?? ""))) return null; // la galerie publique du site n'affiche jamais de catégorie sensible
      const isVideo = String(p["dataType"] ?? "").toUpperCase() === "VIDEO";
      let images = Array.isArray(p["images"]) ? (p["images"] as string[]).filter(Boolean) : [];
      // anciens posts : l'image est dans url_media
      if (!isVideo && !images.length && typeof p["url_media"] === "string" && p["url_media"]) images = [p["url_media"] as string];
      const { title, text } = splitAdText(x.a, String(p["description"] ?? ""));
      const action = String(x.a["actionType"] ?? "");
      return {
        id: x.id, kind: String(x.a["adKind"] ?? ""), title, text: text.slice(0, 220), video: isVideo, media: isVideo ? String(p["url_media"] ?? "") : images[0] ?? "",
        thumb: isVideo ? String(p["thumbnail"] ?? "") : images[0] ?? "", images: images.slice(0, 5),
        action: action && action !== "none" ? String(x.a["actionButtonText"] ?? "") : "", url: action && action !== "none" ? String(x.a["actionUrl"] ?? "") : "",
        views: Number(x.a["views"]) || 0, days: daysLeft(Number(x.a["endDate"]), now),
      };
    }).filter((x) => x !== null);
    // annonce sans image : aperçu du lien (image, titre et description de la page), construit au plus 4 fois par appel puis gardé 24 h
    let budget = 4;
    await Promise.all(items.map(async (it) => {
      if (!it || it.media || !/^https:\/\//.test(it.url)) return;
      const pv = await previewOf(it.url, budget-- > 0);
      if (!pv) return;
      (it as Record<string, unknown>)["preview"] = { title: pv.title, description: pv.description, image: pv.image, site: pv.siteName };
      if (pv.image) { it.media = pv.image; it.thumb = pv.image; }
    }));
    res.set("Cache-Control", "public, max-age=60, s-maxage=60");
    res.json({ items });
  } catch (e) {
    console.error("[adsWebPublic]", e);
    res.status(500).json({ items: [] });
  }
});

/**
 * Compte une vue ou un clic d'un visiteur de la plateforme (POST {id, type: "view" | "click", vid, placement?}).
 * Même effet que dans l'application sur Advertisements (views, clicks, uniqueViews, uniqueClicks, dailyStats) : l'annonceur voit les chiffres dans son espace
 * et reçoit son courriel à chaque palier de 100 vues. Les compteurs par plateforme sont aussi notés (placements.<nom>.views / clicks).
 * Réponse toujours 200 (ne bloque jamais l'affichage) ; seules les annonces en ligne comptent.
 */
export const adsWebTrack = onRequest({ ...OPTS, cors: true, timeoutSeconds: 15, maxInstances: 20 }, async (req, res) => {
  if (req.method !== "POST") { res.status(405).send("Method Not Allowed"); return; }
  try {
    const raw = typeof req.body === "string" ? JSON.parse(req.body || "{}") : (req.body ?? {});
    const id = String(raw.id ?? ""), type = raw.type === "click" ? "click" : raw.type === "view" ? "view" : "";
    if (!/^[A-Za-z0-9]{10,40}$/.test(id) || !type || !validVisitorId(raw.vid)) { res.status(400).json({ ok: false }); return; }
    if (isBot(req.headers["user-agent"])) { res.json({ ok: true, counted: false }); return; }
    const placement = validPlacement(raw.placement);
    const ip = String(req.headers["x-forwarded-for"] ?? req.ip ?? "").split(",")[0].trim();
    const ipHash = createHash("sha256").update(`ads:${ip}`).digest("hex").slice(0, 20);
    const vh = createHash("sha256").update(`${raw.vid}:${ipHash}`).digest("hex").slice(0, 24);
    const now = micros();
    const today = new Date().toISOString().slice(0, 10);
    const adRef = db.collection("Advertisements").doc(id);
    const seenRef = db.collection("AdsWebSeen").doc(`${id}_${vh}`);
    const rateRef = db.collection("AdsWebRate").doc(`${ipHash}_${today}`);
    const counted = await db.runTransaction(async (tx) => {
      const [ad, seen, rate] = await Promise.all([tx.get(adRef), tx.get(seenRef), tx.get(rateRef)]);
      const a = ad.data();
      if (!a || a["status"] !== "active" || !(Number(a["endDate"]) > now)) return false;
      const d = trackDecision(seen.data(), type, today);
      if (!d.count) return false;
      if ((Number(rate.data()?.["n"]) || 0) >= MAX_TRACK_PER_IP_DAY) return false;
      const k = type === "view" ? "views" : "clicks";
      const upd: Record<string, FieldValue | number> = { [k]: FieldValue.increment(1), [`dailyStats.${today}.${k}`]: FieldValue.increment(1), [`placements.${placement}.${k}`]: FieldValue.increment(1), updatedAt: now };
      if (d.unique) upd[type === "view" ? "uniqueViews" : "uniqueClicks"] = FieldValue.increment(1);
      tx.update(adRef, upd);
      tx.set(seenRef, type === "view" ? { viewed: true, lastViewDay: today, updatedDay: today } : { clicked: true, lastClickDay: today, updatedDay: today }, { merge: true });
      tx.set(rateRef, { n: FieldValue.increment(1), day: today }, { merge: true });
      return true;
    });
    res.json({ ok: true, counted });
  } catch (e) {
    console.error("[adsWebTrack]", e);
    res.json({ ok: false });
  }
});
