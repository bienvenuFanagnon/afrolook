import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import '../../models/model_data.dart';

class PostViewService {
  static final _firestore = FirebaseFirestore.instance;

  static String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Convertit `created_at` en DateTime, qu'il soit en microsecondes,
  /// millisecondes ou Timestamp Firestore.
  /// Les timestamps ms de 2020-2030 ont 13 chiffres ; µs en ont 16.
  static DateTime? _parseCreatedAt(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      return value > 9999999999999
          ? DateTime.fromMicrosecondsSinceEpoch(value)
          : DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  /// Appelé après chaque vue unique confirmée sur un post.
  /// N'incrémente le compteur de l'auteur QUE si :
  ///   - le post est de type PostType.POST (pas PUB, CHALLENGE, SERVICE, etc.)
  ///   - l'auteur est connu et différent du viewer (pas ses propres vues)
  static Future<void> recordAuthorView(Post post, String viewerUserId) async {
    if (post.type != PostType.POST.name) return;
    if (post.isAdvertisement == true) return;
    final authorId = post.user_id;
    if (authorId == null || authorId.isEmpty) return;
    if (authorId == viewerUserId) return;
    final postId = post.id;
    if (postId == null || postId.isEmpty) return;

    final month = _currentMonth();
    try {
      await _firestore.collection('Users').doc(authorId).update({
        'totalPostUniqueViews': FieldValue.increment(1),
        'postViewsMonthly.$month': FieldValue.increment(1),
        'postViewsMonthlyPostIds.$month': FieldValue.arrayUnion([postId]),
        'postViewsPerPost.$postId': FieldValue.increment(1),
      });
      // Met à jour le compteur du post pour l'affichage dans les gains
      _firestore.collection('Posts').doc(postId).update({
        'uniqueViewsCount': FieldValue.increment(1),
      }).catchError((e) => printVm('PostViewService post update error: $e'));
    } catch (e) {
      printVm('PostViewService.recordAuthorView error: $e');
    }
  }

  /// Migration one-time : agrège les vues des posts des 3 derniers mois.
  /// Idempotent grâce au flag postViewsMigrationDone.
  static Future<void> migrateUserPostViews(String userId) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      if (!userDoc.exists) return;
      final data = userDoc.data()!;
      if (data['postViewsMigrationDone'] == true) return;

      final postIds = <String, List<String>>{};
      final perPost = <String, int>{};
      final monthly = await _aggregateMonthlyViews(userId, postIds, perPost);
      final totalViews = monthly.values.fold(0, (a, b) => a + b);

      final Map<String, dynamic> monthlyUpdate = {};
      monthly.forEach((k, v) => monthlyUpdate['postViewsMonthly.$k'] = v);
      postIds.forEach((k, v) => monthlyUpdate['postViewsMonthlyPostIds.$k'] = v);
      perPost.forEach((k, v) => monthlyUpdate['postViewsPerPost.$k'] = v);

      await _firestore.collection('Users').doc(userId).update({
        'totalPostUniqueViews': FieldValue.increment(totalViews),
        'postViewsMigrationDone': true,
        ...monthlyUpdate,
      });

      printVm('✅ Migration vues posts: $totalViews vues (3 derniers mois)');
    } catch (e) {
      printVm('PostViewService.migrateUserPostViews error: $e');
    }
  }

  /// Corrige uniquement la map mensuelle si elle contient des dates corrompues
  /// (timestamps µs traités comme ms lors d'une ancienne migration).
  /// Ne touche pas postViewsAvailable ni totalPostUniqueViews.
  static Future<void> fixMonthlyData(String userId) async {
    try {
      final postIds = <String, List<String>>{};
      final monthly = await _aggregateMonthlyViews(userId, postIds);

      final Map<String, dynamic> update = {'postViewsMonthly': monthly};
      postIds.forEach((k, v) => update['postViewsMonthlyPostIds.$k'] = v);

      await _firestore.collection('Users').doc(userId).update(update);

      printVm('✅ Correction map mensuelle: ${monthly.length} mois recalculés');
    } catch (e) {
      printVm('PostViewService.fixMonthlyData error: $e');
    }
  }

  /// Requête commune : posts de l'utilisateur des 3 derniers mois,
  /// agrégés par mois avec détection automatique ms/µs.
  /// Si [postIdsCollector] est fourni, il est également peuplé (postId par mois).
  /// Si [perPostCollector] est fourni, il reçoit les vues par postId.
  static Future<Map<String, int>> _aggregateMonthlyViews(String userId,
      [Map<String, List<String>>? postIdsCollector,
      Map<String, int>? perPostCollector]) async {
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    final now = DateTime.now();

    // Pas de filtre date Firestore : on filtre côté client car les posts
    // peuvent stocker created_at en ms OU en µs (valeurs incomparables).
    final postsSnap = await _firestore
        .collection('Posts')
        .where('user_id', isEqualTo: userId)
        .where('type', isEqualTo: PostType.POST.name)
        .get();

    final Map<String, int> monthly = {};

    for (final doc in postsSnap.docs) {
      final postData = doc.data();

      if (postData['isAdvertisement'] == true) continue;

      final views = (postData['uniqueViewsCount'] as num?)?.toInt()
          ?? (postData['vues'] as num?)?.toInt()
          ?? 0;
      if (views == 0) continue;

      final postDate = _parseCreatedAt(postData['created_at']);
      if (postDate == null) continue;
      if (postDate.isBefore(threeMonthsAgo)) continue; // hors fenêtre
      if (postDate.isAfter(now)) continue;              // date future corrompue

      final key = '${postDate.year}-${postDate.month.toString().padLeft(2, '0')}';
      monthly[key] = (monthly[key] ?? 0) + views;

      if (postIdsCollector != null) {
        (postIdsCollector[key] ??= []).add(doc.id);
      }
      if (perPostCollector != null) {
        perPostCollector[doc.id] = views;
      }
    }

    return monthly;
  }
}
