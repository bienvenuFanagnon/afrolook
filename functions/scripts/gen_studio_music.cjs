'use strict';
// Musiques gratuites du Studio Afrolook (templates « prêts à poster ») : tout est synthétisé ici,
// aucun échantillon ni mélodie existante, donc aucun droit d'auteur à payer.
// Chaque piste dure ~30 s et boucle sans coupure (les queues de notes reviennent au début).
//
//   node functions/scripts/gen_studio_music.cjs <dossier_sortie> [id…]
// Produit <id>.m4a (AAC 96 kb/s stéréo) et <id>.wav. Envoi vers Storage : studio_music/<id>.m4a.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const SR = 44100;
const TARGET = 30;
const TAU = Math.PI * 2;

function rng(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; }; }
const hz = (m) => 440 * Math.pow(2, (m - 69) / 12);
const N = (sec) => Math.max(1, Math.floor(sec * SR));

// ───────── instruments (renvoient un Float32Array mono) ─────────

function adsr(n, a, d, s, r, holdSec) {
  const e = new Float32Array(n); const A = a * SR, D = d * SR, H = holdSec * SR, R = r * SR;
  for (let i = 0; i < n; i++) {
    let v;
    if (i < A) v = i / A;
    else if (i < A + D) v = 1 - (1 - s) * ((i - A) / D);
    else if (i < H) v = s;
    else v = s * Math.max(0, 1 - (i - H) / R);
    e[i] = v;
  }
  return e;
}

/** Corde pincée (Karplus-Strong) : guitare, kora, oud selon la brillance. */
function pluck(f, sec, { bright = 0.5, decay = 0.996, seed = 1 } = {}) {
  const n = N(sec); const o = new Float32Array(n); const R = rng(seed + Math.round(f));
  const p = Math.max(2, Math.round(SR / f)); const buf = new Float32Array(p);
  for (let i = 0; i < p; i++) buf[i] = R() * 2 - 1;
  // pré-filtrage : moins de brillance = attaque plus ronde
  for (let k = 0; k < Math.round((1 - bright) * 4); k++) for (let i = 1; i < p; i++) buf[i] = 0.5 * (buf[i] + buf[i - 1]);
  let idx = 0;
  for (let i = 0; i < n; i++) {
    const a = buf[idx], b = buf[(idx + 1) % p];
    const v = decay * (bright * a + (1 - bright) * 0.5 * (a + b));
    o[i] = a; buf[idx] = v; idx = (idx + 1) % p;
  }
  const tail = N(0.01); for (let i = 0; i < tail; i++) o[n - 1 - i] *= i / tail;
  return o;
}

/** Kalimba / balafon : sinus + partiel inharmonique, attaque nette. */
function kalimba(f, sec = 1.6) {
  const n = N(sec); const o = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    o[i] = (Math.sin(TAU * f * t) * Math.exp(-t / 0.55) + 0.35 * Math.sin(TAU * f * 5.93 * t) * Math.exp(-t / 0.06)
      + 0.12 * Math.sin(TAU * f * 2 * t) * Math.exp(-t / 0.3)) * Math.min(1, t / 0.0015);
  }
  return o;
}

/** Piano électrique (FM). */
function epiano(f, sec) {
  const n = N(sec + 0.6); const o = new Float32Array(n); const env = adsr(n, 0.004, 0.9, 0.35, 0.5, sec);
  for (let i = 0; i < n; i++) {
    const t = i / SR; const idx = 1.6 * Math.exp(-t / 0.35) + 0.2;
    o[i] = Math.sin(TAU * f * t + idx * Math.sin(TAU * f * t)) * env[i] * 0.8 + Math.sin(TAU * f * 2 * t) * 0.06 * Math.exp(-t / 0.2);
  }
  return o;
}

/** Piano acoustique simplifié : harmoniques à décroissance propre + frappe. */
function piano(f, sec, vel = 1) {
  const n = N(sec + 1.4); const o = new Float32Array(n); const R = rng(Math.round(f * 7));
  const harm = [1, 0.55, 0.32, 0.2, 0.12, 0.07, 0.04];
  const relStart = N(sec);
  for (let i = 0; i < n; i++) {
    const t = i / SR; let v = 0;
    for (let k = 0; k < harm.length; k++) {
      const fk = f * (k + 1) * (1 + 0.0004 * (k + 1) * (k + 1));
      if (fk > 9000) break;
      v += Math.sin(TAU * fk * t) * harm[k] * Math.exp(-t / (1.8 / (1 + k * 0.6)));
    }
    if (i < 300) v += (R() * 2 - 1) * 0.08 * (1 - i / 300);
    const rel = i > relStart ? Math.exp(-(i - relStart) / (0.25 * SR)) : 1;
    o[i] = v * rel * Math.min(1, t / 0.002) * 0.45 * vel;
  }
  return o;
}

/** Nappe : dents de scie désaccordées + passe-bas, attaque lente. */
function pad(freqs, sec, { cutoff = 1400, attack = 0.6, release = 0.9 } = {}) {
  const n = N(sec + release); const o = new Float32Array(n); const env = adsr(n, attack, 0.3, 0.85, release, sec);
  const voices = [];
  freqs.forEach((f) => [-0.09, 0, 0.11].forEach((dt) => voices.push({ f: f * Math.pow(2, dt / 12), ph: Math.random() })));
  let lp1 = 0, lp2 = 0; const k = 1 - Math.exp(-TAU * cutoff / SR);
  for (let i = 0; i < n; i++) {
    let v = 0;
    for (const vo of voices) { vo.ph += vo.f / SR; if (vo.ph >= 1) vo.ph -= 1; v += 2 * vo.ph - 1; }
    v /= voices.length;
    lp1 += (v - lp1) * k; lp2 += (lp1 - lp2) * k;
    o[i] = lp2 * env[i] * 1.4;
  }
  return o;
}

