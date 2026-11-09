import '../widget_raster.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:crypto/crypto.dart' show sha1;
import 'dart:convert' show utf8;
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
  /// [layers] : `pill` (pastille), `logo` (silhouette), `qr` (tuile du QR) et, pour la fin Afrolook, `story_pill`, `story_tag` (720 × 1280) et `post_pill`, `post_tag` (720 × 900) et `land_pill`, `land_tag` (1280 × 720).
  /// Ordre fixe des calques pour l'empreinte : le même que sur le serveur (`StudioWatermarkController::LAYER_ORDER`).
  static const _layerOrder = ['pill', 'logo', 'qr', 'story_pill', 'story_tag', 'post_pill', 'post_tag', 'land_pill', 'land_tag'];

  /// Empreinte des calques : sha1 de « role:sha1(octets) » joints par « | », dans l'ordre fixe. Deux demandes avec les mêmes dessins ont la même empreinte,
  /// donc la même copie gardée sur le serveur (pour tout le monde : la signature est celle du créateur, pas de la personne qui télécharge).
  @visibleForTesting
  static String layersHash(Map<String, Uint8List> layers) {
    final parts = [for (final role in _layerOrder) if (layers[role] != null) '$role:${sha1.convert(layers[role]!)}'];
    return sha1.convert(utf8.encode(parts.join('|'))).toString();
  }

  /// [animated] : widgets qui défilent (compte à rebours), une bande d'images par widget (une image par seconde). [asVideo] : publication IMAGE avec un widget animé : la copie téléchargée
  /// est une vidéo de [videoSeconds] secondes (l'image, le compte à rebours qui défile, la signature).
  static Future<String> signedDownload(String postId, Map<String, Uint8List> layers,
      {void Function(String step)? onStep, List<WidgetLayer> widgets = const [], List<StripLayer> animated = const [], bool asVideo = false, int videoSeconds = 10}) async {
    // copie déjà gardée pour cette vidéo et ces dessins ? on la prend tout de suite : rien à envoyer ni à fabriquer
    // (avec des widgets affichés, le serveur calcule lui-même l'empreinte, qui compte leur dessin et leur place : pas de sonde ici)
    final hash = layersHash(layers);
    try {
      if (widgets.isNotEmpty || animated.isNotEmpty || asVideo) throw StateError('widgets');
      final hit = WalletApi.map(await ApiGateway.instance.client.get('/posts/$postId/signed-download/cached', query: {'hash': hash}));
      if (hit['url'] is String && (hit['url'] as String).isNotEmpty) return hit['url'] as String;
    } catch (_) {
      // pas de copie (404) ou serveur ancien : on la fabrique
    }
    onStep?.call('sending');
    final ids = <String, String>{};
    await Future.wait([
      for (final e in layers.entries)
        ArgentUpload.bytes(e.value, contentType: 'image/png').then((id) => ids[e.key] = id),
    ]);
    // widgets du créateur tels qu'affichés maintenant : un PNG par widget, posé par le serveur dans la vidéo téléchargée
    final widgetBody = <Map<String, Object?>>[];
    for (final w in widgets.take(5)) {
      final id = await ArgentUpload.bytes(w.png, contentType: 'image/png');
      widgetBody.add({'upload_id': id, 'x': w.x, 'y': w.y, 'w': w.width, if (w.start != null) 'start': w.start, if (w.end != null) 'end': w.end});
    }
    // widgets animés : une bande par widget (le dessin change à chaque téléchargement : jamais de copie gardée)
    final animatedBody = <Map<String, Object?>>[];
    for (final s in animated.take(9)) {
      final id = await ArgentUpload.bytes(s.png, contentType: 'image/png');
      animatedBody.add({'upload_id': id, 'frames': s.frames, 'x': s.x, 'y': s.y, 'w': s.width, if (s.from > 0) 'from': s.from, if (!s.hold) 'hold': false});
    }
    final body = <String, Object?>{
      'wm_upload_id': ids['pill'],
      if (widgetBody.isNotEmpty) 'widgets': widgetBody,
      if (animatedBody.isNotEmpty) 'animated': animatedBody,
      if (asVideo) ...{'as_video': true, 'video_seconds': videoSeconds},
      if (ids['logo'] != null) 'logo_upload_id': ids['logo'],
      if (ids['qr'] != null) 'qr_upload_id': ids['qr'],
      'outro': {
        for (final k in const ['story_pill', 'story_tag', 'post_pill', 'post_tag', 'land_pill', 'land_tag'])
          if (ids[k] != null) k: ids[k],
      },
      'async': true,
      if (widgetBody.isEmpty && animatedBody.isEmpty && !asVideo) 'layers_hash': hash,
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

  /// Signe une vidéo de la personne (copie enregistrée dans sa galerie). [logo] et [outro] (mêmes calques que pour un téléchargement : `story_pill`, `story_tag`, `post_pill`, `post_tag`,
  /// `land_pill`, `land_tag`) ajoutent le logo animé et la fin Afrolook : la copie porte la MÊME marque qu'une vidéo téléchargée.
  static Future<File> sign(File video, Uint8List pill, {Uint8List? logo, Map<String, Uint8List> outro = const {}, void Function(double)? onProgress}) async {
    final videoId = await UploadsApi.upload(video, contentType: 'video/mp4', onProgress: onProgress);
    final pillId = await ArgentUpload.bytes(pill, contentType: 'image/png');
    final logoId = logo == null ? null : await ArgentUpload.bytes(logo, contentType: 'image/png');
    final outroIds = <String, String>{};
    for (final e in outro.entries) {
      outroIds[e.key] = await ArgentUpload.bytes(e.value, contentType: 'image/png');
    }
    final res = await ApiGateway.instance.client.post('/studio/watermark',
        body: {'upload_id': videoId, 'wm_upload_id': pillId, if (logoId != null) 'logo_upload_id': logoId, if (outroIds.isNotEmpty) 'outro': outroIds}, longJob: true);
    final url = WalletApi.map(res)['url'] as String;
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/signee_${DateTime.now().microsecondsSinceEpoch}.mp4').writeAsBytes(r.bodyBytes, flush: true);
  }
}
