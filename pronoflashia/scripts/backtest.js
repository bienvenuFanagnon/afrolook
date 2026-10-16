'use strict';
// Jugement du moteur sur de vrais matchs passés (walk-forward : à chaque match, seul le passé est connu).
// Compare l'ancien calcul (buts des 20 derniers matchs de la saison) aux notes d'équipes (engine/ratings.js) sur 5 championnats.
// Données : openfootball (domaine public, https://github.com/openfootball/football.json), téléchargées à chaque exécution.
// Usage : node scripts/backtest.js [saison, ex. 2023-24]   (la saison précédente sert d'historique)
const { backtest, isActive } = require('../functions/src/engine/ratings');

const LEAGUES = { 'en.1': 'Premier League', 'es.1': 'LaLiga', 'de.1': 'Bundesliga', 'it.1': 'Serie A', 'fr.1': 'Ligue 1' };
const season = process.argv[2] || '2023-24';
const [y] = season.split('-').map(Number);
const prevSeason = `${y - 1}-${String(y).slice(2)}`;
const URL = (s, lg) => `https://raw.githubusercontent.com/openfootball/football.json/master/${s}/${lg}.json`;

async function load(s, lg) {
  const res = await fetch(URL(s, lg));
  if (!res.ok) throw new Error(`${s}/${lg} : HTTP ${res.status}`);
  const j = await res.json();
  return j.matches.filter((m) => m.score && m.score.ft).map((m) => ({ t: Date.parse(`${m.date}T${m.time || '15:00'}:00Z`), h: m.team1, a: m.team2, gh: m.score.ft[0], ga: m.score.ft[1] }));
}

(async () => {
  let N = 0, G = 0, P = 0;
  console.log(`Saison ${season} (historique : ${prevSeason}) — gain > 0 : les notes expliquent mieux les buts ; RPS < 0 : meilleures probabilités 1N2\n`);
  for (const [lg, nom] of Object.entries(LEAGUES)) {
    const r = backtest(await load(prevSeason, lg), await load(season, lg));
    N += r.n; G += r.gain * r.n; P += r.rps * r.n;
    console.log(`${nom.padEnd(16)} matchs jugés ${String(r.n).padStart(4)}   gain ${r.gain >= 0 ? '+' : ''}${r.gain.toFixed(4)}   RPS ${r.rps >= 0 ? '+' : ''}${r.rps.toFixed(4)}   ${isActive(r) ? 'notes utilisées' : 'ancien calcul conservé'}`);
  }
  console.log(`\nEnsemble : ${N} matchs, gain moyen ${(G / N >= 0 ? '+' : '') + (G / N).toFixed(4)} par match, RPS ${(P / N >= 0 ? '+' : '') + (P / N).toFixed(4)}`);
})().catch((e) => { console.error(e.message); process.exit(1); });
