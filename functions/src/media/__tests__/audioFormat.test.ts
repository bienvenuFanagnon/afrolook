import { sniffAudio } from "../audioFormat";

const bytes = (...a: Array<number | string>) => Uint8Array.from(a.flatMap((x) => (typeof x === "string" ? [...x].map((c) => c.charCodeAt(0)) : [x])));

describe("sniffAudio", () => {
  it("reconnaît les formats courants", () => {
    expect(sniffAudio(bytes("ID3", 4, 0)).ext).toBe("mp3");
    expect(sniffAudio(bytes(0xff, 0xfb, 0x90, 0)).ext).toBe("mp3");
    expect(sniffAudio(bytes(0xff, 0xf1, 0x50, 0x80)).ext).toBe("aac");
    expect(sniffAudio(bytes(0, 0, 0, 0x20, "ftypM4A ")).ext).toBe("m4a");
    expect(sniffAudio(bytes("RIFF", 0, 0, 0, 0, "WAVE")).ext).toBe("wav");
    expect(sniffAudio(bytes("fLaC", 0)).ext).toBe("flac");
  });
  it("marque ce qu'Apple ne lit pas", () => {
    expect(sniffAudio(bytes("OggS", 0)).apple).toBe(false);
    expect(sniffAudio(bytes(0x1a, 0x45, 0xdf, 0xa3, 1)).apple).toBe(false);
    expect(sniffAudio(bytes("#!AMR", 10)).apple).toBe(false);
    expect(sniffAudio(bytes("ID3", 4, 0)).apple).toBe(true);
  });
  it("fichier trop court ou inconnu : m4a par défaut", () => {
    expect(sniffAudio(bytes(1, 2))).toMatchObject({ mime: "audio/mp4", ext: "m4a" });
    expect(sniffAudio(new Uint8Array(16).fill(7))).toMatchObject({ mime: "audio/mp4" });
  });
});
