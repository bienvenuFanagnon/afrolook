import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';
import '../providers/coin_gift_provider.dart';
import '../widgets/like_coins_helper.dart';

/// Paiement des commentaires : 2 pièces (1 au créateur, 1 à l'app), calculé par le serveur (sendComment).
/// Gratuit pour le créateur sur son propre post ; les réponses aux commentaires ne passent pas ici.
/// N'empêche jamais la publication : sans solde, le commentaire est publié et une fenêtre invite à recharger.
class CommentCoins {
  /// À appeler juste après la publication d'un commentaire (pas d'une réponse).
  static Future<void> charge(BuildContext context, Post post) async {
    final postId = post.id;
    if (postId == null) return;
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    final userId = auth.loginUserData.id;
    if (userId == null || userId == post.user_id) return;

    try {
      final res = await FirebaseFunctions.instance.httpsCallable('sendComment').call({'postId': postId});
      final data = Map<String, dynamic>.from(res.data as Map);
      if (!context.mounted) return;
      if (data['paid'] == true) {
        showLikeOverlay(context, creatorName: post.user?.pseudo ?? '', isComment: true);
        post.totalGiftCoinsSentOnThisPost = (post.totalGiftCoinsSentOnThisPost ?? 0) + 1;
        await coinProvider.refreshBalance(userId);
      } else if (data['reason'] == 'insufficient') {
        showInsufficientCoinsForLikeDialog(
          context: context,
          user: auth.loginUserData,
          coinProvider: coinProvider,
          authProvider: auth,
          isComment: true,
        );
      }
    } catch (e) {
      // Erreur réseau : le commentaire reste publié, rien n'est débité
      debugPrint('Paiement commentaire : $e');
    }
  }
}
