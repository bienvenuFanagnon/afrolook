import 'package:afrotok/widgets/name_tag.dart';
import 'package:afrotok/widgets/safe_network_avatar.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'dart:async';
import 'package:afrotok/services/api/canaux_api.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/services/coin_checkout.dart';

import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/userProvider.dart';


import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';


import 'detailsCanal.dart';

import 'newCanal.dart';
import 'package:afrotok/layout/centered_content.dart';
import '../../l10n/tr.dart';

class CanalListPage extends StatefulWidget {
  final bool isUserCanals;

  CanalListPage({required this.isUserCanals});

  @override
  _CanalListPageState createState() => _CanalListPageState();
}

class _CanalListPageState extends State<CanalListPage> {
  late AppColors _colors;

  // CONFIGURATION - Activer/Désactiver le paiement pour les abonnés existants
  // Changez cette valeur selon vos besoins:
  // true = Les abonnés existants doivent payer si le canal devient privé
  // false = Les abonnés existants gardent l'accès gratuit
  final bool _requirePaymentForExistingSubscribers = true;

  late UserAuthProvider authProvider;
  late UserProvider userProvider;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Canal> _allCanals = [];
  List<Canal> _displayedCanals = [];
  List<Canal> _filteredCanals = [];
  int _currentLimit = 10;
  final int _loadMoreLimit = 5;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String? _nextCursor; // page suivante (API)
  String? _error; // message d'erreur (bouton « Réessayer »)
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);

    _loadInitialCanals();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 80) {
      _loadMoreCanals();
    }
  }

  Future<void> _loadInitialCanals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await CanauxApi.list(search: _searchQuery, limit: _currentLimit, myId: authProvider.loginUserData.id);
      if (!mounted) return;
      setState(() {
        _allCanals = page.items;
        _displayedCanals = page.items;
        _filteredCanals = page.items;
        _nextCursor = page.next;
        _isLoading = false;
      });
    } catch (e) {
      printVm('Erreur chargement initial: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = CanauxApi.message(e);
      });
    }
  }

  Future<void> _loadMoreCanals() async {
    if (_isLoadingMore || _isLoading || _nextCursor == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await CanauxApi.list(search: _searchQuery, cursor: _nextCursor, limit: _loadMoreLimit + 5, myId: authProvider.loginUserData.id);
      if (!mounted) return;
      final known = _allCanals.map((c) => c.id).toSet();
      setState(() {
        _allCanals = [..._allCanals, ...page.items.where((c) => !known.contains(c.id))];
        _filteredCanals = _allCanals;
        _nextCursor = page.next;
        _isLoadingMore = false;
      });
    } catch (e) {
      printVm('Erreur chargement supplémentaire: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// La recherche se fait sur le serveur (titre), après une courte pause de frappe.
  void _searchCanals(String query) {
    _searchQuery = query.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _loadInitialCanals);
  }

  Widget _buildCanalCard(Canal canal) {
    final isFollowing = canal.usersSuiviId!.contains(authProvider.loginUserData.id);
    final isPrivate = canal.isPrivate == true;
    final subscribersCount = canal.membersCount;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CanalDetails(canal: canal),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar du canal
                    Stack(
                      children: [
                        SafeNetworkAvatar(url: canal.urlImage, radius: 25, fallbackIcon: Icons.tv_rounded),
                        if (isPrivate)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _colors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock,
                                color: _colors.onAccent,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: 12),

                    // Contenu principal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête avec titre et badge vérifié
                          Row(
                            children: [
                              Flexible(
                                // Titre affiché en entier (jusqu'à 32 caractères), badge canal Afrolook
                                child: NameTag(
                                  bordered: false,
                                  label: "#${canal.titre ?? ''}",
                                  style: TextStyle(
                                    color: _colors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (canal.isVerify == true)
                                Icon(Icons.verified, color: _colors.primary, size: 16),
                              if (isPrivate)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(Icons.attach_money, color: _colors.accentText, size: 14),
                                ),
                            ],
                          ),

                          SizedBox(height: 4),

                          // Description
                          if (canal.description != null && canal.description!.isNotEmpty)
                            Text(
                              canal.description!,
                              style: TextStyle(
                                color: _colors.textSecondary,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                          SizedBox(height: 8),

                          // Statistiques
                          Row(
                            children: [
                              Icon(Icons.people, color: _colors.textSecondary, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '$subscribersCount',
                                style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                              ),
                              SizedBox(width: 16),
                              Icon(Icons.post_add, color: _colors.textSecondary, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '${canal.publication ?? 0}',
                                style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                              ),
                              if (isPrivate) ...[
                                SizedBox(width: 16),
                                Icon(Icons.attach_money, color: _colors.accentText, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  context.tr('{a} pièces', {'a': CoinCheckout.fmt(canal.subscriptionPriceCoins)}),
                                  style: TextStyle(color: _colors.accentText, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Bouton Suivre/Abonner
                    if (!isFollowing)
                      Container(
                        height: 32,
                        child: ElevatedButton(
                          // Le bouton ouvre la page du canal : l'abonnement (et son paiement en pièces) se fait là-bas
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: canal))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPrivate ? _colors.accent : _colors.primary,
                            foregroundColor: isPrivate ? _colors.onAccent : _colors.onPrimary,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            isPrivate ? l10n.canalSubscribe : l10n.canalFollow,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: canal))),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _colors.textSecondary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            l10n.canalFollowing,
                            style: TextStyle(
                              color: _colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _searchCanals,
        style: TextStyle(color: _colors.textPrimary),
        decoration: InputDecoration(
          hintText: l10n.canalSearch,
          hintStyle: TextStyle(color: _colors.textSecondary),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: _colors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: _colors.textSecondary),
            onPressed: () {
              _searchController.clear();
              _searchCanals('');
            },
          )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        iconTheme: IconThemeData(color: _colors.textPrimary),
        automaticallyImplyLeading: true,
        title: Text(
          l10n.canalExplore,
          style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _colors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _colors.primary),
            onPressed: _loadInitialCanals,
          ),
        ],
      ),
      // Tablette et ordinateur : liste centrée
      body: CenteredContent(child: Column(
        children: [
          // Barre de recherche
          _buildSearchBar(),

          // Liste des canaux
          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(color: _colors.primary),
            )
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: _colors.danger, size: 48),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: _colors.textSecondary)),
                  ),
                  SizedBox(height: 12),
                  OutlinedButton(onPressed: _loadInitialCanals, child: Text(context.tr('Réessayer'))),
                ],
              ),
            )
                : _filteredCanals.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    color: _colors.textSecondary,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? l10n.canalNone
                        : l10n.canalNotFound,
                    style: TextStyle(
                      color: _colors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: _colors.primary,
              backgroundColor: _colors.background,
              onRefresh: _loadInitialCanals,
              child: ListView.builder(
                controller: _scrollController,
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: _filteredCanals.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _filteredCanals.length) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: _colors.primary),
                      ),
                    );
                  }
                  return _buildCanalCard(_filteredCanals[index]);
                },
              ),
            ),
          ),
        ],
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewCanal()),
          );
        },
        backgroundColor: _colors.primary,
        child: Icon(Icons.add, color: _colors.onPrimary),
      ),
    );
  }
}