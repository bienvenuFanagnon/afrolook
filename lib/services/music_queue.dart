// File d'attente de la musique d'Afrolook : suivant, précédent, aléatoire, préchargement, fin d'extrait gratuit.
// Un seul lecteur dans toute l'application (SoundPreview) ; ce fichier décide QUOI jouer ensuite et prévient l'interface.

import 'package:afrotok/services/read_meter.dart';
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../pages/studio/artist_marketplace.dart';
import '../pages/studio/artist_sound_common.dart';
import '../pages/studio/montage/montage_music.dart';
import 'music_head.dart';
import 'music_voice.dart';
import 'offline_music_service.dart';

/// Un titre de la file : musique gratuite d'Afrolook, son d'artiste, ou titre de la bibliothèque (acheté).
class MusicTrack {
  MusicTrack._({
    required this.kind,
    required this.id,
    required this.title,
    required this.artist,
    this.genre,
    this.coverUrl,
    this.previewUrl,
    this.sound,
    this.studio,
    this.owned = false,
  });

  factory MusicTrack.fromSound(ArtistSound s, {bool owned = false}) => MusicTrack._(
        kind: 'artist',
        id: s.id,
        title: s.title,
        artist: '@${s.userPseudo}',
        genre: s.genre,
        coverUrl: s.coverImageUrl,
        previewUrl: s.previewUrl,
        sound: s,
        owned: owned,
      );

  factory MusicTrack.fromStudio(StudioTrack t) => MusicTrack._(
        kind: 'free',
        id: t.id,
        title: t.title,
        artist: 'Musique Afrolook',
        genre: t.mood,
        studio: t,
      );

  /// Titre de la bibliothèque : on garde l'essentiel du document MusicLibrary (le son complet se charge à la demande).
  factory MusicTrack.fromLibrary(Map<String, dynamic> d, {String? cover}) => MusicTrack._(
        kind: 'artist',
        id: '${d['soundId']}',
        title: '${d['title'] ?? 'Titre'}',
        artist: (d['userPseudo'] ?? '').toString().isEmpty ? 'Acheté' : '@${d['userPseudo']}',
        genre: (d['genre'] ?? '').toString().isEmpty ? null : '${d['genre']}',
        coverUrl: cover,
        owned: true,
      );

  final String kind; // 'free' | 'artist'
  final String id;
  final String title;
  final String artist;
  final String? genre;
  final String? coverUrl;
  final String? previewUrl;
  final ArtistSound? sound;
  final StudioTrack? studio;
  final bool owned;

  String get key => 'music_$kind:$id';

  /// Durée de l'extrait gratuit (secondes), calculée d'après la durée du titre.
  int get previewSec => sound?.previewSec ?? 30;
  bool get isArtist => kind == 'artist';

  /// Gratuit (musique Afrolook ou son d'artiste gratuit). Un titre de la bibliothèque est « payé ».
  bool get isFree => sound != null ? sound!.isFree : !owned && kind == 'free';

  /// Prix pour l'utiliser dans un post (pièces), 0 = gratuit.
  int get useCoins => sound != null && !sound!.isFree ? sound!.unitPrice : 0;

  /// Prix pour acheter le titre complet (pièces), 0 = pas en vente.
  int get saleCoins => sound != null && sound!.forSale ? sound!.saleCoins : 0;

  /// Part de l'artiste sur un achat (60 %).
  int get saleShare => (saleCoins * 60) ~/ 100;

  bool get isMine {
    try {
      return sound != null && sound!.userId == FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return false;
    }
  }
}

class MusicQueue {
  MusicQueue._();

  static final ValueNotifier<MusicTrack?> current = ValueNotifier<MusicTrack?>(null);
  static final ValueNotifier<bool> shuffle = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> loading = ValueNotifier<bool>(false);

  /// Vrai quand l'extrait gratuit du titre en cours est terminé (le titre complet reste à débloquer).
  static final ValueNotifier<bool> previewEnded = ValueNotifier<bool>(false);

  /// Vrai quand le titre en cours est un extrait (titre payant pas encore débloqué).
  static final ValueNotifier<bool> previewMode = ValueNotifier<bool>(false);

