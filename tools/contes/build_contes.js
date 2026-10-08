// Assemble « La Case aux Contes » : contrôle les récits, écrit tools/contes/out/ puis (avec --upload) les envoie dans Firestore.
//   node build_contes.js
//   GOOGLE_APPLICATION_CREDENTIALS=... node build_contes.js --upload
//
// Un fichier par recueil dans tools/contes/recueils/<id>.txt :
//
//   recueil: Les Veillées de la Hyène
//   categorie: Ruses et malices
//   description: Une phrase qui donne envie.
//   ordre: 1
//   prix: 70                     (facultatif, prix du recueil complet en pièces)
//
//   === conte: hyene-voix
//   titre: Le jour où la hyène vendit sa voix
//   accroche: Elle l'a cédée pour un festin. Elle ne savait pas à qui.
//   etiquette: Fin surprenante    (Fin surprenante, Rire, Sagesse, Frisson, Légende, Amour, Mythe, Ruse, Histoire)
//   origine: Conte traditionnel (peul, Sénégal)
//   region: Afrique de l'Ouest    (Afrique de l'Ouest, Centrale, de l'Est, Australe, du Nord)
//   type: court                   (court = 10 pièces, long = 20, chapitre = 20 ; le premier conte du recueil est gratuit)
//   gratuites: 2                  (nombre de pages lisibles sans payer ; la suivante s'arrête sur un moment fort)
//   decor: savane                 (baobab, savane, village, foret, fleuve, desert, montagne)
//   lumiere: crepuscule           (aube, midi, crepuscule, nuit, orage)
//   figures: hyene, ancien        (jusqu'à 3 : lievre, hyene, araignee, lion, tortue, elephant, oiseau, singe, crocodile,
//                                  serpent, enfant, ancien, reine, guerrier, griot, tambour, masque, calebasse, pirogue, feu)
//   morale: Une phrase finale ou un proverbe.
//   ---
//   Texte de la page 1 (70 à 170 mots)
//   ---
//   Texte de la page 2
//   ...
const fs = require('fs');
const path = require('path');

const dir = __dirname;
const problems = [];
const warnings = [];

const DECORS = ['baobab', 'savane', 'village', 'foret', 'fleuve', 'desert', 'montagne'];
const LIGHTS = ['aube', 'midi', 'crepuscule', 'nuit', 'orage'];
const FIGURES = ['lievre', 'hyene', 'araignee', 'lion', 'tortue', 'elephant', 'oiseau', 'singe', 'crocodile', 'serpent', 'enfant', 'ancien', 'reine', 'guerrier', 'griot', 'tambour', 'masque', 'calebasse', 'pirogue', 'feu'];
const TAGS = ['Fin surprenante', 'Rire', 'Sagesse', 'Frisson', 'Légende', 'Amour', 'Mythe', 'Ruse', 'Histoire'];
const REGIONS = ["Afrique de l'Ouest", 'Afrique centrale', "Afrique de l'Est", 'Afrique australe', 'Afrique du Nord'];
const KINDS = ['court', 'long', 'chapitre'];
const CHUNK = 40;

const words = (t) => t.trim().split(/\s+/).filter(Boolean).length;

