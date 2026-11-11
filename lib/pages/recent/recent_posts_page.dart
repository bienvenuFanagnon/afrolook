import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../services/api/api_gateway.dart';
import '../../services/api/recent_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feed/sections/feed_ad_widgets.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';

/// Page « 🕒 Récents » : tout ce qui vient d'être publié, toutes catégories confondues, du plus récent au plus ancien (30 jours). Même liste de cartes que « Pour toi ».
/// Un post qui reste à l'écran est compté comme vu.
class RecentPostsPage extends StatefulWidget {
  const RecentPostsPage({super.key});

  @override
  State<RecentPostsPage> createState() => _RecentPostsPageState();
}

class _RecentPostsPageState extends State<RecentPostsPage> {
  final _scroll = ScrollController();
  final _posts = <Post>[];
  String? _next;
  bool _loading = false;
  bool _failed = false;
  bool _loaded = false;
  int _token = 0;

  static const _adEvery = 6;

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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: colors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text(context.tr('🕒 Récents'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
      ),
      body: _body(colors, size),
    );
  }

  Widget _body(AppColors colors, Size size) {
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
    // pubs intercalées toutes les 6 cartes
    final rows = <Object>[];
    for (var i = 0; i < _posts.length; i++) {
      rows.add(_posts[i]);
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
          return VisibilityDetector(
            key: ValueKey('recent_vis_${post.id}'),
            onVisibilityChanged: (info) {
              // un post resté à l'écran est « vu » : le serveur le compte une seule fois
              if (info.visibleFraction >= 0.6 && post.id != null) ApiGateway.instance.markViewed(post.id!);
            },
            child: HomePostUsersWidget(
              key: ValueKey('recent-${post.id}'),
              post: post,
              index: i,
              height: size.height * 0.6,
              width: size.width,
              isDegrade: true,
              suppressInlineAd: true,
            ),
          );
        },
      ),
    );
  }
}
