import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canaux_api.dart';
import 'package:afrotok/services/api/api_identity.dart';

/// Faux « document » au format des anciens documents Firestore : les écrans qui lisaient `snapshot.docs` / `doc.data()` / `doc.id` gardent leur code.
class LegacyDoc {
  LegacyDoc(this.id, this._data);
  final String id;
  final Map<String, dynamic> _data;
  Map<String, dynamic> data() => _data;
}

/// Faux « instantané de requête » (liste de [LegacyDoc]) rempli par l'API.
class LegacySnap {
  LegacySnap(this.docs);
  final List<LegacyDoc> docs;
}

String _typeFromApi(String? t) => switch (t) {
      'ebook' => 'EBOOK',
      'audio' => 'AUDIO',
      'formation' => 'FORMATION',
      'template' => 'TEMPLATE',
      'pack_zip' => 'PACK_ZIP',
      _ => 'VIDEO',
    };

String contentTypeToApi(ContentType t) => switch (t) {
      ContentType.EBOOK => 'ebook',
      ContentType.AUDIO => 'audio',
      ContentType.FORMATION => 'formation',
      ContentType.TEMPLATE => 'template',
      ContentType.PACK_ZIP => 'pack_zip',
      ContentType.VIDEO => 'video',
      _ => 'other',
    };

int _ms(dynamic iso) => DateTime.tryParse('$iso')?.millisecondsSinceEpoch ?? 0;

/// Contenu payant de l'API -> table au format de l'ancien document `ContentPaies/{id}` (lue par `ContentPaie.fromJson`).
/// Les fichiers payants ne sont JAMAIS dans la fiche : `videoUrl`, `pdfUrl`, `fileUrl`, `tutorialVideoUrl` valent « private » quand le fichier existe
/// (l'adresse réelle, signée 10 minutes, se demande avec [ContenuPayantApi.access] après vérification de l'achat).
Map<String, dynamic> contentPaieMapFromApi(Map<String, dynamic> j, {String? myId}) {
  final kinds = (j['file_kinds'] as List? ?? const []).map((e) => '$e').toSet();
  final flash = j['flash_ends_at'] != null;
  final reaction = j['my_reaction'];
  final created = _ms(j['created_at']);
  final boosted = j['is_boosted'] == true;
  return {
    'id': j['id'],
    'ownerId': j['owner_id'],
    'title': j['title'] ?? '',
    'description': j['description'] ?? '',
    'videoUrl': kinds.contains('video') ? 'private' : null,
    'pdfUrl': kinds.contains('pdf') ? 'private' : null,
    'fileUrl': kinds.contains('file') ? 'private' : null,
    'tutorialVideoUrl': kinds.contains('tutorial') ? 'private' : null,
    'thumbnailUrl': j['thumbnail_url'] ?? '',
    'coverImages': (j['cover_images'] as List? ?? const []).map((e) => '$e').toList(),
    'categories': (j['categories'] as List? ?? const []).map((e) => '$e').toList(),
    'hashtags': (j['hashtags'] as List? ?? const []).map((e) => '$e').toList(),
    'isSeries': j['is_series'] == true,
    'seriesId': j['series_id'],
    'contentType': _typeFromApi(j['content_type'] as String?),
    'price': (j['price_xof'] as num?)?.toDouble() ?? 0.0,
    'isFree': j['is_free'] == true,
    'views': (j['views_count'] as num?)?.toInt() ?? 0,
    'likes': (j['likes_count'] as num?)?.toInt() ?? 0,
    'dislikes': (j['dislikes_count'] as num?)?.toInt() ?? 0,
    'comments': (j['comments_count'] as num?)?.toInt() ?? 0,
    'shares': (j['shares_count'] as num?)?.toInt() ?? 0,
    'sales': (j['sales_count'] as num?)?.toInt() ?? 0,
    'likedBy': [if (reaction == 'like' && myId != null) myId],
    'dislikedBy': [if (reaction == 'dislike' && myId != null) myId],
    'duration': (j['duration_sec'] as num?)?.toInt() ?? 0,
    'pageCount': (j['page_count'] as num?)?.toInt() ?? 0,
    'fileSize': (j['file_size_kb'] as num?) == null ? null : '${j['file_size_kb']}',
    'createdAt': created,
    'updatedAt': created,
    'isBoosted': boosted,
    // la date de fin du boost n'est pas donnée par l'API : un boost actif est traité comme valable encore un jour (voir lacunes_api_canaux.md)
    'boostEndDate': boosted ? DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch : null,
    'affiliationEnabled': j['affiliation_enabled'] == true,
    'affiliationRate': (j['affiliation_rate'] as num?)?.toDouble() ?? 0.0,
    'flashSaleEndDate': flash ? _ms(j['flash_ends_at']) : null,
    'flashSalePrice': flash ? (j['effective_price_xof'] as num?)?.toDouble() : null,
  };
}

