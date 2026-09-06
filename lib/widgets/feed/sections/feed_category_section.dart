import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/user_interests.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../services/feed/feed_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../pages/home/category_feed_page.dart';
import '../../../pages/postDetailsVideo.dart';
import '../../../pages/postDetails.dart';

/// Mini-section "Découverte — [Catégorie]" affichée dans le feed principal.
/// Montre 2 posts compacts de la catégorie + bouton "Voir plus".
/// Se charge de façon autonome (pas de propagation d'état depuis HomeConstPost).
class FeedCategorySectionWidget extends StatefulWidget {
  final String categoryId;
  final Set<String> excludedIds;

  const FeedCategorySectionWidget({
    super.key,
    required this.categoryId,
    this.excludedIds = const {},
  });

  @override
  State<FeedCategorySectionWidget> createState() => _FeedCategorySectionWidgetState();
}

class _FeedCategorySectionWidgetState extends State<FeedCategorySectionWidget> {
  List<Post>? _posts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<UserAuthProvider>();
    final countryCode =
        auth.loginUserData.countryData?['countryCode'] as String? ?? '';
    final posts = await FeedRepository().fetchInterestPosts(
      [widget.categoryId],
      widget.excludedIds,
      countryCode: countryCode,
      limit: 2,
    );
    if (mounted) setState(() => _posts = posts);
  }

  @override
  Widget build(BuildContext context) {
    // Pas encore chargé → rien (évite tout saut de layout)
    if (_posts == null) return const SizedBox.shrink();
    // Aucun post pour cette catégorie → section masquée
    if (_posts!.isEmpty) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final cat = UserInterests.categoryById(widget.categoryId);
    final emoji = cat?.emoji ?? '📌';
    final label = cat?.labelFr ?? widget.categoryId;
    final catColor = UserInterests.categoryColor(widget.categoryId, isDark: colors.isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                'Découverte · $label',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: catColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [catColor.withOpacity(0.35), Colors.transparent],
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryFeedPage(
                      categoryId: widget.categoryId,
                      categoryLabel: label,
                      categoryEmoji: emoji,
                    ),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Voir plus',
                  style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        // ── 2 posts compacts ─────────────────────────────────────────────
        for (final post in _posts!)
          _MiniCategoryCard(post: post, catColor: catColor, colors: colors),

        const SizedBox(height: 4),
      ],
    );
  }
}

class _MiniCategoryCard extends StatelessWidget {
  final Post post;
  final Color catColor;
  final AppColors colors;

  const _MiniCategoryCard({
    required this.post,
    required this.catColor,
    required this.colors,
  });

  void _open(BuildContext context) {
    final route = post.dataType == PostDataType.VIDEO.name
        ? MaterialPageRoute(
            builder: (_) => VideoYoutubePageDetails(initialPost: post))
        : MaterialPageRoute(builder: (_) => DetailsPost(post: post));
    Navigator.push(context, route);
  }

  /// Extrait la bonne miniature selon le type du post.
  String _thumbUrl() {
    final dt = post.dataType ?? '';
    if (dt == PostDataType.IMAGE.name) {
      // IMAGE : première image de la liste
      if (post.images?.isNotEmpty == true) return post.images!.first;
      return post.thumbnail ?? '';
    }
    if (dt == PostDataType.VIDEO.name) {
      // VIDEO : thumbnail généré, jamais l'URL vidéo
      return post.thumbnail ?? '';
    }
    // AUDIO, TEXT, etc.
    return post.thumbnail ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbUrl();
    final desc = post.description ?? '';
    final pseudo = post.user?.pseudo ?? '';
    final isVideo = post.dataType == PostDataType.VIDEO.name;
    final isAudio = post.dataType == PostDataType.AUDIO.name;

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: catColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Miniature — taille agrandie
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: SizedBox(
                width: 104,
                height: 104,
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
                    // Overlay type
                    if (isVideo)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 34),
                        ),
                      )
                    else if (isAudio && thumb.isEmpty)
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            // Description + auteur
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    if (pseudo.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '@$pseudo',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Flèche
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right, size: 18, color: catColor.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({bool isAudio = false}) {
    return Container(
      color: colors.shimmerBase,
      child: isAudio
          ? Center(child: Icon(Icons.music_note_rounded, color: catColor.withOpacity(0.6), size: 38))
          : const SizedBox.shrink(),
    );
  }
}
