'use strict';
// Sons des vidéos : effets synchronisés avec les mouvements (souffle, impact, pop, scintillement, caisse enregistreuse…)
// et musiques (rythmée selon le style, ou ambiance douce). Tout est synthétisé : aucun fichier, aucun droit d'auteur.
const SR = 24000;
const clamp = (x, a = -1, b = 1) => Math.min(b, Math.max(a, x));
function rng(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; }; }
const hz = (m) => 440 * Math.pow(2, (m - 69) / 12);
const N = (sec) => Math.max(1, Math.floor(sec * SR));

function lowpassNoise(len, R, cutoffAt) { // bruit filtré, coupure variable (0..1 → fréquence)
  const o = new Float32Array(len); let a = 0, b = 0;
  for (let i = 0; i < len; i++) { const f = cutoffAt(i / len); const k = 1 - Math.exp(-2 * Math.PI * f / SR); a += (R() * 2 - 1 - a) * k; b += (a - b) * k; o[i] = b * 3.2; }
  return o;
}
const bell = (f, sec, dec, harm = [1, 0.5, 0.25]) => { const o = new Float32Array(N(sec)); for (let i = 0; i < o.length; i++) { const t = i / SR; let v = 0; harm.forEach((h, k) => { v += Math.sin(2 * Math.PI * f * (k === 0 ? 1 : k * 2.01 + 0.4 * k) * t) * h; }); o[i] = v * Math.min(1, t / 0.002) * Math.exp(-t / dec); } return o; };

