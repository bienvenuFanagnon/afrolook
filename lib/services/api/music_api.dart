import 'dart:io';
import 'dart:typed_data';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/pages/studio/artist_marketplace.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/argent_upload.dart';
import 'package:afrotok/services/api/wallet_api.dart';
import 'package:afrotok/utils/media_cdn.dart';

/// Accès à l'API : musique (sons d'artistes, favoris, j'aime, bibliothèque, playlists, écoutes, signalements, validation par l'équipe).
/// Aucun retour à Firebase : toute erreur est transmise ([ApiException], message en français).
class MusicApi {
  MusicApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _map(dynamic r) => WalletApi.map(r);
  static List<Map<String, dynamic>> _list(dynamic r) => WalletApi.list(r);

  static String message(Object e, {String fallback = 'Action impossible. Vérifie ta connexion.'}) => WalletApi.message(e, fallback: fallback);

  // ── Conversion API → modèle d'affichage ──

  /// Un titre de l'API (`GET /music/sounds`) → [ArtistSound]. Les infos « à moi » (aimé, acheté) sont lues par [absorbMe].
  static ArtistSound soundFromApi(Map<String, dynamic> m) {
    final artist = m['artist'] is Map ? Map<String, dynamic>.from(m['artist'] as Map) : const <String, dynamic>{};
    final use = (m['use_coins'] as num?)?.toInt() ?? 0;
    final sale = (m['sale_coins'] as num?)?.toInt() ?? 0;
    final countries = m['countries'];
    String? url(String? u) => (u == null || u.isEmpty) ? null : MediaCdn.url(u);
    final created = DateTime.tryParse('${m['created_at']}') ?? DateTime.now();
    final s = ArtistSound(
      id: '${m['id']}',
      userId: '${m['artist_id'] ?? artist['id'] ?? ''}',
      userPseudo: '${artist['username'] ?? ''}',
      userImageUrl: MediaCdn.url(artist['avatar_url'] as String?),
      title: '${m['title'] ?? ''}',
      genre: m['genre'] as String?,
      description: m['description'] as String?,
      previewUrl: url(m['preview_url'] as String?),
      pricing: (use > 0 || sale > 0) ? 'paid' : 'free',
      coverImageUrl: url(m['cover_url'] as String?),
      durationMs: (m['duration_ms'] as num?)?.toInt() ?? 0,
      status: '${m['status'] ?? 'validated'}',
      refusalReason: m['refusal_reason'] as String?,
      usageCount: (m['usage_count'] as num?)?.toInt() ?? 0,
      totalEarningsCoins: ((m['use_earnings'] as num?)?.toInt() ?? 0) + ((m['sale_earnings'] as num?)?.toInt() ?? 0),
      reportCount: (m['reports'] as num?)?.toInt() ?? 0,
      postCount: (m['post_count'] as num?)?.toInt() ?? 0,
      useCoins: use,
      saleCoins: sale,
      saleCount: (m['sale_count'] as num?)?.toInt() ?? 0,
      previewSec: ((m['preview_sec'] as num?)?.toInt() ?? 30).clamp(5, 60),
      streamCount: (m['stream_count'] as num?)?.toInt() ?? 0,
      likeCount: (m['like_count'] as num?)?.toInt() ?? 0,
      saleEarnings: (m['sale_earnings'] as num?)?.toInt() ?? 0,
      useEarnings: (m['use_earnings'] as num?)?.toInt() ?? 0,
      processed: m['processed'],
      duplicates: [for (final d in (m['duplicates'] as List? ?? const [])) if (d is Map) Map<String, dynamic>.from(d)],
      availableCountries: countries is List ? [for (final x in countries) '$x'] : const [],
      createdAt: created,
      validatedAt: created,
    );
    absorbMe(s.id, m['me']);
    return s;
  }

  /// Ce que l'API dit de MOI sur un titre : aimé, acheté. Alimente les ensembles gardés en mémoire (cœurs, « acheté »).
  static void Function(String soundId, Map<String, dynamic> me)? onMe;
  static void absorbMe(String soundId, dynamic me) {
    if (me is Map && onMe != null) onMe!(soundId, Map<String, dynamic>.from(me));
  }

  // ── Catalogue ──

