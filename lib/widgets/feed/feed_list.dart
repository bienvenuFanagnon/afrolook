import 'package:flutter/material.dart';
import '../../models/model_data.dart';
import '../../pages/chronique/chroniqueform.dart';
import '../../services/postService/mixed_feed_service.dart';
import 'post_renderer.dart';

/// Liste de feed générique basée sur [mixedContent] provenant de [FeedProvider].
///
/// Chaque élément est un [ContentSection]. Les sections non-post (chroniques,
/// canaux, articles) sont rendues via des builders optionnels passés par la page
/// parente — cela permet aux pages existantes d'injecter leurs propres renderers
/// le temps de la migration, sans casser le comportement actuel.
///
/// Usage minimal :
/// ```dart
/// FeedList(
///   mixedContent: context.watch<FeedProvider>().mixedFor(FeedType.home),
///   isLoading: context.watch<FeedProvider>().isLoadingFor(FeedType.home),
///   onLoadMore: () => feedProvider.loadMore(FeedType.home, ...),
/// )
/// ```
class FeedList extends StatefulWidget {
  final List<dynamic> mixedContent;
  final bool isLoading;
  final bool hasMore;
  final String? filterCountry;
  final VoidCallback? onLoadMore;

  /// Builders optionnels pour les sections spécialisées.
  /// Si null, la section correspondante est rendue par un fallback par défaut.
  final Widget Function(List<Chronique>)? chroniqueBuilder;
  final Widget Function(List<Canal>)? canauxBuilder;
  final Widget Function(List<ArticleData>)? articlesBuilder;

  const FeedList({
    Key? key,
    required this.mixedContent,
    this.isLoading = false,
    this.hasMore = true,
    this.filterCountry,
    this.onLoadMore,
    this.chroniqueBuilder,
    this.canauxBuilder,
    this.articlesBuilder,
  }) : super(key: key);

  @override
  State<FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<FeedList> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !widget.hasMore || widget.onLoadMore == null) return;
    final threshold = _scrollController.position.maxScrollExtent * 0.85;
    if (_scrollController.position.pixels >= threshold) {
      _isLoadingMore = true;
      widget.onLoadMore!();
      // Réinitialiser après un court délai pour éviter les déclenchements multiples
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isLoadingMore = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      itemCount: widget.mixedContent.length + (widget.isLoading || widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.mixedContent.length) {
          return _buildFooter();
        }
        final section = widget.mixedContent[index];
        if (section is ContentSection) {
          return _buildSection(section);
        }
        // Fallback pour compatibilité (Post direct dans la liste)
        if (section is Post) {
          return PostRenderer(
            post: section,
            index: index,
            filterCountry: widget.filterCountry,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSection(ContentSection section) {
    switch (section.type) {
      case ContentMixtType.POST:
        final post = section.data as Post?;
        if (post == null) return const SizedBox.shrink();
        return PostRenderer(
          key: ValueKey('renderer_${post.id}'),
          post: post,
          filterCountry: widget.filterCountry,
        );

      case ContentMixtType.CHRONIQUES:
        final chroniques = section.data as List<Chronique>? ?? [];
        if (chroniques.isEmpty) return const SizedBox.shrink();
        if (widget.chroniqueBuilder != null) {
          return widget.chroniqueBuilder!(chroniques);
        }
        return _defaultChroniqueRow(chroniques);

      case ContentMixtType.CANAUX:
        final canaux = section.data as List<Canal>? ?? [];
        if (canaux.isEmpty) return const SizedBox.shrink();
        if (widget.canauxBuilder != null) {
          return widget.canauxBuilder!(canaux);
        }
        return const SizedBox.shrink();

      case ContentMixtType.ARTICLES:
        final articles = section.data as List<ArticleData>? ?? [];
        if (articles.isEmpty) return const SizedBox.shrink();
        if (widget.articlesBuilder != null) {
          return widget.articlesBuilder!(articles);
        }
        return const SizedBox.shrink();
    }
  }

  /// Fallback minimal pour les chroniques : rangée d'avatars circulaires.
  /// Les pages migrées fourniront leur propre [chroniqueBuilder].
  Widget _defaultChroniqueRow(List<Chronique> chroniques) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chroniques.length,
        itemBuilder: (context, index) {
          final c = chroniques[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF25D366), width: 2),
                    image: c.userImageUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(c.userImageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: c.userImageUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(
                    c.userPseudo,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '— Fin du feed —',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox(height: 80);
  }
}
