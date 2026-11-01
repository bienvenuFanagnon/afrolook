import 'package:afrotok/services/api/api_identity.dart';
import 'dart:async';
import 'dart:io';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:afrotok/pages/chronique/chroniqueform.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canaux_api.dart';
import 'package:afrotok/services/api/chroniques_mapper.dart';
import 'package:afrotok/services/chronique_first_page.dart';

/// Accès à l'API pour le module « chroniques » (contenus de 24 h : liste, création, vue, j'aime / j'adore, suppression, réponse privée).
/// Les COMMENTAIRES (`chronique_messages`) restent sur Firebase. Aucun retour à Firebase en cas d'erreur de l'API.
class ChroniquesApi {
  ChroniquesApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  /// Identifiant de la personne connectée.
  static String? get myId => ApiIdentity.myId;

  static Map<String, dynamic> _map(dynamic r) {
    final d = ApiClient.data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(dynamic r) {
    final d = r is Map ? r['data'] : r;
    return (d as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Message en français prêt à afficher.
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) => CanauxApi.message(e, fallback: fallback);

  /// Chroniques actives (plus récentes d'abord), par curseur. [userId] : celles d'une seule personne.
  static Future<({List<Chronique> items, String? next})> list({String? userId, String? cursor, int limit = 20, String? myId}) async {
    final r = await _c.get('/chronicles', query: {'limit': limit, if (userId != null) 'user_id': userId, if (cursor != null) 'cursor': cursor});
    final raw = _list(r);
    final next = r is Map ? r['next_cursor'] as String? : null;
    // La première page générale est gardée sur le téléphone : à la prochaine ouverture, les chroniques s'affichent tout de suite
    if (userId == null && cursor == null) unawaited(ChroniqueFirstPage.persistRaw(myId ?? ApiIdentity.myId, raw, next));
    return (items: raw.map((j) => chroniqueFromApi(j, myId: myId)).toList(), next: next);
  }

  /// Une chronique (null si elle a expiré ou a été supprimée).
  static Future<Chronique?> get(String id, {String? myId}) async {
    try {
      return chroniqueFromApi(_map(await _c.get('/chronicles/$id')), myId: myId);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Création. [body] suit le contrat de `POST /v1/chronicles` (type, text, media_upload_id, cover_upload_id, poster_upload_id, music…).
  /// Peut lever une [ApiException] : `too_many_active` (429), `payment_required` (402, musique d'artiste), `music_unavailable`…
  /// [idempotencyKey] : OBLIGATOIRE pour une chronique supplémentaire payante (garder la même clé tant que la personne n'a pas confirmé ou annulé).
  static Future<Chronique> create(Map<String, dynamic> body, {String? myId, String? idempotencyKey}) async =>
      chroniqueFromApi(_map(await _c.post('/chronicles', body: body, idempotencyKey: idempotencyKey)), myId: myId);

  /// Chroniques gratuites restantes et prix de la suivante : `{free_left (null = illimité), fee_coins, fee_due}`.
  static Future<Map<String, dynamic>> fee() async => _map(await _c.get('/chronicles/fee'));

  static Future<void> delete(String id) => _c.delete('/chronicles/$id');

  static final Set<String> _viewed = {};

  /// Vue unique par personne (l'auteur ne compte pas) ; un même appareil n'envoie qu'une fois.
  static Future<void> view(String id) async {
    if (!_viewed.add(id)) return;
    try {
      await _c.post('/chronicles/$id/view');
    } catch (e) {
      _viewed.remove(id);
      rethrow;
    }
  }

  /// [kind] : `like` ou `love`.
  static Future<void> react(String id, String kind) => _c.put('/chronicles/$id/reactions/$kind');

  static Future<void> unreact(String id, String kind) => _c.delete('/chronicles/$id/reactions/$kind');

  /// Réponse privée : `sent` (invitation envoyée), `pending`, `incoming`, `friends` (déjà amis : la discussion s'ouvre), `accepted`.
  static Future<String> reply(String id, String message) async => '${_map(await _c.post('/chronicles/$id/reply', body: {'message': message}))['status']}';

  // ── Musique (sons d'artistes validés visibles pour moi, ma bibliothèque) ──

  /// Page de sons d'artistes (50 au plus) : { data, has_more }.
  static Future<({List<Map<String, dynamic>> items, bool hasMore})> musicSounds({int page = 1, int limit = 50}) async {
    final r = await _c.get('/music/sounds', query: {'page': page, 'limit': limit, 'sort': 'popular'});
    return (items: _list(r), hasMore: r is Map && r['has_more'] == true);
  }

  /// Titres que j'ai achetés.
  static Future<List<Map<String, dynamic>>> musicLibrary() async => _list(await _c.get('/music/library'));

  /// Fiche d'un son (extrait, prix) ; null s'il n'est plus disponible.
  static Future<Map<String, dynamic>?> musicSound(String id) async {
    try {
      return _map(await _c.get('/music/sounds/$id'));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  // ── Envois de fichiers (voir [CanauxApi.upload]) ──
  static Future<String> upload(File file, {void Function(double)? onProgress}) => CanauxApi.upload(file, onProgress: onProgress);
}
