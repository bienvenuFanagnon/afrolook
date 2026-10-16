'use strict';
// Jugement du moteur sur de vrais matchs passés (walk-forward : à chaque match, seul le passé est connu).
// Compare l'ancien calcul (buts des 20 derniers matchs de la saison) aux notes d'équipes (engine/ratings.js) sur 5 championnats.
// Données : openfootball (domaine public, https://github.com/openfootball/football.json), téléchargées à chaque exécution.
// Usage : node scripts/backtest.js [saison, ex. 2023-24] [--calibration]   (la saison précédente sert d'historique)
// --calibration : probabilité annoncée du pronostic 1N2 contre taux réel de réussite, par tranche et selon le nombre de matchs joués.
const { backtest, isActive } = require('../functions/src/engine/ratings');

const LEAGUES = { 'en.1': 'Premier League', 'es.1': 'LaLiga', 'de.1': 'Bundesliga', 'it.1': 'Serie A', 'fr.1': 'Ligue 1' };
const season = process.argv.find((a) => /^\d{4}-\d{2}$/.test(a)) || '2023-24';
const CALIB = process.argv.includes('--calibration');
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
  const rows = [];
  console.log(`Saison ${season} (historique : ${prevSeason}) — gain > 0 : les notes expliquent mieux les buts ; RPS < 0 : meilleures probabilités 1N2\n`);
  for (const [lg, nom] of Object.entries(LEAGUES)) {
    const r = backtest(await load(prevSeason, lg), await load(season, lg), CALIB ? { collect: rows } : {});
    N += r.n; G += r.gain * r.n; P += r.rps * r.n;
    console.log(`${nom.padEnd(16)} matchs jugés ${String(r.n).padStart(4)}   gain ${r.gain >= 0 ? '+' : ''}${r.gain.toFixed(4)}   RPS ${r.rps >= 0 ? '+' : ''}${r.rps.toFixed(4)}   ${isActive(r) ? 'notes utilisées' : 'ancien calcul conservé'}`);
  }
  console.log(`\nEnsemble : ${N} matchs, gain moyen ${(G / N >= 0 ? '+' : '') + (G / N).toFixed(4)} par match, RPS ${(P / N >= 0 ? '+' : '') + (P / N).toFixed(4)}`);
  if (CALIB) {
    const show = (label, key, edges) => {
      console.log(`\n${label}`);
      for (let i = 0; i < edges.length - 1; i++) {
        const sub = rows.filter((r) => r[key] >= edges[i] && r[key] < edges[i + 1]);
        if (sub.length < 30) continue;
        const hit = sub.reduce((s, r) => s + r.hit, 0) / sub.length, pm = sub.reduce((s, r) => s + r.pmax, 0) / sub.length;
        console.log(`  [${edges[i]}, ${edges[i + 1]})  n=${String(sub.length).padStart(4)}  annoncé ${(pm * 100).toFixed(1)} %  réel ${(hit * 100).toFixed(1)} %  écart ${((hit - pm) * 100).toFixed(1)}`);
      }
    };
    show('Par probabilité annoncée du pronostic', 'pmax', [0, 0.4, 0.45, 0.5, 0.55, 0.6, 0.7, 1.01]);
    show('Par nombre de matchs joués (plus petit des deux clubs)', 'nmin', [5, 8, 12, 20, 40]);
  }
})().catch((e) => { console.error(e.message); process.exit(1); });
