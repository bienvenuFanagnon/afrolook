import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/user_interests.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/feed/feed_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feed/sections/feed_ad_widgets.dart';
import '../../widgets/user_badge_widget.dart';
import '../postDetailsVideo.dart';
import '../postDetails.dart';

/// Page dédiée à une catégorie d'intérêt — affiche les posts de cette
/// catégorie avec pagination + pubs intercalées toutes les 5 cartes.
class CategoryFeedPage extends StatefulWidget {
  final String categoryId;
  final String categoryLabel;
  final String categoryEmoji;

  const CategoryFeedPage({
    super.key,
    required this.categoryId,
    required this.categoryLabel,
    required this.categoryEmoji,
  });

  @override
  State<CategoryFeedPage> createState() => _CategoryFeedPageState();
}

class _CategoryFeedPageState extends State<CategoryFeedPage> {
  final _scrollController = ScrollController();
  final _repo = FeedRepository();
  final _posts = <Post>[];
  final _loadedIds = <String>{};
  // false au départ pour que _load() puisse s'exécuter dès le premier appel
  bool _isLoading = false;
  bool _hasMore = true;

  static const _pageSize = 10;
  // Une pub toutes les 5 cartes
  static const _adEvery = 5;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!_hasMore || _isLoading) return;
    setState(() => _isLoading = true);
    final auth = context.read<UserAuthProvider>();
    final countryCode =
        auth.loginUserData.countryData?['countryCode'] as String? ?? '';
    final fetched = await _repo.fetchInterestPosts(
      [widget.categoryId],
      _loadedIds,
      countryCode: countryCode,
      limit: _pageSize,
    );
    if (!mounted) return;
    for (final p in fetched) {
      if (p.id != null) _loadedIds.add(p.id!);
    }
    setState(() {
      _posts.addAll(fetched);
      _isLoading = false;
      _hasMore = fetched.length >= _pageSize;
    });
  }

  /// Construit la liste d'items : posts + slots pub intercalés toutes les _adEvery cartes.
  List<Object> _buildItems() {
    final items = <Object>[];
    for (int i = 0; i < _posts.length; i++) {
      items.add(_posts[i]);
      if ((i + 1) % _adEvery == 0) {
        items.add('ad_${i ~/ _adEvery}');
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final catColor = UserInterests.categoryColor(
      widget.categoryId,
      isDark: colors.isDark,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(widget.categoryEmoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              widget.categoryLabel,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: catColor.withOpacity(0.6)),
        ),
      ),
      body: _posts.isEmpty && _isLoading
          ? _buildShimmer(colors)
          : _posts.isEmpty
              ? Center(
                  child: Text(
                    'Aucun post pour le moment',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                )
              : _buildList(colors, catColor),
    );
  }

  Widget _buildList(AppColors colors, Color catColor) {
    final items = _buildItems();
    final total = items.length + (_hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: total,
      itemBuilder: (_, i) {
        // Indicateur de chargement en bas
        if (i == items.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = items[i];
        if (item is String) {
          // Slot pub
          return FeedUnifiedAdSlot(adKey: item);
        }
        return _CategoryPostCard(
          post: item as Post,
          catColor: catColor,
          colors: colors,
        );
      },
    );
  }

  Widget _buildShimmer(AppColors colors) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        height: 240,
        decoration: BoxDecoration(
          color: colors.shimmerBase,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _CategoryPostCard extends StatelessWidget {
  final Post post;
  final Color catColor;
  final AppColors colors;

  const _CategoryPostCard({
    required this.post,
    required this.catColor,
    required this.colors,
  });

  void _open(BuildContext context) {
    final route = post.dataType == PostDataType.VIDEO.name
        ? MaterialPageRoute(builder: (_) => VideoYoutubePageDetails(initialPost: post))
        : MaterialPageRoute(builder: (_) => DetailsPost(post: post));
    Navigator.push(context, route);
  }

  String _thumbUrl() {
    final dt = post.dataType ?? '';
    if (dt == PostDataType.IMAGE.name) {
      if (post.images?.isNotEmpty == true) return post.images!.first;
    }
    return post.thumbnail ?? '';
  }

  // Résolution pseudo/avatar depuis snapshot dénormalisé ou fallback post.user
  bool get _isCanalPost => post.canal_id != null && post.canal_id!.isNotEmpty;

  String get _displayName {
    if (_isCanalPost) {
      final titre = post.canalSnapshot?['titre'] as String?;
      if (titre != null && titre.isNotEmpty) return '#$titre';
      return post.canal_id ?? '';
    }
    final pseudo = post.creatorSnapshot?['pseudo'] as String?;
    if (pseudo != null && pseudo.isNotEmpty) return '@$pseudo';
    final fallback = post.user?.pseudo ?? '';
    return fallback.isNotEmpty ? '@$fallback' : '';
  }

  String get _avatarUrl {
    if (_isCanalPost) {
      return (post.canalSnapshot?['urlImage'] as String?) ??
          post.user?.imageUrl ?? '';
    }
    return (post.creatorSnapshot?['imageUrl'] as String?) ??
        post.user?.imageUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbUrl();
    final desc = post.description ?? '';
    final isVideo = post.dataType == PostDataType.VIDEO.name;
    final isAudio = post.dataType == PostDataType.AUDIO.name;
    final avatar = _avatarUrl;
    final name = _displayName;

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Miniature grande ──────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(isAudio: isAudio),
                      )
                    else
                      _placeholder(isAudio: isAudio),
                    // Overlay play/audio
                    if (isVideo || isAudio)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    if (isVideo)
                      const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 48),
                      ),
                    if (isAudio)
                      Center(
                        child: Icon(Icons.music_note_rounded,
                            color: Colors.white.withOpacity(0.85), size: 44),
                      ),
                    // Badge type en haut à droite
                    Positioned(
                      top: 8,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isVideo
                              ? Icons.videocam_rounded
                              : isAudio
                                  ? Icons.music_note_rounded
                                  : Icons.image_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Info ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auteur (avatar + pseudo/canal + badge)
                  Row(
                    children: [
                      if (avatar.isNotEmpty)
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors.shimmerBase,
                          backgroundImage: CachedNetworkImageProvider(avatar),
                        )
                      else
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors.shimmerBase,
                          child: Icon(
                            _isCanalPost
                                ? Icons.tv_rounded
                                : Icons.person_rounded,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      // Badge vérification — disponible si post.user chargé
                      if (post.user != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: UserBadgeWidget(
                            user: post.user,
                            size: 13,
                            withBackground: false,
                          ),
                        ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({bool isAudio = false}) {
    return Container(
      color: colors.shimmerBase,
      child: Center(
        child: Icon(
          isAudio ? Icons.music_note_rounded : Icons.image_outlined,
          color: catColor.withOpacity(0.4),
          size: 40,
        ),
      ),
    );
  }
}
