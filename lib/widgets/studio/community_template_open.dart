import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../models/community_template.dart';
import '../../pages/create/create_flow.dart';
import '../../pages/studio/montage/montage_catalog.dart';
import '../../pages/studio/montage/montage_editor_page.dart';
import '../../pages/studio/montage/montage_face_capture.dart';
import '../../pages/studio/studio_models.dart';
import '../../services/api/community_templates_api.dart';
import '../../services/post_source_link.dart';
import '../../services/template_link.dart';
import '../../pages/studio/montage/collage_template.dart';
import '../../pages/studio/montage/collage_template_page.dart';
import '../../pages/studio/montage/story_page.dart';
import '../../pages/studio/montage/story_script.dart';
import '../../theme/app_colors.dart';

/// Ouverture d'un modèle créé par une personne (09/11/2026) : depuis le catalogue « Communauté », la bande « Les plus utilisés » ou « Essayer ce modèle » sous un post.
/// Un modèle payant s'annonce avant (« 20 pièces, payées à la publication, une seule fois ») ; le paiement lui-même a lieu à la publication ([PostTemplateLink.payIfNeeded]),
/// jamais si la personne abandonne ou si c'est son propre modèle.
class CommunityTemplateOpen {
  CommunityTemplateOpen._();

  /// Ouvre le modèle d'identifiant [id] (chargé du serveur) ; message clair s'il n'est plus disponible.
  static Future<void> byId(BuildContext context, String id, {String? fromPostId}) async {
    final t = await CommunityTemplatesApi.get(id);
    if (!context.mounted) return;
    if (t == null || t.toMontage() == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('Ce modèle n\'est plus disponible.'))));
      return;
    }
    await open(context, t, fromPostId: fromPostId);
  }

  static Future<void> open(BuildContext context, CommunityTemplate t, {String? fromPostId}) async {
    final tp = t.toMontage();
    if (tp == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.tr('Ce modèle n\'est pas disponible dans cette version de l\'application.'))));
      return;
    }
    if (!t.isFree && !await confirmPrice(context, t)) return;
    if (!context.mounted) return;
    await openMontage(context, tp, fromPostId: fromPostId);
  }

  /// Le parcours d'un modèle du Studio (du catalogue ou d'une personne) : si le modèle a des filtres de visage, on se filme d'abord avec l'avatar et l'effet déjà choisis (Android) ;
  /// puis l'éditeur, puis le formulaire unique. Ce qui est filmé garde la mention « Fait sur Afrolook » comme tout ce qui est filmé dans l'application.
  static Future<void> openMontage(BuildContext context, MontageTemplate tp, {String? fromPostId}) async {
    String? video;
    String? photo;
    var filmed = false;
    if (tp.face != null) {
      final cap = await captureForFaceTemplate(context, tp.face!);
      if (cap == null || !context.mounted) return;
      video = cap.isVideo ? cap.path : null;
      photo = cap.isVideo ? null : cap.path;
      filmed = true;
    }
    PostTemplateLink.begin(fromPostId);
    // modèle « histoire » : la vidéo défile toute seule (diaporama) ; la page gère elle-même l'éditeur et la publication
    final story = tp.isStory ? storyScriptFor(tp.id) : null;
    if (story != null) {
      try {
        await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => StoryTemplatePage(template: tp, script: story)));
      } finally {
        PostTemplateLink.clear();
      }
      return;
    }
    final collage = tp.isCollage ? collageScriptFor(tp.id) : null;
    if (collage != null) {
      try {
        await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => CollageTemplatePage(template: tp, script: collage)));
      } finally {
        PostTemplateLink.clear();
      }
      return;
    }
    try {
      final r = await Navigator.of(context).push<StudioResult>(MaterialPageRoute(builder: (_) => MontageEditorPage(template: tp, presetVideoPath: video, presetPhotoPath: photo)));
      if (r == null || !context.mounted) return;
      await openCreateForm(context, studio: r, source: filmed ? PostSourceLink.captured : PostSourceLink.edited);
    } finally {
      PostTemplateLink.clear();
    }
  }

  static Future<bool> confirmPrice(BuildContext context, CommunityTemplate t) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('community_price_dialog'),
        backgroundColor: c.surface,
        title: Text(t.name, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(
          context.tr('Ce modèle coûte {n} pièces, payées une seule fois à la publication. Si tu n\'as pas assez de pièces, tu pourras en recharger à ce moment-là. Rien n\'est débité si tu abandonnes.', {'n': '${t.priceCoins}'}),
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'))),
          FilledButton(
            key: const ValueKey('community_price_ok'),
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent),
            child: Text(context.tr('Utiliser · {n} pièces', {'n': '${t.priceCoins}'}), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return ok == true;
  }
}