function parseRecueil(file) {
  const id = path.basename(file, '.txt');
  const text = fs.readFileSync(file, 'utf8').replace(/\r/g, '');
  const parts = text.split(/^=== conte:\s*/m);
  const head = parts.shift();
  const rec = { id, title: '', category: '', description: '', order: 99, price: undefined, stories: [] };
  head.split('\n').forEach((raw) => {
    const m = /^(recueil|categorie|description|ordre|prix):\s*(.*)$/.exec(raw.trim());
    if (!m) return;
    if (m[1] === 'recueil') rec.title = m[2].trim();
    else if (m[1] === 'categorie') rec.category = m[2].trim();
    else if (m[1] === 'description') rec.description = m[2].trim();
    else if (m[1] === 'ordre') rec.order = Number(m[2]);
    else if (m[1] === 'prix') rec.price = Number(m[2]);
  });
  if (!rec.title) problems.push(`${id} : « recueil: » manquant`);
  if (!rec.category) problems.push(`${id} : « categorie: » manquante`);
  parts.forEach((block) => {
    const lines = block.split('\n');
    const sid = lines.shift().trim();
    const st = { id: sid, recueil: id, pages: [], title: '', hook: '', tag: '', origin: '', region: '', kind: 'court', free: 2, decor: 'savane', light: 'crepuscule', figures: [], morale: '' };
    let page = null;
    let inBody = false;
    lines.forEach((raw) => {
      const line = raw.trimEnd();
      if (line.trim() === '---') {
        if (page !== null && page.trim()) st.pages.push(page.trim());
        page = '';
        inBody = true;
        return;
      }
      if (!inBody) {
        const m = /^(titre|accroche|etiquette|origine|region|type|gratuites|decor|lumiere|figures|morale):\s*(.*)$/.exec(line.trim());
        if (!m) { if (line.trim()) problems.push(`${sid} : ligne d'en-tête inconnue « ${line.slice(0, 40)} »`); return; }
        const v = m[2].trim();
        if (m[1] === 'titre') st.title = v;
        else if (m[1] === 'accroche') st.hook = v;
        else if (m[1] === 'etiquette') st.tag = v;
        else if (m[1] === 'origine') st.origin = v;
        else if (m[1] === 'region') st.region = v;
        else if (m[1] === 'type') st.kind = v;
        else if (m[1] === 'gratuites') st.free = Number(v);
        else if (m[1] === 'decor') st.decor = v;
        else if (m[1] === 'lumiere') st.light = v;
        else if (m[1] === 'figures') st.figures = v.split(',').map((x) => x.trim()).filter(Boolean);
        else if (m[1] === 'morale') st.morale = v;
      } else {
        page += (page ? '\n' : '') + line;
      }
    });
    if (page !== null && page.trim()) st.pages.push(page.trim());
    rec.stories.push(st);
  });
  return rec;
}

const files = fs.readdirSync(path.join(dir, 'recueils')).filter((f) => f.endsWith('.txt')).sort();
const recueils = files.map((f) => parseRecueil(path.join(dir, 'recueils', f)));
recueils.sort((a, b) => a.order - b.order || a.id.localeCompare(b.id));

const seenIds = new Set();
const seenTitles = new Set();
let totalWords = 0;
recueils.forEach((r) => {
  if (r.stories.length === 0) problems.push(`${r.id} : aucun conte`);
  r.stories.forEach((s, i) => {
    const w = s.id;
    if (!/^[a-z0-9-]{3,40}$/.test(s.id)) problems.push(`${w} : identifiant invalide (a-z, 0-9, tirets)`);
    if (seenIds.has(s.id)) problems.push(`${w} : identifiant en double`);
    seenIds.add(s.id);
    if (!s.title) problems.push(`${w} : titre manquant`);
    if (s.title.length > 70) problems.push(`${w} : titre trop long (${s.title.length} > 70)`);
    if (seenTitles.has(s.title.toLowerCase())) problems.push(`${w} : titre en double`);
    seenTitles.add(s.title.toLowerCase());
    if (!s.hook) problems.push(`${w} : accroche manquante`);
    if (s.hook.length > 140) problems.push(`${w} : accroche trop longue (${s.hook.length} > 140)`);
    if (!TAGS.includes(s.tag)) problems.push(`${w} : étiquette inconnue « ${s.tag} »`);
    if (!s.origin) problems.push(`${w} : origine manquante`);
    if (!REGIONS.includes(s.region)) problems.push(`${w} : région inconnue « ${s.region} »`);
    if (!KINDS.includes(s.kind)) problems.push(`${w} : type inconnu « ${s.kind} »`);
    if (!DECORS.includes(s.decor)) problems.push(`${w} : décor inconnu « ${s.decor} »`);
    if (!LIGHTS.includes(s.light)) problems.push(`${w} : lumière inconnue « ${s.light} »`);
    if (s.figures.length === 0 || s.figures.length > 3) problems.push(`${w} : 1 à 3 figures`);
    s.figures.forEach((f) => { if (!FIGURES.includes(f)) problems.push(`${w} : figure inconnue « ${f} »`); });
    if (s.pages.length < 4 || s.pages.length > 8) problems.push(`${w} : ${s.pages.length} pages (4 à 8)`);
    if (!(s.free >= 1 && s.free < s.pages.length)) problems.push(`${w} : gratuites doit être entre 1 et ${s.pages.length - 1}`);
    let sw = 0;
    s.pages.forEach((p, k) => {
      const n = words(p);
      sw += n;
      if (n < 60) problems.push(`${w} p.${k + 1} : ${n} mots (60 mini)`);
      if (n > 190) problems.push(`${w} p.${k + 1} : ${n} mots (190 maxi)`);
    });
    s.words = sw;
    s.minutes = Math.max(2, Math.round(sw / 180));
    totalWords += sw;
    if (i === 0) s.kind = 'gratuit'; // le premier conte de chaque recueil est gratuit
    if (!s.morale) warnings.push(`${w} : pas de morale`);
  });
});

