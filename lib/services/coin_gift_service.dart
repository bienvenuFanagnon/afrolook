import 'dart:math';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';

import '../models/coin_pack.dart';
import '../models/model_data.dart';
import '../providers/authProvider.dart';
import 'api/api_gateway.dart';
import 'api/wallet_api.dart';
import '../l10n/tr.dart';

class CoinGiftService {
  static const int coinsPerFcfa = 25;   // pour 10 FCFA
  static const int fcfaBase = 10;

  /// Champs de verrouillage à écrire quand [delta] pièces achetées (ou bonus) sont ajoutées :
  /// ces pièces restent dépensables mais pas convertibles en argent.
  /// Même calcul que lockFieldsAfterChange (functions/src/shared/coin_locks.ts).
  static Map<String, int> lockFieldsAfterPurchase(Map<String, dynamic>? user, int delta) {
    int n(String k) => (user?[k] as num?)?.toInt() ?? 0;
    final locked = n('lockedCoins');
    final spentSinceLock = (n('totalGiftCoinsSpent') - n('lockedCoinsSpentBaseline')).clamp(0, 999999999999);
    final effective = locked <= 0 ? 0 : (locked - spentSinceLock).clamp(0, n('giftCoinsBalance'));
    return {
      'lockedCoins': (effective + delta).clamp(0, 999999999999),
      'lockedCoinsSpentBaseline': n('totalGiftCoinsSpent'),
    };
  }

  /// Conversion FCFA → pièces (arrondi défavorable à l'utilisateur)
  static int fcfaToCoins(double fcfaAmount) {
    return ((fcfaAmount / fcfaBase) * coinsPerFcfa).floor();
  }

  /// Conversion pièces → FCFA (arrondi favorable à l'utilisateur)
  static double coinsToFcfa(int coins) {
    return ((coins / coinsPerFcfa) * fcfaBase).ceilToDouble();
  }

// services/coin_gift_service.dart

  /// Achat de pièces
  ///
  /// Cas 1 - Pour soi-même : userPaid = userReceived
  /// Cas 2 - Pour un autre : userPaid (celui qui paie) ≠ userReceived (celui qui reçoit)
  static Future<void> purchaseCoins({
    required String userPaid,      // L'utilisateur qui PAYE (son solde FCFA est débité)
    required String userReceived,  // L'utilisateur qui REÇOIT les pièces
    required int coinsAmount,
    required double fcfaCost,
    required UserAuthProvider authProvider,
    String balanceKey = 'votre_solde_depot', // solde débité : votre_solde_depot ou votre_solde_principal
  }) async {
    // Prix du pack, débit, crédit des pièces (Pièces de dépôt), transactions : calculés par l'API.
    try {
      await WalletApi.instance.buyCoinsWithBalance(
        coins: coinsAmount,
        balance: balanceKey == 'votre_solde_principal' ? 'payout' : 'deposit',
        beneficiaryId: userReceived != userPaid ? userReceived : null,
      );
    } on ApiException catch (e) {
      if (e.code == 'insufficient_funds') throw Exception('Solde insuffisant');
      if (e.code == 'unknown_beneficiary') throw Exception('Destinataire introuvable');
      throw Exception(WalletApi.message(e, fallback: 'Achat impossible'));
    }
  }

// Helper pour formater les nombres
// Helper pour récupérer le nom d'un utilisateur
  /// Envoyer un like avec pièces (1 pièce pour le créateur, 1 pièce pour l'application).
  /// Retourne false si l'utilisateur n'a pas assez de pièces.
  static Future<bool> sendLikeWithCoins({
    required String senderId,
    required String receiverId,
    required UserAuthProvider authProvider,
    required Post post,
    required BuildContext context,
  }) async {
    // 2 pièces : 1 au créateur, 1 à la plateforme — l'API décide (publication monétisée ou non) et annule le « j'aime » si le solde ne suffit pas
    try {
      await ApiGateway.instance.client.put('/posts/${post.id}/reaction');
    } on ApiException catch (e) {
      if (e.isInsufficientCoins) return false; // solde insuffisant
      rethrow;
    }
    return true;
  }

  /// Envoi d'un cadeau en pièces : débit, part du créateur, parrainages et part gardée sont calculés par l'API.
  static Future<void> sendGift({
    required String senderId,
    required String receiverId,
    required int coinsAmount,
    required UserAuthProvider authProvider,
    required Post post,
    required BuildContext context,
    required CoinPack giftPack,
    int quantity = 1,
    VoidCallback? onSuccess,
  }) async {
    try {
      await WalletApi.instance.giftPost(post.id!, coins: coinsAmount, icon: giftPack.icon, label: giftPack.label);
    } on ApiException catch (e) {
      if (e.isInsufficientCoins) throw Exception('Pièces insuffisantes');
      rethrow;
    }
    // La notification « cadeau reçu » est envoyée par l'API (voir lacunes_api_argent_creations.md).
    onSuccess?.call();
  }

  static List<String> get _giftMessages => [
    tr('🎁 Un cadeau pour soutenir ce travail 💪 Merci pour ce contenu !'),
    tr('🎁 Ce contenu mérite d\'être reconnu — voilà ma contribution !'),
    tr('🎁 Bravo pour ce post, voilà mon petit soutien 🔥'),
    tr('🎁 Continuez comme ça, vous méritez ce cadeau 💙'),
    tr('🎁 Ce contenu est top, je soutiens ✨'),
    tr('🎁 Merci pour ce que vous créez — voilà pour vous 🙏'),
    tr('🎁 Un vrai coup de cœur pour ce post 💎'),
    tr('🎁 Trop bien ce contenu, je vous soutiens 🚀'),
    tr('🎁 Voilà ma façon de vous encourager — continuez ! 💪'),
    tr('🎁 Ce post vaut le détour, voilà mon soutien 🌟'),
  ];

  static void postGiftAutoComment({
    required String senderId,
    required UserData senderData,
    required String postId,
    required CoinPack giftPack,
    required int coinsAmount,
    required int quantity,
  }) {
    Future.microtask(() async {
      try {
        final qty = quantity > 1
            ? quantity
            : (giftPack.coins > 0 ? (coinsAmount / giftPack.coins).round() : 1);
        final qtyText = qty > 1 ? ' × $qty' : '';
        final randomLine = _giftMessages[Random().nextInt(_giftMessages.length)];
        final message =
            '$randomLine\n'
            '${giftPack.icon} ${giftPack.label}$qtyText · $coinsAmount 🪙';
        await ApiGateway.instance.client.post('/posts/$postId/comments', body: {'body': message});
      } catch (e) {
        printVm('⚠️ _postGiftAutoComment: $e');
      }
    });
  }

  /// Conversion de pièces gagnées en FCFA à retirer (calcul et vérifications faits par l'API).
  static Future<void> convertCoinsToFcfa({required int coinsAmount}) async {
    try {
      await WalletApi.instance.convert(coinsAmount);
    } on ApiException catch (e) {
      throw Exception(WalletApi.message(e, fallback: 'Conversion impossible'));
    }
  }
}
