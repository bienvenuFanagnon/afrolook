import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../l10n/tr.dart';
import '../models/model_data.dart';
import '../pages/postDetailsVideo.dart';
import '../pages/post_video_format_tel_details.dart';
import '../services/api/posts_api.dart';
import '../services/post_orientation.dart';
import 'post_widget_view.dart';

/// Tout ce qui se pose SUR le média d'une publication, au même endroit partout (fil, pages de détail, lecteur vertical) :
/// les widgets du créateur (sondage, quiz, question, lien, carte de vente…, dans leur plage de temps pour une vidéo) et les vidéos épinglées (« Voir l'original »).
/// À placer dans un `Stack` au-dessus du média : `Positioned.fill(child: PostMediaOverlays(post: post))`.
/// [video] : le lecteur de la vidéo (les widgets « de… à… » n'apparaissent que dans leur plage) ; [mediaAspect] : format réel du média quand il est montré en entier.
class PostMediaOverlays extends StatelessWidget {
  const PostMediaOverlays({super.key, required this.post, this.video, this.mediaAspect, this.feedTier});

  final Post post;
  final VideoPlayerController? video;
  final double? mediaAspect;
  final String? feedTier;

  @override
  Widget build(BuildContext context) {
    final hasWidgets = post.widgets.isNotEmpty;
    final hasPins = post.studioPins.isNotEmpty;
    if (!hasWidgets && !hasPins) return const SizedBox.shrink();
    return Stack(fit: StackFit.expand, children: [
      if (hasPins) _StudioPinMarkers(post: post, feedTier: feedTier),
      if (hasWidgets) PostWidgetsLayer(widgets: post.widgets, video: video, mediaAspect: mediaAspect),
    ]);
  }
}

/// Vidéo épinglée dans le post : un toucher ouvre la vidéo d'origine (repère « ▶ Voir l'original » à l'endroit où elle est posée).
class _StudioPinMarkers extends StatelessWidget {
  const _StudioPinMarkers({required this.post, this.feedTier});

  final Post post;
  final String? feedTier;

  Future<void> _open(BuildContext context, String id) async {
    final target = await PostsApi.get(id);
    if (!context.mounted) return;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Vidéo indisponible'))));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostOrientation.of(target) ? PostDetailsVideoFormatTel(initialPost: target, isIn: false) : VideoYoutubePageDetails(initialPost: target, feedTier: feedTier)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return Stack(children: [
        for (final p in post.studioPins.take(2))
          Positioned(
            left: (((p['x'] as num?)?.toDouble() ?? .8) * box.maxWidth - 46).clamp(4, box.maxWidth - 96).toDouble(),
            top: (((p['y'] as num?)?.toDouble() ?? .2) * box.maxHeight + ((p['w'] as num?)?.toDouble() ?? .3) * box.maxWidth * .3).clamp(4, box.maxHeight - 34).toDouble(),
            child: GestureDetector(
              key: ValueKey('pin_open_${p['post_id']}'),
              onTap: () => _open(context, '${p['post_id']}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(context.tr("Voir l'original"), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
      ]);
    });
  }
}
