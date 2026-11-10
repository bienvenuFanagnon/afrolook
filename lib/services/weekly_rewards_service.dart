import 'package:afrotok/services/api/canaux_api.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
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
      postId: (m['post_id'] ?? m['postId']) as String? ?? '',
      authorId: (m['author_id'] ?? m['authorId']) as String? ?? '',
      score: (m['score'] as num?)?.toInt() ?? 0,
      uniqueViews: ((m['unique_views'] ?? m['uniqueViews']) as num?)?.toInt() ?? 0,
      uniqueComments: ((m['unique_comments'] ?? m['uniqueComments']) as num?)?.toInt() ?? 0,
      uniqueLikes: ((m['unique_likes'] ?? m['uniqueLikes']) as num?)?.toInt() ?? 0,
      rewardedCoins: ((m['rewarded_coins'] ?? m['rewardedCoins']) as num?)?.toInt() ?? 0,
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
  /// Commentaires reçus dans la semaine (tous), et total des interactions (j'aime + commentaires + partages) : mesurés par le serveur.
  final int comments;
  final int interactions;

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
    this.comments = 0,
    this.interactions = 0,
  });

  factory WeeklyCreatorRanking.fromMap(Map<String, dynamic> m) {
    return WeeklyCreatorRanking(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      entityId: (m['entity_id'] ?? m['entityId']) as String? ?? '',
      isCanal: (m['is_channel'] ?? m['isCanal']) as bool? ?? false,
      score: (m['score'] as num?)?.toDouble() ?? 0,
      postCount: ((m['post_count'] ?? m['postCount']) as num?)?.toInt() ?? 0,
      uniqueLovers: ((m['unique_lovers'] ?? m['uniqueLovers']) as num?)?.toInt() ?? 0,
      uniqueCommenters: ((m['unique_commenters'] ?? m['uniqueCommenters']) as num?)?.toInt() ?? 0,
      totalViews: ((m['total_views'] ?? m['totalViews']) as num?)?.toInt() ?? 0,
      comments: ((m['comments'] ?? m['unique_commenters']) as num?)?.toInt() ?? 0,
      interactions: (m['interactions'] as num?)?.toInt() ?? 0,
    );
  }

  /// Total des interactions : celui du serveur, sinon la somme des compteurs reçus (anciens classements enregistrés).
  int get totalInteractions => interactions > 0 ? interactions : uniqueLovers + comments;

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
      userId: (m['user_id'] ?? m['userId']) as String? ?? '',
      commentCount: ((m['comment_count'] ?? m['commentCount']) as num?)?.toInt() ?? 0,
      rewardedCoins: ((m['rewarded_coins'] ?? m['rewardedCoins']) as num?)?.toInt() ?? 0,
      paid: m['paid'] as bool? ?? false,
    );
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class WeeklyRewardsService {
  static final WeeklyRewardsService _instance = WeeklyRewardsService._();
  factory WeeklyRewardsService() => _instance;
  WeeklyRewardsService._();

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

  // ── Accès à l'API : GET /weekly/{kind}?week= ────────────────────────────────

  Future<Map<String, dynamic>> _fetch(String kind, String weekId) async => RegieApi.getMap('/weekly/$kind', query: {'week': weekId});

  List<Map<String, dynamic>> _rankings(Map<String, dynamic> d) =>
      ((d['rankings'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// Vérifie si la semaine a déjà été calculée (et donc payée) pour ce type (`posts`, `commentators`, `creators`).
  Future<bool> isWeekProcessed(String weekId, String type) async {
    final d = await _fetch(type == 'commentators' || type == 'creators' ? type : 'posts', weekId);
    return d['computed_at'] != null;
  }

  // ── Top Posts ───────────────────────────────────────────────────────────────

  /// Retourne le top 20 posts de la semaine (avec enrichissement Post + auteur).
  Future<List<WeeklyPostRanking>> getWeeklyTopPosts({String? weekId}) async {
    final wid = weekId ?? getCurrentWeekId();
    final hit = _postsCache[wid];
    if (hit != null) return hit;
    final rankings = _rankings(await _fetch('posts', wid)).map(WeeklyPostRanking.fromMap).toList();
    await _enrichPostRankings(rankings);
    _postsCache[wid] = rankings;
    return rankings;
  }

  Future<UserData?> _user(String id) async {
    try {
      return userFromApi(await UsersApi.publicProfile(id));
    } catch (_) {
      return null;
    }
  }

  Future<void> _enrichPostRankings(List<WeeklyPostRanking> rankings) async {
    if (rankings.isEmpty) return;
    final postIds = rankings.map((r) => r.postId).where((id) => id.isNotEmpty).toList();
    final authorIds = rankings.map((r) => r.authorId).where((id) => id.isNotEmpty).toSet().toList();
    final posts = await PostsApi.getMany(postIds);
    final postsById = {for (final p in posts) if (p.id != null) p.id!: p};
    final users = await Future.wait(authorIds.map(_user));
    final usersById = {for (var i = 0; i < authorIds.length; i++) if (users[i] != null) authorIds[i]: users[i]!};
    for (final r in rankings) {
      r.post = postsById[r.postId];
      r.author = usersById[r.authorId];
    }
  }

  // ── Top Commentateurs ───────────────────────────────────────────────────────

  /// Retourne la semaine la plus récente (parmi les huit dernières) qui a un classement de commentateurs, ou null.
  Future<String?> getLatestCommentatorsWeekId() async {
    final ids = await getAvailableWeekIds('commentators');
    return ids.isEmpty ? null : ids.first;
  }

  /// Retourne le classement complet des commentateurs pour la semaine donnée.
  Future<List<WeeklyCommentatorRanking>> getWeeklyTopCommentators({String? weekId}) async {
    final wid = weekId ?? getCurrentWeekId();
    final hit = _commentatorsCache[wid];
    if (hit != null) return hit;
    final rankings = _rankings(await _fetch('commentators', wid)).map(WeeklyCommentatorRanking.fromMap).toList();
    await Future.wait(rankings.map((r) async => r.user = await _user(r.userId)));
    _commentatorsCache[wid] = rankings;
    return rankings;
  }

  // ── Semaines disponibles ────────────────────────────────────────────────────

  /// Semaines ayant un classement pour [collection] (`posts`, `creators`, `commentators`, ou les anciens noms WeeklyTopPosts…),
  /// de la plus récente à la plus ancienne, parmi les huit dernières semaines.
  Future<List<String>> getAvailableWeekIds(String collection) async {
    final kind = collection.toLowerCase().contains('creator') ? 'creators' : (collection.toLowerCase().contains('commentator') ? 'commentators' : 'posts');
    final now = DateTime.now().toUtc();
    final ids = <String>[for (var i = 0; i < 8; i++) _weekIdForDate(now.subtract(Duration(days: 7 * i)))];
    final ok = await Future.wait(ids.map((id) async {
      try {
        return _rankings(await _fetch(kind, id)).isNotEmpty;
      } catch (_) {
        return false;
      }
    }));
    return [for (var i = 0; i < ids.length; i++) if (ok[i]) ids[i]];
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
    final rankings = _rankings(await _fetch('creators', weekId)).map(WeeklyCreatorRanking.fromMap).toList();
    await Future.wait(rankings.map((r) async {
      if (r.entityId.isEmpty) return;
      try {
        if (r.isCanal) {
          r.canal = await CanauxApi.get(r.entityId);
        } else {
          r.user = await _user(r.entityId);
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