  /// Titre payant dont l'extrait vient de se terminer et que la lecture a laissé derrière elle (la lecture est passée au suivant) :
  /// l'interface propose alors de l'acheter.
  static final ValueNotifier<MusicTrack?> skippedPaid = ValueNotifier<MusicTrack?>(null);

  /// Message d'erreur à montrer (une seule fois) : lecture impossible…
  static final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  /// Titres achetés par la personne (lu en direct depuis MusicLibrary).
  static final ValueNotifier<Set<String>> ownedIds = ValueNotifier<Set<String>>(<String>{});

  /// Fin d'un extrait gratuit : l'interface ouvre la feuille « Tu aimes ce titre ? ».
  static final StreamController<MusicTrack> _ends = StreamController<MusicTrack>.broadcast();
  static Stream<MusicTrack> get ends => _ends.stream;

  /// Pub plein écran « entre deux titres » (branchée par l'interface, qui connaît l'utilisateur).
  static Future<void> Function()? interstitialHook;

  /// Playlist en cours de lecture (ses écoutes sont comptées aussi pour elle), null hors playlist.
  static String? _playlistId;
  static String? get playlistId => _playlistId;
  static String? _streamCountedKey; // titre dont l'écoute (30 s) est déjà comptée pour cette lecture

  static List<MusicTrack> _queue = const [];
  static int _index = -1;
  static int _gen = 0;
  static bool _wired = false;
  static StreamSubscription<QuerySnapshot>? _ownedSub;
  static String? _ownedUid;
  static final Random _rnd = Random();
  static final List<int> _history = [];
  static int? _peeked; // prochain titre déjà choisi (pour le précharger et rester cohérent avec « suivant »)

  static List<MusicTrack> get queue => _queue;
  static int get index => _index;
  static bool get hasNext => _queue.length > 1;

  /// À appeler une fois (démarrage de l'interface) : écoute la fin des titres et les achats de la personne.
  static bool _doneWired = false;
  static void start() {
    if (!_doneWired) {
      _doneWired = true;
      SoundPreview.completed.listen(_onCompleted);
      SoundPreview.position.listen(_onPosition);
    }
    if (_wired) return;
    try {
      FirebaseAuth.instance.authStateChanges().listen(_watchOwned);
      _watchOwned(FirebaseAuth.instance.currentUser);
      _wired = true;
    } catch (_) {
      // Firebase pas encore prêt : on réessaiera au prochain lancement d'un titre
    }
  }

  static void _watchOwned(User? u) {
    if (u?.uid == _ownedUid) return;
    final previous = _ownedUid;
    _ownedUid = u?.uid;
    if (previous != null && u?.uid != previous) unawaited(MusicHead.purgeAll()); // déconnexion ou autre compte : plus rien de l'ancien
    _ownedSub?.cancel();
    ownedIds.value = <String>{};
    if (u == null) return;
    _ownedSub = FirebaseFirestore.instance.collection('MusicLibrary').where('uid', isEqualTo: u.uid).snapshotsM('music_queue.dart:179').listen((s) {
      ownedIds.value = {for (final d in s.docs) '${d.data()['soundId']}'};
    }, onError: (_) {});
  }

  static bool isOwned(MusicTrack t) => t.owned || ownedIds.value.contains(t.id);

  // ── Lancer ──

  /// Lance [queue] au titre [index]. Les titres suivants de la liste sont ceux du « suivant » (ou de l'aléatoire).
  static Future<bool> play(List<MusicTrack> queue, int index, {bool interstitial = true, String? playlistId}) async {
    start();
    _playlistId = playlistId;
    if (queue.isEmpty || index < 0 || index >= queue.length) return false;
    _queue = List.unmodifiable(queue);
    _index = index;
    _history.clear();
    _peeked = null;
    return _startCurrent(interstitial: interstitial);
  }

  /// Titre seul : s'il est déjà dans la file en cours, on garde la file.
  static Future<bool> playTrack(MusicTrack t, {bool interstitial = true}) {
    final i = _queue.indexWhere((x) => x.key == t.key);
    if (i >= 0) {
      _index = i;
      _history.clear();
      _peeked = null;
      return _startCurrent(interstitial: interstitial);
    }
    return play([t], 0, interstitial: interstitial);
  }

