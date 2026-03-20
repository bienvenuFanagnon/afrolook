import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;
  static const int _pageSize = 12;

  // États de pagination recherche
  DocumentSnapshot? _lastSearchDocument;
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
      _lastDocument = null;
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
      // Requête SANS where sur l'ID
      Query query = FirebaseFirestore.instance
          .collection('Users')
          .limit(_pageSize);

      if (!reset && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        // Filtrer l'utilisateur connecté localement
        final newUsers = snapshot.docs
            .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
            .where((user) =>
        user.id != authProvider.loginUserData.id! &&
            !_loadedUserIds.contains(user.id))
            .toList();

        if (newUsers.isNotEmpty) {
          setState(() {
            if (reset) {
              _users = newUsers;
              _loadedUserIds = newUsers.map((u) => u.id!).toSet();
            } else {
              _users.addAll(newUsers);
              _loadedUserIds.addAll(newUsers.map((u) => u.id!));
            }
            _lastDocument = snapshot.docs.last;
            _hasMoreData = snapshot.docs.length == _pageSize;
          });

          _preloadLikeStates(newUsers);
        } else {
          // Si tous les nouveaux utilisateurs sont des doublons ou l'utilisateur connecté
          if (snapshot.docs.length == _pageSize) {
            _lastDocument = snapshot.docs.last;
            _loadMoreUsers();
          } else {
            setState(() {
              _hasMoreData = false;
            });
          }
        }
      } else {
        setState(() {
          _hasMoreData = false;
        });
      }
    } catch (e) {
      print('Erreur chargement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
        _isInitialLoading = false;
      });
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
    });

    try {
      // Nettoyer la query (enlever le @ si présent)
      String searchQuery = query.startsWith('@') ? query.substring(1) : query;

      // Recherche Firebase directe sur le pseudo exact
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('pseudo', isEqualTo: searchQuery) // ✅ Recherche exacte sur le pseudo
          .limit(10) // Au cas où plusieurs utilisateurs ont le même pseudo
          .get();

      // Filtrer pour enlever l'utilisateur connecté
      List<UserData> results = snapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .where((user) => user.id != authProvider.loginUserData.id!)
          .toList();

      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });

      // Précharger les likes si on a des résultats
      if (results.isNotEmpty) {
        _preloadLikeStates(results);
      }

    } catch (e) {
      print("Erreur recherche: $e");
      setState(() {
        _isSearchLoading = false;
      });
    }
  }
  // Charger plus de résultats de recherche (uniquement depuis Firebase)
  Future<void> _loadMoreSearchResults() async {
    if (_isLoadingMoreSearch || !_hasMoreSearchData || _currentSearchQuery.isEmpty) return;

    setState(() {
      _isLoadingMoreSearch = true;
    });

    try {
      String searchQuery = _currentSearchQuery.startsWith('@')
          ? _currentSearchQuery.substring(1)
          : _currentSearchQuery;
      searchQuery = searchQuery.toLowerCase();

      // Charger plus d'utilisateurs depuis Firebase
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .limit(30)
          .get();

      // Éviter les doublons avec les résultats existants
      final existingIds = _searchResults.map((u) => u.id).toSet();

      List<UserData> newResults = snapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .where((user) =>
      !existingIds.contains(user.id) &&
          user.id != authProvider.loginUserData.id! &&
          (user.pseudo?.toLowerCase().contains(searchQuery) == true ||
              (user.prenom?.toLowerCase().contains(searchQuery) ?? false) ||
              (user.nom?.toLowerCase().contains(searchQuery) ?? false)))
          .take(_pageSize)
          .toList();

      if (newResults.isNotEmpty) {
        setState(() {
          _searchResults.addAll(newResults);
          _hasMoreSearchData = newResults.length == _pageSize;
        });

        _preloadLikeStates(newResults);
      } else {
        setState(() {
          _hasMoreSearchData = false;
        });
      }

    } catch (e) {
      print('Erreur chargement plus de résultats: $e');
    } finally {
      setState(() {
        _isLoadingMoreSearch = false;
      });
    }
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
          print('Erreur préchargement like: $e');
        }
      }
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

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
                            Text(
                              '@${user.pseudo ?? "utilisateur"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildStatChip(
                                  Icons.people,
                                  _formatCount(user.userAbonnesIds?.length ?? 0),
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


// import 'dart:math';
// import 'package:afrotok/models/model_data.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:loading_animation_widget/loading_animation_widget.dart';
// import 'package:provider/provider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
//
// import '../../../constant/constColors.dart';
// import '../../../constant/logo.dart';
// import '../../../constant/sizeText.dart';
// import '../../../constant/textCustom.dart';
// import '../../../providers/authProvider.dart';
// import '../../../providers/profilLikeProvider.dart';
// import '../../../providers/userProvider.dart';
// import '../../component/showUserDetails.dart';
//
// class AddListAmis extends StatefulWidget {
//   const AddListAmis({super.key});
//
//   @override
//   State<AddListAmis> createState() => _ListUserChatsState();
// }
//
// class _ListUserChatsState extends State<AddListAmis> {
//   late UserAuthProvider authProvider;
//   late UserProvider userProvider;
//   late ProfileLikeProvider profileLikeProvider;
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//
//   late List<UserData> listUser = [];
//   late List<UserData> filteredListUser = [];
//   final TextEditingController _searchController = TextEditingController();
//   bool _isSearching = false;
//   bool _isLoading = false;
//   bool _hasSearched = false;
//
//   @override
//   void initState() {
//     super.initState();
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     userProvider = Provider.of<UserProvider>(context, listen: false);
//     profileLikeProvider = Provider.of<ProfileLikeProvider>(context, listen: false);
//
//     _searchController.addListener(() {
//       if (_searchController.text.isNotEmpty) {
//         Future.delayed(const Duration(milliseconds: 500), () {
//           if (_searchController.text.isNotEmpty && mounted) {
//             _searchUsers(_searchController.text);
//           }
//         });
//       } else {
//         setState(() {
//           _isSearching = false;
//           _hasSearched = false;
//           filteredListUser = listUser;
//         });
//       }
//     });
//   }
//
//   Future<void> _searchUsers(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _isSearching = false;
//         _hasSearched = false;
//         filteredListUser = listUser;
//       });
//       return;
//     }
//
//     setState(() {
//       _isSearching = true;
//       _isLoading = true;
//       _hasSearched = true;
//     });
//
//     try {
//       String searchQuery = query.startsWith('@') ? query.substring(1) : query;
//       searchQuery = searchQuery.toLowerCase();
//
//       // Recherche locale
//       List<UserData> localResults = listUser.where((user) {
//         return user.pseudo!.toLowerCase().contains(searchQuery);
//       }).toList();
//
//       // Recherche Firebase si peu de résultats locaux
//       if (localResults.length < 5) {
//         QuerySnapshot snapshot = await FirebaseFirestore.instance
//             .collection('Users')
//             .get();
//
//         List<UserData> firebaseResults = snapshot.docs
//             .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
//             .where((user) =>
//         user.id != authProvider.loginUserData.id &&
//             user.pseudo!.toLowerCase().contains(searchQuery))
//             .toList();
//
//         Set<UserData> allResults = {...localResults, ...firebaseResults};
//         filteredListUser = allResults.toList();
//       } else {
//         filteredListUser = localResults;
//       }
//
//       setState(() => _isLoading = false);
//     } catch (e) {
//       print("Erreur recherche: $e");
//       setState(() => _isLoading = false);
//     }
//   }
//
//   String _formatCount(int count) {
//     if (count < 1000) return count.toString();
//     if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
//     return '${(count / 1000000).toStringAsFixed(1)}M';
//   }
//
//   Widget _buildUserCard(UserData user) {
//     final isOwnProfile = authProvider.loginUserData.id == user.id;
//
//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             Color(0xFF1A1A1A),
//             Color(0xFF2D1A1A),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.3),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//         border: Border.all(
//           color: Colors.grey[800]!,
//           width: 1,
//         ),
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: () {
//             double w = MediaQuery.of(context).size.width;
//             double h = MediaQuery.of(context).size.height;
//             showUserDetailsModalDialog(user, w, h, context);
//           },
//           borderRadius: BorderRadius.circular(20),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               children: [
//                 // Avatar avec badge vérifié
//                 Stack(
//                   children: [
//                     Container(
//                       width: 60,
//                       height: 60,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         border: Border.all(
//                           color: Color(0xFFFFD700),
//                           width: 2,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.3),
//                             blurRadius: 8,
//                             offset: Offset(0, 3),
//                           ),
//                         ],
//                       ),
//                       child: ClipOval(
//                         child: CachedNetworkImage(
//                           imageUrl: user.imageUrl ?? '',
//                           fit: BoxFit.cover,
//                           placeholder: (context, url) => Container(
//                             color: Colors.grey[800],
//                             child: Center(
//                               child: CircularProgressIndicator(
//                                 color: Color(0xFFFFD700),
//                                 strokeWidth: 2,
//                               ),
//                             ),
//                           ),
//                           errorWidget: (context, url, error) => Container(
//                             color: Colors.grey[800],
//                             child: Icon(
//                               Icons.person,
//                               color: Colors.grey[600],
//                               size: 30,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                     if (user.isVerify!)
//                       Positioned(
//                         bottom: 0,
//                         right: 0,
//                         child: Container(
//                           padding: EdgeInsets.all(4),
//                           decoration: BoxDecoration(
//                             color: Colors.blue,
//                             shape: BoxShape.circle,
//                             border: Border.all(color: Colors.white, width: 2),
//                           ),
//                           child: Icon(
//                             Icons.verified,
//                             color: Colors.white,
//                             size: 12,
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//
//                 SizedBox(width: 16),
//
//                 // Informations utilisateur
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               '@${user.pseudo ?? "Utilisateur"}',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 6),
//
//                       // Statistiques
//                       Row(
//                         children: [
//                           _buildStatItem(
//                             _formatCount(user.userAbonnesIds?.length ?? 0),
//                             'Abonnés',
//                             Icons.people,
//                             Colors.blue,
//                           ),
//                           SizedBox(width: 16),
//                           _buildStatItem(
//                             _formatCount(user.userlikes ?? 0),
//                             'Likes',
//                             Icons.favorite,
//                             Colors.red,
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Bouton like profil
//                 if (!isOwnProfile) _buildProfileLikeButton(user),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildStatItem(String value, String label, IconData icon, Color color) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, color: color, size: 14),
//         SizedBox(width: 4),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               value,
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             Text(
//               label,
//               style: TextStyle(
//                 color: Colors.grey[400],
//                 fontSize: 10,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildProfileLikeButton(UserData user) {
//     return StreamBuilder<int>(
//       stream: profileLikeProvider.getProfileLikesStream(user.id!),
//       builder: (context, snapshot) {
//         final likesCount = snapshot.data ?? user.userlikes ?? 0;
//
//         return FutureBuilder<bool>(
//           future: profileLikeProvider.hasLikedProfile(user.id!, authProvider.loginUserData.id!),
//           builder: (context, hasLikedSnapshot) {
//             final hasLiked = hasLikedSnapshot.data ?? false;
//
//             return GestureDetector(
//               onTap: () async {
//                 try {
//                   if (hasLiked) {
//                     await profileLikeProvider.unlikeProfile(user.id!, authProvider.loginUserData.id!);
//                   } else {
//                     await profileLikeProvider.likeProfile(user.id!, authProvider.loginUserData.id!);
//
//                     // Envoyer notification
//                     if (user.oneIgnalUserid != null && user.oneIgnalUserid!.isNotEmpty) {
//                       await authProvider.sendNotification(
//                         appName: '@${authProvider.loginUserData.pseudo!}',
//                         userIds: [user.oneIgnalUserid!],
//                         smallImage: authProvider.loginUserData.imageUrl!,
//                         send_user_id: authProvider.loginUserData.id!,
//                         recever_user_id: user.id!,
//                         message: "❤️ a aimé votre profil !",
//                         type_notif: 'PROFILE_LIKE',
//                         post_id: "",
//                         post_type: "",
//                         chat_id: '',
//                       );
//                     }
//                   }
//                 } catch (e) {
//                   print('Erreur like profil: $e');
//                 }
//               },
//               child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: hasLiked ? Colors.red.withOpacity(0.2) : Colors.transparent,
//                   borderRadius: BorderRadius.circular(15),
//                   border: Border.all(
//                     color: hasLiked ? Colors.red : Colors.grey[600]!,
//                     width: 1,
//                   ),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       hasLiked ? Icons.favorite : Icons.favorite_border,
//                       color: hasLiked ? Colors.red : Colors.grey[400],
//                       size: 16,
//                     ),
//                     SizedBox(width: 4),
//                     Text(
//                       _formatCount(likesCount),
//                       style: TextStyle(
//                         color: hasLiked ? Colors.red : Colors.grey[400],
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   Widget _buildSearchField() {
//     return Container(
//       margin: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.grey[900],
//         borderRadius: BorderRadius.circular(25),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.3),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//       ),
//       child: TextField(
//         controller: _searchController,
//         cursorColor: Color(0xFFFFD700),
//         style: TextStyle(color: Colors.white),
//         decoration: InputDecoration(
//           hintText: "Rechercher par pseudo...",
//           hintStyle: TextStyle(color: Colors.grey[500]),
//           prefixIcon: Icon(
//             Icons.search,
//             color: Color(0xFFFFD700),
//             size: 22,
//           ),
//           suffixIcon: _searchController.text.isNotEmpty
//               ? IconButton(
//             icon: Icon(Icons.clear, color: Colors.grey[500]),
//             onPressed: () {
//               _searchController.clear();
//               setState(() {
//                 _isSearching = false;
//                 _hasSearched = false;
//               });
//             },
//           )
//               : null,
//           filled: true,
//           fillColor: Colors.transparent,
//           contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 20),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(25),
//             borderSide: BorderSide(color: Colors.transparent),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(25),
//             borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
//           ),
//         ),
//         onSubmitted: (value) {
//           if (value.isNotEmpty) {
//             _searchUsers(value);
//           }
//         },
//       ),
//     );
//   }
//
//   Widget _buildUserGrid() {
//     if (_isLoading) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(40.0),
//           child: LoadingAnimationWidget.flickr(
//             size: 60,
//             leftDotColor: Color(0xFFFFD700),
//             rightDotColor: Color(0xFF8B0000),
//           ),
//         ),
//       );
//     }
//
//     final usersToDisplay = _isSearching || _hasSearched ? filteredListUser : listUser;
//
//     if (usersToDisplay.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.people_outline,
//               size: 80,
//               color: Colors.grey[600],
//             ),
//             SizedBox(height: 16),
//             Text(
//               _isSearching || _hasSearched
//                   ? "Aucun utilisateur trouvé"
//                   : "Aucun utilisateur à afficher",
//               style: TextStyle(
//                 color: Colors.grey[400],
//                 fontSize: 16,
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               "Essayez avec d'autres termes de recherche",
//               style: TextStyle(
//                 color: Colors.grey[600],
//                 fontSize: 14,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       );
//     }
//
//     return GridView.builder(
//       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         crossAxisSpacing: 12,
//         mainAxisSpacing: 12,
//         childAspectRatio: 0.75,
//       ),
//       padding: EdgeInsets.all(16),
//       physics: NeverScrollableScrollPhysics(),
//       shrinkWrap: true,
//       itemCount: usersToDisplay.length,
//       itemBuilder: (context, index) {
//         return _buildUserGridCard(usersToDisplay[index]);
//       },
//     );
//   }
//
//   Widget _buildUserGridCard(UserData user) {
//     final isOwnProfile = authProvider.loginUserData.id == user.id;
//
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [
//             Color(0xFF1A1A1A),
//             Color(0xFF0D0D0D),
//           ],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.4),
//             blurRadius: 15,
//             offset: Offset(0, 5),
//           ),
//         ],
//         border: Border.all(
//           color: Colors.grey[800]!,
//           width: 1,
//         ),
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: () {
//             double w = MediaQuery.of(context).size.width;
//             double h = MediaQuery.of(context).size.height;
//             showUserDetailsModalDialog(user, w, h, context);
//           },
//           borderRadius: BorderRadius.circular(20),
//           child: Stack(
//             children: [
//               // Image de fond
//               Positioned.fill(
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(20),
//                   child: CachedNetworkImage(
//                     imageUrl: user.imageUrl ?? '',
//                     fit: BoxFit.cover,
//                     placeholder: (context, url) => Container(
//                       color: Colors.grey[900],
//                     ),
//                     errorWidget: (context, url, error) => Container(
//                       color: Colors.grey[900],
//                       child: Icon(
//                         Icons.person,
//                         color: Colors.grey[600],
//                         size: 40,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//               // Overlay gradient
//               Container(
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(20),
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.transparent,
//                       Colors.black.withOpacity(0.3),
//                       Colors.black.withOpacity(0.8),
//                     ],
//                   ),
//                 ),
//               ),
//
//               // Contenu
//               Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Header avec badge vérifié
//                     Row(
//                       children: [
//                         if (user.isVerify!)
//                           Container(
//                             padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                             decoration: BoxDecoration(
//                               color: Colors.blue,
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Icon(Icons.verified, size: 10, color: Colors.white),
//                                 SizedBox(width: 2),
//                                 Text(
//                                   'Vérifié',
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 8,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         Spacer(),
//                         if (!isOwnProfile)
//                           Container(
//                             padding: EdgeInsets.all(4),
//                             decoration: BoxDecoration(
//                               color: Colors.black.withOpacity(0.7),
//                               shape: BoxShape.circle,
//                             ),
//                             child: FutureBuilder<bool>(
//                               future: profileLikeProvider.hasLikedProfile(user.id!, authProvider.loginUserData.id!),
//                               builder: (context, snapshot) {
//                                 final hasLiked = snapshot.data ?? false;
//                                 return Icon(
//                                   hasLiked ? Icons.favorite : Icons.favorite_border,
//                                   color: hasLiked ? Colors.red : Colors.white,
//                                   size: 14,
//                                 );
//                               },
//                             ),
//                           ),
//                       ],
//                     ),
//
//                     Spacer(),
//
//                     // Informations utilisateur
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           '@${user.pseudo ?? "Utilisateur"}',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontWeight: FontWeight.bold,
//                             shadows: [
//                               Shadow(
//                                 blurRadius: 10,
//                                 color: Colors.black,
//                               ),
//                             ],
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         SizedBox(height: 4),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             _buildGridStatItem(
//                               _formatCount(user.userAbonnesIds?.length ?? 0),
//                               'Abonnés',
//                               Icons.people,
//                             ),
//                             _buildGridStatItem(
//                               _formatCount(user.userlikes ?? 0),
//                               'Likes',
//                               Icons.favorite,
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildGridStatItem(String value, String label, IconData icon) {
//     return Column(
//       children: [
//         Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(icon, color: Color(0xFFFFD700), size: 10),
//             SizedBox(width: 2),
//             Text(
//               value,
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 10,
//                 fontWeight: FontWeight.bold,
//                 shadows: [
//                   Shadow(
//                     blurRadius: 5,
//                     color: Colors.black,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 2),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.grey[300],
//             fontSize: 8,
//             shadows: [
//               Shadow(
//                 blurRadius: 5,
//                 color: Colors.black,
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xFF0A0A0A),
//       appBar: AppBar(
//         backgroundColor: Color(0xFF0A0A0A),
//         elevation: 0,
//         title: Text(
//           'Découvrir des Amis',
//           style: TextStyle(
//             color: Color(0xFFFFD700),
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         centerTitle: true,
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16.0),
//             child: Logo(),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Barre de recherche
//           _buildSearchField(),
//
//           // Contenu
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('Users')
//                   .where('id', isNotEqualTo: authProvider.loginUserData.id!)
//                   .limit(20)
//                   .snapshots(),
//               builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
//                 if (snapshot.hasData) {
//                   QuerySnapshot data = snapshot.requireData;
//                   List<UserData> list = data.docs
//                       .map((doc) =>
//                       UserData.fromJson(doc.data() as Map<String, dynamic>))
//                       .toList();
//
//                   if (!_isSearching && !_hasSearched) {
//                     listUser = list;
//                     filteredListUser = list;
//                   }
//
//                   return _buildUserGrid();
//                 } else if (snapshot.hasError) {
//                   print("${snapshot.error}");
//                   return Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.error_outline,
//                           color: Colors.red,
//                           size: 60,
//                         ),
//                         SizedBox(height: 16),
//                         Text(
//                           "Erreur de chargement",
//                           style: TextStyle(
//                             color: Colors.red,
//                             fontSize: 16,
//                           ),
//                         ),
//                         SizedBox(height: 16),
//                         ElevatedButton(
//                           onPressed: () => setState(() {}),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Color(0xFFFFD700),
//                             foregroundColor: Colors.black,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                           ),
//                           child: Text('Réessayer'),
//                         ),
//                       ],
//                     ),
//                   );
//                 } else {
//                   // Shimmer effect amélioré
//                   return GridView.builder(
//                     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: 2,
//                       crossAxisSpacing: 12,
//                       mainAxisSpacing: 12,
//                       childAspectRatio: 0.75,
//                     ),
//                     padding: EdgeInsets.all(16),
//                     physics: NeverScrollableScrollPhysics(),
//                     shrinkWrap: true,
//                     itemCount: 6,
//                     itemBuilder: (context, index) {
//                       return Container(
//                         decoration: BoxDecoration(
//                           color: Colors.grey[900],
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Column(
//                           children: [
//                             Expanded(
//                               child: Container(
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey[800],
//                                   borderRadius: BorderRadius.only(
//                                     topLeft: Radius.circular(20),
//                                     topRight: Radius.circular(20),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             Padding(
//                               padding: const EdgeInsets.all(12.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Container(
//                                     width: 80,
//                                     height: 16,
//                                     color: Colors.grey[800],
//                                   ),
//                                   SizedBox(height: 8),
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       Container(
//                                         width: 40,
//                                         height: 12,
//                                         color: Colors.grey[800],
//                                       ),
//                                       Container(
//                                         width: 40,
//                                         height: 12,
//                                         color: Colors.grey[800],
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   );
//                 }
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
// }