const FX = {
  /** Souffle de mouvement : dir 1 = monte, -1 = descend. */
  whoosh(dir = 1, sec = 0.55) { const R = rng(3 + sec * 100); const n = N(sec); const nz = lowpassNoise(n, R, (p) => (dir > 0 ? 250 + 5200 * p * p : 5200 - 4900 * p)); for (let i = 0; i < n; i++) { const p = i / n; nz[i] *= Math.sin(Math.PI * p) ** 1.6 * 0.9; } return nz; },
  /** Petit pop de texte ou d'icône (hauteur variable). */
  pop(base = 520) { const n = N(0.14); const o = new Float32Array(n); let ph = 0; for (let i = 0; i < n; i++) { const t = i / SR; ph += 2 * Math.PI * (base * (1 + 0.9 * Math.exp(-t * 40))) / SR; o[i] = Math.sin(ph) * Math.exp(-t / 0.035) * 0.8 + (i < 40 ? (Math.random() * 2 - 1) * 0.3 : 0); } return o; },
  tick() { const n = N(0.05); const o = new Float32Array(n); for (let i = 0; i < n; i++) { const t = i / SR; o[i] = (Math.sin(2 * Math.PI * 2100 * t) * 0.6 + (i < 30 ? 0.6 : 0)) * Math.exp(-t / 0.012); } return o; },
  /** Atterrissage du produit : grave + choc. */
  thud() { const n = N(0.55); const R = rng(9); const o = new Float32Array(n); let ph = 0; const nz = lowpassNoise(n, R, (p) => 900 * (1 - p) + 120); for (let i = 0; i < n; i++) { const t = i / SR; ph += 2 * Math.PI * (46 + 70 * Math.exp(-t * 18)) / SR; o[i] = Math.sin(ph) * Math.exp(-t / 0.16) * 1.0 + nz[i] * Math.exp(-t / 0.06) * 0.7; } return o; },
  /** Impact fort : choc + souffle grave + traîne. */
  impact() { const th = FX.thud(); const n = N(1.1); const R = rng(21); const o = new Float32Array(n); const nz = lowpassNoise(n, R, (p) => 2600 * (1 - p) ** 2 + 150); for (let i = 0; i < n; i++) { const t = i / SR; o[i] = (i < th.length ? th[i] : 0) * 1.1 + nz[i] * Math.exp(-t / 0.22) * 0.6; } return o; },
  /** Scintillement : petites notes aiguës qui s'égrènent. */
  sparkle(count = 7, sec = 0.7) { const n = N(sec + 0.3); const R = rng(17); const o = new Float32Array(n); for (let k = 0; k < count; k++) { const t0 = Math.floor((k / count) * sec * SR * (0.7 + R() * 0.3)); const f = 1800 + R() * 3600; for (let i = 0; i < N(0.18) && t0 + i < n; i++) { const t = i / SR; o[t0 + i] += Math.sin(2 * Math.PI * f * t) * Math.exp(-t / 0.045) * 0.35; } } return o; },
  /** Montée de tension avant un temps fort. */
  riser(sec = 0.9) { const n = N(sec); const R = rng(5); const nz = lowpassNoise(n, R, (p) => 300 + 6500 * p * p); const o = new Float32Array(n); let ph = 0; for (let i = 0; i < n; i++) { const p = i / n; ph += 2 * Math.PI * (180 + 1300 * p * p) / SR; o[i] = (nz[i] * 0.8 + Math.sin(ph) * 0.35) * p ** 2.2; } return o; },
  /** Carillon doux (beauté, fin de scène). */
  chime(base = 880) { const a = bell(base, 1.4, 0.5, [1, 0.45, 0.2]); const b = bell(base * 1.5, 1.2, 0.4, [1, 0.3]); const o = new Float32Array(a.length); const d = N(0.07); for (let i = 0; i < o.length; i++) o[i] = a[i] * 0.7 + (i >= d && i - d < b.length ? b[i - d] * 0.5 : 0); return o; },
  /** Ding de validation. */
  ding() { return bell(1568, 0.9, 0.24, [1, 0.35]); },
  /** « Ka-ching » du prix. */
  cash() { const a = bell(2093, 0.9, 0.2, [1, 0.6, 0.3]), b = bell(3136, 1.2, 0.3, [1, 0.5]); const n = N(1.3); const o = new Float32Array(n); const d = N(0.1); for (let i = 0; i < n; i++) o[i] = (i < a.length ? a[i] * 0.8 : 0) + (i >= d && i - d < b.length ? b[i - d] * 0.8 : 0); const sp = FX.sparkle(9, 0.6); for (let i = 0; i < sp.length && i + d < n; i++) o[i + d] += sp[i] * 0.7; return o; },
  /** Glissement rapide de texte. */
  swish() { return FX.whoosh(1, 0.22); },
};
const GAIN = { whoosh: 0.55, pop: 0.55, tick: 0.4, thud: 0.9, impact: 0.85, sparkle: 0.5, riser: 0.5, chime: 0.45, ding: 0.5, cash: 0.6, swish: 0.4 };
const cache = {};
function fx(name, arg) { const key = name + ':' + arg; if (!cache[key]) { const a = FX[name](arg); let pk = 0; for (let i = 0; i < a.length; i++) pk = Math.max(pk, Math.abs(a[i])); if (pk > 0) { const k = 0.95 / pk; for (let i = 0; i < a.length; i++) a[i] *= k; } cache[key] = a; } return cache[key]; }

/** Piste d'effets à partir d'une liste d'événements [{ t (s), k (nom), a (argument), g (gain) }]. */
function sfxTrack(events, seconds) {
  const out = new Float32Array(Math.ceil(seconds * SR));
  events.forEach((e) => { const arr = fx(e.k, e.a); const i0 = Math.max(0, Math.floor(e.t * SR)); const g = (GAIN[e.k] || 0.5) * (e.g == null ? 1 : e.g); for (let i = 0; i < arr.length && i0 + i < out.length; i++) out[i0 + i] += arr[i] * g; });
  return out;
}

