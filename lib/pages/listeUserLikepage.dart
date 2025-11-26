// pages/users/users_list_page.dart
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

class _UsersListPageState extends State<UsersListPage> {
  final ScrollController _scrollController = ScrollController();
  final List<UserData> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _batchSize = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
    _scrollController.addListener(_onScroll);
  }

  void _loadInitialUsers() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _users.clear();
      _hasMore = true;
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

  Future<List<UserData>> _fetchUsersBatch2({
    required int limit,
    DocumentSnapshot? lastDocument,
  }) async
  {
    try {
      Query query = FirebaseFirestore.instance
          .collection('Users')
          .where('isBlocked', isEqualTo: false)
          // .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) return [];

      // Mettre à jour le lastDocument
      _lastDocument = snapshot.docs.last;

      // Mélanger aléatoirement les utilisateurs
      final users = snapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      users.shuffle(); // Mélange aléatoire

      return users;
    } catch (e) {
      throw Exception('Erreur fetch users: $e');
    }
  }
  final _seenUserIds = <String>{};

  Future<List<UserData>> _fetchUsersBatch({
    required int limit,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // Récupérer plus d'utilisateurs pour avoir plus de choix
      final fetchLimit = lastDocument == null ? limit * 5 : limit * 2;

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

      // Filtrer les utilisateurs déjà vus récemment
      final users = snapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .where((user) => user.id != null && !_seenUserIds.contains(user.id))
          .toList();

      // Si pas assez de nouveaux utilisateurs, en prendre quand même
      final resultUsers = users.isNotEmpty ? users : snapshot.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // Mélanger aléatoirement
      resultUsers.shuffle();

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

  void refreshUsersRandomly() {
    _seenUserIds.clear();
    _lastDocument = null;
  }
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Header
          SliverAppBar(
            backgroundColor: Color(0xFF0A0A0A),
            elevation: 0,
            pinned: true,
            title: Text(
              'Découvrir',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search, color: Color(0xFFFFD700)),
                onPressed: () {},
              ),
            ],
          ),

          // Contenu
          _isLoading && _users.isEmpty
              ? SliverFillRemaining(
            child: Center(
              child: LoadingAnimationWidget.flickr(
                size: 60,
                leftDotColor: Color(0xFFFFD700),
                rightDotColor: Color(0xFF8B0000),
              ),
            ),
          )
              : _users.isEmpty
              ? SliverFillRemaining(
            child: _buildEmptyState(),
          )
              : SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index == _users.length) {
                    return _buildLoadMoreIndicator();
                  }
                  return _buildUserCard(_users[index]);
                },
                childCount: _users.length + (_hasMore ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserData user) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF0D0D0D),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Image de fond
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: user.imageUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[900],
                  child: Icon(
                    Icons.person,
                    color: Colors.grey[600],
                    size: 50,
                  ),
                ),
              ),
            ),

            // Overlay gradient
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec badge vérifié
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (user.isVerify!)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: Colors.white),
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
                        ),
                      Spacer(),
                      _buildLikeButton(user),
                    ],
                  ),
                ),

                Spacer(),

                // Informations utilisateur
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pseudo
                      Text(
                        '@${user.pseudo ?? "Utilisateur"}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 8),

                      // Statistiques
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            _formatCount(user.userAbonnesIds?.length ?? 0),
                            'Abonnés',
                            Icons.people,
                          ),
                          // _buildStatItem(
                          //   _formatCount(user.userlikes ?? 0),
                          //   'Likes',
                          //   Icons.favorite,
                          // ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // Bouton voir profil
                      Container(
                        width: double.infinity,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFFFD700).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () {
                            double w = MediaQuery.of(context).size.width;
                            double h = MediaQuery.of(context).size.height;
                            showUserDetailsModalDialog(user, w, h, context);
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            'Voir Profil',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikeButton(UserData user) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final profileLikeProvider = Provider.of<ProfileLikeProvider>(context, listen: false);
    final isOwnProfile = authProvider.loginUserData.id == user.id;

    if (isOwnProfile) return SizedBox();

    return StreamBuilder<int>(
      stream: profileLikeProvider.getProfileLikesStream(user.id!),
      builder: (context, snapshot) {
        final likesCount = snapshot.data ?? user.userlikes ?? 0;

        return FutureBuilder<bool>(
          future: profileLikeProvider.hasLikedProfile(user.id!, authProvider.loginUserData.id!),
          builder: (context, hasLikedSnapshot) {
            final hasLiked = hasLikedSnapshot.data ?? false;

            return GestureDetector(
              onTap: () async {
                try {
                  if (hasLiked) {
                    await profileLikeProvider.unlikeProfile(user.id!, authProvider.loginUserData.id!);
                  } else {
                    await profileLikeProvider.likeProfile(user.id!, authProvider.loginUserData.id!);

                    // Envoyer notification
                    if (user.oneIgnalUserid != null && user.oneIgnalUserid!.isNotEmpty) {
                      await authProvider.sendNotification(
                        appName: '@${authProvider.loginUserData.pseudo!}',
                        userIds: [user.oneIgnalUserid!],
                        smallImage: authProvider.loginUserData.imageUrl!,
                        send_user_id: authProvider.loginUserData.id!,
                        recever_user_id: user.id!,
                        message: "❤️ a aimé votre profil !",
                        type_notif: 'PROFILE_LIKE',
                        post_id: "",
                        post_type: "",
                        chat_id: '',
                      );
                    }
                  }
                } catch (e) {
                  print('Erreur like profil: $e');
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasLiked ? Colors.red : Colors.grey[600]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasLiked ? Icons.favorite : Icons.favorite_border,
                      color: hasLiked ? Colors.red : Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _formatCount(likesCount),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Color(0xFFFFD700), size: 12),
            SizedBox(width: 2),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreIndicator() {
    return _isLoading
        ? Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: LoadingAnimationWidget.flickr(
          size: 30,
          leftDotColor: Color(0xFFFFD700),
          rightDotColor: Color(0xFF8B0000),
        ),
      ),
    )
        : Container();
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.people_outline,
          color: Color(0xFFFFD700),
          size: 80,
        ),
        SizedBox(height: 20),
        Text(
          'Aucun utilisateur trouvé',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Revenez plus tard pour découvrir\nde nouveaux profils !',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}