  // ── Écoutes (streams) : une écoute = 10 secondes de lecture (ou le titre ou l'extrait écouté en entier s'il est plus court),
  // comptée une fois par lecture ; le serveur limite à 1 par personne, par titre et par tranche de 10 minutes ──

  static const streamAfterSeconds = 10;

  static void _onPosition(Duration p) {
    if (p.inSeconds < streamAfterSeconds) return;
    final t = current.value;
    if (t == null || _streamCountedKey == t.key) return;
    if (SoundPreview.playing.value != t.key) return;
    _countStream(t);
  }

  static void _countStream(MusicTrack t) {
    _streamCountedKey = t.key;
    if (FirebaseAuth.instance.currentUser == null) return;
    final data = <String, dynamic>{'playlistId': _playlistId, if (t.kind == 'free') 'studioId': t.id else 'soundId': t.id};
    unawaited(FirebaseFunctions.instance.httpsCallable('musicStream').call<dynamic>(data).then<void>((_) {}, onError: (Object e) {
      if (kDebugMode) debugPrint('musicStream : $e');
    }));
  }

  static Future<bool> _startCurrent({required bool interstitial}) async {
    final t = _queue[_index];
    final gen = ++_gen;
    current.value = t;
    _streamCountedKey = null;
    previewEnded.value = false;
    loading.value = true;
    var ok = false;
    String? err;
    try {
      if (interstitial) {
        try {
          await interstitialHook?.call();
        } catch (_) {}
        if (gen != _gen) return false;
      }
      final own = t.isMine;
      final owned = isOwned(t);
      final canFull = t.isArtist && (owned || own || (t.sound?.isFree ?? false));
      if (t.isArtist && OfflineMusic.has(t.id)) {
        // Titre téléchargé : lu depuis l'espace privé (fonctionne sans internet)
        previewMode.value = false;
        err = await OfflineMusic.play(t.id, title: t.title, key: t.key).timeout(const Duration(seconds: 20), onTimeout: () => 'Lecture trop longue à démarrer. Réessaie.');
        ok = err == null;
      } else {
        // Démarrage éclair : le début du titre complet est déjà sur l'appareil (voir MusicHead), le son part sans attendre le serveur
        if (canFull && MusicHead.supported) {
          final head = await MusicHead.read(t.id);
          if (head != null && gen == _gen) {
            previewMode.value = false;
            ok = await SoundPreview.playHead(t.key, head, () => fetchFullListenUrl(t.id), meta: _meta(t, 'Titre complet'));
            if (ok) {
              if (gen != _gen) return false;
              loading.value = false;
              _warmUpcoming();
              return true;
            }
          }
        }
        String? url = t.previewUrl;
        var full = false;
        if (url == null && t.studio != null) url = await MontageMusicPlayer.urlOf(MontageMusic.free(t.studio!)).timeout(const Duration(seconds: 6), onTimeout: () => null);
        if (canFull) {
          final f = await fetchFullListenUrl(t.id).timeout(const Duration(seconds: 8), onTimeout: () => null);
          if (f != null) {
            url = f;
            full = true;
          }
        }
        if (gen != _gen) return false;
        previewMode.value = t.isArtist && !full && !(t.sound?.isFree ?? false) && !own;
        if (url != null) {
          ok = await SoundPreview.play(t.key, url, meta: _meta(t, full ? 'Titre complet' : (t.isArtist ? 'Extrait de ${t.previewSec} s' : (t.genre ?? 'Musique Afrolook'))));
        }
      }
    } catch (_) {
      ok = false;
    } finally {
      if (gen == _gen) loading.value = false;
    }
    if (gen != _gen) return false;
    if (!ok) error.value = err ?? _failMessage();
    if (ok) _warmUpcoming();
    return ok;
  }

  /// Message d'échec : la raison technique (format non lu par l'iPhone, lecteur…) est ajoutée en petit pour nous aider à comprendre.
  static String _failMessage() {
    final why = SoundPreview.lastError;
    final base = 'Impossible de lire ce titre. Vérifie ta connexion et réessaie.';
    if (why == null || why.isEmpty) return base;
    if (why.contains('non pris en charge')) return 'Ce titre est dans un format que l’iPhone et l’iPad ne lisent pas ($why).';
    return '$base [${why.length > 90 ? why.substring(0, 90) : why}]';
  }

