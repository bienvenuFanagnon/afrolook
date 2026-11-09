import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';
import 'nsfw_check.dart';
import 'post_source_link.dart';

/// Résultat de l'examen d'une vidéo choisie dans la galerie.
class AuthenticResult {
  const AuthenticResult.ok()
      : ok = true,
        mark = null;
  const AuthenticResult.foreign(this.mark) : ok = false;
  /// Contenu sexuellement explicite vu par le modèle gratuit du téléphone (mark = 'explicit').
  const AuthenticResult.explicit()
      : ok = false,
        mark = 'explicit';

  final bool ok;

  /// tiktok, instagram, facebook, snapchat ou other (valeurs acceptées par l'API).
  final String? mark;
}

/// Vidéos authentiques : Afrolook n'accepte pas les vidéos téléchargées d'autres réseaux (TikTok, Instagram…). Solution gratuite, sur le téléphone :
/// quelques images de la vidéo passent dans la reconnaissance de texte de Google (ML Kit, hors ligne) qui lit le nom des réseaux incrustés (jamais un simple @pseudo).
/// Les vidéos montées avec un éditeur (CapCut, InShot…) ou filmées dans l'application ne portent pas ces marques et passent.
/// En cas de doute ou d'erreur, la vidéo passe : on ne bloque jamais à tort sur un échec technique.
class AuthenticVideoCheck {
  AuthenticVideoCheck._();

  /// Noms de réseaux cherchés (TikTok, Instagram, Facebook, Snapchat…). `strong` : une seule image suffit (le filigrane de TikTok est très reconnaissable) ; sinon il en faut deux (jamais sur un mot isolé).
  static const _marks = <(String, List<String>, bool)>[
    ('tiktok', ['tiktok', 'douyin'], true),
    ('instagram', ['instagram'], false),
    ('facebook', ['facebook'], false),
    ('snapchat', ['snapchat'], false),
    ('other', ['likee', 'kwai', 'triller'], false),
  ];

  /// Vrai si les textes lus dans une image contiennent la marque.
  static bool containsMark(String text, List<String> words) {
    final t = text.toLowerCase().replaceAll(RegExp(r'[\s_\-.]'), '');
    return words.any(t.contains);
  }

  /// Marque trouvée à partir du texte lu dans chaque image (null si la vidéo est propre). Séparé de l'examen pour être testé sans téléphone.
  /// Seul le NOM d'un réseau compte (TikTok : une image suffit ; les autres : deux images). Un @pseudo ne bloque JAMAIS à lui seul : un @nom peut être le pseudo
  /// de la personne, une boutique, un ami cité, un sous-titre (décision du propriétaire, 09/11/2026 : seuls les noms de plateformes sont bloqués).
  static String? decide(List<String> frameTexts) {
    for (final (mark, words, strong) in _marks) {
      final hits = frameTexts.where((t) => containsMark(t, words)).length;
      if (hits >= (strong ? 1 : 2)) return mark;
    }
    return null;
  }

  /// Marque trouvée dans UNE image isolée (photo de publication, couverture) : le nom d'un réseau seulement (un @pseudo ne bloque pas).
  static String? decideImage(String text) {
    for (final (mark, words, _) in _marks) {
      if (containsMark(text, words)) return mark;
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
      final nsfw = <List<double>>[];
      for (final t in times) {
        final f = await VideoThumbnail.thumbnailFile(video: path, imageFormat: ImageFormat.JPEG, timeMs: t, maxWidth: 720, quality: 70);
        if (f == null) continue;
        final r = await recognizer.processImage(InputImage.fromFilePath(f));
        texts.add(r.text);
        final sc = await NsfwCheck.score(f);   // contenu explicite : modèle gratuit sur le téléphone
        if (sc != null) nsfw.add(sc);
        try {
          await File(f).delete();
        } catch (_) {}
      }
      if (NsfwCheck.decide(nsfw)) return const AuthenticResult.explicit();
      final mark = decide(texts);
      return mark == null ? const AuthenticResult.ok() : AuthenticResult.foreign(mark);
    } catch (_) {
      return const AuthenticResult.ok();
    } finally {
      await recognizer.close();
    }
  }

  /// Temps maximal d'une analyse pendant une lecture : au-delà, rien n'est envoyé.
  static const scanMaxDuration = Duration(seconds: 20);

  /// Les 3 images lues pendant une lecture : le début, le milieu et la fin (l'écran de fin de TikTok, 1,2 s avant la fin ; 85 % de la durée si la vidéo est très courte).
  @visibleForTesting
  static List<int> frameTimes(int durationMs) =>
      <int>{300, (durationMs * .5).round(), durationMs > 2500 ? durationMs - 1200 : (durationMs * .85).round()}.where((t) => t >= 0 && t < durationMs).toList()..sort();