  static Future<({List<ArtistSound> items, bool more})> sounds({
    String? genre,
    String? artistId,
    String? search,
    String? pricing,
    String sort = 'recent',
    bool mine = false,
    int page = 1,
    int limit = 30,
  }) async {
    final r = await _c.get('/music/sounds', query: {
      if (genre != null) 'genre': genre,
      if (artistId != null) 'artist_id': artistId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (pricing != null) 'pricing': pricing,
      'sort': sort,
      if (mine) 'mine': 1,
      'page': page,
      'limit': limit.clamp(1, 50), // le serveur refuse (422) plus de 50 par page
    });
    return (items: _list(r).map(soundFromApi).toList(), more: r is Map && r['has_more'] == true);
  }

  static Future<List<ArtistSound>>? _latest;
  static DateTime? _latestAt;

  /// Titres validés récents, mis en mémoire 60 s (Studio, fil, sélecteurs : un seul appel pour tous les écrans).
  static Future<List<ArtistSound>> latestCached({bool force = false}) {
    final at = _latestAt;
    if (force || _latest == null || at == null || DateTime.now().difference(at) > const Duration(seconds: 60)) {
      _latestAt = DateTime.now();
      _latest = latestValidated(limit: 50).catchError((Object e) {
        _latest = null;
        _latestAt = null;
        throw e;
      });
    }
    return _latest!;
  }

