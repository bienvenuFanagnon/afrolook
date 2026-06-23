

import 'package:afrotok/pages/Marketing/pageExplicationMarketing.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../providers/authProvider.dart';
import '../../models/model_data.dart';
import '../component/showUserDetails.dart';
import '../paiement/newDepot.dart';
import '../pub/native_ad_widget.dart';


class MarketingAffiliationPage extends StatefulWidget {
  const MarketingAffiliationPage({Key? key}) : super(key: key);

  @override
  State<MarketingAffiliationPage> createState() => _MarketingAffiliationPageState();
}

class _MarketingAffiliationPageState extends State<MarketingAffiliationPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late UserAuthProvider authProvider;
  bool isLoading = false;
  bool isRefreshing = false;
  bool showTerms = true;
  bool acceptedTerms = false;
  bool showAddParrainForm = false;
  final double subscriptionPrice = 4500.0; // 4500 FCFA pour 3 mois
  UserData? parrainData;
  final TextEditingController parrainCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
  }

  Future<void> _loadData() async {
    await _loadParrainData();
    setState(() {});
  }

  Future<void> _loadParrainData() async {
    final user = authProvider.loginUserData;
    if (user.codeParrain != null && user.codeParrain!.isNotEmpty) {
      try {
        final parrainQuery = await firestore
            .collection('Users')
            .where('code_parrainage', isEqualTo: user.codeParrain)
            .get();

        if (parrainQuery.docs.isNotEmpty) {
          setState(() {
            parrainData = UserData.fromJson(parrainQuery.docs.first.data());
          });
        }
      } catch (e) {
        printVm('Erreur chargement parrain: $e');
      }
    }
  }
  /// Converts a 2-letter ISO country code to the corresponding flag emoji.
  String _countryFlag(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return '';
    return countryCode.toUpperCase().split('').map((c) {
      final code = c.codeUnitAt(0);
      return (code >= 65 && code <= 90) ? String.fromCharCode(0x1F1E6 + code - 65) : '';
    }).join();
  }

  Widget _buildAdBanner({required String key}) {
    final colors = AppColors.of(context);
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: MrecAdWidget(
        // templateType: TemplateType.small,
        onAdLoaded: () {
          printVm('✅ Native Ad chargée dans invitations: $key');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final user = authProvider.loginUserData;
    final isAdmin = user.role == UserRole.ADM.name;
    final isMarketingActive = user.marketingActivated == true || isAdmin;
    final daysLeft = isMarketingActive && user.marketingSubscriptionEndDate != null
        ? _calculateDaysLeft(user.marketingSubscriptionEndDate!)
        : 0;

    printVm("Code parrain : ${user.codeParrain}");
    final hasParrain = parrainData != null || (user.codeParrain != null && user.codeParrain!.isNotEmpty);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          t.affiliTitle,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colors.accent),
            onPressed: _refreshPage,
            tooltip: t.affiliActualize,
          ),
        ],
      ),
      body: Container(
        color: colors.background,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAdBanner(key: 'participants_empty_top'),
                  SizedBox(height: 10),

                  // En-tête marketing
                  _buildMarketingHeader(user, isMarketingActive, daysLeft, isAdmin, hasParrain),
                  SizedBox(height: 10),

                  // Section Ajouter Parrain (si pas de parrain)
                  if (!hasParrain && !showAddParrainForm)
                    _buildNoParrainSection(),
                  if (!hasParrain && !showAddParrainForm)
                    SizedBox(height: 10),

                  // Formulaire ajout parrain
                  if (showAddParrainForm)
                    _buildAddParrainForm(),
                  if (showAddParrainForm)
                    SizedBox(height: 10),

                  // Section Parrain (si parrain existe)
                  if (hasParrain && parrainData != null)
                    _buildParrainSection(parrainData!),
                  if (hasParrain && parrainData != null)
                    SizedBox(height: 20),

                  // Statistiques (seulement si parrain existe)
                  if (hasParrain)
                    _buildStatsSection(user, isMarketingActive),
                  if (hasParrain)
                    SizedBox(height: 20),

                  // Code parrainage (seulement si parrain existe)
                  if (hasParrain)
                    _buildReferralCodeSection(user),
                  if (hasParrain)
                    SizedBox(height: 20),

                  // Liste des parrainés actifs
                  if (hasParrain && isMarketingActive)
                    _buildSponsoredUsersSection(user),
                  if (hasParrain && isMarketingActive)
                    SizedBox(height: 20),

                  // Avantages marketing
                  if (hasParrain)
                    _buildBenefitsSection(isMarketingActive),
                  if (hasParrain)
                    SizedBox(height: 20),

                  // Conditions d'utilisation
                  if (hasParrain && !isMarketingActive)
                    _buildTermsSection(),
                  if (hasParrain && !isMarketingActive)
                    SizedBox(height: 20),

                  // Bouton d'activation/renouvellement
                  if (hasParrain)
                    _buildActionButton(user, isMarketingActive, daysLeft, isAdmin),
                  if (hasParrain)
                    SizedBox(height: 20),
                ],
              ),
            ),

            if (isRefreshing)
              Positioned.fill(
                child: Container(
                  color: colors.background.withOpacity(0.7),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: colors.accent,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketingHeader(UserData user, bool isActive, int daysLeft, bool isAdmin, bool hasParrain) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [colors.danger, colors.accent]
              : [colors.surface, colors.surfaceVariant],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.danger.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isActive ? t.affiliActiveTag : t.affiliInactiveTag,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              if (isActive && !isAdmin)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.background.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.accent),
                  ),
                  child: Text(
                    '$daysLeft ${t.affiliDaysLeftLabel}',
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            !hasParrain
                ? t.affiliDescNoSponsor
                : (isAdmin ? t.affiliDescAdmin : (isActive ? t.affiliDescActive : t.affiliDescInactive)),
            style: TextStyle(
              color: colors.textPrimary.withOpacity(0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.textPrimary.withOpacity(0.1),
              foregroundColor: colors.accent,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: colors.accent),
              ),
            ),
            icon: Icon(Icons.help_outline, size: 18),
            label: Text(
              t.affiliHowItWorks,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () => _navigateToExplanationPage(),
          ),
          if (!hasParrain) SizedBox(height: 12),
          if (!hasParrain)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.danger.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.danger),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: colors.danger, size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      t.affiliAddSponsorStep,
                      style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          if (hasParrain && !isActive && !isAdmin) SizedBox(height: 12),
          if (hasParrain && !isActive && !isAdmin)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.accent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on, color: colors.accent, size: 16),
                  SizedBox(width: 8),
                  Text(
                    t.affiliActivateStep(subscriptionPrice.toInt()),
                    style: TextStyle(color: colors.accent, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

// Méthode de navigation vers la page d'explication
  void _navigateToExplanationPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketingExplanationPage(),
      ),
    );
  }
  Widget _buildNoParrainSection() {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.danger.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.danger),
      ),
      child: Column(
        children: [
          Icon(Icons.group_add, color: colors.danger, size: 50),
          SizedBox(height: 16),
          Text(
            t.affiliNoParrainTitle,
            style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            t.affiliNoParrainDesc,
            style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: colors.textPrimary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.add),
            label: Text(t.affiliAddParrainBtn),
            onPressed: () => setState(() => showAddParrainForm = true),
          ),
        ],
      ),
    );
  }

  Widget _buildAddParrainForm() {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.affiliParrainCodeTitle,
                style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textPrimary),
                onPressed: () => setState(() {
                  showAddParrainForm = false;
                  parrainCodeController.clear();
                }),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(t.affiliParrainCodeLabel, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
          SizedBox(height: 12),
          TextFormField(
            controller: parrainCodeController,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ex: AFRO1234',
              hintStyle: TextStyle(color: colors.textSecondary),
              filled: true,
              fillColor: colors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.accent),
              ),
              prefixIcon: Icon(Icons.code, color: colors.textSecondary),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.surfaceVariant,
                    foregroundColor: colors.textPrimary,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => setState(() {
                    showAddParrainForm = false;
                    parrainCodeController.clear();
                  }),
                  child: Text(t.affiliCancel),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _addParrain(),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.onAccent),
                          ),
                        )
                      : Text(t.affiliValidate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParrainSection(UserData parrain) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: colors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                t.affiliYourSponsor,
                style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              // Spacer(),
              // TextButton(
              //   onPressed: () {
              //     setState(() {
              //       showAddParrainForm = true;
              //     });
              //   },
              //   child: Text(
              //     'Changer',
              //     style: TextStyle(
              //       color: Colors.amber,
              //       fontSize: 12,
              //     ),
              //   ),
              // ),
            ],
          ),
          SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: colors.primary,
              backgroundImage: parrain.imageUrl != null && parrain.imageUrl!.isNotEmpty
                  ? NetworkImage(parrain.imageUrl!)
                  : null,
              child: parrain.imageUrl == null || parrain.imageUrl!.isEmpty
                  ? Text(
                      parrain.pseudo?.substring(0, 1).toUpperCase() ?? 'P',
                      style: TextStyle(color: colors.onPrimary),
                    )
                  : null,
            ),
            title: Text(
              parrain.pseudo ?? 'Parrain',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(parrain.email ?? '', style: TextStyle(color: colors.textSecondary)),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              minimumSize: Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _viewUserProfile(parrain),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility, size: 18),
                SizedBox(width: 8),
                Text(t.affiliViewProfile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(UserData user, bool isActive) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        // Bandeau compte inactif
        if (!isActive)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.warning.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: colors.warning, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.affiliInactiveBanner,
                    style: TextStyle(color: colors.warning, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: colors.accent, size: 20),
                  SizedBox(width: 8),
                  Text(t.affiliStats, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard(icon: Icons.account_balance_wallet, title: t.affiliBalanceMarketing,
                      value: isActive ? '${user.solde_marketing?.toInt() ?? 0} FCFA' : '---', color: colors.primary, isActive: isActive),
                  _buildStatCard(icon: Icons.people, title: t.affiliActiveSponsoreds,
                      value: isActive ? '${user.nbrParrainagesActifs ?? 0}' : '---', color: colors.info, isActive: isActive),
                  _buildStatCard(icon: Icons.trending_up, title: t.affiliTotalGains,
                      value: isActive ? '${user.total_gains_marketing?.toInt() ?? 0} FCFA' : '---', color: colors.accent, isActive: isActive),
                  _buildStatCard(icon: Icons.groups, title: t.affiliTotalSponsoreds,
                      value: '${user.nbrParrainagesTotal ?? 0}', color: colors.warning, isActive: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isActive,
  }) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? color : colors.textSecondary, size: 28),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: isActive ? colors.textPrimary : colors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeSection(UserData user) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final referralLink = 'https://afrolook.com/inscription?ref=${user.codeParrainage}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.share, color: colors.danger, size: 20),
              SizedBox(width: 8),
              Text(t.affiliReferralCodeTitle, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.background, colors.danger.withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.danger),
            ),
            child: Column(
              children: [
                Text(
                  user.codeParrainage ?? 'N/A',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(t.affiliShareCodeHint, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.danger,
                    foregroundColor: colors.textPrimary,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(Icons.copy, size: 18),
                  label: Text(t.affiliCopy),
                  onPressed: () => _copyToClipboard(user.codeParrainage ?? ''),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(Icons.share, size: 18),
                  label: Text(t.affiliShare),
                  onPressed: () => _shareReferralLink(referralLink, user.codeParrainage ?? ''),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSponsoredUsersSection(UserData user) {
    return FutureBuilder<List<UserData>>(
      future: _getSponsoredUsers(user.usersParrainerActifs ?? []),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: Colors.amber),
            ),
          );
        }

        final sponsoredUsers = snapshot.data ?? [];

        final colors = AppColors.of(context);
        final t = AppLocalizations.of(context);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt, color: colors.accent, size: 20),
                      SizedBox(width: 8),
                      Text(t.affiliSponsoredTitle, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t.affiliSponsoredCount(sponsoredUsers.length),
                      style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (sponsoredUsers.isEmpty)
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.group_off, color: colors.textSecondary, size: 40),
                      SizedBox(height: 12),
                      Text(t.affiliNoSponsored, style: TextStyle(color: colors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
                      SizedBox(height: 8),
                      Text(t.affiliNoSponsoredShare, style: TextStyle(color: colors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                    ],
                  ),
                )
              else
                Column(children: sponsoredUsers.map((user) => _buildSponsoredUserTile(user)).toList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSponsoredUserTile(UserData user) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final flag = _countryFlag(user.userPays?.id);
    final countryCode = user.userPays?.id ?? '';
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: colors.danger,
          backgroundImage: user.imageUrl != null && user.imageUrl!.isNotEmpty
              ? NetworkImage(user.imageUrl!)
              : null,
          child: user.imageUrl == null || user.imageUrl!.isEmpty
              ? Text(user.pseudo?.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(color: colors.textPrimary, fontSize: 12))
              : null,
        ),
        title: Row(
          children: [
            if (flag.isNotEmpty) ...[
              Text(flag, style: TextStyle(fontSize: 16)),
              SizedBox(width: 4),
              if (countryCode.isNotEmpty)
                Text('$countryCode · ', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ],
            Flexible(
              child: Text(
                user.pseudo ?? 'Utilisateur',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(user.email ?? '', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.danger,
            foregroundColor: colors.textPrimary,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _viewUserProfile(user),
          child: Text(t.affiliViewProfile.split(' ').last, style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection(bool isActive) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final benefits = [
      t.affiliBenefit1, t.affiliBenefit2, t.affiliBenefit3,
      t.affiliBenefit4, t.affiliBenefit5, t.affiliBenefit6, t.affiliBenefit7,
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: colors.accent, size: 20),
              SizedBox(width: 8),
              Text(t.affiliBenefitsTitle, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12),
          ...benefits.map((benefit) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: isActive ? colors.primary : colors.textSecondary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    benefit,
                    style: TextStyle(color: isActive ? colors.textPrimary : colors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTermsSection() {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => showTerms = !showTerms),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.description, color: colors.textPrimary, size: 20),
                    SizedBox(width: 8),
                    Text(t.affiliTermsTitle, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Icon(showTerms ? Icons.expand_less : Icons.expand_more, color: colors.textPrimary),
              ],
            ),
          ),
          if (showTerms) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.affiliTermsContent,
                style: TextStyle(color: colors.textSecondary, fontSize: 11, height: 1.6),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: acceptedTerms,
                  onChanged: (value) => setState(() => acceptedTerms = value ?? false),
                  checkColor: colors.onAccent,
                  activeColor: colors.accent,
                ),
                Expanded(
                  child: Text(t.affiliTermsAccept, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(UserData user, bool isActive, int daysLeft, bool isAdmin) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final hasEnoughBalance = isAdmin || (user.votre_solde_principal ?? 0) >= subscriptionPrice;
    final canRenew = isActive && daysLeft <= 7;

    return Column(
      children: [
        if (!isAdmin && !hasEnoughBalance && (!isActive || canRenew))
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.danger.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: colors.danger, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.affiliInsuffTitle, style: TextStyle(color: colors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text(
                        t.affiliMissing((subscriptionPrice - (user.votre_solde_principal ?? 0)).toInt()),
                        style: TextStyle(color: colors.danger.withOpacity(0.8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DepositScreen())),
                  child: Text(t.affiliRecharge, style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        if (!isActive && !isAdmin && !acceptedTerms && showTerms)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.warning, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(t.affiliTermsRequired, style: TextStyle(color: colors.warning, fontSize: 12))),
              ],
            ),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _getButtonColor(isActive, canRenew, acceptedTerms, hasEnoughBalance, isAdmin, colors),
              foregroundColor: colors.textPrimary,
              elevation: 4,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              shadowColor: colors.danger,
            ),
            onPressed: isLoading
                ? null
                : () {
                    if (!isActive && !isAdmin && !acceptedTerms) { setState(() => showTerms = true); return; }
                    if (!isAdmin && (!isActive || canRenew) && !hasEnoughBalance) { _showInsufficientBalanceDialog(); return; }
                    if (isActive && !canRenew && !isAdmin) { _showActiveSubscriptionDialog(daysLeft); return; }
                    _activateOrRenewMarketing(isAdmin);
                  },
            child: isLoading
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(colors.textPrimary)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getButtonIcon(isActive, canRenew, isAdmin), size: 20),
                      SizedBox(width: 8),
                      Text(_getButtonText(isActive, canRenew, isAdmin, t), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),

        Builder(builder: (_) {
          final solde = user.solde_marketing ?? 0;
          final showEncash = isActive && !canRenew && solde >= 4000;
          final canEncash = solde >= 7000;
          if (!showEncash) return SizedBox.shrink();
          return Column(
            children: [
              SizedBox(height: 12),
              if (!canEncash)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: colors.textSecondary, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Minimum 7 000 FCFA pour encaisser',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canEncash ? Colors.transparent : colors.surfaceVariant,
                    foregroundColor: canEncash ? colors.accent : colors.textSecondary,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: canEncash ? colors.accent : colors.border),
                    ),
                  ),
                  icon: Icon(Icons.account_balance_wallet, size: 20),
                  label: Text(
                    t.affiliEncash(solde.toInt()),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: canEncash ? () => _encashMarketingBalance() : null,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Color _getButtonColor(bool isActive, bool canRenew, bool acceptedTerms, bool hasEnoughBalance, bool isAdmin, AppColors colors) {
    if (isAdmin) return colors.danger;
    if (isActive && !canRenew) return colors.surfaceVariant;
    if (!isActive && (!acceptedTerms || !hasEnoughBalance)) return colors.surfaceVariant;
    if (canRenew && !hasEnoughBalance) return colors.surfaceVariant;
    return colors.danger;
  }

  IconData _getButtonIcon(bool isActive, bool canRenew, bool isAdmin) {
    if (isAdmin) return Icons.admin_panel_settings;
    if (isActive && canRenew) return Icons.autorenew;
    if (isActive) return Icons.verified;
    return Icons.rocket_launch;
  }

  String _getButtonText(bool isActive, bool canRenew, bool isAdmin, AppLocalizations t) {
    if (isAdmin) return t.affiliBtnAdmin;
    if (isActive && canRenew) return t.affiliBtnRenew(subscriptionPrice.toInt());
    if (isActive) return t.affiliBtnActive;
    return t.affiliBtnActivate(subscriptionPrice.toInt());
  }

  // Méthodes utilitaires
  int _calculateDaysLeft(int endTimestamp) {
    final endDate = DateTime.fromMillisecondsSinceEpoch(endTimestamp);
    final now = DateTime.now();
    final difference = endDate.difference(now);
    return difference.inDays.clamp(0, 90);
  }

  Future<List<UserData>> _getSponsoredUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final usersSnapshot = await firestore
          .collection('Users')
          .where('id', whereIn: userIds)
          .get();

      return usersSnapshot.docs
          .map((doc) => UserData.fromJson(doc.data()))
          .toList();
    } catch (e) {
      printVm('Erreur récupération filleuls: $e');
      return [];
    }
  }

  Future<void> _addParrain() async {
    final code = parrainCodeController.text.trim();
    if (code.isEmpty) {
      _showErrorSnackbar(AppLocalizations.of(context).affiliEnterCode);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Vérifier si le code existe
      final parrainQuery = await firestore
          .collection('Users')
          .where('code_parrainage', isEqualTo: code)
          .get();

      final t = AppLocalizations.of(context);
      if (parrainQuery.docs.isEmpty) {
        _showErrorSnackbar(t.affiliInvalidCode);
        setState(() => isLoading = false);
        return;
      }

      final currentUser = authProvider.loginUserData;
      if (currentUser.codeParrainage == code) {
        _showErrorSnackbar(t.affiliSelfParrain);
        setState(() => isLoading = false);
        return;
      }

      // Mettre à jour le code parrain
      await firestore.collection('Users').doc(currentUser.id!).update({
        'code_parrain': code,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Ajouter l'utilisateur à la liste des filleuls du parrain
      final parrainDoc = parrainQuery.docs.first;
      await firestore.collection('Users').doc(parrainDoc.id).update({
        'usersParrainer': FieldValue.arrayUnion([currentUser.id]),
        'usersParrainerHistorique': FieldValue.arrayUnion([currentUser.id]),
        'nbrParrainagesTotal': FieldValue.increment(1),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await _refreshPage();
      _showSuccessSnackbar(AppLocalizations.of(context).affiliParrainSuccess);

    } catch (e) {
      printVm('Erreur ajout parrain: $e');
      _showErrorSnackbar(AppLocalizations.of(context).affiliErrorParrain);
    } finally {
      setState(() {
        isLoading = false;
        showAddParrainForm = false;
        parrainCodeController.clear();
      });
    }
  }

  Future _refreshPage() async {
    setState(() => isRefreshing = true);
    try {
      await authProvider.refreshUserData();
      await _loadData();
      final t = AppLocalizations.of(context);
      _showSuccessSnackbar(t.affiliRefreshed);
    } catch (e) {
      final t = AppLocalizations.of(context);
      _showErrorSnackbar(t.affiliErrorRefresh);
    } finally {
      setState(() => isRefreshing = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: Colors.white))),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: Colors.white))),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _copyToClipboard(String text) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.accent,
        content: Row(
          children: [
            Icon(Icons.check, color: colors.onAccent),
            SizedBox(width: 8),
            Text(t.affiliCopied, style: TextStyle(color: colors.onAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareReferralLink(String link, String code) {
    Share.share(
      'Rejoins-moi sur Afrolook ! 🚀\n\n'
      'Active ton compte marketing avec mon code : $code\n'
      'pour 4 500 FCFA seulement.\n\n'
      '→ Profite de toutes les fonctionnalités premium !\n'
      '→ Partage ton propre code et gagne à ton tour.\n\n'
      '$link',
      subject: 'Rejoins Afrolook avec mon code de parrainage',
    );
  }

  void _viewUserProfile(UserData user) {
    double h = MediaQuery.of(context).size.height;
    double w = MediaQuery.of(context).size.width;

    showUserDetailsModalDialog(user, w, h, context);

    // TODO: Implémenter la navigation vers le profil
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation profil à implémenter'),
        backgroundColor: Colors.amber,
      ),
    );
  }

  void _showInsufficientBalanceDialog() {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(t.affiliInsuffTitle, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          t.affiliInsuffMsg(
            authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0,
            subscriptionPrice.toInt(),
          ),
          style: TextStyle(color: colors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.affiliLater, style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.danger, foregroundColor: colors.textPrimary),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DepositScreen()));
            },
            child: Text(t.affiliRechargeNow),
          ),
        ],
      ),
    );
  }

  void _showActiveSubscriptionDialog(int daysLeft) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(t.affiliActiveDialogTitle, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(t.affiliActiveDialogMsg(daysLeft), style: TextStyle(color: colors.textSecondary)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.danger, foregroundColor: colors.textPrimary),
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.affiliUnderstand),
          ),
        ],
      ),
    );
  }

  Future<void> _activateOrRenewMarketing(bool isAdmin) async {
    setState(() => isLoading = true);

    try {
      final user = authProvider.loginUserData;
      final now = DateTime.now();
      final endDate = now.add(Duration(days: 90)); // 3 mois

      if (!isAdmin) {
        // Débiter l'utilisateur (sauf admin)
        await firestore.collection('Users').doc(user.id!).update({
          'votre_solde_principal': FieldValue.increment(-subscriptionPrice),
        });

        // Créer la transaction de dépense
        await _createTransaction(
          TypeTransaction.DEPENSE.name,
          subscriptionPrice,
          'Activation compte marketing - 3 mois',
          user.id!,
        );
      }

      // Activer le marketing
      await firestore.collection('Users').doc(user.id!).update({
        'marketingActivated': true,
        'lastMarketingActivationDate': now.millisecondsSinceEpoch,
        'marketingSubscriptionEndDate': endDate.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      // Distribuer les commissions (sauf admin)
      if (!isAdmin) {
        await _distributeCommissions(user);
      }

      // Actualiser les données
      await _refreshPage();

      final t = AppLocalizations.of(context);
      _showSuccessSnackbar(isAdmin ? t.affiliActivatedAdmin : t.affiliActivatedMsg);

    } catch (e) {
      printVm('Erreur activation marketing: $e');
      _showErrorSnackbar('Erreur lors de l\'activation: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
        acceptedTerms = false;
        showTerms = false;
      });
    }
  }

  Future<void> _distributeCommissions(UserData user) async {
    try {
      final commissionParrain = subscriptionPrice * 0.75;
      final commissionApp = subscriptionPrice * 0.25;

      // Si l'utilisateur a un parrain
      if (user.codeParrain != null && user.codeParrain!.isNotEmpty) {
        final parrainQuery = await firestore
            .collection('Users')
            .where('code_parrainage', isEqualTo: user.codeParrain)
            .get();

        if (parrainQuery.docs.isNotEmpty) {
          final parrainDoc = parrainQuery.docs.first;
          final parrainData = parrainDoc.data();

          final parrainMarketingActivated = parrainData['marketingActivated'] == true;

          if (parrainMarketingActivated) {
            await firestore.collection('Users').doc(parrainDoc.id).update({
              'solde_marketing': FieldValue.increment(commissionParrain),
              'total_gains_marketing': FieldValue.increment(commissionParrain),
              'commissionTotalParrainage': FieldValue.increment(commissionParrain),
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            });

            await firestore.collection('Users').doc(parrainDoc.id).update({
              'usersParrainerActifs': FieldValue.arrayUnion([user.id]),
              'nbrParrainagesActifs': FieldValue.increment(1),
            });

            await _sendCommissionNotification(
              parrainDoc.id,
              user.pseudo ?? 'Un utilisateur',
              commissionParrain,
            );
          }
        }
      }

      // Créditer l'application
      await authProvider.getAppData();
      final AppDefaultData appData = authProvider.appDefaultData;
      final appDataId = appData.id!;

      await firestore.collection('AppData').doc(appDataId).update({
        'solde_affiliation': FieldValue.increment(commissionApp),
        'total_gains_affiliation': FieldValue.increment(commissionApp),
        'nbr_affiliations_actives': FieldValue.increment(1),
      });

    } catch (e) {
      printVm('Erreur distribution commissions: $e');
    }
  }

  Future<void> _sendCommissionNotification(
      String receiverId,
      String sponsorPseudo,
      double commission,
      ) async {
    try {
      final notif = NotificationData(
        id: firestore.collection('Notifications').doc().id,
        titre: "🎁 Nouvelle commission !",
        media_url: authProvider.loginUserData.imageUrl,
        type: NotificationType.MARKETING.name,
        description: "@$sponsorPseudo vient d'activer son compte marketing ! Vous avez gagné ${commission.toInt()} FCFA",
        user_id: authProvider.loginUserData.id,
        receiver_id: receiverId,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        updatedAt: DateTime.now().microsecondsSinceEpoch,
        status: PostStatus.VALIDE.name,
      );

      await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

      final receiverUser = await authProvider.getUserById(receiverId);
      if (receiverUser.isNotEmpty && receiverUser.first.oneIgnalUserid != null) {
        await authProvider.sendNotification(
          userIds: [receiverUser.first.oneIgnalUserid!],
          smallImage: authProvider.loginUserData.imageUrl!,
          send_user_id: authProvider.loginUserData.id!,
          recever_user_id: receiverId,
          message: "@$sponsorPseudo vient d'activer son compte marketing ! Vous avez gagné ${commission.toInt()} FCFA",
          type_notif: NotificationType.MARKETING.name,
          post_id: '',
          post_type: '',
          chat_id: '',
        );
      }
    } catch (e) {
      printVm('Erreur envoi notification commission: $e');
    }
  }

  Future<void> _createTransaction(
      String type,
      double montant,
      String description,
      String userId,
      ) async {
    try {
      await firestore.collection('TransactionSoldes').add({
        'user_id': userId,
        'montant': montant,
        'type': type,
        'description': description,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'statut': StatutTransaction.VALIDER.name,
      });
    } catch (e) {
      printVm('Erreur création transaction: $e');
    }
  }

  Future<void> _encashMarketingBalance() async {
    final user = authProvider.loginUserData;
    final marketingBalance = user.solde_marketing ?? 0;

    if (marketingBalance <= 0) {
      _showErrorSnackbar('Votre solde marketing est vide');
      return;
    }

    setState(() => isLoading = true);

    try {
      await firestore.collection('Users').doc(user.id!).update({
        'solde_marketing': 0.0,
        'votre_solde_principal': FieldValue.increment(marketingBalance),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await _createTransaction(
        TypeTransaction.GAIN.name,
        marketingBalance,
        'Encaissement solde marketing',
        user.id!,
      );

      await _refreshPage();

      final t = AppLocalizations.of(context);
      _showSuccessSnackbar(t.affiliEncashSuccess(marketingBalance.toInt()));
    } catch (e) {
      printVm('Erreur encaissement: $e');
      _showErrorSnackbar('Erreur lors de l\'encaissement');
    } finally {
      setState(() => isLoading = false);
    }
  }
}