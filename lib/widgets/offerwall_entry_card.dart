import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../pages/offerwall/offerwall_tasks_page.dart';
import '../services/offerwall/offerwall_promo.dart';
import '../services/offerwall/offerwall_service.dart';
import '../services/share/share_service.dart';
import '../theme/app_colors.dart';

/// Entrée « Gagne des pièces avec des tâches » (page Récompenses, page Pièces, fil…). Invisible tant que la fonction n'est pas disponible :
/// clé du SDK absente de cette version, interrupteur du serveur coupé pour cette plateforme, ou compte suspendu des tâches.
class OfferwallEntryCard extends StatelessWidget {
  const OfferwallEntryCard({super.key, this.margin = const EdgeInsets.only(bottom: 12)});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FutureBuilder<bool>(
      future: OfferwallService.isAvailable(),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return Container(
          margin: margin,
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfferwallTasksPage())),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.primary.withOpacity(0.5))),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.primary.withOpacity(0.14), shape: BoxShape.circle),
                    child: Icon(Icons.task_alt_rounded, color: c.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(OfferwallService.isConfigured ? context.tr('Travaille et gagne de l\'argent réel') : context.tr('Travaille et gagne de l\'argent'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(OfferwallService.isConfigured ? context.tr('Jusqu\'à {a} F par jour en accomplissant des tâches dans Afrolook.', {'a': OfferwallPromo.f(OfferwallPromo.maxPerDayFcfa)}) : context.tr('Partage des annonces sur WhatsApp, Telegram, Facebook… et gagne de l\'argent : environ {f} F par clic valide, jusqu\'à {m} F par jour.', {'f': ShareService.lastPerClickFcfa.round(), 'm': ShareService.lastDailyCapFcfa.round()}), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
