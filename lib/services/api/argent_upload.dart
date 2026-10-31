import 'dart:typed_data';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:dio/dio.dart';

import 'api_gateway.dart';

/// Envoi direct d'un fichier vers le stockage (URL signée demandée à l'API, dépôt, puis confirmation).
/// Utilisé par la musique, les stickers, les cartes et le studio. [private] : fichier payant ou original d'artiste (clé privée).
class ArgentUpload {
  ArgentUpload._();

  static ApiClient get _c => ApiGateway.instance.client;

  /// Renvoie l'identifiant d'envoi (`upload_id`) à passer à la création de l'objet.
  static Future<String> bytes(Uint8List data, {required String contentType, bool private = false, void Function(double)? onProgress}) async {
    final r = await _c.post('/uploads', body: {'content_type': contentType, 'size': data.length, if (private) 'private': true});
    final d = Map<String, dynamic>.from(ApiClient.data(r) as Map);
    final id = d['upload_id'] as String;
    final headers = Map<String, dynamic>.from(d['headers'] as Map? ?? {'Content-Type': contentType});
    final res = await Dio().put<dynamic>(
      d['url'] as String,
      data: Stream.fromIterable([data]),
      options: Options(
        headers: {...headers, Headers.contentLengthHeader: data.length},
        validateStatus: (_) => true,
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 2),
      ),
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) onProgress(sent / total);
      },
    );
    final code = res.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw ApiException(status: code, code: 'upload_failed', message: "L'envoi du fichier a échoué. Réessaie.");
    }
    await _c.post('/uploads/$id/complete');
    return id;
  }

  static String imageType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
