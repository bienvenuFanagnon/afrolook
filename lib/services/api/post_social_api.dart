import 'dart:async';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/ads/ad_config.dart';
import 'package:afrotok/ads/rewards_service.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/post_social_models.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:afrotok/services/api/post_social_models.dart';

/// Lot B2 « publications » : republier (`POST /posts/{id}/repost`) et soutenir une publication en regardant une pub (`POST /posts/{id}/support-ad`).
/// Aucun retour à Firebase : une erreur de l'API est remontée à l'écran (message traduit par [PostSocialMessages] + « Réessayer »).
class PostSocialApi {
  PostSocialApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  // ── Republication ──

  /// Republie une publication auprès de mes abonnés. Une seule fois par personne : au second appel, [RepostResult.already] est vrai.
  /// Erreurs : 404 `not_found`, 422 `cannot_repost_own`, 422 `not_repostable`, 403 `blocked`.
  static Future<RepostResult> repost(String postId) async => RepostResult.fromResponse(await _c.post('/posts/$postId/repost'));

  // ── Soutien par publicité ──

  /// Clé d'idempotence conservée jusqu'au succès : un nouvel essai après une coupure réseau ne compte pas deux fois le soutien.
  static final Map<String, String> _keys = {};

  /// Consomme UNE pub de la réserve du serveur au profit du créateur. Ne s'appelle qu'après une pub regardée en entier ET déclarée
  /// ([declareWatchedAd]) ; sinon le serveur répond 409 `ad_not_watched`. Autres erreurs : 409 `already_supported_today`
  /// (la pub n'est alors pas consommée), 422 `cannot_support_own`, 422 `not_supportable`, 404 `not_found`.
  static Future<AdSupportResult> supportAd(String postId) async {
    final key = _keys.putIfAbsent(postId, ApiClient.newIdempotencyKey);
    try {
      final r = AdSupportResult.fromResponse(await _c.pay('/posts/$postId/support-ad', idempotencyKey: key));
      _keys.remove(postId);
      await _rememberSupported(postId);
      return r;
    } on ApiException catch (e) {
      if (!e.isNetwork) _keys.remove(postId); // une réponse du serveur clôt cet essai ; seule une coupure réseau garde la clé
      if (e.code == 'already_supported_today') await _rememberSupported(postId);
      rethrow;
    }
  }

  /// Met la pub qui vient d'être regardée « en réserve » (étape 2 du parcours) :
  /// - sans vérification AdMob côté serveur, l'application la déclare (`POST /rewards/views`) ;
  /// - avec la vérification (SSV), le serveur la reçoit d'AdMob : on attend qu'elle arrive (voir [supportAfterAd]).
  static Future<void> declareWatchedAd() async {
    await RewardsService.loadConfig();
    if (_ssv) return;
    await RewardsService.recordView();
  }

  static bool get _ssv => RewardsService.serverSsv || AdConfig.current.ssvEnabled;

  /// Étapes 2 et 3 du parcours, à appeler quand la pub récompensée a été regardée jusqu'au bout.
  /// Avec la vérification AdMob, la confirmation du serveur peut arriver quelques secondes plus tard : on réessaie (6 fois, toutes les 1,5 s)
  /// tant que le serveur répond `ad_not_watched`.
  /// [declare] à faux pour un nouvel essai après coupure : la pub est déjà en réserve, il ne faut pas la déclarer deux fois.
  static Future<AdSupportResult> supportAfterAd(String postId, {bool declare = true, Duration wait = const Duration(milliseconds: 1500)}) async {
    if (declare) await declareWatchedAd();
    final tries = _ssv ? 6 : 1;
    for (var i = 1;; i++) {
      try {
        return await supportAd(postId);
      } on ApiException catch (e) {
        if (e.code == 'ad_not_watched' && i < tries) {
          await Future<void>.delayed(wait);
          continue;
        }
        rethrow;
      }
    }
  }

  // ── Mémoire locale du jour (évite de faire regarder une pub pour rien) ──

  static String _utcDay() => DateTime.now().toUtc().toIso8601String().substring(0, 10);

  static Future<void> _rememberSupported(String postId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('support_ad_$postId', _utcDay());
    } catch (e) {
      if (kDebugMode) debugPrint('support_ad : mémoire locale indisponible ($e)');
    }
  }

  /// Vrai si cette publication a déjà été soutenue aujourd'hui (jour UTC, comme le serveur) : inutile de lancer une pub.
  static Future<bool> supportedToday(String postId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getString('support_ad_$postId') == _utcDay();
    } catch (_) {
      return false;
    }
  }
}