/** Cuivres (fanfare) : scie avec filtre qui s'ouvre. */
function brass(f, sec) {
  const n = N(sec + 0.25); const o = new Float32Array(n); const env = adsr(n, 0.03, 0.15, 0.75, 0.2, sec);
  let ph = 0, lp = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR; const vib = 1 + 0.004 * Math.sin(TAU * 5.5 * t) * Math.min(1, t / 0.3);
    ph += f * vib / SR; if (ph >= 1) ph -= 1;
    const cut = 500 + 3200 * Math.min(1, t / 0.08) * (0.6 + 0.4 * env[i]);
    lp += ((2 * ph - 1) - lp) * (1 - Math.exp(-TAU * cut / SR));
    o[i] = lp * env[i] * 0.7;
  }
  return o;
}

/** Boîte à musique / clochettes. */
function bell(f, sec = 1.8, bright = 1) {
  const n = N(sec); const o = new Float32Array(n);
  const parts = [[1, 1, 1.2], [2.76, 0.45 * bright, 0.5], [5.4, 0.22 * bright, 0.25], [8.93, 0.1 * bright, 0.12]];
  for (let i = 0; i < n; i++) { const t = i / SR; let v = 0; for (const [m, a, d] of parts) v += Math.sin(TAU * f * m * t) * a * Math.exp(-t / d); o[i] = v * Math.min(1, t / 0.001) * 0.5; }
  return o;
}

function bass(f, sec, { drive = 1.5, glideFrom = 0 } = {}) {
  const n = N(sec + 0.08); const o = new Float32Array(n); const env = adsr(n, 0.006, 0.2, 0.8, 0.07, sec);
  let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR; const fr = glideFrom ? f + (glideFrom - f) * Math.exp(-t / 0.06) : f;
    ph += fr / SR;
    const v = Math.sin(TAU * ph) + 0.25 * Math.sin(TAU * ph * 2);
    o[i] = Math.tanh(v * drive) * env[i] * 0.8;
  }
  return o;
}

/** Basse 808 avec glissé. */
function b808(f, sec, glideFrom = 0) {
  const n = N(sec + 0.1); const o = new Float32Array(n); let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR; const fr = (glideFrom ? f + (glideFrom - f) * Math.exp(-t / 0.08) : f) * (1 + 0.6 * Math.exp(-t / 0.012));
    ph += fr / SR;
    o[i] = Math.tanh(Math.sin(TAU * ph) * 2.2) * Math.exp(-t / Math.max(0.3, sec * 0.7)) * Math.min(1, t / 0.002) * 0.9;
  }
  return o;
}

/** Log drum (amapiano) : sinus qui plonge, saturé. */
function logdrum(f, sec = 0.5) {
  const n = N(sec); const o = new Float32Array(n); let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR; ph += f * (1 + 1.2 * Math.exp(-t / 0.018)) / SR;
    o[i] = Math.tanh(Math.sin(TAU * ph) * 3) * Math.exp(-t / 0.22) * Math.min(1, t / 0.001) * 0.75;
  }
  return o;
}

function noise(seed) { const R = rng(seed); return () => R() * 2 - 1; }

