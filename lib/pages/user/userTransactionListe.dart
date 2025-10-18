import 'package:afrotok/pages/user/profile/retraitAdmin/retraitAdminList.dart';
import 'package:afrotok/pages/user/profile/retraitAdmin/searchUserAdmin.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/model_data.dart';


class UserTransactionsPage extends StatefulWidget {
  final String userId;

  const UserTransactionsPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _UserTransactionsPageState createState() => _UserTransactionsPageState();
}

class _UserTransactionsPageState extends State<UserTransactionsPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedType = "TOUS";
  final ScrollController _scrollController = ScrollController();

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 10;
  List<TransactionSolde> _allTransactions = [];
  List<TransactionSolde> _displayedTransactions = [];
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Données utilisateur
  UserData? _userData;
  bool _isLoadingUser = true;
  bool _isLoadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("Users")  // Correction: "Users" au lieu de "users"
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userData = UserData.fromJson(userDoc.data()!);
        });
      } else {
        print("Utilisateur non trouvé avec l'ID: ${widget.userId}");
      }
    } catch (e) {
      print("Erreur chargement user: $e");
    } finally {
      setState(() {
        _isLoadingUser = false;
      });
      // Charger les transactions une fois les données utilisateur chargées
      _applyFilters();
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent - 100 &&
        !_scrollController.position.outOfRange &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(Duration(milliseconds: 500));

    final nextPage = _currentPage + 1;
    final startIndex = nextPage * _pageSize;

    if (startIndex >= _allTransactions.length) {
      setState(() {
        _hasMoreData = false;
        _isLoadingMore = false;
      });
      return;
    }

    final endIndex = (startIndex + _pageSize).clamp(0, _allTransactions.length);
    final newTransactions = _allTransactions.sublist(startIndex, endIndex);

    setState(() {
      _displayedTransactions.addAll(newTransactions);
      _currentPage = nextPage;
      _isLoadingMore = false;
      _hasMoreData = endIndex < _allTransactions.length;
    });
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

  void _applyFilters() {
    setState(() {
      _currentPage = 0;
      _displayedTransactions = [];
      _hasMoreData = true;
      _isLoadingTransactions = true;
    });

    // Charger les transactions filtrées
    _loadFilteredTransactions();
  }

  Future<void> _loadFilteredTransactions() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection("TransactionSoldes")
          .where("user_id", isEqualTo: widget.userId)
          .orderBy("createdAt", descending: true);

      final snapshot = await query.get();

      List<TransactionSolde> transactions = snapshot.docs.map((e) {
        final data = e.data() as Map<String, dynamic>;
        data['id'] = e.id;
        return TransactionSolde.fromJson(data);
      }).toList();

      // Appliquer les filtres locaux (date et type)
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

      setState(() {
        _allTransactions = filtered;
        _isLoadingTransactions = false;
      });

      // Charger la première page
      _loadFirstPage();

    } catch (e) {
      print("Erreur chargement transactions: $e");
      setState(() {
        _isLoadingTransactions = false;
      });
    }
  }

  void _loadFirstPage() {
    final endIndex = _pageSize.clamp(0, _allTransactions.length);
    setState(() {
      _displayedTransactions = _allTransactions.sublist(0, endIndex);
      _currentPage = 0;
      _hasMoreData = _allTransactions.length > _pageSize;
    });
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

  Future<void> _showTransactionDetails(TransactionSolde transaction) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.yellow[700]),
            SizedBox(width: 8),
            Text(
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
              // Informations utilisateur
              if (_userData != null) ...[
                _buildDetailItem("Utilisateur",
                    "${_userData!.pseudo ?? 'N/A'} (${_userData!.email ?? 'N/A'})"),
                _buildDetailItem("Téléphone", _userData!.numeroDeTelephone ?? 'N/A'),
                SizedBox(height: 16),
              ],

              // Informations transaction
              _buildDetailItem("Type", _formatTransactionType(transaction.type)),
              _buildDetailItem("Montant", "${transaction.montant?.toStringAsFixed(2) ?? '0.00'} FCFA"),

              if (transaction.frais != null && transaction.frais! > 0)
                _buildDetailItem("Frais", "${transaction.frais?.toStringAsFixed(2) ?? '0.00'} FCFA"),

              if (transaction.montant_total != null && transaction.montant_total! > 0)
                _buildDetailItem("Montant total", "${transaction.montant_total?.toStringAsFixed(2) ?? '0.00'} FCFA"),

              if (transaction.description != null && transaction.description!.isNotEmpty)
                _buildDetailItem("Description", transaction.description!),

              if (transaction.statut != null && transaction.statut!.isNotEmpty)
                _buildDetailItem("Statut", transaction.statut!),

              if (transaction.methode_paiement != null && transaction.methode_paiement!.isNotEmpty)
                _buildDetailItem("Méthode de paiement", transaction.methode_paiement!),

              if (transaction.id_transaction_cinetpay != null && transaction.id_transaction_cinetpay!.isNotEmpty)
                _buildDetailItem("ID CinetPay", transaction.id_transaction_cinetpay!),

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
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetailedDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy à HH:mm:ss').format(date);
  }

  Widget _buildUserHeader() {
    if (_isLoadingUser) {
      return Container(
        padding: EdgeInsets.all(16),
        color: Colors.grey[800],
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[700],
              child: CircularProgressIndicator(
                color: Colors.yellow[700],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    color: Colors.grey[700],
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_userData == null) {
      return Container(
        padding: EdgeInsets.all(16),
        color: Colors.red[900]!.withOpacity(0.3),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "Utilisateur non trouvé",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[800],
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[700],
            backgroundImage: _userData!.imageUrl != null && _userData!.imageUrl!.isNotEmpty
                ? NetworkImage(_userData!.imageUrl!)
                : null,
            child: _userData!.imageUrl == null || _userData!.imageUrl!.isEmpty
                ? Icon(Icons.person, color: Colors.grey[400])
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData!.pseudo ?? 'Utilisateur',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _userData!.email ?? 'N/A',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                if (_userData!.numeroDeTelephone != null && _userData!.numeroDeTelephone!.isNotEmpty)
                  Text(
                    _userData!.numeroDeTelephone!,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // Solde actuel
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.yellow[700]!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.yellow[700]!),
            ),
            child: Column(
              children: [
                Text(
                  'SOLDE',
                  style: TextStyle(
                    color: Colors.yellow[700],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${_userData!.votre_solde_principal?.toStringAsFixed(2) ?? '0.00'} FCFA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  '${_userData!.votre_solde?.toStringAsFixed(2) ?? '0.00'} FCFA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          "Transactions Utilisateur",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                _applyFilters();
              },
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // En-tête utilisateur
          _buildUserHeader(),

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
                      _selectedType = "TOUS";
                    });
                    _applyFilters();
                  },
                  child: Icon(Icons.clear, size: 16),
                ),
              ],
            ),
          ),

          // Statistiques rapides pour cet utilisateur
          _buildUserQuickStats(),

          // Liste des transactions
          Expanded(
            child: _isLoadingTransactions
                ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow[700]!),
              ),
            )
                : _allTransactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, color: Colors.grey, size: 60),
                  SizedBox(height: 16),
                  Text(
                    "Aucune transaction",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Cet utilisateur n'a effectué aucune transaction",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
                : Column(
              children: [
                // Compteur de résultats
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.grey[800],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Affichées: ${_displayedTransactions.length}",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      Text(
                        "Total: ${_allTransactions.length}",
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _displayedTransactions.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _displayedTransactions.length) {
                        return _buildLoadingIndicator();
                      }
                      final t = _displayedTransactions[index];
                      return _buildTransactionCard(t);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow[700]!),
        ),
      ),
    );
  }

  Widget _buildUserQuickStats() {
    if (_isLoadingTransactions || _allTransactions.isEmpty) {
      return SizedBox.shrink();
    }

    // Calcul des statistiques pour cet utilisateur
    final totalDepots = _allTransactions
        .where((t) => t.type == 'DEPOT' || t.type == 'DEPOTADMIN')
        .fold(0.0, (sum, t) => sum + (t.montant ?? 0));

    final totalRetraits = _allTransactions
        .where((t) => t.type == 'RETRAIT' || t.type == 'RETRAITADMIN')
        .fold(0.0, (sum, t) => sum + (t.montant ?? 0));

    final totalGains = _allTransactions
        .where((t) => t.type == 'GAIN')
        .fold(0.0, (sum, t) => sum + (t.montant ?? 0));

    return Container(
      padding: EdgeInsets.all(12),
      color: Colors.grey[850],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Dépôts', totalDepots, Colors.green),
          _buildStatItem('Retraits', totalRetraits, Colors.orange),
          _buildStatItem('Gains', totalGains, Colors.blue),
        ],
      ),
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
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[600],
          size: 16,
        ),
        onTap: () {
          _showTransactionDetails(transaction);
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