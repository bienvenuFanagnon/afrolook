import 'dart:async';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canaux_api.dart';
import 'package:afrotok/services/api/home_feed_api.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/api/shop_api.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:flutter/foundation.dart';

/// Opérations de publications partagées par les écrans de détail, de vidéos, de vibes et d'accueil.
/// Tout passe par l'API : aucun retour à Firebase en cas d'erreur (l'écran affiche le message et propose « Réessayer »).
/// Les routes encore absentes de l'API sont listées dans `lacunes_api_publications_restantes.md`.
class PubApi {
  PubApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  /// Message en français prêt à afficher.
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) => UsersApi.message(e, fallback: fallback);

  static List<Map<String, dynamic>> _list(dynamic r) {
    final d = r is Map ? r['data'] : r;
    return (d as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ── Lecture d'une publication ──

  /// Publication à jour (null si supprimée). Remplace les flux `snapshots()` : l'écran rappelle cette méthode pour se rafraîchir.
  static Future<Post?> fresh(String id) => PostsApi.get(id);

  // ── Réactions ──
  /// J'aime / retrait du j'aime. Lève une [ApiException] (402 `insufficient_coins` possible).
  static Future<void> setLike(String postId, bool liked) async {
    if (liked) {
      await PostsApi.like(postId);
    } else {
      await PostsApi.unlike(postId);
    }
  }

  static Future<void> setFavorite(String postId, bool favorite) async {
    if (favorite) {
      await PostsApi.favorite(postId);
    } else {
      await PostsApi.unfavorite(postId);
    }
  }

  /// Vue comptée par le serveur (une seule fois par publication et par session ; gains compris).
  static Future<void> view(String postId) => ApiGateway.instance.markViewed(postId);

  // ── Partage et republication ──
  /// Compte un partage (`POST /posts/{id}/share`, une fois par personne ; le serveur enregistre aussi le signal de goût pour le fil).
  /// Jamais bloquant : la personne a déjà partagé, une erreur n'est que journalisée. Renvoie le nombre de partages du serveur
  /// (null si l'appel a échoué) et [counted] à vrai quand ce partage vient d'être compté.
  static Future<({int? count, bool counted})> share(String postId) async {
    try {
      final r = await PostsApi.share(postId);
      return (count: r.count, counted: r.counted);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ API PARTAGE EN ÉCHEC pour $postId : $e');
      return (count: null, counted: false);
    }
  }

  /// Republie une publication (diffusée aux abonnés). Route souhaitée : POST /posts/{id}/repost (un seul repost par personne).
  static Future<void> repost(String postId) async {
    await _c.post('/posts/$postId/repost', idempotencyKey: ApiClient.newIdempotencyKey());
  }

  /// « Soutenir par une publicité » : 1 pièce au créateur, une fois par jour et par publication. Route souhaitée : POST /posts/{id}/support-ad.
  /// Erreur 429/409 du serveur = déjà soutenu aujourd'hui.
  static Future<void> supportAd(String postId) async {
    await _c.post('/posts/$postId/support-ad', idempotencyKey: ApiClient.newIdempotencyKey());
  }

  static Future<void> report(String postId, {String type = 'standard'}) => PostsApi.report(postId, type: type);

  static Future<void> delete(String postId) => PostsApi.delete(postId);

  // ── Profils et canaux ──

  /// Profils publics en lot -> UserData (les introuvables sont absents).
  static Future<List<UserData>> users(Iterable<String> ids) async {
    final list = ids.where((e) => e.isNotEmpty).toSet().toList();
    final out = <UserData>[];
    for (var i = 0; i < list.length; i += 50) {
      final rows = await UsersApi.lookup(list.sublist(i, i + 50 > list.length ? list.length : i + 50));
      out.addAll(rows.map(userSummaryFromApi));
    }
    return out;
  }

  static Future<UserData?> user(String id) async {
    try {
      return userFromApi(await UsersApi.publicProfile(id));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Recherche de personnes par pseudo / nom.
  static Future<List<UserData>> searchUsers(String q, {int limit = 30}) async => (await UsersApi.searchUsers(q, limit: limit)).map(userSummaryFromApi).toList();

  /// Recherche de canaux (par nom), éventuellement les plus populaires si [q] est vide.
  static Future<List<Canal>> searchCanaux(String q, {int limit = 20, String? myId}) async => (await CanauxApi.list(search: q, limit: limit, myId: myId)).items;

  static Future<Canal?> canal(String id, {String? myId}) async {
    try {
      return await CanauxApi.get(id, myId: myId);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  static Future<void> followCanal(String canalId) => CanauxApi.join(canalId);

  // ── Listes de publications par curseur ──

  /// Publications d'un compte.
  static Future<({List<Post> posts, String? next})> userPosts(String userId, {String? cursor, int limit = 20, String? dataType}) async {
    final r = await UsersApi.userPosts(userId, cursor: cursor, limit: limit, dataType: dataType);
    return (posts: r.items.map(postFromApi).where((p) => p.id != null).toList(), next: r.next);
  }

  /// Mes favoris, du plus récent au plus ancien.
  static Future<({List<Post> posts, String? next})> myFavorites({String? cursor, int limit = 20}) async {
    final r = await _c.get('/me/favorites/posts', query: {'limit': limit, if (cursor != null) 'cursor': cursor}) as Map;
    return (posts: _list(r).map(postFromApi).where((p) => p.id != null).toList(), next: r['next_cursor'] as String?);
  }

  /// Fil de découverte (niveau 3) filtré par thème / pays. Voir [HomeFeedApi.discover].
  static Future<({List<Post> posts, String? next})> discover({String? category, String? country, String? cursor, int limit = 20, int tier = 3}) =>
      HomeFeedApi.discover(category: category, country: country, cursor: cursor, limit: limit, tier: tier);

  /// Fil des abonnements (niveau 1, publications non vues).
  static Future<({List<Post> posts, String? next})> following({String? cursor, int limit = 20}) => HomeFeedApi.discover(cursor: cursor, limit: limit, tier: 1);

  /// Fil selon les centres d'intérêt (niveau 2).
  static Future<({List<Post> posts, String? next})> interests({String? cursor, int limit = 20}) => HomeFeedApi.discover(cursor: cursor, limit: limit, tier: 2);

  // ── Divers ──

  /// Nombre de clics par réseau (`{facebook: 12, tiktok: 3, …}`), compté par le serveur : GET /home/social-clicks. Lève l'erreur de l'API.
  static Future<Map<String, int>> socialClicks() async {
    final d = ApiClient.data(await _c.get('/home/social-clicks'));
    return d is Map ? d.map((k, v) => MapEntry('$k', (v as num?)?.toInt() ?? 0)) : <String, int>{};
  }

  /// Clic sur un réseau social (compteur côté serveur : POST /home/social-clicks). Jamais bloquant.
  static Future<void> socialClick(String network) async {
    try {
      await _c.post('/home/social-clicks', body: {'network': network});
    } catch (e) {
      if (kDebugMode) debugPrint('API clic réseau $network : $e');
    }
  }

  /// Transactions de la personne connectée (page).
  static Future<({List<TransactionSolde> items, String? next})> transactions(String userId, {String? cursor, int limit = 30}) async {
    final r = await UsersApi.transactions(cursor: cursor, limit: limit);
    return (items: r.items.map((j) => transactionFromApi(j, userId)).toList(), next: r.next);
  }

  // ── Services des utilisateurs (routes à créer : voir lacunes_api_publications_restantes.md) ──
  static UserServiceData serviceFromApi(Map<String, dynamic> j) {
    final s = UserServiceData.fromJson(j);
    if (j['user'] is Map) s.user = userSummaryFromApi(Map<String, dynamic>.from(j['user'] as Map));
    return s;
  }

  /// Page de services disponibles. Route souhaitée : GET /services?category=&country=&city=&q=&cursor=&limit=
  static Future<({List<UserServiceData> items, String? next})> services({String? category, String? country, String? city, String? q, String? cursor, int limit = 6}) async {
    final r = await _c.get('/services', query: {
      'limit': limit,
      if (category != null && category.isNotEmpty) 'category': category,
      if (country != null && country.isNotEmpty) 'country': country,
      if (city != null && city.isNotEmpty) 'city': city,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (cursor != null) 'cursor': cursor,
    });
    return (items: _list(r).map(serviceFromApi).toList(), next: r is Map ? r['next_cursor'] as String? : null);
  }

  /// Un service (null s'il n'existe plus). Route souhaitée : GET /services/{id}
  static Future<UserServiceData?> service(String id) async {
    try {
      final d = ApiClient.data(await _c.get('/services/$id'));
      return d is Map ? serviceFromApi(Map<String, dynamic>.from(d)) : null;
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Villes proposées par les services disponibles. Route souhaitée : GET /services/cities -> {data:[...]}
  static Future<List<String>> serviceCities() async {
    final d = (await _c.get('/services/cities')) as Map;
    return ((d['data'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList()..sort();
  }

  /// Entreprises (boutiques) d'une personne. Route souhaitée : GET /shop/businesses?owner_id= (filtre ajouté à la route existante).
  static Future<List<EntrepriseData>> businessesOf(String userId) async {
    final r = await _c.get('/shop/businesses', query: {'owner_id': userId});
    return _list(r).map(ShopApi.business).toList();
  }

  /// Canaux mis en avant sur l'accueil (les mieux notés, 8 au plus).
  static Future<List<Canal>> topCanaux({int limit = 8, String? myId}) async => (await CanauxApi.list(limit: 20, myId: myId)).items.take(limit).toList();
}
