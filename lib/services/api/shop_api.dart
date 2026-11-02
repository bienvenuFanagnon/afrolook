import 'dart:io';
import 'dart:typed_data';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/argent_upload.dart';
import 'package:afrotok/services/api/wallet_api.dart';

/// Un commentaire d'article tel que l'écran le montre.
class ShopComment {
  ShopComment({required this.id, required this.userId, required this.pseudo, required this.avatar, required this.text, required this.likes, required this.createdAt});
  final String id;
  final String userId;
  final String pseudo;
  final String avatar;
  final String text;
  final int likes;
  final DateTime createdAt;
}

/// Accès à l'API : boutique Afroshop (catégories, entreprises, articles, j'aime, commentaires, boosts).
/// Aucun retour à Firebase : les erreurs sont transmises ([ApiException], message en français).
class ShopApi {
  ShopApi._();

  static ApiClient get _c => ApiGateway.instance.client;
  static Map<String, dynamic> _map(dynamic r) => WalletApi.map(r);
  static List<Map<String, dynamic>> _list(dynamic r) => WalletApi.list(r);
  static String message(Object e, {String fallback = 'Action impossible. Vérifie ta connexion.'}) => WalletApi.message(e, fallback: fallback);

  // ── Conversion API → modèles d'affichage ──

  static int _ms(dynamic iso) => DateTime.tryParse('$iso')?.millisecondsSinceEpoch ?? 0;

  static ArticleData article(Map<String, dynamic> m) {
    final a = ArticleData();
    a.id = '${m['id']}';
    a.user_id = m['owner_id'] as String?;
    a.categorie_id = m['category_id'] as String?;
    a.titre = m['title'] as String?;
    a.description = m['description'] as String?;
    a.phone = m['phone'] as String?;
    a.prix = (m['price'] as num?)?.toInt();
    a.prixOriginal = (m['original_price'] as num?)?.toInt();
    a.reduction = (m['discount_percent'] as num?)?.toInt();
    a.negociable = m['negotiable'] == true;
    a.images = [for (final i in (m['images'] as List? ?? const [])) '$i'];
    a.thumbnailUrl = m['thumbnail_url'] as String?;
    a.videoUrl = m['video_url'] as String?;
    a.videoDurationSec = (m['video_duration_sec'] as num?)?.toInt();
    a.condition = m['condition'] as String?;
    a.etat = m['state'] as String?;
    a.sousCategorie = m['sub_category'] as String?;
    a.tags = [for (final t in (m['tags'] as List? ?? const [])) '$t'];
    a.ville = m['city'] as String?;
    a.quartier = m['district'] as String?;
    a.latitude = (m['latitude'] as num?)?.toDouble();
    a.longitude = (m['longitude'] as num?)?.toDouble();
    a.disponible = m['is_available'] != false;
    a.status = switch (m['status']) { 'approved' => 'approuve', 'rejected' => 'rejete', _ => 'en_attente' };
    a.isBoosted = m['is_boosted'] == true;
    a.booster = a.isBoosted == true ? 1 : 0;
    a.boostEndDate = m['boost_until'] == null ? null : _ms(m['boost_until']);
    a.vues = (m['views_count'] as num?)?.toInt() ?? 0;
    a.contact = (m['contacts_count'] as num?)?.toInt() ?? 0;
    a.jaime = (m['likes_count'] as num?)?.toInt() ?? 0;
    a.partage = (m['shares_count'] as num?)?.toInt() ?? 0;
    a.commentaires = (m['comments_count'] as num?)?.toInt() ?? 0;
    a.modReason = m['mod_reason'] as String?;
    a.createdAt = _ms(m['created_at']);
    a.updatedAt = a.createdAt;
    return a;
  }

  /// L'article a-t-il été aimé par moi ? (champ `me.liked` de l'API)
  static bool likedByMe(Map<String, dynamic> m) => (m['me'] is Map) && (m['me'] as Map)['liked'] == true;

