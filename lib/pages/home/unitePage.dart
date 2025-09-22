import 'dart:async';
import 'dart:math';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/contentDetails.dart';
import 'package:afrotok/pages/contenuPayant/contentSerie.dart';
import 'package:afrotok/pages/home/storyCustom/StoryCustom.dart';
import 'package:afrotok/pages/story/afroStory/storie/storyFormChoise.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../userPosts/postWidgets/postWidgetPage.dart';

class UnifiedHomePage extends StatefulWidget {
  const UnifiedHomePage({super.key});

  @override
  State<UnifiedHomePage> createState() => _UnifiedHomePageState();
}

class _UnifiedHomePageState extends State<UnifiedHomePage> {
  final int _initialLimit = 5;
  final int _loadMoreLimit = 5;

  late UserAuthProvider _authProvider;
  late PostProvider _postProvider;
  late ContentProvider _contentProvider;

  List<Post> _posts = [];
  List<ContentPaie> _contents = [];
  List<dynamic> _mixedItems = [];

  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _hasMoreContent = true;

  // Pour stocker le nombre total de documents
  int _totalPostsCount = 0;
  int _totalContentCount = 0;

  DocumentSnapshot? _lastPostDocument;
  DocumentSnapshot? _lastContentDocument;

  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  Color _color = Colors.blue;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);
    _contentProvider = Provider.of<ContentProvider>(context, listen: false);

    _loadInitialData();

    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        (_hasMorePosts || _hasMoreContent)) {
      _loadMoreData();
    }
  }

  void _changeColor() {
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.brown,
      Colors.blueAccent,
      Colors.red,
      Colors.yellow,
    ];
    _color = colors[_random.nextInt(colors.length)];
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      _lastPostDocument = null;
      _lastContentDocument = null;

      // Charger les comptes totaux et les données initiales
      await Future.wait([
        _getTotalPostsCount(),
        _getTotalContentCount(),
        _loadPostsWithStream(isInitialLoad: true),
        _loadContentWithStream(isInitialLoad: true),
      ]);

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading initial data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // Obtenir le nombre total de posts
  Future<void> _getTotalPostsCount() async {
    try {
      final query = FirebaseFirestore.instance.collection('Posts')
          .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          .where("typeTabbar", isEqualTo: TabBarType.LOOKS.name)
          .where("type", isEqualTo: PostType.POST.name);

      final snapshot = await query.count().get();
      _totalPostsCount = snapshot.count!;
      print('_totalPostsCount content count: $_totalPostsCount');

    } catch (e) {
      print('Error getting total posts count: $e');
      _totalPostsCount = 0;
    }
  }

  // Obtenir le nombre total de contenus
  Future<void> _getTotalContentCount() async {
    try {
      final query = FirebaseFirestore.instance.collection('ContentPaies');
      final snapshot = await query.count().get();
      _totalContentCount = snapshot.count!;
      print('_totalContentCount content count: $_totalContentCount');

    } catch (e) {
      print('Error getting total content count: $e');
      _totalContentCount = 0;
    }
  }

  Future<void> _loadPostsWithStream({bool isInitialLoad = false}) async {
    try {
      Query query = FirebaseFirestore.instance.collection('Posts')
          .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          .where("typeTabbar", isEqualTo: TabBarType.LOOKS.name)
          .where("type", isEqualTo: PostType.POST.name)
          .orderBy("status") // obligatoire si tu utilises isNotEqualTo
          .orderBy("created_at", descending: true);

      if (_lastPostDocument != null && !isInitialLoad) {
        query = query.startAfterDocument(_lastPostDocument!);
      }

      query = query.limit(isInitialLoad ? _initialLimit : _loadMoreLimit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastPostDocument = snapshot.docs.last;
      }

      final newPosts = <Post>[];

      for (var doc in snapshot.docs) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);

        final userFuture = post.user_id != null && post.user_id!.isNotEmpty
            ? FirebaseFirestore.instance
            .collection('Users')
            .where("id", isEqualTo: post.user_id)
            .get()
            .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            post.user = UserData.fromJson(snapshot.docs.first.data());
          }
          return post;
        })
            : Future.value(post);

        final canalFuture = post.canal_id != null && post.canal_id!.isNotEmpty
            ? FirebaseFirestore.instance
            .collection('Canaux')
            .where("id", isEqualTo: post.canal_id)
            .get()
            .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            post.canal = Canal.fromJson(snapshot.docs.first.data());
          }
          return post;
        })
            : Future.value(post);

        final completedPost = await Future.wait([userFuture, canalFuture]).then((_) => post);
        newPosts.add(completedPost);
      }

      if (isInitialLoad) {
        _posts = newPosts;
      } else {
        final existingIds = _posts.map((p) => p.id).toSet();
        final uniqueNewPosts = newPosts.where((post) => !existingIds.contains(post.id)).toList();
        _posts.addAll(uniqueNewPosts);
      }

      // Vérifier s'il reste des posts à charger basé sur le compte total
      _hasMorePosts = _posts.length < _totalPostsCount;
      _createMixedList();

    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _hasMorePosts = false;
      });
    }
  }

  Future<void> _loadContentWithStream({bool isInitialLoad = false}) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('ContentPaies')
          .orderBy('createdAt', descending: true);

      if (_lastContentDocument != null && !isInitialLoad) {
        query = query.startAfterDocument(_lastContentDocument!);
      }

      query = query.limit(isInitialLoad ? _initialLimit : _loadMoreLimit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastContentDocument = snapshot.docs.last;
      }

      final newContents = snapshot.docs
          .map((doc) => ContentPaie.fromJson({
        ...?doc.data() as Map<String, dynamic>?,
        'id': doc.id,
      }))
          .toList();

      if (isInitialLoad) {
        _contents = newContents;
      } else {
        final existingIds = _contents.map((c) => c.id).toSet();
        final uniqueNewContents = newContents.where((content) => !existingIds.contains(content.id)).toList();
        _contents.addAll(uniqueNewContents);
      }

      // Vérifier s'il reste des contenus à charger basé sur le compte total
      _hasMoreContent = _contents.length < _totalContentCount;
      _createMixedList();

    } catch (e) {
      print('Error loading content: $e');
      setState(() {
        _hasMoreContent = false;
      });
    }
  }

  void _createMixedList() {
    _mixedItems = [];
    int postIndex = 0;
    int contentIndex = 0;
    int cycle = 0;

    while (postIndex < _posts.length && contentIndex < _contents.length) {
      if (cycle % 2 == 0) {
        if (postIndex < _posts.length) {
          _mixedItems.add(_MixedItem(type: _MixedItemType.post, data: _posts[postIndex]));
          postIndex++;
        }

        if (contentIndex < _contents.length) {
          final contentsToAdd = [];
          for (int i = 0; i < 2 && contentIndex < _contents.length; i++) {
            contentsToAdd.add(_contents[contentIndex]);
            contentIndex++;
          }
          _mixedItems.add(_MixedItem(type: _MixedItemType.contentGrid, data: contentsToAdd));
        }
      } else {
        for (int i = 0; i < 2 && postIndex < _posts.length; i++) {
          _mixedItems.add(_MixedItem(type: _MixedItemType.post, data: _posts[postIndex]));
          postIndex++;
        }

        if (contentIndex < _contents.length) {
          final contentsToAdd = [];
          for (int i = 0; i < 2 && contentIndex < _contents.length; i++) {
            contentsToAdd.add(_contents[contentIndex]);
            contentIndex++;
          }
          _mixedItems.add(_MixedItem(type: _MixedItemType.contentGrid, data: contentsToAdd));
        }
      }
      cycle++;
    }

    while (postIndex < _posts.length) {
      _mixedItems.add(_MixedItem(type: _MixedItemType.post, data: _posts[postIndex]));
      postIndex++;
    }

    while (contentIndex < _contents.length) {
      final contentsToAdd = [];
      for (int i = 0; i < 2 && contentIndex < _contents.length; i++) {
        contentsToAdd.add(_contents[contentIndex]);
        contentIndex++;
      }
      _mixedItems.add(_MixedItem(type: _MixedItemType.contentGrid, data: contentsToAdd));
    }

    setState(() {});
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    final shouldLoadMore = _hasMorePosts || _hasMoreContent;
    if (!shouldLoadMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await Future.wait([
        if (_hasMorePosts) _loadPostsWithStream(isInitialLoad: false),
        if (_hasMoreContent) _loadContentWithStream(isInitialLoad: false),
      ]);
    } catch (e) {
      print('Error loading more data: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _posts = [];
      _contents = [];
      _mixedItems = [];
      _isLoading = true;
      _isLoadingMore = false;
      _hasMorePosts = true;
      _hasMoreContent = true;
      _lastPostDocument = null;
      _lastContentDocument = null;
      _totalPostsCount = 0;
      _totalContentCount = 0;
    });

    await _loadInitialData();
  }

  void _navigateToDetails(dynamic item, _MixedItemType type) {
    _authProvider.checkAppVersionAndProceed(context, () {
      if (type == _MixedItemType.post) {
        print('Navigate to post details: ${item.id}');
      } else {
        if (item.isSeries) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SeriesEpisodesScreen(series: item)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ContentDetailScreen(content: item)),
          );
        }
      }
    });
  }

  Widget _buildPostItem(Post post, double width) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: HomePostUsersWidget(
        post: post,
        color: _color,
        height: MediaQuery.of(context).size.height * 0.6,
        width: width,
        isDegrade: true,
      ),
    );
  }

  Widget _buildContentGrid(List<ContentPaie> contents, double width) {
    return Container(
        margin: EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Text(
                "Vidéos virales 🔥",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: contents.length,
              itemBuilder: (context, index) {
                final content = contents[index];
                return _buildContentItem(content, width / 2 - 12);
              },
            ),
          ],)
    );
  }

  Widget _buildContentItem(ContentPaie content, double itemWidth) {
    return GestureDetector(
      onTap: () => _navigateToDetails(content, _MixedItemType.content),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: Colors.grey[800],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: content.thumbnailUrl != null && content.thumbnailUrl!.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: content.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: Center(child: CircularProgressIndicator(color: Colors.green)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.error, color: Colors.white),
                      ),
                    )
                        : Center(child: Icon(Icons.videocam, color: Colors.grey[600], size: 30)),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill, color: Colors.red, size: 40),
                        SizedBox(height: 4),
                        Text(
                          "Voir",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      children: [
                        if (!content.isFree)
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${content.price} F',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        SizedBox(width: 4),
                        if (content.isSeries)
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(Icons.playlist_play, color: Colors.blue, size: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        content.isSeries ? 'Série' : 'Film',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      if (content.views != null && content.views! > 0)
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              content.views!.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
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
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    _changeColor();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        title: Text(
          'Découvrir',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerEffect()
          : _hasError
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 50),
            SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: Text('Réessayer'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final item = _mixedItems[index];
                  if (item.type == _MixedItemType.post) {
                    return GestureDetector(
                      onTap: () => _navigateToDetails(item.data, _MixedItemType.post),
                      child: _buildPostItem(item.data, width),
                    );
                  } else if (item.type == _MixedItemType.contentGrid) {
                    return _buildContentGrid(
                      (item.data as List<dynamic>).map((e) => e as ContentPaie).toList(),
                      width,
                    );
                  }
                  return SizedBox.shrink();
                },
                childCount: _mixedItems.length,
              ),
            ),
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  ),
                ),
              ),
            if (!_hasMorePosts && !_hasMoreContent && _mixedItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Vous avez vu tous les contenus',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

enum _MixedItemType { post, content, contentGrid }

class _MixedItem {
  final _MixedItemType type;
  final dynamic data;

  _MixedItem({required this.type, required this.data});
}