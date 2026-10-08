// Prépare l'écriture d'une vague de contes : lit un plan (vagues/vague-NN.txt), le contrôle et crée un brouillon par recueil
// dans tools/contes/brouillons/. Il ne produit AUCUN texte de conte : on y écrit les pages, puis on déplace le fichier dans recueils/.
//   node scaffold.js vagues/vague-02.txt              contrôle le plan et affiche l'équilibre des régions
//   node scaffold.js vagues/vague-02.txt --write      crée les brouillons (n'écrase jamais un brouillon existant)
//   node scaffold.js vagues/vague-02.txt --write --only 07-ruses-de-la-tortue
const fs = require('fs');
const path = require('path');

const DECORS = ['baobab', 'savane', 'village', 'foret', 'fleuve', 'desert', 'montagne'];
const LIGHTS = ['aube', 'midi', 'crepuscule', 'nuit', 'orage'];
const FIGURES = ['lievre', 'hyene', 'araignee', 'lion', 'tortue', 'elephant', 'oiseau', 'singe', 'crocodile', 'serpent', 'enfant', 'ancien', 'reine', 'guerrier', 'griot', 'tambour', 'masque', 'calebasse', 'pirogue', 'feu'];
const TAGS = ['Fin surprenante', 'Rire', 'Sagesse', 'Frisson', 'Légende', 'Amour', 'Mythe', 'Ruse', 'Histoire'];
const REGIONS = { O: "Afrique de l'Ouest", C: 'Afrique centrale', E: "Afrique de l'Est", S: 'Afrique australe', N: 'Afrique du Nord' };

const file = process.argv[2];
if (!file) { console.error('Usage : node scaffold.js vagues/vague-NN.txt [--write] [--only <recueil>]'); process.exit(1); }
const onlyIdx = process.argv.indexOf('--only');
const only = onlyIdx > 0 ? process.argv[onlyIdx + 1] : '';
const problems = [];

const existing = new Set();
for (const dirName of ['recueils', 'brouillons']) {
  const d = path.join(__dirname, dirName);
  if (!fs.existsSync(d)) continue;
  for (const f of fs.readdirSync(d).filter((x) => x.endsWith('.txt'))) {
    for (const m of fs.readFileSync(path.join(d, f), 'utf8').matchAll(/^=== conte:\s*(\S+)/gm)) existing.add(m[1]);
  }
}

const recueils = [];
let cur = null;
fs.readFileSync(path.resolve(file), 'utf8').split('\n').forEach((raw, n) => {
  const line = raw.trim();
  if (!line || line.startsWith('#')) return;
  if (line.startsWith('== recueil:')) {
    const [id, title, category, order] = line.slice(11).split('|').map((x) => x.trim());
    cur = { id, title, category, order: Number(order), description: '', stories: [] };
    recueils.push(cur);
    return;
  }
  if (!cur) return;
  if (line.startsWith('description:')) { cur.description = line.slice(12).trim(); return; }
  const p = line.split('|').map((x) => x.trim());
  if (p.length !== 8) { problems.push(`ligne ${n + 1} : 8 champs attendus, ${p.length} trouvés`); return; }
  const [id, title, rg, tag, type, scene, figs, idea] = p;
  const [decor, light] = scene.split('/');
  const figures = figs.split(',').map((x) => x.trim());
  const w = `${cur.id}/${id}`;
  if (!/^[a-z0-9-]{3,40}$/.test(id)) problems.push(`${w} : identifiant invalide`);
  if (existing.has(id) && !fs.existsSync(path.join(__dirname, 'brouillons', `${cur.id}.txt`))) problems.push(`${w} : identifiant déjà utilisé`);
  if (!REGIONS[rg]) problems.push(`${w} : région « ${rg} » (O, C, E, S ou N)`);
  if (!TAGS.includes(tag)) problems.push(`${w} : étiquette « ${tag} »`);
  if (!['court', 'long', 'chapitre'].includes(type)) problems.push(`${w} : type « ${type} »`);
  if (!DECORS.includes(decor)) problems.push(`${w} : décor « ${decor} »`);
  if (!LIGHTS.includes(light)) problems.push(`${w} : lumière « ${light} »`);
  if (figures.length < 1 || figures.length > 3 || figures.some((f) => !FIGURES.includes(f))) problems.push(`${w} : figures « ${figs} »`);
  if (title.length > 70) problems.push(`${w} : titre trop long`);
  cur.stories.push({ id, title, region: REGIONS[rg], rg, tag, type, decor, light, figures, idea });
});

const all = recueils.flatMap((r) => r.stories);
const ids = new Set();
all.forEach((s) => { if (ids.has(s.id)) problems.push(`${s.id} : en double dans le plan`); ids.add(s.id); });
recueils.forEach((r) => { if (!r.id || !r.title || !r.category || !(r.order > 0)) problems.push(`recueil « ${r.id} » incomplet`); });

const tally = (key) => all.reduce((m, s) => { m[s[key]] = (m[s[key]] || 0) + 1; return m; }, {});
console.log(`${recueils.length} recueils, ${all.length} contes prévus`);
console.log('Régions : ' + Object.entries(tally('region')).map(([k, v]) => `${k} ${v}`).join(' · '));
console.log('Étiquettes : ' + Object.entries(tally('tag')).map(([k, v]) => `${k} ${v}`).join(' · '));
if (problems.length) { console.error(`${problems.length} problème(s) :\n  ` + problems.join('\n  ')); process.exit(1); }

if (!process.argv.includes('--write')) process.exit(0);
const outDir = path.join(__dirname, 'brouillons');
fs.mkdirSync(outDir, { recursive: true });
recueils.filter((r) => !only || r.id === only).forEach((r) => {
  const out = path.join(outDir, `${r.id}.txt`);
  if (fs.existsSync(out)) { console.log(`déjà là, laissé tel quel : brouillons/${r.id}.txt`); return; }
  let t = `recueil: ${r.title}\ncategorie: ${r.category}\ndescription: ${r.description}\nordre: ${r.order}\nprix: 70\n`;
  r.stories.forEach((s, i) => {
    t += `\n=== conte: ${s.id}\ntitre: ${s.title}\naccroche: À ÉCRIRE (140 signes maximum)\netiquette: ${s.tag}\norigine: À PRÉCISER (peuple, pays — « d'inspiration » si le récit est une libre réécriture)\nregion: ${s.region}\ntype: ${s.type}\ngratuites: 2\ndecor: ${s.decor}\nlumiere: ${s.light}\nfigures: ${s.figures.join(', ')}\nmorale: À ÉCRIRE\n`;
    t += `# idée : ${s.idea}\n`;
    for (let k = 0; k < 5; k++) t += `---\nÀ ÉCRIRE (page ${k + 1}, 70 à 170 mots)\n`;
  });
  fs.writeFileSync(out, t);
  console.log(`créé : brouillons/${r.id}.txt (${r.stories.length} contes)`);
});
