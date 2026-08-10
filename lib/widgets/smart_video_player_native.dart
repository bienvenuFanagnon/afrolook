import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/media_cache_service.dart';

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
  State<SmartVideoPlayer> createState() => _SmartVideoPlayerNativeState();
}

class _SmartVideoPlayerNativeState extends State<SmartVideoPlayer> {
  VideoPlayerController? _vpController;
  ChewieController? _chewieController;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = await MediaCacheService.videoController(widget.url);
      _vpController = ctrl;
      await ctrl.initialize();
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: widget.autoPlay,
        looping: widget.looping,
        showControls: widget.showControls,
        aspectRatio: widget.aspectRatio ?? ctrl.value.aspectRatio,
        allowFullScreen: true,
        fullScreenByDefault: false,
        materialProgressColors: ChewieProgressColors(
          backgroundColor: Colors.white24,
          playedColor: widget.progressColor,
          handleColor: widget.progressColor,
          bufferedColor: Colors.white38,
        ),
        cupertinoProgressColors: ChewieProgressColors(
          backgroundColor: Colors.white24,
          playedColor: widget.progressColor,
          handleColor: widget.progressColor,
        ),
        errorBuilder: (_, msg) => _buildError(msg),
      );
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void didUpdateWidget(SmartVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _dispose();
      setState(() { _initialized = false; _error = false; });
      _init();
    }
  }

  void _dispose() {
    _chewieController?.dispose();
    _vpController?.dispose();
    _chewieController = null;
    _vpController = null;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  Widget _buildError([String? msg]) => Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 32),
              const SizedBox(height: 8),
              const Text('Impossible de lire la vidéo',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              if (msg != null && msg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(msg,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                      textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_error) return _buildError();
    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: widget.progressColor)),
      );
    }
    return Chewie(controller: _chewieController!);
  }
}
