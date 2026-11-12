import 'package:flutter/material.dart';

import '../../models/model_data.dart';
import '../../pages/postDetailsVideo.dart';
import '../../pages/userPosts/postWidgets/postWidgetPage.dart';
import '../../pages/userPosts/video_preload_manager.dart';
import '../../pages/userPosts/youTube_video_card.dart';

/// UNE SEULE carte de post pour tous les fils de l'écran d'accueil (« Pour toi », « Récents »…) : le choix du widget selon le type du post est ici et nulle part ailleurs.
///  - post vidéo → [YouTubeVideoCard] : lecture automatique à l'écran, préchargement des vidéos voisines, ouverture de la page de lecture complète ;
///  - pronostic (abandonné) → rien ;
///  - tout autre post (image, texte, audio, défi, chronique…) → [HomePostUsersWidget].
/// L'accueil (HomeConstPost) et l'onglet « Récents » l'utilisent tous les deux : une vidéo se comporte donc pareil partout.
class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    required this.index,
    required this.width,
    required this.height,
    this.onNeighborhoodPreload,
    this.currentFilterCountry,
    this.feedTier,
    this.color,
  });

  final Post post;

  /// Rang du post dans la liste des POSTS du fil (sans les publicités ni les cartes intercalées).
  final int index;
  final double width;

  /// Hauteur de l'écran : la carte en prend 60 %.
  final double height;
  final Function(int)? onNeighborhoodPreload;
  final String? currentFilterCountry;

  /// 'tier1' | 'tier2' | 'tier3' : transmis à la page de détails (défaut : 'tier3').
  final String? feedTier;
  final Color? color;

  /// Vrai pour les posts qui utilisent la carte vidéo (lecture automatique). Les autres cartes s'ouvrent par un appui sur la carte entière (voir l'accueil).
  static bool isVideoPost(Post post) => post.type == PostType.POST.name && post.dataType == PostDataType.VIDEO.name;

  @override
  Widget build(BuildContext context) {
    if (post.type == PostType.PRONOSTIC.name) return const SizedBox.shrink();
    if (isVideoPost(post)) {
      return YouTubeVideoCard(
        key: ValueKey('ytcard_${post.id}'),
        post: post,
        index: index,
        suppressInlineAd: true,
        onNeighborhoodPreload: onNeighborhoodPreload,
        currentFilterCountry: currentFilterCountry,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => VideoYoutubePageDetails(initialPost: post, feedTier: feedTier ?? 'tier3')),
          );
        },
      );
    }
    return HomePostUsersWidget(
      key: ValueKey('hwp-${post.id}'),
      index: index,
      post: post,
      color: color,
      height: height * 0.6,
      width: width,
      isDegrade: true,
      suppressInlineAd: true,
      currentFilterCountry: currentFilterCountry,
      feedTier: feedTier,
    );
  }

  /// Préchargement « Facebook » des vidéos voisines de [index] dans [posts] (le même que celui de l'accueil) : initialise sans jouer les vidéos
  /// proches et libère celles qui sont sorties de l'écran.
  static void preloadNeighborhood(List<Post> posts, int index) {
    if (posts.isEmpty) return;
    String? idAt(int i) => i < 0 || i >= posts.length || posts[i].dataType != PostDataType.VIDEO.name ? null : posts[i].id;
    String? urlAt(int i) => i < 0 || i >= posts.length || posts[i].dataType != PostDataType.VIDEO.name ? null : posts[i].url_media;
    VideoPreloadManager.preloadNeighborhood(index, posts.length, idAt, urlAt);
    VideoPreloadManager.cleanupOutOfRange(index, posts.length, idAt);
  }
}
