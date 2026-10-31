import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/post_mapper.dart';

/// Ce que le défi a rapporté (visible par le créateur et l'équipe) : sommes payées par les participants et les votants.
class DefiRevenue {
  const DefiRevenue({this.voteCoins = 0, this.voteCount = 0, this.participationCoins = 0, this.participationCount = 0});
  final int voteCoins;
  final int voteCount;
  final int participationCoins;
  final int participationCount;
  int get total => voteCoins + participationCoins;
}

/// Accès à l'API pour le module DÉFIS : découverte, détail, création, conversion d'un post, participation, vote, gains, boost.
/// Aucun retour à Firebase en cas d'erreur : les erreurs sont des [ApiException] (code stable + message en français) ; l'écran les affiche
/// et propose « Réessayer ». Les actions d'argent portent une clé d'idempotence conservée tant que l'action n'a pas abouti ou été refusée :
/// un second appui ou une reprise réseau réutilise la MÊME clé (jamais de double débit).
class DefisApi {
  DefisApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(dynamic r) {
    final d = r is Map ? r['data'] : r;
    return (d as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Message en français prêt à afficher.
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) => e is ApiException ? e.message : fallback;

  // ── Clés d'idempotence ──
  static final Map<String, String> _keys = {};

  static Future<T> _once<T>(String action, Future<T> Function(String key) run) async {
    final key = _keys.putIfAbsent(action, ApiClient.newIdempotencyKey);
    try {
      final r = await run(key);
      _keys.remove(action);
      return r;
    } on ApiException catch (e) {
      if (!e.isNetwork) _keys.remove(action); // refus définitif : une nouvelle tentative est une nouvelle action
      rethrow;
    }
  }

  /// Oublie la clé d'une action abandonnée par la personne (bouton « Annuler »).
  static void forget(String action) => _keys.remove(action);

  // ── Lecture ──

  /// Découverte : les défis, du plus récent au plus ancien ([onlyOngoing] : seulement ceux en cours), par curseur.
  static Future<({List<Post> items, String? next})> discover({String? cursor, int limit = 15, bool onlyOngoing = false, String? creatorId}) async {
    final r = await _c.get('/defis', query: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
      if (onlyOngoing) 'status': 'ongoing',
      if (creatorId != null) 'creator_id': creatorId,
    });
    return (items: _list(r).map(postFromApi).toList(), next: r is Map ? r['next_cursor'] as String? : null);
  }

  /// Un défi (null s'il n'existe pas).
  static Future<Post?> get(String id) async {
    try {
      return postFromApi(_map(await _c.get('/defis/$id')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Participations d'un défi, déjà classées (votes, score, j'aime, ancienneté).
  static Future<List<Post>> participations(String defiId, {int limit = 50}) async =>
      _list(await _c.get('/defis/$defiId/participations', query: {'limit': limit})).map(postFromApi).toList();

  /// Gains du défi (créateur et équipe seulement ; 404 pour les autres).
  static Future<DefiRevenue> revenue(String defiId) async {
    final d = _map(await _c.get('/defis/$defiId/revenue'));
    int n(String k) => (d[k] as num?)?.toInt() ?? 0;
    return DefiRevenue(voteCoins: n('vote_coins'), voteCount: n('vote_count'), participationCoins: n('participation_coins'), participationCount: n('participation_count'));
  }

  // ── Écriture ──

  static Map<String, dynamic> _configBody(DefiConfig c) => {
        'jackpot_coins': c.cagnottePieces,
        'participation_fee': c.participationFee,
        'vote_fee': c.voteFee,
        'winners_count': c.winnersCount,
        'ends_at': DateTime.fromMillisecondsSinceEpoch(c.endDate).toUtc().toIso8601String(),
      };

  /// Crée un défi : la cagnotte est débitée dans la même opération. [content] : description, link_url, upload_ids, countries, interests, category.
  /// Erreurs : 402 `insufficient_coins`, 422 `invalid_config`…
  static Future<Post> create(Map<String, dynamic> content, DefiConfig config) =>
      _once('create', (k) async => postFromApi(_map(await _c.pay('/defis', body: {...content, ..._configBody(config)}, idempotencyKey: k))));

  /// Transforme un post de la personne en défi (mêmes règles que la création). Erreurs : 402, 409 `post_monetized` / `not_convertible`…
  static Future<Post> convert(String postId, DefiConfig config, {String? description}) =>
      _once('convert:$postId', (k) async => postFromApi(_map(await _c.pay('/defis/convert', body: {
            'post_id': postId,
            if (description != null) 'description': description,
            ..._configBody(config),
          }, idempotencyKey: k))));

  /// Participe (frais éventuels) et publie la réponse. Erreurs : 402, 409 `already_participating` / `defi_ended`.
  static Future<Post> participate(String defiId, Map<String, dynamic> content) =>
      _once('participate:$defiId', (k) async => postFromApi(_map(await _c.pay('/defis/$defiId/participations', body: content, idempotencyKey: k))));

  /// Vote pour une participation. Erreurs : 402, 403 `creator_cannot_vote`, 409 `already_voted` / `defi_ended`.
  /// Renvoie le nombre de votes de la participation.
  static Future<int> vote(String defiId, String responsePostId) => _once('vote:$defiId', (k) async {
        final d = _map(await _c.pay('/defis/$defiId/votes', body: {'response_post_id': responsePostId}, idempotencyKey: k));
        return (d['votes_count'] as num?)?.toInt() ?? 0;
      });

  /// Publicité d'un défi (boost payant du créateur) : débit en pièces ET annonce en attente de validation dans la même opération.
  /// [weeks] : durée choisie ; [countries] vide = tous les pays ; [text] : texte de la publicité (220 caractères au plus).
  static Future<void> boost(String defiId, {required int weeks, List<String> countries = const [], required String text}) =>
      _once('boost:$defiId', (k) async {
        await _c.pay('/ads/boosts', body: {
          'target': 'post',
          'target_id': defiId,
          'weeks': weeks,
          'description': text,
          'action_text': 'Participer',
          if (countries.isNotEmpty) 'countries': countries,
        }, idempotencyKey: k);
      });
}
