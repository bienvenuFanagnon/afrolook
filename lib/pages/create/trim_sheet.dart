import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../theme/app_colors.dart';

/// « m:ss » à partir de millisecondes.
String trimClock(int ms) => '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';

/// Feuille « Couper » (vidéo ou audio) : deux poignées pour choisir le passage gardé (1 seconde au moins). Rend le passage choisi, ou null si la personne ferme la feuille.
/// [maxMs] : durée maximale du passage (30 s pour une chronique) ; la fenêtre suit la poignée déplacée. En thème clair comme en thème sombre.
Future<RangeValues?> showTrimSheet(BuildContext context, {required int totalMs, required String title, int? maxMs}) {
  final c = AppColors.of(context);
  final max = maxMs != null && maxMs < totalMs ? maxMs.toDouble() : totalMs.toDouble();
  var range = RangeValues(0, max);
  return showModalBottomSheet<RangeValues>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
      final kept = (range.end - range.start) / 1000;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: Text(
                maxMs != null && maxMs < totalMs
                    ? context.tr('Choisis le passage à garder : {n} secondes au maximum.', {'n': maxMs ~/ 1000})
                    : context.tr('Garde seulement le passage choisi.'),
                style: TextStyle(color: c.textSecondary, fontSize: 13))),
            const SizedBox(height: 10),
            RangeSlider(
              key: const ValueKey('trim_range'),
              values: range,
              min: 0,
              max: totalMs.toDouble(),
              divisions: (totalMs / 100).clamp(2, 3000).round(),
              activeColor: c.isDark ? c.accent : c.accentText,
              inactiveColor: c.border,
              onChanged: (r) => setM(() {
                if ((r.end - r.start) < 1000) return;
                if ((r.end - r.start) > max) {
                  // passage trop long : l'autre poignée suit celle qu'on déplace
                  r = r.start != range.start ? RangeValues(r.start, r.start + max) : RangeValues(r.end - max, r.end);
                }
                range = r;
              }),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(trimClock(range.start.round()), style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
              Text(context.tr('{n} s gardées', {'n': kept.toStringAsFixed(1)}), style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              Text(trimClock(range.end.round()), style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const ValueKey('trim_ok'),
                onPressed: () => Navigator.pop(ctx, range),
                style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text(context.tr('Garder ce passage'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ]),
        ),
      );
    }),
  );
}
