// lib/services/challenge_month_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';

class ChallengeMonthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String appDataId = 'XgkSxKc10vWsJJ2uBraT'; // ID du document AppData

  // Récupérer la date de début des challenges (en microsecondes)
  Future<DateTime> getChallengeStartDate() async {
    try {
      final doc = await _firestore.collection('AppData').doc(appDataId).get();
      if (doc.exists && doc.data()!.containsKey('challengeStartDate')) {
        final ts = doc.data()!['challengeStartDate'] as int?;
        if (ts != null) return DateTime.fromMicrosecondsSinceEpoch(ts);
      }
    } catch (e) {
      print('Erreur récupération date début challenge: $e');
    }
    // Date par défaut: 1 avril 2026 (microsecondes)
    return DateTime(2026, 4, 1);
  }

  // Modifier la date de début (admin / simulation)
  Future<void> setChallengeStartDate(DateTime date) async {
    await _firestore.collection('AppData').doc(appDataId).set({
      'challengeStartDate': date.microsecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  // Obtenir le top N des posts pour un mois donné (basé sur totalInteractions)
// lib/services/challenge_month_service.dart (extrait modifié)
// Remplacer la méthode getTopPostsForMonth par celle-ci

  Future<List<Post>> getTopPostsForMonth(DateTime month, {int limit = 10}) async {
    final startDate = await getChallengeStartDate();
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);

    if (monthStart.isBefore(startDate) && !_isSameMonth(monthStart, startDate)) {
      return [];
    }

    final startTs = monthStart.microsecondsSinceEpoch;
    final endTs = monthEnd.microsecondsSinceEpoch;

    // Récupérer tous les posts éligibles du mois (pas de limite ici pour pouvoir trier)
    final query = await _firestore
        .collection('Posts')
        .where('dataType', whereIn: ['TEXT', 'VIDEO', 'IMAGE', 'AUDIO'])
        .where('isAdvertisement', isEqualTo: false)
        .where('created_at', isGreaterThanOrEqualTo: startTs)
        .where('created_at', isLessThan: endTs)
        .get();

    // Calculer le score pour chaque post
    final List<Post> posts = [];
    for (var doc in query.docs) {
      final post = Post.fromJson(doc.data());
      final score = (post.totalInteractions ?? 0) +
          (post.loves ?? 0) +
          (post.favoritesCount ?? 0) +
          (post.uniqueViewsCount ?? 0);
      posts.add(post..feedScore = score.toDouble()); // on stocke temporairement le score dans feedScore (ou autre)
    }

    // Trier par score décroissant, puis par created_at décroissant
    posts.sort((a, b) {
      final scoreA = (a.totalInteractions ?? 0) + (a.loves ?? 0) + (a.favoritesCount ?? 0) + (a.uniqueViewsCount ?? 0);
      final scoreB = (b.totalInteractions ?? 0) + (b.loves ?? 0) + (b.favoritesCount ?? 0) + (b.uniqueViewsCount ?? 0);
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      return (b.createdAt ?? 0).compareTo(a.createdAt ?? 0);
    });

    // Prendre les 'limit' premiers
    return posts.take(limit).toList();
  }
  // Récupérer la validation pour un mois donné
  Future<ChallengeValidation?> getValidationForMonth(DateTime month) async {
    final id = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final doc = await _firestore.collection('ChallengeValidations').doc(id).get();
    if (doc.exists) {
      return ChallengeValidation.fromJson(doc.data()!);
    }
    return null;
  }

  // Valider le gagnant (admin)
  Future<void> validateWinner({
    required DateTime month,
    required String winnerPostId,
    required String winnerUserId,
    required double prizeAmount,
    required String adminId,
  }) async {
    final id = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final now = DateTime.now().microsecondsSinceEpoch;

    // Récupérer le top 10 pour stocker les IDs (optionnel)
    final topPosts = await getTopPostsForMonth(month);
    final topPostsIds = topPosts.map((p) => p.id!).toList();

    final validation = ChallengeValidation(
      id: id,
      year: month.year,
      month: month.month,
      winnerPostId: winnerPostId,
      winnerUserId: winnerUserId,
      prizeAmount: prizeAmount,
      status: 'validated',
      validationDate: now,
      adminId: adminId,
      topPostsIds: topPostsIds,
    );

    // Sauvegarder la validation
    await _firestore.collection('ChallengeValidations').doc(id).set(validation.toJson());
  }

  // Annuler le gagnant (admin)
  Future<void> cancelWinner(DateTime month, String reason, String adminId) async {
    final id = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final doc = await _firestore.collection('ChallengeValidations').doc(id).get();
    if (!doc.exists) throw Exception('Aucune validation trouvée pour ce mois');
    final validation = ChallengeValidation.fromJson(doc.data()!);
    if (validation.status != 'validated') throw Exception('Ce mois n\'est pas validé');

    // Mettre à jour la validation
    await _firestore.collection('ChallengeValidations').doc(id).update({
      'status': 'cancelled',
      'cancellationReason': reason,
      'adminId': adminId,
    });
  }

  // Encaissement par l'utilisateur gagnant
  Future<void> payoutWinner({
    required Post winnerPost,
    required UserData currentUser,
    required UserAuthProvider authProvider,
    required DateTime month,
  }) async {
    // Vérifier que l'utilisateur est bien le propriétaire
    if (winnerPost.user_id != currentUser.id) {
      throw Exception('Vous n\'êtes pas le propriétaire de ce post');
    }

    // Récupérer la validation du mois
    final validation = await getValidationForMonth(month);
    if (validation == null || validation.status != 'validated') {
      throw Exception('Aucune validation pour ce mois');
    }
    if (validation.winnerPostId != winnerPost.id) {
      throw Exception('Ce post n\'est pas le gagnant du mois');
    }
    if (validation.payoutCompleted) {
      throw Exception('Ce prix a déjà été encaissé');
    }

    final prize = validation.prizeAmount;

    // Exécuter la transaction Firestore
    await _firestore.runTransaction((transaction) async {
      // Vérification supplémentaire que le paiement n'a pas été fait entre-temps
      final valSnapshot = await transaction.get(_firestore.collection('ChallengeValidations').doc(validation.id));
      if (valSnapshot.data()!['payoutCompleted'] == true) {
        throw Exception('Déjà encaissé');
      }

      // 1. Créer la transaction de gain
      final transactionId = _firestore.collection('TransactionSoldes').doc().id;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final transactionData = {
        'id': transactionId,
        'user_id': currentUser.id,
        'type': 'GAIN',
        'statut': 'VALIDER',
        'description': 'Gain challenge du mois ${validation.id}',
        'montant': prize,
        'methode_paiement': 'challenge_winner',
        'post_id': winnerPost.id,
        'createdAt': nowMs,
        'updatedAt': nowMs,
      };
      transaction.set(_firestore.collection('TransactionSoldes').doc(transactionId), transactionData);

      // 2. Mettre à jour le solde principal de l'utilisateur
      final newBalance = (currentUser.votre_solde_principal ?? 0) + prize;
      transaction.update(_firestore.collection('Users').doc(currentUser.id), {
        'votre_solde_principal': newBalance,
      });

      // 3. Marquer la validation comme encaissée
      transaction.update(_firestore.collection('ChallengeValidations').doc(validation.id), {
        'payoutCompleted': true,
        'payoutDate': DateTime.now().millisecondsSinceEpoch,
        'payoutTransactionId': transactionId,
      });
    });

    // Mettre à jour l'état local du provider
    authProvider.updateUserBalance((currentUser.votre_solde_principal ?? 0) + prize);
  }

  // Obtenir tous les mois avec gagnant validé pour l'historique
  Future<List<ChallengeValidation>> getHistoryValidations() async {
    final snapshot = await _firestore
        .collection('ChallengeValidations')
        .where('status', isEqualTo: 'validated')
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .get();
    return snapshot.docs.map((doc) => ChallengeValidation.fromJson(doc.data())).toList();
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}