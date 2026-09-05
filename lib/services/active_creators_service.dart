import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/model_data.dart';

class ActiveCreator {
  final UserData user;
  final int unseenCount;
  /// Timestamp du post le plus récent (microsecondes). 0 si inconnu.
  final int lastActivityUs;

  const ActiveCreator({
    required this.user,
    required this.unseenCount,
    this.lastActivityUs = 0,
  });
}

/// Canal suivi avec timestamp d'activité pour le tri mixte.
class ActiveCanal {
  final Canal canal;
  /// Timestamp du post le plus récent (microsecondes). 0 si inconnu.
  final int lastActivityUs;

  const ActiveCanal({required this.canal, this.lastActivityUs = 0});
}

/// Service "Vos Créateurs actifs".
///
/// Architecture scalable (10 000 following+) :
///
///  Priorité :
///  1. CF hot-set (newPostsByCreator) → query posts uniquement pour ces créateurs
///     → O(k) avec k = nb créateurs actifs récents (typiquement < 50)
///  2. Requête globale Posts filtrée côté client pour les followings
///     → 1 seule requête Firestore, indépendant du nb de followings
///  3. Découverte plateforme (creators récents de la plateforme)
///
///  created_at = microsecondes entières (int), PAS Timestamp.
class ActiveCreatorsService {
  final FirebaseFirestore _db;

  ActiveCreatorsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Résolution principale ─────────────────────────────────────────────────────
  //
  // Stratégie pour la section home (round cards) :
  //
  //   Phase A — CF hot-set : créateurs avec newPostsByCreator > 0
  //             → query directe pour récupérer lastActivityUs + unseen réels
  //
  //   Phase B — Direct chunk query sur les followings restants
  //             → whereIn par batch de 30, parallèle, jusqu'à 150 IDs supplémentaires
  //             → couvre les followings actifs non détectés par le CF
  //
  //   Phase C — Fallback plateforme si aucun following actif
  //
  //  Pourquoi PAS la requête globale ?
  //  → Une requête globalelimitée à 500 posts peut rater des créateurs suivis si la
  //    plateforme publie plus de 500 posts par jour. La page liste n'a jamais ce
  //    problème car elle fait des whereIn directs sur les IDs suivis.

  Future<List<ActiveCreator>> resolve(
    UserData me, {
    int limit = 10,
    List<String>? followingIds,
    Map<String, int>? freshCounts,
  }) async {
    // freshCounts prioritaire sur me.newPostsByCreator (evite données stale du cache local)
    final cfCounts = Map<String, int>.from(freshCounts ?? me.newPostsByCreator ?? {});

    // ── Créateurs avec posts non vus (hot-set CF) ────────────────────────────
    final hotIds = cfCounts.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    final List<ActiveCreator> result = [];

    if (hotIds.isNotEmpty) {
      final users = await _fetchUsers(hotIds);
      final creators = users
          .where((u) => u.id != null)
          .map((u) => ActiveCreator(
                user: u,
                unseenCount: cfCounts[u.id!] ?? 0,
                lastActivityUs: 0,
              ))
          .toList()
        ..sort((a, b) => b.unseenCount.compareTo(a.unseenCount));
      result.addAll(creators);
    }

    // ── Compléter avec des followings récents (0 unseen) si besoin ──────────
    // Une seule requête Users — pas de requête Posts.
    if (result.length < limit) {
      final following = followingIds?.isNotEmpty == true
          ? followingIds!
          : (me.followingIds ?? []);
      final shown = <String>{...hotIds};
      final toFetch = following
          .where((id) => !shown.contains(id))
          .take(limit - result.length)
          .toList();
      if (toFetch.isNotEmpty) {
        final users = await _fetchUsers(toFetch);
        result.addAll(users
            .where((u) => u.id != null)
            .map((u) =>
                ActiveCreator(user: u, unseenCount: 0, lastActivityUs: 0)));
      }
    }

    if (result.isEmpty) {
      return fetchPlatformRecentCreators(me.id ?? '', limit: limit);
    }

    return result.take(limit).toList()
      ..sort((a, b) {
        if (a.unseenCount > 0 && b.unseenCount == 0) return -1;
        if (b.unseenCount > 0 && a.unseenCount == 0) return 1;
        return b.lastActivityUs.compareTo(a.lastActivityUs);
      });
  }

