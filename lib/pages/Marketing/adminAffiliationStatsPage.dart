import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/authProvider.dart';
import '../../models/model_data.dart';

class AdminAffiliationStatsPage extends StatefulWidget {
  const AdminAffiliationStatsPage({Key? key}) : super(key: key);

  @override
  State<AdminAffiliationStatsPage> createState() => _AdminAffiliationStatsPageState();
}

class _AdminAffiliationStatsPageState extends State<AdminAffiliationStatsPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late UserAuthProvider authProvider;
  bool _isLoading = true;
  bool _showDetailedStats = true;

  // Données globales
  double _totalAffiliationRevenue = 0.0;
  double _totalMarketingRevenue = 0.0;
  double _totalAppRevenue = 0.0;
  int _activeUsersCount = 0;
  int _inactiveUsersCount = 0;
  int _totalUsersWithMarketing = 0;
  double _averageUserRevenue = 0.0;

  // Liste des utilisateurs
  List<UserData> _allMarketingUsers = [];
  List<UserData> _activeMarketingUsers = [];
  List<UserData> _inactiveMarketingUsers = [];

  // Filtres
  String _filterStatus = 'tous'; // 'tous', 'actifs', 'inactifs'
  String _sortBy = 'recent'; // 'recent', 'gains', 'ancien'

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
    setState(() => _isLoading = true);

    try {
      await authProvider.getAppData();
      final appData = authProvider.appDefaultData;

      // Charger tous les utilisateurs avec marketing
      final usersSnapshot = await firestore.collection('Users').get();

      final allUsers = usersSnapshot.docs
          .map((doc) => UserData.fromJson(doc.data()))
          .toList();

      // Filtrer les utilisateurs avec marketing
      final marketingUsers = allUsers.where((user) {
        return user.marketingActivated == true ||
            (user.marketingSubscriptionEndDate != null &&
                user.marketingSubscriptionEndDate! > DateTime.now().millisecondsSinceEpoch);
      }).toList();

      // Séparer actifs/inactifs
      final now = DateTime.now().millisecondsSinceEpoch;
      final activeUsers = marketingUsers.where((user) {
        return user.marketingSubscriptionEndDate != null &&
            user.marketingSubscriptionEndDate! > now;
      }).toList();

      final inactiveUsers = marketingUsers.where((user) {
        return user.marketingSubscriptionEndDate == null ||
            user.marketingSubscriptionEndDate! <= now;
      }).toList();

      // Calculer les totaux
      double totalAffiliation = 0;
      double totalMarketing = 0;

      for (final user in marketingUsers) {
        totalAffiliation += user.total_gains_marketing ?? 0;
        totalMarketing += user.solde_marketing ?? 0;
      }

      // Mettre à jour l'état
      setState(() {
        _totalAffiliationRevenue = totalAffiliation;
        _totalMarketingRevenue = totalMarketing;
        _totalAppRevenue = appData.solde_affiliation ?? 0;
        _activeUsersCount = activeUsers.length;
        _inactiveUsersCount = inactiveUsers.length;
        _totalUsersWithMarketing = marketingUsers.length;
        _averageUserRevenue = _totalUsersWithMarketing > 0
            ? totalAffiliation / _totalUsersWithMarketing
            : 0;

        _allMarketingUsers = marketingUsers;
        _activeMarketingUsers = activeUsers;
        _inactiveMarketingUsers = inactiveUsers;

        // Trier par défaut
        _applySort();

        _isLoading = false;
      });

    } catch (e) {
      print('Erreur chargement données: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applySort() {
    List<UserData> usersToSort = [];

    switch (_filterStatus) {
      case 'actifs':
        usersToSort = List.from(_activeMarketingUsers);
        break;
      case 'inactifs':
        usersToSort = List.from(_inactiveMarketingUsers);
        break;
      default:
        usersToSort = List.from(_allMarketingUsers);
    }

    switch (_sortBy) {
      case 'recent':
        usersToSort.sort((a, b) {
          final dateA = b.lastMarketingActivationDate ?? 0;
          final dateB = a.lastMarketingActivationDate ?? 0;
          return dateA.compareTo(dateB);
        });
        break;
      case 'gains':
        usersToSort.sort((a, b) {
          final gainsA = b.total_gains_marketing ?? 0;
          final gainsB = a.total_gains_marketing ?? 0;
          return gainsA.compareTo(gainsB);
        });
        break;
      case 'ancien':
        usersToSort.sort((a, b) {
          final dateA = a.lastMarketingActivationDate ?? 0;
          final dateB = b.lastMarketingActivationDate ?? 0;
          return dateA.compareTo(dateB);
        });
        break;
    }

    setState(() {
      switch (_filterStatus) {
        case 'actifs':
          _activeMarketingUsers = usersToSort;
          break;
        case 'inactifs':
          _inactiveMarketingUsers = usersToSort;
          break;
        default:
          _allMarketingUsers = usersToSort;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _getCurrentUserList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          '📊 Statistiques Affiliation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.amber),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            color: Colors.grey[900],
            onSelected: (value) {
              if (value == 'export') {
                // TODO: Exporter les données
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Exporter CSV', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec revenu total
            _buildRevenueHeader(),
            SizedBox(height: 20),

            // Statistiques détaillées (expandable)
            _buildStatsExpandableSection(),
            SizedBox(height: 20),

            // Filtres et tris
            _buildFiltersSection(),
            SizedBox(height: 20),

            // Liste des utilisateurs
            _buildUsersListHeader(currentList.length),
            SizedBox(height: 12),

            if (currentList.isEmpty)
              _buildEmptyState()
            else
              _buildUsersList(currentList),

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB71C1C), Color(0xFFFFA000)],
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
        children: [
          Text(
            'REVENUS AFFILIATION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '${_totalAffiliationRevenue.toInt()} FCFA',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Total généré par les utilisateurs',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniRevenueItem(
                label: 'Pour l\'App',
                value: _totalAppRevenue,
                color: Colors.green,
              ),
              _buildMiniRevenueItem(
                label: 'En solde utilisateurs',
                value: _totalMarketingRevenue,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniRevenueItem({
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${value.toInt()} FCFA',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsExpandableSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          // Header expandable
          GestureDetector(
            onTap: () => setState(() => _showDetailedStats = !_showDetailedStats),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      Text(
                        "STATISTIQUES DÉTAILLÉES",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showDetailedStats ? Icons.expand_less : Icons.expand_more,
                    color: Colors.amber,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_showDetailedStats) ...[
            Divider(color: Colors.grey[800], height: 1),
            Container(
              padding: EdgeInsets.all(16),
              child: GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _buildStatCard(
                    title: 'UTILISATEURS ACTIFS',
                    value: '$_activeUsersCount',
                    subtitle: 'Comptes valides',
                    icon: Icons.verified_user,
                    color: Colors.green,
                  ),
                  _buildStatCard(
                    title: 'UTILISATEURS INACTIFS',
                    value: '$_inactiveUsersCount',
                    subtitle: 'Comptes expirés',
                    icon: Icons.history,
                    color: Colors.orange,
                  ),
                  _buildStatCard(
                    title: 'TOTAL UTILISATEURS',
                    value: '$_totalUsersWithMarketing',
                    subtitle: 'Ayant activé au moins une fois',
                    icon: Icons.group,
                    color: Colors.blue,
                  ),
                  _buildStatCard(
                    title: 'REVENU MOYEN',
                    value: '${_averageUserRevenue.toInt()} FCFA',
                    subtitle: 'Par utilisateur',
                    icon: Icons.trending_up,
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 18),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILTRES ET TRI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),

          // Filtre par statut
          Text(
            'Statut',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildFilterChip(
                label: 'Tous (${_totalUsersWithMarketing})',
                value: 'tous',
                currentValue: _filterStatus,
              ),
              SizedBox(width: 8),
              _buildFilterChip(
                label: 'Actifs (${_activeUsersCount})',
                value: 'actifs',
                currentValue: _filterStatus,
              ),
              SizedBox(width: 8),
              _buildFilterChip(
                label: 'Inactifs (${_inactiveUsersCount})',
                value: 'inactifs',
                currentValue: _filterStatus,
              ),
            ],
          ),

          SizedBox(height: 16),

          // Tri
          Text(
            'Trier par',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildSortChip(
                label: 'Plus récent',
                value: 'recent',
                currentValue: _sortBy,
              ),
              SizedBox(width: 8),
              _buildSortChip(
                label: 'Plus de gains',
                value: 'gains',
                currentValue: _sortBy,
              ),
              SizedBox(width: 8),
              _buildSortChip(
                label: 'Plus ancien',
                value: 'ancien',
                currentValue: _sortBy,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required String currentValue,
  }) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = value;
          _applySort();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey[700]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip({
    required String label,
    required String value,
    required String currentValue,
  }) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
          _applySort();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.withOpacity(0.2) : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.grey[700]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.amber : Colors.grey[300],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildUsersListHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'UTILISATEURS (${count})',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (count > 0)
          Text(
            'Total: ${_getCurrentTotalRevenue().toInt()} FCFA',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  double _getCurrentTotalRevenue() {
    final list = _getCurrentUserList();
    return list.fold(0, (sum, user) => sum + (user.total_gains_marketing ?? 0));
  }

  List<UserData> _getCurrentUserList() {
    switch (_filterStatus) {
      case 'actifs':
        return _activeMarketingUsers;
      case 'inactifs':
        return _inactiveMarketingUsers;
      default:
        return _allMarketingUsers;
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.group_off, color: Colors.grey[600], size: 50),
          SizedBox(height: 16),
          Text(
            'Aucun utilisateur trouvé',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Aucun utilisateur n\'a activé le marketing pour le moment',
            textAlign: TextAlign.center,

            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: Icon(Icons.refresh),
            label: Text('Actualiser'),
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(List<UserData> users) {
    return Column(
      children: [
        ...users.map((user) => _buildUserCard(user)),
      ],
    );
  }

  Widget _buildUserCard(UserData user) {
    final isActive = user.marketingSubscriptionEndDate != null &&
        user.marketingSubscriptionEndDate! > DateTime.now().millisecondsSinceEpoch;
    final daysLeft = isActive && user.marketingSubscriptionEndDate != null
        ? _calculateDaysLeft(user.marketingSubscriptionEndDate!)
        : 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey[800]!,
        ),
      ),
      child: Column(
        children: [
          // En-tête utilisateur
          ListTile(
            contentPadding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: isActive ? Colors.green : Colors.grey[700],
              backgroundImage: user.imageUrl != null && user.imageUrl!.isNotEmpty
                  ? NetworkImage(user.imageUrl!)
                  : null,
              child: user.imageUrl == null || user.imageUrl!.isEmpty
                  ? Text(
                user.pseudo?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(color: Colors.white),
              )
                  : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    user.pseudo ?? 'Utilisateur',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ACTIF (${daysLeft} j)' : 'INACTIF',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.orange,
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
                SizedBox(height: 4),
                Text(
                  user.email ?? '',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                if (user.numeroDeTelephone != null && user.numeroDeTelephone!.isNotEmpty)
                  Text(
                    user.numeroDeTelephone!,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
              ],
            ),
          ),

          // Statistiques utilisateur
          Container(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.5,
              children: [
                _buildUserStatItem(
                  label: 'Gains Totaux',
                  value: '${(user.total_gains_marketing ?? 0).toInt()} FCFA',
                  color: Colors.amber,
                ),
                _buildUserStatItem(
                  label: 'Solde Actuel',
                  value: '${(user.solde_marketing ?? 0).toInt()} FCFA',
                  color: Colors.green,
                ),
                _buildUserStatItem(
                  label: 'Filleuls',
                  value: '${user.nbrParrainagesActifs ?? 0}',
                  color: Colors.blue,
                ),
              ],
            ),
          ),

          // Boutons d'action
          Container(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[300],
                      side: BorderSide(color: Colors.grey[700]!),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: Icon(Icons.visibility, size: 16),
                    label: Text('Voir Profil', style: TextStyle(fontSize: 12)),
                    onPressed: () => _viewUserProfile(user.id!),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: Icon(Icons.history, size: 16),
                    label: Text('Historique', style: TextStyle(fontSize: 12)),
                    onPressed: () => _viewUserHistory(user.id!),
                  ),
                ),
              ],
            ),
          ),

          // Dates d'activation
          Container(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (user.lastMarketingActivationDate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dernière activation',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _formatDate(user.lastMarketingActivationDate!),
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                if (user.marketingSubscriptionEndDate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isActive ? 'Expire le' : 'Expiré le',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _formatDate(user.marketingSubscriptionEndDate!),
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  int _calculateDaysLeft(int endTimestamp) {
    final endDate = DateTime.fromMillisecondsSinceEpoch(endTimestamp);
    final now = DateTime.now();
    final difference = endDate.difference(now);
    return difference.inDays.clamp(0, 90);
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yy').format(date);
  }

  void _viewUserProfile(String userId) {
    // TODO: Navigation vers le profil utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation profil à implémenter'),
        backgroundColor: Colors.amber,
      ),
    );
  }

  void _viewUserHistory(String userId) {
    // TODO: Navigation vers l'historique des transactions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Historique à implémenter'),
        backgroundColor: Colors.amber,
      ),
    );
  }
}