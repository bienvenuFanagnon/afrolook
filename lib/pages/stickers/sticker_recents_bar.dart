import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/stickers/sticker_models.dart';
import '../../theme/app_colors.dart';
import 'sticker_widgets.dart';

/// Ligne « Récents » au-dessus de la barre de saisie : 5 derniers stickers.
class StickerRecentsBar extends StatelessWidget {
  final List<StickerItem> recents;
  final StickerAccess? access;
  final ValueChanged<StickerItem> onSend;

  const StickerRecentsBar({super.key, required this.recents, required this.access, required this.onSend});

  @override
  Widget build(BuildContext context) {
    if (recents.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final shown = recents.take(5).toList();
    final globalReason = (access != null && !access!.canSend) ? access!.reason : null;

    return Container(
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        children: [
          Text(context.tr('Récents'), style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              globalReason != null
                  ? stickerReasonText(context, globalReason)
                  : context.tr('Touche un sticker pour l\'envoyer'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: globalReason != null ? c.danger : c.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(width: 6),
          for (final s in shown) _cell(context, c, s),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, AppColors c, StickerItem s) {
    final reason = access?.blockedReasonFor(s, isRecent: true);
    final blocked = reason != null;
    final cell = Padding(
        padding: const EdgeInsets.only(left: 6),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: blocked ? 0.35 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: StickerImage(sticker: s, size: 40, loadAnimation: !blocked),
                ),
              ),
              if (reason == 'not_owned')
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(Icons.lock_rounded, size: 14, color: c.textPrimary),
                ),
            ],
          ),
        ),
      );
    if (blocked) {
      // Non cliquable : un toucher affiche seulement la raison.
      return Tooltip(
        message: stickerReasonText(context, reason),
        triggerMode: TooltipTriggerMode.tap,
        child: cell,
      );
    }
    return GestureDetector(onTap: () => onSend(s), child: cell);
  }
}
