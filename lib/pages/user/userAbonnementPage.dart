import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../services/abonnement_service.dart';
import '../../services/utils/abonnement_utils.dart';
import '../../theme/app_colors.dart';

class AbonnementScreen extends StatefulWidget {
  @override
  _AbonnementScreenState createState() => _AbonnementScreenState();
}

class _AbonnementScreenState extends State<AbonnementScreen>
    with SingleTickerProviderStateMixin {
  final AbonnementService _abonnementService = AbonnementService();

  late TabController _tabController;
  bool _isLoading = false;
  bool _showPlanDetails = false;

  // Durée sélectionnée par plan
  int _dureePremium = 1;
  int _dureeGold = 1;

  // Offres Premium
  final List<Map<String, dynamic>> _offresPremium = [
    {'mois': 1, 'prixBase': 200.0, 'reduction': 0.0},
    {'mois': 2, 'prixBase': 400.0, 'reduction': 0.0},
    {'mois': 3, 'prixBase': 600.0, 'reduction': 100.0},
    {'mois': 6, 'prixBase': 1200.0, 'reduction': 200.0},
    {'mois': 12, 'prixBase': 2400.0, 'reduction': 500.0},
  ];

  // Offres Gold
  final List<Map<String, dynamic>> _offresGold = [
    {'mois': 1, 'prixBase': 500.0, 'reduction': 0.0},
    {'mois': 2, 'prixBase': 1000.0, 'reduction': 50.0},
    {'mois': 3, 'prixBase': 1500.0, 'reduction': 150.0},
    {'mois': 6, 'prixBase': 3000.0, 'reduction': 500.0},
    {'mois': 12, 'prixBase': 6000.0, 'reduction': 1500.0},
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final type = authProvider.loginUserData?.abonnement?.type ?? 'gratuit';
    int initialTab = 0;
    if (type == 'premium') initialTab = 1;
    if (type == 'gold') initialTab = 2;
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _getPrixPremium(int mois) {
    final offre = _offresPremium.firstWhere((o) => o['mois'] == mois,
        orElse: () => _offresPremium.first);
    return (offre['prixBase'] as double) - (offre['reduction'] as double);
  }

  double _getPrixGold(int mois) {
    final offre = _offresGold.firstWhere((o) => o['mois'] == mois,
        orElse: () => _offresGold.first);
    return (offre['prixBase'] as double) - (offre['reduction'] as double);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final authProvider = Provider.of<UserAuthProvider>(context);
    final user = authProvider.loginUserData!;
    final abonnement = user.abonnement;
    final isPremium = AbonnementUtils.isPremiumActive(abonnement);
    final isGold = AbonnementUtils.isGold(abonnement);

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverAppBar(colors, isGold, isPremium)],
        body: Column(
          children: [
            _buildTabBar(colors),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFreeTab(colors, abonnement),
                  _buildPremiumTab(colors, user, abonnement, isPremium, isGold),
                  _buildGoldTab(colors, user, abonnement, isGold),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(AppColors colors, bool isGold, bool isPremium) {
    List<Color> gradientColors;
    String title;
    if (isGold) {
      gradientColors = [const Color(0xFFFFD700), const Color(0xFFFF8C00)];
      title = 'Afrolook Gold 👑';
    } else if (isPremium) {
      gradientColors = [const Color(0xFFFF416C), const Color(0xFFFDB813)];
      title = 'Afrolook Premium ⭐';
    } else {
      gradientColors = [const Color(0xFF1FAA59), const Color(0xFF0E7C3A)];
      title = 'Abonnement';
    }

    return SliverAppBar(
      expandedHeight: 110,
      floating: false,
      pinned: true,
      backgroundColor: colors.background,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
        ),
      ),
    );
  }

  // ── TabBar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar(AppColors colors) {
    return Container(
      color: colors.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: colors.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: '🆓 Gratuit'),
          Tab(text: '⭐ Premium'),
          Tab(text: '👑 Gold'),
        ],
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFDB813)]),
          borderRadius: BorderRadius.circular(4),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  // ── Onglet Gratuit ──────────────────────────────────────────────────────

  Widget _buildFreeTab(AppColors colors, AfrolookAbonnement? abonnement) {
    final isActive = abonnement?.type == 'gratuit' || abonnement == null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(
          colors: colors,
          icon: Icons.person_outline,
          iconColor: colors.textSecondary,
          borderColor: colors.border,
          title: 'PLAN GRATUIT',
          subtitle: isActive ? 'Votre plan actuel' : 'Plan de base',
          badge: isActive ? 'ACTUEL' : null,
          badgeColor: colors.primary,
        ),
        const SizedBox(height: 20),
        _buildFeatureList(colors, [
          _Feature('Messagerie privée', true),
          _Feature('Rejoindre des groupes publics', true),
          _Feature('Posts visibles dans son pays', true),
          _Feature('1 photo par look', true),
          _Feature('Créer un groupe', false),
          _Feature('Live HD', false),
          _Feature('Groupes privés payants', false),
          _Feature('Badge exclusif', false),
        ]),
        const SizedBox(height: 20),
        _buildInfoCard(colors, [
          '⏰ À l\'expiration d\'un plan payant, retour automatique au plan Gratuit',
          '💡 Votre abonnement soutient le développement d\'Afrolook',
        ]),
      ],
    );
  }

  // ── Onglet Premium ──────────────────────────────────────────────────────

  Widget _buildPremiumTab(AppColors colors, UserData user,
      AfrolookAbonnement? abonnement, bool isPremium, bool isGold) {
    final solde = user.votre_solde_principal ?? 0.0;
    final prixFinal = _getPrixPremium(_dureePremium);
    final soldeInsuffisant = solde < prixFinal;

    // Si Gold actif : afficher info upgrade impossible (déjà au dessus)
    if (isGold) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(
            colors: colors,
            icon: Icons.workspace_premium,
            iconColor: const Color(0xFFFFD700),
            borderColor: const Color(0xFFFFD700),
            title: 'VOUS ÊTES GOLD 👑',
            subtitle: 'Le plan Gold inclut tout Premium et plus encore',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Text(
              'Gold ⊃ Premium : tous les avantages Premium sont inclus dans votre plan Gold.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          _buildFeatureList(colors, _premiumFeatures()),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Statut actuel
        if (isPremium)
          _buildStatusCard(
            colors: colors,
            icon: Icons.workspace_premium,
            iconColor: const Color(0xFFFDB813),
            borderColor: const Color(0xFFFDB813),
            title: 'ABONNÉ PREMIUM ⭐',
            subtitle: 'Valable encore ${AbonnementUtils.getDaysRemaining(abonnement)} jours',
            badge: 'ACTIF',
            badgeColor: const Color(0xFFFF416C),
            dateDebut: abonnement?.dateDebut,
            dateFin: abonnement?.dateFin,
            montantPaye: abonnement?.montantPaye,
          ),
        if (!isPremium) ...[
          _buildPlanHeader(colors, 'Premium ⭐', 'À partir de', 200, const Color(0xFFFDB813)),
          const SizedBox(height: 16),
          _buildFeatureList(colors, _premiumFeatures()),
          const SizedBox(height: 20),
          _buildDurationSelector(
            colors: colors,
            offres: _offresPremium,
            selected: _dureePremium,
            accentColor: const Color(0xFFFDB813),
            onSelect: (m) => setState(() => _dureePremium = m),
          ),
          const SizedBox(height: 16),
          _buildPriceSummary(colors, _offresPremium, _dureePremium, const Color(0xFFFDB813)),
          const SizedBox(height: 16),
          _buildPaymentSection(
            colors: colors,
            solde: solde,
            prixFinal: prixFinal,
            soldeInsuffisant: soldeInsuffisant,
            accentColor: const Color(0xFFFF416C),
            btnLabel: '⭐ DEVENIR PREMIUM — ${prixFinal.toInt()} FCFA',
            onPay: () => _souscrire(user, 'premium', _dureePremium),
          ),
        ],
        if (isPremium) ...[
          const SizedBox(height: 20),
          _buildRenewalSection(
            colors: colors,
            user: user,
            abonnement: abonnement!,
            offres: _offresPremium,
            accentColor: const Color(0xFFFDB813),
            planType: 'premium',
          ),
          const SizedBox(height: 16),
          _buildFeatureList(colors, _premiumFeatures()),
        ],
        const SizedBox(height: 20),
        _buildGroupRenewalNote(colors),
        const SizedBox(height: 20),
        _buildInfoCard(colors, [
          '🔄 Pas de renouvellement automatique — vous contrôlez votre abonnement',
          '⏰ À l\'expiration, retour automatique au plan Gratuit',
          '👑 Pour les groupes privés payants, passez au plan Gold',
        ]),
      ],
    );
  }

  // ── Onglet Gold ─────────────────────────────────────────────────────────

  Widget _buildGoldTab(AppColors colors, UserData user,
      AfrolookAbonnement? abonnement, bool isGold) {
    final solde = user.votre_solde_principal ?? 0.0;
    final prixFinal = _getPrixGold(_dureeGold);
    final soldeInsuffisant = solde < prixFinal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Statut actuel si Gold actif
        if (isGold)
          _buildStatusCard(
            colors: colors,
            icon: Icons.workspace_premium,
            iconColor: const Color(0xFFFFD700),
            borderColor: const Color(0xFFFFD700),
            title: 'ABONNÉ GOLD 👑',
            subtitle: 'Valable encore ${AbonnementUtils.getDaysRemaining(abonnement)} jours',
            badge: 'ACTIF',
            badgeColor: const Color(0xFFFFD700),
            dateDebut: abonnement?.dateDebut,
            dateFin: abonnement?.dateFin,
            montantPaye: abonnement?.montantPaye,
          ),

        if (!isGold) ...[
          _buildNewBadge(),
          const SizedBox(height: 12),
          _buildPlanHeader(colors, 'Gold 👑', 'À partir de', 500, const Color(0xFFFFD700)),
        ],

        const SizedBox(height: 16),
        _buildFeatureList(colors, _goldFeatures()),

        // Avertissement Gold expiré
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
          ),
          child: Text(
            '👑 Si votre abonnement Gold expire : vos groupes passent en lecture seule. '
            'Les membres ne sont pas expulsés — le renouvellement est demandé à leur prochaine entrée.',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ),

        const SizedBox(height: 20),

        if (!isGold) ...[
          _buildDurationSelector(
            colors: colors,
            offres: _offresGold,
            selected: _dureeGold,
            accentColor: const Color(0xFFFFD700),
            onSelect: (m) => setState(() => _dureeGold = m),
          ),
          const SizedBox(height: 16),
          _buildPriceSummary(colors, _offresGold, _dureeGold, const Color(0xFFFFD700)),
          const SizedBox(height: 16),
          _buildPaymentSection(
            colors: colors,
            solde: solde,
            prixFinal: prixFinal,
            soldeInsuffisant: soldeInsuffisant,
            accentColor: const Color(0xFFFFD700),
            btnLabel: '👑 DEVENIR GOLD — ${prixFinal.toInt()} FCFA',
            onPay: () => _souscrire(user, 'gold', _dureeGold),
            btnTextColor: Colors.black,
          ),
        ],

        if (isGold) ...[
          const SizedBox(height: 20),
          _buildRenewalSection(
            colors: colors,
            user: user,
            abonnement: abonnement!,
            offres: _offresGold,
            accentColor: const Color(0xFFFFD700),
            planType: 'gold',
          ),
        ],

        const SizedBox(height: 20),
        _buildGroupRenewalNote(colors),
        const SizedBox(height: 20),
        _buildInfoCard(colors, [
          '🔄 Pas de renouvellement automatique — vous contrôlez votre abonnement',
          '⏰ À l\'expiration, retour automatique au plan Gratuit',
          '💰 70% des abonnements de vos groupes privés vous reviennent directement',
        ]),
      ],
    );
  }

  // ── Widgets communs ─────────────────────────────────────────────────────

  Widget _buildStatusCard({
    required AppColors colors,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    DateTime? dateDebut,
    DateTime? dateFin,
    double? montantPaye,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor ?? colors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (dateDebut != null && dateFin != null) ...[
            const SizedBox(height: 14),
            Divider(color: colors.border),
            const SizedBox(height: 10),
            _infoRow(colors, 'Début',
                '${dateDebut.day}/${dateDebut.month}/${dateDebut.year}'),
            const SizedBox(height: 6),
            _infoRow(colors, 'Fin',
                '${dateFin.day}/${dateFin.month}/${dateFin.year}',
                valueColor: dateFin.difference(DateTime.now()).inDays <= 7
                    ? Colors.orange
                    : null),
            if (montantPaye != null) ...[
              const SizedBox(height: 6),
              _infoRow(colors, 'Montant payé', '${montantPaye.toInt()} FCFA',
                  valueColor: const Color(0xFFFDB813)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _infoRow(AppColors colors, String label, String value,
      {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPlanHeader(AppColors colors, String name, String prefix,
      int basePrice, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              Text('$prefix ${basePrice.toString()} FCFA/mois',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('NOUVEAU 🆕',
            style: TextStyle(
                color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFeatureList(AppColors colors, List<_Feature> features) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Text(f.enabled ? '✅' : '❌', style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(f.label,
                      style: TextStyle(
                          color: f.enabled ? colors.textPrimary : colors.textSecondary,
                          fontSize: 13)),
                ),
                if (f.isGoldOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('GOLD',
                        style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDurationSelector({
    required AppColors colors,
    required List<Map<String, dynamic>> offres,
    required int selected,
    required Color accentColor,
    required void Function(int) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CHOISIR LA DURÉE',
            style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: offres.map((offre) {
              final mois = offre['mois'] as int;
              final prixBase = offre['prixBase'] as double;
              final reduction = offre['reduction'] as double;
              final prixFinal = prixBase - reduction;
              final prixMois = (prixFinal / mois).round();
              final isSelected = selected == mois;

              return GestureDetector(
                onTap: () => onSelect(mois),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 110,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [accentColor, accentColor.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)
                        : null,
                    color: isSelected ? null : colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? accentColor : colors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$mois mois',
                              style: TextStyle(
                                  color: isSelected ? Colors.black : colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: Colors.black, size: 16),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$prixMois F/mois',
                          style: TextStyle(
                              color: isSelected ? Colors.black87 : accentColor,
                              fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('${prixFinal.toInt()} F',
                          style: TextStyle(
                              color: isSelected ? Colors.black : colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      if (reduction > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text('-${reduction.toInt()} F',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSummary(AppColors colors, List<Map<String, dynamic>> offres,
      int selected, Color accentColor) {
    final offre = offres.firstWhere((o) => o['mois'] == selected,
        orElse: () => offres.first);
    final prixBase = offre['prixBase'] as double;
    final reduction = offre['reduction'] as double;
    final prixFinal = prixBase - reduction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _infoRow(colors, 'Durée', '$selected mois'),
          if (reduction > 0) ...[
            const SizedBox(height: 8),
            _infoRow(colors, 'Prix de base', '${prixBase.toInt()} F',
                valueColor: colors.textSecondary),
            const SizedBox(height: 8),
            _infoRow(colors, 'Réduction', '-${reduction.toInt()} F',
                valueColor: Colors.green),
          ],
          Divider(color: colors.border, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total à payer',
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              Text('${prixFinal.toInt()} FCFA',
                  style: TextStyle(
                      color: accentColor, fontSize: 26, fontWeight: FontWeight.bold)),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                'soit ${(prixFinal / selected).round()} F/mois',
                style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection({
    required AppColors colors,
    required double solde,
    required double prixFinal,
    required bool soldeInsuffisant,
    required Color accentColor,
    required String btnLabel,
    required VoidCallback onPay,
    Color btnTextColor = Colors.white,
  }) {
    final manquant = prixFinal - solde;

    return Column(
      children: [
        // Info solde
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  color: soldeInsuffisant ? Colors.orange : accentColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Solde principal',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    Text('${solde.toInt()} FCFA',
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (soldeInsuffisant)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text('-${manquant.toInt()} F',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Alerte solde insuffisant
        if (soldeInsuffisant) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Solde insuffisant',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('Il vous manque ${manquant.toInt()} F',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => DepositScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: btnTextColor,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Recharger', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Bouton paiement
        if (_isLoading)
          CircularProgressIndicator(color: accentColor)
        else
          ElevatedButton(
            onPressed: soldeInsuffisant ? null : onPay,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: btnTextColor,
              disabledBackgroundColor: colors.border,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: soldeInsuffisant ? 0 : 4,
            ),
            child: Text(btnLabel,
                style: TextStyle(
                    color: btnTextColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildRenewalSection({
    required AppColors colors,
    required UserData user,
    required AfrolookAbonnement abonnement,
    required List<Map<String, dynamic>> offres,
    required Color accentColor,
    required String planType,
  }) {
    final expireBientot = AbonnementUtils.isExpiringSoon(abonnement);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expireBientot ? Colors.orange : accentColor.withOpacity(0.4),
          width: expireBientot ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expireBientot)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Expire dans ${AbonnementUtils.getDaysRemaining(abonnement)} jours',
                      style: const TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Text('Renouveler votre abonnement',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Renouvelez avant l\'expiration pour ne pas perdre vos avantages.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => _showRenewalSheet(user, offres, accentColor, planType),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accentColor, width: 2),
              foregroundColor: accentColor,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('VOIR LES OPTIONS DE RENOUVELLEMENT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupRenewalNote(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ℹ️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Groupes privés payants : si votre abonnement à un groupe expire, '
              'vous n\'êtes pas expulsé. Le renouvellement vous est demandé '
              'uniquement lorsque vous essayez de ré-entrer dans le groupe.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(AppColors colors, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.split(' ')[0], style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.substring(item.indexOf(' ') + 1),
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Listes de fonctionnalités ────────────────────────────────────────────

  List<_Feature> _premiumFeatures() => [
    _Feature('Messagerie privée', true),
    _Feature('Créer et gérer des groupes · 2 groupes max · 100 membres/groupe', true),
    _Feature('Posts visibles partout en Afrique', true),
    _Feature('3 photos par look', true),
    _Feature('Live HD · latence 500ms', true),
    _Feature('Mode fantôme · connexion cachée', true),
    _Feature('Emojis 3D · Stickers exclusifs', true),
    _Feature('Challenges illimités', true),
    _Feature('Badge Premium ⭐', true),
    _Feature('Mode lecture seule pour les membres', true),
    _Feature('Support prioritaire', true),
    _Feature('Groupes illimités · membres illimités (Gold)', false, isGoldOnly: true),
    _Feature('Groupes privés payants (70% vous revient)', false, isGoldOnly: true),
    _Feature('Code unique + lien d\'invitation partageable', false, isGoldOnly: true),
    _Feature('Liens externes cliquables dans les messages', false, isGoldOnly: true),
    _Feature('Carousel pub dans la page Groupes', false, isGoldOnly: true),
    _Feature('Contrôle écriture / partage par membre', false, isGoldOnly: true),
    _Feature('Masquer ou restreindre un message', false, isGoldOnly: true),
    _Feature('Groupe gelé si plan expire (membres protégés)', false, isGoldOnly: true),
  ];

  List<_Feature> _goldFeatures() => [
    // ── Hérité du plan Premium
    _Feature('Tout le plan Premium inclus', true),
    // ── Groupes : limites levées
    _Feature('Groupes illimités (Premium : 2 max)', true, isGoldOnly: true),
    _Feature('Membres illimités par groupe (Premium : 100 max)', true, isGoldOnly: true),
    // ── Groupes privés
    _Feature('Groupes privés payants · 70% des revenus vous revient', true, isGoldOnly: true),
    _Feature('Abonnés groupes : renouvellement à la demande (non expulsés)', true, isGoldOnly: true),
    // ── Accès & invitation
    _Feature('Code unique d\'accès (valide 30 jours, régénérable)', true, isGoldOnly: true),
    _Feature('Lien d\'invitation partageable (WhatsApp, SMS…)', true, isGoldOnly: true),
    _Feature('Lien redirige directement vers le groupe dans l\'app', true, isGoldOnly: true),
    // ── Contrôle des membres
    _Feature('Contrôle d\'écriture global (activer/désactiver pour tous)', true, isGoldOnly: true),
    _Feature('Contrôle de partage global (posts, produits, lives)', true, isGoldOnly: true),
    _Feature('Permissions individuelles par membre', true, isGoldOnly: true),
    // ── Messages enrichis
    _Feature('Liens externes cliquables dans les messages', true, isGoldOnly: true),
    _Feature('Masquer un message existant (sans le supprimer)', true, isGoldOnly: true),
    _Feature('Choisir qui peut voir un message (destinataires ciblés)', true, isGoldOnly: true),
    // ── Visibilité & badge
    _Feature('Carousel pub dans la page Groupes (aléatoire)', true, isGoldOnly: true),
    _Feature('Badge Gold 👑 exclusif sur votre profil et vos groupes', true, isGoldOnly: true),
    _Feature('Groupe gelé automatiquement si plan expire (membres conservés)', true, isGoldOnly: true),
  ];

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _souscrire(UserData user, String planType, int dureeMois) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await _abonnementService.souscrire(
        planType: planType,
        dureeMois: dureeMois,
        user: user,
        context: context,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        // Rafraîchir le plan en mémoire immédiatement sans relancer l'app
        await Provider.of<UserAuthProvider>(context, listen: false).refreshUserData();
        if (!mounted) return;
        _showSuccessDialog(planType);
      } else {
        _showErrorDialog(result['message'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(e.toString());
    }
  }

  void _showRenewalSheet(UserData user, List<Map<String, dynamic>> offres,
      Color accentColor, String planType) {
    final colors = AppColors.of(context);
    showResponsiveBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: colors.border, borderRadius: BorderRadius.circular(2))),
              Text('Renouveler l\'abonnement',
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Choisissez une durée pour votre renouvellement',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: offres.map((offre) {
                    final mois = offre['mois'] as int;
                    final prixFinal = (offre['prixBase'] as double) -
                        (offre['reduction'] as double);
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        if (planType == 'premium') {
                          setState(() => _dureePremium = mois);
                        } else {
                          setState(() => _dureeGold = mois);
                        }
                        _souscrire(user, planType, mois);
                      },
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$mois mois',
                            style: TextStyle(
                                color: accentColor, fontWeight: FontWeight.bold)),
                      ),
                      title: Text('${prixFinal.toInt()} FCFA',
                          style: TextStyle(
                              color: colors.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'soit ${(prixFinal / mois).round()} F/mois',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      trailing: Icon(Icons.arrow_forward_ios,
                          color: colors.textSecondary, size: 16),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String planType) {
    final isGold = planType == 'gold';
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: isGold ? const Color(0xFFFFD700) : const Color(0xFFFDB813),
              width: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isGold
                      ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                      : [const Color(0xFFFDB813), const Color(0xFFFF416C)],
                ),
              ),
              child: Icon(Icons.workspace_premium, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text('FÉLICITATIONS !',
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              isGold
                  ? 'Vous êtes maintenant membre Afrolook Gold 👑'
                  : 'Vous êtes maintenant membre Afrolook Premium ⭐',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isGold ? const Color(0xFFFFD700) : const Color(0xFFFF416C),
                foregroundColor: isGold ? Colors.black : Colors.white,
                minimumSize: const Size(150, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('SUPER !',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Erreur', style: TextStyle(color: colors.danger)),
        content: Text(message, style: TextStyle(color: colors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: TextStyle(color: const Color(0xFFFDB813))),
          ),
        ],
      ),
    );
  }
}

// ── Modèle local pour les fonctionnalités ────────────────────────────────────

class _Feature {
  final String label;
  final bool enabled;
  final bool isGoldOnly;
  const _Feature(this.label, this.enabled, {this.isGoldOnly = false});
}