  /// Requête Posts par créateur (whereIn, chunked, parallèle).
  /// Mutate [latestUs] et [unseenPerCreator] in-place.
  Future<void> _queryPostsByCreators(
    List<String> ids,
    int sinceUs,
    Set<String> viewedSet,
    Map<String, int> latestUs,
    Map<String, int> unseenPerCreator, {
    int postsPerCreator = 15,
  }) async {
    final futures = <Future<void>>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      futures.add(() async {
        try {
          final snap = await _db
              .collection('Posts')
              .where('user_id', whereIn: chunk)
              .where('created_at', isGreaterThan: sinceUs)
              .orderBy('created_at', descending: true)
              .limit(chunk.length * postsPerCreator)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            final uid = data['user_id'] as String? ?? '';
            if (uid.isEmpty) continue;
            final ts = (data['created_at'] as num?)?.toInt() ?? 0;
            if (!latestUs.containsKey(uid) || ts > (latestUs[uid] ?? 0)) {
              latestUs[uid] = ts;
            }
            if (!viewedSet.contains(doc.id)) {
              unseenPerCreator[uid] = (unseenPerCreator[uid] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }());
    }
    await Future.wait(futures);
  }

  // ── fetchFollowedRecentCreators (pagination liste détaillée) ─────────────────
  //
  // Utilisé par ActiveCreatorsListPage pour la pagination "voir plus".
  // Chunks whereIn 30 en parallèle — pour de grandes listes on exclut les IDs
  // déjà affichés et on utilise un curseur beforeUs.

  Future<List<ActiveCreator>> fetchFollowedRecentCreators(
    List<String> abonnesIds, {
    int dayRange = 30,
    int limit = 10,
    int? beforeUs,
    Set<String> excludeIds = const {},
    List<String> viewedPostIds = const [],
  }) async {
    if (abonnesIds.isEmpty) return [];

    final sinceUs = DateTime.now()
        .subtract(Duration(days: dayRange))
        .microsecondsSinceEpoch;

    final Map<String, int> latestUs = {};
    final Map<String, int> unseenPerCreator = {};
    final viewedSet = Set<String>.from(viewedPostIds);

    final futures = <Future<void>>[];
    for (int i = 0; i < abonnesIds.length; i += 30) {
      final chunk = abonnesIds.sublist(
          i, (i + 30).clamp(0, abonnesIds.length));
      futures.add(() async {
        try {
          Query<Map<String, dynamic>> q = _db
              .collection('Posts')
              .where('user_id', whereIn: chunk)
              .where('created_at', isGreaterThan: sinceUs)
              .orderBy('created_at', descending: true);
          if (beforeUs != null) {
            q = q.where('created_at', isLessThan: beforeUs);
          }
          q = q.limit(limit * 3);
          final snap = await q.get();

          for (final doc in snap.docs) {
            final data = doc.data();
            final uid = data['user_id'] as String? ?? '';
            if (uid.isEmpty || excludeIds.contains(uid)) continue;
            final ts = (data['created_at'] as num?)?.toInt() ?? 0;
            if (!latestUs.containsKey(uid) || ts > latestUs[uid]!) {
              latestUs[uid] = ts;
            }
            if (!viewedSet.contains(doc.id)) {
              unseenPerCreator[uid] = (unseenPerCreator[uid] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }());
    }
    await Future.wait(futures);

    if (latestUs.isEmpty) return [];

    final sorted = latestUs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ids = sorted.take(limit).map((e) => e.key).toList();
    if (ids.isEmpty) return [];
    final users = await _fetchUsers(ids);

    return users
        .where((u) => u.id != null)
        .map((u) => ActiveCreator(
              user: u,
              unseenCount: unseenPerCreator[u.id!] ?? 0,
              lastActivityUs: latestUs[u.id!] ?? 0,
            ))
        .toList();
  }

  // ── Découverte plateforme ─────────────────────────────────────────────────────

  Future<List<ActiveCreator>> fetchPlatformRecentCreators(
    String currentUserId, {
    int dayRange = 30,
    int limit = 10,
  }) async {
    final sinceUs = DateTime.now()
        .subtract(Duration(days: dayRange))
        .microsecondsSinceEpoch;

    try {
      final snap = await _db
          .collection('Posts')
          .where('created_at', isGreaterThan: sinceUs)
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();

      final Map<String, int> latestUs = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = data['user_id'] as String? ?? '';
        if (uid.isEmpty || uid == currentUserId) continue;
        if (!latestUs.containsKey(uid)) {
          latestUs[uid] = (data['created_at'] as num?)?.toInt() ?? 0;
        }
      }

      if (latestUs.isEmpty) return [];

      final sorted = latestUs.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final ids = sorted.take(limit).map((e) => e.key).toList();
      final users = await _fetchUsers(ids);

      return users
          .where((u) => u.id != null && u.id != currentUserId)
          .map((u) => ActiveCreator(
                user: u,
                unseenCount: 0,
                lastActivityUs: latestUs[u.id!] ?? 0,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Canaux ───────────────────────────────────────────────────────────────────

  Future<List<Canal>> fetchCanaux(List<String> canalIds) async {
    final List<Canal> result = [];
    for (int i = 0; i < canalIds.length; i += 10) {
      final chunk = canalIds.sublist(i, (i + 10).clamp(0, canalIds.length));
      try {
        final snap = await _db
            .collection('Canaux')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          result.add(Canal.fromJson(data));
        }
      } catch (_) {}
    }
    return result;
  }

  Future<List<ActiveCanal>> fetchFollowedRecentCanaux(
    List<String> canalIds, {
    int dayRange = 30,
    int limit = 10,
  }) async {
    if (canalIds.isEmpty) return [];

    final sinceUs = DateTime.now()
        .subtract(Duration(days: dayRange))
        .microsecondsSinceEpoch;

    final Map<String, int> latestUs = {};

    for (int i = 0; i < canalIds.length; i += 10) {
      final chunk = canalIds.sublist(i, (i + 10).clamp(0, canalIds.length));
      try {
        final snap = await _db
            .collection('Posts')
            .where('canal_id', whereIn: chunk)
            .where('created_at', isGreaterThan: sinceUs)
            .orderBy('created_at', descending: true)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final cid = data['canal_id'] as String? ?? '';
          if (cid.isEmpty) continue;
          final ts = (data['created_at'] as num?)?.toInt() ?? 0;
          if (!latestUs.containsKey(cid) || ts > latestUs[cid]!) {
            latestUs[cid] = ts;
          }
        }
      } catch (_) {}
    }

    if (latestUs.isEmpty) return [];

    final sorted = latestUs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ids = sorted.take(limit).map((e) => e.key).toList();
    final canaux = await fetchCanaux(ids);

    return canaux
        .where((c) => c.id != null)
        .map((c) => ActiveCanal(
              canal: c,
              lastActivityUs: latestUs[c.id!] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.lastActivityUs.compareTo(a.lastActivityUs));
  }

  Future<List<ActiveCanal>> fetchFollowedCanauxDirect(
    List<String> canalIds, {
    int limit = 5,
  }) async {
    final canaux = await fetchCanaux(canalIds.take(limit).toList());
    return canaux
        .map((c) => ActiveCanal(
              canal: c,
              lastActivityUs: (c.updatedAt ?? 0) * 1000,
            ))
        .toList()
      ..sort((a, b) => b.lastActivityUs.compareTo(a.lastActivityUs));
  }

  /// Récupère les IDs des créateurs que [userId] SUIT (abonnements, pas abonnés).
  /// Source : collection Abonnements, champ compte_user_id == userId.
  Future<List<String>> fetchFollowingIds(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await _db
          .collection('Abonnements')
          .where('compte_user_id', isEqualTo: userId)
          .get();
      return snap.docs
          .map((d) => d.data()['abonne_user_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchFollowedCanalIds(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await _db
          .collection('Canaux')
          .where('usersSuiviId', arrayContains: userId)
          .get();
      return snap.docs.map((d) => d.id).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> resetCreatorCounter(
    String currentUserId,
    String creatorId,
  ) async {
    if (currentUserId.isEmpty || creatorId.isEmpty) return;
    try {
      await _db.collection('Users').doc(currentUserId).update({
        'newPostsByCreator.$creatorId': FieldValue.delete(),
      });
    } catch (_) {}
  }

  Future<void> resetCanalCounter(
    String currentUserId,
    String canalId,
  ) async {
    if (currentUserId.isEmpty || canalId.isEmpty) return;
    try {
      await _db.collection('Users').doc(currentUserId).update({
        'newPostsByCanal.$canalId': FieldValue.delete(),
      });
    } catch (_) {}
  }

  Future<List<UserData>> fetchUsersById(List<String> ids) =>
      _fetchUsers(ids);

  // ── Recalibration des compteurs non vus ──────────────────────────────────────
  //
  // Pour chaque créateur de [creatorIds] ayant un compteur > 0, interroge
  // Firestore pour compter les posts réels non vus (non présents dans
  // [viewedPostIds]) créés après [userCreatedAtMs].
  // Retourne une Map creatorId → unseenCount (seulement ceux > 0).

  Future<Map<String, int>> recalibrateUnseenCounts({
    required List<String> creatorIds,
    required Set<String> viewedPostIds,
    required int userCreatedAtMs,
  }) async {
    if (creatorIds.isEmpty) return {};

    final sinceUs = userCreatedAtMs > 0 ? userCreatedAtMs * 1000 : 0;
    final Map<String, int> unseenPerCreator = {};
    final futures = <Future<void>>[];

    for (int i = 0; i < creatorIds.length; i += 10) {
      final chunk = creatorIds.sublist(i, (i + 10).clamp(0, creatorIds.length));
      futures.add(() async {
        try {
          var q = _db
              .collection('Posts')
              .where('user_id', whereIn: chunk)
              .orderBy('created_at', descending: true)
              .limit(500);
          if (sinceUs > 0) {
            q = q.where('created_at', isGreaterThanOrEqualTo: sinceUs);
          }
          final snap = await q.get();
          for (final doc in snap.docs) {
            final uid = doc.data()['user_id'] as String? ?? '';
            if (uid.isEmpty) continue;
            if (!viewedPostIds.contains(doc.id)) {
              unseenPerCreator[uid] = (unseenPerCreator[uid] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }());
    }
    await Future.wait(futures);
    return unseenPerCreator;
  }

  // ── Marquer tous les posts d'un créateur comme vus ───────────────────────────
  //
  // Identique au "tout marquer comme lu" des notifications.
  // 1. Récupère tous les post IDs du créateur depuis [userCreatedAtMs].
  // 2. Ajoute les nouveaux IDs dans viewedPostIds (arrayUnion, chunks de 400).
  // 3. Remet newPostsByCreator.{creatorId} à 0.
  // Retourne les IDs effectivement ajoutés (non déjà vus).

  Future<List<String>> markAllPostsSeenForCreator({
    required String userId,
    required String creatorId,
    required int userCreatedAtMs,
    required Set<String> alreadyViewedIds,
  }) async {
    if (userId.isEmpty || creatorId.isEmpty) return [];

    final sinceUs = userCreatedAtMs > 0 ? userCreatedAtMs * 1000 : 0;
    final List<String> newIds = [];

    try {
      // Récupère tous les post IDs du créateur (pages de 500)
      DocumentSnapshot? lastDoc;
      bool hasMore = true;
      while (hasMore) {
        var q = _db
            .collection('Posts')
            .where('user_id', isEqualTo: creatorId)
            .orderBy('created_at', descending: true)
            .limit(500);
        if (sinceUs > 0) {
          q = q.where('created_at', isGreaterThanOrEqualTo: sinceUs);
        }
        if (lastDoc != null) q = q.startAfterDocument(lastDoc!);

        final snap = await q.get();
        for (final doc in snap.docs) {
          if (!alreadyViewedIds.contains(doc.id)) {
            newIds.add(doc.id);
          }
        }
        lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        hasMore = snap.docs.length == 500;
      }

      if (newIds.isEmpty) {
        // Rien de nouveau, reset quand même le compteur CF
        await _db.collection('Users').doc(userId).update({
          'newPostsByCreator.$creatorId': FieldValue.delete(),
        });
        return [];
      }

      // arrayUnion en chunks de 400 (sécurité taille doc)
      final userRef = _db.collection('Users').doc(userId);
      for (int i = 0; i < newIds.length; i += 400) {
        final chunk = newIds.sublist(i, (i + 400).clamp(0, newIds.length));
        await userRef.update({
          'viewedPostIds': FieldValue.arrayUnion(chunk),
          'newPostsByCreator.$creatorId': FieldValue.delete(),
        });
      }
    } catch (_) {}

    return newIds;
  }

  Future<List<UserData>> _fetchUsers(List<String> ids) async {
    final List<UserData> users = [];
    for (int i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      try {
        final snap = await _db
            .collection('Users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          users.add(UserData.fromJson(data));
        }
      } catch (_) {}
    }
    return users;
  }
}
