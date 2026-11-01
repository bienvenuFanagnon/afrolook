import '../../../utils/count_format.dart';
import 'package:afrotok/widgets/pseudo_tag.dart';
import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';

import 'package:flutter/material.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:provider/provider.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/profilLikeProvider.dart';

import '../../../providers/userProvider.dart';

import '../../component/showUserDetails.dart';

class AddListAmis extends StatefulWidget {
  const AddListAmis({super.key});

  @override
  State<AddListAmis> createState() => _AddListAmisState();
}

class _AddListAmisState extends State<AddListAmis> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Providers
  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late ProfileLikeProvider profileLikeProvider;

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  // États de recherche
  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentSearchQuery = '';
  List<UserData> _searchResults = [];
  bool _isSearchLoading = false;

  // États de pagination normale
  List<UserData> _users = [];
  int _suggestionsLimit = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;
  static const int _pageSize = 12;

  // États de pagination recherche
  bool _hasMoreSearchData = true;
  bool _isLoadingMoreSearch = false;

  // Cache pour les likes
  final Map<String, bool> _likedCache = {};
  final Map<String, int> _likesCountCache = {};

  // Set pour éviter les doublons
  late Set<String> _loadedUserIds = {};

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    profileLikeProvider = Provider.of<ProfileLikeProvider>(context, listen: false);

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
    if (_scrollController.position.pixels >= threshold && !_isLoadingMore && !_isLoadingMoreSearch) {
      if (_isSearching || _hasSearched) {
        // Mode recherche - charger plus de résultats de recherche
        if (_hasMoreSearchData) {
          _loadMoreSearchResults();
        }
      } else {
        // Mode normal - charger plus d'utilisateurs
        if (_hasMoreData) {
          _loadMoreUsers();
        }
      }
    }
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (_searchController.text != _currentSearchQuery) {
        _performSearch(_searchController.text);
      }
    });
  }

  Future<void> _loadInitialUsers() async {
    setState(() {
      _isInitialLoading = true;
      _users.clear();
      _loadedUserIds.clear();
      _suggestionsLimit = 0;
      _hasMoreData = true;
    });

    await _loadMoreUsers(reset: true);
  }

  Future<void> _loadMoreUsers({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMoreData && !reset)) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Suggestions de profils (API : GET /v1/users/suggestions). L'API renvoie la liste jusqu'à `limit` : on agrandit la fenêtre à chaque page.
      if (reset) _suggestionsLimit = 0;
      _suggestionsLimit += _pageSize;
      final rows = (await UsersApi.suggestions(limit: _suggestionsLimit)).map(userSummaryFromApi).toList();
      final newUsers = rows.where((user) => user.id != authProvider.loginUserData.id && !_loadedUserIds.contains(user.id)).toList();

      setState(() {
        if (reset) {
          _users = newUsers;
          _loadedUserIds = newUsers.map((u) => u.id!).toSet();
        } else {
          _users.addAll(newUsers);
          _loadedUserIds.addAll(newUsers.map((u) => u.id!));
        }
        _hasMoreData = rows.length >= _suggestionsLimit && newUsers.isNotEmpty;
      });
      _preloadLikeStates(newUsers);
    } catch (e) {
      printVm('Erreur chargement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UsersApi.message(e, fallback: 'Erreur de chargement. Réessaie.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _isInitialLoading = false;
        });
      }
    }
  }

  // Méthode de recherche avec la logique mixte (locale d'abord, puis Firebase)
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
      _hasMoreSearchData = true;
    });

    try {
      // Nettoyer la query (enlever le @ si présent)
      String searchQuery = query.startsWith('@') ? query.substring(1) : query;

      // Recherche par pseudo (API : GET /v1/users/search?q=)
      final results = (await UsersApi.searchUsers(searchQuery, limit: _pageSize * 2))
          .map(userSummaryFromApi)
          .where((user) => user.id != authProvider.loginUserData.id)
          .toList();

      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
        _hasMoreSearchData = false; // l'API renvoie déjà la liste complète des correspondances
      });

      if (results.isNotEmpty) {
        _preloadLikeStates(results);
      }
    } catch (e) {
      printVm("Erreur recherche: $e");
      setState(() {
        _isSearchLoading = false;
      });
    }
  }
  // Charger plus de résultats de recherche (uniquement depuis Firebase)
  Future<void> _loadMoreSearchResults() async {
    // La recherche de l'API renvoie déjà toutes les correspondances : rien de plus à charger.
    if (mounted) setState(() => _hasMoreSearchData = false);
  }

  Future<void> _preloadLikeStates(List<UserData> users) async {
    for (final user in users) {
      if (user.id != null && !_likedCache.containsKey(user.id!)) {
        try {
          final hasLiked = await profileLikeProvider.hasLikedProfile(
            user.id!,
            authProvider.loginUserData.id!,
          );
          final likesCount = await profileLikeProvider.getProfileLikesCount(user.id!);

          if (mounted) {
            setState(() {
              _likedCache[user.id!] = hasLiked;
              _likesCountCache[user.id!] = likesCount;
            });
          }
        } catch (e) {
          printVm('Erreur préchargement like: $e');
        }
      }
    }
  }

  String _formatCount(int count) => formatCompactCount(count);

  Future<void> _handleLike(UserData user) async {
    if (user.id == null) return;

    final currentUserId = authProvider.loginUserData.id!;
    final isLiked = _likedCache[user.id!] ?? false;

    setState(() {
      _likedCache[user.id!] = !isLiked;
      _likesCountCache[user.id!] = (_likesCountCache[user.id!] ?? user.userlikes ?? 0) + (isLiked ? -1 : 1);
    });

    try {
      if (isLiked) {
        await profileLikeProvider.unlikeProfile(user.id!, currentUserId);
      } else {
        await profileLikeProvider.likeProfile(user.id!, currentUserId);

        if (user.oneIgnalUserid?.isNotEmpty ?? false) {
          authProvider.sendNotification(
            appName: '@${authProvider.loginUserData.pseudo!}',
            userIds: [user.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl ?? '',
            send_user_id: currentUserId,
            recever_user_id: user.id!,
            message: "❤️ a aimé votre profil",
            type_notif: 'PROFILE_LIKE',
            post_id: "",
            post_type: "",
            chat_id: '',
          );
        }
      }
    } catch (e) {
      setState(() {
        _likedCache[user.id!] = isLiked;
        _likesCountCache[user.id!] = (_likesCountCache[user.id!] ?? user.userlikes ?? 0) + (isLiked ? 0 : -1);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserCard(UserData user) {
    final likesCount = _likesCountCache[user.id!] ?? user.userlikes ?? 0;
    final isLiked = _likedCache[user.id!] ?? false;
    final isOwnProfile = authProvider.loginUserData.id == user.id;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
              onTap: () => showUserDetailsModalDialog(
                user,
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
                context,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: user.imageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[850],
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[850],
                      child: const Icon(
                        Icons.person,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                    memCacheWidth: 300,
                    memCacheHeight: 400,
                  ),
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
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (user.isVerify ?? false)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Vérifié',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const SizedBox.shrink(),

                            if (!isOwnProfile)
                              GestureDetector(
                                onTap: () => _handleLike(user),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? Colors.red : Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PseudoTag(label: '@${user.pseudo ?? "utilisateur"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildStatChip(
                                  Icons.people,
                                  _formatCount(user.followersCount),
                                ),
                                const SizedBox(width: 8),
                                _buildStatChip(
                                  Icons.favorite,
                                  _formatCount(likesCount),
                                  isLiked ? Colors.red : null,
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

  Widget _buildStatChip(IconData icon, String count, [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color ?? const Color(0xFFFFD700),
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        cursorColor: const Color(0xFFFFD700),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: "Rechercher par pseudo...",
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFFFFD700),
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey[500], size: 18),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _isSearching = false;
                _hasSearched = false;
                _currentSearchQuery = '';
                _searchResults.clear();
              });
            },
          )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildUserGrid() {
    final displayList = (_isSearching || _hasSearched) ? _searchResults : _users;
    final isLoading = _isInitialLoading || _isSearchLoading;
    final isLoadingMore = _isLoadingMore || _isLoadingMoreSearch;

    if (isLoading && displayList.isEmpty) {
      return Center(
        child: LoadingAnimationWidget.flickr(
          size: 50,
          leftDotColor: const Color(0xFFFFD700),
          rightDotColor: const Color(0xFF8B0000),
        ),
      );
    }

    if (displayList.isEmpty && _hasSearched) {
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
                });
              },
              child: const Text(
                'Voir tous les utilisateurs',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        ),
      );
    }

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 60,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun utilisateur',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      padding: const EdgeInsets.all(8),
      physics: const BouncingScrollPhysics(),
      itemCount: displayList.length + (isLoadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= displayList.length) {
          return _buildShimmerCard();
        }
        return _buildUserCard(displayList[index]);
      },
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.all(6),
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
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Container(
                  height: 10,
                  width: 80,
                  color: Colors.grey[800],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 8,
                      width: 30,
                      color: Colors.grey[800],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 8,
                      width: 30,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          'Découvrir',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (_isSearching || _hasSearched) {
                  await _performSearch(_currentSearchQuery);
                } else {
                  await _loadInitialUsers();
                }
              },
              color: const Color(0xFFFFD700),
              backgroundColor: Colors.grey[900],
              child: _buildUserGrid(),
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
    _likedCache.clear();
    _likesCountCache.clear();
    super.dispose();
  }
}
