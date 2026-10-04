import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/model_data.dart';

// ─── Modèles ─────────────────────────────────────────────────────────────────

class WeeklyPostRanking {
  final int rank;
  final String postId;
  final String authorId;
  final int score;
  final int uniqueViews;
  final int uniqueComments;
  final int uniqueLikes;
  final int rewardedCoins;
  final bool paid;

  // Données enrichies (remplies côté Flutter)
  Post? post;
  UserData? author;

  WeeklyPostRanking({
    required this.rank,
    required this.postId,
    required this.authorId,
    required this.score,
    required this.uniqueViews,
    required this.uniqueComments,
    required this.uniqueLikes,
    required this.rewardedCoins,
    required this.paid,
    this.post,
    this.author,
  });

  factory WeeklyPostRanking.fromMap(Map<String, dynamic> m) {
    return WeeklyPostRanking(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      postId: m['postId'] as String? ?? '',
      authorId: m['authorId'] as String? ?? '',
      score: (m['score'] as num?)?.toInt() ?? 0,
      uniqueViews: (m['uniqueViews'] as num?)?.toInt() ?? 0,
      uniqueComments: (m['uniqueComments'] as num?)?.toInt() ?? 0,
      uniqueLikes: (m['uniqueLikes'] as num?)?.toInt() ?? 0,
      rewardedCoins: (m['rewardedCoins'] as num?)?.toInt() ?? 0,
      paid: m['paid'] as bool? ?? false,
    );
  }
}

class WeeklyCreatorRanking {
  final int rank;
  final String entityId;
  final bool isCanal;
  final double score;
  final int postCount;
  final int uniqueLovers;
  final int uniqueCommenters;
  final int totalViews;

  // Données enrichies (remplies côté Flutter)
  UserData? user;
  Canal? canal;

  WeeklyCreatorRanking({
    required this.rank,
    required this.entityId,
    required this.isCanal,
    required this.score,
    required this.postCount,
    required this.uniqueLovers,
    required this.uniqueCommenters,
    required this.totalViews,
  });

