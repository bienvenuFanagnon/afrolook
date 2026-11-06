import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/audit_errors.dart';

/// Accès à la nouvelle API pour le module « régie et administration ».
/// Aucune requête ne revient vers Firebase : une erreur est remontée telle quelle (ApiException, message déjà en français).
class RegieApi {
  RegieApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(dynamic v) =>
      (v is List ? v : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// Message lisible pour une erreur d'API (ou autre).
  static String err(Object e) => e is ApiException ? (AuditErrors.known(e, scope: ErrorScope.share) ?? e.message) : 'Une erreur est survenue. Réessaie.';

  // ── Lectures / écritures génériques ──
  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _c.get(path, query: query);
  static Future<dynamic> post(String path, {Object? body}) => _c.post(path, body: body);
  static Future<dynamic> put(String path, {Object? body}) => _c.put(path, body: body);
  static Future<dynamic> patch(String path, {Object? body}) => _c.patch(path, body: body);
  static Future<dynamic> delete(String path, {Object? body}) => _c.delete(path, body: body);

  /// Réponse `data` sous forme d'objet.
  static Future<Map<String, dynamic>> getMap(String path, {Map<String, dynamic>? query}) async => _map(await _c.get(path, query: query));

  /// Réponse `data` sous forme de liste d'objets.
  static Future<List<Map<String, dynamic>>> getList(String path, {Map<String, dynamic>? query}) async => _list(ApiClient.data(await _c.get(path, query: query)));

  // ── Configuration publique (GET /config) ──
  static Map<String, dynamic>? _config;
  static DateTime? _configAt;

  /// Configuration publique (réglages marqués publics côté serveur). Gardée 5 minutes en mémoire. Vide si l'API ne répond pas.
  static Future<Map<String, dynamic>> config({bool force = false}) async {
    final at = _configAt;
    if (!force && _config != null && at != null && DateTime.now().difference(at) < const Duration(minutes: 5)) return _config!;
    final c = await getMap('/config');
    _config = c;
    _configAt = DateTime.now();
    return c;
  }

  /// Un sous-arbre de la configuration (ex. `ads`, `rewards`, `modules`, `exchange_rates`), objet vide s'il est absent.
  static Future<Map<String, dynamic>> configSection(String key, {bool force = false}) async {
    final c = await config(force: force);
    final v = c[key];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  // ── Récompenses ──
  static Future<Map<String, dynamic>> rewardsState() => getMap('/rewards/state');
  static Future<Map<String, dynamic>> rewardsView() async => _map(await _c.post('/rewards/views'));
  /// Export d'une création du Studio : libre avec Gold ou une passe, sinon consomme un crédit (402 `export_locked` sinon).
  static Future<Map<String, dynamic>> rewardsExport() async => _map(await _c.post('/rewards/export', body: const {}));
  static Future<Map<String, dynamic>> rewardsClaim(String offerId) async => _map(await _c.post('/rewards/claim', body: {'offer_id': offerId}));

  // ── Pubs de la régie dans l'application (choix de l'annonce par le serveur) ──
  static Future<Map<String, dynamic>> adsServe(Map<String, dynamic> query) async => _map(await _c.get('/ads/app/serve', query: query));

  /// Stock d'annonces d'Afrolook préparé à l'avance pour la personne connectée (voir AfrolookAdsPool) : `{ads: [...], ttl_sec}`.
  static Future<Map<String, dynamic>> adsPool({int limit = 10}) async => _map(await _c.get('/ads/app/pool', query: {'limit': limit}));
  static Future<void> adsEvent(Map<String, dynamic> body) async {
    await _c.post('/ads/app/event', body: body);
  }
}
