

import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';

import '../models/coin_pack.dart';
import '../models/model_data.dart';
import '../providers/authProvider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';

// services/coin_gift_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/model_data.dart';
import '../providers/authProvider.dart';
import 'inactiveUserReminderHelperService.dart';

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
    required FirebaseFirestore firestore,
    required UserAuthProvider authProvider,
    String balanceKey = 'votre_solde_depot', // solde débité : votre_solde_depot ou votre_solde_principal
  }) async {
    // Prix du pack, débit, crédit des pièces (Pièces de dépôt), transactions et suivi des ventes :
    // calculés par le serveur (buyCoinsWithBalance). Un e-mail est envoyé aux admins à chaque achat.
    try {
      await FirebaseFunctions.instance.httpsCallable('buyCoinsWithBalance').call({
        'coins': coinsAmount,
        'balanceKey': balanceKey,
        if (userReceived != userPaid) 'beneficiaryId': userReceived,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') throw Exception('Solde insuffisant');
      if (e.code == 'not-found') throw Exception('Destinataire introuvable');
      throw Exception(e.message ?? 'Achat impossible');
    }
  }

// Helper pour formater les nombres
// Helper pour récupérer le nom d'un utilisateur
  /// Envoyer un like avec pièces (1 pièce pour le créateur, 1 pièce pour l'application).
  /// Retourne false si l'utilisateur n'a pas assez de pièces.
  static Future<bool> sendLikeWithCoins({
    required String senderId,
    required String receiverId,
    required FirebaseFirestore firestore,
    required UserAuthProvider authProvider,
    required Post post,
    required BuildContext context,
  }) async {
    // 2 pièces : 1 au créateur, 1 à l'app — calculé par le serveur (sendLike)
    try {
      await FirebaseFunctions.instance.httpsCallable('sendLike').call({'postId': post.id});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') return false; // solde insuffisant
      rethrow;
    }
    // Vérifier si le propriétaire est inactif (en arrière-plan)
    _checkAndSendReminderIfInactive(receiverId);
    return true;
  }

  /// Vérification en arrière-plan (non bloquante)
  static void _checkAndSendReminderIfInactive(String userId) {
    // Exécution en arrière-plan sans attendre
    Future.microtask(() async {
      try {
        // 1. Vérifier si l'utilisateur est inactif (depuis Firestore)
        final isInactive = await InactiveUserReminderService.isUserInactive(userId);
        if (!isInactive) return;

        // 2. Vérifier la limite mensuelle (depuis Firestore)
        final canReceive = await InactiveUserReminderService.canReceiveReminder(userId);
        if (!canReceive) return;

        // 3. Récupérer les données utilisateur
        final userData = await InactiveUserReminderService.getUserEmailData(userId);
        if (userData == null) return;
        if (userData['userEmail'] == null || userData['userEmail'].isEmpty) return;

        // 4. Appeler la Cloud Function
        final result = await FirebaseFunctions.instance
            .httpsCallable('sendInactiveUserReminder')
            .call({'userId': userId, 'userData': userData});

        if (result.data['success'] == true) {
          printVm('✅ Email de rappel envoyé à ${userData['userEmail']}');
        }
      } catch (e) {
        printVm('❌ Erreur _checkAndSendReminderIfInactive: $e');
      }
    });
  }

  /// Envoyer une notification de cadeau
  static Future<void> _sendGiftNotification({
    required String receiverId,
    required String receiverOneSignalId,
    required String senderName,
    required int coinsAmount,
    required String postId,
    required String postDataType,
    required UserAuthProvider authProvider,
    required BuildContext context,
  }) async {
    // Notification Firebase
    final notificationId = FirebaseFirestore.instance.collection('Notifications').doc().id;
    final notification = NotificationData(
      id: notificationId,
      titre: "🎁 Cadeau reçu !",
      media_url: authProvider.loginUserData.imageUrl ?? '',
      type: NotificationType.POST.name,
      description: "@$senderName vous a envoyé un cadeau de $coinsAmount pièces ! 🎉",
      users_id_view: [],
      user_id: authProvider.loginUserData.id!,
      receiver_id: receiverId,
      post_id: postId,
      post_data_type: postDataType,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: PostStatus.VALIDE.name,
    );

    await FirebaseFirestore.instance
        .collection('Notifications')
        .doc(notificationId)
        .set(notification.toJson());

    // Push notification
    if (receiverOneSignalId != null && receiverOneSignalId.isNotEmpty) {
      await authProvider.sendNotification(
        userIds: [receiverOneSignalId],
        smallImage: authProvider.loginUserData.imageUrl ?? '',
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: receiverId,
        message: "🎁 @$senderName vous a envoyé un cadeau de $coinsAmount pièces !",
        type_notif: NotificationType.POST.name,
        post_id: postId,
        post_type: postDataType,
        chat_id: '',
      );
    }
  }

  /// Envoi d'un cadeau en pièces : débit, 70 % au créateur, parrainages et part de l'app
  /// sont calculés par le serveur (sendPostGift) ; l'app gère la notification.
  static Future<void> sendGift({
    required String senderId,
    required String receiverId,
    required int coinsAmount,
    required FirebaseFirestore firestore,
    required UserAuthProvider authProvider,
    required Post post,
    required BuildContext context,
    required CoinPack giftPack,
    int quantity = 1,
    VoidCallback? onSuccess,
  }) async {
    final receiverDoc = await firestore.collection('Users').doc(receiverId).get();
    final receiverOneSignalId = receiverDoc.data()?['oneIgnalUserid'] ?? '';

    try {
      await FirebaseFunctions.instance.httpsCallable('sendPostGift').call({
        'postId': post.id,
        'coins': coinsAmount,
        'giftIcon': giftPack.icon,
        'giftLabel': giftPack.label,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') throw Exception('Pièces insuffisantes');
      rethrow;
    }

    await _sendGiftNotification(
      receiverId: receiverId,
      receiverOneSignalId: receiverOneSignalId,
      senderName: authProvider.loginUserData.pseudo ?? 'Un utilisateur',
      coinsAmount: coinsAmount,
      postId: post.id!,
      postDataType: post.dataType ?? PostDataType.IMAGE.name,
      authProvider: authProvider,
      context: context,
    );

    onSuccess?.call();
  }

  static const List<String> _giftMessages = [
    '🎁 Un cadeau pour soutenir ce travail 💪 Merci pour ce contenu !',
    '🎁 Ce contenu mérite d\'être reconnu — voilà ma contribution !',
    '🎁 Bravo pour ce post, voilà mon petit soutien 🔥',
    '🎁 Continuez comme ça, vous méritez ce cadeau 💙',
    '🎁 Ce contenu est top, je soutiens ✨',
    '🎁 Merci pour ce que vous créez — voilà pour vous 🙏',
    '🎁 Un vrai coup de cœur pour ce post 💎',
    '🎁 Trop bien ce contenu, je vous soutiens 🚀',
    '🎁 Voilà ma façon de vous encourager — continuez ! 💪',
    '🎁 Ce post vaut le détour, voilà mon soutien 🌟',
  ];

  static void postGiftAutoComment({
    required String senderId,
    required UserData senderData,
    required String postId,
    required CoinPack giftPack,
    required int coinsAmount,
    required int quantity,
    required FirebaseFirestore firestore,
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

        final commentId = firestore.collection('PostComments').doc().id;
        final now = DateTime.now().microsecondsSinceEpoch;

        await firestore.collection('PostComments').doc(commentId).set({
          'id': commentId,
          'user_id': senderId,
          'post_id': postId,
          'message': message,
          'created_at': now,
          'updated_at': now,
          'loves': 0,
          'likes': 0,
          'comments': 0,
          'users_like_id': [],
          'responseComments': [],
          'isAutoGiftComment': true,
        });

        await firestore.collection('Posts').doc(postId).update({
          'comments': FieldValue.increment(1),
        });
      } catch (e) {
        printVm('⚠️ _postGiftAutoComment: $e');
      }
    });
  }

  /// Conversion de pièces en FCFA (ajout au solde principal)
  static Future<void> convertCoinsToFcfa({
    required String userId,
    required int coinsAmount,
    required FirebaseFirestore firestore,
  }) async {
    final double fcfaGain = coinsToFcfa(coinsAmount);
    final userRef = firestore.collection('Users').doc(userId);

    return firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('Utilisateur introuvable');
      final currentCoins = (userSnap.data()?['giftCoinsBalance'] ?? 0) as int;
      if (currentCoins < coinsAmount) throw Exception('Pièces insuffisantes');

      tx.update(userRef, {
        'giftCoinsBalance': FieldValue.increment(-coinsAmount),
        'votre_solde_principal': FieldValue.increment(fcfaGain),
        'totalGiftCoinsConverted': FieldValue.increment(coinsAmount),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      final transaction = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id = userId
        ..type = TypeTransaction.CONVERSION_PIECES.name
        ..statut = StatutTransaction.VALIDER.name
        ..description = "Conversion de $coinsAmount pièces en FCFA"
        ..montant = fcfaGain
        ..methode_paiement = "pieces"
        ..createdAt = DateTime.now().millisecondsSinceEpoch;

      tx.set(firestore.collection('TransactionSoldes').doc(transaction.id), transaction.toJson());
    });
  }
}
