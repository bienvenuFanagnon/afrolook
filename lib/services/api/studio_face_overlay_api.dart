import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../beauty.dart';
import 'api_gateway.dart';
import 'argent_upload.dart';
import 'posts_api.dart';
import 'wallet_api.dart';

/// Un instant de la trajectoire du visage pendant le tournage : position du centre en fractions (0 à 1) de l'image redressée ; null = visage perdu.
class FaceTrackPoint {
  const FaceTrackPoint(this.tMs, this.x, this.y);
  final int tMs;
  final double? x;
  final double? y;
  Map<String, dynamic> toJson() => {'t': tMs, 'x': x, 'y': y};
}

/// Beauté d'une vidéo filmée : couleurs sur toute l'image, peau adoucie autour du visage suivi (le son n'est pas touché).
class StudioBeautyApi {
  StudioBeautyApi._();

  static Future<File> apply(File video, BeautyLevel beauty, List<FaceTrackPoint> track, {void Function(double)? onProgress}) async {
    final id = await UploadsApi.upload(video, contentType: 'video/mp4', onProgress: onProgress);
    final res = await ApiGateway.instance.client.post('/studio/beauty', body: {
      'upload_id': id,
      'beauty': beauty.toJson(),
      if (beauty.smooth > 0 && track.any((p) => p.x != null)) 'track': [for (final p in track) p.toJson()],
    });
    final url = WalletApi.map(res)['url'] as String;
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/beaute_${DateTime.now().microsecondsSinceEpoch}.mp4').writeAsBytes(r.bodyBytes, flush: true);
  }
}

/// Filtre de visage sur une vidéo filmée : le serveur pose l'image du filtre sur la trajectoire notée pendant le tournage (le son n'est pas touché).
class StudioFaceOverlayApi {
  StudioFaceOverlayApi._();

  static Future<File> apply(File video, List<int> filterPng, List<FaceTrackPoint> track, {void Function(double)? onProgress}) async {
    final videoId = await UploadsApi.upload(video, contentType: 'video/mp4', onProgress: onProgress);
    final imageId = await ArgentUpload.bytes(Uint8List.fromList(filterPng), contentType: 'image/png');
    final res = await ApiGateway.instance.client.post('/studio/face-overlay', body: {'upload_id': videoId, 'overlay_upload_id': imageId, 'track': [for (final p in track) p.toJson()]});
    final url = WalletApi.map(res)['url'] as String;
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/filtre_${DateTime.now().microsecondsSinceEpoch}.mp4').writeAsBytes(r.bodyBytes, flush: true);
  }
}
