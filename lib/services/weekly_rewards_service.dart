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
  List<WeeklyPostRanking>? _cachedPosts;
  List<WeeklyCommentatorRanking>? _cachedCommentators;
  String? _cachedWeekId;

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
    final weekNo = ((thursday.difference(yearStart).inDays) / 7).ceil();
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

    if (_cachedWeekId == wid && _cachedPosts != null) return _cachedPosts!;

    final doc = await _db.collection('WeeklyTopPosts').doc(wid).get();
    if (!doc.exists) return [];

    final rawList = (doc.data()?['rankings'] as List<dynamic>?) ?? [];
    final rankings = rawList
        .map((e) => WeeklyPostRanking.fromMap(e as Map<String, dynamic>))
        .toList();

    // Enrichissement : récupération des posts et auteurs en parallèle
    await _enrichPostRankings(rankings);

    _cachedWeekId = wid;
    _cachedPosts = rankings;
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

  /// Retourne le top 5 commentateurs de la semaine.
  Future<List<WeeklyCommentatorRanking>> getWeeklyTopCommentators({String? weekId}) async {
    final wid = weekId ?? getCurrentWeekId();

    if (_cachedWeekId == wid && _cachedCommentators != null) return _cachedCommentators!;

    final doc = await _db.collection('WeeklyTopCommentators').doc(wid).get();
    if (!doc.exists) return [];

    final rawList = (doc.data()?['rankings'] as List<dynamic>?) ?? [];
    final rankings = rawList
        .map((e) => WeeklyCommentatorRanking.fromMap(e as Map<String, dynamic>))
        .toList();

    await _enrichCommentatorRankings(rankings);

    _cachedWeekId = wid;
    _cachedCommentators = rankings;
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

  // ── Invalidation cache ──────────────────────────────────────────────────────

  void clearCache() {
    _cachedPosts = null;
    _cachedCommentators = null;
    _cachedWeekId = null;
  }
}
