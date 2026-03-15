// pages/admin/remuneration_admin_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/remuneration_service.dart';
import '../../models/model_data.dart';

class RemunerationAdminPage extends StatefulWidget {
  const RemunerationAdminPage({Key? key}) : super(key: key);

  @override
  _RemunerationAdminPageState createState() => _RemunerationAdminPageState();
}

class _RemunerationAdminPageState extends State<RemunerationAdminPage> with SingleTickerProviderStateMixin {
  final RemunerationService _service = RemunerationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic> _statsGlobales = {};
  List<Map<String, dynamic>> _dernieresTransactions = [];
  List<Map<String, dynamic>> _topUtilisateurs = [];
  List<Map<String, dynamic>> _encaissementsParJour = [];

  // Filtres
  DateTime _dateDebut = DateTime.now().subtract(Duration(days: 30));
  DateTime _dateFin = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _chargerDonnees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _chargerStatsGlobales(),
        _chargerDernieresTransactions(),
        _chargerTopUtilisateurs(),
        _chargerEncaissementsParJour(),
      ]);
    } catch (e) {
      print('Erreur chargement: $e');
      _showError('Erreur chargement: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _chargerStatsGlobales() async {
    // Total des encaissements
    QuerySnapshot transactions = await _firestore
        .collection('TransactionSoldes')
        .where('type', isEqualTo: 'ENCAISSEMENT_POST')
        .where('statut', isEqualTo: 'VALIDER')
        .get();

    double totalEncaissements = 0;
    int nombreEncaissements = transactions.docs.length;
    Set<String> utilisateursUniques = {};

    for (var doc in transactions.docs) {
      var data = doc.data() as Map<String, dynamic>;
      totalEncaissements += (data['montant'] as num?)?.toDouble() ?? 0;
      utilisateursUniques.add(data['user_id'] ?? '');
    }

    // Encaissements aujourd'hui
    DateTime aujourdhui = DateTime.now();
    int debutAujourdhui = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day).microsecondsSinceEpoch;
    int finAujourdhui = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day, 23, 59, 59).microsecondsSinceEpoch;

    QuerySnapshot aujourdhuiTx = await _firestore
        .collection('TransactionSoldes')
        .where('type', isEqualTo: 'ENCAISSEMENT_POST')
        .where('statut', isEqualTo: 'VALIDER')
        .where('createdAt', isGreaterThanOrEqualTo: debutAujourdhui)
        .where('createdAt', isLessThanOrEqualTo: finAujourdhui)
        .get();

    double aujourdhuiMontant = 0;
    for (var doc in aujourdhuiTx.docs) {
      var data = doc.data() as Map<String, dynamic>;
      aujourdhuiMontant += (data['montant'] as num?)?.toDouble() ?? 0;
    }

    // Encaissements ce mois
    DateTime debutMois = DateTime(aujourdhui.year, aujourdhui.month, 1);
    int debutMoisTs = debutMois.microsecondsSinceEpoch;

    QuerySnapshot moisTx = await _firestore
        .collection('TransactionSoldes')
        .where('type', isEqualTo: 'ENCAISSEMENT_POST')
        .where('statut', isEqualTo: 'VALIDER')
        .where('createdAt', isGreaterThanOrEqualTo: debutMoisTs)
        .get();

    double moisMontant = 0;
    for (var doc in moisTx.docs) {
      var data = doc.data() as Map<String, dynamic>;
      moisMontant += (data['montant'] as num?)?.toDouble() ?? 0;
    }

    // Configuration active
    RemunerationConfig? config = await _service.getActiveConfig();

    setState(() {
      _statsGlobales = {
        'totalEncaissements': totalEncaissements,
        'nombreEncaissements': nombreEncaissements,
        'utilisateursActifs': utilisateursUniques.length,
        'aujourdhuiMontant': aujourdhuiMontant,
        'aujourdhuiNombre': aujourdhuiTx.docs.length,
        'moisMontant': moisMontant,
        'moisNombre': moisTx.docs.length,
        'config': config,
      };
    });
  }

  Future<void> _chargerDernieresTransactions() async {
    QuerySnapshot snapshot = await _firestore
        .collection('TransactionSoldes')
        .where('type', isEqualTo: 'ENCAISSEMENT_POST')
        .where('statut', isEqualTo: 'VALIDER')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    List<Map<String, dynamic>> transactions = [];

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      // Récupérer les infos utilisateur
      String userId = data['user_id'] ?? '';
      DocumentSnapshot userDoc = await _firestore.collection('Users').doc(userId).get();

      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        data['user_pseudo'] = userData['pseudo'] ?? 'Inconnu';
        data['user_email'] = userData['email'] ?? '';
      } else {
        data['user_pseudo'] = 'Utilisateur inconnu';
      }

      transactions.add(data);
    }

    setState(() {
      _dernieresTransactions = transactions;
    });
  }

  Future<void> _chargerTopUtilisateurs() async {
    QuerySnapshot transactions = await _firestore
        .collection('TransactionSoldes')
        .where('type', isEqualTo: 'ENCAISSEMENT_POST')
        .where('statut', isEqualTo: 'VALIDER')
        .get();

    Map<String, Map<String, dynamic>> utilisateursMap = {};

    for (var doc in transactions.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String userId = data['user_id'] ?? '';
      double montant = (data['montant'] as num?)?.toDouble() ?? 0;

      if (!utilisateursMap.containsKey(userId)) {
        utilisateursMap[userId] = {
          'userId': userId,
          'totalEncaissements': 0,
          'nombreEncaissements': 0,
          'pseudo': 'Chargement...',
        };
      }

      utilisateursMap[userId]!['totalEncaissements'] += montant;
      utilisateursMap[userId]!['nombreEncaissements'] += 1;
    }

    // Récupérer les pseudos et trier
    List<Map<String, dynamic>> topList = [];
    for (var entry in utilisateursMap.entries) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('Users').doc(entry.key).get();
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          entry.value['pseudo'] = userData['pseudo'] ?? 'Sans pseudo';
          entry.value['email'] = userData['email'] ?? '';
        }
      } catch (e) {
        entry.value['pseudo'] = 'Erreur chargement';
      }
      topList.add(entry.value);
    }

    // Trier par montant total décroissant
    topList.sort((a, b) => (b['totalEncaissements'] as double).compareTo(a['totalEncaissements'] as double));

    setState(() {
      _topUtilisateurs = topList.take(10).toList();
    });
  }

  Future<void> _chargerEncaissementsParJour() async {
    int debut = _dateDebut.microsecondsSinceEpoch;
    int fin = _dateFin.microsecondsSinceEpoch;

    QuerySnapshot snapshot = await _firestore
        .collection('TransactionSoldes')
        .where('type', isEqualTo: 'ENCAISSEMENT_POST')
        .where('statut', isEqualTo: 'VALIDER')
        .where('createdAt', isGreaterThanOrEqualTo: debut)
        .where('createdAt', isLessThanOrEqualTo: fin)
        .orderBy('createdAt', descending: false)
        .get();

    Map<String, Map<String, dynamic>> jourMap = {};

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      int timestamp = data['createdAt'] ?? 0;
      DateTime date = DateTime.fromMicrosecondsSinceEpoch(timestamp);
      String jourKey = DateFormat('yyyy-MM-dd').format(date);

      if (!jourMap.containsKey(jourKey)) {
        jourMap[jourKey] = {
          'date': date,
          'montant': 0.0,
          'nombre': 0,
        };
      }

      jourMap[jourKey]!['montant'] += (data['montant'] as num?)?.toDouble() ?? 0;
      jourMap[jourKey]!['nombre'] += 1;
    }

    List<Map<String, dynamic>> liste = jourMap.values.toList();
    liste.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    setState(() {
      _encaissementsParJour = liste;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatMontant(double montant, {String devise = 'FCFA'}) {
    return '${montant.toStringAsFixed(0)} $devise';
  }

  String _formatDate(int microseconds) {
    if (microseconds <= 0) return 'Date inconnue';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(
          DateTime.fromMicrosecondsSinceEpoch(microseconds)
      );
    } catch (e) {
      return 'Date invalide';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'ADMIN RÉMUNÉRATION',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Color(0xFFFFD700),
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFFFD700)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Color(0xFFFFD700),
          labelColor: Color(0xFFFFD700),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'TABLEAU DE BORD'),
            Tab(icon: Icon(Icons.history), text: 'TRANSACTIONS'),
            Tab(icon: Icon(Icons.people), text: 'TOP UTILISATEURS'),
            Tab(icon: Icon(Icons.bar_chart), text: 'ANALYTIQUES'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
            SizedBox(height: 20),
            Text(
              'Chargement des données...',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildTableauDeBord(),
          _buildTransactionsTab(),
          _buildTopUtilisateursTab(),
          _buildAnalytiquesTab(),
        ],
      ),
    );
  }

  // ============================================
  // TABLEAU DE BORD
  // ============================================
  Widget _buildTableauDeBord() {
    return RefreshIndicator(
      onRefresh: _chargerDonnees,
      color: Color(0xFFFFD700),
      backgroundColor: Colors.black,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(),
            SizedBox(height: 25),
            _buildConfigCard(),
            SizedBox(height: 25),
            _buildDernieresTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VUE D\'ENSEMBLE',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Encaissements',
              _formatMontant(_statsGlobales['totalEncaissements'] ?? 0),
              Icons.account_balance_wallet,
              Colors.green,
            ),
            _buildStatCard(
              'Nombre Transactions',
              '${_statsGlobales['nombreEncaissements'] ?? 0}',
              Icons.receipt,
              Colors.blue,
            ),
            _buildStatCard(
              'Utilisateurs Actifs',
              '${_statsGlobales['utilisateursActifs'] ?? 0}',
              Icons.people,
              Colors.orange,
            ),
            _buildStatCard(
              'Moyenne par user',
              _formatMontant(
                  (_statsGlobales['totalEncaissements'] ?? 0) /
                      (_statsGlobales['utilisateursActifs'] ?? 1).toDouble()
              ),
              Icons.analytics,
              Colors.purple,
            ),
          ],
        ),
        SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildPeriodeCard(
                'AUJOURD\'HUI',
                '${_statsGlobales['aujourdhuiNombre'] ?? 0} transactions',
                _formatMontant(_statsGlobales['aujourdhuiMontant'] ?? 0),
                Icons.today,
                Colors.cyan,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildPeriodeCard(
                'CE MOIS',
                '${_statsGlobales['moisNombre'] ?? 0} transactions',
                _formatMontant(_statsGlobales['moisMontant'] ?? 0),
                Icons.calendar_month,
                Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodeCard(String titre, String sousTitre, String montant, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(titre, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 10),
          Text(montant, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(sousTitre, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    var config = _statsGlobales['config'];
    if (config == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: Color(0xFFFFD700), size: 20),
              SizedBox(width: 8),
              Text(
                'CONFIGURATION ACTIVE',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildConfigItem(
                'PALIER',
                '${config.nombreVuesParPalier} vues',
                Icons.remove_red_eye,
              ),
              Container(height: 30, width: 1, color: Color(0xFFFFD700).withOpacity(0.3)),
              _buildConfigItem(
                'MONTANT',
                '${config.montantParPalier} ${config.devise}',
                Icons.monetization_on,
              ),
              Container(height: 30, width: 1, color: Color(0xFFFFD700).withOpacity(0.3)),
              _buildConfigItem(
                'STATUT',
                config.estActif ? 'Actif' : 'Inactif',
                Icons.check_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFFFFD700), size: 18),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
      ],
    );
  }

  Widget _buildDernieresTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DERNIÈRES TRANSACTIONS',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 15),
        ..._dernieresTransactions.take(5).map((tx) => _buildTransactionTile(tx)).toList(),
      ],
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(Icons.payments, color: Colors.green, size: 20)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['user_pseudo'] ?? 'Inconnu',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatDate(tx['createdAt'] ?? 0),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${_formatMontant(tx['montant'] ?? 0)}',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
              Text(
                'ID: ${tx['id'].toString().substring(0, 6)}...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // TRANSACTIONS
  // ============================================
  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      onRefresh: _chargerDernieresTransactions,
      color: Color(0xFFFFD700),
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _dernieresTransactions.length,
        itemBuilder: (context, index) {
          var tx = _dernieresTransactions[index];
          return Container(
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: ExpansionTile(
              leading: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Icon(Icons.payments, color: Colors.green, size: 22)),
              ),
              title: Text(
                tx['user_pseudo'] ?? 'Inconnu',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _formatDate(tx['createdAt'] ?? 0),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  '+${_formatMontant(tx['montant'] ?? 0)}',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow('ID Transaction', tx['id']),
                      _buildDetailRow('Utilisateur ID', tx['user_id']),
                      _buildDetailRow('Description', tx['description'] ?? 'Encaissement'),
                      _buildDetailRow('Méthode', tx['methode_paiement'] ?? 'solde_principal'),
                      _buildDetailRow('Statut', tx['statut']),
                      if (tx['user_email'] != null && tx['user_email'].isNotEmpty)
                        _buildDetailRow('Email', tx['user_email']),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // TOP UTILISATEURS
  // ============================================
  Widget _buildTopUtilisateursTab() {
    return RefreshIndicator(
      onRefresh: _chargerTopUtilisateurs,
      color: Color(0xFFFFD700),
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _topUtilisateurs.length,
        itemBuilder: (context, index) {
          var user = _topUtilisateurs[index];
          return Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: index == 0
                    ? Color(0xFFFFD700).withOpacity(0.5)
                    : Colors.green.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? Color(0xFFFFD700).withOpacity(0.2)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        color: index == 0 ? Color(0xFFFFD700) : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['pseudo'] ?? 'Sans pseudo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${user['nombreEncaissements']} encaissements',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMontant(user['totalEncaissements']),
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'total',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // ANALYTIQUES
  // ============================================
  Widget _buildAnalytiquesTab() {
    return RefreshIndicator(
      onRefresh: _chargerEncaissementsParJour,
      color: Color(0xFFFFD700),
      backgroundColor: Colors.black,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltresPeriode(),
            SizedBox(height: 20),
            if (_encaissementsParJour.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.show_chart, color: Colors.grey.shade700, size: 60),
                    SizedBox(height: 20),
                    Text(
                      'Aucune donnée pour cette période',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              )
            else ...[
              _buildGraphiqueSimple(),
              SizedBox(height: 20),
              ..._encaissementsParJour.map((jour) => _buildJourTile(jour)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFiltresPeriode() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: Color(0xFFFFD700), size: 20),
              SizedBox(width: 8),
              Text('FILTRER PAR PÉRIODE', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'Du',
                  _dateDebut,
                      () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _dateDebut,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _dateDebut = picked);
                      _chargerEncaissementsParJour();
                    }
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _buildDateField(
                  'Au',
                  _dateFin,
                      () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _dateFin,
                      firstDate: _dateDebut,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _dateFin = picked);
                      _chargerEncaissementsParJour();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
            SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphiqueSimple() {
    double maxMontant = _encaissementsParJour.fold(0.0, (max, jour) {
      return (jour['montant'] as double) > max ? jour['montant'] : max;
    });

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ÉVOLUTION QUOTIDIENNE', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _encaissementsParJour.map((jour) {
                double hauteur = maxMontant > 0
                    ? (jour['montant'] as double) / maxMontant * 100
                    : 0;
                String dateStr = DateFormat('dd/MM').format(jour['date'] as DateTime);

                return Container(
                  width: 50,
                  margin: EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      Container(
                        height: 100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: hauteur,
                              width: 30,
                              decoration: BoxDecoration(
                                color: Color(0xFFFFD700).withOpacity(0.7),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        dateStr,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                      ),
                      Text(
                        '${(jour['montant'] as double).toStringAsFixed(0)}',
                        style: TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourTile(Map<String, dynamic> jour) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                DateFormat('dd').format(jour['date'] as DateTime),
                style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(jour['date'] as DateTime),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${jour['nombre']} transaction${jour['nombre'] > 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMontant(jour['montant']),
                style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
              ),
              Text(
                'total',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}