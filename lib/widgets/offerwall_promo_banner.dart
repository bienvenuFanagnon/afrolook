import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/offerwall/offerwall_promo.dart';
import '../theme/app_colors.dart';

/// Bandeau « Travaille dans Afrolook, sois payé » : combien on peut gagner par jour, par mois et pour une seule tâche, et que les pièces
/// gagnées se convertissent en argent réel. Montants : [OfferwallPromo].
class OfferwallPromoBanner extends StatelessWidget {
  const OfferwallPromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget line(IconData icon, String text, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: c.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: strong ? 14.5 : 13, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, height: 1.3)),
            ),
          ]),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary.withOpacity(0.16), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withOpacity(0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        line(Icons.payments_rounded, context.tr('Jusqu\'à {a} F par jour', {'a': OfferwallPromo.f(OfferwallPromo.maxPerDayFcfa)}), strong: true),
        line(Icons.calendar_month_rounded, context.tr('Jusqu\'à {a} F par mois', {'a': OfferwallPromo.f(OfferwallPromo.maxPerMonthFcfa)}), strong: true),
        line(Icons.bolt_rounded, context.tr('Une seule tâche peut te rapporter jusqu\'à {a} F', {'a': OfferwallPromo.f(OfferwallPromo.maxPerTaskFcfa)})),
        line(Icons.swap_horiz_rounded, context.tr('Tes pièces gagnées se convertissent en argent réel, selon le minimum de retrait en vigueur.')),
      ]),
    );
  }
}
