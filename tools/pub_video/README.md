# Vidéo publicitaire Afrolook (Google Ads / YouTube)

Outils qui ont produit la vidéo de 32 s (9:16, 1:1 et 16:9) : voix off (Google Text-to-Speech, voix Chirp3-HD), musique et effets générés par code, montage image par code.

- `tts.js` : génère les 7 phrases de voix off (`vo/l1.wav` … `l7.wav`). Demande d'activer l'API Text-to-Speech du projet (à désactiver ensuite).
- `build_audio.py` : musique (100 BPM), effets (sons de l'application dans `assets/sounds/`), voix, mixage avec réduction de la musique sous la voix → `mix.wav`.
- `render.py LARGEUR HAUTEUR sortie.mp4` : dessine les images (PIL) et encode avec ffmpeg (paquet `imageio-ffmpeg`). Utilise les visuels « monétisation » des stores (`raw_*` : zips fournis par le propriétaire, 1284×2778 et 1920×1080) et `assets/logo/afrolook_logo.png`.

Modifier le texte : `LINES` dans `tts.js`, horaires dans `build_audio.py` (`VO`) et `render.py` (`frame`).
