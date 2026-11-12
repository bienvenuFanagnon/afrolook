import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../services/api/api_gateway.dart';
import '../../services/api/recent_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feed/feed_post_card.dart';
import '../../widgets/feed/sections/feed_ad_widgets.dart';

/// Onglet « 🕒 Récents » de l'écran d'accueil : tout ce qui vient d'être publié, toutes catégories confondues, du plus récent au plus ancien (30 jours).
/// C'est un onglet de l'écran d'accueil (la barre d'onglets reste là) : il ne s'ouvre pas dans une autre page. MÊME carte de post que « Pour toi » ([FeedPostCard], partagée avec
/// l'accueil) : une vidéo se lit toute seule à l'écran, les vidéos voisines sont préchargées, un appui ouvre la page de lecture complète.
/// Un post qui reste à l'écran (plus de la moitié, pendant une demi-seconde, comme sur l'accueil) est compté comme vu. L'ORDRE est décidé par l'API (jamais plus de 2 posts de suite de la même personne) : l'application l'affiche tel quel.
class RecentPostsView extends StatefulWidget {
  const RecentPostsView({super.key});

  @override
  State<RecentPostsView> createState() => _RecentPostsViewState();
}

class _RecentPostsViewState extends State<RecentPostsView> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _posts = <Post>[];
  String? _next;
  bool _loading = false;
  bool _failed = false;
  bool _loaded = false;
  int _token = 0;
  final _viewTimers = <String, Timer>{};

  static const _adEvery = 6;

  @override
  bool get wantKeepAlive => true;   // changer d'onglet ne vide pas la liste

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _load();
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    for (final t in _viewTimers.values) {
      t.cancel();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && _loaded && _next == null)) return;
    final token = reset ? ++_token : _token;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _posts.clear();
        _next = null;
        _loaded = false;
      }
    });
    try {
      final page = await RecentApi.page(cursor: reset ? null : _next);
      if (!mounted || token != _token) return;
      final known = _posts.map((e) => e.id).toSet();
      setState(() {
        _posts.addAll(page.posts.where((e) => !known.contains(e.id)));
        _next = page.next;
        _loaded = true;
      });
    } catch (_) {
      if (mounted && token == _token) setState(() => _failed = true);
    } finally {
      if (mounted && token == _token) setState(() => _loading = false);
    }
  }

  void _markViewed(Post post) {
    if (post.id != null) ApiGateway.instance.markViewed(post.id!);
  }

  /// Même règle que l'accueil : un post visible à plus de 50 % pendant une demi-seconde est « vu » (le serveur le compte une seule fois).
  void _onVisible(Post post, double fraction) {
    final id = post.id;
    if (id == null) return;
    _viewTimers[id]?.cancel();
    if (fraction > 0.5) {
      _viewTimers[id] = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _markViewed(post);
      });
    } else {
      _viewTimers.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    if (_posts.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_posts.isEmpty && _failed) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr('Impossible de charger les posts récents pour le moment.'), style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => _load(reset: true), child: Text(context.tr('Réessayer'))),
        ]),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(context.tr('Pas encore de post récent. Reviens bientôt !'), textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        ),
      );
    }
    // pubs intercalées toutes les 6 cartes ; `postIndex` = rang du post parmi les POSTS (sans les pubs), comme sur l'accueil (préchargement des vidéos voisines)
    final rows = <Object>[];
    final postIndex = <String, int>{};
    for (var i = 0; i < _posts.length; i++) {
      rows.add(_posts[i]);
      if (_posts[i].id != null) postIndex[_posts[i].id!] = i;
      if ((i + 1) % _adEvery == 0) rows.add('recent_ad_${i ~/ _adEvery}');
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        itemCount: rows.length + (_loading || _next != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == rows.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          final row = rows[i];
          if (row is String) return FeedUnifiedAdSlot(adKey: row);
          final post = row as Post;
          final rank = postIndex[post.id] ?? i;
          final card = FeedPostCard(
            post: post,
            index: rank,
            width: size.width,
            height: size.height,
            onNeighborhoodPreload: (n) => FeedPostCard.preloadNeighborhood(_posts, n),
          );
          return RepaintBoundary(
            child: VisibilityDetector(
              key: ValueKey('recent_vis_${post.id}'),
              onVisibilityChanged: (info) => _onVisible(post, info.visibleFraction),
              // comme sur l'accueil : la carte vidéo gère son propre appui (page de lecture) ; les autres cartes comptent la vue au toucher
              child: FeedPostCard.isVideoPost(post) ? card : GestureDetector(onTap: () => _markViewed(post), child: card),
            ),
          );
        },
      ),
    );
  }
}