  static Future<ArtistSound?> sound(String id) async {
    try {
      return soundFromApi(_map(await _c.get('/music/sounds/$id')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Titres validés les plus récents (Studio, fil, sélecteurs).
  static Future<List<ArtistSound>> latestValidated({int limit = 50}) async => (await sounds(limit: limit)).items.where((s) => s.previewUrl != null).toList();

  /// Mes titres déposés.
  /// Adresse d'écoute d'une musique gratuite d'Afrolook (lien valable une heure) : GET /music/free/{id}. Lève une erreur (404) si le fichier n'est pas encore sur le stockage.
  static Future<String> freeTrackUrl(String id) async => '${_map(await _c.get('/music/free/$id'))['url']}';

  static Future<List<ArtistSound>> mySounds() async => (await sounds(mine: true, limit: 50)).items;

  /// Ma bibliothèque (titres achetés).
  static Future<List<ArtistSound>> library() async => _list(await _c.get('/music/library')).map(soundFromApi).toList();

  /// Lien d'écoute : titre complet (gratuit, acheté ou à moi) sinon extrait. {full, url, expires_in | preview_sec, purchase_required}
  static Future<Map<String, dynamic>> listen(String soundId) async => _map(await _c.get('/music/sounds/$soundId/listen'));

  // ── Favoris et j'aime ──
  static Future<List<Map<String, dynamic>>> favorites() async => _list(await _c.get('/music/favorites'));

  static Future<void> setFavorite(String kind, String itemId, bool on) async {
    on ? await _c.put('/music/favorites/$kind/$itemId') : await _c.delete('/music/favorites/$kind/$itemId');
  }

  static Future<void> setLike(String kind, String itemId, bool on) async {
    on ? await _c.put('/music/likes/$kind/$itemId') : await _c.delete('/music/likes/$kind/$itemId');
  }

  /// Écoute comptée par le serveur (10 s de lecture ; limites gérées côté API).
  static Future<bool> countStream(String kind, String id) async => _map(await _c.post('/music/streams', body: {'kind': kind, 'id': id}))['counted'] == true;

  static Future<Map<String, dynamic>> report(String soundId, {String? reason}) async => _map(await _c.post('/music/sounds/$soundId/report', body: {if (reason != null) 'reason': reason}));

  // ── Achats (pièces) ──
  /// Achat du titre complet (ajout à la bibliothèque).
  static Future<Map<String, dynamic>> buySound(String soundId) => WalletApi.instance.buy('music_sale', refId: soundId);

  /// Utilisation payante d'un titre dans un montage ([jobId] = identifiant du montage).
  static Future<Map<String, dynamic>> buyUse(String soundId, String jobId) => WalletApi.instance.buy('music_use', refId: soundId, jobId: jobId);

  /// Utilisation d'un titre gratuit : simple trace.
  static Future<void> freeUse(String soundId, String jobId) => _c.post('/music/sounds/$soundId/free-use', body: {'job_id': jobId});

  /// Relie la publication au montage qui a utilisé le titre.
  static Future<void> linkPost(String jobId, String postId) => _c.post('/music/uses/$jobId/link', body: {'post_id': postId});

  // ── Dépôt, modification, suppression ──
  /// Dépose un titre : l'original part en PRIVÉ (jamais d'adresse publique), l'équipe l'écoute avant validation.
  static Future<ArtistSound> create({
    required File audio,
    File? cover,
    required String title,
    String? genre,
    String? description,
    int useCoins = 0,
    int saleCoins = 0,
    List<String>? countries,
    void Function(double)? onProgress,
  }) async {
    final bytes = await audio.readAsBytes();
    final audioId = await ArgentUpload.bytes(Uint8List.fromList(bytes), contentType: _audioType(audio.path), private: true, onProgress: onProgress);
    String? coverId;
    if (cover != null) {
      coverId = await ArgentUpload.bytes(Uint8List.fromList(await cover.readAsBytes()), contentType: cover.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    }
    final r = await _c.post('/music/sounds', body: {
      'title': title,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (description != null && description.isNotEmpty) 'description': description,
      'use_coins': useCoins,
      'sale_coins': saleCoins,
      if (countries != null) 'countries': countries,
      'original_upload_id': audioId,
      if (coverId != null) 'cover_upload_id': coverId,
      'rights_certified': true,
    });
    return soundFromApi(_map(r));
  }

  static String _audioType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.mp3')) return 'audio/mpeg';
    if (p.endsWith('.wav')) return 'audio/wav';
    if (p.endsWith('.ogg')) return 'audio/ogg';
    if (p.endsWith('.aac')) return 'audio/aac';
    return 'audio/mp4';
  }

  static Future<ArtistSound> update(String id, Map<String, dynamic> fields) async => soundFromApi(_map(await _c.patch('/music/sounds/$id', body: fields)));

  /// Suppression stricte : la personne retape le titre exact ([confirmTitle]).
  static Future<void> delete(String id, {String? confirmTitle}) => _c.delete('/music/sounds/$id', body: {if (confirmTitle != null) 'confirm_title': confirmTitle});

  // ── Playlists ──
  static Future<List<Map<String, dynamic>>> playlists({bool mine = false, bool added = false}) async =>
      _list(await _c.get('/music/playlists', query: {if (mine) 'mine': 1, if (added) 'added': 1}));

  static Future<Map<String, dynamic>?> playlist(String id) async {
    try {
      return _map(await _c.get('/music/playlists/$id'));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Crée ([playlistId] null) ou modifie une playlist.
  static Future<Map<String, dynamic>> savePlaylist({String? playlistId, required String title, String description = '', required bool paid, int price = 0, required List<String> trackIds}) async {
    final body = {'title': title, 'description': description, 'access': paid ? 'paid' : 'free', if (paid) 'price_coins': price, 'track_ids': trackIds};
    final r = playlistId == null ? await _c.post('/music/playlists', body: body) : await _c.patch('/music/playlists/$playlistId', body: body);
    return _map(r);
  }

  /// Point d'accès prévu : DELETE /music/playlists/{id}/library (absent pour l'instant, voir lacunes_api_argent_creations.md).
  static Future<void> removePlaylistFromLibrary(String id) => _c.delete('/music/playlists/$id/library');

  static Future<void> deletePlaylist(String id) => _c.delete('/music/playlists/$id');

  /// Ajoute une playlist gratuite à la bibliothèque.
  static Future<Map<String, dynamic>> addFreePlaylist(String id) async => _map(await _c.post('/music/playlists/$id/add'));

  /// Achète une playlist payante (pièces) : elle est ajoutée à la bibliothèque.
  static Future<Map<String, dynamic>> buyPlaylist(String id) => WalletApi.instance.buy('music_playlist', refId: id);

  // ── Équipe ──
  static Future<List<ArtistSound>> adminQueue() async => _list(await _c.get('/admin/music/queue')).map((m) {
        final s = soundFromApi(m);
        return s;
      }).toList();

  /// Lien d'écoute de l'original (équipe) pour un titre en attente.
  static Future<String?> adminListenUrl(String id) async {
    final rows = _list(await _c.get('/admin/music/queue'));
    for (final m in rows) {
      if ('${m['id']}' == id) return m['listen_url'] as String?;
    }
    return null;
  }

  /// [action] : validate | refuse | suspend | restore (motif obligatoire pour refuser).
  static Future<void> adminReview(String id, String action, {String? reason}) => _c.post('/admin/music/sounds/$id/review', body: {'action': action, if (reason != null) 'reason': reason});
}
