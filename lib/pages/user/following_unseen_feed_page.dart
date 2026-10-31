import 'package:afrotok/services/read_meter.dart';
import 'dart:async';
import 'dart:math';

import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import '../postDetailsVideo.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import '../userPosts/youTube_video_card.dart';

/// Feed paginé de tous les posts récents des followings (créateurs + canaux).
///
/// Architecture :
///   Requête A – Posts par créateur  : where('user_id', whereIn: chunk)
///   Requête B – Posts par canal     : where('canal_id', whereIn: chunk)
///   Les deux s'exécutent en parallèle, résultats fusionnés et triés par date.
///   Cursor basé sur created_at (microsecondes) pour la pagination.
///   Chunks de 30 max (limite Firestore whereIn).
class FollowingUnseenFeedPage extends StatefulWidget {
  /// IDs des créateurs qui ont des posts non vus (clés de newPostsByCreator).
  final List<String> unseenCreatorIds;

  /// IDs des canaux que l'utilisateur suit (chargés depuis Canaux collection au démarrage).
  final List<String> followedCanalIds;

  /// Total de posts non vus à afficher dans le titre (optionnel).
  final int totalUnseen;

  final String currentUserId;
  final List<String> viewedPostIds;

  const FollowingUnseenFeedPage({
    super.key,
    required this.unseenCreatorIds,
    required this.currentUserId,
    required this.viewedPostIds,
    this.followedCanalIds = const [],
    this.totalUnseen = 0,
  });

  @override
  State<FollowingUnseenFeedPage> createState() =>
      _FollowingUnseenFeedPageState();
}

class _FollowingUnseenFeedPageState extends State<FollowingUnseenFeedPage> {
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  final Map<String, Timer> _visibilityTimers = {};
  final Set<String> _sessionViewedIds = {};

  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _cursor; // curseur de l'API

  static const _pageSize = 10;

  static const List<Color> _postColors = [
    Color(0xFF1A237E),
    Color(0xFF880E4F),
    Color(0xFF1B5E20),
    Color(0xFF4A148C),
    Color(0xFF006064),
    Color(0xFFBF360C),
  ];

  Color _getRandomColor() => _postColors[_random.nextInt(_postColors.length)];

  @override
  void initState() {
    super.initState();
    _loadPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    for (final t in _visibilityTimers.values) {
      t.cancel();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_loadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  // ── Chargement ───────────────────────────────────────────────────────────────

  /// Publications NON VUES des comptes suivis (API : GET /v1/feed, niveau 1, curseur).
  Future<List<Post>> _fetchPage() async {
    final r = await ApiGateway.instance.client.get('/feed', query: {'limit': _pageSize, 'tier': 1, if (_cursor != null) 'cursor': _cursor}) as Map;
    _cursor = r['next_cursor'] as String?;
    return ((r['data'] as List?) ?? const []).map((e) => postFromApi(Map<String, dynamic>.from(e as Map))).where((p) => p.id != null).toList();
  }

  Future<void> _loadPage() async {
    setState(() => _loading = true);
    _cursor = null;
    try {
      final posts = await _fetchPage();
      if (mounted) {
        setState(() {
          _posts = posts;
          _hasMore = _cursor != null;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || !_hasMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _fetchPage();
      final known = _posts.map((p) => p.id).toSet();
      if (mounted) {
        setState(() {
          _posts.addAll(more.where((p) => !known.contains(p.id)));
          _hasMore = _cursor != null;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  // ── Tracking de vue ──────────────────────────────────────────────────────────

  void _handleVisibilityChanged(Post post, VisibilityInfo info) {
    final postId = post.id;
    if (postId == null) return;
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.5) {
      _visibilityTimers[postId] =
          Timer(const Duration(milliseconds: 500), () {
        if (mounted) _recordView(post);
      });
    } else {
      _visibilityTimers.remove(postId);
    }
  }

  Future<void> _recordView(Post post) async {
    final postId = post.id;
    if (postId == null || widget.currentUserId.isEmpty) return;
    if (_sessionViewedIds.contains(postId)) return;
    _sessionViewedIds.add(postId);

    await ApiGateway.instance.markViewed(postId); // vue comptée par le serveur
  }

  // ── Widget post (tous types) ──────────────────────────────────────────────────

  Widget _buildPostWidget(Post post, double width, double height, int index) {
    return VisibilityDetector(
      key: Key('unseen-feed-${post.id}'),
      onVisibilityChanged: (info) => _handleVisibilityChanged(post, info),
      child: post.type == PostType.PRONOSTIC.name
          ? const SizedBox.shrink()
          : (post.type == PostType.POST.name &&
                      post.dataType == PostDataType.VIDEO.name)
                  ? YouTubeVideoCard(
                      key: ValueKey('ytcard_${post.id}'),
                      post: post,
                      index: index,
                      onNeighborhoodPreload: (_) {},
                      currentFilterCountry: null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VideoYoutubePageDetails(initialPost: post),
                        ),
                      ),
                    )
                  : HomePostUsersWidget(
                      index: index,
                      post: post,
                      color: _getRandomColor(),
                      height: height * 0.6,
                      width: width,
                      isDegrade: true,
                      currentFilterCountry: null,
                    ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    final total = widget.totalUnseen;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Posts non vus',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (total > 0)
              Text(
                '$total nouveau${total > 1 ? 'x' : ''} de ${widget.unseenCreatorIds.length} créateur${widget.unseenCreatorIds.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : widget.unseenCreatorIds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: colors.textSecondary, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Tout est à jour !',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : _posts.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun post trouvé',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _posts.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _posts.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: colors.primary, strokeWidth: 2),
                            ),
                          );
                        }

                        final post = _posts[i];
                        final isUnseen =
                            !widget.viewedPostIds.contains(post.id ?? '') &&
                                !_sessionViewedIds.contains(post.id ?? '');

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isUnseen)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 0, 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: colors.primary
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Non vu',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            _buildPostWidget(post, size.width, size.height, i),
                          ],
                        );
                      },
                    ),
    );
  }
}
