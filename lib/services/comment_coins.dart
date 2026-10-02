import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';
import '../providers/coin_gift_provider.dart';
import '../widgets/like_coins_helper.dart';
import '../widgets/support_modal.dart';

/// Les commentaires sont GRATUITS (depuis octobre 2026) : plus aucun débit, ni gain pour le créateur.
/// [charge] est conservée (appelée après chaque commentaire) mais ne fait plus rien.
/// Reste ici : le like payant d'un commentaire ou d'une réponse.
class CommentCoins {
  /// Ne débite plus rien : commenter est gratuit.
  static Future<void> charge(BuildContext context, Post post) async {}

  /// Like payant d'un commentaire ou d'une réponse : 2 pièces (1 à l'auteur, 1 à l'app), payé une seule fois.
  /// Le like reste toujours compté ; sans solde, la fenêtre d'insuffisance s'affiche. Rien pour son propre commentaire.
  static Future<void> like(
    BuildContext context, {
    required String commentId,
    String? replyId,
    required String authorId,
    required String authorPseudo,
  }) async {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    final userId = auth.loginUserData.id;
    if (userId == null || userId == authorId) return;
    try {
      final res = await FirebaseFunctions.instance.httpsCallable('sendCommentLike').call({
        'commentId': commentId,
        if (replyId != null) 'replyId': replyId,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      if (!context.mounted) return;
      if (data['paid'] == true) {
        await coinProvider.refreshBalance(userId);
        if (context.mounted) {
          // Même animation que le like d'un post : grand cœur + « Votre like rapporte 1 🪙 à @pseudo ! »
          showLikeOverlay(context, creatorName: authorPseudo);
        }
      } else if (data['reason'] == 'insufficient') {
        showInsufficientCoinsForLikeDialog(
          context: context,
          user: auth.loginUserData,
          coinProvider: coinProvider,
          authProvider: auth,
        );
      }
    } catch (e) {
      debugPrint('Like commentaire : $e');
    }
  }
}
