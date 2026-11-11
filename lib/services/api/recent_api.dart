import 'package:afrolook_api_client/afrolook_api_client.dart';

import '../../models/model_data.dart';
import 'post_mapper.dart';
import 'regie_api.dart';

/// Une page de l'onglet « Récents » : les publications de toutes les catégories, de la plus récente à la plus ancienne.
class RecentPageData {
  const RecentPageData({required this.posts, this.next});
  final List<Post> posts;

  /// Curseur de la page suivante ; null quand il n'y a plus rien.
  final String? next;
}

/// Onglet « Récents » (GET /feed/recent) : tout ce qui vient d'être publié, vu ou non, sans mes propres posts. Visible par tous.
class RecentApi {
  RecentApi._();

  static Future<RecentPageData> page({String? cursor, int limit = 20}) async {
    final r = await RegieApi.get('/feed/recent', query: {'limit': limit, if (cursor != null) 'cursor': cursor});
    return parse(r);
  }

  /// Lecture d'une réponse de l'API (séparée pour être testée sans réseau).
  static RecentPageData parse(dynamic r) {
    final rows = ApiClient.data(r);
    final posts = <Post>[];
    for (final e in (rows is List ? rows : const [])) {
      if (e is! Map) continue;
      final post = postFromApi(Map<String, dynamic>.from(e));
      if (post.id != null) posts.add(post);
    }
    final next = r is Map ? r['next_cursor'] : null;
    return RecentPageData(posts: posts, next: next is String && next.isNotEmpty ? next : null);
  }
}