// ── Sorties ─────────────────────────────────────────────────────────────────
let seed = 0;
const stories = [];
recueils.forEach((r) => r.stories.forEach((s, i) => stories.push({ ...s, order: stories.length + 1, first: i === 0, seed: (seed += 7919) })));
stories.forEach((s, i) => { s.chunk = Math.floor(i / CHUNK); });
const card = (s) => ({
  id: s.id, t: s.title, h: s.hook, c: s.recueil, tag: s.tag, org: s.origin, rg: s.region, m: s.minutes, p: s.pages.length,
  f: s.free, k: s.kind, o: s.order, feat: false, active: true,
  sc: { d: s.decor, l: s.light, f: s.figures, s: s.seed },
});
const meta = {
  collections: recueils.map((r) => ({
    id: r.id, title: r.title, category: r.category, desc: r.description, order: r.order, count: r.stories.length,
    ...(r.price ? { price: r.price } : {}),
    sc: (() => { const s = stories.find((x) => x.recueil === r.id); return { d: s.decor, l: s.light, f: s.figures, s: s.seed }; })(),
  })),
  chunks: Math.ceil(stories.length / CHUNK),
  dailyPool: stories.map((s) => s.id),
  updatedAt: Date.now(),
};

console.log(`${recueils.length} recueils, ${stories.length} contes, ${totalWords} mots (~${Math.round(totalWords / Math.max(1, stories.length))} par conte)`);
if (warnings.length) console.log(`${warnings.length} avertissement(s) :\n  ` + warnings.slice(0, 20).join('\n  '));
if (problems.length) {
  console.error(`${problems.length} problème(s) :\n  ` + problems.slice(0, 80).join('\n  '));
  process.exit(1);
}
fs.mkdirSync(path.join(dir, 'out'), { recursive: true });
fs.writeFileSync(path.join(dir, 'out', 'meta.json'), JSON.stringify(meta, null, 1));
fs.writeFileSync(path.join(dir, 'out', 'stories.json'), JSON.stringify(stories.map((s) => ({ ...card(s), pages: s.pages, morale: s.morale })), null, 1));

if (process.argv.includes('--upload')) {
  const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));
  admin.initializeApp({ credential: admin.credential.cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)), projectId: 'afrolooki' });
  const db = admin.firestore();
  (async () => {
    // garde les réglages faits depuis l'admin (masqué, à la une, prix) si le conte existe déjà
    const existing = {};
    (await db.collection('ContesStories').get()).docs.forEach((d) => { existing[d.id] = d.data(); });
    let batch = db.batch();
    let n = 0;
    const flush = async () => { if (n > 0) { await batch.commit(); batch = db.batch(); n = 0; } };
    const chunks = [];
    for (const s of stories) {
      const old = existing[s.id] || {};
      const c = card(s);
      if (typeof old.active === 'boolean') c.active = old.active;
      if (typeof old.featured === 'boolean') c.feat = old.featured;
      if (typeof old.price === 'number') c.pr = old.price;
      (chunks[s.chunk] = chunks[s.chunk] || []).push(c);
      batch.set(db.collection('ContesStories').doc(s.id), {
        ...c, title: s.title, collectionId: s.recueil, kind: s.kind, free: s.free, pages: s.pages.length, chunk: s.chunk,
        featured: c.feat, ...(typeof old.price === 'number' ? { price: old.price } : {}), updatedAt: Date.now(),
      });
      batch.set(db.collection('ContesText').doc(s.id), { pages: s.pages, morale: s.morale, updatedAt: Date.now() });
      n += 2;
      if (n >= 400) await flush();
    }
    chunks.forEach((cards, i) => { batch.set(db.collection('ContesIndex').doc(`c${i}`), { cards }); n++; });
    batch.set(db.collection('ContesIndex').doc('meta'), meta);
    n++;
    await flush();
    const cfgRef = db.collection('AppConfig').doc('contes');
    if (!(await cfgRef.get()).exists) await cfgRef.set({ enabled: true, updatedAt: Date.now() });
    console.log(`Envoyé : ${stories.length} contes, ${chunks.length} bloc(s) d'index.`);
  })().catch((e) => { console.error(e); process.exit(1); });
}
