import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api_gateway.dart';
import 'posts_api.dart';
import 'wallet_api.dart';

/// Un passage parlé de la vidéo, avec le texte à afficher en sous-titre.
class SubtitleSegment {
  SubtitleSegment({required this.startMs, required this.endMs, required this.text});

  int startMs;
  int endMs;
  String text;

  factory SubtitleSegment.fromJson(Map<String, dynamic> j) => SubtitleSegment(startMs: (j['start_ms'] as num).toInt(), endMs: (j['end_ms'] as num).toInt(), text: (j['text'] ?? '').toString());

  Map<String, dynamic> toJson() => {'start_ms': startMs, 'end_ms': endMs, 'text': text.trim()};
}

/// Sous-titres automatiques : le serveur transcrit la voix, la personne relit et corrige, puis le serveur incruste le texte dans la vidéo.
class StudioSubtitlesApi {
  StudioSubtitlesApi._();

  /// Vrai si le serveur sait transcrire (service réglé) ; faux sinon : l'outil reste caché.
  static Future<bool> available() async {
    try {
      final res = await ApiGateway.instance.client.get('/studio/subtitles/status');
      return WalletApi.map(res)['available'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Envoie la vidéo et rend les passages reconnus (à relire avant l'incrustation).
  static Future<List<SubtitleSegment>> transcribe(File video, {String? language, void Function(double)? onProgress}) async {
    final id = await UploadsApi.upload(video, contentType: 'video/mp4', onProgress: onProgress);
    final res = await ApiGateway.instance.client.post('/studio/subtitles', body: {'upload_id': id, if (language != null) 'language': language}, longJob: true);
    final list = (WalletApi.map(res)['segments'] as List?) ?? const [];
    return [for (final s in list) SubtitleSegment.fromJson(Map<String, dynamic>.from(s as Map))];
  }

  /// Incruste les [segments] dans la vidéo et rend le nouveau fichier.
  static Future<File> burn(File video, List<SubtitleSegment> segments, {void Function(double)? onProgress}) async {
    final id = await UploadsApi.upload(video, contentType: 'video/mp4', onProgress: onProgress);
    final res = await ApiGateway.instance.client.post('/studio/subtitles/burn', body: {'upload_id': id, 'segments': [for (final s in segments) s.toJson()]}, longJob: true);
    final url = WalletApi.map(res)['url'] as String;
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/soustitres_${DateTime.now().microsecondsSinceEpoch}.mp4').writeAsBytes(r.bodyBytes, flush: true);
  }
}
