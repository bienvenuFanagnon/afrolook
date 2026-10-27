import { randomUUID } from "crypto";
import { getStorage } from "firebase-admin/storage";
import sharp from "sharp";
import { db } from "../shared/firebase";
import { NEWS_AGENTS, agentUserId } from "./agents";
import { GLYPHS, Glyph } from "./avatarGlyphs";
import { ensureAgent } from "./publish";

/**
 * Photos de profil des agents d'actualités : générées par le code, sans outil payant, aux couleurs de l'application. Même dessin que l'avatar des cartes :
 * un cercle teinté de la couleur du domaine, l'icône du domaine au centre et le badge « journal » vert en bas à droite, réservé aux agents.
 * L'image carrée de 512 pixels laisse le badge dans le cercle quand l'application recadre la photo en rond.
 * Écrites dans Storage (news_agents/{agent}.png, lien permanent avec jeton) puis rangées dans le profil de l'agent (Users.imageUrl).
 */
export const AVATAR_COLORS: Record<string, string> = {
  sport: "#2ECC71", politik: "#5B9CFA", culture: "#FF9248", beat: "#FF6B6F", tech: "#FFE14D", voyage: "#14B8A6", mode: "#EC4899", info: "#A78BFA",
};
const BG = "#0E0E0E";
const GREEN = "#2ECC71";
export const AVATAR_SIZE = 512;

/** Place une icône au centre (cx, cy), à la taille voulue : mise à l'échelle de sa boîte, recentrée sur son milieu. */
export function glyphTransform(g: Glyph, size: number, cx: number, cy: number): string {
  const s = size / Math.max(g.x2 - g.x1, g.y2 - g.y1);
  const mx = (g.x1 + g.x2) / 2;
  const my = (g.y1 + g.y2) / 2;
  return `translate(${cx} ${cy}) scale(${s.toFixed(5)}) translate(${(-mx).toFixed(2)} ${(-my).toFixed(2)})`;
}

export function avatarSvg(key: string): string {
  const color = AVATAR_COLORS[key];
  const glyph = GLYPHS[key];
  const journal = GLYPHS["journal"];
  if (!color || !glyph || !journal) throw new Error(`Agent inconnu : ${key}`);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${AVATAR_SIZE}" height="${AVATAR_SIZE}" viewBox="0 0 ${AVATAR_SIZE} ${AVATAR_SIZE}">` +
    `<rect width="${AVATAR_SIZE}" height="${AVATAR_SIZE}" fill="${BG}"/>` +
    `<circle cx="256" cy="256" r="236" fill="${color}" fill-opacity="0.18" stroke="${color}" stroke-width="12"/>` +
    `<path d="${glyph.d}" fill="${color}" transform="${glyphTransform(glyph, 250, 256, 256)}"/>` +
    `<circle cx="380" cy="380" r="64" fill="${GREEN}" stroke="${BG}" stroke-width="12"/>` +
    `<path d="${journal.d}" fill="${BG}" transform="${glyphTransform(journal, 76, 380, 380)}"/>` +
    `</svg>`;
}

export async function avatarPng(key: string): Promise<Buffer> {
  return sharp(Buffer.from(avatarSvg(key))).png({ compressionLevel: 9 }).toBuffer();
}

/** Crée (ou remplace) les photos des agents et les range dans leur profil. Retourne le lien de chaque photo. */
export async function publishAvatars(nowMs = Date.now()): Promise<Array<{ key: string; pseudo: string; url: string }>> {
  const bucket = getStorage().bucket();
  const out: Array<{ key: string; pseudo: string; url: string }> = [];
  for (const a of NEWS_AGENTS) {
    await ensureAgent(a.key);
    const path = `news_agents/${a.key}.png`;
    const token = randomUUID();
    await bucket.file(path).save(await avatarPng(a.key), {
      contentType: "image/png",
      metadata: { cacheControl: "public,max-age=31536000", metadata: { firebaseStorageDownloadTokens: token } },
    });
    const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
    await db.collection("Users").doc(agentUserId(a.key)).set({ imageUrl: url, updatedAt: nowMs }, { merge: true });
    await db.collection("NewsAgents").doc(a.key).set({ key: a.key, avatarUrl: url }, { merge: true });
    out.push({ key: a.key, pseudo: a.pseudo, url });
  }
  return out;
}
