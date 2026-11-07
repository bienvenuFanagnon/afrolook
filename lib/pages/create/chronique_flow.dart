import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiClient, ApiException;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../services/api/chroniques_api.dart';
import '../../services/new_content_bus.dart';
import '../../theme/app_colors.dart';
import '../../widgets/api_error_dialogs.dart' show showRechargeDialog;
import '../chronique/chronique_commerce.dart';
import '../chronique/chronique_preview.dart';
import '../chronique/chroniqueform.dart' show ChroniqueType;
import '../component/consoleWidget.dart';
import '../studio/studio_models.dart';
import 'create_hub_page.dart';
import 'create_result.dart';

/// Les deux chroniques du parcours « Créer » : la chronique ordinaire (24 h) et la chronique business (carte de vente).
enum ChroniqueKind { normal, business }

/// Parcours « Chronique » : les chroniques se fabriquent dans le même Studio que les posts (caméra, montage, musique, texte, voix), puis une carte de vente
/// pour la chronique business, un aperçu exact de la lecture, et la publication. Ce parcours remplace l'ancien formulaire de chronique.
class ChroniqueFlow {
  ChroniqueFlow._();

  /// Chronique en cours de création (null = on crée un post). Posée par l'écran « Que créer ? » tant qu'il est ouvert.
  static ChroniqueKind? active;

  static const int maxVideoSeconds = 30;
}

/// Ouvre le parcours de création d'une chronique. Rend vrai si une chronique a été publiée.
Future<bool> openChroniqueCreate(BuildContext context, {ChroniqueKind kind = ChroniqueKind.normal}) async {
  final r = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => CreateHubPage(chronique: kind)));
  return r == kCreateDone;
}

/// Fin du parcours : ce qui vient d'être préparé dans le Studio devient une chronique. Rend [kCreateDone] (publiée : tout le parcours se referme)
/// ou [kCreateBack] (la personne revient en arrière : l'écran précédent reste ouvert).
///
/// [beforePublish] : appelée juste avant l'envoi réel, une fois les vérifications passées (ex. débit d'une carte). Faux = annuler.
Future<String> finishChronique(
  BuildContext context, {
  StudioResult? studio,
  File? audio,
  File? audioCover,
  List<Uint8List>? images,
  File? imageFile,
  String? caption,
  ChroniqueKind kind = ChroniqueKind.normal,
  Future<bool> Function()? beforePublish,
}) async {
  var type = ChroniqueType.TEXT;
  File? media;
  File? cover = audioCover;
  var text = (caption ?? '').trim();
  String? templateId;
  int? startMs;
  int? endMs;

  if (studio != null) {
    text = (studio.textContent ?? text).trim();
    templateId = studio.templateId;
    switch (studio.type) {
      case StudioContentType.video:
        type = ChroniqueType.VIDEO;
        media = studio.mediaFile;
      case StudioContentType.image:
        type = ChroniqueType.IMAGE;
        media = studio.mediaFile;
      case StudioContentType.audio:
        type = ChroniqueType.AUDIO;
        media = studio.mediaFile;
        cover = studio.coverImageFile ?? cover;
        startMs = studio.audioStartMs;
        endMs = studio.audioEndMs;
      case StudioContentType.text:
        type = ChroniqueType.TEXT;
    }
  } else if (audio != null) {
    type = ChroniqueType.AUDIO;
    media = audio;
  } else if (imageFile != null) {
    type = ChroniqueType.IMAGE;
    media = imageFile;
  } else if (images != null && images.isNotEmpty) {
    type = ChroniqueType.IMAGE;
    final dir = await getTemporaryDirectory();
    media = await File('${dir.path}/chronique_${DateTime.now().millisecondsSinceEpoch}.jpg').writeAsBytes(images.first, flush: true);
  }
  if (!context.mounted) return kCreateBack;
  if (text.length > 100 && type != ChroniqueType.TEXT) text = text.substring(0, 100);
  if (type != ChroniqueType.TEXT && media == null) return kCreateBack;
  if (type == ChroniqueType.TEXT && text.isEmpty) return kCreateBack;

  // vidéo : 30 secondes au plus (même règle qu'avant)
  VideoPlayerController? vc;
  if (type == ChroniqueType.VIDEO && media != null) {
    vc = VideoPlayerController.file(media);
    try {
      await vc.initialize();
    } catch (_) {
      await vc.dispose();
      vc = null;
    }
    if (vc != null && vc.value.duration.inSeconds > ChroniqueFlow.maxVideoSeconds + 1) {
      await vc.dispose();
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('La vidéo est trop longue : 30 secondes au maximum pour une chronique. Coupe-la avant de continuer.'))));
      }
      return kCreateBack;
    }
  }
  if (!context.mounted) {
    await vc?.dispose();
    return kCreateBack;
  }

  // chronique business : la carte de vente d'abord (produit, prix, WhatsApp, appel, lien)
  Map<String, dynamic>? commerce;
  if (kind == ChroniqueKind.business) {
    commerce = await showChroniqueCommerceEditor(context);
    if (commerce == null || !context.mounted) {
      await vc?.dispose();
      return kCreateBack;
    }
  }

  // aperçu : exactement la lecture réelle, avec « Modifier » ou « Publier »
  final me = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ChroniquePreviewPage(
      type: type,
      pseudo: me.pseudo ?? '',
      avatarUrl: me.imageUrl,
      text: text,
      backgroundColor: type == ChroniqueType.TEXT ? const Color(0xFF1B8A3C) : null,
      mediaFile: media,
      coverFile: cover,
      videoController: vc,
      commerce: commerce,
    ),
  ));
  await vc?.dispose();
  if (ok != true || !context.mounted) return kCreateBack;

  final published = await ChroniquePublisher.publish(
    context,
    type: type,
    text: text,
    media: media,
    cover: cover,
    templateId: templateId,
    audioStartMs: startMs,
    audioEndMs: endMs,
    commerce: commerce,
    beforePublish: beforePublish,
  );
  return published ? kCreateDone : kCreateBack;
}

