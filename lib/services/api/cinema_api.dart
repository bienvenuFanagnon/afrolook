import 'dart:io' show File;
import 'dart:typed_data';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:http/http.dart' as http;

import 'api_gateway.dart';
import 'canaux_api.dart';
import 'users_api.dart';

/// Cartoon Cinéma (21/11/2026) : séries et films animés, lecture HLS (une piste son par langue, sous-titres WebVTT), progression,
/// impressions, commentaires courts, visites de la page, notifications ; gestion par l'équipe selon ses droits (`cinema.create`,
/// `cinema.edit`, `cinema.delete`, `cinema.stats`, ou `cinema.manage` pour tout).
class CinemaApi {
  CinemaApi._();

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
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) => CanauxApi.message(e, fallback: fallback);

  // ── Public ──

  static Future<Map<String, dynamic>> home() async => _map(await _c.get('/cinema/home'));

  /// Épisodes sortis que la personne n'a pas encore commencés (pastille du bouton Cinéma).
  static Future<int> unseen() async => ((_map(await _c.get('/cinema/badge'))['unseen']) as num?)?.toInt() ?? 0;

  static Future<Map<String, dynamic>?> teaser() async {
    final r = await _c.get('/cinema/teaser');
    final d = r is Map ? r['data'] : null;
    return d is Map ? Map<String, dynamic>.from(d) : null;
  }

  static Future<Map<String, dynamic>> title(String id) async => _map(await _c.get('/cinema/titles/$id'));

  static Future<Map<String, dynamic>> episode(String id) async => _map(await _c.get('/cinema/episodes/$id'));

  /// Lecture : `master_url`, `entitled`, `preview_seconds`, `audio` [{lang,label}], `subtitles` [{lang,label,url}], `default_lang`, `my_lang`, `resume_sec`.
  static Future<Map<String, dynamic>> play(String id) async => _map(await _c.get('/cinema/episodes/$id/play'));

  /// Recherche : `{titles, episodes}` (titre, résumé, genre, nom d'épisode).
  static Future<Map<String, dynamic>> search(String q) async => _map(await _c.get('/cinema/search', query: {'q': q}));

  /// Débloque l'épisode pour 24 h après les pubs regardées (`via: 'ads'`), ou quand aucune pub n'était disponible (`via: 'none'`).
  /// Renvoie la même réponse que [play], avec la lecture complète.
  static Future<Map<String, dynamic>> unlock(String id, {required String via, int ads = 0}) async =>
      _map(await _c.post('/cinema/episodes/$id/unlock', body: {'via': via, 'ads': ads}));

  static Future<Map<String, dynamic>> progress(String id, int positionSec, {int? durationSec, String? lang}) async =>
      _map(await _c.post('/cinema/episodes/$id/progress', body: {'position_sec': positionSec, if (durationSec != null) 'duration_sec': durationSec, if (lang != null) 'lang': lang}));

  static Future<Map<String, dynamic>> react(String id, String kind) async => _map(await _c.put('/cinema/episodes/$id/reaction', body: {'kind': kind}));

  static Future<Map<String, dynamic>> unreact(String id) async => _map(await _c.delete('/cinema/episodes/$id/reaction'));

  static Future<({List<Map<String, dynamic>> items, String? next})> comments(String id, {String? cursor}) async {
    final r = await _c.get('/cinema/episodes/$id/comments', query: {'limit': 20, if (cursor != null) 'cursor': cursor});
    return (items: _list(r), next: r is Map ? r['next_cursor'] as String? : null);
  }

  static Future<Map<String, dynamic>> comment(String id, String body) async => _map(await _c.post('/cinema/episodes/$id/comments', body: {'body': body}));

  static Future<void> deleteComment(String commentId) => _c.delete('/cinema/comments/$commentId');

  static Future<Map<String, dynamic>> likeComment(String commentId, bool like) async =>
      _map(like ? await _c.put('/cinema/comments/$commentId/like') : await _c.delete('/cinema/comments/$commentId/like'));

  static Future<void> reportComment(String commentId, {String? reason}) => _c.post('/cinema/comments/$commentId/report', body: {if (reason != null) 'reason': reason});

  /// Visite de la page (source : nav, feed, notif, menu) ; le temps passé est envoyé ensuite par [visitPing].
  static Future<String?> visit(String source) async => _map(await _c.post('/cinema/visits', body: {'source': source}))['id'] as String?;

  static Future<void> visitPing(String visitId, int seconds) => _c.post('/cinema/visits/$visitId/ping', body: {'seconds': seconds});

  static Future<void> setNotifications(bool on) => on ? _c.put('/cinema/follow') : _c.delete('/cinema/follow');

  // ── Gestion (équipe) ──

  /// Droits de gestion du cinéma de la personne connectée (le serveur reste seul juge).
  static Future<CinemaRights> rights() async {
    try {
      final c = await UsersApi.capabilities();
      if (c['is_staff'] != true) return const CinemaRights();
      final perms = ((c['permissions'] as List?) ?? const []).map((e) => '$e').toSet();
      final all = c['type'] == 'super_admin' || perms.contains('cinema.manage') || perms.contains('content.moderate');
      bool has(String p) => all || perms.contains(p);
      return CinemaRights(create: has('cinema.create'), edit: has('cinema.edit'), delete: has('cinema.delete'), stats: has('cinema.stats'),
          manage: c['type'] == 'super_admin' || perms.contains('cinema.manage'));
    } catch (_) {
      return const CinemaRights();
    }
  }

  static Future<List<Map<String, dynamic>>> adminTitles() async => _list(await _c.get('/admin/cinema/titles'));

  static Future<Map<String, dynamic>> createTitle(Map<String, dynamic> body) async => _map(await _c.post('/admin/cinema/titles', body: body));

  static Future<Map<String, dynamic>> updateTitle(String id, Map<String, dynamic> body) async => _map(await _c.patch('/admin/cinema/titles/$id', body: body));

  static Future<void> deleteTitle(String id) => _c.delete('/admin/cinema/titles/$id');

  static Future<Map<String, dynamic>> createEpisode(String titleId, Map<String, dynamic> body) async => _map(await _c.post('/admin/cinema/titles/$titleId/episodes', body: body));

  static Future<Map<String, dynamic>> updateEpisode(String id, Map<String, dynamic> body) async => _map(await _c.patch('/admin/cinema/episodes/$id', body: body));

  static Future<void> deleteEpisode(String id) => _c.delete('/admin/cinema/episodes/$id');

  static Future<void> deleteTrack(String episodeId, String kind, String lang) => _c.delete('/admin/cinema/episodes/$episodeId/$kind/$lang');

  static Future<Map<String, dynamic>> stats({int days = 30}) async => _map(await _c.get('/admin/cinema/stats', query: {'days': days}));

  /// Promo de fin d'épisode : `{video_url, link_url, label}`.
  static Future<Map<String, dynamic>> promo() async => _map(await _c.get('/admin/cinema/promo'));

  /// Envoie la vidéo de la promo (lue par morceaux sur téléphone) puis l'annonce au serveur.
  static Future<Map<String, dynamic>> uploadPromo({Uint8List? bytes, String? path, required int size, required String contentType, void Function(double)? onProgress}) async {
    final u = _map(await _c.post('/admin/cinema/promo/upload-url', body: {'content_type': contentType, 'size': size}));
    await _put('${u['upload_url']}', contentType: contentType, bytes: bytes, path: path, size: size, onProgress: onProgress);
    return _map(await _c.post('/admin/cinema/promo/uploaded', body: {'key': u['key']}));
  }

  /// Lien ouvert par le bouton (https) et texte du bouton.
  static Future<Map<String, dynamic>> updatePromo({String? linkUrl, String? label}) async =>
      _map(await _c.put('/admin/cinema/promo', body: {'link_url': linkUrl, 'label': label}));

  static Future<Map<String, dynamic>> deletePromo() async => _map(await _c.delete('/admin/cinema/promo'));

  /// Pubs du cinéma : `{unlock_ads, mid_ads, unlock_hours, preview_seconds}` (lecture par l'équipe du cinéma).
  static Future<Map<String, dynamic>> adSettings() async => _map(await _c.get('/admin/cinema/ads'));

  /// Modifie les nombres de pubs (droit « tout gérer »).
  static Future<Map<String, dynamic>> updateAdSettings({required int unlockAds, required int midAds}) async =>
      _map(await _c.put('/admin/cinema/ads', body: {'unlock_ads': unlockAds, 'mid_ads': midAds}));

  /// Envoi direct vers le stockage, par morceaux de 1 Mo (sur téléphone : lus depuis le fichier, jamais tout en mémoire).
  static Future<void> _put(String url, {required String contentType, Uint8List? bytes, String? path, required int size, void Function(double)? onProgress}) async {
    final req = http.StreamedRequest('PUT', Uri.parse(url))
      ..headers['Content-Type'] = contentType
      ..contentLength = size;
    final Stream<List<int>> source = path != null ? File(path).openRead() : Stream<List<int>>.fromIterable([for (var i = 0; i < bytes!.length; i += 1 << 20) bytes.sublist(i, (i + (1 << 20)).clamp(0, bytes.length))]);
    var sent = 0;
    final pump = source.listen((chunk) {
      req.sink.add(chunk);
      sent += chunk.length;
      onProgress?.call(size > 0 ? (sent / size * 0.95).clamp(0.0, 0.95) : 0);
    }, onDone: () => req.sink.close(), onError: (Object e) {
      req.sink.addError(e);
      req.sink.close();
    }, cancelOnError: true);
    final res = await http.Client().send(req);
    await pump.asFuture<void>().catchError((_) {});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Envoi interrompu (${res.statusCode}). Réessaie.');
    }
    onProgress?.call(1);
  }

  /// Envoi d'un fichier (vidéo sans voix, voix off ou sous-titres d'une langue) directement vers le stockage, puis annonce au serveur.
  /// Sur téléphone, [path] : le fichier est lu par morceaux (jamais 300 Mo en mémoire) ; sur le web, [bytes]. [onProgress] reçoit 0 à 1.
  static Future<Map<String, dynamic>> uploadFile(String episodeId, {required String kind, String? lang, String? label, Uint8List? bytes, String? path, required int size, required String contentType, void Function(double)? onProgress}) async {
    final u = _map(await _c.post('/admin/cinema/episodes/$episodeId/upload-url', body: {'kind': kind, if (lang != null) 'lang': lang, 'content_type': contentType, 'size': size}));
    await _put('${u['upload_url']}', contentType: contentType, bytes: bytes, path: path, size: size, onProgress: onProgress);
    final done = _map(await _c.post('/admin/cinema/episodes/$episodeId/uploaded', body: {'kind': kind, 'key': u['key'], if (lang != null) 'lang': lang, if (label != null) 'label': label}));
    onProgress?.call(1);
    return done;
  }
}

/// Ce que la personne peut faire dans la gestion du cinéma.
class CinemaRights {
  const CinemaRights({this.create = false, this.edit = false, this.delete = false, this.stats = false, this.manage = false});

  final bool create;
  /// « Tout gérer » : seul ce droit modifie les nombres de pubs.
  final bool manage;
  final bool edit;
  final bool delete;
  final bool stats;

  bool get any => create || edit || delete || stats;
}
