import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/post_widget.dart';

/// Brouillon du parcours de création (un seul, gardé sur le téléphone) : le média retouché, son origine, l'effet de voix et les widgets posés.
/// Enregistré quand la personne quitte l'éditeur en choisissant « Enregistrer en brouillon », repris depuis l'écran « Créer ».
class CreateDraft {
  CreateDraft({required this.path, required this.isVideo, required this.source, this.voiceEffect, this.widgets = const [], this.touched = false, this.savedAt});

  final String path;
  final bool isVideo;
  final String source;
  final String? voiceEffect;
  final List<PostWidget> widgets;
  final bool touched;
  final DateTime? savedAt;

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/create_draft');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Copie le média dans le dossier des brouillons (le fichier d'origine est temporaire) et écrit la description.
  static Future<void> save({required String path, required bool isVideo, required String source, String? voiceEffect, List<PostWidget> widgets = const [], bool touched = false}) async {
    final d = await _dir();
    final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : (isVideo ? '.mp4' : '.jpg');
    final target = File('${d.path}/media$ext');
    if (File(path).absolute.path != target.absolute.path) {
      for (final f in d.listSync().whereType<File>().where((f) => f.path.contains('/media') || f.path.contains('\\media'))) {
        if (f.absolute.path != File(path).absolute.path) await f.delete();
      }
      await File(path).copy(target.path);
    }
    await File('${d.path}/draft.json').writeAsString(jsonEncode({
      'media': target.path,
      'video': isVideo,
      'source': source,
      'voice': voiceEffect,
      'touched': touched,
      'widgets': [for (final w in widgets) w.toApi()],
      'saved_at': DateTime.now().toIso8601String(),
    }));
  }

  /// Le brouillon enregistré, ou null s'il n'y en a pas (ou si son média a disparu).
  static Future<CreateDraft?> load() async {
    try {
      final d = await _dir();
      final f = File('${d.path}/draft.json');
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final media = '${j['media']}';
      if (!await File(media).exists()) return null;
      return CreateDraft(
        path: media,
        isVideo: j['video'] == true,
        source: '${j['source']}',
        voiceEffect: j['voice'] as String?,
        touched: j['touched'] == true,
        widgets: PostWidget.listFromApi(j['widgets']),
        savedAt: DateTime.tryParse('${j['saved_at']}'),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final d = await _dir();
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }
}
