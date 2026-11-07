import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api_gateway.dart';
import 'argent_upload.dart';
import 'posts_api.dart';
import 'wallet_api.dart';

/// Signature d'une vidéo filmée ou choisie : le serveur incruste la pastille mobile « Afrolook + @pseudo » (dessinée par l'application) et rend la vidéo signée.
class StudioWatermarkApi {
  StudioWatermarkApi._();

  /// Téléchargement d'une vidéo de publication : le serveur pose la signature (logo + @pseudo du créateur, qui change de coin) sur une copie de la vidéo et rend son adresse.
  static Future<String> signedDownload(String postId, Uint8List pill) async {
    final pillId = await ArgentUpload.bytes(pill, contentType: 'image/png');
    final res = await ApiGateway.instance.client.post('/posts/$postId/signed-download', body: {'wm_upload_id': pillId}, longJob: true);
    return WalletApi.map(res)['url'] as String;
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
