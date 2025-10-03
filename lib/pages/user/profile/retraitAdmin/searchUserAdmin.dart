// pages/admin/user_search_page.dart
import 'package:afrotok/pages/user/profile/retraitAdmin/userAllDetails.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../models/model_data.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({Key? key}) : super(key: key);

  @override
  _UserSearchPageState createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<UserData> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _searchType = 'email'; // 'email' ou 'pseudo'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Recherche Utilisateur',
          style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.yellow[700]),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(),

          // Résultats ou état vide
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Sélecteur de type de recherche
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rechercher par:',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildSearchTypeChip('email', 'Email'),
                      SizedBox(width: 8),
                      _buildSearchTypeChip('pseudo', 'Pseudo'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Barre de recherche
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow[700]!.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: _getSearchHintText(),
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(
                  Iconsax.search_normal,
                  color: Colors.yellow[700],
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Iconsax.close_circle, color: Colors.grey),
                  onPressed: _clearSearch,
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.yellow[700]!, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[800],
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (value) => _searchUsers(value.trim()),
              onChanged: (value) {
                if (value.isEmpty) {
                  _clearSearch();
                }
              },
            ),
          ),
          SizedBox(height: 8),

          // Bouton de recherche
          if (_searchController.text.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : () => _searchUsers(_searchController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700],
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: Icon(Iconsax.search_normal, size: 20),
                label: Text(
                  'RECHERCHER',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
          _clearSearch();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow[700]! : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.yellow.shade700! : Colors.grey.shade600,
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

  Widget _buildSearchResults() {
    if (_isSearching) {
      return _buildLoadingState();
    }

    if (!_hasSearched) {
      return _buildInitialState();
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState();
    }

    return _buildResultsList();
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.people,
            size: 80,
            color: Colors.grey[600],
          ),
          SizedBox(height: 20),
          Text(
            'Recherchez un utilisateur',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchType == 'email'
                ? 'Entrez un email pour commencer la recherche'
                : 'Entrez un pseudo pour commencer la recherche',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.yellow[700],
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Recherche en cours...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.search_status,
            size: 80,
            color: Colors.grey[600],
          ),
          SizedBox(height: 20),
          Text(
            'Aucun utilisateur trouvé',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchType == 'email'
                ? 'Aucun utilisateur avec cet email'
                : 'Aucun utilisateur avec ce pseudo',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _clearSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
            ),
            icon: Icon(Iconsax.refresh),
            label: Text('Nouvelle recherche'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserData user) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToUserManagement(user.id!),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getUserStatusColor(user),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: user.imageUrl != null && user.imageUrl!.isNotEmpty
                        ? Image.network(
                      user.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar(user);
                      },
                    )
                        : _buildDefaultAvatar(user),
                  ),
                ),
                SizedBox(width: 16),

                // Informations utilisateur
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.pseudo ?? 'Non renseigné',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        user.email ?? 'Aucun email',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        user.numeroDeTelephone ?? 'Aucun numéro',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Badges de statut
                      Row(
                        children: [
                          _buildStatusBadge(
                            'Vérifié',
                            user.isVerify == true ? Colors.green : Colors.grey,
                          ),
                          SizedBox(width: 6),
                          _buildStatusBadge(
                            user.isBlocked == true ? 'Bloqué' : 'Actif',
                            user.isBlocked == true ? Colors.red : Colors.green,
                          ),
                          SizedBox(width: 6),
                          _buildStatusBadge(
                            '${user.votre_solde_principal?.toStringAsFixed(0) ?? '0'} FCFA',
                            Colors.yellow[700]!,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Flèche de navigation
                Icon(
                  Iconsax.arrow_right_3,
                  color: Colors.yellow[700],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(UserData user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        shape: BoxShape.circle,
      ),
      child: Icon(
        Iconsax.profile_circle,
        color: Colors.grey[400],
        size: 30,
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getUserStatusColor(UserData user) {
    if (user.isBlocked == true) return Colors.red;
    if (user.isVerify == true) return Colors.green;
    return Colors.yellow[700]!;
  }

  String _getSearchHintText() {
    switch (_searchType) {
      case 'email':
        return 'Rechercher par email...';
      case 'pseudo':
        return 'Rechercher par pseudo...';
      default:
        return 'Rechercher...';
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResults.clear();
    });

    try {
      QuerySnapshot snapshot;

      if (_searchType == 'email') {
        // Recherche par email (correspondance exacte)
        snapshot = await _firestore
            .collection('Users')
            .where('email', isEqualTo: query.toLowerCase())
            .limit(20)
            .get();
      } else {
        // Recherche par pseudo (recherche partielle)
        snapshot = await _firestore
            .collection('Users')
            .where('pseudo', isGreaterThanOrEqualTo: query)
            .where('pseudo', isLessThan: query + 'z')
            .limit(20)
            .get();
      }

      final results = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return UserData.fromJson(data);
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Erreur recherche: $e');
      setState(() => _isSearching = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la recherche'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults.clear();
      _hasSearched = false;
      _isSearching = false;
    });
  }

  void _navigateToUserManagement(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserManagementPage(userId: userId),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}