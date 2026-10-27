// Image d'aperçu (WhatsApp, Facebook…) de l'opportunité « publier ses commandes et gagner » : 1200 × 630, une version par langue.
// Usage : node scripts/og-earn.mjs  → static/img/og-gagner-fr.jpg et og-gagner-en.jpg
import sharp from 'sharp';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const out = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'static', 'img');
const T = {
  fr: { chip: 'NOUVEAU · GAGNEZ DE L’ARGENT', h1: 'Publiez votre commande.', h2: 'Chaque utilisation vous rapporte.', steps: [['1', 'Rédigez', 'votre commande'], ['2', 'Testez', 'le rendu'], ['3', 'Soumettez', 'pour validation'], ['4', 'Gagnez', 'à chaque utilisation']], line: '1 crédit gagné ≈ 4 F  ·  retrait mobile money dès 1 000 F', foot: 'slashatlas.com' },
  en: { chip: 'NEW · EARN MONEY', h1: 'Publish your command.', h2: 'Every use pays you.', steps: [['1', 'Write', 'your command'], ['2', 'Test', 'the result'], ['3', 'Submit', 'for approval'], ['4', 'Earn', 'on every use']], line: '1 earned credit ≈ 4 F  ·  mobile money withdrawal from 1,000 F', foot: 'slashatlas.com' },
};
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
const FONT = "Segoe UI, Arial, Helvetica, sans-serif";

for (const l of ['fr', 'en']) {
  const t = T[l];
  const steps = t.steps.map((s, i) => {
    const x = 60 + i * 285;
    return `<g transform="translate(${x},330)"><rect width="265" height="150" rx="24" fill="#0c1118" stroke="#1d2a3a" stroke-width="2"/><circle cx="46" cy="48" r="26" fill="#2997ff"/><text x="46" y="58" text-anchor="middle" font-family="${FONT}" font-size="30" font-weight="800" fill="#fff">${s[0]}</text><text x="24" y="104" font-family="${FONT}" font-size="34" font-weight="800" fill="#fff">${esc(s[1])}</text><text x="24" y="134" font-family="${FONT}" font-size="22" fill="#9aa4b2">${esc(s[2])}</text></g>`;
  }).join('');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#050a12"/><stop offset="1" stop-color="#0a2340"/></linearGradient></defs>
<rect width="1200" height="630" fill="url(#g)"/>
<text x="60" y="78" font-family="${FONT}" font-size="34" font-weight="800" fill="#fff"><tspan fill="#2997ff">/</tspan>SlashAtlas</text>
<rect x="60" y="106" width="${t.chip.length * 14 + 44}" height="42" rx="21" fill="#2997ff"/>
<text x="82" y="135" font-family="${FONT}" font-size="21" font-weight="800" fill="#fff" letter-spacing="1">${esc(t.chip)}</text>
<text x="60" y="226" font-family="${FONT}" font-size="64" font-weight="800" fill="#fff">${esc(t.h1)}</text>
<text x="60" y="296" font-family="${FONT}" font-size="64" font-weight="800" fill="#2997ff">${esc(t.h2)}</text>
${steps}
<text x="60" y="548" font-family="${FONT}" font-size="30" font-weight="700" fill="#ffd27a">${esc(t.line)}</text>
<text x="60" y="597" font-family="${FONT}" font-size="24" fill="#6b7686">${esc(t.foot)}</text>
</svg>`;
  await sharp(Buffer.from(svg)).jpeg({ quality: 84, mozjpeg: true }).toFile(path.join(out, `og-gagner-${l}.jpg`));
  console.log('ok', `og-gagner-${l}.jpg`);
}
