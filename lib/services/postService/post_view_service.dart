import 'package:cloud_firestore/cloud_firestore.dart';
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
        'postViewsAvailable': FieldValue.increment(2.0),
        'postViewsMonthly.$month': FieldValue.increment(1),
        'postViewsMonthlyPostIds.$month': FieldValue.arrayUnion([postId]),
      });
    } catch (e) {
      print('PostViewService.recordAuthorView error: $e');
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
      final monthly = await _aggregateMonthlyViews(userId, postIds);
      final totalViews = monthly.values.fold(0, (a, b) => a + b);

      final Map<String, dynamic> monthlyUpdate = {};
      monthly.forEach((k, v) => monthlyUpdate['postViewsMonthly.$k'] = v);
      postIds.forEach((k, v) => monthlyUpdate['postViewsMonthlyPostIds.$k'] = v);

      await _firestore.collection('Users').doc(userId).update({
        'totalPostUniqueViews': FieldValue.increment(totalViews),
        'postViewsAvailable': FieldValue.increment(totalViews * 2.0),
        'postViewsMigrationDone': true,
        ...monthlyUpdate,
      });

      print('✅ Migration vues posts: $totalViews vues (3 derniers mois)');
    } catch (e) {
      print('PostViewService.migrateUserPostViews error: $e');
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

      print('✅ Correction map mensuelle: ${monthly.length} mois recalculés');
    } catch (e) {
      print('PostViewService.fixMonthlyData error: $e');
    }
  }

  /// Requête commune : posts de l'utilisateur des 3 derniers mois,
  /// agrégés par mois avec détection automatique ms/µs.
  /// Si [postIdsCollector] est fourni, il est également peuplé (postId par mois).
  static Future<Map<String, int>> _aggregateMonthlyViews(String userId,
      [Map<String, List<String>>? postIdsCollector]) async {
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
    }

    return monthly;
  }
}
