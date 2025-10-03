// pages/retrait/admin_retrait_list_page.dart
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/user/profile/retraitAdmin/retraitAdminDetails.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../models/model_data.dart';
import '../../../../services/retraitService.dart';


class AdminRetraitListPage extends StatefulWidget {
  @override
  _AdminRetraitListPageState createState() => _AdminRetraitListPageState();
}

class _AdminRetraitListPageState extends State<AdminRetraitListPage> {
  String _selectedFilter = 'TOUS';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchType = 'email'; // 'email' ou 'numero_transaction'

  final List<String> _filters = [
    'TOUS',
    'EN_ATTENTE',
    'VALIDER',
    'ANNULE'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Gestion des Retraits',
          style: TextStyle(color: Colors.yellow[700]),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.yellow[700]),
        elevation: 0,
        actions: [
          // Filtres
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.yellow[700]),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => _filters.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Text(_getFilterText(filter)),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche avec sélecteur de type
          _buildSearchBar(),

          // Filtres rapides
          _buildFilterChips(),

          // Liste des retraits
          Expanded(
            child: _buildRetraitsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Sélecteur du type de recherche
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rechercher par:',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildSearchTypeChip('email', 'Email'),
                      SizedBox(width: 8),
                      _buildSearchTypeChip('numero_transaction', 'N° Transaction'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // Barre de recherche
          TextField(
            controller: _searchController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _getSearchHintText(),
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.search, color: Colors.green),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.yellow),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _isSearching = false);
                },
              )
                  : null,
            ),
            onChanged: (value) {
              setState(() => _isSearching = value.isNotEmpty);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTypeChip(String type, String label) {
    final isSelected = _searchType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchType = type;
          _searchController.clear();
          _isSearching = false;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow[700] : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.yellow.shade700 : Colors.grey.shade600,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getSearchHintText() {
    switch (_searchType) {
      case 'email':
        return 'Rechercher par email...';
      case 'numero_transaction':
        return 'Rechercher par numéro de transaction...';
      default:
        return 'Rechercher...';
    }
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                _getFilterText(filter),
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
              selected: isSelected,
              backgroundColor: Colors.grey[800],
              selectedColor: Colors.yellow[700],
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = selected ? filter : 'TOUS';
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRetraitsList() {
    return StreamBuilder<List<TransactionRetrait>>(
      stream: _isSearching
          ? _getSearchStream()
          : RetraitService.getAllRetraits(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.yellow[700]));
        }

        if (snapshot.hasError) {
          printVm("snapshot : ${snapshot.error}");
          return Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final allRetraits = snapshot.data ?? [];
        final filteredRetraits = _filterRetraits(allRetraits);

        if (filteredRetraits.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredRetraits.length,
          itemBuilder: (context, index) {
            return _buildRetraitCard(filteredRetraits[index]);
          },
        );
      },
    );
  }

  Stream<List<TransactionRetrait>> _getSearchStream() {
    final searchText = _searchController.text.trim().toLowerCase();

    if (_searchType == 'email') {
      return RetraitService.searchRetraitsByEmail(searchText);
    } else {
      // Recherche par numéro de transaction
      return FirebaseFirestore.instance
          .collection('TransactionRetraits')
          .where('numero_transaction', isEqualTo: searchText)
          .orderBy('created_at', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TransactionRetrait.fromJson(data);
      })
          .toList());
    }
  }

  List<TransactionRetrait> _filterRetraits(List<TransactionRetrait> retraits) {
    if (_selectedFilter == 'TOUS') return retraits;
    return retraits.where((retrait) => retrait.statut == _selectedFilter).toList();
  }

  Widget _buildRetraitCard(TransactionRetrait retrait) {
    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: retrait.statutColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: retrait.statutColor),
          ),
          child: Icon(
            _getStatusIcon(retrait.statut!),
            color: retrait.statutColor,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${retrait.montant!.toStringAsFixed(2)} FCFA',
              style: TextStyle(
                color: Colors.yellow[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (retrait.numeroTransaction != null && retrait.numeroTransaction!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'N°: ${retrait.numeroTransaction!}',
                  style: TextStyle(
                    color: Colors.green[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${retrait.userPseudo ?? 'Utilisateur'}',
              style: TextStyle(color: Colors.white),
            ),
            Text(
              '${retrait.methodPaiement} - ${retrait.numeroCompte}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            Text(
              _formatDate(retrait.createdAt!),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: retrait.statutColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: retrait.statutColor),
          ),
          child: Text(
            retrait.statutText,
            style: TextStyle(
              color: retrait.statutColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminRetraitDetailPage(retrait: retrait),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.money_off, size: 64, color: Colors.grey[600]),
          SizedBox(height: 16),
          Text(
            _isSearching ? 'Aucun résultat' : 'Aucune demande de retrait',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
            ),
          ),
          if (_isSearching) ...[
            SizedBox(height: 8),
            Text(
              _searchType == 'email'
                  ? 'Aucun utilisateur trouvé avec cet email'
                  : 'Aucune transaction trouvée avec ce numéro',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _getFilterText(String filter) {
    switch (filter) {
      case 'EN_ATTENTE': return 'En attente';
      case 'VALIDER': return 'Validés';
      case 'ANNULE': return 'Annulés';
      default: return 'Tous';
    }
  }

  IconData _getStatusIcon(String statut) {
    switch (statut) {
      case 'EN_ATTENTE': return Icons.access_time;
      case 'VALIDER': return Icons.check_circle;
      case 'ANNULE': return Icons.cancel;
      default: return Icons.help;
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }
}