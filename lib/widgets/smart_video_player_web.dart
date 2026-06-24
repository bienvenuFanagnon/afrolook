// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Lecteur vidéo Web natif — utilise un élément HTML <video> directement.
/// Contourne complètement video_player_web et son bug 'isSupported'.
class SmartVideoPlayer extends StatefulWidget {
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
  State<SmartVideoPlayer> createState() => _SmartVideoPlayerWebState();
}

class _SmartVideoPlayerWebState extends State<SmartVideoPlayer> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'svp-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      final video = html.VideoElement()
        ..src = widget.url
        ..controls = widget.showControls
        ..autoplay = widget.autoPlay
        ..loop = widget.looping
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.background = '#000000'
        ..setAttribute('crossorigin', 'anonymous')
        ..setAttribute('playsinline', 'true');
      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
