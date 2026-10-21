import 'package:afrotok/services/read_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/model_data.dart';
import '../../../services/feed/seen_discovery_cache.dart';
import '../../../theme/app_colors.dart';

/// Posts « À découvrir » affichés quand il n'y a plus (ou pas du tout) de post non lu, à la place d'un écran sans contenu.
///
/// - Accueil : on reprend les [seed] déjà préchargés en arrière-plan (aucune lecture de plus).
/// - Fil par thème (Sport, Looks…) : lecture unique des posts récents du thème, filtrés côté client (même source que la page Découvrir).
/// - Jamais un post déjà chargé dans le fil ([excludeIds]), déjà vu en découverte, ni un post de la personne ou d'un créateur qu'elle suit.
/// - L'affichage d'un post est délégué à la page ([buildPost]) : mêmes cartes, mêmes lecteurs vidéo que le reste du fil.
class FeedDiscoverySection extends StatefulWidget {
  const FeedDiscoverySection({
    Key? key,
    required this.myId,
    required this.buildPost,
    this.pageType,
    this.seed = const [],
    this.excludeIds = const {},
    this.followedIds = const {},
    this.maxPosts = 8,
    this.onShown,
  }) : super(key: key);

  final String myId;

  /// null = accueil ; sinon thème du fil (`typeTabbar` : SPORT, LOOKS…).
  final String? pageType;
  final List<Post> seed;
  final Set<String> excludeIds;
  final Set<String> followedIds;
  final int maxPosts;

  /// Construit la carte d'un post (index de départ fourni pour les lecteurs vidéo de la page).
  final Widget Function(Post post, int index) buildPost;

  /// Appelé avec les posts retenus (la page peut leur donner un badge « Découverte »).
  final void Function(List<Post> posts)? onShown;

  @override
  State<FeedDiscoverySection> createState() => _FeedDiscoverySectionState();
}

class _FeedDiscoverySectionState extends State<FeedDiscoverySection> {
  List<Post>? _posts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _eligible(Post p) {
    final id = p.id ?? '';
    if (id.isEmpty || widget.excludeIds.contains(id)) return false;
    if (p.type != PostType.POST.name) return false;
    if (p.status != null && p.status != PostStatus.VALIDE.name) return false;
    final uid = p.user_id ?? '';
    if (uid.isEmpty || uid == widget.myId || widget.followedIds.contains(uid)) return false;
    if (widget.pageType != null && p.typeTabbar != widget.pageType) return false;
    return true;
  }

  Future<void> _load() async {
    final seen = SeenDiscoveryCache.instance.seenIds;
    var pool = widget.seed.where(_eligible).where((p) => !seen.contains(p.id)).toList();
    if (pool.isEmpty) {
      try {
        // orderBy created_at seul : index automatique (le thème et le statut sont filtrés côté client, comme la page Découvrir)
        final snap = await FirebaseFirestore.instance
            .collection('Posts')
            .orderBy('created_at', descending: true)
            .limit(40)
            .getM('feed_discovery_section.dart:load');
        pool = snap.docs
            .map((d) {
              try {
                return Post.fromJson(d.data())..id = d.id;
              } catch (_) {
                return null;
              }
            })
            .whereType<Post>()
            .where(_eligible)
            .where((p) => !seen.contains(p.id))
            .toList();
      } catch (_) {}
    }
    // un seul post par créateur : une découverte variée plutôt que cinq posts de la même personne
    final byCreator = <String>{};
    final picked = <Post>[];
    for (final p in pool) {
      if (byCreator.add(p.user_id ?? '')) picked.add(p);
      if (picked.length >= widget.maxPosts) break;
    }
    if (picked.isNotEmpty) {
      SeenDiscoveryCache.instance.add(picked.map((p) => p.id!));
      SeenDiscoveryCache.instance.save();
      widget.onShown?.call(picked);
    }
    if (mounted) setState(() => _posts = picked);
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    if (posts == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (posts.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Icon(Icons.explore_rounded, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('À découvrir',
                  style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        for (var i = 0; i < posts.length; i++) RepaintBoundary(child: widget.buildPost(posts[i], i)),
        const SizedBox(height: 8),
      ],
    );
  }
}
