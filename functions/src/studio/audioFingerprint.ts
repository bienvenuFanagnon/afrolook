/**
 * Empreinte audio pour repérer les doublons : un même morceau déposé deux fois, même ré-encodé (MP3 → AAC),
 * recadré ou décalé de quelques secondes. Méthode du type « Philips » : le son est ramené à 8 kHz mono,
 * découpé en fenêtres de 128 ms (pas de 64 ms) ; l'énergie de 17 bandes de fréquences (300–3000 Hz, échelle log)
 * donne 16 bits par fenêtre selon le sens de l'évolution de l'énergie entre bandes voisines et entre fenêtres voisines.
 * Deux enregistrements identiques ont ~0 % de bits différents (BER) ; un son sans rapport ~50 %.
 *
 * Limites assumées : un morceau accéléré, ralenti, transposé ou fortement remixé échappe à cette méthode
 * (l'administrateur écoute avant de valider, et chaque son peut être signalé).
 */
const N = 1024;
const HOP = 512;
const BANDS = 17;
const POP = (() => {
  const t = new Uint8Array(65536);
  for (let i = 1; i < 65536; i++) t[i] = t[i >> 1] + (i & 1);
  return t;
})();

export const FP_FRAMES_PER_SECOND = 8000 / HOP;

function fft(re: Float64Array, im: Float64Array) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      [re[i], re[j]] = [re[j], re[i]];
      [im[i], im[j]] = [im[j], im[i]];
    }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = (-2 * Math.PI) / len;
    const wr = Math.cos(ang);
    const wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let cr = 1;
      let ci = 0;
      for (let k = 0; k < len / 2; k++) {
        const a = i + k;
        const b = a + len / 2;
        const tr = re[b] * cr - im[b] * ci;
        const ti = re[b] * ci + im[b] * cr;
        re[b] = re[a] - tr;
        im[b] = im[a] - ti;
        re[a] += tr;
        im[a] += ti;
        const nr = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = nr;
      }
    }
  }
}

/** Empreinte d'un son PCM 16 bits mono à 8 kHz : un mot de 16 bits par fenêtre. */
export function fingerprint(pcm: Int16Array): Uint16Array {
  const frames = Math.floor((pcm.length - N) / HOP) + 1;
  if (frames < 3) return new Uint16Array(0);
  const lo = 300 / (8000 / N);
  const hi = 3000 / (8000 / N);
  const edges: number[] = [];
  for (let b = 0; b <= BANDS; b++) edges.push(Math.round(lo * Math.pow(hi / lo, b / BANDS)));
  const win = new Float64Array(N);
  for (let i = 0; i < N; i++) win[i] = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / (N - 1));
  const re = new Float64Array(N);
  const im = new Float64Array(N);
  const out = new Uint16Array(frames - 1);
  let prev = new Float64Array(BANDS);
  for (let f = 0; f < frames; f++) {
    const o = f * HOP;
    for (let i = 0; i < N; i++) {
      re[i] = pcm[o + i] * win[i];
      im[i] = 0;
    }
    fft(re, im);
    const e = new Float64Array(BANDS);
    for (let b = 0; b < BANDS; b++) {
      let s = 0;
      for (let k = edges[b]; k < Math.max(edges[b] + 1, edges[b + 1]); k++) s += re[k] * re[k] + im[k] * im[k];
      e[b] = s;
    }
    if (f > 0) {
      let w = 0;
      for (let m = 0; m < BANDS - 1; m++) {
        if (e[m] - e[m + 1] - (prev[m] - prev[m + 1]) > 0) w |= 1 << m;
      }
      out[f - 1] = w;
    }
    prev = e;
  }
  return out;
}

/** Plus petit taux d'erreur (bits différents) entre une fenêtre de [query] et n'importe quel endroit de [ref] (0 = identique, ~0,5 = sans rapport). */
export function bestMatch(query: Uint16Array, ref: Uint16Array, windowFrames = 320): { ber: number; offset: number } {
  const w = Math.min(windowFrames, query.length);
  if (w < 120 || ref.length < w) return { ber: 0.5, offset: -1 };
  // fenêtre prise au milieu du morceau déposé (évite silences d'intro/outro)
  const q0 = Math.max(0, Math.floor((query.length - w) / 2));
  let best = 1;
  let bestAt = -1;
  const limit = ref.length - w;
  for (let s = 0; s <= limit; s++) {
    let diff = 0;
    const cap = Math.floor(best * w * 16);
    for (let i = 0; i < w; i++) {
      diff += POP[query[q0 + i] ^ ref[s + i]];
      if (diff > cap && cap > 0) break;
    }
    const ber = diff / (w * 16);
    if (ber < best) {
      best = ber;
      bestAt = s;
    }
  }
  return { ber: best, offset: bestAt };
}

export const toBase64 = (fp: Uint16Array) => Buffer.from(fp.buffer, fp.byteOffset, fp.byteLength).toString("base64");
export const fromBase64 = (s: string) => {
  const b = Buffer.from(s, "base64");
  return new Uint16Array(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength));
};

/** En dessous : même morceau (ré-encodé ou recadré). Entre les deux : très proche, à faire vérifier. */
export const BER_SAME = 0.2;
export const BER_SIMILAR = 0.33;
