import 'package:afrotok/pages/userPosts/postWidgets/postWidgetPage.dart';
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

  List<Post> _favoritePosts = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isGridView = true; // Par défaut vue grille

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
    _loadFavoritePosts();
  }

  Future<void> _loadFavoritePosts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final userId = _authProvider.loginUserData.id!;

      // Récupérer la liste des IDs des posts favoris
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final favoriteIds = List<String>.from(userDoc.data()?['favoritePostsIds'] ?? []);

      if (favoriteIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _favoritePosts = [];
        });
        return;
      }

      // Récupérer les posts en batch (limité à 50 pour performance)
      final batchIds = favoriteIds.take(50).toList();
      final postsSnapshot = await _firestore
          .collection('Posts')
          .where('id', whereIn: batchIds)
          .get();

      // Convertir en objets Post
      final posts = postsSnapshot.docs.map((doc) {
        final postData = doc.data();
        final post = Post.fromJson(postData);
        post.id = doc.id;
        return post;
      }).toList();

      // Trier par date (les plus récents d'abord)
      posts.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

      setState(() {
        _favoritePosts = posts;
        _isLoading = false;
      });

    } catch (e) {
      print('Erreur chargement favoris: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 colonnes
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85, // Format carré légèrement vertical
      ),
      itemCount: _favoritePosts.length,
      itemBuilder: (context, index) {
        final post = _favoritePosts[index];
        return FavoritePostThumbnailWidget(
          post: post,
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
      itemCount: _favoritePosts.length,
      itemBuilder: (context, index) {
        final post = _favoritePosts[index];
        return Container(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          child: HomePostUsersWidget(
            post: post,
            color: _primaryColor,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 100,
              color: Colors.grey[600],
            ),
            SizedBox(height: 24),
            Text(
              'Aucun post en favoris',
              style: TextStyle(
                fontSize: 22,
                color: _textColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Les posts que vous ajoutez aux favoris\napparaîtront ici',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _subtextColor,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.info, color: _primaryColor, size: 24),
                  SizedBox(height: 8),
                  Text(
                    'Comment ajouter aux favoris ?',
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cliquez sur l\'icône 📖 sous chaque post',
                    style: TextStyle(
                      color: _subtextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                elevation: 3,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore),
                  SizedBox(width: 12),
                  Text(
                    'Explorer les posts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red),
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                color: _textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Impossible de charger vos favoris.\nVérifiez votre connexion internet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _subtextColor,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Retour'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loadFavoritePosts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Réessayer'),
                ),
              ],
            ),
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
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Chargement des favoris...',
            style: TextStyle(
              color: _textColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Veuillez patienter',
            style: TextStyle(
              color: _subtextColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    if (_favoritePosts.isEmpty) return SizedBox.shrink();

    int totalLikes = _favoritePosts.fold(0, (sum, post) => sum + (post.loves ?? 0));
    int totalComments = _favoritePosts.fold(0, (sum, post) => sum + (post.comments ?? 0));
    int totalViews = _favoritePosts.fold(0, (sum, post) => sum + (post.vues ?? 0));

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Résumé des favoris',
            style: TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.bookmark,
                value: _favoritePosts.length.toString(),
                label: 'Posts',
                color: _accentColor,
              ),
              _buildStatItem(
                icon: Icons.favorite,
                value: _formatCount(totalLikes),
                label: 'Likes total',
                color: Colors.red,
              ),
              _buildStatItem(
                icon: Icons.comment,
                value: _formatCount(totalComments),
                label: 'Commentaires',
                color: _primaryColor,
              ),
              _buildStatItem(
                icon: Icons.remove_red_eye,
                value: _formatCount(totalViews),
                label: 'Vues total',
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: _textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: _subtextColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Mes Favoris',
          style: TextStyle(
            color: _textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _backgroundColor,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          // Bouton pour changer de vue
          IconButton(
            icon: Icon(
              _isGridView ? Icons.list : Icons.grid_view,
              color: _textColor,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'Vue liste' : 'Vue grille',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: _textColor),
            onPressed: _loadFavoritePosts,
            tooltip: 'Rafraîchir',
          ),
          if (_favoritePosts.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 16, top: 16),
              child: Text(
                '${_favoritePosts.length}',
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
          ? _buildErrorState()
          : _favoritePosts.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          // Header avec statistiques
          _buildStatsHeader(),

          // Contenu
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFavoritePosts,
              color: _primaryColor,
              child: _isGridView ? _buildGridView() : _buildListView(),
            ),
          ),
        ],
      ),
      floatingActionButton: _favoritePosts.isNotEmpty
          ? FloatingActionButton(
        onPressed: () {
          setState(() {
            _isGridView = !_isGridView;
          });
        },
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        child: Icon(
          _isGridView ? Icons.list : Icons.grid_view,
        ),
        tooltip: _isGridView ? 'Vue liste' : 'Vue grille',
      )
          : null,
    );
  }
}