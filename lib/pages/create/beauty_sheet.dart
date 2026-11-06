import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/beauty.dart';
import '../../theme/app_colors.dart';

/// Feuille « Beauté » : trois curseurs (peau lisse, teint éclatant, chaleur des couleurs). Rend le nouveau réglage, ou null si la feuille est fermée sans changement.
/// [onChanged] est appelé à chaque mouvement (l'aperçu de la caméra suit tout de suite).
Future<BeautyLevel?> showBeautySheet(BuildContext context, BeautyLevel current, {ValueChanged<BeautyLevel>? onChanged}) {
  final c = AppColors.of(context);
  var level = current;
  return showModalBottomSheet<BeautyLevel>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
      Widget slider(Key key, String label, double v, ValueChanged<double> set) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              SizedBox(width: 118, child: Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14))),
              Expanded(
                child: Slider(
                  key: key,
                  value: v,
                  activeColor: c.isDark ? c.accent : c.accentText,
                  inactiveColor: c.border,
                  onChanged: (x) {
                    setM(() => set(x));
                    onChanged?.call(level);
                  },
                ),
              ),
              SizedBox(width: 42, child: Text('${(v * 100).round()} %', textAlign: TextAlign.right, style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700))),
            ]),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: Text(context.tr('✨ Beauté'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
            const SizedBox(height: 2),
            Align(alignment: Alignment.centerLeft, child: Text(context.tr('Peau plus douce, teint lumineux, couleurs chaudes. Le niveau naturel est déjà réglé.'), style: TextStyle(color: c.textSecondary, fontSize: 13))),
            const SizedBox(height: 8),
            slider(const ValueKey('beauty_smooth'), context.tr('Peau lisse'), level.smooth, (x) => level = level.copyWith(smooth: x)),
            slider(const ValueKey('beauty_glow'), context.tr('Teint éclatant'), level.glow, (x) => level = level.copyWith(glow: x)),
            slider(const ValueKey('beauty_warm'), context.tr('Chaleur'), level.warm, (x) => level = level.copyWith(warm: x)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('beauty_reset'),
                  onPressed: () => Navigator.pop(ctx, const BeautyLevel()),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: BorderSide(color: c.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(context.tr('Niveau naturel'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('beauty_ok'),
                  onPressed: () => Navigator.pop(ctx, level),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(context.tr('Valider'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ]),
        ),
      );
    }),
  );
}
