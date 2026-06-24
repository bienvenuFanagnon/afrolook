import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
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
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _vpController = ctrl;
      await ctrl.initialize();
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: ctrl,
        aspectRatio: 16 / 12,
        autoPlay: false,
        looping: false,
        allowFullScreen: false,
        fullScreenByDefault: false,
        materialProgressColors: ChewieProgressColors(
          backgroundColor: Colors.green,
          playedColor: Colors.green,
          handleColor: Colors.green,
        ),
        cupertinoProgressColors: ChewieProgressColors(
          backgroundColor: Colors.green,
          playedColor: Colors.green,
          handleColor: Colors.green,
        ),
        errorBuilder: (_, __) => const Center(
          child: Icon(Icons.error_outline, color: Colors.white54),
        ),
      );
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _vpController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(child: Icon(Icons.error_outline, color: Colors.white54));
    }
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }
    return Chewie(controller: _chewieController!);
  }
}
