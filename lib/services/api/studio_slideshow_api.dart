import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:uuid/uuid.dart';

import 'api_gateway.dart';
import 'wallet_api.dart';

/// Diaporama du Studio (2 à 5 images → une vidéo) : `POST /studio/slideshow` en mode ASYNCHRONE. Le serveur répond tout de suite (202) et fait le travail lourd
/// ensuite ; on vérifie l'avancement avec `GET /studio/slideshow/{job}` jusqu'à « done » (l'adresse de la vidéo) ou « failed » (le message précis du serveur).
/// Constaté le 11/11/2026 : en une seule requête, un film de 5 photos avec générique dépassait le délai de nginx (« upstream timed out ») et l'application
/// affichait « le serveur a rencontré une erreur ». Un serveur qui répond encore directement (ancienne version de l'API) reste accepté.
class StudioSlideshowApi {
  StudioSlideshowApi._();

  /// Lance le diaporama et attend sa fin. Retourne les données de la vidéo (`url`, `duration_ms`…). [body] : les champs habituels (`uploads`, `durations`…).
  static Future<Map<String, dynamic>> render(
    Map<String, dynamic> body, {
    required String idempotencyKey,
    Duration wait = const Duration(minutes: 10),
    Duration every = const Duration(seconds: 2),
  }) async {
    final jobId = const Uuid().v4();
    final started = WalletApi.map(await ApiGateway.instance.client.post(
      '/studio/slideshow',
      body: {...body, 'async': true, 'job_id': jobId},
      idempotencyKey: idempotencyKey,
      longJob: true,
    ));
    if (started['url'] is String) return started;   // ancien serveur : le diaporama est déjà prêt
    final id = '${started['job_id'] ?? jobId}';
    return wait_(id, wait: wait, every: every);
  }

  /// Attend la fin d'un diaporama déjà lancé (séparé pour être testé sans réseau).
  static Future<Map<String, dynamic>> wait_(String jobId, {required Duration wait, required Duration every}) async {
    final deadline = DateTime.now().add(wait);
    var misses = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(every);
      Map<String, dynamic> st;
      try {
        st = WalletApi.map(await ApiGateway.instance.client.get('/studio/slideshow/$jobId'));
        misses = 0;
      } on ApiException catch (e) {
        if (e.status == 404) throw ApiException(status: 404, code: 'slideshow_failed', message: 'Le diaporama a été perdu côté serveur. Réessaie.');
        if (++misses >= 5) rethrow;   // réseau instable : quelques ratés sont tolérés
        continue;
      }
      final out = outcome(st);
      if (out != null) return out;
    }
    throw ApiException(status: 504, code: 'slideshow_timeout', message: 'Le diaporama prend trop de temps. Réessaie avec moins ou de plus petites images.');
  }

  /// Lecture d'un état de suivi : les données de la vidéo si « done », une exception avec le message du serveur si « failed », sinon null (on continue d'attendre).
  static Map<String, dynamic>? outcome(Map<String, dynamic> st) {
    switch (st['status']) {
      case 'done':
        final data = st['data'];
        if (data is Map && data['url'] is String && (data['url'] as String).isNotEmpty) return Map<String, dynamic>.from(data);
        throw ApiException(status: 500, code: 'slideshow_failed', message: 'Le diaporama est terminé mais la vidéo est introuvable. Réessaie.');
      case 'failed':
        throw ApiException(status: (st['http'] as num?)?.toInt() ?? 500, code: '${st['code'] ?? 'slideshow_failed'}', message: '${st['message'] ?? 'Le diaporama a échoué.'}');
      default:
        return null;
    }
  }
}
