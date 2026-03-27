// lib/pages/dating/dating_creator_posts_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/dating_data.dart';
import '../../models/enums.dart';
import '../../providers/authProvider.dart';
import 'creator_content_detail_page.dart';
import 'creator_content_form_page.dart';
import 'creator_profile_page.dart';
import 'creator_subscription_page.dart';
import 'creator_register_page.dart';

class DatingCreatorPostsPage extends StatefulWidget {
  const DatingCreatorPostsPage({Key? key}) : super(key: key);

  @override
  State<DatingCreatorPostsPage> createState() => _DatingCreatorPostsPageState();
}

class _DatingCreatorPostsPageState extends State<DatingCreatorPostsPage> {
  // Données
  List<CreatorContent> _contents = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String? _error;
  String? _currentUserId;
  CreatorProfile? _myCreatorProfile;
  bool _isCreator = false;
  bool _isLoadingCreatorProfile = true;
  Map<String, bool> _subscriptionCache = {};
  Set<String> _viewedContentIds = {};

  // UI
  int _displayMode = 0; // 0: page view, 1: grid
  int _currentPage = 0;
  PageController _pageController = PageController();
  ScrollController _gridScrollController = ScrollController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _batchSize = 5;

  final Color primaryRed = const Color(0xFFE63946);
  final Color primaryYellow = const Color(0xFFFFD700);
  final Color primaryBlack = Colors.black;