// ───────── musiques ─────────
function music(kind, style, seconds, bounds) {
  const n = Math.ceil(seconds * SR); const o = new Float32Array(n);
  if (kind === 'none') return o;
  const R = rng(11);
  const add = (t0, arr, g = 1) => { const i0 = Math.floor(t0 * SR); for (let i = 0; i < arr.length && i0 + i < n; i++) o[i0 + i] += arr[i] * g; };
  const env = (len, a, d) => { const e = new Float32Array(len); for (let i = 0; i < len; i++) { const t = i / SR; e[i] = Math.min(1, t / a) * Math.exp(-t / d); } return e; };
  const tone = (f, len, a, d, harm = [1]) => { const e = env(len, a, d); const x = new Float32Array(len); for (let i = 0; i < len; i++) { let v = 0; harm.forEach((h, k) => { v += Math.sin((2 * Math.PI * f * (k + 1) * i) / SR) * h; }); x[i] = v * e[i]; } return x; };
  if (kind === 'ambient') {
    const bpm = 66, beat = 60 / bpm, bar = beat * 4; const chords = [[57, 60, 64, 67], [53, 57, 60, 64], [48, 52, 55, 59], [55, 59, 62, 64]];
    const bars = Math.ceil(seconds / bar) + 1;
    for (let b = 0; b < bars; b++) {
      const ch = chords[b % 4]; const t0 = b * bar;
      ch.forEach((m, i) => { const len = N(bar * 1.5); const x = new Float32Array(len); const f1 = hz(m), f2 = hz(m) * 1.003; for (let k = 0; k < len; k++) { const t = k / SR; const e = Math.min(1, t / 1.1) * Math.min(1, (len / SR - t) / 1.2); x[k] = (Math.sin(2 * Math.PI * f1 * t) + Math.sin(2 * Math.PI * f2 * t) * 0.8 + Math.sin(2 * Math.PI * f1 * 2 * t) * 0.18) * e; } add(t0, x, 0.07); });
      add(t0, tone(hz(ch[0] - 24), N(bar * 1.2), 0.5, 2.2), 0.2);
      const pent = [0, 2, 4, 7, 9]; for (let s = 0; s < 4; s++) { if (R() < 0.7) { const note = ch[0] + 12 + pent[Math.floor(R() * 5)]; add(t0 + s * beat + (R() < 0.4 ? beat * 0.5 : 0), tone(hz(note), N(1.6), 0.004, 0.45, [1, 0.3, 0.1]), 0.1); } }
    }
    // écho doux
    const d1 = N(0.42); for (let i = n - 1; i >= d1; i--) o[i] += o[i - d1] * 0.28;
  } else {
    const bpm = { mode: 118, beaute: 98, promo: 128 }[style] || 110; const beat = 60 / bpm;
    const kick = (() => { const len = N(0.32); const e = new Float32Array(len); let ph = 0; for (let i = 0; i < len; i++) { const t = i / SR; ph += (2 * Math.PI * (48 + 110 * Math.exp(-t * 28))) / SR; e[i] = Math.sin(ph) * Math.exp(-t * 11); } return e; })();
    const noise = (len, dec, hp) => { const e = new Float32Array(len); let last = 0; for (let i = 0; i < len; i++) { const w = R() * 2 - 1; const v = w - last * hp; last = w; e[i] = v * Math.exp(-(i / SR) / dec); } return e; };
    const hat = noise(N(0.06), 0.018, 0.95), ohat = noise(N(0.2), 0.07, 0.95), clap = noise(N(0.22), 0.05, 0.6), shaker = noise(N(0.09), 0.03, 0.9);
    const chords = style === 'beaute' ? [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]] : [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]];
    const bars = Math.ceil(seconds / (beat * 4));
    for (let b = 0; b < bars; b++) {
      const ch = chords[b % 4]; const t0 = b * beat * 4; const root = ch[0] - 24; const soft = style === 'beaute'; const four = style === 'promo';
      if (soft) {
        ch.forEach((m) => add(t0, tone(hz(m), N(beat * 4), 0.25, 3.0, [1, 0.3]), 0.08));
        for (let s = 0; s < 8; s++) add(t0 + s * beat * 0.5, tone(hz(ch[s % 3] + 12), N(0.7), 0.004, 0.22, [1, 0.35, 0.12]), 0.07);
        add(t0, tone(hz(root), N(beat * 1.9), 0.01, 0.6), 0.2); add(t0 + beat * 2, tone(hz(root), N(beat * 1.9), 0.01, 0.6), 0.16);
        add(t0, kick, 0.5); add(t0 + beat * 2.5, kick, 0.35); for (let s = 0; s < 8; s++) add(t0 + s * beat * 0.5 + (s % 2 ? beat * 0.06 : 0), shaker, 0.09); add(t0 + beat, clap, 0.1); add(t0 + beat * 3, clap, 0.1);
      } else {
        for (let s = 0; s < 4; s++) { if (four || s % 2 === 0) add(t0 + s * beat, kick, 0.8); }
        if (!four) add(t0 + beat * 2.5, kick, 0.6);
        add(t0 + beat, clap, 0.28); add(t0 + beat * 3, clap, 0.28);
        for (let s = 0; s < 8; s++) add(t0 + s * beat * 0.5, hat, s % 2 ? 0.2 : 0.1); if (four) for (let s = 0; s < 4; s++) add(t0 + s * beat + beat * 0.5, ohat, 0.16);
        for (let s = 0; s < 8; s++) { const note = s % 4 === 3 ? root + 12 : root; add(t0 + s * beat * 0.5, tone(hz(note), N(0.2), 0.004, four ? 0.09 : 0.12, [1, 0.4, 0.2]), four ? 0.32 : 0.26); }
        [0.5, 1.5, 2.5, 3.5].forEach((off) => ch.forEach((m) => add(t0 + off * beat, tone(hz(m), N(0.22), 0.003, 0.09, [1, 0.5, 0.3]), 0.07)));
        if (four) for (let s = 0; s < 8; s++) add(t0 + s * beat * 0.5, tone(hz(ch[s % 3] + 24), N(0.14), 0.002, 0.05, [1, 0.3]), 0.045);
      }
    }
  }
  let pk = 0; for (let i = 0; i < n; i++) pk = Math.max(pk, Math.abs(o[i])); const k = pk ? 0.85 / pk : 1; for (let i = 0; i < n; i++) o[i] *= k;
  return o;
}