  factory WeeklyCreatorRanking.fromMap(Map<String, dynamic> m) {
    return WeeklyCreatorRanking(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      entityId: m['entityId'] as String? ?? '',
      isCanal: m['isCanal'] as bool? ?? false,
      score: (m['score'] as num?)?.toDouble() ?? 0,
      postCount: (m['postCount'] as num?)?.toInt() ?? 0,
      uniqueLovers: (m['uniqueLovers'] as num?)?.toInt() ?? 0,
      uniqueCommenters: (m['uniqueCommenters'] as num?)?.toInt() ?? 0,
      totalViews: (m['totalViews'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayName => isCanal ? (canal?.titre ?? '') : (user?.pseudo ?? '');
  String get imageUrl => isCanal ? (canal?.urlImage ?? '') : (user?.imageUrl ?? '');
}

class WeeklyCommentatorRanking {
  final int rank;
  final String userId;
  final int commentCount;
  final int rewardedCoins;
  final bool paid;

  UserData? user;

  WeeklyCommentatorRanking({
    required this.rank,
    required this.userId,
    required this.commentCount,
    required this.rewardedCoins,
    required this.paid,
    this.user,
  });

  factory WeeklyCommentatorRanking.fromMap(Map<String, dynamic> m) {
    return WeeklyCommentatorRanking(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      userId: m['userId'] as String? ?? '',
      commentCount: (m['commentCount'] as num?)?.toInt() ?? 0,
      rewardedCoins: (m['rewardedCoins'] as num?)?.toInt() ?? 0,
      paid: m['paid'] as bool? ?? false,
    );
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class WeeklyRewardsService {
  static final WeeklyRewardsService _instance = WeeklyRewardsService._();
  factory WeeklyRewardsService() => _instance;
  WeeklyRewardsService._();

  final _db = FirebaseFirestore.instance;

  // ── Cache en mémoire (durée de session) ────────────────────────────────────
  final Map<String, List<WeeklyPostRanking>> _postsCache = {};
  final Map<String, List<WeeklyCommentatorRanking>> _commentatorsCache = {};
  final Map<String, List<WeeklyCreatorRanking>> _creatorsCache = {};

  // ── ID de semaine ISO ───────────────────────────────────────────────────────

  /// Retourne l'identifiant ISO de la semaine courante, ex. "2026-W34".
  static String getCurrentWeekId() {
    return _weekIdForDate(DateTime.now().toUtc());
  }

  /// Retourne l'identifiant ISO de la semaine précédente, ex. "2026-W33".
  static String getLastWeekId() {
    return _weekIdForDate(DateTime.now().toUtc().subtract(const Duration(days: 7)));
  }

  static String _weekIdForDate(DateTime date) {
    // Calcul de la semaine ISO-8601 (lundi = 1er jour)
    final thursday = date.subtract(Duration(days: date.weekday - 4));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final weekNo = (((thursday.difference(yearStart).inDays) + 1) / 7).ceil(); // identique au serveur (ISO)
    return '${thursday.year}-W${weekNo.toString().padLeft(2, '0')}';
  }

  /// Retourne le début de la semaine courante (lundi 00:00 UTC) en millisecondes.
  static int getWeekStartMs() {
    final now = DateTime.now().toUtc();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime.utc(monday.year, monday.month, monday.day).millisecondsSinceEpoch;
  }

  // ── Vérification traitement ─────────────────────────────────────────────────

  /// Vérifie si la semaine a déjà été traitée (lock existant).
  Future<bool> isWeekProcessed(String weekId, String type) async {
    final doc = await _db
        .collection('WeeklyRewardLocks')
        .doc('${weekId}_$type')
        .get();
    return doc.exists;
  }

  // ── Top Posts ───────────────────────────────────────────────────────────────

  /// Retourne le top 20 posts de la semaine (avec enrichissement Post + auteur).
  Future<List<WeeklyPostRanking>> getWeeklyTopPosts({String? weekId}) async {
    final wid = weekId ?? getCurrentWeekId();

    final hit = _postsCache[wid];
    if (hit != null) return hit;

    final doc = await _db.collection('WeeklyTopPosts').doc(wid).get();
    if (!doc.exists) return [];

    final rawList = (doc.data()?['rankings'] as List<dynamic>?) ?? [];
    final rankings = rawList
        .map((e) => WeeklyPostRanking.fromMap(e as Map<String, dynamic>))
        .toList();

    // Enrichissement : récupération des posts et auteurs en parallèle
    await _enrichPostRankings(rankings);

    _postsCache[wid] = rankings;
    return rankings;
  }

  Future<void> _enrichPostRankings(List<WeeklyPostRanking> rankings) async {
    if (rankings.isEmpty) return;

    final postIds = rankings.map((r) => r.postId).where((id) => id.isNotEmpty).toList();
    final authorIds = rankings.map((r) => r.authorId).where((id) => id.isNotEmpty).toSet().toList();

    // Posts
    final Map<String, Post> postsById = {};
    for (int i = 0; i < postIds.length; i += 10) {
      final chunk = postIds.sublist(i, i + 10 > postIds.length ? postIds.length : i + 10);
      final snap = await _db.collection('Posts').where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in snap.docs) {
        final p = Post.fromJson(d.data());
        p.id = d.id;
        postsById[d.id] = p;
      }
    }

    // Auteurs
    final Map<String, UserData> usersById = {};
    for (int i = 0; i < authorIds.length; i += 10) {
      final chunk = authorIds.sublist(i, i + 10 > authorIds.length ? authorIds.length : i + 10);
      final snap = await _db.collection('Users').where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in snap.docs) {
        final u = UserData.fromJson(d.data());
        u.id = d.id;
        usersById[d.id] = u;
      }
    }

    for (final r in rankings) {
      r.post = postsById[r.postId];
      r.author = usersById[r.authorId];
    }
  }

  // ── Top Commentateurs ───────────────────────────────────────────────────────

  /// Retourne la semaine la plus récente qui a des données dans WeeklyTopCommentators.
  /// Retourne null si aucune donnée n'existe.
  Future<String?> getLatestCommentatorsWeekId() async {
    final snap = await _db
        .collection('WeeklyTopCommentators')
        .orderBy('computedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['weekId'] as String?;
  }

  /// Retourne le classement complet des commentateurs pour la semaine donnée.
  Future<List<WeeklyCommentatorRanking>> getWeeklyTopCommentators({String? weekId}) async {
    final wid = weekId ?? getCurrentWeekId();

    final hit = _commentatorsCache[wid];
    if (hit != null) return hit;

    final doc = await _db.collection('WeeklyTopCommentators').doc(wid).get();
    if (!doc.exists) return [];

    final rawList = (doc.data()?['rankings'] as List<dynamic>?) ?? [];
    final rankings = rawList
        .map((e) => WeeklyCommentatorRanking.fromMap(e as Map<String, dynamic>))
        .toList();

    await _enrichCommentatorRankings(rankings);

    _commentatorsCache[wid] = rankings;
    return rankings;
  }

  Future<void> _enrichCommentatorRankings(List<WeeklyCommentatorRanking> rankings) async {
    if (rankings.isEmpty) return;

    final userIds = rankings.map((r) => r.userId).where((id) => id.isNotEmpty).toList();
    for (int i = 0; i < userIds.length; i += 10) {
      final chunk = userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10);
      final snap = await _db.collection('Users').where(FieldPath.documentId, whereIn: chunk).get();
      final usersById = {for (final d in snap.docs) d.id: UserData.fromJson(d.data())..id = d.id};
      for (final r in rankings) {
        if (usersById.containsKey(r.userId)) r.user = usersById[r.userId];
      }
    }
  }

  // ── Semaines disponibles (Top Posts / Top Créateurs / Top Commentateurs) ────

  /// Semaines ayant un classement dans [collection] (WeeklyTopPosts, WeeklyTopCreators,
  /// WeeklyTopCommentators), de la plus récente à la plus ancienne ; les semaines sans classement sont ignorées.
  Future<List<String>> getAvailableWeekIds(String collection) async {
    final snap = await _db
        .collection(collection)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(60)
        .get();
    return snap.docs
        .where((d) => ((d.data()['rankings'] as List?) ?? const []).isNotEmpty)
        .map((d) => d.id)
        .toList();
  }

  /// « 2026-W39 » → « Septembre 2026 — 4e semaine du mois ».
  static String formatWeekLabel(String weekId) {
    try {
      final parts = weekId.split('-W');
      if (parts.length != 2) return weekId;
      final year = int.parse(parts[0]);
      final isoWeek = int.parse(parts[1]);
      final jan4 = DateTime.utc(year, 1, 4);
      final day1 = jan4.subtract(Duration(days: jan4.weekday - 1));
      final monday = day1.add(Duration(days: (isoWeek - 1) * 7));
      const months = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août',
        'Septembre', 'Octobre', 'Novembre', 'Décembre'];
      final thursday = monday.add(const Duration(days: 3));
      final weekOfMonth = ((thursday.day - 1) ~/ 7) + 1;
      final ordinal = weekOfMonth == 1 ? '1re' : '${weekOfMonth}e';
      return '${months[thursday.month]} ${thursday.year} — $ordinal semaine du mois';
    } catch (_) {
      return weekId;
    }
  }

  // ── Top Créateurs ───────────────────────────────────────────────────────────

  /// Classement des créateurs (utilisateurs et canaux) de la semaine donnée.
  Future<List<WeeklyCreatorRanking>> getWeeklyTopCreators({required String weekId}) async {
    final hit = _creatorsCache[weekId];
    if (hit != null) return hit;
    final doc = await _db.collection('WeeklyTopCreators').doc(weekId).get();
    if (!doc.exists) return [];
    final rawList = (doc.data()?['rankings'] as List<dynamic>?) ?? [];
    final rankings = rawList.map((e) => WeeklyCreatorRanking.fromMap(e as Map<String, dynamic>)).toList();
    await Future.wait(rankings.map((r) async {
      if (r.entityId.isEmpty) return;
      try {
        final d = await _db.collection(r.isCanal ? 'Canaux' : 'Users').doc(r.entityId).get();
        if (!d.exists) return;
        if (r.isCanal) {
          r.canal = Canal.fromJson({...d.data()!, 'id': d.id});
        } else {
          r.user = UserData.fromJson(d.data()!)..id = d.id;
        }
      } catch (_) {}
    }));
    _creatorsCache[weekId] = rankings;
    return rankings;
  }

  // ── Invalidation cache ──────────────────────────────────────────────────────

  void clearCache() {
    _postsCache.clear();
    _commentatorsCache.clear();
    _creatorsCache.clear();
  }
}
