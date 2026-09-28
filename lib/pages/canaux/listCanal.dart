import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/services/coin_checkout.dart';

import 'package:provider/provider.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/userProvider.dart';

import '../../providers/postProvider.dart';

import '../../theme/app_colors.dart';

import '../../l10n/app_localizations.dart';


import 'detailsCanal.dart';

import 'newCanal.dart';
import 'package:afrotok/layout/centered_content.dart';

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
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

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

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    _loadInitialCanals();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreCanals();
    }
  }

  Future<void> _loadInitialCanals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final canals = await postProvider.getCanauxLimited(_currentLimit);
      setState(() {
        _allCanals = canals;
        _displayedCanals = canals;
        _filteredCanals = canals;
        _isLoading = false;
      });
    } catch (e) {
      printVm('Erreur chargement initial: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreCanals() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newLimit = _currentLimit + _loadMoreLimit;
      final moreCanals = await postProvider.getCanauxLimited(newLimit);

      setState(() {
        _allCanals = moreCanals;
        _currentLimit = newLimit;

        // Appliquer le filtre de recherche si actif
        if (_searchQuery.isNotEmpty) {
          _filteredCanals = _allCanals.where((canal) =>
          canal.titre!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              canal.description!.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
        } else {
          _filteredCanals = _allCanals;
        }

        _isLoadingMore = false;
      });
    } catch (e) {
      printVm('Erreur chargement supplémentaire: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _searchCanals(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCanals = _allCanals;
      } else {
        _filteredCanals = _allCanals.where((canal) =>
        canal.titre!.toLowerCase().contains(query.toLowerCase()) ||
            (canal.description != null &&
                canal.description!.toLowerCase().contains(query.toLowerCase()))
        ).toList();
      }
    });
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
                        CircleAvatar(
                          radius: 25,
                          backgroundImage: canal.urlImage != null
                              ? NetworkImage(canal.urlImage!)
                              : AssetImage('assets/default_profile.png') as ImageProvider,
                        ),
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
                                child: Text(
                                  "#${(canal.titre != null && canal.titre!.length > 12) ? '${canal.titre!.substring(0, 12)}...' : canal.titre ?? ''}",
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
                                  child: Icon(Icons.attach_money, color: _colors.accent, size: 14),
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
                                Icon(Icons.attach_money, color: _colors.accent, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '${CoinCheckout.fmt(canal.subscriptionPriceCoins)} pièces',
                                  style: TextStyle(color: _colors.accent, fontSize: 12),
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