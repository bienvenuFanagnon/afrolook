import 'dart:async';
import 'dart:convert';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_identity.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_preload_service.dart';

/// Stock d'annonces d'Afrolook (boosts payés en pièces + annonces d'Afrolook Ads), préparé À L'AVANCE.
///
/// - Chargé au lancement puis au plus toutes les 30 minutes (retour dans l'application compris) : `GET /ads/app/pool`, environ 10 annonces choisies par
///   le serveur pour CETTE personne (pays du profil, langue, appareil, plafond par appareil, goûts). Les emplacements ne demandent plus rien.
/// - Gardé sur le téléphone (6 h) : prêt dès le lancement suivant, avant même la réponse du serveur.
/// - Images et vidéos préchargées en arrière-plan.
/// - Les emplacements (`AdSlot`) ne l'utilisent qu'en repli : quand Appodeal / AdMob n'ont rien à montrer. Voir `ad_slot.dart` et les règles d'accès `AdGate`.
/// - La vue et le clic sont comptés par le moteur d'Afrolook Ads (`AdsEngineService`), jeton demandé au moment de l'affichage.
///
/// Les éléments sont rendus dans la forme que le widget d'annonce lit depuis toujours : `{ad: <Advertisement>, post: <Post>|null, isEntityBoost: bool}`.
class AfrolookAdsPool {
  AfrolookAdsPool._();
  static final AfrolookAdsPool instance = AfrolookAdsPool._();

  static const _cacheKey = 'afl_ads_pool_v1';
  static const stockSize = 10;
  static const refreshAfter = Duration(minutes: 30);
  static const _cacheMaxAge = Duration(hours: 6);

  List<Map<String, dynamic>> _ads = const [];
  DateTime? _fetchedAt;
  Future<List<Map<String, dynamic>>>? _running;

  /// Le stock actuel (jamais d'exception ; vide tant que rien n'est chargé).
  List<Map<String, dynamic>> get ads => _ads;

  /// Stock récent (moins de 30 minutes) : pas besoin de le redemander.
  bool get isFresh => _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < refreshAfter;

  /// Oublie le stock (changement de compte, déconnexion).
  Future<void> clear() async {
    _ads = const [];
    _fetchedAt = null;
    try {
      (await SharedPreferences.getInstance()).remove(_cacheKey);
    } catch (_) {}
  }

