import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

class MassNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔥 NOTIFICATION PAR LOTS AVEC FIRESTORE BATCH
  Future<void> notifySubscribersAboutNewPost({
    required String postId,
    required String authorId,
  }) async {
    try {
      printVm('🚀 Début notification pour le post $postId aux abonnés de $authorId');
      final startTime = DateTime.now();

      // Utiliser une requête paginée pour gérer un grand nombre d'abonnés
      int totalProcessed = 0;
      int batchCount = 0;

      await _processSubscribersInBatches(authorId, (subscriberIds) async {
        if (subscriberIds.isEmpty) return;

        batchCount++;
        totalProcessed += subscriberIds.length;

        await _updateSubscribersBatch(subscriberIds, postId);

        printVm('📦 Batch $batchCount traité: ${subscriberIds.length} abonnés');
      });

      final duration = DateTime.now().difference(startTime);
      printVm('✅ Notification terminée: $totalProcessed abonnés notifiés en ${duration.inSeconds}s');

    } catch (e) {
      printVm('❌ Erreur notification abonnés: $e');
      // Relancer pour les retries
      rethrow;
    }
  }

  // 🔥 TRAITEMENT PAR LOTS DE 400 (LIMITE FIRESTORE)
  Future<void> _processSubscribersInBatches(
      String authorId,
      Function(List<String>) processBatch,
      ) async {
    const int batchSize = 400; // Firebase limite à 500 par batch
    DocumentSnapshot? lastDoc;
    bool hasMore = true;

    while (hasMore) {
      Query query = _firestore
          .collection('Users')
          .where('userAbonnesIds', arrayContains: authorId)
          .limit(batchSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      final subscriberIds = snapshot.docs.map((doc) => doc.id).toList();

      if (subscriberIds.isNotEmpty) {
        await processBatch(subscriberIds);
        lastDoc = snapshot.docs.last;
      }

      hasMore = subscriberIds.length == batchSize;

      // Petit délai pour éviter de surcharger Firebase
      if (hasMore) {
        await Future.delayed(Duration(milliseconds: 100));
      }
    }
  }

  // 🔥 MISE À JOUR PAR BATCH
  Future<void> _updateSubscribersBatch(List<String> subscriberIds, String postId) async {
    final batch = _firestore.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final subscriberId in subscriberIds) {
      final userRef = _firestore.collection('Users').doc(subscriberId);

      // Mise à jour atomique - seulement les champs nécessaires
      batch.update(userRef, {
        'newPostsFromSubscriptions': FieldValue.arrayUnion([postId]),
        'lastFeedUpdate': now,
      });
    }

    await batch.commit();
  }

  // 🔥 VERSION AVEC CLOUD FUNCTIONS POUR LES TRÈS GRANDS NOMBRES
  Future<void> notifyViaCloudFunction(String postId, String authorId) async {
    // Cette méthode serait idéalement implémentée dans une Cloud Function
    // pour gérer des millions d'utilisateurs sans timeout
    printVm('⚡ Utilisation Cloud Function pour la notification de masse');

    // Implémentation avec Firebase Cloud Functions
    // await _firestore.collection('notificationTasks').add({
    //   'postId': postId,
    //   'authorId': authorId,
    //   'status': 'pending',
    //   'createdAt': FieldValue.serverTimestamp(),
    // });
  }
}