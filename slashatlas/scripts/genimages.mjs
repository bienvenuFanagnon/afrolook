// Génère les visuels du site avec Gemini : une photo de départ, puis le résultat obtenu avec la vraie commande.
// Usage : GEMINI_API_KEY=… node scripts/genimages.mjs <dossier de sortie> <slug> [<slug>…]
import fs from 'node:fs';
import path from 'node:path';
import { COMMANDS } from '../src/data.mjs';

const MODEL = process.env.GEMINI_IMAGE_MODEL || 'gemini-3.1-flash-image';
const KEY = process.env.GEMINI_API_KEY;
if (!KEY) throw new Error('GEMINI_API_KEY manquante');
const [out, ...slugs] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });

// Photos de départ : prises de vue banales, sans marque ni logo réel, comme un commerçant les ferait avec son téléphone.
const P = 'Photo prise au smartphone, réaliste et un peu banale, sans marque ni logo connu, sans texte lisible. ';
const SRC = {
  fashionposter: P + 'Une robe en wax aux motifs géométriques orange et bleu, posée à plat sur un lit aux draps blancs.',
  lookbook: P + 'Une femme d\'environ 30 ans debout dans un salon lumineux, vêtue d\'un ensemble pantalon beige et d\'une chemise blanche, regardant l\'objectif.',
  productglow: P + 'Un flacon de parfum en verre ambré avec une étiquette blanche vierge, posé sur une table en bois près d\'une fenêtre.',
  splashshot: P + 'Une bouteille d\'eau minérale en plastique transparent avec une étiquette bleue vierge, posée sur un plan de travail de cuisine.',
  menuhero: P + 'Un plat de poulet braisé avec attiéké et tomates-oignons, dans une assiette blanche sur une table de restaurant, éclairage de salle ordinaire.',
  bakerymorning: P + 'Des croissants et deux baguettes dans un panier en osier sur le comptoir d\'une boulangerie.',
  openhouse: P + 'La façade d\'une maison moderne de plain-pied avec un petit jardin et un portail, en plein jour, ciel clair.',
  roomstaging: P + 'Un salon vide avec murs blancs, parquet clair et une grande fenêtre, sans meuble.',
  matchday: P + 'Un footballeur de 25 ans en maillot rouge, ballon aux pieds, sur un terrain d\'entraînement en herbe, de face.',
  workoutbanner: P + 'Une femme d\'environ 28 ans en tenue de sport noire dans une salle de sport, faisant un squat avec des haltères, de face.',
  coverdrop: P + 'Un portrait d\'un chanteur d\'environ 27 ans, barbe courte, veste en jean, devant un mur de briques, regardant l\'objectif.',
  gigflyer: P + 'Une chanteuse d\'environ 30 ans tenant un micro, sur une petite scène de bar, de face, éclairage de scène ordinaire.',
  reelcover: P + 'Un créateur de contenu d\'environ 25 ans assis à un bureau avec un micro, souriant à la caméra, dans une chambre aménagée en studio.',
  thumbpunch: P + 'Un homme d\'environ 28 ans, expression surprise la bouche ouverte, devant un mur clair, cadrage paysage.',
  eventnight: P + 'Un groupe de quatre amis souriants dans un salon, tenant des verres, soirée entre amis, de face.',
  weddinginvite: P + 'Un couple de jeunes mariés souriants dans un jardin, elle en robe blanche, lui en costume gris, de face.',
  skincareglow: P + 'Un flacon de crème de soin blanc avec une étiquette vierge, posé sur le bord d\'un lavabo de salle de bain.',
  hairshowcase: P + 'Une femme d\'environ 30 ans avec des tresses africaines, vue de trois-quarts, dans un salon de coiffure.',
};

async function gen(parts, ratio) {
  const body = { contents: [{ parts }], generationConfig: { responseModalities: ['IMAGE'], imageConfig: { aspectRatio: ratio } } };
  for (let i = 0; i < 3; i++) {
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-goog-api-key': KEY }, body: JSON.stringify(body) });
    const j = await r.json();
    if (j.error) { console.error('erreur', j.error.code, String(j.error.message).slice(0, 160)); if (j.error.code === 429 || j.error.code >= 500) { await new Promise((s) => setTimeout(s, 4000 * (i + 1))); continue; } return null; }
    const cand = j.candidates?.[0]?.content?.parts || [];
    const img = cand.find((p) => p.inlineData || p.inline_data);
    const d = img?.inlineData || img?.inline_data;
    if (d) return { data: Buffer.from(d.data, 'base64'), mime: d.mimeType || d.mime_type, usage: j.usageMetadata };
    console.error('pas d\'image :', JSON.stringify(cand).slice(0, 200), j.promptFeedback ? JSON.stringify(j.promptFeedback) : '');
    return null;
  }
  return null;
}
const ext = (m) => (m && m.includes('jpeg') ? 'jpg' : 'png');

async function one(slug) {
  const c = COMMANDS.find((x) => x.slug === slug);
  if (!c || !SRC[slug]) { console.error('inconnu', slug); return; }
  console.log('→', slug);
  const a = await gen([{ text: SRC[slug] + ` Format ${c.ratio}.` }], c.ratio);
  if (!a) return;
  const pa = path.join(out, `${slug}-avant.${ext(a.mime)}`); fs.writeFileSync(pa, a.data);
  const b = await gen([{ inlineData: { mimeType: a.mime, data: a.data.toString('base64') } }, { text: `${c.code} : ${c.fr.prompt}` }], c.ratio);
  if (!b) return;
  const pb = path.join(out, `${slug}-apres.${ext(b.mime)}`); fs.writeFileSync(pb, b.data);
  console.log('  ok', pa, pb, JSON.stringify({ a: a.usage?.totalTokenCount, b: b.usage?.totalTokenCount }));
}
const queue = [...slugs];
await Promise.all(Array.from({ length: 3 }, async () => { while (queue.length) await one(queue.shift()); }));
