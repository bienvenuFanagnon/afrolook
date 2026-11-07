import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api_gateway.dart';
import 'posts_api.dart';
import 'wallet_api.dart';

/// Outil « Couper » : le serveur garde seulement le passage choisi d'une vidéo ou d'un audio (découpe précise, ré-encodée), puis l'application récupère le nouveau fichier.
class StudioTrimApi {
  StudioTrimApi._();

  /// Découpe [file] entre [startMs] et [endMs] et rend le nouveau fichier (même nature : vidéo ou audio).
  static Future<File> trim(File file, {required bool isVideo, required int startMs, required int endMs, void Function(double)? onProgress}) async {
    final id = await UploadsApi.upload(file, contentType: isVideo ? 'video/mp4' : 'audio/mp4', onProgress: onProgress);
    final res = await ApiGateway.instance.client.post('/studio/trim', body: {'upload_id': id, 'start_ms': startMs, 'end_ms': endMs}, longJob: true);
    final url = WalletApi.map(res)['url'] as String;
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/coupe_${DateTime.now().microsecondsSinceEpoch}.${isVideo ? 'mp4' : 'm4a'}').writeAsBytes(r.bodyBytes, flush: true);
  }
}
