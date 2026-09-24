import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feed/post_renderer.dart';

class DefiDiscoverPage extends StatefulWidget {
  const DefiDiscoverPage({super.key});

  @override
  State<DefiDiscoverPage> createState() => _DefiDiscoverPageState();
}

class _DefiDiscoverPageState extends State<DefiDiscoverPage> {
  final List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  DocumentSnapshot? _lastDoc;
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
      final snap = await FirebaseFirestore.instance
          .collection('Posts')
          .where('type', isEqualTo: PostType.DEFI.name)
          .orderBy('created_at', descending: true)
          .limit(_pageSize)
          .get();

      final posts = snap.docs.map((d) => Post.fromJson(d.data())).toList();
      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ DefiDiscoverPage._loadPosts error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_lastDoc == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Posts')
          .where('type', isEqualTo: PostType.DEFI.name)
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      final posts = snap.docs.map((d) => Post.fromJson(d.data())).toList();
      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() { _posts.clear(); _lastDoc = null; _loading = true; });
    await _loadPosts();
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
