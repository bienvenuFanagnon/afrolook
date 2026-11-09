import 'dart:math' as math;

/// Le son posé sur un film (08/11/2026) : ce qu'on entend dans l'aperçu est ce que le serveur fabrique.
///  - le son commence à [startMs] et dure autant que le film ([clipMs]) ;
///  - plus court que le film : il est répété, chaque reprise enchaînée à la précédente par un petit fondu croisé ;
///  - plus long : il est coupé à la fin du film ;
///  - fondu d'entrée de 0,3 s, fondu de sortie calé sur la fin du film (1,5 s au plus, un quart du film au plus).
class MusicClipPlan {
  const MusicClipPlan({required this.clipMs, required this.startMs, this.trackMs});

  /// Durée du film (millisecondes).
  final int clipMs;

  /// Début choisi dans le son.
  final int startMs;

  /// Durée entière du son, si on la connaît.
  final int? trackMs;

  static const int fadeInMs = 300;

  int get fadeOutMs => math.min(1500, clipMs ~/ 4);

  /// Son disponible à partir du point de départ.
  int? get availableMs => trackMs == null ? null : math.max(0, trackMs! - startMs);

  /// Le son (depuis son départ) est plus court que le film : il est répété.
  bool get loops => availableMs != null && availableMs! > 300 && availableMs! < clipMs - 50;

  /// Le son est plus long que le film d'au moins une seconde : il est coupé.
  bool get cuts => availableMs != null && availableMs! > clipMs + 1000;

  /// Durée du fondu croisé entre deux reprises.
  int get crossfadeMs => availableMs == null ? 0 : math.min(400, availableMs! ~/ 3);

  /// Nombre de fois que le son est joué pour remplir le film.
  int get repeats {
    if (!loops) return 1;
    final a = availableMs!;
    return math.max(2, ((clipMs - crossfadeMs) / math.max(100, a - crossfadeMs)).ceil());
  }

  /// Début du son pour que SA FIN tombe sur la fin du film (null si le son n'est pas plus long que le film).
  int? get alignedStartMs => trackMs != null && trackMs! > clipMs ? trackMs! - clipMs : null;

  bool get isAligned => alignedStartMs != null && (startMs - alignedStartMs!).abs() < 200;

  /// Volume (0 à 1) à l'instant [elapsedMs] du film : fondu d'entrée, fondu de sortie, et un petit creux à chaque raccord de répétition (l'aperçu n'a qu'un lecteur).
  double volumeAt(int elapsedMs) {
    if (elapsedMs < 0 || elapsedMs >= clipMs) return 0;
    var v = 1.0;
    if (elapsedMs < fadeInMs) v = elapsedMs / fadeInMs;
    final left = clipMs - elapsedMs;
    if (fadeOutMs > 0 && left < fadeOutMs) v = math.min(v, left / fadeOutMs);
    if (loops) {
      final seam = availableMs! - crossfadeMs;
      if (seam > 0) {
        final k = (elapsedMs / seam).round();
        if (k >= 1) {
          final dist = (elapsedMs - k * seam).abs();
          final half = math.max(1, crossfadeMs ~/ 2);
          if (dist < half) v *= 1 - 0.5 * (1 - dist / half);
        }
      }
    }
    return v.clamp(0.0, 1.0);
  }

  /// « 1:05 » : minutes et secondes.
  static String mmss(int ms) {
    final t = (ms / 1000).round();
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }
}
