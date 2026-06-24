import 'package:flutter/material.dart';

// Stub utilisé uniquement si aucune implémentation platform-spécifique n'est choisie.
class SmartVideoPlayer extends StatelessWidget {
  final String url;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final double? aspectRatio;
  final Color progressColor;

  const SmartVideoPlayer({
    Key? key,
    required this.url,
    this.autoPlay = false,
    this.looping = false,
    this.showControls = true,
    this.aspectRatio,
    this.progressColor = const Color(0xFF1FAA59),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text('Lecture vidéo non supportée sur cette plateforme.',
            style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}
