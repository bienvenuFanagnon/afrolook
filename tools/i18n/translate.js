// Traduction du contenu d'Afrolook (contes, quiz, étude) : faite UNE SEULE FOIS, gardée dans un cache, puis envoyée avec le contenu.
// Aucun appel de traduction n'est fait quand un lecteur ouvre l'application : le coût est celui de cette construction, rien d'autre.
//
//   node translate.js --source contes --lang en --estimate        compte les caractères à traduire et chiffre le coût
//   node translate.js --source contes --lang en --run             traduit ce qui manque (le cache évite de payer deux fois)
//   node translate.js --source quiz   --lang en --run --limit 200 essai sur 200 textes
//   node translate.js --source etude  --lang en --show 5          montre 5 traductions déjà faites
//
// Sources :
//   contes : tools/contes/out/stories.json (lancer d'abord `node tools/contes/build_contes.js`)
//   quiz   : tools/quiz/questions/*.json   (q, c, w[], e)
//   etude  : tools/etude/content/*.txt     (titre, fiche, questions)
// Cache : tools/i18n/cache/<source>.<langue>.json  { "<sha1 du texte français>": { "s": "texte français", "t": "traduction" } }
//   Le cache est modifiable à la main : une correction y est reprise telle quelle aux envois suivants.
// Noms propres : tools/i18n/glossary.json (protégés de la traduction).
// Tarif Google Cloud Translation (v2) : 20 $ par million de caractères, 500 000 gratuits par mois.
//
// Identifiants : GOOGLE_APPLICATION_CREDENTIALS=<clé du compte de service du projet afrolooki>
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const argv = process.argv.slice(2);
const opt = (name, def) => { const i = argv.indexOf('--' + name); return i < 0 ? def : (argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : true); };
const source = opt('source', '');
const lang = opt('lang', 'en');
const limit = Number(opt('limit', 0)) || Infinity;
const root = path.join(__dirname, '..');
const cacheFile = path.join(__dirname, 'cache', `${source}.${lang}.json`);
const sha = (t) => crypto.createHash('sha1').update(t).digest('hex');

// ── Extraction des textes français ───────────────────────────────────────────
function unitsContes() {
  const f = path.join(root, 'contes', 'out', 'stories.json');
  if (!fs.existsSync(f)) throw new Error('Lancer d\'abord : node tools/contes/build_contes.js');
  const out = [];
  for (const s of JSON.parse(fs.readFileSync(f, 'utf8'))) {
    out.push(s.t, s.h, s.org);
    if (s.morale) out.push(s.morale);
    out.push(...s.pages);
  }
  return out;
}

function unitsQuiz() {
  const dir = path.join(root, 'quiz', 'questions');
  const out = [];
  for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.json'))) {
    const d = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    const items = Array.isArray(d) ? d : (d.questions || []);
    for (const q of items) {
      if (!q || typeof q !== 'object') continue;
      for (const k of ['q', 'c', 'e']) if (typeof q[k] === 'string') out.push(q[k]);
      for (const w of q.w || []) if (typeof w === 'string') out.push(w);
    }
  }
  return out;
}

function unitsEtude() {
  const dir = path.join(root, 'etude', 'content');
  const out = [];
  for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.txt'))) {
    let mode = '';
    for (const raw of fs.readFileSync(path.join(dir, f), 'utf8').split('\n')) {
      const line = raw.trim();
      if (!line || line.startsWith('#')) continue;
      if (line.startsWith('titre:')) { out.push(line.slice(6).trim()); continue; }
      if (line === '== fiche') { mode = 'fiche'; continue; }
      if (line === '== questions') { mode = 'q'; continue; }
      if (mode === 'fiche') {
        const m = /^(p|li|note):\s*(.+)$/.exec(line);
        if (m) out.push(m[2].trim());
      } else if (mode === 'q') {
        for (const part of line.split('||')) if (part.trim()) out.push(part.trim());
      }
    }
  }
  return out;
}

const SOURCES = { contes: unitsContes, quiz: unitsQuiz, etude: unitsEtude };
if (!SOURCES[source]) {
  console.error('Usage : node translate.js --source contes|quiz|etude --lang en (--estimate | --run [--limit N] | --show N)');
  process.exit(1);
}

const cache = fs.existsSync(cacheFile) ? JSON.parse(fs.readFileSync(cacheFile, 'utf8')) : {};
const saveCache = () => { fs.mkdirSync(path.dirname(cacheFile), { recursive: true }); fs.writeFileSync(cacheFile, JSON.stringify(cache, null, 0)); };

const all = SOURCES[source]().filter((t) => typeof t === 'string' && t.trim());
const unique = [...new Set(all)];
const todo = unique.filter((t) => !cache[sha(t)]);
const chars = (list) => list.reduce((a, t) => a + t.length, 0);

console.log(`${source} → ${lang} : ${all.length} textes (${unique.length} différents), ${unique.length - todo.length} déjà traduits, ${todo.length} à traduire`);
const costOf = (c) => Math.max(0, c) * 20 / 1e6;
console.log(`À traduire : ${chars(todo).toLocaleString('fr')} caractères ≈ ${costOf(chars(todo)).toFixed(2)} $ (${costOf(chars(todo) - 500000).toFixed(2)} $ si le quota gratuit mensuel de 500 000 caractères est encore entier)`);

if (opt('show', false)) {
  const n = Number(opt('show', 5)) || 5;
  Object.values(cache).slice(0, n).forEach((v) => console.log(`\nFR : ${v.s}\n${lang.toUpperCase()} : ${v.t}`));
}
if (!argv.includes('--run')) process.exit(0);

// ── Traduction (protège les noms propres) ────────────────────────────────────
const glossary = JSON.parse(fs.readFileSync(path.join(__dirname, 'glossary.json'), 'utf8')).names.sort((a, b) => b.length - a.length);
const nameRe = new RegExp(`(?<![\\p{L}\\p{N}])(${glossary.map((n) => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|')})(?![\\p{L}\\p{N}])`, 'gu');
const esc = (t) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const protect = (t) => esc(t).replace(nameRe, '<span class="notranslate">$1</span>');
const decode = (t) => t.replace(/<\/?span[^>]*>/g, '').replace(/&#39;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');

(async () => {
  const { v2 } = require(path.join(root, '..', 'functions', 'node_modules', '@google-cloud', 'translate'));
  const client = new v2.Translate({ projectId: 'afrolooki' });
  const queue = todo.slice(0, limit);
  let done = 0;
  let batch = [];
  let size = 0;
  const flush = async () => {
    if (!batch.length) return;
    let res;
    for (let attempt = 0; ; attempt++) {
      try { [res] = await client.translate(batch.map(protect), { from: 'fr', to: lang, format: 'html' }); break; }
      catch (e) { if (attempt >= 3) throw e; await new Promise((r) => setTimeout(r, 1500 * (attempt + 1))); }
    }
    batch.forEach((t, i) => { cache[sha(t)] = { s: t, t: decode(res[i]) }; });
    done += batch.length;
    saveCache();
    process.stdout.write(`\r${done}/${queue.length} traduits`);
    batch = []; size = 0;
  };
  for (const t of queue) {
    if (batch.length >= 100 || size + t.length > 20000) await flush();
    batch.push(t); size += t.length;
  }
  await flush();
  console.log(`\nTerminé : ${done} textes traduits (${chars(queue).toLocaleString('fr')} caractères). Cache : ${path.relative(root, cacheFile)}`);
})().catch((e) => { console.error('\nErreur :', e.message); process.exit(1); });
