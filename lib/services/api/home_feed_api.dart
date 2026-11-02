import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/post_mapper.dart';

/// Lectures d'accueil via l'API : publications de découverte, posts vus, nouveautés par créateur.
/// Aucun retour à Firebase en cas d'erreur : l'exception remonte à l'écran.
class HomeFeedApi {
  HomeFeedApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  /// Une page de découverte (niveau 3 du serveur : publications non vues, pays proche en premier).
  /// Filtres faits PAR LE SERVEUR (`GET /feed?category=&country=`) : [category] = thème exact (Sport, Looks, Événements…),
  /// [country] = code pays à 2 lettres (publications visibles dans ce pays ou dans « tous les pays »). Le code « ALL » ou un code
  /// invalide veut dire « pas de filtre de pays » (le serveur refuse tout autre format).
  static Future<({List<Post> posts, String? next})> discover({String? category, String? country, String? cursor, int limit = 20, int tier = 3}) async {
    final cc = country?.trim().toUpperCase();
    // Page thématique (Sport, Événements, Looks…) : le même fil « pour toi » que l'accueil (non vu, abonnements d'abord, goûts), filtré par thème,
    // et sans fin (quand le récent est épuisé, le serveur élargit à 90 jours, un an, tout l'historique). Le curseur est celui de /feed/for-you.
    final themed = tier == 3 && category != null && category.isNotEmpty;
    final r = await _c.get(themed ? '/feed/for-you' : '/feed', query: {
      if (!themed) 'tier': tier,
      'limit': themed ? limit.clamp(1, 30) : limit,
      if (cursor != null) 'cursor': cursor,
      if (category != null && category.isNotEmpty) 'category': category,
      if (cc != null && RegExp(r'^[A-Z]{2}$').hasMatch(cc)) 'country': cc,
    }) as Map;
    final posts = ((r['data'] as List?) ?? const []).whereType<Map>().map((m) => postFromApi(Map<String, dynamic>.from(m))).where((p) => p.id != null).toList();
    for (final p in posts) {
      p.typeTabbar ??= p.categorie;
    }
    return (posts: posts, next: r['next_cursor'] as String?);
  }

  /// Marque des publications comme vues (100 par envoi).
  static Future<void> markSeen(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    for (var i = 0; i < list.length; i += 100) {
      await _c.post('/feed/seen', body: {'post_ids': list.sublist(i, i + 100 > list.length ? list.length : i + 100)});
    }
  }

  /// Nouveautés non vues par créateur suivi.
  static Future<Map<String, int>> unreadByCreator() async {
    final d = ApiClient.data(await _c.get('/feed/unread-counts'));
    final m = d is Map ? d['by_creator'] : null;
    if (m is! Map) return {};
    return m.map((k, v) => MapEntry('$k', (v as num).toInt())).cast<String, int>()..removeWhere((_, v) => v <= 0);
  }
}
