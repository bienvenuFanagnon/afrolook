import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'api_error.dart';

/// Fournit le jeton Firebase (rafraîchi si besoin). `forceRefresh` est demandé après une réponse 401.
typedef TokenProvider = Future<String?> Function({bool forceRefresh});

/// Fournit le jeton App Check (facultatif).
typedef AppCheckProvider = Future<String?> Function();

/// Client unique de la nouvelle API :
///  - jeton Firebase + App Check sur chaque requête, un seul rafraîchissement automatique après un 401 ;
///  - nouvelles tentatives (réseau, 429, 502/503/504) avec attente croissante, UNIQUEMENT pour les lectures et les écritures portant une clé d'idempotence ;
///  - `Idempotency-Key` stable pour les paiements : la même clé est renvoyée à chaque tentative, jamais de double débit ;
///  - erreurs converties en [ApiException] (code stable + message en français).
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.token,
    this.appCheck,
    this.onEmailUnverified,
    this.maxRetries = 3,
    this.retryBase = const Duration(milliseconds: 400),
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 30)
      ..validateStatus = (_) => true; // les statuts d'erreur sont traités ici, pas par Dio
  }

  final TokenProvider token;
  final AppCheckProvider? appCheck;

  /// Appelé UNE fois par requête quand l'API répond 403 `email_unverified` : l'application ouvre sa fenêtre « Confirme ton e-mail » et
  /// renvoie true si l'e-mail est confirmé (la requête est alors rejouée, avec la même clé d'idempotence). Si la personne renonce (false),
  /// l'erreur est relancée avec `details.declined = true` pour que l'écran n'ouvre pas une seconde fenêtre.
  final Future<bool> Function()? onEmailUnverified;
  final int maxRetries;
  final Duration retryBase;
  final Dio _dio;
  static const _uuid = Uuid();

  static String newIdempotencyKey() => _uuid.v4();

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);

  /// [longJob] : travail lourd du serveur (montage vidéo, découpe, signature…) qui peut durer plusieurs minutes. Le délai d'attente passe à 6 minutes et la requête n'est JAMAIS
  /// rejouée toute seule : un rejeu relancerait un second travail pendant que le premier tourne encore (« montage déjà en cours »).
  Future<dynamic> post(String path, {Object? body, String? idempotencyKey, bool longJob = false}) => _send('POST', path, body: body, idempotencyKey: idempotencyKey, longJob: longJob);

  Future<dynamic> put(String path, {Object? body, String? idempotencyKey}) => _send('PUT', path, body: body, idempotencyKey: idempotencyKey);

  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) => _send('DELETE', path, body: body);

  /// Paiement : génère la clé si elle n'est pas fournie. L'écran garde la clé tant que l'utilisateur n'a pas confirmé ou annulé, pour qu'un
  /// second appui ou une reprise réseau réutilise la MÊME clé.
  Future<dynamic> pay(String path, {Object? body, String? idempotencyKey}) => post(path, body: body, idempotencyKey: idempotencyKey ?? newIdempotencyKey());

  /// Renvoie le champ `data` de la réponse (ou la réponse entière si elle n'en a pas).
  static dynamic data(dynamic response) => response is Map && response.containsKey('data') ? response['data'] : response;

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, dynamic>? query, String? idempotencyKey, bool longJob = false}) async {
    final safeToRetry = !longJob && (method == 'GET' || idempotencyKey != null);
    var refreshed = false;
    var emailAsked = false;
    var attempt = 0;
    while (true) {
      Response<dynamic> res;
      try {
        res = await _dio.request<dynamic>(
          path,
          data: body,
          queryParameters: query,
          options: Options(method: method, headers: await _headers(idempotencyKey, forceRefresh: refreshed), receiveTimeout: longJob ? const Duration(minutes: 6) : null, sendTimeout: longJob ? const Duration(minutes: 2) : null),
        );
      } on DioException catch (e) {
        if (safeToRetry && attempt < maxRetries) {
          await _wait(attempt++, null);
          continue;
        }
        throw ApiException(status: 0, code: 'network', message: e.type == DioExceptionType.connectionError ? 'Pas de connexion.' : 'Le serveur ne répond pas. Réessayez.');
      }
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) return res.data;
      if (status == 401 && !refreshed) {
        refreshed = true; // jeton expiré : un seul nouvel essai avec un jeton rafraîchi
        continue;
      }
      if (status == 403 && !emailAsked && onEmailUnverified != null && res.data is Map && (res.data as Map)['code'] == 'email_unverified') {
        emailAsked = true;
        if (await onEmailUnverified!()) continue; // e-mail confirmé, jeton renouvelé : on rejoue (aucun paiement n'a eu lieu, la route refuse avant)
        final e = _error(status, res.data);
        throw ApiException(status: e.status, code: e.code, message: e.message, details: {...e.details, 'declined': true});
      }
      if (safeToRetry && attempt < maxRetries && (status == 429 || status == 502 || status == 503 || status == 504)) {
        await _wait(attempt++, int.tryParse(res.headers.value('retry-after') ?? ''));
        continue;
      }
      throw _error(status, res.data);
    }
  }

  Future<Map<String, dynamic>> _headers(String? idempotencyKey, {required bool forceRefresh}) async {
    final t = await token(forceRefresh: forceRefresh);
    final ac = await appCheck?.call();
    return {
      'Accept': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
      if (ac != null) 'X-Firebase-AppCheck': ac,
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    };
  }

  Future<void> _wait(int attempt, int? retryAfterSeconds) {
    final backoff = retryBase * pow(2, attempt).toInt();
    final wait = retryAfterSeconds != null ? Duration(seconds: retryAfterSeconds.clamp(0, 10)) : backoff;
    return Future<void>.delayed(wait);
  }

  ApiException _error(int status, dynamic body) {
    if (body is Map && body['code'] is String) {
      final d = body['details'];
      return ApiException(status: status, code: body['code'] as String, message: (body['message'] as String?) ?? 'Une erreur est survenue.', details: d is Map ? Map<String, dynamic>.from(d) : const {});
    }
    return ApiException(status: status, code: 'http_$status', message: status >= 500 ? 'Le serveur rencontre un problème. Réessayez plus tard.' : 'Requête refusée.');
  }
}
