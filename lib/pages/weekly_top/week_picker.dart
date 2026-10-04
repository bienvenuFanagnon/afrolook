import 'package:flutter/material.dart';

import '../../services/weekly_rewards_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive_sheet.dart';

/// Liste des semaines disponibles pour un classement ; retourne la semaine choisie (ou null).
Future<String?> pickWeek(BuildContext context, List<String> weeks, String? current) {
  return showResponsiveBottomSheet<String>(
    context: context,
    builder: (ctx) {
      final colors = AppColors.of(ctx);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Choisir une semaine',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.textPrimary)),
            const SizedBox(height: 8),
            if (weeks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Aucune semaine disponible pour le moment.',
                    style: TextStyle(color: colors.textSecondary)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: weeks
                      .map((w) => ListTile(
                            title: Text(WeeklyRewardsService.formatWeekLabel(w),
                                style: TextStyle(color: colors.textPrimary)),
                            subtitle: Text(w, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                            trailing: current == w ? Icon(Icons.check, color: colors.primary) : null,
                            onTap: () => Navigator.pop(ctx, w),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}
