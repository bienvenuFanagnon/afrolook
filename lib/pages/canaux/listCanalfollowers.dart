import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/model_data.dart';

class ChannelFollowersPage extends StatefulWidget {
  final List<String> userIds;
  final String channelName;

  ChannelFollowersPage({
    required this.userIds,
    required this.channelName,
  });

  @override
  State<ChannelFollowersPage> createState() => _ChannelFollowersPageState();
}

class _ChannelFollowersPageState extends State<ChannelFollowersPage> {
  final ScrollController _scrollController = ScrollController();
  final List<UserData> _displayedUsers = [];
  int _currentPage = 0;
  final int _pageSize = 10;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoadComplete = false;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Vos couleurs
  final Color _primaryColor = Color(0xFFD32F2F); // Rouge
  final Color _secondaryColor = Color(0xFF212121); // Noir
  final Color _accentColor = Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = Color(0xFFFAFAFA); // Gris clair

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<UserData>> _getUsersBatch(List<String> userIds) async {
    List<UserData> listUsers = [];

    print('🔍 _getUsersBatch appelé avec ${userIds.length} userIds');

    if (userIds.isEmpty) {
      print('⚠️ Liste userIds vide');
      return listUsers;
    }

    try {
      CollectionReference userCollect = _firestore.collection('Users');
      const batchSize = 10;
      int batchCount = 0;

      for (int i = 0; i < userIds.length; i += batchSize) {
        batchCount++;
        final end = i + batchSize < userIds.length ? i + batchSize : userIds.length;
        final batchIds = userIds.sublist(i, end);

        print('\n📦 Batch $batchCount (${batchIds.length} IDs)');

        if (batchIds.isEmpty) continue;

        try {
          // QuerySnapshot querySnapshotUser = await userCollect
          //     .where('id', whereIn: batchIds)
          //     .get();

          QuerySnapshot querySnapshotUser = await userCollect
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();

          print('📊 Documents trouvés: ${querySnapshotUser.docs.length}');

          for (var doc in querySnapshotUser.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              final user = UserData.fromJson(data);
              listUsers.add(user);
            } catch (e) {
              print('❌ Erreur création UserData: $e');
            }
          }

          // Petite pause pour éviter les timeouts
          if (i + batchSize < userIds.length) {
            await Future.delayed(Duration(milliseconds: 50));
          }

        } catch (e) {
          print('❌ Erreur batch $batchCount: $e');
        }
      }

      print('✅ Total utilisateurs récupérés: ${listUsers.length} sur ${userIds.length}');

      // Trier par popularité
      listUsers.sort((a, b) {
        final aFollowers = a.userAbonnesIds?.length ?? 0;
        final bFollowers = b.userAbonnesIds?.length ?? 0;
        return bFollowers.compareTo(aFollowers);
      });

    } catch (e) {
      print('❌ Erreur globale _getUsersBatch: $e');
    }

