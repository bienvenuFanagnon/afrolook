import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../pages/viral/viral_page.dart';
import '../services/viral_service.dart';
import '../theme/app_colors.dart';

/// Petit compteur rouge « +N » (règle de couleurs : compteurs en rouge, texte blanc).
class ViralCountPill extends StatelessWidget {
  const ViralCountPill({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = ViralService.badge(count);
    if (text.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    return Container(
      key: const ValueKey('viral_count_pill'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: colors.danger, borderRadius: BorderRadius.circular(9)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, height: 1.2)),
    );
  }
}

/// Libellé de l'onglet « 🔥 Viral » avec le « +N » des posts viraux pas encore vus.
class ViralTabLabel extends StatelessWidget {
  const ViralTabLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ViralService.unseen,
      builder: (context, n, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥 ${context.tr('Viral')}'),
          if (n > 0) ...[const SizedBox(width: 4), ViralCountPill(count: n)],
        ],
      ),
    );
  }
}

/// Bandeau « 🔥 Posts qui décollent » en haut du fil « Pour toi » : visible seulement quand il y a des posts viraux pas encore vus ; mène à la page Viral.
class ViralBanner extends StatelessWidget {
  const ViralBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: ViralService.unseen,
      builder: (context, n, _) {
        if (n <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: colors.border)),
            child: InkWell(
              key: const ValueKey('viral_banner'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViralPage())).then((_) => ViralService.refresh(force: true)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  const Text('🔥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('Posts qui décollent'), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5))),
                  ViralCountPill(count: n),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: colors.textSecondary, size: 20),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
