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

  @override
  void initState() {
    super.initState();

    appDataStream = appDataProvider.getAppDataStream();
  }

  void refreshData() {
    setState(() {
      appDataStream = appDataProvider.getAppDataStream();
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
                            return _buildStatCard(
                              title: "Utilisateurs",
                              value: "...", // loading
                              icon: Iconsax.profile_2user,
                              color: Color(0xFF00CC66),
                            );
                          }
                          return _buildStatCard(
                            title: "Utilisateurs",
                            value: snapshot.data.toString(),
                            icon: Iconsax.profile_2user,
                            color: Color(0xFF00CC66),
                          );
                        },
                      ),

                      // _buildStatCard(
                      //   title: "Utilisateurs",
                      //   value: totalUsers.toString(),
                      //   icon: Iconsax.profile_2user,
                      //   color: Color(0xFF00CC66),
                      // ),
                      _buildStatCard(
                        title: "Abonnés",
                        value: (appData.nbr_abonnes ?? 0).toString(),
                        icon: Iconsax.people,
                        color: Color(0xFF007AFF),
                      ),
                      _buildStatCard(
                        title: "Likes",
                        value: (appData.nbr_likes ?? 0).toString(),
                        icon: Iconsax.like_1,
                        color: Color(0xFFFF2D55),
                      ),
                      _buildStatCard(
                        title: "Commentaires",
                        value: (appData.nbr_comments ?? 0).toString(),
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
}



class TransactionsListPage extends StatefulWidget {
  const TransactionsListPage({Key? key}) : super(key: key);

  @override
  _TransactionsListPageState createState() => _TransactionsListPageState();
}

class _TransactionsListPageState extends State<TransactionsListPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedType = "TOUS"; // Filtre type

  // Sélecteur de date
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

  // Liste des types de transactions
  final List<String> _types = [
    "TOUS",
    "DEPOT",
    "RETRAIT",
    "GAIN",
    "DEPENSE",
  ];

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
                child: Text(type,
                    style: const TextStyle(color: Colors.white)),
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
            padding: const EdgeInsets.all(8),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600),
                  onPressed: () => _selectDate(context, true),
                  child: Text(
                    _startDate == null
                        ? "Date début"
                        : DateFormat("dd/MM/yyyy").format(_startDate!),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600),
                  onPressed: () => _selectDate(context, false),
                  child: Text(
                    _endDate == null
                        ? "Date fin"
                        : DateFormat("dd/MM/yyyy").format(_endDate!),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("TransactionSoldes")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.green)));
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text("Erreur de chargement",
                          style: TextStyle(color: Colors.red)));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                      child: Text("Aucune transaction trouvée",
                          style: TextStyle(color: Colors.white)));
                }

                // Conversion en modèle
                final transactions = docs
                    .map((e) => TransactionSolde.fromJson(
                    e.data() as Map<String, dynamic>))
                    .toList();

                // Filtrage par date et type
                final filtered = transactions.where((t) {
                  if (t.createdAt == null) return false;
                  final date =
                  DateTime.fromMillisecondsSinceEpoch(t.createdAt!);

                  if (_startDate != null && date.isBefore(_startDate!)) {
                    return false;
                  }
                  if (_endDate != null &&
                      date.isAfter(_endDate!.add(const Duration(days: 1)))) {
                    return false;
                  }

                  if (_selectedType != "TOUS" &&
                      t.type?.toUpperCase() != _selectedType) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text("Aucun résultat",
                          style: TextStyle(color: Colors.white70)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final t = filtered[index];
                    return TransactionWidget(transaction: t);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
