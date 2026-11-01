import 'package:afrotok/services/api/api_identity.dart';
// Playlists : modèle, lecture des titres, et appels aux fonctions (créer, acheter, retirer).
// Tout le monde voit une playlist et son contenu ; l'accès (ajout à la bibliothèque) est gratuit ou payant selon le créateur.
// Les titres payants d'artistes y sont permis mais signalés : acheter la playlist ne donne pas le titre complet des titres payants.

import 'dart:async';

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pages/studio/montage/montage_music.dart';
import '../utils/media_cdn.dart';
import 'api/music_api.dart';
import 'music_queue.dart';

const kPlaylistMinPrice = 20;
const kPlaylistMaxPrice = 500;
const kPlaylistMaxTracks = 100;

class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.ownerId,
    required this.ownerPseudo,
    required this.title,
    required this.description,
    required this.access,
    required this.priceCoins,
    required this.trackIds,
    required this.paidCount,
    this.coverUrl,
    this.addCount = 0,
    this.earnedCoins = 0,
    this.streamCount = 0,
    this.status = 'active',
  });

  /// Une playlist de l'API (`GET /music/playlists`).
  factory MusicPlaylist.fromMap(Map<String, dynamic> m, String id) => MusicPlaylist(
        id: id,
        ownerId: '${m['owner_id'] ?? ''}',
        ownerPseudo: '${m['owner_pseudo'] ?? ''}',
        title: '${m['title'] ?? 'Playlist'}',
        description: '${m['description'] ?? ''}',
        access: m['access'] == 'paid' ? 'paid' : 'free',
        priceCoins: (m['price_coins'] as num?)?.toInt() ?? 0,
        trackIds: [for (final t in (m['track_ids'] as List? ?? const [])) '$t'],
        paidCount: (m['paid_count'] as num?)?.toInt() ?? 0,
        coverUrl: m['cover_url'] == null ? null : MediaCdn.url(m['cover_url'] as String),
        addCount: (m['add_count'] as num?)?.toInt() ?? 0,
        earnedCoins: (m['earned_coins'] as num?)?.toInt() ?? 0,
        streamCount: (m['stream_count'] as num?)?.toInt() ?? 0,
        status: '${m['status'] ?? 'active'}',
      );

  final String id;
  final String ownerId;
  final String ownerPseudo;
  final String title;
  final String description;
  final String access; // 'free' | 'paid'
  final int priceCoins;
  final List<String> trackIds; // « a:{idSon} » (artiste) ou « f:{id} » (musique gratuite d'Afrolook)
  final int paidCount;
  final String? coverUrl;
  final int addCount;
  final int earnedCoins;
  final int streamCount;
  final String status;

  bool get isPaid => access == 'paid';
  int get trackCount => trackIds.length;
  bool get hasPaidTracks => paidCount > 0;
  bool get isMine => ownerId == (ApiIdentity.myId ?? '?');

  /// Part du créateur sur un achat (60 %).
  int get ownerShare => (priceCoins * 60) ~/ 100;
}

class PlaylistLoad {
  const PlaylistLoad(this.tracks, this.missing);
  final List<MusicTrack> tracks;

  /// Titres qui ne sont plus disponibles (retirés ou suspendus).
  final int missing;
}

class MusicPlaylists {
  MusicPlaylists._();

  static final Map<String, Future<PlaylistLoad>> _loaded = {};
  static final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Émet tout de suite puis après chaque changement fait depuis cet appareil (créer, ajouter, supprimer).
  static Stream<T> _live<T>(Future<T> Function() load) async* {
    yield await load();
    await for (final _ in _changes.stream) {
      yield await load();
    }
  }

  static List<MusicPlaylist> _parse(List<Map<String, dynamic>> rows) => [for (final m in rows) MusicPlaylist.fromMap(m, '${m['id']}')];

  /// Playlists à découvrir.
  static Stream<List<MusicPlaylist>> discover() => _live(() async => _parse(await MusicApi.playlists()));

  /// Mes playlists.
  static Stream<List<MusicPlaylist>> mine() {
    if (FirebaseAuth.instance.currentUser == null) return const Stream.empty();
    return _live(() async {
      final l = _parse(await MusicApi.playlists(mine: true));
      l.sort((a, b) => b.title.compareTo(a.title) * -1);
      return l;
    });
  }

