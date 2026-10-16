// ignore_for_file: experimental_member_use
// Éléments communs aux pages des sons d'artistes : prix, lecture d'un extrait, signalement.

import 'dart:async';

import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Prix d'un son d'artiste payant (AppConfig/studio, lu une fois) : ce que paie la personne et ce que touche l'artiste.
class ArtistSoundPricing {
  ArtistSoundPricing._();
  static int price = 5;
  static int share = 3;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final d = (await FirebaseFirestore.instance.collection('AppConfig').doc('studio').get()).data() ?? {};
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

  static void _wire() {
    if (_wired) return;
    _wired = true;
    _player.playerStateStream.listen((st) {
      final key = _key;
      if (st.processingState == ProcessingState.completed) {
        playing.value = null;
      } else if (key != null) {
        playing.value = st.playing ? key : null;
      }
    });
  }

  static Stream<Duration> get position => _player.positionStream;
  static Stream<Duration> get duration => _player.durationStream.where((d) => d != null).map((d) => d!);

  static MediaItem _item(String key, NowPlaying? meta) => MediaItem(
        id: key,
        title: meta?.title ?? 'Afrolook Musique',
        artist: meta?.subtitle ?? 'Afrolook',
        artUri: (meta?.coverUrl != null && meta!.coverUrl!.isNotEmpty) ? Uri.tryParse(meta.coverUrl!) : null,
      );

  static Future<bool> _start(String key, AudioSource source, bool loop, NowPlaying? meta) async {
    _wire();
    try {
      await _player.stop();
      _key = key;
      if (meta != null) now.value = meta;
      await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      await _player.setAudioSource(source);
      unawaited(_player.play());
      playing.value = key;
      return true;
    } catch (_) {
      playing.value = null;
      return false;
    }
  }

  /// Joue [url] ; [key] identifie le son (pour afficher le bon bouton lecture/pause).
  static Future<bool> play(String key, String url, {bool loop = false, NowPlaying? meta}) =>
      _start(key, AudioSource.uri(Uri.parse(url), tag: _item(key, meta)), loop, meta);

  /// Joue un titre déchiffré en mémoire (téléchargement protégé) : rien n'est écrit en clair sur l'appareil.
  static Future<bool> playBytes(String key, Uint8List bytes, {NowPlaying? meta}) =>
      _start(key, _BytesSource(bytes, _item(key, meta)), false, meta);

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
    playing.value = null;
    try {
      await _player.stop();
    } catch (_) {}
  }
}

/// Source audio servie depuis la mémoire (octets déjà déchiffrés), avec lecture par morceaux demandée par le lecteur.
class _BytesSource extends StreamAudioSource {
  _BytesSource(this._bytes, MediaItem tag) : super(tag: tag);
  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final e = end ?? _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: e - s,
      offset: s,
      stream: Stream.value(_bytes.sublist(s, e)),
      contentType: 'audio/mp4',
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
