'use strict';
// Comptage approximatif de visiteurs uniques (HyperLogLog) : on ne conserve que de petits tableaux de nombres,
// jamais d'identifiant. 16 fragments × 64 registres : erreur d'environ 3 %.

const crypto = require('crypto');

const SHARDS = 16;
const M = 64;
const ALPHA = 0.709; // constante de correction pour 64 registres

/** Empreinte salée (sel du jour, jamais conservé avec les données) → { shard, idx, rank }. */
function fingerprint(salt, day, ip, ua) {
  const d = crypto.createHmac('sha256', salt).update(`${day}|${ip}|${ua}`).digest();
  const shard = d[0] & (SHARDS - 1);
  const idx = d[1] & (M - 1);
  // 48 bits restants : rang = nombre de zéros en tête + 1
  let rank = 1;
  outer: for (let i = 2; i < 8; i++) {
    for (let b = 7; b >= 0; b--) {
      if ((d[i] >> b) & 1) break outer;
      rank++;
    }
  }
  return { shard, idx, rank };
}

const emptyRegisters = () => new Array(M).fill(0);

/** Met à jour un fragment : renvoie les nouveaux registres. */
function addToRegisters(reg, idx, rank) {
  const r = reg && reg.length === M ? reg.slice() : emptyRegisters();
  if (rank > r[idx]) r[idx] = rank;
  return r;
}

/** Estimation du nombre d'éléments distincts d'un fragment. */
function estimate(reg) {
  if (!reg || !reg.length) return 0;
  let sum = 0, zeros = 0;
  for (const v of reg) { sum += Math.pow(2, -v); if (v === 0) zeros++; }
  const e = (ALPHA * M * M) / sum;
  if (e <= 2.5 * M && zeros > 0) return M * Math.log(M / zeros); // petite plage
  return e;
}

/** Visiteurs d'une journée à partir de ses estimations par fragment { "0": 12.3, … }. */
const visitorsFromEstimates = (est) => Math.round(Object.values(est || {}).reduce((s, x) => s + (+x || 0), 0));

module.exports = { SHARDS, M, fingerprint, emptyRegisters, addToRegisters, estimate, visitorsFromEstimates };