    return listUsers;
  }

  Future<void> _loadInitialUsers() async {
    print('🚀 _loadInitialUsers appelé');

    if (widget.userIds.isEmpty) {
      print('📭 Liste userIds vide');
      if (mounted) {
        setState(() {
          _initialLoadComplete = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Charger la première page
      await _loadNextPage();
    } catch (e) {
      print('❌ Erreur _loadInitialUsers: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initialLoadComplete = true;
          print('🏁 Initialisation terminée');
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    print('\n📄 _loadNextPage appelé');
    print('   Page: $_currentPage');
    print('   _hasMore: $_hasMore');
    print('   _isLoading: $_isLoading');

    if (!_hasMore) {
      print('❌ _loadNextPage: _hasMore = false');
      return;
    }

    // if (_isLoading) {
    //   print('⚠️ _loadNextPage: _isLoading = true');
    //   return;
    // }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Calculer les indices pour cette page
      final startIndex = _currentPage * _pageSize;
      final endIndex = startIndex + _pageSize;
      final end = endIndex > widget.userIds.length ? widget.userIds.length : endIndex;

      print('📊 Chargement indices: $startIndex à $end');
      print('📊 Total users disponibles: ${widget.userIds.length}');

      if (startIndex >= widget.userIds.length) {
        print('📊 Déjà tout chargé');
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoading = false;
          });
        }
        return;
      }

      // Récupérer les IDs pour cette page
      final pageUserIds = widget.userIds.sublist(startIndex, end);
      print('📊 IDs à charger: ${pageUserIds.length}');

      if (pageUserIds.isEmpty) {
        print('❌ Aucun ID à charger');
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoading = false;
          });
        }
        return;
      }

      // Récupérer les utilisateurs depuis Firebase
      final List<UserData> newUsers = await _getUsersBatch(pageUserIds);

      print('✅ ${newUsers.length} utilisateurs récupérés');

      if (mounted) {
        setState(() {
          _displayedUsers.addAll(newUsers);
          _currentPage++;
          _hasMore = endIndex < widget.userIds.length;
          _isLoading = false;

          print('📊 État mis à jour:');
          print('   _displayedUsers: ${_displayedUsers.length}');
          print('   _currentPage: $_currentPage');
          print('   _hasMore: $_hasMore');
        });
      }

    } catch (e) {
      print('❌ Erreur _loadNextPage: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        _hasMore &&
        !_isLoading) {
      print('🔄 Déclenchement du scroll infini');
      _loadNextPage();
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _displayedUsers.clear();
        _currentPage = 0;
        _hasMore = true;
        _initialLoadComplete = false;
        _isLoading = true;
      });
    }

    await _loadNextPage();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _initialLoadComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Abonnés - ${widget.channelName}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _buildBody(width, height),
    );
  }

  Widget _buildBody(double width, double height) {
    if (_isLoading && !_initialLoadComplete) {
      return _buildLoading();
    }

    if (_displayedUsers.isEmpty && _initialLoadComplete) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      backgroundColor: _primaryColor,
      color: _accentColor,
      child: ListView.builder(
        controller: _scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        itemCount: _displayedUsers.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedUsers.length) {
            return _buildLoadingMore();
          }

          final user = _displayedUsers[index];
          return _buildUserItem(user, width, height, context);
        },
      ),
    );
  }

  Widget _buildUserItem(UserData user, double width, double height, BuildContext context) {
    final followerCount = user.abonnes ?? 0;
    final isVerified = user.isVerify ?? false;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showUserDetails(user, width, height, context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar avec badge vérifié
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _primaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: user.imageUrl?.isNotEmpty == true
                            ? Image.network(
                          user.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(_primaryColor),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultAvatar(),
                        )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                    if (isVerified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.verified,
                            color: _accentColor,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(width: 16),

                // Informations utilisateur
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.pseudo ?? 'Utilisateur',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _secondaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: 4),
                          if (user.isConnected ?? false)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatNumber(followerCount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(width: 2),
                          Text(
                            followerCount <= 1 ? 'abonné' : 'abonnés',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),

                      // Indicateur de popularité (optionnel)
                      if ((user.userAbonnesIds?.length ?? 0) > 1000)
                        Container(
                          margin: EdgeInsets.only(top: 6),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Populaire',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Flèche d'indication
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserDetails(UserData user, double width, double height, BuildContext context) {
    // Remplacer par votre fonction de détail
    showUserDetailsModalDialog(user, width, height, context);
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: _primaryColor.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.person,
          color: _primaryColor.withOpacity(0.6),
          size: 28,
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(_primaryColor),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Chargement des abonnés...',
            style: TextStyle(
              color: _secondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(_primaryColor),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'Aucun abonné',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _secondaryColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ce canal n\'a pas encore d\'abonnés',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: Text('Rafraîchir'),
            ),
          ],
        ),
      ),
    );
  }
}