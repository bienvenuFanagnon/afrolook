import 'package:afrolook_api_client/afrolook_api_client.dart';

import '../../models/model_data.dart';
import 'post_mapper.dart';
import 'regie_api.dart';

/// Un post de la page « Viral » avec sa vitesse : personnes différentes qui ont réagi dans la fenêtre choisie.
class ViralItem {
  const ViralItem({required this.post, required this.interactions, this.pinned = false});
  final Post post;
  final int interactions;
  final bool pinned;
}

class ViralPageData {
  const ViralPageData({required this.items, this.next});
  final List<ViralItem> items;

  /// Curseur de la page suivante ; null quand il n'y a plus rien.
  final String? next;
}

/// Page « Viral » (GET /feed/viral) et compteur « +N » de l'onglet (GET /feed/viral/unseen). Visible par tous.
class ViralApi {
  ViralApi._();

  /// Fenêtres : 2h (« En ce moment »), 24h (« Aujourd'hui »), 7d (« Cette semaine »).
  static const windows = ['2h', '24h', '7d'];

  static Future<ViralPageData> page(String window, {String? cursor, int limit = 20}) async {
    final r = await RegieApi.get('/feed/viral', query: {'window': window, 'limit': limit, if (cursor != null) 'cursor': cursor});
    return parse(r);
  }

  /// Lecture d'une réponse de l'API (séparée pour être testée sans réseau).
  static ViralPageData parse(dynamic r) {
    final rows = ApiClient.data(r);
    final items = <ViralItem>[];
    for (final e in (rows is List ? rows : const [])) {
      if (e is! Map) continue;
      final j = Map<String, dynamic>.from(e);
      final post = postFromApi(j);
      if (post.id == null) continue;
      final v = j['viral'] is Map ? Map<String, dynamic>.from(j['viral'] as Map) : const <String, dynamic>{};
      items.add(ViralItem(post: post, interactions: (v['interactions'] as num?)?.toInt() ?? 0, pinned: v['pinned'] == true));
    }
    final next = r is Map ? r['next_cursor'] : null;
    return ViralPageData(items: items, next: next is String && next.isNotEmpty ? next : null);
  }

  static Future<int> unseen() async {
    final m = await RegieApi.getMap('/feed/viral/unseen');
    return (m['count'] as num?)?.toInt() ?? 0;
  }
}
