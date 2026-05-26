
import 'package:cloud_firestore/cloud_firestore.dart';
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

class CoinGiftService {
  static const int coinsPerFcfa = 25;   // pour 10 FCFA
  static const int fcfaBase = 10;

  /// Conversion FCFA → pièces (arrondi défavorable à l’utilisateur)
  static int fcfaToCoins(double fcfaAmount) {
    return ((fcfaAmount / fcfaBase) * coinsPerFcfa).floor();
  }

  /// Conversion pièces → FCFA (arrondi favorable à l’utilisateur)
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
  }) async {
    final payerRef = firestore.collection('Users').doc(userPaid);
    final receiverRef = firestore.collection('Users').doc(userReceived);
    final isForSelf = userPaid == userReceived;

    return firestore.runTransaction((tx) async {
      // 1️⃣ Vérifier que le payeur existe
      final payerSnap = await tx.get(payerRef);
      if (!payerSnap.exists) throw Exception('Utilisateur payeur introuvable');

      // 2️⃣ Vérifier le solde FCFA du payeur
      final payerBalance = (payerSnap.data()?['votre_solde_principal'] ?? 0.0) as double;
      if (payerBalance < fcfaCost) {
        throw Exception('Solde FCFA insuffisant');
      }

      // 3️⃣ Vérifier que le destinataire existe (si différent du payeur)
      if (!isForSelf) {
        final receiverSnap = await tx.get(receiverRef);
        if (!receiverSnap.exists) throw Exception('Destinataire introuvable');
      }

      // 4️⃣ DÉBITER le payeur (son solde FCFA)
      tx.update(payerRef, {
        'votre_solde_principal': FieldValue.increment(-fcfaCost),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 5️⃣ CRÉDITER le destinataire en pièces
      tx.update(receiverRef, {
        'giftCoinsBalance': FieldValue.increment(coinsAmount),
        'totalGiftCoinsPurchased': FieldValue.increment(coinsAmount),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 6️⃣ Transaction pour le PAYEUR (dépense)
      final payerTransaction = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id = userPaid
        ..type = TypeTransaction.ACHAT_PIECES.name
        ..statut = StatutTransaction.VALIDER.name
        ..description = isForSelf
            ? "Achat de ${_formatNumber(coinsAmount)} pièces"
            : "Achat de ${_formatNumber(coinsAmount)} pièces pour @${_getUserName(userReceived, firestore)}"
        ..montant = fcfaCost
        ..methode_paiement = "solde_principal"
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      tx.set(firestore.collection('TransactionSoldes').doc(payerTransaction.id), payerTransaction.toJson());

      // 7️⃣ Transaction pour le DESTINATAIRE (gain) - seulement si différent du payeur
      if (!isForSelf) {
        final receiverTransaction = TransactionSolde()
          ..id = firestore.collection('TransactionSoldes').doc().id
          ..user_id = userReceived
          ..type = TypeTransaction.CADEAU_PIECES_RECU.name
          ..statut = StatutTransaction.VALIDER.name
          ..description = "Réception de ${_formatNumber(coinsAmount)} pièces de la part de @${authProvider.loginUserData!.pseudo}"
          ..montant = coinsAmount.toDouble()
          ..methode_paiement = "cadeau"
          ..createdAt = DateTime.now().millisecondsSinceEpoch
          ..updatedAt = DateTime.now().millisecondsSinceEpoch;
        tx.set(firestore.collection('TransactionSoldes').doc(receiverTransaction.id), receiverTransaction.toJson());
      }
    });
  }

// Helper pour formater les nombres
  static String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

// Helper pour récupérer le nom d'un utilisateur
  static Future<String> _getUserName(String userId, FirebaseFirestore firestore) async {
    try {
      final doc = await firestore.collection('Users').doc(userId).get();
      return doc.data()?['pseudo'] ?? 'utilisateur';
    } catch (e) {
      return 'utilisateur';
    }
  }
  /// Envoyer un like avec pièces (1 pièce pour le créateur, 1 pièce pour l'application)
  /// Si l'utilisateur n'a pas assez de pièces, retourne false avec un message
// services/coin_gift_service.dart

  /// Envoyer un like avec pièces (1 pièce pour le créateur, 1 pièce pour l'application)
  /// Si l'utilisateur n'a pas assez de pièces, retourne false avec un message
  static Future<bool> sendLikeWithCoins({
    required String senderId,
    required String receiverId,
    required FirebaseFirestore firestore,
    required UserAuthProvider authProvider,
    required Post post,
    required BuildContext context,
  }) async {
    const int coinsToDebit = 2;      // 2 pièces par like
    const int creatorCoins = 1;      // 1 pièce pour le créateur
    const int appCoins = 1;          // 1 pièce pour l'application

    final senderRef = firestore.collection('Users').doc(senderId);
    final receiverRef = firestore.collection('Users').doc(receiverId);
    final postRef = firestore.collection('Posts').doc(post.id);
    final appDataRef = firestore.collection('AppData').doc(authProvider.appDefaultData.id);

    // Vérifier le solde de l'utilisateur
    final senderDoc = await senderRef.get();
    if (!senderDoc.exists) {
      throw Exception('Utilisateur introuvable');
    }

    final currentCoins = (senderDoc.data()?['giftCoinsBalance'] ?? 0) as int;

    // Si solde insuffisant, retourner false avec un message
    if (currentCoins < coinsToDebit) {
      return false;
    }

    // 🔥 CORRECTION : Ajouter 'return' devant firestore.runTransaction
    return await firestore.runTransaction((tx) async {
      // 1. Débiter l'utilisateur (2 pièces)
      tx.update(senderRef, {
        'giftCoinsBalance': FieldValue.increment(-coinsToDebit),
        'totalGiftCoinsSpent': FieldValue.increment(coinsToDebit),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 2. Créditer le créateur (1 pièce)
      tx.update(receiverRef, {
        'giftCoinsBalance': FieldValue.increment(creatorCoins),
        'totalCoinsEarnedFromLikes': FieldValue.increment(creatorCoins),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 3. Créditer l'application (1 pièce)
      tx.update(appDataRef, {
        'solde_gain_pieces': FieldValue.increment(appCoins),
      });

      // 4. Mettre à jour le post (incrémenter les likes)
      tx.update(postRef, {
        'loves': FieldValue.increment(1),
        'users_love_id': FieldValue.arrayUnion([senderId]),
        'popularity': FieldValue.increment(1),
        'totalGiftCoinsSentOnThisPost': FieldValue.increment(creatorCoins),

        'totalCoinsFromLikes': FieldValue.increment(creatorCoins),
      });

      return true;
    });
  }

  /// Ajouter une commission de parrainage en PIÈCES (2.5% du montant en pièces)
  static Future<void> _addSponsorCommission({
    required String codeParrainage,
    required int coinsAmount,
    required FirebaseFirestore firestore,
    required UserAuthProvider authProvider,
  }) async {
    if (codeParrainage == null || codeParrainage.isEmpty) return;

    // Récupérer le parrain via son code
    final query = await firestore
        .collection('Users')
        .where('code_parrainage', isEqualTo: codeParrainage)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      print("⚠️ Aucun parrain trouvé avec ce code: $codeParrainage");
      return;
    }

    final DocumentSnapshot parrainDoc = query.docs.first;
    final DocumentReference parrainRef = parrainDoc.reference;
    final String parrainId = parrainDoc.id;

    // Calcul des 2.5% en pièces (arrondi favorable à l'utilisateur)
    final int commissionCoins = (coinsAmount * 0.025).ceil();

    if (commissionCoins <= 0) return;

    // Créditer le parrain en pièces
    await parrainRef.update({
      "giftCoinsBalance": FieldValue.increment(commissionCoins),
      "totalCoinsEarnedFromSponsorship": FieldValue.increment(commissionCoins),
    });

    // Enregistrement de la transaction GAIN en pièces
    final transactionRef = firestore.collection("TransactionSoldes").doc();
    final transaction = TransactionSolde()
      ..id = transactionRef.id
      ..user_id = parrainId
      ..type = TypeTransaction.GAIN_PIECES.name
      ..statut = StatutTransaction.VALIDER.name
      ..description = "Commission de parrainage (2.5%) sur cadeau de $coinsAmount pièces"
      ..montant = commissionCoins.toDouble()
      ..methode_paiement = "commission_parrainage"
      ..createdAt = DateTime.now().millisecondsSinceEpoch;

    await transactionRef.set(transaction.toJson());

    print("✅ Commission de $commissionCoins pièces ajoutée au parrain $parrainId");
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

  /// Envoi d’un cadeau en pièces avec toutes les fonctionnalités
  static Future<void> sendGift2({
    required String senderId,
    required String receiverId,
    required int coinsAmount,
    required FirebaseFirestore firestore,
    required UserAuthProvider authProvider,
    required Post post,
    required BuildContext context, // Ajout du context pour les notifications
    VoidCallback? onSuccess,
  })
  async {
    final senderRef = firestore.collection('Users').doc(senderId);
    final receiverRef = firestore.collection('Users').doc(receiverId);
    final postRef = firestore.collection('Posts').doc(post.id);
    final appDataRef = firestore.collection('AppData').doc(authProvider.appDefaultData.id);

    // Récupérer les données du destinataire pour la notification
    final receiverDoc = await receiverRef.get();
    final receiverData = receiverDoc.data();
    final receiverOneSignalId = receiverData?['oneIgnalUserid'] ?? '';
    final receiverName = receiverData?['pseudo'] ?? 'créateur';

    // Récupérer les codes parrainage
    final senderDoc = await senderRef.get();
    final senderData = senderDoc.data();
    final senderCodeParrain = senderData?['code_parrain'];
    final receiverCodeParrain = receiverData?['code_parrain'];

    final int receiverCoins = (coinsAmount * 0.7).floor(); // 70% pour le créateur
    int appCoins = coinsAmount - receiverCoins;            // 30% pour l’application
    int commissionSenderSponsor = 0;
    int commissionReceiverSponsor = 0;

    // 🔥 Gestion des commissions de parrainage (2.5% chacun)
    if (receiverCodeParrain != null && receiverCodeParrain.isNotEmpty) {
      if (senderCodeParrain != null && senderCodeParrain.isNotEmpty) {
        // Les deux ont des parrains
        commissionReceiverSponsor = (coinsAmount * 0.025).ceil();
        commissionSenderSponsor = (coinsAmount * 0.025).ceil();
        appCoins = coinsAmount - receiverCoins - commissionReceiverSponsor - commissionSenderSponsor;
      } else {
        // Seul le destinataire a un parrain
        commissionReceiverSponsor = (coinsAmount * 0.025).ceil();
        appCoins = coinsAmount - receiverCoins - commissionReceiverSponsor;
      }
    } else if (senderCodeParrain != null && senderCodeParrain.isNotEmpty) {
      // Seul l'expéditeur a un parrain
      commissionSenderSponsor = (coinsAmount * 0.025).ceil();
      appCoins = coinsAmount - receiverCoins - commissionSenderSponsor;
    }

    return firestore.runTransaction((tx) async {
      final senderSnap = await tx.get(senderRef);
      final receiverSnap = await tx.get(receiverRef);

      if (!senderSnap.exists || !receiverSnap.exists) {
        throw Exception('Utilisateur introuvable');
      }

      final senderCoins = (senderSnap.data()?['giftCoinsBalance'] ?? 0) as int;
      if (senderCoins < coinsAmount) {
        throw Exception('Pièces insuffisantes');
      }

      // 1. Débiter l’expéditeur
      tx.update(senderRef, {
        'giftCoinsBalance': FieldValue.increment(-coinsAmount),
        'totalGiftCoinsSpent': FieldValue.increment(coinsAmount),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 2. Créditer le destinataire (créateur)
      tx.update(receiverRef, {
        'giftCoinsBalance': FieldValue.increment(receiverCoins),
        'totalCoinsEarnedFromGifts': FieldValue.increment(receiverCoins),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 3. Gérer les commissions de parrainage
      if (commissionReceiverSponsor > 0) {
        await _addSponsorCommission(
          codeParrainage: receiverCodeParrain!,
          coinsAmount: coinsAmount,
          firestore: firestore,
          authProvider: authProvider,
        );
      }

      if (commissionSenderSponsor > 0) {
        await _addSponsorCommission(
          codeParrainage: senderCodeParrain!,
          coinsAmount: coinsAmount,
          firestore: firestore,
          authProvider: authProvider,
        );
      }

      // 4. Créditer l’application (solde_gain_pieces)
      tx.update(appDataRef, {
        'solde_gain_pieces': FieldValue.increment(appCoins),
      });

      // 5. Mettre à jour le post
      tx.update(postRef, {
        'users_cadeau_id': FieldValue.arrayUnion([senderId]),
        'popularity': FieldValue.increment(5),
        'giftCount': FieldValue.increment(1),  // 🔥 Incrémente le compteur d'envois
        'totalGiftCoinsSentOnThisPost': FieldValue.increment(coinsAmount),
      });

      // 6. Transaction pour l’expéditeur (type CADEAU_PIECES)
      final txSender = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id = senderId
        ..type = TypeTransaction.CADEAU_PIECES.name
        ..statut = StatutTransaction.VALIDER.name
        ..description = "Envoi de $coinsAmount pièces à @$receiverName"
        ..montant = coinsAmount.toDouble()
        ..methode_paiement = "pieces"
        ..createdAt = DateTime.now().millisecondsSinceEpoch;

      // 7. Transaction pour le destinataire (type CADEAU_PIECES_RECU)
      final txReceiver = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id = receiverId
        ..type = TypeTransaction.CADEAU_PIECES_RECU.name
        ..statut = StatutTransaction.VALIDER.name
        ..description = "Réception de $receiverCoins pièces de @${authProvider.loginUserData.pseudo}"
        ..montant = receiverCoins.toDouble()
        ..methode_paiement = "pieces"
        ..createdAt = DateTime.now().millisecondsSinceEpoch;

      tx.set(firestore.collection('TransactionSoldes').doc(txSender.id), txSender.toJson());
      tx.set(firestore.collection('TransactionSoldes').doc(txReceiver.id), txReceiver.toJson());
    });

    // 8. Envoyer les notifications (après la transaction)
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

    // 9. Ajouter des points pour l'action
    if (context.mounted) {
      // Appeler la méthode addPointsForAction via le provider
      // Cette méthode doit être accessible depuis le contexte
      final authProv = Provider.of<UserAuthProvider>(context, listen: false);

    }

    onSuccess?.call();
  }

  // services/coin_gift_service.dart - Ajouter cette méthode et modifier sendGift

  /// Envoi d’un cadeau en pièces avec toutes les fonctionnalités
  static Future<void> sendGift({
    required String senderId,
    required String receiverId,
    required int coinsAmount,
    required FirebaseFirestore firestore,
    required UserAuthProvider authProvider,
    required Post post,
    required BuildContext context,
    required CoinPack giftPack,  // 🔥 NOUVEAU : le pack de cadeau sélectionné
    VoidCallback? onSuccess,
  }) async {
    final senderRef = firestore.collection('Users').doc(senderId);
    final receiverRef = firestore.collection('Users').doc(receiverId);
    final postRef = firestore.collection('Posts').doc(post.id);
    final appDataRef = firestore.collection('AppData').doc(authProvider.appDefaultData.id);
    final giftsRef = firestore.collection('PostGifts');  // 🔥 Nouvelle collection

    // Récupérer les données du destinataire pour la notification
    final receiverDoc = await receiverRef.get();
    final receiverData = receiverDoc.data();
    final receiverOneSignalId = receiverData?['oneIgnalUserid'] ?? '';
    final receiverName = receiverData?['pseudo'] ?? 'créateur';

    // Récupérer les codes parrainage
    final senderDoc = await senderRef.get();
    final senderData = senderDoc.data();
    final senderCodeParrain = senderData?['code_parrain'];
    final receiverCodeParrain = receiverData?['code_parrain'];

    final int receiverCoins = (coinsAmount * 0.7).floor(); // 70% pour le créateur
    int appCoins = coinsAmount - receiverCoins;            // 30% pour l’application
    int commissionSenderSponsor = 0;
    int commissionReceiverSponsor = 0;

    // Gestion des commissions de parrainage (2.5% chacun)
    if (receiverCodeParrain != null && receiverCodeParrain.isNotEmpty) {
      if (senderCodeParrain != null && senderCodeParrain.isNotEmpty) {
        commissionReceiverSponsor = (coinsAmount * 0.025).ceil();
        commissionSenderSponsor = (coinsAmount * 0.025).ceil();
        appCoins = coinsAmount - receiverCoins - commissionReceiverSponsor - commissionSenderSponsor;
      } else {
        commissionReceiverSponsor = (coinsAmount * 0.025).ceil();
        appCoins = coinsAmount - receiverCoins - commissionReceiverSponsor;
      }
    } else if (senderCodeParrain != null && senderCodeParrain.isNotEmpty) {
      commissionSenderSponsor = (coinsAmount * 0.025).ceil();
      appCoins = coinsAmount - receiverCoins - commissionSenderSponsor;
    }

    return firestore.runTransaction((tx) async {
      final senderSnap = await tx.get(senderRef);
      final receiverSnap = await tx.get(receiverRef);

      if (!senderSnap.exists || !receiverSnap.exists) {
        throw Exception('Utilisateur introuvable');
      }

      final senderCoins = (senderSnap.data()?['giftCoinsBalance'] ?? 0) as int;
      if (senderCoins < coinsAmount) {
        throw Exception('Pièces insuffisantes');
      }

      // 1. Débiter l’expéditeur
      tx.update(senderRef, {
        'giftCoinsBalance': FieldValue.increment(-coinsAmount),
        'totalGiftCoinsSpent': FieldValue.increment(coinsAmount),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 2. Créditer le destinataire (créateur)
      tx.update(receiverRef, {
        'giftCoinsBalance': FieldValue.increment(receiverCoins),
        'totalCoinsEarnedFromGifts': FieldValue.increment(receiverCoins),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 3. Gérer les commissions de parrainage
      if (commissionReceiverSponsor > 0) {
        await _addSponsorCommission(
          codeParrainage: receiverCodeParrain!,
          coinsAmount: coinsAmount,
          firestore: firestore,
          authProvider: authProvider,
        );
      }

      if (commissionSenderSponsor > 0) {
        await _addSponsorCommission(
          codeParrainage: senderCodeParrain!,
          coinsAmount: coinsAmount,
          firestore: firestore,
          authProvider: authProvider,
        );
      }

      // 4. Créditer l’application (solde_gain_pieces)
      tx.update(appDataRef, {
        'solde_gain_pieces': FieldValue.increment(appCoins),
      });

      // 5. Mettre à jour le post
      tx.update(postRef, {
        'users_cadeau_id': FieldValue.arrayUnion([senderId]),
        'popularity': FieldValue.increment(5),
        'giftCount': FieldValue.increment(1),
        'totalGiftCoinsSentOnThisPost': FieldValue.increment(coinsAmount),
      });

      // 🔥 6. Enregistrer le cadeau dans la collection PostGifts
      final giftId = firestore.collection('PostGifts').doc().id;
      final postGift = PostGift(
        id: giftId,
        postId: post.id,
        senderId: senderId,
        receiverId: receiverId,
        giftIcon: giftPack.icon,
        giftLabel: giftPack.label,
        coinsAmount: coinsAmount,
        quantity: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      tx.set(firestore.collection('PostGifts').doc(giftId), postGift.toJson());

      // 7. Transaction pour l’expéditeur
      final txSender = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id = senderId
        ..type = TypeTransaction.CADEAU_PIECES.name
        ..statut = StatutTransaction.VALIDER.name
        ..description = "Envoi de ${giftPack.icon} $coinsAmount pièces à @$receiverName"
        ..montant = coinsAmount.toDouble()
        ..methode_paiement = "pieces"
        ..createdAt = DateTime.now().millisecondsSinceEpoch;

      // 8. Transaction pour le destinataire
      final txReceiver = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id = receiverId
        ..type = TypeTransaction.CADEAU_PIECES_RECU.name
        ..statut = StatutTransaction.VALIDER.name
        ..description = "Réception de ${giftPack.icon} $receiverCoins pièces de @${authProvider.loginUserData.pseudo}"
        ..montant = receiverCoins.toDouble()
        ..methode_paiement = "pieces"
        ..createdAt = DateTime.now().millisecondsSinceEpoch;

      tx.set(firestore.collection('TransactionSoldes').doc(txSender.id), txSender.toJson());
      tx.set(firestore.collection('TransactionSoldes').doc(txReceiver.id), txReceiver.toJson());
    });

    // 9. Envoyer les notifications
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