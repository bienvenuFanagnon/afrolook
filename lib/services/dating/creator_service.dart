// lib/services/creator_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import 'coin_service.dart';

class CreatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CoinService _coinService = CoinService();

  // Créer un profil créateur
  Future<bool> createCreatorProfile(CreatorProfile profile) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updatedProfile = profile.copyWith(
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection('creator_profiles')
          .doc(profile.id)
          .set(updatedProfile.toJson());

      return true;
    } catch (e) {
      print('Erreur lors de la création du profil créateur: $e');
      return false;
    }
  }

  // S'abonner à un créateur
  Future<bool> subscribeToCreator({
    required String userId,
    required String creatorId,
    bool isPaid = false,
    int? paidCoinsAmount,
  }) async {
    try {
      // Vérifier si l'abonnement existe déjà
      final existingSubscription = await _firestore
          .collection('creator_subscriptions')
          .where('userId', isEqualTo: userId)
          .where('creatorId', isEqualTo: creatorId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingSubscription.docs.isNotEmpty) {
        return true; // Déjà abonné
      }

      // Si abonnement payant, débiter les pièces
      if (isPaid && paidCoinsAmount != null) {
        final success = await _coinService.spendCoins(
          userId: userId,
          amount: paidCoinsAmount,
          type: CoinTransactionType.spend_creator_subscription,
          referenceId: creatorId,
          description: 'Abonnement au créateur',
        );

        if (!success) {
          throw Exception('Solde de pièces insuffisant');
        }

        // Créditer le créateur
        await _coinService.creditCreator(
          creatorId: creatorId,
          amount: paidCoinsAmount,
          type: CoinTransactionType.earn_creator_subscription,
          referenceId: userId,
          description: 'Abonnement payant',
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final subscription = CreatorSubscription(
        id: _firestore.collection('creator_subscriptions').doc().id,
        userId: userId,
        creatorId: creatorId,
        subscribedAt: now,
        isActive: true,
        notificationsEnabled: true,
        isPaidSubscription: isPaid,
        paidCoinsAmount: paidCoinsAmount,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection('creator_subscriptions')
          .doc(subscription.id)
          .set(subscription.toJson());

      // Incrémenter le compteur d'abonnés du créateur
      await _firestore
          .collection('creator_profiles')
          .doc(creatorId)
          .update({
        'subscribersCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Erreur lors de l\'abonnement: $e');
      return false;
    }
  }

  // Publier un contenu
  Future<bool> publishContent(CreatorContent content) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updatedContent = content.copyWith(
        isPublished: true,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection('creator_contents')
          .doc(content.id)
          .set(updatedContent.toJson());

      // Incrémenter le compteur de contenus du créateur
      final fieldToUpdate = updatedContent.isPaid
          ? 'paidContentsCount'
          : 'freeContentsCount';
      await _firestore
          .collection('creator_profiles')
          .doc(content.creatorId)
          .update({
        fieldToUpdate: FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Erreur lors de la publication: $e');
      return false;
    }
  }

  // Réagir à un contenu
  Future<bool> reactToContent({
    required String contentId,
    required String creatorId,
    required String userId,
    required ReactionType reactionType,
  }) async {
    try {
      // Vérifier si la réaction existe déjà
      final existingReaction = await _firestore
          .collection('creator_content_reactions')
          .where('contentId', isEqualTo: contentId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      return await _firestore.runTransaction((transaction) async {
        final now = DateTime.now().millisecondsSinceEpoch;

        if (existingReaction.docs.isNotEmpty) {
          // Mettre à jour la réaction existante
          final reaction = CreatorContentReaction.fromJson(existingReaction.docs.first.data());
          if (reaction.reactionType == reactionType) {
            return true; // Même réaction, rien à faire
          }

          // Mettre à jour les compteurs
          await _updateReactionCounters(
            contentId,
            reaction.reactionType,
            -1, // Décrémenter l'ancienne réaction
          );

          transaction.update(existingReaction.docs.first.reference, {
            'reactionType': reactionType.value,
            'updatedAt': now,
          });
        } else {
          // Créer une nouvelle réaction
          final reaction = CreatorContentReaction(
            id: _firestore.collection('creator_content_reactions').doc().id,
            contentId: contentId,
            creatorId: creatorId,
            userId: userId,
            reactionType: reactionType,
            createdAt: now,
            updatedAt: now,
          );
          transaction.set(
            _firestore.collection('creator_content_reactions').doc(reaction.id),
            reaction.toJson(),
          );
        }

        // Mettre à jour les compteurs
        await _updateReactionCounters(contentId, reactionType, 1);

        return true;
      });
    } catch (e) {
      print('Erreur lors de la réaction: $e');
      return false;
    }
  }

  // Enregistrer une vue de contenu
  Future<bool> recordContentView({
    required String contentId,
    required String creatorId,
    required String userId,
  }) async {
    try {
      // Vérifier si la vue existe déjà
      final existingView = await _firestore
          .collection('creator_content_views')
          .where('contentId', isEqualTo: contentId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingView.docs.isNotEmpty) {
        return true; // Vue déjà enregistrée
      }

      return await _firestore.runTransaction((transaction) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final view = CreatorContentView(
          id: _firestore.collection('creator_content_views').doc().id,
          contentId: contentId,
          creatorId: creatorId,
          userId: userId,
          viewedAt: now,
        );

        transaction.set(
          _firestore.collection('creator_content_views').doc(view.id),
          view.toJson(),
        );

        // Incrémenter le compteur de vues du contenu
        transaction.update(
          _firestore.collection('creator_contents').doc(contentId),
          {
            'viewsCount': FieldValue.increment(1),
            'interactionsCount': FieldValue.increment(1),
          },
        );

        // Incrémenter le compteur de vues du créateur
        transaction.update(
          _firestore.collection('creator_profiles').doc(creatorId),
          {
            'totalViews': FieldValue.increment(1),
          },
        );

        return true;
      });
    } catch (e) {
      print('Erreur lors de l\'enregistrement de la vue: $e');
      return false;
    }
  }

  // Partager un contenu
  Future<bool> shareContent({
    required String contentId,
    required String creatorId,
    required String userId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final share = CreatorContentShare(
        id: _firestore.collection('creator_content_shares').doc().id,
        contentId: contentId,
        creatorId: creatorId,
        userId: userId,
        sharedAt: now,
      );

      await _firestore
          .collection('creator_content_shares')
          .doc(share.id)
          .set(share.toJson());

      // Incrémenter le compteur de partages
      await _firestore
          .collection('creator_contents')
          .doc(contentId)
          .update({
        'sharesCount': FieldValue.increment(1),
        'interactionsCount': FieldValue.increment(1),
      });

      await _firestore
          .collection('creator_profiles')
          .doc(creatorId)
          .update({
        'totalShares': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Erreur lors du partage: $e');
      return false;
    }
  }

  // Acheter un contenu payant
  Future<bool> purchasePaidContent({
    required String contentId,
    required String creatorId,
    required String buyerUserId,
    required int priceCoins,
  }) async {
    try {
      // Vérifier si le contenu a déjà été acheté
      final existingPurchase = await _firestore
          .collection('creator_content_purchases')
          .where('contentId', isEqualTo: contentId)
          .where('buyerUserId', isEqualTo: buyerUserId)
          .where('status', isEqualTo: 'paid')
          .limit(1)
          .get();

      if (existingPurchase.docs.isNotEmpty) {
        return true; // Déjà acheté
      }

      // Dépenser les pièces
      final spendSuccess = await _coinService.spendCoins(
        userId: buyerUserId,
        amount: priceCoins,
        type: CoinTransactionType.spend_paid_content,
        referenceId: contentId,
        description: 'Achat de contenu payant',
      );

      if (!spendSuccess) {
        throw Exception('Solde de pièces insuffisant');
      }

      return await _firestore.runTransaction((transaction) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final purchase = CreatorContentPurchase(
          id: _firestore.collection('creator_content_purchases').doc().id,
          contentId: contentId,
          creatorId: creatorId,
          buyerUserId: buyerUserId,
          priceCoins: priceCoins,
          purchasedAt: now,
          status: TransactionStatus.paid,
          createdAt: now,
          updatedAt: now,
        );

        transaction.set(
          _firestore.collection('creator_content_purchases').doc(purchase.id),
          purchase.toJson(),
        );

        // Créditer le créateur
        await _coinService.creditCreator(
          creatorId: creatorId,
          amount: priceCoins,
          type: CoinTransactionType.earn_paid_content,
          referenceId: contentId,
          description: 'Vente de contenu payant',
        );

        return true;
      });
    } catch (e) {
      print('Erreur lors de l\'achat: $e');
      return false;
    }
  }

  // Méthodes utilitaires
  Future<void> _updateReactionCounters(
      String contentId,
      ReactionType reactionType,
      int increment,
      ) async {
    String fieldToUpdate;
    switch (reactionType) {
      case ReactionType.like:
        fieldToUpdate = 'likesCount';
        break;
      case ReactionType.love:
        fieldToUpdate = 'lovesCount';
        break;
      case ReactionType.unlike:
        fieldToUpdate = 'unlikesCount';
        break;
    }

    await _firestore
        .collection('creator_contents')
        .doc(contentId)
        .update({
      fieldToUpdate: FieldValue.increment(increment),
      'interactionsCount': FieldValue.increment(increment.abs()),
    });
  }

  // Stream des contenus d'un créateur
  Stream<List<CreatorContent>> getCreatorContents(String creatorId) {
    return _firestore
        .collection('creator_contents')
        .where('creatorId', isEqualTo: creatorId)
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => CreatorContent.fromJson(doc.data()))
        .toList());
  }

  // Vérifier si un utilisateur est abonné à un créateur
  Future<bool> isSubscribedToCreator(String userId, String creatorId) async {
    try {
      final snapshot = await _firestore
          .collection('creator_subscriptions')
          .where('userId', isEqualTo: userId)
          .where('creatorId', isEqualTo: creatorId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}