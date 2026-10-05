// Assemble les questions (tools/quiz/questions/*.json) en niveaux de 5 questions, un jeu de 200 niveaux PAR RÉGION du joueur,
// et contrôle leur qualité. Sortie : tools/quiz/levels_{af,eu,as,am,mx}.json (importés ensuite par upload_levels.js).
//
// Questions :
//   - 01_… à 08_… : 125 questions par thème (5 difficultés de 25), région de chaque question dans regions.json
//     (A Afrique, E Europe, S Asie et Océanie, M Amériques, W monde).
//   - EU_NN_… / AS_NN_… / AM_NN_… : 75 questions par thème et par région (5 difficultés de 15), classées de la plus facile à la plus difficile.
// Organisation d'un jeu : 8 thèmes × 5 difficultés ; chaque unité (difficulté, thème) = 5 niveaux de 5 questions.
//   unité u (0..39) = difficulté (u div 8) + thème (u mod 8) ; niveau n (1..200) : unité = (n-1) div 5.
// Composition d'une unité pour un joueur de la région R : 15 questions de sa région, 5 « monde », 5 des autres régions.
// Jeu « mx » (pays inconnu) : le même nombre de chaque région (+ « monde »). Si un réservoir est trop petit, on complète avec les autres.
// Usage : node build_levels.js
const fs = require('fs');
const path = require('path');

const THEMES = ['courage', 'oeuvres', 'musique', 'football', 'histoire', 'geographie', 'culture', 'sciences'];
const FILES = ['01_courage', '02_oeuvres', '03_musique', '04_football', '05_histoire', '06_geographie', '07_culture', '08_sciences'];
const LETTER = { A: 'af', E: 'eu', S: 'as', M: 'am', W: 'world' };
const NEW_PREFIX = { EU: 'eu', AS: 'as', AM: 'am' };
const REGIONS = ['af', 'eu', 'as', 'am'];
const SETS = ['af', 'eu', 'as', 'am', 'mx'];
const QUESTIONS_PER_LEVEL = 5;
const PER_UNIT = 25;
const SHARE = { own: 15, world: 5, other: 5 };

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
const seen = new Map();
/** pool[ti][tier] = [{ it, region, d, id }] */
const pool = THEMES.map(() => [0, 1, 2, 3, 4].map(() => []));

function check(it, where) {
  const opts = [it.c, ...(it.w || [])];
  if (!it.q || !it.c || !Array.isArray(it.w) || it.w.length !== 3 || !it.e) problems.push(`${where} : champs manquants`);
  if (new Set(opts.map((o) => String(o).trim().toLowerCase())).size !== 4) problems.push(`${where} : réponses en double`);
  if (it.q && it.q.length > 230) problems.push(`${where} : question trop longue (${it.q.length})`);
  if (opts.some((o) => String(o).length > 70)) problems.push(`${where} : réponse trop longue`);
  if (it.e && it.e.length > 170) problems.push(`${where} : explication trop longue (${it.e.length})`);
  const key = String(it.q).trim().toLowerCase();
  if (seen.has(key)) problems.push(`${where} : question en double avec ${seen.get(key)}`);
  seen.set(key, where);
}

const regions = JSON.parse(fs.readFileSync(path.join(__dirname, 'questions', 'regions.json'), 'utf8'));
FILES.forEach((f, ti) => {
  const items = JSON.parse(fs.readFileSync(path.join(__dirname, 'questions', `${f}.json`), 'utf8'));
  if (items.length !== 125) problems.push(`${f} : ${items.length} questions au lieu de 125`);
  const tags = regions[f] || '';
  if (tags.length !== items.length) problems.push(`${f} : ${tags.length} étiquettes de région pour ${items.length} questions`);
  items.forEach((it, i) => {
    check(it, `${f} #${i + 1}`);
    const region = LETTER[tags[i]];
    if (!region) problems.push(`${f} #${i + 1} : région inconnue « ${tags[i]} »`);
    pool[ti][Math.floor(i / 25)].push({ it, region, d: (i % 25) / 25, id: `${f}#${i + 1}` });
  });
});
for (const [prefix, region] of Object.entries(NEW_PREFIX)) {
  FILES.forEach((f, ti) => {
    const file = path.join(__dirname, 'questions', `${prefix}_${f}.json`);
    if (!fs.existsSync(file)) return;
    const items = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (items.length % 5 !== 0 || items.length > 100) problems.push(`${prefix}_${f} : ${items.length} questions (multiple de 5, 100 au maximum)`);
    const per = items.length / 5;
    items.forEach((it, i) => {
      check(it, `${prefix}_${f} #${i + 1}`);
      pool[ti][Math.floor(i / per)].push({ it, region, d: (i % per) / per, id: `${prefix}_${f}#${i + 1}` });
    });
  });
}
if (problems.length) {
  console.error('PROBLÈMES :\n' + problems.join('\n'));
  process.exit(1);
}

