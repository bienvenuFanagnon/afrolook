/**
 * Format réel d'un fichier audio, reconnu à ses premiers octets.
 * iPhone et iPad refusent un fichier dont l'étiquette ne correspond pas au contenu (un mp3 annoncé « audio/mp4 », par exemple) et
 * ne lisent ni l'ogg, ni le webm, ni l'amr : on donne donc le vrai type, et on convertit en AAC (m4a) ce qu'Apple ne sait pas lire.
 */
export interface AudioKind {
  mime: string;
  ext: string;
  /** Lisible par iPhone et iPad sans conversion. */
  apple: boolean;
}

const K = {
  mp3: { mime: "audio/mpeg", ext: "mp3", apple: true },
  m4a: { mime: "audio/mp4", ext: "m4a", apple: true },
  aac: { mime: "audio/aac", ext: "aac", apple: true },
  wav: { mime: "audio/wav", ext: "wav", apple: true },
  flac: { mime: "audio/flac", ext: "flac", apple: true },
  ogg: { mime: "audio/ogg", ext: "ogg", apple: false },
  webm: { mime: "audio/webm", ext: "webm", apple: false },
  amr: { mime: "audio/amr", ext: "amr", apple: false },
  unknown: { mime: "audio/mp4", ext: "m4a", apple: true },
} satisfies Record<string, AudioKind>;

export function sniffAudio(b: Uint8Array): AudioKind {
  const at = (i: number, s: string) => b.length >= i + s.length && [...s].every((c, k) => b[i + k] === c.charCodeAt(0));
  if (b.length < 4) return K.unknown;
  if (at(0, "ID3")) return K.mp3;
  if (at(0, "RIFF") && at(8, "WAVE")) return K.wav;
  if (at(0, "OggS")) return K.ogg;
  if (at(0, "fLaC")) return K.flac;
  if (at(4, "ftyp")) return K.m4a;
  if (at(0, "#!AMR")) return K.amr;
  if (b[0] === 0x1a && b[1] === 0x45 && b[2] === 0xdf && b[3] === 0xa3) return K.webm;
  if (b[0] === 0xff && (b[1] & 0xe0) === 0xe0) return ((b[1] >> 1) & 3) === 0 ? K.aac : K.mp3;
  return K.unknown;
}