  static EntrepriseData business(Map<String, dynamic> m) {
    final e = EntrepriseData();
    e.id = '${m['id']}';
    e.userId = m['owner_id'] as String?;
    e.titre = m['name'] as String?;
    e.type = m['type'] as String?;
    e.description = m['description'] as String?;
    e.urlImage = m['image_url'] as String?;
    e.suivi = (m['followers_count'] as num?)?.toInt() ?? 0;
    e.publication = (m['articles_count'] as num?)?.toInt() ?? 0;
    e.haveSubscription = m['is_premium'] == true;
    // Limites calculées par le serveur (seulement pour le propriétaire) : articles restants et images par article.
    // L'écran de publication lit `abonnement` ; le serveur applique déjà l'expiration, donc aucune date de fin côté application.
    final lim = m['limits'];
    if (lim is Map) {
      final total = (lim['articles'] as num?)?.toInt();   // null = illimité (équipe)
      final used = (m['articles_count'] as num?)?.toInt() ?? 0;
      e.abonnement = EntrepriseAbonnement()
        ..type = e.haveSubscription == true ? TypeAbonement.PREMIUM.name : TypeAbonement.GRATUIT.name
        ..nombre_pub = total == null ? 999 : (total - used).clamp(0, 1 << 30)
        ..nombre_image_pub = (lim['images'] as num?)?.toInt() ?? 1
        ..end = DateTime.now().add(const Duration(days: 3650)).millisecondsSinceEpoch
        ..isFinished = false;
    }
    return e;
  }

  static Categorie category(Map<String, dynamic> m) {
    final c = Categorie();
    c.id = '${m['id']}';
    c.nom = m['name'] as String?;
    c.logo = m['logo_url'] as String?;
    return c;
  }

  // ── Catégories, entreprises ──
  static Future<List<Categorie>> categories() async => _list(await _c.get('/shop/categories')).map(category).toList();

  static Future<List<EntrepriseData>> businesses({bool mine = false, String? search, int page = 1}) async =>
      _list(await _c.get('/shop/businesses', query: {if (mine) 'mine': 1, if (search != null && search.isNotEmpty) 'search': search, 'page': page})).map(business).toList();