  @override
  void initState() {
    super.initState();
    // NE PAS mettre _isLoading à true ici ; il est déjà true.
    // On initialise après le premier frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      _currentUserId = authProvider.loginUserData.id;
      _checkIfUserIsCreator();
      _loadSubscriptions();
      _loadContents(); // Premier chargement
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkIfUserIsCreator() async {
    if (_currentUserId == null) {
      setState(() => _isLoadingCreatorProfile = false);
      return;
    }
    try {
      print('🔍 Vérification si utilisateur est créateur...');
      final snapshot = await _firestore
          .collection('creator_profiles')
          .where('userId', isEqualTo: _currentUserId)
          .where('isCreatorActive', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        _myCreatorProfile = CreatorProfile.fromJson(snapshot.docs.first.data());
        setState(() => _isCreator = true);
        print('✅ Utilisateur est créateur: ${_myCreatorProfile!.pseudo}');
      } else {
        print('ℹ️ Utilisateur n\'est pas créateur');
      }
    } catch (e) {
      print('❌ Erreur vérification créateur: $e');
    } finally {
      setState(() => _isLoadingCreatorProfile = false);
    }
  }

  Future<void> _loadSubscriptions() async {
    if (_currentUserId == null) return;
    try {
      print('📥 Chargement des abonnements créateur...');
      final snapshot = await _firestore
          .collection('creator_subscriptions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .get();
      for (var doc in snapshot.docs) {
        _subscriptionCache[doc['creatorId']] = true;
      }
      print('✅ ${_subscriptionCache.length} abonnements chargés');
    } catch (e) {
      print('❌ Erreur chargement abonnements: $e');
    }
  }

  bool _isSubscribedToCreator(String creatorId) {
    return _subscriptionCache[creatorId] ?? false;
  }

  Future<void> _loadContents({bool loadMore = false}) async {
    // 🔥 Suppression du guard qui bloquait le premier chargement
    // On vérifie seulement si on est déjà en train de charger plus
    if (loadMore && (_isLoadingMore || !_hasMore)) return;

    print('📱 _loadContents - loadMore: $loadMore, isLoading: $_isLoading, isLoadingMore: $_isLoadingMore, hasMore: $_hasMore');

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      Query query = _firestore
          .collection('creator_contents')
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
        print('📄 Pagination après document: ${_lastDocument!.id}');
      }

      final snapshot = await query.limit(_batchSize).get();
      print('📊 Nombre de documents trouvés: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('⚠️ Aucun document trouvé');
        setState(() => _hasMore = false);
      } else {
        _lastDocument = snapshot.docs.last;
        final newContents = snapshot.docs
            .map((doc) => CreatorContent.fromJson(doc.data() as Map<String, dynamic>))
            .toList();

        setState(() {
          if (loadMore) {
            _contents.addAll(newContents);
            print('📦 Ajout de ${newContents.length} contenus (total: ${_contents.length})');
          } else {
            _contents = newContents;
            print('🎯 Premier chargement: ${_contents.length} contenus');
          }
        });
      }
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _recordView(CreatorContent content) {
    if (_viewedContentIds.contains(content.id)) return;
    _viewedContentIds.add(content.id);
    _firestore
        .collection('creator_contents')
        .doc(content.id)
        .update({'viewsCount': FieldValue.increment(1)});
    print('👁️ Vue enregistrée pour ${content.titre}');
  }

  Future<void> _toggleLike(CreatorContent content) async {
    final canAccess = !content.isPaid || _isSubscribedToCreator(content.creatorId);
    if (!canAccess) {
      _showSubscriptionRequiredDialog(content.creatorId);
      return;
    }

    try {
      await _firestore
          .collection('creator_contents')
          .doc(content.id)
          .update({'likesCount': FieldValue.increment(1)});
      final index = _contents.indexWhere((c) => c.id == content.id);
      if (index != -1) {
        setState(() {
          _contents[index] = content.copyWith(likesCount: content.likesCount + 1);
        });
      }
      _showLikeAnimation();
    } catch (e) {
      print('❌ Erreur like: $e');
    }
  }

  void _showLikeAnimation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❤️ Vous avez aimé ce contenu', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _showSubscriptionRequiredDialog(String creatorId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.lock, color: primaryYellow),
            const SizedBox(width: 8),
            const Text('Abonnement requis', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Pour accéder à ce contenu payant, vous devez vous abonner à ce créateur.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorSubscriptionPage(
                    creatorId: creatorId,
                    creatorName: 'ce créateur',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryYellow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text('S\'abonner', style: TextStyle(color: primaryBlack, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToCreatorProfile(String creatorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorProfilePage(userId: creatorId),
      ),
    );
  }

  void _navigateToCreateContent() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreatorContentFormPage()),
    ).then((_) => _loadContents());
  }

  void _navigateToMyCreatorProfile() {
    if (_myCreatorProfile != null) {
      _navigateToCreatorProfile(_myCreatorProfile!.userId);
    }
  }

  void _checkScroll() {
    if (_gridScrollController.position.pixels >= _gridScrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) _loadContents(loadMore: true);
    }
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _contents.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        _recordView(_contents[index]);
      },
      itemBuilder: (context, index) => _buildContentCard(_contents[index], index == _currentPage),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _gridScrollController,
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _contents.length,
      itemBuilder: (context, index) => _buildGridCard(_contents[index]),
    );
  }

  Widget _buildGridCard(CreatorContent content) {
    final canAccess = !content.isPaid || _isSubscribedToCreator(content.creatorId);
    return GestureDetector(
      onTap: () {
        if (canAccess) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreatorContentDetailPage(content: content)),
          );
        } else {
          _showSubscriptionRequiredDialog(content.creatorId);
        }
      },
      onDoubleTap: () => _toggleLike(content),
      child: Card(
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: content.thumbnailUrl ?? content.mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey[800]),
                      errorWidget: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey),
                    ),
                    if (content.isPaid && !canAccess)
                      Container(
                        color: Colors.black54,
                        child: Center(child: Icon(Icons.lock, size: 30, color: Colors.white)),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: content.isPaid ? Colors.amber : Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          content.isPaid ? '${content.priceCoins} coins' : 'Gratuit',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.titre,
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 12, color: Colors.red),
                      SizedBox(width: 2),
                      Text('${content.likesCount}', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                      SizedBox(width: 8),
                      Icon(Icons.visibility, size: 12, color: Colors.grey[500]),
                      SizedBox(width: 2),
                      Text('${content.viewsCount}', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCard(CreatorContent content, bool isCurrent) {
    final canAccess = !content.isPaid || _isSubscribedToCreator(content.creatorId);
    final isVideo = content.mediaType == MediaType.video;

    return GestureDetector(
      onDoubleTap: () => _toggleLike(content),
      onTap: () {
        if (canAccess) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreatorContentDetailPage(content: content)),
          );
        } else {
          _showSubscriptionRequiredDialog(content.creatorId);
        }
      },
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Média
              Positioned.fill(
                child: isVideo
                    ? Container(
                  color: Colors.black,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: content.thumbnailUrl ?? content.mediaUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    : CachedNetworkImage(
                  imageUrl: content.mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[800]),
                  errorWidget: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
              if (content.isPaid && !canAccess)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text('Contenu payant', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('${content.priceCoins} coins', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _showSubscriptionRequiredDialog(content.creatorId),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryYellow),
                          child: Text('S\'abonner', style: TextStyle(color: primaryBlack)),
                        ),
                      ],
                    ),
                  ),
                ),
              // Gradient d'info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          content.titre,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          content.description,
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            // Profil créateur
                            FutureBuilder<CreatorProfile?>(
                              future: _getCreatorProfile(content.creatorId),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return GestureDetector(
                                    onTap: () => _navigateToCreatorProfile(snapshot.data!.userId),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage: NetworkImage(snapshot.data!.imageUrl),
                                          child: snapshot.data!.imageUrl.isEmpty ? Icon(Icons.person, size: 16) : null,
                                        ),
                                        SizedBox(width: 8),
                                        Text(snapshot.data!.pseudo, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  );
                                }
                                return SizedBox.shrink();
                              },
                            ),
                            Spacer(),
                            // Like button & counter
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.favorite_border, color: Colors.white, size: 20),
                                  onPressed: () => _toggleLike(content),
                                ),
                                Text('${content.likesCount}', style: TextStyle(color: Colors.white)),
                                SizedBox(width: 12),
                                Icon(Icons.visibility, size: 16, color: Colors.white70),
                                SizedBox(width: 4),
                                Text('${content.viewsCount}', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Badge payant/gratuit
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: content.isPaid ? Colors.amber : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    content.isPaid ? '${content.priceCoins} coins' : 'Gratuit',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<CreatorProfile?> _getCreatorProfile(String creatorId) async {
    final doc = await _firestore.collection('creator_profiles').doc(creatorId).get();
    if (doc.exists) return CreatorProfile.fromJson(doc.data()!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCreatorProfile || _isLoading) {
      return Scaffold(
        backgroundColor: primaryBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryRed),
              SizedBox(height: 16),
              Text('Chargement...', style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: primaryBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red),
              SizedBox(height: 16),
              Text('Erreur: $_error', style: TextStyle(color: Colors.white)),
              SizedBox(height: 16),
              ElevatedButton(onPressed: () => _loadContents(), child: Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.people, color: primaryYellow, size: 24),
            const SizedBox(width: 8),
            Text('Créateurs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: primaryRed,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_displayMode == 0 ? Icons.grid_view : Icons.view_carousel, color: Colors.white),
            onPressed: () => setState(() => _displayMode = 1 - _displayMode),
          ),
          if (_isCreator && !_isLoadingCreatorProfile)
            IconButton(
              icon: Icon(Icons.add, color: primaryYellow, size: 28),
              onPressed: _navigateToCreateContent,
              tooltip: 'Créer un contenu',
            ),
          if (_isCreator && !_isLoadingCreatorProfile)
            IconButton(
              icon: Icon(Icons.person, color: Colors.white, size: 24),
              onPressed: _navigateToMyCreatorProfile,
              tooltip: 'Mon profil créateur',
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isCreator)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryRed, primaryYellow]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.monetization_on, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deviens créateur !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Partage ton contenu et gagne de l\'argent', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreatorRegisterPage())),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    child: Text('Commencer', style: TextStyle(color: primaryRed)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _contents.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 80, color: Colors.grey[600]),
                  SizedBox(height: 16),
                  Text('Aucun contenu pour le moment', style: TextStyle(color: Colors.grey[500])),
                  if (_isCreator)
                    ElevatedButton(
                      onPressed: _navigateToCreateContent,
                      child: Text('Créer mon premier contenu'),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryYellow, foregroundColor: Colors.black),
                    ),
                ],
              ),
            )
                : _displayMode == 0
                ? _buildPageView()
                : _buildGridView(),
          ),
          if (_isLoadingMore)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator(color: primaryRed)),
            ),
          if (_displayMode == 0 && _contents.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _contents.length,
                      (index) => Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage ? primaryYellow : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}