  /// Même examen sur une vidéo qui se lit (adresse du film et durée déjà connues) : sert aux contrôles d'authenticité pendant les lectures.
  /// Rend la marque vue (tiktok, instagram…), « clean » si rien, null si l'examen n'a pas pu se faire (rien n'est envoyé dans ce cas).
  static Future<String?> scanUrl(String url, int durationMs) async {
    if (kIsWeb || durationMs <= 0) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final deadline = DateTime.now().add(scanMaxDuration);
    try {
      final times = frameTimes(durationMs);
      final texts = <String>[];
      final nsfw = <List<double>>[];
      for (final t in times) {
        // l'analyse continue même si la personne passe à la vidéo suivante (le verdict compte), mais pas au-delà de 20 s ; on laisse respirer la lecture entre deux images
        if (DateTime.now().isAfter(deadline)) return null;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final f = await VideoThumbnail.thumbnailFile(video: url, imageFormat: ImageFormat.JPEG, timeMs: t, maxWidth: 480, quality: 60);
        if (f == null) continue;
        final r = await recognizer.processImage(InputImage.fromFilePath(f));
        texts.add(r.text);
        final sc = await NsfwCheck.score(f);
        if (sc != null) nsfw.add(sc);
        try {
          await File(f).delete();
        } catch (_) {}
      }
      if (texts.length < 2) return null;   // trop peu d'images lues : pas de verdict
      if (NsfwCheck.decide(nsfw)) return 'explicit';
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
        'snapchat' => 'Snapchat',
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

    return _blocked(context, res.mark!, allowClaim);
  }

  /// Examine une IMAGE choisie dans la galerie (contenu sexuellement explicite seulement) : photo de publication, image de couverture, images d'un contenu payant.
  static Future<bool> gateImage(BuildContext context, String path, {bool allowClaim = true}) async {
    PostExternalLink.clear();
    final sc = await NsfwCheck.score(path);
    if (sc != null && NsfwCheck.decide([sc]) && context.mounted) return _blocked(context, 'explicit', allowClaim);
    // image téléchargée d'un autre réseau : nom du réseau incrusté (jamais un simple @pseudo) (lecture de texte gratuite, sur le téléphone)
    if (kIsWeb || !context.mounted) return true;
    String? mark;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final r = await recognizer.processImage(InputImage.fromFilePath(path));
      mark = decideImage(r.text);
    } catch (_) {
      mark = null;   // échec technique : l'image passe
    } finally {
      await recognizer.close();
    }
    if (mark == null || !context.mounted) return true;
    return _blocked(context, mark, allowClaim, image: true);
  }

  /// Contenu déjà publié sur Afrolook par un autre compte : message de refus ; « C'est le mien » envoie à la modération (publication en attente de vérification).
  /// Rend vrai pour continuer (réclamation faite), faux si la personne renonce.
  static Future<bool> duplicateDialog(BuildContext context, {required String author, required bool video}) async {
    final c = AppColors.of(context);
    final own = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(tr('Contenu déjà publié'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            author.isEmpty
                ? tr('Ce contenu existe déjà sur Afrolook. Afrolook est le réseau des contenus authentiques : on ne republie pas le contenu d\'un autre compte.')
                : tr('Ce contenu existe déjà sur Afrolook (publié par @{a}). Afrolook est le réseau des contenus authentiques : on ne republie pas le contenu d\'un autre compte.', {'a': author}),
            style: TextStyle(color: c.textSecondary, height: 1.4, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(tr('C\'est ton contenu ? Notre équipe le vérifie avant de le publier.'), style: TextStyle(color: c.textSecondary, height: 1.4, fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Compris'), style: TextStyle(color: c.textSecondary))),
          FilledButton(
            key: const ValueKey('duplicate_own'),
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent),
            child: Text(video ? tr('C\'est ma vidéo') : tr('C\'est mon image'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (own == true) {
      PostExternalLink.set('duplicate', own: true);
      return true;
    }
    return false;
  }

  /// Message de refus (marque d'un autre réseau ou contenu explicite) ; « C'est ma vidéo » / « C'est une erreur » envoie à la modération (si [allowClaim]).
  static Future<bool> _blocked(BuildContext context, String mark, bool allowClaim, {bool image = false}) async {
    final c = AppColors.of(context);
    final own = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(mark == 'explicit' ? tr('Contenu non accepté') : (image ? tr('Image non acceptée') : tr('Vidéo non acceptée')), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            mark == 'explicit'
                ? tr('Afrolook n\'accepte pas les contenus sexuellement explicites. Les tenues légères et les danses restent permises.')
                : image
                    ? tr('Afrolook est le réseau des contenus authentiques : les images téléchargées de {a} ne sont pas acceptées. Publie tes propres images, prises avec l\'application ou créées dans le Studio.', {'a': _name(mark)})
                    : tr('Afrolook est le réseau des vidéos authentiques : les vidéos téléchargées de {a} ne sont pas acceptées. Publie tes propres vidéos, filmées avec l\'application ou montées avec un éditeur comme CapCut.', {'a': _name(mark)}),
            style: TextStyle(color: c.textSecondary, height: 1.4, fontSize: 14),
          ),
          if (allowClaim) ...[
            const SizedBox(height: 10),
            Text(mark == 'explicit' ? tr('Une erreur ? Notre équipe la vérifie avant de la publier.') : (image ? tr('Cette image est la tienne ? Notre équipe la vérifie avant de la publier.') : tr('Cette vidéo est la tienne ? Notre équipe la vérifie avant de la publier.')), style: TextStyle(color: c.textSecondary, height: 1.4, fontSize: 13)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Compris'), style: TextStyle(color: c.textSecondary))),
          if (allowClaim)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent),
            child: Text(mark == 'explicit' ? tr('C\'est une erreur') : (image ? tr('C\'est mon image') : tr('C\'est ma vidéo')), style: const TextStyle(fontWeight: FontWeight.w800)),
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
