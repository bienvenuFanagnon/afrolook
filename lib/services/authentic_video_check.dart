import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';
import 'post_source_link.dart';

/// Résultat de l'examen d'une vidéo choisie dans la galerie.
class AuthenticResult {
  const AuthenticResult.ok()
      : ok = true,
        mark = null;
  const AuthenticResult.foreign(this.mark) : ok = false;

  final bool ok;

  /// tiktok, instagram, facebook, snapchat ou other (valeurs acceptées par l'API).
  final String? mark;
}

/// Vidéos authentiques : Afrolook n'accepte pas les vidéos téléchargées d'autres réseaux (TikTok, Instagram…). Solution gratuite, sur le téléphone :
/// quelques images de la vidéo passent dans la reconnaissance de texte de Google (ML Kit, hors ligne) qui lit les marques et les @pseudos incrustés.
/// Les vidéos montées avec un éditeur (CapCut, InShot…) ou filmées dans l'application ne portent pas ces marques et passent.
/// En cas de doute ou d'erreur, la vidéo passe : on ne bloque jamais à tort sur un échec technique.
class AuthenticVideoCheck {
  AuthenticVideoCheck._();

  /// Marques cherchées (Snapchat n'est PAS bloqué : beaucoup de créateurs s'en servent pour créer leurs contenus). `strong` : une seule image suffit (le filigrane de TikTok est très reconnaissable) ; sinon il en faut deux (jamais sur un mot isolé).
  static const _marks = <(String, List<String>, bool)>[
    ('tiktok', ['tiktok', 'douyin'], true),
    ('instagram', ['instagram'], false),
    ('facebook', ['facebook'], false),
    ('other', ['likee', 'kwai', 'triller'], false),
  ];

  /// Vrai si les textes lus dans une image contiennent la marque.
  static bool containsMark(String text, List<String> words) {
    final t = text.toLowerCase().replaceAll(RegExp(r'[\s_\-.]'), '');
    return words.any(t.contains);
  }

  /// Marque trouvée à partir du texte lu dans chaque image (null si la vidéo est propre). Séparé de l'examen pour être testé sans téléphone.
  static String? decide(List<String> frameTexts) {
    for (final (mark, words, strong) in _marks) {
      final hits = frameTexts.where((t) => containsMark(t, words)).length;
      if (hits >= (strong ? 1 : 2)) return mark;
    }
    return null;
  }

  static Future<AuthenticResult> scan(String path) async {
    if (kIsWeb) return const AuthenticResult.ok();
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      var durationMs = 0;
      final vc = VideoPlayerController.file(File(path));
      try {
        await vc.initialize().timeout(const Duration(seconds: 8));
        durationMs = vc.value.duration.inMilliseconds;
      } finally {
        await vc.dispose();
      }
      if (durationMs <= 0) return const AuthenticResult.ok();
      final times = <int>{
        300,
        (durationMs * .25).round(),
        (durationMs * .5).round(),
        (durationMs * .75).round(),
        if (durationMs > 2500) durationMs - 1200,   // l'écran de fin de TikTok
      }.where((t) => t >= 0 && t < durationMs).toList()
        ..sort();
      final texts = <String>[];
      for (final t in times) {
        final f = await VideoThumbnail.thumbnailFile(video: path, imageFormat: ImageFormat.JPEG, timeMs: t, maxWidth: 720, quality: 70);
        if (f == null) continue;
        final r = await recognizer.processImage(InputImage.fromFilePath(f));
        texts.add(r.text);
        try {
          await File(f).delete();
        } catch (_) {}
      }
      final mark = decide(texts);
      return mark == null ? const AuthenticResult.ok() : AuthenticResult.foreign(mark);
    } catch (_) {
      return const AuthenticResult.ok();
    } finally {
      await recognizer.close();
    }
  }

  /// Même examen sur une vidéo qui se lit (adresse du film et durée déjà connues) : sert aux contrôles d'authenticité pendant les lectures.
  /// Rend la marque vue (tiktok, instagram…), « clean » si rien, null si l'examen n'a pas pu se faire (rien n'est envoyé dans ce cas).
  static Future<String?> scanUrl(String url, int durationMs) async {
    if (kIsWeb || durationMs <= 0) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final times = <int>{
        300,
        (durationMs * .25).round(),
        (durationMs * .5).round(),
        (durationMs * .75).round(),
        if (durationMs > 2500) durationMs - 1200,
      }.where((t) => t >= 0 && t < durationMs).toList()
        ..sort();
      final texts = <String>[];
      for (final t in times) {
        final f = await VideoThumbnail.thumbnailFile(video: url, imageFormat: ImageFormat.JPEG, timeMs: t, maxWidth: 720, quality: 70);
        if (f == null) continue;
        final r = await recognizer.processImage(InputImage.fromFilePath(f));
        texts.add(r.text);
        try {
          await File(f).delete();
        } catch (_) {}
      }
      if (texts.length < 2) return null;   // trop peu d'images lues : pas de verdict
      return decide(texts) ?? 'clean';
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
  }

  static String _name(String mark) => switch (mark) {
        'tiktok' => 'TikTok',
        'instagram' => 'Instagram',
        'facebook' => 'Facebook',
        _ => tr('d\'autres réseaux'),
      };

  /// Examine la vidéo choisie. Rend vrai pour continuer (vidéo propre, ou « C'est ma vidéo » : la modération la vérifiera avant publication), faux si la personne renonce.
  static Future<bool> gate(BuildContext context, String path, {bool allowClaim = true}) async {
    PostExternalLink.clear();
    final c = AppColors.of(context);
    // petit message pendant l'examen (1 à 3 secondes)
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.accent)),
              const SizedBox(width: 14),
              Material(color: Colors.transparent, child: Text(tr('Vérification de la vidéo…'), style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      ),
    );
    final res = await scan(path);
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (res.ok || !context.mounted) return true;

    final mark = res.mark!;
    final own = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(tr('Vidéo non acceptée'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            tr('Afrolook est le réseau des vidéos authentiques : les vidéos téléchargées de {a} ne sont pas acceptées. Publie tes propres vidéos, filmées avec l\'application ou montées avec un éditeur comme CapCut.', {'a': _name(mark)}),
            style: TextStyle(color: c.textSecondary, height: 1.4, fontSize: 14),
          ),
          if (allowClaim) ...[
            const SizedBox(height: 10),
            Text(tr('Cette vidéo est la tienne ? Notre équipe la vérifie avant de la publier.'), style: TextStyle(color: c.textSecondary, height: 1.4, fontSize: 13)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Compris'), style: TextStyle(color: c.textSecondary))),
          if (allowClaim)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent),
            child: Text(tr('C\'est ma vidéo'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (own == true && allowClaim) {
      PostExternalLink.set(mark, own: true);
      return true;
    }
    return false;
  }
}