const DR = {
  kick(tone = 1) { const n = N(0.45); const o = new Float32Array(n); let ph = 0; for (let i = 0; i < n; i++) { const t = i / SR; ph += (48 + 130 * Math.exp(-t / 0.03)) * tone / SR; o[i] = Math.tanh(Math.sin(TAU * ph) * 1.6 * Math.exp(-t / 0.18)) + (i < 60 ? 0.3 * (1 - i / 60) : 0); } return o; },
  snare() { const n = N(0.25); const o = new Float32Array(n); const nz = noise(3); let hp = 0, prev = 0; for (let i = 0; i < n; i++) { const t = i / SR; const w = nz(); hp = 0.9 * (hp + w - prev); prev = w; o[i] = hp * Math.exp(-t / 0.07) * 0.7 + Math.sin(TAU * 190 * t) * Math.exp(-t / 0.04) * 0.5; } return o; },
  clap() { const n = N(0.3); const o = new Float32Array(n); const nz = noise(5); let bp = 0, lp = 0; for (let i = 0; i < n; i++) { const t = i / SR; const burst = [0, 0.011, 0.022].reduce((a, d) => a + (t >= d ? Math.exp(-(t - d) / 0.006) : 0), 0) * 0.5 + Math.exp(-t / 0.09) * 0.6; const w = nz(); lp += (w - lp) * 0.35; bp = w - lp; o[i] = bp * burst * 0.9; } return o; },
  hat(open = false) { const n = N(open ? 0.32 : 0.06); const o = new Float32Array(n); const nz = noise(open ? 9 : 7); let prev = 0, hp = 0; for (let i = 0; i < n; i++) { const t = i / SR; const w = nz(); hp = 0.75 * (hp + w - prev); prev = w; o[i] = hp * Math.exp(-t / (open ? 0.11 : 0.018)) * 0.45; } return o; },
  shaker() { const n = N(0.09); const o = new Float32Array(n); const nz = noise(11); let prev = 0, hp = 0; for (let i = 0; i < n; i++) { const t = i / SR; const w = nz(); hp = 0.8 * (hp + w - prev); prev = w; o[i] = hp * Math.sin(Math.PI * Math.min(1, t / 0.09)) * 0.3; } return o; },
  rim() { const n = N(0.08); const o = new Float32Array(n); for (let i = 0; i < n; i++) { const t = i / SR; o[i] = (Math.sin(TAU * 1700 * t) * 0.5 + Math.sin(TAU * 820 * t) * 0.5) * Math.exp(-t / 0.012) * 0.6; } return o; },
  conga(f = 220) { const n = N(0.35); const o = new Float32Array(n); for (let i = 0; i < n; i++) { const t = i / SR; o[i] = Math.sin(TAU * f * (1 + 0.15 * Math.exp(-t / 0.01)) * t) * Math.exp(-t / 0.12) * 0.7; } return o; },
  djembeSlap() { const n = N(0.15); const o = new Float32Array(n); const nz = noise(13); for (let i = 0; i < n; i++) { const t = i / SR; o[i] = (nz() * 0.6 * Math.exp(-t / 0.02) + Math.sin(TAU * 420 * t) * 0.5 * Math.exp(-t / 0.05)) * 0.7; } return o; },
  cowbell(f = 800) { const n = N(0.3); const o = new Float32Array(n); for (let i = 0; i < n; i++) { const t = i / SR; const sq = (x) => (Math.sin(TAU * x * t) > 0 ? 1 : -1); o[i] = (sq(f) + sq(f * 1.48)) * 0.18 * Math.exp(-t / 0.07); } return o; },
  crash() { const n = N(1.6); const o = new Float32Array(n); const nz = noise(17); let prev = 0, hp = 0; for (let i = 0; i < n; i++) { const t = i / SR; const w = nz(); hp = 0.85 * (hp + w - prev); prev = w; o[i] = hp * Math.exp(-t / 0.5) * 0.35; } return o; },
  frameDoum() { const n = N(0.4); const o = new Float32Array(n); for (let i = 0; i < n; i++) { const t = i / SR; o[i] = Math.sin(TAU * (90 + 40 * Math.exp(-t / 0.02)) * t) * Math.exp(-t / 0.15) * 0.8; } return o; },
  frameTek() { const n = N(0.08); const o = new Float32Array(n); const nz = noise(19); for (let i = 0; i < n; i++) { const t = i / SR; o[i] = (nz() * 0.4 + Math.sin(TAU * 900 * t) * 0.4) * Math.exp(-t / 0.015); } return o; },
  riser(sec = 2) { const n = N(sec); const o = new Float32Array(n); const nz = noise(23); let lp = 0; for (let i = 0; i < n; i++) { const p = i / n; lp += (nz() - lp) * (0.02 + 0.5 * p * p); o[i] = lp * p * p * 0.7; } return o; },
};

// ───────── mixage ─────────

class Mix {
  constructor(sec) { this.n = N(sec); this.L = new Float32Array(this.n); this.R = new Float32Array(this.n); this.sendL = new Float32Array(this.n); this.sendR = new Float32Array(this.n); }
  /** Ajoute un son (gain, panoramique -1..1, envoi réverbération). Les queues qui dépassent repartent au début (boucle). */
  add(t, arr, g = 1, pan = 0, rev = 0.15) {
    const i0 = Math.floor(t * SR); const gl = g * Math.cos((pan + 1) * Math.PI / 4) * 1.414, gr = g * Math.sin((pan + 1) * Math.PI / 4) * 1.414;
    for (let i = 0; i < arr.length; i++) {
      const j = (i0 + i) % this.n; const v = arr[i];
      this.L[j] += v * gl; this.R[j] += v * gr;
      if (rev) { this.sendL[j] += v * gl * rev; this.sendR[j] += v * gr * rev; }
    }
  }
  /** Bruit de vagues (plage). */
  ocean(g = 0.25) {
    const nz = noise(29); let lp = 0, lp2 = 0;
    for (let i = 0; i < this.n; i++) {
      const t = i / SR; const swell = 0.35 + 0.65 * Math.pow(0.5 + 0.5 * Math.sin(TAU * t / 7.5 - 1.2), 2);
      lp += (nz() - lp) * (0.02 + 0.06 * swell); lp2 += (lp - lp2) * 0.3;
      const v = lp2 * swell * g * 3;
      this.L[i] += v; this.R[(i + 300) % this.n] += v;
    }
  }
  finish(revSize = 0.82, master = 0.9) {
    const [wl, wr] = freeverb(this.sendL, this.sendR, revSize);
    const L = this.L, R = this.R;
    for (let i = 0; i < this.n; i++) { L[i] += wl[i]; R[i] += wr[i]; }
    // compression douce + normalisation
    let pk = 0; for (let i = 0; i < this.n; i++) pk = Math.max(pk, Math.abs(L[i]), Math.abs(R[i]));
    const pre = pk > 0 ? 1.25 / pk : 1;
    for (let i = 0; i < this.n; i++) { L[i] = Math.tanh(L[i] * pre) * master; R[i] = Math.tanh(R[i] * pre) * master; }
    return [L, R];
  }
}

function freeverb(inL, inR, room) {
  const n = inL.length; const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]; const aps = [556, 441, 341, 225];
  const fb = 0.7 + 0.28 * room; const damp = 0.3;
  // préchauffage : la réverb tourne d'abord sur les 3 dernières secondes, pour que la queue de fin revienne au début (boucle)
  const warm = (inp, spread) => {
    const tail = Math.min(n, SR * 3);
    const ext = new Float32Array(tail + n); ext.set(inp.subarray(n - tail), 0); ext.set(inp, tail);
    const full = runPlain(ext, spread);
    return full.subarray(tail);
  };
  function runPlain(inp, spread) {
    const m = inp.length; const out = new Float32Array(m);
    const cs = combs.map((c) => ({ b: new Float32Array(c + spread), i: 0, f: 0 }));
    const as = aps.map((a) => ({ b: new Float32Array(a + spread), i: 0 }));
    for (let i = 0; i < m; i++) {
      const x = inp[i] * 0.015; let y = 0;
      for (const c of cs) { const o = c.b[c.i]; c.f = o * (1 - damp) + c.f * damp; c.b[c.i] = x + c.f * fb; c.i = (c.i + 1) % c.b.length; y += o; }
      for (const a of as) { const o = a.b[a.i]; const v = -y + o; a.b[a.i] = y + o * 0.5; a.i = (a.i + 1) % a.b.length; y = v; }
      out[i] = y;
    }
    return out;
  }
  return [warm(inL, 0), warm(inR, 23)];
}

