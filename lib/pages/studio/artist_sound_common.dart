// Éléments communs aux pages des sons d'artistes : prix, lecture d'un extrait, signalement.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
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

/// Lecteur d'extrait (un seul à la fois dans l'app) : l'extrait public de 30 s, jamais l'original.
class SoundPreview {
  SoundPreview._();
  static final AudioPlayer _player = AudioPlayer();
  static final ValueNotifier<String?> playing = ValueNotifier<String?>(null);
  static bool _wired = false;

  static void _wire() {
    if (_wired) return;
    _wired = true;
    _player.onPlayerComplete.listen((_) => playing.value = null);
  }

  static Stream<Duration> get position => _player.onPositionChanged;
  static Stream<Duration> get duration => _player.onDurationChanged;

  /// Joue [url] ; [key] identifie le son (pour afficher le bon bouton lecture/pause).
  static Future<bool> play(String key, String url, {bool loop = false}) async {
    _wire();
    try {
      await _player.stop();
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await _player.play(UrlSource(url));
      playing.value = key;
      return true;
    } catch (_) {
      playing.value = null;
      return false;
    }
  }

  static Future<void> seek(Duration d) async {
    try {
      await _player.seek(d);
    } catch (_) {}
  }

  static Future<void> stop() async {
    playing.value = null;
    try {
      await _player.stop();
    } catch (_) {}
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