  /// Playlists ajoutées à ma bibliothèque (identifiants + titre + prix).
  static Stream<List<({String id, String title, int price})>> library() {
    if (FirebaseAuth.instance.currentUser == null) return const Stream.empty();
    return _live(() async => [for (final p in _parse(await MusicApi.playlists(added: true))) (id: p.id, title: p.title, price: p.priceCoins)]);
  }

  static Stream<bool> inLibrary(String playlistId) {
    if (FirebaseAuth.instance.currentUser == null) return Stream.value(false);
    return _live(() async {
      final p = await MusicApi.playlist(playlistId);
      return (p?['me'] as Map?)?['added'] == true;
    });
  }

  static Future<MusicPlaylist?> get(String id) async {
    try {
      final m = await MusicApi.playlist(id);
      return m == null ? null : MusicPlaylist.fromMap(m, id);
    } catch (_) {
      return null;
    }
  }

  /// Titres de la playlist, dans l'ordre ; ceux qui ne sont plus disponibles sont comptés à part.
  static Future<PlaylistLoad> tracksOf(MusicPlaylist p, {bool refresh = false}) {
    final key = '${p.id}:${p.trackIds.join(',')}';
    if (refresh) _loaded.remove(key);
    return _loaded[key] ??= _load(p);
  }

  static Future<PlaylistLoad> _load(MusicPlaylist p) async {
    final byId = <String, MusicTrack>{};
    final soundIds = [for (final r in p.trackIds) if (r.startsWith('a:')) r.substring(2)];
    for (var i = 0; i < soundIds.length; i += 10) {
      await Future.wait(soundIds.skip(i).take(10).map((id) async {
        try {
          final snd = await MusicApi.sound(id);
          if (snd != null && snd.status == 'validated' && snd.previewUrl != null) byId['a:$id'] = MusicTrack.fromSound(snd);
        } catch (_) {}
      }));
    }
    for (final t in kStudioTracks) {
      byId['f:${t.id}'] = MusicTrack.fromStudio(t);
    }
    final out = <MusicTrack>[];
    var missing = 0;
    for (final r in p.trackIds) {
      final t = byId[r];
      if (t == null) {
        missing++;
      } else {
        out.add(t);
      }
    }
    return PlaylistLoad(out, missing);
  }

  static String ref(MusicTrack t) => t.kind == 'free' ? 'f:${t.id}' : 'a:${t.id}';

  /// Crée (playlistId null) ou modifie une playlist. Renvoie l'identifiant, ou lève une [ApiException].
  static Future<String> save({String? playlistId, required String title, String description = '', required bool paid, int price = 0, required List<String> trackIds}) async {
    final d = await MusicApi.savePlaylist(playlistId: playlistId, title: title, description: description, paid: paid, price: price, trackIds: trackIds);
    _loaded.clear();
    _changes.add(null);
    return '${d['id']}';
  }

  /// Ajoute à la bibliothèque (achat en pièces si la playlist est payante). Renvoie {ok, already?, price}.
  static Future<Map<String, dynamic>> add(String playlistId) async {
    final p = await MusicApi.playlist(playlistId);
    final price = (p?['price_coins'] as num?)?.toInt() ?? 0;
    final isOwner = (p?['me'] as Map?)?['is_owner'] == true;
    final r = (p?['access'] == 'paid' && price > 0 && !isOwner) ? await MusicApi.buyPlaylist(playlistId) : await MusicApi.addFreePlaylist(playlistId);
    _changes.add(null);
    return {'ok': true, 'price': price, ...r};
  }

  static Future<void> delete(String playlistId) async {
    await MusicApi.deletePlaylist(playlistId);
    _loaded.clear();
    _changes.add(null);
  }

  /// Retirer une playlist de ma bibliothèque : pas encore de point d'accès dans l'API (voir lacunes_api_argent_creations.md).
  static Future<void> removeFromLibrary(String playlistId) async {
    await MusicApi.removePlaylistFromLibrary(playlistId);
    _changes.add(null);
  }

  /// Message lisible pour une erreur de l'API.
  static String message(Object e) {
    if (e is ApiException && e.isInsufficientCoins) return 'Solde de pièces insuffisant.';
    return MusicApi.message(e, fallback: 'Action impossible.');
  }
}