// ───────── outils musicaux ─────────

/** Accord : fondamentale MIDI + intervalles. */
const CH = {
  maj: [0, 4, 7], min: [0, 3, 7], maj7: [0, 4, 7, 11], min7: [0, 3, 7, 10], dom7: [0, 4, 7, 10], min9: [0, 3, 7, 10, 14], sus2: [0, 2, 7], add9: [0, 4, 7, 14],
};
const chord = (root, kind) => CH[kind].map((x) => root + x);
const SCALES = { maj: [0, 2, 4, 5, 7, 9, 11], min: [0, 2, 3, 5, 7, 8, 10], pentaMaj: [0, 2, 4, 7, 9], pentaMin: [0, 3, 5, 7, 10], hijaz: [0, 1, 4, 5, 7, 8, 10] };
const deg = (tonic, scale, d) => { const s = SCALES[scale]; const o = Math.floor(d / s.length); const k = ((d % s.length) + s.length) % s.length; return tonic + 12 * o + s[k]; };

/** Grille de 16 pas : 'x' frappe, '.' rien, 'o' accent. */
function grid(m, bar, bars, beatSec, pattern, fn) {
  const step = beatSec / 4; const p = pattern.replace(/\s/g, '');
  for (let b = 0; b < bars; b++) for (let i = 0; i < p.length; i++) {
    const c = p[i]; if (c === '.') continue;
    fn(b * bar + i * step * (16 / p.length), c === 'o' ? 1 : 0.7, b, i);
  }
}

function plan(bpm, beatsPerBar = 4) {
  const beat = 60 / bpm; const bar = beat * beatsPerBar;
  const bars = Math.max(4, Math.round(TARGET / bar / 4) * 4);
  return { beat, bar, bars, sec: bars * bar };
}

// ───────── pistes ─────────

