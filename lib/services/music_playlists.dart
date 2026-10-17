// Playlists : modèle, lecture des titres, et appels aux fonctions (créer, acheter, retirer).
// Tout le monde voit une playlist et son contenu ; l'accès (ajout à la bibliothèque) est gratuit ou payant selon le créateur.
// Les titres payants d'artistes y sont permis mais signalés : acheter la playlist ne donne pas le titre complet des titres payants.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pages/studio/artist_marketplace.dart';
import '../pages/studio/montage/montage_music.dart';
import '../utils/media_cdn.dart';
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

  factory MusicPlaylist.fromMap(Map<String, dynamic> m, String id) => MusicPlaylist(
        id: id,
        ownerId: '${m['ownerId'] ?? ''}',
        ownerPseudo: '${m['ownerPseudo'] ?? ''}',
        title: '${m['title'] ?? 'Playlist'}',
        description: '${m['description'] ?? ''}',
        access: m['access'] == 'paid' ? 'paid' : 'free',
        priceCoins: (m['priceCoins'] as num?)?.toInt() ?? 0,
        trackIds: [for (final t in (m['trackIds'] as List? ?? const [])) '$t'],
        paidCount: (m['paidCount'] as num?)?.toInt() ?? 0,
        coverUrl: m['coverUrl'] == null ? null : MediaCdn.url(m['coverUrl'] as String),
        addCount: (m['addCount'] as num?)?.toInt() ?? 0,
        earnedCoins: (m['earnedCoins'] as num?)?.toInt() ?? 0,
        streamCount: (m['streamCount'] as num?)?.toInt() ?? 0,
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
  bool get isMine => ownerId == (FirebaseAuth.instance.currentUser?.uid ?? '?');

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

  static final _db = FirebaseFirestore.instance;
  static final Map<String, Future<PlaylistLoad>> _loaded = {};

  /// Playlists à découvrir (les plus récemment modifiées).
  static Stream<List<MusicPlaylist>> discover() => _db
      .collection('MusicPlaylists')
      .where('status', isEqualTo: 'active')
      .orderBy('updatedAt', descending: true)
      .limit(60)
      .snapshots()
      .map((s) => [for (final d in s.docs) MusicPlaylist.fromMap(d.data(), d.id)]);

  /// Mes playlists.
  static Stream<List<MusicPlaylist>> mine() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('MusicPlaylists').where('ownerId', isEqualTo: uid).where('status', isEqualTo: 'active').snapshots().map((s) {
      final l = [for (final d in s.docs) MusicPlaylist.fromMap(d.data(), d.id)];
      l.sort((a, b) => b.title.compareTo(a.title) * -1);
      return l;
    });
  }

  /// Playlists ajoutées à ma bibliothèque (identifiants + titre au moment de l'ajout).
  static Stream<List<({String id, String title, int price})>> library() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('MusicPlaylistLibrary').where('uid', isEqualTo: uid).snapshots().map((s) {
      final d = s.docs.map((x) => x.data()).toList()..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
      return [for (final x in d) (id: '${x['playlistId']}', title: '${x['title'] ?? 'Playlist'}', price: (x['price'] as num?)?.toInt() ?? 0)];
    });
  }

  static Stream<bool> inLibrary(String playlistId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _db.collection('MusicPlaylistLibrary').doc('${uid}_$playlistId').snapshots().map((d) => d.exists);
  }

  static Future<MusicPlaylist?> get(String id) async {
    try {
      final d = await _db.collection('MusicPlaylists').doc(id).get();
      return d.exists ? MusicPlaylist.fromMap(d.data()!, d.id) : null;
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
          final d = await _db.collection('artist_sounds').doc(id).get();
          if (d.exists && d.data()!['status'] == 'validated') {
            final s = ArtistSound.fromMap(d.data()!, d.id);
            if (s.previewUrl != null) byId['a:$id'] = MusicTrack.fromSound(s);
          }
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

  static Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    final r = await FirebaseFunctions.instance.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// Crée (playlistId null) ou modifie une playlist. Renvoie l'identifiant, ou lève FirebaseFunctionsException.
  static Future<String> save({String? playlistId, required String title, String description = '', required bool paid, int price = 0, required List<String> trackIds}) async {
    final d = await _call('playlistSave', {'playlistId': playlistId, 'title': title, 'description': description, 'access': paid ? 'paid' : 'free', 'priceCoins': price, 'trackIds': trackIds});
    _loaded.clear();
    return '${d['id']}';
  }

  /// Ajoute à la bibliothèque (paie si la playlist est payante). Renvoie {ok, already?, price, ownerCoins, paidCount}.
  static Future<Map<String, dynamic>> add(String playlistId) => _call('playlistAdd', {'playlistId': playlistId});

  static Future<void> delete(String playlistId) async {
    await _call('playlistDelete', {'playlistId': playlistId});
    _loaded.clear();
  }

  /// Retire une playlist de ma bibliothèque (sans remboursement).
  static Future<void> removeFromLibrary(String playlistId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('MusicPlaylistLibrary').doc('${uid}_$playlistId').delete();
  }

  /// Message lisible pour une erreur de fonction.
  static String message(Object e) {
    if (e is FirebaseFunctionsException) {
      if (e.code == 'resource-exhausted' && (e.message ?? '').contains('Solde')) return 'Solde de pièces insuffisant.';
      return e.message ?? 'Action impossible.';
    }
    return 'Action impossible. Vérifie ta connexion.';
  }
}
