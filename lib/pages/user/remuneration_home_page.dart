// pages/remuneration_home_page.dart

import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'mes_gains_post_page.dart';
import 'mes_gains_publicite_page.dart';

class RemunerationHomePage extends StatefulWidget {
  final UserData user;

  const RemunerationHomePage({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<RemunerationHomePage> createState() => _RemunerationHomePageState();
}

class _RemunerationHomePageState extends State<RemunerationHomePage> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          l10n.remunerationTitle,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.primary, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet, color: colors.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.user.votre_solde_principal?.toStringAsFixed(2) ?? "0.00"} FCFA',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: CenteredContent(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),

              // Sous-titre
              Text(
                l10n.remunerationSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // Bouton Compte Principal
              _buildRemunerationCard(
                colors,
                title: l10n.remunerationMainAccount,
                subtitle: l10n.remunerationMainAccountDesc,
                icon: Icons.wallet,
                accentColor: colors.primary,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonetisationPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Bouton Rémunération des Posts
              _buildRemunerationCard(
                colors,
                title: l10n.remunerationPosts,
                subtitle: l10n.remunerationPostsDesc,
                icon: Entypo.instagram,
                accentColor: colors.accent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MesGainsPage(
                        userId: widget.user.id!,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Bouton Gains Publicitaires
              _buildRemunerationCard(
                colors,
                title: l10n.remunerationAds,
                subtitle: l10n.remunerationAdsDesc,
                icon: AntDesign.google,
                accentColor: colors.info,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MesGainsPublicitePage(
                        userId: widget.user.id!,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Placeholder pour futurs boutons
              _buildFutureCard(colors, l10n),

              const SizedBox(height: 32),

              // Pied de page
              _buildFooter(colors, l10n),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildRemunerationCard(
    AppColors colors, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              // Icône
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Textes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Flèche
              Icon(
                Icons.arrow_forward_ios,
                color: colors.textSecondary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFutureCard(AppColors colors, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.border,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                color: colors.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.remunerationComingSoon.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.remunerationComingSoonDesc,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppColors colors, AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          height: 3,
          width: 60,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.remunerationFooter,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          l10n.remunerationFooterSub,
          style: TextStyle(
            color: colors.textSecondary.withOpacity(0.6),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
