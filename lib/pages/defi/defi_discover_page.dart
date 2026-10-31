import 'package:flutter/material.dart';
import '../../models/model_data.dart';
import '../../services/api/defis_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feed/post_renderer.dart';

/// Découverte des DÉFIS (API) : du plus récent au plus ancien, par pages. Aucun repli sur Firebase : en cas d'erreur, message clair + « Réessayer ».
class DefiDiscoverPage extends StatefulWidget {
  const DefiDiscoverPage({super.key});

  @override
  State<DefiDiscoverPage> createState() => _DefiDiscoverPageState();
}

class _DefiDiscoverPageState extends State<DefiDiscoverPage> {
  final List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _next;
  String? _error;
  static const int _pageSize = 15;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300 && !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadPosts() async {
    try {
      final page = await DefisApi.discover(limit: _pageSize);
      if (mounted) {
        setState(() {
          _posts
            ..clear()
            ..addAll(page.items);
          _next = page.next;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ DefiDiscoverPage._loadPosts : $e');
      if (mounted) {
        setState(() {
          _error = DefisApi.message(e, fallback: 'Impossible de charger les défis. Réessaie.');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_next == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await DefisApi.discover(cursor: _next, limit: _pageSize);
      if (mounted) {
        setState(() {
          _posts.addAll(page.items);
          _next = page.next;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(DefisApi.message(e, fallback: 'Impossible de charger la suite. Réessaie.')),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: 'Réessayer', textColor: Colors.white, onPressed: _loadMore),
        ));
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _next = null;
      _error = null;
      _loading = true;
    });
    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFFFFE14D), size: 22),
            const SizedBox(width: 8),
            Text(
              '🏆 Défis',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFE14D)))
          : _error != null && _posts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.cloud_off_outlined, color: colors.textSecondary, size: 56),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 15)),
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
                    ]),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFFFFE14D),
              child: _posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events, color: Color(0xFFFFE14D), size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun défi pour l\'instant',
                            style: TextStyle(color: colors.textSecondary, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sois le premier à lancer un Défi !',
                            style: TextStyle(color: colors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _posts.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _posts.length) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFFFFE14D))),
                          );
                        }
                        final post = _posts[i];
                        return PostRenderer(
                          post: post,
                          index: i,
                        );
                      },
                    ),
            ),
    );
  }
}