ContentPaie contentPaieFromApi(Map<String, dynamic> j, {String? myId}) => ContentPaie.fromJson(contentPaieMapFromApi(j, myId: myId));

/// Accès à l'API pour le module « contenu payant » (catalogue, création, achat, accès aux fichiers, boost, réactions, commentaires, codes promo, affiliation).
/// Prix en FCFA (décision du 27/09/2026) ; jamais d'affichage de la part gardée par l'application.
class ContenuPayantApi {
  ContenuPayantApi._();

  static ApiClient get _c => ApiGateway.instance.client;
  static String? get myId => ApiIdentity.myId;

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(dynamic r) {
    final d = r is Map ? r['data'] : r;
    return (d as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) => CanauxApi.message(e, fallback: fallback);

  // ── Catalogue ──

  /// Page de contenus (mis en avant d'abord, puis les plus récents).
  static Future<({List<ContentPaie> items, String? next})> list({
    String? search,
    ContentType? type,
    String? category,
    String? ownerId,
    bool mine = false,
    bool purchased = false,
    String? cursor,
    int limit = 20,
  }) async {
    final r = await _c.get('/paid-contents', query: {
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (type != null) 'type': contentTypeToApi(type),
      if (category != null) 'category': category,
      if (ownerId != null) 'owner_id': ownerId,
      if (mine) 'mine': 1,
      if (purchased) 'purchased': 1,
      if (cursor != null) 'cursor': cursor,
    });
    return (items: _list(r).map((j) => contentPaieFromApi(j, myId: myId)).toList(), next: r is Map ? r['next_cursor'] as String? : null);
  }

  /// Même chose au format « faux instantané » pour les écrans qui lisaient Firestore.
  static Future<LegacySnap> snap({String? search, ContentType? type, String? ownerId, bool mine = false, bool purchased = false, int limit = 50}) async {
    final r = await _c.get('/paid-contents', query: {
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (type != null) 'type': contentTypeToApi(type),
      if (ownerId != null) 'owner_id': ownerId,
      if (mine) 'mine': 1,
      if (purchased) 'purchased': 1,
    });
    return LegacySnap(_list(r).map((j) => LegacyDoc('${j['id']}', contentPaieMapFromApi(j, myId: myId)..['hasAccess'] = j['has_access'] == true)).toList());
  }

  /// Fiche d'un contenu avec mon accès (`hasAccess`) ; null s'il n'existe plus.
  static Future<({ContentPaie content, bool hasAccess})?> get(String id) async {
    try {
      final j = _map(await _c.get('/paid-contents/$id'));
      return (content: contentPaieFromApi(j, myId: myId), hasAccess: j['has_access'] == true);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Création / modification : [body] suit le contrat de l'API (title, description, content_type, price_xof, is_free, flash_*, affiliation_*,
  /// categories, hashtags, thumbnail_upload_id, cover_upload_ids, files{video,pdf,file,tutorial}).
  static Future<ContentPaie> create(Map<String, dynamic> body) async => contentPaieFromApi(_map(await _c.post('/paid-contents', body: body)), myId: myId);

  static Future<ContentPaie> update(String id, Map<String, dynamic> body) async => contentPaieFromApi(_map(await _c.patch('/paid-contents/$id', body: body)), myId: myId);

  static Future<void> delete(String id) => _c.delete('/paid-contents/$id');

  /// Adresse d'un fichier payant (signée 10 minutes) après vérification de l'achat. [fileKey] : video, pdf, file, tutorial.
  static Future<String> access(String id, {String? fileKey}) async {
    final d = _map(await _c.get('/paid-contents/$id/access', query: {if (fileKey != null) 'file_key': fileKey}));
    return '${d['url']}';
  }

  // ── Achat et boost (argent : clé d'idempotence conservée jusqu'au succès) ──
  static final Map<String, String> _keys = {};

  /// Achète un contenu. [promoCode] : le CODE saisi (le serveur ignore un code invalide). [withCoins] : paiement en pièces.
  static Future<void> buy(String id, {String? promoCode, String? affiliateId, bool withCoins = false}) async {
    final k = 'buy:$id';
    final key = _keys.putIfAbsent(k, ApiClient.newIdempotencyKey);
    try {
      await _c.pay('/paid-contents/$id/purchase', body: {
        if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
        if (affiliateId != null) 'affiliate_id': affiliateId,
        if (withCoins) 'pay_with_coins': true,
      }, idempotencyKey: key);
      _keys.remove(k);
    } on ApiException catch (e) {
      if (!e.isNetwork) _keys.remove(k);
      rethrow;
    }
  }

  static Future<void> boost(String id, int days, {bool withCoins = false}) async {
    final k = 'boost:$id:$days';
    final key = _keys.putIfAbsent(k, ApiClient.newIdempotencyKey);
    try {
      await _c.pay('/paid-contents/$id/boost', body: {'days': days, if (withCoins) 'pay_with_coins': true}, idempotencyKey: key);
      _keys.remove(k);
    } on ApiException catch (e) {
      if (!e.isNetwork) _keys.remove(k);
      rethrow;
    }
  }

  // ── Réactions, vues, commentaires ──
  static Future<void> react(String id, String kind) => _c.put('/paid-contents/$id/reactions/$kind'); // like | dislike

  static Future<void> unreact(String id) => _c.delete('/paid-contents/$id/reactions');

  static final Set<String> _viewed = {};
  static Future<void> view(String id) async {
    if (!_viewed.add(id)) return;
    try {
      await _c.post('/paid-contents/$id/view');
    } catch (_) {
      _viewed.remove(id);
    }
  }

  /// Commentaires (plus récents d'abord) au format des anciens documents `ContentComments`.
  static Future<LegacySnap> comments(String id, {int limit = 50}) async {
    final rows = _list(await _c.get('/paid-contents/$id/comments', query: {'limit': limit}));
    return LegacySnap(rows.map((m) {
      final a = m['author'] is Map ? Map<String, dynamic>.from(m['author'] as Map) : <String, dynamic>{};
      return LegacyDoc('${m['id']}', {
        'contentId': id,
        'userId': a['id'],
        'pseudo': a['username'] ?? 'Utilisateur',
        'avatarUrl': a['avatar_url'] ?? '',
        'userPseudo': a['username'] ?? '',
        'userImageUrl': a['avatar_url'] ?? '',
        'text': m['text'] ?? '',
        'message': m['text'] ?? '',
        'createdAt': _ms(m['created_at']),
        // `edited_at` (null si jamais modifié) : la liste l'indique depuis le lot B2
        'editedAt': m['edited_at'] == null ? null : _ms(m['edited_at']),
      });
    }).toList());
  }

  static Future<void> addComment(String id, String text) => _c.post('/paid-contents/$id/comments', body: {'text': text});

  static Future<void> deleteComment(String commentId) => _c.delete('/paid-content-comments/$commentId');

  // ── Codes promo (créateur) ──
  static Future<List<PromoCode>> promoCodes(String contentId) async {
    final rows = _list(await _c.get('/paid-contents/$contentId/promo-codes'));
    return rows
        .map((p) => PromoCode(
              id: '${p['id']}',
              creatorId: myId ?? '',
              contentId: contentId,
              code: '${p['code']}',
              type: p['type'] == 'fixed' ? 'fixed' : 'percent',
              value: (p['value'] as num?)?.toDouble() ?? 0,
              maxUses: (p['max_uses'] as num?)?.toInt(),
              usedCount: (p['used_count'] as num?)?.toInt() ?? 0,
              expiresAt: p['expires_at'] == null ? null : _ms(p['expires_at']),
              isActive: p['is_active'] == true,
            ))
        .toList();
  }

  static Future<void> createPromo(String contentId, {required String code, required String type, required int value, int? maxUses, DateTime? expiresAt}) =>
      _c.post('/paid-contents/$contentId/promo-codes', body: {'code': code, 'type': type, 'value': value, if (maxUses != null) 'max_uses': maxUses, if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String()});

  static Future<void> setPromoActive(String promoId, bool active) => _c.patch('/promo-codes/$promoId', body: {'is_active': active});

  // ── Affiliation ──
  /// Crée (ou renvoie) mon lien d'affiliation pour un contenu qui l'autorise.
  static Future<AffiliateLink> affiliateLink(String contentId) async {
    final l = _map(await _c.post('/paid-contents/$contentId/affiliate-link'));
    return _link(l);
  }

  static Future<List<AffiliateLink>> myAffiliateLinks() async => _list(await _c.get('/me/affiliate-links')).map(_link).toList();

  static AffiliateLink _link(Map<String, dynamic> l) => AffiliateLink(
        id: '${l['id']}',
        affiliateId: myId ?? '',
        contentId: '${l['content_id']}',
        creatorId: '',
        commissionRate: (l['commission_rate'] as num?)?.toDouble() ?? 0,
        clicks: (l['clicks'] as num?)?.toInt() ?? 0,
        sales: (l['sales_count'] as num?)?.toInt() ?? 0,
        totalEarned: (l['total_earned_xof'] as num?)?.toDouble() ?? 0,
      );

  // ── Ventes (créateur) : acheteur, montant payé et MA part uniquement ──
  static Future<List<Map<String, dynamic>>> sales(String contentId) async => _list(await _c.get('/paid-contents/$contentId/sales'));
}
