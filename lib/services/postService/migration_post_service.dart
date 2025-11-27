import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/models/model_data.dart';
import 'feed_scoring_service.dart';

class MigrationPostService {
  static Future<void> migrateExistingPosts() async {
    print('🚀 Début de la migration des posts existants...');

    // ✅ SUPPRIMÉ: plus besoin de vérifier le statut
    final snapshot = await FirebaseFirestore.instance
        .collection('Posts')
        .get();

    int processed = 0;
    var batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      try {
        final postData = doc.data();
        final post = Post.fromJson(postData);

        // Calculer le score initial
        final initialScore = FeedScoringService.calculateFeedScore(post, 0);

        // Préparer la mise à jour
        batch.update(doc.reference, {
          'feedScore': initialScore,
          'lastScoreUpdate': DateTime.now().millisecondsSinceEpoch,
          'recentEngagement': (post.likes ?? 0) + (post.comments ?? 0) + (post.partage ?? 0),
          'isBoosted': false,
          'uniqueViewsCount': post.vues ?? 0,
        });

        processed++;

        // Commit par lots de 100 pour éviter les timeouts
        if (processed % 100 == 0) {
          await batch.commit();
          print('✅ ${processed}/${snapshot.docs.length} posts migrés');
          // Réinitialiser le batch
          batch = FirebaseFirestore.instance.batch();
        }
      } catch (e) {
        print('❌ Erreur sur le post ${doc.id}: $e');
      }
    }

    // Commit final
    if (processed % 100 != 0) {
      await batch.commit();
    }

    print('🎉 Migration terminée: $processed posts migrés');
  }

  static Future<void> migrateUsersLastVisit() async {
    print('🚀 Migration des timestamps utilisateur...');

    final snapshot = await FirebaseFirestore.instance
        .collection('Users')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    final defaultTime = DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'lastFeedVisitTime': defaultTime,
      });
    }

    await batch.commit();
    print('✅ ${snapshot.docs.length} utilisateurs migrés');
  }
}