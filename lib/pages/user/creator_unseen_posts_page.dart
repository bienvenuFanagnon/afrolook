import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/model_data.dart';
import '../../services/active_creators_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_badge_widget.dart';
import '../challenge/postChallengeWidget.dart';
import '../component/showUserDetails.dart';
import '../postDetailsVideo.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import '../userPosts/youTube_video_card.dart';

class CreatorUnseenPostsPage extends StatefulWidget {
  final UserData creator;
  final int unseenCount;
  final List<String> viewedPostIds;
  final String currentUserId;
  /// Timestamp ms de création du compte. Posts antérieurs exclus (0 = pas de filtre).
  final int userCreatedAtMs;

  const CreatorUnseenPostsPage({
    super.key,
    required this.creator,
    required this.unseenCount,
    required this.viewedPostIds,
    required this.currentUserId,
    this.userCreatedAtMs = 0,
  });

  @override
  State<CreatorUnseenPostsPage> createState() => _CreatorUnseenPostsPageState();
}

class _CreatorUnseenPostsPageState extends State<CreatorUnseenPostsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _service = ActiveCreatorsService();
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  final Map<String, Timer> _visibilityTimers = {};
  final Set<String> _sessionViewedIds = {};

  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  static const _pageSize = 10;

  // Compteur local mis à jour au fur et à mesure de la navigation
  late int _localUnseenCount;
  // Posts dont le compteur a déjà été décrémenté cette session (anti double-décrément)
  final Set<String> _decrementedInSession = {};

  static const List<Color> _postColors = [
    Color(0xFF1A237E),
    Color(0xFF880E4F),
    Color(0xFF1B5E20),
    Color(0xFF4A148C),
    Color(0xFF006064),
    Color(0xFFBF360C),
  ];

  Color _getRandomColor() =>
      _postColors[_random.nextInt(_postColors.length)];

  bool get _isSubscribed =>
      widget.creator.userAbonnesIds?.contains(widget.currentUserId) ?? false;

  @override
  void initState() {
    super.initState();
    _localUnseenCount = widget.unseenCount;
    _loadPosts();
    _scrollController.addListener(_onScroll);
    // NE PAS appeler resetCreatorCounter() ici — le compteur doit être
    // décrémenté post par post au fur et à mesure du scroll, pas dès l'ouverture.
  }

  @override
  void dispose() {
    for (final t in _visibilityTimers.values) {
      t.cancel();
    }
    _visibilityTimers.clear();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  // created_at Firestore = microsecondes ; UserData.createdAt = millisecondes après parsing
  int get _sinceUs =>
      widget.userCreatedAtMs > 0 ? widget.userCreatedAtMs * 1000 : 0;

  Query<Map<String, dynamic>> get _baseQuery {
    var q = _db
        .collection('Posts')
        .where('user_id', isEqualTo: widget.creator.id)
        .orderBy('created_at', descending: true);
    if (_sinceUs > 0) {
      q = q.where('created_at', isGreaterThanOrEqualTo: _sinceUs);
    }
    return q;
  }

  List<Post> _filterUnseen(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final viewedSet = Set<String>.from(widget.viewedPostIds);
    return docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return Post.fromJson(data);
    }).where((p) => p.id != null && !viewedSet.contains(p.id)).toList();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      // On charge plus de docs par page pour compenser le filtre côté client
      final snap = await _baseQuery.limit(_pageSize * 3).get();

      if (mounted) {
        final unseen = _filterUnseen(snap.docs);
        setState(() {
          _posts = unseen;
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
          _hasMore = snap.docs.length == _pageSize * 3;
          // Recalcul du compteur réel (posts vraiment non vus)
          _localUnseenCount = unseen.length;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMorePosts() async {
    if (_lastDoc == null || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await _baseQuery
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize * 3)
          .get();

      if (mounted) {
        final newPosts = _filterUnseen(snap.docs);
        setState(() {
          _posts.addAll(newPosts);
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
          _hasMore = snap.docs.length == _pageSize * 3;
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
      _visibilityTimers[postId] = Timer(const Duration(milliseconds: 500), () {
        if (mounted && info.visibleFraction > 0.5) {
          _recordView(post);
        }
      });
    } else {
      _visibilityTimers.remove(postId);
    }
  }

  Future<void> _recordView(Post post) async {
    final postId = post.id;
    if (postId == null || widget.currentUserId.isEmpty) return;
    if (_sessionViewedIds.contains(postId)) return;

    // Ce post était-il non vu ? (pas dans viewedPostIds ET pas déjà décrémenté)
    final wasUnseen = !widget.viewedPostIds.contains(postId) &&
        !_decrementedInSession.contains(postId);

    // Mise à jour immédiate de l'UI (badge "Non vu" + compteur header)
    if (mounted) {
      setState(() {
        _sessionViewedIds.add(postId);
        if (wasUnseen) {
          _decrementedInSession.add(postId);
          if (_localUnseenCount > 0) _localUnseenCount--;
        }
      });
    }

    try {
      // Enregistrer la vue sur le post et dans les vues utilisateur
      final batch = _db.batch();
      batch.update(_db.collection('Posts').doc(postId), {
        'users_vue_id': FieldValue.arrayUnion([widget.currentUserId]),
      });
      batch.update(_db.collection('Users').doc(widget.currentUserId), {
        'viewedPostIds': FieldValue.arrayUnion([postId]),
      });
      await batch.commit();

      // Décrémenter le compteur créateur uniquement pour les posts non vus
      if (wasUnseen) {
        final creatorId = widget.creator.id ?? '';
        if (creatorId.isNotEmpty) {
          if (_localUnseenCount <= 0) {
            // Tous les posts non vus ont été scrollés → reset complet
            _service.resetCreatorCounter(widget.currentUserId, creatorId);
          } else {
            // Encore des posts non vus → décrémenter de 1
            _db.collection('Users').doc(widget.currentUserId).update({
              'newPostsByCreator.$creatorId': FieldValue.increment(-1),
            });
          }
        }
      }
    } catch (_) {}
  }

  // ── Tout marquer comme vu ─────────────────────────────────────────────────────

  bool _isMarkingAll = false;

  Future<void> _markAllAsSeen() async {
    if (_isMarkingAll || widget.currentUserId.isEmpty) return;
    setState(() => _isMarkingAll = true);

    try {
      final alreadyViewed = Set<String>.from(widget.viewedPostIds)
        ..addAll(_sessionViewedIds);

      final newIds = await _service.markAllPostsSeenForCreator(
        userId: widget.currentUserId,
        creatorId: widget.creator.id ?? '',
        userCreatedAtMs: widget.userCreatedAtMs,
        alreadyViewedIds: alreadyViewed,
      );

      if (!mounted) return;

      // Mettre à jour la liste locale des posts vus
      for (final id in newIds) {
        _sessionViewedIds.add(id);
      }

      setState(() {
        _posts.clear();
        _hasMore = false;
        _localUnseenCount = 0;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  // ── Builds ───────────────────────────────────────────────────────────────────

  void _openCreatorProfile() {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    showUserDetailsModalDialog(widget.creator, w, h, context);
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _buildPostWidget(Post post, double width, double height, int index) {
    return VisibilityDetector(
      key: Key('creator-post-${post.id}'),
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    final creator = widget.creator;
    final pseudo = '@${creator.pseudo?.replaceAll('@', '') ?? 'créateur'}';
    final followersCount =
        creator.userAbonnesIds?.length ?? creator.abonnes ?? 0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _openCreatorProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colors.surfaceVariant,
                    backgroundImage: creator.imageUrl != null &&
                            creator.imageUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(creator.imageUrl!)
                        : null,
                    child: creator.imageUrl == null ||
                            creator.imageUrl!.isEmpty
                        ? Icon(Icons.person,
                            color: colors.textSecondary, size: 20)
                        : null,
                  ),
                  if (_localUnseenCount > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: colors.surface, width: 1.5),
                        ),
                        child: Text(
                          '$_localUnseenCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pseudo,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        UserBadgeWidget(
                            user: creator,
                            size: 12,
                            withBackground: false),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.group,
                            size: 10, color: colors.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          _formatCount(followersCount),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        if (_localUnseenCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '$_localUnseenCount non vu${_localUnseenCount > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_localUnseenCount > 0)
            _isMarkingAll
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(colors.primary),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.done_all_rounded,
                        color: colors.primary, size: 22),
                    tooltip: 'Tout marquer comme vu',
                    onPressed: _markAllAsSeen,
                  ),
          IconButton(
            icon: Icon(Icons.person_outline_rounded,
                color: colors.textSecondary, size: 22),
            tooltip: 'Voir le profil',
            onPressed: _openCreatorProfile,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: colors.primary))
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 10),
                      Text(
                        'Tu es à jour !',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aucun post non vu de ce créateur',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _posts.length +
                      (_loadingMore ? 1 : 0) +
                      1, // +1 pour le banner abonnement en tête
                  itemBuilder: (ctx, i) {
                    // ── Bannière abonnement (index 0 si non abonné) ──────────
                    if (i == 0 && !_isSubscribed) {
                      return _SubscribeBanner(
                        creator: creator,
                        colors: colors,
                        onTap: _openCreatorProfile,
                      );
                    }
                    // Ajuster l'index réel selon la présence du banner
                    final postIndex = _isSubscribed ? i : i - 1;

                    if (postIndex == _posts.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }

                    // Si abonné pas de banner → index 0 = post 0
                    if (_isSubscribed && i >= _posts.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }

                    final actualPostIndex =
                        _isSubscribed ? i : i - 1;
                    if (actualPostIndex < 0 ||
                        actualPostIndex >= _posts.length) {
                      return const SizedBox.shrink();
                    }

                    final post = _posts[actualPostIndex];
                    // Tous les posts chargés sont non-vus au départ.
                    // Le badge disparaît dès que le post est scrollé dans cette session.
                    final viewedThisSession =
                        _sessionViewedIds.contains(post.id ?? '');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!viewedThisSession)
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
                        _buildPostWidget(
                          post,
                          size.width,
                          size.height,
                          actualPostIndex,
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

// ── Bannière "S'abonner" ──────────────────────────────────────────────────────

class _SubscribeBanner extends StatelessWidget {
  final UserData creator;
  final AppColors colors;
  final VoidCallback onTap;

  const _SubscribeBanner({
    required this.creator,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded,
                color: colors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Abonnez-vous à @${creator.pseudo?.replaceAll('@', '') ?? 'ce créateur'} pour ne rien manquer",
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "S'abonner",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
