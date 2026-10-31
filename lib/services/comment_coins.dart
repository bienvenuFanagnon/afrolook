import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';
import '../providers/coin_gift_provider.dart';
import '../widgets/like_coins_helper.dart';

/// Les commentaires suivent la règle du serveur : 10 gratuits par publication, puis 1 pièce (le débit est fait par l'API à l'envoi).
/// [charge] est conservée (appelée après chaque commentaire) mais ne fait plus rien.
/// Reste ici : la suite d'un j'aime de commentaire (le paiement lui-même est fait par l'API).
class CommentCoins {
  /// Ne débite plus rien côté application : le serveur débite à l'envoi du commentaire.
  static Future<void> charge(BuildContext context, Post post) async {}

  /// Suite d'un j'aime de commentaire ou de réponse. [result] = réponse de l'API : {paid, reason}.
  /// Payé : le solde est relu depuis l'API et l'animation s'affiche. Solde insuffisant : la fenêtre d'insuffisance s'affiche (le j'aime reste compté).
  static Future<void> afterLike(BuildContext context, Map<String, dynamic> result, {required String authorPseudo}) async {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    final userId = auth.loginUserData.id;
    if (userId == null) return;
    try {
      if (result['paid'] == true) {
        await coinProvider.refreshBalance(userId);
        if (context.mounted) {
          showLikeOverlay(context, creatorName: authorPseudo);
        }
      } else if (result['reason'] == 'insufficient' && context.mounted) {
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
