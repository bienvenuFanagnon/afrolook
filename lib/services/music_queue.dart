// File d'attente de la musique d'Afrolook : suivant, précédent, aléatoire, préchargement, fin d'extrait gratuit.
// Un seul lecteur dans toute l'application (SoundPreview) ; ce fichier décide QUOI jouer ensuite et prévient l'interface.

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../pages/studio/artist_marketplace.dart';
import '../pages/studio/artist_sound_common.dart';
import '../pages/studio/montage/montage_music.dart';
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
  bool get isArtist => kind == 'artist';

  /// Gratuit (musique Afrolook ou son d'artiste gratuit). Un titre de la bibliothèque est « payé ».
  bool get isFree => sound != null ? sound!.isFree : !owned && kind == 'free';

  /// Prix pour l'utiliser dans un post (pièces), 0 = gratuit.
  int get useCoins => sound != null && !sound!.isFree ? sound!.unitPrice : 0;

  /// Prix pour acheter le titre complet (pièces), 0 = pas en vente.
  int get saleCoins => sound != null && sound!.forSale ? sound!.saleCoins : 0;

  /// Part de l'artiste sur un achat (60 %).
  int get saleShare => (saleCoins * 60) ~/ 100;

  bool get isMine => sound != null && sound!.userId == FirebaseAuth.instance.currentUser?.uid;
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

  /// Message d'erreur à montrer (une seule fois) : lecture impossible…
  static final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  /// Titres achetés par la personne (lu en direct depuis MusicLibrary).
  static final ValueNotifier<Set<String>> ownedIds = ValueNotifier<Set<String>>(<String>{});

  /// Fin d'un extrait gratuit : l'interface ouvre la feuille « Tu aimes ce titre ? ».
  static final StreamController<MusicTrack> _ends = StreamController<MusicTrack>.broadcast();
  static Stream<MusicTrack> get ends => _ends.stream;

  /// Pub plein écran « entre deux titres » (branchée par l'interface, qui connaît l'utilisateur).
  static Future<void> Function()? interstitialHook;

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
  static void start() {
    if (_wired) return;
    _wired = true;
    SoundPreview.completed.listen(_onCompleted);
    FirebaseAuth.instance.authStateChanges().listen(_watchOwned);
    _watchOwned(FirebaseAuth.instance.currentUser);
  }

  static void _watchOwned(User? u) {
    if (u?.uid == _ownedUid) return;
    _ownedUid = u?.uid;
    _ownedSub?.cancel();
    ownedIds.value = <String>{};
    if (u == null) return;
    _ownedSub = FirebaseFirestore.instance.collection('MusicLibrary').where('uid', isEqualTo: u.uid).snapshots().listen((s) {
      ownedIds.value = {for (final d in s.docs) '${d.data()['soundId']}'};
    }, onError: (_) {});
  }

  static bool isOwned(MusicTrack t) => t.owned || ownedIds.value.contains(t.id);

  // ── Lancer ──

  /// Lance [queue] au titre [index]. Les titres suivants de la liste sont ceux du « suivant » (ou de l'aléatoire).
  static Future<bool> play(List<MusicTrack> queue, int index, {bool interstitial = true}) async {
    start();
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

  static Future<bool> _startCurrent({required bool interstitial}) async {
    final t = _queue[_index];
    final gen = ++_gen;
    current.value = t;
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
          ok = await SoundPreview.play(t.key, url, meta: _meta(t, full ? 'Titre complet' : (t.isArtist ? 'Extrait de 30 s' : (t.genre ?? 'Musique Afrolook'))));
        }
      }
    } catch (_) {
      ok = false;
    } finally {
      if (gen == _gen) loading.value = false;
    }
    if (gen != _gen) return false;
    if (!ok) error.value = err ?? 'Impossible de lire ce titre. Vérifie ta connexion et réessaie.';
    if (ok) _warmUpcoming();
    return ok;
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

  static int _pickNext() {
    if (_queue.length <= 1) return _index;
    if (shuffle.value) {
      // Aléatoire sans répéter les derniers titres joués
      final recent = _history.reversed.take(min(3, _queue.length - 1)).toSet()..add(_index);
      final candidates = [for (var i = 0; i < _queue.length; i++) if (!recent.contains(i)) i];
      if (candidates.isEmpty) return (_index + 1) % _queue.length;
      return candidates[_rnd.nextInt(candidates.length)];
    }
    return (_index + 1) % _queue.length;
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
    await SoundPreview.stop();
    SoundPreview.now.value = null;
  }

  // ── Fin d'un titre ──

  static void _onCompleted(String key) {
    final t = current.value;
    if (t == null || t.key != key) return;
    if (previewMode.value) {
      previewEnded.value = true;
      _ends.add(t);
      return;
    }
    if (_queue.length > 1 || shuffle.value) {
      unawaited(next(interstitial: false));
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

  /// Préchargement des premiers titres d'une liste affichée (pour un départ immédiat au toucher).
  static final Set<String> _warmed = {};
  static void warmList(Iterable<MusicTrack> tracks, {int max = 8}) {
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