  /// Stock gardé sur le téléphone, s'il est encore bon et s'il est celui de cette personne. Sert à afficher tout de suite au lancement.
  Future<List<Map<String, dynamic>>> fromCache() async {
    if (_ads.isNotEmpty) return _ads;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
      if (raw == null) return _ads;
      final j = jsonDecode(raw);
      if (j is! Map) return _ads;
      final at = DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0);
      final me = ApiIdentity.myId;
      if (DateTime.now().difference(at) > _cacheMaxAge || (me != null && j['uid'] != me)) return _ads;
      final list = convert((j['ads'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      if (list.isNotEmpty) _ads = list;   // _fetchedAt reste vide : le stock sera quand même redemandé au serveur
    } catch (e) {
      if (kDebugMode) debugPrint('AfrolookAdsPool.fromCache: $e');
    }
    return _ads;
  }

  /// Prépare le stock. Sans effet s'il est déjà frais (sauf [force]). Ne lève jamais d'exception ; si le réseau échoue, l'ancien stock est gardé.
  Future<List<Map<String, dynamic>>> refresh({bool force = false}) {
    if (!force && isFresh) return Future.value(_ads);
    return _running ??= _load().whenComplete(() => _running = null);
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final j = await RegieApi.adsPool(limit: stockSize);
      final raw = (j['ads'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _ads = convert(raw);
      _fetchedAt = DateTime.now();
      unawaited(_save(raw));
      _prefetch(_ads);
    } catch (e) {
      if (kDebugMode) debugPrint('AfrolookAdsPool.refresh: $e');
    }
    return _ads;
  }

  Future<void> _save(List<Map<String, dynamic>> raw) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_cacheKey, jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, 'uid': ApiIdentity.myId, 'ads': raw}));
    } catch (_) {}
  }

  /// Images (miniatures, avatars) dans le cache de l'application, vidéos sur le téléphone : l'annonce s'affiche sans attente.
  void _prefetch(List<Map<String, dynamic>> list) {
    AdPreloadService.prefetchFromAds(list.cast<Map<String, dynamic>>());
    final urls = <String>{};
    for (final e in list) {
      final ad = e['ad'] is Map ? e['ad'] as Map : const {};
      final post = e['post'] is Map ? e['post'] as Map : const {};
      final isVideo = post['dataType'] == 'VIDEO';
      for (final u in [ad['ownerAvatar'], post['thumbnail'], ...((post['images'] as List?) ?? const []), if (!isVideo) post['url_media']]) {
        final s = '${u ?? ''}';
        if (s.startsWith('http')) urls.add(s);
      }
    }
    unawaited(() async {
      for (final u in urls.take(30)) {
        try {
          await DefaultCacheManager().getSingleFile(u);
        } catch (_) {/* sera chargée à l'affichage */}
      }
    }());
  }

  /// Éléments du serveur → forme lue par le widget d'annonce. Un élément illisible ou terminé est écarté sans gêner les autres.
  @visibleForTesting
  static List<Map<String, dynamic>> convert(List<Map<String, dynamic>> raw) {
    final out = <Map<String, dynamic>>[];
    for (final it in raw) {
      try {
        final m = toLegacy(it);
        if (m != null) out.add(m);
      } catch (e) {
        if (kDebugMode) debugPrint('AfrolookAdsPool.convert: $e');
      }
    }
    return out;
  }

  @visibleForTesting
  static Map<String, dynamic>? toLegacy(Map<String, dynamic> it) {
    final id = '${it['id'] ?? ''}';
    if (id.isEmpty) return null;
    final type = '${it['target_type'] ?? ''}';
    final media = it['media'] is Map ? Map<String, dynamic>.from(it['media'] as Map) : <String, dynamic>{};
    final images = (media['images'] as List? ?? const []).map((e) => '$e').where((u) => u.isNotEmpty).toList();
    final mediaUrl = '${media['url'] ?? ''}';
    final thumb = '${media['thumb'] ?? ''}';
    final isVideo = media['type'] == 'video';
    final owner = it['owner'] is Map ? Map<String, dynamic>.from(it['owner'] as Map) : <String, dynamic>{};
    final cta = '${it['cta'] ?? ''}'.trim();
    final url = '${it['action_url'] ?? ''}'.trim();
    final text = '${it['text'] ?? ''}'.trim();
    final title = '${it['title'] ?? ''}'.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final ends = DateTime.tryParse('${it['ends_at']}')?.millisecondsSinceEpoch;
    if (ends != null && ends < now) return null;   // annonce terminée depuis le chargement du stock
    if (title.isEmpty && text.isEmpty) return null;   // rien à dire : pas de carte vide
    if (type != 'post' && type != 'profile' && type != 'canal' && type != 'group' && mediaUrl.isEmpty && images.isEmpty && thumb.isEmpty) return null;   // annonce sans aucun visuel

    // profil, canal ou groupe mis en avant : carte « entité » (pas de publication)
    final entityType = switch (type) { 'profile' => 'user', 'canal' => 'canal', 'group' => 'group', _ => null };
    final isEntity = entityType != null;
    final firstImage = thumb.isNotEmpty ? thumb : (images.isNotEmpty ? images.first : mediaUrl);
    final isPostBoost = type == 'post';

    final ad = Advertisement(
      id: id,
      postId: isPostBoost ? '${it['post_id'] ?? ''}' : null,
      description: text.isNotEmpty ? text : title,
      actionType: url.isEmpty ? null : 'visit',
      actionUrl: url.isEmpty ? null : url,
      actionButtonText: cta.isNotEmpty ? cta : (url.isEmpty ? null : 'En savoir plus'),
      status: 'active',
      startDate: now,
      endDate: ends,
      createdAt: now,
      updatedAt: now,
      ownerType: isEntity ? entityType : (isPostBoost && owner.isNotEmpty ? 'user' : null),
      ownerId: isEntity ? '${it['target_id'] ?? ''}' : (isPostBoost && owner.isNotEmpty ? '${owner['id'] ?? ''}' : null),
      ownerName: isEntity ? title : (isPostBoost && owner.isNotEmpty ? '${owner['name'] ?? ''}' : null),
      ownerAvatar: isEntity ? firstImage : (isPostBoost && owner.isNotEmpty ? '${owner['avatar'] ?? ''}' : null),
      ownerDescription: isEntity && text.isNotEmpty ? text : null,
    );

    Map<String, dynamic>? post;
    if (isEntity) {
      post = null;
    } else if (isPostBoost && it['post'] is Map) {
      post = postFromApi(Map<String, dynamic>.from(it['post'] as Map)).toJson();
    } else if (isPostBoost) {
      return null;   // boost de publication sans la publication : rien à montrer
    } else {
      // annonce d'Afrolook Ads (ou annonce autonome) : une carte « publication » faite avec son visuel et son texte
      final list = images.isEmpty && !isVideo && mediaUrl.isNotEmpty ? [mediaUrl] : images;
      final p = Post(
        id: 'ad_$id',
        user_id: '${owner['id'] ?? ''}',
        type: 'POST',
        status: 'VALIDE',
        dataType: isVideo ? 'VIDEO' : 'IMAGE',
        description: text.isNotEmpty ? text : title,
        createdAt: now,
        updatedAt: now,
      )
        ..images = list
        ..url_media = mediaUrl.isEmpty ? null : mediaUrl
        ..thumbnail = thumb.isEmpty ? null : thumb;
      post = p.toJson();
    }
    return {'ad': ad.toJson(), 'post': post, 'isEntityBoost': isEntity};
  }
}