/// Publication d'une chronique : prévient si c'est une chronique payante (2 actives gratuites, puis 10 pièces, sauf Premium et Gold), envoie, puis prévient les abonnés.
class ChroniquePublisher {
  ChroniquePublisher._();

  static String? _feeKey; // clé d'idempotence de la chronique payante en cours (conservée entre deux tentatives : aucun double débit)

  static Future<bool> publish(
    BuildContext context, {
    required ChroniqueType type,
    required String text,
    File? media,
    File? cover,
    String? templateId,
    int? audioStartMs,
    int? audioEndMs,
    Map<String, dynamic>? commerce,
    Future<bool> Function()? beforePublish,
  }) async {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final provider = Provider.of<ChroniqueProvider>(context, listen: false);
    final c = AppColors.of(context);
    final progress = ValueNotifier<double>(0);
    var dialogOpen = false;

    void closeProgress() {
      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
    }

    try {
      String? feeKey;
      final fee = await ChroniquesApi.fee();
      if (fee['fee_due'] == true) {
        final coins = (fee['fee_coins'] as num?)?.toInt() ?? 10;
        if (!context.mounted) return false;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: c.surface,
            title: Text(context.tr('Chronique supplémentaire')),
            content: Text(context.tr('Tu as déjà 2 chroniques actives (limite gratuite).\n\nPublier cette chronique coûte {a} pièces. Les abonnés Premium et Gold publient sans limite.', {'a': '$coins'})),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Payer {a} pièces', {'a': '$coins'}))),
            ],
          ),
        );
        if (ok != true) return false;
        feeKey = _feeKey ??= ApiClient.newIdempotencyKey();
      }
      if (beforePublish != null && !await beforePublish()) return false;
      if (!context.mounted) return false;

      // fenêtre d'envoi avec la progression
      dialogOpen = true;
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: c.surface,
            content: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, p, __) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Publication de ta chronique…'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: p <= 0 ? null : p.clamp(0, 1), color: c.primary, backgroundColor: c.border),
              ]),
            ),
          ),
        ),
      ));

      ChroniqueCommerceLink.set(commerce); // lue une seule fois par la publication
      final uploaded = await provider.publishChronique(
        userId: auth.loginUserData.id!,
        userPseudo: auth.loginUserData.pseudo!,
        userImageUrl: auth.loginUserData.imageUrl!,
        type: type,
        textContent: text,
        mediaFile: media,
        coverImageFile: cover,
        backgroundColor: type == ChroniqueType.TEXT ? const Color(0xFF1B8A3C).value.toRadixString(16) : null,
        templateId: templateId,
        audioStartMs: audioStartMs,
        audioEndMs: audioEndMs,
        idempotencyKey: feeKey,
        onProgress: (p) => progress.value = p,
      );
      _feeKey = null; // publiée : la prochaine chronique aura sa propre clé
      closeProgress();
      NewContentBus.instance.onChroniquePublished(); // retour à l'accueil, la chronique apparaît dans la barre
      addPointsForAction(UserAction.post);
      unawaited(_notify(auth, type: type, text: text, mediaUrl: uploaded));
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(backgroundColor: const Color(0xFF1B4332), content: Text(context.tr('🎉 Chronique publiée avec succès !'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)));
      }
      return true;
    } catch (e) {
      printVm('Erreur publication chronique : $e');
      closeProgress();
      if (!context.mounted) return false;
      if (e is ApiException && e.isInsufficientCoins) {
        showRechargeDialog(context, message: e.message);
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: c.surface,
            title: Text(context.tr('Erreur'), style: TextStyle(color: c.accentText, fontWeight: FontWeight.bold)),
            content: Text(e.toString().replaceFirst('Exception: ', ''), style: TextStyle(color: c.textPrimary)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: TextStyle(color: c.primary, fontWeight: FontWeight.bold)))],
          ),
        );
      }
      return false;
    } finally {
      progress.dispose();
    }
  }

  static Future<void> _notify(UserAuthProvider auth, {required ChroniqueType type, required String text, String? mediaUrl}) async {
    final image = (type != ChroniqueType.TEXT && mediaUrl != null && mediaUrl.isNotEmpty) ? mediaUrl : auth.loginUserData.imageUrl!;
    final label = switch (type) {
      ChroniqueType.TEXT => text.length > 100 ? '${text.substring(0, 100)}...' : text,
      ChroniqueType.IMAGE => '📷 $text',
      ChroniqueType.VIDEO => '🎥 $text',
      ChroniqueType.AUDIO => '🎙️ $text',
    };
    await auth.sendPushNotificationToUsers(
      sender: auth.loginUserData,
      message: '📢 ${auth.loginUserData.pseudo!} a partagé une chronique: $label',
      typeNotif: 'CHRONIQUE',
      smallImage: image,
      postType: type.toString(),
    );
  }
}

/// Choix « Chronique (24 h) » ou « Chronique business » (boutons « Créer une chronique » des listes). Rend vrai si une chronique a été publiée.
Future<bool> showChroniqueChoice(BuildContext context) async {
  final kind = await showModalBottomSheet<ChroniqueKind>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      Widget row(Key key, IconData icon, Color bg, Color fg, String title, String sub, ChroniqueKind k) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: key,
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.pop(ctx, k),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(width: 46, height: 46, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: fg)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                    ])),
                    Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                  ]),
                ),
              ),
            ),
          );
      return Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              row(const ValueKey('choice_chronique'), Icons.history_toggle_off_rounded, c.accent, c.onAccent, ctx.tr('Chronique (24 h)'), ctx.tr('Ouvre le Studio : montage, musique, texte, épinglage'), ChroniqueKind.normal),
              row(const ValueKey('choice_business'), Icons.storefront_rounded, c.primary, Colors.white, ctx.tr('Chronique business'), ctx.tr('Vends un produit : carte de vente, lien, WhatsApp, appel'), ChroniqueKind.business),
            ]),
          ),
        ),
      );
    },
  );
  if (kind == null || !context.mounted) return false;
  return openChroniqueCreate(context, kind: kind);
}
