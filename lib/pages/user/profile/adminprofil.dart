import 'package:afrotok/pages/user/profile/retraitAdmin/retraitAdminList.dart';
import 'package:afrotok/pages/user/profile/retraitAdmin/searchUserAdmin.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/model_data.dart';
import '../monetisation.dart';

class AppInfoPage extends StatefulWidget {
  @override
  _AppInfoPageState createState() => _AppInfoPageState();
}

class _AppInfoPageState extends State<AppInfoPage> {
  late UserAuthProvider appDataProvider = Provider.of<UserAuthProvider>(context, listen: false);
  Stream<AppDefaultData>? appDataStream;
  Map<String, int> _retraitStats = {
    'total': 0,
    'en_attente': 0,
    'valider': 0,
    'annule': 0
  };

  @override
  void initState() {
    super.initState();
    appDataStream = appDataProvider.getAppDataStream();
    _loadRetraitStats();
  }

  Future<void> _loadRetraitStats() async {
    try {
      // Récupérer toutes les transactions de retrait
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
      print('Erreur chargement stats retraits: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('Informations de l\'App',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Iconsax.refresh, color: Colors.white),
            onPressed: refreshData,
            tooltip: "Actualiser",
          ),
          IconButton(
            icon: Icon(Iconsax.wallet_2, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TransactionsListPage()),
              );
            },
            tooltip: "Voir transactions",
          ),
        ],
      ),
      body: StreamBuilder<AppDefaultData>(
        stream: appDataStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00CC66))));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
                child: Text("Erreur de chargement",
                    style: TextStyle(color: Colors.red)));
          }

          final appData = snapshot.data!;
          final totalUsers = appData.users_id?.length ?? 0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte des soldes
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Color(0xFF121212),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SOLDE PRINCIPAL",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "${appData.solde_principal?.toStringAsFixed(2) ?? '0.00'} FCFA",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00CC66),
                          ),
                        ),
                        SizedBox(height: 16),
                        Divider(color: Colors.grey[800], height: 1),
                        SizedBox(height: 16),
                        Text(
                          "GAINS TOTAUX",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "${appData.solde_gain?.toStringAsFixed(2) ?? '0.00'} FCFA",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00CC66),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // NOUVEAU: Carte des demandes de retrait
                  GestureDetector(
                    onTap: () {
                      // Navigation vers la page de gestion des retraits
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdminRetraitListPage()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
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
                              Container(
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

                          SizedBox(height: 12),

                          // Barre de progression pour les retraits en attente
                          if (_retraitStats['total']! > 0) ...[
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                children: [
                                  // Partie en attente (orange)
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

                                  // Partie validés (vert)
                                  if (_retraitStats['valider']! > 0)
                                    Expanded(
                                      flex: _retraitStats['valider']!,
                                      child: Container(
                                        color: Colors.green,
                                      ),
                                    ),

                                  // Partie annulés (rouge)
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
                    ),
                  ),
                  SizedBox(height: 24),

                  // Statistiques de l'application
                  Text(
                    "STATISTIQUES",
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1
                    ),
                  ),
                  SizedBox(height: 16),
                  GridView.count(
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
                          if (!snapshot.hasData) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserSearchPage(),
                                  ),
                                );
                              },
                              child: _buildStatCard(
                                title: "Utilisateurs",
                                value: "...",
                                icon: Iconsax.profile_2user,
                                color: Color(0xFF00CC66),
                              )
                            );
                          }
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserSearchPage(),
                                ),
                              );
                            },
                            child: _buildStatCard(
                              title: "Utilisateurs",
                              value: _formatNumber(snapshot.data!),
                              icon: Iconsax.profile_2user,
                              color: Color(0xFF00CC66),
                            ),
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
                  ),
                  SizedBox(height: 24),

                  // Informations de version
                  Text(
                    "INFORMATIONS DE VERSION",
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF121212),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                  ),
                  SizedBox(height: 24),

                  // Tarifs
                  Text(
                    "TARIFS",
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF121212),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                  ),
                  SizedBox(height: 24),

                  // Points par défaut
                  Text(
                    "POINTS PAR DÉFAUT",
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF121212),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
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
    if (number >= 1000) {
      double result = number / 1000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}k';
    }
    return number.toString();
  }
}

class TransactionsListPage extends StatefulWidget {
  const TransactionsListPage({Key? key}) : super(key: key);

  @override
  _TransactionsListPageState createState() => _TransactionsListPageState();
}

