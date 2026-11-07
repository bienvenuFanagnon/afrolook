import 'dart:io';
import 'dart:typed_data';

import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api_gateway.dart';
import 'argent_upload.dart';
import 'posts_api.dart';
import 'wallet_api.dart';

/// Signature d'une vidéo filmée ou choisie : le serveur incruste la pastille mobile « Afrolook + #canal / @pseudo » (dessinée par l'application) et rend la vidéo signée.
class StudioWatermarkApi {
  StudioWatermarkApi._();

  /// Téléchargement d'une vidéo de publication : le serveur pose la signature (silhouette animée du logo, « Afrolook », #canal ou @pseudo, qui change de place trois fois) sur une copie
  /// de la vidéo, ajoute la fin Afrolook si elle ne l'a pas (avec le QR de la publication) et rend l'adresse du fichier. Le travail se fait APRÈS la réponse : on l'attend en interrogeant
  /// le serveur toutes les 2 secondes (une requête longue serait coupée par Cloudflare). [onStep] reçoit « sending » puis « working » (pour la fenêtre d'avancement).
  ///
  /// [layers] : `pill` (pastille), `logo` (silhouette), `qr` (tuile du QR) et, pour la fin Afrolook, `story_pill`, `story_tag` (720 × 1280) et `post_pill`, `post_tag` (720 × 900).
  static Future<String> signedDownload(String postId, Map<String, Uint8List> layers, {void Function(String step)? onStep}) async {
    onStep?.call('sending');
    final ids = <String, String>{};
    await Future.wait([
      for (final e in layers.entries)
        ArgentUpload.bytes(e.value, contentType: 'image/png').then((id) => ids[e.key] = id),
    ]);
    final body = <String, Object?>{
      'wm_upload_id': ids['pill'],
      if (ids['logo'] != null) 'logo_upload_id': ids['logo'],
      if (ids['qr'] != null) 'qr_upload_id': ids['qr'],
      'outro': {
        for (final k in const ['story_pill', 'story_tag', 'post_pill', 'post_tag'])
          if (ids[k] != null) k: ids[k],
      },
      'async': true,
    };
    final res = await ApiGateway.instance.client.post('/posts/$postId/signed-download', body: body, longJob: true);
    final first = WalletApi.map(res);
    if (first['url'] is String) return first['url'] as String;   // déjà fabriqué (copie gardée) ou ancien serveur synchrone
    return _wait(postId, onStep);
  }

  /// Attend la fin du travail du serveur : « running » on patiente, « done » l'adresse, « failed » le message précis.
  static Future<String> _wait(String postId, void Function(String step)? onStep) async {
    final deadline = DateTime.now().add(const Duration(minutes: 8));
    var misses = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      Map<String, dynamic> st;
      try {
        st = WalletApi.map(await ApiGateway.instance.client.get('/posts/$postId/signed-download'));
        misses = 0;
      } on ApiException catch (e) {
        if (e.status == 404) throw ApiException(status: 404, code: 'watermark_failed', message: 'La signature a été perdue côté serveur. Réessaie.');
        if (++misses >= 5) rethrow;
        continue;
      }
      switch (st['status']) {
        case 'done':
          final data = st['data'];
          final url = data is Map ? (data['url'] ?? (data['data'] is Map ? (data['data'] as Map)['url'] : null)) : null;
          if (url is String && url.isNotEmpty) return url;
          throw ApiException(status: 500, code: 'watermark_failed', message: 'La vidéo signée est introuvable. Réessaie.');
        case 'failed':
          throw ApiException(status: (st['http'] as num?)?.toInt() ?? 500, code: '${st['code'] ?? 'watermark_failed'}', message: '${st['message'] ?? 'La signature a échoué.'}');
        default:
          onStep?.call('working');
      }
    }
    throw ApiException(status: 504, code: 'watermark_timeout', message: 'La signature prend trop de temps. Réessaie.');
  }

  static Future<File> sign(File video, Uint8List pill, {void Function(double)? onProgress}) async {
    final videoId = await UploadsApi.upload(video, contentType: 'video/mp4', onProgress: onProgress);
    final pillId = await ArgentUpload.bytes(pill, contentType: 'image/png');
    final res = await ApiGateway.instance.client.post('/studio/watermark', body: {'upload_id': videoId, 'wm_upload_id': pillId}, longJob: true);
    final url = WalletApi.map(res)['url'] as String;
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/signee_${DateTime.now().microsecondsSinceEpoch}.mp4').writeAsBytes(r.bodyBytes, flush: true);
  }
}
