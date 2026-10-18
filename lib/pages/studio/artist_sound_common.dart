// ignore_for_file: experimental_member_use
// Éléments communs aux pages des sons d'artistes : prix, lecture d'un extrait, signalement.

import 'package:afrotok/services/read_meter.dart';
import 'dart:async';

import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import '../../services/music_head.dart';
import '../../utils/audio_format.dart';
import '../../utils/fnv.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';

import '../../theme/app_colors.dart';
import '../../utils/media_cdn.dart';

/// Prix d'un son d'artiste payant (AppConfig/studio, lu une fois) : ce que paie la personne et ce que touche l'artiste.
class ArtistSoundPricing {
  ArtistSoundPricing._();
  static int price = 5;
  static int share = 3;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final d = (await FirebaseFirestore.instance.collection('AppConfig').doc('studio').getM('artist_sound_common.dart:35')).data() ?? {};
      final p = (d['artistSoundPrice'] as num?)?.round();
      final s = (d['artistSoundShare'] as num?)?.round();
      if (p != null && p > 0) price = p;
      if (s != null && s >= 0) share = s.clamp(0, price);
      _loaded = true;
    } catch (_) {}
  }

  /// 25 pièces gagnées = 10 FCFA (barème de la conversion pièces → FCFA).
  static String fcfaOf(int coins) => '${(coins / 25 * 10).toStringAsFixed(coins % 5 == 0 ? 0 : 1)} FCFA';
}

/// Lien d'écoute du titre complet (gratuit, acheté ou à soi) : le serveur le délivre pour ~10 minutes ; mis en mémoire 8 minutes.
final Map<String, ({String url, DateTime at})> _fullUrls = {};

Future<String?> fetchFullListenUrl(String soundId) async {
  final hit = _fullUrls[soundId];
  if (hit != null && DateTime.now().difference(hit.at).inMinutes < 8) return hit.url;
  try {
    final r = await FirebaseFunctions.instance.httpsCallable('musicStreamUrl').call({'soundId': soundId});
    final url = (r.data as Map)['url'] as String?;
    if (url != null) _fullUrls[soundId] = (url: url, at: DateTime.now());
    return url;
  } catch (_) {
    return null;
  }
}

/// Lecteur d'extrait (un seul à la fois dans l'app) : l'extrait public de 30 s, jamais l'original.
/// Ce qui est lu (affiché dans le lecteur réduit de la page Musique).
class NowPlaying {
  const NowPlaying({required this.key, required this.title, this.subtitle, this.coverUrl});
  final String key;
  final String title;
  final String? subtitle;
  final String? coverUrl;
}

/// Petit cache disque des extraits et musiques gratuites : le 2e lancement (et les titres préchargés) démarre instantanément, sans réseau.
class MusicCache {
  MusicCache._();
  static Directory? _dir;
  static final Map<String, Future<File?>> _inflight = {};
  static const _maxFiles = 80;

  static Future<Directory?> _d() async {
    if (kIsWeb) return null;
    try {
      return _dir ??= await Directory('${(await getTemporaryDirectory()).path}/afrolook_music').create(recursive: true);
    } catch (_) {
      return null;
    }
  }

  static String _name(String url) {
    return '${fnv63(url)}.m4a';
  }

  /// Fichier déjà en cache pour [url], sinon null.
  static Future<File?> cached(String url) async {
    final d = await _d();
    if (d == null) return null;
    final f = File('${d.path}/${_name(url)}');
    try {
      if (await f.exists() && await f.length() > 2000) return f;
    } catch (_) {}
    return null;
  }

  /// Télécharge [url] en arrière-plan (extraits seulement, taille limitée à 3 Mo).
  static Future<File?> warm(String url) {
    if (kIsWeb || url.isEmpty) return Future.value(null);
    return _inflight[url] ??= _fetch(url).whenComplete(() => _inflight.remove(url));
  }

