import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../providers/feed_provider.dart';
import '../../services/feed/feed_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feed/feed_list.dart';

/// Page de feed unifiée — utilise [FeedProvider] + [FeedList].
///
/// Conçue pour les onglets qui n'avaient pas encore d'implémentation
/// (Sport, Vibes, VIP…). Peut évoluer pour remplacer les pages existantes.
class UnifiedFeedPage extends StatefulWidget {
  final FeedType feedType;

  const UnifiedFeedPage({Key? key, required this.feedType}) : super(key: key);

  @override
  State<UnifiedFeedPage> createState() => UnifiedFeedPageState();
}

class UnifiedFeedPageState extends State<UnifiedFeedPage>
    with AutomaticKeepAliveClientMixin {
  late FeedProvider _feedProvider;
  late UserAuthProvider _authProvider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _feedProvider = context.read<FeedProvider>();
      _authProvider = context.read<UserAuthProvider>();
      _feedProvider.loadGlobalContent();
      _loadFeed();
    });
  }

  void _loadFeed() {
    final user = _authProvider.loginUserData;
    _feedProvider.loadFeed(
      widget.feedType,
      userId: user.id ?? '',
      countryCode: user.countryData?['countryCode']?.toUpperCase() ?? '',
      subscriptionPostIds: user.newPostsFromSubscriptions,
    );
  }

  /// Exposé pour que homeScreen puisse déclencher un refresh via GlobalKey.
  Future<void> refreshFeed() async {
    final user = _authProvider.loginUserData;
    await _feedProvider.refresh(
      widget.feedType,
      userId: user.id ?? '',
      countryCode: user.countryData?['countryCode']?.toUpperCase() ?? '',
      subscriptionPostIds: user.newPostsFromSubscriptions,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    return RefreshIndicator(
      color: colors.primary,
      onRefresh: refreshFeed,
      child: Consumer<FeedProvider>(
        builder: (context, feedProvider, _) {
          final state = feedProvider.stateFor(widget.feedType);

          if (state.isLoading && state.posts.isEmpty) {
            return _buildShimmer(colors);
          }

          if (state.error != null && state.posts.isEmpty) {
            return _buildError(colors, state.error!);
          }

          if (state.posts.isEmpty) {
            return _buildEmpty(colors);
          }

          return FeedList(
            mixedContent: feedProvider.mixedFor(widget.feedType),
            isLoading: state.isLoading,
            hasMore: state.hasMore,
            filterCountry: _authProvider.loginUserData.countryData?['countryCode']?.toUpperCase(),
            onLoadMore: () {
              final user = _authProvider.loginUserData;
              feedProvider.loadMore(
                widget.feedType,
                userId: user.id ?? '',
                countryCode: user.countryData?['countryCode']?.toUpperCase() ?? '',
                subscriptionPostIds: user.newPostsFromSubscriptions,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildShimmer(AppColors colors) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        height: 240,
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildError(AppColors colors, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 48, color: colors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Impossible de charger le feed',
            style: TextStyle(color: colors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadFeed,
            child: Text('Réessayer', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: colors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Aucun contenu pour le moment',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