  static NowPlaying _meta(MusicTrack t, String subtitle) =>
      NowPlaying(key: t.key, title: t.title, subtitle: '${t.artist} · $subtitle', coverUrl: t.coverUrl);

  /// Écoute complète ouverte une fois par une pub récompensée (lien donné par le serveur).
  static Future<bool> playGranted(MusicTrack t, String url) async {
    final gen = ++_gen;
    current.value = t;
    if (!_queue.any((x) => x.key == t.key)) {
      _queue = [t];
      _index = 0;
    } else {
      _index = _queue.indexWhere((x) => x.key == t.key);
    }
    previewEnded.value = false;
    previewMode.value = false;
    loading.value = true;
    final ok = await SoundPreview.play(t.key, url, meta: _meta(t, 'Titre complet · écoute avec pub'));
    if (gen == _gen) loading.value = false;
    if (!ok && gen == _gen) error.value = 'Impossible de lire ce titre. Vérifie ta connexion.';
    return ok;
  }

  // ── Commandes ──

  static Future<void> togglePlay() async {
    final t = current.value;
    if (t == null) return;
    if (previewEnded.value) {
      // Réécouter l'extrait depuis le début
      await _startCurrent(interstitial: false);
      return;
    }
    if (SoundPreview.playing.value == t.key) {
      await SoundPreview.pause();
    } else if (SoundPreview.now.value?.key == t.key) {
      await SoundPreview.resume();
      if (SoundPreview.playing.value != t.key) await _startCurrent(interstitial: false);
    } else {
      await _startCurrent(interstitial: false);
    }
  }

  static void toggleShuffle() {
    shuffle.value = !shuffle.value;
    _peeked = null;
    _warmUpcoming();
  }

  static int _pickNext() => pickNext(_queue.length, _index, shuffle.value, _history, _rnd);

  /// Titre suivant : dans l'ordre (en boucle), ou au hasard sans répéter le titre en cours ni les 3 derniers joués.
  @visibleForTesting
  static int pickNext(int length, int index, bool shuffle, List<int> history, Random rnd) {
    if (length <= 1) return index;
    if (shuffle) {
      final recent = history.reversed.take(min(3, length - 1)).toSet()..add(index);
      final candidates = [for (var i = 0; i < length; i++) if (!recent.contains(i)) i];
      if (candidates.isEmpty) return (index + 1) % length;
      return candidates[rnd.nextInt(candidates.length)];
    }
    return (index + 1) % length;
  }

  static Future<bool> next({bool interstitial = true}) async {
    if (_queue.isEmpty) return false;
    final n = _peeked ?? _pickNext();
    _peeked = null;
    if (n == _index && _queue.length <= 1) {
      return _startCurrent(interstitial: false);
    }
    _history.add(_index);
    if (_history.length > 20) _history.removeAt(0);
    _index = n;
    return _startCurrent(interstitial: interstitial);
  }

  /// Précédent : au-delà de 5 secondes, on revient au début du titre ; sinon on repart au titre d'avant.
  static Future<void> previous() async {
    if (_queue.isEmpty) return;
    final pos = await SoundPreview.position.first.timeout(const Duration(milliseconds: 400), onTimeout: () => Duration.zero);
    if (pos.inSeconds > 5 && !previewEnded.value) {
      await SoundPreview.seek(Duration.zero);
      return;
    }
    if (_history.isNotEmpty) {
      _index = _history.removeLast();
    } else {
      _index = (_index - 1 + _queue.length) % _queue.length;
    }
    _peeked = null;
    await _startCurrent(interstitial: false);
  }

  /// Ferme le lecteur : coupe le son et vide la file.
  static Future<void> close() async {
    _gen++;
    _playlistId = null;
    _queue = const [];
    _index = -1;
    _history.clear();
    _peeked = null;
    current.value = null;
    previewEnded.value = false;
    previewMode.value = false;
    loading.value = false;
    _suspenders.clear();
    _resumeAfter = false;
    unawaited(MusicVoice.stop());
    await SoundPreview.stop();
    SoundPreview.now.value = null;
  }

  // ── Fin d'un titre ──