  static Future<File?> _fetch(String url) async {
    final d = await _d();
    if (d == null) return null;
    final f = File('${d.path}/${_name(url)}');
    try {
      if (await f.exists() && await f.length() > 2000) return f;
      final tmp = File('${f.path}.part');
      final res = await Dio().download(url, tmp.path, options: Options(receiveTimeout: const Duration(seconds: 15), sendTimeout: const Duration(seconds: 8)));
      if (res.statusCode == 200 && await tmp.length() > 2000 && await tmp.length() < 3 * 1024 * 1024) {
        await tmp.rename(f.path);
        unawaited(_trim(d));
        return f;
      }
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {}
    return null;
  }

  /// Précharge les premiers titres visibles (2 à la fois au plus).
  static Future<void> warmAll(Iterable<String> urls, {int max = 8}) async {
    final list = urls.where((u) => u.isNotEmpty).take(max).toList();
    for (var i = 0; i < list.length; i += 2) {
      await Future.wait(list.skip(i).take(2).map(warm));
    }
  }

  static Future<void> _trim(Directory d) async {
    try {
      final files = d.listSync().whereType<File>().where((f) => f.path.endsWith('.m4a')).toList();
      if (files.length <= _maxFiles) return;
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      for (final f in files.take(files.length - _maxFiles)) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  static bool isPreview(String url) => url.contains('artist_sound_previews') || url.contains('studio_music');
}

class SoundPreview {
  SoundPreview._();
  // Un seul lecteur dans toute l'application (just_audio_background n'en admet qu'un) : il continue quand l'écran est éteint
  // ou l'application fermée, avec les commandes de la notification et de l'écran verrouillé.
  static final AudioPlayer _player = AudioPlayer();
  static final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  /// Dernier titre lancé (reste renseigné en pause, pour reprendre depuis le lecteur réduit).
  static final ValueNotifier<NowPlaying?> now = ValueNotifier<NowPlaying?>(null);
  static bool _wired = false;
  static String? _key; // son en cours (avec ou sans fiche d'affichage)

  /// Un titre arrive à sa fin (renvoie sa clé) : la file d'attente enchaîne ou propose le titre complet.
  static final StreamController<String> _done = StreamController<String>.broadcast();
  static Stream<String> get completed => _done.stream;
  static String? get currentKey => _key;
  static bool _wasDone = false;
  static int _gen = 0; // numéro de lancement : un lancement plus récent annule le précédent

  static void _wire() {
    if (_wired) return;
    _wired = true;
    _player.playerStateStream.listen((st) {
      final key = _key;
      if (st.processingState == ProcessingState.completed) {
        playing.value = null;
        if (key != null && !_wasDone) _done.add(key); // une seule fois par fin de titre
        _wasDone = true;
        return;
      }
      _wasDone = false;
      if (key != null) playing.value = st.playing ? key : null;
    }, onError: (_) => playing.value = null);
  }

  static Stream<Duration> get position => _player.positionStream;
  static Stream<Duration> get duration => _player.durationStream.where((d) => d != null).map((d) => d!);

  static MediaItem _item(String key, NowPlaying? meta) => MediaItem(
        id: key,
        title: meta?.title ?? 'Afrolook Musique',
        artist: meta?.subtitle ?? 'Afrolook',
        artUri: (meta?.coverUrl != null && meta!.coverUrl!.isNotEmpty) ? Uri.tryParse(meta.coverUrl!) : null,
      );

  /// Dernière raison d'échec d'une lecture (pour l'afficher à la personne et nous aider à comprendre sur iPhone / iPad).
  static String? lastError;

  /// Session audio de l'iPhone / iPad : « lecture de musique » (son même en mode silencieux, reprise après un appel).
  /// D'autres lecteurs de l'application (messages vocaux, montage) la changent ; on la remet avant chaque titre.
  static Future<void> _ensureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (_) {}
  }

  /// Charge puis lance une source. Ne reste jamais bloqué : délai maximum, et un lancement plus récent annule celui-ci.
  static Future<bool> _start(String key, Future<AudioSource> Function() build, bool loop, NowPlaying? meta) async {
    _wire();
    final gen = ++_gen;
    lastError = null;
    try {
      _key = key;
      now.value = meta; // sans fiche d'affichage, on n'affiche pas un ancien titre
      try {
        await _player.stop().timeout(const Duration(seconds: 2), onTimeout: () {});
      } catch (_) {}
      await _ensureSession();
      final source = await build();
      if (gen != _gen) return false;
      await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off).timeout(const Duration(seconds: 3));
      await _player.setAudioSource(source, preload: true).timeout(const Duration(seconds: 12));
      if (gen != _gen) return false;
      unawaited(_player.play());
      playing.value = key;
      return true;
    } catch (e) {
      lastError = e is PlayerException ? 'lecteur ${e.code} : ${e.message}' : '$e';
      if (kDebugMode) debugPrint('[SoundPreview] $key : $lastError');
      if (gen == _gen) playing.value = null;
      return false;
    }
  }

  /// Dernier recours quand le lecteur refuse l'adresse (iPhone / iPad exigent un fichier au format annoncé) : le titre est téléchargé
  /// (40 Mo au plus), reconnu à son contenu, rangé sous la bonne extension, puis lu depuis le disque.
  static Future<bool> _viaFile(String key, String url, bool loop, NowPlaying? meta) async {
    if (kIsWeb) return false;
    try {
      final dir = await getTemporaryDirectory();
      final tmp = File('${dir.path}/snd_${fnv63(url)}.part');
      await Dio().download(url, tmp.path, options: Options(receiveTimeout: const Duration(seconds: 40)));
      final len = await tmp.length();
      if (len < 2000 || len > 40 * 1024 * 1024) {
        await tmp.delete().catchError((_) => tmp);
        return false;
      }
      final head = await tmp.openRead(0, 16).fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      final kind = AudioKind.sniff(head);
      if (!kind.appleCompatible && defaultTargetPlatform == TargetPlatform.iOS) {
        lastError = 'format ${kind.ext} non pris en charge sur iPhone / iPad';
        await tmp.delete().catchError((_) => tmp);
        return false;
      }
      final f = await tmp.rename('${dir.path}/snd_${fnv63(url)}.${kind.ext}');
      return await _start(key, () async => AudioSource.file(f.path, tag: _item(key, meta)), loop, meta);
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  /// Joue [url] ; [key] identifie le son (pour afficher le bon bouton lecture/pause).
  /// Les extraits et musiques gratuites passent par le cache disque (départ instantané au 2e lancement) ; si le CDN ne répond pas,
  /// on retombe sur Firebase Storage.
  static Future<bool> play(String key, String url, {bool loop = false, NowPlaying? meta}) async {
    final item = _item(key, meta);
    if (MusicCache.isPreview(url)) {
      final ok = await _start(key, () async {
        final f = await MusicCache.cached(url);
        if (f != null) return AudioSource.file(f.path, tag: item);
        unawaited(MusicCache.warm(url)); // la 2e écoute sera instantanée
        return AudioSource.uri(Uri.parse(url), tag: item);
      }, loop, meta);
      if (ok) return true;
      final fb = MediaCdn.original(url);
      if (fb != null && await _start(key, () async => AudioSource.uri(Uri.parse(fb), tag: item), loop, meta)) return true;
      return _viaFile(key, fb ?? url, loop, meta);
    }
    if (await _start(key, () async => AudioSource.uri(Uri.parse(url), tag: item), loop, meta)) return true;
    return _viaFile(key, url, loop, meta);
  }

  /// Démarrage éclair d'un titre dont le début est déjà sur l'appareil (voir [MusicHead]) : le son part tout de suite, la suite arrive
  /// du réseau pendant qu'on écoute (le lien d'écoute n'est demandé qu'au moment où il devient nécessaire).
  static Future<bool> playHead(String key, MusicHeadData head, Future<String?> Function() urlProvider, {NowPlaying? meta}) =>
      _start(key, () async => HeadStartSource(head: head.bytes, total: head.total, kind: head.kind, urlProvider: urlProvider, tag: _item(key, meta)), false, meta);

  /// Joue un titre déchiffré en mémoire (téléchargement protégé) : rien n'est écrit en clair sur l'appareil.
  static Future<bool> playBytes(String key, Uint8List bytes, {NowPlaying? meta}) =>
      _start(key, () async => _BytesSource(bytes, _item(key, meta)), false, meta);

  static Future<void> seek(Duration d) async {
    try {
      await _player.seek(d);
    } catch (_) {}
  }

  static Future<void> pause() async {
    playing.value = null;
    try {
      await _player.pause();
    } catch (_) {}
  }

  static Future<void> resume() async {
    final k = _key;
    if (k == null) return;
    try {
      playing.value = k;
      unawaited(_player.play());
    } catch (_) {}
  }

  static Future<void> stop() async {
    _gen++;
    playing.value = null;
    try {
      await _player.stop();
    } catch (_) {}
  }
}

/// Source audio servie depuis la mémoire (octets déjà déchiffrés), avec lecture par morceaux demandée par le lecteur.
class _BytesSource extends StreamAudioSource {
  _BytesSource(this._bytes, MediaItem tag) : _mime = AudioKind.sniffBytes(_bytes).mime, super(tag: tag);
  final Uint8List _bytes;
  final String _mime; // le vrai type du fichier : iPhone et iPad refusent un mp3 annoncé comme « audio/mp4 »

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: e - s,
      offset: s,
      stream: Stream.value(_bytes.sublist(s, e)),
      contentType: _mime,
    );
  }
}

/// Bouton lecture / pause d'un extrait.
class SoundPlayButton extends StatelessWidget {
  const SoundPlayButton({super.key, required this.soundKey, required this.url, this.size = 34, this.color});
  final String soundKey;
  final String? url;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.of(context).primary;
    return ValueListenableBuilder<String?>(
      valueListenable: SoundPreview.playing,
      builder: (_, now, __) {
        final on = now == soundKey;
        return IconButton(
          tooltip: on ? 'Pause' : 'Écouter l’extrait',
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: size + 8, height: size + 8),
          onPressed: url == null
              ? null
              : () async {
                  if (on) {
                    await SoundPreview.stop();
                  } else {
                    final ok = await SoundPreview.play(soundKey, url!);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire ce son. Vérifie ta connexion.')));
                    }
                  }
                },
          icon: Icon(on ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: size, color: url == null ? c.withValues(alpha: .3) : c),
        );
      },
    );
  }
}

