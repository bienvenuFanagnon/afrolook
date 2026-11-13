import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/model_data.dart';
import '../../theme/app_colors.dart';

/// Petit aperçu d'un post (une vignette carrée) pour les endroits où l'on parle d'un post sans l'afficher en entier, par exemple l'en-tête de la page de commentaires.
///  - image : la première image ; vidéo : la miniature (sinon une tuile sombre) avec une pastille « lecture » ;
///  - plusieurs images : une pastille indique qu'il y en a d'autres ;
///  - audio : une tuile avec une note de musique ; texte : le début du texte.
/// Léger : aucune requête, rien que les champs déjà présents dans le post.
class PostMiniPreview extends StatelessWidget {
  const PostMiniPreview({super.key, required this.post, this.size = 52, this.onTap});

  final Post post;
  final double size;

  /// Appui sur l'aperçu (null : l'aperçu n'est qu'une image).
  final VoidCallback? onTap;

  static String? _http(String? u) {
    final t = u?.trim() ?? '';
    return t.startsWith('http') ? t : null;
  }

  /// Adresse de l'image à montrer (null : tuile de remplacement selon le type).
  static String? imageUrl(Post p) {
    if (p.dataType == 'VIDEO') return _http(p.thumbnail);
    if (p.dataType == 'AUDIO') return _http(p.thumbnail);
    String? firstImage;
    for (final u in p.images ?? const <String>[]) {
      final h = _http(u);
      if (h != null) {
        firstImage = h;
        break;
      }
    }
    return _http(p.url_media) ?? firstImage ?? _http(p.thumbnail);
  }

  /// Nombre d'images du post (la pastille n'apparaît qu'au-dessus de 1).
  static int imageCount(Post p) => p.dataType == 'IMAGE' ? (p.images ?? const <String>[]).where((e) => e.trim().isNotEmpty).length : 0;

  /// Début du texte (sans retour à la ligne), pour la tuile d'un post sans image.
  static String excerpt(Post p, {int max = 42}) {
    final t = (p.description ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= max ? t : '${t.substring(0, max).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final url = imageUrl(post);
    final isVideo = post.dataType == 'VIDEO';
    final isAudio = post.dataType == 'AUDIO';
    final more = imageCount(post);
    final radius = BorderRadius.circular(10);

    Widget tile(Widget child) => Container(color: c.surfaceVariant, alignment: Alignment.center, child: child);
    final Widget content = url != null
        ? CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: size,
            height: size,
            fadeInDuration: const Duration(milliseconds: 120),
            placeholder: (_, __) => tile(const SizedBox.shrink()),
            errorWidget: (_, __, ___) => tile(Icon(isVideo ? Icons.videocam_rounded : Icons.image_rounded, size: size * .42, color: c.textSecondary)),
          )
        : isVideo
            ? tile(Icon(Icons.videocam_rounded, size: size * .42, color: c.textSecondary))
            : isAudio
                ? tile(Icon(Icons.music_note_rounded, size: size * .46, color: c.accentText))
                : tile(Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      excerpt(post).isEmpty ? '·' : excerpt(post),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary, fontSize: size * .17, height: 1.15),
                    ),
                  ));

    Widget badge(IconData icon, {String? label}) => Positioned(
          right: 3,
          bottom: 3,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: label == null ? 3 : 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .62), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 11, color: Colors.white),
              if (label != null) ...[const SizedBox(width: 2), Text(label, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700))],
            ]),
          ),
        );

    final preview = Semantics(
      label: 'Aperçu du post',
      image: true,
      child: Container(
        key: const ValueKey('post_mini_preview'),
        width: size,
        height: size,
        decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: c.border.withValues(alpha: .6))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(fit: StackFit.expand, children: [
            content,
            if (isVideo) badge(Icons.play_arrow_rounded),
            if (more > 1) badge(Icons.collections_rounded, label: '$more'),
          ]),
        ),
      ),
    );
    return onTap == null ? preview : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: preview);
  }
}
