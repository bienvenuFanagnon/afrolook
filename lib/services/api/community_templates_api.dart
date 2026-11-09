import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/community_template.dart';
import 'package:afrotok/services/api/api_gateway.dart';

/// Modèles prêts à poster créés par les utilisateurs (09/11/2026) : catalogue, création, modification, suppression ; validation par l'équipe côté admin.
/// Aucun appel ne sort de l'API : une erreur est remontée telle quelle (ApiException, message déjà en français).
class CommunityTemplatesApi {
  CommunityTemplatesApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static List<CommunityTemplate> _list(dynamic d) => [for (final r in (d is List ? d : const []).whereType<Map>()) CommunityTemplate.fromApi(r)];

  /// Catalogue des modèles validés ([sort] : `popular` ou `new`), ou les miens avec [mine] (tous statuts).
  static Future<({List<CommunityTemplate> items, bool hasMore})> list({String sort = 'popular', String? pricing, String? category, String? search, bool mine = false, int page = 1}) async {
    final r = await _c.get('/studio/community-templates', query: {
      'sort': sort,
      if (pricing != null) 'pricing': pricing,
      if (category != null) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      if (mine) 'mine': 'true',
      'page': '$page',
    });
    final map = r is Map ? r : const {};
    return (items: _list(map['data']), hasMore: map['has_more'] == true);
  }

  /// Un modèle (validé, ou le mien) ; null s'il n'est plus disponible (supprimé, suspendu, refusé).
  static Future<CommunityTemplate?> get(String id) async {
    try {
      final d = ApiClient.data(await _c.get('/studio/community-templates/$id'));
      return d is Map ? CommunityTemplate.fromApi(d) : null;
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  static Future<CommunityTemplate> create({required String name, required String category, required int priceCoins, required Map<String, dynamic> recipe}) async {
    final d = ApiClient.data(await _c.post('/studio/community-templates', body: {'name': name, 'category': category, 'price_coins': priceCoins, 'recipe': recipe}));
    return CommunityTemplate.fromApi(Map<String, dynamic>.from(d as Map));
  }

  /// Le nom, la catégorie ou la recette renvoient le modèle en validation ; le prix seul ne change pas son statut.
  static Future<CommunityTemplate> update(String id, {String? name, String? category, int? priceCoins, Map<String, dynamic>? recipe}) async {
    final d = ApiClient.data(await _c.patch('/studio/community-templates/$id', body: {
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (priceCoins != null) 'price_coins': priceCoins,
      if (recipe != null) 'recipe': recipe,
    }));
    return CommunityTemplate.fromApi(Map<String, dynamic>.from(d as Map));
  }

  static Future<void> delete(String id) async {
    await _c.delete('/studio/community-templates/$id');
  }

  // ── Équipe (le « hub » de modération : pas de validation préalable, mais suspension et suppression) ──

  /// Tous les modèles publiés ([status] `validated`) ou suspendus (`suspended`), les plus récents d'abord ; [search] par nom.
  static Future<List<CommunityTemplate>> adminList({String status = 'validated', String search = ''}) async {
    final d = ApiClient.data(await _c.get('/admin/community-templates', query: {'status': status, if (search.isNotEmpty) 'search': search}));
    return _list(d);
  }

  /// [action] : `suspend` (motif obligatoire, montré au créateur) ou `restore`.
  static Future<void> adminReview(String id, String action, {String? reason}) async {
    await _c.post('/admin/community-templates/$id/review', body: {'action': action, if (reason != null && reason.isNotEmpty) 'reason': reason});
  }

  /// Suppression par l'équipe : le modèle disparaît ; les publications déjà faites et les gains déjà versés restent.
  static Future<void> adminDelete(String id) async {
    await _c.delete('/admin/community-templates/$id');
  }
}
