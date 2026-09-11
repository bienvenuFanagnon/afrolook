import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/feed/discovery_posts_cache.dart';
import '../../theme/app_colors.dart';
import '../postDetailsVideo.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import '../userPosts/youTube_video_card.dart';

/// Page "Explorer les posts à découvrir".
/// [pageType] : null = feed normal, 'SPORT' = feed sport.
class DiscoveryFeedPage extends StatefulWidget {
  final String? pageType;
  const DiscoveryFeedPage({Key? key, this.pageType}) : super(key: key);

  @override
  State<DiscoveryFeedPage> createState() => _DiscoveryFeedPageState();
}

class _DiscoveryFeedPageState extends State<DiscoveryFeedPage> {
  List<Post> _posts = [];
  bool _loading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 12;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final userId = auth.loginUserData.id ?? '';

    // 1) Vérifier le cache local
    await DiscoveryPostsCache.load(userId);
    final cached = DiscoveryPostsCache.instance.take(_pageSize);

    if (widget.pageType == 'SPORT') {
      // Pour le sport : ignorer le cache et charger directement Firestore
      await _fetchFromFirestore(reset: true);
    } else if (cached.isNotEmpty) {
      setState(() {
        _posts = cached;
        _loading = false;
      });
      // Charger plus en arrière-plan
      _fetchFromFirestore(reset: false);
    } else {
      await _fetchFromFirestore(reset: true);
    }
  }

  Future<void> _fetchFromFirestore({bool reset = false}) async {
    if (!_hasMore && !reset) return;
    try {
      Query query = FirebaseFirestore.instance
          .collection('Posts')
          .where('status', isEqualTo: 'active');

      if (widget.pageType != null) {
        query = query.where('pageType', isEqualTo: widget.pageType);
      }

      query = query.orderBy('postScore', descending: true).limit(_pageSize);

      if (!reset && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.get();
      final fetched = snap.docs.map((d) {
        try {
          return Post.fromJson(d.data() as Map<String, dynamic>)..id = d.id;
        } catch (_) {
          return null;
        }
      }).whereType<Post>().toList();

      if (!mounted) return;
      setState(() {
        if (reset) {
          _posts = fetched;
        } else {
          final existingIds = _posts.map((p) => p.id).toSet();
          _posts.addAll(fetched.where((p) => !existingIds.contains(p.id)));
        }
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        _hasMore = fetched.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = widget.pageType == 'SPORT' ? 'Explorer · Sport' : 'Explorer les posts';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explore_outlined, size: 48, color: colors.textSecondary),
                      const SizedBox(height: 12),
                      Text('Aucun post à explorer', style: TextStyle(color: colors.textSecondary, fontSize: 15)),
                      const SizedBox(height: 8),
                      Text('Revenez plus tard !', style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notif) {
                    if (notif is ScrollEndNotification && notif.metrics.extentAfter < 400 && _hasMore) {
                      _fetchFromFirestore();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final post = _posts[i];
                      final w = MediaQuery.of(context).size.width;
                      final h = MediaQuery.of(context).size.height;
                      if (post.type == PostType.POST.name && post.dataType == PostDataType.VIDEO.name) {
                        return YouTubeVideoCard(
                          key: ValueKey('disc_yt_${post.id}'),
                          post: post,
                          index: i,
                          suppressInlineAd: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoYoutubePageDetails(initialPost: post, feedTier: 'tier2'),
                            ),
                          ),
                        );
                      }
                      return HomePostUsersWidget(
                        key: ValueKey('disc_hw_${post.id}'),
                        index: i,
                        post: post,
                        color: Colors.transparent,
                        height: h * 0.5,
                        width: w,
                        isDegrade: false,
                        suppressInlineAd: true,
                        feedTier: 'tier2',
                      );
                    },
                  ),
                ),
    );
  }
}
