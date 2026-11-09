import 'api/api_gateway.dart';

/// Un sous-titre posé sur la vidéo d'ORIGINE (temps en millisecondes de la vidéo non coupée, à vitesse normale).
class ProjectCue {
  const ProjectCue(this.startMs, this.endMs, this.text);
  final int startMs;
  final int endMs;
  final String text;
}

/// Réglages d'une vidéo en cours de retouche, gardés EN ATTENTE tant que l'interrupteur serveur « rendu en une passe » est allumé : découpe, vitesse, voix, sous-titres.
/// Rien n'est encodé avant la fin : le serveur applique tout dans la même chaîne que le montage (voir `SinglePass` côté API).
/// Les sous-titres sont gardés dans le temps de la vidéo d'origine ; [toApi] les convertit dans le temps du film final (après découpe et vitesse).
class StudioProject {
  StudioProject({this.trimStartMs, this.trimEndMs, this.speed, this.voice, List<ProjectCue>? subtitles}) : subtitles = List.of(subtitles ?? const []);

  int? trimStartMs;
  int? trimEndMs;

  /// `fast2`, `fast4` ou `slow` (les autres effets de temps gardent leur passe séparée).
  String? speed;
  String? voice;
  List<ProjectCue> subtitles;

  static const speeds = ['fast2', 'fast4', 'slow'];

  bool get hasTrim => trimStartMs != null && trimEndMs != null;
  bool get isEmpty => !hasTrim && speed == null && voice == null && subtitles.isEmpty;
  bool get isNotEmpty => !isEmpty;

  double get _factor => switch (speed) { 'fast2' => 2.0, 'fast4' => 4.0, 'slow' => 0.5, _ => 1.0 };

  StudioProject copy() => StudioProject(trimStartMs: trimStartMs, trimEndMs: trimEndMs, speed: speed, voice: voice, subtitles: subtitles);

  /// Durée du film final (ms) pour une vidéo d'origine de [sourceMs] : découpe puis vitesse.
  int finalMs(int sourceMs) {
    final s = trimStartMs ?? 0;
    final e = (trimEndMs ?? sourceMs).clamp(0, sourceMs);
    return ((e - s) / _factor).round();
  }

  /// Corps `project` de `POST /studio/montages` ; les sous-titres sont ramenés au temps du film final (ceux qui tombent hors du passage gardé sont retirés).
  Map<String, dynamic> toApi() {
    final s = trimStartMs ?? 0;
    final e = trimEndMs;
    final cues = <Map<String, dynamic>>[];
    for (final c in subtitles) {
      final a = ((c.startMs - s) / _factor).round();
      var b = ((c.endMs - s) / _factor).round();
      if (e != null && c.startMs >= e) continue;
      if (e != null && c.endMs > e) b = ((e - s) / _factor).round();
      if (b <= 0 || b <= a) continue;
      cues.add({'start_ms': a < 0 ? 0 : a, 'end_ms': b, 'text': c.text});
    }
    return {
      if (hasTrim) 'trim': {'start_ms': trimStartMs, 'end_ms': trimEndMs},
      if (speed != null) 'speed': speed,
      if (voice != null) 'voice': voice,
      if (cues.isNotEmpty) 'subtitles': cues,
    };
  }
}

/// Interrupteur serveur `studio_single_pass` (réglage public lu dans `GET /config`) : ÉTEINT tant que le propriétaire ne l'allume pas. Éteint, rien ne change.
class SinglePassConfig {
  SinglePassConfig._();

  static bool enabled = false;
  static DateTime? _loadedAt;

  static bool parse(Object? raw) {
    if (raw is Map) return raw['enabled'] == true;
    return raw == true;
  }

  static Future<void> load({bool force = false}) async {
    if (!force && _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(minutes: 10)) return;
    try {
      final r = await ApiGateway.instance.client.get('/config');
      final root = r is Map ? r['data'] : null;
      enabled = root is Map && parse(root['studio_single_pass']);
      _loadedAt = DateTime.now();
    } catch (_) {
      // hors ligne ou erreur : on garde la valeur précédente (éteint au départ) ; les passes séparées marchent toujours
    }
  }
}
