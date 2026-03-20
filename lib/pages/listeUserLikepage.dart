// pages/users/users_list_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';
import '../providers/profilLikeProvider.dart';
import '../providers/userProvider.dart';

import 'component/showUserDetails.dart';

class UsersListPage extends StatefulWidget {
  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Controllers
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // États de pagination normale
  final List<UserData> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _batchSize = 15; // 15 utilisateurs par chargement (3x5)

  // États de recherche
  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentSearchQuery = '';
  List<UserData> _searchResults = [];
  bool _isSearchLoading = false;

  // Set pour éviter les doublons
  final Set<String> _seenUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
    _setupListeners();
  }

  void _setupListeners() {
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final threshold = _scrollController.position.maxScrollExtent - 300;
    if (_scrollController.position.pixels >= threshold && !_isLoading) {
      if (_isSearching || _hasSearched) {
        if (_hasMore) {
          _loadMoreSearchResults();
        }
      } else {
        if (_hasMore) {
          _loadMoreUsers();
        }
      }
    }
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (_searchController.text != _currentSearchQuery) {
        _performSearch(_searchController.text);
      }
    });
  }

  void _loadInitialUsers() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _users.clear();
      _seenUserIds.clear();
      _hasMore = true;
      _lastDocument = null;
    });

    try {
      final users = await _fetchUsersBatch(limit: _batchSize);
      setState(() {
        _users.addAll(users);
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement initial: $e');
      setState(() => _isLoading = false);
    }
  }

  void _loadMoreUsers() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final users = await _fetchUsersBatch(
        limit: _batchSize,
        lastDocument: _lastDocument,
      );

      if (users.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _users.addAll(users);
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement supplémentaire: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<UserData>> _fetchUsersBatch({
    required int limit,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // Récupérer plus d'utilisateurs pour avoir plus de choix
      final fetchLimit = lastDocument == null ? limit * 3 : limit * 2;

      Query query = FirebaseFirestore.instance
          .collection('Users')
          .where('isBlocked', isEqualTo: false)
          .limit(fetchLimit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        // Recycler quand on arrive en fin de liste
        if (_seenUserIds.length > limit * 3) {
          _seenUserIds.clear();
        }
        return [];
      }

      _lastDocument = snapshot.docs.last;

      // Récupérer l'utilisateur connecté
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentUserId = authProvider.loginUserData.id;

      // Filtrer les utilisateurs déjà vus et l'utilisateur connecté
      final users = snapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .where((user) =>
      user.id != null &&
          user.id != currentUserId && // Exclure l'utilisateur connecté
          !_seenUserIds.contains(user.id))
          .toList();

      // Si pas assez de nouveaux utilisateurs, prendre quand même en excluant juste l'utilisateur connecté
      final resultUsers = users.isNotEmpty
          ? users
          : snapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .where((user) => user.id != currentUserId)
          .toList();

      // Mélanger aléatoirement
      resultUsers.shuffle(Random());

      final result = resultUsers.take(limit).toList();

      // Marquer comme vus (garder seulement les 50 derniers)
      _seenUserIds.addAll(result.map((user) => user.id!));
      if (_seenUserIds.length > 50) {
        final newSet = _seenUserIds.toList().reversed.take(50).toSet();
        _seenUserIds.clear();
        _seenUserIds.addAll(newSet);
      }

      return result;
    } catch (e) {
      print('Erreur fetch users: $e');
      throw Exception('Erreur fetch users: $e');
    }
  }

  // Recherche utilisateur
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _currentSearchQuery = '';
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _currentSearchQuery = query;
      _isSearchLoading = true;
    });

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentUserId = authProvider.loginUserData.id;

      String searchQuery = query.startsWith('@') ? query.substring(1) : query;

      // Recherche exacte sur le pseudo
      QuerySnapshot exactSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('pseudo', isEqualTo: searchQuery)
          .where('isBlocked', isEqualTo: false)
          .limit(5)
          .get();

      List<UserData> exactResults = exactSnapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .where((user) => user.id != currentUserId)
          .toList();

      // Recherche partielle (commence par) si pas de résultat exact
      if (exactResults.isEmpty && searchQuery.length >= 2) {
        QuerySnapshot partialSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('pseudo', isGreaterThanOrEqualTo: searchQuery)
            .where('pseudo', isLessThanOrEqualTo: searchQuery + '\uf8ff')
            .where('isBlocked', isEqualTo: false)
            .limit(20)
            .get();

        List<UserData> partialResults = partialSnapshot.docs
            .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
            .where((user) => user.id != currentUserId)
            .toList();

        // Mélanger les résultats
        partialResults.shuffle(Random());

        setState(() {
          _searchResults = partialResults;
          _isSearchLoading = false;
        });
      } else {
        setState(() {
          _searchResults = exactResults;
          _isSearchLoading = false;
        });
      }

    } catch (e) {
      print("Erreur recherche: $e");
      setState(() {
        _isSearchLoading = false;
      });
    }
  }

  // Charger plus de résultats de recherche
  Future<void> _loadMoreSearchResults() async {
    if (_isLoading || !_hasMore || _currentSearchQuery.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentUserId = authProvider.loginUserData.id;

      String searchQuery = _currentSearchQuery.startsWith('@')
          ? _currentSearchQuery.substring(1)
          : _currentSearchQuery;

      Query query = FirebaseFirestore.instance
          .collection('Users')
          .where('pseudo', isGreaterThanOrEqualTo: searchQuery)
          .where('pseudo', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .where('isBlocked', isEqualTo: false)
          .limit(_batchSize * 2);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDocument = snapshot.docs.last;

      // Éviter les doublons avec les résultats existants
      final existingIds = _searchResults.map((u) => u.id).toSet();

      final newResults = snapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .where((user) =>
      user.id != currentUserId &&
          !existingIds.contains(user.id))
          .toList();

      if (newResults.isNotEmpty) {
        setState(() {
          _searchResults.addAll(newResults);
          _searchResults.shuffle(Random()); // Mélanger
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Erreur chargement plus de résultats: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final displayList = (_isSearching || _hasSearched) ? _searchResults : _users;
    final isLoading = _isLoading && displayList.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar avec champ de recherche
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0A),
            elevation: 0,
            pinned: true,
            expandedHeight: 90,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              title: Container(
                margin: const EdgeInsets.fromLTRB(16, 50, 16, 10),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: TextField(
                  controller: _searchController,
                  cursorColor: const Color(0xFFFFD700),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Rechercher par pseudo...",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(
                      Icons.search, size: 13,
                      color: Color(0xFFFFD700),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear,size: 13, color: Colors.grey[500]),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _isSearching = false;
                          _hasSearched = false;
                          _currentSearchQuery = '';
                          _searchResults.clear();
                          _lastDocument = null;
                        });
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // Titre
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _isSearching || _hasSearched
                    ? 'Résultats pour "$_currentSearchQuery"'
                    : 'Découvrir des profils Afrolooks',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Contenu
          isLoading
              ? SliverFillRemaining(
            child: Center(
              child: LoadingAnimationWidget.flickr(
                size: 60,
                leftDotColor: const Color(0xFFFFD700),
                rightDotColor: const Color(0xFF8B0000),
              ),
            ),
          )
              : displayList.isEmpty && _hasSearched
              ? SliverFillRemaining(
            child: _buildEmptySearchState(),
          )
              : displayList.isEmpty
              ? SliverFillRemaining(
            child: _buildEmptyState(),
          )
              : SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.65,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index >= displayList.length) {
                    return _buildShimmerCard();
                  }
                  return _buildUserCard(displayList[index]);
                },
                childCount: displayList.length + (_hasMore ? 3 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserData user) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final profileLikeProvider = Provider.of<ProfileLikeProvider>(context, listen: false);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.grey[900],
            child: InkWell(
              onTap: () {
                double w = MediaQuery.of(context).size.width;
                double h = MediaQuery.of(context).size.height;
                showUserDetailsModalDialog(user, w, h, context);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image de fond
                  CachedNetworkImage(
                    imageUrl: user.imageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[850],
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 30,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[850],
                      child: const Icon(
                        Icons.person,
                        color: Colors.grey,
                        size: 30,
                      ),
                    ),
                    memCacheWidth: 200,
                    memCacheHeight: 300,
                  ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),

                  // Contenu
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge vérifié
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (user.isVerify ?? false)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      color: Colors.white,
                                      size: 8,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Vérifié',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 6,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const SizedBox.shrink(),

                            // Bouton like minimal
                            if (authProvider.loginUserData.id != user.id)
                              StreamBuilder<int>(
                                stream: profileLikeProvider.getProfileLikesStream(user.id!),
                                builder: (context, snapshot) {
                                  final likesCount = snapshot.data ?? user.userlikes ?? 0;
                                  return FutureBuilder<bool>(
                                    future: profileLikeProvider.hasLikedProfile(
                                      user.id!,
                                      authProvider.loginUserData.id!,
                                    ),
                                    builder: (context, hasLikedSnapshot) {
                                      final hasLiked = hasLikedSnapshot.data ?? false;
                                      return GestureDetector(
                                        onTap: () async {
                                          try {
                                            if (hasLiked) {
                                              await profileLikeProvider.unlikeProfile(
                                                user.id!,
                                                authProvider.loginUserData.id!,
                                              );
                                            } else {
                                              await profileLikeProvider.likeProfile(
                                                user.id!,
                                                authProvider.loginUserData.id!,
                                              );
                                            }
                                          } catch (e) {
                                            print('Erreur like: $e');
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            hasLiked ? Icons.favorite : Icons.favorite_border,
                                            color: hasLiked ? Colors.red : Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),

                        const Spacer(),

                        // Pseudo et stats
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${user.pseudo ?? "user"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                _buildMiniStat(
                                  Icons.people,
                                  _formatCount(user.userAbonnesIds?.length ?? 0),
                                ),
                                const SizedBox(width: 6),
                                _buildMiniStat(
                                  Icons.favorite,
                                  _formatCount(user.userlikes ?? 0),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: const Color(0xFFFFD700),
          size: 8,
        ),
        const SizedBox(width: 2),
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              children: [
                Container(
                  height: 8,
                  width: 50,
                  color: Colors.grey[800],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 6,
                      width: 20,
                      color: Colors.grey[800],
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 6,
                      width: 20,
                      color: Colors.grey[800],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            color: const Color(0xFFFFD700),
            size: 60,
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun utilisateur trouvé',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Revenez plus tard pour découvrir\nde nouveaux profils !',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 60,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat pour',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          Text(
            '"$_currentSearchQuery"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _isSearching = false;
                _hasSearched = false;
                _currentSearchQuery = '';
                _searchResults.clear();
                _lastDocument = null;
              });
            },
            child: const Text(
              'Voir tous les profils',
              style: TextStyle(color: Color(0xFFFFD700)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}