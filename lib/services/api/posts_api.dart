import 'dart:io';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/services/api/posts_mapper.dart';
import 'package:afrotok/services/post_source_link.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Accès à l'API pour les publications (création, lecture, réactions, favoris, signalement) : aucun retour à Firebase en cas d'erreur.
/// Les erreurs sont des [ApiException] (code stable + message en français) : l'écran les affiche et propose « Réessayer ».
class PostsApi {
  PostsApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _asMap(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  // ── Lecture ──
  /// Une publication (null si introuvable ou supprimée).
  static Future<Post?> get(String id) async {
    try {
      return postFromApi(_asMap(await _c.get('/posts/$id')));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Réponses en vidéo faites à un post (les plus récentes d'abord, première page).
  static Future<List<Post>> replies(String postId) async {
    final d = ApiClient.data(await _c.get('/posts/$postId/replies'));
    return d is List ? [for (final m in d.whereType<Map>()) postFromApi(Map<String, dynamic>.from(m))] : <Post>[];
  }

  /// Plusieurs publications (les introuvables sont ignorées), en parallèle.
  static Future<List<Post>> getMany(Iterable<String> ids) async {
    final out = await Future.wait(ids.map((id) async {
      try {
        return await get(id);
      } catch (e) {
        if (kDebugMode) debugPrint('❌ API PUBLICATION $id : $e');
        return null;
      }
    }));
    return out.whereType<Post>().toList();
  }

  // ── Écriture ──
  /// Crée une publication. [uploadIds] : fichiers déjà téléversés et confirmés ([UploadsApi.upload]).
  static Future<Post> create({
    String? description,
    String? linkUrl,
    String? category,
    bool? isMonetized,
    List<String> uploadIds = const [],
    List<String> countries = const [],
    List<String> interests = const [],
    String? channelId,
    bool? freePreview,
    DateTime? eventDate,
    String? thumbnailUploadId,
    String? studioTemplate,
    int? videoWidth,
    int? videoHeight,
    String? captureSource,
  }) async {
    // Origine du média (filmé ou enregistré dans l'application / choisi dans la galerie) : posée par le parcours « Créer un post », consommée ici une seule fois
    final source = captureSource ?? PostSourceLink.take();
    // Effet de voix (audio) et publication à laquelle on répond en vidéo : posés par le parcours, consommés ici une seule fois
    final voiceEffect = PostVoiceLink.take();
    final replyToId = PostReplyLink.take();
    final studioPins = PostPinLink.take();
    final external = PostExternalLink.take();   // vidéo portant la marque d'un autre réseau : « C'est ma vidéo », vérifiée par la modération avant publication
    final body = <String, dynamic>{
      if (external != null && uploadIds.isNotEmpty) ...{'external_mark': external.$1, 'own_claim': external.$2},
      if (source != null && uploadIds.isNotEmpty) 'capture_source': source,
      if (voiceEffect != null && uploadIds.isNotEmpty) 'voice_effect': voiceEffect,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (studioPins != null && uploadIds.isNotEmpty) 'studio_pins': studioPins,
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      if (linkUrl != null && linkUrl.trim().isNotEmpty) 'link_url': linkUrl.trim(),
      if (category != null && category.isNotEmpty) 'category': category,
      if (isMonetized != null) 'is_monetized': isMonetized,
      if (uploadIds.isNotEmpty) 'upload_ids': uploadIds,
      if (countries.isNotEmpty) 'countries': countries,
      if (interests.isNotEmpty) 'interests': interests,
      if (channelId != null && channelId.isNotEmpty) 'channel_id': channelId,
      if (freePreview != null) 'free_preview': freePreview,
      if (eventDate != null) 'event_date': eventDate.toUtc().toIso8601String(),
      if (thumbnailUploadId != null && thumbnailUploadId.isNotEmpty) 'thumbnail_upload_id': thumbnailUploadId,
      if (studioTemplate != null && studioTemplate.isNotEmpty) 'studio_template': studioTemplate.length > 120 ? studioTemplate.substring(0, 120) : studioTemplate,
      if (videoWidth != null && videoHeight != null && videoWidth > 0 && videoHeight > 0) ...{'video_width': videoWidth, 'video_height': videoHeight},
    };
    // Clé d'idempotence : un nouvel essai réseau ne crée pas deux publications.
    final r = await _c.post('/posts', body: body, idempotencyKey: ApiClient.newIdempotencyKey());
    if (_asMap(r)['pending_review'] == true) PostExternalLink.markPending();   // en vérification par la modération
    return postFromApi(_asMap(r));
  }

  /// Résultat d'un contrôle d'authenticité fait sur ce téléphone pendant une lecture : « clean » ou « mark » (+ marque). Rend l'état public de la vidéo (validated, flagged, null).
  static Future<String?> reportAuthenticity(String postId, {required bool clean, String? mark}) async {
    try {
      final r = await _c.post('/posts/$postId/authenticity', body: {'result': clean ? 'clean' : 'mark', if (!clean && mark != null) 'mark': mark});
      final d = ApiClient.data(r);
      return d is Map ? d['authenticity'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  /// « C'est ma vidéo » sur une vidéo marquée : l'équipe la vérifie. Vrai si la demande est partie.
  static Future<bool> claimOwnership(String postId) async {
    try {
      await _c.post('/posts/$postId/ownership-claim');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Onglet « Suivis » de la page des vidéos verticales : vidéos des comptes et canaux suivis, du plus récent au plus ancien.
  static Future<({List<Map<String, dynamic>> items, String? next})> followingVideos({String? cursor, int limit = 10}) async {
    final r = await _c.get('/feed/videos/following', query: {'limit': limit, if (cursor != null) 'cursor': cursor});
    final m = Map<String, dynamic>.from(r as Map);
    final items = ((m['data'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return (items: items, next: m['next_cursor'] as String?);
  }

  /// Imports restants aujourd'hui (médias choisis dans la galerie : 2 par jour, publications de canal comprises). Les comptes Gold ne sont pas limités (`unlimited`) ;
  /// pour un canal, c'est le plan de son créateur qui compte (`channelId`). En cas d'erreur réseau, null : l'écran n'empêche rien, le serveur décide.
  static Future<({int limit, int used, int remaining, bool unlimited})?> importQuota({String? channelId}) async {
    try {
      final d = ApiClient.data(await _c.get('/posts/quota', query: {if (channelId != null && channelId.isNotEmpty) 'channel_id': channelId}));
      if (d is! Map) return null;
      return (limit: (d['limit'] as num).toInt(), used: (d['used'] as num).toInt(), remaining: (d['remaining'] as num).toInt(), unlimited: d['unlimited'] == true);
    } catch (_) {
      return null;
    }
  }

  static Future<Post> update(String id, {String? description, String? linkUrl, String? category}) async {
    final r = await _c.patch('/posts/$id', body: {
      if (description != null) 'description': description,
      if (linkUrl != null) 'link_url': linkUrl,
      if (category != null) 'category': category,
    });
    return postFromApi(_asMap(r));
  }

  /// L'auteur supprime sa publication ; un membre de l'équipe avec le droit de modération peut supprimer celle d'un autre (motif facultatif, gardé au journal de modération).
  static Future<void> delete(String id, {String? reason}) async {
    final r = reason?.trim() ?? '';
    await _c.delete('/posts/$id', body: r.isEmpty ? null : {'reason': r});
  }

  // ── Réactions ──
  /// J'aime. Erreur 402 `insufficient_coins` possible (pièces insuffisantes) : [ApiException.isInsufficientCoins].
  /// Renvoie false si la personne avait déjà aimé.
  static Future<bool> like(String id) async => _asMap(await _c.put('/posts/$id/reaction'))['already'] != true;

  static Future<void> unlike(String id) async {
    await _c.delete('/posts/$id/reaction');
  }

  static Future<void> favorite(String id) async {
    await _c.put('/posts/$id/favorite');
  }

  static Future<void> unfavorite(String id) async {
    await _c.delete('/posts/$id/favorite');
  }

  /// [type] : `standard` ou `wrong_category`.
  static Future<void> report(String id, {String type = 'standard'}) async {
    await _c.post('/posts/$id/report', body: {'type': type});
  }

  /// Compte un partage (`POST /posts/{id}/share`) : une seule fois par personne et par publication.
  /// Renvoie le nombre de partages tenu par le serveur et si ce partage vient d'être compté.
  static Future<({int count, bool counted})> share(String id) async {
    final d = _asMap(await _c.post('/posts/$id/share'));
    return (count: (d['count'] as num?)?.toInt() ?? 0, counted: d['already'] != true);
  }

  /// Signal de goût pour le fil : share, click, watch, skip, hide. Jamais bloquant (erreur ignorée).
  static Future<void> signal(String id, String type) async {
    try {
      await _c.post('/posts/$id/signal', body: {'type': type});
    } catch (e) {
      if (kDebugMode) debugPrint('API signal $type $id : $e');
    }
  }

  /// Cadeau à une publication. [body] : voir `GiftController@toPost` (clé d'idempotence conservée par l'écran).
  static Future<Map<String, dynamic>> gift(String id, Map<String, dynamic> body, {String? idempotencyKey}) async =>
      _asMap(await _c.pay('/posts/$id/gifts', body: body, idempotencyKey: idempotencyKey));
}

/// Commentaires : 10 gratuits par publication, puis 1 pièce (erreur 402 `insufficient_coins` → proposer de recharger).
class CommentsApi {
  CommentsApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  /// Une page de commentaires racine (du plus récent au plus ancien) ; les premières réponses de chacun sont chargées avec.
  static Future<ApiCommentPage> list(String postId, {String? cursor, int limit = 10, bool withReplies = true}) async {
    final r = await _c.get('/posts/$postId/comments', query: {'limit': limit, if (cursor != null) 'cursor': cursor});
    final rows = ((r as Map)['data'] as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final comments = rows.map(commentFromApi).toList();
    if (withReplies) {
      await Future.wait(comments.where((c) => (c.comments ?? 0) > 0).map((c) async {
        try {
          c.responseComments = await replies(c.id!);
        } catch (e) {
          if (kDebugMode) debugPrint('❌ API RÉPONSES ${c.id} : $e');
        }
      }));
    }
    return ApiCommentPage(comments, r['next_cursor'] as String?);
  }

  static Future<List<ResponsePostComment>> replies(String commentId, {int limit = 50}) async {
    final r = await _c.get('/comments/$commentId/replies', query: {'limit': limit});
    final rows = ((r as Map)['data'] as List? ?? const []).whereType<Map>();
    return rows.map((m) => replyFromApi(Map<String, dynamic>.from(m))).toList();
  }

  /// Envoie un commentaire (ou une réponse si [parentId]). [CommentSent.paidCoins] = pièces débitées (0 ou 1).
  static Future<CommentSent> send(String postId, {String? body, String? parentId, Map<String, dynamic>? sticker}) async {
    final r = await _c.post('/posts/$postId/comments', body: {
      if (body != null) 'body': body,
      if (parentId != null) 'parent_id': parentId,
      if (sticker != null) 'sticker': sticker,
    }, idempotencyKey: ApiClient.newIdempotencyKey());
    final m = Map<String, dynamic>.from(r as Map);
    final quota = m['quota'] is Map ? Map<String, dynamic>.from(m['quota'] as Map) : <String, dynamic>{};
    return CommentSent(Map<String, dynamic>.from(m['data'] as Map), quota);
  }

  static Future<CommentQuota> quota(String postId) async {
    final d = ApiClient.data(await _c.get('/posts/$postId/comment-quota'));
    return CommentQuota.fromJson(d is Map ? Map<String, dynamic>.from(d) : const {});
  }

  static Future<void> delete(String commentId) async {
    await _c.delete('/comments/$commentId');
  }

  /// J'aime un commentaire ou une réponse. Réponse : {ok, already, paid, reason} (reason = insufficient ou own : le j'aime reste compté).
  static Future<Map<String, dynamic>> like(String commentId) async {
    final d = ApiClient.data(await _c.put('/comments/$commentId/like'));
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static Future<void> unlike(String commentId) async {
    await _c.delete('/comments/$commentId/like');
  }

  /// Cadeau (sticker ou pièces) sur un commentaire : voir `GiftController@toComment`.
  static Future<Map<String, dynamic>> gift(String commentId, Map<String, dynamic> body, {String? idempotencyKey}) async {
    final d = ApiClient.data(await _c.pay('/comments/$commentId/gifts', body: body, idempotencyKey: idempotencyKey));
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }
}

class ApiCommentPage {
  ApiCommentPage(this.comments, this.nextCursor);
  final List<PostComment> comments;
  final String? nextCursor;
}

class CommentSent {
  CommentSent(this.json, this.quota);
  final Map<String, dynamic> json;
  final Map<String, dynamic> quota;
  PostComment get comment => commentFromApi(json);
  ResponsePostComment get reply => replyFromApi(json);
  int get paidCoins => (quota['paid_coins'] as num?)?.toInt() ?? 0;
}

/// Quota de commentaires d'une publication.
class CommentQuota {
  CommentQuota({required this.freeLeft, required this.price, required this.raw});
  final int freeLeft;
  final int price;
  final Map<String, dynamic> raw;
  factory CommentQuota.fromJson(Map<String, dynamic> j) => CommentQuota(
        freeLeft: (j['free_left'] as num?)?.toInt() ?? 0,
        price: (j['price'] as num?)?.toInt() ?? (j['price_coins'] as num?)?.toInt() ?? 1,
        raw: j,
      );
}

/// Téléversements : URL signée, dépôt direct sur R2, confirmation. Renvoie l'identifiant à passer à [PostsApi.create].
class UploadsApi {
  UploadsApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static const _mime = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp', 'gif': 'image/gif',
    'mp4': 'video/mp4', 'mov': 'video/quicktime', 'webm': 'video/webm',
    'mp3': 'audio/mpeg', 'm4a': 'audio/mp4', 'aac': 'audio/aac', 'wav': 'audio/wav', 'ogg': 'audio/ogg',
  };

  static String contentTypeFor(String path) {
    final i = path.lastIndexOf('.');
    final ext = i < 0 ? '' : path.substring(i + 1).toLowerCase();
    return _mime[ext] ?? 'application/octet-stream';
  }

  /// Téléverse un fichier local. [onProgress] : 0.0 à 1.0.
  static Future<String> upload(File file, {String? contentType, bool private = false, void Function(double)? onProgress}) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(bytes, contentType: contentType ?? contentTypeFor(file.path), private: private, onProgress: onProgress);
  }

  static Future<String> uploadBytes(Uint8List bytes, {required String contentType, bool private = false, void Function(double)? onProgress}) async {
    final r = await _c.post('/uploads', body: {'content_type': contentType, 'size': bytes.length, if (private) 'private': true});
    final d = Map<String, dynamic>.from(ApiClient.data(r) as Map);
    final id = d['upload_id'] as String;
    final headers = Map<String, dynamic>.from(d['headers'] as Map? ?? {'Content-Type': contentType});
    final res = await Dio().put<dynamic>(
      d['url'] as String,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {...headers, Headers.contentLengthHeader: bytes.length},
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
      throw ApiException(status: code, code: 'upload_failed', message: "L'envoi du fichier a échoué. Réessayez.");
    }
    await _c.post('/uploads/$id/complete');
    return id;
  }
}
