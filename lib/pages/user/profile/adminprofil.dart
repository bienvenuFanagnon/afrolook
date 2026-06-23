import 'package:afrotok/pages/user/profile/retraitAdmin/retraitAdminList.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/pages/user/profile/retraitAdmin/searchUserAdmin.dart';
import 'package:afrotok/providers/authProvider.dart';

import 'package:flutter/material.dart';

import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:iconsax/iconsax.dart';

import '../../../models/model_data.dart';

import '../../Marketing/adminAffiliationStatsPage.dart';

import '../../admin/ad_admin_page.dart';

import '../../admin/remuneration_admin_page.dart';

import '../monetisation.dart';

class AdminHubPage extends StatefulWidget {
  @override
  _AdminHubPageState createState() => _AdminHubPageState();
}

class _AdminHubPageState extends State<AdminHubPage> {
  late UserAuthProvider appDataProvider;
  bool _showDetailedStats = false;
  Map<String, int> _retraitStats = {
    'total': 0,
    'en_attente': 0,
    'valider': 0,
    'annule': 0
  };

  Stream<AppDefaultData>? appDataStream;

  @override
  void initState() {
    super.initState();
    appDataProvider = Provider.of<UserAuthProvider>(context, listen: false);
    appDataStream = appDataProvider.getAppDataStream();
    _loadRetraitStats();
  }

  Future<void> _loadRetraitStats() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('TransactionRetraits')
          .get();

      int total = snapshot.docs.length;
      int enAttente = 0;
      int valider = 0;
      int annule = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final statut = data['statut']?.toString().toLowerCase();