  static Future<EntrepriseData?> businessById(String id) async {
    try {
      return business(_map(await _c.get('/shop/businesses/$id')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  static Future<EntrepriseData> createBusiness({required String name, required String type, String? description, File? image}) async {
    final imageId = image == null ? null : await ArgentUpload.bytes(Uint8List.fromList(await image.readAsBytes()), contentType: ArgentUpload.imageType(image.path));
    return business(_map(await _c.post('/shop/businesses', body: {'name': name, 'type': type, if (description != null) 'description': description, if (imageId != null) 'image_upload_id': imageId})));
  }

  static Future<void> follow(String businessId, bool on) async => on ? await _c.put('/shop/businesses/$businessId/follow') : await _c.delete('/shop/businesses/$businessId/follow');

  // ── Articles ──
  /// Articles disponibles. [owner]/[businessId]/[categoryId]/[search] filtrent ; [mine] = mes articles (tous statuts).
  static Future<({List<ArticleData> items, bool more})> articles({
    String? categoryId,
    String? businessId,
    String? ownerId,
    String? search,
    bool mine = false,
    int page = 1,
    int limit = 30,
  }) async {
    final r = await _c.get('/shop/articles', query: {
      if (categoryId != null && categoryId.isNotEmpty) 'category_id': categoryId,
      if (businessId != null) 'business_id': businessId,
      if (ownerId != null) 'owner_id': ownerId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (mine) 'mine': 1,
      'page': page,
      'limit': limit,
    });
    return (items: _list(r).map(article).toList(), more: r is Map && r['has_more'] == true);
  }

  static Future<ArticleData?> articleById(String id) async {
    try {
      return article(_map(await _c.get('/shop/articles/$id')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Article + « aimé par moi » en un appel.
  static Future<({ArticleData article, bool liked})?> articleWithMe(String id) async {
    try {
      final m = _map(await _c.get('/shop/articles/$id'));
      return (article: article(m), liked: likedByMe(m));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Crée un article : les images et la vidéo sont envoyées d'abord (envoi direct), puis l'article est créé.
  static Future<ArticleData> createArticle({
    required String businessId,
    required String title,
    required int price,
    String? description,
    String? categoryId,
    String? phone,
    List<File> images = const [],
    File? video,
    int? videoDurationSec,
    Map<String, dynamic> extra = const {},
    void Function(double)? onProgress,
  }) async {
    final ids = <String>[];
    for (var i = 0; i < images.length; i++) {
      ids.add(await ArgentUpload.bytes(Uint8List.fromList(await images[i].readAsBytes()), contentType: ArgentUpload.imageType(images[i].path)));
      onProgress?.call((i + 1) / (images.length + (video == null ? 0 : 1)));
    }
    String? videoId;
    if (video != null) {
      videoId = await ArgentUpload.bytes(Uint8List.fromList(await video.readAsBytes()), contentType: 'video/mp4');
      onProgress?.call(1);
    }
    final r = await _c.post('/shop/articles', body: {
      'business_id': businessId,
      'title': title,
      'price': price,
      if (description != null) 'description': description,
      if (categoryId != null) 'category_id': categoryId,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'image_upload_ids': ids,
      if (videoId != null) 'video_upload_id': videoId,
      if (videoDurationSec != null) 'video_duration_sec': videoDurationSec,
      ...extra,
    });
    return article(_map(r));
  }

  static Future<ArticleData> updateArticle(String id, Map<String, dynamic> fields) async => article(_map(await _c.patch('/shop/articles/$id', body: fields)));

  static Future<void> deleteArticle(String id) => _c.delete('/shop/articles/$id');

  static Future<void> like(String id, bool on) async => on ? await _c.put('/shop/articles/$id/like') : await _c.delete('/shop/articles/$id/like');

  /// [kind] : view | contact | share (compté une fois par personne et par article).
  static Future<void> event(String id, String kind) => _c.post('/shop/articles/$id/events', body: {'kind': kind});

  /// Boost gratuit (abonnés Premium) ; sinon [boostPaid].
  static Future<ArticleData> boostFree(String id, {int? days}) async => article(_map(await _c.post('/shop/articles/$id/boost', body: {if (days != null) 'days': days})));

  /// Boost payant en pièces (10, 20, 30 ou 40 jours).
  static Future<Map<String, dynamic>> boostPaid(String id, int days) => WalletApi.instance.buy('product_boost', refId: id, days: days);

  // ── Commentaires ──
  static Future<List<ShopComment>> comments(String articleId, {int limit = 50}) async => [
        for (final m in _list(await _c.get('/shop/articles/$articleId/comments', query: {'limit': limit})))
          ShopComment(
            id: '${m['id']}',
            userId: '${(m['user'] as Map?)?['id'] ?? ''}',
            pseudo: '${(m['user'] as Map?)?['username'] ?? ''}',
            avatar: '${(m['user'] as Map?)?['avatar_url'] ?? ''}',
            text: '${m['text'] ?? ''}',
            likes: (m['likes_count'] as num?)?.toInt() ?? 0,
            createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
          ),
      ];

  static Future<String> addComment(String articleId, String text) async => '${_map(await _c.post('/shop/articles/$articleId/comments', body: {'text': text}))['id']}';

  static Future<void> deleteComment(String articleId, String commentId) => _c.delete('/shop/articles/$articleId/comments/$commentId');

  // ── Équipe ──
  static Future<void> moderate(String id, String status, {String? reason}) => _c.patch('/admin/shop/articles/$id/moderation', body: {'status': status, if (reason != null) 'reason': reason});
}
