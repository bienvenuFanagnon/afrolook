// pages/admin/user_search_page.dart

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/user/profile/retraitAdmin/userAllDetails.dart';
import 'package:flutter/material.dart';
import '../../../admin/admin_palette.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../models/model_data.dart';
import '../../../../services/api/api_gateway.dart';
import '../../../../services/api/wallet_api.dart';
// pages/admin/user_search_page.dart

import 'package:afrotok/pages/user/profile/retraitAdmin/userAllDetails.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../models/model_data.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({Key? key}) : super(key: key);

  @override
  _UserSearchPageState createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  List<UserData> _displayedUsers = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _hasSearched = false;
  String _searchType = 'email'; // 'email' ou 'pseudo'

  // Pagination et filtre
  int _selectedLimit = 10; // Valeurs: 10, 50, 200
  final List<int> _limitOptions = [10, 50, 200];

  // Contrôleur pour le scroll infini
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _loadRecentUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData &&
        !_isSearching &&
        _searchController.text.isEmpty) {
      _loadMoreUsers();
    }
  }

  /// Ligne de l'API d'administration (`GET /admin/users`) → profil d'affichage.
  UserData _userFromAdmin(Map<String, dynamic> r) {
    final created = DateTime.tryParse('${r['created_at']}')?.millisecondsSinceEpoch;
    final u = UserData.fromJson({
      'id': r['id'],
      'pseudo': r['username'] ?? r['display_name'] ?? '',
      'email': r['email'] ?? '',
      'imageUrl': r['avatar_url'] ?? '',
      if (created != null) 'createdAt': created,
    });
    u.id = '${r['id']}';
    return u;
  }

  Future<({List<UserData> users, bool more})> _fetch({String search = '', int page = 1}) async {
    final r = await ApiGateway.instance.client.get('/admin/users', query: {if (search.isNotEmpty) 'search': search, 'page': page});
    final rows = WalletApi.list(r);
    return (users: rows.map(_userFromAdmin).toList(), more: r is Map && r['has_more'] == true);
  }

  Future<void> _loadRecentUsers() async {
    setState(() {
      _isLoading = true;
      _displayedUsers.clear();
      _hasSearched = false;
    });

    try {
      _page = 1;
      final res = await _fetch();
      _hasMoreData = res.more;
      setState(() {
        _displayedUsers = res.users;
        _isLoading = false;
      });
      printVm('✅ ${res.users.length} utilisateurs chargés');
    } catch (e) {
      printVm('❌ Erreur chargement utilisateurs: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar(WalletApi.message(e, fallback: 'Erreur lors du chargement des utilisateurs'));
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);
    try {
      final res = await _fetch(page: _page + 1);
      _page++;
      _hasMoreData = res.more;
      setState(() {
        _displayedUsers.addAll(res.users);
        _isLoadingMore = false;
      });
    } catch (e) {
      printVm('❌ Erreur chargement supplémentaire: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      _loadRecentUsers();
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _displayedUsers.clear();
    });

    try {
      // L'API cherche à la fois dans le pseudo, l'e-mail et l'identifiant
      final res = await _fetch(search: query.trim());
      setState(() {
        _displayedUsers = res.users;
        _isSearching = false;
      });
      printVm('🔍 ${res.users.length} résultats trouvés pour "$query"');
    } catch (e) {
      printVm('❌ Erreur recherche: $e');
      setState(() => _isSearching = false);
      _showErrorSnackBar(WalletApi.message(e, fallback: 'Erreur lors de la recherche'));
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _hasSearched = false;
    });
    _loadRecentUsers();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(int? microseconds) {
    if (microseconds == null || microseconds == 0) {
      return 'Date inconnue';
    }

    try {
      DateTime date =
      DateTime.fromMicrosecondsSinceEpoch(microseconds);

      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return 'Date inconnue';
    }
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

  @override
  Widget build(BuildContext context) {
    AdminPalette.of(context);
    return Scaffold(
      backgroundColor: AdminPalette.bg,
      appBar: AppBar(
        title: Text('Utilisateurs',
            style: TextStyle(color: AdminPalette.textP, fontWeight: FontWeight.w700, fontSize: 17)),
        backgroundColor: AdminPalette.surface,
        iconTheme: IconThemeData(color: AdminPalette.textP),
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AdminPalette.border),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (!_isLoading && !_isSearching && _searchController.text.isEmpty) _buildUserCountHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AdminPalette.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: AdminPalette.textP, fontSize: 15),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: _getSearchHintText(),
              hintStyle: TextStyle(color: AdminPalette.textS),
              prefixIcon: Icon(Iconsax.search_normal, color: AdminPalette.textS, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Iconsax.close_circle, color: AdminPalette.textS, size: 20),
                      onPressed: _clearSearch,
                    )
                  : null,
              filled: true,
              fillColor: AdminPalette.field,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AdminPalette.gold, width: 1.5),
              ),
            ),
            onSubmitted: (value) => _searchUsers(value.trim()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSearchTypeChip('pseudo', 'Pseudo'),
              const SizedBox(width: 6),
              _buildSearchTypeChip('email', 'E-mail'),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedLimit,
                  isDense: true,
                  dropdownColor: AdminPalette.card,
                  icon: Icon(Iconsax.arrow_down_1, color: AdminPalette.textS, size: 16),
                  style: TextStyle(color: AdminPalette.textP, fontSize: 12.5),
                  items: _limitOptions
                      .map((limit) => DropdownMenuItem(value: limit, child: Text('$limit derniers')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedLimit = value);
                      _loadRecentUsers();
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

  Widget _buildSearchTypeChip(String type, String label) {
    final isSelected = _searchType == type;
    return GestureDetector(
      onTap: () => setState(() => _searchType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AdminPalette.textP : AdminPalette.field,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: isSelected ? AdminPalette.bg : AdminPalette.textS,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }

  Widget _buildUserCountHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Row(
        children: [
          Text('DERNIERS INSCRITS',
              style: TextStyle(
                  color: AdminPalette.textS, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const Spacer(),
          Text('${_displayedUsers.length} affichés', style: TextStyle(color: AdminPalette.textS, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _centerMessage(IconData icon, String title, String subtitle, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AdminPalette.textS),
            const SizedBox(height: 14),
            Text(title,
                style: TextStyle(color: AdminPalette.textP, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: AdminPalette.textS, fontSize: 13)),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading || _isSearching) {
      return Center(child: CircularProgressIndicator(color: AdminPalette.gold, strokeWidth: 2.5));
    }

    if (_displayedUsers.isEmpty) {
      return _centerMessage(
        _hasSearched ? Iconsax.search_status : Iconsax.people,
        _hasSearched ? 'Aucun utilisateur trouvé' : 'Aucun utilisateur',
        _hasSearched ? "Essaie avec d'autres critères" : 'Les utilisateurs apparaîtront ici',
        action: _hasSearched
            ? OutlinedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Iconsax.refresh, size: 18),
                label: const Text('Voir les derniers inscrits'),
                style: OutlinedButton.styleFrom(foregroundColor: AdminPalette.textP),
              )
            : null,
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _displayedUsers.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _displayedUsers.length) return _buildLoadingMoreIndicator();
        return _buildUserCard(_displayedUsers[index]);
      },
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator(color: AdminPalette.gold, strokeWidth: 2)),
    );
  }

  Widget _buildUserCard(UserData user) {
    return Material(
      color: AdminPalette.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _navigateToUserManagement(user.id!),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _getUserStatusColor(user), width: 2),
                    ),
                    child: ClipOval(
                      child: user.imageUrl != null && user.imageUrl!.isNotEmpty
                          ? Image.network(user.imageUrl!,
                              fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildDefaultAvatar(user))
                          : _buildDefaultAvatar(user),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(user.pseudo ?? 'Non renseigné',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AdminPalette.textP, fontSize: 14.5, fontWeight: FontWeight.w700)),
                            ),
                            if (user.isVerify == true) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified_rounded, size: 15, color: AdminPalette.blue),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(user.email ?? 'Aucun e-mail',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AdminPalette.textS, fontSize: 12)),
                        Text('Inscrit le ${_formatDate(user.createdAt ?? 0)}',
                            style: TextStyle(color: AdminPalette.textS, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusBadge(
                        user.isBlocked == true ? 'Bloqué' : 'Actif',
                        user.isBlocked == true ? AdminPalette.red : AdminPalette.green,
                      ),
                      if (user.role != null && user.role!.isNotEmpty && user.role!.toUpperCase() != 'USER') ...[
                        const SizedBox(height: 4),
                        _buildStatusBadge(user.role!.toUpperCase(), AdminPalette.blue),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Les 4 soldes : argent (FCFA) et pièces
              Row(
                children: [
                  _balance('Dépôt', '${(user.votre_solde_depot ?? 0).toStringAsFixed(0)} F', AdminPalette.blue),
                  _balance('Gains', '${(user.votre_solde_principal ?? 0).toStringAsFixed(0)} F', AdminPalette.amber),
                  _balance('P. dépôt', '${user.lockedGiftCoins}', AdminPalette.gold),
                  _balance('P. gagnées', '${user.convertibleGiftCoins}', AdminPalette.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balance(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, style: TextStyle(color: AdminPalette.textS, fontSize: 10.5)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(UserData user) {
    return Container(
      color: AdminPalette.field,
      alignment: Alignment.center,
      child: Text(
        user.pseudo != null && user.pseudo!.isNotEmpty ? user.pseudo![0].toUpperCase() : '?',
        style: TextStyle(color: AdminPalette.textS, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }

  Color _getUserStatusColor(UserData user) {
    if (user.isBlocked == true) return AdminPalette.red;
    if (user.isVerify == true) return AdminPalette.green;
    return AdminPalette.gold;
  }

  void _navigateToUserManagement(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserManagementPage(userId: userId)),
    );
  }
}