        switch (statut) {
          case 'en_attente':
            enAttente++;
            break;
          case 'valider':
            valider++;
            break;
          case 'annule':
            annule++;
            break;
        }
      }

      setState(() {
        _retraitStats = {
          'total': total,
          'en_attente': enAttente,
          'valider': valider,
          'annule': annule
        };
      });
    } catch (e) {
      printVm('Erreur chargement stats retraits: $e');
    }
  }

  void refreshData() {
    setState(() {
      appDataStream = appDataProvider.getAppDataStream();
      _loadRetraitStats();
    });
  }

  Future<int> getUsersCount() async {
    final aggregateQuery = await FirebaseFirestore.instance
        .collection("Users")
        .count()
        .get();
    return aggregateQuery.count ?? 0;
  }

  // Helpers pour les stats financières
  Widget _buildCompactStat({
    required String label,
    required double value,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[400], size: 12),
          SizedBox(height: 4),
          Text(
            "${(value / 1000).toStringAsFixed(2)}K",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPiecesDetailRow({
    required String label,
    required double value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        Text(
          "${value.ceil()} 🪙",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  Widget _buildDetailRow({
    required String label,
    required double value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
        Text(
          "${value.toStringAsFixed(0)} FCFA",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(
          'ADMIN HUB',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Iconsax.refresh, color: Colors.white),
            onPressed: refreshData,
            tooltip: "Actualiser",
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Color(0xFFFFD700), Colors.black],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<AppDefaultData>(
        stream: appDataStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700))));
          }

          final appData = snapshot.data ?? AppDefaultData();

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec bienvenue
                _buildWelcomeHeader(),
                SizedBox(height: 24),

                // 📊 SECTION FINANCIÈRE (ce qui était dans AppInfoPage)
                Text(
                  'STATISTIQUES FINANCIÈRES',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 16),

                // Carte des soldes (version compacte/détaillée)
                _buildSoldesCard(appData),
                SizedBox(height: 24),

                // 📊 STATISTIQUES GÉNÉRALES
                Text(
                  'STATISTIQUES GÉNÉRALES',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 16),

                // Grille des stats générales
                _buildStatsGenerales(appData),
                SizedBox(height: 24),

                // 📊 DEMANDES DE RETRAIT
                _buildRetraitSummary(),
                SizedBox(height: 24),

                // 🎯 SECTIONS ADMINISTRATION
                Text(
                  'SECTIONS ADMINISTRATION',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 16),

                // Grille des modules admin
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _buildAdminCard(
                      titre: 'RÉMUNÉRATION',
                      sousTitre: 'Gains & statistiques',
                      icon: Icons.monetization_on,
                      couleur: Color(0xFFFFD700),
                      page: RemunerationAdminPage(),
                    ),
                    _buildAdminCard(
                      titre: 'RETRAITS',
                      sousTitre: '${_retraitStats['en_attente']} en attente',
                      icon: Iconsax.money_send,
                      couleur: Colors.blue,
                      page: AdminRetraitListPage(),
                    ),
                    _buildAdminCard(
                      titre: 'PUBLICITÉS',
                      sousTitre: 'Gestion des annonces',
                      icon: Iconsax.video_play,
                      couleur: Colors.purple,
                      page: AdAdminPage(),
                    ),
                    _buildAdminCard(
                      titre: 'AFFILIATION',
                      sousTitre: 'Stats parrainage',
                      icon: Iconsax.people,
                      couleur: Colors.green,
                      page: AdminAffiliationStatsPage(),
                    ),
                    _buildAdminCard(
                      titre: 'UTILISATEURS',
                      sousTitre: 'Recherche & gestion',
                      icon: Iconsax.profile_2user,
                      couleur: Colors.orange,
                      page: UserSearchPage(),
                    ),
                    _buildAdminCard(
                      titre: 'TRANSACTIONS',
                      sousTitre: 'Historique complet',
                      icon: Iconsax.receipt,
                      couleur: Colors.teal,
                      page: TransactionsListPage(),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // ℹ️ INFORMATIONS DE VERSION
                _buildVersionInfo(appData),
                SizedBox(height: 24),

                // 💰 TARIFS
                _buildTarifsInfo(appData),
                SizedBox(height: 24),

                // 🎯 POINTS PAR DÉFAUT
                _buildPointsInfo(appData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Colors.black],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFFFD700).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.admin_panel_settings,
              color: Color(0xFFFFD700),
              size: 30,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESPACE ADMINISTRATEUR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Gérez tous les aspects de l\'application',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoldesCard(AppDefaultData appData) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          // En-tête avec bouton expand
          GestureDetector(
            onTap: () => setState(() => _showDetailedStats = !_showDetailedStats),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.grey[400], size: 16),
                    SizedBox(width: 8),
                    Text(
                      "STATS FINANCIÈRES",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showDetailedStats ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[500],
                  size: 16,
                ),
              ],
            ),
          ),

          // Vue réduite (toujours visible)
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCompactStat(
                label: "Principal",
                value: appData.solde_principal ?? 0,
                icon: Icons.account_balance_wallet,
              ),
              Container(width: 1, height: 20, color: Colors.grey[800]),
              _buildCompactStat(
                label: "Gains",
                value: appData.solde_gain ?? 0,
                icon: Icons.monetization_on,
              ),
              Container(width: 1, height: 20, color: Colors.grey[800]),
              _buildCompactStat(
                label: "Affiliation",
                value: appData.solde_affiliation ?? 0,
                icon: Icons.group,
              ),
              Container(width: 1, height: 20, color: Colors.grey[800]),
              _buildCompactStat(
                label: "Gains pieces",
                value: appData.solde_gain_pieces ?? 0,
                icon: Icons.monetization_on,
              ),
            ],
          ),

          // Vue détaillée (si expand)
          if (_showDetailedStats) ...[
            SizedBox(height: 12),
            Divider(color: Colors.grey[800], height: 1),
            SizedBox(height: 12),
            Column(
              children: [
                _buildDetailRow(
                  label: "Solde Principal",
                  value: appData.solde_principal ?? 0,
                ),
                SizedBox(height: 8),
                _buildDetailRow(
                  label: "Gains Totaux",
                  value: appData.solde_gain ?? 0,
                ),
                SizedBox(height: 8),
                _buildDetailRow(
                  label: "Affiliation",
                  value: appData.solde_affiliation ?? 0,
                ),
                SizedBox(height: 8),
                _buildPiecesDetailRow(
                  label: "Gains pieces",
                  value: appData.solde_gain_pieces ?? 0,
                ),
                SizedBox(height: 8),
                _buildDetailRow(
                  label: "Total Général",
                  value: (appData.solde_principal ?? 0) +
                      (appData.solde_gain ?? 0) +
                      (appData.solde_affiliation ?? 0) +(0.4*
                      (appData.solde_gain_pieces ?? 0)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGenerales(AppDefaultData appData) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        FutureBuilder<int>(
          future: getUsersCount(),
          builder: (context, snapshot) {
            return _buildStatCard(
              title: "Utilisateurs",
              value: _formatNumber(snapshot.data ?? 0),
              icon: Iconsax.profile_2user,
              color: Color(0xFF00CC66),
            );
          },
        ),
        _buildStatCard(
          title: "Abonnés",
          value: _formatNumber(appData.nbr_abonnes ?? 0),
          icon: Iconsax.people,
          color: Color(0xFF007AFF),
        ),

        _buildStatCard(
          title: "Likes",
          value: _formatNumber(appData.nbr_likes ?? 0),
          icon: Iconsax.like_1,
          color: Color(0xFFFF2D55),
        ),
        _buildStatCard(
          title: "Commentaires",
          value: _formatNumber(appData.nbr_comments ?? 0),
          icon: Iconsax.message,
          color: Color(0xFFFF9500),
        ),
      ],
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard({
    required String titre,
    required String sousTitre,
    required IconData icon,
    required Color couleur,
    required Widget page,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: couleur.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                icon,
                size: 60,
                color: couleur.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: couleur.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: couleur, size: 24),
                  ),
                  SizedBox(height: 12),
                  Text(
                    titre,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    sousTitre,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetraitSummary() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a237e), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.4),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "DEMANDES DE RETRAIT",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminRetraitListPage()),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Gérer",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Iconsax.arrow_right_3, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Statistiques en ligne
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRetraitStatItem(
                "Total",
                _retraitStats['total']!.toString(),
                Iconsax.money_send,
                Colors.white,
              ),
              _buildRetraitStatItem(
                "En Attente",
                _retraitStats['en_attente']!.toString(),
                Iconsax.clock,
                Colors.orange,
              ),
              _buildRetraitStatItem(
                "Validés",
                _retraitStats['valider']!.toString(),
                Iconsax.tick_circle,
                Colors.green,
              ),
              _buildRetraitStatItem(
                "Annulés",
                _retraitStats['annule']!.toString(),
                Iconsax.close_circle,
                Colors.red,
              ),
            ],
          ),

          if (_retraitStats['total']! > 0) ...[
            SizedBox(height: 12),
            // Barre de progression
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  if (_retraitStats['en_attente']! > 0)
                    Expanded(
                      flex: _retraitStats['en_attente']!,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(3),
                            bottomLeft: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  if (_retraitStats['valider']! > 0)
                    Expanded(
                      flex: _retraitStats['valider']!,
                      child: Container(
                        color: Colors.green,
                      ),
                    ),
                  if (_retraitStats['annule']! > 0)
                    Expanded(
                      flex: _retraitStats['annule']!,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(3),
                            bottomRight: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${_retraitStats['en_attente']!} demande(s) en attente de traitement',
              style: TextStyle(
                color: _retraitStats['en_attente']! > 0 ? Colors.orange : Colors.white70,
                fontSize: 12,
                fontWeight: _retraitStats['en_attente']! > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRetraitStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo(AppDefaultData appData) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "INFORMATIONS DE VERSION",
            style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            "Version actuelle",
            "${appData.app_version_code ?? 0}",
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            "Version officielle",
            "${appData.app_version_code_officiel ?? 0}",
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            "Vérification Google",
            appData.googleVerification == true ? "Activée" : "Désactivée",
            valueColor: appData.googleVerification == true
                ? Color(0xFF00CC66)
                : Color(0xFFFF3B30),
          ),
        ],
      ),
    );
  }

  Widget _buildTarifsInfo(AppDefaultData appData) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TARIFS",
            style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            "PubliCash",
            "${appData.tarifPubliCash?.toStringAsFixed(2) ?? '0.00'}",
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            "Conversion PubliCash",
            "${appData.tarifPubliCash_to_xof?.toStringAsFixed(2) ?? '0.00'} FCFA",
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            "Image",
            "${appData.tarifImage?.toStringAsFixed(2) ?? '0.00'}",
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            "Vidéo",
            "${appData.tarifVideo?.toStringAsFixed(2) ?? '0.00'}",
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            "Par jour",
            "${appData.tarifjour?.toStringAsFixed(2) ?? '0.00'}",
          ),
        ],
      ),
    );
  }

  Widget _buildPointsInfo(AppDefaultData appData) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "POINTS PAR DÉFAUT",
            style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            "Nouvel utilisateur",
            "${appData.default_point_new_user ?? 0} pts",
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            "Nouveau like",
            "${appData.default_point_new_like ?? 0} pts",
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            "Nouveau love",
            "${appData.default_point_new_love ?? 0} pts",
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      double result = number / 1000000;
      return '${result.toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      double result = number / 1000;
      return '${result.toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}

