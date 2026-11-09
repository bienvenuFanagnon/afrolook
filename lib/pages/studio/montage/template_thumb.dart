import 'package:flutter/material.dart';

/// Pastille « vidéo » posée au centre de l'aperçu d'un modèle qui se fait en vidéo (modèle à vidéo d'exemple, ou à filtres de visage filmés à la caméra) : l'aperçu reste une image
/// de l'application, avec l'icône d'une vidéo par-dessus (demande du 09/11/2026).
class VideoBadge extends StatelessWidget {
  const VideoBadge({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('video_badge'),
      width: size,
      height: size,
      decoration: BoxDecoration(color: const Color(0x99000000), shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1.5)),
      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * .66),
    );
  }
}

/// Aperçu d'un modèle : une image de l'application ([asset]) et, si le modèle se fait en vidéo ([video]), l'icône vidéo par-dessus.
class TemplateThumb extends StatelessWidget {
  const TemplateThumb({super.key, required this.asset, required this.video, this.cacheWidth = 400, this.badgeSize = 40});
  final String asset;
  final bool video;
  final int cacheWidth;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
      Image.asset(asset, fit: BoxFit.cover, cacheWidth: cacheWidth),
      if (video) Center(child: VideoBadge(size: badgeSize)),
    ]);
  }
}