  static void _onCompleted(String key) {
    final t = current.value;
    if (t == null || t.key != key) return;
    if (_streamCountedKey != t.key) _countStream(t); // titre ou extrait court écouté en entier
    if (previewMode.value) {
      unawaited(_onPreviewEnded(t));
      return;
    }
    if (_queue.length > 1 || shuffle.value) {
      unawaited(next(interstitial: false));
    }
  }

  /// Fin de l'extrait gratuit : une voix annonce « Extrait gratuit terminé. Pour écouter la suite, achetez ce titre pour N pièces. »,
  /// puis la lecture passe au titre suivant. Sans titre suivant (titre seul), la feuille d'achat s'ouvre après la voix.
  static Future<void> _onPreviewEnded(MusicTrack t) async {
    previewEnded.value = true;
    final g = _gen;
    await MusicVoice.say(MusicVoice.endOfPreview(t.saleCoins));
    if (g != _gen || current.value?.key != t.key) return; // la personne a déjà fait autre chose
    if (_queue.length > 1) {
      skippedPaid.value = t;
      await next(interstitial: false);
    } else {
      _ends.add(t);
    }
  }

  // ── Préchargement : les 2 titres suivants sont prêts avant qu'on les demande ──

  static void _warmUpcoming() {
    if (_queue.length <= 1) return;
    _peeked ??= _pickNext();
    final ids = <int>[_peeked!];
    if (!shuffle.value) ids.add((_peeked! + 1) % _queue.length);
    for (final i in ids) {
      if (i == _index) continue;
      final t = _queue[i];
      _warmHead(t);
      final u = t.previewUrl;
      if (u != null && u.isNotEmpty) {
        unawaited(MusicCache.warm(u));
      } else if (t.studio != null) {
        MontageMusicPlayer.urlOf(MontageMusic.free(t.studio!)).then((url) {
          if (url != null) MusicCache.warm(url);
        }).catchError((_) {});
      }
    }
  }

  /// Début du titre complet gardé d'avance (chiffré, privé) pour un premier « Lecture » instantané. Seulement si la personne a le droit
  /// d'écouter ce titre en entier, et pas s'il est déjà téléchargé hors ligne.
  static void _warmHead(MusicTrack t) {
    if (!MusicHead.supported || !t.isArtist) return;
    if (!(isOwned(t) || t.isMine || (t.sound?.isFree ?? false))) return;
    if (OfflineMusic.has(t.id)) return;
    MusicHead.prefetch(t.id, fetchFullListenUrl);
  }

  /// Préchargement des premiers titres d'une liste affichée (pour un départ immédiat au toucher).
  static final Set<String> _warmed = {};
  static void warmList(Iterable<MusicTrack> tracks, {int max = 8}) {
    for (final t in tracks.take(4)) {
      _warmHead(t);
    }
    final fresh = <String>[];
    for (final t in tracks.take(max)) {
      final u = t.previewUrl;
      if (u != null && _warmed.add(u)) fresh.add(u);
    }
    if (fresh.isNotEmpty) unawaited(MusicCache.warmAll(fresh));
    for (final t in tracks.where((t) => t.studio != null).take(4)) {
      if (!_warmed.add('free:${t.id}')) continue;
      MontageMusicPlayer.urlOf(MontageMusic.free(t.studio!)).then((u) {
        if (u != null) MusicCache.warm(u);
      }).catchError((_) {});
    }
  }

  // ── Pause devant une vidéo (ou autre média) et reprise à la fin ──

  static final Set<Object> _suspenders = <Object>{};
  static bool _resumeAfter = false;

  /// Une page avec une vidéo (ou un appel) s'ouvre : la musique se met en pause, puis reprend à [release].
  static void suspend(Object owner) {
    if (current.value != null && SoundPreview.playing.value == current.value!.key) {
      _resumeAfter = true;
      unawaited(SoundPreview.pause());
    }
    _suspenders.add(owner);
  }

  static void release(Object owner) {
    _suspenders.remove(owner);
    if (_suspenders.isEmpty && _resumeAfter) {
      _resumeAfter = false;
      final t = current.value;
      if (t != null && SoundPreview.now.value?.key == t.key) unawaited(SoundPreview.resume());
    }
  }
}
