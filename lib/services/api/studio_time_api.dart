import 'dart:io';

import 'package:flutter/material.dart' show Icons;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api_gateway.dart';
import 'posts_api.dart';
import 'wallet_api.dart';

/// Effets de temps du Studio : accéléré, ralenti, rembobinage, boomerang, rampe de vitesse (le serveur refait la vidéo, l'application récupère le nouveau fichier).
class StudioTimeApi {
  StudioTimeApi._();

  /// Effets proposés : clé du serveur, libellé, icône et facteur de durée du résultat (null = rampe : durée × 1,17).
  static const effects = [
    ('fast2', 'Accéléré ×2', Icons.fast_forward_rounded, 0.5),
    ('fast4', 'Accéléré ×4', Icons.skip_next_rounded, 0.25),
    ('slow', 'Ralenti', Icons.slow_motion_video_rounded, 2.0),
    ('reverse', 'Rembobinage', Icons.fast_rewind_rounded, 1.0),
    ('boomerang', 'Boomerang', Icons.repeat_rounded, 2.0),
    ('ramp', 'Rampe de vitesse', Icons.show_chart_rounded, 1.1667),
  ];

  /// Durée maximale de la vidéo selon l'effet (le rembobinage et le boomerang gardent tout en mémoire).
  static int maxSeconds(String key) => key == 'reverse' || key == 'boomerang' ? 30 : 90;

  static Future<File> apply(File file, String effect, {void Function(double)? onProgress}) async {
    final id = await UploadsApi.upload(file, contentType: 'video/mp4', onProgress: onProgress);
    final res = await ApiGateway.instance.client.post('/studio/time', body: {'upload_id': id, 'effect': effect});
    final url = WalletApi.map(res)['url'] as String;
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/temps_${DateTime.now().microsecondsSinceEpoch}.mp4').writeAsBytes(r.bodyBytes, flush: true);
  }
}
