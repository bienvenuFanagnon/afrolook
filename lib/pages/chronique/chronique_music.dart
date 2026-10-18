import '../studio/montage/montage_music.dart';

/// Musique choisie pour une chronique : un extrait de 5 à 30 s lu en boucle pendant que la chronique est affichée.
class ChroniqueMusic {
  ChroniqueMusic({
    required this.kind,
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    this.volume = 0.7,
    this.keepVideoSound = false,
    this.coins = 0,
  });

  /// À partir du choix dans la liste des musiques (gratuites d'Afrolook ou sons d'artistes) et de l'adresse de l'extrait.
  factory ChroniqueMusic.from(MontageMusic m, String url) {
    final dur = m.durationMs > 0 ? m.durationMs : 30000;
    return ChroniqueMusic(
      kind: m.type,
      id: m.id,
      title: m.title,
      artist: m.isArtist ? m.subtitle.split(' · ').first : 'Musique Afrolook',
      url: url,
      startMs: 0,
      endMs: dur < maxClipMs ? dur : maxClipMs,
      durationMs: dur,
      coins: m.paid ? m.useCoins : 0,
    );
  }

  static const int minClipMs = 5000;
  static const int maxClipMs = 30000;

  final String kind; // 'free' | 'artist'
  final String id;
  final String title;
  final String artist;
  final String url;
  final int durationMs;
  int startMs;
  int endMs;
  double volume;

  /// Vidéo : garder le son d'origine (mélangé à la musique) au lieu de le remplacer.
  bool keepVideoSound;

  /// Prix d'utilisation en pièces (0 : gratuit). Payé à la publication.
  final int coins;

  bool get isArtist => kind == 'artist';
  int get clipMs => endMs - startMs;

  /// Remet début et fin dans les limites : 5 s au moins, 30 s au plus, sans dépasser la durée de l'extrait.
  void clamp() {
    startMs = startMs.clamp(0, durationMs);
    endMs = endMs.clamp(startMs, durationMs);
    final minLen = durationMs < minClipMs ? durationMs : minClipMs;
    if (endMs - startMs < minLen) endMs = (startMs + minLen).clamp(0, durationMs);
    if (endMs - startMs < minLen) startMs = (endMs - minLen).clamp(0, durationMs);
    if (endMs - startMs > maxClipMs) endMs = startMs + maxClipMs;
  }
}
