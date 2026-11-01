import 'package:afrolook_api_client/afrolook_api_client.dart';

import '../../models/model_data.dart';
import 'api_gateway.dart';
import 'publications_api.dart';

/// Résultat d'un « j'aime » sur un service : total et état pour la personne connectée.
class ServiceLikeResult {
  const ServiceLikeResult({required this.like, required this.liked});
  final int like;
  final bool liked;

  /// Lit `{like:int, liked:bool}` (PUT / DELETE /services/{id}/like).
  factory ServiceLikeResult.fromJson(Map<String, dynamic> j, {required bool fallbackLiked}) => ServiceLikeResult(
        like: (j['like'] as num?)?.toInt() ?? 0,
        liked: j['liked'] is bool ? j['liked'] as bool : fallbackLiked,
      );
}

/// Accès à l'API pour les services des utilisateurs (module « UserServices » de l'API, fiche 40 §1).
/// Aucun retour à Firebase : en cas d'erreur, l'écran affiche le message en français et propose « Réessayer ».
class ServicesApi {
  ServicesApi._();

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

  /// Recopie dans [target] ce que le serveur vient de renvoyer (compteurs, « j'aime », texte, couverture), sans changer l'objet affiché.
  static void merge(UserServiceData target, UserServiceData fresh) {
    target
      ..titre = fresh.titre ?? target.titre
      ..description = fresh.description ?? target.description
      ..category = fresh.category ?? target.category
      ..country = fresh.country ?? target.country
      ..city = fresh.city ?? target.city
      ..contact = fresh.contact ?? target.contact
      ..disponible = fresh.disponible
      ..imageCourverture = fresh.imageCourverture ?? target.imageCourverture
      ..vues = fresh.vues
      ..like = fresh.like
      ..contactWhatsapp = fresh.contactWhatsapp
      ..partage = fresh.partage
      ..usersLikeId = fresh.usersLikeId
      ..user = fresh.user ?? target.user;
  }

  /// Corps envoyé pour créer ou modifier un service (les compteurs, dates et `userId` du modèle sont ignorés par le serveur,
  /// on n'envoie donc que les champs utiles). [coverUploadId] : envoi d'image confirmé (`ArgentUpload.bytes`).
  static Map<String, dynamic> body(UserServiceData s, {String? coverUploadId}) => {
        'title': (s.titre ?? '').trim(),
        if (s.description != null) 'description': s.description,
        if (s.category != null) 'category': s.category,
        if (s.country != null) 'country': s.country,
        if (s.city != null) 'city': s.city,
        if (s.contact != null) 'contact': s.contact!.trim(),
        if (s.disponible != null) 'is_available': s.disponible,
        if (coverUploadId != null) 'cover_upload_id': coverUploadId,
      };

  /// Crée (POST /services, avec clé d'idempotence : un rejeu ne crée jamais de doublon) ou modifie (PUT /services/{id}).
  /// Renvoie le service tel que le serveur le garde (avec `image_url` définitive).
  static Future<UserServiceData> save(UserServiceData s, {String? coverUploadId, String? idempotencyKey}) async {
    final b = body(s, coverUploadId: coverUploadId);
    final r = s.id == null
        ? await _c.post('/services', body: b, idempotencyKey: idempotencyKey ?? ApiClient.newIdempotencyKey())
        : await _c.put('/services/${s.id}', body: b);
    return PubApi.serviceFromApi(_map(r));
  }

  /// Suppression (douce) : propriétaire ou équipe. DELETE /services/{id}
  static Future<void> delete(String id) => _c.delete('/services/$id');

  /// PUT /services/{id}/like → {like, liked: true} (rejouable).
  static Future<ServiceLikeResult> like(String id) async =>
      ServiceLikeResult.fromJson(_map(await _c.put('/services/$id/like')), fallbackLiked: true);

  /// DELETE /services/{id}/like → {like, liked: false}.
  static Future<ServiceLikeResult> unlike(String id) async =>
      ServiceLikeResult.fromJson(_map(await _c.delete('/services/$id/like')), fallbackLiked: false);

  /// POST /services/{id}/view → {views, counted} (une vue par personne, jamais le créateur). Renvoie le total.
  static Future<int?> view(String id) async => (_map(await _c.post('/services/$id/view'))['views'] as num?)?.toInt();

  /// POST /services/{id}/share → {shares}.
  static Future<int?> share(String id) async => (_map(await _c.post('/services/$id/share'))['shares'] as num?)?.toInt();

  /// POST /services/{id}/contact → {contacts}. Le créateur est prévenu une seule fois par personne (notification `SERVICE`).
  static Future<int?> contact(String id) async => (_map(await _c.post('/services/$id/contact'))['contacts'] as num?)?.toInt();
}
