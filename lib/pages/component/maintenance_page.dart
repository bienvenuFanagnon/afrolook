import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class MaintenancePage extends StatelessWidget {
  final String pageName;
  final bool showBack;
  final bool isAppLevel;

  const MaintenancePage({
    Key? key,
    required this.pageName,
    this.showBack = true,
    this.isAppLevel = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: showBack
          ? AppBar(
              backgroundColor: colors.background,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAppLevel ? Icons.phone_android_rounded : Icons.construction_rounded,
                size: 72,
                color: colors.warning,
              ),
              const SizedBox(height: 24),
              Text(
                isAppLevel ? 'Application en maintenance' : 'Page en maintenance',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isAppLevel
                    ? 'Afrolook est temporairement indisponible.\nNous effectuons une mise à jour. Merci de réessayer dans quelques instants.'
                    : 'La section "$pageName" est temporairement indisponible.\nNous travaillons à l\'améliorer. Revenez bientôt !',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (showBack)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accent,
                    side: BorderSide(color: colors.accent),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Retour'),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