const TRACKS = {
  piano_triste: { calm: true, title: 'Piano triste', make() {
    const P = plan(68); const m = new Mix(P.sec); const prog = [[57, 'min'], [53, 'maj'], [48, 'maj'], [55, 'maj']];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      m.add(t0, piano(hz(r - 24), P.bar * 0.95, 0.9), 0.55, -0.1, 0.3);
      const arp = [c[0], c[1], c[2], c[1] + 12, c[2], c[1]];
      arp.forEach((n, i) => m.add(t0 + i * P.beat * 0.666, piano(hz(n), P.beat, 0.6), 0.35, 0.2, 0.35));
      m.add(t0, pad(c.map((x) => hz(x)), P.bar, { cutoff: 800, attack: 1 }), 0.12, 0, 0.4);
    }
    const mel = [[0, 4, 2], [2, 3, 1], [3, 2, 1], [4, 1, 3], [8, 2, 2], [10, 1, 1], [11, 0, 1], [12, -1, 4]];
    for (let rep = 0; rep < P.bars / 4; rep++) mel.forEach(([beat, d, len]) => m.add(rep * P.bar * 4 + (rep % 2 ? P.bar * 2 : 0) + beat * P.beat, piano(hz(deg(69, 'min', d)), len * P.beat, 0.8), 0.4, 0.05, 0.4));
    return m.finish(0.9, 0.85);
  } },

  love_afro: { title: 'Love afro', make() {
    const P = plan(92); const m = new Mix(P.sec); const prog = [[62, 'maj7'], [59, 'min7'], [64, 'min7'], [57, 'dom7']];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      [0, 1.5, 2.5].forEach((bt) => c.forEach((n) => m.add(t0 + bt * P.beat, epiano(hz(n), P.beat * 0.9), 0.14, (n % 3 - 1) * 0.3, 0.3)));
      m.add(t0, bass(hz(r - 24), P.beat * 1.4), 0.5, 0, 0);
      m.add(t0 + 2.5 * P.beat, bass(hz(r - 24 + 7), P.beat * 0.8), 0.4, 0, 0);
    }
    grid(m, P.bar, P.bars, P.beat, 'x... .... ..x. ....', (t) => m.add(t, DR.kick(), 0.6, 0, 0));
    grid(m, P.bar, P.bars, P.beat, '.... x... .... x...', (t) => m.add(t, DR.rim(), 0.35, 0.2, 0.2));
    grid(m, P.bar, P.bars, P.beat, 'xxxx xxxx xxxx xxxx', (t, a) => m.add(t, DR.shaker(), 0.5 * a, -0.4, 0.05));
    const mel = [[0, 4], [1, 2], [1.5, 4], [2, 5], [3, 4], [4.5, 2], [6, 1], [6.5, 2]];
    for (let rep = 1; rep < P.bars / 2; rep += 2) mel.forEach(([bt, d]) => m.add(rep * P.bar + bt * P.beat, kalimba(hz(deg(74, 'maj', d))), 0.3, 0.3, 0.35));
    return m.finish(0.8);
  } },

  afrobeat: { title: 'Afrobeat énergique', make() {
    const P = plan(108); const m = new Mix(P.sec); const prog = [[60, 'maj'], [57, 'min'], [53, 'maj'], [55, 'maj']];
    for (let b = 0; b < P.bars; b++) {
      const [r] = prog[b % 4]; const t0 = b * P.bar;
      [[0, 0], [0.75, 0], [1.5, 7], [2.5, 0], [3, 10], [3.5, 7]].forEach(([bt, iv]) => m.add(t0 + bt * P.beat, bass(hz(r - 24 + iv), P.beat * 0.4), 0.5, 0, 0));
      const c = chord(r, prog[b % 4][1]);
      [0.5, 1.25, 2.5, 3.25].forEach((bt, i) => m.add(t0 + bt * P.beat, pluck(hz(c[i % 3] + 12), 0.35, { bright: 0.7, decay: 0.993 }), 0.3, 0.45, 0.1));
      [0, 1, 2, 3].forEach((bt) => m.add(t0 + bt * P.beat, pluck(hz(c[(bt + 1) % 3] + 24), 0.2, { bright: 0.85, decay: 0.99, seed: 9 }), 0.16, -0.5, 0.1));
    }
    grid(m, P.bar, P.bars, P.beat, 'x... ..x. x... ..x.', (t) => m.add(t, DR.kick(), 0.75, 0, 0));
    grid(m, P.bar, P.bars, P.beat, '.... o... .... o...', (t) => m.add(t, DR.clap(), 0.5, 0, 0.2));
    grid(m, P.bar, P.bars, P.beat, 'oxxx oxxx oxxx oxxx', (t, a) => m.add(t, DR.shaker(), 0.55 * a, 0.35, 0));
    grid(m, P.bar, P.bars, P.beat, '..x. .x.. x..x ..x.', (t, a, b, i) => m.add(t, DR.conga(i % 2 ? 260 : 200), 0.35, -0.3, 0.1));
    grid(m, P.bar, P.bars, P.beat, 'x.x. xx.x .xx. x.x.', (t) => m.add(t, DR.cowbell(), 0.18, 0.6, 0.1));
    return m.finish(0.6);
  } },

  amapiano: { title: 'Amapiano', make() {
    const P = plan(112); const m = new Mix(P.sec); const prog = [[53, 'min7'], [58, 'min7'], [51, 'maj7'], [56, 'maj7']];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      m.add(t0, pad(c.map((x) => hz(x)), P.bar, { cutoff: 1100, attack: 0.3 }), 0.12, 0, 0.35);
      [0.5, 1.75, 3].forEach((bt) => c.forEach((n) => m.add(t0 + bt * P.beat, piano(hz(n + 12), P.beat * 0.3, 0.7), 0.1, 0.25, 0.3)));
      [[0, 0], [0.75, 0], [1.5, 7], [2.25, 12], [3, 10], [3.5, 7]].forEach(([bt, iv]) => m.add(t0 + bt * P.beat, logdrum(hz(r - 12 + iv)), 0.5, 0, 0.05));
    }
    grid(m, P.bar, P.bars, P.beat, 'x... x... x... x...', (t) => m.add(t, DR.kick(0.9), 0.55, 0, 0));
    grid(m, P.bar, P.bars, P.beat, 'oxxx oxxo xxox xxxx', (t, a) => m.add(t, DR.shaker(), 0.6 * a, -0.35, 0));
    grid(m, P.bar, P.bars, P.beat, '..x. ..x. ..x. ..x.', (t) => m.add(t, DR.hat(true), 0.25, 0.3, 0.05));
    grid(m, P.bar, P.bars, P.beat, '.... o... .... o...', (t) => m.add(t, DR.rim(), 0.3, 0.2, 0.3));
    return m.finish(0.7);
  } },

  coupe_decale: { title: 'Coupé-décalé', make() {
    const P = plan(128); const m = new Mix(P.sec); const prog = [[60, 'maj'], [55, 'maj'], [57, 'min'], [53, 'maj']];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      for (let s = 0; s < 16; s++) if (s % 4 !== 3) m.add(t0 + s * P.beat / 4, pluck(hz(c[s % 3] + 12 + (s % 8 === 6 ? 12 : 0)), 0.18, { bright: 0.8, decay: 0.99 }), 0.2, 0.4, 0.08);
      [0, 1.5, 2, 3.5].forEach((bt, i) => m.add(t0 + bt * P.beat, bass(hz(r - 24 + (i === 3 ? 7 : 0)), P.beat * 0.45), 0.5, 0, 0));
      if (b % 4 === 3) m.add(t0 + 2 * P.beat, DR.riser(P.beat * 2), 0.3, 0, 0.2);
    }
    grid(m, P.bar, P.bars, P.beat, 'x... x... x... x...', (t) => m.add(t, DR.kick(), 0.75, 0, 0));
    grid(m, P.bar, P.bars, P.beat, '.... x... .... x.xx', (t) => m.add(t, DR.snare(), 0.45, 0, 0.15));
    grid(m, P.bar, P.bars, P.beat, '..x. ..x. ..x. ..x.', (t) => m.add(t, DR.hat(true), 0.3, -0.3, 0.05));
    grid(m, P.bar, P.bars, P.beat, 'x.xx x.xx x.xx x.xx', (t) => m.add(t, DR.hat(), 0.35, 0.3, 0));
    grid(m, P.bar, P.bars, P.beat, 'x..x ..x. x..x ..x.', (t) => m.add(t, DR.cowbell(900), 0.16, -0.6, 0.1));
    return m.finish(0.6);
  } },

  zen_kalimba: { calm: true, title: 'Kalimba zen', make() {
    const P = plan(70); const m = new Mix(P.sec); const prog = [[48, 'sus2'], [45, 'min7'], [53, 'maj7'], [50, 'min7']];
    const R = rng(4);
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      m.add(t0, pad(c.map((x) => hz(x + 12)), P.bar, { cutoff: 900, attack: 1.2, release: 1.4 }), 0.16, 0, 0.5);
      for (let s = 0; s < 8; s++) { const d = [0, 2, 4, 1, 3, 2, 4, 5][(s + b) % 8]; m.add(t0 + s * P.beat / 2, kalimba(hz(deg(72, 'pentaMaj', d - (R() < 0.3 ? 5 : 0)))), 0.32 * (0.6 + 0.4 * R()), (s % 2 ? 0.35 : -0.35), 0.45); }
    }
    return m.finish(0.92, 0.8);
  } },

  afro_trap: { title: 'Afro trap', make() {
    const P = plan(140); const m = new Mix(P.sec); const prog = [[48, 'min'], [44, 'maj'], [46, 'maj'], [43, 'min']];
    for (let b = 0; b < P.bars; b++) {
      const [r] = prog[b % 4]; const t0 = b * P.bar;
      m.add(t0, b808(hz(r - 12), P.beat * 2.2), 0.7, 0, 0);
      m.add(t0 + 2.5 * P.beat, b808(hz(r - 12), P.beat * 1.2, hz(r - 5)), 0.6, 0, 0);
      const c = chord(r + 12, prog[b % 4][1]);
      [0, 0.75, 1.5, 2.5, 3].forEach((bt, i) => m.add(t0 + bt * P.beat, bell(hz(deg(72, 'min', [0, 2, 4, 3, 2][i] + (b % 2 ? -1 : 0))), 0.6, 0.6), 0.22, 0.3, 0.3));
      m.add(t0, pad(c.map((x) => hz(x)), P.bar, { cutoff: 700, attack: 0.4 }), 0.1, 0, 0.3);
    }
    grid(m, P.bar, P.bars, P.beat, 'x... .... ..x. ....', (t) => m.add(t, DR.kick(), 0.5, 0, 0));
    grid(m, P.bar, P.bars, P.beat, '.... .... o... ....', (t) => m.add(t, DR.clap(), 0.55, 0, 0.2));
    grid(m, P.bar, P.bars, P.beat, 'x.x. x.x. xxx. x.xx', (t) => m.add(t, DR.hat(), 0.4, 0.25, 0));
    return m.finish(0.6);
  } },

  fanfare: { title: 'Fanfare festive', make() {
    const P = plan(120); const m = new Mix(P.sec); const prog = [[60, 'maj'], [65, 'maj'], [67, 'maj'], [60, 'maj']];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      [[0, 0.9], [1.5, 0.4], [2, 0.9], [3, 0.4], [3.5, 0.4]].forEach(([bt, len]) => c.forEach((n, i) => m.add(t0 + bt * P.beat, brass(hz(n - (i === 0 ? 12 : 0)), len * P.beat), 0.14, (i - 1) * 0.35, 0.2)));
      [0, 2].forEach((bt) => m.add(t0 + bt * P.beat, bass(hz(r - 24), P.beat * 0.8, { drive: 1 }), 0.45, 0, 0));
      if (b % 4 === 0) m.add(t0, DR.crash(), 0.4, 0.3, 0.2);
    }
    grid(m, P.bar, P.bars, P.beat, 'x... .... x... ....', (t) => m.add(t, DR.kick(), 0.6, 0, 0));
    grid(m, P.bar, P.bars, P.beat, '.... o... .... o...', (t) => m.add(t, DR.clap(), 0.5, 0, 0.25));
    grid(m, P.bar, P.bars, P.beat, 'x.xx x.x. x.xx x.xx', (t, a) => m.add(t, DR.snare(), 0.18 * a, -0.2, 0.1));
    return m.finish(0.7);
  } },

  nuit: { calm: true, title: 'Nuit douce', make() {
    const P = plan(60); const m = new Mix(P.sec); const prog = [[52, 'min9'], [48, 'maj7'], [45, 'min9'], [47, 'min7']];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      m.add(t0, pad(c.map((x) => hz(x)), P.bar, { cutoff: 650, attack: 1.6, release: 2 }), 0.3, 0, 0.6);
      [0, 2.5].forEach((bt, i) => m.add(t0 + bt * P.beat, bell(hz(c[(b + i) % c.length] + 24), 2.4, 0.4), 0.12, i ? 0.4 : -0.4, 0.6));
    }
    return m.finish(0.95, 0.75);
  } },

  highlife: { title: 'Highlife joyeux', make() {
    const P = plan(116); const m = new Mix(P.sec); const prog = [[55, 'maj'], [60, 'maj'], [62, 'maj'], [55, 'maj']];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      const lineA = [0, 2, 1, 2, 0, 2, 1, 2]; const lineB = [2, 1, 0, 1, 2, 1, 0, 2];
      lineA.forEach((ci, s) => m.add(t0 + s * P.beat / 2, pluck(hz(c[ci] + 12), 0.3, { bright: 0.75, decay: 0.994 }), 0.24, -0.45, 0.12));
      lineB.forEach((ci, s) => m.add(t0 + s * P.beat / 2 + P.beat / 4, pluck(hz(c[ci] + 24), 0.22, { bright: 0.85, decay: 0.991, seed: 5 }), 0.15, 0.45, 0.12));
      [[0, 0], [1, 7], [2, 0], [2.5, 4], [3, 7]].forEach(([bt, iv]) => m.add(t0 + bt * P.beat, bass(hz(r - 24 + iv), P.beat * 0.5, { drive: 1.2 }), 0.45, 0, 0));
    }
    grid(m, P.bar, P.bars, P.beat, 'x... ..x. x... ....', (t) => m.add(t, DR.kick(), 0.6, 0, 0));
    grid(m, P.bar, P.bars, P.beat, '.... x... .... x...', (t) => m.add(t, DR.snare(), 0.35, 0, 0.15));
    grid(m, P.bar, P.bars, P.beat, 'x.x. xx.x .xx. x.x.', (t) => m.add(t, DR.cowbell(760), 0.2, 0.6, 0.1));
    grid(m, P.bar, P.bars, P.beat, 'xxxx xxxx xxxx xxxx', (t, a) => m.add(t, DR.shaker(), 0.4 * a, -0.2, 0));
    return m.finish(0.6);
  } },

  tension: { title: 'Suspense', make() {
    const P = plan(90); const m = new Mix(P.sec);
    for (let b = 0; b < P.bars; b++) {
      const t0 = b * P.bar; const r = [50, 50, 51, 49][b % 4];
      m.add(t0, pad([hz(r - 12), hz(r - 5), hz(r + 1)], P.bar, { cutoff: 500, attack: 0.5 }), 0.3, 0, 0.4);
      for (let s = 0; s < 8; s++) m.add(t0 + s * P.beat / 2, pluck(hz(r + (s % 4 === 3 ? 13 : 12)), 0.25, { bright: 0.5, decay: 0.99 }), 0.2, s % 2 ? 0.4 : -0.4, 0.2);
      m.add(t0, DR.kick(0.6), 0.7, 0, 0.3);
      if (b % 2 === 1) m.add(t0 + 2 * P.beat, DR.riser(P.beat * 2), 0.35, 0, 0.3);
    }
    grid(m, P.bar, P.bars, P.beat, '.... .... x... ....', (t) => m.add(t, DR.frameDoum(), 0.5, 0, 0.3));
    return m.finish(0.85, 0.8);
  } },

  noel: { title: 'Clochettes de fête', make() {
    const P = plan(100); const m = new Mix(P.sec); const prog = [[60, 'maj'], [57, 'min'], [53, 'maj'], [55, 'maj']];
    const mel = [[0, 4], [1, 4], [2, 5], [3, 7], [4, 7], [5, 5], [6, 4], [7, 2], [8, 0], [9, 0], [10, 2], [11, 4], [12, 4], [13.5, 2], [14, 2]];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      m.add(t0, pad(c.map((x) => hz(x)), P.bar, { cutoff: 1300 }), 0.12, 0, 0.4);
      [0, 2].forEach((bt) => m.add(t0 + bt * P.beat, bass(hz(r - 24), P.beat * 1.5, { drive: 0.9 }), 0.35, 0, 0));
    }
    for (let rep = 0; rep < P.bars / 4; rep++) mel.forEach(([bt, d]) => m.add(rep * 4 * P.bar + bt * P.beat, bell(hz(deg(72, 'maj', d)), 1.4), 0.28, 0.15, 0.35));
    grid(m, P.bar, P.bars, P.beat, 'xxxx xxxx xxxx xxxx', (t, a) => m.add(t, DR.shaker(), 0.5 * a, -0.4, 0.05));
    grid(m, P.bar, P.bars, P.beat, 'x... .... x... ....', (t) => m.add(t, DR.kick(0.9), 0.4, 0, 0));
    grid(m, P.bar, P.bars, P.beat, '.... x... .... x...', (t) => m.add(t, DR.rim(), 0.25, 0.2, 0.2));
    return m.finish(0.8);
  } },

  oud: { calm: true, title: 'Oud doux', make() {
    const P = plan(80); const m = new Mix(P.sec);
    const phrase = [0, 1, 2, 1, 3, 2, 1, 0, 4, 3, 2, 3, 1, 2, 1, 0];
    for (let b = 0; b < P.bars; b++) {
      const t0 = b * P.bar;
      m.add(t0, pad([hz(50), hz(57)], P.bar, { cutoff: 600, attack: 0.8 }), 0.15, 0, 0.4);
      for (let s = 0; s < 8; s++) { const d = phrase[(b * 8 + s) % phrase.length] + (b % 4 === 3 ? 2 : 0); m.add(t0 + s * P.beat / 2, pluck(hz(deg(62, 'hijaz', d)), 0.5, { bright: 0.45, decay: 0.995 }), 0.3, 0.15, 0.3); }
    }
    grid(m, P.bar, P.bars, P.beat, 'x... ..x. .... x...', (t) => m.add(t, DR.frameDoum(), 0.45, 0, 0.15));
    grid(m, P.bar, P.bars, P.beat, '..x. x... x.x. ..x.', (t) => m.add(t, DR.frameTek(), 0.3, 0.3, 0.15));
    return m.finish(0.85, 0.8);
  } },

  plage: { calm: true, title: 'Vagues et guitare', make() {
    const P = plan(84); const m = new Mix(P.sec); const prog = [[62, 'maj'], [57, 'maj'], [59, 'min'], [55, 'maj']];
    m.ocean(0.22);
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      const arp = [c[0] - 12, c[1], c[2], c[0] + 12, c[2], c[1], c[2], c[0] + 12];
      arp.forEach((n, s) => m.add(t0 + s * P.beat / 2, pluck(hz(n), 0.9, { bright: 0.55, decay: 0.997 }), 0.28, s % 2 ? 0.3 : -0.3, 0.3));
    }
    return m.finish(0.85, 0.8);
  } },

  workout: { title: 'Afro workout', make() {
    const P = plan(124); const m = new Mix(P.sec); const prog = [[45, 'min'], [45, 'min'], [41, 'maj'], [43, 'maj']];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r + 24, k); const t0 = b * P.bar;
      for (let s = 0; s < 8; s++) m.add(t0 + s * P.beat / 2 + P.beat / 4, bass(hz(r - 12 + (s % 2 ? 12 : 0)), P.beat * 0.22, { drive: 2 }), 0.4, 0, 0);
      [0.5, 2.5].forEach((bt) => c.forEach((n) => m.add(t0 + bt * P.beat, brass(hz(n), P.beat * 0.3), 0.08, (n % 3 - 1) * 0.4, 0.15)));
      if (b % 4 === 3) m.add(t0 + 2 * P.beat, DR.riser(P.beat * 2), 0.35, 0, 0.2);
    }
    grid(m, P.bar, P.bars, P.beat, 'x... x... x... x...', (t) => m.add(t, DR.kick(), 0.8, 0, 0));
    grid(m, P.bar, P.bars, P.beat, '.... o... .... o...', (t) => m.add(t, DR.clap(), 0.5, 0, 0.15));
    grid(m, P.bar, P.bars, P.beat, '..x. ..x. ..x. ..x.', (t) => m.add(t, DR.hat(true), 0.3, 0.3, 0));
    grid(m, P.bar, P.bars, P.beat, 'xxxx xxxx xxxx xxxx', (t, a) => m.add(t, DR.hat(), 0.25 * a, -0.3, 0));
    grid(m, P.bar, P.bars, P.beat, '..x. .x.. x..x ..x.', (t, a, b, i) => m.add(t, DR.conga(i % 3 ? 240 : 190), 0.3, -0.5, 0.1));
    return m.finish(0.55);
  } },

  berceuse: { calm: true, title: 'Berceuse', make() {
    const P = plan(72, 3); const m = new Mix(P.sec); const prog = [[60, 'maj'], [53, 'maj'], [55, 'maj'], [60, 'maj']];
    const mel = [[0, 4], [1, 2], [2, 3], [3, 4], [4, 5], [5, 4], [6, 2], [7, 1], [8, 0], [9, 1], [10, 2], [11, 0]];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      m.add(t0, pad(c.map((x) => hz(x)), P.bar, { cutoff: 700, attack: 0.8 }), 0.14, 0, 0.5);
      m.add(t0, bell(hz(r - 12), 2, 0.3), 0.18, 0, 0.3);
    }
    for (let rep = 0; rep < P.bars / 4; rep++) mel.forEach(([bt, d]) => m.add(rep * 4 * P.bar + bt * P.beat, bell(hz(deg(84, 'maj', d)), 1.6, 1.4), 0.24, 0.1, 0.45));
    return m.finish(0.9, 0.75);
  } },

  kora_calme: { calm: true, title: 'Kora calme', make() {
    const P = plan(76); const m = new Mix(P.sec); const prog = [[53, 'maj'], [58, 'maj'], [60, 'maj'], [53, 'maj']];
    for (let b = 0; b < P.bars; b++) {
      const [r, k] = prog[b % 4]; const c = chord(r, k); const t0 = b * P.bar;
      const low = [c[0] - 12, c[2] - 12, c[0], c[2] - 12];
      low.forEach((n, s) => m.add(t0 + s * P.beat, pluck(hz(n), 1.2, { bright: 0.6, decay: 0.997, seed: 3 }), 0.26, -0.3, 0.25));
      for (let s = 0; s < 12; s++) { const d = [4, 2, 0, 2, 4, 5, 4, 2, 1, 2, 4, 2][(s + b * 3) % 12]; m.add(t0 + s * P.beat / 3, pluck(hz(deg(65, 'maj', d)), 0.6, { bright: 0.85, decay: 0.995, seed: 11 }), 0.2, 0.35, 0.3); }
    }
    grid(m, P.bar, P.bars, P.beat, 'x.x. x.x. x.x. x.x.', (t, a) => m.add(t, DR.shaker(), 0.3 * a, 0.5, 0.05));
    return m.finish(0.85, 0.8);
  } },
};

