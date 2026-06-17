import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'affiliationMarketing.dart';

void showAffiliationAnnounceModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      final colors = AppColors.of(context);
      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.accent.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.people_alt_rounded, color: colors.accent, size: 34),
                ),
                const SizedBox(height: 14),

                // Badge "NOUVEAU"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'NOUVEAU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Titre
                Text(
                  '💰 Marketing d\'Affiliation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  'Gagnez 75% de commission pour chaque personne que vous parrainez !\n'
                  'Soit 3 375 FCFA par filleul actif.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),

                // Points clés
                _buildPoint(Icons.check_circle_outline, '75% de commission par activation', colors),
                const SizedBox(height: 6),
                _buildPoint(Icons.check_circle_outline, 'Revenus récurrents tous les 3 mois', colors),
                const SizedBox(height: 6),
                _buildPoint(Icons.check_circle_outline, 'Encaissement direct sur votre solde', colors),

                const SizedBox(height: 20),

                // Boutons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'PLUS TARD',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MarketingAffiliationPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: colors.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'DÉCOUVRIR',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildPoint(IconData icon, String text, AppColors colors) {
  return Row(
    children: [
      Icon(icon, color: colors.primary, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: colors.textPrimary, fontSize: 13),
        ),
      ),
    ],
  );
}
