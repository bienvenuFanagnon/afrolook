

import 'package:afrotok/pages/Marketing/pageExplicationMarketing.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../providers/authProvider.dart';
import '../../models/model_data.dart';
import '../component/showUserDetails.dart';
import '../paiement/newDepot.dart';


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
        print('Erreur chargement parrain: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authProvider.loginUserData;
    final isAdmin = user.role == UserRole.ADM.name;
    final isMarketingActive = user.marketingActivated == true || isAdmin;
    final daysLeft = isMarketingActive && user.marketingSubscriptionEndDate != null
        ? _calculateDaysLeft(user.marketingSubscriptionEndDate!)
        : 0;

    printVm("Code parrain : ${user.codeParrain}");
    final hasParrain = parrainData != null || (user.codeParrain != null && user.codeParrain!.isNotEmpty);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Marketing & Affiliation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.amber),
            onPressed: _refreshPage,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête marketing
                  _buildMarketingHeader(user, isMarketingActive, daysLeft, isAdmin, hasParrain),
                  SizedBox(height: 20),

                  // Section Ajouter Parrain (si pas de parrain)
                  if (!hasParrain && !showAddParrainForm)
                    _buildNoParrainSection(),
                  if (!hasParrain && !showAddParrainForm)
                    SizedBox(height: 20),

                  // Formulaire ajout parrain
                  if (showAddParrainForm)
                    _buildAddParrainForm(),
                  if (showAddParrainForm)
                    SizedBox(height: 20),

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

            // Indicateur de chargement
            if (isRefreshing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.amber,
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [Color(0xFFB71C1C), Color(0xFFFFA000)]
              : [Colors.grey.shade900, Colors.grey.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
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
                isActive ? '🎯 MARKETING ACTIF' : '📊 MARKETING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              if (isActive && !isAdmin)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Text(
                    '$daysLeft jours',
                    style: TextStyle(
                      color: Colors.amber,
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
                ? '📝 Pour activer le marketing, vous devez d\'abord avoir un parrain'
                : (isAdmin
                ? '🎖️ COMPTE ADMIN - Marketing activé gratuitement'
                : (isActive
                ? '✅ Votre compte marketing est actif !\nGagnez 50% sur chaque activation de vos filleuls.'
                : '🚀 Activez votre compte marketing pour gagner des commissions sur vos filleuls.')),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),

          // Bouton Comment ça marche ?
          SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.amber,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.amber),
              ),
            ),
            icon: Icon(Icons.help_outline, size: 18),
            label: Text(
              'Comment ça marche ?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            onPressed: () => _navigateToExplanationPage(),
          ),

          if (!hasParrain) SizedBox(height: 12),
          if (!hasParrain)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Étape 1 : Ajoutez un parrain pour continuer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Étape 2 : Prix: ${subscriptionPrice.toInt()} FCFA / 3 mois',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        children: [
          Icon(Icons.group_add, color: Colors.red, size: 50),
          SizedBox(height: 16),
          Text(
            '👑 AJOUTER UN PARRAIN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            'Pour activer le marketing, vous devez d\'abord avoir un parrain.\n\n'
                'Le marketing vous permet de gagner 50% de commission sur chaque activation de vos filleuls.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.add),
            label: Text('AJOUTER UN PARRAIN'),
            onPressed: () {
              setState(() {
                showAddParrainForm = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddParrainForm() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🔑 CODE DE PARRAINAGE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    showAddParrainForm = false;
                    parrainCodeController.clear();
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Entrez le code parrainage de votre parrain',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          TextFormField(
            controller: parrainCodeController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ex: AFRO1234',
              hintStyle: TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.amber),
              ),
              prefixIcon: Icon(Icons.code, color: Colors.grey),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      showAddParrainForm = false;
                      parrainCodeController.clear();
                    });
                  },
                  child: Text('Annuler'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _addParrain(),
                  child: isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                      : Text('Valider'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParrainSection(UserData parrain) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                '✅ VOTRE PARRAIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
              backgroundColor: Colors.green,
              backgroundImage: parrain.imageUrl != null && parrain.imageUrl!.isNotEmpty
                  ? NetworkImage(parrain.imageUrl!)
                  : null,
              child: parrain.imageUrl == null || parrain.imageUrl!.isEmpty
                  ? Text(
                parrain.pseudo?.substring(0, 1).toUpperCase() ?? 'P',
                style: TextStyle(color: Colors.white),
              )
                  : null,
            ),
            title: Text(
              parrain.pseudo ?? 'Parrain',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parrain.email ?? '',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, color: Colors.grey, size: 12),
                    SizedBox(width: 4),
                    Text(
                      parrain.numeroDeTelephone ?? '',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _viewUserProfile(parrain),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility, size: 18),
                SizedBox(width: 8),
                Text('Voir le profil'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(UserData user, bool isActive) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                '📊 STATISTIQUES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
              _buildStatCard(
                icon: Icons.account_balance_wallet,
                title: 'Solde Marketing',
                value: isActive ? '${user.solde_marketing?.toInt() ?? 0} FCFA' : '---',
                color: Colors.green,
                isActive: isActive,
              ),
              _buildStatCard(
                icon: Icons.people,
                title: 'Filleuls Actifs',
                value: isActive ? '${user.nbrParrainagesActifs ?? 0}' : '---',
                color: Colors.blue,
                isActive: isActive,
              ),
              _buildStatCard(
                icon: Icons.trending_up,
                title: 'Total Gains',
                value: isActive ? '${user.total_gains_marketing?.toInt() ?? 0} FCFA' : '---',
                color: Colors.amber,
                isActive: isActive,
              ),
              _buildStatCard(
                icon: Icons.groups,
                title: 'Total Filleuls',
                value: '${user.nbrParrainagesTotal ?? 0}',
                color: Colors.purple,
                isActive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isActive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? color : Colors.grey.shade600,
            size: 28,
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeSection(UserData user) {
    final referralLink = 'https://afrolook.com/inscription?ref=${user.codeParrainage}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.share, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                '🔗 CODE DE PARRAINAGE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.black, Colors.red.shade900],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Column(
              children: [
                Text(
                  user.codeParrainage ?? 'N/A',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontFamily: 'Courier',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Partagez ce code avec vos amis',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(Icons.copy, size: 18),
                  label: Text('Copier'),
                  onPressed: () => _copyToClipboard(user.codeParrainage ?? ''),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(Icons.share, size: 18),
                  label: Text('Partager'),
                  onPressed: () => _shareReferralLink(referralLink),
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

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '👥 FILLEULS ACTIFS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${sponsoredUsers.length} actifs',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (sponsoredUsers.isEmpty)
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.group_off, color: Colors.grey.shade600, size: 40),
                      SizedBox(height: 12),
                      Text(
                        'Aucun filleul actif pour le moment',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Partagez votre code parrainage pour gagner vos premiers filleuls',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: sponsoredUsers
                      .map((user) => _buildSponsoredUserTile(user))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSponsoredUserTile(UserData user) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.red,
          backgroundImage: user.imageUrl != null && user.imageUrl!.isNotEmpty
              ? NetworkImage(user.imageUrl!)
              : null,
          child: user.imageUrl == null || user.imageUrl!.isEmpty
              ? Text(
            user.pseudo?.substring(0, 1).toUpperCase() ?? 'U',
            style: TextStyle(color: Colors.white, fontSize: 12),
          )
              : null,
        ),
        title: Text(
          user.pseudo ?? 'Utilisateur',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          user.email ?? '',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade900,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _viewUserProfile(user),
          child: Text(
            'Profil',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection(bool isActive) {
    final benefits = [
      '🎯 Commission 50% sur activation filleul',
      '🔄 Commission sur chaque renouvellement',
      '📱 Partage illimité d\'images',
      '📢 Publicités ciblées',
      '🎥 Lives gratuits et monétisés',
      '👑 Accès toutes fonctionnalités premium',
      '📈 Statistiques détaillées',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                '✨ AVANTAGES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...benefits.map((benefit) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  color: isActive ? Colors.green : Colors.grey.shade600,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    benefit,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      fontSize: 13,
                      height: 1.4,
                    ),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
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
                    Icon(Icons.description, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '📝 CONDITIONS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  showTerms ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          if (showTerms) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '1. Activation: 4500 FCFA pour 3 mois\n'
                    '2. Commission: 50% parrain / 50% application\n'
                    '3. Paiement: Via solde principal\n'
                    '4. Encaissement: Solde marketing vers solde principal\n'
                    // '5. Suspension: Accès retiré si non renouvelé\n'
                    '5. Abus: Peut entraîner suspension du compte',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: acceptedTerms,
                  onChanged: (value) => setState(() => acceptedTerms = value ?? false),
                  checkColor: Colors.black,
                  activeColor: Colors.amber,
                ),
                Expanded(
                  child: Text(
                    'J\'accepte les conditions d\'utilisation',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(UserData user, bool isActive, int daysLeft, bool isAdmin) {
    final hasEnoughBalance = isAdmin || (user.votre_solde_principal ?? 0) >= subscriptionPrice;
    final canRenew = isActive && daysLeft <= 7;

    return Column(
      children: [
        // Message solde insuffisant
        if (!isAdmin && !hasEnoughBalance && (!isActive || canRenew))
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solde insuffisant',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Il vous manque ${(subscriptionPrice - (user.votre_solde_principal ?? 0)).toInt()} FCFA',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DepositScreen()),
                    );
                  },
                  child: Text(
                    'Recharger',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Message conditions non acceptées
        if (!isActive && !isAdmin && !acceptedTerms && showTerms)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Veuillez accepter les conditions d\'utilisation',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Bouton principal
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _getButtonColor(isActive, canRenew, acceptedTerms, hasEnoughBalance, isAdmin),
              foregroundColor: Colors.white,
              elevation: 4,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: Colors.red,
            ),
            onPressed: isLoading
                ? null
                : () {
              if (!isActive && !isAdmin && !acceptedTerms) {
                setState(() => showTerms = true);
                return;
              }
              if (!isAdmin && (!isActive || canRenew) && !hasEnoughBalance) {
                _showInsufficientBalanceDialog();
                return;
              }
              if (isActive && !canRenew && !isAdmin) {
                _showActiveSubscriptionDialog(daysLeft);
                return;
              }
              _activateOrRenewMarketing(isAdmin);
            },
            child: isLoading
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getButtonIcon(isActive, canRenew, isAdmin), size: 20),
                SizedBox(width: 8),
                Text(
                  _getButtonText(isActive, canRenew, isAdmin),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bouton encaissement si actif
        if (isActive && !canRenew && !isAdmin && (user.solde_marketing ?? 0) > 0)
          SizedBox(height: 12),
        if (isActive && !canRenew && !isAdmin && (user.solde_marketing ?? 0) > 0)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.amber,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber),
                ),
              ),
              icon: Icon(Icons.account_balance_wallet, size: 20),
              label: Text(
                'Encaisser ${user.solde_marketing?.toInt() ?? 0} FCFA',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _encashMarketingBalance(),
            ),
          ),
      ],
    );
  }

  Color _getButtonColor(bool isActive, bool canRenew, bool acceptedTerms, bool hasEnoughBalance, bool isAdmin) {
    if (isAdmin) return Colors.red.shade900;
    if (isActive && !canRenew) return Colors.grey.shade800;
    if (!isActive && (!acceptedTerms || !hasEnoughBalance)) return Colors.grey.shade800;
    if (canRenew && !hasEnoughBalance) return Colors.grey.shade800;
    return Colors.red;
  }

  IconData _getButtonIcon(bool isActive, bool canRenew, bool isAdmin) {
    if (isAdmin) return Icons.admin_panel_settings;
    if (isActive && canRenew) return Icons.autorenew;
    if (isActive) return Icons.verified;
    return Icons.rocket_launch;
  }

  String _getButtonText(bool isActive, bool canRenew, bool isAdmin) {
    if (isAdmin) return 'COMPTE ADMIN ACTIF';
    if (isActive && canRenew) return 'RENOUVELER - ${subscriptionPrice.toInt()} FCFA';
    if (isActive) return 'COMPTE MARKETING ACTIF';
    return 'ACTIVER LE MARKETING - ${subscriptionPrice.toInt()} FCFA';
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
      print('Erreur récupération filleuls: $e');
      return [];
    }
  }

  Future<void> _addParrain() async {
    final code = parrainCodeController.text.trim();
    if (code.isEmpty) {
      _showErrorSnackbar('Veuillez entrer un code de parrainage');
      return;
    }

    setState(() => isLoading = true);

    try {
      // Vérifier si le code existe
      final parrainQuery = await firestore
          .collection('Users')
          .where('code_parrainage', isEqualTo: code)
          .get();

      if (parrainQuery.docs.isEmpty) {
        _showErrorSnackbar('Code de parrainage invalide');
        setState(() => isLoading = false);
        return;
      }

      // Ne pas permettre de s'auto-parrainer
      final currentUser = authProvider.loginUserData;
      if (currentUser.codeParrainage == code) {
        _showErrorSnackbar('Vous ne pouvez pas être votre propre parrain');
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

      // Recharger les données
      await _refreshPage();

      _showSuccessSnackbar('Parrain ajouté avec succès !');

    } catch (e) {
      print('Erreur ajout parrain: $e');
      _showErrorSnackbar('Erreur lors de l\'ajout du parrain');
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

      _showSuccessSnackbar('Données actualisées');
    } catch (e) {
      _showErrorSnackbar('Erreur lors de l\'actualisation');
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
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber.shade800,
        content: Row(
          children: [
            Icon(Icons.check, color: Colors.black),
            SizedBox(width: 8),
            Text(
              'Code copié dans le presse-papier !',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareReferralLink(String link) {
    Share.share(
      'Rejoins-moi sur Afrolook ! 🚀\n\nUtilise mon code de parrainage : $link\n\nGagne des commissions et profite de toutes les fonctionnalités premium !',
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          'Solde insuffisant',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Votre solde (${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA) '
              'est insuffisant pour l\'activation du marketing (${subscriptionPrice.toInt()} FCFA). '
              'Voulez-vous recharger votre compte ?',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DepositScreen()),
              );
            },
            child: Text('Recharger maintenant'),
          ),
        ],
      ),
    );
  }

  void _showActiveSubscriptionDialog(int daysLeft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          'Compte actif',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Votre compte marketing est actif pour encore $daysLeft jours. '
              'Vous pourrez renouveler 7 jours avant l\'expiration.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('Compris'),
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

      _showSuccessSnackbar(
          isAdmin
              ? '✅ Compte marketing activé (Admin)'
              : '🎉 Compte marketing activé pour 3 mois !'
      );

    } catch (e) {
      print('Erreur activation marketing: $e');
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
      final commissionParrain = subscriptionPrice * 0.5;
      final commissionApp = subscriptionPrice * 0.5;

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
      print('Erreur distribution commissions: $e');
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
      print('Erreur envoi notification commission: $e');
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
      print('Erreur création transaction: $e');
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

      _showSuccessSnackbar('✅ ${marketingBalance.toInt()} FCFA encaissés sur votre solde principal !');
    } catch (e) {
      print('Erreur encaissement: $e');
      _showErrorSnackbar('Erreur lors de l\'encaissement');
    } finally {
      setState(() => isLoading = false);
    }
  }
}