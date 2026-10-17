// « Essayer ce template » sous un post fait avec un template du Studio ou une carte Afrolook (comme sur TikTok) :
// la personne ouvre le même template, déjà rempli, et publie son propre post.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../pages/cards/card_entry.dart';
import '../../pages/studio/montage/montage_editor_page.dart';
import '../../pages/studio/studio_models.dart';
import '../../pages/userPosts/userPostForm.dart';
import '../../services/template_link.dart';
import '../../theme/app_colors.dart';

class TemplateTry {
  TemplateTry._();

  /// Ouvre le template et, à la fin, le formulaire de post. [fromPostId] : le post d'où l'on vient (il compte l'essai).
  static Future<void> open(BuildContext context, TemplateRef ref, {String? fromPostId}) async {
    PostTemplateLink.begin(fromPostId);
    try {
      if (ref.isMontage) {
        final tp = ref.montage;
        if (tp == null) return;
        final r = await Navigator.push<StudioResult>(context, MaterialPageRoute(builder: (_) => MontageEditorPage(template: tp)));
        if (r == null || !context.mounted) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => UserPostForm(initialStudio: r)));
      } else {
        await CardEntry.openCompose(context, style: ref.cardStyle, template: ref.cardTemplate);
      }
    } finally {
      PostTemplateLink.clear();
    }
  }

  /// Le bouton existe-t-il sur cet appareil ? Le Studio et les cartes ne sont pas disponibles sur le web.
  static bool available(Post post) => !kIsWeb && TemplateRef.parse(post.studioTemplate) != null && post.isAdvertisement != true;
}

class PostTemplateTry extends StatelessWidget {
  const PostTemplateTry({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    if (!TemplateTry.available(post)) return const SizedBox.shrink();
    final ref = TemplateRef.parse(post.studioTemplate)!;
    return TemplateTryPill(ref: ref, tries: post.templateTries, onTap: () => TemplateTry.open(context, ref, fromPostId: post.id));
  }
}

/// La pastille elle-même (utilisée aussi dans les aperçus et les tests).
class TemplateTryPill extends StatelessWidget {
  const TemplateTryPill({super.key, required this.ref, required this.onTap, this.tries = 0});
  final TemplateRef ref;
  final int tries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(colors: [c.primary.withValues(alpha: .16), c.accent.withValues(alpha: .18)]),
                border: Border.all(color: c.primary.withValues(alpha: .5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.accent]), shape: BoxShape.circle),
                  child: Icon(Icons.auto_awesome_rounded, size: 13, color: c.onAccent),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: context.tr(ref.isCard ? 'Essayer ce modèle' : 'Essayer ce template'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5)),
                      TextSpan(text: '  ·  ${ref.label}', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                      if (tries > 0) TextSpan(text: '  ·  ${context.tr(tries > 1 ? '{n} essais' : '{n} essai', {'n': tries > 999 ? '${(tries / 1000).toStringAsFixed(1).replaceAll('.', ',')} k' : tries})}', style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.primary),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