/** Prend k éléments répartis sur toute la difficulté (liste triée par d). */
function spread(list, k) {
  if (k <= 0 || !list.length) return [];
  if (k >= list.length) return list.slice();
  const out = [];
  for (let i = 0; i < k; i++) out.push(list[Math.round((i * (list.length - 1)) / Math.max(1, k - 1))]);
  return out;
}
const byD = (a, b) => a.d - b.d || (a.id < b.id ? -1 : 1);

/** Les 25 questions d'une unité pour un jeu donné, de la plus facile à la plus difficile. */
function compose(set, ti, tier) {
  const all = pool[ti][tier];
  const used = new Set();
  const take = (list, k) => {
    const free = list.filter((x) => !used.has(x.id)).sort(byD);
    const got = spread(free, k);
    got.forEach((x) => used.add(x.id));
    return got;
  };
  const chosen = [];
  const world = all.filter((x) => x.region === 'world');
  if (set === 'mx') {
    const each = 5;
    REGIONS.forEach((r) => chosen.push(...take(all.filter((x) => x.region === r), each)));
    chosen.push(...take(world, 5));
  } else {
    chosen.push(...take(all.filter((x) => x.region === set), SHARE.own));
    chosen.push(...take(world, SHARE.world));
    chosen.push(...take(all.filter((x) => x.region !== set && x.region !== 'world'), SHARE.other));
  }
  // Complète si un réservoir était trop petit : d'abord la région du jeu, puis le monde, puis le reste
  const order = (x) => (x.region === set ? 0 : x.region === 'world' ? 1 : 2);
  const rest = all.filter((x) => !used.has(x.id)).sort((a, b) => order(a) - order(b) || byD(a, b));
  while (chosen.length < PER_UNIT && rest.length) {
    const x = rest.shift();
    used.add(x.id);
    chosen.push(x);
  }
  if (chosen.length < PER_UNIT) throw new Error(`jeu ${set}, thème ${THEMES[ti]}, difficulté ${tier + 1} : ${chosen.length} questions seulement`);
  return chosen.slice(0, PER_UNIT).sort(byD);
}

const report = [];
for (const set of SETS) {
  const levels = [];
  const positions = [0, 0, 0, 0];
  const mix = { own: 0, world: 0, other: 0 };
  for (let u = 0; u < 40; u++) {
    const tier = Math.floor(u / 8);
    const ti = u % 8;
    const unit = compose(set, ti, tier);
    for (let rank = 0; rank < 5; rank++) {
      const n = u * 5 + rank + 1;
      const questions = unit.slice(rank * 5, rank * 5 + 5).map((x, k) => {
        if (x.region === set) mix.own++;
        else if (x.region === 'world') mix.world++;
        else mix.other++;
        const rand = rng(n * 1000 + k * 7 + 13);
        const opts = [x.it.c, ...x.it.w];
        for (let i = opts.length - 1; i > 0; i--) {
          const j = Math.floor(rand() * (i + 1));
          [opts[i], opts[j]] = [opts[j], opts[i]];
        }
        const a = opts.indexOf(x.it.c);
        positions[a]++;
        return { q: x.it.q, o: opts, a, e: x.it.e };
      });
      levels.push({ n, unit: u + 1, tier: tier + 1, theme: THEMES[ti], region: set, questions });
    }
  }
  fs.writeFileSync(path.join(__dirname, `levels_${set}.json`), JSON.stringify(levels));
  const total = levels.length * QUESTIONS_PER_LEVEL;
  report.push(`${set} : ${levels.length} niveaux, ${total} questions — ${Math.round((mix.own * 100) / total)} % de sa région, ${Math.round((mix.world * 100) / total)} % monde, ${Math.round((mix.other * 100) / total)} % autres régions ; bonne réponse A,B,C,D : ${positions.join(', ')}`);
}
console.log('OK');
console.log(report.join('\n'));