// ───────── sortie ─────────

function writeWav(file, L, R) {
  const n = L.length; const buf = Buffer.alloc(44 + n * 4);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 4, 4); buf.write('WAVE', 8); buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(2, 22); buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 4, 28);
  buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) {
    buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, L[i])) * 32767), 44 + i * 4);
    buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, R[i])) * 32767), 46 + i * 4);
  }
  fs.writeFileSync(file, buf);
}

function main() {
  const out = process.argv[2];
  if (!out) { console.error('usage: node gen_studio_music.cjs <dossier> [id…]'); process.exit(1); }
  fs.mkdirSync(out, { recursive: true });
  const ids = process.argv.slice(3).length ? process.argv.slice(3) : Object.keys(TRACKS);
  const ffmpeg = require(path.join(__dirname, '..', 'node_modules', 'ffmpeg-static'));
  const meta = [];
  for (const id of ids) {
    const t0 = Date.now();
    const [L, R] = TRACKS[id].make();
    const wav = path.join(out, `${id}.wav`);
    writeWav(wav, L, R);
    execFileSync(ffmpeg, ['-y', '-loglevel', 'error', '-i', wav, '-af', `loudnorm=I=${TRACKS[id].calm ? -16 : -14}:TP=-1.5:LRA=11`, '-ar', '44100', '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart', path.join(out, `${id}.m4a`)]);
    const sec = L.length / SR;
    meta.push({ id, title: TRACKS[id].title, durationMs: Math.round(sec * 1000) });
    console.log(`${id}: ${sec.toFixed(1)} s, ${((Date.now() - t0) / 1000).toFixed(1)} s de calcul`);
  }
  fs.writeFileSync(path.join(out, 'tracks.json'), JSON.stringify(meta, null, 2));
}

main();
