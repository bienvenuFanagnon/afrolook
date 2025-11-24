import 'dart:math';

import 'package:afrotok/models/tiktokModel.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideoListe.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/constant/textCustom.dart';
import 'package:afrotok/pages/user/profile/profileDetail/widget/numbers_widget.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class OtherUserPage extends StatefulWidget {
  final UserData otherUser;

  const OtherUserPage({super.key, required this.otherUser});

  @override
  _OtherUserPageState createState() => _OtherUserPageState();
}

class _OtherUserPageState extends State<OtherUserPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  DocumentSnapshot? _lastDocument;
  String _selectedFilter = 'all';
  final int _postsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    try {
      setState(() => _loading = true);

      final query = _firestore
          .collection('Posts')
          .where('user_id', isEqualTo: widget.otherUser.id)
          .orderBy('created_at', descending: true)
          .limit(_postsPerPage);

      final snapshot = await query.get();

      // Filtrage manuel : on garde que ceux sans challenge_id et sans canal_id
      final filteredPosts = snapshot.docs
          .map((doc) => Post.fromJson({'id': doc.id, ...doc.data()}))
          .where((post) =>
      (post.challenge_id == null || post.challenge_id!.isEmpty) &&
          (post.canal_id == null || post.canal_id!.isEmpty)
          && (post.type == PostType.POST.name)
      )

          .toList();

      setState(() {
        _posts = filteredPosts;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _loading = false;
      });
    } catch (e) {
      print('Erreur chargement posts: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || _lastDocument == null) return;

    try {
      setState(() => _loadingMore = true);

      var query = _firestore
          .collection('Posts')
          .where('user_id', isEqualTo: widget.otherUser.id)
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage);

      if (_selectedFilter != 'all') {
        query = query.where('dataType', isEqualTo: _selectedFilter);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        // Filtrage manuel encore
        final filteredPosts = snapshot.docs
            .map((doc) => Post.fromJson({'id': doc.id, ...doc.data()}))
            .where((post) =>
        (post.challenge_id == null || post.challenge_id!.isEmpty) &&
            (post.canal_id == null || post.canal_id!.isEmpty)
            && (post.type == PostType.POST.name)
        )
            .toList();

        setState(() {
          _posts.addAll(filteredPosts);
          _lastDocument = snapshot.docs.last;
        });
      }
    } catch (e) {
      print('Erreur chargement plus de posts: $e');
    } finally {
      setState(() => _loadingMore = false);
    }
  }


  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange) {
      _loadMorePosts();
    }
  }

  Future<void> _applyFilter(String filter) async {
    setState(() {
      _selectedFilter = filter;
      _loading = true;
      _posts.clear();
      _lastDocument = null;
    });
    printVm("_selectedFilter : ${_selectedFilter}");
    await _loadInitialPosts();
  }

  List<Post> get _filteredPosts {
    if (_selectedFilter == 'all') return _posts;
    return _posts.where((post) => post.dataType == _selectedFilter).toList();
  }

  void _navigateToPostDetails(Post post) {
    if (post.dataType == PostDataType.VIDEO.name) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => VideoTikTokPageDetails(initialPost: post,),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DetailsPost(post: post),
      ));
    }
  }

  Widget _buildVerificationBadge() {
    if (widget.otherUser.isVerify == true) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text(
              'Vérifié',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _loadInitialPosts,
        backgroundColor: Colors.green,
        color: Colors.white,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // En-tête du profil
            SliverAppBar(
              expandedHeight: 300,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.green.withOpacity(0.3),
                        Colors.black,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Photo de profil
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: widget.otherUser.imageUrl ?? '',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[800],
                                  child: Icon(Icons.person, color: Colors.grey),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[800],
                                  child: Icon(Icons.person, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Nom et badge de vérification
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "@${widget.otherUser.pseudo!}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          _buildVerificationBadge(),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Code de parrainage
                      _buildReferralCode(),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),

            // Section statistiques
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    NumbersWidget(

                      followers: widget.otherUser.userAbonnesIds?.length ?? 0,
                      taux: widget.otherUser.popularite! * 100,
                      points: widget.otherUser.pointContribution!,
                    ),
                    SizedBox(height: 16),

                    // Likes
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        "${_formatNumber(widget.otherUser.userlikes!)} like(s)",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // À propos
                    _buildAboutSection(),
                    SizedBox(height: 16),

                    // Filtres
                    _buildFilterSection(),
                  ],
                ),
              ),
            ),

            // Grille des posts
            if (_loading)
              SliverToBoxAdapter(
                child: Container(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ),
              )
            else if (_filteredPosts.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  height: 200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.post_add,
                        size: 64,
                        color: Colors.grey[700],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _selectedFilter == 'all'
                            ? 'Aucun post publié'
                            : 'Aucun ${_getFilterLabel(_selectedFilter)} publié',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _filteredPosts.length) {
                      return _buildLoadMoreIndicator();
                    }
                    return _buildPostCard(_filteredPosts[index], width);
                  },
                  childCount: _filteredPosts.length + (_loadingMore ? 1 : 0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCode() {
    return Column(
      children: [
        Text(
          "Code de parrainage",
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.yellow.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.yellow),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${widget.otherUser.codeParrainage}",
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(
                      text: "${widget.otherUser.codeParrainage}"));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Code de parrainage copié !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Icon(Icons.copy, color: Colors.yellow, size: 16),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, color: Colors.blue, size: 16),
            SizedBox(width: 4),
            Text(
              "${widget.otherUser.usersParrainer!.length} parrainages",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'À PROPOS',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            widget.otherUser.apropos ?? 'Aucune description',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final filters = [
      {'value': 'all', 'label': 'Tous', 'icon': Icons.all_inclusive},
        {'value': 'IMAGE', 'label': 'Images', 'icon': Icons.photo},
      {'value': 'VIDEO', 'label': 'Vidéos', 'icon': Icons.videocam},
      {'value': 'TEXT', 'label': 'Textes', 'icon': Icons.text_fields},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FILTRER PAR TYPE',
          style: TextStyle(
            color: Colors.green,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final isSelected = _selectedFilter == filter['value'];
              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: FilterChip(

                  selected: isSelected,
                  onSelected: (_) => _applyFilter(filter['value'].toString()),
                  label: Text(
                    filter['label'].toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  deleteIcon: Icon(
                    filter['icon'] as IconData,
                    color: isSelected ? Colors.black : Colors.green,
                    size: 16,
                  ),
                  backgroundColor: Colors.grey[800],
                  selectedColor: Colors.green,
                  checkmarkColor: Colors.black,
                  side: BorderSide(color: Colors.green),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(Post post, double width) {
    return GestureDetector(
      onTap: () => _navigateToPostDetails(post),
      child: Container(
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[900],
          border: Border.all(color: Colors.green.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Contenu du post
            _buildPostContent(post),

            // Overlay avec statistiques
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPostStat(Icons.favorite, post.loves ?? 0),
                    _buildPostStat(Icons.visibility, post.vues ?? 0),
                    _buildPostStat(Icons.comment, post.comments ?? 0),
                  ],
                ),
              ),
            ),

            // Badge type de contenu
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getPostTypeIcon(post.dataType),
                      color: Colors.green,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _getPostTypeLabel(post.dataType),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildPostContent(Post post) {
    if (post.dataType == PostDataType.VIDEO.name && post.url_media != null) {
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: post.url_media!,
          imageFormat: ImageFormat.JPEG,
          maxHeight: 300, // taille de l'aperçu
          quality: 75,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.grey[700],
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Container(
              color: Colors.grey[700],
              child: Icon(Icons.videocam, color: Colors.green, size: 40),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                Center(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (post.dataType == 'IMAGE' &&
        post.images != null &&
        post.images!.isNotEmpty) {
      // Pour les images
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: post.images!.first,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            color: Colors.grey[700],
            child: Icon(Icons.photo, color: Colors.green),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[700],
            child: Icon(Icons.broken_image, color: Colors.green),
          ),
        ),
      );
    } else {
      // Pour les posts texte
      return _buildTextPost(post);
    }
  }

  Widget _buildTextPost(Post post) {
    // Liste de dégradés prédéfinis (tu peux en rajouter d’autres)
    final gradients = [
      [Colors.purple, Colors.deepPurpleAccent],
      [Colors.blue, Colors.lightBlueAccent],
      [Colors.green, Colors.teal],
      [Colors.orange, Colors.deepOrangeAccent],
      [Colors.red, Colors.pinkAccent],
      [Colors.indigo, Colors.blueGrey],
    ];

    // On génère un index en fonction de l'id (pour que ce soit stable)
    int gradientIndex = 0;
    if (post.id != null) {
      gradientIndex = post.id.hashCode % gradients.length;
    } else {
      gradientIndex = Random().nextInt(gradients.length);
    }

    final chosenGradient = gradients[gradientIndex];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: chosenGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          post.description ?? 'Post texte',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
          maxLines: 4, // limite comme un statut
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPostStat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.green, size: 12),
        SizedBox(width: 4),
        Text(
          _formatNumber(count),
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ),
    );
  }

  IconData _getPostTypeIcon(String? dataType) {
    switch (dataType) {
      case 'video':
        return Icons.videocam;
      case 'image':
        return Icons.photo;
      case 'text':
        return Icons.text_fields;
      default:
        return Icons.post_add;
    }
  }

  String _getPostTypeLabel(String? dataType) {
    switch (dataType) {
      case 'video':
        return 'VIDÉO';
      case 'image':
        return 'IMAGE';
      case 'text':
        return 'TEXTE';
      default:
        return 'POST';
    }
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'image':
          return 'IMAGE';
      case 'video':
        return 'VIDEO';
      case 'text':
        return 'TEXT';
      default:
        return 'IMAGE';
    }
  }

  String _formatNumber(int number) {
    if (number < 1000) {
      return number.toStringAsFixed(0);
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    } else if (number < 1000000000) {
      return '${(number / 1000000).toStringAsFixed(1)}m';
    } else {
      return '${(number / 1000000000).toStringAsFixed(1)}b';
    }
  }
}
