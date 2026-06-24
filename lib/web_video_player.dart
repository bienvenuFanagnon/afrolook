import 'package:flutter/material.dart';

import 'widgets/smart_video_player.dart';

// Sur Flutter Web, webview_flutter n'est pas disponible —
// on utilise SmartVideoPlayer (video_player_web) à la place.
// Sur Android/iOS, on garde SmartVideoPlayer pour la cohérence.

class WebVideoPlayer extends StatelessWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool looping;

  const WebVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.autoPlay = true,
    this.looping = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SmartVideoPlayer(
      url: videoUrl,
      autoPlay: autoPlay,
      looping: looping,
    );
  }
}
