import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/user_interests.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/feed/feed_repository.dart';
import '../../theme/app_colors.dart';
import '../postDetailsVideo.dart';
import '../postDetails.dart';

/// Page dédiée à une catégorie d'intérêt — affiche les posts de cette
/// catégorie avec pagination, en suivant le même algorithme Tier 2
/// (postInterests arrayContainsAny + orderBy created_at).
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
  bool _isLoading = true;
  bool _hasMore = true;

  static const _pageSize = 10;

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
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: _posts.length + (_hasMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _posts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _CategoryPostCard(post: _posts[i], catColor: catColor);
                  },
                ),
    );
  }

  Widget _buildShimmer(AppColors colors) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        height: 90,
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
  const _CategoryPostCard({required this.post, required this.catColor});

  void _open(BuildContext context) {
    final route = post.dataType == PostDataType.VIDEO.name
        ? MaterialPageRoute(builder: (_) => VideoYoutubePageDetails(initialPost: post))
        : MaterialPageRoute(builder: (_) => DetailsPost(post: post));
    Navigator.push(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final thumb = post.thumbnail ?? post.url_media ?? '';
    final desc = post.description ?? '';
    final pseudo = post.user?.pseudo ?? '';
    final avatar = post.user?.imageUrl ?? '';

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            // Miniature
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: thumb.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: colors.shimmerBase),
                      )
                    : Container(color: colors.shimmerBase),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (avatar.isNotEmpty)
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: CachedNetworkImageProvider(avatar),
                          ),
                        if (avatar.isNotEmpty) const SizedBox(width: 5),
                        Text(
                          pseudo,
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Indicateur type
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                post.dataType == PostDataType.VIDEO.name
                    ? Icons.play_circle_outline
                    : Icons.image_outlined,
                size: 18,
                color: catColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
