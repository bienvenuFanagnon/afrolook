import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canal_mapper.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
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

/// Service "Vos Créateurs actifs" (API).
///
/// Les nouveautés par créateur sont calculées par le serveur à la lecture (`GET /v1/feed/unread-counts` : publications des comptes suivis
/// non vues, 30 jours). Plus aucun compteur n'est écrit dans le profil : « marquer comme vu » passe par `POST /v1/feed/seen`.
class ActiveCreatorsService {
  ActiveCreatorsService();

  ApiClient get _c => ApiGateway.instance.client;

  /// Nombre de nouveautés par créateur suivi (serveur).
  Future<Map<String, int>> _unreadByCreator() async {
    try {
      final r = await _c.get('/feed/unread-counts') as Map;
      final by = Map<String, dynamic>.from(((r['data'] as Map?)?['by_creator'] as Map?) ?? const {});
      return by.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// Créateurs suivis par la personne connectée (résumés), du plus récemment suivi au plus ancien.
  Future<List<UserData>> _followedSummaries(String userId, {int max = 150}) async {
    final out = <UserData>[];
    String? cursor;
    try {
      do {
        final page = await UsersApi.following(userId, cursor: cursor, limit: 100);
        out.addAll(page.items.map(userSummaryFromApi));
        cursor = page.next;
      } while (cursor != null && out.length < max);
    } catch (_) {}
    return out;
  }

  Future<List<ActiveCreator>> resolve(
    UserData me, {
    int limit = 10,
    List<String>? followingIds,
    Map<String, int>? freshCounts,
  }) async {
    final counts = Map<String, int>.from(freshCounts ?? await _unreadByCreator());
    final hotIds = counts.entries.where((e) => e.value > 0).map((e) => e.key).toList();
    final result = <ActiveCreator>[];

    if (hotIds.isNotEmpty) {
      final users = await _fetchUsers(hotIds);
      result.addAll(users.where((u) => u.id != null).map((u) => ActiveCreator(user: u, unseenCount: counts[u.id!] ?? 0)));
      result.sort((a, b) => b.unseenCount.compareTo(a.unseenCount));
    }

    if (result.length < limit && me.id != null) {
      final shown = <String>{...hotIds};
      final followed = await _followedSummaries(me.id!, max: limit + shown.length);
      result.addAll(followed.where((u) => u.id != null && !shown.contains(u.id)).take(limit - result.length).map((u) => ActiveCreator(user: u, unseenCount: 0)));
    }

    if (result.isEmpty) return fetchPlatformRecentCreators(me.id ?? '', limit: limit);
    return result.take(limit).toList();
  }

  /// Créateurs ayant des nouveautés, les plus nombreuses d'abord. [beforeUs] n'est pas géré (la liste du serveur est complète).
  Future<List<ActiveCreator>> fetchFollowedRecentCreators(
    List<String> abonnesIds, {
    int dayRange = 30,
    int limit = 10,
    int? beforeUs,
    Set<String> excludeIds = const {},
    List<String> viewedPostIds = const [],
  }) async {
    if (abonnesIds.isEmpty || beforeUs != null) return [];
    final counts = await _unreadByCreator();
    final ids = abonnesIds.where((id) => !excludeIds.contains(id) && (counts[id] ?? 0) > 0).toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    if (ids.isEmpty) return [];
    final users = await _fetchUsers(ids.take(limit).toList());
    return users.where((u) => u.id != null).map((u) => ActiveCreator(user: u, unseenCount: counts[u.id!] ?? 0)).toList();
  }

  /// Découverte plateforme : nouveaux créateurs conseillés par le serveur (`GET /v1/discover/newcomers`).
  Future<List<ActiveCreator>> fetchPlatformRecentCreators(String currentUserId, {int dayRange = 30, int limit = 10}) async {
    try {
      final r = await _c.get('/discover/newcomers') as Map;
      final rows = ((r['data'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return rows
          .map((j) => userSummaryFromApi(j['author'] is Map ? Map<String, dynamic>.from(j['author'] as Map) : j))
          .where((u) => u.id != null && u.id != currentUserId)
          .take(limit)
          .map((u) => ActiveCreator(user: u, unseenCount: 0))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Canaux ──

  Future<List<Canal>> fetchCanaux(List<String> canalIds) async {
    final res = await Future.wait(canalIds.map((id) async {
      try {
        final r = await _c.get('/channels/$id') as Map;
        return canalFromApi(Map<String, dynamic>.from((r['data'] ?? r) as Map));
      } catch (_) {
        return null;
      }
    }));
    return res.whereType<Canal>().toList();
  }

  Future<List<ActiveCanal>> fetchFollowedRecentCanaux(List<String> canalIds, {int dayRange = 30, int limit = 10}) async {
    if (canalIds.isEmpty) return [];
    final canaux = await fetchCanaux(canalIds.take(limit).toList());
    return canaux.where((c) => c.id != null).map((c) => ActiveCanal(canal: c, lastActivityUs: (c.updatedAt ?? 0) * 1000)).toList()
      ..sort((a, b) => b.lastActivityUs.compareTo(a.lastActivityUs));
  }

  Future<List<ActiveCanal>> fetchFollowedCanauxDirect(List<String> canalIds, {int limit = 5}) async {
    final canaux = await fetchCanaux(canalIds.take(limit).toList());
    return canaux.map((c) => ActiveCanal(canal: c, lastActivityUs: (c.updatedAt ?? 0) * 1000)).toList()
      ..sort((a, b) => b.lastActivityUs.compareTo(a.lastActivityUs));
  }

  /// IDs des créateurs que [userId] SUIT (abonnements).
  Future<List<String>> fetchFollowingIds(String userId) async {
    if (userId.isEmpty) return [];
    return (await _followedSummaries(userId, max: 5000)).map((u) => u.id).whereType<String>().toList();
  }

  /// Canaux suivis par personne : gardés 30 minutes.
  static final Map<String, ({int at, List<String> ids})> _canalIdsCache = {};

  Future<List<String>> fetchFollowedCanalIds(String userId) async {
    if (userId.isEmpty) return [];
    final cached = _canalIdsCache[userId];
    if (cached != null && DateTime.now().millisecondsSinceEpoch - cached.at < 30 * 60 * 1000) return cached.ids;
    try {
      final r = await _c.get('/channels', query: {'mine': 1, 'limit': 50}) as Map;
      final ids = ((r['data'] as List?) ?? const []).map((e) => (e as Map)['id'] as String).toList();
      _canalIdsCache[userId] = (at: DateTime.now().millisecondsSinceEpoch, ids: ids);
      return ids;
    } catch (_) {
      return [];
    }
  }

  /// Le serveur calcule les nouveautés à la lecture : plus de compteur à remettre à zéro dans le profil.
  Future<void> resetCreatorCounter(String currentUserId, String creatorId) async {}

  Future<void> resetCanalCounter(String currentUserId, String canalId) async {}

  Future<List<UserData>> fetchUsersById(List<String> ids) => _fetchUsers(ids);

  /// Nouveautés par créateur (serveur) : seulement les créateurs de [creatorIds] ayant des publications non vues.
  Future<Map<String, int>> recalibrateUnseenCounts({
    required List<String> creatorIds,
    required Set<String> viewedPostIds,
    required int userCreatedAtMs,
  }) async {
    if (creatorIds.isEmpty) return {};
    final counts = await _unreadByCreator();
    final wanted = creatorIds.toSet();
    return {for (final e in counts.entries) if (wanted.contains(e.key) && e.value > 0) e.key: e.value};
  }

  /// Marque comme vues les publications d'un créateur (`POST /v1/feed/seen`, par lots de 100). Retourne les IDs marqués.
  /// L'API n'a pas de filtre « par créateur » : on parcourt jusqu'à 10 pages du fil des abonnements (voir lacunes_api_utilisateurs.md).
  Future<List<String>> markAllPostsSeenForCreator({
    required String userId,
    required String creatorId,
    required int userCreatedAtMs,
    required Set<String> alreadyViewedIds,
  }) async {
    if (userId.isEmpty || creatorId.isEmpty) return [];
    final ids = <String>[];
    String? cursor;
    try {
      for (var page = 0; page < 10; page++) {
        final r = await _c.get('/feed', query: {'limit': 50, 'tier': 1, if (cursor != null) 'cursor': cursor}) as Map;
        for (final p in (r['data'] as List? ?? const [])) {
          final m = p as Map;
          final authorId = (m['author_id'] ?? (m['author'] as Map?)?['id'] ?? (m['user'] as Map?)?['id']) as String?;
          if (authorId == creatorId && !alreadyViewedIds.contains(m['id'])) ids.add(m['id'] as String);
        }
        cursor = r['next_cursor'] as String?;
        if (cursor == null) break;
      }
      for (var i = 0; i < ids.length; i += 100) {
        await _c.post('/feed/seen', body: {'post_ids': ids.sublist(i, (i + 100).clamp(0, ids.length))});
      }
    } catch (_) {}
    return ids;
  }

  /// Profils publics (API : GET /users/{id}, en parallèle ; route à confirmer, voir lacunes_api_utilisateurs.md).
  Future<List<UserData>> _fetchUsers(List<String> ids) async {
    final res = await Future.wait(ids.map((id) async {
      try {
        return userFromApi(await UsersApi.publicProfile(id));
      } catch (_) {
        return null;
      }
    }));
    return res.whereType<UserData>().toList();
  }
}
