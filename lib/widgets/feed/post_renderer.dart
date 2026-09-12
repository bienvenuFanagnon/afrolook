import 'package:flutter/material.dart';
import '../../models/model_data.dart';
import '../../pages/challenge/postChallengeWidget.dart';
import '../../pages/userPosts/postWidgets/audioPostWidget.dart';
import '../../pages/userPosts/postWidgets/postWidgetPage.dart';
import '../../pages/userPosts/youTube_video_card.dart';

/// Dispatch universel : reçoit un [Post] et rend le bon widget.
///
/// Logique :
///   CHALLENGEPARTICIPATION → LookChallengePostWidget
///   POST + VIDEO            → YouTubeVideoCard
///   POST + AUDIO            → AudioPostCard
///   PRONOSTIC               → invisible
///   tout le reste           → HomePostUsersWidget
class PostRenderer extends StatelessWidget {
  final Post post;
  final int index;
  final String? filterCountry;

  const PostRenderer({
    Key? key,
    required this.post,
    this.index = 0,
    this.filterCountry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Post de type pronostic — masqué dans le feed général
    if (post.type == PostType.PRONOSTIC.name) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(builder: (context, constraints) {
      // Largeur réelle du conteneur (tient compte du CenteredContent sur wide)
      final double w = constraints.maxWidth.isFinite ? constraints.maxWidth : size.width;

      // Participation à un challenge
      if (post.type == PostType.CHALLENGEPARTICIPATION.name) {
        return LookChallengePostWidget(
          post: post,
          height: size.height,
          width: w,
        );
      }

      // Post vidéo (YouTube / local)
      if (post.type == PostType.POST.name &&
          post.dataType == PostDataType.VIDEO.name) {
        return YouTubeVideoCard(
          key: ValueKey('video_${post.id}'),
          post: post,
          index: index,
          currentFilterCountry: filterCountry,
          onTap: () => _openVideoDetails(context),
        );
      }

      // Post audio
      if (post.type == PostType.POST.name &&
          post.dataType == PostDataType.AUDIO.name) {
        return AudioPostCard(post: post);
      }

      // Cas général (image, texte, article, service…)
      return HomePostUsersWidget(
        key: ValueKey('post_${post.id}'),
        post: post,
        index: index,
        height: size.height * 0.6,
        width: w,
        isDegrade: true,
        currentFilterCountry: filterCountry,
      );
    });
  }

  void _openVideoDetails(BuildContext context) {
    // Navigation gérée à l'intérieur de YouTubeVideoCard via onTap
    // Ce stub est requis par l'API du widget.
  }
}