class _TransactionsListPageState extends State<TransactionsListPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedType = "TOUS";

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
    }
  }

  // Liste mise à jour avec les nouveaux types
  final List<String> _types = [
    "TOUS",
    "DEPOT",
    "RETRAIT",
    "DEPOTADMIN",
    "RETRAITADMIN",
    "GAIN",
    "DEPENSE",
  ];

  // Méthode pour obtenir la couleur selon le type de transaction
  Color _getTransactionColor(String? type) {
    switch (type?.toUpperCase()) {
      case 'DEPOT':
      case 'DEPOTADMIN':
        return Colors.green;
      case 'RETRAIT':
      case 'RETRAITADMIN':
        return Colors.orange;
      case 'GAIN':
        return Colors.blue;
      case 'DEPENSE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Méthode pour obtenir l'icône selon le type de transaction
  IconData _getTransactionIcon(String? type) {
    switch (type?.toUpperCase()) {
      case 'DEPOT':
      case 'DEPOTADMIN':
        return Iconsax.arrow_down;
      case 'RETRAIT':
      case 'RETRAITADMIN':
        return Iconsax.arrow_up;
      case 'GAIN':
        return Iconsax.gift;
      case 'DEPENSE':
        return Iconsax.wallet_minus;
      default:
        return Iconsax.transaction_minus;
    }
  }

  // Méthode pour formater le type de transaction
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
      case 'DEPENSE':
        return 'Dépense';
      default:
        return type ?? 'Inconnu';
    }
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
          // Filtre par type
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: _selectedType,
              dropdownColor: Colors.black87,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              underline: const SizedBox(),
              items: _types
                  .map((type) => DropdownMenuItem(
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
                    SizedBox(width: 8),
                    Text(
                      type == "TOUS" ? "TOUS" : _formatTransactionType(type),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedType = val!;
                });
              },
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Filtres par date
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _startDate == null
                          ? "Date début"
                          : DateFormat("dd/MM/yyyy").format(_startDate!),
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _selectDate(context, true),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _endDate == null
                          ? "Date fin"
                          : DateFormat("dd/MM/yyyy").format(_endDate!),
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  child: Icon(Icons.clear, size: 16),
                ),
              ],
            ),
          ),

          // Statistiques rapides
          _buildQuickStats(),

          // Liste des transactions
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("TransactionSoldes")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow[700]!),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 50),
                        SizedBox(height: 16),
                        Text(
                          "Erreur de chargement",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Veuillez réessayer",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, color: Colors.grey, size: 60),
                        SizedBox(height: 16),
                        Text(
                          "Aucune transaction trouvée",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Les transactions apparaîtront ici",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                final transactions = docs
                    .map((e) {
                  final data = e.data() as Map<String, dynamic>;
                  data['id'] = e.id;
                  return TransactionSolde.fromJson(data);
                }).toList();

                // Filtrage par date et type
                final filtered = transactions.where((t) {
                  if (t.createdAt == null) return false;
                  final date = DateTime.fromMillisecondsSinceEpoch(t.createdAt!);

                  // Filtrage par date
                  if (_startDate != null && date.isBefore(_startDate!)) {
                    return false;
                  }
                  if (_endDate != null && date.isAfter(_endDate!.add(const Duration(days: 1)))) {
                    return false;
                  }

                  // Filtrage par type
                  if (_selectedType != "TOUS" && t.type?.toUpperCase() != _selectedType) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, color: Colors.grey, size: 60),
                        SizedBox(height: 16),
                        Text(
                          "Aucun résultat",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Aucune transaction ne correspond aux filtres",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                              _selectedType = "TOUS";
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellow[700],
                            foregroundColor: Colors.black,
                          ),
                          child: Text("Réinitialiser les filtres"),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final t = filtered[index];
                    return _buildTransactionCard(t);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("TransactionSoldes")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final transactions = snapshot.data!.docs
            .map((e) => TransactionSolde.fromJson(e.data() as Map<String, dynamic>))
            .toList();

        // Calcul des statistiques
        final totalDepots = transactions
            .where((t) => t.type == 'DEPOT' || t.type == 'DEPOTADMIN')
            .fold(0.0, (sum, t) => sum + (t.montant ?? 0));

        final totalRetraits = transactions
            .where((t) => t.type == 'RETRAIT' || t.type == 'RETRAITADMIN')
            .fold(0.0, (sum, t) => sum + (t.montant ?? 0));

        final totalAdmin = transactions
            .where((t) => t.type == 'DEPOTADMIN' || t.type == 'RETRAITADMIN')
            .length;

        return Container(
          padding: EdgeInsets.all(12),
          color: Colors.grey[850],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Dépôts', totalDepots, Colors.green),
              _buildStatItem('Retraits', totalRetraits, Colors.orange),
              _buildStatItem('Opérations Admin', totalAdmin.toDouble(), Colors.purple),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(TransactionSolde transaction) {
    final isDepot = transaction.type == 'DEPOT' || transaction.type == 'DEPOTADMIN';
    final color = _getTransactionColor(transaction.type);
    final icon = _getTransactionIcon(transaction.type);
    final typeText = _formatTransactionType(transaction.type);

    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
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
              '${transaction.montant?.toStringAsFixed(2) ?? '0.00'} FCFA',
              style: TextStyle(
                color: isDepot ? Colors.green : Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            SizedBox(height: 4),
            Text(
              _formatDate(transaction.createdAt ?? 0),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
            // if (transaction.raison != null && transaction.raison!.isNotEmpty)
            //   Padding(
            //     padding: EdgeInsets.only(top: 4),
            //     child: Text(
            //       'Raison: ${transaction.raison!}',
            //       style: TextStyle(
            //         color: Colors.grey[600],
            //         fontSize: 10,
            //         fontStyle: FontStyle.italic,
            //       ),
            //     ),
            //   ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[600],
          size: 16,
        ),
        onTap: () {
          // Optionnel: Ajouter une page de détail des transactions
          // _showTransactionDetails(transaction);
        },
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));

    if (date.isAfter(today)) {
      return 'Aujourd\'hui à ${DateFormat('HH:mm').format(date)}';
    } else if (date.isAfter(yesterday)) {
      return 'Hier à ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd/MM/yyyy à HH:mm').format(date);
    }
  }
}