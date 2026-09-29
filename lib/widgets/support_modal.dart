import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';
import 'pseudo_tag.dart';

/// Fenêtre de confirmation « Tu viens de soutenir @pseudo » : preuve visible qu'un like ou un cadeau
/// payant vient de passer. Se ferme seule après 2,5 s.
Future<void> showSupportedModal(
  BuildContext context, {
  required String pseudo,
  required String emoji,
  required String detail,
}) async {
  var closed = false;
  final timer = Timer(const Duration(milliseconds: 2500), () {
    if (!closed && context.mounted) Navigator.of(context, rootNavigator: true).maybePop();
  });
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final c = AppColors.of(ctx);
      final gold = c.isDark ? const Color(0xFFF5C542) : const Color(0xFFD99A00);
      return Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: gold.withOpacity(.6), width: 1.5)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 46)),
            const SizedBox(height: 8),
            Text(ctx.tr('Tu viens de soutenir'),
                style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            PseudoTag(label: '@$pseudo', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(detail, textAlign: TextAlign.center, style: TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
    },
  );
  closed = true;
  timer.cancel();
}
