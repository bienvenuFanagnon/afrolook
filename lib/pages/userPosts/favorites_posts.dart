import 'package:afrotok/pages/userPosts/postWidgets/postWidgetPage.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';

import '../../providers/postProvider.dart';

import '../home/homeWidget.dart';

import '../../models/model_data.dart';

import 'favorite_post_thumbnail.dart';

class FavoritePostsPage extends StatefulWidget {
  @override
  _FavoritePostsPageState createState() => _FavoritePostsPageState();
}

class _FavoritePostsPageState extends State<FavoritePostsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late UserAuthProvider _authProvider;
  late PostProvider _postProvider;

  // Tous les IDs (triés du plus récent au plus ancien)
  List<String> _allIds = [];
  // Posts déjà chargés
  List<Post> _favoritePosts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _isGridView = true;

  static const int _pageSize = 10;
  int _loadedCount = 0; // combien d'IDs ont déjà été chargés

  // Couleurs du thème
  final Color _backgroundColor = Color(0xFF000000);
  final Color _textColor = Colors.white;
  final Color _subtextColor = Colors.grey[400]!;
  final Color _primaryColor = Color(0xFF2E7D32);
  final Color _accentColor = Color(0xFFFFD600);

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);
    _loadInitial();
  }

  /// Charge la liste des IDs depuis le document utilisateur, puis la première page.
  Future<void> _loadInitial() async {
    setState(() { _isLoading = true; _hasError = false; _allIds = []; _favoritePosts = []; _loadedCount = 0; });
    try {
      final userId = _authProvider.loginUserData.id!;
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final ids = List<String>.from(userDoc.data()?['favoritePostsIds'] ?? []);
      _allIds = ids.reversed.toList(); // plus récent en premier
      await _fetchNextPage();
    } catch (e) {
      printVm('Erreur chargement favoris: $e');
      if (mounted) setState(() { _hasError = true; _isLoading = false; });
    }
  }

  /// Charge la prochaine tranche de _pageSize posts.
  Future<void> _fetchNextPage() async {
    final chunk = _allIds.skip(_loadedCount).take(_pageSize).toList();
    if (chunk.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _isLoadingMore = false; });
      return;
    }
    try {
      final snap = await _firestore.collection('Posts').where(FieldPath.documentId, whereIn: chunk).get();
      final posts = <Post>[];
      for (final doc in snap.docs) {
        try {
          final p = Post.fromJson(doc.data()); p.id = doc.id; posts.add(p);
        } catch (e) { printVm('Favori illisible ${doc.id}: $e'); }
      }
      // Trier selon l'ordre des IDs (plus récent d'abord)
      posts.sort((a, b) => chunk.indexOf(a.id ?? '').compareTo(chunk.indexOf(b.id ?? '')));
      if (mounted) setState(() {
        _favoritePosts.addAll(posts);
        _loadedCount += chunk.length;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      printVm('Erreur page favoris: $e');
      if (mounted) setState(() { _hasError = _loadedCount == 0; _isLoading = false; _isLoadingMore = false; });
    }
  }

  bool get _hasMore => _loadedCount < _allIds.length;

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() { _isLoadingMore = true; });
    await _fetchNextPage();
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: _favoritePosts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _favoritePosts.length) return _buildLoadMoreButton();
        return FavoritePostThumbnailWidget(
          post: _favoritePosts[index],
          size: 120,
          showStats: true,
          showUserInfo: true,
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 20),
      itemCount: _favoritePosts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _favoritePosts.length) return _buildLoadMoreButton();
        return Container(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          child: HomePostUsersWidget(
            post: _favoritePosts[index],
            color: _primaryColor,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: _isLoadingMore
          ? Center(child: CircularProgressIndicator(color: _primaryColor, strokeWidth: 2))
          : ElevatedButton.icon(
              onPressed: _loadMore,
              icon: Icon(Icons.expand_more),
              label: Text('Charger plus (${_allIds.length - _loadedCount} restants)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 100, color: Colors.grey[600]),
            SizedBox(height: 24),
            Text('Aucun post en favoris',
                style: TextStyle(fontSize: 22, color: _textColor, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            SizedBox(height: 12),
            Text('Les posts que vous ajoutez aux favoris\napparaîtront ici',
                textAlign: TextAlign.center,
                style: TextStyle(color: _subtextColor, fontSize: 16)),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor),
              ),
              child: Column(children: [
                Icon(Icons.info, color: _primaryColor, size: 24),
                SizedBox(height: 8),
                Text('Comment ajouter aux favoris ?',
                    style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Cliquez sur l\'icône 📖 sous chaque post',
                    style: TextStyle(color: _subtextColor, fontSize: 14)),
              ]),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.explore), SizedBox(width: 12),
                Text('Explorer les posts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red)),
              child: Icon(Icons.error_outline, size: 60, color: Colors.red),
            ),
            SizedBox(height: 24),
            Text('Erreur de chargement', style: TextStyle(color: _textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Impossible de charger vos favoris.\nVérifiez votre connexion internet.',
                textAlign: TextAlign.center, style: TextStyle(color: _subtextColor, fontSize: 16)),
            SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                child: Text('Retour'),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: _loadInitial,
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                child: Text('Réessayer'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: CircularProgressIndicator(color: _primaryColor, strokeWidth: 3),
          ),
          SizedBox(height: 24),
          Text('Chargement des favoris...', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Veuillez patienter', style: TextStyle(color: _subtextColor, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    if (_favoritePosts.isEmpty) return SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryColor.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_favoritePosts.length} affiché${_favoritePosts.length > 1 ? 's' : ''}',
              style: TextStyle(color: _textColor, fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${_allIds.length} au total',
              style: TextStyle(color: _accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Mes Favoris',
            style: TextStyle(color: _textColor, fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: _backgroundColor,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view, color: _textColor),
            onPressed: () => setState(() { _isGridView = !_isGridView; }),
            tooltip: _isGridView ? 'Vue liste' : 'Vue grille',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: _textColor),
            onPressed: _loadInitial,
            tooltip: 'Rafraîchir',
          ),
          if (_allIds.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 16, top: 16),
              child: Text('${_allIds.length}',
                  style: TextStyle(color: _accentColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
              ? _buildErrorState()
              : _allIds.isEmpty
                  ? _buildEmptyState()
                  : Column(children: [
                      _buildStatsHeader(),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadInitial,
                          color: _primaryColor,
                          child: _isGridView ? _buildGridView() : _buildListView(),
                        ),
                      ),
                    ]),
    );
  }
}
