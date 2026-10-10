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
const SRC = {
  productglow: 'Photo prise au smartphone, réaliste et un peu banale, d\'un flacon de parfum en verre ambré avec une étiquette blanche sobre, posé sur une table en bois près d\'une fenêtre, lumière du jour. Aucune marque connue, aucun texte lisible. Format 4:5.',
  menuhero: 'Photo prise au smartphone, réaliste, d\'un plat de poulet braisé avec attiéké et tomates-oignons, dans une assiette blanche sur une table de restaurant, éclairage de salle ordinaire. Format 4:5.',
  openhouse: 'Photo prise au smartphone, réaliste, en plein jour, de la façade d\'une maison moderne de plain-pied avec un petit jardin et un portail, ciel clair. Format 4:5.',
};

async function gen(parts) {
  const body = { contents: [{ parts }], generationConfig: { responseModalities: ['IMAGE'], imageConfig: { aspectRatio: '4:5' } } };
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

for (const slug of slugs) {
  const c = COMMANDS.find((x) => x.slug === slug);
  if (!c || !SRC[slug]) { console.error('inconnu', slug); continue; }
  console.log('→', slug);
  const a = await gen([{ text: SRC[slug] }]);
  if (!a) continue;
  const pa = path.join(out, `${slug}-avant.${ext(a.mime)}`); fs.writeFileSync(pa, a.data);
  const b = await gen([{ inlineData: { mimeType: a.mime, data: a.data.toString('base64') } }, { text: `${c.code} : ${c.fr.prompt}` }]);
  if (!b) continue;
  const pb = path.join(out, `${slug}-apres.${ext(b.mime)}`); fs.writeFileSync(pb, b.data);
  console.log('  ok', pa, pb, JSON.stringify({ a: a.usage?.totalTokenCount, b: b.usage?.totalTokenCount }));
}