const kReportReasons = <(String, String)>[
  ('copyright', '©️ Ce son m’appartient / droits d’auteur'),
  ('stolen', '🎵 Ce morceau est copié ou volé à un autre artiste'),
  ('offensive', '🚫 Contenu choquant ou haineux'),
  ('spam', '📢 Spam ou publicité déguisée'),
  ('other', '💬 Autre problème'),
];

/// Signaler un son : un signalement par personne et par son ; à 3, le son est suspendu en attendant l'administrateur.
Future<void> reportArtistSound(BuildContext context, String soundId, String title) async {
  final c = AppColors.of(context);
  final note = TextEditingController();
  String? reason;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Signaler « $title »', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final r in kReportReasons)
              RadioListTile<String>(
                value: r.$1,
                groupValue: reason,
                onChanged: (v) => setS(() => reason = v),
                activeColor: c.primary,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(r.$2, style: TextStyle(color: c.textPrimary, fontSize: 13)),
              ),
            TextField(
              controller: note,
              maxLines: 2,
              maxLength: 300,
              style: TextStyle(color: c.textPrimary, fontSize: 13),
              decoration: InputDecoration(hintText: 'Précise si tu veux (facultatif)', hintStyle: TextStyle(color: c.textSecondary), counterText: ''),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
          TextButton(onPressed: reason == null ? null : () => Navigator.pop(ctx, true), child: const Text('Signaler', style: TextStyle(color: Colors.red))),
        ],
      ),
    ),
  );
  final text = note.text.trim();
  note.dispose();
  if (ok != true || reason == null || !context.mounted) return;
  String msg;
  try {
    final r = await FirebaseFunctions.instance.httpsCallable('artistSoundReport').call({'soundId': soundId, 'reason': reason, 'note': text});
    final d = Map<String, dynamic>.from(r.data as Map);
    msg = d['already'] == true ? 'Tu as déjà signalé ce son.' : 'Merci, ton signalement a été envoyé à l’équipe.';
  } on FirebaseFunctionsException catch (e) {
    msg = e.message ?? 'Signalement impossible.';
  } catch (_) {
    msg = 'Signalement impossible. Vérifie ta connexion.';
  }
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
