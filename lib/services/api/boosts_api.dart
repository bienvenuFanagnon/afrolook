import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';

/// Boosts payants des annonces d'utilisateurs (publication, profil, canal, groupe).
///
/// Chaque paiement est UNE SEULE opération côté serveur : débit en pièces ET création de l'annonce (jamais de pièces prises sans annonce).
/// Les actions d'argent portent une clé d'idempotence conservée tant que l'action n'a pas abouti ou été refusée : un second appui ou une
/// reprise réseau réutilise la MÊME clé (jamais de double débit). Aucun retour à Firebase : les erreurs sont des [ApiException]
/// (code stable + message en français) que l'écran affiche avec « Réessayer ». Les prix viennent toujours du serveur ; la part gardée
/// par l'application n'est jamais renvoyée ni affichée.
class BoostsApi {
  BoostsApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// Message en français prêt à afficher.
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) {
    if (e is ApiException) {
      if (e.isNetwork) return 'Connexion impossible. Vérifie ta connexion puis réessaie.';
      return e.message.isNotEmpty ? e.message : fallback;
    }
    return fallback;
  }

  // ── Clés d'idempotence ──
  static final Map<String, String> _keys = {};

  static Future<T> _once<T>(String action, Future<T> Function(String key) run) async {
    final key = _keys.putIfAbsent(action, ApiClient.newIdempotencyKey);
    try {
      final r = await run(key);
      _keys.remove(action);
      return r;
    } on ApiException catch (e) {
      if (!e.isNetwork && e.status < 500) _keys.remove(action); // refus définitif : une nouvelle tentative est une nouvelle action
      rethrow;
    }
  }

  /// Oublie la clé d'une action abandonnée par la personne (bouton « Annuler »).
  static void forget(String action) => _keys.remove(action);

  /// Identifiant d'action de [create] (sert aussi à [forget]).
  static String createAction(String target, String? targetId, int weeks, bool combined, String fingerprint) => 'boost:$target:$targetId:$weeks:$combined:$fingerprint';

  /// Crée l'annonce payante d'une cible qui appartient à la personne et débite les pièces dans la même opération.
  /// [target] : `post`, `profile`, `canal`, `group` ou `new` (annonce autonome : [targetId] absent, au moins une image ou une vidéo téléversée ;
  /// aucune publication n'est créée, rien n'apparaît dans le fil). [weeks] : durée choisie (les tarifs viennent de `GET /config`, `ad_durations`).
  /// [combined] : publication + profil (+ 50 %), pour `post` seulement. [countries] vide = tous les pays.
  /// L'annonce attend la validation de l'équipe (`status` = `pending`). Erreurs : 402 `insufficient_coins`, 404 `target_unavailable`,
  /// 422 `invalid_duration` / `upload_invalid` / `media_required`.
  static Future<Map<String, dynamic>> create({
    required String target,
    String? targetId,
    required int weeks,
    bool combined = false,
    List<String> countries = const [],
    String? actionText,
    String? actionUrl,
    String? description,
    String? title,
    List<String> imageUploadIds = const [],
    String? videoUploadId,
  }) {
    final fingerprint = Object.hash(description, actionText, actionUrl, title, countries.join(','), imageUploadIds.join(','), videoUploadId).toString();
    return _once(createAction(target, targetId, weeks, combined, fingerprint), (k) async => _map(await _c.pay('/ads/boosts', body: {
          'target': target,
          if (targetId != null) 'target_id': targetId,
          'weeks': weeks,
          if (combined && target != 'new') 'combined': true,
          if (countries.isNotEmpty) 'countries': countries,
          if (actionText != null && actionText.isNotEmpty) 'action_text': actionText,
          if (actionUrl != null && actionUrl.isNotEmpty) 'action_url': actionUrl,
          if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
          if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
          if (imageUploadIds.isNotEmpty) 'image_upload_ids': imageUploadIds,
          if (videoUploadId != null) 'video_upload_id': videoUploadId,
        }, idempotencyKey: k)));
  }

  /// Détail d'une de mes annonces, avec ses statistiques (`views`, `clicks`, `renewal_count`, `paid`). Null si introuvable.
  static Future<Map<String, dynamic>?> get(String adId) async {
    try {
      return _map(await _c.get('/ads/account/ads/$adId'));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Renouvellement payant : prolonge à partir de la fin (ou de maintenant si l'annonce est échue). Erreurs : 402, 404, 422 `invalid_duration`.
  static Future<Map<String, dynamic>> renew(String adId, int weeks) =>
      _once('renew:$adId:$weeks', (k) async => _map(await _c.pay('/ads/account/ads/$adId/renew', body: {'weeks': weeks}, idempotencyKey: k)));

  /// Suppression par le propriétaire : l'annonce s'arrête et disparaît de sa liste (aucun remboursement) ; la publication liée reste.
  static Future<void> delete(String adId) async {
    await _c.delete('/ads/account/ads/$adId');
  }
}
