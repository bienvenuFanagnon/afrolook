import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import '../challenge/postChallengeWidget.dart';
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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  final Map<String, Timer> _visibilityTimers = {};
  final Set<String> _sessionViewedIds = {};

  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int? _lastTimestampUs; // curseur pagination (microsecondes)

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

  /// Découpe une liste en chunks de taille [size].
  List<List<T>> _chunks<T>(List<T> list, int size) {
    final result = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      result.add(list.sublist(i, (i + size).clamp(0, list.length)));
    }
    return result;
  }

  /// Exécute les queries créateurs ET canaux en parallèle et fusionne les résultats.
  Future<List<Post>> _fetchFromFirestore({int? beforeUs}) async {
    final creatorIds = widget.unseenCreatorIds;
    final canalIds = widget.followedCanalIds;

    if (creatorIds.isEmpty && canalIds.isEmpty) return [];

    final allFutures = <Future<List<Post>>>[];

    // ── Requête A : posts des créateurs (par user_id) ────────────────────────
    for (final chunk in _chunks(creatorIds, 30)) {
      allFutures.add(_queryPosts(
        field: 'user_id',
        ids: chunk,
        beforeUs: beforeUs,
      ));
    }

    // ── Requête B : posts des canaux (par canal_id) ──────────────────────────
    for (final chunk in _chunks(canalIds, 30)) {
      allFutures.add(_queryPosts(
        field: 'canal_id',
        ids: chunk,
        beforeUs: beforeUs,
      ));
    }

    final results = await Future.wait(allFutures);
    final seen = <String>{};
    final merged = results
        .expand((e) => e)
        .where((p) => p.id != null && seen.add(p.id!)) // déduplique
        .toList()
      ..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

    return merged.take(_pageSize).toList();
  }

  Future<List<Post>> _queryPosts({
    required String field,
    required List<String> ids,
    int? beforeUs,
  }) async {
    if (ids.isEmpty) return [];
    try {
      Query q = _db
          .collection('Posts')
          .where(field, whereIn: ids)
          .orderBy('created_at', descending: true);

      if (beforeUs != null) {
        q = q.where('created_at', isLessThan: beforeUs);
      }
      q = q.limit(_pageSize * 2);

      final snap = await q.get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        data['id'] = d.id;
        return Post.fromJson(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadPage() async {
    setState(() => _loading = true);
    try {
      final posts = await _fetchFromFirestore();
      if (mounted) {
        setState(() {
          _posts = posts;
          _hasMore = posts.length == _pageSize;
          if (posts.isNotEmpty) {
            // createdAt est en ms dans le modèle → convertir en µs pour Firestore
            _lastTimestampUs = (posts.last.createdAt ?? 0) * 1000;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || !_hasMore || _lastTimestampUs == null) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _fetchFromFirestore(beforeUs: _lastTimestampUs);
      if (mounted) {
        setState(() {
          _posts.addAll(more);
          _hasMore = more.length == _pageSize;
          if (more.isNotEmpty) {
            _lastTimestampUs = (more.last.createdAt ?? 0) * 1000;
          }
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

    try {
      final batch = _db.batch();
      batch.update(_db.collection('Posts').doc(postId), {
        'users_vue_id': FieldValue.arrayUnion([widget.currentUserId]),
      });
      batch.update(
          _db.collection('Users').doc(widget.currentUserId), {
        'viewedPostIds': FieldValue.arrayUnion([postId]),
      });
      await batch.commit();
    } catch (_) {}
  }

  // ── Widget post (tous types) ──────────────────────────────────────────────────

  Widget _buildPostWidget(Post post, double width, double height, int index) {
    return VisibilityDetector(
      key: Key('unseen-feed-${post.id}'),
      onVisibilityChanged: (info) => _handleVisibilityChanged(post, info),
      child: post.type == PostType.PRONOSTIC.name
          ? const SizedBox.shrink()
          : post.type == PostType.CHALLENGEPARTICIPATION.name
              ? LookChallengePostWidget(
                  post: post, height: height, width: width)
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