// ==================== TRANSACTIONS LIST PAGE AVEC PAGINATION FIRESTORE ====================

class TransactionsListPage extends StatefulWidget {
  const TransactionsListPage({Key? key}) : super(key: key);

  @override
  _TransactionsListPageState createState() => _TransactionsListPageState();
}

class _TransactionsListPageState extends State<TransactionsListPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedType = "TOUS";
  String? _selectedUserId;
  final TextEditingController _emailController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Pagination Firestore
  final int _pageSize = 10;
  List<QueryDocumentSnapshot> _allDocs = [];
  List<TransactionSolde> _transactions = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isInitialLoad = true;

  // Pour éviter les appels multiples
  bool _isFiltering = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        !_isLoadingMore &&
        _hasMore &&
        !_isFiltering) {
      printVm("📜 Scroll en bas - Chargement de la page suivante...");
      _loadNextPage();
    }
  }

  /// Construction de la requête de base
  Query _buildBaseQuery() {
    Query query = FirebaseFirestore.instance
        .collection("TransactionSoldes")
        .orderBy("createdAt", descending: true);

    // Filtre par utilisateur si sélectionné
    if (_selectedUserId != null && _selectedUserId!.isNotEmpty) {
      printVm("🔍 Filtre par user_id: $_selectedUserId");
      query = query.where("user_id", isEqualTo: _selectedUserId);
    }

    return query;
  }

  /// Charger la première page
  Future<void> _loadFirstPage() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isInitialLoad = true;
      _transactions = [];
      _allDocs = [];
      _lastDocument = null;
      _hasMore = true;
    });

    printVm("🚀 Chargement de la première page...");
    printVm("🔍 Filtres - Type: $_selectedType, StartDate: $_startDate, EndDate: $_endDate, UserId: $_selectedUserId");

    try {
      Query query = _buildBaseQuery();
      query = query.limit(_pageSize);

      final snapshot = await query.get();
      printVm("📊 Nombre de documents reçus: ${snapshot.docs.length}");

      _allDocs = snapshot.docs;
      _transactions = _applyLocalFilters(snapshot.docs);

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
      } else {
        _hasMore = false;
      }

      printVm("📊 Transactions après filtre local: ${_transactions.length}");
      printVm("📊 hasMore: $_hasMore");

    } catch (e, stack) {
      printVm("❌ Erreur chargement première page: $e");
      printVm(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  /// Charger la page suivante
  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore || _isFiltering) return;

    setState(() {
      _isLoadingMore = true;
    });

    printVm("🚀 Chargement de la page suivante...");
    printVm("📄 LastDocument: ${_lastDocument?.id}");

    try {
      Query query = _buildBaseQuery();
      query = query.startAfterDocument(_lastDocument!).limit(_pageSize);

      final snapshot = await query.get();
      printVm("📊 Nouveaux documents reçus: ${snapshot.docs.length}");

      if (snapshot.docs.isNotEmpty) {
        _allDocs.addAll(snapshot.docs);
        final newTransactions = _applyLocalFilters(snapshot.docs);
        _transactions.addAll(newTransactions);
        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
      } else {
        _hasMore = false;
      }

      printVm("📊 Total transactions: ${_transactions.length}");
      printVm("📊 hasMore: $_hasMore");

    } catch (e, stack) {
      printVm("❌ Erreur chargement page suivante: $e");
      printVm(stack);
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// Appliquer les filtres locaux (date et type)
  List<TransactionSolde> _applyLocalFilters(List<QueryDocumentSnapshot> docs) {
    final filtered = <TransactionSolde>[];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      final transaction = TransactionSolde.fromJson(data);

      // Filtre par date
      if (_startDate != null || _endDate != null) {
        if (transaction.createdAt == null) continue;
        final date = DateTime.fromMillisecondsSinceEpoch(transaction.createdAt!);

        if (_startDate != null && date.isBefore(_startDate!)) continue;
        if (_endDate != null && date.isAfter(_endDate!.add(const Duration(days: 1)))) continue;
      }

      // Filtre par type
      if (_selectedType != "TOUS") {
        final transactionType = transaction.type?.toUpperCase() ?? "";
        if (transactionType != _selectedType) continue;
      }

      filtered.add(transaction);
    }

    return filtered;
  }

  /// Appliquer tous les filtres (réinitialise la pagination)
  Future<void> _applyFilters() async {
    if (_isFiltering) return;

    setState(() {
      _isFiltering = true;
    });

    printVm("🔄 Application des filtres...");

    // Réinitialiser tout
    _transactions = [];
    _allDocs = [];
    _lastDocument = null;
    _hasMore = true;
    _isLoadingMore = false;

    await _loadFirstPage();

    setState(() {
      _isFiltering = false;
    });
  }

  /// Rechercher un utilisateur par email
  Future<void> _searchUserByEmail() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _selectedUserId = null;
      });
      _applyFilters();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection("Users")
          .where("email", isEqualTo: _emailController.text.trim())
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userId = userQuery.docs.first.id;
        final userData = UserData.fromJson(userQuery.docs.first.data());

        setState(() {
          _selectedUserId = userId;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Utilisateur trouvé: ${userData.pseudo ?? userData.email}"),
            backgroundColor: Colors.green,
          ),
        );
        _applyFilters();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aucun utilisateur trouvé avec cet email"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _selectedUserId = null;
        });
      }
    } catch (e) {
      printVm("❌ Erreur recherche utilisateur: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      locale: const Locale("fr", "FR"),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _applyFilters();
    }
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedType = "TOUS";
      _selectedUserId = null;
      _emailController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          "Transactions",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: _selectedType,
              dropdownColor: Colors.black87,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              underline: const SizedBox(),
              items: _getTypeDropdownItems(),
              onChanged: (val) {
                setState(() {
                  _selectedType = val!;
                });
                _applyFilters();
              },
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche par email
          _buildSearchBar(),

          // Filtres par date
          _buildDateFilters(),

          // Indicateur de filtre utilisateur
          if (_selectedUserId != null) _buildUserFilterIndicator(),

          // Liste des transactions
          Expanded(
            child: _buildTransactionList(),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _getTypeDropdownItems() {
    final types = [
      "TOUS",
      "DEPOT",
      "DEPOTADMIN",
      "RETRAIT",
      "RETRAITADMIN",
      "GAIN",
      "GAIN_PIECES",
      "DEPENSE",
      "ACHAT_PIECES",
      "CONVERSION_PIECES",
      "CADEAU_PIECES",
      "CADEAU_PIECES_RECU",
      "LIKE_PIECES",
    ];

    return types.map((type) {
      return DropdownMenuItem(
        value: type,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getTransactionColor(type == "TOUS" ? null : type),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              type == "TOUS" ? "TOUS" : _formatTransactionType(type),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[800],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Rechercher par email...",
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[700],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                  onPressed: () {
                    _emailController.clear();
                    setState(() {
                      _selectedUserId = null;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.search, color: Colors.yellow[700]),
            onPressed: _searchUserByEmail,
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _startDate == null
                    ? "Date début"
                    : DateFormat("dd/MM/yyyy").format(_startDate!),
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _selectDate(context, true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _endDate == null
                    ? "Date fin"
                    : DateFormat("dd/MM/yyyy").format(_endDate!),
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _selectDate(context, false),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _resetFilters,
            child: const Icon(Icons.clear, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFilterIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[900]!.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Filtré par utilisateur ID: $_selectedUserId",
            style: TextStyle(color: Colors.blue[200], fontSize: 12),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: Colors.blue[200]),
            onPressed: () {
              setState(() {
                _selectedUserId = null;
                _emailController.clear();
              });
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    // État de chargement initial
    if (_isInitialLoad && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
        ),
      );
    }

    // Aucune transaction
    if (_transactions.isEmpty && !_isLoading && !_isLoadingMore) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            Text(
              "Aucune transaction",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedUserId != null
                  ? "Cet utilisateur n'a aucune transaction"
                  : "Aucune transaction trouvée",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow[700],
                foregroundColor: Colors.black,
              ),
              child: const Text("Réinitialiser les filtres"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length + (_hasMore && !_isFiltering ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _transactions.length) {
          return _buildLoadingMoreIndicator();
        }
        return _buildTransactionCard(_transactions[index]);
      },
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
        )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionSolde transaction) {
    final color = _getTransactionColor(transaction.type);
    final icon = _getTransactionIcon(transaction.type);
    final typeText = _formatTransactionType(transaction.type);
    final isDepot = transaction.type == 'DEPOT' || transaction.type == 'DEPOTADMIN';
    final isGain = transaction.type == 'GAIN' || transaction.type == 'GAIN_PIECES';
    final isCoinTransaction = transaction.type == 'ACHAT_PIECES' ||
        transaction.type == 'CADEAU_PIECES' ||
        transaction.type == 'CADEAU_PIECES_RECU' ||
        transaction.type == 'LIKE_PIECES' ||
        transaction.type == 'GAIN_PIECES';

    String amountDisplay;
    if (isCoinTransaction && transaction.type != 'ACHAT_PIECES') {
      amountDisplay = "${transaction.montant?.toInt()} 🪙";
    } else if (transaction.type == 'ACHAT_PIECES') {
      amountDisplay = "${transaction.montant?.toStringAsFixed(2)} FCFA";
    } else {
      amountDisplay = "${transaction.montant?.toStringAsFixed(2)} FCFA";
    }

    final prefix = isDepot || isGain ? "+ " : "- ";

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$prefix$amountDisplay',
              style: TextStyle(
                color: isDepot || isGain ? Colors.green : Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Text(
                typeText,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.description != null && transaction.description!.isNotEmpty)
              Text(
                transaction.description!,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              _formatDate(transaction.createdAt ?? 0),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[600],
          size: 16,
        ),
        onTap: () => _showTransactionDetails(transaction),
      ),
    );
  }

  Future<void> _showTransactionDetails(TransactionSolde transaction) async {
    UserData? userData;
    if (transaction.user_id != null && transaction.user_id!.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection("Users")
            .doc(transaction.user_id)
            .get();

        if (userDoc.exists) {
          userData = UserData.fromJson(userDoc.data()!);
        }
      } catch (e) {
        printVm("❌ Erreur chargement utilisateur: $e");
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.yellow[700]),
            const SizedBox(width: 8),
            const Text(
              "Détails de la transaction",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (userData != null) ...[
                _buildDetailItem("Utilisateur", "${userData.pseudo ?? 'N/A'} (${userData.email ?? 'N/A'})"),
                _buildDetailItem("Téléphone", userData.numeroDeTelephone ?? 'N/A'),
                const SizedBox(height: 16),
              ],
              _buildDetailItem("Type", _formatTransactionType(transaction.type)),
              _buildDetailItem("Montant", "${transaction.montant?.toStringAsFixed(2) ?? '0.00'} ${transaction.type == 'ACHAT_PIECES' ? 'FCFA' : '🪙'}"),
              if (transaction.frais != null && transaction.frais! > 0)
                _buildDetailItem("Frais", "${transaction.frais?.toStringAsFixed(2) ?? '0.00'} FCFA"),
              if (transaction.description != null && transaction.description!.isNotEmpty)
                _buildDetailItem("Description", transaction.description!),
              if (transaction.statut != null && transaction.statut!.isNotEmpty)
                _buildDetailItem("Statut", transaction.statut!),
              if (transaction.methode_paiement != null && transaction.methode_paiement!.isNotEmpty)
                _buildDetailItem("Méthode", transaction.methode_paiement!),
              _buildDetailItem("Date", _formatDetailedDate(transaction.createdAt ?? 0)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Fermer",
              style: TextStyle(color: Colors.yellow[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== MÉTHODES UTILITAIRES ====================

  Color _getTransactionColor(String? type) {
    switch (type?.toUpperCase()) {
      case 'DEPOT':
      case 'DEPOTADMIN':
        return Colors.green;
      case 'RETRAIT':
      case 'RETRAITADMIN':
        return Colors.orange;
      case 'GAIN':
      case 'GAIN_PIECES':
        return Colors.blue;
      case 'DEPENSE':
      case 'ACHAT_PIECES':
      case 'CADEAU_PIECES':
      case 'LIKE_PIECES':
        return Colors.red;
      case 'CONVERSION_PIECES':
        return Colors.purple;
      case 'CADEAU_PIECES_RECU':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getTransactionIcon(String? type) {
    switch (type?.toUpperCase()) {
      case 'DEPOT':
      case 'DEPOTADMIN':
        return Iconsax.arrow_down;
      case 'RETRAIT':
      case 'RETRAITADMIN':
        return Iconsax.arrow_up;
      case 'GAIN':
      case 'GAIN_PIECES':
        return Iconsax.gift;
      case 'DEPENSE':
        return Iconsax.wallet_minus;
      case 'ACHAT_PIECES':
        return Iconsax.shopping_bag;
      case 'CONVERSION_PIECES':
        return Iconsax.convert_card;
      case 'CADEAU_PIECES':
      case 'CADEAU_PIECES_RECU':
        return Iconsax.gift;
      case 'LIKE_PIECES':
        return Iconsax.heart;
      default:
        return Iconsax.transaction_minus;
    }
  }

  String _formatTransactionType(String? type) {
    switch (type?.toUpperCase()) {
      case 'DEPOTADMIN':
        return 'Dépôt Admin';
      case 'RETRAITADMIN':
        return 'Retrait Admin';
      case 'DEPOT':
        return 'Dépôt';
      case 'RETRAIT':
        return 'Retrait';
      case 'GAIN':
        return 'Gain';
      case 'GAIN_PIECES':
        return 'Gain en pièces';
      case 'DEPENSE':
        return 'Dépense';
      case 'ACHAT_PIECES':
        return 'Achat pièces';
      case 'CONVERSION_PIECES':
        return 'Conversion';
      case 'CADEAU_PIECES':
        return 'Cadeau envoyé';
      case 'CADEAU_PIECES_RECU':
        return 'Cadeau reçu';
      case 'LIKE_PIECES':
        return 'Like envoyé';
      default:
        return type ?? 'Inconnu';
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAfter(today)) {
      return 'Aujourd\'hui à ${DateFormat('HH:mm').format(date)}';
    } else if (date.isAfter(yesterday)) {
      return 'Hier à ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd/MM/yyyy à HH:mm').format(date);
    }
  }

  String _formatDetailedDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy à HH:mm:ss').format(date);
  }
}

// class TransactionsListPage extends StatefulWidget {
//   const TransactionsListPage({Key? key}) : super(key: key);
//
//   @override
//   _TransactionsListPageState createState() => _TransactionsListPageState();
// }
//
// class _TransactionsListPageState extends State<TransactionsListPage> {
//   DateTime? _startDate;
//   DateTime? _endDate;
//   String _selectedType = "TOUS";
//   String? _selectedUserEmail;
//   final TextEditingController _emailController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//
//   // Pagination
//   int _currentPage = 0;
//   final int _pageSize = 10;
//   List<TransactionSolde> _allTransactions = [];
//   List<TransactionSolde> _displayedTransactions = [];
//   bool _isLoadingMore = false;
//   bool _hasMoreData = true;
//   bool _isInitialLoad = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _scrollController.addListener(_scrollListener);
//     // Charger les données initiales
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _applyFilters();
//     });
//   }
//
//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _emailController.dispose();
//     super.dispose();
//   }
//
//   void _scrollListener() {
//     if (_scrollController.offset >=
//         _scrollController.position.maxScrollExtent - 100 &&
//         !_scrollController.position.outOfRange &&
//         !_isLoadingMore &&
//         _hasMoreData) {
//       _loadMoreTransactions();
//     }
//   }
//
//   Future<void> _loadMoreTransactions() async {
//     if (_isLoadingMore) return;
//
//     setState(() {
//       _isLoadingMore = true;
//     });
//
//     await Future.delayed(Duration(milliseconds: 500));
//
//     final nextPage = _currentPage + 1;
//     final startIndex = nextPage * _pageSize;
//
//     if (startIndex >= _allTransactions.length) {
//       setState(() {
//         _hasMoreData = false;
//         _isLoadingMore = false;
//       });
//       return;
//     }
//
//     final endIndex = (startIndex + _pageSize).clamp(0, _allTransactions.length);
//     final newTransactions = _allTransactions.sublist(startIndex, endIndex);
//
//     setState(() {
//       _displayedTransactions.addAll(newTransactions);
//       _currentPage = nextPage;
//       _isLoadingMore = false;
//       _hasMoreData = endIndex < _allTransactions.length;
//     });
//   }
//
//   Future<void> _selectDate(BuildContext context, bool isStart) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(2023),
//       lastDate: DateTime(2100),
//       locale: const Locale("fr", "FR"),
//     );
//     if (picked != null) {
//       setState(() {
//         if (isStart) {
//           _startDate = picked;
//         } else {
//           _endDate = picked;
//         }
//       });
//       _applyFilters();
//     }
//   }
//
//   Future<void> _searchUserByEmail() async {
//     if (_emailController.text.isEmpty) {
//       setState(() {
//         _selectedUserEmail = null;
//       });
//       _applyFilters();
//       return;
//     }
//
//     // Rechercher l'utilisateur par email
//     final userQuery = await FirebaseFirestore.instance
//         .collection("Users")
//         .where("email", isEqualTo: _emailController.text.trim())
//         .limit(1)
//         .get();
//
//     if (userQuery.docs.isNotEmpty) {
//       final userData = UserData.fromJson(userQuery.docs.first.data());
//       setState(() {
//         _selectedUserEmail = userData.email;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Utilisateur trouvé: ${userData.pseudo ?? userData.email}"),
//           backgroundColor: Colors.green,
//         ),
//       );
//       _applyFilters();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Aucun utilisateur trouvé avec cet email"),
//           backgroundColor: Colors.red,
//         ),
//       );
//       setState(() {
//         _selectedUserEmail = null;
//       });
//       _applyFilters();
//     }
//   }
//
//   void _applyFilters() {
//     setState(() {
//       _currentPage = 0;
//       _displayedTransactions = [];
//       _hasMoreData = true;
//       _isInitialLoad = true;
//     });
//   }
//
//   // Stream pour récupérer les transactions avec filtres
//   Stream<List<TransactionSolde>> get _transactionsStream {
//     Query query = FirebaseFirestore.instance
//         .collection("TransactionSoldes")
//         .orderBy("createdAt", descending: true);
//
//     // Si un email utilisateur est sélectionné, on filtre par user_id
//     if (_selectedUserEmail != null && _selectedUserEmail!.isNotEmpty) {
//       // On retourne un stream vide temporairement, le vrai filtre se fera après
//       return Stream.value([]);
//     }
//
//     return query.snapshots().map((snapshot) {
//       List<TransactionSolde> transactions = snapshot.docs.map((e) {
//         final data = e.data() as Map<String, dynamic>;
//         data['id'] = e.id;
//         return TransactionSolde.fromJson(data);
//       }).toList();
//
//       // Appliquer les filtres locaux (date et type)
//       return transactions.where((t) {
//         if (t.createdAt == null) return false;
//         final date = DateTime.fromMillisecondsSinceEpoch(t.createdAt!);
//
//         // Filtrage par date
//         if (_startDate != null && date.isBefore(_startDate!)) {
//           return false;
//         }
//         if (_endDate != null && date.isAfter(_endDate!.add(const Duration(days: 1)))) {
//           return false;
//         }
//
//         // Filtrage par type
//         if (_selectedType != "TOUS" && t.type?.toUpperCase() != _selectedType) {
//           return false;
//         }
//
//         return true;
//       }).toList();
//     });
//   }
//
//   // Stream pour récupérer les transactions d'un utilisateur spécifique
//   Stream<List<TransactionSolde>> get _userTransactionsStream {
//     if (_selectedUserEmail == null || _selectedUserEmail!.isEmpty) {
//       return Stream.value([]);
//     }
//
//     // D'abord récupérer l'ID utilisateur à partir de l'email
//     return FirebaseFirestore.instance
//         .collection("Users")
//         .where("email", isEqualTo: _selectedUserEmail)
//         .limit(1)
//         .snapshots()
//         .asyncMap((userSnapshot) async {
//       if (userSnapshot.docs.isEmpty) return [];
//
//       final userId = userSnapshot.docs.first.id;
//
//       // Maintenant récupérer les transactions de cet utilisateur
//       final transactionsSnapshot = await FirebaseFirestore.instance
//           .collection("TransactionSoldes")
//           .where("user_id", isEqualTo: userId)
//           .orderBy("createdAt", descending: true)
//           .get();
//
//       List<TransactionSolde> transactions = transactionsSnapshot.docs.map((e) {
//         final data = e.data() as Map<String, dynamic>;
//         data['id'] = e.id;
//         return TransactionSolde.fromJson(data);
//       }).toList();
//
//       // Appliquer les filtres locaux (date et type)
//       return transactions.where((t) {
//         if (t.createdAt == null) return false;
//         final date = DateTime.fromMillisecondsSinceEpoch(t.createdAt!);
//
//         // Filtrage par date
//         if (_startDate != null && date.isBefore(_startDate!)) {
//           return false;
//         }
//         if (_endDate != null && date.isAfter(_endDate!.add(const Duration(days: 1)))) {
//           return false;
//         }
//
//         // Filtrage par type
//         if (_selectedType != "TOUS" && t.type?.toUpperCase() != _selectedType) {
//           return false;
//         }
//
//         return true;
//       }).toList();
//     });
//   }
//
//   // Méthode principale pour obtenir le stream selon le filtre
//   Stream<List<TransactionSolde>> get _filteredTransactionsStream {
//     if (_selectedUserEmail != null && _selectedUserEmail!.isNotEmpty) {
//       return _userTransactionsStream;
//     } else {
//       return _transactionsStream;
//     }
//   }
//
//   Future<void> _showTransactionDetails(TransactionSolde transaction) async {
//     // Récupérer les données utilisateur
//     UserData? userData;
//     if (transaction.user_id != null && transaction.user_id!.isNotEmpty) {
//       final userDoc = await FirebaseFirestore.instance
//           .collection("Users")
//           .doc(transaction.user_id)
//           .get();
//
//       if (userDoc.exists) {
//         userData = UserData.fromJson(userDoc.data()!);
//       }
//     }
//
//     showDialog(
//       context: context,
//       barrierDismissible: true,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: Row(
//           children: [
//             Icon(Icons.receipt_long, color: Colors.yellow[700]),
//             SizedBox(width: 8),
//             Text(
//               "Détails de la tran",
//               style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//             ),
//           ],
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Informations utilisateur
//               if (userData != null) ...[
//                 _buildDetailItem("Utilisateur",
//                     "${userData.pseudo ?? 'N/A'} (${userData.email ?? 'N/A'})"),
//                 _buildDetailItem("Téléphone", userData.numeroDeTelephone ?? 'N/A'),
//                 SizedBox(height: 16),
//               ],
//
//               // Informations transaction
//               _buildDetailItem("Type", _formatTransactionType(transaction.type)),
//               _buildDetailItem("Montant", "${transaction.montant?.toStringAsFixed(2) ?? '0.00'} FCFA"),
//
//               if (transaction.frais != null && transaction.frais! > 0)
//                 _buildDetailItem("Frais", "${transaction.frais?.toStringAsFixed(2) ?? '0.00'} FCFA"),
//
//               if (transaction.montant_total != null && transaction.montant_total! > 0)
//                 _buildDetailItem("Montant total", "${transaction.montant_total?.toStringAsFixed(2) ?? '0.00'} FCFA"),
//
//               if (transaction.description != null && transaction.description!.isNotEmpty)
//                 _buildDetailItem("Description", transaction.description!),
//
//               if (transaction.statut != null && transaction.statut!.isNotEmpty)
//                 _buildDetailItem("Statut", transaction.statut!),
//
//               if (transaction.methode_paiement != null && transaction.methode_paiement!.isNotEmpty)
//                 _buildDetailItem("Méthode de paiement", transaction.methode_paiement!),
//
//               if (transaction.id_transaction_cinetpay != null && transaction.id_transaction_cinetpay!.isNotEmpty)
//                 _buildDetailItem("ID CinetPay", transaction.id_transaction_cinetpay!),
//
//               _buildDetailItem("Date", _formatDetailedDate(transaction.createdAt ?? 0)),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text(
//               "Fermer",
//               style: TextStyle(color: Colors.yellow[700]),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDetailItem(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 2,
//             child: Text(
//               "$label:",
//               style: TextStyle(
//                 color: Colors.grey[400],
//                 fontWeight: FontWeight.bold,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: Text(
//               value,
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _formatDetailedDate(int timestamp) {
//     final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
//     return DateFormat('dd/MM/yyyy à HH:mm:ss').format(date);
//   }
//
//   // Liste mise à jour avec les nouveaux types
//   final List<String> _types = [
//     "TOUS",
//     "DEPOT",
//     "RETRAIT",
//     "DEPOTADMIN",
//     "RETRAITADMIN",
//     "GAIN",
//     "DEPENSE",
//   ];
//
//   // Méthode pour obtenir la couleur selon le type de transaction
//   Color _getTransactionColor(String? type) {
//     switch (type?.toUpperCase()) {
//       case 'DEPOT':
//       case 'DEPOTADMIN':
//         return Colors.green;
//       case 'RETRAIT':
//       case 'RETRAITADMIN':
//         return Colors.orange;
//       case 'GAIN':
//         return Colors.blue;
//       case 'DEPENSE':
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }
//
//   // Méthode pour obtenir l'icône selon le type de transaction
//   IconData _getTransactionIcon(String? type) {
//     switch (type?.toUpperCase()) {
//       case 'DEPOT':
//       case 'DEPOTADMIN':
//         return Iconsax.arrow_down;
//       case 'RETRAIT':
//       case 'RETRAITADMIN':
//         return Iconsax.arrow_up;
//       case 'GAIN':
//         return Iconsax.gift;
//       case 'DEPENSE':
//         return Iconsax.wallet_minus;
//       default:
//         return Iconsax.transaction_minus;
//     }
//   }
//
//   // Méthode pour formater le type de transaction
//   String _formatTransactionType(String? type) {
//     switch (type?.toUpperCase()) {
//       case 'DEPOTADMIN':
//         return 'Dépôt Admin';
//       case 'RETRAITADMIN':
//         return 'Retrait Admin';
//       case 'DEPOT':
//         return 'Dépôt';
//       case 'RETRAIT':
//         return 'Retrait';
//       case 'GAIN':
//         return 'Gain';
//       case 'DEPENSE':
//         return 'Dépense';
//       default:
//         return type ?? 'Inconnu';
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF0A0A0A),
//       appBar: AppBar(
//         title: const Text(
//           "Transactions",
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.black,
//         centerTitle: true,
//         actions: [
//           // Filtre par type
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8),
//             child: DropdownButton<String>(
//               value: _selectedType,
//               dropdownColor: Colors.black87,
//               icon: const Icon(Icons.filter_list, color: Colors.white),
//               underline: const SizedBox(),
//               items: _types
//                   .map((type) => DropdownMenuItem(
//                 value: type,
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 8,
//                       height: 8,
//                       decoration: BoxDecoration(
//                         color: _getTransactionColor(type == "TOUS" ? null : type),
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     SizedBox(width: 8),
//                     Text(
//                       type == "TOUS" ? "TOUS" : _formatTransactionType(type),
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ))
//                   .toList(),
//               onChanged: (val) {
//                 setState(() {
//                   _selectedType = val!;
//                 });
//                 _applyFilters();
//               },
//             ),
//           )
//         ],
//       ),
//       body: Column(
//         children: [
//           // Barre de recherche par email
//           Container(
//             padding: const EdgeInsets.all(12),
//             color: Colors.grey[800],
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _emailController,
//                     style: TextStyle(color: Colors.white, fontSize: 14),
//                     decoration: InputDecoration(
//                       hintText: "Rechercher par email...",
//                       hintStyle: TextStyle(color: Colors.grey[400]),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(8),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey[700],
//                       contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                       suffixIcon: IconButton(
//                         icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
//                         onPressed: () {
//                           _emailController.clear();
//                           setState(() {
//                             _selectedUserEmail = null;
//                           });
//                           _applyFilters();
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 8),
//                 IconButton(
//                   icon: Icon(Icons.search, color: Colors.yellow[700]),
//                   onPressed: _searchUserByEmail,
//                 ),
//               ],
//             ),
//           ),
//
//           // Filtres par date
//           Container(
//             padding: const EdgeInsets.all(12),
//             color: Colors.grey[900],
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     icon: Icon(Icons.calendar_today, size: 16),
//                     label: Text(
//                       _startDate == null
//                           ? "Date début"
//                           : DateFormat("dd/MM/yyyy").format(_startDate!),
//                       style: TextStyle(fontSize: 12),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green.shade800,
//                       foregroundColor: Colors.white,
//                       padding: EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     onPressed: () => _selectDate(context, true),
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     icon: Icon(Icons.calendar_today, size: 16),
//                     label: Text(
//                       _endDate == null
//                           ? "Date fin"
//                           : DateFormat("dd/MM/yyyy").format(_endDate!),
//                       style: TextStyle(fontSize: 12),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue.shade800,
//                       foregroundColor: Colors.white,
//                       padding: EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     onPressed: () => _selectDate(context, false),
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red.shade800,
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                   ),
//                   onPressed: () {
//                     setState(() {
//                       _startDate = null;
//                       _endDate = null;
//                       _selectedUserEmail = null;
//                       _emailController.clear();
//                       _selectedType = "TOUS";
//                     });
//                     _applyFilters();
//                   },
//                   child: Icon(Icons.clear, size: 16),
//                 ),
//               ],
//             ),
//           ),
//
//           // Indicateur de filtre utilisateur
//           if (_selectedUserEmail != null)
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               color: Colors.blue[900]!.withOpacity(0.3),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     "Filtré par: $_selectedUserEmail",
//                     style: TextStyle(color: Colors.blue[200], fontSize: 12),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.close, size: 16, color: Colors.blue[200]),
//                     onPressed: () {
//                       setState(() {
//                         _selectedUserEmail = null;
//                         _emailController.clear();
//                       });
//                       _applyFilters();
//                     },
//                   ),
//                 ],
//               ),
//             ),
//
//           // Statistiques rapides
//           _buildQuickStats(),
//
//           // Liste des transactions
//           Expanded(
//             child: StreamBuilder<List<TransactionSolde>>(
//               stream: _filteredTransactionsStream,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting && _isInitialLoad) {
//                   return Center(
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow[700]!),
//                     ),
//                   );
//                 }
//
//                 if (snapshot.hasError) {
//                   return Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.error_outline, color: Colors.red, size: 50),
//                         SizedBox(height: 16),
//                         Text(
//                           "Erreur de chargement",
//                           style: TextStyle(color: Colors.red, fontSize: 16),
//                         ),
//                         SizedBox(height: 8),
//                         Text(
//                           "Veuillez réessayer",
//                           style: TextStyle(color: Colors.grey, fontSize: 14),
//                         ),
//                       ],
//                     ),
//                   );
//                 }
//
//                 if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.search_off, color: Colors.grey, size: 60),
//                         SizedBox(height: 16),
//                         Text(
//                           "Aucune transaction",
//                           style: TextStyle(color: Colors.grey, fontSize: 16),
//                         ),
//                         SizedBox(height: 8),
//                         Text(
//                           _selectedUserEmail != null
//                               ? "Cet utilisateur n'a aucune transaction"
//                               : "Aucune transaction trouvée",
//                           style: TextStyle(color: Colors.grey, fontSize: 12),
//                         ),
//                         SizedBox(height: 16),
//                         ElevatedButton(
//                           onPressed: () {
//                             setState(() {
//                               _startDate = null;
//                               _endDate = null;
//                               _selectedType = "TOUS";
//                               _selectedUserEmail = null;
//                               _emailController.clear();
//                             });
//                             _applyFilters();
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.yellow[700],
//                             foregroundColor: Colors.black,
//                           ),
//                           child: Text("Réinitialiser les filtres"),
//                         ),
//                       ],
//                     ),
//                   );
//                 }
//
//                 final filtered = snapshot.data!;
//
//                 // Mettre à jour les données seulement si nécessaire
//                 if (_allTransactions != filtered) {
//                   _allTransactions = filtered;
//                   _currentPage = 0;
//                   _displayedTransactions = [];
//                   _hasMoreData = filtered.length > _pageSize;
//
//                   // Charger la première page
//                   final endIndex = _pageSize.clamp(0, filtered.length);
//                   _displayedTransactions = filtered.sublist(0, endIndex);
//                   _isInitialLoad = false;
//                 }
//
//                 return Column(
//                   children: [
//                     // Compteur de résultats
//                     Container(
//                       padding: EdgeInsets.all(8),
//                       color: Colors.grey[800],
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             "Affichées: ${_displayedTransactions.length}",
//                             style: TextStyle(color: Colors.grey[400], fontSize: 12),
//                           ),
//                           Text(
//                             "Total: ${_allTransactions.length}",
//                             style: TextStyle(color: Colors.grey[400], fontSize: 12),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     Expanded(
//                       child: ListView.builder(
//                         controller: _scrollController,
//                         padding: const EdgeInsets.all(12),
//                         itemCount: _displayedTransactions.length + (_isLoadingMore ? 1 : 0),
//                         itemBuilder: (context, index) {
//                           if (index == _displayedTransactions.length) {
//                             return _buildLoadingIndicator();
//                           }
//                           final t = _displayedTransactions[index];
//                           return _buildTransactionCard(t);
//                         },
//                       ),
//                     ),
//                   ],
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLoadingIndicator() {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow[700]!),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildQuickStats() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection("TransactionSoldes")
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return SizedBox.shrink();
//         }
//
//         final transactions = snapshot.data!.docs
//             .map((e) => TransactionSolde.fromJson(e.data() as Map<String, dynamic>))
//             .toList();
//
//         // Calcul des statistiques
//         final totalDepots = transactions
//             .where((t) => t.type == 'DEPOT' || t.type == 'DEPOTADMIN')
//             .fold(0.0, (sum, t) => sum + (t.montant ?? 0));
//
//         final totalRetraits = transactions
//             .where((t) => t.type == 'RETRAIT' || t.type == 'RETRAITADMIN')
//             .fold(0.0, (sum, t) => sum + (t.montant ?? 0));
//
//         final totalAdmin = transactions
//             .where((t) => t.type == 'DEPOTADMIN' || t.type == 'RETRAITADMIN')
//             .length;
//
//         return Container(
//           padding: EdgeInsets.all(12),
//           color: Colors.grey[850],
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _buildStatItem('Dépôts', totalDepots, Colors.green),
//               _buildStatItem('Retraits', totalRetraits, Colors.orange),
//               _buildStatItem('Opérations Admin', totalAdmin.toDouble(), Colors.purple),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildStatItem(String label, double value, Color color) {
//     return Column(
//       children: [
//         Text(
//           value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
//           style: TextStyle(
//             color: color,
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         SizedBox(height: 4),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.grey[400],
//             fontSize: 10,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildTransactionCard(TransactionSolde transaction) {
//     final isDepot = transaction.type == 'DEPOT' || transaction.type == 'DEPOTADMIN';
//     final color = _getTransactionColor(transaction.type);
//     final icon = _getTransactionIcon(transaction.type);
//     final typeText = _formatTransactionType(transaction.type);
//
//     return Card(
//       color: Colors.grey[900],
//       margin: EdgeInsets.only(bottom: 8),
//       elevation: 2,
//       child: ListTile(
//         contentPadding: EdgeInsets.all(16),
//         leading: Container(
//           width: 50,
//           height: 50,
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.2),
//             shape: BoxShape.circle,
//             border: Border.all(color: color),
//           ),
//           child: Icon(icon, color: color, size: 24),
//         ),
//         title: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               '${transaction.montant?.toStringAsFixed(2) ?? '0.00'} FCFA',
//               style: TextStyle(
//                 color: isDepot ? Colors.green : Colors.orange,
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: color),
//               ),
//               child: Text(
//                 typeText,
//                 style: TextStyle(
//                   color: color,
//                   fontSize: 10,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (transaction.description != null && transaction.description!.isNotEmpty)
//               Text(
//                 transaction.description!,
//                 style: TextStyle(
//                   color: Colors.grey[400],
//                   fontSize: 12,
//                 ),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             SizedBox(height: 4),
//             Text(
//               _formatDate(transaction.createdAt ?? 0),
//               style: TextStyle(
//                 color: Colors.grey[500],
//                 fontSize: 11,
//               ),
//             ),
//           ],
//         ),
//         trailing: Icon(
//           Icons.arrow_forward_ios,
//           color: Colors.grey[600],
//           size: 16,
//         ),
//         onTap: () {
//           _showTransactionDetails(transaction);
//         },
//       ),
//     );
//   }
//
//   String _formatDate(int timestamp) {
//     final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//     final yesterday = today.subtract(Duration(days: 1));
//
//     if (date.isAfter(today)) {
//       return 'Aujourd\'hui à ${DateFormat('HH:mm').format(date)}';
//     } else if (date.isAfter(yesterday)) {
//       return 'Hier à ${DateFormat('HH:mm').format(date)}';
//     } else {
//       return DateFormat('dd/MM/yyyy à HH:mm').format(date);
//     }
//   }
// }

