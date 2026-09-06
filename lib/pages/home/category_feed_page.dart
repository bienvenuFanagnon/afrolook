import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/user_interests.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/feed/feed_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feed/sections/feed_ad_widgets.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';

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
  bool _isLoading = false;
  bool _hasMore = true;

  static const _pageSize = 10;
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
    final size = MediaQuery.of(context).size;

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
              : _buildList(size),
    );
  }

  Widget _buildList(Size size) {
    final items = _buildItems();
    final total = items.length + (_hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: total,
      itemBuilder: (_, i) {
        if (i == items.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = items[i];
        if (item is String) {
          return FeedUnifiedAdSlot(adKey: item);
        }
        final post = item as Post;
        return HomePostUsersWidget(
          key: ValueKey('cat-${post.id}'),
          post: post,
          index: i,
          height: size.height * 0.6,
          width: size.width,
          isDegrade: true,
          suppressInlineAd: true,
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
