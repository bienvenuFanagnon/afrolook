import 'dart:io';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canaux_mapper.dart';
import 'package:afrotok/services/api/paid_file_types.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:dio/dio.dart';

/// Accès à l'API pour le module « canaux » (liste, détail, création, modification, abonnements, membres, publications, déblocage).
/// Aucun retour à Firebase : en cas d'erreur, l'écran affiche le message et propose « Réessayer ».
class CanauxApi {
  CanauxApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(dynamic r) {
    final d = r is Map ? r['data'] : r;
    return (d as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Message en français prêt à afficher (l'API renvoie déjà un texte français).
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) {
    if (e is ApiException) {
      if (e.isNetwork) return 'Connexion impossible. Vérifie ta connexion puis réessaie.';
      return e.message.isNotEmpty ? e.message : fallback;
    }
    return fallback;
  }

  // ── Canaux ──

  /// Catégories principales acceptées par l'API.
  static const apiCategories = {'SPORT', 'ACTUALITES', 'LOOKS', 'GAMER', 'EVENEMENT', 'OFFRES', 'MUSIQUE', 'EDUCATION', 'HUMOUR', 'BUSINESS'};

  /// Catégorie de l'application -> catégorie de l'API (null si l'API ne la connaît pas : « VIBE » et « GENERAL », voir lacunes_api_canaux.md).
  static String? apiCategory(String? c) => c != null && apiCategories.contains(c) ? c : null;

  /// Page de canaux. [mine] : seulement ceux dont je suis membre (propriétaire, administrateur ou abonné).
  /// [admin] : seulement ceux que j'administre (les miens et ceux où je suis nommé administrateur, abonnement non échu).
  /// Chaque canal porte `me {is_owner, is_admin, is_member, can_post, expires_at}` : plus besoin de relire la fiche de chacun.
  static Future<({List<Canal> items, String? next})> list({String? search, String? category, bool mine = false, bool admin = false, String? cursor, int limit = 20, String? myId}) async {
    final r = await _c.get('/channels', query: {
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (category != null && category.isNotEmpty) 'category': category,
      if (mine) 'mine': 1,
      if (admin) 'admin': 1,
      if (cursor != null) 'cursor': cursor,
    });
    final rows = _list(r);
    return (items: rows.map((j) => canalFromApiFull(j, myId)).toList(), next: r is Map ? r['next_cursor'] as String? : null);
  }

  /// Fiche complète d'un canal avec ma situation (membre, administrateur, droit de publier, échéance).
  static Future<Canal> get(String id, {String? myId}) async => canalFromApiFull(_map(await _c.get('/channels/$id')), myId);

  /// Création : renvoie le canal créé. Si un ticket est nécessaire, lève une [ApiException] `creation_credit_required` (402, 500 pièces).
  static Future<Canal> create({
    required String title,
    String? description,
    bool isPrivate = false,
    String subscriptionType = 'free',
    int priceCoins = 0,
    String? mainCategory,
    List<String>? categories,
    bool allowAllMembersToPost = false,
    String? imageUploadId,
    String? coverUploadId,
    String? myId,
  }) async {
    final r = await _c.post('/channels', body: {
      'title': title,
      if (description != null) 'description': description,
      'is_private': isPrivate,
      'subscription_type': apiSubscriptionType(subscriptionType, isPrivate),
      'price_coins': isPrivate ? priceCoins : 0,
      if (mainCategory != null) 'main_category': mainCategory,
      if (categories != null) 'categories': categories,
      'allow_all_members_to_post': allowAllMembersToPost,
      if (imageUploadId != null) 'image_upload_id': imageUploadId,
      if (coverUploadId != null) 'cover_upload_id': coverUploadId,
    });
    return canalFromApiFull(_map(r), myId);
  }

  /// Modification (seuls les champs envoyés changent). Titre, prix et confidentialité : propriétaire seulement.
  static Future<Canal> update(String id, Map<String, dynamic> fields, {String? myId}) async => canalFromApiFull(_map(await _c.patch('/channels/$id', body: fields)), myId);

  static Future<void> delete(String id) => _c.delete('/channels/$id');

  /// S'abonner à un canal PUBLIC (gratuit). Un canal payant s'achète avec [buySubscription].
  static Future<void> join(String id) => _c.post('/channels/$id/membership');

  static Future<void> leave(String id) => _c.delete('/channels/$id/membership');

  /// Membres (administrateurs du canal seulement).
  static Future<({List<Map<String, dynamic>> items, String? next})> members(String id, {String? cursor, int limit = 50}) async {
    final r = await _c.get('/channels/$id/members', query: {'limit': limit, if (cursor != null) 'cursor': cursor});
    return (items: _list(r), next: r is Map ? r['next_cursor'] as String? : null);
  }

  static Future<void> updateMember(String id, String userId, {bool? isAdmin, bool? canPost}) =>
      _c.patch('/channels/$id/members/$userId', body: {if (isAdmin != null) 'is_admin': isAdmin, if (canPost != null) 'can_post': canPost});

  /// Publications du canal, par curseur. [meta] est renseigné pour un canal privé que je ne peux pas encore voir en entier
  /// (`members_only`, `subscription_type`, `price_coins`, `locked_count`). [freeIds] : publications gratuites (aperçu) du canal.
  static Future<({List<Post> posts, String? next, Map<String, dynamic>? meta, Set<String> freeIds})> posts(String id, {String? cursor, int limit = 10}) async {
    final r = await _c.get('/channels/$id/posts', query: {'limit': limit, if (cursor != null) 'cursor': cursor});
    final rows = _list(r);
    final meta = r is Map && r['meta'] is Map ? Map<String, dynamic>.from(r['meta'] as Map) : null;
    return (
      posts: rows.map(postFromApi).where((p) => p.id != null).toList(),
      next: r is Map ? r['next_cursor'] as String? : null,
      meta: meta,
      freeIds: rows.where((j) => j['is_free_preview'] == true).map((j) => '${j['id']}').toSet(),
    );
  }

  /// Rend une publication gratuite (visible de tous) ou réservée aux abonnés.
  static Future<void> setFreePreview(String channelId, String postId, bool free) => _c.put('/channels/$channelId/posts/$postId/free-preview', body: {'free': free});

  /// Prix du déblocage d'un canal bloqué (propriétaire) : { is_blocked, coins, followers }.
  static Future<Map<String, dynamic>> unlockQuote(String id) async => _map(await _c.get('/channels/$id/unlock-quote'));

  // ── Achats (point d'achat unique) ──

  /// Prix d'un achat calculé par le serveur.
  static Future<int> quote(String kind, {String? refId}) async => (_map(await _c.get('/purchases/quote', query: {'kind': kind, if (refId != null) 'ref_id': refId}))['coins'] as num?)?.toInt() ?? 0;

  static final Map<String, String> _keys = {};

  /// Achat en pièces avec clé d'idempotence conservée tant que l'achat n'a pas abouti (un second appui ne débite jamais deux fois).
  /// `kind` : `canal` (abonnement), `canal_unlock` (déblocage), `canal_create` (ticket de création).
  static Future<Map<String, dynamic>> buy(String kind, {String? refId}) async {
    final k = '$kind:${refId ?? ''}';
    final key = _keys.putIfAbsent(k, ApiClient.newIdempotencyKey);
    final r = await _c.pay('/purchases', body: {'kind': kind, if (refId != null) 'ref_id': refId}, idempotencyKey: key);
    _keys.remove(k);
    return _map(r);
  }

  /// Oublie la clé mémorisée (la personne a annulé : le prochain essai sera un nouvel achat).
  static void forgetKey(String kind, {String? refId}) => _keys.remove('$kind:${refId ?? ''}');

  // ── Envois de fichiers (URL signée, dépôt direct, confirmation) ──

  static const _types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'mp4': 'video/mp4',
    'mov': 'video/mp4',
    'm4a': 'audio/mp4',
    'aac': 'audio/mp4',
    'mp3': 'audio/mpeg',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
  };

  /// Envoie un fichier vers le stockage et renvoie son identifiant d'envoi (`upload_id`) à passer aux créations.
  /// [private] : fichier payant (clé privée, jamais d'adresse publique). [onProgress] : 0 à 1.
  static Future<String> upload(File file, {bool private = false, String? contentType, void Function(double)? onProgress}) async {
    final ext = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : '';
    // Fichier payant (privé) : types élargis du lot B2 (audio wav/aac/ogg/flac, mov, webm, epub, documents Office, 7z, rar, psd) ; public : types de base.
    final type = contentType ?? (private ? PaidFileTypes.mimeFor(ext) : null) ?? _types[ext] ?? 'application/octet-stream';
    final size = await file.length();
    final created = _map(await _c.post('/uploads', body: {'content_type': type, 'size': size, if (private) 'private': true}));
    final headers = Map<String, dynamic>.from((created['headers'] as Map?) ?? {'Content-Type': type});
    headers['Content-Length'] = size;
    final res = await Dio().put<dynamic>(
      created['url'] as String,
      data: file.openRead(),
      options: Options(headers: headers, validateStatus: (_) => true, sendTimeout: const Duration(minutes: 10), receiveTimeout: const Duration(minutes: 2)),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
    if ((res.statusCode ?? 0) < 200 || (res.statusCode ?? 0) >= 300) {
      throw ApiException(status: res.statusCode ?? 0, code: 'upload_failed', message: 'L\'envoi du fichier a échoué. Réessaie.');
    }
    await _c.post('/uploads/${created['upload_id']}/complete');
    return created['upload_id'] as String;
  }
}
