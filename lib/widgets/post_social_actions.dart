import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/ads/rewarded_ads.dart';
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_identity.dart';
import 'package:afrotok/services/api/post_social_api.dart';
import 'package:flutter/material.dart';

/// Actions « republier » et « soutenir par une pub » d'une publication, avec leurs messages (traduits) et le bouton « Réessayer ».
/// Utilisées par tous les écrans qui montrent une publication (fil, détails, vidéos, vibes).
class PostSocialActions {
  PostSocialActions._();

  static void _say(BuildContext context, String text, {Color? color, SnackBarAction? action, int seconds = 3}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: color,
      action: action,
      duration: Duration(seconds: seconds),
    ));
  }

  /// Identifiant de la publication d'origine quand [post] est une republication affichée dans le fil.
  static String? originalId(Post post) => post.isRepost == true ? (post.originalPostId ?? post.id) : post.id;

  // ── Republier ──

  /// Republie [post] auprès de mes abonnés. Renvoie vrai si la republication existe (nouvelle ou déjà faite).
  /// [onDone] est appelé après une republication réussie (pour rafraîchir le compteur de l'écran).
  static Future<bool> repost(BuildContext context, Post post, {required String? myId, VoidCallback? onDone}) async {
    final id = originalId(post);
    if (myId == null || id == null) return false;
    if (myId == post.user_id) {
      _say(context, tr('Tu ne peux pas republier ta propre publication.'));
      return false;
    }
    post.users_republier_id ??= [];
    if (post.users_republier_id!.contains(myId)) {
      _say(context, tr('Tu as déjà republié cette publication.'));
      return true;
    }
    try {
      final r = await PostSocialApi.repost(id);
      // Déjà republiée avant : la personne est déjà dans le compteur (entrée vide), on la nomme sans compter deux fois.
      final slot = r.already ? post.users_republier_id!.indexOf('') : -1;
      if (slot >= 0) {
        post.users_republier_id![slot] = myId;
      } else {
        post.users_republier_id!.add(myId);
      }
      while (post.users_republier_id!.length < r.repostsCount) {
        post.users_republier_id!.add('');
      }
      if (r.sharesCount > 0) post.partage = r.sharesCount;
      _say(context, r.already ? tr('Tu as déjà republié cette publication.') : tr('Publication republiée ✓'), seconds: 2);
      onDone?.call();
      return true;
    } catch (e) {
      _say(
        context,
        PostSocialMessages.repost(e),
        action: SnackBarAction(label: tr('Réessayer'), onPressed: () => repost(context, post, myId: myId, onDone: onDone)),
      );
      return false;
    }
  }

  // ── Soutenir par une publicité ──

  /// Parcours complet : pub récompensée regardée en entier -> déclarée au serveur -> soutien. Renvoie vrai si le créateur a reçu sa pièce.
  /// [onSupported] reçoit le nombre de soutiens tenu par le serveur.
  static Future<bool> supportWithAd(BuildContext context, Post post, {required String? myId, void Function(int count)? onSupported}) async {
    final id = post.id;
    if (id == null) return false;
    if (myId != null && myId == post.user_id) {
      _say(context, tr('Tu ne peux pas soutenir ta propre publication.'), color: Colors.orange.shade800);
      return false;
    }
    if (await PostSocialApi.supportedToday(id)) {
      if (context.mounted) _say(context, tr('Tu as déjà soutenu cette publication aujourd\'hui. Reviens demain !'), color: Colors.orange.shade800);
      return false;
    }
    final watched = await RewardedAds.watch(userId: ApiIdentity.myId);
    if (!watched) {
      if (context.mounted) _say(context, tr('Publicité non terminée ou indisponible. Réessaie dans un instant.'), color: Colors.orange.shade800);
      return false;
    }
    if (!context.mounted) return false;
    return _finishSupport(context, post, declare: true, onSupported: onSupported);
  }

  static Future<bool> _finishSupport(BuildContext context, Post post, {required bool declare, void Function(int count)? onSupported}) async {
    var declared = !declare; // la pub est-elle déjà en réserve chez le serveur ?
    try {
      if (!declared) {
        await PostSocialApi.declareWatchedAd();
        declared = true;
      }
      final r = await PostSocialApi.supportAfterAd(post.id!, declare: false);
      post.adSupportCount = r.adSupportCount > 0 ? r.adSupportCount : (post.adSupportCount ?? 0) + 1;
      onSupported?.call(post.adSupportCount ?? 0);
      _say(context, tr('🎉 Merci ! Le créateur a reçu {n} pièce.', {'n': r.coins}), color: Colors.green.shade700, seconds: 2);
      return true;
    } catch (e) {
      _say(
        context,
        PostSocialMessages.support(e),
        color: Colors.orange.shade800,
        action: PostSocialMessages.supportRetryable(e)
            ? SnackBarAction(label: tr('Réessayer'), onPressed: () => _finishSupport(context, post, declare: !declared, onSupported: onSupported))
            : null,
        seconds: 4,
      );
      return false;
    }
  }
}
