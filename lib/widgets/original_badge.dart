import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';

/// Mention « Fait sur Afrolook » : le média de ce post a été filmé, photographié, enregistré OU retouché avec le Studio de l'application (origines `captured` et `edited`).
/// Elle valorise ce que la personne crée elle-même ; ces posts passent aussi en priorité dans le fil.
class OriginalBadge extends StatelessWidget {
  const OriginalBadge({super.key, this.compact = false});

  /// Version réduite (icône seule) pour les endroits étroits.
  final bool compact;

  /// L'origine est-elle « filmé ou enregistré dans l'application » ?
  static bool isCaptured(String? captureSource) => captureSource == 'captured' || captureSource == 'edited';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: context.tr('Filmé ou enregistré avec Afrolook'),
      child: Container(
        key: const ValueKey('original_badge'),
        padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8, vertical: 3),
        decoration: BoxDecoration(color: c.accent.withOpacity(c.isDark ? .16 : .3), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.videocam_rounded, size: 13, color: c.accentText),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(context.tr('Fait sur Afrolook'), style: TextStyle(color: c.isDark ? c.accent : c.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ],
        ]),
      ),
    );
  }
}

/// Étiquette « Voix modifiée » : l'auteur d'un audio a choisi un effet de voix (jamais un clonage de voix). Honnêteté envers celles et ceux qui écoutent.
class VoiceChangedBadge extends StatelessWidget {
  const VoiceChangedBadge({super.key});

  /// Le post porte-t-il un effet de voix ?
  static bool has(String? voiceEffect) => voiceEffect != null && voiceEffect.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      key: const ValueKey('voice_changed_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(99), border: Border.all(color: c.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.graphic_eq_rounded, size: 13, color: c.textSecondary),
        const SizedBox(width: 4),
        Text(context.tr('Voix modifiée'), style: TextStyle(color: c.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Ligne « En réponse à @pseudo » sous un post qui répond en vidéo à un autre post ; toucher la ligne ouvre le post d'origine.
class ReplyToLine extends StatelessWidget {
  const ReplyToLine({super.key, required this.username, this.excerpt, this.onTap});

  final String? username;
  final String? excerpt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final who = (username == null || username!.isEmpty) ? context.tr('un post') : '@$username';
    return GestureDetector(
      key: const ValueKey('reply_to_line'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.subdirectory_arrow_right_rounded, size: 15, color: c.textSecondary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              context.tr('En réponse à {who}', {'who': who}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.info, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
    );
  }
}
