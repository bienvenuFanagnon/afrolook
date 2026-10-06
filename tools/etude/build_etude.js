// Assemble le catalogue et le contenu d'Afrolook Étude, les contrôle, puis (avec --upload) les envoie dans Firestore.
//   node build_etude.js            : contrôle et écrit tools/etude/out/ (catalog_*.json, content_*.json)
//   GOOGLE_APPLICATION_CREDENTIALS=... node build_etude.js --upload
//
// structure.json décrit les parcours (classes → matières → chapitres). Un chapitre n'existe dans le catalogue que si
// tools/etude/content/<id>.txt est présent. Format d'un chapitre :
//   titre: Les variables
//   == fiche
//   p: un paragraphe
//   li: un point de liste
//   note: une formule, un exemple, une remarque
//   == questions
//   question || bonne réponse || faux 1 || faux 2 || faux 3 || explication      (15 lignes : 3 niveaux de 5, du plus facile au plus dur)
// Le premier chapitre de chaque matière est gratuit.
const fs = require('fs');
const path = require('path');

const dir = __dirname;
const structure = JSON.parse(fs.readFileSync(path.join(dir, 'structure.json'), 'utf8'));
const problems = [];
const warnings = [];
const LEVELS = 3;
const PER_LEVEL = 5;

function parseChapter(id, text) {
  const out = { id, title: '', lesson: [], questions: [] };
  let mode = '';
  text.split('\n').forEach((raw, n) => {
    const line = raw.trim();
    if (!line || line.startsWith('#')) return;
    const where = `${id}:${n + 1}`;
    if (line.startsWith('titre:')) { out.title = line.slice(6).trim(); return; }
    if (line === '== fiche') { mode = 'fiche'; return; }
    if (line === '== questions') { mode = 'q'; return; }
    if (mode === 'fiche') {
      const m = /^(p|li|note):\s*(.+)$/.exec(line);
      if (!m) { problems.push(`${where} : ligne de fiche inconnue`); return; }
      out.lesson.push({ t: m[1], x: m[2].trim() });
    } else if (mode === 'q') {
      const p = line.split('||').map((x) => x.trim());
      if (p.length !== 6) { problems.push(`${where} : ${p.length} champs au lieu de 6`); return; }
      out.questions.push({ q: p[0], c: p[1], w: p.slice(2, 5), e: p[5], where });
    } else problems.push(`${where} : ligne hors section`);
  });
  return out;
}

const seen = new Map();
function checkQuestion(x) {
  const opts = [x.c, ...x.w];
  if (new Set(opts.map((o) => o.toLowerCase())).size !== 4) problems.push(`${x.where} : réponses en double`);
  if (x.q.length > 260) problems.push(`${x.where} : question trop longue (${x.q.length})`);
  if (opts.some((o) => o.length > 80)) problems.push(`${x.where} : réponse trop longue`);
  if (x.e.length > 200) problems.push(`${x.where} : explication trop longue (${x.e.length})`);
  const k = x.q.toLowerCase();
  if (seen.has(k)) problems.push(`${x.where} : question déjà posée en ${seen.get(k)}`);
  seen.set(k, x.where);
}

// Mélange reproductible : la bonne réponse n'est pas toujours à la même place
function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function hash(s) { let h = 7; for (const ch of s) h = (h * 31 + ch.charCodeAt(0)) >>> 0; return h; }

const catalogs = [];
const contents = [];
const positions = [0, 0, 0, 0];
for (const track of structure.tracks) {
  const cat = { id: track.id, kind: track.kind, title: track.title, order: track.order, classes: [] };
  if (track.country) cat.country = track.country;
  if (track.after) cat.after = track.after;
  if (track.exam) cat.exam = track.exam;
  if (track.cert) cat.cert = track.cert;
  if (track.featured) { cat.featured = track.featured; cat.badge = track.badge || ''; cat.pitch = track.pitch || ''; }
  for (const cls of track.classes) {
    const c = { id: cls.id, title: cls.title, subjects: [] };
    for (const sub of cls.subjects) {
      const s = { id: sub.id, title: sub.title, icon: sub.icon, chapters: [] };
      for (const chap of sub.chapters) {
        const file = path.join(dir, 'content', `${chap.id}.txt`);
        if (!fs.existsSync(file)) { warnings.push(`${chap.id} : pas encore rédigé`); continue; }
        const ch = parseChapter(chap.id, fs.readFileSync(file, 'utf8'));
        if (!ch.title) ch.title = chap.title;
        if (ch.questions.length !== LEVELS * PER_LEVEL) problems.push(`${chap.id} : ${ch.questions.length} questions au lieu de ${LEVELS * PER_LEVEL}`);
        if (ch.lesson.length < 4) problems.push(`${chap.id} : fiche trop courte`);
        ch.questions.forEach(checkQuestion);
        const levels = [];
        for (let l = 0; l < LEVELS; l++) {
          levels.push({ questions: ch.questions.slice(l * PER_LEVEL, (l + 1) * PER_LEVEL).map((x, k) => {
            const rand = rng(hash(`${chap.id}${l}${k}`));
            const opts = [x.c, ...x.w];
            for (let i = opts.length - 1; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [opts[i], opts[j]] = [opts[j], opts[i]]; }
            const a = opts.indexOf(x.c);
            positions[a]++;
            return { q: x.q, o: opts, a, e: x.e };
          }) });
        }
        contents.push({ id: chap.id, title: ch.title, lesson: ch.lesson, levels });
        s.chapters.push({ id: chap.id, title: ch.title, levels: LEVELS, ...(s.chapters.length === 0 ? { free: true } : {}) });
      }
      if (s.chapters.length) c.subjects.push(s);
    }
    cat.classes.push(c);
  }
  // une attestation ne peut pas citer un chapitre absent
  if (track.cert) {
    const all = new Set(structure.tracks.flatMap((t) => t.classes.flatMap((x) => x.subjects.flatMap((y) => y.chapters.map((z) => z.id)))));
    track.cert.from.forEach((id) => { if (!all.has(id)) problems.push(`${track.id} : chapitre inconnu « ${id} » dans l'attestation`); });
  }
  catalogs.push(cat);
}

if (problems.length) {
  console.error('PROBLÈMES :\n' + problems.join('\n'));
  process.exit(1);
}
fs.mkdirSync(path.join(dir, 'out'), { recursive: true });
catalogs.forEach((c) => fs.writeFileSync(path.join(dir, 'out', `catalog_${c.id}.json`), JSON.stringify(c)));
contents.forEach((c) => fs.writeFileSync(path.join(dir, 'out', `content_${c.id}.json`), JSON.stringify(c)));
console.log(`OK : ${catalogs.length} parcours, ${contents.length} chapitres, ${contents.length * LEVELS * PER_LEVEL} questions ; bonne réponse A,B,C,D : ${positions.join(', ')}`);
if (warnings.length && process.argv.includes('--warn')) console.log(warnings.join('\n'));

if (process.argv.includes('--upload')) {
  const admin = require('../../functions/node_modules/firebase-admin');
  admin.initializeApp({ credential: admin.credential.cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)), projectId: 'afrolooki' });
  (async () => {
    const db = admin.firestore();
    for (const c of catalogs) await db.collection('EtudeCatalog').doc(c.id).set(c);
    for (const c of contents) await db.collection('EtudeContent').doc(c.id).set(c);
    console.log('Importé dans Firestore.');
  })().catch((e) => { console.error(e); process.exit(1); });
}