/** Mixage final : voix + effets + musique (musique et effets baissent sous la voix) → fichier WAV 16 bits. */
function mix({ music: mu, sfx, voices, seconds, hasVoice, musicLevel = 0.6 }) {
  const n = Math.ceil(seconds * SR); const out = new Float32Array(n); const duck = new Float32Array(n);
  voices.forEach(({ at, pcm }) => { const i0 = Math.floor(at * SR); for (let i = 0; i < pcm.length && i0 + i < n; i++) out[i0 + i] += pcm[i] / 32768; for (let i = Math.max(0, i0 - 2400); i < Math.min(n, i0 + pcm.length + 7200); i++) duck[i] = 1; });
  let sm = 0; const base = hasVoice ? musicLevel * 0.62 : musicLevel;
  for (let i = 0; i < n; i++) {
    sm += (duck[i] - sm) * (duck[i] > sm ? 0.003 : 0.00045); // l'atténuation s'installe vite et se relâche doucement
    const fade = Math.max(0, Math.min(1, i / (0.15 * SR), (n - i) / (1.4 * SR)));
    const musicG = base * (1 - 0.68 * sm) * fade; const sfxG = 1 - 0.45 * sm;
    out[i] += (mu[i] || 0) * musicG + (sfx[i] || 0) * sfxG * 0.9;
  }
  let pk = 0; for (let i = 0; i < n; i++) pk = Math.max(pk, Math.abs(out[i])); const k = pk > 0.92 ? 0.92 / pk : 1;
  const pcm = Buffer.alloc(n * 2); for (let i = 0; i < n; i++) pcm.writeInt16LE(Math.round(clamp(out[i] * k) * 32767), i * 2);
  const h = Buffer.alloc(44); h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([h, pcm]);
}

module.exports = { SR, music, sfxTrack, mix, FX };
