import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';

class MarketingExplanationPage extends StatelessWidget {
  const MarketingExplanationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          t.explainTitle,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colors.background,
        iconTheme: IconThemeData(color: colors.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.danger, colors.accent],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colors.danger.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    t.explainHeroTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.explainHeroAmount,
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.explainHeroDesc,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Introduction
            _buildSectionTitle(t.explainIntroTitle, colors),
            const SizedBox(height: 12),
            Text(
              t.explainIntroDesc,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            // Étapes
            _buildStepCard(
              stepNumber: 1,
              title: t.explainStep1Title,
              description: t.explainStep1Desc,
              icon: Icons.group_add,
              color: colors.danger,
              colors: colors,
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              stepNumber: 2,
              title: t.explainStep2Title,
              description: t.explainStep2Desc,
              icon: Icons.rocket_launch,
              color: colors.warning,
              colors: colors,
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              stepNumber: 3,
              title: t.explainStep3Title,
              description: t.explainStep3Desc,
              icon: Icons.share,
              color: colors.primary,
              colors: colors,
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              stepNumber: 4,
              title: t.explainStep4Title,
              description: t.explainStep4Desc,
              icon: Icons.monetization_on,
              color: colors.accent,
              colors: colors,
            ),
            const SizedBox(height: 24),

            // Avantages
            _buildSectionTitle(t.explainBenefitsTitle, colors),
            const SizedBox(height: 12),
            _buildBenefitItem(t.explainBenefit1, colors),
            _buildBenefitItem(t.explainBenefit2, colors),
            _buildBenefitItem(t.explainBenefit3, colors),
            _buildBenefitItem(t.explainBenefit4, colors),
            _buildBenefitItem(t.explainBenefit5, colors),
            _buildBenefitItem(t.explainBenefit6, colors),
            const SizedBox(height: 24),

            // Revenus récurrents
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.autorenew, color: colors.primary, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        t.explainRenewalTitle,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.explainRenewalDesc,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      t.explainRenewalExample,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tableau des Gains
            _buildSectionTitle(t.explainEarningsTitle, colors),
            const SizedBox(height: 12),
            _buildEarningsTable(t, colors),
            const SizedBox(height: 24),

            // Témoignage
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.info),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user, color: colors.info, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        t.explainTestimTitle,
                        style: TextStyle(
                          color: colors.info,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.explainTestimQuote,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.explainTestimAuthor,
                    style: TextStyle(
                      color: colors.info,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Calculatrice
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.background, colors.surface],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.danger),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.explainCalcTitle,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.explainCalcLines,
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.explainCalcFooter,
                    style: TextStyle(color: colors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CTA Final
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accent, colors.danger],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.celebration, color: Colors.white, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    t.explainCtaTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.explainCtaDesc,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: colors.onAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      t.explainCtaBtn,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppColors colors) {
    return Text(
      title,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: colors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsTable(AppLocalizations t, AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.explainEarningsCol1,
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    t.explainEarningsCol2,
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    t.explainEarningsCol3,
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          _buildTableRow('5 filleuls', '16 875 FCFA', '67 500 FCFA', colors),
          _buildTableRow('10 filleuls', '33 750 FCFA', '135 000 FCFA', colors),
          _buildTableRow('20 filleuls', '67 500 FCFA', '270 000 FCFA', colors),
          _buildTableRow('50 filleuls', '168 750 FCFA', '675 000 FCFA', colors),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    String filleuls,
    String activation,
    String annuel,
    AppColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              filleuls,
              style: TextStyle(color: colors.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              activation,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              annuel,
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
