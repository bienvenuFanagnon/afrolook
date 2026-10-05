// Assemble les 1 000 questions (tools/quiz/questions/*.json) en 200 niveaux de 5 questions
// et contrôle leur qualité. Sortie : tools/quiz/levels.json (importé ensuite par upload_levels.js).
//
// Organisation : 8 thèmes × 5 paliers de difficulté × 25 questions.
//   unité u (0..39) = palier (u div 8) + thème (u mod 8) ; chaque unité a 5 niveaux de 5 questions.
//   niveau n (1..200) : unité = (n-1) div 5, rang dans l'unité = (n-1) mod 5.
// Usage : node build_levels.js
const fs = require('fs');
const path = require('path');

const THEMES = ['courage', 'oeuvres', 'musique', 'football', 'histoire', 'geographie', 'culture', 'sciences'];
const FILES = ['01_courage', '02_oeuvres', '03_musique', '04_football', '05_histoire', '06_geographie', '07_culture', '08_sciences'];
const PER_THEME = 125;
const QUESTIONS_PER_LEVEL = 5;

// Mélange reproductible (mulberry32) : la bonne réponse n'est pas toujours à la même place.
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

const problems = [];
const seenQuestions = new Map();
const perTheme = [];

FILES.forEach((f, ti) => {
  const items = JSON.parse(fs.readFileSync(path.join(__dirname, 'questions', `${f}.json`), 'utf8'));
  if (items.length !== PER_THEME) problems.push(`${f} : ${items.length} questions au lieu de ${PER_THEME}`);
  items.forEach((it, i) => {
    const where = `${f} #${i + 1}`;
    const opts = [it.c, ...(it.w || [])];
    if (!it.q || !it.c || !Array.isArray(it.w) || it.w.length !== 3 || !it.e) problems.push(`${where} : champs manquants`);
    if (new Set(opts.map((o) => String(o).trim().toLowerCase())).size !== 4) problems.push(`${where} : réponses en double`);
    if (it.q.length > 230) problems.push(`${where} : question trop longue (${it.q.length})`);
    if (opts.some((o) => String(o).length > 70)) problems.push(`${where} : réponse trop longue`);
    if (it.e.length > 170) problems.push(`${where} : explication trop longue (${it.e.length})`);
    const key = it.q.trim().toLowerCase();
    if (seenQuestions.has(key)) problems.push(`${where} : question en double avec ${seenQuestions.get(key)}`);
    seenQuestions.set(key, where);
  });
  perTheme.push(items);
});

if (problems.length) {
  console.error('PROBLÈMES :\n' + problems.join('\n'));
  process.exit(1);
}

const levels = [];
const positions = [0, 0, 0, 0];
for (let n = 1; n <= 200; n++) {
  const unit = Math.floor((n - 1) / 5); // 0..39
  const rank = (n - 1) % 5;
  const tier = Math.floor(unit / 8);
  const ti = unit % 8;
  const base = tier * 25 + rank * 5;
  const questions = perTheme[ti].slice(base, base + QUESTIONS_PER_LEVEL).map((it, k) => {
    const rand = rng(n * 1000 + k * 7 + 13);
    const opts = [it.c, ...it.w];
    for (let i = opts.length - 1; i > 0; i--) {
      const j = Math.floor(rand() * (i + 1));
      [opts[i], opts[j]] = [opts[j], opts[i]];
    }
    const a = opts.indexOf(it.c);
    positions[a]++;
    return { q: it.q, o: opts, a, e: it.e };
  });
  levels.push({ n, unit: unit + 1, tier: tier + 1, theme: THEMES[ti], questions });
}

fs.writeFileSync(path.join(__dirname, 'levels.json'), JSON.stringify(levels));
console.log(`OK : ${levels.length} niveaux, ${levels.length * QUESTIONS_PER_LEVEL} questions.`);
console.log('Position de la bonne réponse (A,B,C,D) :', positions.join(', '));
