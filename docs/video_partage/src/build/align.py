"""Repère l'instant de chaque mot de la voix (reconnaissance vocale locale). Usage : python align.py sans|avec"""
import json
import os
import subprocess
import sys
from pathlib import Path

import numpy as np
from faster_whisper import WhisperModel

root = Path(os.environ.get("PROJ") or Path(__file__).resolve().parents[2])
v = sys.argv[1]
src = root / "sortie" / f"voix_complete_{v}.wav"
# audio décodé par ffmpeg (16 kHz, mono) : évite la bibliothèque de décodage de faster-whisper
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(src), "-f", "f32le", "-ac", "1", "-ar", "16000", "-"], capture_output=True, check=True).stdout
audio = np.frombuffer(raw, dtype=np.float32)
model = WhisperModel(os.environ.get("AL_MODEL", "base"), device="cpu", compute_type="int8")
segments, info = model.transcribe(audio, language="fr", word_timestamps=True, beam_size=5, vad_filter=False)
mots = []
for seg in segments:
    for w in seg.words or []:
        mots.append({"w": w.word.strip(), "s": round(w.start, 3), "e": round(w.end, 3)})
(root / "sortie" / f"mots_{v}.json").write_text(json.dumps({"duree": round(len(audio) / 16000, 3), "mots": mots}, ensure_ascii=False, indent=1), encoding="utf-8")
print(v, len(mots), "mots, durée", round(len(audio) / 16000, 2), "s")
print(" ".join(f"{m['w']}@{m['s']}" for m in mots))
