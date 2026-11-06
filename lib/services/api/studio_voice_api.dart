import 'dart:io';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'api_gateway.dart';
import 'argent_upload.dart';
import 'wallet_api.dart';

/// Un effet de voix proposé par le serveur (identifiant technique + nom affiché).
class VoiceEffect {
  const VoiceEffect(this.id, this.name);
  final String id;
  final String name;
}

/// Effets de voix du Studio audio : l'audio de la personne est transformé par le serveur (ffmpeg) avec l'effet qu'elle a choisi, puis elle ÉCOUTE le vrai
/// résultat avant de publier. Aucune imitation de la voix d'une autre personne ; un post publié ainsi porte la mention « Voix modifiée ».
class StudioVoiceApi {
  StudioVoiceApi._();

  /// Effets connus (repli si le serveur ne répond pas : l'écran reste utilisable, le serveur valide de toute façon).
  static const fallback = [
    VoiceEffect('deep', 'Grave'),
    VoiceEffect('high', 'Aiguë'),
    VoiceEffect('radio', 'Radio'),
    VoiceEffect('echo', 'Écho'),
    VoiceEffect('hall', 'Salle'),
    VoiceEffect('anonymous', 'Anonyme'),
  ];

  static Future<List<VoiceEffect>> effects() async {
    try {
      final r = await ApiGateway.instance.client.get('/studio/voice/effects');
      final d = ApiClient.data(r);
      if (d is List) {
        final l = d.whereType<Map>().map((m) => VoiceEffect('${m['id']}', '${m['name']}')).toList();
        if (l.isNotEmpty) return l;
      }
    } catch (_) {}
    return fallback;
  }

  static String contentType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.mp3')) return 'audio/mpeg';
    if (p.endsWith('.wav')) return 'audio/wav';
    if (p.endsWith('.ogg') || p.endsWith('.opus')) return 'audio/ogg';
    if (p.endsWith('.aac')) return 'audio/aac';
    return 'audio/mp4';
  }

  /// Envoie l'audio au stockage une fois et rend son identifiant : on peut ensuite essayer plusieurs effets sans le renvoyer.
  static Future<String> upload(File audio) async => ArgentUpload.bytes(await audio.readAsBytes(), contentType: contentType(audio.path));

  /// Applique [effect] à l'audio déjà envoyé ([uploadId]) et rend le fichier transformé, prêt à écouter puis à publier.
  static Future<File> apply(String uploadId, String effect) async {
    final res = await ApiGateway.instance.client.post('/studio/voice', body: {'upload_id': uploadId, 'effect': effect});
    final url = WalletApi.map(res)['url'] as String;
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw StateError('Téléchargement impossible');
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/voix_${effect}_${DateTime.now().microsecondsSinceEpoch}.m4a').writeAsBytes(r.bodyBytes, flush: true);
  }
}
